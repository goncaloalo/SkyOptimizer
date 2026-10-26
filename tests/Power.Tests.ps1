. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
$script:realSavePowerState = (Get-Command Save-SkyPowerState).ScriptBlock

# In-memory Windows model. These tests never call powercfg, registry APIs or Add-Type.
function Invoke-FakePowerProcess {
    param($FileName, $Arguments)
    if ($FileName -ne 'powercfg.exe') { throw "Unexpected native process: $FileName" }
    $command = $Arguments[0]
    $script:fake.Calls += ($Arguments -join ' ')
    if ($script:fake.FailCommand -eq $command) {
        return [pscustomobject]@{ ExitCode = 5; Output = 'Simulated native failure' }
    }
    $output = ''
    switch ($command) {
        '/getactivescheme' { $output = "Plano de energia: $($script:fake.Active) (Nome livre)" }
        '/list' { $output = $script:fake.Plans.Keys -join "`n" }
        '/duplicatescheme' {
            $saved = [IO.File]::ReadAllText((Join-Path $Global:SkyBackupDir 'power_state.json')) | ConvertFrom-Json
            if ($saved.OriginalGuid -ne $script:original -or $saved.OwnedGuid -ne $Arguments[2]) {
                throw 'Baseline must be persisted before duplication.'
            }
            if ($script:fake.Plans.ContainsKey($Arguments[2])) { throw 'Duplicate destination already exists.' }
            $copy = @{}
            foreach ($key in $script:fake.Plans[$Arguments[1]].Keys) {
                $value = $script:fake.Plans[$Arguments[1]][$key]
                $copy[$key] = [pscustomobject]@{ AC = $value.AC; DC = $value.DC }
            }
            $script:fake.Plans[$Arguments[2]] = $copy
        }
        '/changename' { }
        '/setactive' {
            if (-not $script:fake.Plans.ContainsKey($Arguments[1])) { throw 'Missing plan.' }
            if (-not $script:fake.IgnoreActivation) { $script:fake.Active = $Arguments[1] }
        }
        '/delete' { $script:fake.Plans.Remove($Arguments[1]) }
        '/setacvalueindex' {
            if ($script:fake.FailSetting -eq $Arguments[3]) {
                return [pscustomobject]@{ ExitCode = 5; Output = 'Simulated partial failure' }
            }
            if (-not $script:fake.IgnoreWrite) {
                $script:fake.Plans[$Arguments[1]][$Arguments[3]].AC = [int]$Arguments[4]
            }
        }
        default { throw "Unmocked power operation: $command" }
    }
    [pscustomobject]@{ ExitCode = 0; Output = $output }
}

