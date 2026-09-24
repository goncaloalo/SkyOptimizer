<#
.SYNOPSIS
    SkyOptimizer - Toolkit Modular, Não-Destrutivo e Reversível de Otimização Windows 10/11.
.DESCRIPTION
    Aplica 18 otimizações de baixa latência e alto desempenho em sistemas Windows de uso diário,
    sem remover aplicações de sistema, sem tocar em ficheiros protegidos e com backups completos
    (Ponto de Restauro + backups de registo .reg + manifesto de estado).
.NOTES
    Autor: SkyOS Team
    Versão: 1.0.0
    Requisitos: Windows 10 / 11, PowerShell 5.1+, Privilégios de Administrador
#>

# ------------------------------------------------------------------------------
# 1. AUTO-ELEVAÇÃO PARA ADMINISTRADOR
# ------------------------------------------------------------------------------
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$currentUser
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Privilégios de Administrador necessários. A reiniciar com elevação..." -ForegroundColor Yellow
    $argsList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -ArgumentList $argsList -Verb RunAs
    exit
}

# ------------------------------------------------------------------------------
# 2. INICIALIZAÇÃO DE AMBIENTE E MÓDULOS
# ------------------------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = "SkyOptimizer v1.0.0 [Administrador]"
$scriptDir = $PSScriptRoot

# Importar Módulos da pasta Tweaks
$tweaksDir = Join-Path -Path $scriptDir -ChildPath "Tweaks"
$commonModule = Join-Path -Path $tweaksDir -ChildPath "0-Common.ps1"

if (-not (Test-Path $commonModule)) {
    Write-Error "Ficheiro de módulos comum não encontrado em: $commonModule"
    Read-Host "Pressione ENTER para sair..."
    exit 1
}

# Carregar funções partilhadas
. $commonModule

# Carregar cada categoria de tweaks
$modules = @("1-System.ps1", "2-Gaming.ps1", "3-Network.ps1", "4-Privacy.ps1", "5-Explorer.ps1")
foreach ($mod in $modules) {
    $modPath = Join-Path -Path $tweaksDir -ChildPath $mod
    if (Test-Path $modPath) {
        . $modPath
    } else {
        Write-SkyLog -Message "Módulo '$mod' não encontrado em $tweaksDir" -Level "Warning"
    }
}

# ------------------------------------------------------------------------------
# 3. APRESENTAÇÃO / BANNER
# ------------------------------------------------------------------------------
Clear-Host
$banner = @"
================================================================================
  ____  _            ___        _   _           _              
 / ___|| | _____   _/ _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __ 
 \___ \| |/ / | | | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
  ___) |   <| |_| | |_| | |_) | |_| | | | | | | |/ /  __/ |   
 |____/|_|\_\\__, |\___/| .__/ \__|_|_| |_| |_|_/___\___|_|   
             |___/      |_|                                    
                 Windows 10/11 Performance Toolkit
                          Versão: 1.0.0
================================================================================
"@
Write-Host $banner -ForegroundColor Cyan
Write-SkyLog -Message "Início da sessão SkyOptimizer v1.0.0 em $env:COMPUTERNAME ($((Get-CimInstance Win32_OperatingSystem).Caption))" -Level "Info" -NoConsole

# ------------------------------------------------------------------------------
# 4. CRIAÇÃO DE PONTO DE RESTAURO DO SISTEMA (SYSTEM RESTORE POINT)
# ------------------------------------------------------------------------------
Write-Host "`n>>> [Passo 1/2] Segurança do Sistema" -ForegroundColor Magenta
Write-Host "A verificar / criar Ponto de Restauro do Sistema antes de aplicar alterações..." -ForegroundColor Gray

