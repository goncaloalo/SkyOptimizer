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

Describe 'MAX independent validation scope covers conditional policy and startup resources' {
    Mock Write-SkyLog {}
    Mock Test-SkyClientPolicySupport { $true }
    Mock Get-SkyBrowserMajorVersion { 100 }
    Mock Set-SkyRegistryValue {
        $script:writes += "$Path|$Name".ToUpperInvariant()
        New-SkyActionResult -Status Applied -Reason 'Synthetic write' -RestartRequired Unknown
    }
    Mock Get-SkyResourceState {
        $hive=if($Resource.Hive -eq 'HKEY_CURRENT_USER'){'HKCU:'}else{'HKLM:'}
        $script:writes += "$hive\$($Resource.Key)|$($Resource.Name)".ToUpperInvariant()
        ConvertTo-SkyRegistryState -Exists $false
    }
    It 'covers the superset before Apply, including resources that should remain unchanged on other editions' {
        $script:writes=@()
        $null=Enable-WindowsGameMode
        $null=Disable-GameDVR
        $null=Disable-BrowserBackgroundTasks
        $null=Disable-TaskbarWidgets
        foreach($id in @(58,70,84)) { $null=Set-SkyCloudPolicy $id }
        foreach($name in @('Spotify','Steam')) { $null=Get-SkyStartupCandidate $name }
        $specs=Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\integration\evidence-max.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $expected=@(foreach($spec in $specs) {
            $null = $spec.Type | Should Be Registry
            $null = $spec.View | Should Be Registry64
            $hive=if($spec.Hive -eq 'CurrentUser'){'HKCU:'}else{'HKLM:'}
            "$hive\$($spec.Path)|$($spec.Name)".ToUpperInvariant()
        })
        ($script:writes | Sort-Object -Unique) -join ';' | Should Be (($expected | Sort-Object -Unique) -join ';')
        $expected.Count | Should Be 16
        @($specs.Id | Select-Object -Unique).Count | Should Be 16
    }
}
