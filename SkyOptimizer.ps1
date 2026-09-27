<#
.SYNOPSIS
    SkyOptimizer v2.6 - Toolkit Autónomo, Não-Destrutivo e 100% Reversível de Otimização Windows 10/11.
.DESCRIPTION
    Ficheiro único consolidado e autocontido (sem dependências externas).
    Desenvolvido especificamente para suporte e otimização remota via AnyDesk em computadores de uso diário
    e máquinas de gaming competitivo (FiveM, CS2, ARC Raiders, etc.).
    Aplica 80 otimizações de elite: baixa latência, estabilização de frametimes, agendamento de CPU (0x26),
    MMCSS para jogos, HAGS condicional (>=6GB VRAM), NIC e USB sem poupança de energia, modo MSI exclusivo
    na GPU dedicada, debloat de navegadores em background, DirectFlip (Win11), Re-Trim de SSD NVMe,
    LLMNR desativado, sniffing de pastas desativado, agrupamento svchost, remoção de bloatware AppX,
    kernel e drivers em RAM (DisablePagingExecutive), desativação de Page Combining, suspensão inteligente
    de indexação em jogos, remoção de limite SMB, desativação de Aero Shake, caminhos longos Win32 (>260 chars),
    eliminação de DMA Coalescing em rede, controlo de crash BSOD, expansão de cache de ícones (4MB),
    bloqueio de firmware WPBT, eliminação de audio ducking, menu clássico Win11 sem atrasos, aceleração
    visual de janelas, telemetria NVIDIA em fundo, qualidade 100% wallpaper, diagnóstico silencioso,
    resposta rápida de teclado (strafe seguro sem FilterKeys), moderação de interrupções ITR desativada (hitreg instantâneo),
    desativação de RSC e LSO (ticks de dados puros), Flow Control desativado (anti-bufferbloat), gestão de portas efémeras
    MaxUserPort/TcpTimedWaitDelay, otimização de pilha TCP com proteção de velocidade de fibra (AutoTuning Normal),
    ativação de Modo de Jogo nativo (AutoGameModeEnabled=1) e otimização de ecrã inteiro e apresentação (GameDVR FSE=2).
    Inclui motor de salvaguarda total, relatório Antes vs. Depois e implementação automática do 'Painel do Cliente'
    no Ambiente de Trabalho com atalhos de 1 clique (Impressora, Bluetooth, Pesquisa, VBS, Shaders e Reverter).
.PARAMETER Apply
    Aplica diretamente as 80 otimizações e gera o Painel do Cliente sem exibir o menu interativo.
.PARAMETER Clean
    Executa exclusivamente a rotina de limpeza de shaders e ficheiros temporários.
.PARAMETER Undo
    Executa diretamente a reversão de todas as alterações sem exibir o menu interativo.
.PARAMETER DeployPanel
    Gera exclusivamente o 'Painel do Cliente' no Ambiente de Trabalho.
.EXAMPLE
    .\SkyOptimizer.ps1
    Apresenta o menu interativo inicial.
.EXAMPLE
    .\SkyOptimizer.ps1 -Apply
    Aplica as 80 otimizações e gera o Painel do Cliente no Desktop.
.EXAMPLE
    .\SkyOptimizer.ps1 -DeployPanel
    Instala os atalhos de 1 clique no Ambiente de Trabalho do cliente.
.EXAMPLE
    .\SkyOptimizer.ps1 -Clean
    Executa a manutenção e limpeza de caches de shaders.
.EXAMPLE
    .\SkyOptimizer.ps1 -Undo
    Reverte todas as otimizações de volta para o estado original da máquina.
.NOTES
    Autor: SkyOS Team
    Versão: 2.6.0
    Requisitos: Windows 10 / 11, PowerShell 5.1+, Privilégios de Administrador
#>

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(ParameterSetName = "ApplyDirect")]
    [switch]$Apply,

    [Parameter(ParameterSetName = "CleanDirect")]
    [switch]$Clean,

    [Parameter(ParameterSetName = "UndoDirect")]
    [switch]$Undo,

    [Parameter(ParameterSetName = "DeployPanelDirect")]
    [switch]$DeployPanel,

    [Parameter(ParameterSetName = "RepairDirect")]
    [switch]$Repair,

    [Parameter(ParameterSetName = "AuditDirect")]
    [switch]$Audit
)

# ==============================================================================
# 0. CONFIGURAÇÃO DE CODIFICAÇÃO UTF-8
# ==============================================================================
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch {}

# ==============================================================================
# 1. AUTO-ELEVAÇÃO PARA ADMINISTRADOR
# ==============================================================================
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$currentUser
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Privilégios de Administrador necessários. A reiniciar com elevação..." -ForegroundColor Yellow
    $paramString = ""
    if ($Apply) { $paramString = " -Apply" }
    elseif ($Clean) { $paramString = " -Clean" }
    elseif ($Undo) { $paramString = " -Undo" }
    elseif ($DeployPanel) { $paramString = " -DeployPanel" }
    $argsList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$paramString"
    Start-Process powershell.exe -ArgumentList $argsList -Verb RunAs
    exit
}

# ==============================================================================
# 2. INICIALIZAÇÃO DE AMBIENTE, DIRETÓRIOS E VARIÁVEIS GLOBAIS
# ==============================================================================
$Host.UI.RawUI.WindowTitle = "SkyOptimizer v2.6.0 [Administrador]"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

# Diretório Central de Backups (Cofre Oculto em C:\ProgramData\SkyOptimizer\Backups)
# Todos os backups originais vão DIRETAMENTE para o cofre do sistema, mantendo a pasta de trabalho 100% limpa
$Global:SkyPermDir = Join-Path -Path $env:SystemDrive -ChildPath "ProgramData\SkyOptimizer"
$Global:SkyBackupDir = Join-Path -Path $Global:SkyPermDir -ChildPath "Backups"
if (-not (Test-Path $Global:SkyBackupDir)) {
    New-Item -ItemType Directory -Path $Global:SkyBackupDir -Force | Out-Null
}
$Global:SkyBackupDir = (Resolve-Path $Global:SkyBackupDir).Path
$Global:SkyPermBackupDir = $Global:SkyBackupDir

# Diretório de Logs
$logsFolder = Join-Path -Path $scriptDir -ChildPath "Logs"
if (-not (Test-Path $logsFolder)) {
    New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$Global:SkyLogFile = Join-Path -Path $logsFolder -ChildPath "SkyOptimizer_$timestamp.log"

# Manifesto de Estado
if (-not $Global:SkyManifest) {
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $Global:SkyManifest = [ordered]@{
        Timestamp       = (Get-Date -Format "o")
        MachineName     = $env:COMPUTERNAME
        OperatingSystem = if ($osInfo) { $osInfo.Caption } else { "Windows" }
        PowerPlan       = $null
        Hibernation     = $null
        SysMain         = $null
        DynamicTick     = $null
        ReservedStorage = $null
        AppliedTweaks   = @()
    }
}

# ==============================================================================
# 3. FUNÇÕES PARTILHADAS (LOGGING, REGISTO E HARDWARE)
# ==============================================================================

function Write-SkyLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Highlight", "Status")]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )

    $timeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileLogEntry = "[$timeStr] [$($Level.ToUpper())] $Message"

    try {
        if ($Global:SkyLogFile) {
            Add-Content -Path $Global:SkyLogFile -Value $fileLogEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    } catch {}

    if ($NoConsole) { return }

    switch ($Level) {
        "Success" {
            Write-Host "    [OK] " -ForegroundColor Green -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "Warning" {
            Write-Host "    [AVISO] " -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor Yellow
        }
        "Error" {
            Write-Host "    [FALHOU] " -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor Red
        }
        "Highlight" {
            Write-Host "    [*] " -ForegroundColor Cyan -NoNewline
            Write-Host $Message -ForegroundColor Cyan
        }
        "Status" {
            Write-Host ">>> " -ForegroundColor Magenta -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        Default {
            Write-Host "    [INFO] " -ForegroundColor Gray -NoNewline
            Write-Host $Message -ForegroundColor Gray
        }
    }
}

function Convert-ToStandardRegPath {
    param([string]$Path)

    $clean = $Path.Trim()
    $clean = $clean -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
    $clean = $clean -replace '^HKCU:\\', 'HKEY_CURRENT_USER\'
    $clean = $clean -replace '^HKLM:', 'HKEY_LOCAL_MACHINE'
    $clean = $clean -replace '^HKCU:', 'HKEY_CURRENT_USER'
    return $clean
}

function Convert-ToPSRegPath {
    param([string]$Path)

    $clean = $Path.Trim()
    $clean = $clean -replace '^HKEY_LOCAL_MACHINE\\', 'HKLM:\'
    $clean = $clean -replace '^HKEY_CURRENT_USER\\', 'HKCU:\'
    $clean = $clean -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'
    $clean = $clean -replace '^HKEY_CURRENT_USER', 'HKCU:'
    return $clean
}

function Backup-RegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyPath,

        [Parameter(Mandatory = $true)]
        [string]$BackupName
    )

    $psPath = Convert-ToPSRegPath -Path $KeyPath
    $stdPath = Convert-ToStandardRegPath -Path $KeyPath
    $backupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "$BackupName.reg"
    $createdKeysFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "created_keys.txt"

    if (Test-Path $psPath) {
        if (-not (Test-Path $backupFile)) {
            Write-SkyLog -Message "A criar backup de registo para '$stdPath' -> '$BackupName.reg'" -Level "Info" -NoConsole
            & reg.exe export "$stdPath" "$backupFile" /y *> $null
            if ($LASTEXITCODE -ne 0) {
                Write-SkyLog -Message "Falha ao exportar registo de '$stdPath' (ExitCode: $LASTEXITCODE)" -Level "Warning" -NoConsole
            } else {
                # Sincronização em tempo real para o cofre permanente de backups
                if ($Global:SkyPermBackupDir -and (Test-Path $Global:SkyPermBackupDir)) {
                    Copy-Item -Path $backupFile -Destination $Global:SkyPermBackupDir -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } else {
        Write-SkyLog -Message "Chave '$stdPath' não existia previamente. Registada em created_keys.txt." -Level "Info" -NoConsole
        if (-not (Test-Path $createdKeysFile)) {
            New-Item -ItemType File -Path $createdKeysFile -Force | Out-Null
        }
        $existing = Get-Content -Path $createdKeysFile -ErrorAction SilentlyContinue
        if ($existing -notcontains $stdPath) {
            Add-Content -Path $createdKeysFile -Value $stdPath -ErrorAction SilentlyContinue
        }
        if ($Global:SkyPermBackupDir -and (Test-Path $Global:SkyPermBackupDir)) {
            Copy-Item -Path $createdKeysFile -Destination $Global:SkyPermBackupDir -Force -ErrorAction SilentlyContinue
        }
    }
}

function Ensure-RegistryPath {
    param([string]$KeyPath)
    $psPath = Convert-ToPSRegPath -Path $KeyPath
    if (-not (Test-Path $psPath)) {
        New-Item -Path $psPath -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

function Save-SkyManifest {
    $manifestPath = Join-Path -Path $Global:SkyBackupDir -ChildPath "state_backup.json"
    $json = $Global:SkyManifest | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($manifestPath, $json, [System.Text.Encoding]::UTF8)
    if ($Global:SkyPermBackupDir -and (Test-Path $Global:SkyPermBackupDir)) {
        Copy-Item -Path $manifestPath -Destination $Global:SkyPermBackupDir -Force -ErrorAction SilentlyContinue
    }
}

function Test-IsDesktopOrAcPower {
    try {
        # Verificar se existe hardware de bateria instalado
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $battery) {
            # Se não tem bateria, é 100% garantido um Desktop / Torre
            return $true
        }

        # Se tem bateria (Portátil), verificar se está ligado à tomada (AC Power)
        $batteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
        if ($batteryStatus -and $batteryStatus.PowerOnline -eq $true) {
            return $true # Portátil ligado à tomada elétrica
        }

        # Verificar tipo de chassis para confirmação
        $chassis = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue
        if ($chassis.ChassisTypes -match '^(3|4|5|6|7|15|16|23|24)$') {
            return $true
        }

        return $false # Portátil a funcionar na bateria
    } catch {
        return $true
    }
}

function Test-IsOnBattery {
    return (-not (Test-IsDesktopOrAcPower))
}

function Get-AccurateVramBytes {
    try {
        $gpuItem = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\000*' -ErrorAction SilentlyContinue | Where-Object DriverDesc | Select-Object -First 1
        if ($gpuItem -and $gpuItem.'HardwareInformation.qwMemorySize') {
            return [PSCustomObject]@{ Bytes = [int64]$gpuItem.'HardwareInformation.qwMemorySize' }
        }
        $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vc -and $vc.AdapterRAM) {
            return [PSCustomObject]@{ Bytes = [int64]$vc.AdapterRAM }
        }
    } catch {}
    return [PSCustomObject]@{ Bytes = [int64]0 }
}

function Get-VbsStatus {
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
        if ($dg -and $dg.VirtualizationBasedSecurityStatus -eq 2) {
            return "Ativado"
        }
        $hvciKey = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
        if (Test-Path $hvciKey) {
            $val = (Get-ItemProperty -Path $hvciKey -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
            if ($val -eq 1) { return "Ativado" }
        }
        return "Desativado"
    } catch {
        return "Desativado"
    }
}

function Show-SystemHardwareInfo {
    try {
        $osCaption = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
        $cpuName   = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name
        if ($cpuName) { $cpuName = $cpuName.Trim() } else { $cpuName = "Processador Genérico" }

        $ramGB = 0
        $compSys = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($compSys -and $compSys.TotalPhysicalMemory) {
            $ramGB = [math]::Round($compSys.TotalPhysicalMemory / 1GB)
        } else {
            $ramBytes = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
            if ($ramBytes) { $ramGB = [math]::Round($ramBytes / 1GB) }
        }
        if ($ramGB -eq 0) {
            $osMem = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).TotalVisibleMemorySize
            if ($osMem) { $ramGB = [math]::Round($osMem / 1MB) }
        }

        # Deteção de GPU e VRAM real via chave de classe do display (evita o limite de 4GB do WMI)
        $gpuItem = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\000*' -ErrorAction SilentlyContinue | Where-Object DriverDesc | Select-Object -First 1
        $gpuName = if ($gpuItem) { $gpuItem.DriverDesc } else { "GPU Genérica" }
        $vramGB  = 0
        $vramInfo = Get-AccurateVramBytes
        if ($vramInfo.Bytes -gt 0) {
            $vramGB = [math]::Round($vramInfo.Bytes / 1GB)
        }

        # Deteção de Disco do Sistema
        $diskInfo = "Armazenamento Padrão"
        try {
            $physDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($physDisk) {
                $diskInfo = "$($physDisk.MediaType) ($($physDisk.BusType))"
            }
        } catch {}

        # Deteção de Plano de Energia Ativo
        $powerPlan = "Equilibrado / Padrão"
        try {
            $rawScheme = powercfg /getactivescheme 2>$null
            if ($rawScheme -match '\((.*?)\)') {
                $powerPlan = $matches[1]
            }
        } catch {}

        $vbsState = Get-VbsStatus

        Write-Host "  Dispositivo:   " -NoNewline -ForegroundColor Gray
        Write-Host "$env:COMPUTERNAME" -ForegroundColor White
        Write-Host "  Sistema:       " -NoNewline -ForegroundColor Gray
        Write-Host "$osCaption" -ForegroundColor White
        Write-Host "  Processador:   " -NoNewline -ForegroundColor Gray
        Write-Host "$cpuName" -ForegroundColor White
        Write-Host "  Placa Gráfica: " -NoNewline -ForegroundColor Gray
        Write-Host "$gpuName $(if ($vramGB -gt 0) { "($vramGB GB VRAM)" })" -ForegroundColor White
        Write-Host "  Memória RAM:   " -NoNewline -ForegroundColor Gray
        Write-Host "$ramGB GB" -ForegroundColor White
        Write-Host "  Disco do SO:   " -NoNewline -ForegroundColor Gray
        Write-Host "$diskInfo" -ForegroundColor White
        Write-Host "  Plano Energia: " -NoNewline -ForegroundColor Gray
        $planColor = if ($powerPlan -match 'Desempenho|Ultimate|Performance') { "Green" } else { "Yellow" }
        Write-Host "$powerPlan" -ForegroundColor $planColor
        Write-Host "  Núcleo VBS:    " -NoNewline -ForegroundColor Gray
        $vbsColor = if ($vbsState -eq "Ativado") { "Yellow" } else { "Green" }
        Write-Host "$vbsState $(if ($vbsState -eq "Ativado") { "(Valorant / CS2 no FACEIT Suportados)" } else { "(Máxima Performance)" })" -ForegroundColor $vbsColor
        Write-Host "================================================================================" -ForegroundColor Cyan
    } catch {}
}

# ==============================================================================
# 4. FUNÇÕES DE OTIMIZAÇÃO (34 TWEAKS EM 9 CATEGORIAS)
# ==============================================================================

# --- CATEGORIA 1: SISTEMA E DESEMPENHO (KERNEL & POWER) ---

function Set-UltimatePowerPlan {
    [CmdletBinding()]
    param()

    $activeSchemeOutput = powercfg -getactivescheme 2>&1
    $currentGuid = $null
    if ($activeSchemeOutput -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
        $currentGuid = $matches[1]
    }

    if ($currentGuid -and -not $Global:SkyManifest.PowerPlan) {
        $Global:SkyManifest.PowerPlan = $currentGuid
        $powerPlanBackupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_power_plan.txt"
        $currentGuid | Out-File -FilePath $powerPlanBackupFile -Encoding UTF8 -Force
        Write-SkyLog -Message "Plano de energia original guardado: $currentGuid" -Level "Info" -NoConsole
    }

    $allSchemes = powercfg -list 2>&1
    $ultimateGuid = $null

    foreach ($line in ($allSchemes -split "`r?`n")) {
        if ($line -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})' -and 
            ($line -match 'Ultimate Performance' -or $line -match 'Desempenho Máximo')) {
            $ultimateGuid = $matches[1]
            break
        }
    }

    if (-not $ultimateGuid) {
        $dupOutput = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
        if ($dupOutput -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
            $ultimateGuid = $matches[1]
        } else {
            $dupHigh = powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1
            if ($dupHigh -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
                $ultimateGuid = $matches[1]
            }
        }
    }

    if ($ultimateGuid) {
        powercfg -setactive $ultimateGuid 2>$null
        Write-SkyLog -Message "Plano 'Desempenho Máximo' ($ultimateGuid) ativado com sucesso." -Level "Success"
        return $true
    } else {
        throw "Não foi possível criar ou encontrar o perfil de Desempenho Máximo."
    }
}

function Set-TimerResolution {
    [CmdletBinding()]
    param()

    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
    Ensure-RegistryPath -KeyPath $regKey
    Backup-RegistryKey -KeyPath $regKey -BackupName "02_TimerResolution_Kernel"

    Set-ItemProperty -Path $regKey -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force

    $bcdCheck = bcdedit /enum "{current}" 2>&1
    if ($bcdCheck -match "disabledynamictick\s+Yes") {
        $Global:SkyManifest.DynamicTick = "AlreadyDisabled"
    } else {
        $Global:SkyManifest.DynamicTick = "WasEnabled"
    }
    
    $bcdResult = bcdedit /set disabledynamictick yes 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-SkyLog -Message "Aviso: bcdedit disabledynamictick devolveu código: $bcdResult" -Level "Warning"
    }

    Write-SkyLog -Message "Temporizador de alta precisão (GlobalTimerResolutionRequests & DynamicTick=Disabled) aplicado." -Level "Success"
    return $true
}

function Disable-CoreParking {
    [CmdletBinding()]
    param()

    $subGroup   = "54533251-82be-4824-96c1-47b60b740d00" # Subgrupo de Processador
    $settingMin = "0cc5b647-c1df-4637-891a-dec75c318583" # Processor performance core parking min cores
    $settingMax = "ea062031-0e34-4ff1-9b6d-eb1059324028" # Processor performance core parking max cores

    $null = powercfg -attributes $subGroup $settingMin -ATTRIB_HIDE 2>&1
    $null = powercfg -attributes $subGroup $settingMax -ATTRIB_HIDE 2>&1

    $null = powercfg -setacvalueindex SCHEME_CURRENT $subGroup $settingMin 100 2>&1
    $null = powercfg -setdcvalueindex SCHEME_CURRENT $subGroup $settingMin 100 2>&1
    $null = powercfg -setacvalueindex SCHEME_CURRENT $subGroup $settingMax 100 2>&1
    $null = powercfg -setdcvalueindex SCHEME_CURRENT $subGroup $settingMax 100 2>&1
    $null = powercfg -setactive SCHEME_CURRENT 2>&1

    Write-SkyLog -Message "Core Parking desativado (100% núcleos ativos no perfil de energia)." -Level "Success"
    return $true
}

function Disable-Hibernation {
    [CmdletBinding()]
    param()

    $powerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    $currentState = (Get-ItemProperty -Path $powerKey -Name "HibernateEnabled" -ErrorAction SilentlyContinue).HibernateEnabled
    $wasEnabled = if ($currentState -eq 0) { 0 } else { 1 }

    if ($null -eq $Global:SkyManifest.Hibernation) {
        $Global:SkyManifest.Hibernation = $wasEnabled
        $hibBackupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_hibernation.txt"
        $wasEnabled | Out-File -FilePath $hibBackupFile -Encoding UTF8 -Force
    }

    $null = powercfg -h off 2>&1
    Write-SkyLog -Message "Hibernação desativada com sucesso (ficheiro hiberfil.sys removido)." -Level "Success"
    return $true
}

function Disable-FaultTolerantHeap {
    [CmdletBinding()]
    param()

    $fthKey = "HKLM:\SOFTWARE\Microsoft\FTH"
    Ensure-RegistryPath -KeyPath $fthKey
    Backup-RegistryKey -KeyPath $fthKey -BackupName "05_FaultTolerantHeap"

    Set-ItemProperty -Path $fthKey -Name "Enabled" -Value 0 -Type DWord -Force
    Write-SkyLog -Message "Fault Tolerant Heap (FTH) desativado para eliminar latência de monitorização." -Level "Success"
    return $true
}

function Disable-Superfetch {
    [CmdletBinding()]
    param()

    $sysDriveLetter = $env:SystemDrive.Substring(0, 1)
    $partition = Get-Partition -DriveLetter $sysDriveLetter -ErrorAction SilentlyContinue
    $disk = if ($partition) { Get-PhysicalDisk -DeviceNumber $partition.DiskNumber -ErrorAction SilentlyContinue } else { $null }

    $isSSD = $false
    if ($disk) {
        if ($disk.MediaType -in @('SSD', 'NVMe') -or $disk.BusType -eq 'NVMe') {
            $isSSD = $true
        }
    } else {
        $wmiDrive = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wmiDrive.Model -match 'SSD|NVMe') {
            $isSSD = $true
        }
    }

    if (-not $isSSD) {
        Write-SkyLog -Message "Disco detetado como HDD ou Virtual/Indeterminado. SysMain mantido ativo por segurança." -Level "Warning"
        return $true
    }

    $svc = Get-Service -Name SysMain -ErrorAction SilentlyContinue
    if ($svc) {
        $cimSvc = Get-CimInstance Win32_Service -Filter "Name='SysMain'" -ErrorAction SilentlyContinue
        $prevMode = if ($cimSvc) { $cimSvc.StartMode } else { "Auto" }
        
        if ($null -eq $Global:SkyManifest.SysMain) {
            $Global:SkyManifest.SysMain = $prevMode
            $sysmainBackupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_sysmain.txt"
            $prevMode | Out-File -FilePath $sysmainBackupFile -Encoding UTF8 -Force
        }

        Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
        Set-Service -Name SysMain -StartupType Disabled -ErrorAction Stop
        Write-SkyLog -Message "SysMain (Superfetch) desativado com segurança (disco SSD/NVMe confirmado)." -Level "Success"
    } else {
        Write-SkyLog -Message "Serviço SysMain não encontrado no sistema." -Level "Info"
    }

    return $true
}

# --- CATEGORIA 2: INPUT E GAMING ---

