. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Apply orchestration without host changes' {
    BeforeEach {
        $Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $Global:SkyManifest=[ordered]@{OperatingSystem='Mock Windows';AppliedTweaks=@()}
        $Global:SkyLogFile=$null
        $Profile='Balanced'; $ExperimentalActions=''
        $script:panelOk=$true; $script:modeStatus='Applied'; $script:report=''
    }
    Mock Write-Host { }
    Mock Clear-Host { }
    Mock Write-SkyLog { }
    Mock Read-Host { 'N' }
    Mock Start-Sleep { }
    Mock Show-SystemHardwareInfo { }
    Mock Get-SkyLegacyBackupFiles { }
    Mock Get-Process { [pscustomobject]@{Id=123} }
    Mock Get-VbsStatus { 'Unknown' }
    Mock Get-CimInstance { [pscustomobject]@{TotalVisibleMemorySize=8192000;FreePhysicalMemory=4096000} }
    Mock Get-PSDrive { [pscustomobject]@{Free=100GB} } -ParameterFilter { $Name -eq 'C' }
    Mock Checkpoint-Computer { }
    Mock Save-SkyManifest { }
    Mock Get-SkyWindowsBuild { 22631 }
    Mock Enable-WindowsGameMode { New-SkyActionResult -Status $script:modeStatus -Reason 'simulated Game Mode' -RestartRequired No }
    Mock Deploy-ClientPanel { $script:report=$ReportContent; $script:panelOk }
    Mock Invoke-SkyNativeProcess { throw 'Native command forbidden.' }
    Mock Open-SkyRegistryBase { throw 'Registry access forbidden.' }
    Mock Stop-Process { throw 'Process termination forbidden.' }
    It 'includes panel deployment failure in the final exit code while retaining action evidence' {
        $script:panelOk=$false
        $null=Invoke-SkyOptimize
        $script:SkyLastExitCode | Should Be 1
        $rows=Get-Content (Join-Path $Global:SkyBackupDir 'execution_results.json') -Raw | ConvertFrom-Json
        @($rows).Count | Should Be 90
        @($rows | Where-Object Status -eq 'Applied').Count | Should Be 1
        Assert-MockCalled Enable-WindowsGameMode -Times 1 -Exactly -Scope It
        Assert-MockCalled Stop-Process -Times 0 -Exactly -Scope It
    }
    It 'returns incomplete when the selected action is incompatible' {
        $script:modeStatus='Incompatible'
        $null=Invoke-SkyOptimize
        $script:SkyLastExitCode | Should Be 2
    }
    It 'keeps successful execution distinct from performance validation' {
        $null=Invoke-SkyOptimize
        $script:SkyLastExitCode | Should Be 0
        $script:report.Contains('FPS, frametimes/input lag:') | Should Be $true
    }
    It 'uses the same action journal path in operator mode without deploying a panel or waiting at the end' {
        $null=Invoke-SkyOptimize -SelectedActionIds @(79) -OperatorMode
        $script:SkyLastExitCode | Should Be 0
        Assert-MockCalled Deploy-ClientPanel -Times 0 -Exactly -Scope It
        Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
        Test-Path (Join-Path $Global:SkyBackupDir 'operator_report.txt') | Should Be $true
    }
}
