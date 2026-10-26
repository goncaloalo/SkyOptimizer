. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Update policy compatibility without Windows mutations' {
    BeforeEach {
        $script:os = [pscustomobject]@{ Version = '10.0.22631'; BuildNumber = '22631'; ProductType = 1; OperatingSystemSKU = 48 }
        $script:queryFailure = $false
        $Global:SkyLogFile = $null
    }
    Mock Get-CimInstance { if ($script:queryFailure) { throw 'CIM unavailable' }; $script:os }
    Mock Set-SkyRegistryValue { throw 'No registry writes permitted in capability tests.' }
    It 'accepts only enumerated client editions on supported builds' {
        foreach ($sku in @(4,27,48,49,121,122,125,126)) {
            $script:os.OperatingSystemSKU = $sku
            (Test-SkyUpdatePolicySupport) | Should Be $true
        }
        $script:os.BuildNumber = '15063'
        (Test-SkyUpdatePolicySupport) | Should Be $true
    }
    It 'does not write either policy on Home, unknown editions or Server' {
        foreach ($sku in @(101, 999)) {
            $script:os.OperatingSystemSKU = $sku
            (Block-AutomaticDriverUpdates).Status | Should Be Incompatible
            (Disable-DeliveryOptimizationP2P).Status | Should Be Incompatible
            (Disable-BackgroundUWPApps).Status | Should Be Incompatible
        }
        $script:os.OperatingSystemSKU = 48; $script:os.ProductType = 3
        (Block-AutomaticDriverUpdates).Status | Should Be Incompatible
        (Disable-DeliveryOptimizationP2P).Status | Should Be Incompatible
        Assert-MockCalled Set-SkyRegistryValue -Times 0 -Exactly -Scope It
    }
    It 'rejects old or unknown builds, another OS version and missing data' {
        foreach ($build in @('14393', 'unknown', '')) {
            $script:os.BuildNumber = $build
            (Test-SkyUpdatePolicySupport) | Should Be $false
        }
        $script:os.BuildNumber = '22631'; $script:os.Version = '11.0.1'
        (Test-SkyUpdatePolicySupport) | Should Be $false
        $script:os = $null
        (Test-SkyUpdatePolicySupport) | Should Be $false
    }
    It 'reports capability query failures and never treats them as applied' {
        $script:queryFailure = $true
        (Invoke-SkyAction { Block-AutomaticDriverUpdates }).Status | Should Be Failed
        (Invoke-SkyAction { Disable-DeliveryOptimizationP2P }).Status | Should Be Failed
        Assert-MockCalled Set-SkyRegistryValue -Times 0 -Exactly -Scope It
    }
    It 'keeps both policies opt-in and out of Balanced and Performance' {
        foreach ($profile in @('Balanced', 'Performance')) {
            @((Get-SkyProfileActionIds $profile) | Where-Object { $_ -in @(19,20) }).Count | Should Be 0
        }
        (@(Get-SkyProfileActionIds Extreme -Experiments @(19,20)) -join ',') | Should Be '9,19,20,41,79'
        foreach ($id in @(19,20)) { (Get-SkyMigratedActionIds) -contains $id | Should Be $true }
    }
}