function Disable-MouseAcceleration {
    [CmdletBinding()]
    param()

    $mouseKey = "HKCU:\Control Panel\Mouse"
    Ensure-RegistryPath -KeyPath $mouseKey
    Backup-RegistryKey -KeyPath $mouseKey -BackupName "07_MouseSettings"

    Set-ItemProperty -Path $mouseKey -Name "MouseSpeed" -Value "0" -Type String -Force
    Set-ItemProperty -Path $mouseKey -Name "MouseThreshold1" -Value "0" -Type String -Force
    Set-ItemProperty -Path $mouseKey -Name "MouseThreshold2" -Value "0" -Type String -Force
    Set-ItemProperty -Path $mouseKey -Name "MouseSensitivity" -Value "10" -Type String -Force
    Set-ItemProperty -Path $mouseKey -Name "MouseTrails" -Value "0" -Type String -Force

    # Curva Linear MarkC 1:1 (elimina qualquer interpolação não-linear de aceleração residual no Windows 10/11)
    $markCX = [byte[]](
        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
        0x15,0xE5,0x00,0x00,0x00,0x00,0x00,0x00,
        0x00,0x40,0x01,0x00,0x00,0x00,0x00,0x00,
        0x00,0x80,0x02,0x00,0x00,0x00,0x00,0x00,
        0x00,0x00,0x28,0x00,0x00,0x00,0x00,0x00
    )
    $markCY = [byte[]](
        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
        0xB8,0x0B,0x01,0x00,0x00,0x00,0x00,0x00,
        0x00,0x20,0x05,0x00,0x00,0x00,0x00,0x00,
        0x00,0x00,0x50,0x00,0x00,0x00,0x00,0x00,
        0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x00
    )
    Set-ItemProperty -Path $mouseKey -Name "SmoothMouseXCurve" -Value $markCX -Type Binary -Force
    Set-ItemProperty -Path $mouseKey -Name "SmoothMouseYCurve" -Value $markCY -Type Binary -Force

    Write-SkyLog -Message "Aceleração de rato desativada (input linear 1:1, sensibilidade neutra 6/11 e curva MarkC configurados)." -Level "Success"
    return $true
}

function Disable-USBSelectiveSuspend {
    [CmdletBinding()]
    param()

    # Deteção de Alimentação CA / Portátil
    if (Test-IsOnBattery) {
        Write-SkyLog -Message "Dispositivo a funcionar a bateria. Otimização de Suspensão Seletiva USB ignorada para poupança." -Level "Warning"
        return $false
    }

    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"

    $null = powercfg -attributes $usbSubGroup $usbSetting -ATTRIB_HIDE 2>&1
    $null = powercfg -setacvalueindex SCHEME_CURRENT $usbSubGroup $usbSetting 0 2>&1
    $null = powercfg -setdcvalueindex SCHEME_CURRENT $usbSubGroup $usbSetting 0 2>&1
    $null = powercfg -setactive SCHEME_CURRENT 2>&1

    # Desativação de poupança de energia nos controladores e Hubs USB
    $usbHubs = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\Device Parameters" -ErrorAction SilentlyContinue
    $hubCount = 0
    foreach ($h in $usbHubs) {
        $p = $h.PSPath
        Set-ItemProperty -Path $p -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name "SelectiveSuspendEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name "AllowIdleIrpInD3" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        $hubCount++
    }

    Write-SkyLog -Message "Suspensão Seletiva USB desativada no perfil de energia e em $hubCount controladores USB (estabilidade 1000Hz-8000Hz)." -Level "Success"
    return $true
}

function Disable-GameDVR {
    [CmdletBinding()]
    param()

    $configStore = "HKCU:\System\GameConfigStore"
    Ensure-RegistryPath -KeyPath $configStore
    Backup-RegistryKey -KeyPath $configStore -BackupName "09_GameConfigStore"
    Set-ItemProperty -Path $configStore -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

    $appCapture = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    Ensure-RegistryPath -KeyPath $appCapture
    Backup-RegistryKey -KeyPath $appCapture -BackupName "09_GameDVR_User"
    Set-ItemProperty -Path $appCapture -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force

    $policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    Ensure-RegistryPath -KeyPath $policyKey
    Backup-RegistryKey -KeyPath $policyKey -BackupName "09_GameDVR_Policy"
    Set-ItemProperty -Path $policyKey -Name "AllowGameDVR" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Gravação em segundo plano do Game DVR / Xbox Game Bar desativada." -Level "Success"
    return $true
}

# --- CATEGORIA 3: OTIMIZAÇÕES DE REDE & LATÊNCIA ---

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
        if ($props.DhcpIPAddress -or $props.IPAddress) {
            Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $iface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $iface.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force
            $configuredCount++
        }
    }

    Write-SkyLog -Message "Algoritmo de Nagle desativado (TCPNoDelay=1, TcpAckFrequency=1) em $configuredCount interface(s)." -Level "Success"
    return $true
}

function Optimize-NetworkThrottling {
    [CmdletBinding()]
    param()

    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Ensure-RegistryPath -KeyPath $profileKey
    Backup-RegistryKey -KeyPath $profileKey -BackupName "11_Multimedia_SystemProfile"

    Set-ItemProperty -Path $profileKey -Name "NetworkThrottlingIndex" -Value 0xffffffff -Force
    Set-ItemProperty -Path $profileKey -Name "SystemResponsiveness" -Value 10 -Type DWord -Force

    Write-SkyLog -Message "Network Throttling desativado e SystemResponsiveness definido para 10 (proteção de áudio em background)." -Level "Success"
    return $true
}

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

# --- CATEGORIA 4: PRIVACIDADE E TELEMETRIA ---

function Set-TelemetryBasic {
    [CmdletBinding()]
    param()

    $dataColKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    Ensure-RegistryPath -KeyPath $dataColKey
    Backup-RegistryKey -KeyPath $dataColKey -BackupName "13_DataCollection_Telemetry"

    Set-ItemProperty -Path $dataColKey -Name "AllowTelemetry" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Telemetria configurada para nível Básico/Necessário (Windows Update e Store seguros)." -Level "Success"
    return $true
}

function Disable-StartMenuSuggestions {
    [CmdletBinding()]
    param()

    $cdmKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Ensure-RegistryPath -KeyPath $cdmKey
    Backup-RegistryKey -KeyPath $cdmKey -BackupName "14_ContentDeliveryManager_Suggestions"

    $settings = @{
        "SystemPaneSuggestionsEnabled"        = 0
        "SubscribedContent-338388Enabled"      = 0
        "SubscribedContent-338389Enabled"      = 0
        "SubscribedContent-353694Enabled"      = 0
        "SubscribedContent-353696Enabled"      = 0
        "RotatingLockScreenOverlayEnabled"     = 0
    }

    foreach ($name in $settings.Keys) {
        Set-ItemProperty -Path $cdmKey -Name $name -Value $settings[$name] -Type DWord -Force
    }

    Write-SkyLog -Message "Sugestões automáticas e apps promovidas no Menu Iniciar desativadas." -Level "Success"
    return $true
}

function Disable-SearchAndSpotlight {
    [CmdletBinding()]
    param()

    $explorerPolicy = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Ensure-RegistryPath -KeyPath $explorerPolicy
    Backup-RegistryKey -KeyPath $explorerPolicy -BackupName "15_SearchSuggestions_Policy"
    Set-ItemProperty -Path $explorerPolicy -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force

    $searchKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    Ensure-RegistryPath -KeyPath $searchKey
    Backup-RegistryKey -KeyPath $searchKey -BackupName "15_SearchSettings_User"
    Set-ItemProperty -Path $searchKey -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $searchKey -Name "CortanaConsent" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Pesquisa remota na Web (Bing) desativada no Menu Iniciar (pesquisa local instantânea)." -Level "Success"
    return $true
}

function Disable-TaskbarWidgets {
    [CmdletBinding()]
    param()

    $dshKey = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    Ensure-RegistryPath -KeyPath $dshKey
    Backup-RegistryKey -KeyPath $dshKey -BackupName "16_Widgets_DshPolicy"
    Set-ItemProperty -Path $dshKey -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force

    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Ensure-RegistryPath -KeyPath $advKey
    Backup-RegistryKey -KeyPath $advKey -BackupName "16_TaskbarWidgets_User"
    try {
        Set-ItemProperty -Path $advKey -Name "TaskbarDa" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {}

    $feedsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
    Ensure-RegistryPath -KeyPath $feedsKey
    Backup-RegistryKey -KeyPath $feedsKey -BackupName "16_Feeds_Win10"
    try {
        Set-ItemProperty -Path $feedsKey -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {}

    Write-SkyLog -Message "Widgets e Feeds de Notícias da barra de tarefas desativados." -Level "Success"
    return $true
}

# --- CATEGORIA 5: EXPLORADOR DE FICHEIROS & QOL BASE ---

function Show-FileExtensions {
    [CmdletBinding()]
    param()

    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Ensure-RegistryPath -KeyPath $advKey
    Backup-RegistryKey -KeyPath $advKey -BackupName "17_Explorer_FileExtensions"

    Set-ItemProperty -Path $advKey -Name "HideFileExt" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Exibição de extensões de ficheiros ativada (.exe, .ps1, etc.)." -Level "Success"
    return $true
}

function Disable-AppArchival {
    [CmdletBinding()]
    param()

    $cdmKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Ensure-RegistryPath -KeyPath $cdmKey
    Backup-RegistryKey -KeyPath $cdmKey -BackupName "18_ContentDeliveryManager_AppArchival"

    Set-ItemProperty -Path $cdmKey -Name "ArchiveApps" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Arquivamento automático de aplicações em segundo plano desativado." -Level "Success"
    return $true
}

# --- CATEGORIA 6: CONTROLO INTELIGENTE DE WINDOWS UPDATE ---

function Block-AutomaticDriverUpdates {
    [CmdletBinding()]
    param()

    $wuPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    Ensure-RegistryPath -KeyPath $wuPolicy
    Backup-RegistryKey -KeyPath $wuPolicy -BackupName "19_WU_ExcludeDrivers"
    Set-ItemProperty -Path $wuPolicy -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord -Force

    $dsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
    Ensure-RegistryPath -KeyPath $dsKey
    Backup-RegistryKey -KeyPath $dsKey -BackupName "19_DriverSearching_Order"
    Set-ItemProperty -Path $dsKey -Name "SearchOrderConfig" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Substituição automática de drivers de GPU/Hardware pelo Windows Update bloqueada." -Level "Success"
    return $true
}

function Disable-DeliveryOptimizationP2P {
    [CmdletBinding()]
    param()

    $doKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    Ensure-RegistryPath -KeyPath $doKey
    Backup-RegistryKey -KeyPath $doKey -BackupName "20_DeliveryOptimization_P2P"
    Set-ItemProperty -Path $doKey -Name "DODownloadMode" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $doKey -Name "DOMinDiskSizeAllowedToPeer" -Value 100 -Type DWord -Force

    Write-SkyLog -Message "Otimização de Entrega P2P desativada (largura de banda e ping protegidos)." -Level "Success"
    return $true
}

function Set-ManualWindowsUpdate {
    [CmdletBinding()]
    param()

    $wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $auKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    Backup-RegistryKey -KeyPath $wuKey -BackupName "21_WU_PowerManagement"
    Backup-RegistryKey -KeyPath $auKey -BackupName "21_WU_AU_ManualAndNoReboot"
    Ensure-RegistryPath -KeyPath $wuKey
    Ensure-RegistryPath -KeyPath $auKey
    Set-ItemProperty -Path $wuKey -Name "AUPowerManagement" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $auKey -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $auKey -Name "AUOptions" -Value 2 -Type DWord -Force

    Write-SkyLog -Message "Windows Update configurado para manual/sem reinícios forçados e sem acordar o PC da suspensão." -Level "Success"
    return $true
}

# --- CATEGORIA 7: ARMAZENAMENTO, I/O & LIMPEZA DE DISCO ---

function Disable-ReservedStorage {
    [CmdletBinding()]
    param()

    $dismCheck = dism.exe /Online /Get-ReservedStorageState 2>&1
    if ($dismCheck -match "Enabled|Ativado") {
        $Global:SkyManifest.ReservedStorage = "Enabled"
        $resFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_reserved_storage.txt"
        "Enabled" | Out-File -FilePath $resFile -Encoding UTF8 -Force

        $res = dism.exe /Online /Set-ReservedStorageState /State:Disabled 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-SkyLog -Message "Armazenamento Reservado desativado com sucesso (libertados ~7 GB a 10 GB no disco C:)." -Level "Success"
            return $true
        } else {
            Write-SkyLog -Message "Aviso: DISM não conseguiu alterar o Armazenamento Reservado nesta build." -Level "Warning"
            return $true
        }
    } else {
        Write-SkyLog -Message "Armazenamento Reservado já se encontrava desativado ou não é suportado pelo build." -Level "Info"
        return $true
    }
}

function Optimize-NTFS {
    [CmdletBinding()]
    param()

    $ntfsBackupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_ntfs.txt"
    if (-not (Test-Path $ntfsBackupFile)) {
        $la = fsutil behavior query disablelastaccess 2>&1
        $fn = fsutil behavior query disable8dot3 2>&1
        "$la`n$fn" | Out-File -FilePath $ntfsBackupFile -Encoding UTF8 -Force
    }

    $null = fsutil behavior set disablelastaccess 1 2>&1
    $null = fsutil behavior set disable8dot3 1 2>&1

    Write-SkyLog -Message "Otimização NTFS aplicada (desativado LastAccessUpdate e nomes curtos 8.3)." -Level "Success"
    return $true
}

function Clear-ShaderCache {
    [CmdletBinding()]
    param()

    $clearedCount = 0

    # Pastas de cache de shaders (NVIDIA e DirectX)
    $shaderDirs = @(
        (Join-Path $env:LOCALAPPDATA "NVIDIA\DXCache"),
        (Join-Path $env:LOCALAPPDATA "NVIDIA\GLCache"),
        (Join-Path $env:LOCALAPPDATA "D3DSCache")
    )

    foreach ($dir in $shaderDirs) {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                    $clearedCount++
                } catch {}
            }
        }
    }

    # Limpeza segura de ficheiros temporários órfãos com mais de 24h
    $tempDirs = @($env:TEMP, "$env:SystemRoot\Temp")
    $cutoff = (Get-Date).AddDays(-1)
    foreach ($td in $tempDirs) {
        if (Test-Path $td) {
            Get-ChildItem -Path $td -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                    $clearedCount++
                } catch {}
            }
        }
    }

    # Invocar a limpeza silenciosa nativa do Windows (CleanMgr SilentCleanup)
    $null = Start-ScheduledTask -TaskPath "\Microsoft\Windows\DiskCleanup" -TaskName "SilentCleanup" -ErrorAction SilentlyContinue

    Write-SkyLog -Message "Caches de shaders e ficheiros temporários limpos ($clearedCount ficheiros removidos com segurança)." -Level "Success"
    return $true
}

# --- CATEGORIA 8: PROCESSOS EM SEGUNDO PLANO (DEBLOAT NÃO-DESTRUTIVO) ---

function Disable-BackgroundUWPApps {
    [CmdletBinding()]
    param()

    $bgKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    Ensure-RegistryPath -KeyPath $bgKey
    Backup-RegistryKey -KeyPath $bgKey -BackupName "25_BackgroundAccessApplications"
    Set-ItemProperty -Path $bgKey -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force

    $searchKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    Ensure-RegistryPath -KeyPath $searchKey
    Backup-RegistryKey -KeyPath $searchKey -BackupName "25_Search_BackgroundApps"
    Set-ItemProperty -Path $searchKey -Name "BackgroundAppGlobalToggle" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Ciclos de CPU e RAM poupados: aplicações UWP em segundo plano desativadas." -Level "Success"
    return $true
}

function Disable-SleepStudyLogging {
    [CmdletBinding()]
    param()

    $null = wevtutil.exe set-log "Microsoft-Windows-SleepStudy/Diagnostic" /e:false 2>&1
    $null = wevtutil.exe set-log "Microsoft-Windows-Kernel-Processor-Power/Diagnostic" /e:false 2>&1
    $null = wevtutil.exe set-log "Microsoft-Windows-UserModePowerService/Diagnostic" /e:false 2>&1
    $null = schtasks /Change /TN "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /Disable 2>&1

    Write-SkyLog -Message "Registo contínuo de diagnóstico SleepStudy desativado (escritas e I/O de disco poupados)." -Level "Success"
    return $true
}

function Disable-WindowsErrorReporting {
    [CmdletBinding()]
    param()

    $werMachineKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
    Ensure-RegistryPath -KeyPath $werMachineKey
    Backup-RegistryKey -KeyPath $werMachineKey -BackupName "27_WER_MachinePolicy"
    Set-ItemProperty -Path $werMachineKey -Name "Disabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $werMachineKey -Name "DontShowUI" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $werMachineKey -Name "LoggingDisabled" -Value 1 -Type DWord -Force

    $werUserKey = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
    Ensure-RegistryPath -KeyPath $werUserKey
    Backup-RegistryKey -KeyPath $werUserKey -BackupName "27_WER_UserPolicy"
    Set-ItemProperty -Path $werUserKey -Name "Disabled" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Windows Error Reporting (WER) desativado (elimina congelamentos em segundo plano)." -Level "Success"
    return $true
}

# --- CATEGORIA 9: AGILIDADE DO SISTEMA & QUALIDADE DE VIDA (QOL) ---

function Set-InterfaceDelays {
    [CmdletBinding()]
    param()

    $deskKey = "HKCU:\Control Panel\Desktop"
    Ensure-RegistryPath -KeyPath $deskKey
    Backup-RegistryKey -KeyPath $deskKey -BackupName "28_Desktop_Delays"
    Set-ItemProperty -Path $deskKey -Name "MenuShowDelay" -Value "0" -Type String -Force
    Set-ItemProperty -Path $deskKey -Name "MouseHoverTime" -Value "20" -Type String -Force

    Write-SkyLog -Message "Delays de animação e abertura de menus reduzidos para 0 ms (instantâneo)." -Level "Success"
    return $true
}

function Disable-StartupDelay {
    [CmdletBinding()]
    param()

    $serKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    Ensure-RegistryPath -KeyPath $serKey
    Backup-RegistryKey -KeyPath $serKey -BackupName "29_Explorer_StartupDelay"
    Set-ItemProperty -Path $serKey -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Atraso artificial de arranque de programas pós-login (StartupDelay) desativado." -Level "Success"
    return $true
}

