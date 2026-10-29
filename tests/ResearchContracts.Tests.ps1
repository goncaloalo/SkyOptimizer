. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Research capture contract with no host writes' {
    BeforeEach {
        $script:os=[pscustomobject]@{Version='10.0.19045';BuildNumber='19045';ProductType=1;OperatingSystemSKU=48}
    }
    Mock Get-CimInstance { $script:os }
    Mock Set-SkyRegistryValue { New-SkyActionResult -Status Applied -Reason 'fixture' }
    Mock Write-SkyLog {}
    It 'refuses Windows 11 before any registry mutation' {
        $script:os.BuildNumber='22631'
        (Disable-GameDVR).Status | Should Be Incompatible
        Assert-MockCalled Set-SkyRegistryValue -Times 0 -Exactly -Scope It
    }
    It 'refuses unknown builds, Home and Server' {
        foreach($build in @('unknown','0')) {
            $script:os.BuildNumber=$build
            (Disable-GameDVR).Status | Should Be Incompatible
        }
        $script:os.BuildNumber='19045';$script:os.OperatingSystemSKU=101
        (Disable-GameDVR).Status | Should Be Incompatible
        $script:os.OperatingSystemSKU=48;$script:os.ProductType=3
        (Disable-GameDVR).Status | Should Be Incompatible
        Assert-MockCalled Set-SkyRegistryValue -Times 0 -Exactly -Scope It
    }
    It 'retains the five tracked writes for the declared Win10 client contract' {
        $null=Disable-GameDVR
        Assert-MockCalled Set-SkyRegistryValue -Times 5 -Exactly -Scope It
    }
}

Describe 'Suspended groups cannot mutate even when directly invoked' {
    Mock Disable-SkyService { throw 'No service mutations allowed' }
    Mock Set-SkyRegistryValue { throw 'No registry mutations allowed' }
    Mock Remove-AppxPackage { throw 'No package removal allowed' }
    Mock Remove-AppxProvisionedPackage { throw 'No provisioning removal allowed' }
    It 'refuses 48, 71 and 49 at both action and dispatcher boundaries' {
        (Disable-TelemetryServicesDeep).Status | Should Be Deferred
        (Disable-SilentDiagnosticServices).Status | Should Be Deferred
        (Remove-BloatwareAppX).Status | Should Be Deferred
        foreach($id in @(48,49,71)) {
            (Invoke-SkyEligibleAction -Id $id -SelectedIds @($id) -Action {throw 'Body must stay blocked'}).Status | Should Be Deferred
        }
        Assert-MockCalled Disable-SkyService -Times 0 -Exactly -Scope It
        Assert-MockCalled Set-SkyRegistryValue -Times 0 -Exactly -Scope It
        Assert-MockCalled Remove-AppxPackage -Times 0 -Exactly -Scope It
        Assert-MockCalled Remove-AppxProvisionedPackage -Times 0 -Exactly -Scope It
    }
}

Describe 'AppX current-account preview with dependency protection' {
    BeforeEach { $script:packages=@();$script:enumerationFails=$false }
    Mock Get-AppxPackage { if($script:enumerationFails){throw 'private path'}; $script:packages }
    It 'distinguishes failed enumeration from an empty installed set' {
        (Get-SkyAppxPreview).Status | Should Be Observed
        $script:enumerationFails=$true
        $r=Get-SkyAppxPreview
        $r.Status | Should Be Unknown
        $r.Reason | Should Not Match 'private path'
        Assert-MockCalled Get-AppxPackage -Times 0 -Exactly -Scope It -ParameterFilter { $AllUsers -or $User }
    }
    It 'protects frameworks, reverse dependencies and gaming components; unknown metadata never authorizes removal' {
        $script:packages=@(
            [pscustomobject]@{Name='App';PackageFullName='App_1';PublisherId='p';Version='1.0';IsFramework=$false;IsResourcePackage=$false;NonRemovable=$false;Dependencies=@([pscustomobject]@{PackageFullName='Shared_1'})},
            [pscustomobject]@{Name='Shared';PackageFullName='Shared_1';PublisherId='p';Version='1.0';IsFramework=$false;IsResourcePackage=$false;NonRemovable=$false;Dependencies=@()},
            [pscustomobject]@{Name='Framework';PackageFullName='F_1';IsFramework=$true},
            [pscustomobject]@{Name='Microsoft.GamingServices';PackageFullName='G_1'},
            [pscustomobject]@{Name='Incomplete';PackageFullName='U_1'}
        )
        $r=Get-SkyAppxPreview
        ($r.Items | Where-Object Name -eq App).Classification | Should Be ReviewOnly
        foreach($name in @('Shared','Framework','Microsoft.GamingServices')) {
            ($r.Items | Where-Object Name -eq $name).Classification | Should Be Protected
        }
        ($r.Items | Where-Object Name -eq Incomplete).Classification | Should Be Unknown
        @($r.Items | Where-Object ApplyAllowed).Count | Should Be 0
        $script:packages=$script:packages[0]
        (Get-SkyAppxPreview).Items[0].Classification | Should Be Unknown
    }
}

Describe 'Exact laboratory selection' {
    It 'has no hidden Performance actions and resolves only required power dependency' {
        (@(Get-SkyProfileActionIds Laboratory -Experiments @(74)) -join ',') | Should Be '74'
        (@(Get-SkyProfileActionIds Laboratory -Experiments @(8,8)) -join ',') | Should Be '1,8'
        (@(Get-SkyProfileActionIds Laboratory -Experiments @(3,42)) -join ',') | Should Be '1,3,42'
        { Get-SkyProfileActionIds Laboratory } | Should Throw
        { Get-SkyProfileActionIds Laboratory -Experiments @(91) } | Should Throw
        (@(Get-SkyProfileActionIds Extreme -Experiments @(74)) -join ',') | Should Be '9,41,74,79'
    }
}
