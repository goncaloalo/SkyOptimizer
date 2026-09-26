<#
.SYNOPSIS
    SkyStrafe - Resposta Instantânea de Teclado & Strafe Competitivo
    SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5

.DESCRIPTION
    Pack autónomo e seguro para maximizar a reatividade das teclas de movimento
    (A/D - Strafe) sem recurso a FilterKeys agressivo que quebre a digitação
    normal no Discord, WhatsApp ou browser.
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

$Host.UI.RawUI.WindowTitle = "SkyStrafe - Otimização de Teclado & Strafe"

# Definição de User32 para aplicação instantânea na sessão sem reiniciar
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class NativeUser32 {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
    }
"@ -ErrorAction SilentlyContinue
} catch {}

$backupDir = Join-Path -Path $PSScriptRoot -ChildPath "Backups_SkyStrafe"

function Invoke-ApplyStrafe {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "          SkyStrafe - A Aplicar Otimização de Resposta e Strafe" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Discord Oficial: https://discord.gg/cE8ZaDRGV5`n" -ForegroundColor DarkCyan

    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    # Backup do registo de teclado original
    $regBackup = Join-Path -Path $backupDir -ChildPath "Original_Keyboard.reg"
    if (-not (Test-Path $regBackup)) {
        Write-Host "[*] A criar backup do registo de teclado original..." -ForegroundColor Gray
        & reg.exe export "HKCU\Control Panel\Keyboard" "$regBackup" /y *> $null
    }

    Write-Host "[*] A definir atraso mínimo de repetição (KeyboardDelay = 0)..." -ForegroundColor White
    Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0" -Type String -Force

    Write-Host "[*] A definir velocidade máxima de repetição (KeyboardSpeed = 31)..." -ForegroundColor White
    Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force

    # Notificação nativa ao Windows para aplicar de imediato
    try {
        # SPI_SETKEYBOARDDELAY = 0x0017, SPIF_UPDATEINIFILE = 0x01, SPIF_SENDCHANGE = 0x02
        [NativeUser32]::SystemParametersInfo(0x0017, 0, [IntPtr]::Zero, 3) | Out-Null
        # SPI_SETKEYBOARDSPEED = 0x000B
        [NativeUser32]::SystemParametersInfo(0x000B, 31, [IntPtr]::Zero, 3) | Out-Null
    } catch {}

    Write-Host @"

================================================================================
                   OTIMIZAÇÃO DE STRAFE CONCLUÍDA COM ÊXITO
================================================================================
  [✓] Delay de Teclado:      0 (Mínimo absoluto nativo)
  [✓] Velocidade de Tecla:   31 (Máxima taxa de resposta)
  [✓] Digitação Normal:      100% Preservada (Sem bugs de repetição no Discord/Web)
  [✓] Reversibilidade:       Backup guardado em .\Backups_SkyStrafe\
================================================================================
As alterações estão ATIVAS de imediato. Não é necessário reiniciar o PC.
"@ -ForegroundColor Green

    Read-Host "`nPressione ENTER para regressar ao menu..."
}

function Invoke-UndoStrafe {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "             SkyStrafe - A Reverter Definições de Teclado" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan

    $regBackup = Join-Path -Path $backupDir -ChildPath "Original_Keyboard.reg"
    if (Test-Path $regBackup) {
        Write-Host "[*] A restaurar backup original do registo..." -ForegroundColor White
        & reg.exe import "$regBackup" *> $null
    } else {
        Write-Host "[*] A repor valores de fábrica do Windows (KeyboardDelay = 1, Speed = 31)..." -ForegroundColor White
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "1" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force
    }

    try {
        [NativeUser32]::SystemParametersInfo(0x0017, 1, [IntPtr]::Zero, 3) | Out-Null
        [NativeUser32]::SystemParametersInfo(0x000B, 31, [IntPtr]::Zero, 3) | Out-Null
    } catch {}

    Write-Host @"

================================================================================
                       REVERSÃO CONCLUÍDA COM ÊXITO
================================================================================
  [✓] O teclado foi reposto para as definições originais do Windows.
================================================================================
"@ -ForegroundColor Green

    Read-Host "`nPressione ENTER para regressar ao menu..."
}

if ($Apply) {
    Invoke-ApplyStrafe
    exit 0
}

if ($Undo) {
    Invoke-UndoStrafe
    exit 0
}

# Menu Interativo
while ($true) {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "          SkyOptimizer - Pack Strafe & Resposta de Teclado" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Dispositivo: $env:COMPUTERNAME | Utilizador: $env:USERNAME" -ForegroundColor Gray
    Write-Host "Discord da Comunidade: https://discord.gg/cE8ZaDRGV5`n" -ForegroundColor DarkCyan

    $curDelay = (Get-ItemProperty "HKCU:\Control Panel\Keyboard" -ErrorAction SilentlyContinue).KeyboardDelay
    $curSpeed = (Get-ItemProperty "HKCU:\Control Panel\Keyboard" -ErrorAction SilentlyContinue).KeyboardSpeed
    Write-Host "Estado Atual: Delay = $curDelay (Padrão: 1, Otimizado: 0) | Speed = $curSpeed" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

    Write-Host "[1] Aplicar Otimização de Strafe (Delay 0 / Speed 31)" -ForegroundColor Green
    Write-Host "[2] Reverter Alterações (Repor Padrão do Windows)" -ForegroundColor Yellow
    Write-Host "[3] Sair" -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor Cyan

    $choice = Read-Host "Escolha uma opção (1-3)"
    switch ($choice.Trim()) {
        "1" { Invoke-ApplyStrafe }
        "2" { Invoke-UndoStrafe }
        "3" { exit 0 }
        Default {
            Write-Host "`nOpção inválida!" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
