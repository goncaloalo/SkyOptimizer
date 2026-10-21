. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Service and network journal lifecycles' {
    BeforeEach {
        $Global:SkyBackupDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $script:states = @{}; $script:failType = ''; $script:writes = @()
        $script:delayed = ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 1
        $script:svc = [pscustomobject]@{ Name = 'FakeService'; StartType = 'Automatic'; Status = 'Running'; DependentServices = @() }
        $script:runtime = [pscustomobject]@{ Type = 'ServiceRuntime'; Name = 'FakeService' }
        $script:startup = [pscustomobject]@{ Type = 'ServiceStartup'; Name = 'FakeService'
            DelayedResource = ConvertTo-SkyRegistryResource 'HKLM:\SYSTEM\CurrentControlSet\Services\FakeService' 'DelayedAutoStart' }
        $script:states['ServiceRuntime'] = [pscustomobject]@{ Value = 'Running' }
        $script:states['ServiceStartup'] = [pscustomobject]@{ Value = 'Automatic'; Delayed = $script:delayed }
        $script:nic = [pscustomobject]@{ Type = 'NicRegistry'; InterfaceGuid = '11111111-1111-1111-1111-111111111111'
            PnpDeviceId = 'PCI\FAKE'; DriverVersion = '1.0'; Keyword = '*InterruptModeration'
            Registry = ConvertTo-SkyRegistryResource 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\Fake\0001' '*InterruptModeration' }
        $script:states['NicRegistry'] = ConvertTo-SkyRegistryState -Exists $true -Kind String -Value '3'
    }
    Mock Get-SkyMachineId { 'fake' }
    Mock Get-SkyUserSid { 'fake-user' }
    Mock Get-Service { $script:svc }
    Mock Open-SkyRegistryBase { throw 'No registry access permitted.' }
    Mock Set-SkyServiceStartTypeNative { throw 'No SCM mutation permitted.' }
    Mock Invoke-SkyNativeProcess { throw 'No native commands permitted.' }
    Mock Get-SkyResourceState { $script:states[$Resource.Type] }
    Mock Set-SkyResourceState {
        if ($Resource.Type -eq $script:failType) { throw 'injected failure' }
        $script:writes += $Resource.Type
        $script:states[$Resource.Type] = $State
        if ($Resource.Type -eq 'ServiceRuntime') { $script:svc.Status = $State.Value }
        if ($Resource.Type -eq 'ServiceStartup') { $script:svc.StartType = $State.Value }
    }
    It 'restores delayed automatic startup and running state after Apply Apply Undo' {
        $null = Disable-SkyService FakeService
        $null = Disable-SkyService FakeService
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 2
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:states.ServiceStartup.Value | Should Be Automatic
        $script:states.ServiceStartup.Delayed.Data | Should Be '1'
        $script:states.ServiceRuntime.Value | Should Be Running
        ($script:writes -join ',') | Should Be 'ServiceRuntime,ServiceStartup,ServiceStartup,ServiceRuntime'
    }
    It 'preserves manual and originally stopped services without starting them' {
        $script:svc.StartType = 'Manual'; $script:svc.Status = 'Stopped'
        $script:states.ServiceRuntime.Value = 'Stopped'; $script:states.ServiceStartup.Value = 'Manual'
        $script:states.ServiceStartup.Delayed = ConvertTo-SkyRegistryState -Exists $false
        $null = Disable-SkyService FakeService
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:states.ServiceStartup.Value | Should Be Manual
        $script:states.ServiceRuntime.Value | Should Be Stopped
        $script:states.ServiceStartup.Delayed.Exists | Should Be $false
        @($script:writes | Where-Object { $_ -eq 'ServiceRuntime' }).Count | Should Be 0
    }
    It 'does not own an already disabled and stopped service' {
        $script:svc.StartType = 'Disabled'; $script:svc.Status = 'Stopped'
        $script:states.ServiceRuntime.Value = 'Stopped'; $script:states.ServiceStartup.Value = 'Disabled'
        $null = Disable-SkyService FakeService
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 0
        $script:writes.Count | Should Be 0
    }
    It 'restores runtime after stopping succeeded but disabling failed' {
        $script:failType = 'ServiceStartup'
        { Disable-SkyService FakeService } | Should Throw
        $script:failType = ''
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:states.ServiceRuntime.Value | Should Be Running
        $script:states.ServiceStartup.Value | Should Be Automatic
    }
    It 'refuses active dependents and paused or transitional services' {
        $script:svc.DependentServices = @([pscustomobject]@{ Status = 'Running' })
        (Disable-SkyService FakeService).Status | Should Be Incompatible
        $script:svc.DependentServices = @(); $script:svc.Status = 'Paused'
        (Disable-SkyService FakeService).Status | Should Be Incompatible
        $script:writes.Count | Should Be 0
    }
    It 'restores only the changed NIC property and its exact string value' {
        $desired = ConvertTo-SkyRegistryState -Exists $true -Kind String -Value '0'
        $null = Invoke-SkyTrackedChange $script:nic $desired
        $null = Invoke-SkyTrackedChange $script:nic $desired
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:states.NicRegistry.Data | Should Be '3'
        $script:states.NicRegistry.Kind | Should Be String
        ($script:writes -join ',') | Should Be 'NicRegistry,NicRegistry'
    }
    It 'preserves user changes to a NIC property instead of resetting defaults' {
        $null = Invoke-SkyTrackedChange $script:nic (ConvertTo-SkyRegistryState -Exists $true -Kind String -Value '0')
        $script:states.NicRegistry = ConvertTo-SkyRegistryState -Exists $true -Kind String -Value '4'
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        $script:states.NicRegistry.Data | Should Be '4'
    }
    It 'filters panel Undo to its service without changing NIC settings' {
        $null = Disable-SkyService FakeService
        $null = Invoke-SkyTrackedChange $script:nic (ConvertTo-SkyRegistryState -Exists $true -Kind String -Value '0')
        $null = Restore-SkyTrackedChanges -BackupDirectory $Global:SkyBackupDir -ServiceName FakeService
        $script:states.ServiceRuntime.Value | Should Be Running
        $script:states.NicRegistry.Data | Should Be '0'
    }
}

