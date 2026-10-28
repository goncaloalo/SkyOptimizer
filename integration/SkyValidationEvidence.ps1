# Declarations only. Independent, read-only collector; never imports the product writer.
# Snapshots cover explicit resources only, not the entire Windows installation.

function Get-SkyEvidenceDigest {
    param([byte[]]$Key, [string]$Text)
    if ($Key.Length -ne 32) { throw 'A private 32-byte evidence key is required.' }
    $hmac = New-Object Security.Cryptography.HMACSHA256
    try {
        $hmac.Key = $Key
        ([BitConverter]::ToString($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '')
    } finally { $hmac.Dispose() }
}

function Get-SkyEvidenceIdentity {
    @([Environment]::MachineName, [Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
}

function Open-SkyEvidenceRegistryRoot {
    param([string]$Hive, [string]$View)
    [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]$Hive, [Microsoft.Win32.RegistryView]$View)
}

function Read-SkyEvidenceResource {
    param($Spec)
    switch ($Spec.Type) {
        'Registry' {
            if ($Spec.Hive -notin @('LocalMachine','CurrentUser') -or $Spec.View -notin @('Registry64','Registry32')) { throw 'Invalid registry scope.' }
            $root = Open-SkyEvidenceRegistryRoot $Spec.Hive $Spec.View
            $key = $null
            try {
                $key = $root.OpenSubKey([string]$Spec.Path, $false)
                if ($null -eq $key -or [string]$Spec.Name -notin $key.GetValueNames()) { return [ordered]@{ Exists = $false } }
                $kind = $key.GetValueKind([string]$Spec.Name).ToString()
                if ($kind -notin @('String','ExpandString','MultiString','Binary','DWord','QWord')) { throw 'Unsupported registry kind.' }
                [ordered]@{ Exists = $true; Kind = $kind
                    Value = $key.GetValue([string]$Spec.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
            } finally { if ($key) { $key.Dispose() }; $root.Dispose() }
        }
        'Service' {
            if ($Spec.Name -notmatch '^[a-zA-Z0-9_.-]+$') { throw 'Invalid service name.' }
            $services = @(Get-CimInstance -ClassName Win32_Service -Filter "Name='$($Spec.Name)'" -ErrorAction Stop)
            if (-not $services.Count) { return [ordered]@{ Exists = $false } }
            if ($services.Count -ne 1) { throw 'Ambiguous service.' }
            $svc = $services[0]
            [ordered]@{ Exists = $true; StartMode = [string]$svc.StartMode; State = [string]$svc.State
                DelayedAutoStart = (Read-SkyEvidenceResource ([pscustomobject]@{ Type='Registry'; Hive='LocalMachine'; View='Registry64'; Path="SYSTEM\CurrentControlSet\Services\$($Spec.Name)"; Name='DelayedAutoStart' })) }
        }
        'Power' {
            # Full active-plan query plus the plan list; inactive-plan indices need separate inventory.
            $parts = @()
            foreach ($arg in @('/getactivescheme','/list','/qh')) {
                $output = & (Join-Path ([Environment]::SystemDirectory) 'powercfg.exe') $arg 2>&1
                if ($LASTEXITCODE -ne 0) { throw 'Power inventory failed.' }
                $parts += ($output -join "`n")
            }
            [ordered]@{ Output = $parts }
        }
        default { throw 'Unsupported evidence resource type.' }
    }
}

function Get-SkyValidationSnapshot {
    param([object[]]$Resources, [byte[]]$Key, [string]$SourceSha256, [ValidateSet('Before','AfterApply','AfterReboot','AfterUndo','AfterUndoReboot')][string]$Stage)
    if ($SourceSha256 -notmatch '^[A-Fa-f0-9]{64}$' -or -not $Stage) { throw 'Source hash and stage are required.' }
    if (-not $Resources.Count) { throw 'Explicit nonempty resource scope is required.' }
    $ids = @{}
    $scope = @()
    foreach ($spec in $Resources) {
        if ($spec.Id -notmatch '^R[0-9]{3}$' -or $ids.ContainsKey([string]$spec.Id)) { throw 'Use unique anonymous IDs R001..R999.' }
        $ids[[string]$spec.Id] = $true
        # Fixed property order makes scope stable across JSON property ordering.
        if ($spec.Type -eq 'Registry') {
            if ($spec.Hive -notin @('LocalMachine','CurrentUser') -or $spec.View -notin @('Registry64','Registry32') -or [string]::IsNullOrWhiteSpace($spec.Path)) { throw 'Invalid registry scope.' }
            $canonical = @('Registry', [string]$spec.Hive, [string]$spec.View, ([string]$spec.Path).ToUpperInvariant(), ([string]$spec.Name).ToUpperInvariant())
        } elseif ($spec.Type -eq 'Service' -and $spec.Name -match '^[a-zA-Z0-9_.-]+$') {
            $canonical = @('Service', ([string]$spec.Name).ToUpperInvariant())
        } elseif ($spec.Type -eq 'Power') { $canonical = @('Power') }
        else { throw 'Unsupported or invalid scope.' }
        $scope += [pscustomobject]@{ Id=[string]$spec.Id; Spec=$spec; Digest=(Get-SkyEvidenceDigest $Key (ConvertTo-Json -InputObject $canonical -Compress)) }
    }
    $entries = foreach ($item in $scope | Sort-Object Id) {
        try {
            $state = Read-SkyEvidenceResource $item.Spec
            if ($null -eq $state) { throw 'No state returned.' }
            $digest = Get-SkyEvidenceDigest $Key (ConvertTo-Json -InputObject $state -Depth 20 -Compress)
            [pscustomobject]@{ Id=$item.Id; ScopeDigest=$item.Digest; Status='Observed'; StateDigest=$digest }
        } catch {
            # No exception, path, SID, GUID, value or service name is exported.
            [pscustomobject]@{ Id=$item.Id; ScopeDigest=$item.Digest; Status='ReadFailed'; StateDigest=$null }
        }
    }
    [pscustomobject]@{ SchemaVersion=1; Stage=$Stage; TimestampUtc=[DateTime]::UtcNow.ToString('o')
        SourceSha256=$SourceSha256.ToUpperInvariant(); KeyId=(Get-SkyEvidenceDigest $Key 'SkyEvidence-KeyId-v1')
        IdentityDigest=(Get-SkyEvidenceDigest $Key (ConvertTo-Json -InputObject @(Get-SkyEvidenceIdentity) -Compress)); Entries=@($entries) }
}

function Compare-SkyValidationSnapshot {
    param($Before, $After)
    if ($Before.SchemaVersion -ne 1 -or $After.SchemaVersion -ne 1 -or
        $Before.SourceSha256 -cne $After.SourceSha256 -or $Before.KeyId -cne $After.KeyId -or
        $Before.KeyId -notmatch '^[A-F0-9]{64}$' -or $Before.SourceSha256 -notmatch '^[A-F0-9]{64}$' -or
        $Before.IdentityDigest -notmatch '^[A-F0-9]{64}$' -or $Before.IdentityDigest -cne $After.IdentityDigest) { throw 'Incompatible snapshot metadata.' }
    $maps = @()
    foreach ($snapshot in @($Before,$After)) {
        $map = @{}
        foreach ($entry in $snapshot.Entries) {
            if ($entry.Id -notmatch '^R[0-9]{3}$' -or $map.ContainsKey([string]$entry.Id) -or
                $entry.ScopeDigest -notmatch '^[A-F0-9]{64}$' -or $entry.Status -notin @('Observed','ReadFailed') -or
                ($entry.Status -eq 'Observed' -and $entry.StateDigest -notmatch '^[A-F0-9]{64}$')) { throw 'Malformed snapshot entry.' }
            $map[[string]$entry.Id] = $entry
        }
        if (-not $map.Count) { throw 'Empty snapshot.' }
        $maps += ,$map
    }
    if ((($maps[0].Keys | Sort-Object) -join ',') -cne (($maps[1].Keys | Sort-Object) -join ',')) { throw 'Resource coverage differs.' }
    $rows = foreach ($id in $maps[0].Keys | Sort-Object) {
        $a=$maps[0][$id]; $b=$maps[1][$id]
        if ($a.ScopeDigest -cne $b.ScopeDigest) { throw 'Resource scope differs.' }
        $status = if ($a.Status -ne 'Observed' -or $b.Status -ne 'Observed') { 'Inconclusive' }
            elseif ($a.StateDigest -ceq $b.StateDigest) { 'Equal' } else { 'Changed' }
        [pscustomobject]@{ Id=$id; Status=$status }
    }
    $verdict = if (@($rows | Where-Object Status -eq 'Inconclusive').Count) { 'Inconclusive' }
        elseif (@($rows | Where-Object Status -eq 'Changed').Count) { 'Changed' } else { 'Equal' }
    [pscustomobject]@{ Verdict=$verdict; Entries=@($rows); Note='Scoped comparison only; equality does not certify the whole OS or policy consumption.' }
}