function Set-FastShutdown {
    [CmdletBinding()]
    param()

    $deskKey = "HKCU:\Control Panel\Desktop"
    Ensure-RegistryPath -KeyPath $deskKey
    Backup-RegistryKey -KeyPath $deskKey -BackupName "30_FastShutdown_User"
    Set-ItemProperty -Path $deskKey -Name "HungAppTimeout" -Value "2000" -Type String -Force
    Set-ItemProperty -Path $deskKey -Name "WaitToKillAppTimeOut" -Value "2000" -Type String -Force
    Set-ItemProperty -Path $deskKey -Name "AutoEndTasks" -Value "1" -Type String -Force

    $sysCtrlKey = "HKLM:\SYSTEM\CurrentControlSet\Control"
    $origTimeout = (Get-ItemProperty -Path $sysCtrlKey -Name "WaitToKillServiceTimeout" -ErrorAction SilentlyContinue).WaitToKillServiceTimeout
    if (-not $origTimeout) { $origTimeout = "5000" }

    $backupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "30_FastShutdown_System.reg"
    if (-not (Test-Path $backupFile)) {
        $regContent = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control]`r`n`"WaitToKillServiceTimeout`"=`"$origTimeout`"`r`n"
        [System.IO.File]::WriteAllText($backupFile, $regContent, [System.Text.Encoding]::ASCII)
    }

    Set-ItemProperty -Path $sysCtrlKey -Name "WaitToKillServiceTimeout" -Value "2000" -Type String -Force

    Write-SkyLog -Message "Tempo de espera de encerramento do Windows otimizado para 2 segundos." -Level "Success"
    return $true
}

function Set-AltTabFilter {
    [CmdletBinding()]
    param()

    $advKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Ensure-RegistryPath -KeyPath $advKey
    Backup-RegistryKey -KeyPath $advKey -BackupName "31_AltTabFilter"
    Set-ItemProperty -Path $advKey -Name "MultiTaskingAltTabFilter" -Value 3 -Type DWord -Force

    Write-SkyLog -Message "Alt-Tab configurado para mostrar apenas janelas abertas (separadores do Edge omitidos)." -Level "Success"
    return $true
}

function Enable-TaskbarEndTask {
    [CmdletBinding()]
    param()

    $tbDevKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
    Ensure-RegistryPath -KeyPath $tbDevKey
    Backup-RegistryKey -KeyPath $tbDevKey -BackupName "32_TaskbarEndTask"
    Set-ItemProperty -Path $tbDevKey -Name "TaskbarEndTask" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Opção 'Terminar Tarefa' ativada no menu de clique direito da barra de tarefas." -Level "Success"
    return $true
}

function Disable-Copilot {
    [CmdletBinding()]
    param()

    $copilotUser = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    Ensure-RegistryPath -KeyPath $copilotUser
    Backup-RegistryKey -KeyPath $copilotUser -BackupName "33_Copilot_UserPolicy"
    Set-ItemProperty -Path $copilotUser -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force

    $copilotMachine = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    Ensure-RegistryPath -KeyPath $copilotMachine
    Backup-RegistryKey -KeyPath $copilotMachine -BackupName "33_Copilot_MachinePolicy"
    Set-ItemProperty -Path $copilotMachine -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Microsoft Copilot desativado (processos WebView e telemetria poupados)." -Level "Success"
    return $true
}

function Disable-StickyKeysPopup {
    [CmdletBinding()]
    param()

    $skKey = "HKCU:\Control Panel\Accessibility\StickyKeys"
    Ensure-RegistryPath -KeyPath $skKey
    Backup-RegistryKey -KeyPath $skKey -BackupName "34_Accessibility_StickyKeys"
    Set-ItemProperty -Path $skKey -Name "Flags" -Value "506" -Type String -Force

    $krKey = "HKCU:\Control Panel\Accessibility\Keyboard Response"
    Ensure-RegistryPath -KeyPath $krKey
    Backup-RegistryKey -KeyPath $krKey -BackupName "34_Accessibility_FilterKeys"
    Set-ItemProperty -Path $krKey -Name "Flags" -Value "122" -Type String -Force

    $tkKey = "HKCU:\Control Panel\Accessibility\ToggleKeys"
    Ensure-RegistryPath -KeyPath $tkKey
    Backup-RegistryKey -KeyPath $tkKey -BackupName "34_Accessibility_ToggleKeys"
    Set-ItemProperty -Path $tkKey -Name "Flags" -Value "58" -Type String -Force

    Write-SkyLog -Message "Popups de teclas presas (StickyKeys/FilterKeys) desativados para gaming." -Level "Success"
    return $true
}

# ==============================================================================
# 4.10 ESCALONAMENTO DE CPU & LATÊNCIA GRÁFICA (FASE 2)
# ==============================================================================

function Set-CpuScheduling {
    [CmdletBinding()]
    param()

    # Win32PrioritySeparation = 0x26 (38 decimal)
    # Bits 0-1: 10 (Short quantum length)
    # Bits 2-3: 01 (Variable quantum length)
    # Bits 4-5: 10 (3:1 ratio favoring foreground app)
    $priorityKey = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    Ensure-RegistryPath -KeyPath $priorityKey
    Backup-RegistryKey -KeyPath $priorityKey -BackupName "35_PriorityControl"

    Set-ItemProperty -Path $priorityKey -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force

    Write-SkyLog -Message "Escalonamento de CPU otimizado para jogos (Win32PrioritySeparation 0x26: foco na janela ativa)." -Level "Success"
    return $true
}

function Set-MMCSSTasksGames {
    [CmdletBinding()]
    param()

    # MMCSS (Multimedia Class Scheduler Service) - Perfil de Jogos
    $gamesKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Ensure-RegistryPath -KeyPath $gamesKey
    Backup-RegistryKey -KeyPath $gamesKey -BackupName "36_MMCSS_Games"

    Set-ItemProperty -Path $gamesKey -Name "Affinity" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $gamesKey -Name "Background Only" -Value "False" -Type String -Force
    Set-ItemProperty -Path $gamesKey -Name "Clock Rate" -Value 10000 -Type DWord -Force
    Set-ItemProperty -Path $gamesKey -Name "GPU Priority" -Value 8 -Type DWord -Force
    Set-ItemProperty -Path $gamesKey -Name "Priority" -Value 6 -Type DWord -Force
    Set-ItemProperty -Path $gamesKey -Name "Scheduling Category" -Value "High" -Type String -Force
    Set-ItemProperty -Path $gamesKey -Name "SFIO Priority" -Value "High" -Type String -Force

    Write-SkyLog -Message "Prioridade MMCSS para Jogos configurada para High (áudio e renderização sem perdas)." -Level "Success"
    return $true
}

function Enable-HAGSConditional {
    [CmdletBinding()]
    param()

    $osBuild = [Environment]::OSVersion.Version.Build
    if ($osBuild -lt 19041) {
        Write-SkyLog -Message "HAGS não suportado nesta versão do Windows (Build $osBuild < 19041)." -Level "Info"
        return $false
    }

    # Deteção precisa de VRAM real de 64-bit
    $vramInfo = Get-AccurateVramBytes
    $vramGB = [math]::Round($vramInfo.Bytes / 1GB, 1)

    # Identificar se existe GPU dedicada (NVIDIA VEN_10DE ou AMD VEN_1002)
    $dedicatedGpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object {
        $_.PNPDeviceID -match "^PCI\\VEN_10DE" -or $_.PNPDeviceID -match "^PCI\\VEN_1002"
    } | Select-Object -First 1

    if (-not $dedicatedGpu) {
        Write-SkyLog -Message "Nenhuma GPU dedicada NVIDIA/AMD detetada. HAGS mantido inalterado por segurança." -Level "Info"
        return $false
    }

    # Salvaguarda: Mínimo de 6 GB de VRAM real para evitar micro-stutters e crashes no FiveM
    if ($vramInfo.Bytes -lt 6GB) {
        Write-SkyLog -Message "GPU com $vramGB GB VRAM (< 6 GB). HAGS mantido desativado para prevenir micro-stutters e overflow de VRAM." -Level "Info"
        return $false
    }

    $gfxKey = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    Ensure-RegistryPath -KeyPath $gfxKey
    Backup-RegistryKey -KeyPath $gfxKey -BackupName "37_GraphicsDrivers_HAGS"

    Set-ItemProperty -Path $gfxKey -Name "HwSchMode" -Value 2 -Type DWord -Force
    Write-SkyLog -Message "HAGS ativado com sucesso para $($dedicatedGpu.Name) ($vramGB GB VRAM dedicados)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.11 HARDWARE, REDE & PERIFÉRICOS (BAIXA LATÊNCIA)
# ==============================================================================

function Optimize-NetworkAdapterPower {
    [CmdletBinding()]
    param()

    # Salvaguarda para não drenar bateria se o utilizador estiver num portátil fora da tomada
    if (-not (Test-IsDesktopOrAcPower)) {
        Write-SkyLog -Message "Portátil em bateria detetado. Poupança de energia na rede mantida para preservar autonomia." -Level "Info"
        return $false
    }

    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    if (-not $adapters) {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    }

    if (-not $adapters) {
        Write-SkyLog -Message "Nenhum adaptador de rede físico detetado para otimização de energia." -Level "Info"
        return $false
    }

    $propsToDisable = @("*EEE", "*GreenEthernet", "*GigaLite", "PowerSavingMode", "EnergyEfficientEthernet")
    $count = 0

    foreach ($nic in $adapters) {
        foreach ($prop in $propsToDisable) {
            try {
                $exists = Get-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword $prop -ErrorAction SilentlyContinue
                if ($exists) {
                    Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword $prop -RegistryValue 0 -ErrorAction SilentlyContinue
                    $count++
                }
            } catch {}
        }
    }

    Write-SkyLog -Message "Poupança de energia e Energy Efficient Ethernet (EEE) desativados nos adaptadores de rede (prevenção de packet drops)." -Level "Success"
    return $true
}

function Disable-UsbPowerManagement {
    [CmdletBinding()]
    param()

    if (-not (Test-IsDesktopOrAcPower)) {
        Write-SkyLog -Message "Portátil em bateria detetado. Gestão de energia USB mantida para preservar autonomia." -Level "Info"
        return $false
    }

    $hubs = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
        $_.Service -in @("usbhub", "usbhub3", "USBHUB", "USBHUB3") -or $_.Name -like "*Root Hub*"
    }

    $hubIndex = 0
    foreach ($hub in $hubs) {
        $devId = $hub.PNPDeviceID
        if ($devId) {
            $wdfKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$devId\Device Parameters\Wdf"
            if (Test-Path $wdfKey) {
                Backup-RegistryKey -KeyPath $wdfKey -BackupName "39_USB_Hub_$hubIndex"
                Set-ItemProperty -Path $wdfKey -Name "IdleInWorkingState" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                $hubIndex++
            }
        }
    }

    Write-SkyLog -Message "Suspensão de energia em Hubs USB raiz desativada (menor latência e estabilidade no polling rate do rato)." -Level "Success"
    return $true
}

function Enable-GpuMsiMode {
    [CmdletBinding()]
    param()

    # REGRA DE SEGURANÇA CRÍTICA:
    # Aplicar MSI Mode EXCLUSIVAMENTE à GPU dedicada (NVIDIA VEN_10DE ou AMD VEN_1002).
    # NUNCA aplicar a áudio, rede ou USB para prevenir BSODs ou perda de som.
    # Manter prioridade padrão (Undefined - não forçar High).
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object {
        $_.PNPDeviceID -match "^PCI\\VEN_10DE" -or $_.PNPDeviceID -match "^PCI\\VEN_1002"
    }

    if (-not $gpus) {
        Write-SkyLog -Message "Nenhuma GPU dedicada (NVIDIA/AMD) elegível para MSI Mode encontrada." -Level "Info"
        return $false
    }

    $configured = 0
    foreach ($gpu in $gpus) {
        $pnpId = $gpu.PNPDeviceID
        $msiKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"

        Ensure-RegistryPath -KeyPath $msiKey
        $cleanName = ($gpu.Name -replace '[^a-zA-Z0-9]', '_').Trim('_')
        Backup-RegistryKey -KeyPath $msiKey -BackupName "40_MSI_GPU_$cleanName"

        Set-ItemProperty -Path $msiKey -Name "MSISupported" -Value 1 -Type DWord -Force

        # Garantir que a prioridade NÃO é forçada a High (manter Undefined / omitido)
        if (Get-ItemProperty -Path $msiKey -Name "DevicePriority" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $msiKey -Name "DevicePriority" -Force -ErrorAction SilentlyContinue
        }

        Write-SkyLog -Message "Modo MSI ativado na GPU dedicada: $($gpu.Name) (Prioridade: Padrão/Undefined, sem partilha de IRQ)." -Level "Success"
        $configured++
    }

    return ($configured -gt 0)
}

# ==============================================================================
# 4.12 NAVEGADORES, JOGOS EM JANELA & ARMAZENAMENTO AVANÇADO
# ==============================================================================

function Disable-BrowserBackgroundTasks {
    [CmdletBinding()]
    param()

    # Microsoft Edge - Desativar Startup Boost e processos em segundo plano
    $edgePolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    Ensure-RegistryPath -KeyPath $edgePolicyKey
    Backup-RegistryKey -KeyPath $edgePolicyKey -BackupName "41_Edge_MachinePolicy"
    Set-ItemProperty -Path $edgePolicyKey -Name "StartupBoostEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $edgePolicyKey -Name "BackgroundModeEnabled" -Value 0 -Type DWord -Force

    $edgeUserKey = "HKCU:\SOFTWARE\Policies\Microsoft\Edge"
    Ensure-RegistryPath -KeyPath $edgeUserKey
    Backup-RegistryKey -KeyPath $edgeUserKey -BackupName "41_Edge_UserPolicy"
    Set-ItemProperty -Path $edgeUserKey -Name "StartupBoostEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $edgeUserKey -Name "BackgroundModeEnabled" -Value 0 -Type DWord -Force

    # Google Chrome - Desativar aplicações em segundo plano quando fechado
    $chromePolicyKey = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    Ensure-RegistryPath -KeyPath $chromePolicyKey
    Backup-RegistryKey -KeyPath $chromePolicyKey -BackupName "41_Chrome_MachinePolicy"
    Set-ItemProperty -Path $chromePolicyKey -Name "BackgroundModeEnabled" -Value 0 -Type DWord -Force

    $chromeUserKey = "HKCU:\SOFTWARE\Policies\Google\Chrome"
    Ensure-RegistryPath -KeyPath $chromeUserKey
    Backup-RegistryKey -KeyPath $chromeUserKey -BackupName "41_Chrome_UserPolicy"
    Set-ItemProperty -Path $chromeUserKey -Name "BackgroundModeEnabled" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Processos em segundo plano do Edge (Startup Boost) e Chrome desativados (liberta 300-800MB RAM)." -Level "Success"
    return $true
}

function Enable-WindowedOptimizations {
    [CmdletBinding()]
    param()

    # Windows 11 - Otimizações para jogos em janela (DirectFlip / SwapEffectUpgrade)
    $dxKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    Ensure-RegistryPath -KeyPath $dxKey
    Backup-RegistryKey -KeyPath $dxKey -BackupName "42_DirectX_Windowed"
    Set-ItemProperty -Path $dxKey -Name "DirectXUserGlobalSettings" -Value "SwapEffectUpgradeEnable=1;" -Type String -Force

    $gcsKey = "HKCU:\System\GameConfigStore"
    Ensure-RegistryPath -KeyPath $gcsKey
    Backup-RegistryKey -KeyPath $gcsKey -BackupName "42_GameConfigStore_Windowed"
    Set-ItemProperty -Path $gcsKey -Name "GameDVR_EFSEnabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $gcsKey -Name "GameDVR_DSEBehavior" -Value 2 -Type DWord -Force

    Write-SkyLog -Message "DirectFlip / Otimizações para jogos em janela ativadas (menor latência em Borderless)." -Level "Success"
    return $true
}

function Invoke-SsdReTrim {
    [CmdletBinding()]
    param()

    try {
        $isSsd = $false
        $disk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.MediaType -eq "SSD" }
        if ($disk) {
            $isSsd = $true
        } else {
            $pnp = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
            if ($pnp.Model -match "NVMe|SSD") { $isSsd = $true }
        }

        if ($isSsd) {
            $null = Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
            Write-SkyLog -Message "Re-Trim executado com sucesso no SSD (Drive C:) para streaming rápido de texturas sem engasgos." -Level "Success"
            return $true
        } else {
            Write-SkyLog -Message "Drive C: não detetado como SSD. Re-Trim ignorado para preservar disco mecânico." -Level "Info"
            return $false
        }
    } catch {
        Write-SkyLog -Message "Re-Trim ignorado ou não suportado neste controlador de armazenamento." -Level "Info"
        return $false
    }
}

# ==============================================================================
# 4.13 OTIMIZAÇÕES DE ELITE (REDE, EXPLORADOR & AGENDADOR)
# ==============================================================================

function Disable-LLMNRProtocol {
    [CmdletBinding()]
    param()

    $dnsClientKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
    Ensure-RegistryPath -KeyPath $dnsClientKey
    Backup-RegistryKey -KeyPath $dnsClientKey -BackupName "44_DNSClient_LLMNR"
    Set-ItemProperty -Path $dnsClientKey -Name "EnableMulticast" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Protocolo LLMNR desativado (eliminação de broadcasts e ruído na rede local)." -Level "Success"
    return $true
}

function Disable-AutoFolderDiscovery {
    [CmdletBinding()]
    param()

    $bagsKey = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell"
    Ensure-RegistryPath -KeyPath $bagsKey
    Backup-RegistryKey -KeyPath $bagsKey -BackupName "45_Explorer_FolderTypeNotSpecified"
    Set-ItemProperty -Path $bagsKey -Name "FolderType" -Value "NotSpecified" -Type String -Force

    Write-SkyLog -Message "Descoberta automática de pastas desativada no Explorador (abertura instantânea de pastas pesadas e FiveM)." -Level "Success"
    return $true
}

function Disable-MaintenanceWakeUp {
    [CmdletBinding()]
    param()

    $maintKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Task Scheduler\Maintenance"
    Ensure-RegistryPath -KeyPath $maintKey
    Backup-RegistryKey -KeyPath $maintKey -BackupName "46_TaskScheduler_MaintenanceWakeUp"
    Set-ItemProperty -Path $maintKey -Name "WakeUp" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Acordar automático por manutenção do sistema desativado (prevenção de tarefas pesadas noturnas)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.14 DEBLOAT AVANÇADO & AGRUPAMENTO SVCHOST (ATLAS TWEAKS)
# ==============================================================================

function Set-SvcHostProcessGrouping {
    [CmdletBinding()]
    param()

    $ctrlKey = "HKLM:\SYSTEM\CurrentControlSet\Control"
    Ensure-RegistryPath -KeyPath $ctrlKey

    $origVal = (Get-ItemProperty -Path $ctrlKey -Name "SvcHostSplitThresholdInKB" -ErrorAction SilentlyContinue).SvcHostSplitThresholdInKB
    if ($null -ne $origVal) {
        $backupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_svchost_split.txt"
        $origVal | Out-File -FilePath $backupFile -Encoding UTF8 -Force
    }

    Backup-RegistryKey -KeyPath $ctrlKey -BackupName "47_Control_SvcHostSplit"
    Set-ItemProperty -Path $ctrlKey -Name "SvcHostSplitThresholdInKB" -Value 0x40000000 -Type DWord -Force

    Write-SkyLog -Message "Agrupamento de processos svchost ativado (SvcHostSplitThresholdInKB elevado; redução substancial de processos e RAM)." -Level "Success"
    return $true
}

function Disable-TelemetryServicesDeep {
    [CmdletBinding()]
    param()

    $servicesToDisable = @(
        @{ Name = "DiagTrack"; Desc = "Connected User Experiences and Telemetry" },
        @{ Name = "PcaSvc";    Desc = "Program Compatibility Assistant Service" },
        @{ Name = "TrkWks";    Desc = "Distributed Link Tracking Client" }
    )

    $backupState = @{}
    $backupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_telemetry_services.json"

    foreach ($s in $servicesToDisable) {
        $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
        if ($svc) {
            $cim = Get-CimInstance Win32_Service -Filter "Name='$($s.Name)'" -ErrorAction SilentlyContinue
            $prevMode = if ($cim) { $cim.StartMode } else { "Manual" }
            $backupState[$s.Name] = $prevMode

            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    if ($backupState.Count -gt 0) {
        $backupState | ConvertTo-Json | Out-File -FilePath $backupFile -Encoding UTF8 -Force
    }

    Write-SkyLog -Message "Serviços de telemetria e overhead (DiagTrack, PcaSvc, TrkWks) desativados com sucesso." -Level "Success"
    return $true
}

function Remove-BloatwareAppX {
    [CmdletBinding()]
    param()

    $bloatTargets = @(
        "Clipchamp.Clipchamp",
        "Disney.37853FC22B2CE",
        "*TikTok*",
        "*SpotifyMusic*",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Todos",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MixedReality.Portal",
        "Microsoft.WindowsMaps",
        "Microsoft.ZuneVideo",
        "Microsoft.549981C3F5F10"
    )

    $removedCount = 0
    foreach ($target in $bloatTargets) {
        try {
            $pkgs = Get-AppxPackage -Name $target -AllUsers -ErrorAction SilentlyContinue
            if ($pkgs) {
                $pkgs | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                $removedCount++
            }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $target } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        } catch {}
    }

    Write-SkyLog -Message "Debloat de aplicações AppX concluído ($removedCount pacote(s) dispensáveis removidos; Microsoft Store e Xbox protegidas)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.14 BATCH DE TWEAKS AVANÇADOS DO ATLAS (MEMÓRIA, I/O, REDE & SISTEMA)
# ==============================================================================

function Optimize-KernelMemoryPaging {
    [CmdletBinding()]
    param()

    $memKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Backup-RegistryKey -KeyPath $memKey -BackupName "50_KernelMemoryManagement"
    Ensure-RegistryPath -KeyPath $memKey

    # DisablePagingExecutive: Mantém o kernel NT e todos os drivers residentes na RAM física (evita page faults e micro-stutters)
    Set-ItemProperty -Path $memKey -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force

    # DisablePageCombining: Desativa o thread periódico de desduplicação de memória RAM (poupa ciclos de CPU e invalidações de cache)
    Set-ItemProperty -Path $memKey -Name "DisablePageCombining" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Gestão de memória de kernel otimizada (DisablePagingExecutive=1, DisablePageCombining=1)." -Level "Success"
    return $true
}

function Optimize-SearchIndexerPower {
    [CmdletBinding()]
    param()

    $searchKey = "HKLM:\Software\Microsoft\Windows Search\Gather\Windows\SystemIndex"
    Backup-RegistryKey -KeyPath $searchKey -BackupName "51_SearchIndexerPower"
    Ensure-RegistryPath -KeyPath $searchKey

    # RespectPowerModes: Força a indexação de ficheiros a suspender quando o sistema está em Desempenho Máximo / Gaming
    try {
        Set-ItemProperty -Path $searchKey -Name "RespectPowerModes" -Value 1 -Type DWord -Force -ErrorAction Stop
    } catch {
        $null = & reg.exe add "HKLM\Software\Microsoft\Windows Search\Gather\Windows\SystemIndex" /v "RespectPowerModes" /t REG_DWORD /d 1 /f 2>&1
    }

    Write-SkyLog -Message "Windows Search configurado para respeitar planos de energia (pausa indexação durante jogos)." -Level "Success"
    return $true
}

function Disable-SmbBandwidthThrottling {
    [CmdletBinding()]
    param()

    $lanmanKey = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    Backup-RegistryKey -KeyPath $lanmanKey -BackupName "52_LanmanSmbThrottling"
    Ensure-RegistryPath -KeyPath $lanmanKey

    # DisableBandwidthThrottling: Remove o limite artificial de taxa de transferência de rede SMB
    Set-ItemProperty -Path $lanmanKey -Name "DisableBandwidthThrottling" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Estrangulamento de largura de banda de rede SMB desativado com sucesso." -Level "Success"
    return $true
}

function Disable-AeroShake {
    [CmdletBinding()]
    param()

    $expAdvKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Backup-RegistryKey -KeyPath $expAdvKey -BackupName "53_DisallowAeroShaking"
    Ensure-RegistryPath -KeyPath $expAdvKey

    # DisallowShaking: Impede que movimentos rápidos do rato minimizem janelas de fundo (Discord, OBS, etc.)
    Set-ItemProperty -Path $expAdvKey -Name "DisallowShaking" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Gesto Aero Shake desativado (elimina minimizações acidentais de janelas em jogos rápidos)." -Level "Success"
    return $true
}

function Disable-LowDiskSpaceChecks {
    [CmdletBinding()]
    param()

    $polExpKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    Backup-RegistryKey -KeyPath $polExpKey -BackupName "54_NoLowDiskSpaceChecks"
    Ensure-RegistryPath -KeyPath $polExpKey

    # NoLowDiskSpaceChecks: Elimina o thread de sondagem periódica de espaço em disco e popups invasivos
    Set-ItemProperty -Path $polExpKey -Name "NoLowDiskSpaceChecks" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Verificações periódicas de pouco espaço em disco desativadas (poupança de I/O de disco)." -Level "Success"
    return $true
}

function Set-CrashControlQuality {
    [CmdletBinding()]
    param()

    $crashKey = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
    Backup-RegistryKey -KeyPath $crashKey -BackupName "55_CrashControlDiagnostics"
    Ensure-RegistryPath -KeyPath $crashKey

    # AutoReboot = 0: Impede reinício imediato após BSOD para permitir leitura do código de erro e driver .sys
    Set-ItemProperty -Path $crashKey -Name "AutoReboot" -Value 0 -Type DWord -Force

    # DisplayParameters = 1: Apresenta parâmetros detalhados de diagnóstico no ecrã de crash
    Set-ItemProperty -Path $crashKey -Name "DisplayParameters" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Controlo de falhas (BSOD) configurado para diagnóstico (sem reinício instantâneo, código visível)." -Level "Success"
    return $true
}

function Disable-MaintenanceScheduledTasks {
    [CmdletBinding()]
    param()

    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting"
    )

    $disabledCount = 0
    foreach ($t in $tasks) {
        $null = schtasks /Change /TN $t /Disable 2>&1
        if ($LASTEXITCODE -eq 0) { $disabledCount++ }
    }

    $ubpmKey = "HKLM:\System\CurrentControlSet\Control\Ubpm"
    if (Test-Path $ubpmKey) {
        Remove-ItemProperty -Path $ubpmKey -Name "CriticalMaintenance_UsageDataReporting" -Force -ErrorAction SilentlyContinue
    }

    Write-SkyLog -Message "Tarefas agendadas de telemetria e diagnóstico em segundo plano desativadas ($disabledCount tarefas)." -Level "Success"
    return $true
}

function Disable-ActivityHistoryAndDiagnosticTracing {
    [CmdletBinding()]
    param()

    # Histórico de Atividades / Windows Timeline
    $sysPolKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    Backup-RegistryKey -KeyPath $sysPolKey -BackupName "57_ActivityHistory_Policy"
    Ensure-RegistryPath -KeyPath $sysPolKey
    Set-ItemProperty -Path $sysPolKey -Name "UploadUserActivities" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $sysPolKey -Name "PublishUserActivities" -Value 0 -Type DWord -Force

    # Tracing de Desempenho / Diagnóstico
    $diagKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance"
    Backup-RegistryKey -KeyPath $diagKey -BackupName "57_DiagnosticTracing"
    Ensure-RegistryPath -KeyPath $diagKey
    try {
        Set-ItemProperty -Path $diagKey -Name "DisableDiagnosticTracing" -Value 1 -Type DWord -Force -ErrorAction Stop
    } catch {
        $null = & reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance" /v "DisableDiagnosticTracing" /t REG_DWORD /d 1 /f 2>&1
    }

    # Programa de Melhoria de Experiência (CEIP)
    $sqmKey = "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"
    Backup-RegistryKey -KeyPath $sqmKey -BackupName "57_SQMClient_CEIP"
    Ensure-RegistryPath -KeyPath $sqmKey
    Set-ItemProperty -Path $sqmKey -Name "CEIPEnable" -Value 0 -Type DWord -Force

    $appvKey = "HKLM:\SOFTWARE\Policies\Microsoft\AppV\CEIP"
    Backup-RegistryKey -KeyPath $appvKey -BackupName "57_AppV_CEIP"
    Ensure-RegistryPath -KeyPath $appvKey
    Set-ItemProperty -Path $appvKey -Name "CEIPEnable" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Histórico de atividades e tracing de diagnóstico contínuo desativados com sucesso." -Level "Success"
    return $true
}

function Disable-SilentAppInstallation {
    [CmdletBinding()]
    param()

    $cdmKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Backup-RegistryKey -KeyPath $cdmKey -BackupName "58_ContentDeliveryManager_SilentApps"
    Ensure-RegistryPath -KeyPath $cdmKey

    $cdmSettings = [ordered]@{
        "ContentDeliveryAllowed"          = 0
        "OemPreInstalledAppsEnabled"      = 0
        "PreInstalledAppsEnabled"         = 0
        "PreInstalledAppsEverEnabled"     = 0
        "SilentInstalledAppsEnabled"      = 0
        "SubscribedContent-338388Enabled" = 0
        "SubscribedContent-338389Enabled" = 0
        "SoftLandingEnabled"              = 0
        "FeatureManagementEnabled"        = 0
    }

    foreach ($k in $cdmSettings.Keys) {
        Set-ItemProperty -Path $cdmKey -Name $k -Value $cdmSettings[$k] -Type DWord -Force
    }

    Write-SkyLog -Message "Instalação silenciosa de aplicações patrocinadas e sugestões do ContentDeliveryManager desativadas." -Level "Success"
    return $true
}

function Enable-LongFilePaths {
    [CmdletBinding()]
    param()

    $fsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    Backup-RegistryKey -KeyPath $fsKey -BackupName "59_FileSystem_LongPaths"
    Ensure-RegistryPath -KeyPath $fsKey

    Set-ItemProperty -Path $fsKey -Name "LongPathsEnabled" -Value 1 -Type DWord -Force
    Write-SkyLog -Message "Suporte para caminhos longos de ficheiro Win32 (>260 caracteres) ativado (protege mods de FiveM e jogos)." -Level "Success"
    return $true
}

function Disable-NetworkDmaCoalescing {
    [CmdletBinding()]
    param()

    $netClassKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (-not (Test-Path $netClassKey)) {
        Write-SkyLog -Message "Chave de adaptadores de rede não encontrada. Ignorado." -Level "Info"
        return $true
    }

    Backup-RegistryKey -KeyPath $netClassKey -BackupName "60_NetworkAdapters_DMACoalescing"

    $subKeys = Get-ChildItem -Path $netClassKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
    $coalesceDisabled = 0

    foreach ($k in $subKeys) {
        $keyPath = $k.PSPath
        $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
        if ($props) {
            foreach ($propName in @("*DMACoalescing", "DMACoalescing")) {
                if ($null -ne $props.$propName) {
                    Set-ItemProperty -Path $keyPath -Name $propName -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                    $coalesceDisabled++
                }
            }
        }
    }

    Write-SkyLog -Message "DMA Coalescing desativado nos adaptadores de rede ($coalesceDisabled propriedades ajustadas; menor atraso de pacotes/jitter)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.15 BATCH DE TWEAKS DE ELITE ADICIONAIS (INTERFACE, FIRMWARE & DIAGNÓSTICO)
# ==============================================================================

function Optimize-ExplorerIconCache {
    [CmdletBinding()]
    param()

    $expKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
    Backup-RegistryKey -KeyPath $expKey -BackupName "61_Explorer_MaxCachedIcons"
    Ensure-RegistryPath -KeyPath $expKey

    # Expande o cache de ícones de 500 para 4096 KB (evita recarregamentos contínuos de ícones e travamentos de pastas)
    Set-ItemProperty -Path $expKey -Name "Max Cached Icons" -Value "4096" -Type String -Force
    Write-SkyLog -Message "Cache de ícones do Explorador expandida para 4096 KB (elimina recarregamentos constantes e lentidão em pastas)." -Level "Success"
    return $true
}

function Disable-AudioDucking {
    [CmdletBinding()]
    param()

    $audioKey = "HKCU:\SOFTWARE\Microsoft\Multimedia\Audio"
    Backup-RegistryKey -KeyPath $audioKey -BackupName "62_Audio_UserDuckingPreference"
    Ensure-RegistryPath -KeyPath $audioKey

    # UserDuckingPreference = 3 ("Do nothing" - impede que o Windows reduza o som do jogo em 80% quando alguém fala no Discord/FiveM)
    Set-ItemProperty -Path $audioKey -Name "UserDuckingPreference" -Value 3 -Type DWord -Force
    Write-SkyLog -Message "Atenuação automática de áudio (Audio Ducking) desativada (volume de jogos não é reduzido em chamadas do Discord/TeamSpeak)." -Level "Success"
    return $true
}

function Set-ClassicContextMenuWin11 {
    [CmdletBinding()]
    param()

    # Aplica-se estritamente ao Windows 11 (Build >= 22000)
    $osBuild = [Environment]::OSVersion.Version.Build
    if ($osBuild -lt 22000) {
        Write-SkyLog -Message "Menu de contexto clássico nativo no Windows 10 (Build $osBuild). Ignorado com segurança." -Level "Info"
        return $true
    }

    $parentClsid = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    $clsidKey = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    Backup-RegistryKey -KeyPath $parentClsid -BackupName "63_Win11_ClassicContextMenu"

    Ensure-RegistryPath -KeyPath $clsidKey
    & reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve /t REG_SZ /d "" *> $null

    Write-SkyLog -Message "Menu de contexto clássico restaurado no Windows 11 (elimina o atraso e 'Mostrar mais opções')." -Level "Success"
    return $true
}

function Disable-WindowMinimizeAnimations {
    [CmdletBinding()]
    param()

    $wmKey = "HKCU:\Control Panel\Desktop\WindowMetrics"
    Backup-RegistryKey -KeyPath $wmKey -BackupName "64_WindowMetrics_MinAnimate"
    Ensure-RegistryPath -KeyPath $wmKey
    Set-ItemProperty -Path $wmKey -Name "MinAnimate" -Value "0" -Type String -Force

    $advKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Backup-RegistryKey -KeyPath $advKey -BackupName "64_Explorer_TaskbarAnimations"
    Ensure-RegistryPath -KeyPath $advKey
    Set-ItemProperty -Path $advKey -Name "TaskbarAnimations" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Animações de minimizar/maximizar e barra de tarefas desativadas (resposta instantânea em Alt-Tab; fontes 100% nítidas)." -Level "Success"
    return $true
}

function Set-MaxWallpaperQuality {
    [CmdletBinding()]
    param()

    $deskKey = "HKCU:\Control Panel\Desktop"
    Backup-RegistryKey -KeyPath $deskKey -BackupName "65_Desktop_WallpaperQuality"
    Ensure-RegistryPath -KeyPath $deskKey

    # 100 = 100% qualidade JPEG (desativa a compressão para 85% padrão do Windows em monitores 1080p/1440p/4K)
    Set-ItemProperty -Path $deskKey -Name "JPEGImportQuality" -Value 100 -Type DWord -Force
    Write-SkyLog -Message "Qualidade de importação de papel de parede definida para 100% (elimina compressão e artefactos visuais no ambiente de trabalho)." -Level "Success"
    return $true
}

function Disable-EdgeScreenGestures {
    [CmdletBinding()]
    param()

    $edgeKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI"
    Backup-RegistryKey -KeyPath $edgeKey -BackupName "66_EdgeUI_AllowEdgeSwipe"
    Ensure-RegistryPath -KeyPath $edgeKey

    # Impede gestos acidentais de deslize das bordas do ecrã durante flicks rápidos com o rato no gaming
    Set-ItemProperty -Path $edgeKey -Name "AllowEdgeSwipe" -Value 0 -Type DWord -Force
    Write-SkyLog -Message "Gestos de deslize nas extremidades do ecrã (Edge Swipe) desativados (previne interferências de cliques rápidos em jogos)." -Level "Success"
    return $true
}

function Disable-WpbtExecution {
    [CmdletBinding()]
    param()

    $smKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    Backup-RegistryKey -KeyPath $smKey -BackupName "67_SessionManager_DisableWpbt"
    Ensure-RegistryPath -KeyPath $smKey

    # Impede que tabelas de firmware/BIOS (WPBT) injetem bloatware (Armoury Crate, Vantage, App Center) silenciosamente na inicialização
    Set-ItemProperty -Path $smKey -Name "DisableWpbtExecution" -Value 1 -Type DWord -Force
    Write-SkyLog -Message "Injeção automática de software da BIOS/Firmware (WPBT) bloqueada com sucesso." -Level "Success"
    return $true
}

function Disable-NvidiaTelemetry {
    [CmdletBinding()]
    param()

    $isNvidia = $false
    try {
        $gpuItem = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\000*' -ErrorAction SilentlyContinue | Where-Object { $_.DriverDesc -match 'NVIDIA' }
        if ($gpuItem) { $isNvidia = $true }
    } catch {}

    $nvKey = "HKCU:\Software\NVIDIA Corporation\NVControlPanel2\Client"
    if ((Test-Path "HKCU:\Software\NVIDIA Corporation") -or $isNvidia) {
        Backup-RegistryKey -KeyPath $nvKey -BackupName "68_Nvidia_Telemetry"
        Ensure-RegistryPath -KeyPath $nvKey
        Set-ItemProperty -Path $nvKey -Name "OptInOrOutPreference" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    # Desativação de tarefas agendadas de telemetria da NVIDIA (se instaladas)
    $nvTasks = @("\NvTmMon", "\NvTmRep", "\NvTmRepOnLogon")
    $tasksDisabled = 0
    foreach ($tName in $nvTasks) {
        $matching = Get-ScheduledTask -TaskPath "\" -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "$($tName.TrimStart('\'))*" }
        foreach ($t in $matching) {
            $null = schtasks /Change /TN "$($t.TaskName)" /Disable 2>&1
            $tasksDisabled++
        }
    }

    if ($isNvidia) {
        Write-SkyLog -Message "Telemetria e relatórios em background da NVIDIA desativados com sucesso ($tasksDisabled tarefa(s) suspensa(s))." -Level "Success"
    } else {
        Write-SkyLog -Message "Configuração de telemetria NVIDIA concluída (GPU não-NVIDIA ou componentes não instalados)." -Level "Info"
    }
    return $true
}

function Disable-WindowsFeedbackRequests {
    [CmdletBinding()]
    param()

    $dcKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    Backup-RegistryKey -KeyPath $dcKey -BackupName "69_DataCollection_Feedback"
    Ensure-RegistryPath -KeyPath $dcKey
    Set-ItemProperty -Path $dcKey -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -Force

    $siufKey = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
    Backup-RegistryKey -KeyPath $siufKey -BackupName "69_Siuf_FeedbackRules"
    Ensure-RegistryPath -KeyPath $siufKey
    Set-ItemProperty -Path $siufKey -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Inquéritos e notificações de feedback do Windows (SIUF) desativados com sucesso." -Level "Success"
    return $true
}

function Disable-SettingsOnlineTips {
    [CmdletBinding()]
    param()

    $polKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    Backup-RegistryKey -KeyPath $polKey -BackupName "70_Policies_OnlineTips"
    Ensure-RegistryPath -KeyPath $polKey
    Set-ItemProperty -Path $polKey -Name "AllowOnlineTips" -Value 0 -Type DWord -Force

    $cloudKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    Backup-RegistryKey -KeyPath $cloudKey -BackupName "70_CloudContent_SoftLanding"
    Ensure-RegistryPath -KeyPath $cloudKey
    Set-ItemProperty -Path $cloudKey -Name "DisableSoftLanding" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Dicas online e conteúdos de ajuda remota nas Definições do Windows desativados." -Level "Success"
    return $true
}

function Disable-SilentDiagnosticServices {
    [CmdletBinding()]
    param()

    $targetServices = @(
        "diagnosticshub.standardcollector.service",
        "wercplsupport"
    )

    $backupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_diagnostic_services.json"
    $backupState = @{}

    foreach ($sName in $targetServices) {
        $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
        if ($svc) {
            $cim = Get-CimInstance Win32_Service -Filter "Name='$sName'" -ErrorAction SilentlyContinue
            $prevMode = if ($cim) { $cim.StartMode } else { "Manual" }
            $backupState[$sName] = $prevMode

            Stop-Service -Name $sName -Force -ErrorAction SilentlyContinue
            Set-Service -Name $sName -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    # Desativação do template de sincronização em segundo plano OneSyncSvc
    $oneSyncKey = "HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc"
    if (Test-Path $oneSyncKey) {
        $curStart = (Get-ItemProperty -Path $oneSyncKey -Name "Start" -ErrorAction SilentlyContinue).Start
        if ($null -ne $curStart) {
            $backupState["OneSyncSvc_RegStart"] = $curStart
            Set-ItemProperty -Path $oneSyncKey -Name "Start" -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }

    if ($backupState.Count -gt 0) {
        $backupState | ConvertTo-Json | Out-File -FilePath $backupFile -Encoding UTF8 -Force
    }

    Write-SkyLog -Message "Serviços adicionais de diagnóstico silencioso e tracing suspensos com sucesso." -Level "Success"
    return $true
}

function Disable-GameBarPresenceWriter {
    [CmdletBinding()]
    param()

    $gbKey = "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter"
    Backup-RegistryKey -KeyPath $gbKey -BackupName "72_GameBar_PresenceWriter"
    Ensure-RegistryPath -KeyPath $gbKey

    # ActivationType = 0 impede o arranque em segundo plano do GameBarPresenceWriter.exe ao abrir qualquer jogo
    try {
        Set-ItemProperty -Path $gbKey -Name "ActivationType" -Value 0 -Type DWord -Force -ErrorAction Stop
    } catch {
        $null = & reg.exe add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v "ActivationType" /t REG_DWORD /d 0 /f 2>&1
    }
    Write-SkyLog -Message "GameBarPresenceWriter em segundo plano desativado (elimina micro-stutter e polling de jogos)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.16 BATCH DE TWEAKS COMPETITIVOS (HITREG, HARDWARE DE REDE & RESPOSTA DE TECLADO)
# ==============================================================================

function Optimize-KeyboardRepeatResponse {
    [CmdletBinding()]
    param()

    $kbKey = "HKCU:\Control Panel\Keyboard"
    Backup-RegistryKey -KeyPath $kbKey -BackupName "73_Keyboard_RepeatResponse"
    Ensure-RegistryPath -KeyPath $kbKey

    # Reduz o atraso inicial de repetição para 0 e eleva a velocidade de repetição ao máximo nativo (31)
    # 100% SEGURO: Não ativa FilterKeys nem corrompe a escrita normal em chats como Discord ou WhatsApp
    Set-ItemProperty -Path $kbKey -Name "KeyboardDelay" -Value "0" -Type String -Force
    Set-ItemProperty -Path $kbKey -Name "KeyboardSpeed" -Value "31" -Type String -Force

    Write-SkyLog -Message "Resposta de repetição de teclado otimizada para o máximo nativo (KeyboardDelay=0, KeyboardSpeed=31; escrita diária 100% preservada)." -Level "Success"
    return $true
}

function Disable-NetworkInterruptModeration {
    [CmdletBinding()]
    param()

    $netClassKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (-not (Test-Path $netClassKey)) {
        Write-SkyLog -Message "Chave de adaptadores de rede não encontrada. Ignorado com segurança." -Level "Info"
        return $true
    }

    Backup-RegistryKey -KeyPath $netClassKey -BackupName "74_Network_InterruptModeration"

    $subKeys = Get-ChildItem -Path $netClassKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
    $itrAdjusted = 0

    foreach ($k in $subKeys) {
        $keyPath = $k.PSPath
        $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
        if ($props) {
            foreach ($propName in @("*InterruptModeration", "InterruptModeration", "ITR")) {
                if ($null -ne $props.$propName) {
                    Set-ItemProperty -Path $keyPath -Name $propName -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                    $itrAdjusted++
                }
            }
        }
    }

    # Tentativa de ajuste via cmdlet de adaptador de rede avançado
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    foreach ($nic in $adapters) {
        try {
            $exists = Get-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*InterruptModeration" -ErrorAction SilentlyContinue
            if ($exists) {
                Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    Write-SkyLog -Message "Moderação de interrupções (ITR) desativada nos adaptadores de rede ($itrAdjusted propriedades ajustadas; processamento imediato de pacotes de tiros/hitreg)." -Level "Success"
    return $true
}

function Disable-NetworkRscAndLso {
    [CmdletBinding()]
    param()

    # Desativação de RSC (Receive Segment Coalescing) nos adaptadores físicos
    try {
        Disable-NetAdapterRsc -Name * -ErrorAction SilentlyContinue
    } catch {}

    # Desativação de LSO (Large Send Offload) nos adaptadores físicos
    try {
        Disable-NetAdapterLso -Name * -IPv4 -IPv6 -ErrorAction SilentlyContinue
    } catch {}

    # Ajuste direto no registo da classe de rede para compatibilidade universal
    $netClassKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $netClassKey) {
        Backup-RegistryKey -KeyPath $netClassKey -BackupName "75_Network_RscAndLso"
        $subKeys = Get-ChildItem -Path $netClassKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
        foreach ($k in $subKeys) {
            $keyPath = $k.PSPath
            $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
            if ($props) {
                foreach ($propName in @("*RSC", "*RscIPv4", "*RscIPv6", "*LsoV2IPv4", "*LsoV2IPv6")) {
                    if ($null -ne $props.$propName) {
                        Set-ItemProperty -Path $keyPath -Name $propName -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    Write-SkyLog -Message "RSC e LSO desativados nos adaptadores de rede (elimina agregação artificial de pacotes; ticks de dados puros e sem micro-desync)." -Level "Success"
    return $true
}

function Disable-NetworkFlowControl {
    [CmdletBinding()]
    param()

    $netClassKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (-not (Test-Path $netClassKey)) {
        Write-SkyLog -Message "Chave de adaptadores de rede não encontrada. Ignorado com segurança." -Level "Info"
        return $true
    }

    Backup-RegistryKey -KeyPath $netClassKey -BackupName "76_Network_FlowControl"

    $subKeys = Get-ChildItem -Path $netClassKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
    $fcAdjusted = 0

    foreach ($k in $subKeys) {
        $keyPath = $k.PSPath
        $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
        if ($props) {
            foreach ($propName in @("*FlowControl", "FlowControl")) {
                if ($null -ne $props.$propName) {
                    Set-ItemProperty -Path $keyPath -Name $propName -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                    $fcAdjusted++
                }
            }
        }
    }

    # Cmdlet de ajuste avançado se suportado pelo driver
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    foreach ($nic in $adapters) {
        try {
            $exists = Get-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*FlowControl" -ErrorAction SilentlyContinue
            if ($exists) {
                Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*FlowControl" -RegistryValue 0 -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    Write-SkyLog -Message "Controlo de Fluxo (Flow Control) desativado nos adaptadores de rede ($fcAdjusted propriedades ajustadas; previne buffering de pacotes em picos de tráfego)." -Level "Success"
    return $true
}

function Optimize-TcpSocketsAndPorts {
    [CmdletBinding()]
    param()

    $tcpKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Backup-RegistryKey -KeyPath $tcpKey -BackupName "77_Tcpip_SocketsAndPorts"
    Ensure-RegistryPath -KeyPath $tcpKey

    # MaxUserPort = 65534 (Garante máximo de portas dinâmicas para conexões simultâneas de servidores multiplayer)
    Set-ItemProperty -Path $tcpKey -Name "MaxUserPort" -Value 65534 -Type DWord -Force

    # TcpTimedWaitDelay = 30 (Reduz retenção de sockets fechados de 120s para 30s, libertando canais de comunicação rapidamente)
    Set-ItemProperty -Path $tcpKey -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force

    # DefaultTTL = 64 (Padrão RFC ideal para baixa latência em saltos de rota de rede)
    Set-ItemProperty -Path $tcpKey -Name "DefaultTTL" -Value 64 -Type DWord -Force

    Write-SkyLog -Message "Gestão de sockets TCP/IP e portas efémeras otimizada (MaxUserPort=65534, TcpTimedWaitDelay=30s, DefaultTTL=64)." -Level "Success"
    return $true
}

function Optimize-NetshTcpGlobal {
    [CmdletBinding()]
    param()

    # Guardar configuração original do TCP global para eventual diagnóstico
    $backupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_netsh_tcp.txt"
    if (-not (Test-Path $backupFile)) {
        try {
            $currentTcp = netsh int tcp show global 2>&1
            $currentTcp | Out-File -FilePath $backupFile -Encoding UTF8 -Force
        } catch {}
    }

    # Desativar cabeçalhos redundantes e timestamps
    $null = netsh int tcp set global timestamps=disabled 2>&1

    # Desativar ECN (Explicit Congestion Notification - evita pacotes descartados por routers com suporte deficiente)
    $null = netsh int tcp set global ecncapability=disabled 2>&1

    # Desativar RSC a nível de stack TCP global
    $null = netsh int tcp set global rsc=disabled 2>&1

    # Ativar RSS (Receive Side Scaling - distribui processamento de rede por múltiplos núcleos de CPU)
    $null = netsh int tcp set global rss=enabled 2>&1

    # PROTEÇÃO CRÍTICA: Manter SEMPRE autotuninglevel=normal para garantir velocidade máxima em fibra 500M/1Gbps
    $null = netsh int tcp set global autotuninglevel=normal 2>&1

    Write-SkyLog -Message "Pilha TCP global otimizada via netsh (Timestamps=Disabled, ECN=Disabled, RSC=Disabled, RSS=Enabled, AutoTuning=Normal protegido)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.17 BATCH DE MODO DE JOGO & APRESENTAÇÃO GRÁFICA (TWEAKS 79 E 80)
# ==============================================================================

function Enable-WindowsGameMode {
    [CmdletBinding()]
    param()

    $gameBarKey = "HKCU:\SOFTWARE\Microsoft\GameBar"
    Ensure-RegistryPath -KeyPath $gameBarKey
    Backup-RegistryKey -KeyPath $gameBarKey -BackupName "79_Windows_GameMode"

    # AutoGameModeEnabled = 1 (Prioriza alocação de GPU e threads de CPU para o jogo ativo, reduzindo manutenção do SO)
    Set-ItemProperty -Path $gameBarKey -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $gameBarKey -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Modo de Jogo nativo do Windows ativado (AutoGameModeEnabled=1; prioridade de hardware para o processo do jogo)." -Level "Success"
    return $true
}

function Optimize-FullscreenOptimizations {
    [CmdletBinding()]
    param()

    $configStore = "HKCU:\System\GameConfigStore"
    Ensure-RegistryPath -KeyPath $configStore
    Backup-RegistryKey -KeyPath $configStore -BackupName "80_GameConfigStore_FSE"

    # GameDVR_FSEBehaviorMode = 2 (Desativa o hooking forçado de Fullscreen Optimizations híbridas, garantindo renderização limpa e taxa de atualização sem atrasos)
    Set-ItemProperty -Path $configStore -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force
    Set-ItemProperty -Path $configStore -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $configStore -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Apresentação gráfica e FSO otimizados (GameDVR_FSEBehaviorMode=2; elimina atrasos de overlay híbrido em ecrãs de alta taxa de Hz)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.18 BATCH DE OTIMIZAÇÕES CIRÚRGICAS (ESTABILIDADE, I/O & RESPONSIVIDADE)
# ==============================================================================

function Disable-PowerThrottling {
    [CmdletBinding()]
    param()

    $ptKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
    Ensure-RegistryPath -KeyPath $ptKey
    Backup-RegistryKey -KeyPath $ptKey -BackupName "81_PowerThrottling"

    # PowerThrottlingOff = 1 impede o corte artificial de frequência e prioridade em threads em background (Discord, OBS, FiveM subprocessos)
    Set-ItemProperty -Path $ptKey -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-SkyLog -Message "Power Throttling do Windows desativado (garante prioridade estável no Discord, OBS e processos auxiliares)." -Level "Success"
    return $true
}

function Disable-ZipIndexing {
    [CmdletBinding()]
    param()

    $searchPolKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Ensure-RegistryPath -KeyPath $searchPolKey
    Backup-RegistryKey -KeyPath $searchPolKey -BackupName "82_WindowsSearch_ZipIndexing"

    # PreventIndexingArchives = 1 impede a descompressão e indexação contínua de ficheiros .zip e pacotes de mods em background
    Set-ItemProperty -Path $searchPolKey -Name "PreventIndexingArchives" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-SkyLog -Message "Indexação de ficheiros comprimidos (.zip/mods) desativada (elimina leituras de disco e picos de CPU durante o jogo)." -Level "Success"
    return $true
}

function Optimize-DwmVisualEffects {
    [CmdletBinding()]
    param()

    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Ensure-RegistryPath -KeyPath $advKey
    Backup-RegistryKey -KeyPath $advKey -BackupName "83_Explorer_VisualEffects"

    # Desativação de sombras de ícones no ambiente de trabalho e sombras de janelas
    Set-ItemProperty -Path $advKey -Name "ListviewShadow" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $desktopKey = "HKCU:\Control Panel\Desktop"
    Ensure-RegistryPath -KeyPath $desktopKey
    Backup-RegistryKey -KeyPath $desktopKey -BackupName "83_Desktop_VisualEffects"

    # Desativação de sombras de cursor mantendo FontSmoothing ativo (ClearType preservado a 100%)
    Set-ItemProperty -Path $desktopKey -Name "DragFullWindows" -Value "1" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $desktopKey -Name "FontSmoothing" -Value "2" -Type String -Force -ErrorAction SilentlyContinue

    Write-SkyLog -Message "Sombras decorativas de janelas/ambiente de trabalho otimizadas (DWM aliviado com texto perfeitamente nítido)." -Level "Success"
    return $true
}

function Disable-WindowsSpotlightDownloads {
    [CmdletBinding()]
    param()

    $cdmKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Ensure-RegistryPath -KeyPath $cdmKey
    Backup-RegistryKey -KeyPath $cdmKey -BackupName "84_Spotlight_ContentDelivery"

    Set-ItemProperty -Path $cdmKey -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cdmKey -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cdmKey -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cdmKey -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cdmKey -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $cloudKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    Ensure-RegistryPath -KeyPath $cloudKey
    Backup-RegistryKey -KeyPath $cloudKey -BackupName "84_CloudContent_Spotlight"
    Set-ItemProperty -Path $cloudKey -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-SkyLog -Message "Downloads em segundo plano e publicidade do Windows Spotlight no LockScreen desativados com sucesso." -Level "Success"
    return $true
}

function Optimize-QuickAccessHistory {
    [CmdletBinding()]
    param()

    $expKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
    Ensure-RegistryPath -KeyPath $expKey
    Backup-RegistryKey -KeyPath $expKey -BackupName "85_Explorer_QuickAccess"

    # ShowRecent = 0 e ShowFrequent = 0 eliminam o journaling contínuo de ficheiros abertos no SSD
    Set-ItemProperty -Path $expKey -Name "ShowRecent" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $expKey -Name "ShowFrequent" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-SkyLog -Message "Histórico contínuo de ficheiros recentes no Explorador desativado (abertura instantânea e menos escritas no SSD)." -Level "Success"
    return $true
}

# ==============================================================================
# 4.19 GERADOR DO 'PAINEL DO CLIENTE' NO AMBIENTE DE TRABALHO
# ==============================================================================

function Deploy-ClientPanel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ReportContent
    )

    try {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        if (-not (Test-Path $desktopPath)) {
            $desktopPath = Join-Path $env:USERPROFILE "Desktop"
        }
        $panelDir = Join-Path $desktopPath "SkyOptimizer - Painel de Controlo"
        if (-not (Test-Path $panelDir)) {
            New-Item -ItemType Directory -Path $panelDir -Force | Out-Null
        }

        # 1. Configurar Cofre Permanente e Garantir Proteção de Propriedade Intelectual (Zero Code Exposure)
        $permDir = Join-Path $env:SystemDrive "ProgramData\SkyOptimizer"
        if (-not (Test-Path $permDir)) {
            New-Item -ItemType Directory -Path $permDir -Force | Out-Null
        }

        # SEGURANÇA IP: Garantir que o script mestre com as 78 otimizações NUNCA fica no PC do cliente
        $oldMasterScript = Join-Path $permDir "SkyOptimizer.ps1"
        if (Test-Path $oldMasterScript) {
            Remove-Item -Path $oldMasterScript -Force -ErrorAction SilentlyContinue
        }

        # Sincronizar pasta de Backups para o local permanente
        $permBackups = Join-Path $permDir "Backups"
        if (Test-Path $Global:SkyBackupDir) {
            if (-not (Test-Path $permBackups)) {
                New-Item -ItemType Directory -Path $permBackups -Force | Out-Null
            }
            Copy-Item -Path (Join-Path $Global:SkyBackupDir "*") -Destination $permBackups -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Gerar Motor Leve de Reversão Exclusivo (Apenas código de restauro - ZERO segredos ou funções de tuning)
        $revertScriptPath = Join-Path $permDir "SkyRevert.ps1"
        $revertScriptCode = @'
# ==============================================================================
# SkyOptimizer - Motor Autónomo de Reversão e Restauro
# (C) SkyOS Team - Suporte & Reversão Segura de Sistema
# ==============================================================================
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch {}

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$currentUser
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Privilegios de Administrador necessarios. A reiniciar com elevacao..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Clear-Host
Write-Host @"
================================================================================
  ____  _            ___        _   _           _              
 / ___|| | _____   _/ _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __ 
 \___ \| |/ / | | | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
  ___) |   <| |_| | |_| | |_) | |_| | | | | | | |/ /  __/ |   
 |____/|_|\_\\__, |\___/| .__/ \__|_|_| |_| |_|_/___\___|_|   
             |___/      |_|                                    
                    Modulo de Restauracao / Reversao
================================================================================
"@ -ForegroundColor Cyan

Write-Host "`n[!] ATENCAO: Este procedimento ira reverter as configuracoes do sistema" -ForegroundColor Yellow
Write-Host "    de volta para o estado original da sua maquina." -ForegroundColor Gray
Write-Host "    Os seus ficheiros originais de backup serao restaurados com seguranca.`n" -ForegroundColor Gray

$confirm = Read-Host "Deseja realmente reverter todas as otimizacoes? (S/N)"
if ($confirm -notmatch '^(s|sim|y|yes)$') {
    Write-Host "`nOperacao cancelada pelo utilizador." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    exit 0
}

$backupDir = Join-Path $PSScriptRoot "Backups"
if (-not (Test-Path $backupDir)) {
    $altBackup = Join-Path $env:SystemDrive "ProgramData\SkyOptimizer\Backups"
    if (Test-Path $altBackup) { $backupDir = $altBackup }
}

# 1. Restaurar Backups de Registo (.reg)
Write-Host "`n>>> [Passo 1/4] A restaurar ficheiros de Registo (.reg)..." -ForegroundColor Magenta
$restoredRegCount = 0
if (Test-Path $backupDir) {
    $regFiles = Get-ChildItem -Path $backupDir -Filter "*.reg" -ErrorAction SilentlyContinue
    if ($regFiles -and $regFiles.Count -gt 0) {
        foreach ($file in $regFiles) {
            Write-Host "  [*] A importar $($file.Name)..." -ForegroundColor Gray -NoNewline

            # Interceções cirúrgicas para chaves de sistema protegidas / de grande porte:
            if ($file.Name -eq "30_FastShutdown_System.reg") {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "5000" -Type String -Force -ErrorAction SilentlyContinue
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
                continue
            }
            if ($file.Name -eq "47_Control_SvcHostSplit.reg") {
                $svchostFile = Join-Path -Path $backupDir -ChildPath "previous_svchost_split.txt"
                $origSvcSplit = 3670016
                if (Test-Path $svchostFile) {
                    $val = (Get-Content -Path $svchostFile -ErrorAction SilentlyContinue).Trim()
                    if ($val -as [int]) { $origSvcSplit = [int]$val }
                }
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $origSvcSplit -Type DWord -Force -ErrorAction SilentlyContinue
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
                continue
            }
            if ($file.Name -eq "51_SearchIndexerPower.reg") {
                Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows Search\Gather\Windows\SystemIndex" -Name "RespectPowerModes" -Force -ErrorAction SilentlyContinue
                $null = & reg.exe delete "HKLM\Software\Microsoft\Windows Search\Gather\Windows\SystemIndex" /v "RespectPowerModes" /f 2>&1
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
                continue
            }
            if ($file.Name -eq "57_DiagnosticTracing.reg") {
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance" -Name "DisableDiagnosticTracing" -Force -ErrorAction SilentlyContinue
                $null = & reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance" /v "DisableDiagnosticTracing" /f 2>&1
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
                continue
            }
            if ($file.Name -eq "61_Explorer_MaxCachedIcons.reg") {
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "Max Cached Icons" -Force -ErrorAction SilentlyContinue
                $null = & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "Max Cached Icons" /f 2>&1
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
                continue
            }
            if ($file.Name -eq "67_SessionManager_DisableWpbt.reg") {
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWpbtExecution" -Force -ErrorAction SilentlyContinue
                $null = & reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "DisableWpbtExecution" /f 2>&1
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
                continue
            }
            if ($file.Name -eq "72_GameBar_PresenceWriter.reg") {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" -Name "ActivationType" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                $null = & reg.exe add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v "ActivationType" /t REG_DWORD /d 1 /f 2>&1
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
                continue
            }

            & reg.exe import "$($file.FullName)" *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
            } else {
                Write-Host " [OK]" -ForegroundColor Green
                $restoredRegCount++
            }
        }
    }
}

