. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
Describe 'Per-run evidence isolates completion cancellation and interrupted attempts' {
    BeforeEach {$Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir);$script:SkyReportRun=$null}
    Mock Assert-SkyNoReparsePoint {}
    Mock New-SkyProtectedDirectory {$null=[IO.Directory]::CreateDirectory($Path)}
    It 'keeps successive run evidence separate and does not adopt legacy results' {
        [IO.File]::WriteAllText((Join-Path $Global:SkyBackupDir 'execution_results.json'),'legacy')
        Invoke-SkyReportRun MAX {Write-SkyReportArtifact execution_results.json '["first"]';$script:SkyLastExitCode=0}
        $first=Get-Content (Join-Path $Global:SkyBackupDir latest_run.json) -Raw | ConvertFrom-Json
        Invoke-SkyReportRun MAX {$script:SkyLastExitCode=2}
        $second=Get-Content (Join-Path $Global:SkyBackupDir latest_run.json) -Raw | ConvertFrom-Json
        $first.RunId | Should Not Be $second.RunId
        $second.Artifacts.Count | Should Be 0
        Test-Path (Join-Path $second.Path execution_results.json) | Should Be $false
        (Get-Content (Join-Path $first.Path execution_results.json) -Raw) | Should Be '["first"]'
        $first.State | Should Be ConfigurationVerified
        $second.State | Should Be IncompleteOrFailed
    }
    It 'records partial failure without inheriting another run and clears active context' {
        {Invoke-SkyReportRun BackgroundLab {Write-SkyReportArtifact plan.json '{}';throw 'simulated interruption'}} | Should Throw
        $r=Get-Content (Join-Path $Global:SkyBackupDir latest_run.json) -Raw | ConvertFrom-Json
        $r.ExitCode | Should Be 1
        $r.Artifacts.Count | Should Be 1
        $r.Ended | Should Not BeNullOrEmpty
        ($null -eq $script:SkyReportRun) | Should Be $true
    }
    It 'updates artifact inventory without duplicating repeated writes' {
        Invoke-SkyReportRun MAX {Write-SkyReportArtifact results.json '[]';Write-SkyReportArtifact results.json '[1]';$script:SkyLastExitCode=0}
        $r=Get-Content (Join-Path $Global:SkyBackupDir latest_run.json) -Raw | ConvertFrom-Json
        $r.Artifacts.Count | Should Be 1
        (Get-Content (Join-Path $r.Path results.json) -Raw) | Should Be '[1]'
    }
    It 'refuses traversal and nested runs without adopting their output' {
        Invoke-SkyReportRun MAX {
            {Write-SkyReportArtifact '../escape.json' '{}'} | Should Throw
            {Invoke-SkyReportRun MAX {throw 'nested'}} | Should Throw
            $script:SkyLastExitCode=2
        }
    }
    It 'does not run a mutator if initial metadata cannot be persisted' {
        Mock Write-SkyAtomicFile {throw 'disk full'}
        $script:ran=$false
        {Invoke-SkyReportRun MAX {$script:ran=$true}} | Should Throw
        $script:ran | Should Be $false
        ($null -eq $script:SkyReportRun) | Should Be $true
    }
}
