. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Wireless capability detection is based on physical NDIS medium' {
    BeforeEach { $script:adapters=@();$script:unreadable=$false }
    Mock Get-NetAdapter { if($script:unreadable){throw 'unreadable'}; $script:adapters }
    Mock Set-SkyAcPowerSettings {throw 'No physical Wi-Fi must not mutate power settings'}
    It 'distinguishes absent unknown Ethernet and native Wi-Fi without guessing vendor names' {
        (Get-SkyWirelessPresence) | Should Be $false
        $script:adapters=@([pscustomobject]@{NdisPhysicalMedium=14})
        (Get-SkyWirelessPresence) | Should Be $false
        (Set-SkyWirelessPerformance).Status | Should Be Incompatible
        $script:unreadable=$true
        ($null -eq (Get-SkyWirelessPresence)) | Should Be $true
        (Set-SkyWirelessPerformance).Status | Should Be Incompatible
        $script:unreadable=$false;$script:adapters=@([pscustomobject]@{NdisPhysicalMedium=9})
        (Get-SkyWirelessPresence) | Should Be $true
        Assert-MockCalled Set-SkyAcPowerSettings -Times 0 -Exactly -Scope It
        Assert-MockCalled Get-NetAdapter -ParameterFilter {$Physical} -Scope It
    }
}

Describe 'New CPU and Wi-Fi actions cannot write on DC or unknown power' {
    Mock Test-IsDesktopOrAcPower {$false}
    Mock Get-SkyWirelessPresence {$true}
    Mock Invoke-SkyNativeProcess {throw 'No native mutations permitted'}
    Mock Enter-SkyPowerLock {throw 'No baseline access permitted before the AC check'}
    It 'rejects all three before native writes or journal access' {
        (Set-SkyCpuPerformancePreference).Status | Should Be Incompatible
        (Enable-SkyCpuBoost).Status | Should Be Incompatible
        (Set-SkyWirelessPerformance).Status | Should Be Incompatible
        Assert-MockCalled Enter-SkyPowerLock -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
}
