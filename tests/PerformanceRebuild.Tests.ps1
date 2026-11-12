. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Performance plan expands selection without bypassing recovery contracts' {
    BeforeEach {
        $script:context=[pscustomobject]@{Windows=[pscustomobject]@{Version='10.0.22631';BuildNumber='22631';ProductType=1;OperatingSystemSKU=48};DomainJoined=$false;MdmIndicator=$false;Browsers=@{Edge=130;Chrome=0};PowerSource='AC';MemoryBytes=16GB;Issues=@()}
    }
    Mock Get-SkyStartupCandidate { [pscustomobject]@{Name=$Name;Status='Absent'} }
    Mock Get-CimInstance { throw 'No live OS discovery in synthetic plans' }
    Mock Set-SkyResourceState { throw 'Plans cannot mutate the host' }
    It 'selects energy background and network tradeoffs on unmanaged Pro AC' {
        $plan=Get-SkyPerformancePlan $script:context
        ($plan.SelectedIds -join ',') | Should Be '1,3,16,20,25,38,41,60,70,74,75,76,79'
        $plan.Mode | Should Be Performance
        @($plan.SelectedIds | Where-Object {$_ -notin (Get-SkyMigratedActionIds)}).Count | Should Be 0
        $plan.Decisions.Count | Should Be 90
        ($plan.Decisions | Where-Object Id -eq 74).Reason | Should Match 'piorar'
        Assert-MockCalled Set-SkyResourceState -Times 0 -Exactly -Scope It
    }
    It 'preserves battery and refuses extra changes on managed or unknown systems' {
        $script:context.PowerSource='DC'
        $p=Get-SkyPerformancePlan $script:context
        @($p.SelectedIds | Where-Object {$_ -in @(1,3,38,60,74,75,76)}).Count | Should Be 0
        $script:context.DomainJoined=$true
        ((Get-SkyPerformancePlan $script:context).SelectedIds -join ',') | Should Be '79'
        $script:context.Windows=$null
        (Get-SkyPerformancePlan $script:context).SelectedIds.Count | Should Be 0
    }
    It 'leaves Home policies and unsupported device writes excluded' {
        $script:context.Windows.OperatingSystemSKU=101
        ((Get-SkyPerformancePlan $script:context).SelectedIds -join ',') | Should Be '1,3,38,41,60,74,75,76,79'
        foreach($id in @(8,37,40,48,49,71)) {
            (Get-SkyPerformancePlan $script:context).SelectedIds -contains $id | Should Be $false
        }
    }
}

Describe 'Panel delivery keeps working maintenance source and client report' {
    BeforeEach {
        $script:files=@{};$script:SkyApplicationPath=Join-Path $TestDrive 'source.ps1'
        [IO.File]::WriteAllText($script:SkyApplicationPath,'# retained application fixture')
        $Global:SkyBackupDir=$TestDrive;$Global:SkyPermDir=$TestDrive
    }
    Mock Initialize-SkyStorage {}
    Mock Get-SkyStorageRoot {$TestDrive}
    Mock Assert-SkyPanelBackupDirectory {}
    Mock Assert-SkyNoReparsePoint {}
    Mock Test-Path {$true}
    Mock Remove-Item {}
    Mock Write-SkyPanelFile {$script:files[[IO.Path]::GetFileName($Path)]=$Content}
    Mock Write-SkyAtomicFile {$script:files[[IO.Path]::GetFileName($Path)]=$Content}
    Mock Write-SkyLog {}
    It 'generates real maintenance shortcuts and retains the report without touching Desktop' {
        Deploy-ClientPanel -ReportContent 'client report fixture' | Should Be $true
        $script:files['SkyOptimizer.ps1'] | Should Be '# retained application fixture'
        $script:files['Relatorio_Otimizacao.txt'] | Should Be 'client report fixture'
        $script:files['[5] Limpar Temporarios Antigos.cmd'] | Should Match '-Clean'
        $script:files['[6] Limpeza de Shaders (Diagnostico).cmd'] | Should Match '-CleanShaders'
        $script:files['[8] Reparar Windows.cmd'] | Should Match '-Repair'
        $script:files['[4] Abrir Definicoes de Seguranca.cmd'] | Should Match 'ms-settings:windowsdefender'
        $script:files['[7] Abrir Definicoes de Localizacao.cmd'] | Should Match 'ms-settings:privacy-location'
    }
}

