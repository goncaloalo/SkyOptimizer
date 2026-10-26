. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
. (Join-Path $PSScriptRoot '..\integration\SkyVmHarness.ps1')

Describe 'Disposable VM guard without system mutations' {
    BeforeEach {
        $script:source = Join-Path $TestDrive 'product.ps1'
        [IO.File]::WriteAllText($script:source, 'function Placeholder { 42 }')
        $script:context = [pscustomobject]@{ MachineId = 'guest-machine'; UserSid = 'guest-user'; IsAdministrator = $true
            Manufacturer = 'Microsoft Corporation'; Model = 'Virtual Machine'; BootId = 'boot-1'; SystemDrive = 'C:' }
        $script:manifest = [pscustomobject]@{ SchemaVersion = 1; Acknowledgement = 'DISPOSABLE-VM-WITH-SNAPSHOT'; SnapshotReference = 'snapshot-001'
            RunId = '11111111-2222-3333-4444-555555555555'; MachineId = 'guest-machine'; UserSid = 'guest-user'
            SourceSha256 = (Get-FileHash -LiteralPath $script:source -Algorithm SHA256).Hash }
    }
    Mock Get-SkyVmContext { throw 'Guarded entry must not inspect or mutate Windows without opt-in.' }
    It 'refuses entry without explicit system-change opt-in before querying the machine' {
        { Invoke-SkyVmScenario -ManifestPath 'missing.json' -Stage Prepare } | Should Throw
        Assert-MockCalled Get-SkyVmContext -Times 0 -Exactly -Scope It
    }
    It 'accepts a matching explicit guest declaration and constructs only its fixed fixture paths' {
        $permission = Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges
        $permission.Directory | Should Be 'C:\SkyOptimizer-Lab\11111111222233334444555555555555'
        $permission.RegistryPath | Should Be 'HKCU:\Software\SkyOptimizerIntegration\11111111222233334444555555555555'
    }
    It 'rejects a physical Hyper-V host or unknown guest instead of trusting a hypervisor flag' {
        foreach ($model in @('Surface Laptop', 'Unknown VM')) {
            $script:context.Model = $model
            { Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges } | Should Throw
        }
    }
    It 'rejects mismatched identity, missing elevation and modified source' {
        $script:context.UserSid = 'another-user'
        { Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges } | Should Throw
        $script:context.UserSid = 'guest-user'; $script:context.MachineId = 'another-machine'
        { Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges } | Should Throw
        $script:context.MachineId = 'guest-machine'; $script:context.IsAdministrator = $false
        { Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges } | Should Throw
        $script:context.IsAdministrator = $true
        [IO.File]::WriteAllText($script:source, 'modified source')
        { Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges } | Should Throw
    }
    It 'rejects absent snapshot acknowledgement and RunId traversal' {
        $script:manifest.RunId = '..\outside'
        { Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges } | Should Throw
        $script:manifest.RunId = '11111111-2222-3333-4444-555555555555'; $script:manifest.Acknowledgement = 'example'
        { Assert-SkyVmPermission $script:manifest $script:context $script:source -AllowSystemChanges } | Should Throw
    }
    It 'loads only function declarations and omits application entry points' {
        [IO.File]::WriteAllText($script:source, "throw 'Entry point forbidden'`r`nfunction Test-SkyVmDeclarationFixture { 'declaration' }")
        . (Get-SkyVmDeclarations $script:source)
        (Test-SkyVmDeclarationFixture) | Should Be declaration
    }
    It 'rejects files where a lab directory is required' {
        $folder = Join-Path $TestDrive 'lab'
        $null = [IO.Directory]::CreateDirectory($folder)
        $run = Join-Path $folder 'run'
        [IO.File]::WriteAllText($run, 'must not overwrite')
        { Assert-SkyVmLabPath $run } | Should Throw
        [IO.File]::ReadAllText($run) | Should Be 'must not overwrite'
    }
}

