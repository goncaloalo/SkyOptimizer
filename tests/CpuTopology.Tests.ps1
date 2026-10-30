. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
# Synthetic Windows ABI records; no CPU API, process affinity or hardware readers execute.
function New-SkySyntheticCpuRecord {
    param([uint32]$Id=900,[uint16]$Group=0,[byte]$Logical=0,[byte]$Core=0,[byte]$Cache=0,[byte]$Numa=0,[byte]$Efficiency=0,[uint32]$Size=32,[uint32]$Type=0)
    $b=New-Object byte[] ([int]$Size)
    [BitConverter]::GetBytes($Size).CopyTo($b,0);[BitConverter]::GetBytes($Type).CopyTo($b,4)
    if($Size -ge 32){[BitConverter]::GetBytes($Id).CopyTo($b,8);[BitConverter]::GetBytes($Group).CopyTo($b,12)
        $b[14]=$Logical;$b[15]=$Core;$b[16]=$Cache;$b[17]=$Numa;$b[18]=$Efficiency}
    ,$b
}

Describe 'CPU Set parser with labelled synthetic buffers' {
    Mock Invoke-SkyCpuSetNativeQuery {throw 'No native call in parser tests'}
    It 'keeps OS CPU Set ID separate from group-relative logical, core, cache and NUMA indices' {
        $b=[byte[]]((New-SkySyntheticCpuRecord -Id 901 -Group 0 -Logical 2 -Core 1 -Cache 3 -Numa 4 -Efficiency 8)+(New-SkySyntheticCpuRecord -Id 902 -Group 1 -Logical 2 -Core 1 -Cache 3 -Numa 4 -Efficiency 0))
        $p=ConvertFrom-SkyCpuSetBuffer $b
        $p.Status | Should Be Observed
        $p.LogicalProcessors.Count | Should Be 2
        $p.LogicalProcessors[0].CpuSetId | Should Be 901
        $p.LogicalProcessors[0].LogicalProcessorIndex | Should Be 2
        $p.LogicalProcessors[0].CoreIndex | Should Be 1
        $p.LogicalProcessors[0].LastLevelCacheIndex | Should Be 3
        $p.LogicalProcessors[0].NumaNodeIndex | Should Be 4
        $p.LogicalProcessors[1].Group | Should Be 1
        $p.HeterogeneousEfficiencyClasses | Should Be $true
        $p.X3DTopology | Should Be Unknown
        $p.CcdTopology | Should Be Unknown
        Assert-MockCalled Invoke-SkyCpuSetNativeQuery -Times 0 -Exactly -Scope It
    }
    It 'steps by Size, skips unknown types and accepts larger future known records' {
        $b=[byte[]]((New-SkySyntheticCpuRecord -Size 8 -Type 99)+(New-SkySyntheticCpuRecord -Size 40))
        $p=ConvertFrom-SkyCpuSetBuffer $b
        $p.LogicalProcessors.Count | Should Be 1
        $p.UnknownRecordTypesSkipped | Should Be 1
        $p.HeterogeneousEfficiencyClasses | Should Be $false
    }
    It 'does not equate a single efficiency class with a proven homogeneous or X3D topology' {
        $p=ConvertFrom-SkyCpuSetBuffer (New-SkySyntheticCpuRecord)
        $p.HeterogeneousEfficiencyClasses | Should Be $false
        $p.Limitation | Should Match 'does not prove'
        $p.X3DTopology | Should Be Unknown
    }
    It 'rejects empty, short, zero-size, overflowing and truncated known records' {
        {ConvertFrom-SkyCpuSetBuffer -Buffer ([byte[]]@())} | Should Throw
        {ConvertFrom-SkyCpuSetBuffer -Buffer ([byte[]]@(1,2,3))} | Should Throw
        {ConvertFrom-SkyCpuSetBuffer -Buffer (New-Object byte[] 8)} | Should Throw
        $b=New-SkySyntheticCpuRecord;[BitConverter]::GetBytes([uint32]100).CopyTo($b,0)
        {ConvertFrom-SkyCpuSetBuffer $b} | Should Throw
        {ConvertFrom-SkyCpuSetBuffer (New-SkySyntheticCpuRecord -Size 24)} | Should Throw
        {ConvertFrom-SkyCpuSetBuffer (New-SkySyntheticCpuRecord -Size 8 -Type 99)} | Should Throw
    }
    It 'rejects duplicate OS IDs and duplicate group-relative logical identities' {
        {ConvertFrom-SkyCpuSetBuffer ([byte[]]((New-SkySyntheticCpuRecord)+(New-SkySyntheticCpuRecord -Logical 1)))} | Should Throw
        {ConvertFrom-SkyCpuSetBuffer ([byte[]]((New-SkySyntheticCpuRecord)+(New-SkySyntheticCpuRecord -Id 901)))} | Should Throw
    }
}