$restorePointCreated = $false
try {
    # Tentar ativar o Restauro do Sistema na drive de sistema se estiver inativo
    Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
    
    # Criar Ponto de Restauro
    Checkpoint-Computer -Description "SkyOptimizer Pre-Tweak" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-SkyLog -Message "Ponto de Restauro criado: 'SkyOptimizer Pre-Tweak'" -Level "Success"
    $restorePointCreated = $true
} catch {
    $errMessage = $_.Exception.Message
    Write-SkyLog -Message "Não foi possível criar o Ponto de Restauro automaticamente. Motivo: $errMessage" -Level "Warning"
    Write-Host "`n[!] ATENÇÃO:" -ForegroundColor Yellow
    Write-Host "    O Windows pode restringir a frequência de criação de pontos de restauro (limite de 24h)" -ForegroundColor Gray
    Write-Host "    ou a funcionalidade de Proteção do Sistema pode estar desativada." -ForegroundColor Gray
    Write-Host "    Nota: Todos os backups de registo (.reg) e ficheiros de reversão continuarão a ser criados.`n" -ForegroundColor Gray

    $confirm = Read-Host "Deseja continuar com as otimizações mesmo assim? (S/N)"
    if ($confirm -notmatch '^(s|sim|y|yes)$') {
        Write-Host "`nOperação cancelada pelo utilizador com segurança." -ForegroundColor Yellow
        Write-SkyLog -Message "Execução cancelada pelo utilizador devido à ausência de Ponto de Restauro." -Level "Warning"
        Start-Sleep -Seconds 2
        exit 0
    }
}

# ------------------------------------------------------------------------------
# 5. EXECUÇÃO DOS 18 TWEAKS EM 5 CATEGORIAS
# ------------------------------------------------------------------------------
Write-Host "`n>>> [Passo 2/2] A executar Otimizações Seguras (18 Tweaks)" -ForegroundColor Magenta
Write-Host "Todas as chaves de registo alteradas são guardadas em .\Backups\`n" -ForegroundColor Gray

$tweaks = @(
    # Categoria 1: Sistema e Desempenho
    [ordered]@{ Id = 1;  Category = "Sistema & Desempenho"; Name = "Plano de Energia 'Desempenho Máximo'"; Action = { Set-UltimatePowerPlan } },
    [ordered]@{ Id = 2;  Category = "Sistema & Desempenho"; Name = "Resolução de Temporizador Global & Dynamic Tick"; Action = { Set-TimerResolution } },
    [ordered]@{ Id = 3;  Category = "Sistema & Desempenho"; Name = "Desativação de Core Parking de CPU"; Action = { Disable-CoreParking } },
    [ordered]@{ Id = 4;  Category = "Sistema & Desempenho"; Name = "Desativação de Hibernação (Libertar hiberfil.sys)"; Action = { Disable-Hibernation } },
    [ordered]@{ Id = 5;  Category = "Sistema & Desempenho"; Name = "Desativação de Fault Tolerant Heap (FTH)"; Action = { Disable-FaultTolerantHeap } },
    [ordered]@{ Id = 6;  Category = "Sistema & Desempenho"; Name = "SysMain / Superfetch (Inteligente para SSD)"; Action = { Disable-Superfetch } },

    # Categoria 2: Input e Gaming
    [ordered]@{ Id = 7;  Category = "Input & Gaming"; Name = "Desativação de Aceleração de Rato (1:1 Raw Input)"; Action = { Disable-MouseAcceleration } },
    [ordered]@{ Id = 8;  Category = "Input & Gaming"; Name = "Desativação de Suspensão Seletiva USB"; Action = { Disable-USBSelectiveSuspend } },
    [ordered]@{ Id = 9;  Category = "Input & Gaming"; Name = "Desativação de Gravação Xbox Game DVR / Game Bar"; Action = { Disable-GameDVR } },

    # Categoria 3: Otimizações de Rede
    [ordered]@{ Id = 10; Category = "Rede & Latência"; Name = "Algoritmo de Nagle (TCPNoDelay & TCPAckFrequency)"; Action = { Optimize-NetworkLatency } },
    [ordered]@{ Id = 11; Category = "Rede & Latência"; Name = "Network Throttling Index & SystemResponsiveness"; Action = { Optimize-NetworkThrottling } },
    [ordered]@{ Id = 12; Category = "Rede & Latência"; Name = "Remoção de Limite de Banda Reservada QoS (Psched)"; Action = { Disable-QoSBandwidthLimit } },

    # Categoria 4: Privacidade e Limpeza Leve
    [ordered]@{ Id = 13; Category = "Privacidade & Limpeza"; Name = "Telemetria no Nível Básico/Necessário (Seguro)"; Action = { Set-TelemetryBasic } },
    [ordered]@{ Id = 14; Category = "Privacidade & Limpeza"; Name = "Desativação de Sugestões e Anúncios no Menu Iniciar"; Action = { Disable-StartMenuSuggestions } },
    [ordered]@{ Id = 15; Category = "Privacidade & Limpeza"; Name = "Desativação de Pesquisa Web Bing e Dicas do Spotlight"; Action = { Disable-SearchAndSpotlight } },
    [ordered]@{ Id = 16; Category = "Privacidade & Limpeza"; Name = "Desativação de Widgets e Feeds da Barra de Tarefas"; Action = { Disable-TaskbarWidgets } },

    # Categoria 5: Explorador de Ficheiros e QoL
    [ordered]@{ Id = 17; Category = "Explorador & QoL"; Name = "Exibição de Extensões de Ficheiros Conhecidos"; Action = { Show-FileExtensions } },
    [ordered]@{ Id = 18; Category = "Explorador & QoL"; Name = "Desativação de Arquivamento Automático de Apps"; Action = { Disable-AppArchival } }
)

