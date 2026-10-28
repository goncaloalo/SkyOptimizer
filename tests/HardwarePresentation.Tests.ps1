. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
# Pester 3 cannot proxy the CIM cmdlet's generated enum type names. A test-local stub prevents host access.
function Get-PhysicalDisk { throw 'Physical disk access forbidden in presentation tests.' }

Describe 'Hardware observations do not certify performance or security' {
    BeforeEach { $script:text=New-Object 'System.Collections.Generic.List[string]'; $script:empty=$false }
    Mock Write-Host { $script:text.Add(($Object -join ' ')) }
    Mock Clear-Host { }
    Mock Read-Host { '' }
    Mock Get-CimInstance {
        switch ($ClassName) {
            Win32_OperatingSystem { [pscustomobject]@{Caption='Mock Windows';TotalVisibleMemorySize=16777216} }
            Win32_Processor { [pscustomobject]@{Name='Mock CPU'} }
            Win32_ComputerSystem { [pscustomobject]@{TotalPhysicalMemory=16GB} }
            Win32_PhysicalMemory {
                if (-not $script:empty) { 1..2 | ForEach-Object { [pscustomobject]@{Capacity=8GB;ConfiguredClockSpeed=2133;Speed=3200} } }
            }
            Win32_VideoController { [pscustomobject]@{CurrentHorizontalResolution=1920;CurrentVerticalResolution=1080;CurrentRefreshRate=59;Name='Mock GPU'} }
            Win32_StartupCommand { }
            default { throw 'Unexpected CIM call' }
        }
    }
    Mock Get-ItemProperty { [pscustomobject]@{DriverDesc='Mock GPU'} }
    Mock Get-AccurateVramBytes { [pscustomobject]@{Bytes=8GB} }
    Mock Get-PhysicalDisk { [pscustomobject]@{MediaType='SSD';BusType='NVMe'} }
    Mock Get-VbsStatus { 'Desconhecido' }
    Mock Invoke-SkyNativeProcess { throw 'Native command forbidden.' }
    Mock Invoke-SkyNativeCommand { 'Power scheme GUID: 11111111-2222-3333-4444-555555555555 (Mock plan)' }
    It 'does not turn unknown VBS into anti-cheat certification or maximum performance' {
        Show-SystemHardwareInfo
        $out=$script:text -join "`n"
        $out.Contains('nao certifica anti-cheat') | Should Be $true
        $out.Contains('FACEIT Suportados') | Should Be $false
        $out.Contains('Mock plan') | Should Be $true
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
    It 'does not infer memory channels, XMP state or percentage gains from module count and WMI speeds' {
        $null=Invoke-SkyHardwareAudit
        $out=$script:text -join "`n"
        $out.Contains('canais ativos nao confirmados') | Should Be $true
        $out.Contains('nao permitem concluir o estado de XMP') | Should Be $true
        $out.Contains('+25%') | Should Be $false
        $out.Contains('driver reporta 59 Hz') | Should Be $true
    }
    It 'distinguishes missing inventory from a clean system or a detected VM' {
        $script:empty=$true
        $null=Invoke-SkyHardwareAudit
        $out=$script:text -join "`n"
        $out.Contains('isto nao identifica VM') | Should Be $true
        $out.Contains('ausencia/falha de dados nao prova') | Should Be $true
    }
}
