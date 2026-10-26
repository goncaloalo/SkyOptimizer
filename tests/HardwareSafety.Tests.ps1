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
