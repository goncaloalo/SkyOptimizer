. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Documented software policies with conservative compatibility' {
    BeforeEach {
        $script:os = [pscustomobject]@{ Version='10.0.22631'; BuildNumber='22631'; ProductType=1; OperatingSystemSKU=48 }
        $script:queryFails = $false
        $Global:SkyLogFile = $null
    }
    Mock Get-CimInstance { if ($script:queryFails) { throw 'CIM unavailable' }; $script:os }
    Mock Get-SkyWindowsBuild { [int]$script:os.BuildNumber }
    Mock Set-SkyRegistryValue { New-SkyActionResult AlreadyCompliant 'mocked configured policy' }
    It 'checks each documented minimum build before any write' {
        foreach ($case in @(
            @{Name='Disable-TaskbarWidgets';Minimum=22000},
            @{Name='Enable-LongFilePaths';Minimum=14393},
            @{Name='Disable-StorageSenseBackgroundScans';Minimum=18362},
            @{Name='Disable-CloudClipboardSync';Minimum=17763}
        )) {
            $script:os.BuildNumber = [string]($case.Minimum - 1)
            (& $case.Name).Status | Should Be Incompatible
            $script:os.BuildNumber = [string]$case.Minimum
            (& $case.Name).Status | Should Be AlreadyCompliant
        }
        Assert-MockCalled Set-SkyRegistryValue -Times 4 -Exactly -Scope It
    }
    It 'allows known Home SKUs only for the native long-path feature' {
        foreach ($sku in @(98,99,100,101)) {
            $script:os.OperatingSystemSKU = $sku
            (Enable-LongFilePaths).Status | Should Be AlreadyCompliant
            (Disable-TaskbarWidgets).Status | Should Be Incompatible
            (Disable-StorageSenseBackgroundScans).Status | Should Be Incompatible
            (Disable-CloudClipboardSync).Status | Should Be Incompatible
        }
        Assert-MockCalled Set-SkyRegistryValue -Times 4 -Exactly -Scope It -ParameterFilter { $Name -eq 'LongPathsEnabled' }
    }
    It 'rejects Server, unknown editions and unavailable OS detection before writes' {
        $script:os.ProductType=3
        (Test-SkyClientPolicySupport) | Should Be $false
        $script:os.ProductType=1; $script:os.OperatingSystemSKU=999
        foreach ($name in @('Disable-TaskbarWidgets','Enable-LongFilePaths','Disable-StorageSenseBackgroundScans','Disable-CloudClipboardSync')) { (& $name).Status | Should Be Incompatible }
        $script:queryFails = $true
        foreach ($name in @('Disable-TaskbarWidgets','Enable-LongFilePaths','Disable-StorageSenseBackgroundScans','Disable-CloudClipboardSync')) { (Invoke-SkyAction { & $name }).Status | Should Be Failed }
        Assert-MockCalled Set-SkyRegistryValue -Times 0 -Exactly -Scope It
    }
    It 'requests validation after reboot for cached long-path state and preserves clipboard history' {
        (Enable-LongFilePaths).RestartRequired | Should Be Yes
        (Disable-CloudClipboardSync).RestartRequired | Should Be No
        Assert-MockCalled Set-SkyRegistryValue -Times 0 -Exactly -Scope It -ParameterFilter { $Name -eq 'AllowClipboardHistory' }
    }
    It 'keeps all four choices explicit and respects long-path support in the dispatcher' {
        foreach ($profile in @('Balanced','Performance')) {
            @((Get-SkyProfileActionIds $profile) | Where-Object { $_ -in @(16,59,88,90) }).Count | Should Be 0
        }
        foreach ($id in @(16,59,88,90)) { (Get-SkyMigratedActionIds) -contains $id | Should Be $true }
        $script:os.BuildNumber='14393'
        (Invoke-SkyEligibleAction -Id 59 -SelectedIds @(59) -Action { Enable-LongFilePaths }).Status | Should Be AlreadyCompliant
        (Invoke-SkyEligibleAction -Id 79 -SelectedIds @(79) -Action { throw 'unsupported Game Mode body' }).Status | Should Be Incompatible
    }
}
