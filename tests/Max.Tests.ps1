. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'MAX inventory preserves uncertainty and stable revalidation fields' {
    Mock Get-SkyUserSid {'fixture-user'}
    Mock Get-SkyPowerSource {'Unknown'}
    Mock Get-SkyBrowserMajorVersion {0}
    Mock Test-Path {$false}
    It 'does not export volatile memory counters or infer hybrid/X3D topology from names' {
        Mock Get-CimInstance {
            switch($ClassName) {
                Win32_OperatingSystem {[pscustomobject]@{Version='10.0.22631';BuildNumber='22631';ProductType=1;OperatingSystemSKU=48;FreePhysicalMemory=123;RegisteredUser='private'}}
                Win32_ComputerSystem {[pscustomobject]@{PartOfDomain=$false;TotalPhysicalMemory=8GB;PCSystemType=2}}
                Win32_Processor {[pscustomobject]@{Name='Synthetic X3D';Manufacturer='Synthetic';NumberOfCores=8;NumberOfLogicalProcessors=16}}
                Win32_VideoController {[pscustomobject]@{Name='Synthetic GPU';DriverVersion='test'}}
            }
        }
        $c=Get-SkyMaxContext
        $c.HybridTopology | Should Be Unknown
        $c.X3DTopology | Should Be Unknown
        $c.PowerSource | Should Be Unknown
        ($c.Windows | ConvertTo-Json) | Should Not Match 'FreePhysicalMemory|RegisteredUser|private'
        $c.UserSid | Should Be 'fixture-user'
    }
    It 'keeps failed OS and management reads unknown rather than compatible or unmanaged' {
        Mock Get-CimInstance {throw 'unreadable'}
        Mock Test-Path {throw 'denied'}
        $c=Get-SkyMaxContext
        ($null -eq $c.Windows) | Should Be $true
        ($null -eq $c.DomainJoined) | Should Be $true
        ($null -eq $c.MdmIndicator) | Should Be $true
        $c.Issues.Count | Should BeGreaterThan 0
    }
}

Describe 'MAX decisions use compatibility rather than an Extreme alias' {
    BeforeEach {
        $script:context=[pscustomobject]@{Windows=[pscustomobject]@{Version='10.0.22631';BuildNumber='22631';ProductType=1;OperatingSystemSKU=48}
            DomainJoined=$false;MdmIndicator=$false;Browsers=@{Edge=130;Chrome=0};PowerSource='AC';MemoryBytes=16GB;Issues=@()}
    }
    Mock Get-SkyStartupCandidate { [pscustomobject]@{Name=$Name;Status='Absent'} }
    Mock Get-CimInstance {throw 'No live CIM in pure plan'}
    Mock Set-SkyResourceState {throw 'Plan must not write'}
    It 'selects documented Win11 Pro background contracts without capture or hardware experiments' {
        $plan=Get-SkyMaxPlan $script:context
        ($plan.SelectedIds -join ',') | Should Be '16,41,70,79'
        $plan.Decisions.Count | Should Be 90
        @($plan.SelectedIds | Where-Object {$_ -in @(1,3,8,25,37,40,42,48,49,71,74,75,76,81,88)}).Count | Should Be 0
        Assert-MockCalled Set-SkyResourceState -Times 0 -Exactly -Scope It
    }
    It 'uses Windows 10 enterprise policy contracts without assuming Pro has enterprise features' {
        $script:context.Windows.BuildNumber='19045';$script:context.Windows.OperatingSystemSKU=4
        ((Get-SkyMaxPlan $script:context).SelectedIds -join ',') | Should Be '9,41,58,70,79,84'
    }
    It 'limits Home, managed and unknown systems and does not guess AC' {
        $script:context.Windows.OperatingSystemSKU=101
        ((Get-SkyMaxPlan $script:context).SelectedIds -join ',') | Should Be '41,79'
        $script:context.DomainJoined=$true
        ((Get-SkyMaxPlan $script:context).SelectedIds -join ',') | Should Be '79'
        $script:context.DomainJoined=$false;$script:context.MdmIndicator=$null;$script:context.PowerSource='Unknown'
        $p=Get-SkyMaxPlan $script:context
        ($p.SelectedIds -join ',') | Should Be '79'
        ($p.Recommendations -join ' ') | Should Match 'DC/Unknown'
        $script:context.Windows=$null
        @( (Get-SkyMaxPlan $script:context).SelectedIds ).Count | Should Be 0
    }
    It 'keeps startup discovery failures distinct from absence' {
        Mock Get-SkyStartupCandidate {throw 'unreadable'}
        $p=Get-SkyMaxPlan $script:context
        @($p.Startup | Where-Object Status -eq Unknown).Count | Should Be 2
    }
}

