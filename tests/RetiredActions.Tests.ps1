. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Retired and quarantined operations never reach Windows mutations' {
    Mock Set-ItemProperty { throw 'Raw writes forbidden.' }
    Mock Remove-ItemProperty { throw 'Deletes forbidden.' }
    Mock Backup-RegistryKey { throw 'Do not create new legacy baselines.' }
    Mock Invoke-SkyTrackedChange { throw 'Retired actions must not journal a mutation.' }
    Mock Invoke-SkyNativeProcess { throw 'Native processes forbidden.' }
    Mock Disable-MMAgent { throw 'MMAgent changes forbidden without a baseline.' }
    It 'makes every retired dispatcher decision traceable and blocks direct legacy entry points' {
        $functions = @{12='Disable-QoSBandwidthLimit';30='Set-FastShutdown';39='Disable-UsbPowerManagement';54='Disable-LowDiskSpaceChecks'}
        ((Get-SkyRetiredActionIds | Sort-Object) -join ',') | Should Be '12,30,39,54'
        foreach ($id in $functions.Keys) {
            (Invoke-SkyEligibleAction -Id $id -SelectedIds @($id) -Action { throw 'Retired body reached' }).Reason | Should Be (Get-SkyRetiredActionReason $id)
            (& $functions[$id]).Status | Should Be Deferred
        }
        Assert-MockCalled Set-ItemProperty -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SkyTrackedChange -Times 0 -Exactly -Scope It
        Assert-MockCalled Backup-RegistryKey -Times 0 -Exactly -Scope It
    }
    It 'preserves the MMCSS and prelaunch hypotheses without writing unused or unrelated settings' {
        (Set-MMCSSTasksGames).Status | Should Be Deferred
        (Disable-ApplicationPreLaunch).Status | Should Be Deferred
        Assert-MockCalled Set-ItemProperty -Times 0 -Exactly -Scope It
        Assert-MockCalled Disable-MMAgent -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
}