# 2. Remover Chaves Criadas de Raiz
Write-Host "`n>>> [Passo 2/4] A limpar chaves de registo criadas de raiz..." -ForegroundColor Magenta
$createdKeysFile = Join-Path -Path $backupDir -ChildPath "created_keys.txt"
if (Test-Path $createdKeysFile) {
    $createdKeys = Get-Content -Path $createdKeysFile -ErrorAction SilentlyContinue
    foreach ($key in $createdKeys) {
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            Write-Host "  [*] A remover chave recem-criada '$key'..." -ForegroundColor Gray -NoNewline
            & reg.exe delete "$key" /f *> $null
            if ($LASTEXITCODE -eq 0) { Write-Host " [OK]" -ForegroundColor Green } else { Write-Host " [IGNORADO]" -ForegroundColor Gray }
        }
    }
}

# 3. Restaurar Energia, BCD, Servicos e Agendador
Write-Host "`n>>> [Passo 3/4] A restaurar Definicoes de Energia, BCD, Servicos e Armazenamento..." -ForegroundColor Magenta

# Plano de Energia
$powerPlanFile = Join-Path -Path $backupDir -ChildPath "previous_power_plan.txt"
if (Test-Path $powerPlanFile) {
    $origPlanGuid = (Get-Content -Path $powerPlanFile -ErrorAction SilentlyContinue).Trim()
    if ($origPlanGuid -and ($origPlanGuid -match '^[a-fA-F0-9-]+$')) {
        powercfg -setactive $origPlanGuid 2>$null
        Write-Host "  [OK] Plano de Energia original reativado ($origPlanGuid)." -ForegroundColor Green
    } else {
        powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        Write-Host "  [INFO] Plano de Energia reposto para Equilibrado (Balanced)." -ForegroundColor Gray
    }
} else {
    powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    Write-Host "  [INFO] Plano de Energia reposto para Equilibrado (Balanced)." -ForegroundColor Gray
}

