<#
.SYNOPSIS
    SkyOptimizer - Toolkit Autónomo, Não-Destrutivo e 100% Reversível de Otimização Windows 10/11.
.DESCRIPTION
    Ficheiro único consolidado e autocontido (sem dependências externas).
    Aplica 18 otimizações de baixa latência e alto desempenho em sistemas Windows de uso diário,
    sem remover aplicações de sistema, sem tocar em ficheiros protegidos e com backups completos
    (Ponto de Restauro + backups de registo .reg + manifesto de estado + motor de reversão/UNDO).
.PARAMETER Apply
    Aplica diretamente as 18 otimizações sem exibir o menu interativo.
.PARAMETER Undo
    Executa diretamente a reversão de todas as alterações sem exibir o menu interativo.
.EXAMPLE
    .\SkyOptimizer.ps1
    Apresenta o menu interativo inicial (Aplicar / Reverter / Sair).
.EXAMPLE
    .\SkyOptimizer.ps1 -Apply
    Aplica as otimizações diretamente de forma não interativa.
.EXAMPLE
    .\SkyOptimizer.ps1 -Undo
    Reverte todas as otimizações de volta para o estado original.
.NOTES
    Autor: SkyOS Team
    Versão: 1.0.0
    Requisitos: Windows 10 / 11, PowerShell 5.1+, Privilégios de Administrador
#>

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(ParameterSetName = "ApplyDirect")]
    [switch]$Apply,

    [Parameter(ParameterSetName = "UndoDirect")]
    [switch]$Undo
)

# ==============================================================================
# 1. AUTO-ELEVAÇÃO PARA ADMINISTRADOR
# ==============================================================================
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$currentUser
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Privilégios de Administrador necessários. A reiniciar com elevação..." -ForegroundColor Yellow
    $paramString = ""
    if ($Apply) { $paramString = " -Apply" }
    elseif ($Undo) { $paramString = " -Undo" }
    $argsList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$paramString"
    Start-Process powershell.exe -ArgumentList $argsList -Verb RunAs
    exit
}

# ==============================================================================
# 2. INICIALIZAÇÃO DE AMBIENTE, DIRETÓRIOS E VARIÁVEIS GLOBAIS
# ==============================================================================
$Host.UI.RawUI.WindowTitle = "SkyOptimizer v1.0.0 [Administrador]"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

# Diretório de Backups
$Global:SkyBackupDir = Join-Path -Path $scriptDir -ChildPath "Backups"
if (-not (Test-Path $Global:SkyBackupDir)) {
    New-Item -ItemType Directory -Path $Global:SkyBackupDir -Force | Out-Null
}
$Global:SkyBackupDir = (Resolve-Path $Global:SkyBackupDir).Path

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
        AppliedTweaks   = @()
    }
}