$currentCategory = ""
$totalSuccess = 0
$totalFailed = 0
$failureDetails = @()

foreach ($item in $tweaks) {
    if ($item.Category -ne $currentCategory) {
        $currentCategory = $item.Category
        Write-Host "`n--- [$currentCategory] ---" -ForegroundColor DarkCyan
    }

    Write-Host ("[*] [{0,2}/18] {1}..." -f $item.Id, $item.Name) -NoNewline
    Write-SkyLog -Message "A iniciar: $($item.Name)" -Level "Info" -NoConsole

    try {
        $res = & $item.Action
        Write-Host " [OK]" -ForegroundColor Green
        $totalSuccess++
        $Global:SkyManifest.AppliedTweaks += $item.Name
    } catch {
        Write-Host " [FALHOU]" -ForegroundColor Red
        $errorMsg = $_.Exception.Message
        Write-SkyLog -Message "Falha em $($item.Name): $errorMsg" -Level "Error"
        $totalFailed++
        $failureDetails += [PSCustomObject]@{
            Id     = $item.Id
            Name   = $item.Name
            Reason = $errorMsg
        }
    }
}

# ------------------------------------------------------------------------------
# 6. SALVAGUARDA DE ESTADO FINAL
# ------------------------------------------------------------------------------
Save-SkyManifest

# ------------------------------------------------------------------------------
# 7. RELATÓRIO FINAL DE EXECUÇÃO
# ------------------------------------------------------------------------------
$summaryBox = @"

================================================================================
                         RELATÓRIO DE EXECUÇÃO
================================================================================
  Total de Tweaks Executados:  $($tweaks.Count)
  Sucessos:                    $totalSuccess
  Falhas:                      $totalFailed
  Ponto de Restauro:           $(if ($restorePointCreated) { "Criado com Sucesso" } else { "Ignorado / Restrito" })

  Ficheiro de Log:             $Global:SkyLogFile
  Pasta de Backups:            $Global:SkyBackupDir
  Script de Reversão:          .\UNDO-SkyOptimizer.ps1
================================================================================
"@

Write-Host $summaryBox -ForegroundColor Green

if ($totalFailed -gt 0) {
    Write-Host "`nDetalhes das Falhas:" -ForegroundColor Red
    foreach ($f in $failureDetails) {
        Write-Host "  - [#$($f.Id)] $($f.Name): $($f.Reason)" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 8. REINÍCIO DO WINDOWS EXPLORER (OPCIONAL)
# ------------------------------------------------------------------------------
Write-Host "`nAlgumas alterações de interface (extensões de ficheiros, widgets, menu iniciar)" -ForegroundColor Gray
Write-Host "tornam-se imediatamente visíveis após reiniciar o Windows Explorer." -ForegroundColor Gray
$restartExplorer = Read-Host "Pretende reiniciar o Windows Explorer agora? (S/N)"

if ($restartExplorer -match '^(s|sim|y|yes)$') {
    Write-Host "A reiniciar o Windows Explorer..." -ForegroundColor Cyan
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Host "[OK] Windows Explorer reiniciado com sucesso." -ForegroundColor Green
}

Write-Host "`n[+] SkyOptimizer concluído com êxito! Para reverter qualquer alteração, execute UNDO-SkyOptimizer.ps1." -ForegroundColor Cyan
Read-Host "`nPressione ENTER para fechar..."
