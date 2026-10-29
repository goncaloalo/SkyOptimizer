# Explicit laboratory collector; never starts a game or changes configuration.
[CmdletBinding()]
param([int]$GameProcessId, [ValidateRange(1,1800)][int]$Seconds=150,
    [ValidateRange(250,5000)][int]$IntervalMilliseconds=1000,
    [string]$OutputPath, [switch]$ExecuteAuthorizedLabCapture)

function Read-SkyProcessSample {
    $failed = 0
    $rows = @(foreach ($process in Get-Process -ErrorAction Stop) {
        try {
            [pscustomobject]@{ Pid=$process.Id; StartTicks=$process.StartTime.ToUniversalTime().Ticks
                CpuSeconds=$process.TotalProcessorTime.TotalSeconds; PrivateBytes=$process.PrivateMemorySize64 }
        } catch { $failed++ }
        finally { $process.Dispose() }
    })
    [pscustomobject]@{ Rows=$rows; UnreadableProcesses=$failed }
}

function Read-SkyLogicalProcessors {
    $count=(Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).NumberOfLogicalProcessors
    if (-not $count -or $count -gt 64) { throw 'Unknown or >64 logical CPUs; processor-group normalization not supported.' }
    [int]$count
}

function Collect-SkySession {
    param([int]$TargetPid, [int]$Duration, [int]$IntervalMs)
    if ($TargetPid -lt 1) { throw 'A positive target PID is required.' }
    $logicalProcessors=Read-SkyLogicalProcessors
    $identities = @{}; $lifetimes = @{}; $nextId=2; $nextLife=1
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $samples=New-Object Collections.Generic.List[object]
    do {
        $begin=$watch.Elapsed.TotalSeconds
        $read=Read-SkyProcessSample
        if ($samples.Count -eq 0 -and $TargetPid -notin $read.Rows.Pid) { throw 'Target absent or unreadable; capture unavailable.' }
        $processes=@(foreach($row in $read.Rows) {
            $pidKey=[string]$row.Pid; $lifeKey="$pidKey/$($row.StartTicks)"
            if (-not $identities.ContainsKey($pidKey)) {
                if ($row.Pid -eq $TargetPid) { $identities[$pidKey]='P001' }
                else {
                    if ($nextId -gt 999) { throw 'Anonymous process identity capacity exceeded; capture incomplete.' }
                    $identities[$pidKey]='P{0:D3}' -f $nextId; $nextId++
                }
            }
            if (-not $lifetimes.ContainsKey($lifeKey)) {
                if ($nextLife -gt 999) { throw 'Lifetime capacity exceeded; capture incomplete.' }
                $lifetimes[$lifeKey]='L{0:D3}' -f $nextLife; $nextLife++
            }
            [pscustomobject]@{ id=$identities[$pidKey]; lifetime=$lifetimes[$lifeKey]
                cpu_seconds=$row.CpuSeconds; private_bytes=$row.PrivateBytes; read_bytes=$null; write_bytes=$null }
        })
        $samples.Add([pscustomobject]@{ seconds=$begin; processes=$processes
            memory=@{available_bytes=$null;commit_bytes=$null;commit_limit_bytes=$null}
            collection_seconds=$watch.Elapsed.TotalSeconds-$begin; unreadable_processes=$read.UnreadableProcesses })
        if ($watch.Elapsed.TotalSeconds -ge $Duration) { break }
        Start-Sleep -Milliseconds $IntervalMs
    } while ($true)
    [pscustomobject]@{ schema_version=1; clock='relative_monotonic_seconds'
        logical_processors=$logicalProcessors; game_process_id='P001'; samples=@($samples.ToArray())
        collector='Sky process sampler; .NET Process; no physical input latency or disk telemetry'
        sampling_limit='Sequential process reads, boundary timestamps; short spikes and inaccessible processes may be missed.' }
}

if (-not $ExecuteAuthorizedLabCapture) { throw 'Capture disabled. Explicit laboratory capture switch required.' }
if ($PSVersionTable.PSEdition -ne 'Desktop' -or -not [Environment]::Is64BitProcess) { throw 'Requires x64 Windows PowerShell 5.1.' }
if (-not $OutputPath) { throw 'OutputPath required.' }
# Reserve the output before collecting, so an existing file is never overwritten.
$stream=[IO.File]::Open($OutputPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
    $session=Collect-SkySession -TargetPid $GameProcessId -Duration $Seconds -IntervalMs $IntervalMilliseconds
    $writer=New-Object IO.StreamWriter($stream,(New-Object Text.UTF8Encoding($false)))
    try { $writer.Write(($session | ConvertTo-Json -Depth 8)); $writer.Flush() } finally { $writer.Dispose() }
} finally { $stream.Dispose() }
