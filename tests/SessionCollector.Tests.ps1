$source=Join-Path $PSScriptRoot '..\benchmarks\Collect-SkySession.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$functions=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)
. ([scriptblock]::Create(($functions | ForEach-Object {$_.Extent.Text}) -join "`n"))

Describe 'Synthetic process collector fixtures; no live readers' {
    Mock Read-SkyLogicalProcessors {8}
    Mock Read-SkyProcessSample {
        [pscustomobject]@{UnreadableProcesses=1;Rows=@(
            [pscustomobject]@{Pid=123;StartTicks=100;CpuSeconds=1;PrivateBytes=1234},
            [pscustomobject]@{Pid=456;StartTicks=200;CpuSeconds=2;PrivateBytes=5678})}
    }
    Mock Start-Sleep {}
    It 'anonymizes identities and preserves unsupported metrics as null' {
        $r=Collect-SkySession -TargetPid 123 -Duration 0 -IntervalMs 1000
        $r.game_process_id | Should Be P001
        $r.samples[0].processes[0].id | Should Be P001
        $r.samples[0].processes[1].id | Should Be P002
        ($null -eq $r.samples[0].processes[0].read_bytes) | Should Be $true
        ($null -eq $r.samples[0].memory.commit_bytes) | Should Be $true
        $r.samples[0].unreadable_processes | Should Be 1
        ($r | ConvertTo-Json -Depth 8) | Should Not Match 'StartTicks|PrivateBytes|Pid'
    }
    It 'rejects missing target identity' {
        {Collect-SkySession -TargetPid 0 -Duration 0 -IntervalMs 1000} | Should Throw
        {Collect-SkySession -TargetPid 999 -Duration 0 -IntervalMs 1000} | Should Throw
    }
}
