# ==============================================================================
# SkyOptimizer - 4-Privacy.ps1
# Categoria 4: Privacidade e Limpeza Leve (4 Tweaks)
# ==============================================================================

# Carregar funções partilhadas caso ainda não estejam carregadas
$commonPath = Join-Path -Path $PSScriptRoot -ChildPath "0-Common.ps1"
if (Test-Path $commonPath) { . $commonPath }

<#
.SYNOPSIS
    Configura a telemetria do Windows para o nível 'Básico / Necessário'.
.DESCRIPTION
    Mantém o Windows Update e a Microsoft Store 100% funcionais, ao mesmo tempo
    que reduz a recolha de dados de diagnóstico e telemetria ao estritamente necessário.
#>
function Set-TelemetryBasic {
    [CmdletBinding()]
    param()

    $dataColKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    Ensure-RegistryPath -KeyPath $dataColKey
    Backup-RegistryKey -KeyPath $dataColKey -BackupName "13_DataCollection_Telemetry"

    # 1 = Nível Básico / Necessário (compatível com todas as edições e serviços)
    Set-ItemProperty -Path $dataColKey -Name "AllowTelemetry" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Telemetria configurada para nível Básico/Necessário (Windows Update e Store seguros)." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Desativa sugestões, publicidade e apps promovidas no Menu Iniciar.
.DESCRIPTION
    Remove as notificações de 'dicas', sugestões automáticas de instalação de apps
    e banners patrocinados no menu Iniciar através do ContentDeliveryManager.
#>
function Disable-StartMenuSuggestions {
    [CmdletBinding()]
    param()

    $cdmKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Ensure-RegistryPath -KeyPath $cdmKey
    Backup-RegistryKey -KeyPath $cdmKey -BackupName "14_ContentDeliveryManager_Suggestions"

    $settings = @{
        "SystemPaneSuggestionsEnabled"        = 0
        "SubscribedContent-338388Enabled"      = 0 # Sugestões do Menu Iniciar
        "SubscribedContent-338389Enabled"      = 0 # Sugestões nas Definições
        "SubscribedContent-353694Enabled"      = 0 # Dicas de boas-vindas
        "SubscribedContent-353696Enabled"      = 0 # Apps sugeridas
        "RotatingLockScreenOverlayEnabled"     = 0 # Dicas no ecrã de bloqueio
    }

    foreach ($name in $settings.Keys) {
        Set-ItemProperty -Path $cdmKey -Name $name -Value $settings[$name] -Type DWord -Force
    }

    Write-SkyLog -Message "Sugestões automáticas e apps promovidas no Menu Iniciar desativadas." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Desativa a pesquisa na Web do Bing no Menu Iniciar e o Windows Spotlight.
.DESCRIPTION
    Evita pesquisas lentas na web quando o utilizador procura apenas ficheiros locais
    no Menu Iniciar, poupando largura de banda e melhorando a rapidez de pesquisa.
#>
function Disable-SearchAndSpotlight {
    [CmdletBinding()]
    param()

    # 1. Desativar sugestões na barra de pesquisa
    $explorerPolicy = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Ensure-RegistryPath -KeyPath $explorerPolicy
    Backup-RegistryKey -KeyPath $explorerPolicy -BackupName "15_SearchSuggestions_Policy"
    Set-ItemProperty -Path $explorerPolicy -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force

    # 2. Desativar Bing Search e Cortana Consent
    $searchKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    Ensure-RegistryPath -KeyPath $searchKey
    Backup-RegistryKey -KeyPath $searchKey -BackupName "15_SearchSettings_User"
    Set-ItemProperty -Path $searchKey -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $searchKey -Name "CortanaConsent" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Pesquisa remota na Web (Bing) desativada no Menu Iniciar (pesquisa local instantânea)." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Desativa os Widgets do Windows 11 e 'Notícias e Interesses' do Windows 10.
.DESCRIPTION
    Desativa os processos em segundo plano do WebView e feeds de notícias
    que consomem memória RAM e ciclos de CPU na barra de tarefas.
#>
function Disable-TaskbarWidgets {
    [CmdletBinding()]
    param()

    # 1. Política de Widgets (Windows 11)
    $dshKey = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    Ensure-RegistryPath -KeyPath $dshKey
    Backup-RegistryKey -KeyPath $dshKey -BackupName "16_Widgets_DshPolicy"
    Set-ItemProperty -Path $dshKey -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force

    # 2. Ocultar ícone de Widgets na barra de tarefas (Windows 11)
    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Ensure-RegistryPath -KeyPath $advKey
    Backup-RegistryKey -KeyPath $advKey -BackupName "16_TaskbarWidgets_User"
    Set-ItemProperty -Path $advKey -Name "TaskbarDa" -Value 0 -Type DWord -Force

    # 3. Desativar Notícias e Interesses (Windows 10)
    $feedsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
    Ensure-RegistryPath -KeyPath $feedsKey
    Backup-RegistryKey -KeyPath $feedsKey -BackupName "16_Feeds_Win10"
    Set-ItemProperty -Path $feedsKey -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWord -Force

    Write-SkyLog -Message "Widgets e Feeds de Notícias da barra de tarefas desativados." -Level "Success"
    return $true
}