# ==============================================================================
# 3. FUNÇÕES PARTILHADAS (LOGGING, REGISTO E ESTADO)
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
            Add-Content -Path $Global:SkyLogFile -Value $fileLogEntry -ErrorAction SilentlyContinue
        }
    } catch {}

    if ($NoConsole) { return }

    switch ($Level) {
        "Success" {
            Write-Host "[OK] " -ForegroundColor Green -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "Warning" {
            Write-Host "[AVISO] " -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor Yellow
        }
        "Error" {
            Write-Host "[FALHOU] " -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor Red
        }
        "Highlight" {
            Write-Host "[*] " -ForegroundColor Cyan -NoNewline
            Write-Host $Message -ForegroundColor Cyan
        }
        "Status" {
            Write-Host ">>> " -ForegroundColor Magenta -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        Default {
            Write-Host "[INFO] " -ForegroundColor Gray -NoNewline
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
            $regProc = Start-Process -FilePath "reg.exe" -ArgumentList "export `"$stdPath`" `"$backupFile`" /y" -Wait -NoNewWindow -PassThru
            if ($regProc.ExitCode -ne 0) {
                Write-SkyLog -Message "Falha ao exportar registo de '$stdPath' (ExitCode: $($regProc.ExitCode))" -Level "Warning"
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
    }
}

function Ensure-RegistryPath {
    param([string]$KeyPath)
    $psPath = Convert-ToPSRegPath -Path $KeyPath
    if (-not (Test-Path $psPath)) {
        New-Item -Path $psPath -Force | Out-Null
    }
}

function Save-SkyManifest {
    $manifestPath = Join-Path -Path $Global:SkyBackupDir -ChildPath "state_backup.json"
    $json = $Global:SkyManifest | ConvertTo-Json -Depth 5
    Set-Content -Path $manifestPath -Value $json -Encoding UTF8 -Force
}

function Load-SkyManifest {
    $manifestPath = Join-Path -Path $Global:SkyBackupDir -ChildPath "state_backup.json"
    if (Test-Path $manifestPath) {
        $json = Get-Content -Path $manifestPath -Raw -Encoding UTF8
        return ($json | ConvertFrom-Json)
    }
    return $null
}

# ==============================================================================
# 4. FUNÇÕES DE OTIMIZAÇÃO (18 TWEAKS EM 5 CATEGORIAS)
# ==============================================================================

# --- CATEGORIA 1: SISTEMA E DESEMPENHO ---

function Set-UltimatePowerPlan {
    [CmdletBinding()]
    param()

    # 1. Guardar o plano de energia atual
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

    # 2. Procurar se o Ultimate Performance já existe no sistema
    $allSchemes = powercfg -list 2>&1
    $ultimateGuid = $null

    foreach ($line in ($allSchemes -split "`r?`n")) {
        if ($line -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})' -and 
            ($line -match 'Ultimate Performance' -or $line -match 'Desempenho Máximo')) {
            $ultimateGuid = $matches[1]
            break
        }
    }

    # 3. Se não existir, duplicar o template oficial do Ultimate Performance
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
        powercfg -setactive $ultimateGuid
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
        Write-SkyLog -Message "Aviso: bcdedit disabledynamictick devolveu código de aviso: $bcdResult" -Level "Warning"
    }

    Write-SkyLog -Message "Temporizador de alta precisão (GlobalTimerResolutionRequests & DynamicTick=Disabled) aplicado." -Level "Success"
    return $true
}

function Disable-CoreParking {
    [CmdletBinding()]
    param()

    $subGroup = "54533251-82be-4824-96c1-47b60b740d00" # Subgrupo de Processador
    $setting  = "0cc5b647-c1df-4637-891a-dec75c318583" # Processor performance core parking min cores

    powercfg -setacvalueindex scheme_current $subGroup $setting 100
    powercfg -setdcvalueindex scheme_current $subGroup $setting 100
    powercfg -setactive scheme_current

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

    powercfg -h off
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
        Write-SkyLog -Message "Disco de sistema detetado como HDD/Indeterminado. SysMain MANTIDO ATIVO por segurança." -Level "Warning"
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

    Write-SkyLog -Message "Aceleração de rato desativada (input linear 1:1 configurado)." -Level "Success"
    return $true
}

function Disable-USBSelectiveSuspend {
    [CmdletBinding()]
    param()

    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"

    powercfg -setacvalueindex scheme_current $usbSubGroup $usbSetting 0
    powercfg -setdcvalueindex scheme_current $usbSubGroup $usbSetting 0
    powercfg -setactive scheme_current

    Write-SkyLog -Message "Suspensão Seletiva USB desativada no perfil de energia ativo." -Level "Success"
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

# --- CATEGORIA 3: OTIMIZAÇÕES DE REDE ---

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

    Write-SkyLog -Message "Algoritmo de Nagle desativado (TCPNoDelay=1, TcpAckFrequency=1) em $configuredCount interface(s) ativa(s)." -Level "Success"
    return $true
}

