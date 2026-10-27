. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
$script:cloudSave=(Get-Command Save-SkyMutationState).ScriptBlock

Describe 'Cloud policies use documented scopes without CDM fallback writes' {
    BeforeEach {
        $Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $Global:SkyLogFile=$null
        $script:values=@{}; $script:writes=0; $script:saves=0; $script:failSaveAt=0
        $script:os=[pscustomobject]@{Version='10.0.22631';BuildNumber='22631';ProductType=1;OperatingSystemSKU=4}
        $script:functions=@{58='Disable-SilentAppInstallation';70='Disable-SettingsOnlineTips';84='Disable-WindowsSpotlightDownloads'}
    }
    Mock Get-CimInstance { $script:os }
    Mock Get-SkyMachineId { 'mock-machine' }
    Mock Get-SkyUserSid { 'mock-user' }
    Mock Open-SkyRegistryBase { throw 'Real registry access forbidden.' }
    Mock Set-ItemProperty { throw 'Raw CDM/policy writes forbidden.' }
    Mock Get-SkyResourceState {
        $id=Get-SkyResourceIdentity $Resource
        if ($script:values.ContainsKey($id)) { return $script:values[$id] }
        ConvertTo-SkyRegistryState -Exists $false
    }
    Mock Set-SkyResourceState { $script:writes++; $script:values[(Get-SkyResourceIdentity $Resource)]=$State }
    Mock Save-SkyMutationState {
        $script:saves++
        if ($script:saves -eq $script:failSaveAt) { throw 'disk unavailable' }
        & $script:cloudSave $State $BackupDirectory
    }
    It 'supports six execution orders, repeated Apply and exact scoped/global Undo' {
        foreach ($order in @(@(58,70,84),@(58,84,70),@(70,58,84),@(70,84,58),@(84,58,70),@(84,70,58))) {
            foreach ($id in $order) { (Invoke-SkyAction { & $script:functions[$id] }).Status | Should Be Applied }
            foreach ($id in $order) { (Invoke-SkyAction { & $script:functions[$id] }).Status | Should Be AlreadyCompliant }
            $entries=@((Read-SkyMutationState $Global:SkyBackupDir).Entries | Where-Object Status -ne 'Restored')
            $entries.Count | Should Be 3
            foreach ($entry in $entries) { @($entry.OwnerIds).Count | Should Be 1; $entry.Original.Exists | Should Be $false }
            @($entries | Where-Object { $_.Resource.Hive -eq 'HKEY_CURRENT_USER' -and $_.Resource.Name -eq 'DisableWindowsSpotlightFeatures' }).Count | Should Be 1
            $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58
            @((Read-SkyMutationState $Global:SkyBackupDir).Entries | Where-Object Status -ne 'Restored').Count | Should Be 2
            $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
            @($script:values.Values | Where-Object Exists).Count | Should Be 0
        }
    }
    It 'preserves internal CDM flags, unrelated CloudContent values and misplaced legacy machine values' {
        $untouched=@(
            (ConvertTo-SkyRegistryResource 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled'),
            (ConvertTo-SkyRegistryResource 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'FeatureManagementEnabled'),
            (ConvertTo-SkyRegistryResource 'HKLM:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding'),
            (ConvertTo-SkyRegistryResource 'HKLM:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures')
        )
        $original=ConvertTo-SkyRegistryState -Exists $true -Kind ExpandString -Value '%USERPROFILE%\untouched'
        foreach ($resource in $untouched) { $script:values[(Get-SkyResourceIdentity $resource)]=$original }
        foreach ($id in @(58,70,84)) { $null=Invoke-SkyAction { & $script:functions[$id] } }
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        foreach ($resource in $untouched) { (Test-SkyStateEqual (Get-SkyResourceState $resource) $original) | Should Be $true }
        @($script:values.Values | Where-Object Exists).Count | Should Be 4
    }
    It 'does not invent ownership for policies already configured by the user' {
        foreach ($id in @(58,70,84)) {
            $spec=Get-SkyCloudPolicySpec $id
            $resource=ConvertTo-SkyRegistryResource $spec.Path $spec.Name
            $value=if ($id -eq 70) { 0 } else { 1 }
            $script:values[(Get-SkyResourceIdentity $resource)]=ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value $value
            (Invoke-SkyAction { & $script:functions[$id] }).Status | Should Be AlreadyCompliant
        }
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 0
        $script:writes | Should Be 0
    }
    It 'allows only OnlineTips on Pro and refuses Home, Server and unknown editions' {
        $script:os.OperatingSystemSKU=48
        (Disable-SilentAppInstallation).Status | Should Be Incompatible
        (Disable-WindowsSpotlightDownloads).Status | Should Be Incompatible
        (Disable-SettingsOnlineTips).Status | Should Be Applied
        foreach ($sku in @(101,999)) {
            $script:os.OperatingSystemSKU=$sku
            foreach ($id in @(58,70,84)) { (& $script:functions[$id]).Status | Should Be Incompatible }
        }
        $script:os.OperatingSystemSKU=4; $script:os.ProductType=3
        foreach ($id in @(58,70,84)) { (& $script:functions[$id]).Status | Should Be Incompatible }
        $script:writes | Should Be 1
    }
    It 'respects minimum builds and does not write a machine consumer policy in the old user-scope window' {
        foreach ($id in @(58,70,84)) {
            $spec=Get-SkyCloudPolicySpec $id
            $script:os.BuildNumber=[string]($spec.MinimumBuild-1)
            (& $script:functions[$id]).Status | Should Be Incompatible
            $script:os.BuildNumber=[string]$spec.MinimumBuild
            (& $script:functions[$id]).Status | Should Be Applied
        }
        $script:writes | Should Be 3
        { Test-SkyClientPolicySupport -EnterpriseOnly -AllowHome } | Should Throw
    }
    It 'recovers independently after a middle action fails to persist intent' {
        $script:failSaveAt=3
        (Invoke-SkyAction { Disable-SilentAppInstallation }).Status | Should Be Applied
        (Invoke-SkyAction { Disable-SettingsOnlineTips }).Status | Should Be Failed
        (Invoke-SkyAction { Disable-WindowsSpotlightDownloads }).Status | Should Be Applied
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58
        @($script:values.Values | Where-Object Exists).Count | Should Be 1
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        @($script:values.Values | Where-Object Exists).Count | Should Be 0
    }
}
