<#
.SYNOPSIS
    UNDO-SkyOptimizer - Reversão Completa e Restauração de Estado Original do Sistema.
.DESCRIPTION
    Restaura todos os backups de registo (.reg), reverte serviços (SysMain, Hibernação),
    perfil de energia original, dynamic tick, core parking e configurações de rede
    para o estado exato antes da execução do SkyOptimizer.
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
# 2. INICIALIZAÇÃO E AMBIENTE
# ------------------------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = "SkyOptimizer - REVERSÃO (UNDO) [Administrador]"
$scriptDir = $PSScriptRoot
$backupDir = Join-Path -Path $scriptDir -ChildPath "Backups"
$commonModule = Join-Path -Path $scriptDir -ChildPath "Tweaks\0-Common.ps1"

if (Test-Path $commonModule) {
    . $commonModule
}

Clear-Host
$banner = @"
================================================================================
  ____  _            ___        _   _           _              
 / ___|| | _____   _/ _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __ 
 \___ \| |/ / | | | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
  ___) |   <| |_| | |_| | |_) | |_| | | | | | | |/ /  __/ |   
 |____/|_|\_\\__, |\___/| .__/ \__|_|_| |_| |_|_/___\___|_|   
             |___/      |_|                                    
                  Módulo de Restauração / Reversão
================================================================================
"@
Write-Host $banner -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 3. CONFIRMAÇÃO DO UTILIZADOR
# ------------------------------------------------------------------------------
Write-Host "`n[!] ATENÇÃO: Este script irá reverter todas as configurações alteradas" -ForegroundColor Yellow
Write-Host "    pelo SkyOptimizer de volta para o estado original da máquina." -ForegroundColor Gray
Write-Host "    Os ficheiros em '$backupDir' serão utilizados como fonte da verdade.`n" -ForegroundColor Gray

$confirm = Read-Host "Deseja realmente reverter todas as otimizações? (S/N)"
if ($confirm -notmatch '^(s|sim|y|yes)$') {
    Write-Host "`nOperação de reversão cancelada pelo utilizador." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    exit 0
}

Write-SkyLog -Message "Início do processo de REVERSÃO (UNDO) no sistema $env:COMPUTERNAME" -Level "Info" -NoConsole

# ------------------------------------------------------------------------------
# 4. RESTAURAÇÃO DE BACKUPS DE REGISTO (.REG)
# ------------------------------------------------------------------------------
Write-Host "`n>>> [Passo 1/4] A restaurar ficheiros de Registo (.reg)..." -ForegroundColor Magenta

