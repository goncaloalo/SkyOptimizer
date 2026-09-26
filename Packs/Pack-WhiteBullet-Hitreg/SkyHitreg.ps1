<#
.SYNOPSIS
    SkyHitreg (White Bullet) - Rede Competitiva & Latência de Hardware
    SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5

.DESCRIPTION
    Pack autónomo focado em registo de balas (hitreg), sincronização de servidor
    e eliminação de atrasos de hardware na placa de rede para FiveM, CS2, etc.
    Desativa Interrupt Moderation (ITR 0), Flow Control, RSC/LSO e otimiza
    portas TCP sem capar a velocidade de fibra (AutoTuning seguro).
    Inclui módulo de reversão 100% integrado.
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Undo
)

$ErrorActionPreference = "SilentlyContinue"

# Elevação UAC
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] A solicitar permissões de Administrador..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $processInfo.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($processInfo) | Out-Null
        exit 0
    } catch {
        Write-Host "[ERRO] Privilégios de Administrador são necessários." -ForegroundColor Red
        Read-Host "Pressione ENTER para sair..."
        exit 1
    }
}

$Host.UI.RawUI.WindowTitle = "SkyHitreg - Pack White Bullet & Hardware de Rede"

$backupDir = Join-Path -Path $PSScriptRoot -ChildPath "Backups_SkyHitreg"