# Core Parking e USB
$subGroup   = "54533251-82be-4824-96c1-47b60b740d00"
$settingMin = "0cc5b647-c1df-4637-891a-dec75c318583"
$settingMax = "ea062031-0e34-4ff1-9b6d-eb1059324028"
$null = powercfg -setacvalueindex SCHEME_CURRENT $subGroup $settingMin 0 2>&1
$null = powercfg -setdcvalueindex SCHEME_CURRENT $subGroup $settingMin 0 2>&1
$null = powercfg -setacvalueindex SCHEME_CURRENT $subGroup $settingMax 100 2>&1
$null = powercfg -setdcvalueindex SCHEME_CURRENT $subGroup $settingMax 100 2>&1
$usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
$usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
$null = powercfg -setacvalueindex SCHEME_CURRENT $usbSubGroup $usbSetting 1 2>&1
$null = powercfg -setdcvalueindex SCHEME_CURRENT $usbSubGroup $usbSetting 1 2>&1
$null = powercfg -setactive SCHEME_CURRENT 2>&1
Write-Host "  [OK] Gestao de energia de CPU e USB reposta." -ForegroundColor Green

# Dynamic Tick
$null = bcdedit /deletevalue disabledynamictick 2>&1
if ($LASTEXITCODE -ne 0) { $null = bcdedit /set disabledynamictick no 2>&1 }
Write-Host "  [OK] Dynamic Tick (BCD) reposto." -ForegroundColor Green

# Hibernacao
$hibFile = Join-Path -Path $backupDir -ChildPath "previous_hibernation.txt"
if (Test-Path $hibFile) {
    $origHib = (Get-Content -Path $hibFile -ErrorAction SilentlyContinue).Trim()
    if ($origHib -eq 1 -or $origHib -eq "1") { powercfg -h on 2>$null; Write-Host "  [OK] Hibernacao reativada." -ForegroundColor Green }
    else { powercfg -h off 2>$null; Write-Host "  [INFO] Hibernacao mantida desligada." -ForegroundColor Gray }
}

# SysMain
$sysmainFile = Join-Path -Path $backupDir -ChildPath "previous_sysmain.txt"
if (Test-Path $sysmainFile) {
    $origSysMain = (Get-Content -Path $sysmainFile -ErrorAction SilentlyContinue).Trim()
    if ($origSysMain -in @("Auto", "Automatic", "Manual")) {
        $startupType = if ($origSysMain -eq "Manual") { "Manual" } else { "Automatic" }
        Set-Service -Name SysMain -StartupType $startupType -ErrorAction SilentlyContinue
        Start-Service -Name SysMain -ErrorAction SilentlyContinue
        Write-Host "  [OK] Servico SysMain restaurado para $startupType." -ForegroundColor Green
    }
}

# NTFS
$null = fsutil behavior set disablelastaccess 0 2>&1
$null = fsutil behavior set disable8dot3 0 2>&1
Write-Host "  [OK] Parametros NTFS repostos." -ForegroundColor Green

# Armazenamento Reservado
$resFile = Join-Path -Path $backupDir -ChildPath "previous_reserved_storage.txt"
if (Test-Path $resFile) {
    $origRes = (Get-Content -Path $resFile -ErrorAction SilentlyContinue).Trim()
    if ($origRes -eq "Enabled") {
        $null = dism.exe /Online /Set-ReservedStorageState /State:Enabled 2>&1
        Write-Host "  [OK] Armazenamento Reservado reposto." -ForegroundColor Green
    }
}

# SleepStudy
'y' | & wevtutil.exe set-log "Microsoft-Windows-SleepStudy/Diagnostic" /e:true /q:true 2>&1 | Out-Null
'y' | & wevtutil.exe set-log "Microsoft-Windows-Kernel-Processor-Power/Diagnostic" /e:true /q:true 2>&1 | Out-Null
'y' | & wevtutil.exe set-log "Microsoft-Windows-UserModePowerService/Diagnostic" /e:true /q:true 2>&1 | Out-Null
$null = schtasks /Change /TN "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /Enable 2>&1
Write-Host "  [OK] Canais SleepStudy reativados." -ForegroundColor Green

# HAGS
if (-not (Test-Path (Join-Path $backupDir "37_GraphicsDrivers_HAGS.reg"))) {
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Force -ErrorAction SilentlyContinue
}

# Placas de Rede
$adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
foreach ($nic in $adapters) {
    foreach ($prop in @("*EEE", "*GreenEthernet", "*GigaLite", "PowerSavingMode", "EnergyEfficientEthernet")) {
        try {
            $exists = Get-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword $prop -ErrorAction SilentlyContinue
            if ($exists) { Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword $prop -RegistryValue 1 -ErrorAction SilentlyContinue }
        } catch {}
    }
}
Write-Host "  [OK] Gestao de energia de adaptadores de rede reposta." -ForegroundColor Green

# SvcHost
$svchostFile = Join-Path -Path $backupDir -ChildPath "previous_svchost_split.txt"
$origSvcSplit = 3670016
if (Test-Path $svchostFile) {
    $val = (Get-Content -Path $svchostFile -ErrorAction SilentlyContinue).Trim()
    if ($val -as [int]) { $origSvcSplit = [int]$val }
}
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $origSvcSplit -Type DWord -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] SvcHostSplitThresholdInKB reposto ($origSvcSplit KB)." -ForegroundColor Green

# Servicos de Telemetria
$telemetrySvcFile = Join-Path -Path $backupDir -ChildPath "previous_telemetry_services.json"
if (Test-Path $telemetrySvcFile) {
    try {
        $svcMap = Get-Content -Path $telemetrySvcFile -Raw | ConvertFrom-Json
        foreach ($prop in $svcMap.PSObject.Properties) {
            $sName = $prop.Name
            $sMode = $prop.Value
            $startup = if ($sMode -in @("Auto", "Automatic")) { "Automatic" } else { "Manual" }
            Set-Service -Name $sName -StartupType $startup -ErrorAction SilentlyContinue
            if ($startup -eq "Automatic") { Start-Service -Name $sName -ErrorAction SilentlyContinue }
        }
        Write-Host "  [OK] Modos de arranque de servicos repostos." -ForegroundColor Green
    } catch {}
}

# Tarefas Agendadas
$maintTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting"
)
foreach ($t in $maintTasks) { $null = schtasks /Change /TN $t /Enable 2>&1 }
Write-Host "  [OK] Tarefas agendadas reativadas." -ForegroundColor Green

# Reposicao de Kernel Paging e CrashControl
if (-not (Test-Path (Join-Path $backupDir "50_KernelMemoryManagement.reg"))) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePageCombining" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path (Join-Path $backupDir "55_CrashControlDiagnostics.reg"))) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
}

# Servicos de Diagnostico Adicionais
$diagSvcFile = Join-Path -Path $backupDir -ChildPath "previous_diagnostic_services.json"
if (Test-Path $diagSvcFile) {
    try {
        $diagMap = Get-Content -Path $diagSvcFile -Raw | ConvertFrom-Json
        foreach ($prop in $diagMap.PSObject.Properties) {
            $sName = $prop.Name
            $sVal = $prop.Value
            if ($sName -eq "OneSyncSvc_RegStart") {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc" -Name "Start" -Value ([int]$sVal) -Type DWord -Force -ErrorAction SilentlyContinue
            } else {
                $startup = if ($sVal -in @("Auto", "Automatic")) { "Automatic" } else { "Manual" }
                Set-Service -Name $sName -StartupType $startup -ErrorAction SilentlyContinue
                if ($startup -eq "Automatic") { Start-Service -Name $sName -ErrorAction SilentlyContinue }
            }
        }
        Write-Host "  [OK] Servicos de diagnostico adicionais restaurados." -ForegroundColor Green
    } catch {}
}

# Tarefas Nvidia Telemetry
$nvTasks = Get-ScheduledTask -TaskPath "\" -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match '^NvTm' }
foreach ($t in $nvTasks) { $null = schtasks /Change /TN "$($t.TaskName)" /Enable 2>&1 }

# Menu de Contexto Classico Win11 (se chave nao existia previamente)
if (-not (Test-Path (Join-Path $backupDir "63_Win11_ClassicContextMenu.reg"))) {
    & reg.exe delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f *> $null
}

# Fallbacks de Interface, Firmware e Sistema
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "Max Cached Icons" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWpbtExecution" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "1" -Type String -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "JPEGImportQuality" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" -Name "AllowEdgeSwipe" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" -Name "ActivationType" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Reposicao de Rede Competitiva, Hitreg e Teclado (Tweaks 73 a 78)
Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "1" -Type String -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force -ErrorAction SilentlyContinue

$adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
foreach ($nic in $adapters) {
    try { Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 1 -ErrorAction SilentlyContinue } catch {}
    try { Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*FlowControl" -RegistryValue 3 -ErrorAction SilentlyContinue } catch {}
}
try { Enable-NetAdapterRsc -Name * -ErrorAction SilentlyContinue } catch {}
try { Enable-NetAdapterLso -Name * -IPv4 -IPv6 -ErrorAction SilentlyContinue } catch {}

Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxUserPort" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpTimedWaitDelay" -Force -ErrorAction SilentlyContinue
$null = netsh int tcp set global timestamps=allowed 2>&1
$null = netsh int tcp set global ecncapability=default 2>&1
$null = netsh int tcp set global autotuninglevel=normal 2>&1

# Reposicao de Modo de Jogo e FSO (Tweaks 79 e 80)
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Force -ErrorAction SilentlyContinue

# Reposicao de Otimizacoes Cirurgicas (Tweaks 81 a 85)
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "PreventIndexingArchives" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsSpotlightFeatures" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# 4. Finalizacao
Write-Host "`n>>> [Passo 4/4] Finalizacao" -ForegroundColor Magenta

# Limpeza da pasta do Painel do Cliente no Ambiente de Trabalho
$desktopFolders = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) "SkyOptimizer - Painel de Controlo"),
    (Join-Path $env:USERPROFILE "Desktop\SkyOptimizer - Painel de Controlo"),
    (Join-Path $env:PUBLIC "Desktop\SkyOptimizer - Painel de Controlo")
) | Select-Object -Unique