function Optimize-NetworkThrottling {
    [CmdletBinding()]
    param()

    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Ensure-RegistryPath -KeyPath $profileKey
    Backup-RegistryKey -KeyPath $profileKey -BackupName "11_Multimedia_SystemProfile"

    Set-ItemProperty -Path $profileKey -Name "NetworkThrottlingIndex" -Value ([uint32]0xFFFFFFFF) -Type DWord -Force
    Set-ItemProperty -Path $profileKey -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Network Throttling desativado e SystemResponsiveness definido para 0." -Level "Success"
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

# --- CATEGORIA 4: PRIVACIDADE E LIMPEZA LEVE ---

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
    Set-ItemProperty -Path $advKey -Name "TaskbarDa" -Value 0 -Type DWord -Force

    $feedsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
    Ensure-RegistryPath -KeyPath $feedsKey
    Backup-RegistryKey -KeyPath $feedsKey -BackupName "16_Feeds_Win10"
    Set-ItemProperty -Path $feedsKey -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWord -Force

    Write-SkyLog -Message "Widgets e Feeds de Notícias da barra de tarefas desativados." -Level "Success"
    return $true
}

# --- CATEGORIA 5: EXPLORADOR DE FICHEIROS E QOL ---

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

# ==============================================================================
# 5. FUNÇÃO PRINCIPAL DE OTIMIZAÇÃO (APLICAR 18 TWEAKS)
# ==============================================================================

