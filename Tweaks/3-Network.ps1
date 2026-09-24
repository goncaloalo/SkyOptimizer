# ==============================================================================
# SkyOptimizer - 3-Network.ps1
# Categoria 3: Otimizações de Rede e Latência (3 Tweaks)
# ==============================================================================

# Carregar funções partilhadas caso ainda não estejam carregadas
$commonPath = Join-Path -Path $PSScriptRoot -ChildPath "0-Common.ps1"
if (Test-Path $commonPath) { . $commonPath }

<#
.SYNOPSIS
    Desativa o Algoritmo de Nagle (TCPNoDelay e TcpAckFrequency).
.DESCRIPTION
    O algoritmo de Nagle combina pequenos pacotes de rede para poupar largura de banda,
    o que introduz atraso (buffer lag/jitter) em jogos online competitivos.
    Esta função força o envio e confirmação imediata de pacotes nas interfaces ativas.
#>
function Optimize-NetworkLatency {
    [CmdletBinding()]
    param()

    $interfacesBase = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Ensure-RegistryPath -KeyPath $interfacesBase
    Backup-RegistryKey -KeyPath $interfacesBase -BackupName "10_Tcpip_Interfaces"

    $interfaces = Get-ChildItem -Path $interfacesBase -ErrorAction SilentlyContinue
    $configuredCount = 0

    foreach ($iface in $interfaces) {
        $props = Get-ItemProperty -Path $iface.PSPath -ErrorAction SilentlyContinue
        # Configurar interfaces ativas (com IP definido ou atribuído por DHCP)
        if ($props.DhcpIPAddress -or $props.IPAddress) {
            Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $iface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $iface.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force
            $configuredCount++
        }
    }

    Write-SkyLog -Message "Algoritmo de Nagle desativado (TCPNoDelay=1, TcpAckFrequency=1) em $configuredCount interface(s) ativa(s)." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Desativa o Network Throttling Index e ajusta o SystemResponsiveness.
.DESCRIPTION
    O Windows restringe por defeito o tráfego de pacotes de rede não multimédia
    a 10 pacotes por milissegundo quando aplicações multimédia estão a correr.
    Definir NetworkThrottlingIndex para FFFFFFFF desativa este estrangulamento.
#>
function Optimize-NetworkThrottling {
    [CmdletBinding()]
    param()

    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Ensure-RegistryPath -KeyPath $profileKey
    Backup-RegistryKey -KeyPath $profileKey -BackupName "11_Multimedia_SystemProfile"

    # 0xFFFFFFFF = Desativa o estrangulamento de pacotes
    Set-ItemProperty -Path $profileKey -Name "NetworkThrottlingIndex" -Value ([uint32]0xFFFFFFFF) -Type DWord -Force
    # 0 = Máxima prioridade para jogos em vez de tarefas de sistema
    Set-ItemProperty -Path $profileKey -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Network Throttling desativado e SystemResponsiveness definido para 0." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Remove o limite de largura de banda reservada do Agendador de Pacotes QoS (Psched).
.DESCRIPTION
    Por defeito, o QoS reserva até 20% da largura de banda para serviços de sistema.
    Definir NonBestEffortLimit para 0 liberta 100% da ligação para o tráfego direto.
#>
function Disable-QoSBandwidthLimit {
    [CmdletBinding()]
    param()

    $pschedKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    Ensure-RegistryPath -KeyPath $pschedKey
    Backup-RegistryKey -KeyPath $pschedKey -BackupName "12_QoS_Psched"

    Set-ItemProperty -Path $pschedKey -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Limite de 20% de largura de banda reservada por QoS desativado (NonBestEffortLimit=0)." -Level "Success"
    return $true
}
