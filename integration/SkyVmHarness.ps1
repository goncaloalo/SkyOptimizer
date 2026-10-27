# Declarations only. Dot-sourcing this file does not execute a scenario or alter Windows.
# Real scenarios require a matching guest manifest, explicit opt-in and a disposable VM.

function Get-SkyVmContext {
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    [pscustomobject]@{
        MachineId = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid
        UserSid = $identity.User.Value
        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Manufacturer = [string]$computer.Manufacturer
        Model = [string]$computer.Model
        BootId = $os.LastBootUpTime.ToUniversalTime().ToString('o')
        SystemDrive = $env:SystemDrive
    }
}

function Assert-SkyVmPermission {
    param($Manifest, $Context, [string]$SourcePath, [switch]$AllowSystemChanges)
    if (-not $AllowSystemChanges) { throw 'Explicit -AllowSystemChanges is required. No scenario executed.' }
    if ($Manifest.SchemaVersion -ne 1 -or $Manifest.Acknowledgement -cne 'DISPOSABLE-VM-WITH-SNAPSHOT' -or
        [string]::IsNullOrWhiteSpace($Manifest.SnapshotReference)) { throw 'A disposable-VM manifest and snapshot reference are required.' }
    $id = [guid]::Empty
    if (-not [guid]::TryParseExact([string]$Manifest.RunId, 'D', [ref]$id) -or $id -eq [guid]::Empty) { throw 'Invalid RunId.' }
    if (-not $Context.IsAdministrator -or [string]::IsNullOrWhiteSpace($Context.MachineId) -or
        [string]::IsNullOrWhiteSpace($Context.UserSid) -or [string]::IsNullOrWhiteSpace($Context.BootId) -or
        $Manifest.MachineId -ne $Context.MachineId -or $Manifest.UserSid -ne $Context.UserSid) { throw 'Guest identity, user or elevation does not match.' }
    # HypervisorPresent alone also matches physical Hyper-V hosts. Require a guest model/vendor pair.
    $guest = ($Context.Manufacturer -match '^Microsoft Corporation$' -and $Context.Model -eq 'Virtual Machine') -or
        ($Context.Manufacturer -match '^VMware' -and $Context.Model -match '^VMware') -or
        ($Context.Manufacturer -match '^(innotek GmbH|Oracle Corporation)$' -and $Context.Model -eq 'VirtualBox') -or
        ($Context.Manufacturer -match '^(QEMU|Red Hat)$' -and $Context.Model -match '(KVM|Virtual Machine|QEMU)')
    if (-not $guest) { throw 'Guest model not recognized. Physical hosts and unknown environments are refused.' }
    $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256 -ErrorAction Stop).Hash
    if ($Manifest.SourceSha256 -notmatch '^[0-9a-fA-F]{64}$' -or $Manifest.SourceSha256 -ne $sourceHash) { throw 'Product source hash differs from the manifest.' }
    [pscustomobject]@{
        RunId = $id.ToString('N')
        Directory = Join-Path (Join-Path $Context.SystemDrive 'SkyOptimizer-Lab') $id.ToString('N')
        RegistryPath = "HKCU:\Software\SkyOptimizerIntegration\$($id.ToString('N'))"
        SourceSha256 = $sourceHash
    }
}

function Get-SkyVmDeclarations {
    param([string]$SourcePath)
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($SourcePath, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Product source does not parse.' }
    $definitions = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)
    [scriptblock]::Create(($definitions | ForEach-Object { $_.Extent.Text }) -join "`r`n")
}

function Assert-SkyVmLabPath {
    param([string]$Directory)
    $paths = @((Split-Path -Parent $Directory), $Directory, (Join-Path $Directory 'Backups'))
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path -ErrorAction Stop) {
            $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Lab paths must be real directories, without junctions or symbolic links.'
            }
        }
    }
}