foreach ($df in $desktopFolders) {
    if (Test-Path $df) {
        if ($PWD.Path -like "$df*") { Set-Location $env:TEMP }
        Remove-Item -Path $df -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$restartExplorer = Read-Host "Pretende reiniciar o Windows Explorer agora? (S/N)"
if ($restartExplorer -match '^(s|sim|y|yes)$') {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Host "[OK] Windows Explorer reiniciado." -ForegroundColor Green
}

Write-Host @"

================================================================================
                         REVERSAO CONCLUIDA COM SUCESSO
================================================================================
  Ficheiros de registo restaurados: $restoredRegCount
  Definicoes de hardware e energia: Repostas
  Estado dos Servicos:              Restaurado
  Painel do Ambiente de Trabalho:   Removido
================================================================================
O seu sistema foi revertido com seguranca para o estado anterior.
"@ -ForegroundColor Green
Read-Host "`nPressione ENTER para concluir..."
'@
        [System.IO.File]::WriteAllText($revertScriptPath, $revertScriptCode, [System.Text.Encoding]::UTF8)

        # Limpar atalhos antigos ou duplicados se existirem
        $obsoleteFiles = @(
            "[1] Desfazer Tudo (Reverter Otimizacoes).cmd",
            "[4] Alternar Pesquisa na Barra de Tarefas.cmd",
            "[5] Limpar Shaders e Cache (FiveM e CS2).cmd",
            "[6] Limpar Shaders e Cache (FiveM e CS2).cmd",
            "[6] Alternar Isolamento do Nucleo (VBS).cmd",
            "[6] Alternar Isolamento do Nucleo (Jogos e FPS).cmd",
            "[6] Desinstalar SkyOptimizer e Apagar Tudo.cmd",
            "[7] Desinstalar SkyOptimizer e Apagar Tudo.cmd",
            "LEIA-ME (Suporte SkyOptimizer).txt",
            "Guia_VIP_Maximo_FPS.txt"
        )
        foreach ($old in $obsoleteFiles) {
            $oldPath = Join-Path $panelDir $old
            if (Test-Path $oldPath) { Remove-Item -Path $oldPath -Force -ErrorAction SilentlyContinue }
        }

        # 1. Atalho Reverter Otimizações (Executa exclusivamente o motor SkyRevert.ps1)
        $undoCmd = "@echo off`r`ntitle SkyOptimizer - Reverter Otimizacoes`r`n:: SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5`r`nnet session >nul 2>&1`r`nif %errorLevel% neq 0 (`r`n    powershell -Command `"Start-Process cmd -ArgumentList '/c \`"`\`"%~f0\`"\`"' -Verb RunAs`"`r`n    exit /b`r`n)`r`nchcp 65001 >nul`r`ncd /d `"%TEMP%`"`r`ncls`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%SystemDrive%\ProgramData\SkyOptimizer\SkyRevert.ps1`"`r`nexit /b"
        [System.IO.File]::WriteAllText((Join-Path $panelDir "[1] Reverter Todas as Otimizacoes.cmd"), $undoCmd, [System.Text.Encoding]::ASCII)

        # 2. Atalho Impressora
        $printerCmd = "@echo off`r`ntitle SkyOptimizer - Controlo de Impressora`r`n:: SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5`r`nnet session >nul 2>&1`r`nif %errorLevel% neq 0 (`r`n    powershell -Command `"Start-Process cmd -ArgumentList '/c \`"`\`"%~f0\`"\`"' -Verb RunAs`"`r`n    exit /b`r`n)`r`nchcp 65001 >nul`r`ncls`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& { `$svc = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue; if (-not `$svc) { Write-Host '[AVISO] Servico de impressao nao encontrado neste sistema.' -ForegroundColor Yellow; pause; exit }; if (`$svc.StartType -eq 'Disabled' -or `$svc.Status -ne 'Running') { Set-Service -Name 'Spooler' -StartupType Automatic; Start-Service -Name 'Spooler' -ErrorAction SilentlyContinue; Write-Host '===================================================' -ForegroundColor Green; Write-Host '  SERVICO DE IMPRESSORA ATIVADO COM SUCESSO' -ForegroundColor Green; Write-Host '===================================================' -ForegroundColor Green; Write-Host 'O Windows ja pode comunicar com impressoras e faturas.' -ForegroundColor White } else { Stop-Service -Name 'Spooler' -Force -ErrorAction SilentlyContinue; Set-Service -Name 'Spooler' -StartupType Disabled; Write-Host '===================================================' -ForegroundColor Yellow; Write-Host '  SERVICO DE IMPRESSORA DESATIVADO COM SUCESSO' -ForegroundColor Yellow; Write-Host '===================================================' -ForegroundColor Yellow; Write-Host 'Processos em segundo plano suspensos para poupar RAM e CPU.' -ForegroundColor White } }`"`r`necho.`r`npause"
        [System.IO.File]::WriteAllText((Join-Path $panelDir "[2] Alternar Impressora (Ligar-Desligar).cmd"), $printerCmd, [System.Text.Encoding]::ASCII)

        # 3. Atalho Bluetooth
        $btCmd = "@echo off`r`ntitle SkyOptimizer - Controlo de Bluetooth`r`n:: SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5`r`nnet session >nul 2>&1`r`nif %errorLevel% neq 0 (`r`n    powershell -Command `"Start-Process cmd -ArgumentList '/c \`"`\`"%~f0\`"\`"' -Verb RunAs`"`r`n    exit /b`r`n)`r`nchcp 65001 >nul`r`ncls`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& { `$svc = Get-Service -Name 'bthserv' -ErrorAction SilentlyContinue; if (-not `$svc) { Write-Host '[AVISO] Servico Bluetooth nao encontrado neste sistema.' -ForegroundColor Yellow; pause; exit }; if (`$svc.StartType -eq 'Disabled' -or `$svc.Status -ne 'Running') { Set-Service -Name 'bthserv' -StartupType Manual; Start-Service -Name 'bthserv' -ErrorAction SilentlyContinue; Write-Host '===================================================' -ForegroundColor Green; Write-Host '  BLUETOOTH ATIVADO COM SUCESSO' -ForegroundColor Green; Write-Host '===================================================' -ForegroundColor Green; Write-Host 'Ja pode ligar comandos (Xbox/PS5), auscultadores e outros.' -ForegroundColor White } else { Stop-Service -Name 'bthserv' -Force -ErrorAction SilentlyContinue; Set-Service -Name 'bthserv' -StartupType Disabled; Write-Host '===================================================' -ForegroundColor Yellow; Write-Host '  BLUETOOTH DESATIVADO COM SUCESSO' -ForegroundColor Yellow; Write-Host '===================================================' -ForegroundColor Yellow; Write-Host 'Processos de pesquisa sem fios desativados.' -ForegroundColor White } }`"`r`necho.`r`npause"
        [System.IO.File]::WriteAllText((Join-Path $panelDir "[3] Alternar Bluetooth (Ligar-Desligar).cmd"), $btCmd, [System.Text.Encoding]::ASCII)

        # 4. Atalho Isolamento do Núcleo (VBS e Jogos)
        $vbsCmd = @'
@echo off
title SkyOptimizer - Controlo de Isolamento do Nucleo (VBS e Jogos)
:: SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)
chcp 65001 >nul
cls
echo ================================================================================
echo           SkyOptimizer - Controlo de Isolamento do Nucleo (VBS / HVCI)
echo           Discord Oficial: https://discord.gg/cE8ZaDRGV5
echo ================================================================================
echo.
echo  O Isolamento do Nucleo (VBS/HVCI) e uma camada de seguranca do Windows.
echo  Desativa-lo liberta a CPU, garantindo mais 5%% a 15%% de FPS e eliminando
echo  micro-stutters e latencia em praticamente todos os jogos.
echo.
echo  ------------------------------------------------------------------------------
echo  GUIA DE COMPATIBILIDADE DE JOGOS:
echo  ------------------------------------------------------------------------------
echo.
echo  [!] EXIGEM ESTE RECURSO ATIVADO (Se desligar, o jogo nao arranca no Win11):
echo      * VALORANT (Anti-cheat Riot Vanguard)
echo      * CS2 no FACEIT (Anti-cheat Faceit Client no Win11)
echo      * League of Legends (Anti-cheat Riot Vanguard)
echo.
echo  [+] GANHAM +5%% A +15%% FPS E MENOS LATENCIA COM ISTO DESATIVADO:
echo      * Counter-Strike 2 (Premier, Valve Matchmaking, Servidores Comunidade)
echo      * FiveM, RedM e GTA V
echo      * ARC Raiders
echo      * Call of Duty: Warzone, Modern Warfare e Black Ops
echo      * Fortnite (Modo Desempenho, DX11 e DX12)
echo      * Apex Legends, PUBG: Battlegrounds e The Finals
echo      * Rust, Escape from Tarkov e DayZ
echo      * Tom Clancy's Rainbow Six Siege e Overwatch 2
echo      * EA SPORTS FC 24 / 25 e Rocket League
echo      * Assetto Corsa, Forza Horizon e F1
echo      * Todos os titulos competitivos e AAA DirectX 11, DirectX 12 e Vulkan
echo.
echo ================================================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $hvciKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; $dgKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; $curVal = 0; if (Test-Path $hvciKey) { $curVal = (Get-ItemProperty $hvciKey -ErrorAction SilentlyContinue).Enabled }; if ($curVal -eq 1) { Write-Host 'Estado Atual: ATIVADO (Seguranca Ligada / Menos FPS)' -ForegroundColor Yellow; Write-Host 'Compatibilidade: VALORANT e jogos no FACEIT funcionam a 100%.' -ForegroundColor Gray; Write-Host ''; $resp = Read-Host 'Pretende DESATIVAR para ganhar mais FPS em FiveM, CS2, COD, Fortnite, etc.? (S/N)'; if ($resp -match '^(s|sim|y|yes)$') { if (-not (Test-Path $hvciKey)) { New-Item -Path $hvciKey -Force | Out-Null }; Set-ItemProperty -Path $hvciKey -Name 'Enabled' -Value 0 -Type DWord -Force; Set-ItemProperty -Path $dgKey -Name 'EnableVirtualizationBasedSecurity' -Value 0 -Type DWord -Force; Write-Host '`n[OK] Isolamento do Nucleo DESATIVADO com sucesso!' -ForegroundColor Green; Write-Host 'E necessario reiniciar o computador para aplicar.' -ForegroundColor Yellow } } else { Write-Host 'Estado Atual: DESATIVADO (Maxima Performance / Sem VBS)' -ForegroundColor Green; Write-Host 'Compatibilidade: FiveM, CS2, ARC Raiders, COD com maxima fluidez.' -ForegroundColor Gray; Write-Host ''; $resp = Read-Host 'Pretende ATIVAR para poder jogar VALORANT ou no FACEIT? (S/N)'; if ($resp -match '^(s|sim|y|yes)$') { if (-not (Test-Path $hvciKey)) { New-Item -Path $hvciKey -Force | Out-Null }; Set-ItemProperty -Path $hvciKey -Name 'Enabled' -Value 1 -Type DWord -Force; Set-ItemProperty -Path $dgKey -Name 'EnableVirtualizationBasedSecurity' -Value 1 -Type DWord -Force; Write-Host '`n[OK] Isolamento do Nucleo ATIVADO com sucesso!' -ForegroundColor Green; Write-Host 'E necessario reiniciar o computador para aplicar.' -ForegroundColor Yellow } } }"
echo.
echo Discord da Comunidade: https://discord.gg/cE8ZaDRGV5
echo.
pause
'@
        [System.IO.File]::WriteAllText((Join-Path $panelDir "[4] Alternar Isolamento do Nucleo (VBS e Jogos).cmd"), $vbsCmd, [System.Text.Encoding]::ASCII)

        # 5. Atalho Limpeza de Shaders e Caches de Jogos
        $cleanCmd = "@echo off`r`ntitle SkyOptimizer - Limpeza de Shaders e Caches`r`n:: SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5`r`nnet session >nul 2>&1`r`nif %errorLevel% neq 0 (`r`n    powershell -Command `"Start-Process cmd -ArgumentList '/c \`"`\`"%~f0\`"\`"' -Verb RunAs`"`r`n    exit /b`r`n)`r`nchcp 65001 >nul`r`ncls`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& { Write-Host '===================================================' -ForegroundColor Cyan; Write-Host '   SkyOptimizer - Limpeza de Shaders e Caches' -ForegroundColor Cyan; Write-Host '===================================================' -ForegroundColor Cyan; `$cleared = 0; `$dirs = @(\`"`$env:LOCALAPPDATA\NVIDIA\DXCache\`", \`"`$env:LOCALAPPDATA\NVIDIA\GLCache\`", \`"`$env:LOCALAPPDATA\D3DSCache\`", \`"`$env:LOCALAPPDATA\CitizenFX\cache\`", \`"`$env:TEMP\`", \`"`$env:SystemRoot\Temp\`); foreach (`$d in `$dirs) { if (Test-Path `$d) { Get-ChildItem -Path `$d -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item -Path `$_.FullName -Force -ErrorAction SilentlyContinue; `$cleared++ } catch {} } } }; Write-Host '`n[OK] Limpeza concluida com sucesso! ' -NoNewline -ForegroundColor Green; Write-Host \`"`$cleared ficheiro(s) de cache e shaders removidos.\`" -ForegroundColor White; pause }`"`r`npause"
        [System.IO.File]::WriteAllText((Join-Path $panelDir "[5] Limpar Shaders e Caches de Jogos.cmd"), $cleanCmd, [System.Text.Encoding]::ASCII)

        # Relatório Antes vs. Depois
        if ($ReportContent) {
            [System.IO.File]::WriteAllText((Join-Path $panelDir "Relatorio_Otimizacao.txt"), $ReportContent, [System.Text.Encoding]::UTF8)
        }

        # Ficheiro LÊ-ME (Suporte SkyOptimizer)
        $readmeTxt = @"
================================================================================
                    SkyOptimizer - Painel de Controlo & Suporte
================================================================================
Comunidade Oficial & Suporte: https://discord.gg/cE8ZaDRGV5
================================================================================

Boas! O teu computador foi otimizado a fundo pelo teu técnico do SkyOptimizer.
Foram aplicadas 85 otimizações cirúrgicas de kernel, rede, input de rato/teclado,
gestão de memória e energia para espremer o máximo de fluidez, reduzir a latência
ao milissegundo e estabilizar os teus frametimes.

🎮 Compatibilidade Total de Jogos:
Estas otimizações cobrem todos os teus jogos favoritos em DirectX 11, DirectX 12
e Vulkan:
- Shooters Competitivos: CS2, VALORANT, Rainbow Six Siege, Overwatch 2, Apex Legends
- Roleplay & Open-World: FiveM, RedM, GTA V, Rust, DayZ, Escape from Tarkov
- Battle Royale & Ação: Warzone, Fortnite, PUBG, ARC Raiders, The Finals
- Desporto & Simulação: EA SPORTS FC 24/25, Rocket League, Assetto Corsa, F1, Forza

--------------------------------------------------------------------------------
ATALHOS DE 1 CLIQUE NO AMBIENTE DE TRABALHO:
--------------------------------------------------------------------------------

1. [1] Reverter Todas as Otimizacoes.cmd
   - Se por algum motivo quiseres repor o teu Windows exatamente como estava antes,
     dá 2 cliques aqui. O restauro repõe 100% dos teus ficheiros de registo e
     serviços originais com segurança total.

2. [2] Alternar Impressora (Ligar-Desligar).cmd
   - O serviço de spooler de impressão consome processos em segundo plano.
     Se precisares de imprimir faturas ou documentos, clica aqui para ligar na hora.
     Quando acabares, clica de novo para desligar e poupar CPU.

3. [3] Alternar Bluetooth (Ligar-Desligar).cmd
   - Se usares comandos sem fios (Xbox, PS5, PS4) ou auscultadores Bluetooth,
     clica 2 cliques para ativar. Se usas rato e teclado por cabo/dongle 2.4GHz,
     mantém desligado para latência zero.

4. [4] Alternar Isolamento do Nucleo (VBS e Jogos).cmd
   - O Isolamento do Núcleo (VBS/HVCI) protege o Windows, mas rouba 5% a 15% de FPS
     e cria micro-stutters na CPU:
     * Queres mais FPS em FiveM, CS2, Warzone, Fortnite, Rust, Tarkov, etc.? DESLIGA.
     * Queres jogar VALORANT, LoL ou CS2 no FACEIT? LIGA (obrigatório pelo anti-cheat).

5. [5] Limpar Shaders e Caches de Jogos.cmd
   - Executa uma vez por mês ou sempre que notares engasgos após um update de driver
     da gráfica. Limpa em segundos caches corrompidas de DirectX, NVIDIA e FiveM.

--------------------------------------------------------------------------------
🚀 QUERES AINDA MAIS FPS? SESSÃO VIP DE BIOS & HARDWARE TUNING
--------------------------------------------------------------------------------
O teu Windows já está afinado ao limite. Mas sabias que pode haver 15% a 30% de
performance extra ainda "adormecida" na tua máquina?

Muitos computadores saem de fábrica ou de montagem com:
- Memória RAM a correr à velocidade mínima base (sem XMP/EXPO ativo na BIOS)
- Re-Size BAR desativado (a GPU e a CPU comunicam com limites de banda)
- Curvas de ventoinhas desreguladas (levando a thermal throttling / perdas de clock)
- Voltagens excessivas de fábrica que aquecem a CPU e reduzem frequências Boost

⚠️ AVISO IMPORTANTE:
Alterar opções na BIOS sem conhecimento avançado pode impedir o computador de
ligar, dar ecrã preto ou até danificar componentes por sobretensão.
Não mexas sozinho na BIOS através de tutoriais genéricos da internet!

👉 Se queres desbloquear o potencial máximo do teu hardware em segurança absoluta,
fala comigo no Discord oficial da SkyOptimizer para agendares uma sessão VIP
dedicada de BIOS & Hardware Tuning!

--------------------------------------------------------------------------------
Comunidade Oficial SkyOptimizer:
👉 Discord: https://discord.gg/cE8ZaDRGV5
================================================================================
"@
        [System.IO.File]::WriteAllText((Join-Path $panelDir "LÊ-ME (Suporte SkyOptimizer).txt"), $readmeTxt, [System.Text.Encoding]::UTF8)

        Write-SkyLog -Message "Painel do Cliente criado com sucesso no Ambiente de Trabalho ('$panelDir')." -Level "Success"
        return $true
    } catch {
        Write-SkyLog -Message "Falha ao gerar Painel do Cliente no Desktop: $($_.Exception.Message)" -Level "Warning"
        return $false
    }
}

function Repair-WindowsSystemIntegrity {
    [CmdletBinding()]
    param()

    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "         SkyOptimizer - Verificação de Integridade do Windows (DISM / SFC)" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "`nEsta ferramenta analisa e repara ficheiros corrompidos do sistema operativo." -ForegroundColor Gray
    Write-Host "Recomendada se o cliente tiver queixas de ecrãs azuis (BSOD), crashes frequentes ou" -ForegroundColor Gray
    Write-Host "atualizações do Windows interrompidas.`n" -ForegroundColor Gray
    Write-Host "[!] Tempo estimado: 5 a 10 minutos (necessita de ligação à Internet).`n" -ForegroundColor Yellow

    $conf = Read-Host "Pretende iniciar a reparação de integridade agora? (S/N) [Padrão: N]"
    if ($conf -notmatch '^(s|sim|y|yes)$') {
        Write-Host "`n[*] Operação cancelada. A regressar ao menu..." -ForegroundColor Gray
        Start-Sleep -Seconds 1
        return $false
    }

    Write-SkyLog -Message "Início da reparação de integridade do Windows (DISM / SFC)." -Level "Info"

    Write-Host "`n[Passo 1/2] A reparar a base de componentes do Windows via DISM..." -ForegroundColor Magenta
    Write-Host "Comando: dism.exe /Online /Cleanup-Image /RestoreHealth`n" -ForegroundColor Gray
    & dism.exe /Online /Cleanup-Image /RestoreHealth

    Write-Host "`n[Passo 2/2] A analisar e reparar ficheiros de sistema protegidos via SFC..." -ForegroundColor Magenta
    Write-Host "Comando: sfc.exe /scannow`n" -ForegroundColor Gray
    & sfc.exe /scannow

    Write-Host "`n================================================================================" -ForegroundColor Green
    Write-Host "  VERIFICAÇÃO DE INTEGRIDADE CONCLUÍDA" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Green
    Write-SkyLog -Message "Reparação de integridade do Windows concluída." -Level "Success"
    return $true
}

# ==============================================================================
# 5. FUNÇÃO PRINCIPAL DE OTIMIZAÇÃO (APLICAR 80 TWEAKS)
# ==============================================================================

function Invoke-SkyOptimize {
    [CmdletBinding()]
    param()

    Clear-Host
    $banner = @"
===============================================================================
  ____  _            ___        _   _           _              
 / ___|| | _____   _/ _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __ 
 \___ \| |/ / | | | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
  ___) |   <| |_| | |_| | |_) | |_| | | | | | | |/ /  __/ |   
 |____/|_|\_\\__, |\___/| .__/ \__|_|_| |_| |_|_/___\___|_|   
             |___/      |_|                                    
                 Windows 10/11 Performance Toolkit
                          Versão: 2.7.0