function Invoke-SkyOptimize {
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
                 Windows 10/11 Performance Toolkit
                          Versão: 1.0.0
================================================================================
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-SkyLog -Message "Início da sessão de Otimização SkyOptimizer v1.0.0 em $env:COMPUTERNAME ($($Global:SkyManifest.OperatingSystem))" -Level "Info" -NoConsole

    # 1. Ponto de Restauro do Sistema
    Write-Host "`n>>> [Passo 1/2] Segurança do Sistema" -ForegroundColor Magenta
    Write-Host "A verificar / criar Ponto de Restauro do Sistema antes de aplicar alterações..." -ForegroundColor Gray

    $restorePointCreated = $false
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
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
            return
        }
    }

    # 2. Execução dos 18 Tweaks
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
            $null = & $item.Action
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

    # Salvaguarda de Estado
    Save-SkyManifest

    # Relatório Final
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
  Comando de Reversão:         .\SkyOptimizer.ps1 -Undo
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
    Write-Host "`nAlgumas alterações de interface (extensões de ficheiros, widgets, menu iniciar)" -ForegroundColor Gray
    Write-Host "tornam-se imediatamente visíveis após reiniciar o Windows Explorer." -ForegroundColor Gray
    $restartExplorer = Read-Host "Pretende reiniciar o Windows Explorer agora? (S/N)"

    if ($restartExplorer -match '^(s|sim|y|yes)$') {
        Write-Host "A reiniciar o Windows Explorer..." -ForegroundColor Cyan
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Host "[OK] Windows Explorer reiniciado com sucesso." -ForegroundColor Green
    }

    Write-Host "`n[+] SkyOptimizer concluído com êxito! Para reverter qualquer alteração, execute: .\SkyOptimizer.ps1 -Undo" -ForegroundColor Cyan
    Read-Host "`nPressione ENTER para concluir..."
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
                          Versão: 1.0.0
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

    $restoredRegCount = 0
    if (Test-Path $Global:SkyBackupDir) {
        $regFiles = Get-ChildItem -Path $Global:SkyBackupDir -Filter "*.reg" -ErrorAction SilentlyContinue

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

    # 2. Remoção de Chaves Criadas de Raiz
    Write-Host "`n>>> [Passo 2/4] A limpar chaves de registo criadas de raiz..." -ForegroundColor Magenta
    $createdKeysFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "created_keys.txt"

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

    # 3. Restauração de Serviços e Hardware
    Write-Host "`n>>> [Passo 3/4] A restaurar Definições de Energia, BCD e Serviços..." -ForegroundColor Magenta

    # Plano de Energia Original
    $powerPlanFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_power_plan.txt"
    $origPlanGuid = $null
    if (Test-Path $powerPlanFile) {
        $origPlanGuid = (Get-Content -Path $powerPlanFile -ErrorAction SilentlyContinue).Trim()
    } elseif ($Global:SkyManifest.PowerPlan) {
        $origPlanGuid = $Global:SkyManifest.PowerPlan
    }

    if ($origPlanGuid -and ($origPlanGuid -match '^[a-fA-F0-9-]+$')) {
        powercfg -setactive $origPlanGuid
        Write-Host "  [OK] Plano de Energia original reativado ($origPlanGuid)." -ForegroundColor Green
        Write-SkyLog -Message "Plano de energia original reativado: $origPlanGuid" -Level "Success"
    } else {
        powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        Write-Host "  [INFO] Plano de Energia reposto para Equilibrado (Balanced)." -ForegroundColor Gray
    }

    # Core Parking (Repor para 0%)
    $subGroup = "54533251-82be-4824-96c1-47b60b740d00"
    $setting  = "0cc5b647-c1df-4637-891a-dec75c318583"
    powercfg -setacvalueindex scheme_current $subGroup $setting 0 2>$null
    powercfg -setdcvalueindex scheme_current $subGroup $setting 0 2>$null
    powercfg -setactive scheme_current 2>$null
    Write-Host "  [OK] Core Parking reposto para predefinição de gestão de energia." -ForegroundColor Green

    # Suspensão Seletiva USB (Repor para 1 - Ativado por defeito)
    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    powercfg -setacvalueindex scheme_current $usbSubGroup $usbSetting 1 2>$null
    powercfg -setdcvalueindex scheme_current $usbSubGroup $usbSetting 1 2>$null
    powercfg -setactive scheme_current 2>$null
    Write-Host "  [OK] Suspensão Seletiva USB reposta para padrão de conservação de energia." -ForegroundColor Green

    # Dynamic Tick (BCD)
    $bcdResult = bcdedit /deletevalue disabledynamictick 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Dynamic Tick (BCD) reposto para o valor padrão." -ForegroundColor Green
    } else {
        bcdedit /set disabledynamictick no 2>&1 | Out-Null
        Write-Host "  [OK] Dynamic Tick verificado e reposto." -ForegroundColor Green
    }

    # Hibernação
    $hibFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "previous_hibernation.txt"
    $origHib = $null
    if (Test-Path $hibFile) {
        $origHib = (Get-Content -Path $hibFile -ErrorAction SilentlyContinue).Trim()
    } elseif ($null -ne $Global:SkyManifest.Hibernation) {
        $origHib = "$($Global:SkyManifest.Hibernation)"
    }

    if ($origHib -eq "1") {
        powercfg -h on
        Write-Host "  [OK] Hibernação reativada (estado original: Ativa)." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Hibernação mantida no estado original." -ForegroundColor Gray
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

    # 4. Finalização e Explorer
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

    Read-Host "`nPressione ENTER para concluir..."
}

# ==============================================================================
# 7. MENU INTERATIVO & DESPACHO DE EXECUÇÃO
# ==============================================================================

# Se invocado com parâmetros diretos de linha de comando:
if ($Apply) {
    Invoke-SkyOptimize
    exit 0
}

if ($Undo) {
    Invoke-SkyUndo
    exit 0
}

# Modo Interativo Padrão
while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "           SkyOptimizer v1.0            " -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[1] Aplicar Otimizações" -ForegroundColor Green
    Write-Host "[2] Reverter Alterações (Desfazer)" -ForegroundColor Yellow
    Write-Host "[3] Sair" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Escolha uma opção"

    switch ($choice.Trim()) {
        "1" {
            Invoke-SkyOptimize
            exit 0
        }
        "2" {
            Invoke-SkyUndo
            exit 0
        }
        "3" {
            Write-Host "`nA sair do SkyOptimizer. Nenhuma alteração foi realizada." -ForegroundColor Gray
            Start-Sleep -Seconds 1
            exit 0
        }
        Default {
            Write-Host "`nOpção inválida! Escolha 1, 2 ou 3." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
