. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'AC-only capability checks fail closed' {
    BeforeEach { $script:line = 1; $script:readFails = $false }
    Mock Get-SkyAcLineStatus { if ($script:readFails) { throw 'Power status unavailable' }; $script:line }
    Mock Invoke-SkyTrackedChange { throw 'A blocked AC-only operation must not mutate Windows.' }
    Mock Set-SkyNicProperties { throw 'A blocked AC-only operation must not configure a NIC.' }
    It 'permits only an explicit online status' {
        (Test-IsDesktopOrAcPower) | Should Be $true
        foreach ($value in @(0,255,2,$null)) {
            $script:line = $value
            (Test-IsDesktopOrAcPower) | Should Be $false
        }
    }
    It 'does not classify an API failure as desktop or AC' {
        $script:readFails = $true
        (Test-IsDesktopOrAcPower) | Should Be $false
        (Optimize-NetworkAdapterPower).Status | Should Be Incompatible
        Assert-MockCalled Set-SkyNicProperties -Times 0 -Exactly -Scope It
    }
    It 'skips the USB plan experiment when AC is unknown or offline' {
        foreach ($line in @(0,255)) {
            $script:line = $line
            (Disable-USBSelectiveSuspend).Status | Should Be Incompatible
        }
        Assert-MockCalled Invoke-SkyTrackedChange -Times 0 -Exactly -Scope It
    }
    It 'compiles the power status declaration without invoking its native API' {
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\SkyOptimizer.ps1'), [ref]$tokens, [ref]$errors)
        $definition = $ast.FindAll({ param($node)
            $node -is [Management.Automation.Language.StringConstantExpressionAst] -and $node.Value.Contains('public static class SkyPowerSourceRead')
        }, $true) | Select-Object -First 1
        if (-not ('SkyPowerSourceRead' -as [type])) { Add-Type -TypeDefinition $definition.Value -ErrorAction Stop }
        ('SkyPowerSourceRead' -as [type]) -ne $null | Should Be $true
    }
}

Describe 'Unsupported device operations cannot reach legacy writes' {
    Mock Get-CimInstance { throw 'Brand and VRAM heuristics must not be used.' }
    Mock Set-ItemProperty { throw 'No device registry writes permitted.' }
    Mock Remove-ItemProperty { throw 'Existing interrupt priority must be preserved.' }
    Mock Invoke-SkyTrackedChange { throw 'Blocked device operations cannot start a journal.' }
    It 'blocks HAGS and MSI even when invoked directly' {
        (Enable-HAGSConditional).Status | Should Be Deferred
        (Enable-GpuMsiMode).Status | Should Be Deferred
        Assert-MockCalled Set-ItemProperty -Times 0 -Exactly -Scope It
        Assert-MockCalled Remove-ItemProperty -Times 0 -Exactly -Scope It
        Assert-MockCalled Get-CimInstance -Times 0 -Exactly -Scope It
    }
    It 'retires the broad WDF hub operation in the dispatcher and direct function' {
        (Disable-UsbPowerManagement).Status | Should Be Deferred
        (Invoke-SkyEligibleAction -Id 39 -SelectedIds @(39) -Action { throw 'retired' }).Status | Should Be Deferred
        (Get-SkyRetiredActionIds) -contains 39 | Should Be $true
        Assert-MockCalled Set-ItemProperty -Times 0 -Exactly -Scope It
    }
    It 'adds only the power plan dependency for the explicit USB experiment' {
        (@(Get-SkyProfileActionIds Extreme -Experiments @(8)) -join ',') | Should Be '1,8,9,41,79'
        foreach ($profile in @('Balanced','Performance')) { (Get-SkyProfileActionIds $profile) -contains 8 | Should Be $false }
    }
}
