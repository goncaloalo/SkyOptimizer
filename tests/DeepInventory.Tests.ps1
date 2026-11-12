. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Deep inventory isolates unavailable readers without declaring absence' {
    It 'distinguishes empty observations, partial scope and complete reader failure' {
        $empty=Get-SkyInventorySection -Scope fixture -Reader { @() }
        $empty.Status | Should Be Observed
        $empty.Items.Count | Should Be 0
        (Get-SkyInventorySection -Scope fixture -Reader { throw 'denied' }).Status | Should Be Unknown
        (Get-SkyInventorySection -Scope fixture -Reader { [pscustomobject]@{Status='Unknown'} }).Status | Should Be Partial
    }
    It 'keeps failures private rather than exporting exception paths' {
        $r=Get-SkyInventorySection -Scope fixture -Reader {throw 'C:\private\customer'}
        ($r | ConvertTo-Json) | Should Not Match 'customer|private'
    }
}

Describe 'Installed software inventory never launches MSI or uninstall commands' {
    Mock Test-Path {$true}
    Mock Get-ChildItem {[pscustomobject]@{PSPath='fixture-key'}}
    Mock Get-ItemProperty {[pscustomobject]@{DisplayName='OEM fixture';Publisher='Vendor';DisplayVersion='1';UninstallString='malicious.exe'}}
    Mock Get-CimInstance {throw 'No MSI query permitted'}
    Mock Invoke-SkyNativeProcess {throw 'No execution'}
    It 'preserves exact registration identity and leaves OEM role and recovery unproven' {
        $r=@(Get-SkyInstalledSoftware)
        $r.Count | Should Be 4
        $r[0].Identity | Should Be fixture-key
        $r[0].OemRole | Should Be Unknown
        $r[0].ApplyAllowed | Should Be $false
        ($r | ConvertTo-Json) | Should Not Match 'malicious'
        Assert-MockCalled Get-CimInstance -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
    It 'retains denied root as incomplete instead of claiming no software' {
        Mock Get-ChildItem {throw 'access denied'}
        $r=@(Get-SkyInstalledSoftware)
        @($r | Where-Object Status -eq Unknown).Count | Should Be 4
    }
}

Describe 'Debloat diagnostic coverage is read-only and scope-separated' {
    Mock Get-SkyAppxPreview {[pscustomobject]@{Status='Observed';Scope='CurrentProcessUser';Items=@()}}
    Mock Get-SkyInventorySection {[pscustomobject]@{Status='Unknown';Scope=$Scope;Items=@()}}
    Mock Set-SkyResourceState {throw 'Inventory cannot mutate'}
    It 'includes provisioned apps, OEM/software, startup, service, task, feature and process scopes' {
        $r=Get-SkyDebloatInventory
        $r.SchemaVersion | Should Be 2
        @($r.Sections.PSObject.Properties).Count | Should Be 10
        $r.Sections.Appx.Scope | Should Be CurrentProcessUser
        $r.OperationPolicy.Deprovision | Should Match 'Blocked'
        $r.OperationPolicy.Uninstall | Should Match 'Blocked'
        $r.BackgroundCoverage | Should Match 'not measured activity'
        Assert-MockCalled Set-SkyResourceState -Times 0 -Exactly -Scope It
    }
}

Describe 'Hardware observations do not invent topology, pressure duration or causal bottlenecks' {
    Mock Get-SkyCpuTopology {[pscustomobject]@{Status='Unknown';LogicalProcessors=@()}}
    Mock Get-CimInstance {
        switch($ClassName) {
            Win32_Processor {[pscustomobject]@{Name='Fixture X3D';Family=198;NumberOfCores=8}}
            Win32_PerfFormattedData_PerfOS_Memory {[pscustomobject]@{CommittedBytes=90;CommitLimit=100;PageReadsPersec=12}}
            default { [pscustomobject]@{Name='Fixture';Model='SSD string does not prove media';DriverVersion='1'} }
        }
    }
    It 'reports validated commit ratio without choosing a tweak or claiming X3D topology' {
        $r=Get-SkyHardwareDiagnostics
        $r.Memory.Items[0].CommitRatio | Should Be 0.9
        $r.HybridTopology | Should Be Unknown
        $r.X3DTopology | Should Be Unknown
        $r.Bottleneck | Should Be Unknown
        $r.Memory.Items[0].Interpretation | Should Match 'Single snapshot'
    }
    It 'keeps invalid commit limits unknown and reader failures distinct' {
        Mock Get-CimInstance {[pscustomobject]@{CommittedBytes=90;CommitLimit=0}}
        $r=Get-SkyHardwareDiagnostics
        ($null -eq $r.Memory.Items[0].CommitRatio) | Should Be $true
        Mock Get-CimInstance {throw 'unavailable'}
        (Get-SkyHardwareDiagnostics).Memory.Status | Should Be Unknown
    }
}

Describe 'Every eligible action has an individual MAX decision and evidence limitation' {
    Mock Get-SkyStartupCandidate {[pscustomobject]@{Name=$Name;Status='Absent'}}
    It 'covers all 29 eligible IDs exactly and distinguishes operational choices from hardware experiments' {
        $rows=@(Get-SkyMaxActionAssessment)
        $rows.Count | Should Be 29
        (($rows.Id | Sort-Object) -join ',') | Should Be ((Get-SkyMigratedActionIds | Sort-Object) -join ',')
        @($rows | Where-Object MeasuredBenefit).Count | Should Be 0
        ($rows | Where-Object Id -eq 20).Disposition | Should Be ObservedWorkload
        ($rows | Where-Object Id -eq 13).Reason | Should Match 'aumentar'
        ($rows | Where-Object Id -eq 86).Disposition | Should Be FunctionalRisk
    }
    It 'includes individual exclusions in dry-run instead of a generic performance assumption' {
        $context=[pscustomobject]@{Windows=[pscustomobject]@{Version='10.0.22631';BuildNumber='22631';ProductType=1;OperatingSystemSKU=48};DomainJoined=$false;MdmIndicator=$false;Browsers=@{Edge=100;Chrome=0};PowerSource='AC';MemoryBytes=16GB;Issues=@()}
        $plan=Get-SkyMaxPlan $context
        ($plan.Decisions | Where-Object Id -eq 20).Reason | Should Match 'trafego peer'
        ($plan.Decisions | Where-Object Id -eq 3).Disposition | Should Be PhysicalValidation
        ($plan.SelectedIds -join ',') | Should Be '16,41,70,79'
    }
}

Describe 'Deep inventory executes leaf readers only through mocked OS surfaces' {
    Mock Get-SkyDebloatLabPlans {[pscustomobject]@{Status='Deferred';Reason='fixture'}}
    Mock Get-SkyAppxPreview {[pscustomobject]@{Status='Observed';Scope='CurrentProcessUser';Items=@()}}
    Mock Get-SkyBackgroundPlan {[pscustomobject]@{Status='Deferred';Reason='fixture'}}
    Mock Get-SkyInstalledSoftware {[pscustomobject]@{Identity='fixture-software';Dependencies='Unknown';ApplyAllowed=$false}}
    Mock Get-AppxProvisionedPackage {[pscustomobject]@{PackageName='fixture-provision';DisplayName='fixture';Version='1';Architecture='x64'}}
    Mock Get-Service {[pscustomobject]@{Name='fixture-service';Status='Running';StartType='Manual';RequiredServices=@([pscustomobject]@{Name='dependency'});DependentServices=@()}}
    Mock Get-ScheduledTask {[pscustomobject]@{TaskPath='\Fixture\';TaskName='Task';State='Ready';Actions=@([pscustomobject]@{Execute='fixture.exe'});Triggers=@()}}
    Mock Get-WindowsOptionalFeature {[pscustomobject]@{FeatureName='fixture-feature';State='Enabled'}}
    Mock Get-CimInstance {
        switch($ClassName) {
            Win32_Process {[pscustomobject]@{ProcessId=123;Name='fixture.exe';UserModeTime=1000;WorkingSetSize=2000}}
            Win32_StartupCommand {[pscustomobject]@{Name='fixture-startup';Command='never-run.exe';Location='fixture';User='fixture'}}
            default {throw 'Unexpected reader'}
        }
    }
    It 'keeps exact identities, declared SCM edges and cumulative counter semantics' {
        $r=Get-SkyDebloatInventory
        $r.Sections.Provisioned.Items[0].Identity | Should Be fixture-provision
        $r.Sections.Services.Items[0].RequiredServices[0] | Should Be dependency
        $r.Sections.Tasks.Items[0].Identity | Should Be '\Fixture\Task'
        $r.Sections.Features.Items[0].ApplyAllowed | Should Be $false
        $r.Sections.Processes.Items[0].UserModeTime | Should Be 1000
        $r.Sections.Processes.Scope | Should Match 'cumulative'
    }
    It 'isolates feature and task enumeration failures without losing other categories' {
        Mock Get-WindowsOptionalFeature {throw 'unavailable'}
        Mock Get-ScheduledTask {throw 'denied'}
        $r=Get-SkyDebloatInventory
        $r.Sections.Features.Status | Should Be Unknown
        $r.Sections.Tasks.Status | Should Be Unknown
        $r.Sections.Services.Status | Should Be Observed
    }
}