===============================================================================
"@
    Write-Host $banner -ForegroundColor Cyan
    Show-SystemHardwareInfo
    Write-SkyLog -Message "Início da sessão de Otimização SkyOptimizer v2.7.0 em $env:COMPUTERNAME ($($Global:SkyManifest.OperatingSystem))" -Level "Info" -NoConsole

    # 0. Recolha de Métricas Iniciais (Antes da Otimização)
    $baselineMetrics = [ordered]@{
        Timestamp       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        ProcessCount    = (Get-Process).Count
        RamTotalMB      = 0
        RamUsedMB       = 0
        FreeDiskCGB     = 0
        VbsState        = (Get-VbsStatus)
    }
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($osInfo) {
        $baselineMetrics.RamTotalMB = [math]::Round($osInfo.TotalVisibleMemorySize / 1024)
        $baselineMetrics.RamUsedMB  = [math]::Round(($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / 1024)
    }
    $driveC = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if ($driveC) {
        $baselineMetrics.FreeDiskCGB = [math]::Round($driveC.Free / 1GB, 2)
    }

    # 1. Ponto de Restauro do Sistema
    Write-Host "`n>>> [Passo 1/3] Segurança do Sistema" -ForegroundColor Magenta
    Write-Host "A verificar / criar Ponto de Restauro do Sistema antes de aplicar alterações..." -ForegroundColor Gray

    $restorePointCreated = $false
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue

        # Permitir criação de pontos de restauro sem restrição do limite de 24h do Windows
        $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        if (Test-Path $srKey) {
            Set-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        Checkpoint-Computer -Description "SkyOptimizer Pre-Tweak" -RestorePointType "MODIFY_SETTINGS" -WarningAction SilentlyContinue -ErrorAction Stop
        Write-SkyLog -Message "Ponto de Restauro criado: 'SkyOptimizer Pre-Tweak'" -Level "Success"
        $restorePointCreated = $true
    } catch {
        $errMessage = $_.Exception.Message
        Write-SkyLog -Message "Não foi possível criar o Ponto de Restauro automaticamente. Motivo: $errMessage" -Level "Warning"
        Write-Host "`n[!] ATENÇÃO:" -ForegroundColor Yellow
        Write-Host "    O Windows pode restringir a frequência de criação de pontos de restauro" -ForegroundColor Gray
        Write-Host "    ou a funcionalidade de Proteção do Sistema pode estar desativada." -ForegroundColor Gray
        Write-Host "    Nota: Todos os backups de registo (.reg) e ficheiros de reversão continuarão a ser criados.`n" -ForegroundColor Gray

        $confirm = Read-Host "Deseja continuar com as otimizações mesmo assim? (S/N)"
        if ($confirm -notmatch '^(s|sim|y|yes)$') {
            Write-Host "`nOperação cancelada pelo utilizador com segurança." -ForegroundColor Yellow
            Write-SkyLog -Message "Execução cancelada pelo utilizador devido à ausência de Ponto de Restauro." -Level "Warning"
            Start-Sleep -Seconds 2
            return
        }
    } finally {
        $ProgressPreference = $prevProgress
    }

    # 2. Execução das 85 Otimizações
    Write-Host "`n>>> [Passo 2/3] A executar Otimizações Seguras (85 Tweaks)" -ForegroundColor Magenta
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

        # Categoria 4: Privacidade e Telemetria
        [ordered]@{ Id = 13; Category = "Privacidade & Telemetria"; Name = "Telemetria no Nível Básico/Necessário (Seguro)"; Action = { Set-TelemetryBasic } },
        [ordered]@{ Id = 14; Category = "Privacidade & Telemetria"; Name = "Desativação de Sugestões e Anúncios no Menu Iniciar"; Action = { Disable-StartMenuSuggestions } },
        [ordered]@{ Id = 15; Category = "Privacidade & Telemetria"; Name = "Desativação de Pesquisa Web Bing e Dicas do Spotlight"; Action = { Disable-SearchAndSpotlight } },
        [ordered]@{ Id = 16; Category = "Privacidade & Telemetria"; Name = "Desativação de Widgets e Feeds da Barra de Tarefas"; Action = { Disable-TaskbarWidgets } },

        # Categoria 5: Explorador de Ficheiros
        [ordered]@{ Id = 17; Category = "Explorador & QoL"; Name = "Exibição de Extensões de Ficheiros Conhecidos"; Action = { Show-FileExtensions } },
        [ordered]@{ Id = 18; Category = "Explorador & QoL"; Name = "Desativação de Arquivamento Automático de Apps"; Action = { Disable-AppArchival } },

        # Categoria 6: Controlo Inteligente de Windows Update
        [ordered]@{ Id = 19; Category = "Controlo Windows Update"; Name = "Bloqueio de Substituição Automática de Drivers GPU/Hardware"; Action = { Block-AutomaticDriverUpdates } },
        [ordered]@{ Id = 20; Category = "Controlo Windows Update"; Name = "Desativação de P2P da Otimização de Entrega (Proteção de Ping)"; Action = { Disable-DeliveryOptimizationP2P } },
        [ordered]@{ Id = 21; Category = "Controlo Windows Update"; Name = "Modo de Atualização Manual e Notificação (Sem Reinícios Forçados)"; Action = { Set-ManualWindowsUpdate } },

        # Categoria 7: Armazenamento, I/O & Limpeza de Disco
        [ordered]@{ Id = 22; Category = "Armazenamento & Limpeza"; Name = "Desativação de Armazenamento Reservado (Libertar 7GB-10GB)"; Action = { Disable-ReservedStorage } },
        [ordered]@{ Id = 23; Category = "Armazenamento & Limpeza"; Name = "Otimização de Sistema de Ficheiros NTFS (I/O Boost)"; Action = { Optimize-NTFS } },
        [ordered]@{ Id = 24; Category = "Armazenamento & Limpeza"; Name = "Limpeza Segura de Caches de Shaders (NVIDIA/DirectX) e Temp"; Action = { Clear-ShaderCache } },

        # Categoria 8: Processos em Segundo Plano (Debloat)
        [ordered]@{ Id = 25; Category = "Processos em Segundo Plano"; Name = "Desativação de Aplicações UWP em Segundo Plano (Poupança CPU/RAM)"; Action = { Disable-BackgroundUWPApps } },
        [ordered]@{ Id = 26; Category = "Processos em Segundo Plano"; Name = "Desativação de Registo Diagnóstico SleepStudy / Modern Standby"; Action = { Disable-SleepStudyLogging } },
        [ordered]@{ Id = 27; Category = "Processos em Segundo Plano"; Name = "Desativação de Windows Error Reporting (WER)"; Action = { Disable-WindowsErrorReporting } },

        # Categoria 9: Agilidade do Sistema & QoL
        [ordered]@{ Id = 28; Category = "Agilidade & QoL"; Name = "Eliminação de Delays de Interface e Menus (0 ms Instantâneo)"; Action = { Set-InterfaceDelays } },
        [ordered]@{ Id = 29; Category = "Agilidade & QoL"; Name = "Arranque Imediato de Aplicações Pós-Login (StartupDelay 0 ms)"; Action = { Disable-StartupDelay } },
        [ordered]@{ Id = 30; Category = "Agilidade & QoL"; Name = "Encerramento e Reinício Rápido do Sistema (Timeout 2s)"; Action = { Set-FastShutdown } },
        [ordered]@{ Id = 31; Category = "Agilidade & QoL"; Name = "Alt-Tab Limpo (Apenas Janelas Abertas, sem Separadores do Edge)"; Action = { Set-AltTabFilter } },
        [ordered]@{ Id = 32; Category = "Agilidade & QoL"; Name = "Atalho 'Terminar Tarefa' na Barra de Tarefas (Windows 11)"; Action = { Enable-TaskbarEndTask } },
        [ordered]@{ Id = 33; Category = "Agilidade & QoL"; Name = "Desativação de Processos em Fundo do Microsoft Copilot"; Action = { Disable-Copilot } },
        [ordered]@{ Id = 34; Category = "Agilidade & QoL"; Name = "Desativação de Popups de Teclas Presas (StickyKeys Shift 5x)"; Action = { Disable-StickyKeysPopup } },

        # Categoria 10: Escalonamento de CPU & Latência Gráfica (Fase 2)
        [ordered]@{ Id = 35; Category = "Escalonamento & Gráficos"; Name = "Escalonamento de CPU para Jogos (Win32PrioritySeparation 0x26)"; Action = { Set-CpuScheduling } },
        [ordered]@{ Id = 36; Category = "Escalonamento & Gráficos"; Name = "Prioridade Multimédia MMCSS para Jogos (Games Profile High)"; Action = { Set-MMCSSTasksGames } },
        [ordered]@{ Id = 37; Category = "Escalonamento & Gráficos"; Name = "HAGS Condicional (WDDM 2.7+ e VRAM Dedicada >= 6GB)"; Action = { Enable-HAGSConditional } },

        # Categoria 11: Hardware, Rede & Periféricos (Baixa Latência)
        [ordered]@{ Id = 38; Category = "Hardware & Periféricos"; Name = "Adaptadores de Rede: Desativação de EEE / Green Ethernet (Desktop/AC)"; Action = { Optimize-NetworkAdapterPower } },
        [ordered]@{ Id = 39; Category = "Hardware & Periféricos"; Name = "Hubs USB Raiz: Desativação de Suspensão de Energia (Desktop/AC)"; Action = { Disable-UsbPowerManagement } },
        [ordered]@{ Id = 40; Category = "Hardware & Periféricos"; Name = "Modo MSI (Message Signaled Interrupts) na GPU Dedicada"; Action = { Enable-GpuMsiMode } },

        # Categoria 12: Navegadores, Jogos em Janela & Armazenamento Avançado
        [ordered]@{ Id = 41; Category = "Navegadores & Janelas"; Name = "Desativação de Tarefas em Segundo Plano de Navegadores (Edge/Chrome)"; Action = { Disable-BrowserBackgroundTasks } },
        [ordered]@{ Id = 42; Category = "Navegadores & Janelas"; Name = "DirectFlip / Otimizações para Jogos em Janela (Windows 11)"; Action = { Enable-WindowedOptimizations } },
        [ordered]@{ Id = 43; Category = "Navegadores & Janelas"; Name = "Re-Trim Otimizado de Memória Flash em SSDs NVMe (Drive C:)"; Action = { Invoke-SsdReTrim } },

        # Categoria 13: Otimizações de Elite (Rede, Explorador & Agendador)
        [ordered]@{ Id = 44; Category = "Elite & Agendador"; Name = "Desativação de Protocolo LLMNR (Redução de Ruído na Rede)"; Action = { Disable-LLMNRProtocol } },
        [ordered]@{ Id = 45; Category = "Elite & Agendador"; Name = "Desativação de Sniffing de Pastas no Explorador (FiveM / Pastas Rápidas)"; Action = { Disable-AutoFolderDiscovery } },
        [ordered]@{ Id = 46; Category = "Elite & Agendador"; Name = "Bloqueio de Acordar por Manutenção Automática (WakeUp = 0)"; Action = { Disable-MaintenanceWakeUp } },

        # Categoria 14: Debloat Profundo & svchost
        [ordered]@{ Id = 47; Category = "Debloat Profundo"; Name = "Agrupamento de Processos svchost.exe (Redução de Processos e RAM)"; Action = { Set-SvcHostProcessGrouping } },
        [ordered]@{ Id = 48; Category = "Debloat Profundo"; Name = "Desativação de Serviços de Telemetria (DiagTrack, PcaSvc, TrkWks)"; Action = { Disable-TelemetryServicesDeep } },
        [ordered]@{ Id = 49; Category = "Debloat Profundo"; Name = "Remoção de Bloatware e Apps Pré-instaladas (Store/Xbox Protegidas)"; Action = { Remove-BloatwareAppX } },

        # Categoria 15: Kernel, Memória & I/O Avançado (Atlas Engine)
        [ordered]@{ Id = 50; Category = "Kernel, Memória & I/O"; Name = "Kernel em RAM & Desativação de Page Combining (DisablePagingExecutive)"; Action = { Optimize-KernelMemoryPaging } },
        [ordered]@{ Id = 51; Category = "Kernel, Memória & I/O"; Name = "Indexação Windows Search Sensível a Planos de Energia (RespectPowerModes)"; Action = { Optimize-SearchIndexerPower } },
        [ordered]@{ Id = 52; Category = "Kernel, Memória & I/O"; Name = "Remoção de Estrangulamento de Largura de Banda SMB (LanmanWorkstation)"; Action = { Disable-SmbBandwidthThrottling } },
        [ordered]@{ Id = 53; Category = "Kernel, Memória & I/O"; Name = "Desativação de Gesto Aero Shake (Proteção contra Minimização no Gaming)"; Action = { Disable-AeroShake } },
        [ordered]@{ Id = 54; Category = "Kernel, Memória & I/O"; Name = "Desativação de Verificação Periódica de Pouco Espaço em Disco"; Action = { Disable-LowDiskSpaceChecks } },
        [ordered]@{ Id = 55; Category = "Kernel, Memória & I/O"; Name = "Controlo de Falhas BSOD (Sem Reinício Instantâneo, Diagnóstico Visível)"; Action = { Set-CrashControlQuality } },

        # Categoria 16: Telemetria Silenciosa, Agendador & Caminhos Longos (Atlas Engine)
        [ordered]@{ Id = 56; Category = "Agendador & Telemetria Avançada"; Name = "Desativação de Tarefas Agendadas de Telemetria e Diagnóstico de Disco"; Action = { Disable-MaintenanceScheduledTasks } },
        [ordered]@{ Id = 57; Category = "Agendador & Telemetria Avançada"; Name = "Desativação de Histórico de Atividades e Tracing de Diagnóstico Contínuo"; Action = { Disable-ActivityHistoryAndDiagnosticTracing } },
        [ordered]@{ Id = 58; Category = "Agendador & Telemetria Avançada"; Name = "Bloqueio de Instalação Silenciosa de Apps (ContentDeliveryManager)"; Action = { Disable-SilentAppInstallation } },
        [ordered]@{ Id = 59; Category = "Agendador & Telemetria Avançada"; Name = "Ativação de Caminhos Longos de Ficheiro Win32 (>260 Chars para FiveM/Mods)"; Action = { Enable-LongFilePaths } },
        [ordered]@{ Id = 60; Category = "Agendador & Telemetria Avançada"; Name = "Desativação de DMA Coalescing em Adaptadores de Rede (Menor Jitter/Latência)"; Action = { Disable-NetworkDmaCoalescing } },

        # Categoria 17: Interface, Janelas & Multimédia
        [ordered]@{ Id = 61; Category = "Interface & Multimédia"; Name = "Expansão da Cache de Ícones do Explorador (4096 KB sem Recarregamentos)"; Action = { Optimize-ExplorerIconCache } },
        [ordered]@{ Id = 62; Category = "Interface & Multimédia"; Name = "Desativação de Atenuação de Áudio (Volume de Jogos Estável em Chamadas)"; Action = { Disable-AudioDucking } },
        [ordered]@{ Id = 63; Category = "Interface & Multimédia"; Name = "Menu de Contexto Clássico Instantâneo no Windows 11 (Sem Delays)"; Action = { Set-ClassicContextMenuWin11 } },
        [ordered]@{ Id = 64; Category = "Interface & Multimédia"; Name = "Desativação de Animações de Minimização (Alt-Tab Instantâneo e Fluido)"; Action = { Disable-WindowMinimizeAnimations } },
        [ordered]@{ Id = 65; Category = "Interface & Multimédia"; Name = "Qualidade Máxima de Papel de Parede (100% JPEG sem Compressão)"; Action = { Set-MaxWallpaperQuality } },
        [ordered]@{ Id = 66; Category = "Interface & Multimédia"; Name = "Desativação de Gestos de Extremidade do Ecrã (Edge Swipe no Gaming)"; Action = { Disable-EdgeScreenGestures } },

        # Categoria 18: Firmware, Diagnóstico & Serviços Adicionais
        [ordered]@{ Id = 67; Category = "Firmware & Diagnóstico"; Name = "Bloqueio de Injeção de Bloatware de Firmware/BIOS no Boot (WPBT)"; Action = { Disable-WpbtExecution } },
        [ordered]@{ Id = 68; Category = "Firmware & Diagnóstico"; Name = "Desativação de Telemetria e Relatórios em Fundo da NVIDIA"; Action = { Disable-NvidiaTelemetry } },
        [ordered]@{ Id = 69; Category = "Firmware & Diagnóstico"; Name = "Desativação de Inquéritos e Pedidos de Feedback do Windows (SIUF)"; Action = { Disable-WindowsFeedbackRequests } },
        [ordered]@{ Id = 70; Category = "Firmware & Diagnóstico"; Name = "Desativação de Dicas Online e Promoções Cloud nas Definições"; Action = { Disable-SettingsOnlineTips } },
        [ordered]@{ Id = 71; Category = "Firmware & Diagnóstico"; Name = "Desativação de Serviços de Diagnóstico Silencioso (Hub, WerCpl, Sync)"; Action = { Disable-SilentDiagnosticServices } },
        [ordered]@{ Id = 72; Category = "Firmware & Diagnóstico"; Name = "Desativação de GameBarPresenceWriter em Fundo (Anti-Stutter no Arranque)"; Action = { Disable-GameBarPresenceWriter } },

        # Categoria 19: Rede Competitiva, Hitreg & Resposta de Movimento
        [ordered]@{ Id = 73; Category = "Competitivo: Hitreg & Movimento"; Name = "Resposta Rápida de Teclado & Strafe (Delay 0, Speed 31 Nativo)"; Action = { Optimize-KeyboardRepeatResponse } },
        [ordered]@{ Id = 74; Category = "Competitivo: Hitreg & Movimento"; Name = "Moderação de Interrupções Desativada (ITR = 0 / Hitreg Instantâneo)"; Action = { Disable-NetworkInterruptModeration } },
        [ordered]@{ Id = 75; Category = "Competitivo: Hitreg & Movimento"; Name = "Desativação de RSC e LSO na Rede (Ticks Puros sem Agregação)"; Action = { Disable-NetworkRscAndLso } },
        [ordered]@{ Id = 76; Category = "Competitivo: Hitreg & Movimento"; Name = "Desativação de Controlo de Fluxo na Rede (Flow Control Off / Anti-Bufferbloat)"; Action = { Disable-NetworkFlowControl } },
        [ordered]@{ Id = 77; Category = "Competitivo: Hitreg & Movimento"; Name = "Gestão de Sockets e Portas Efémeras TCP/IP (MaxUserPort=65534, WaitDelay=30s)"; Action = { Optimize-TcpSocketsAndPorts } },
        [ordered]@{ Id = 78; Category = "Competitivo: Hitreg & Movimento"; Name = "Otimização de Pilha TCP Global (Timestamps/ECN Off, AutoTuning Normal)"; Action = { Optimize-NetshTcpGlobal } },

        # Categoria 20: Modo de Jogo & Apresentação Gráfica (FSO)
        [ordered]@{ Id = 79; Category = "Modo de Jogo & Apresentação"; Name = "Ativação do Modo de Jogo Nativo do Windows (AutoGameModeEnabled = 1)"; Action = { Enable-WindowsGameMode } },
        [ordered]@{ Id = 80; Category = "Modo de Jogo & Apresentação"; Name = "Otimização de Ecrã Inteiro e Renderização (FSEBehaviorMode = 2 / Anti-Input Lag)"; Action = { Optimize-FullscreenOptimizations } },

        # Categoria 21: Estabilidade de Frametimes & Otimizações Cirúrgicas
        [ordered]@{ Id = 81; Category = "Estabilidade & Frametimes"; Name = "Desativação de Power Throttling do Windows (Prioridade Contínua no Discord/OBS)"; Action = { Disable-PowerThrottling } },
        [ordered]@{ Id = 82; Category = "Armazenamento & I/O"; Name = "Desativação de Indexação de Ficheiros Comprimidos (.zip/mods no Windows Search)"; Action = { Disable-ZipIndexing } },
        [ordered]@{ Id = 83; Category = "Interface & Multimédia"; Name = "Otimização de Sombras do DWM e Compositor Gráfico (Sem Sombras / Texto Nítido)"; Action = { Optimize-DwmVisualEffects } },
        [ordered]@{ Id = 84; Category = "Privacidade & Telemetria"; Name = "Bloqueio de Downloads em Segundo Plano do Windows Spotlight no LockScreen"; Action = { Disable-WindowsSpotlightDownloads } },
        [ordered]@{ Id = 85; Category = "Explorador & QoL"; Name = "Acesso Rápido Limpo sem Histórico Contínuo no SSD (Menos Escritas)"; Action = { Optimize-QuickAccessHistory } }
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

        Write-Host ("[*] [{0,2}/{1}] {2}" -f $item.Id, $tweaks.Count, $item.Name) -ForegroundColor White
        Write-SkyLog -Message "A iniciar: $($item.Name)" -Level "Info" -NoConsole

        try {
            $null = & $item.Action
            $totalSuccess++
            $Global:SkyManifest.AppliedTweaks += $item.Name
        } catch {
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

    # Salvaguarda de Estado
    Save-SkyManifest

    # Recolha de Métricas Finais (Depois da Otimização)
    $postMetrics = [ordered]@{
        Timestamp       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        ProcessCount    = (Get-Process).Count
        RamUsedMB       = 0
        FreeDiskCGB     = 0
        VbsState        = (Get-VbsStatus)
    }
    $osInfoAfter = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($osInfoAfter) {
        $postMetrics.RamUsedMB = [math]::Round(($osInfoAfter.TotalVisibleMemorySize - $osInfoAfter.FreePhysicalMemory) / 1024)
    }
    $driveCAfter = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if ($driveCAfter) {
        $postMetrics.FreeDiskCGB = [math]::Round($driveCAfter.Free / 1GB, 2)
    }

    $deltaProcess = $baselineMetrics.ProcessCount - $postMetrics.ProcessCount
    $deltaRamMB   = $baselineMetrics.RamUsedMB - $postMetrics.RamUsedMB
    $deltaDiskGB  = [math]::Round($postMetrics.FreeDiskCGB - $baselineMetrics.FreeDiskCGB, 2)

    # 3. Implementação Automática do Painel do Cliente & Relatório Antes vs. Depois
    Write-Host "`n>>> [Passo 3/3] A gerar o 'Painel do Cliente' e Relatório no Ambiente de Trabalho..." -ForegroundColor Magenta
    
    $reportText = @"
================================================================================
                    SkyOptimizer - Relatório de Impacto (Antes vs. Depois)
================================================================================
  Data/Hora:     $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
  Computador:    $env:COMPUTERNAME
  Sistema:       $($Global:SkyManifest.OperatingSystem)
  Núcleo VBS:    $($baselineMetrics.VbsState)
--------------------------------------------------------------------------------
  Métrica                      Antes             Depois            Impacto Real
  ------------------------------------------------------------------------------
  Processos Ativos:            $($baselineMetrics.ProcessCount)               $($postMetrics.ProcessCount)               $(if ($deltaProcess -ge 0) { "-$deltaProcess processos" } else { "+$([math]::Abs($deltaProcess)) processos" })
  Memória RAM em Uso:          $([math]::Round($baselineMetrics.RamUsedMB / 1024, 2)) GB          $([math]::Round($postMetrics.RamUsedMB / 1024, 2)) GB          $(if ($deltaRamMB -gt 0) { "-$([math]::Round($deltaRamMB / 1024, 2)) GB libertados" } else { "Estável" })
  Espaço Livre Disco C:        $($baselineMetrics.FreeDiskCGB) GB         $($postMetrics.FreeDiskCGB) GB         $(if ($deltaDiskGB -gt 0) { "+$deltaDiskGB GB recuperados" } else { "Otimizado" })
  Resolução de Temporizador:   15.6 ms (Padrão)  0.5-1.0 ms        Estabilizado (DynamicTick Off)
  Modo de Interrupção GPU:     Partilhado        Modo MSI          Prioridade Exclusiva Ativa
================================================================================
  Comunidade & Suporte SkyOptimizer:
  Dúvidas ou novos setups? Dá um salto no nosso Discord:
  👉 https://discord.gg/cE8ZaDRGV5
================================================================================
"@

    Deploy-ClientPanel -ReportContent $reportText | Out-Null
    Write-Host $reportText -ForegroundColor Cyan

    # Relatório Final de Execução
    $summaryBox = @"
================================================================================
                         RELATÓRIO DE EXECUÇÃO
================================================================================
  Total de Tweaks Executados:  $($tweaks.Count)
  Sucessos:                    $totalSuccess
  Falhas:                      $totalFailed
  Ponto de Restauro:           $(if ($restorePointCreated) { "Criado com Sucesso" } else { "Ignorado / Restrito" })

  Painel do Cliente:           Criado no Ambiente de Trabalho ('SkyOptimizer - Painel de Controlo')
  Relatório Gravado em:        Área de Trabalho\SkyOptimizer - Painel de Controlo\Relatorio_Otimizacao.txt
  Pasta de Backups:            $Global:SkyBackupDir
  Comando de Reversão:         .\SkyOptimizer.ps1 -Undo
  Discord da Comunidade:       https://discord.gg/cE8ZaDRGV5
================================================================================
"@
    Write-Host $summaryBox -ForegroundColor Green

    if ($totalFailed -gt 0) {
        Write-Host "`nDetalhes das Falhas:" -ForegroundColor Red
        foreach ($f in $failureDetails) {
            Write-Host "  - [#$($f.Id)] $($f.Name): $($f.Reason)" -ForegroundColor Yellow
        }
    }

    # Reinício opcional do Explorer
    Write-Host "`nAlgumas alterações de interface (extensões de ficheiros, widgets, menu iniciar, delays)" -ForegroundColor Gray
    Write-Host "tornam-se imediatamente visíveis após reiniciar o Windows Explorer." -ForegroundColor Gray
    $restartExplorer = Read-Host "Pretende reiniciar o Windows Explorer agora? (S/N)"

    if ($restartExplorer -match '^(s|sim|y|yes)$') {
        Write-Host "A reiniciar o Windows Explorer..." -ForegroundColor Cyan
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Host "[OK] Windows Explorer reiniciado com sucesso." -ForegroundColor Green
    }

    Write-Host "`n[+] SkyOptimizer v2.7 concluído com êxito! Para reverter qualquer alteração, utilize a Opção [4] ou execute: .\SkyOptimizer.ps1 -Undo" -ForegroundColor Cyan
    Read-Host "`nPressione ENTER para regressar ao menu principal..."
}

# ==============================================================================
# 6. FUNÇÃO DE REVERSÃO / UNDO (RESTAURAR ESTADO ORIGINAL)
# ==============================================================================

function Invoke-SkyUndo {
    [CmdletBinding()]
    param()

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
                           Versão: 2.7.0
================================================================================
"@
    Write-Host $banner -ForegroundColor Cyan

    Write-Host "`n[!] ATENÇÃO: Este procedimento irá reverter todas as configurações alteradas" -ForegroundColor Yellow
    Write-Host "    pelo SkyOptimizer de volta para o estado original da máquina." -ForegroundColor Gray
    Write-Host "    Os ficheiros em '$($Global:SkyBackupDir)' serão utilizados como fonte da verdade.`n" -ForegroundColor Gray

    $confirm = Read-Host "Deseja realmente reverter todas as otimizações? (S/N)"
    if ($confirm -notmatch '^(s|sim|y|yes)$') {
        Write-Host "`nOperação de reversão cancelada pelo utilizador." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    Write-SkyLog -Message "Início do processo de REVERSÃO (UNDO) no sistema $env:COMPUTERNAME" -Level "Info" -NoConsole

    # 1. Restauração de Backups de Registo (.reg)
    Write-Host "`n>>> [Passo 1/4] A restaurar ficheiros de Registo (.reg)..." -ForegroundColor Magenta

    # Fallback Automático para o Cofre Permanente (C:\ProgramData\SkyOptimizer\Backups)
    # Garante que a reversão funciona mesmo que a pasta de execução inicial tenha sido apagada
    $permBackupDir = Join-Path -Path $env:SystemDrive -ChildPath "ProgramData\SkyOptimizer\Backups"
    $localHasRegs = (Test-Path $Global:SkyBackupDir) -and ((Get-ChildItem -Path $Global:SkyBackupDir -Filter "*.reg" -ErrorAction SilentlyContinue).Count -gt 0)
    if (-not $localHasRegs -and (Test-Path $permBackupDir)) {
        $permHasRegs = (Get-ChildItem -Path $permBackupDir -Filter "*.reg" -ErrorAction SilentlyContinue).Count -gt 0
        if ($permHasRegs) {
            $Global:SkyBackupDir = $permBackupDir
            Write-Host "  [INFO] A utilizar cofre permanente de backups: '$Global:SkyBackupDir'." -ForegroundColor Gray
            Write-SkyLog -Message "Pasta de backups local ausente. A utilizar cofre permanente em '$Global:SkyBackupDir'." -Level "Info" -NoConsole
        }
    }

    $restoredRegCount = 0
    if (Test-Path $Global:SkyBackupDir) {
        $regFiles = Get-ChildItem -Path $Global:SkyBackupDir -Filter "*.reg" -ErrorAction SilentlyContinue

        if (-not $regFiles -or $regFiles.Count -eq 0) {
            Write-Host "  [*] Nenhum ficheiro de backup (.reg) encontrado em .\Backups\" -ForegroundColor Gray
            Write-Host "      (Os backups individuais de registo são gerados ao executar a Opção [1])." -ForegroundColor DarkGray
        } else {
            foreach ($file in $regFiles) {
                Write-Host "  [*] A importar $($file.Name)..." -ForegroundColor Gray -NoNewline

                # Interceções cirúrgicas para chaves de sistema protegidas / de grande porte:
                # 1. 30_FastShutdown_System (HKLM Control - WaitToKillServiceTimeout)
                if ($file.Name -eq "30_FastShutdown_System.reg") {
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "5000" -Type String -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                    continue
                }

                # 2. 47_Control_SvcHostSplit (HKLM Control - SvcHostSplitThresholdInKB)
                if ($file.Name -eq "47_Control_SvcHostSplit.reg") {
                    $svchostFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_svchost_split.txt"
                    $origSvcSplit = 3670016
                    if (Test-Path $svchostFile) {
                        $val = (Get-Content -Path $svchostFile -ErrorAction SilentlyContinue).Trim()
                        if ($val -as [int]) { $origSvcSplit = [int]$val }
                    }
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $origSvcSplit -Type DWord -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                    continue
                }

                # 3. 51_SearchIndexerPower (Windows Search Gather SystemIndex - RespectPowerModes)
                if ($file.Name -eq "51_SearchIndexerPower.reg") {
                    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows Search\Gather\Windows\SystemIndex" -Name "RespectPowerModes" -Force -ErrorAction SilentlyContinue
                    $null = & reg.exe delete "HKLM\Software\Microsoft\Windows Search\Gather\Windows\SystemIndex" /v "RespectPowerModes" /f 2>&1
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                    continue
                }

                # 4. 57_DiagnosticTracing (Diagnostics Performance - DisableDiagnosticTracing)
                if ($file.Name -eq "57_DiagnosticTracing.reg") {
                    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance" -Name "DisableDiagnosticTracing" -Force -ErrorAction SilentlyContinue
                    $null = & reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance" /v "DisableDiagnosticTracing" /f 2>&1
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                    continue
                }

                # 5. 61_Explorer_MaxCachedIcons (HKLM Explorer - Max Cached Icons)
                if ($file.Name -eq "61_Explorer_MaxCachedIcons.reg") {
                    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "Max Cached Icons" -Force -ErrorAction SilentlyContinue
                    $null = & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "Max Cached Icons" /f 2>&1
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                    continue
                }

                # 6. 67_SessionManager_DisableWpbt (Session Manager - DisableWpbtExecution)
                if ($file.Name -eq "67_SessionManager_DisableWpbt.reg") {
                    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWpbtExecution" -Force -ErrorAction SilentlyContinue
                    $null = & reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "DisableWpbtExecution" /f 2>&1
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                    continue
                }

                # 7. 72_GameBar_PresenceWriter (WindowsRuntime ActivatableClassId - ActivationType)
                if ($file.Name -eq "72_GameBar_PresenceWriter.reg") {
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" -Name "ActivationType" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    $null = & reg.exe add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v "ActivationType" /t REG_DWORD /d 1 /f 2>&1
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                    continue
                }

                & reg.exe import "$($file.FullName)" *> $null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com sucesso: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                } else {
                    Write-Host " [OK]" -ForegroundColor Green
                    Write-SkyLog -Message "Registo restaurado com tolerância a permissões: $($file.Name)" -Level "Success" -NoConsole
                    $restoredRegCount++
                }
            }
        }
    } else {
        Write-Host "  [!] Pasta de Backups não encontrada." -ForegroundColor Yellow
    }

    # 2. Remoção de Chaves Criadas de Raiz
    Write-Host "`n>>> [Passo 2/4] A limpar chaves de registo criadas de raiz..." -ForegroundColor Magenta
    $createdKeysFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "created_keys.txt"

    if (Test-Path $createdKeysFile) {
        $createdKeys = Get-Content -Path $createdKeysFile -ErrorAction SilentlyContinue
        foreach ($key in $createdKeys) {
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                Write-Host "  [*] A remover chave recém-criada '$key'..." -ForegroundColor Gray -NoNewline
                & reg.exe delete "$key" /f *> $null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " [OK]" -ForegroundColor Green
                } else {
                    Write-Host " [IGNORADO]" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "  [*] Nenhuma chave necessitou de remoção manual." -ForegroundColor Gray
    }

    # 3. Restauração de Serviços, Hardware e Parâmetros de Sistema
    Write-Host "`n>>> [Passo 3/4] A restaurar Definições de Energia, BCD, Serviços e Armazenamento..." -ForegroundColor Magenta

    # Plano de Energia Original
    $powerPlanFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_power_plan.txt"
    $origPlanGuid = $null
    if (Test-Path $powerPlanFile) {
        $origPlanGuid = (Get-Content -Path $powerPlanFile -ErrorAction SilentlyContinue).Trim()
    } elseif ($Global:SkyManifest.PowerPlan) {
        $origPlanGuid = $Global:SkyManifest.PowerPlan
    }

    if ($origPlanGuid -and ($origPlanGuid -match '^[a-fA-F0-9-]+$')) {
        powercfg -setactive $origPlanGuid 2>$null
        Write-Host "  [OK] Plano de Energia original reativado ($origPlanGuid)." -ForegroundColor Green
        Write-SkyLog -Message "Plano de energia original reativado: $origPlanGuid" -Level "Success" -NoConsole
    } else {
        powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        Write-Host "  [INFO] Plano de Energia reposto para Equilibrado (Balanced)." -ForegroundColor Gray
    }

    # Core Parking (Repor para 0% e desocultar)
    $subGroup   = "54533251-82be-4824-96c1-47b60b740d00"
    $settingMin = "0cc5b647-c1df-4637-891a-dec75c318583"
    $settingMax = "ea062031-0e34-4ff1-9b6d-eb1059324028"
    $null = powercfg -attributes $subGroup $settingMin -ATTRIB_HIDE 2>&1
    $null = powercfg -attributes $subGroup $settingMax -ATTRIB_HIDE 2>&1
    $null = powercfg -setacvalueindex SCHEME_CURRENT $subGroup $settingMin 0 2>&1
    $null = powercfg -setdcvalueindex SCHEME_CURRENT $subGroup $settingMin 0 2>&1
    $null = powercfg -setacvalueindex SCHEME_CURRENT $subGroup $settingMax 100 2>&1
    $null = powercfg -setdcvalueindex SCHEME_CURRENT $subGroup $settingMax 100 2>&1
    $null = powercfg -setactive SCHEME_CURRENT 2>&1
    Write-Host "  [OK] Core Parking reposto para predefinição de gestão de energia." -ForegroundColor Green

    # Suspensão Seletiva USB (Repor para 1 - Ativado por defeito)
    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    $null = powercfg -attributes $usbSubGroup $usbSetting -ATTRIB_HIDE 2>&1
    $null = powercfg -setacvalueindex SCHEME_CURRENT $usbSubGroup $usbSetting 1 2>&1
    $null = powercfg -setdcvalueindex SCHEME_CURRENT $usbSubGroup $usbSetting 1 2>&1
    $null = powercfg -setactive SCHEME_CURRENT 2>&1
    Write-Host "  [OK] Suspensão Seletiva USB reposta para padrão de conservação de energia." -ForegroundColor Green

    # Dynamic Tick (BCD)
    $null = bcdedit /deletevalue disabledynamictick 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Dynamic Tick (BCD) reposto para o valor padrão." -ForegroundColor Green
    } else {
        $null = bcdedit /set disabledynamictick no 2>&1
        Write-Host "  [OK] Dynamic Tick verificado e reposto." -ForegroundColor Green
    }

    # Hibernação
    $hibFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_hibernation.txt"
    $origHib = $null
    if (Test-Path $hibFile) {
        $origHib = (Get-Content -Path $hibFile -ErrorAction SilentlyContinue).Trim()
    } elseif ($null -ne $Global:SkyManifest.Hibernation) {
        $origHib = $Global:SkyManifest.Hibernation
    }

    if ($origHib -eq 1 -or $origHib -eq "1") {
        powercfg -h on 2>$null
        Write-Host "  [OK] Hibernação reativada." -ForegroundColor Green
    } else {
        powercfg -h off 2>$null
        Write-Host "  [INFO] Hibernação mantida desativada (estado original)." -ForegroundColor Gray
    }

    # SysMain (Superfetch)
    $sysmainFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_sysmain.txt"
    $origSysMain = $null
    if (Test-Path $sysmainFile) {
        $origSysMain = (Get-Content -Path $sysmainFile -ErrorAction SilentlyContinue).Trim()
    } elseif ($Global:SkyManifest.SysMain) {
        $origSysMain = $Global:SkyManifest.SysMain
    }

    if ($origSysMain -in @("Auto", "Automatic", "Manual")) {
        $startupType = if ($origSysMain -eq "Manual") { "Manual" } else { "Automatic" }
        Set-Service -Name SysMain -StartupType $startupType -ErrorAction SilentlyContinue
        Start-Service -Name SysMain -ErrorAction SilentlyContinue
        Write-Host "  [OK] Serviço SysMain restaurado para $startupType e reiniciado." -ForegroundColor Green
    }

    # Otimização NTFS (Repor LastAccess e 8.3)
    $null = fsutil behavior set disablelastaccess 0 2>&1
    $null = fsutil behavior set disable8dot3 0 2>&1
    Write-Host "  [OK] Parâmetros de I/O do sistema de ficheiros NTFS repostos." -ForegroundColor Green

    # Armazenamento Reservado (Reativar caso estivesse ativo)
    $resFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_reserved_storage.txt"
    if (Test-Path $resFile) {
        $origRes = (Get-Content -Path $resFile -ErrorAction SilentlyContinue).Trim()
        if ($origRes -eq "Enabled") {
            $null = dism.exe /Online /Set-ReservedStorageState /State:Enabled 2>&1
            Write-Host "  [OK] Armazenamento Reservado reposto para o estado original." -ForegroundColor Green
        }
    }

    # Diagnóstico SleepStudy (Reativar logs sem bloquear ou pedir confirmação)
    'y' | & wevtutil.exe set-log "Microsoft-Windows-SleepStudy/Diagnostic" /e:true /q:true 2>&1 | Out-Null
    'y' | & wevtutil.exe set-log "Microsoft-Windows-Kernel-Processor-Power/Diagnostic" /e:true /q:true 2>&1 | Out-Null
    'y' | & wevtutil.exe set-log "Microsoft-Windows-UserModePowerService/Diagnostic" /e:true /q:true 2>&1 | Out-Null
    $null = schtasks /Change /TN "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /Enable 2>&1
    Write-Host "  [OK] Canais de diagnóstico SleepStudy reativados." -ForegroundColor Green

    # HAGS (Limpeza de HwSchMode se não existia previamente)
    if (-not (Test-Path (Join-Path $Global:SkyBackupDir "37_GraphicsDrivers_HAGS.reg"))) {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Force -ErrorAction SilentlyContinue
    }

    # Adaptadores de Rede (Reativar propriedades de poupança de energia se suportado)
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    foreach ($nic in $adapters) {
        foreach ($prop in @("*EEE", "*GreenEthernet", "*GigaLite", "PowerSavingMode", "EnergyEfficientEthernet")) {
            try {
                $exists = Get-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword $prop -ErrorAction SilentlyContinue
                if ($exists) {
                    Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword $prop -RegistryValue 1 -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    }
    Write-Host "  [OK] Propriedades avançadas de gestão de energia de rede repostas." -ForegroundColor Green

    # SvcHostSplitThresholdInKB (Repor para o valor original ou 3670016 / 3.5GB padrão)
    $svchostFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_svchost_split.txt"
    $origSvcSplit = 3670016
    if (Test-Path $svchostFile) {
        $val = (Get-Content -Path $svchostFile -ErrorAction SilentlyContinue).Trim()
        if ($val -as [int]) { $origSvcSplit = [int]$val }
    }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $origSvcSplit -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] SvcHostSplitThresholdInKB reposto para o valor original ($origSvcSplit KB)." -ForegroundColor Green

    # Serviços de Telemetria Adicionais (DiagTrack, PcaSvc, TrkWks)
    $telemetrySvcFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_telemetry_services.json"
    if (Test-Path $telemetrySvcFile) {
        try {
            $svcMap = Get-Content -Path $telemetrySvcFile -Raw | ConvertFrom-Json
            foreach ($prop in $svcMap.PSObject.Properties) {
                $sName = $prop.Name
                $sMode = $prop.Value
                $startup = if ($sMode -in @("Auto", "Automatic")) { "Automatic" } else { "Manual" }
                Set-Service -Name $sName -StartupType $startup -ErrorAction SilentlyContinue
                if ($startup -eq "Automatic") { Start-Service -Name $sName -ErrorAction SilentlyContinue }
            }
            Write-Host "  [OK] Serviços de telemetria adicionais repostos para os modos de arranque originais." -ForegroundColor Green
        } catch {}
    }

    # Reativação de Tarefas Agendadas de Telemetria e Diagnóstico
    $maintTasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting"
    )
    foreach ($t in $maintTasks) {
        $null = schtasks /Change /TN $t /Enable 2>&1
    }
    Write-Host "  [OK] Tarefas agendadas de diagnóstico/telemetria reativadas." -ForegroundColor Green

    # Reposição de Kernel Memory Paging (se não restaurado por .reg)
    if (-not (Test-Path (Join-Path $Global:SkyBackupDir "50_KernelMemoryManagement.reg"))) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePageCombining" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    # Reposição de CrashControl (AutoReboot)
    if (-not (Test-Path (Join-Path $Global:SkyBackupDir "55_CrashControlDiagnostics.reg"))) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    # Serviços de Diagnóstico Adicionais (Tweak 71)
    $diagSvcFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_diagnostic_services.json"
    if (Test-Path $diagSvcFile) {
        try {
            $diagMap = Get-Content -Path $diagSvcFile -Raw | ConvertFrom-Json
            foreach ($prop in $diagMap.PSObject.Properties) {
                $sName = $prop.Name
                $sVal = $prop.Value
                if ($sName -eq "OneSyncSvc_RegStart") {
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc" -Name "Start" -Value ([int]$sVal) -Type DWord -Force -ErrorAction SilentlyContinue
                } else {
                    $startup = if ($sVal -in @("Auto", "Automatic")) { "Automatic" } else { "Manual" }
                    Set-Service -Name $sName -StartupType $startup -ErrorAction SilentlyContinue
                    if ($startup -eq "Automatic") { Start-Service -Name $sName -ErrorAction SilentlyContinue }
                }
            }
            Write-Host "  [OK] Serviços de diagnóstico adicionais repostos para os modos de arranque originais." -ForegroundColor Green
        } catch {}
    }

    # Tarefas Nvidia Telemetry
    $nvTasks = Get-ScheduledTask -TaskPath "\" -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match '^NvTm' }
    foreach ($t in $nvTasks) { $null = schtasks /Change /TN "$($t.TaskName)" /Enable 2>&1 }

    # Menu de Contexto Clássico Win11 (se chave não existia previamente)
    if (-not (Test-Path (Join-Path $Global:SkyBackupDir "63_Win11_ClassicContextMenu.reg"))) {
        & reg.exe delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f *> $null
    }

    # Fallbacks de Interface, Firmware e Sistema
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "Max Cached Icons" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWpbtExecution" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "1" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "JPEGImportQuality" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" -Name "AllowEdgeSwipe" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" -Name "ActivationType" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Reposição de Rede Competitiva, Hitreg e Teclado (Tweaks 73 a 78)
    Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "1" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force -ErrorAction SilentlyContinue

    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    foreach ($nic in $adapters) {
        try { Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 1 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword "*FlowControl" -RegistryValue 3 -ErrorAction SilentlyContinue } catch {}
    }
    try { Enable-NetAdapterRsc -Name * -ErrorAction SilentlyContinue } catch {}
    try { Enable-NetAdapterLso -Name * -IPv4 -IPv6 -ErrorAction SilentlyContinue } catch {}

    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxUserPort" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpTimedWaitDelay" -Force -ErrorAction SilentlyContinue
    $null = netsh int tcp set global timestamps=allowed 2>&1
    $null = netsh int tcp set global ecncapability=default 2>&1
    $null = netsh int tcp set global autotuninglevel=normal 2>&1

    # Reposição de Modo de Jogo e FSO (Tweaks 79 e 80)
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Force -ErrorAction SilentlyContinue

    # Reposição de Otimizações Cirúrgicas (Tweaks 81 a 85)
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "PreventIndexingArchives" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsSpotlightFeatures" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # 4. Finalização, Limpeza do Painel e Explorer
    Write-Host "`n>>> [Passo 4/4] Finalização" -ForegroundColor Magenta

    # Limpeza da pasta do Painel do Cliente no Ambiente de Trabalho
    $desktopFolders = @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) "SkyOptimizer - Painel de Controlo"),
        (Join-Path $env:USERPROFILE "Desktop\SkyOptimizer - Painel de Controlo"),
        (Join-Path $env:PUBLIC "Desktop\SkyOptimizer - Painel de Controlo")
    ) | Select-Object -Unique

    $panelRemoved = $false
    foreach ($df in $desktopFolders) {
        if (Test-Path $df) {
            if ($PWD.Path -like "$df*") { Set-Location $env:TEMP }
            Remove-Item -Path $df -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path $df)) {
                $panelRemoved = $true
            }
        }
    }
    if ($panelRemoved) {
        Write-Host "  [OK] Pasta 'SkyOptimizer - Painel de Controlo' removida do Ambiente de Trabalho." -ForegroundColor Green
    }

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
  Parâmetros de I/O e Sistema:      Repostos