Describe 'VM scenario transitions using mocked Windows resources only' {
    BeforeEach {
        $Global:SkyBackupDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $script:values = @{}; $script:writes = 0
        $script:cases = @(New-SkyVmRegistryCases 'HKCU:\Software\SkyOptimizerIntegration\fixture')
        foreach ($case in $script:cases) { $script:values[($case.Resource | ConvertTo-Json -Compress)] = $case.Original }
        $script:state = [pscustomobject]@{ Phase = 'Prepared'; ApplyBootId = ''; UndoBootId = '' }
    }
    Mock Get-SkyMachineId { 'mock-machine' }
    Mock Get-SkyUserSid { 'mock-user' }
    Mock Open-SkyRegistryBase { throw 'Real registry access forbidden.' }
    Mock Invoke-SkyNativeProcess { throw 'Native processes forbidden.' }
    Mock Get-SkyResourceState {
        $key = $Resource | ConvertTo-Json -Compress
        if ($script:values.ContainsKey($key)) { return $script:values[$key] }
        ConvertTo-SkyRegistryState -Exists $false
    }
    Mock Set-SkyResourceState { $script:writes++; $script:values[($Resource | ConvertTo-Json -Compress)] = $State }
    Mock Get-SkyVmContext { $script:vmContext }
    Mock Get-SkyVmDeclarations { [scriptblock]::Create('') }
    Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like 'HKCU:\Software\SkyOptimizerIntegration\*' }
    It 'checks repeated Apply, distinct boot, exact Undo and a second boot without owning the untouched value' {
        Invoke-SkyVmRegistryStep Apply $script:state $script:cases $Global:SkyBackupDir 'boot-A'
        Invoke-SkyVmRegistryStep Apply $script:state $script:cases $Global:SkyBackupDir 'boot-A'
        $script:writes | Should Be 6
        { Invoke-SkyVmRegistryStep VerifyAfterReboot $script:state $script:cases $Global:SkyBackupDir 'boot-A' } | Should Throw
        Invoke-SkyVmRegistryStep VerifyAfterReboot $script:state $script:cases $Global:SkyBackupDir 'boot-B'
        Invoke-SkyVmRegistryStep Undo $script:state $script:cases $Global:SkyBackupDir 'boot-B'
        Invoke-SkyVmRegistryStep Undo $script:state $script:cases $Global:SkyBackupDir 'boot-B'
        $script:writes | Should Be 12
        { Invoke-SkyVmRegistryStep VerifyAfterUndo $script:state $script:cases $Global:SkyBackupDir 'boot-B' } | Should Throw
        Invoke-SkyVmRegistryStep VerifyAfterUndo $script:state $script:cases $Global:SkyBackupDir 'boot-C'
        $script:state.Phase | Should Be VerifiedAfterUndo
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 6
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries | Where-Object { $_.Resource.Name -eq 'Untouched' }).Count | Should Be 0
    }
    It 'exercises after-write faults in Apply and Undo and leaves a retryable baseline' {
        Invoke-SkyVmRegistryStep FailureRecovery $script:state $script:cases $Global:SkyBackupDir 'boot-A'
        $script:state.Phase | Should Be Prepared
        Assert-SkyVmCaseStates $script:cases Original
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries | Where-Object { $_.Status -ne 'Restored' }).Count | Should Be 0
        $script:writes | Should Be 4
    }
    It 'confirms an expected external conflict and preserves that external value for review' {
        Invoke-SkyVmRegistryStep ExternalConflict $script:state $script:cases $Global:SkyBackupDir 'boot-A'
        $script:state.Phase | Should Be ConflictObserved
        (Get-SkyResourceState $script:cases[0].Resource).Data | Should Be 'external preference'
        $script:writes | Should Be 2
    }
    It 'refuses invalid stage order before making a change' {
        { Invoke-SkyVmRegistryStep Undo $script:state $script:cases $Global:SkyBackupDir 'boot-A' } | Should Throw
        { Invoke-SkyVmRegistryStep VerifyAfterReboot $script:state $script:cases $Global:SkyBackupDir 'boot-B' } | Should Throw
        $script:writes | Should Be 0
    }
    It 'persists scenario reports and restores caller globals across separate invocations with mocked registry access' {
        $script:values = @{}
        $script:vmContext = [pscustomobject]@{ MachineId = 'mock-machine'; UserSid = 'mock-user'; IsAdministrator = $true
            Manufacturer = 'Microsoft Corporation'; Model = 'Virtual Machine'; BootId = 'boot-A'; SystemDrive = $TestDrive }
        $source = Join-Path $TestDrive 'mock-product.ps1'
        [IO.File]::WriteAllText($source, '# declarations mocked; never execute a product entry point')
        $runId = [guid]::NewGuid().ToString()
        $manifest = [pscustomobject]@{ SchemaVersion = 1; Acknowledgement = 'DISPOSABLE-VM-WITH-SNAPSHOT'; SnapshotReference = 'unit-test-only'
            RunId = $runId; MachineId = 'mock-machine'; UserSid = 'mock-user'; SourceSha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash }
        $manifestPath = Join-Path $TestDrive 'guest.json'
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json))
        $callerBackup = $Global:SkyBackupDir
        (Invoke-SkyVmScenario $manifestPath Prepare -SourcePath $source -AllowSystemChanges).Passed | Should Be $true
        { Invoke-SkyVmScenario $manifestPath Prepare -SourcePath $source -AllowSystemChanges } | Should Throw
        (Invoke-SkyVmScenario $manifestPath Apply -SourcePath $source -AllowSystemChanges).Phase | Should Be Applied
        $script:vmContext.BootId = 'boot-B'
        (Invoke-SkyVmScenario $manifestPath VerifyAfterReboot -SourcePath $source -AllowSystemChanges).Phase | Should Be VerifiedAfterReboot
        (Invoke-SkyVmScenario $manifestPath Undo -SourcePath $source -AllowSystemChanges).Phase | Should Be Restored
        $script:vmContext.BootId = 'boot-C'
        (Invoke-SkyVmScenario $manifestPath VerifyAfterUndo -SourcePath $source -AllowSystemChanges).Phase | Should Be VerifiedAfterUndo
        $Global:SkyBackupDir | Should Be $callerBackup
        $lab = Join-Path (Join-Path $TestDrive 'SkyOptimizer-Lab') ([guid]$runId).ToString('N')
        @(Get-ChildItem -LiteralPath $lab -Filter 'evidence-*.json').Count | Should Be 5
        ([IO.File]::ReadAllText((Join-Path $lab 'scenario_state.json')) | ConvertFrom-Json).Phase | Should Be VerifiedAfterUndo
        Assert-MockCalled Open-SkyRegistryBase -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
}