Describe 'MAX lifecycle without system mutation' {
    Mock New-SkyProtectedDirectory { $null=[IO.Directory]::CreateDirectory($Path) }
    Mock Assert-SkyNoReparsePoint {}
    BeforeEach {
        $Global:SkyBackupDir=$TestDrive;$ExperimentalActions='';$script:answer='S';$script:reads=0;$script:drift=$false
        $script:plan=[pscustomobject]@{SelectedIds=@(41,79);Decisions=@();Recommendations=@();Startup=@();Context=@{Issues=@()}}
    }
    Mock Get-SkyMaxPlan { $script:reads++;if($script:drift -and $script:reads -eq 2){throw 'context read failed'};$script:plan }
    Mock Write-SkyAtomicFile {}
    Mock Write-Host {}
    Mock Read-Host {$script:answer}
    Mock Invoke-SkyOptimize {$script:SkyLastExitCode=0}
    Mock Deploy-ClientPanel {throw 'No automatic panel'}
    It 'passes its exact selection to the existing engine once and returns' {
        Invoke-SkyMax
        $script:SkyLastExitCode | Should Be 0
        Assert-MockCalled Invoke-SkyOptimize -Times 1 -Exactly -Scope It -ParameterFilter {$OperatorMode -and ($SelectedActionIds -join ',') -eq '41,79'}
        Assert-MockCalled Deploy-ClientPanel -Times 0 -Exactly -Scope It
        Assert-MockCalled Read-Host -Times 1 -Exactly -Scope It
    }
    It 'does not apply when functional impact is declined' {
        $script:answer='N';Invoke-SkyMax
        $script:SkyLastExitCode | Should Be 2
        Assert-MockCalled Invoke-SkyOptimize -Times 0 -Exactly -Scope It
    }
    It 'does not apply after revalidation failure or silently append experimental actions' {
        $script:drift=$true
        {Invoke-SkyMax} | Should Throw
        Assert-MockCalled Invoke-SkyOptimize -Times 0 -Exactly -Scope It
        $ExperimentalActions='74'
        {Invoke-SkyMax} | Should Throw
    }
    It 'rejects a changed selection before any action and surfaces unknown inventory as incomplete' {
        Mock Get-SkyMaxPlan {
            $script:reads++
            if($script:reads -eq 2) {return [pscustomobject]@{SelectedIds=@(79);Decisions=@();Recommendations=@();Startup=@();Context=@{Issues=@()}}}
            $script:plan
        }
        Invoke-SkyMax
        $script:SkyLastExitCode | Should Be 2
        Assert-MockCalled Invoke-SkyOptimize -Times 0 -Exactly -Scope It
    }
}

Describe 'MAX entry points remain finite and dry-run bypasses initialization' {
    It 'retains technical MAX and restores the default Performance menu' {
        $text=Get-Content (Join-Path $PSScriptRoot '..\SkyOptimizer.ps1') -Raw
        $text | Should Match "\[string\]\`$Profile = 'Performance'"
        $text.IndexOf('if ($DryRun -or $Diagnose)') | Should BeLessThan $text.IndexOf('try { Initialize-SkyStorage }')
        $text | Should Match 'Show-SkyMenu'
        $text | Should Match 'Invoke-SkyOptimize -OperatorMode'
        $text | Should Match '\} finally \{ \$skySession.Dispose\(\) \}'
        (Get-Content (Join-Path $PSScriptRoot '..\Executar-SkyOptimizer.bat') -Raw) | Should Match '(?im)^\s*pause\s*$'
    }
}