Describe 'CPU Set two-call buffer reader with native query mocked' {
    BeforeEach {$script:queryError=122;$script:querySize=32;$script:readSuccess=$true;$script:returned=32}
    Mock Add-Type {throw 'Native type must not compile in tests'}
    Mock Invoke-SkyCpuSetNativeQuery {
        if($Length -eq 0){return [pscustomobject]@{Success=$false;ErrorCode=$script:queryError;ReturnedLength=$script:querySize}}
        (New-SkySyntheticCpuRecord).CopyTo($Buffer,0)
        [pscustomobject]@{Success=$script:readSuccess;ErrorCode=122;ReturnedLength=$script:returned}
    }
    It 'requests bounded buffer then returns bytes without native execution' {
        $b=Get-SkyCpuSetBuffer
        $b.GetType().FullName | Should Be 'System.Byte[]'
        $b.Length | Should Be 32
        (ConvertFrom-SkyCpuSetBuffer $b).Status | Should Be Observed
        Assert-MockCalled Add-Type -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SkyCpuSetNativeQuery -Times 1 -Exactly -Scope It -ParameterFilter {$Length -eq 0 -and $null -eq $Buffer}
    }
    It 'fails closed on API errors, empty size and oversized allocation requests' {
        $script:queryError=5;{Get-SkyCpuSetBuffer} | Should Throw
        $script:queryError=122;$script:querySize=0;{Get-SkyCpuSetBuffer} | Should Throw
        $script:querySize=16777217;{Get-SkyCpuSetBuffer} | Should Throw
    }
    It 'does not consume output after failure or growth between size and data query' {
        $script:readSuccess=$false;{Get-SkyCpuSetBuffer} | Should Throw
        $script:readSuccess=$true;$script:returned=40;{Get-SkyCpuSetBuffer} | Should Throw
        $script:returned=0;{Get-SkyCpuSetBuffer} | Should Throw
    }
}

Describe 'CPU topology reader surfaces unknown instead of guessing' {
    BeforeEach {$script:throwRead=$false;$script:buffer=New-SkySyntheticCpuRecord}
    Mock Get-SkyCpuSetBuffer {if($script:throwRead){throw 'unavailable'};,$script:buffer}
    Mock Invoke-SkyCpuSetNativeQuery {throw 'No native call'}
    It 'reports structured topology only after successful parse' {
        (Get-SkyCpuTopology).Status | Should Be Observed
    }
    It 'returns Unknown for unavailable API and malformed output' {
        $script:throwRead=$true;(Get-SkyCpuTopology).Status | Should Be Unknown
        $script:throwRead=$false;$script:buffer=[byte[]]@(1,2,3)
        $p=Get-SkyCpuTopology
        $p.Status | Should Be Unknown
        ($null -eq $p.HeterogeneousEfficiencyClasses) | Should Be $true
        $p.LogicalProcessors.Count | Should Be 0
    }
}