function New-SkyVmRegistryCases {
    param([string]$RegistryPath)
    $specifications = @(
        @{ Name = 'Absent'; Original = (ConvertTo-SkyRegistryState -Exists $false); Desired = (ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 1) },
        @{ Name = 'Expand'; Original = (ConvertTo-SkyRegistryState -Exists $true -Kind ExpandString -Value '%SystemRoot%\literal'); Desired = (ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'changed') },
        @{ Name = 'Binary'; Original = (ConvertTo-SkyRegistryState -Exists $true -Kind Binary -Value ([byte[]]@(0,255,17,0))); Desired = (ConvertTo-SkyRegistryState -Exists $false) },
        @{ Name = 'Multi'; Original = (ConvertTo-SkyRegistryState -Exists $true -Kind MultiString -Value @('first','second')); Desired = (ConvertTo-SkyRegistryState -Exists $true -Kind MultiString -Value @('replacement')) },
        @{ Name = 'QWord'; Original = (ConvertTo-SkyRegistryState -Exists $true -Kind QWord -Value ([long]::MaxValue)); Desired = (ConvertTo-SkyRegistryState -Exists $true -Kind QWord -Value 0) },
        @{ Name = ''; Original = (ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'default'); Desired = (ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value -1) },
        @{ Name = 'Untouched'; Original = (ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'preserve'); Desired = (ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'preserve') }
    )
    foreach ($specification in $specifications) {
        [pscustomobject]@{ Resource = ConvertTo-SkyRegistryResource $RegistryPath $specification.Name
            Original = $specification.Original; Desired = $specification.Desired }
    }
}

function Assert-SkyVmCaseStates {
    param([object[]]$Cases, [ValidateSet('Original','Desired')][string]$Mode)
    foreach ($case in $Cases) {
        if (-not (Test-SkyStateEqual (Get-SkyResourceState $case.Resource) $case.$Mode)) {
            throw "Fixture differs from $Mode at value '$($case.Resource.Name)'. Evidence preserved."
        }
    }
}

function Invoke-SkyVmFaultedWrite {
    param([scriptblock]$Operation)
    # Fault injection after the real setter, before the caller persists completion.
    # This models an exception at that boundary, not power-loss durability.
    $originalSetter = (Get-Command Set-SkyResourceState).ScriptBlock
    $fault = @{ Armed = $true; Writes = 0 }
    function Set-SkyResourceState {
        param($Resource, $State)
        & $originalSetter -Resource $Resource -State $State
        $fault.Writes++
        if ($fault.Armed) { $fault.Armed = $false; throw 'SKY_VM_INJECTED_AFTER_WRITE' }
    }
    try { & $Operation }
    finally { Remove-Item -LiteralPath Function:\Set-SkyResourceState -ErrorAction Stop }
}

