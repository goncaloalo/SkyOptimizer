. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Default validation scope covers every registry write in Performance' {
    Mock Write-SkyLog {}
    Mock Get-SkyBrowserMajorVersion { 100 }
    Mock Set-SkyRegistryValue { $script:writes += "$Path|$Name".ToUpperInvariant() }
    It 'covers Game Mode, DVR and both browser branches without changing Windows' {
        $script:writes=@()
        $null=Enable-WindowsGameMode
        Mock Test-SkyClientPolicySupport { $true }
        $null=Disable-GameDVR
        $null=Disable-BrowserBackgroundTasks
        $specs=Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\integration\evidence-performance.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $expected=@(foreach($spec in $specs) {
            $null = $spec.Type | Should Be Registry
            $null = $spec.View | Should Be Registry64
            $hive=if($spec.Hive -eq 'CurrentUser'){'HKCU:'}else{'HKLM:'}
            "$hive\$($spec.Path)|$($spec.Name)".ToUpperInvariant()
        })
        ($script:writes | Sort-Object -Unique) -join ';' | Should Be (($expected | Sort-Object -Unique) -join ';')
        $expected.Count | Should Be 10
    }
}
