# ==============================================================================
# SkyOptimizer - 1-System.ps1
# Categoria 1: Sistema e Desempenho (6 Tweaks)
# ==============================================================================

# Carregar funções partilhadas caso ainda não estejam carregadas
$commonPath = Join-Path -Path $PSScriptRoot -ChildPath "0-Common.ps1"
if (Test-Path $commonPath) { . $commonPath }

<#
.SYNOPSIS
    Ativa o Plano de Energia 'Desempenho Máximo' (Ultimate Performance).
.DESCRIPTION
    Regista o plano atual para restauração reversível e ativa o perfil de energia
    com latência mínima e máximo desempenho de CPU.
#>
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
            # Fallback para High Performance se o template de Ultimate não existir na edição
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

<#
.SYNOPSIS
    Configura a resolução de temporizador global e desativa o dynamic tick.
.DESCRIPTION
    Ativa GlobalTimerResolutionRequests nativo no kernel e desativa Dynamic Ticking
    no BCD para reduzir jitter de frametime e input lag sem binários externos.
#>
function Set-TimerResolution {
    [CmdletBinding()]
    param()

    # Backup do registo de kernel do Session Manager
    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
    Ensure-RegistryPath -KeyPath $regKey
    Backup-RegistryKey -KeyPath $regKey -BackupName "02_TimerResolution_Kernel"

    Set-ItemProperty -Path $regKey -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force

    # Desativar Dynamic Ticking no BCD
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

<#
.SYNOPSIS
    Desativa o estacionamento de núcleos (Core Parking).
.DESCRIPTION
    Define o patamar mínimo de núcleos ativos para 100% no perfil de energia ativo,
    garantindo que todos os núcleos físicos e lógicos estejam disponíveis sem latência de transição C-State.
#>
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

<#
.SYNOPSIS
    Desativa a hibernação para libertar espaço em disco (hiberfil.sys) e evitar locks.
.DESCRIPTION
    Verifica o estado atual da hibernação, guarda-o para reversibilidade e corre 'powercfg -h off'.
#>
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

<#
.SYNOPSIS
    Desativa o Fault Tolerant Heap (FTH).
.DESCRIPTION
    O FTH monitoriza falhas em aplicações e injeta camadas de segurança de memória
    que geram micro-stutters e overhead adicional durante videojogos intensivos.
#>
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

<#
.SYNOPSIS
    Desativa o SysMain (Superfetch) apenas caso o sistema operativo esteja instalado num SSD/NVMe.
.DESCRIPTION
    Em discos mecânicos (HDD), o SysMain é vital para o pré-carregamento.
    Em SSDs e NVMes ultrarrápidos, gera escritas desnecessárias e consumo residual de CPU/RAM.
#>
function Disable-Superfetch {
    [CmdletBinding()]
    param()

    # 1. Identificar o tipo de disco onde o Windows está instalado
    $sysDriveLetter = $env:SystemDrive.Substring(0, 1)
    $partition = Get-Partition -DriveLetter $sysDriveLetter -ErrorAction SilentlyContinue
    $disk = if ($partition) { Get-PhysicalDisk -DeviceNumber $partition.DiskNumber -ErrorAction SilentlyContinue } else { $null }

    $isSSD = $false
    if ($disk) {
        if ($disk.MediaType -in @('SSD', 'NVMe') -or $disk.BusType -eq 'NVMe') {
            $isSSD = $true
        }
    } else {
        # Fallback de verificação se Get-PhysicalDisk não estiver disponível
        $wmiDrive = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wmiDrive.Model -match 'SSD|NVMe') {
            $isSSD = $true
        }
    }

    if (-not $isSSD) {
        Write-SkyLog -Message "Disco de sistema detetado como HDD/Indeterminado. SysMain MANTIDO ATIVO por segurança." -Level "Warning"
        return $true
    }

    # 2. Guardar o estado original do serviço SysMain
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