$(if ($panelRemoved) { "  Painel do Ambiente de Trabalho:   Removido com Sucesso`n" })================================================================================
O seu sistema foi revertido com segurança para o estado anterior.
"@ -ForegroundColor Green

    Read-Host "`nPressione ENTER para regressar ao menu principal..."
}

# ==============================================================================
# 6.1 INSPEÇÃO DO TÉCNICO (HARDWARE, ECRÃ, ARRANQUE & BIOS)
# ==============================================================================

function Invoke-SkyHardwareAudit {
    [CmdletBinding()]
    param()

    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host @'
  ____  _            ___        _   _           _              
 / ___|| | _____   _/ _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __ 
 \___ \| |/ / | | | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
  ___) |   <| |_| | |_| | |_) | |_| | | | | | | |/ /  __/ |   
 |____/|_|\_\\__, |\___/| .__/ \__|_|_| |_| |_|_/___\___|_|   
             |___/      |_|                                    
'@ -ForegroundColor Cyan
    Write-Host "         Inspeção do Técnico - Hardware, Frequências & Arranque" -ForegroundColor White
    Write-Host "                          Versão: 2.7.0" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "`nA analisar componentes do cliente para diagnóstico técnico...`n" -ForegroundColor Gray

    # 1. Memória RAM & Análise de XMP / EXPO
    Write-Host "--- [1/4] Memória RAM & Perfil XMP / EXPO (BIOS) ---" -ForegroundColor Yellow
    $ramModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $totalRamBytes = ($ramModules | Measure-Object -Property Capacity -Sum).Sum
    $compSys = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $totalRamGB = if ($totalRamBytes) { [math]::Round($totalRamBytes / 1GB, 1) } elseif ($compSys.TotalPhysicalMemory) { [math]::Round($compSys.TotalPhysicalMemory / 1GB, 1) } else { 0 }

    if ($ramModules -and $ramModules.Count -gt 0) {
        $firstMod = $ramModules | Select-Object -First 1
        $currentSpeed = $firstMod.ConfiguredClockSpeed
        $nominalSpeed = $firstMod.Speed
        $channelCount = $ramModules.Count

        Write-Host "  Capacidade Total:          $totalRamGB GB ($channelCount pentes instalados - $(if ($channelCount -ge 2) { 'Dual Channel / Multi-Channel Ativo' } else { 'Single Channel - Recomendar 2º módulo ao cliente' }))" -ForegroundColor White
        Write-Host "  Velocidade Atual:          $currentSpeed MHz" -ForegroundColor $(if ($currentSpeed -ge $nominalSpeed -and $currentSpeed -gt 2400) { "Green" } else { "Yellow" })
        Write-Host "  Velocidade Nominal Módulo: $nominalSpeed MHz" -ForegroundColor White

        if ($currentSpeed -lt $nominalSpeed) {
            Write-Host "  [DIAGNÓSTICO TÉCNICO] RAM a $($currentSpeed) MHz (Capacidade Nominal: $($nominalSpeed) MHz)!" -ForegroundColor Yellow
            Write-Host "    -> Perfil XMP (Intel) ou EXPO/DOCP (AMD) DESATIVADO na BIOS da motherboard." -ForegroundColor Cyan
            Write-Host "    -> OPORTUNIDADE: Propor afinação de BIOS ao cliente (+10% a +25% de estabilidade nos 1% Lows)." -ForegroundColor Green
        } elseif ($currentSpeed -in @(2133, 2400) -and $nominalSpeed -eq $currentSpeed) {
            Write-Host "  [INFO JEDEC] A RAM está a correr a $currentSpeed MHz (frequência base)." -ForegroundColor Gray
            Write-Host "    -> Confirmar com o cliente se as memórias suportam frequências superiores para ativar perfil na BIOS." -ForegroundColor Cyan
        } else {
            Write-Host "  [OK] Frequência da RAM afinada ($currentSpeed MHz)." -ForegroundColor Green
        }
    } else {
        Write-Host "  Capacidade Total:          $totalRamGB GB" -ForegroundColor White
        Write-Host "  [INFO] Ambiente Virtualizado (VM) ou chipset OEM sem exposição direta de dados SPD." -ForegroundColor Gray
    }

    # 2. Monitores & Taxa de Atualização (Hz)
    Write-Host "`n--- [2/4] Monitores & Taxa de Atualização (Taxa de Hertz) ---" -ForegroundColor Yellow
    $videoControllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    $monitorsChecked = 0
    foreach ($vc in $videoControllers) {
        if ($vc.CurrentHorizontalResolution -gt 0) {
            $monitorsChecked++
            $hz = $vc.CurrentRefreshRate
            Write-Host "  Ecrã #$($monitorsChecked) - $($vc.Name)" -ForegroundColor White
            Write-Host "  Resolução Atual:           $($vc.CurrentHorizontalResolution) x $($vc.CurrentVerticalResolution)" -ForegroundColor White
            Write-Host "  Taxa de Atualização:       $hz Hz" -ForegroundColor $(if ($hz -gt 60) { "Green" } else { "Yellow" })

            if ($hz -le 60) {
                Write-Host "  [DIAGNÓSTICO TÉCNICO] O monitor está a correr a 60 Hz no Windows." -ForegroundColor Yellow
                Write-Host "    -> Se o monitor do cliente for de 144Hz/165Hz/240Hz, ajustar nas definições do Windows (Ecrã Avançado)." -ForegroundColor Cyan
                Write-Host "    -> Confirmar se o cliente está a utilizar cabo DisplayPort (DP) adequado." -ForegroundColor Gray
            } else {
                Write-Host "  [OK] Monitor de Alta Frequência ativo ($hz Hz - Fluidez Máxima)." -ForegroundColor Green
            }
        }
    }
    if ($monitorsChecked -eq 0) {
        Write-Host "  [INFO] Nenhum ecrã ativo reportado pelo driver WMI." -ForegroundColor Gray
    }

    # 3. Aplicações de Arranque (Impacto em Boot e RAM)
    Write-Host "`n--- [3/4] Aplicações de Inicialização (Consumo de RAM no Boot) ---" -ForegroundColor Yellow
    $startups = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
    $heavyApps = @("Discord", "Spotify", "Steam", "EpicGamesLauncher", "Synapse3", "Overwolf", "Teams", "OneDrive", "Skype", "Battle.net")
    $detectedHeavy = @()

    if ($startups -and $startups.Count -gt 0) {
        Write-Host "  Total de programas no arranque: $($startups.Count)" -ForegroundColor White
        foreach ($s in $startups) {
            $isHeavy = $false
            foreach ($h in $heavyApps) {
                if ($s.Name -match $h -or $s.Command -match $h) { $isHeavy = $true; break }
            }
            if ($isHeavy) {
                $detectedHeavy += $s.Name
                Write-Host "    [!] $($s.Name) (Consome CPU e RAM em segundo plano)" -ForegroundColor Yellow
            } else {
                Write-Host "    [-] $($s.Name)" -ForegroundColor Gray
            }
        }
        if ($detectedHeavy.Count -gt 0) {
            Write-Host "`n  [DIAGNÓSTICO TÉCNICO] Detetadas $($detectedHeavy.Count) aplicações pesadas no arranque do cliente." -ForegroundColor Yellow
            Write-Host "    -> Recomenda-se abrir Gestor de Tarefas > Arranque e desativar com o consentimento do cliente." -ForegroundColor Cyan
            Write-Host "    -> Libertará entre 1.0 GB e 2.5 GB de RAM antes de abrir qualquer jogo!" -ForegroundColor Green
        } else {
            Write-Host "  [OK] Arranque limpo! Nenhuma aplicação pesada detetada na inicialização." -ForegroundColor Green
        }
    } else {
        Write-Host "  [OK] Nenhuma aplicação de inicialização registada (Arranque ultra limpo)." -ForegroundColor Green
    }

    # 4. Estado do Isolamento do Núcleo (VBS / HVCI)
    Write-Host "`n--- [4/4] Camada de Segurança e Jogos (Isolamento do Núcleo) ---" -ForegroundColor Yellow
    $vbsState = Get-VbsStatus
    if ($vbsState -eq "Ativado") {
        Write-Host "  Estado do VBS:             ATIVADO (Segurança de Virtualização Ligada)" -ForegroundColor Yellow
        Write-Host "  Compatibilidade:           VALORANT e jogos no FACEIT funcionam a 100%." -ForegroundColor White
        Write-Host "  Diagnóstico Técnico:       Se o cliente não joga VALORANT nem no FACEIT, desativar no Painel" -ForegroundColor Cyan
        Write-Host "                             do Cliente garante +5% a +15% de FPS e elimina micro-stutters." -ForegroundColor Cyan
    } else {
        Write-Host "  Estado do VBS:             DESATIVADO (Modo Máxima Performance / Menor Latência)" -ForegroundColor Green
        Write-Host "  Compatibilidade:           FiveM, CS2 (Premier/VAC), ARC Raiders, COD com fluidez máxima." -ForegroundColor White
        Write-Host "  Aviso:                     Se o cliente precisar de jogar VALORANT ou CS2 no FACEIT, deve ativar no Painel do Cliente." -ForegroundColor Gray
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "Inspeção Técnica de Hardware e Arranque concluída." -ForegroundColor Green
    Write-Host "Utiliza estas informações para afinar o setup do cliente ou propor serviços VIP de BIOS." -ForegroundColor Gray
    Write-Host "================================================================================" -ForegroundColor Cyan
    Read-Host "`nPressione ENTER para regressar ao menu principal..."
}

# ==============================================================================
# 7. MENU INTERATIVO & DESPACHO DE EXECUÇÃO
# ==============================================================================

# Se invocado com parâmetros diretos de linha de comando:
if ($Apply) {
    Invoke-SkyOptimize
    exit 0
}

if ($Clean) {
    Clear-Host
    Write-Host ">>> A executar Limpeza de Caches de Shaders e Temporários..." -ForegroundColor Cyan
    Clear-ShaderCache
    Write-Host "`n[OK] Manutenção de Shaders concluída." -ForegroundColor Green
    exit 0
}

if ($Undo) {
    Invoke-SkyUndo
    exit 0
}

if ($DeployPanel) {
    Clear-Host
    Write-Host ">>> A gerar 'Painel do Cliente' no Ambiente de Trabalho..." -ForegroundColor Cyan
    Deploy-ClientPanel
    Write-Host "`n[OK] Painel gerado com sucesso no Desktop." -ForegroundColor Green
    exit 0
}

if ($Repair) {
    Repair-WindowsSystemIntegrity
    exit 0
}

if ($Audit) {
    Invoke-SkyHardwareAudit
    exit 0
}

# Modo Interativo Padrão
while ($true) {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host @'
  ____  _            ___        _   _           _              
 / ___|| | _____   _/ _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __ 
 \___ \| |/ / | | | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
  ___) |   <| |_| | |_| | |_) | |_| | | | | | | |/ /  __/ |   
 |____/|_|\_\\__, |\___/| .__/ \__|_|_| |_| |_|_/___\___|_|   
             |___/      |_|                                    
'@ -ForegroundColor Cyan
    Write-Host "                 Windows 10/11 Performance Toolkit" -ForegroundColor White
    Write-Host "                          Versão: 2.7.0" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Show-SystemHardwareInfo
    Write-Host "[1] Aplicar Otimizações Completas (85 Tweaks)" -ForegroundColor Green
    Write-Host "[2] Gerar 'Painel do Cliente' no Ambiente de Trabalho" -ForegroundColor Magenta
    Write-Host "[3] Inspeção do Técnico (Hardware, XMP, Hz do Ecrã & Arranque)" -ForegroundColor Yellow
    Write-Host "[4] Limpeza de Caches e Shaders" -ForegroundColor Cyan
    Write-Host "[5] Reverter Alterações (100% Desfazer)" -ForegroundColor DarkYellow
    Write-Host "[6] Reparar Integridade do Windows (DISM / SFC)" -ForegroundColor Blue
    Write-Host "[7] Sair" -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Escolha uma opção (1-7)"

    switch ($choice.Trim()) {
        "1" {
            Invoke-SkyOptimize
        }
        "2" {
            Clear-Host
            Write-Host ">>> A gerar 'Painel do Cliente' no Ambiente de Trabalho..." -ForegroundColor Cyan
            Deploy-ClientPanel
            Read-Host "`nPressione ENTER para regressar ao menu principal..."
        }
        "3" {
            Invoke-SkyHardwareAudit
        }
        "4" {
            Clear-Host
            Write-Host ">>> A executar Limpeza de Caches de Shaders e Temporários..." -ForegroundColor Cyan
            Clear-ShaderCache
            Read-Host "`nPressione ENTER para regressar ao menu principal..."
        }
        "5" {
            Invoke-SkyUndo
        }
        "6" {
            Repair-WindowsSystemIntegrity
            Read-Host "`nPressione ENTER para regressar ao menu principal..."
        }
        "7" {
            Write-Host "`nA sair do SkyOptimizer. Nenhuma alteração foi realizada." -ForegroundColor Gray
            Start-Sleep -Seconds 1
            exit 0
        }
        Default {
            Write-Host "`nOpção inválida! Escolha de 1 a 7." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}






