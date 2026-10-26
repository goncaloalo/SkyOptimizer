. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Integrity repair never certifies success from exit codes alone' {
    BeforeEach {
        $script:confirmation = 'S'; $script:dismCode = 0; $script:sfcCode = 0
        $script:launchFails = $false
        $script:calls = @()
    }
    Mock Clear-Host { }
    Mock Start-Sleep { }
    Mock Write-SkyLog { }
    Mock Read-Host { $script:confirmation }
    Mock Invoke-SkyNativeProcess {
        $script:calls += $FileName
        if ($script:launchFails) { throw 'Launch denied' }
        $code = if ($FileName -eq 'dism.exe') { $script:dismCode } else { $script:sfcCode }
        [pscustomobject]@{ ExitCode = $code; Output = 'Localized diagnostic output, not a health certificate.' }
    }
    It 'runs nothing when cancelled' {
        $script:confirmation = 'N'
        (Repair-WindowsSystemIntegrity).Status | Should Be NotSelected
        $script:calls.Count | Should Be 0
    }
    It 'does not run SFC after DISM fails or omits its exit code' {
        foreach ($code in @($null, 5, 87)) {
            $script:dismCode = $code
            (Repair-WindowsSystemIntegrity).Status | Should Be Failed
        }
        @($script:calls | Where-Object { $_ -eq 'sfc.exe' }).Count | Should Be 0
    }
    It 'reports restart required and defers SFC after DISM returns 3010' {
        $script:dismCode = 3010
        $result = Repair-WindowsSystemIntegrity
        $result.Status | Should Be Unverified
        $result.RestartRequired | Should Be Yes
        ($script:calls -join ',') | Should Be 'dism.exe'
        Assert-MockCalled Invoke-SkyNativeProcess -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments -contains '/NoRestart' }
    }
    It 'reports a launch exception without proceeding' {
        $script:launchFails = $true
        (Repair-WindowsSystemIntegrity).Status | Should Be Failed
        ($script:calls -join ',') | Should Be 'dism.exe'
    }
    It 'reports nonzero or missing SFC exit codes as unconfirmed failures' {
        foreach ($code in @($null, 1, 5)) {
            $script:sfcCode = $code
            (Repair-WindowsSystemIntegrity).Status | Should Be Failed
        }
    }
    It 'requires diagnostic review even after both commands return zero' {
        $result = Repair-WindowsSystemIntegrity
        $result.Status | Should Be Unverified
        $result.Reason.Contains('CBS.log') | Should Be $true
        ($script:calls -join ',') | Should Be 'dism.exe,sfc.exe'
        Assert-MockCalled Write-SkyLog -Times 0 -Exactly -Scope It -ParameterFilter { $Level -eq 'Success' }
    }
}

Describe 'VBS observations distinguish configured, running and unknown' {
    BeforeEach { $script:state = 0; $script:missing = $false; $script:queryFails = $false }
    Mock Get-CimInstance {
        if ($script:queryFails) { throw 'Provider unavailable' }
        if ($script:missing) { return }
        [pscustomobject]@{ VirtualizationBasedSecurityStatus = $script:state }
    }
    Mock Get-ItemProperty { throw 'Registry configuration must not stand in for runtime evidence.' }
    It 'identifies only runtime status 2 as running' {
        $script:state = 2
        (Get-VbsStatus) | Should Be Ativado
        $script:state = 1
        (Get-VbsStatus) | Should Be 'Configurado, sem execucao'
    }
    It 'identifies explicit status 0 as disabled' {
        (Get-VbsStatus) | Should Be Desativado
    }
    It 'keeps missing, null and future status values unknown' {
        foreach ($state in @($null, 3, 99)) {
            $script:state = $state
            (Get-VbsStatus) | Should Be Desconhecido
        }
        $script:missing = $true
        (Get-VbsStatus) | Should Be Desconhecido
    }
    It 'does not translate provider failure into disabled security' {
        $script:queryFails = $true
        (Get-VbsStatus) | Should Be Desconhecido
        Assert-MockCalled Get-ItemProperty -Times 0 -Exactly -Scope It
    }
}
