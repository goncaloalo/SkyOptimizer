. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Panel shares the original backup directory without copying' {
    It 'accepts equivalent paths without rewriting the existing baseline' {
        $folder = Join-Path $TestDrive 'Backups'
        $null = [IO.Directory]::CreateDirectory($folder)
        $baseline = Join-Path $folder 'mutation_state.json'
        [IO.File]::WriteAllText($baseline, 'original baseline')
        Assert-SkyPanelBackupDirectory -ActiveDirectory "$folder\" -PanelDirectory $folder.ToUpperInvariant()
        [IO.File]::ReadAllText($baseline) | Should Be 'original baseline'
    }
    It 'refuses distinct backup directories without replacing either baseline' {
        $first = Join-Path $TestDrive 'First'
        $second = Join-Path $TestDrive 'Second'
        foreach ($folder in @($first, $second)) { $null = [IO.Directory]::CreateDirectory($folder) }
        [IO.File]::WriteAllText((Join-Path $first 'mutation_state.json'), 'first baseline')
        [IO.File]::WriteAllText((Join-Path $second 'mutation_state.json'), 'second baseline')
        { Assert-SkyPanelBackupDirectory $first $second } | Should Throw
        [IO.File]::ReadAllText((Join-Path $first 'mutation_state.json')) | Should Be 'first baseline'
        [IO.File]::ReadAllText((Join-Path $second 'mutation_state.json')) | Should Be 'second baseline'
    }
    It 'refuses missing directories and empty paths' {
        $missing = Join-Path $TestDrive 'Missing'
        { Assert-SkyPanelBackupDirectory $missing $missing } | Should Throw
        { Assert-SkyPanelBackupDirectory '' '' } | Should Throw
    }
}

Describe 'Evidence-scoped development profiles' {
    Mock Get-SkyWindowsBuild { 22631 }
    It 'keeps Balanced small and does not disable captures, services or offloads' {
        (@(Get-SkyProfileActionIds Balanced) -join ',') | Should Be '79'
    }
    It 'adds only documented background mechanisms to Performance' {
        (@(Get-SkyProfileActionIds Performance) -join ',') | Should Be '9,41,79'
    }
    It 'requires explicit experimental IDs and resolves the owned-power dependency' {
        (@(Get-SkyProfileActionIds Extreme) -join ',') | Should Be '9,41,79'
        (@(Get-SkyProfileActionIds Extreme -Experiments @(3,3,74)) -join ',') | Should Be '1,3,9,41,74,79'
        { Get-SkyProfileActionIds Balanced -Experiments @(3) } | Should Throw
        { Get-SkyProfileActionIds Extreme -Experiments @(91) } | Should Throw
    }
    It 'never executes unmigrated experiments or actions outside the selection' {
        (Invoke-SkyEligibleAction -Id 78 -SelectedIds @(78) -Action { throw 'must not execute' }).Status | Should Be Deferred
        (Invoke-SkyEligibleAction -Id 9 -SelectedIds @(79) -Action { throw 'must not execute' }).Status | Should Be NotSelected
    }
    It 'executes a selected migrated action without interpreting legacy booleans as success' {
        (Invoke-SkyEligibleAction -Id 79 -SelectedIds @(79) -Action { $true }).Status | Should Be Unverified
    }
    It 'rejects duplicate managed graphics flags rather than losing unknown settings' {
        { Merge-SkyGraphicsFlag 'SwapEffectUpgradeEnable=0;Other=1;SwapEffectUpgradeEnable=1;' } | Should Throw
        (Merge-SkyGraphicsFlag 'Other=1') | Should Be 'Other=1;SwapEffectUpgradeEnable=1;'
        (Merge-SkyGraphicsFlag '') | Should Be 'SwapEffectUpgradeEnable=1;'
    }
}

Describe 'Explicit shader maintenance without filesystem deletion' {
    BeforeEach { $script:answer = 'N'; $script:deleteFails = $false }
    Mock Read-Host { $script:answer }
    Mock Get-SkyShaderCacheFiles { [pscustomobject]@{ FullName = 'C:\FakeCache\file.bin' } }
    Mock Remove-Item { if ($script:deleteFails) { throw 'locked' } }
    Mock Test-Path { $false }
    Mock Start-ScheduledTask { throw 'Broad cleanup must not run.' }
    It 'preserves caches when diagnostic deletion is not confirmed' {
        (Clear-ShaderCache).Status | Should Be NotSelected
        Assert-MockCalled Remove-Item -Times 0 -Exactly -Scope It
    }
    It 'reports locked files as failures instead of counting false success' {
        $script:answer = 'S'; $script:deleteFails = $true
        $result = Clear-ShaderCache
        $result.Status | Should Be Failed
        $result.Reason.Contains('0 ficheiros removidos, 1 falhas') | Should Be $true
        Assert-MockCalled Start-ScheduledTask -Times 0 -Exactly -Scope It
    }
    It 'deletes only enumerated literal files and confirms their absence' {
        $script:answer = 'S'
        (Clear-ShaderCache).Status | Should Be Applied
        Assert-MockCalled Remove-Item -Times 1 -Exactly -Scope It -ParameterFilter { $LiteralPath -eq 'C:\FakeCache\file.bin' -and -not $Recurse }
        Assert-MockCalled Start-ScheduledTask -Times 0 -Exactly -Scope It
    }
}