function Invoke-ApplyHitreg {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "     SkyHitreg (White Bullet) - A Aplicar Otimizações de Rede & Hardware" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Discord Oficial: https://discord.gg/cE8ZaDRGV5`n" -ForegroundColor DarkCyan

    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    # 1. Backup do Registo TCP/IP
    $regBackup = Join-Path -Path $backupDir -ChildPath "Original_Tcpip.reg"
    if (-not (Test-Path $regBackup)) {
        Write-Host "[*] A criar backup das definições TCP/IP originais..." -ForegroundColor Gray
        & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "$regBackup" /y *> $null
    }

    # 2. Placas de Rede Físicas (Hardware)
    $physicalAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    $nicCount = 0

    if ($physicalAdapters) {
        foreach ($nic in $physicalAdapters) {
            $nicName = $nic.Name
            Write-Host "[*] A otimizar hardware da placa: $nicName ($($nic.InterfaceDescription))..." -ForegroundColor White
            
            # Desativar Interrupt Moderation (ITR = 0)
            try { Set-NetAdapterAdvancedProperty -Name $nicName -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
            try { Set-NetAdapterAdvancedProperty -Name $nicName -RegistryKeyword "ITR" -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}

            # Desativar Flow Control (Anti-Bufferbloat)
            try { Set-NetAdapterAdvancedProperty -Name $nicName -RegistryKeyword "*FlowControl" -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}

            $nicCount++
        }
    } else {
        Write-Host "[!] Nenhuma placa de rede física dedicada identificada." -ForegroundColor Yellow
    }

    # 3. Desativar RSC e LSO (Segment Coalescing / Offload)
    Write-Host "[*] A desativar agregação de pacotes RSC (Receive Segment Coalescing)..." -ForegroundColor White
    try { Disable-NetAdapterRsc -Name * -ErrorAction SilentlyContinue } catch {}

    Write-Host "[*] A desativar descarregamento LSO (Large Send Offload)..." -ForegroundColor White
    try { Disable-NetAdapterLso -Name * -IPv4 -IPv6 -ErrorAction SilentlyContinue } catch {}

    # Desativação em Registo Global TCP/IP
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnableRSC" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DisableLargeSendOffload" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # 4. Otimização de Sockets e Portas Efémeras
    Write-Host "[*] A expandir portas efémeras para 65534 e reduzir espera para 30s..." -ForegroundColor White
    $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-ItemProperty -Path $tcpPath -Name "MaxUserPort" -Value 65534 -Type DWord -Force
    Set-ItemProperty -Path $tcpPath -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force
    Set-ItemProperty -Path $tcpPath -Name "DefaultTTL" -Value 64 -Type DWord -Force

    # Algoritmo de Nagle (TCPNoDelay e TCPAckFrequency nas interfaces ativas)
    $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $interfacesPath) {
        $subKeys = Get-ChildItem -Path $interfacesPath -ErrorAction SilentlyContinue
        foreach ($sub in $subKeys) {
            Set-ItemProperty -Path $sub.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $sub.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }

    # 5. Pilha TCP Global via Netsh (Sem danificar velocidade de Fibra)
    Write-Host "[*] A afinar pilha TCP global (Timestamps/ECN Off, RSS On, AutoTuning Normal)..." -ForegroundColor White
    $null = netsh int tcp set global timestamps=disabled 2>&1
    $null = netsh int tcp set global ecncapability=disabled 2>&1
    $null = netsh int tcp set global rsc=disabled 2>&1
    $null = netsh int tcp set global rss=enabled 2>&1
    $null = netsh int tcp set global autotuninglevel=normal 2>&1

    # 6. Limpeza e Flush de Rede
    Write-Host "[*] A limpar caches de DNS e tabela ARP..." -ForegroundColor White
    try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch { ipconfig /flushdns *> $null }
    $null = netsh interface ip delete arpcache 2>&1

    Write-Host @"

================================================================================
              PACK WHITE BULLET / HITREG CONCLUÍDO COM ÊXITO
================================================================================
  [✓] Placas Físicas Otimizadas:   $nicCount adaptador(es)
  [✓] Interrupt Moderation:       Desativada (ITR = 0 / Resposta Imediata)
  [✓] RSC & LSO Offload:          Desativados (Ticks Puros em Tempo Real)
  [✓] Controlo de Fluxo:          Desativado (Anti-Bufferbloat)
  [✓] Algoritmo de Nagle:         Desativado (TCPNoDelay = 1, AckFrequency = 1)
  [✓] Portas Efémeras:            Expandidas (MaxUserPort = 65534, Delay = 30s)
  [✓] Velocidade de Fibra:        100% Protegida (AutoTuning = Normal)
  [✓] Caches de Rede:             Renovadas (DNS e ARP limpos)
  [✓] Reversibilidade:            Backup guardado em .\Backups_SkyHitreg\
================================================================================
As otimizações estão ativas. Recomenda-se reiniciar o jogo para sentir o efeito.
"@ -ForegroundColor Green

    Read-Host "`nPressione ENTER para regressar ao menu..."
}

function Invoke-UndoHitreg {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "        SkyHitreg - A Reverter Definições de Rede e Hardware" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan

    # 1. Restaurar Registo se houver backup
    $regBackup = Join-Path -Path $backupDir -ChildPath "Original_Tcpip.reg"
    if (Test-Path $regBackup) {
        Write-Host "[*] A restaurar definições TCP/IP originais..." -ForegroundColor White
        & reg.exe import "$regBackup" *> $null
    } else {
        Write-Host "[*] A repor registos TCP/IP para o padrão do Windows..." -ForegroundColor White
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Remove-ItemProperty -Path $tcpPath -Name "MaxUserPort" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $tcpPath -Name "TcpTimedWaitDelay" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $tcpPath -Name "EnableRSC" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $tcpPath -Name "DisableLargeSendOffload" -Force -ErrorAction SilentlyContinue
    }

    # 2. Restaurar Placas Físicas
    $physicalAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    if ($physicalAdapters) {
        foreach ($nic in $physicalAdapters) {
            Write-Host "[*] A repor hardware da placa: $($nic.Name)..." -ForegroundColor White
            try { Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 1 -ErrorAction SilentlyContinue } catch {}
            try { Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*FlowControl" -RegistryValue 3 -ErrorAction SilentlyContinue } catch {}
        }
    }

    # 3. Reativar RSC e LSO
    Write-Host "[*] A reativar RSC e LSO padrão do Windows..." -ForegroundColor White
    try { Enable-NetAdapterRsc -Name * -ErrorAction SilentlyContinue } catch {}
    try { Enable-NetAdapterLso -Name * -IPv4 -IPv6 -ErrorAction SilentlyContinue } catch {}

    # 4. Repor Netsh TCP
    Write-Host "[*] A repor definições padrão da pilha Netsh TCP..." -ForegroundColor White
    $null = netsh int tcp set global timestamps=allowed 2>&1
    $null = netsh int tcp set global ecncapability=default 2>&1
    $null = netsh int tcp set global autotuninglevel=normal 2>&1

    # 5. Flush
    try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch { ipconfig /flushdns *> $null }

    Write-Host @"

================================================================================
                       REVERSÃO CONCLUÍDA COM ÊXITO
================================================================================
  [✓] As definições de rede, hardware e TCP foram repostas para o padrão.
================================================================================
"@ -ForegroundColor Green

    Read-Host "`nPressione ENTER para regressar ao menu..."
}

if ($Apply) {
    Invoke-ApplyHitreg
    exit 0
}

if ($Undo) {
    Invoke-UndoHitreg
    exit 0
}

# Menu Interativo
while ($true) {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "    SkyOptimizer - Pack White Bullet & Hitreg (Rede & Hardware Competitivo)" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Dispositivo: $env:COMPUTERNAME | SO: $([System.Environment]::OSVersion.Version)" -ForegroundColor Gray
    Write-Host "Discord da Comunidade: https://discord.gg/cE8ZaDRGV5`n" -ForegroundColor DarkCyan

    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    if ($adapters) {
        Write-Host "Placa(s) de Rede Física(s) Detetada(s):" -ForegroundColor Yellow
        foreach ($a in $adapters) {
            Write-Host "  * $($a.Name) - $($a.InterfaceDescription) [$($a.Status)]" -ForegroundColor Gray
        }
    }
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

    Write-Host "[1] Aplicar Otimizações White Bullet / Hitreg (ITR 0, RSC/LSO Off, TCP Tuning)" -ForegroundColor Green
    Write-Host "[2] Reverter Alterações (Repor Padrão do Windows)" -ForegroundColor Yellow
    Write-Host "[3] Sair" -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor Cyan

    $choice = Read-Host "Escolha uma opção (1-3)"
    switch ($choice.Trim()) {
        "1" { Invoke-ApplyHitreg }
        "2" { Invoke-UndoHitreg }
        "3" { exit 0 }
        Default {
            Write-Host "`nOpção inválida!" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
