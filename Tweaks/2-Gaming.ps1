# ==============================================================================
# SkyOptimizer - 2-Gaming.ps1
# Categoria 2: Input e Gaming (3 Tweaks)
# ==============================================================================

# Carregar funções partilhadas caso ainda não estejam carregadas
$commonPath = Join-Path -Path $PSScriptRoot -ChildPath "0-Common.ps1"
if (Test-Path $commonPath) { . $commonPath }

<#
.SYNOPSIS
    Desativa a aceleração de rato (Enhanced Pointer Precision).
.DESCRIPTION
    Configura resposta de mira direta 1:1 ao desativar MouseSpeed e os limiares
    de aceleração angular no registo do utilizador atual.
#>
function Disable-MouseAcceleration {
    [CmdletBinding()]
    param()

    $mouseKey = "HKCU:\Control Panel\Mouse"
    Ensure-RegistryPath -KeyPath $mouseKey
    Backup-RegistryKey -KeyPath $mouseKey -BackupName "07_MouseSettings"

    # Definir valores de aceleração como 0 (movimento linear 1:1)
    Set-ItemProperty -Path $mouseKey -Name "MouseSpeed" -Value "0" -Type String -Force
    Set-ItemProperty -Path $mouseKey -Name "MouseThreshold1" -Value "0" -Type String -Force
    Set-ItemProperty -Path $mouseKey -Name "MouseThreshold2" -Value "0" -Type String -Force

    Write-SkyLog -Message "Aceleração de rato desativada (input linear 1:1 configurado)." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Desativa a suspensão seletiva USB (USB Selective Suspend).
.DESCRIPTION
    Impede que o Windows coloque portas USB e periféricos (rato, teclado, headset, DAC)
    em modo de suspensão de poupança de energia, eliminando micro-delays de 'wake-up'.
#>
function Disable-USBSelectiveSuspend {
    [CmdletBinding()]
    param()

    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"

    # 0 = Desativado (Sem suspensão)
    powercfg -setacvalueindex scheme_current $usbSubGroup $usbSetting 0
    powercfg -setdcvalueindex scheme_current $usbSubGroup $usbSetting 0
    powercfg -setactive scheme_current

    Write-SkyLog -Message "Suspensão Seletiva USB desativada no perfil de energia ativo." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Desativa a gravação em segundo plano do Xbox Game DVR / Game Bar.
.DESCRIPTION
    Reduz o consumo de CPU/GPU e elimina frames perdidos causados pela codificação
    contínua de vídeo em buffer de background.
#>
function Disable-GameDVR {
    [CmdletBinding()]
    param()

    # 1. ConfigStore do utilizador
    $configStore = "HKCU:\System\GameConfigStore"
    Ensure-RegistryPath -KeyPath $configStore
    Backup-RegistryKey -KeyPath $configStore -BackupName "09_GameConfigStore"
    Set-ItemProperty -Path $configStore -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

    # 2. AppCapture do utilizador
    $appCapture = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    Ensure-RegistryPath -KeyPath $appCapture
    Backup-RegistryKey -KeyPath $appCapture -BackupName "09_GameDVR_User"
    Set-ItemProperty -Path $appCapture -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force

    # 3. Política de Sistema (Machine)
    $policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    Ensure-RegistryPath -KeyPath $policyKey
    Backup-RegistryKey -KeyPath $policyKey -BackupName "09_GameDVR_Policy"
    Set-ItemProperty -Path $policyKey -Name "AllowGameDVR" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Gravação em segundo plano do Game DVR / Xbox Game Bar desativada." -Level "Success"
    return $true
}