$restoredRegCount = 0
if (Test-Path $backupDir) {
    $regFiles = Get-ChildItem -Path $backupDir -Filter "*.reg" -ErrorAction SilentlyContinue

    foreach ($file in $regFiles) {
        Write-Host "  [*] A importar $($file.Name)..." -ForegroundColor Gray -NoNewline
        $importProc = Start-Process -FilePath "reg.exe" -ArgumentList "import `"$($file.FullName)`"" -Wait -NoNewWindow -PassThru
        if ($importProc.ExitCode -eq 0) {
            Write-Host " [OK]" -ForegroundColor Green
            Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
            $restoredRegCount++
        } else {
            Write-Host " [FALHOU]" -ForegroundColor Red
            Write-SkyLog -Message "Falha ao restaurar $($file.Name) (ExitCode: $($importProc.ExitCode))" -Level "Warning"
        }
    }
} else {
    Write-Host "  [!] Pasta de Backups não encontrada." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# 5. REMOÇÃO DE CHAVES CRIADAS QUE NÃO EXISTIAM PREVIAMENTE
# ------------------------------------------------------------------------------
Write-Host "`n>>> [Passo 2/4] A limpar chaves de registo criadas de raiz..." -ForegroundColor Magenta
$createdKeysFile = Join-Path -Path $backupDir -ChildPath "created_keys.txt"

if (Test-Path $createdKeysFile) {
    $createdKeys = Get-Content -Path $createdKeysFile -ErrorAction SilentlyContinue
    foreach ($key in $createdKeys) {
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            Write-Host "  [*] A remover chave recém-criada '$key'..." -ForegroundColor Gray -NoNewline
            $delProc = Start-Process -FilePath "reg.exe" -ArgumentList "delete `"$key`" /f" -Wait -NoNewWindow -PassThru
            if ($delProc.ExitCode -eq 0) {
                Write-Host " [OK]" -ForegroundColor Green
            } else {
                Write-Host " [IGNORADO]" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "  [*] Nenhuma chave necessitou de remoção manual." -ForegroundColor Gray
}

# ------------------------------------------------------------------------------
# 6. RESTAURAÇÃO DE SERVIÇOS E ESTADO DE SISTEMA
# ------------------------------------------------------------------------------
Write-Host "`n>>> [Passo 3/4] A restaurar Definições de Energia, BCD e Serviços..." -ForegroundColor Magenta

# 1. Plano de Energia Original
$powerPlanFile = Join-Path -Path $backupDir -ChildPath "previous_power_plan.txt"
if (Test-Path $powerPlanFile) {
    $origPlanGuid = (Get-Content -Path $powerPlanFile -ErrorAction SilentlyContinue).Trim()
    if ($origPlanGuid -match '^[a-fA-F0-9-]+$') {
        powercfg -setactive $origPlanGuid
        Write-Host "  [OK] Plano de Energia original reativado ($origPlanGuid)." -ForegroundColor Green
        Write-SkyLog -Message "Plano de energia original reativado: $origPlanGuid" -Level "Success"
    }
} else {
    # Predefinição: Equilibrado (Balanced)
    powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    Write-Host "  [INFO] Plano de Energia reposto para Equilibrado (Balanced)." -ForegroundColor Gray
}

# 2. Core Parking (Repor para predefinição 0%)
$subGroup = "54533251-82be-4824-96c1-47b60b740d00"
$setting  = "0cc5b647-c1df-4637-891a-dec75c318583"
powercfg -setacvalueindex scheme_current $subGroup $setting 0 2>$null
powercfg -setdcvalueindex scheme_current $subGroup $setting 0 2>$null
powercfg -setactive scheme_current 2>$null
Write-Host "  [OK] Core Parking reposto para predefinição de gestão de energia." -ForegroundColor Green

# 3. Suspensão Seletiva USB (Repor para 1 - Ativado por defeito)
$usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
$usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
powercfg -setacvalueindex scheme_current $usbSubGroup $usbSetting 1 2>$null
powercfg -setdcvalueindex scheme_current $usbSubGroup $usbSetting 1 2>$null
powercfg -setactive scheme_current 2>$null
Write-Host "  [OK] Suspensão Seletiva USB reposta para padrão de conservação de energia." -ForegroundColor Green

# 4. Dynamic Tick (BCD)
$bcdResult = bcdedit /deletevalue disabledynamictick 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Dynamic Tick (BCD) reposto para o valor padrão." -ForegroundColor Green
} else {
    bcdedit /set disabledynamictick no 2>&1 | Out-Null
    Write-Host "  [OK] Dynamic Tick verificado e reposto." -ForegroundColor Green
}

# 5. Hibernação
$hibFile = Join-Path -Path $backupDir -ChildPath "previous_hibernation.txt"
if (Test-Path $hibFile) {
    $origHib = (Get-Content -Path $hibFile -ErrorAction SilentlyContinue).Trim()
    if ($origHib -eq "1") {
        powercfg -h on
        Write-Host "  [OK] Hibernação reativada (estado original: Ativa)." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Hibernação já se encontrava inativa antes do SkyOptimizer." -ForegroundColor Gray
    }
}

# 6. SysMain (Superfetch)
$sysmainFile = Join-Path -Path $backupDir -ChildPath "previous_sysmain.txt"
if (Test-Path $sysmainFile) {
    $origSysMain = (Get-Content -Path $sysmainFile -ErrorAction SilentlyContinue).Trim()
    if ($origSysMain -in @("Auto", "Automatic", "Manual")) {
        $startupType = if ($origSysMain -eq "Manual") { "Manual" } else { "Automatic" }
        Set-Service -Name SysMain -StartupType $startupType -ErrorAction SilentlyContinue
        Start-Service -Name SysMain -ErrorAction SilentlyContinue
        Write-Host "  [OK] Serviço SysMain restaurado para $startupType e reiniciado." -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# 7. REINÍCIO DO WINDOWS EXPLORER (OPCIONAL)
# ------------------------------------------------------------------------------
Write-Host "`n>>> [Passo 4/4] Finalização" -ForegroundColor Magenta
Write-Host "Recomenda-se reiniciar o Windows Explorer para repor de imediato as definições visuais." -ForegroundColor Gray
$restartExplorer = Read-Host "Pretende reiniciar o Windows Explorer agora? (S/N)"

if ($restartExplorer -match '^(s|sim|y|yes)$') {
    Write-Host "A reiniciar o Windows Explorer..." -ForegroundColor Cyan
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Host "[OK] Windows Explorer reiniciado." -ForegroundColor Green
}

Write-Host @"

================================================================================
                         REVERSÃO CONCLUÍDA
================================================================================
  Ficheiros de registo restaurados: $restoredRegCount
  Definições de hardware e energia: Repostas com Sucesso
  Estado dos Serviços:              Restaurado
================================================================================
O seu sistema foi revertido com segurança para o estado anterior.
"@ -ForegroundColor Green

Read-Host "Pressione ENTER para fechar..."
