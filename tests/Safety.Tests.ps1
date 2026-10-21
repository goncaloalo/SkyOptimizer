. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Checked native commands' {
    Mock Invoke-SkyNativeProcess { throw 'A native process must be mocked in every test.' }
    It 'rejects a nonzero exit code even with success-like output' {
        Mock Invoke-SkyNativeProcess { [pscustomobject]@{ ExitCode = 5; Output = 'success' } }
        { Invoke-SkyNativeCommand -FileName reg.exe -Arguments @('export') } | Should Throw
    }
    It 'rejects a missing exit code' {
        Mock Invoke-SkyNativeProcess { [pscustomobject]@{ ExitCode = $null; Output = '' } }
        { Invoke-SkyNativeCommand -FileName reg.exe -Arguments @('export') } | Should Throw
    }
    It 'returns output only after a zero exit code' {
        Mock Invoke-SkyNativeProcess { [pscustomobject]@{ ExitCode = 0; Output = 'checked' } }
        (Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/list')) | Should Be 'checked'
    }
}

Describe 'Action reporting' {
    BeforeEach { $Global:SkyLogFile = $null; $script:SkyActionContext = $null }
    It 'does not count legacy true as verified success' {
        (Invoke-SkyAction -Action { $true }).Status | Should Be 'Unverified'
    }
    It 'does not count legacy false as success or invent an incompatibility reason' {
        (Invoke-SkyAction -Action { $false }).Status | Should Be 'Unverified'
    }
    It 'does not count missing output as success' {
        (Invoke-SkyAction -Action {}).Status | Should Be 'Unverified'
    }
    It 'reports exceptions as failures' {
        $result = Invoke-SkyAction -Action { throw 'write denied' }
        $result.Status | Should Be 'Failed'
        $result.Reason | Should Be 'write denied'
    }
    It 'reports a nonterminating error as failure' {
        (Invoke-SkyAction -Action { Write-Error 'write denied' }).Status | Should Be 'Failed'
    }
    It 'rejects a claimed success when the action logged an error' {
        $result = Invoke-SkyAction -Action {
            Write-SkyLog -Message 'failure' -Level Error -NoConsole
            New-SkyActionResult -Status Applied -Reason 'incorrect claim'
        }
        $result.Status | Should Be 'Failed'
    }
    It 'preserves structured verification and reboot requirements' {
        $result = Invoke-SkyAction -Action {
            New-SkyActionResult -Status AlreadyCompliant -Reason 'state checked' -RestartRequired No
        }
        $result.Status | Should Be 'AlreadyCompliant'
        $result.RestartRequired | Should Be 'No'
    }
    It 'restores caller logging context after failure' {
        $script:SkyActionContext = @{ ErrorLogged = $false; Marker = 42 }
        $null = Invoke-SkyAction -Action { throw 'failed' }
        $script:SkyActionContext.Marker | Should Be 42
        $script:SkyActionContext = $null
    }
}

Describe 'Atomic files and registry export barriers' {
    BeforeEach {
        $Global:SkyBackupDir = $TestDrive
        $Global:SkyPermBackupDir = $TestDrive
        $Global:SkyLogFile = $null
    }
    Mock Invoke-SkyNativeProcess { throw 'A native process must be mocked in every test.' }
    Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like 'HKCU:\*' }
    It 'atomically creates and replaces UTF-8 content' {
        $path = Join-Path $TestDrive 'state.json'
        Write-SkyAtomicFile -Path $path -Content '{"estado":"inicial"}'
        Write-SkyAtomicFile -Path $path -Content '{"estado":"verificado"}'
        ([IO.File]::ReadAllText($path) | ConvertFrom-Json).estado | Should Be 'verificado'
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.tmp').Count | Should Be 0
    }
    It 'stops the action after an export failure and removes a partial export' {
        Mock Invoke-SkyNativeProcess {
            [IO.File]::WriteAllText($Arguments[2], 'partial')
            [pscustomobject]@{ ExitCode = 5; Output = 'Access denied' }
        }
        $script:writeReached = $false
        $result = Invoke-SkyAction -Action {
            Backup-RegistryKey -KeyPath 'HKCU:\Software\SkyTest' -BackupName 'failure'
            $script:writeReached = $true
        }
        $result.Status | Should Be 'Failed'
        $script:writeReached | Should Be $false
        Test-Path -LiteralPath (Join-Path $TestDrive 'failure.reg') | Should Be $false
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.tmp').Count | Should Be 0
    }
    It 'rejects a success exit code without an exported file' {
        Mock Invoke-SkyNativeProcess { [pscustomobject]@{ ExitCode = 0; Output = '' } }
        { Backup-RegistryKey -KeyPath 'HKCU:\Software\SkyTest' -BackupName 'missing' } | Should Throw
    }
    It 'preserves the first export across repeated applications' {
        Mock Invoke-SkyNativeProcess {
            [IO.File]::WriteAllText($Arguments[2], 'original baseline')
            [pscustomobject]@{ ExitCode = 0; Output = '' }
        }
        Backup-RegistryKey -KeyPath 'HKCU:\Software\SkyTest' -BackupName 'repeated'
        Mock Invoke-SkyNativeProcess { throw 'Must not overwrite a baseline.' }
        Backup-RegistryKey -KeyPath 'HKCU:\Software\SkyTest' -BackupName 'repeated'
        [IO.File]::ReadAllText((Join-Path $TestDrive 'repeated.reg')) | Should Be 'original baseline'
    }
    It 'refuses to overwrite an existing empty backup' {
        [IO.File]::WriteAllText((Join-Path $TestDrive 'empty.reg'), '')
        { Backup-RegistryKey -KeyPath 'HKCU:\Software\SkyTest' -BackupName 'empty' } | Should Throw
    }
}