Describe 'Service native declarations and standalone parity' {
    It 'compiles SCM declarations without invoking any native function' {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput((Get-Command Set-SkyServiceStartTypeNative).Definition, [ref]$tokens, [ref]$errors)
        $definition = $ast.FindAll({ param($n)
            $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.Contains('public static class SkyServiceConfig')
        }, $true) | Select-Object -First 1
        ($null -ne $definition) | Should Be $true
        if (-not ('SkyServiceConfig' -as [type])) { Add-Type -TypeDefinition $definition.Value -ErrorAction Stop }
        ('SkyServiceConfig' -as [type]).Name | Should Be SkyServiceConfig
    }
    It 'parses the generated service panel with the same journal and SCM helpers' {
        $source = Get-SkyPanelServiceSource
        $tokens = $null; $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
        $errors.Count | Should Be 0
        $source.Contains((Get-Command Disable-SkyService).Definition) | Should Be $true
        $source.Contains((Get-Command Set-SkyServiceStartTypeNative).Definition) | Should Be $true
        $source.Contains((Get-Command Invoke-SkyTrackedChange).Definition) | Should Be $true
    }
}

Describe 'NIC binding and capability guards' {
    BeforeEach {
        $script:adapter = [pscustomobject]@{ Name = 'Ethernet [1]'; InterfaceGuid = '11111111-1111-1111-1111-111111111111'
            PnPDeviceID = 'PCI\FAKE'; DriverVersionString = '1.0'; Status = 'Up'; NdisPhysicalMedium = 14 }
        $script:prop = [pscustomobject]@{ RegistryKeyword = '*EEE'; ValidRegistryValues = @('0', '1') }
        $script:nic = [pscustomobject]@{ Type = 'NicRegistry'; InterfaceGuid = $script:adapter.InterfaceGuid
            PnpDeviceId = 'PCI\FAKE'; DriverVersion = '1.0'; Keyword = '*EEE'
            Registry = ConvertTo-SkyRegistryResource 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\Fake\0001' '*EEE' }
    }
    Mock Get-NetAdapter { $script:adapter }
    Mock Get-NetAdapterAdvancedProperty { $script:prop }
    Mock Get-SkyResourceState { ConvertTo-SkyRegistryState -Exists $true -Kind String -Value $script:adapter.InterfaceGuid }
    Mock Invoke-SkyTrackedChange { throw 'Unsupported adapters must never reach a write.' }
    It 'resolves the adapter by GUID even after a friendly-name change' {
        (Get-SkyNicBinding $script:nic).RegistryKeyword | Should Be '*EEE'
        $script:adapter.Name = 'Renamed Ethernet'
        (Get-SkyNicBinding $script:nic).RegistryKeyword | Should Be '*EEE'
    }
    It 'rejects a changed driver or substituted device' {
        $script:adapter.DriverVersionString = '2.0'
        { Get-SkyNicBinding $script:nic } | Should Throw
        $script:adapter.DriverVersionString = '1.0'; $script:adapter.PnPDeviceID = 'PCI\OTHER'
        { Get-SkyNicBinding $script:nic } | Should Throw
    }
    It 'rejects a missing property and skips wireless for Ethernet-only changes' {
        $script:prop.RegistryKeyword = '*Other'
        { Get-SkyNicBinding $script:nic } | Should Throw
        $script:adapter.NdisPhysicalMedium = 9
        (Set-SkyNicProperties -Keywords @('*FlowControl') -EthernetOnly).Status | Should Be Incompatible
        Assert-MockCalled Invoke-SkyTrackedChange -Times 0 -Exactly -Scope It
    }
}