function Invoke-SkyVmRegistryStep {
    param([string]$Stage, $State, [object[]]$Cases, [string]$BackupDirectory, [string]$BootId)
    switch ($Stage) {
        'Apply' {
            if ($State.Phase -notin @('Prepared','Applied')) { throw 'Apply requires Prepared or Applied.' }
            foreach ($case in $Cases) {
                $result = Invoke-SkyTrackedChange -Resource $case.Resource -Desired $case.Desired -BackupDirectory $BackupDirectory
                if ($result.Status -notin @('Applied','AlreadyCompliant')) { throw 'Apply was not verified.' }
            }
            Assert-SkyVmCaseStates $Cases Desired
            $State.Phase = 'Applied'; $State.ApplyBootId = $BootId
        }
        'VerifyAfterReboot' {
            if ($State.Phase -ne 'Applied' -or $State.ApplyBootId -eq $BootId) { throw 'A new OS boot after Apply is required.' }
            Assert-SkyVmCaseStates $Cases Desired
            $journal = Read-SkyMutationState $BackupDirectory
            foreach ($case in $Cases | Where-Object { $_.Resource.Name -ne 'Untouched' }) {
                $entry = @($journal.Entries | Where-Object { $_.Status -ne 'Restored' -and $_.Resource.Name -eq $case.Resource.Name })
                if ($entry.Count -ne 1 -or -not (Test-SkyStateEqual $entry[0].Original $case.Original)) { throw 'Original baseline did not survive Apply/reboot.' }
            }
            $State.Phase = 'VerifiedAfterReboot'
        }
        'Undo' {
            if ($State.Phase -notin @('Applied','VerifiedAfterReboot','Restored')) { throw 'Undo requires a completed Apply.' }
            $results = @(Restore-SkyTrackedChanges $BackupDirectory)
            if (@($results | Where-Object Status -eq 'Failed').Count) { throw 'Undo failed. Journal and fixture preserved.' }
            Assert-SkyVmCaseStates $Cases Original
            $State.Phase = 'Restored'; $State.UndoBootId = $BootId
        }
        'VerifyAfterUndo' {
            if ($State.Phase -ne 'Restored' -or $State.UndoBootId -eq $BootId) { throw 'A new OS boot after Undo is required.' }
            Assert-SkyVmCaseStates $Cases Original
            $State.Phase = 'VerifiedAfterUndo'
        }
        'FailureRecovery' {
            if ($State.Phase -ne 'Prepared') { throw 'Failure probe requires Prepared.' }
            Assert-SkyVmCaseStates $Cases Original
            $case = $Cases[0]
            $interrupted = $false
            try {
                Invoke-SkyVmFaultedWrite { Invoke-SkyTrackedChange -Resource $case.Resource -Desired $case.Desired -BackupDirectory $BackupDirectory } | Out-Null
            } catch {
                if ($_.Exception.Message -notlike '*SKY_VM_INJECTED_AFTER_WRITE*') { throw }
                $interrupted = $true
            }
            if (-not $interrupted -or -not (Test-SkyStateEqual (Get-SkyResourceState $case.Resource) $case.Desired)) { throw 'Apply fault boundary not reproduced.' }
            $journal = Read-SkyMutationState $BackupDirectory
            if (@($journal.Entries | Where-Object Status -eq 'Pending').Count -ne 1) { throw 'Pending intent not persisted.' }
            $null = Restore-SkyTrackedChanges $BackupDirectory
            Assert-SkyVmCaseStates $Cases Original
            $null = Invoke-SkyTrackedChange -Resource $case.Resource -Desired $case.Desired -BackupDirectory $BackupDirectory
            $results = @(Invoke-SkyVmFaultedWrite { Restore-SkyTrackedChanges $BackupDirectory })
            if (@($results | Where-Object Status -eq 'Failed').Count -ne 1) { throw 'Undo fault boundary not reproduced.' }
            if (-not (Test-SkyStateEqual (Get-SkyResourceState $case.Resource) $case.Original)) { throw 'Undo did not reach original state before the injected fault.' }
            $journal = Read-SkyMutationState $BackupDirectory
            if (@($journal.Entries | Where-Object Status -eq 'Restoring').Count -ne 1) { throw 'Restoring intent not preserved.' }
            $results = @(Restore-SkyTrackedChanges $BackupDirectory)
            if (@($results | Where-Object Status -eq 'Failed').Count) { throw 'Undo retry failed.' }
            Assert-SkyVmCaseStates $Cases Original
        }
        'BackupWriteFailure' {
            if ($State.Phase -ne 'Prepared') { throw 'Backup failure probe requires Prepared.' }
            Assert-SkyVmCaseStates $Cases Original
            $journal = Read-SkyMutationState $BackupDirectory
            Save-SkyMutationState $journal $BackupDirectory
            $path = Join-Path $BackupDirectory 'mutation_state.json'
            $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
            # Real file-sharing barrier: reads remain possible, but atomic replacement must fail.
            $held = [IO.File]::Open($path, 'Open', 'Read', 'Read')
            $blocked = $false
            try {
                try { $null = Invoke-SkyTrackedChange -Resource $Cases[0].Resource -Desired $Cases[0].Desired -BackupDirectory $BackupDirectory }
                catch {
                    if ($_.Exception.GetBaseException() -isnot [IO.IOException]) { throw }
                    $blocked = $true
                }
            } finally { $held.Dispose() }
            if (-not $blocked) { throw 'Locked journal did not prevent mutation.' }
            if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -cne $before) { throw 'Original journal changed after a failed intent write.' }
            Assert-SkyVmCaseStates $Cases Original
        }
        'ExternalConflict' {
            if ($State.Phase -ne 'Prepared') { throw 'Conflict probe requires Prepared.' }
            Assert-SkyVmCaseStates $Cases Original
            $case = $Cases[0]
            foreach ($candidate in $Cases) { $null = Invoke-SkyTrackedChange -Resource $candidate.Resource -Desired $candidate.Desired -BackupDirectory $BackupDirectory }
            $external = ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'external preference'
            Set-SkyResourceState $case.Resource $external
            $results = @(Restore-SkyTrackedChanges $BackupDirectory)
            if (@($results | Where-Object Status -eq 'Failed').Count -ne 1 -or
                -not (Test-SkyStateEqual (Get-SkyResourceState $case.Resource) $external)) { throw 'External conflict was not preserved.' }
            Assert-SkyVmCaseStates @($Cases | Select-Object -Skip 1) Original
            $State.Phase = 'ConflictObserved'
        }
        default { throw 'Unknown registry stage.' }
    }
}

