# ==============================================================================
# SkyOptimizer - 5-Explorer.ps1
# Categoria 5: Explorador de Ficheiros e Qualidade de Vida (2 Tweaks)
# ==============================================================================

# Carregar funções partilhadas caso ainda não estejam carregadas
$commonPath = Join-Path -Path $PSScriptRoot -ChildPath "0-Common.ps1"
if (Test-Path $commonPath) { . $commonPath }

<#
.SYNOPSIS
    Mostra extensões de ficheiros conhecidos no Explorador do Windows (.exe, .ps1, .zip, etc.).
.DESCRIPTION
    Aumenta a transparência e a segurança ao permitir identificar visualmente
    a extensão real de qualquer ficheiro transferido ou executável.
#>
function Show-FileExtensions {
    [CmdletBinding()]
    param()

    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Ensure-RegistryPath -KeyPath $advKey
    Backup-RegistryKey -KeyPath $advKey -BackupName "17_Explorer_FileExtensions"

    # 0 = Mostrar extensões de todos os tipos de ficheiros
    Set-ItemProperty -Path $advKey -Name "HideFileExt" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Exibição de extensões de ficheiros ativada (.exe, .ps1, etc.)." -Level "Success"
    return $true
}

<#
.SYNOPSIS
    Desativa o arquivamento automático de aplicações não utilizadas.
.DESCRIPTION
    O Windows tenta por defeito 'arquivar' executáveis de aplicações instaladas que não são
    abertas com frequência para poupar disco, introduzindo tempos de espera quando são reabertas.
#>
function Disable-AppArchival {
    [CmdletBinding()]
    param()

    $cdmKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Ensure-RegistryPath -KeyPath $cdmKey
    Backup-RegistryKey -KeyPath $cdmKey -BackupName "18_ContentDeliveryManager_AppArchival"

    # 0 = Desativar arquivamento automático
    Set-ItemProperty -Path $cdmKey -Name "ArchiveApps" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Arquivamento automático de aplicações em segundo plano desativado." -Level "Success"
    return $true
}