Describe 'Owned power plan lifecycle' {
    BeforeEach {
        $Global:SkyBackupDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $Global:SkyManifest = [ordered]@{ PowerPlan = $null }
        $Global:SkyLogFile = $null
        $script:original = '11111111-2222-3333-4444-555555555555'
        $script:minimum = '0cc5b647-c1df-4637-891a-dec75c318583'
        $script:maximum = 'ea062031-0e34-4ff1-9b6d-eb1059324028'
        $script:fake = @{ Active = $script:original; Plans = @{}; Calls = @(); FailCommand = ''; FailSave = ''; MachineId = 'test-machine-guid'; IgnoreActivation = $false; IgnoreWrite = $false }
        $script:fake.Plans[$script:original] = @{
            $script:minimum = [pscustomobject]@{ AC = 23; DC = 14 }
            $script:maximum = [pscustomobject]@{ AC = 91; DC = 77 }
            '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' = [pscustomobject]@{ AC = 1; DC = 1 }
        }
    }
    Mock Invoke-SkyNativeProcess { Invoke-FakePowerProcess -FileName $FileName -Arguments $Arguments }
    Mock Get-SkyMachineId { $script:fake.MachineId }
    Mock Test-IsOnBattery { $false }
    Mock Test-IsDesktopOrAcPower { $true }
    Mock Get-ItemProperty { throw 'Unexpected registry access in power tests.' }
    Mock Save-SkyPowerState {
        if ($script:fake.FailSave -eq $State.Status) { throw 'Disk full' }
        & $script:realSavePowerState -BackupDirectory $BackupDirectory -State $State
    }
    Mock Get-SkyPowerSetting {
        if ($script:fake.UnsupportedSetting -eq $SettingGuid.ToString()) { throw (New-Object ComponentModel.Win32Exception(2)) }
        $value = $script:fake.Plans[$PlanGuid.ToString()][$SettingGuid.ToString()]
        if (-not $value) { throw 'Unsupported setting' }
        [pscustomobject]@{ AC = $value.AC; DC = $value.DC }
    }

    It 'parses the GUID independently of localized plan names and automatic matches' {
        $text = "Energieplan: $script:original (Leistung)"
        $null = 'unrelated' -match 'unrelated'
        (Get-SkyPowerGuid -Text $text) | Should Be $script:original
    }
    It 'rejects ambiguous active-plan output' {
        { Get-SkyPowerGuid -Text "$script:original $script:original" } | Should Throw
    }
    It 'persists the baseline before mutation and reuses the owned GUID on Apply Apply Undo' {
        (Set-UltimatePowerPlan).Status | Should Be 'Applied'
        $first = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        (Disable-CoreParking).Status | Should Be 'Applied'
        (Set-UltimatePowerPlan).Status | Should Be 'AlreadyCompliant'
        (Disable-CoreParking).Status | Should Be 'AlreadyCompliant'
        $second = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        $second.OriginalGuid | Should Be $script:original
        $second.OwnedGuid | Should Be $first.OwnedGuid
        @($script:fake.Calls | Where-Object { $_ -like '/duplicatescheme *' }).Count | Should Be 1
        $script:fake.Plans[$first.OwnedGuid][$script:minimum].DC | Should Be 14
        $script:fake.Plans[$first.OwnedGuid][$script:maximum].DC | Should Be 77
        (Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Applied'
        $script:fake.Active | Should Be $script:original
        $script:fake.Plans.Count | Should Be 1
        $script:fake.Plans[$script:original][$script:minimum].AC | Should Be 23
        $script:fake.Plans[$script:original][$script:maximum].AC | Should Be 91
        $script:fake.Plans[$script:original][$script:minimum].DC | Should Be 14
        (Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'AlreadyCompliant'
    }
    It 'never writes DC indices or global setting attributes' {
        $null = Set-UltimatePowerPlan
        $null = Disable-CoreParking
        @($script:fake.Calls | Where-Object { $_ -match '/setdcvalueindex|/attributes' }).Count | Should Be 0
    }
    It 'blocks configuration without an active owned plan' {
        { Disable-CoreParking } | Should Throw
        $script:fake.Plans[$script:original][$script:minimum].AC | Should Be 23
    }
    It 'detects a successful native command that did not change the setting' {
        $null = Set-UltimatePowerPlan
        $script:fake.IgnoreWrite = $true
        { Disable-CoreParking } | Should Throw
    }
    It 'detects a successful activation command that did not activate the plan' {
        $script:fake.IgnoreActivation = $true
        { Set-UltimatePowerPlan } | Should Throw
        (Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Prepared'
    }
    It 'recovers after duplication succeeded but activation failed' {
        $script:fake.FailCommand = '/setactive'
        { Set-UltimatePowerPlan } | Should Throw
        $script:fake.FailCommand = ''
        (Set-UltimatePowerPlan).Status | Should Be 'Applied'
        @($script:fake.Calls | Where-Object { $_ -like '/duplicatescheme *' }).Count | Should Be 1
        (Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Applied'
    }
    It 'can undo an interrupted Prepared transaction without activating the owned plan' {
        $script:fake.FailCommand = '/changename'
        { Set-UltimatePowerPlan } | Should Throw
        $script:fake.FailCommand = ''
        (Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Applied'
        $script:fake.Active | Should Be $script:original
        $script:fake.Plans.Count | Should Be 1
    }
    It 'recovers from a crash between activation and the final journal write' {
        $script:fake.FailSave = 'Active'
        { Set-UltimatePowerPlan } | Should Throw
        $prepared = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        $prepared.Status | Should Be 'Prepared'
        $script:fake.Active | Should Be $prepared.OwnedGuid
        $script:fake.FailSave = ''
        (Set-UltimatePowerPlan).Status | Should Be 'Applied'
        @($script:fake.Calls | Where-Object { $_ -like '/duplicatescheme *' }).Count | Should Be 1
        $null = Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir
        $script:fake.Active | Should Be $script:original
    }
    It 'restores the original after an intermediate setting write fails' {
        $null = Set-UltimatePowerPlan
        $state = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        $script:fake.FailSetting = $script:maximum
        { Disable-CoreParking } | Should Throw
        $script:fake.Plans[$state.OwnedGuid][$script:minimum].AC | Should Be 100
        $null = Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir
        $script:fake.Plans[$script:original][$script:minimum].AC | Should Be 23
        $script:fake.Plans[$script:original][$script:maximum].AC | Should Be 91
    }
    It 'classifies an unsupported setting without changing any index' {
        $null = Set-UltimatePowerPlan
        $script:fake.UnsupportedSetting = $script:maximum
        (Disable-CoreParking).Status | Should Be 'Incompatible'
        @($script:fake.Calls | Where-Object { $_ -like '/setacvalueindex *' }).Count | Should Be 0
    }
    It 'does not enter device writes when selective suspend is unsupported' {
        $null = Set-UltimatePowerPlan
        $script:fake.UnsupportedSetting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        (Disable-USBSelectiveSuspend).Status | Should Be 'Incompatible'
        Assert-MockCalled Get-ItemProperty -Times 0 -Exactly -Scope It
    }
    It 'changes only USB AC on the owned copy and restores the original after repetition' {
        $null = Set-UltimatePowerPlan
        $state = Read-SkyPowerState $Global:SkyBackupDir
        $usb = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        (Disable-USBSelectiveSuspend).Status | Should Be Applied
        (Disable-USBSelectiveSuspend).Status | Should Be AlreadyCompliant
        $script:fake.Plans[$state.OwnedGuid][$usb].AC | Should Be 0
        $script:fake.Plans[$state.OwnedGuid][$usb].DC | Should Be 1
        $script:fake.Plans[$script:original][$usb].AC | Should Be 1
        $null = Restore-SkyPowerPlan $Global:SkyBackupDir
        $script:fake.Active | Should Be $script:original
        $script:fake.Plans[$script:original][$usb].AC | Should Be 1
        $script:fake.Plans[$script:original][$usb].DC | Should Be 1
        Assert-MockCalled Get-ItemProperty -Times 0 -Exactly -Scope It
    }
    It 'does not mutate Windows if persisting the baseline fails' {
        $script:fake.FailSave = 'Prepared'
        { Set-UltimatePowerPlan } | Should Throw
        @($script:fake.Calls | Where-Object { $_ -notmatch '^/(list|getactivescheme)$' }).Count | Should Be 0
    }
    It 'rejects malformed baseline JSON without making a native call' {
        [IO.File]::WriteAllText((Join-Path $Global:SkyBackupDir 'power_state.json'), '{broken')
        { Set-UltimatePowerPlan } | Should Throw
        $script:fake.Calls.Count | Should Be 0
    }
    It 'rejects a baseline from another machine' {
        $null = Set-UltimatePowerPlan
        $script:fake.MachineId = 'another-machine'
        $script:fake.Calls = @()
        { Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir } | Should Throw
        $script:fake.Calls.Count | Should Be 0
    }
    It 'preserves an external choice of active plan' {
        $null = Set-UltimatePowerPlan
        $third = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $script:fake.Plans[$third] = @{}
        $script:fake.Active = $third
        { Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir } | Should Throw
        { Set-UltimatePowerPlan } | Should Throw
        $script:fake.Active | Should Be $third
    }
    It 'refuses to choose a default when the original plan disappeared' {
        $null = Set-UltimatePowerPlan
        $script:fake.Plans.Remove($script:original)
        { Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir } | Should Throw
        (Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Active'
    }
    It 'preserves retry information when deleting the owned plan fails' {
        $null = Set-UltimatePowerPlan
        $script:fake.FailCommand = '/delete'
        { Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir } | Should Throw
        $script:fake.Active | Should Be $script:original
        (Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Active'
        $script:fake.FailCommand = ''
        (Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Applied'
    }
    It 'allows a new cycle after completed Undo' {
        $null = Set-UltimatePowerPlan
        $first = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        $null = Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir
        (Set-UltimatePowerPlan).Status | Should Be 'Applied'
        (Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir).OwnedGuid | Should Not Be $first.OwnedGuid
    }
    It 'does nothing on Undo without any baseline' {
        (Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'AlreadyCompliant'
        $script:fake.Calls.Count | Should Be 0
        (Get-SkyUndoScope -BackupDirectory $Global:SkyBackupDir) | Should Be 'None'
    }
    It 'blocks legacy baseline overwrite and never changes a plan from incomplete evidence' {
        $path = Join-Path $Global:SkyBackupDir 'previous_power_plan.txt'
        [IO.File]::WriteAllText($path, $script:original)
        { Set-UltimatePowerPlan } | Should Throw
        $script:fake.Calls = @()
        (Restore-SkyPowerPlan -BackupDirectory $Global:SkyBackupDir).Status | Should Be 'Unverified'
        [IO.File]::ReadAllText($path) | Should Be $script:original
        @($script:fake.Calls | Where-Object { $_ -match '/setacvalueindex|/setdcvalueindex|/delete ' }).Count | Should Be 0
        $script:fake.Calls.Count | Should Be 0
    }
    It 'rejects concurrent access to the power transaction' {
        $held = Enter-SkyPowerLock -BackupDirectory $Global:SkyBackupDir
        try { { Set-UltimatePowerPlan } | Should Throw }
        finally { $held.Dispose() }
        $script:fake.Calls.Count | Should Be 0
    }
    It 'reads all capabilities before changing any index' {
        $null = Set-UltimatePowerPlan
        $state = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        $script:fake.Plans[$state.OwnedGuid].Remove($script:maximum)
        { Disable-CoreParking } | Should Throw
        $script:fake.Plans[$state.OwnedGuid][$script:minimum].AC | Should Be 23
    }
}

Describe 'Standalone panel parity' {
    It 'embeds the same restoration functions and parses without errors' {
        $source = Get-SkyPowerRestoreSource
        $tokens = $null; $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
        $errors.Count | Should Be 0
        $source.Contains((Get-Command Restore-SkyPowerPlan).Definition) | Should Be $true
        $source.Contains((Get-Command Read-SkyPowerState).Definition) | Should Be $true
    }
    It 'parses the complete generated Undo after shared functions are inserted' {
        $tokens = $null; $errors = $null
        $path = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\SkyOptimizer.ps1')).Path
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
        $template = $ast.FindAll({ param($node)
            $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $node.Value.Contains('# SKY_POWER_RESTORE_FUNCTIONS')
        }, $true) | Where-Object { $_.Value.Contains('$backupDir = Join-Path $PSScriptRoot') } | Select-Object -First 1
        ($null -ne $template) | Should Be $true
        $generated = $template.Value.Replace('# SKY_POWER_RESTORE_FUNCTIONS', (Get-SkyPowerRestoreSource))
        $null = [System.Management.Automation.Language.Parser]::ParseInput($generated, [ref]$tokens, [ref]$errors)
        $errors.Count | Should Be 0
        $generated.Contains('# SKY_POWER_RESTORE_FUNCTIONS') | Should Be $false
    }
}

Describe 'Undo entry guard' {
    BeforeEach {
        $Global:SkyBackupDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($Global:SkyBackupDir)
    }
    Mock Write-SkyLog { }
    Mock Read-Host { throw 'The legacy path must not be reached without backup evidence.' }
    Mock Invoke-SkyNativeProcess { throw 'No Windows process is allowed in this test.' }
    It 'returns before confirmation or system operations when no backups exist' {
        { Invoke-SkyUndo } | Should Not Throw
        Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
    It 'does not mistake execution reports and lock files for an original baseline' {
        [IO.File]::WriteAllText((Join-Path $Global:SkyBackupDir 'execution_results.json'), '[]')
        [IO.File]::WriteAllText((Join-Path $Global:SkyBackupDir 'power_state.lock'), '')
        { Invoke-SkyUndo } | Should Not Throw
        Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
    }
}