Describe 'Client Apply deploys panel and uses the exact confirmed performance plan' {
    BeforeEach {
        $Global:SkyBackupDir=$TestDrive;$ExperimentalActions=''
        $script:reads=0;$script:drift=$false;$script:answer='S'
    }
    Mock Write-Host {}
    Mock Write-SkyReportArtifact {}
    Mock Read-Host {$script:answer}
    Mock Get-SkyPerformancePlan {
        $script:reads++
        $ids=if($script:drift -and $script:reads -eq 2){@(79)}else{@(1,3,79)}
        [pscustomobject]@{Mode='Performance';SelectedIds=$ids;Decisions=@();Startup=@();Recommendations=@();Context=@{Issues=@()}}
    }
    Mock Invoke-SkyOptimize {$script:SkyLastExitCode=0}
    It 'runs the non-operator engine so its panel deployment is retained' {
        Invoke-SkyMaxCore -ClientMode
        Assert-MockCalled Invoke-SkyOptimize -Times 1 -Exactly -Scope It -ParameterFilter {-not $OperatorMode -and ($SelectedActionIds -join ',') -eq '1,3,79'}
    }
    It 'does not apply declined or changed plans' {
        $script:answer='N';Invoke-SkyMaxCore -ClientMode
        Assert-MockCalled Invoke-SkyOptimize -Times 0 -Exactly -Scope It
        $script:answer='S';$script:reads=0;$script:drift=$true;Invoke-SkyMaxCore -ClientMode
        Assert-MockCalled Invoke-SkyOptimize -Times 0 -Exactly -Scope It
    }
}

Describe 'Temporary maintenance preserves recent files and shaders' {
    BeforeEach {$script:answer='S';$script:recent=$false;$script:locked=$false}
    Mock Read-Host {$script:answer}
    Mock Get-SkyTemporaryFiles { [pscustomobject]@{FullName='C:\Fixture\old.tmp';Length=20} }
    Mock Assert-SkyNoReparsePoint {}
    Mock Get-Item { [pscustomobject]@{FullName='C:\Fixture\old.tmp';Length=20;PSIsContainer=$false;LastWriteTime=$(if($script:recent){Get-Date}else{(Get-Date).AddDays(-10)})} }
    Mock Remove-Item {if($script:locked){throw 'locked'}}
    Mock Test-Path {$false}
    Mock Clear-ShaderCache {throw 'Temporary cleanup must preserve shaders'}
    It 'returns cancellation without deleting files' {
        $script:answer='N'
        (Clear-SkyTemporaryFiles).Status | Should Be NotSelected
        Assert-MockCalled Remove-Item -Times 0 -Exactly -Scope It
    }
    It 'rechecks file age immediately before deletion' {
        $script:recent=$true
        (Clear-SkyTemporaryFiles).Status | Should Be AlreadyCompliant
        Assert-MockCalled Remove-Item -Times 0 -Exactly -Scope It
    }
    It 'reports actual deletion and locked-file failure separately' {
        (Clear-SkyTemporaryFiles).Reason | Should Match '1 removidos, 0 falhas, 20 bytes'
        $script:locked=$true
        (Clear-SkyTemporaryFiles).Status | Should Be Failed
        Assert-MockCalled Remove-Item -Times 2 -Exactly -Scope It -ParameterFilter {$LiteralPath -eq 'C:\Fixture\old.tmp' -and -not $Recurse}
    }
}

Describe 'Panel maintenance shortcuts invoke the retained application' {
    Mock Get-SkyStorageRoot {'C:\ProgramData\SkyOptimizer'}
    It 'routes cleanup and repair to real commands with exit code propagation' {
        foreach($action in @('Clean','CleanShaders','Repair','Audit')) {
            $cmd=Get-SkyPanelLauncher -FileName SkyOptimizer.ps1 -Action $action
            $cmd | Should Match "SkyOptimizer.ps1.*-$action"
            $cmd | Should Match 'exit /b %SkyExit%'
        }
        {Get-SkyPanelLauncher -FileName SkyRevert.ps1 -Action Clean} | Should Throw
        {Get-SkyPanelLauncher -FileName SkyOptimizer.ps1} | Should Throw
    }
}

Describe 'Interactive menu dispatch' {
    BeforeEach {$script:menuReads=0}
    Mock Write-Host {}
    Mock Read-Host {$script:menuReads++;if($script:menuReads -eq 1){'1'}else{'0'}}
    Mock Invoke-SkyPerformance {$script:SkyLastExitCode=2}
    It 'applies performance once then returns to a usable menu' {
        Show-SkyMenu
        Assert-MockCalled Invoke-SkyPerformance -Times 1 -Exactly -Scope It
        $script:SkyLastExitCode | Should Be 2
    }
}
