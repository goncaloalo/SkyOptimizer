. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Auxiliary log failures remain visible without exposing exception content' {
    BeforeEach {
        $Global:SkyLogFile = Join-Path $TestDrive 'aux.log'
        $script:SkyLogWarningPath = $null
        $script:SkyLogWriteFailed = $false
        $script:SkyActionContext = $null
    }
    Mock Write-Warning {}
    Mock Write-Host {}
    It 'warns once per destination even with NoConsole and retains failure evidence' {
        Mock Add-Content { throw 'private-user-path-secret' }
        Write-SkyLog -Message 'one' -NoConsole
        Write-SkyLog -Message 'two' -NoConsole
        $script:SkyLogWriteFailed | Should Be $true
        Assert-MockCalled Write-Warning -Times 1 -Exactly -Scope It
        Assert-MockCalled Write-Warning -Times 0 -Exactly -Scope It -ParameterFilter { $Message -match 'private-user-path-secret' }
        $Global:SkyLogFile = Join-Path $TestDrive 'other.log'
        Write-SkyLog -Message 'three' -NoConsole
        Assert-MockCalled Write-Warning -Times 2 -Exactly -Scope It
    }
    It 'does not mark a successful append as a failed log' {
        Mock Add-Content {}
        Write-SkyLog -Message 'ok' -NoConsole
        $script:SkyLogWriteFailed | Should Be $false
        Assert-MockCalled Write-Warning -Times 0 -Exactly -Scope It
    }
}