function Write-SkyVmEvidence {
    param([string]$Directory, [string]$Stage, [bool]$Passed, $State, $Context, $Permission, [string]$ErrorMessage = '')
    $report = [pscustomobject]@{ Stage = $Stage; Passed = $Passed
        Phase = $(if ($State) { $State.Phase } else { 'Unavailable' }); BootId = $Context.BootId
        SourceSha256 = $Permission.SourceSha256; RunId = $Permission.RunId; Utc = [DateTime]::UtcNow.ToString('o')
        ErrorMessage = $ErrorMessage
        Scope = 'Registry fixture only; not full Apply, services, NIC, hardware or performance validation.' }
    Write-SkyAtomicFile (Join-Path $Directory ("evidence-$Stage-$([guid]::NewGuid().ToString('N')).json")) ($report | ConvertTo-Json)
    $report
}

function Invoke-SkyVmScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][ValidateSet('Prepare','Apply','VerifyAfterReboot','Undo','VerifyAfterUndo','FailureRecovery','BackupWriteFailure','ExternalConflict')][string]$Stage,
        [string]$SourcePath = (Join-Path $PSScriptRoot '..\SkyOptimizer.ps1'),
        [switch]$AllowSystemChanges
    )
    if (-not $AllowSystemChanges) { throw 'Explicit -AllowSystemChanges is required. No scenario executed.' }
    $manifestBytes = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ManifestPath).Path)
    $manifest = $manifestBytes | ConvertFrom-Json -ErrorAction Stop
    $context = Get-SkyVmContext
    $permission = Assert-SkyVmPermission $manifest $context $SourcePath -AllowSystemChanges:$AllowSystemChanges
    # Load declarations locally, never the application entry point/UAC/initializers.
    . (Get-SkyVmDeclarations $SourcePath)
    $directory = $permission.Directory
    $statePath = Join-Path $directory 'scenario_state.json'
    Assert-SkyVmLabPath $directory
    if ($Stage -eq 'Prepare' -and (Test-Path -LiteralPath $directory -ErrorAction Stop)) { throw 'Run directory already exists. Choose a fresh RunId or restore the snapshot.' }
    if ($Stage -ne 'Prepare' -and -not [IO.File]::Exists($statePath)) { throw 'Prepare this run first.' }
    $null = [IO.Directory]::CreateDirectory($directory)
    $lock = [IO.File]::Open((Join-Path $directory 'scenario.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $oldBackup = $Global:SkyBackupDir; $oldLog = $Global:SkyLogFile
    $state = $null
    try {
        $Global:SkyBackupDir = Join-Path $directory 'Backups'
        $Global:SkyLogFile = $null
        $null = [IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $cases = @(New-SkyVmRegistryCases $permission.RegistryPath)
        if ($Stage -eq 'Prepare') {
            if ([IO.File]::Exists($statePath) -or (Test-Path -LiteralPath $permission.RegistryPath -ErrorAction Stop)) { throw 'Run/fixture already exists. Do not overwrite evidence; restore snapshot or choose a fresh RunId.' }
            $state = [pscustomobject]@{ SchemaVersion = 1; RunId = $permission.RunId; SourceSha256 = $permission.SourceSha256
                MachineId = $context.MachineId; UserSid = $context.UserSid; Phase = 'Initializing'; ApplyBootId = ''; UndoBootId = '' }
            Write-SkyAtomicFile $statePath ($state | ConvertTo-Json)
            foreach ($case in $cases | Where-Object { $_.Original.Exists }) { Set-SkyResourceState $case.Resource $case.Original }
            Assert-SkyVmCaseStates $cases Original
            $state.Phase = 'Prepared'
        } else {
            $state = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json -ErrorAction Stop
            if ($state.SchemaVersion -ne 1 -or $state.RunId -ne $permission.RunId -or $state.SourceSha256 -ne $permission.SourceSha256 -or
                $state.MachineId -ne $context.MachineId -or $state.UserSid -ne $context.UserSid) { throw 'Scenario state belongs to another run/source/identity.' }
            Invoke-SkyVmRegistryStep -Stage $Stage -State $state -Cases $cases -BackupDirectory $Global:SkyBackupDir -BootId $context.BootId
        }
        Write-SkyAtomicFile $statePath ($state | ConvertTo-Json)
        Write-SkyVmEvidence $directory $Stage $true $state $context $permission
    } catch {
        $failure = $_
        try { $null = Write-SkyVmEvidence $directory $Stage $false $state $context $permission $failure.Exception.Message }
        catch { Write-Warning 'Failure evidence could not be persisted; preserve the transcript and original journal.' }
        throw $failure
    } finally {
        $Global:SkyBackupDir = $oldBackup; $Global:SkyLogFile = $oldLog
        $lock.Dispose()
    }
}
