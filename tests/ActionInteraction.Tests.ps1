. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Shared resource ownership without Windows changes' {
    BeforeEach {
        $Global:SkyBackupDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $script:values=@{}; $script:writes=0; $script:failSave=$false; $script:failAfterWrite=$false
        $script:resource=ConvertTo-SkyRegistryResource 'HKCU:\Software\SkyInteraction' 'Shared'
        $script:desired=ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 1
        $script:other=ConvertTo-SkyRegistryResource 'HKCU:\Software\SkyInteraction' 'Independent'
    }
    Mock Get-SkyMachineId { 'mock-machine' }
    Mock Get-SkyUserSid { 'mock-user' }
    Mock Open-SkyRegistryBase { throw 'Real registry access forbidden.' }
    Mock Get-SkyResourceState {
        $key=Get-SkyResourceIdentity $Resource
        if ($script:values.ContainsKey($key)) { return $script:values[$key] }
        ConvertTo-SkyRegistryState -Exists $false
    }
    Mock Set-SkyResourceState {
        $script:writes++; $script:values[(Get-SkyResourceIdentity $Resource)]=$State
        if ($script:failAfterWrite) { throw 'failure after mutation' }
    }
    Mock Save-SkyMutationState {
        if ($script:failSave) { throw 'disk unavailable' }
        Write-SkyAtomicFile (Join-Path $BackupDirectory 'mutation_state.json') ($State | ConvertTo-Json -Depth 15)
    }
    It 'shares one immutable baseline in either action order and undoes only after the last release' {
        foreach ($order in @(@(58,84),@(84,58))) {
            (Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId $order[0]).Status | Should Be Applied
            (Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId $order[1]).Status | Should Be AlreadyCompliant
            $journal=Read-SkyMutationState $Global:SkyBackupDir
            $journal.SchemaVersion | Should Be 2
            @($journal.Entries | Where-Object Status -ne 'Restored').Count | Should Be 1
            $entry=@($journal.Entries | Where-Object Status -ne 'Restored')[0]
            $entry.Original.Exists | Should Be $false
            @($entry.OwnerIds).Count | Should Be 2
            $before=$script:writes
            $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId $order[0]
            $script:writes | Should Be $before
            (Get-SkyResourceState $script:resource).Exists | Should Be $true
            $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId $order[1]
            (Get-SkyResourceState $script:resource).Exists | Should Be $false
        }
    }
    It 'treats casing and property order as the same registry resource, not another baseline' {
        $variant=[pscustomobject]@{ Name='sHARED'; View=$script:resource.View; Key='software\skyinteraction'; Hive='HKEY_CURRENT_USER'; Type='Registry' }
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        $null=Invoke-SkyTrackedChange $variant $script:desired -OwnerActionId 84
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 1
        $script:writes | Should Be 1
    }
    It 'rejects opposing desired states from another owner before changing the baseline or value' {
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        $opposite=ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 0
        { Invoke-SkyTrackedChange $script:resource $opposite -OwnerActionId 84 } | Should Throw
        $entry=(Read-SkyMutationState $Global:SkyBackupDir).Entries[0]
        $entry.Desired.Data | Should Be '1'
        (@($entry.OwnerIds) -join ',') | Should Be '58'
        $script:writes | Should Be 1
    }
    It 'does not acquire ownership for an initially compliant resource' {
        $script:values[(Get-SkyResourceIdentity $script:resource)]=$script:desired
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58).Count | Should Be 0
        $script:writes | Should Be 0
    }
    It 'keeps legacy ownership unknown until full Undo, without inventing an action baseline' {
        $null=Invoke-SkyTrackedChange $script:resource $script:desired
        (Read-SkyMutationState $Global:SkyBackupDir).SchemaVersion | Should Be 1
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        $entry=(Read-SkyMutationState $Global:SkyBackupDir).Entries[0]
        (@($entry.OwnerIds) -join ',') | Should Be '0,58'
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58
        (Get-SkyResourceState $script:resource).Exists | Should Be $true
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Get-SkyResourceState $script:resource).Exists | Should Be $false
    }
    It 'does not persist a second owner if its journal write fails' {
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        $script:failSave=$true
        { Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 84 } | Should Throw
        (@((Read-SkyMutationState $Global:SkyBackupDir).Entries[0].OwnerIds) -join ',') | Should Be '58'
        $script:writes | Should Be 1
    }
    It 'retries failed ownership release and interrupted final Undo without rewriting the original state twice' {
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 84
        $script:failSave=$true
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58)[0].Status | Should Be Failed
        (@((Read-SkyMutationState $Global:SkyBackupDir).Entries[0].OwnerIds) -join ',') | Should Be '58,84'
        $script:failSave=$false
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58
        $script:failAfterWrite=$true
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 84)[0].Status | Should Be Failed
        (Get-SkyResourceState $script:resource).Exists | Should Be $false
        $script:failAfterWrite=$false
        $before=$script:writes
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 84)[0].Status | Should Be AlreadyCompliant
        $script:writes | Should Be $before
    }
    It 'preserves an external conflict while restoring independent resources for the selected action' {
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        $null=Invoke-SkyTrackedChange $script:other $script:desired -OwnerActionId 58
        $external=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'external'
        $script:values[(Get-SkyResourceIdentity $script:resource)]=$external
        $results=@(Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58)
        @($results | Where-Object Status -eq 'Failed').Count | Should Be 1
        (Get-SkyResourceState $script:other).Exists | Should Be $false
        (Test-SkyStateEqual (Get-SkyResourceState $script:resource) $external) | Should Be $true
    }
    It 'retries a partial mutation and retains the first baseline across action releases' {
        $script:failAfterWrite=$true
        { Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58 } | Should Throw
        $script:failAfterWrite=$false
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 84
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 58
        (Get-SkyResourceState $script:resource).Exists | Should Be $true
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir -OwnerActionId 84
        (Get-SkyResourceState $script:resource).Exists | Should Be $false
    }
    It 'rejects a duplicate physical resource in reordered journal data and an unsupported schema' {
        $null=Invoke-SkyTrackedChange $script:resource $script:desired -OwnerActionId 58
        $journal=Read-SkyMutationState $Global:SkyBackupDir
        $copy=$journal.Entries[0] | ConvertTo-Json -Depth 15 | ConvertFrom-Json
        $copy.Id=[guid]::NewGuid().ToString()
        $copy.Resource=[pscustomobject]@{ Name='SHARED'; View=$script:resource.View; Key='SOFTWARE\SKYINTERACTION'; Hive='HKEY_CURRENT_USER'; Type='Registry' }
        $journal.Entries=@($journal.Entries)+$copy
        Save-SkyMutationState $journal $Global:SkyBackupDir
        { Restore-SkyTrackedChanges $Global:SkyBackupDir } | Should Throw
        $journal.Entries=@($journal.Entries[0]); $journal.SchemaVersion=99
        Save-SkyMutationState $journal $Global:SkyBackupDir
        { Restore-SkyTrackedChanges $Global:SkyBackupDir } | Should Throw
        $script:writes | Should Be 1
    }
}
