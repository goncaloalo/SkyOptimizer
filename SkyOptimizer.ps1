<#
.SYNOPSIS
    SkyOptimizer v2.8 - perfis de desenvolvimento com baseline e Undo por recurso.
.DESCRIPTION
    Ficheiro único consolidado e autocontido (sem dependências externas).
    Mantém o catálogo de 90 ações, mas só executa ações selecionadas e migradas.
    As restantes conservam o código para revisão e ficam bloqueadas no dispatcher.
    Configurações verificadas não são ganhos comprovados de FPS, frametimes ou input lag.
    Backups legados incompletos são preservados para revisão; não se aplicam defaults no Undo.
    Esta branch ainda exige integração num Windows descartável e benchmarks físicos.
.PARAMETER Apply
    Aplica o perfil selecionado e gera o painel existente.
.PARAMETER Profile
    Balanced (padrão), Performance ou Extreme. Consultar docs/PERFIS.md.
.PARAMETER ExperimentalActions
    IDs adicionais separados por vírgula, apenas para Extreme. Ações não migradas não são executadas.
.PARAMETER Clean
    Limpeza explícita de diagnóstico de shaders, com confirmação e sem Undo dos ficheiros eliminados.
.PARAMETER Undo
    Reverte apenas recursos com baseline verificável, preservando conflitos externos.
.PARAMETER DeployPanel
    Gera exclusivamente o 'Painel do Cliente' no Ambiente de Trabalho.
.EXAMPLE
    .\SkyOptimizer.ps1
    Apresenta o menu interativo inicial.
.EXAMPLE
    .\SkyOptimizer.ps1 -Apply
    Aplica Gaming - Balanced e gera o painel no Desktop.
.EXAMPLE
    .\SkyOptimizer.ps1 -DeployPanel
    Instala os atalhos de 1 clique no Ambiente de Trabalho do cliente.
.EXAMPLE
    .\SkyOptimizer.ps1 -Clean
    Executa a manutenção e limpeza de caches de shaders.
.EXAMPLE
    .\SkyOptimizer.ps1 -Undo
    Restaura as baselines verificáveis e comunica conflitos ou reversões pendentes.
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
    [switch]$Audit,

    [ValidateSet('Balanced', 'Performance', 'Extreme')]
    [string]$Profile = 'Balanced',

    [ValidatePattern('^(\d{1,2}(,\d{1,2})*)?$')]
    [string]$ExperimentalActions = ''
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
    elseif ($Repair) { $paramString = " -Repair" }
    elseif ($Audit) { $paramString = " -Audit" }
    $paramString += " -Profile $Profile"
    if ($ExperimentalActions) { $paramString += " -ExperimentalActions $ExperimentalActions" }
    $argsList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$paramString"
    try {
        $child = Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $argsList -Verb RunAs -Wait -PassThru -ErrorAction Stop
        if ($null -eq $child.ExitCode) { throw 'Processo elevado sem exit code.' }
        exit $child.ExitCode
    } catch { Write-Error $_; exit 1 }
}

# ==============================================================================
# 2. INICIALIZAÇÃO DE AMBIENTE, DIRETÓRIOS E VARIÁVEIS GLOBAIS
# ==============================================================================
$Host.UI.RawUI.WindowTitle = "SkyOptimizer v2.6.0 [Administrador]"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

# Diretório Central de Backups (Cofre Oculto em C:\ProgramData\SkyOptimizer\Backups)
# Todos os backups originais vão DIRETAMENTE para o cofre do sistema, mantendo a pasta de trabalho 100% limpa
$Global:SkyPermDir = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'SkyOptimizer'
$Global:SkyBackupDir = Join-Path -Path $Global:SkyPermDir -ChildPath "Backups"
$Global:SkyPermBackupDir = $Global:SkyBackupDir

# Diretório de Logs
$logsFolder = Join-Path $Global:SkyPermDir 'Logs'
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

function Get-SkyStorageRoot {
    Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'SkyOptimizer'
}

function Get-SkyStorageTrustedSids {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Armazenamento requer processo elevado.' }
    @('S-1-5-18', 'S-1-5-32-544', $identity.User.Value)
}

function Assert-SkyNoReparsePoint {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor -ErrorAction Stop) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Caminho redirecionado recusado: $cursor" }
        }
        $cursor = Split-Path -Parent $cursor
    }
}

function Assert-SkyStorageAcl {
    param($Acl, [string[]]$TrustedSids, [switch]$ParentDirectory)
    $owner = $Acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin $TrustedSids) { throw 'Owner do armazenamento nao e de confianca; preservar dados para revisao manual.' }
    $rules = @($Acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if (-not $rules.Count) { throw 'DACL ausente/vazia; armazenamento recusado.' }
    $writeMask = [Security.AccessControl.FileSystemRights]::Write -bor
        [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership
    if ($ParentDirectory) {
        # ProgramData may permit creating a new child, but not replacing our protected child.
        $writeMask = [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
            [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
            [Security.AccessControl.FileSystemRights]::TakeOwnership
    }
    foreach ($rule in $rules) {
        if ($ParentDirectory -and ($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly)) { continue }
        if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin $TrustedSids -and
            ($rule.FileSystemRights -band $writeMask)) { throw 'Escrita por identidade nao autorizada; nao adotar nem corrigir ACL automaticamente.' }
    }
}

function Assert-SkyStorageTree {
    param([string]$Path, [string[]]$TrustedSids)
    Assert-SkyNoReparsePoint $Path
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    Assert-SkyStorageAcl (Get-Acl -LiteralPath $Path -ErrorAction Stop) $TrustedSids
    if ($item.PSIsContainer) {
        foreach ($child in Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop) {
            Assert-SkyStorageTree -Path $child.FullName -TrustedSids $TrustedSids
        }
    }
}

function New-SkyStorageSecurity {
    $security = New-Object Security.AccessControl.DirectorySecurity
    $security.SetAccessRuleProtection($true, $false)
    $security.SetOwner([Security.Principal.SecurityIdentifier]'S-1-5-32-544')
    foreach ($sid in @('S-1-5-18', 'S-1-5-32-544')) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            [Security.Principal.SecurityIdentifier]$sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $security.AddAccessRule($rule)
    }
    $security
}

function New-SkyProtectedDirectory {
    param([string]$Path)
    Assert-SkyNoReparsePoint $Path
    $null = [IO.Directory]::CreateDirectory($Path, (New-SkyStorageSecurity))
}

function Initialize-SkyStorage {
    $root = Get-SkyStorageRoot
    $trusted = @(Get-SkyStorageTrustedSids)
    Assert-SkyNoReparsePoint $root
    Assert-SkyStorageAcl (Get-Acl -LiteralPath (Split-Path -Parent $root) -ErrorAction Stop) $trusted -ParentDirectory
    # Existing content is evidence, not trusted merely because an administrator can read it.
    if (Test-Path -LiteralPath $root -ErrorAction Stop) { Assert-SkyStorageTree $root $trusted }
    else { New-SkyProtectedDirectory $root; Assert-SkyStorageTree $root $trusted }
    foreach ($name in @('Backups', 'Logs')) {
        $path = Join-Path $root $name
        if (-not (Test-Path -LiteralPath $path -ErrorAction Stop)) { New-SkyProtectedDirectory $path }
    }
    Assert-SkyStorageTree $root $trusted
    $Global:SkyPermDir = $root
    $Global:SkyBackupDir = Join-Path $root 'Backups'
    $Global:SkyPermBackupDir = $Global:SkyBackupDir
}

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

    if ($script:SkyActionContext) {
        if ($Level -eq 'Error') { $script:SkyActionContext.ErrorLogged = $true }
        if ($Level -eq 'Success') {
            $Level = 'Info'
            $Message = "Resultado comunicado pela ação, ainda sem validação: $Message"
        }
    }
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

function Invoke-SkyNativeProcess {
    [CmdletBinding()]
    param(
        [ValidateSet('powercfg.exe', 'reg.exe', 'dism.exe', 'sfc.exe')][string]$FileName,
        [string[]]$Arguments
    )
    # Keep native stderr as diagnostic output; the process exit code decides success.
    $ErrorActionPreference = 'Continue'
    $executable = Join-Path ([Environment]::SystemDirectory) $FileName
    if (-not [IO.File]::Exists($executable)) { throw "Executável indisponível: $executable" }
    $LASTEXITCODE = $null
    $output = @(& $executable @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    [pscustomobject]@{ ExitCode = $exitCode; Output = ($output | Out-String).Trim() }
}

function Invoke-SkyNativeCommand {
    [CmdletBinding()]
    param(
        [ValidateSet('powercfg.exe', 'reg.exe')][string]$FileName,
        [string[]]$Arguments
    )
    $result = Invoke-SkyNativeProcess -FileName $FileName -Arguments $Arguments
    if ($null -eq $result.ExitCode -or $result.ExitCode -ne 0) {
        throw "$FileName falhou (exit code $($result.ExitCode)): $($result.Output)"
    }
    return $result.Output
}

function Write-SkyAtomicFile {
    [CmdletBinding()]
    param([string]$Path, [AllowEmptyString()][string]$Content, [switch]$Ascii)
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $encoding = if ($Ascii) { [Text.Encoding]::ASCII } else { New-Object System.Text.UTF8Encoding($true) }
        $bytes = $encoding.GetPreamble() + $encoding.GetBytes($Content)
        $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
        finally { $stream.Dispose() }
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function New-SkyActionResult {
    [CmdletBinding()]
    param(
        [ValidateSet('Applied', 'AlreadyCompliant', 'Incompatible', 'Failed', 'Unverified', 'NotSelected', 'Deferred')]
        [string]$Status,
        [string]$Reason,
        [ValidateSet('Yes', 'No', 'Unknown')][string]$RestartRequired = 'Unknown'
    )
    [pscustomobject]@{
        PSTypeName = 'SkyOptimizer.ActionResult'
        Status = $Status
        Reason = $Reason
        RestartRequired = $RestartRequired
    }
}

function Get-SkyMachineId {
    (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid
}

function Enter-SkyPowerLock {
    param([string]$BackupDirectory)
    # FileShare.None serializes plan changes in the application and the generated panel.
    [IO.File]::Open((Join-Path $BackupDirectory 'power_state.lock'),
        [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
}

function Read-SkyPowerState {
    param([string]$BackupDirectory)
    $path = Join-Path $BackupDirectory 'power_state.json'
    if (-not [IO.File]::Exists($path)) { return $null }
    $state = [IO.File]::ReadAllText($path) | ConvertFrom-Json -ErrorAction Stop
    if ($state.SchemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace($state.MachineId) -or $state.MachineId -ne (Get-SkyMachineId) -or
        $state.Status -notin @('Prepared', 'Active', 'Restored')) {
        throw 'Baseline de energia inválida, de outra máquina ou de versão não suportada.'
    }
    $original = [guid]::Empty
    $owned = [guid]::Empty
    if (-not [guid]::TryParseExact($state.OriginalGuid, 'D', [ref]$original) -or
        -not [guid]::TryParseExact($state.OwnedGuid, 'D', [ref]$owned) -or
        $original -eq $owned -or $original -eq [guid]::Empty -or $owned -eq [guid]::Empty) {
        throw 'GUIDs inválidos na baseline de energia.'
    }
    return $state
}

function Save-SkyPowerState {
    param([string]$BackupDirectory, $State)
    Write-SkyAtomicFile -Path (Join-Path $BackupDirectory 'power_state.json') -Content ($State | ConvertTo-Json -Depth 4)
}

function Get-SkyPowerGuid {
    param([string]$Text)
    $guidMatches = [regex]::Matches($Text, '(?i)\b[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\b')
    if ($guidMatches.Count -ne 1) { throw 'Não foi possível identificar um único GUID do plano ativo.' }
    return $guidMatches[0].Value.ToLowerInvariant()
}

function Get-SkyActivePowerGuid {
    Get-SkyPowerGuid -Text (Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/getactivescheme'))
}

function Get-SkyPowerGuids {
    $text = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/list')
    $guidMatches = [regex]::Matches($text, '(?i)\b[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\b')
    if ($guidMatches.Count -eq 0) { throw 'Não foi possível enumerar os planos de energia.' }
    @($guidMatches | ForEach-Object { $_.Value.ToLowerInvariant() })
}

function Restore-SkyPowerPlan {
    [CmdletBinding()]
    param([string]$BackupDirectory)
    $lock = Enter-SkyPowerLock -BackupDirectory $BackupDirectory
    try {
        $state = Read-SkyPowerState -BackupDirectory $BackupDirectory
        if (-not $state) {
            $legacyPath = Join-Path $BackupDirectory 'previous_power_plan.txt'
            if (-not [IO.File]::Exists($legacyPath)) {
                return New-SkyActionResult -Status AlreadyCompliant -Reason 'Sem baseline de energia: nenhuma alteração efetuada.' -RestartRequired No
            }
            # A legacy GUID proves neither ownership nor the plan active before an actual change.
            $legacyGuid = [guid]::Empty
            if (-not [guid]::TryParseExact([IO.File]::ReadAllText($legacyPath).Trim(), 'D', [ref]$legacyGuid)) {
                throw 'GUID inválido no backup legado de energia; nenhum default será aplicado.'
            }
            return New-SkyActionResult -Status Unverified -Reason 'Backup legado de energia preservado para revisao manual: autoria e indices originais AC/DC nao demonstrados. Nenhum plano foi alterado.' -RestartRequired No
        }
        if ($state.Status -eq 'Restored') {
            if (@($state.RetainedOwnedGuids | Where-Object { $_ }).Count) {
                return New-SkyActionResult -Status Unverified -Reason "Ativacao original ja revertida. Copias preservadas para revisao manual: $($state.RetainedOwnedGuids -join ', '). Nenhum plano eliminado." -RestartRequired No
            }
            return New-SkyActionResult -Status AlreadyCompliant -Reason 'Este ciclo de energia já foi revertido; nenhuma alteração efetuada.' -RestartRequired No
        }
        $plans = @(Get-SkyPowerGuids)
        $active = Get-SkyActivePowerGuid
        if ($plans -notcontains $state.OriginalGuid) { throw 'Plano original ausente; recuperação automática interrompida.' }
        if ($active -notin @($state.OriginalGuid, $state.OwnedGuid)) {
            throw 'Outro plano foi selecionado entretanto. A reversão não substituirá essa escolha.'
        }
        if ($active -ne $state.OriginalGuid) {
            $null = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/setactive', $state.OriginalGuid)
        }
        if ((Get-SkyActivePowerGuid) -ne $state.OriginalGuid) { throw 'O plano original não ficou ativo.' }
        if ($plans -contains $state.OwnedGuid) {
            # A GUID proves creation, not that every setting still belongs to us. Preserve external edits.
            $retained = @(@($state.RetainedOwnedGuids | Where-Object { $_ }) + $state.OwnedGuid | Select-Object -Unique)
            $state | Add-Member NoteProperty RetainedOwnedGuids $retained -Force
        }
        $state.Status = 'Restored'
        Save-SkyPowerState -BackupDirectory $BackupDirectory -State $state
        if (@($state.RetainedOwnedGuids | Where-Object { $_ }).Count) {
            return New-SkyActionResult -Status Unverified -Reason "Plano original reativado, indices originais intactos. Copias preservadas porque alteracoes externas nao podem ser excluidas: $($state.RetainedOwnedGuids -join ', '). Limpeza manual pendente." -RestartRequired No
        }
        return New-SkyActionResult -Status Applied -Reason 'Plano original reativado sem modificar os seus valores AC/DC; copia ja ausente.' -RestartRequired No
    } finally { $lock.Dispose() }
}

function Get-SkyPowerSetting {
    param([guid]$PlanGuid, [guid]$SubgroupGuid, [guid]$SettingGuid)
    # Query the documented API instead of parsing localized powercfg setting labels.
    if (-not ('SkyOptimizer.PowerRead' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace SkyOptimizer {
    public static class PowerRead {
        [DllImport("powrprof.dll")]
        public static extern uint PowerReadACValueIndex(IntPtr root, ref Guid plan, ref Guid subgroup, ref Guid setting, out uint value);
        [DllImport("powrprof.dll")]
        public static extern uint PowerReadDCValueIndex(IntPtr root, ref Guid plan, ref Guid subgroup, ref Guid setting, out uint value);
    }
}
'@ -ErrorAction Stop
    }
    $ac = [uint32]0
    $dc = [uint32]0
    $acError = [SkyOptimizer.PowerRead]::PowerReadACValueIndex([IntPtr]::Zero, [ref]$PlanGuid, [ref]$SubgroupGuid, [ref]$SettingGuid, [ref]$ac)
    $dcError = [SkyOptimizer.PowerRead]::PowerReadDCValueIndex([IntPtr]::Zero, [ref]$PlanGuid, [ref]$SubgroupGuid, [ref]$SettingGuid, [ref]$dc)
    if ($acError -ne 0 -or $dcError -ne 0) {
        $code = if ($acError -ne 0) { $acError } else { $dcError }
        throw (New-Object ComponentModel.Win32Exception([int]$code))
    }
    [pscustomobject]@{ AC = $ac; DC = $dc }
}

function Set-SkyAcPowerSettings {
    [CmdletBinding()]
    param([object[]]$Settings)
    if (-not (Test-IsDesktopOrAcPower)) {
        return New-SkyActionResult -Status Incompatible -Reason 'AC nao confirmado: nenhum indice de energia alterado.' -RestartRequired No
    }
    $lock = Enter-SkyPowerLock -BackupDirectory $Global:SkyBackupDir
    try {
        $state = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        if (-not $state -or $state.Status -ne 'Active' -or (Get-SkyActivePowerGuid) -ne $state.OwnedGuid) {
            throw 'É necessário um plano Sky ativo e com baseline antes de alterar AC/DC.'
        }
        $before = @()
        # Read all settings first. An unsupported setting must not cause a partially configured group.
        foreach ($setting in $Settings) {
            try {
                $before += Get-SkyPowerSetting -PlanGuid $state.OwnedGuid -SubgroupGuid $setting.Subgroup -SettingGuid $setting.Setting
            } catch {
                if ($_.Exception -is [ComponentModel.Win32Exception] -and $_.Exception.NativeErrorCode -in @(2, 50, 1168)) {
                    return New-SkyActionResult -Status Incompatible -Reason "Definição de energia não disponível nesta plataforma: $($setting.Setting). Nenhum índice alterado." -RestartRequired No
                }
                throw
            }
        }
        $changed = $false
        for ($i = 0; $i -lt $Settings.Count; $i++) {
            $setting = $Settings[$i]
            if ($before[$i].AC -ne $setting.Value) {
                if (-not (Test-IsDesktopOrAcPower)) { throw 'Alimentacao mudou ou ficou desconhecida antes da escrita AC. Baseline preservada para Undo.' }
                $null = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/setacvalueindex', $state.OwnedGuid, $setting.Subgroup, $setting.Setting, [string]$setting.Value)
                $changed = $true
            }
        }
        if ($changed) {
            if (-not (Test-IsDesktopOrAcPower)) { throw 'AC deixou de estar confirmado antes de reativar o plano. Baseline preservada para Undo.' }
            # Refuse to replace a plan selected by a user or another tool during this operation.
            if ((Get-SkyActivePowerGuid) -ne $state.OwnedGuid) { throw 'O plano ativo mudou durante a operação.' }
            $null = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/setactive', $state.OwnedGuid)
        }
        for ($i = 0; $i -lt $Settings.Count; $i++) {
            $setting = $Settings[$i]
            $after = Get-SkyPowerSetting -PlanGuid $state.OwnedGuid -SubgroupGuid $setting.Subgroup -SettingGuid $setting.Setting
            if ($after.AC -ne $setting.Value -or $after.DC -ne $before[$i].DC) {
                throw 'Pós-verificação AC/DC falhou; a baseline original continua disponível para Undo.'
            }
        }
        if ((Get-SkyActivePowerGuid) -ne $state.OwnedGuid) { throw 'A ativação do plano Sky não foi confirmada.' }
        $status = if ($changed) { 'Applied' } else { 'AlreadyCompliant' }
        New-SkyActionResult -Status $status -Reason 'Índices AC verificados no plano Sky; índices DC preservados. Desempenho não medido.' -RestartRequired No
    } finally { $lock.Dispose() }
}

function Get-SkyUserSid {
    [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Get-SkyLegacyBackupFiles {
    param([string]$BackupDirectory)
    if ([IO.Directory]::Exists($BackupDirectory)) {
        Get-ChildItem -LiteralPath $BackupDirectory -File -ErrorAction Stop | Where-Object {
            $_.Extension -eq '.reg' -or $_.Name -eq 'created_keys.txt' -or
            ($_.Name -like 'previous_*' -and $_.Name -ne 'previous_power_plan.txt')
        }
    }
}

function Enter-SkyMutationLock {
    param([string]$BackupDirectory)
    if (-not [IO.Directory]::Exists($BackupDirectory)) { throw 'Diretório de backups inexistente.' }
    [IO.File]::Open((Join-Path $BackupDirectory 'mutation_state.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
}

function Read-SkyMutationState {
    param([string]$BackupDirectory)
    $machineId = Get-SkyMachineId
    $userSid = Get-SkyUserSid
    if ([string]::IsNullOrWhiteSpace($machineId) -or [string]::IsNullOrWhiteSpace($userSid)) {
        throw 'Identidade da maquina/utilizador indisponivel. Nenhuma baseline sera criada ou utilizada.'
    }
    $path = Join-Path $BackupDirectory 'mutation_state.json'
    if (-not [IO.File]::Exists($path)) {
        return [pscustomobject]@{ SchemaVersion = 1; MachineId = $machineId; UserSid = $userSid; Entries = @() }
    }
    $state = [IO.File]::ReadAllText($path) | ConvertFrom-Json -ErrorAction Stop
    if ($state.SchemaVersion -notin @(1,2) -or $state.MachineId -ne $machineId -or
        $state.UserSid -ne $userSid -or $null -eq $state.Entries) {
        throw 'Diário inválido ou pertencente a outra máquina/utilizador. Nenhuma baseline será substituída.'
    }
    $ids = @{}
    $activeResources = @{}
    foreach ($entry in $state.Entries) {
        if (-not $entry.Id -or $ids.ContainsKey($entry.Id) -or $entry.Status -notin @('Pending', 'Applied', 'Restoring', 'Restored')) {
            throw 'Entrada inválida ou duplicada no diário.'
        }
        $ids[$entry.Id] = $true
        Assert-SkyResourceState -Resource $entry.Resource -State $entry.Original
        Assert-SkyResourceState -Resource $entry.Resource -State $entry.Before
        Assert-SkyResourceState -Resource $entry.Resource -State $entry.Desired
        if ($entry.Resource.Type -eq 'ScheduledTaskEnabled' -and $state.SchemaVersion -ne 2) { throw 'Tarefas exigem diario de formato 2.' }
        if ($entry.PSObject.Properties.Name -contains 'OwnerIds') {
            $owners = @($entry.OwnerIds)
            if ($state.SchemaVersion -ne 2 -or -not $owners.Count -or
                @($owners | Where-Object { ($_ -isnot [int] -and $_ -isnot [long]) -or $_ -lt 0 -or $_ -gt [int]::MaxValue }).Count -or
                @($owners | Select-Object -Unique).Count -ne $owners.Count) { throw 'Ownership invalido no diario.' }
        }
        if ($entry.Status -ne 'Restored') {
            $identity = Get-SkyResourceIdentity $entry.Resource
            if ($activeResources.ContainsKey($identity)) { throw 'Mais de uma baseline ativa para o recurso. Diario preservado para revisao.' }
            $activeResources[$identity] = $true
        }
    }
    return $state
}

function Save-SkyMutationState {
    param($State, [string]$BackupDirectory)
    Write-SkyAtomicFile -Path (Join-Path $BackupDirectory 'mutation_state.json') -Content ($State | ConvertTo-Json -Depth 15)
}

function Get-SkyResourceIdentity {
    param($Resource)
    switch ($Resource.Type) {
        'Registry' {
            $identity = [ordered]@{ Type='Registry'; Hive=$Resource.Hive.ToUpperInvariant(); View=$Resource.View.ToUpperInvariant()
                Key=$Resource.Key.TrimEnd('\').ToUpperInvariant(); Name=$Resource.Name.ToUpperInvariant() }
        }
        'ServiceStartup' { $identity = [ordered]@{ Type='ServiceStartup'; Name=$Resource.Name.ToUpperInvariant() } }
        'ServiceRuntime' { $identity = [ordered]@{ Type='ServiceRuntime'; Name=$Resource.Name.ToUpperInvariant() } }
        'NicRegistry' { $identity = [ordered]@{ Type='NicRegistry'; InterfaceGuid=([guid]$Resource.InterfaceGuid).ToString(); Keyword=$Resource.Keyword.ToUpperInvariant() } }
        'ScheduledTaskEnabled' { $identity = [ordered]@{ Type='ScheduledTaskEnabled'; Path=$Resource.Path.ToUpperInvariant(); Name=$Resource.Name.ToUpperInvariant() } }
        default { throw 'Tipo de recurso sem identidade suportada.' }
    }
    $identity | ConvertTo-Json -Compress
}

function ConvertTo-SkyRegistryResource {
    param([string]$Path, [AllowEmptyString()][string]$Name)
    $canonical = $Path -replace '^Microsoft.PowerShell.Core\\Registry::', '' -replace '^Registry::', ''
    $canonical = $canonical -replace '^HKLM:\\?', 'HKEY_LOCAL_MACHINE\' -replace '^HKCU:\\?', 'HKEY_CURRENT_USER\'
    if ($canonical -notmatch '^(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\(.+)$') { throw "Caminho de registo não suportado: $Path" }
    $hive = $Matches[1]; $key = $Matches[2].TrimEnd('\')
    if ($key -match '[\x00]' -or $Name -match '[\x00]') { throw 'Caminho ou nome inválido.' }
    [pscustomobject]@{ Type = 'Registry'; Hive = $hive; Key = $key; Name = $Name
        View = $(if ([Environment]::Is64BitOperatingSystem) { 'Registry64' } else { 'Registry32' }) }
}

function ConvertTo-SkyRegistryState {
    param([bool]$Exists, [string]$Kind = 'None', [AllowNull()]$Value)
    if (-not $Exists) { return [pscustomobject]@{ Exists = $false; Kind = 'None'; Data = $null } }
    $data = switch ($Kind) {
        'DWord' { ([long]$Value).ToString([Globalization.CultureInfo]::InvariantCulture) }
        'QWord' { ([long]$Value).ToString([Globalization.CultureInfo]::InvariantCulture) }
        'Binary' { [Convert]::ToBase64String([byte[]]$Value) }
        'None' { [Convert]::ToBase64String([byte[]]$Value) }
        'MultiString' { ,([string[]]$Value) }
        'String' { [string]$Value }
        'ExpandString' { [string]$Value }
        default { throw "Tipo de registo não suportado: $Kind" }
    }
    [pscustomobject]@{ Exists = $true; Kind = $Kind; Data = $data }
}

function ConvertFrom-SkyRegistryState {
    param($State)
    switch ($State.Kind) {
        'DWord' { return [int]::Parse($State.Data, [Globalization.CultureInfo]::InvariantCulture) }
        'QWord' { return [long]::Parse($State.Data, [Globalization.CultureInfo]::InvariantCulture) }
        'Binary' { return ,([Convert]::FromBase64String($State.Data)) }
        'None' { return ,([Convert]::FromBase64String($State.Data)) }
        'MultiString' { return ,([string[]]$State.Data) }
        default { return [string]$State.Data }
    }
}

function Open-SkyRegistryBase {
    param($Resource)
    $hive = if ($Resource.Hive -eq 'HKEY_LOCAL_MACHINE') { 'LocalMachine' } else { 'CurrentUser' }
    [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]$hive, [Microsoft.Win32.RegistryView]$Resource.View)
}

function Assert-SkyTaskResource {
    param($Resource)
    # This phase deliberately has no production task allowlist. Only operator-created fixtures.
    if ($Resource.Type -ne 'ScheduledTaskEnabled' -or
        $Resource.Path -notmatch '^\\SkyOptimizer-Lab\\[0-9a-f]{32}\\$' -or
        $Resource.Name -notmatch '^Fixture(?:[ _.-][a-z0-9_\[\] .-]+)?$' -or
        $Resource.DefinitionHash -notmatch '^[0-9a-f]{64}$') {
        throw 'Tarefa fora do namespace de laboratorio ou identidade/fingerprint invalida. Nenhuma tarefa de sistema/terceiros permitida.'
    }
}

function Get-SkyTaskDefinitionFingerprint {
    param([string]$Xml, [string]$SecurityDescriptor, [bool]$Enabled)
    if ([string]::IsNullOrWhiteSpace($SecurityDescriptor) -or $Xml.Length -gt 1048576) { throw 'Definicao/seguranca da tarefa indisponivel ou demasiado grande.' }
    $settings=New-Object Xml.XmlReaderSettings
    $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit; $settings.XmlResolver=$null
    $textReader=New-Object IO.StringReader($Xml)
    $reader=[Xml.XmlReader]::Create($textReader,$settings)
    $document=New-Object Xml.XmlDocument
    $document.PreserveWhitespace=$false; $document.XmlResolver=$null
    try { $document.Load($reader) } finally { $reader.Dispose(); $textReader.Dispose() }
    $ns=New-Object Xml.XmlNamespaceManager($document.NameTable)
    $ns.AddNamespace('t','http://schemas.microsoft.com/windows/2004/02/mit/task')
    $nodes=$document.SelectNodes('/t:Task/t:Settings/t:Enabled',$ns)
    if ($document.SelectNodes('/t:Task/t:Settings',$ns).Count -ne 1 -or $nodes.Count -ne 1) { throw 'Definicao de tarefa sem Enabled explicito e inequivoco.' }
    if ([Xml.XmlConvert]::ToBoolean($nodes[0].InnerText.Trim()) -ne $Enabled) { throw 'Estado XML difere da propriedade Enabled.' }
    $null=$nodes[0].ParentNode.RemoveChild($nodes[0])
    Add-Type -AssemblyName System.Security -ErrorAction Stop
    $canonical=New-Object Security.Cryptography.Xml.XmlDsigC14NTransform
    $canonical.LoadInput($document)
    $stream=$canonical.GetOutput([IO.Stream])
    $memory=New-Object IO.MemoryStream
    try { $stream.CopyTo($memory); $bytes=$memory.ToArray() } finally { $stream.Dispose(); $memory.Dispose() }
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        $payload=[Convert]::ToBase64String($bytes)+"`n"+$SecurityDescriptor
        ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)))).Replace('-','')
    } finally { $sha.Dispose() }
}

function Invoke-SkyTaskBackend {
    [CmdletBinding()]
    param($Resource, [ValidateSet('Read','Write')][string]$Operation='Read', [bool]$Enabled)
    Assert-SkyTaskResource $Resource
    $service=$null; $folder=$null; $task=$null
    try {
        $service=New-Object -ComObject 'Schedule.Service' -ErrorAction Stop
        $service.Connect()
        $folder=$service.GetFolder($Resource.Path.TrimEnd('\'))
        $task=$folder.GetTask($Resource.Name)
        if ($task.Path -ine ($Resource.Path+$Resource.Name) -or $task.Name -ine $Resource.Name -or $task.Enabled -isnot [bool]) {
            throw 'A tarefa devolvida nao corresponde a identidade literal pedida.'
        }
        $hash=Get-SkyTaskDefinitionFingerprint -Xml $task.Xml -SecurityDescriptor ($task.GetSecurityDescriptor(7)) -Enabled $task.Enabled
        if ($Operation -eq 'Read') {
            return [pscustomobject]@{ DefinitionHash=$hash; Enabled=[bool]$task.Enabled; RuntimeState=[int]$task.State }
        }
        if ($hash -ine $Resource.DefinitionHash) { throw 'Definicao, principal, triggers, acoes ou seguranca da tarefa mudou. Escrita recusada.' }
        if (-not $Enabled -and [int]$task.State -notin @(1,3)) { throw 'Tarefa ativa/em fila/desconhecida; nao sera parada para alterar Enabled.' }
        # Only this property changes. No registration, deletion, start/stop or security writes.
        $task.Enabled=$Enabled
    } finally {
        foreach ($handle in @($task,$folder,$service)) {
            if ($null -ne $handle -and [Runtime.InteropServices.Marshal]::IsComObject($handle)) {
                $null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($handle)
            }
        }
    }
}

function Disable-SkyScheduledTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][string]$ExpectedDefinitionHash, [Parameter(Mandatory)][string]$BackupDirectory)
    $resource=[pscustomobject]@{ Type='ScheduledTaskEnabled'; Path=$TaskPath; Name=$TaskName; DefinitionHash=$ExpectedDefinitionHash }
    Assert-SkyTaskResource $resource
    $snapshot=Invoke-SkyTaskBackend $resource
    if ($snapshot.DefinitionHash -ine $ExpectedDefinitionHash -or $snapshot.Enabled -isnot [bool] -or $snapshot.RuntimeState -notin @(1,3)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Fingerprint/estado da fixture diferente do autorizado; nenhuma alteracao.' -RestartRequired No
    }
    $result=Invoke-SkyTrackedChange -Resource $resource -Desired ([pscustomobject]@{Enabled=$false}) -BackupDirectory $BackupDirectory
    $result.RestartRequired='No'
    $result.Reason+=' Apenas Enabled da fixture alterado; nao termina execucoes, nao re-regista XML nem demonstra desempenho.'
    $result
}

function Get-SkyResourceState {
    param($Resource)
    if ($Resource.Type -eq 'ScheduledTaskEnabled') {
        $snapshot=Invoke-SkyTaskBackend $Resource
        if ($snapshot.DefinitionHash -ine $Resource.DefinitionHash -or $snapshot.Enabled -isnot [bool]) { throw 'Tarefa substituida/alterada ou estado indisponivel; baseline preservada para revisao.' }
        return [pscustomobject]@{Enabled=[bool]$snapshot.Enabled}
    }
    if ($Resource.Type -eq 'ServiceStartup') {
        $svc = Get-SkyService -Name $Resource.Name
        return [pscustomobject]@{ Value = $svc.StartType.ToString(); Delayed = Get-SkyResourceState $Resource.DelayedResource }
    }
    if ($Resource.Type -eq 'ServiceRuntime') {
        return [pscustomobject]@{ Value = (Get-SkyService -Name $Resource.Name).Status.ToString() }
    }
    if ($Resource.Type -eq 'NicRegistry') {
        $null = Get-SkyNicBinding $Resource
        return Get-SkyResourceState $Resource.Registry
    }
    if ($Resource.Type -ne 'Registry') { throw 'Tipo de recurso não suportado.' }
    $base = Open-SkyRegistryBase $Resource
    $key = $null
    try {
        $key = $base.OpenSubKey($Resource.Key, $false)
        if ($null -eq $key -or $key.GetValueNames() -notcontains $Resource.Name) {
            return ConvertTo-SkyRegistryState -Exists $false
        }
        $value = $key.GetValue($Resource.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        ConvertTo-SkyRegistryState -Exists $true -Kind ($key.GetValueKind($Resource.Name).ToString()) -Value $value
    } finally { if ($key) { $key.Dispose() }; $base.Dispose() }
}

function Set-SkyResourceState {
    param($Resource, $State)
    if ($Resource.Type -eq 'ScheduledTaskEnabled') {
        $null=Invoke-SkyTaskBackend -Resource $Resource -Operation Write -Enabled $State.Enabled
        return
    }
    if ($Resource.Type -eq 'ServiceStartup') {
        Set-SkyServiceStartTypeNative -Name $Resource.Name -StartupType $State.Value
        return
    }
    if ($Resource.Type -eq 'ServiceRuntime') {
        $svc = Get-SkyService -Name $Resource.Name
        if ($State.Value -eq 'Running') {
            # Starting dependencies would change resources for which this entry owns no baseline.
            if (@($svc.ServicesDependedOn | Where-Object Status -ne 'Running').Count) { throw 'Dependências paradas: arranque automático recusado.' }
            Start-Service -InputObject $svc -ErrorAction Stop
        } else {
            if (@($svc.DependentServices | Where-Object Status -ne 'Stopped').Count) { throw 'Dependentes ativos: paragem em cascata recusada.' }
            Stop-Service -InputObject $svc -ErrorAction Stop
        }
        $svc.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]$State.Value, [TimeSpan]::FromSeconds(15))
        return
    }
    if ($Resource.Type -eq 'NicRegistry') {
        $null = Get-SkyNicBinding $Resource
        # Change only this documented driver property. No adapter restart/disconnection here.
        Set-SkyResourceState -Resource $Resource.Registry -State $State
        return
    }
    if ($Resource.Type -ne 'Registry') { throw 'Tipo de recurso não suportado.' }
    $base = Open-SkyRegistryBase $Resource
    $key = $null
    try {
        if ($State.Exists) {
            $key = $base.CreateSubKey($Resource.Key)
            $key.SetValue($Resource.Name, (ConvertFrom-SkyRegistryState $State), [Microsoft.Win32.RegistryValueKind]$State.Kind)
        } else {
            $key = $base.OpenSubKey($Resource.Key, $true)
            if ($key) { $key.DeleteValue($Resource.Name, $false) }
        }
        if ($key) { $key.Flush() }
        # Empty keys are retained: deleting a subtree could erase another application's data.
    } finally { if ($key) { $key.Dispose() }; $base.Dispose() }
}

function Assert-SkyResourceState {
    param($Resource, $State)
    if ($Resource.Type -eq 'ScheduledTaskEnabled') {
        Assert-SkyTaskResource $Resource
        if ($State.Enabled -isnot [bool]) { throw 'Estado Enabled da tarefa invalido.' }
        return
    }
    if ($Resource.Type -in @('ServiceStartup', 'ServiceRuntime')) {
        if ($Resource.Name -notmatch '^[a-zA-Z0-9_.-]+$') { throw 'Identidade de serviço inválida.' }
        $allowed = if ($Resource.Type -eq 'ServiceStartup') { @('Automatic', 'Manual', 'Disabled') } else { @('Running', 'Stopped') }
        if ($State.Value -notin $allowed) { throw 'Estado de serviço não suportado; sem alteração.' }
        if ($Resource.Type -eq 'ServiceStartup') { Assert-SkyResourceState $Resource.DelayedResource $State.Delayed }
        return
    }
    if ($Resource.Type -eq 'NicRegistry') {
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse($Resource.InterfaceGuid, [ref]$parsed) -or -not $Resource.PnpDeviceId -or
            -not $Resource.DriverVersion -or -not $Resource.Keyword) { throw 'Identidade do adaptador inválida.' }
        Assert-SkyResourceState $Resource.Registry $State
        return
    }
    if ($Resource.Type -ne 'Registry' -or $Resource.Hive -notin @('HKEY_LOCAL_MACHINE', 'HKEY_CURRENT_USER') -or
        $Resource.View -notin @('Registry64', 'Registry32') -or -not $Resource.Key -or $null -eq $Resource.Name -or
        $null -eq $State -or $State.Exists -isnot [bool]) { throw 'Recurso/estado de registo inválido.' }
    if ($State.Exists) {
        if ($State.Kind -notin @('String', 'ExpandString', 'MultiString', 'Binary', 'DWord', 'QWord', 'None') -or $null -eq $State.Data) {
            throw 'Tipo/conteúdo de registo inválido.'
        }
        $null = ConvertFrom-SkyRegistryState $State
    } elseif ($State.Kind -ne 'None' -or $null -ne $State.Data) { throw 'Estado ausente inválido.' }
}

function Test-SkyStateEqual {
    param($Left, $Right)
    # Ordered, typed state constructors provide stable serialization, including empty arrays.
    ($Left | ConvertTo-Json -Depth 10 -Compress) -ceq ($Right | ConvertTo-Json -Depth 10 -Compress)
}

function Invoke-SkyTrackedChange {
    [CmdletBinding()]
    param($Resource, $Desired, [string]$BackupDirectory = $Global:SkyBackupDir, $ExpectedBefore,
        [ValidateRange(0,2147483647)][int]$OwnerActionId = 0)
    Assert-SkyResourceState -Resource $Resource -State $Desired
    $lock = Enter-SkyMutationLock $BackupDirectory
    try {
        if (@(Get-SkyLegacyBackupFiles $BackupDirectory).Count) { throw 'Backups legados exigem revisão antes de uma nova baseline. Ficheiros preservados.' }
        $journal = Read-SkyMutationState $BackupDirectory
        $current = Get-SkyResourceState $Resource
        Assert-SkyResourceState -Resource $Resource -State $current
        if ($PSBoundParameters.ContainsKey('ExpectedBefore') -and -not (Test-SkyStateEqual $current $ExpectedBefore)) {
            throw 'Estado mudou desde a preparação; alteração composta cancelada.'
        }
        $identity = Get-SkyResourceIdentity $Resource
        $entries = @($journal.Entries | Where-Object { $_.Status -ne 'Restored' -and (Get-SkyResourceIdentity $_.Resource) -ceq $identity })
        if ($entries.Count -gt 1) { throw 'Mais de uma baseline ativa para o recurso.' }
        $entry = $entries | Select-Object -First 1
        if ($entry) {
            # Identity excludes mutable driver/definition metadata; never silently adopt a replacement.
            if ($Resource.Type -in @('NicRegistry','ScheduledTaskEnabled') -and
                ($entry.Resource | ConvertTo-Json -Compress) -ine ($Resource | ConvertTo-Json -Compress)) {
                throw 'Contrato/identidade do dispositivo ou tarefa mudou; concluir a revisao antes de aplicar.'
            }
            if ($entry.Status -eq 'Restoring') { throw 'Undo interrompido: concluir a reversão antes de aplicar.' }
            $expected = Test-SkyStateEqual $current $entry.Desired
            $pendingBefore = $entry.Status -eq 'Pending' -and (Test-SkyStateEqual $current $entry.Before)
            if (-not ($expected -or $pendingBefore)) { throw 'Conflito: recurso alterado fora do SkyOptimizer. Estado preservado.' }
        }
        $ownerAdded = $false
        if ($entry -and ($OwnerActionId -gt 0 -or $entry.PSObject.Properties.Name -contains 'OwnerIds')) {
            $owners = @(if ($entry.PSObject.Properties.Name -contains 'OwnerIds') { $entry.OwnerIds } else { 0 })
            if (-not (Test-SkyStateEqual $Desired $entry.Desired) -and @($owners | Where-Object { $_ -ne $OwnerActionId }).Count) {
                throw 'Conflito entre acoes: outro proprietario exige um estado diferente. Baseline e configuracao preservadas.'
            }
            if ($OwnerActionId -gt 0 -and $owners -notcontains $OwnerActionId) {
                $entry | Add-Member NoteProperty OwnerIds @($owners + $OwnerActionId) -Force
                $journal.SchemaVersion = 2; $ownerAdded = $true
            }
        }
        if (Test-SkyStateEqual $current $Desired) {
            if ($entry -and $entry.Status -eq 'Pending') {
                $entry.Status = 'Applied'; Save-SkyMutationState $journal $BackupDirectory
            } elseif ($ownerAdded) {
                Save-SkyMutationState $journal $BackupDirectory
            }
            return New-SkyActionResult -Status AlreadyCompliant -Reason 'Estado configurado já conforme; baseline preservada.'
        }
        if (-not $entry) {
            $entry = [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); Resource = $Resource
                Original = $current; Before = $current; Desired = $Desired; Status = 'Pending' }
            if ($OwnerActionId -gt 0) {
                $entry | Add-Member NoteProperty OwnerIds @($OwnerActionId)
                $journal.SchemaVersion = 2
            }
            if ($Resource.Type -eq 'ScheduledTaskEnabled') { $journal.SchemaVersion=2 }
            $journal.Entries = @($journal.Entries) + $entry
        } else { $entry.Before = $current; $entry.Desired = $Desired; $entry.Status = 'Pending' }
        # Durable intent precedes the first system write; a crash can leave only Before or Desired.
        Save-SkyMutationState $journal $BackupDirectory
        if (-not (Test-SkyStateEqual (Get-SkyResourceState $Resource) $current)) { throw 'Conflito detetado antes da escrita.' }
        Set-SkyResourceState -Resource $Resource -State $Desired
        if (-not (Test-SkyStateEqual (Get-SkyResourceState $Resource) $Desired)) { throw 'Pós-verificação falhou; diário preservado para Undo.' }
        $entry.Status = 'Applied'; Save-SkyMutationState $journal $BackupDirectory
        New-SkyActionResult -Status Applied -Reason 'Alteração verificada e baseline persistida. Ganho de desempenho não medido.'
    } finally { $lock.Dispose() }
}

function Restore-SkyTrackedChanges {
    param([string]$BackupDirectory, [string]$ServiceName, [ValidateRange(0,2147483647)][int]$OwnerActionId = 0)
    if (-not [IO.File]::Exists((Join-Path $BackupDirectory 'mutation_state.json'))) { return }
    $lock = Enter-SkyMutationLock $BackupDirectory
    try {
        $journal = Read-SkyMutationState $BackupDirectory
        $entries = @($journal.Entries); [array]::Reverse($entries)
        foreach ($entry in $entries) {
            if ($entry.Status -eq 'Restored') { continue }
            if ($ServiceName -and ($entry.Resource.Type -notin @('ServiceRuntime', 'ServiceStartup') -or $entry.Resource.Name -ne $ServiceName)) { continue }
            if ($OwnerActionId -gt 0 -and ($entry.PSObject.Properties.Name -notcontains 'OwnerIds' -or @($entry.OwnerIds) -notcontains $OwnerActionId)) { continue }
            try {
                $didRestore = $false
                $current = Get-SkyResourceState $entry.Resource
                $currentOriginal = Test-SkyStateEqual $current $entry.Original
                $expected = Test-SkyStateEqual $current $entry.Desired
                $pendingBefore = $entry.Status -in @('Pending', 'Restoring') -and (Test-SkyStateEqual $current $entry.Before)
                if (-not ($currentOriginal -or $expected -or $pendingBefore)) { throw 'Conflito externo; recurso preservado para revisao.' }
                if ($OwnerActionId -gt 0 -and @($entry.OwnerIds).Count -gt 1) {
                    if ($entry.Status -eq 'Restoring') { throw 'Concluir o Undo interrompido antes de libertar ownership parcial.' }
                    $previousOwners = @($entry.OwnerIds)
                    $entry.OwnerIds = @($entry.OwnerIds | Where-Object { $_ -ne $OwnerActionId })
                    try { Save-SkyMutationState $journal $BackupDirectory }
                    catch {
                        # Another resource may save this journal later. Do not commit a failed release through it.
                        $entry.OwnerIds = $previousOwners
                        throw
                    }
                    New-SkyActionResult -Status AlreadyCompliant -Reason "Acao $OwnerActionId libertada; recurso partilhado preservado para os restantes proprietarios." -RestartRequired No
                    continue
                }
                if (-not (Test-SkyStateEqual $current $entry.Original)) {
                    $expected = Test-SkyStateEqual $current $entry.Desired
                    $pendingBefore = $entry.Status -in @('Pending', 'Restoring') -and (Test-SkyStateEqual $current $entry.Before)
                    if (-not ($expected -or $pendingBefore)) { throw 'Conflito externo; recurso preservado para revisão.' }
                    $entry.Status = 'Restoring'; Save-SkyMutationState $journal $BackupDirectory
                    if (-not (Test-SkyStateEqual (Get-SkyResourceState $entry.Resource) $current)) { throw 'Conflito antes da reversão.' }
                    Set-SkyResourceState -Resource $entry.Resource -State $entry.Original
                    if (-not (Test-SkyStateEqual (Get-SkyResourceState $entry.Resource) $entry.Original)) { throw 'Reversão não confirmada.' }
                    $didRestore = $true
                }
                $entry.Status = 'Restored'; Save-SkyMutationState $journal $BackupDirectory
                $restart = if ($entry.Resource.Type -eq 'NicRegistry') { 'Yes' } elseif ($entry.Resource.Type -eq 'ScheduledTaskEnabled') { 'No' } else { 'Unknown' }
                $status = if ($didRestore) { 'Applied' } else { 'AlreadyCompliant' }
                New-SkyActionResult -Status $status -Reason "Baseline confirmada: $($entry.Id)." -RestartRequired $restart
            } catch { New-SkyActionResult -Status Failed -Reason "$($entry.Id): $($_.Exception.Message)" }
        }
    } finally { $lock.Dispose() }
}

function Set-SkyRegistryValue {
    [CmdletBinding()]
    param([string]$Path, [AllowEmptyString()][string]$Name, [AllowNull()]$Value,
        [ValidateSet('String', 'ExpandString', 'MultiString', 'Binary', 'DWord', 'QWord', 'None')][string]$Type = 'DWord', [switch]$Force,
        [ValidateRange(0,2147483647)][int]$OwnerActionId = 0)
    $resource = ConvertTo-SkyRegistryResource $Path $Name
    $desired = ConvertTo-SkyRegistryState -Exists $true -Kind $Type -Value $Value
    Invoke-SkyTrackedChange -Resource $resource -Desired $desired -OwnerActionId $OwnerActionId
}

function Remove-SkyRegistryValue {
    [CmdletBinding()]
    param([string]$Path, [AllowEmptyString()][string]$Name, [switch]$Force)
    Invoke-SkyTrackedChange -Resource (ConvertTo-SkyRegistryResource $Path $Name) -Desired (ConvertTo-SkyRegistryState -Exists $false)
}

function Get-SkyService {
    param([ValidatePattern('^[a-zA-Z0-9_.-]+$')][string]$Name)
    Get-Service -Name $Name -ErrorAction Stop
}

function Set-SkyServiceStartTypeNative {
    param([string]$Name, [ValidateSet('Automatic', 'Manual', 'Disabled')][string]$StartupType)
    # ChangeServiceConfig modifies start type only; delayed start, triggers, account,
    # recovery actions and dependencies are not passed to the API and remain intact.
    if (-not ('SkyServiceConfig' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class SkyServiceConfig {
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr OpenSCManager(string machine, string database, uint access);
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr OpenService(IntPtr manager, string name, uint access);
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool ChangeServiceConfig(IntPtr service, uint type, uint start, uint error,
        string path, string group, IntPtr tag, string dependencies, string account, string password, string display);
    [DllImport("advapi32.dll")] static extern bool CloseServiceHandle(IntPtr handle);
    public static void SetStart(string name, uint start) {
        IntPtr manager = OpenSCManager(null, null, 1);
        if (manager == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            IntPtr service = OpenService(manager, name, 2);
            if (service == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            try {
                if (!ChangeServiceConfig(service, UInt32.MaxValue, start, UInt32.MaxValue,
                    null, null, IntPtr.Zero, null, null, null, null))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
            } finally { CloseServiceHandle(service); }
        } finally { CloseServiceHandle(manager); }
    }
}
'@ -ErrorAction Stop
    }
    $start = @{ Automatic = 2; Manual = 3; Disabled = 4 }[$StartupType]
    [SkyServiceConfig]::SetStart($Name, $start)
}

function Disable-SkyService {
    [CmdletBinding()]
    param([ValidatePattern('^[a-zA-Z0-9_.-]+$')][string]$Name)
    $matches = @(Get-Service -ErrorAction Stop | Where-Object Name -eq $Name)
    if ($matches.Count -eq 0) { return New-SkyActionResult -Status Incompatible -Reason "Serviço ausente: $Name." -RestartRequired No }
    $svc = $matches[0]
    if ($svc.Status -notin @('Running', 'Stopped') -or $svc.StartType -notin @('Automatic', 'Manual', 'Disabled') -or
        ($svc.StartType -eq 'Disabled' -and $svc.Status -eq 'Running') -or
        @($svc.DependentServices | Where-Object Status -ne 'Stopped').Count) {
        return New-SkyActionResult -Status Incompatible -Reason "Estado transitório ou dependentes ativos: $Name. Nenhuma paragem em cascata." -RestartRequired No
    }
    # Stop first, disable second. Undo restores startup first, then runtime.
    $runtime = [pscustomobject]@{ Type = 'ServiceRuntime'; Name = $svc.Name }
    Invoke-SkyTrackedChange -Resource $runtime -Desired ([pscustomobject]@{ Value = 'Stopped' })
    $startup = [pscustomobject]@{ Type = 'ServiceStartup'; Name = $svc.Name
        DelayedResource = ConvertTo-SkyRegistryResource "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)" 'DelayedAutoStart' }
    $current = Get-SkyResourceState $startup
    Invoke-SkyTrackedChange -Resource $startup -Desired ([pscustomobject]@{ Value = 'Disabled'; Delayed = $current.Delayed })
}

function Get-SkyNicBinding {
    param($Resource)
    $adapters = @(Get-NetAdapter -Physical -IncludeHidden -ErrorAction Stop | Where-Object {
        ([guid]$_.InterfaceGuid).ToString() -eq ([guid]$Resource.InterfaceGuid).ToString()
    })
    if ($adapters.Count -ne 1 -or $adapters[0].PnPDeviceID -ne $Resource.PnpDeviceId -or
        $adapters[0].DriverVersionString -ne $Resource.DriverVersion) { throw 'Adaptador removido/substituído ou driver alterado; configuração preservada.' }
    $properties = @(Get-NetAdapterAdvancedProperty -Name ([WildcardPattern]::Escape($adapters[0].Name)) -AllProperties -ErrorAction Stop |
        Where-Object RegistryKeyword -eq $Resource.Keyword)
    if ($properties.Count -ne 1) { throw 'Propriedade do adaptador indisponível ou ambígua.' }
    # Recheck the class-key binding: indices can be reused by Windows after driver changes.
    $binding = ConvertTo-SkyRegistryResource ("HKLM:\" + $Resource.Registry.Key) 'NetCfgInstanceId'
    $guidState = Get-SkyResourceState $binding
    if (-not $guidState.Exists -or ([guid]$guidState.Data) -ne ([guid]$Resource.InterfaceGuid)) { throw 'Chave de driver já não pertence ao adaptador.' }
    return $properties[0]
}

function Switch-SkyPanelService {
    param([ValidateSet('Spooler', 'bthserv')][string]$Name)
    $journal = Read-SkyMutationState $Global:SkyBackupDir
    $owned = @($journal.Entries | Where-Object {
        $_.Status -ne 'Restored' -and $_.Resource.Type -in @('ServiceRuntime', 'ServiceStartup') -and $_.Resource.Name -eq $Name
    })
    if ($owned.Count) { Restore-SkyTrackedChanges -BackupDirectory $Global:SkyBackupDir -ServiceName $Name }
    else { Disable-SkyService -Name $Name }
}

function Get-SkyPanelServiceSource {
    $header = @'
param([ValidateSet('Spooler', 'bthserv')][string]$Name)
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        $child = Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe') -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Name $Name" -Verb RunAs -Wait -PassThru -ErrorAction Stop
        if ($null -eq $child.ExitCode) { throw 'Processo elevado sem exit code.' }
        exit $child.ExitCode
    } catch { Write-Error $_; exit 1 }
}
$Global:SkyBackupDir = Join-Path $env:SystemDrive 'ProgramData\SkyOptimizer\Backups'
'@
    $footer = @'
try {
    Initialize-SkyStorage
    $results = @(Switch-SkyPanelService -Name $Name)
    $results | Format-Table Status, Reason -Wrap
    if (@($results | Where-Object Status -eq 'Failed').Count) { exit 1 }
} catch { Write-Error $_; exit 1 }
'@
    $header + "`r`n" + (Get-SkyPowerRestoreSource) + "`r`n" + $footer
}

function Set-SkyNicProperties {
    [CmdletBinding()]
    param([string[]]$Keywords, [switch]$EthernetOnly)
    $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up')
    if ($EthernetOnly) { $adapters = @($adapters | Where-Object { [int]$_.NdisPhysicalMedium -eq 14 }) }
    if ($adapters.Count -gt 1) {
        return New-SkyActionResult -Status Incompatible -Reason 'Varios adaptadores fisicos ativos elegiveis: selecao ambigua. Nenhuma propriedade alterada; falta selecao explicita por interface.' -RestartRequired No
    }
    $found = $false
    foreach ($nic in $adapters) {
        if ($EthernetOnly -and [int]$nic.NdisPhysicalMedium -ne 14) { continue }
        if (-not $nic.PnPDeviceID -or -not $nic.DriverVersionString) { continue }
        $keys = @(Get-ChildItem -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction Stop |
            Where-Object { $_.PSChildName -match '^\d{4}$' -and
                (([string](Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop).NetCfgInstanceId).Trim('{}') -eq ([guid]$nic.InterfaceGuid).ToString()) })
        if ($keys.Count -ne 1) { continue }
        $properties = @(Get-NetAdapterAdvancedProperty -Name ([WildcardPattern]::Escape($nic.Name)) -AllProperties -ErrorAction Stop)
        foreach ($keyword in $Keywords) {
            $prop = @($properties | Where-Object RegistryKeyword -eq $keyword)
            if ($prop.Count -ne 1 -or $prop[0].ValidRegistryValues -notcontains '0') { continue }
            $registry = ConvertTo-SkyRegistryResource $keys[0].PSPath $keyword
            $before = Get-SkyResourceState $registry
            if (-not $before.Exists -or $before.Kind -notin @('String', 'DWord')) { continue }
            $resource = [pscustomobject]@{ Type = 'NicRegistry'; InterfaceGuid = ([guid]$nic.InterfaceGuid).ToString()
                PnpDeviceId = $nic.PnPDeviceID; DriverVersion = $nic.DriverVersionString; Keyword = $keyword; Registry = $registry }
            $result = Invoke-SkyTrackedChange -Resource $resource -Desired (ConvertTo-SkyRegistryState -Exists $true -Kind $before.Kind -Value 0)
            $result.RestartRequired = 'Yes'
            $result.Reason = "Propriedade persistida e verificada: $keyword em $($nic.Name). Reinício necessário; efeito no driver e latência ainda por medir."
            $result; $found = $true
        }
    }
    if (-not $found) { New-SkyActionResult -Status Incompatible -Reason 'Nenhuma propriedade suportada num adaptador físico ativo; nada alterado.' -RestartRequired No }
}


function Get-SkyPowerRestoreSource {
    # Embed the same implementation in the existing standalone Undo; no runtime module dependency.
    $names = @('Get-SkyStorageRoot', 'Get-SkyStorageTrustedSids', 'Assert-SkyNoReparsePoint', 'Assert-SkyStorageAcl',
        'Assert-SkyStorageTree', 'New-SkyStorageSecurity', 'New-SkyProtectedDirectory', 'Initialize-SkyStorage', 'Invoke-SkyNativeProcess', 'Invoke-SkyNativeCommand', 'Write-SkyAtomicFile',
        'New-SkyActionResult', 'Get-SkyMachineId', 'Enter-SkyPowerLock', 'Read-SkyPowerState',
        'Save-SkyPowerState', 'Get-SkyPowerGuid', 'Get-SkyActivePowerGuid', 'Get-SkyPowerGuids', 'Restore-SkyPowerPlan', 'Get-SkyUndoScope', 'Invoke-SkyVerifiedUndo',
        'Get-SkyUserSid', 'Get-SkyLegacyBackupFiles', 'Enter-SkyMutationLock', 'Read-SkyMutationState', 'Save-SkyMutationState',
        'ConvertTo-SkyRegistryState', 'ConvertFrom-SkyRegistryState', 'Open-SkyRegistryBase',
        'ConvertTo-SkyRegistryResource', 'Get-SkyResourceIdentity', 'Get-SkyService', 'Set-SkyServiceStartTypeNative', 'Get-SkyNicBinding',
        'Assert-SkyTaskResource', 'Get-SkyTaskDefinitionFingerprint', 'Invoke-SkyTaskBackend',
        'Get-SkyResourceState', 'Set-SkyResourceState', 'Assert-SkyResourceState', 'Test-SkyStateEqual', 'Restore-SkyTrackedChanges',
        'Invoke-SkyTrackedChange', 'Disable-SkyService', 'Switch-SkyPanelService')
    ($names | ForEach-Object { "function $_ {`r`n$((Get-Command $_ -CommandType Function).Definition)`r`n}" }) -join "`r`n"
}

function Get-SkyUndoScope {
    param([string]$BackupDirectory)
    if (-not [IO.Directory]::Exists($BackupDirectory)) { return 'None' }
    $files = @(Get-ChildItem -LiteralPath $BackupDirectory -File -ErrorAction Stop |
        Where-Object { $_.Length -gt 0 -and ($_.Extension -eq '.reg' -or $_.Name -match '^(previous_|created_keys\.txt$|power_state\.json$)') })
    if ([IO.File]::Exists((Join-Path $BackupDirectory 'mutation_state.json'))) { return 'Tracked' }
    if (@(Get-SkyLegacyBackupFiles $BackupDirectory).Count) { return 'LegacyMixed' }
    if ($files.Count -eq 0) { return 'None' }
    if (@($files | Where-Object { $_.Name -notin @('power_state.json', 'previous_power_plan.txt') }).Count -eq 0) { return 'PowerOnly' }
    return 'LegacyMixed'
}

function Invoke-SkyAction {
    [CmdletBinding()]
    param([scriptblock]$Action)
    # Legacy booleans cannot prove effective state or distinguish a skip from a failure.
    $previousContext = $script:SkyActionContext
    $script:SkyActionContext = @{ ErrorLogged = $false }
    $output = New-Object 'System.Collections.Generic.List[object]'
    try {
        $ErrorActionPreference = 'Stop'
        & $Action | ForEach-Object { $output.Add($_) }
        if ($script:SkyActionContext.ErrorLogged) { throw 'A ação registou um erro; consultar o log.' }
        $verified = @($output | Where-Object { $_ -and $_.PSTypeNames -contains 'SkyOptimizer.ActionResult' })
        if ($verified.Count -gt 0) {
            $restart = if (@($verified | Where-Object RestartRequired -eq 'Yes').Count) { 'Yes' }
                elseif (@($verified | Where-Object RestartRequired -eq 'Unknown').Count) { 'Unknown' } else { 'No' }
            $applied = @($verified | Where-Object Status -eq 'Applied').Count
            $deferred = @($verified | Where-Object Status -eq 'Deferred').Count
            $notSelected = @($verified | Where-Object Status -eq 'NotSelected').Count
            $incompatible = @($verified | Where-Object Status -eq 'Incompatible').Count
            $status = if (@($verified | Where-Object Status -eq 'Failed').Count) { 'Failed' }
                elseif (@($verified | Where-Object Status -eq 'Unverified').Count -or ($applied -and ($deferred -or $notSelected -or $incompatible))) { 'Unverified' }
                elseif ($deferred) { 'Deferred' }
                elseif ($applied) { 'Applied' }
                elseif (@($verified | Where-Object Status -eq 'Incompatible').Count) { 'Incompatible' }
                elseif (@($verified | Where-Object Status -eq 'AlreadyCompliant').Count) { 'AlreadyCompliant' }
                else { 'NotSelected' }
            return New-SkyActionResult -Status $status -Reason (($verified.Reason | Select-Object -Unique) -join ' ') -RestartRequired $restart
        }
        return New-SkyActionResult -Status Unverified -Reason 'Implementação legada sem verificação completa do estado; não contabilizada como sucesso.'
    } catch {
        $failure = $_.Exception.Message
        $partial = @($output | Where-Object { $_ -and $_.PSTypeNames -contains 'SkyOptimizer.ActionResult' })
        $restart = if (@($partial | Where-Object RestartRequired -eq 'Yes').Count) { 'Yes' } else { 'Unknown' }
        return New-SkyActionResult -Status Failed -Reason ((@($partial | ForEach-Object { $_.Reason }) + $failure) -join ' ') -RestartRequired $restart
    } finally {
        $script:SkyActionContext = $previousContext
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
        [ValidatePattern('^[a-zA-Z0-9_. -]+$')]
        [string]$BackupName
    )

    $psPath = Convert-ToPSRegPath -Path $KeyPath
    $stdPath = Convert-ToStandardRegPath -Path $KeyPath
    $backupFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "$BackupName.reg"
    $createdKeysFile = Join-Path -Path $Global:SkyBackupDir -ChildPath "created_keys.txt"

    if (Test-Path -LiteralPath $psPath -ErrorAction Stop) {
        if (-not (Test-Path -LiteralPath $backupFile -ErrorAction Stop)) {
            Write-SkyLog -Message "A criar backup de registo para '$stdPath' -> '$BackupName.reg'" -Level "Info" -NoConsole
            $temporary = "$backupFile.$([guid]::NewGuid().ToString('N')).tmp"
            try {
                $null = Invoke-SkyNativeCommand -FileName reg.exe -Arguments @('export', $stdPath, $temporary, '/y')
                if (-not [IO.File]::Exists($temporary) -or (Get-Item -LiteralPath $temporary -ErrorAction Stop).Length -eq 0) {
                    throw "Exportação sem conteúdo: $stdPath"
                }
                # Move refuses to overwrite an existing baseline, including a concurrent export.
                [IO.File]::Move($temporary, $backupFile)
                # Sincronização em tempo real para o cofre permanente de backups
                if ($Global:SkyPermBackupDir -and
                    [IO.Path]::GetFullPath($Global:SkyPermBackupDir) -ne [IO.Path]::GetFullPath($Global:SkyBackupDir)) {
                    Copy-Item -LiteralPath $backupFile -Destination $Global:SkyPermBackupDir -ErrorAction Stop
                }
            } finally {
                if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
            }
        } elseif ((Get-Item -LiteralPath $backupFile -ErrorAction Stop).Length -eq 0) {
            throw "Backup vazio existente: $backupFile. A baseline não será substituída."
        }
    } else {
        Write-SkyLog -Message "Chave '$stdPath' não existia previamente. Registada em created_keys.txt." -Level "Info" -NoConsole
        if (-not (Test-Path $createdKeysFile)) {
            New-Item -ItemType File -Path $createdKeysFile -ErrorAction Stop | Out-Null
        }
        $existing = Get-Content -LiteralPath $createdKeysFile -ErrorAction Stop
        if ($existing -notcontains $stdPath) {
            Add-Content -LiteralPath $createdKeysFile -Value $stdPath -ErrorAction Stop
        }
        if ($Global:SkyPermBackupDir -and
            [IO.Path]::GetFullPath($Global:SkyPermBackupDir) -ne [IO.Path]::GetFullPath($Global:SkyBackupDir)) {
            Copy-Item -LiteralPath $createdKeysFile -Destination $Global:SkyPermBackupDir -Force -ErrorAction Stop
        }
    }
}

function Ensure-RegistryPath {
    param([string]$KeyPath)
    $psPath = Convert-ToPSRegPath -Path $KeyPath
    if (-not (Test-Path $psPath)) {
        New-Item -Path $psPath -Force -ErrorAction Stop | Out-Null
    }
}

function Save-SkyManifest {
    $manifestPath = Join-Path -Path $Global:SkyBackupDir -ChildPath "state_backup.json"
    $json = $Global:SkyManifest | ConvertTo-Json -Depth 5
    Write-SkyAtomicFile -Path $manifestPath -Content $json
    if ($Global:SkyPermBackupDir -and
        [IO.Path]::GetFullPath($Global:SkyPermBackupDir) -ne [IO.Path]::GetFullPath($Global:SkyBackupDir)) {
        Copy-Item -LiteralPath $manifestPath -Destination $Global:SkyPermBackupDir -Force -ErrorAction Stop
    }
}

function Get-SkyAcLineStatus {
    [CmdletBinding()]
    param()
    if (-not ('SkyPowerSourceRead' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class SkyPowerSourceRead {
    [StructLayout(LayoutKind.Sequential)]
    struct Status {
        public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
        public uint BatteryLifeTime, BatteryFullLifeTime;
    }
    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool GetSystemPowerStatus(out Status status);
    public static byte ReadLineStatus() {
        Status status;
        if (!GetSystemPowerStatus(out status)) throw new Win32Exception(Marshal.GetLastWin32Error());
        return status.ACLineStatus;
    }
}
'@ -ErrorAction Stop
    }
    [SkyPowerSourceRead]::ReadLineStatus()
}

function Get-SkyPowerSource {
    # Preserve uncertainty. A failed query, malformed result or missing battery is not AC evidence.
    try { $line = Get-SkyAcLineStatus }
    catch { return 'Unknown' }
    if ($line -isnot [byte] -and $line -isnot [int]) { return 'Unknown' }
    switch ($line) {
        0 { return 'DC' }
        1 { return 'AC' }
        default { return 'Unknown' }
    }
}

function Test-IsDesktopOrAcPower {
    # Legacy name retained; only explicit AC, never a guessed desktop/chassis, is accepted.
    (Get-SkyPowerSource) -eq 'AC'
}

function Test-IsOnBattery {
    (Get-SkyPowerSource) -eq 'DC'
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
        $dg = @(Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop)
        if ($dg.Count -eq 1 -and $null -ne $dg[0].VirtualizationBasedSecurityStatus) {
            switch ($dg[0].VirtualizationBasedSecurityStatus) {
                0 { return 'Desativado' }
                1 { return 'Configurado, sem execucao' }
                2 { return 'Ativado' }
            }
        }
    } catch { return 'Desconhecido' }
    return 'Desconhecido'
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
        $powerPlan = "Desconhecido"
        try {
            $rawScheme = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/getactivescheme')
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
        Write-Host "$gpuName (primeiro adaptador reportado; GPU ativa por confirmar)" -ForegroundColor White
        Write-Host "  VRAM reportada: $vramGB GB (associacao ao adaptador/jogo por confirmar)" -ForegroundColor Gray
        Write-Host "  Memória RAM:   " -NoNewline -ForegroundColor Gray
        Write-Host "$ramGB GB" -ForegroundColor White
        Write-Host "  Primeiro disco reportado (mapeamento ao SO nao confirmado): " -NoNewline -ForegroundColor Gray
        Write-Host "$diskInfo" -ForegroundColor White
        Write-Host "  Plano Energia: " -NoNewline -ForegroundColor Gray
        $planColor = if ($powerPlan -match 'Desempenho|Ultimate|Performance') { "Green" } else { "Yellow" }
        Write-Host "$powerPlan" -ForegroundColor $planColor
        Write-Host "  Núcleo VBS:    " -NoNewline -ForegroundColor Gray
        $vbsColor = if ($vbsState -eq "Ativado") { "Yellow" } else { "Green" }
        Write-Host "$vbsState (nao certifica anti-cheat, HVCI ou desempenho)" -ForegroundColor Gray
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

    $lock = Enter-SkyPowerLock -BackupDirectory $Global:SkyBackupDir
    try {
        $state = Read-SkyPowerState -BackupDirectory $Global:SkyBackupDir
        $currentGuid = Get-SkyActivePowerGuid
        $plans = @(Get-SkyPowerGuids)
        if (-not $state -or $state.Status -eq 'Restored') {
            if (-not $state -and [IO.File]::Exists((Join-Path $Global:SkyBackupDir 'previous_power_plan.txt'))) {
                throw 'Existe uma baseline legada de energia. Rever/restaurar esse ciclo antes de criar uma nova baseline.'
            }
            $state = [pscustomobject]@{
                SchemaVersion = 1
                MachineId = Get-SkyMachineId
                OriginalGuid = $currentGuid
                OwnedGuid = [guid]::NewGuid().ToString()
                Status = 'Prepared'
                RetainedOwnedGuids = @($state.RetainedOwnedGuids | Where-Object { $_ })
            }
            if ([string]::IsNullOrWhiteSpace($state.MachineId)) { throw 'Identidade da máquina indisponível.' }
            # Persist original state and destination GUID before the first Windows mutation.
            Save-SkyPowerState -BackupDirectory $Global:SkyBackupDir -State $state
        }
        if ($plans -notcontains $state.OriginalGuid) { throw 'O plano original já não existe.' }
        if ($currentGuid -notin @($state.OriginalGuid, $state.OwnedGuid)) {
            throw 'O plano ativo foi alterado fora do SkyOptimizer; a baseline não será substituída.'
        }
        if ($state.Status -eq 'Active' -and $currentGuid -eq $state.OwnedGuid) {
            return New-SkyActionResult -Status AlreadyCompliant -Reason 'Plano Sky já ativo; baseline original preservada.' -RestartRequired No
        }
        if ($plans -notcontains $state.OwnedGuid) {
            if ($state.Status -ne 'Prepared') { throw 'O plano Sky foi removido fora do programa; executar Undo antes de reaplicar.' }
            # Clone the customer's plan, preserving OEM/CPU settings and battery policy.
            # Performance changes are explicit actions on this copy, not promises attached to a plan name.
            $null = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/duplicatescheme', $state.OriginalGuid, $state.OwnedGuid)
            if (@(Get-SkyPowerGuids) -notcontains $state.OwnedGuid) { throw 'A duplicação do plano não foi confirmada.' }
        }
        $null = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/changename', $state.OwnedGuid, 'SkyOptimizer')
        $null = Invoke-SkyNativeCommand -FileName powercfg.exe -Arguments @('/setactive', $state.OwnedGuid)
        if ((Get-SkyActivePowerGuid) -ne $state.OwnedGuid) { throw 'A ativação do plano Sky não foi confirmada.' }
        $state.Status = 'Active'
        Save-SkyPowerState -BackupDirectory $Global:SkyBackupDir -State $state
        $Global:SkyManifest.PowerPlan = $state.OriginalGuid
        return New-SkyActionResult -Status Applied -Reason 'Cópia isolada do plano original criada e ativada; baseline persistida antes da alteração.' -RestartRequired No
    } finally { $lock.Dispose() }
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

    Set-SkyAcPowerSettings -Settings @(
        [pscustomobject]@{ Subgroup = $subGroup; Setting = $settingMin; Value = 100 },
        [pscustomobject]@{ Subgroup = $subGroup; Setting = $settingMax; Value = 100 }
    )
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
    Disable-SkyService -Name 'SysMain'
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
    if (-not (Test-IsDesktopOrAcPower)) {
        return New-SkyActionResult -Status Incompatible -Reason 'AC nao confirmado: experiencia USB ignorada; nenhuma configuracao por dispositivo alterada.' -RestartRequired No
    }
    # Limit this diagnostic experiment to AC in the owned plan. Do not edit Enum\USB.
    $result = Set-SkyAcPowerSettings -Settings @(
        [pscustomobject]@{ Subgroup = '2a737441-1930-4402-8d77-b2bebba308a3'; Setting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'; Value = 0 }
    )
    $result.Reason += ' Experiencia de diagnostico: suspensao seletiva AC no plano, DC preservado. Pode aumentar consumo/temperatura. Nao prova polling, estado de portas ou input lag.'
    $result
}

function Disable-GameDVR {
    [CmdletBinding()]
    param()

    $configStore = "HKCU:\System\GameConfigStore"
    Set-SkyRegistryValue -Path $configStore -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

    $appCapture = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    Set-SkyRegistryValue -Path $appCapture -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
    Set-SkyRegistryValue -Path $appCapture -Name "HistoricalCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop

    Set-SkyRegistryValue -Path $configStore -Name "GameDVR_HistoricalCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop

    $policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    Set-SkyRegistryValue -Path $policyKey -Name "AllowGameDVR" -Value 0 -Type DWord -Force

    Write-SkyLog -Message "Configuracoes Game DVR processadas; estado por valor no resultado. Consumo de CPU/GPU e efeito nas capturas por validar." -Level "Info"
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
    New-SkyActionResult -Status Deferred -Reason (Get-SkyRetiredActionReason 12) -RestartRequired No
}

# --- CATEGORIA 4: PRIVACIDADE E TELEMETRIA ---

function Set-TelemetryBasic {
    [CmdletBinding()]
    param()

    $dataColKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"

    Set-SkyRegistryValue -Path $dataColKey -Name "AllowTelemetry" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Telemetria configurada para nível Básico/Necessário (Windows Update e Store seguros)." -Level "Success"
    return $true
}

function Disable-StartMenuSuggestions {
    [CmdletBinding()]
    param()
    New-SkyActionResult -Status Deferred -Reason (Get-SkyRetiredActionReason 14) -RestartRequired No
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
    if (-not (Test-SkyClientPolicySupport -MinimumBuild 22000)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Widgets requer Windows 11 e edicao cliente suportada pela politica; flags de Feeds/Taskbar preservadas.' -RestartRequired No
    }
    $result = Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name AllowNewsAndInterests -Type DWord -Value 0
    $result.Reason += ' Politica de Widgets configurada; TaskbarDa e Feeds intactos. Nao desinstala pacotes nem prova que processos terminaram. Perde Widgets; validar consumo efetivo e carga concorrente.'
    $result
}

# --- CATEGORIA 5: EXPLORADOR DE FICHEIROS & QOL BASE ---

function Show-FileExtensions {
    [CmdletBinding()]
    param()

    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    Set-SkyRegistryValue -Path $advKey -Name "HideFileExt" -Value 0 -Type DWord -Force

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

function Test-SkyClientPolicySupport {
    [CmdletBinding()]
    param([ValidateRange(10240,99999)][int]$MinimumBuild = 15063, [switch]$AllowHome, [switch]$EnterpriseOnly)
    $systems = @(Get-CimInstance -ClassName Win32_OperatingSystem -Property Version, BuildNumber, ProductType, OperatingSystemSKU -ErrorAction Stop)
    if ($systems.Count -ne 1) { return $false }
    $os = $systems[0]
    $build = 0
    if (-not [int]::TryParse([string]$os.BuildNumber, [ref]$build)) { return $false }
    # Conservative client matrix. Home is allowed only for an explicitly documented feature.
    if ($EnterpriseOnly -and $AllowHome) { throw 'Requisitos de edicao contraditorios.' }
    $skus = if ($EnterpriseOnly) { @(4,27,121,122,125,126) } else { @(4,27,48,49,121,122,125,126) }
    if ($AllowHome) { $skus += @(98,99,100,101) }
    return ($os.Version -match '^10\.0\.' -and $build -ge $MinimumBuild -and $os.ProductType -eq 1 -and
        $os.OperatingSystemSKU -in $skus)
}

function Test-SkyUpdatePolicySupport {
    [CmdletBinding()]
    param()
    Test-SkyClientPolicySupport -MinimumBuild 15063
}

function Block-AutomaticDriverUpdates {
    [CmdletBinding()]
    param()

    if (-not (Test-SkyUpdatePolicySupport)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Build/edicao cliente fora da matriz de politicas suportadas; nenhuma alteracao.' -RestartRequired No
    }
    $result = Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name ExcludeWUDriversInQualityUpdate -Type DWord -Value 1
    $result.Reason += ' Politica para excluir drivers das atualizacoes de qualidade; nao bloqueia instalacao manual, OEM ou todos os percursos de atualizacao. Consumo efetivo por Windows Update por validar.'
    $result
}

function Disable-DeliveryOptimizationP2P {
    [CmdletBinding()]
    param()

    if (-not (Test-SkyUpdatePolicySupport)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Build/edicao cliente fora da matriz de politicas suportadas; nenhuma alteracao.' -RestartRequired No
    }
    # HTTP-only mode already excludes peers. Leave cache limits and services untouched.
    $result = Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name DODownloadMode -Type DWord -Value 0
    $result.Reason += ' HTTP-only configurado; downloads HTTP/Connected Cache continuam permitidos. Nao garante menor ping nem limita downloads. Consumo efetivo pelo servico por validar.'
    $result
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

function Get-SkyShaderCacheFiles {
    $root = [IO.Path]::GetFullPath($env:LOCALAPPDATA)
    foreach ($relative in @('NVIDIA\DXCache', 'NVIDIA\GLCache', 'D3DSCache')) {
        $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $path.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Caminho de cache fora do âmbito.' }
        if (-not [IO.Directory]::Exists($path)) { continue }
        $cursor = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        while ($cursor) {
            if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Cache sob junction/symlink: limpeza recusada.' }
            $cursor = $cursor.Parent
        }
        Get-ChildItem -LiteralPath $path -File -Force -Attributes !ReparsePoint -ErrorAction Stop
    }
}

function Clear-ShaderCache {
    [CmdletBinding()]
    param()
    Write-Host 'Manutenção de diagnóstico: a reconstrução de shaders pode causar stuttering. Não aumenta FPS por definição.' -ForegroundColor Yellow
    $confirm = Read-Host 'Eliminar apenas caches locais NVIDIA/DirectX, sem possibilidade de Undo? (S/N)'
    if ($confirm -notmatch '^(s|sim|y|yes)$') {
        return New-SkyActionResult -Status NotSelected -Reason 'Limpeza cancelada; caches preservadas.' -RestartRequired No
    }
    # Enumerate and validate all locations before deleting anything. No recursive traversal.
    $files = @(Get-SkyShaderCacheFiles)
    $removed = 0; $failed = 0
    foreach ($file in $files) {
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            if (Test-Path -LiteralPath $file.FullName -ErrorAction Stop) { throw 'Ficheiro ainda presente.' }
            $removed++
        } catch { $failed++ }
    }
    $status = if ($failed) { 'Failed' } elseif ($removed) { 'Applied' } else { 'AlreadyCompliant' }
    New-SkyActionResult -Status $status -Reason "Limpeza de diagnóstico: $removed ficheiros removidos, $failed falhas. Reaquecer caches antes de comparar frametimes." -RestartRequired No
}


# --- CATEGORIA 8: PROCESSOS EM SEGUNDO PLANO (DEBLOAT NÃO-DESTRUTIVO) ---

function Disable-BackgroundUWPApps {
    [CmdletBinding()]
    param()
    if (-not (Test-SkyUpdatePolicySupport)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Politica de background fora da matriz cliente/build/edicao conhecida; nenhuma alteracao.' -RestartRequired No
    }
    # A per-app policy overrides this default. Preserve all package-specific exceptions.
    $result = Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name LetAppsRunInBackground -Type DWord -Value 2
    $result.Reason += ' Default de background das Windows apps configurado; excecoes por app preservadas. Pode impedir notificacoes/sincronizacao. Nao controla todos os processos Win32 nem prova FPS. Reiniciar apps para validar consumo.'
    $result
}

function Disable-SleepStudyLogging {
    [CmdletBinding()]
    param()
    New-SkyActionResult -Status Deferred -Reason 'Acao 26 bloqueada: canais de diagnostico nao tem baseline/estado efetivo migrados. AnalyzeSystem nao sera alterada pelo mecanismo de fixtures.' -RestartRequired No
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
    New-SkyActionResult -Status Deferred -Reason (Get-SkyRetiredActionReason 30) -RestartRequired No
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
    New-SkyActionResult -Status Deferred -Reason 'MMCSS bloqueado: GPU Priority/SFIO Priority nao usados e garantia antiga de Clock Rate nao justificam escritas. Hipotese de prioridades exige threads inscritas, estado efetivo e ensaios de audio/frametimes.' -RestartRequired No
}

function Enable-HAGSConditional {
    [CmdletBinding()]
    param()
    New-SkyActionResult -Status Deferred -Reason 'HAGS bloqueado: faltam detecao por adaptador/driver, contrato de configuracao e verificacao apos reinicio. VRAM e fabricante nao demonstram capacidade. HwSchMode nao foi alterado.' -RestartRequired No
}

# ==============================================================================
# 4.11 HARDWARE, REDE & PERIFÉRICOS (BAIXA LATÊNCIA)
# ==============================================================================

function Optimize-NetworkAdapterPower {
    [CmdletBinding()]
    param()
    if (-not (Test-IsDesktopOrAcPower)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Em bateria: configuração de energia de rede preservada.' -RestartRequired No
    }
    Set-SkyNicProperties -Keywords @('*EEE') -EthernetOnly
}

function Disable-UsbPowerManagement {
    [CmdletBinding()]
    param()
    New-SkyActionResult -Status Deferred -Reason 'Acao 39 retirada: escrita indiscriminada de IdleInWorkingState em hubs removida. Controlo depende do power-policy owner e do contrato do driver; nao substituido por outra flag privada.' -RestartRequired No
}

function Enable-GpuMsiMode {
    [CmdletBinding()]
    param()
    New-SkyActionResult -Status Deferred -Reason 'MSI bloqueado: fabricante nao demonstra suporte do driver nem recursos de interrupcao ativos. Sem escrita em MSISupported, DevicePriority ou MessageNumberLimit; faltam identidade, prova e recuperacao por dispositivo.' -RestartRequired No
}

# ==============================================================================
# 4.12 NAVEGADORES, JOGOS EM JANELA & ARMAZENAMENTO AVANÇADO
# ==============================================================================





function Invoke-SsdReTrim {
    [CmdletBinding()]
    param()

    try {
        $isSsd = $false
        $diskDesc = "Desconhecido"

        # 1. Verificação rigorosa do disco físico
        $physDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($physDisk) {
            $diskDesc = "$($physDisk.MediaType) ($($physDisk.BusType))"
            
            # Se for HDD mecânico ou tiver rotação física, ignorar imediatamente
            if ($physDisk.MediaType -eq "HDD" -or ($physDisk.SpindleSpeed -gt 0)) {
                Write-SkyLog -Message "Drive C: detetado como disco mecânico ($diskDesc). Re-Trim ignorado com segurança para preservar o disco." -Level "Info"
                return $false
            }
            
            # Se for explicitamente SSD ou NVMe, ou rotação 0 sem ser Unspecified duvidoso
            if ($physDisk.MediaType -eq "SSD" -or $physDisk.BusType -eq "NVMe" -or ($physDisk.SpindleSpeed -eq 0 -and $physDisk.MediaType -ne "Unspecified")) {
                $isSsd = $true
            }
        }

        # Fallback de verificação se não foi confirmado via PhysicalDisk
        if (-not $isSsd) {
            $pnp = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pnp -and $pnp.Model -match "NVMe|SSD") {
                $isSsd = $true
                $diskDesc = "$($pnp.Model)"
            }
        }

        # Se o disco for 'Unspecified (SATA)' ou não comprovadamente SSD, ignorar para evitar congelamento
        if (-not $isSsd) {
            Write-SkyLog -Message "Drive C: reportado como '$diskDesc'. Re-Trim ignorado com segurança (evita incompatibilidade ou congelamento em controladores SATA / Unspecified)." -Level "Info"
            return $false
        }

        # 2. Execução assíncrona com timeout estrito de 5 segundos contra congelamento
        Write-SkyLog -Message "A executar Re-Trim no SSD ($diskDesc)..." -Level "Info"
        $job = Start-Job -ScriptBlock {
            Optimize-Volume -DriveLetter C -ReTrim -ErrorAction Stop
        } -ErrorAction SilentlyContinue

        if ($job) {
            $completed = Wait-Job -Job $job -Timeout 5
            if ($completed) {
                $null = Receive-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                Write-SkyLog -Message "Re-Trim executado com sucesso no SSD (Drive C:) para streaming rápido de texturas sem engasgos." -Level "Success"
                return $true
            } else {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                Write-SkyLog -Message "Re-Trim cancelado por timeout (>5s) de resposta do controlador de armazenamento. A prosseguir com segurança." -Level "Warning"
                return $false
            }
        } else {
            # Se não conseguir criar o job, fallback não-bloqueante
            Write-SkyLog -Message "Não foi possível criar processo isolado para Re-Trim. Ignorado com segurança." -Level "Info"
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
    foreach ($name in @('DiagTrack', 'PcaSvc', 'TrkWks')) { Disable-SkyService -Name $name }
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
    New-SkyActionResult -Status Deferred -Reason (Get-SkyRetiredActionReason 54) -RestartRequired No
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
    New-SkyActionResult -Status Deferred -Reason 'Acao 56 bloqueada: sem allowlist de tarefas reais por definicao/build e validacao Windows. Nao se desativa manutencao/diagnostico em massa nem se remove valor privado Ubpm.' -RestartRequired No
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
    Set-SkyCloudPolicy -ActionId 58
}

function Get-SkyCloudPolicySpec {
    param([ValidateSet('58','70','84')][int]$ActionId)
    switch ($ActionId) {
        58 { [pscustomobject]@{ Id=58; MinimumBuild=17134; EnterpriseOnly=$true
            Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'
            Note='Politica de experiencias de consumidor: sugestoes/promocoes e instalacoes pos-OOBE abrangidas pelo Windows. Nao desinstala apps nem controla todas as sugestoes. Escopo de maquina; Pro nao suportado nesta matriz.' } }
        70 { [pscustomobject]@{ Id=70; MinimumBuild=16299; EnterpriseOnly=$false
            Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='AllowOnlineTips'
            Note='Apenas obtencao de dicas/ajuda online nas Definicoes. DisableSoftLanding e outras preferencias intactas.' } }
        84 { [pscustomobject]@{ Id=84; MinimumBuild=15063; EnterpriseOnly=$true
            Path='HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsSpotlightFeatures'
            Note='Politica Spotlight da conta elevada. Abrange funcionalidades relacionadas nessa conta; nao substitui a politica de consumidor HKLM para outras contas. Sem alterar flags ContentDeliveryManager ou preferencias de wallpaper.' } }
    }
}

function Set-SkyCloudPolicy {
    [CmdletBinding()]
    param([ValidateSet('58','70','84')][int]$ActionId)
    $spec=Get-SkyCloudPolicySpec $ActionId
    if (-not (Test-SkyClientPolicySupport -MinimumBuild $spec.MinimumBuild -EnterpriseOnly:$spec.EnterpriseOnly)) {
        return New-SkyActionResult -Status Incompatible -Reason "Politica $ActionId fora da matriz cliente/build/edicao documentada. Nenhuma flag alternativa foi criada." -RestartRequired No
    }
    $value=if ($ActionId -eq 70) { 0 } else { 1 }
    $result=Set-SkyRegistryValue -Path $spec.Path -Name $spec.Name -Value $value -Type DWord -OwnerActionId $ActionId
    $result.Reason += " $($spec.Note) Estado persistido nao prova consumo da politica, trafego evitado ou FPS."
    $result
}

function Enable-LongFilePaths {
    [CmdletBinding()]
    param()
    if (-not (Test-SkyClientPolicySupport -MinimumBuild 14393 -AllowHome)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Long paths requer cliente Windows 10 1607+ com identificacao conhecida; nenhuma alteracao.' -RestartRequired No
    }
    $result = Set-SkyRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Type DWord -Value 1
    $result.RestartRequired = 'Yes'
    $result.Reason += ' Compatibilidade, nao FPS: apenas APIs/apps opt-in longPathAware. Processos fazem cache; reiniciar Windows para validar todos. Nao remove limites de shell, cloud ou de todas as apps.'
    $result
}

function Disable-NetworkDmaCoalescing {
    [CmdletBinding()]
    param()
    Set-SkyNicProperties -Keywords @('*DMACoalescing') -EthernetOnly
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
    New-SkyActionResult -Status Deferred -Reason 'Acao 68 bloqueada: fabricante nao identifica tarefa/versao atual. Sem wildcard NvTm, sem politica privada NVControlPanel2; nenhuma tarefa de terceiros alterada.' -RestartRequired No
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
    Set-SkyCloudPolicy -ActionId 70
}

function Disable-SilentDiagnosticServices {
    [CmdletBinding()]
    param()
    foreach ($name in @('diagnosticshub.standardcollector.service', 'wercplsupport')) { Disable-SkyService -Name $name }
    # The per-user service template is a registry value, not a running service instance.
    if (Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc') {
        Set-SkyRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc' -Name Start -Value 4 -Type DWord
    }
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
    Set-SkyNicProperties -Keywords @('*InterruptModeration')
}

function Disable-NetworkRscAndLso {
    [CmdletBinding()]
    param()
    Set-SkyNicProperties -Keywords @('*RscIPv4', '*RscIPv6', '*LsoV2IPv4', '*LsoV2IPv6')
}

function Disable-NetworkFlowControl {
    [CmdletBinding()]
    param()
    Set-SkyNicProperties -Keywords @('*FlowControl') -EthernetOnly
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
    New-SkyActionResult -Status Unverified -Reason 'Experiência isolada: alterações TCP globais não executadas sem diagnóstico e baseline estruturada. UDP e FPS não beneficiam automaticamente destes parâmetros.' -RestartRequired No
}

# ==============================================================================
# 4.17 BATCH DE MODO DE JOGO & APRESENTAÇÃO GRÁFICA (TWEAKS 79 E 80)
# ==============================================================================

function Enable-WindowsGameMode {
    [CmdletBinding()]
    param()

    $gameBarKey = "HKCU:\SOFTWARE\Microsoft\GameBar"

    # AutoGameModeEnabled = 1 (Prioriza alocação de GPU e threads de CPU para o jogo ativo, reduzindo manutenção do SO)
    Set-SkyRegistryValue -Path $gameBarKey -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force
    Set-SkyRegistryValue -Path $gameBarKey -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force

    Write-SkyLog -Message "Configuracoes de Game Mode processadas; consumo efetivo e desempenho precisam de verificacao no jogo." -Level "Info"
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
    Set-SkyCloudPolicy -ActionId 84
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
# 4.19 BATCH DE TWEAKS DE LATÊNCIA EXTREMA & BACKGROUND (TWEAKS 86 A 90)
# ==============================================================================

function Disable-LocationAndSensors {
    [CmdletBinding()]
    param()

    # 1. Políticas de Localização e Sensores
    $locPolKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"

    Set-SkyRegistryValue -Path $locPolKey -Name "DisableLocation" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-SkyRegistryValue -Path $locPolKey -Name "DisableLocationScripting" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-SkyRegistryValue -Path $locPolKey -Name "DisableSensors" -Value 1 -Type DWord -Force -ErrorAction Stop

    # 2. Consentimento de Aplicações para Localização (Deny)
    $consentKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    Set-SkyRegistryValue -Path $consentKey -Name "Value" -Value "Deny" -Type String -Force -ErrorAction Stop

    # 3. Serviço de Geolocalização (lfsvc)
    Disable-SkyService -Name 'lfsvc'

    Write-SkyLog -Message "Politicas de localizacao/sensores e lfsvc processados; consultar os resultados por recurso. Nao foi medida atividade Wi-Fi ou desempenho." -Level "Info"
    return $true
}

function Disable-ApplicationPreLaunch {
    [CmdletBinding()]
    param()
    New-SkyActionResult -Status Deferred -Reason 'ApplicationPreLaunch bloqueado ate guardar e verificar estado MMAgent. AllowDeploymentInSpecialProfiles controla deployment em perfis especiais, nao prelaunch; nenhuma destas configuracoes foi alterada.' -RestartRequired No
}

function Disable-StorageSenseBackgroundScans {
    [CmdletBinding()]
    param()
    if (-not (Test-SkyClientPolicySupport -MinimumBuild 18362)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Politica Storage Sense requer cliente Windows 10 1903+ e edicao suportada; preferencias intactas.' -RestartRequired No
    }
    $result = Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense' -Name AllowStorageSenseGlobal -Type DWord -Value 0
    $result.Reason += ' Limpeza automatica Storage Sense bloqueada por politica; nao elimina ficheiros nem muda cadencias/preferencias. Risco de disco cheio: gerir espaco manualmente. Nao prova menos stuttering.'
    $result
}

function Disable-NetBiosOverTcpip {
    [CmdletBinding()]
    param()

    $netbtBase = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
    Ensure-RegistryPath -KeyPath $netbtBase
    Backup-RegistryKey -KeyPath $netbtBase -BackupName "89_NetBT_Interfaces"

    $interfaces = Get-ChildItem -Path $netbtBase -ErrorAction SilentlyContinue
    $configuredCount = 0

    foreach ($iface in $interfaces) {
        # NetbiosOptions: 2 = Desativar NetBIOS sobre TCP/IP (elimina broadcasts periódicos UDP portas 137/138 na LAN)
        Set-ItemProperty -Path $iface.PSPath -Name "NetbiosOptions" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        $configuredCount++
    }

    Write-SkyLog -Message "NetBIOS sobre TCP/IP desativado em $configuredCount interface(s) (elimina ruído de broadcast UDP)." -Level "Success"
    return $true
}

function Disable-CloudClipboardSync {
    [CmdletBinding()]
    param()
    if (-not (Test-SkyClientPolicySupport -MinimumBuild 17763)) {
        return New-SkyActionResult -Status Incompatible -Reason 'Politica de clipboard requer cliente Windows 10 1809+ e edicao suportada; nenhuma alteracao.' -RestartRequired No
    }
    $result = Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name AllowCrossDeviceClipboard -Type DWord -Value 0
    $result.RestartRequired = 'No'
    $result.Reason += ' Sincronizacao entre dispositivos bloqueada por politica; AllowClipboardHistory e historico existentes preservados. Preferencia de privacidade, sem ganho de FPS demonstrado.'
    $result
}

# ==============================================================================
# 4.20 GERADOR DO 'PAINEL DO CLIENTE' NO AMBIENTE DE TRABALHO
# ==============================================================================

function Assert-SkyPanelBackupDirectory {
    [CmdletBinding()]
    param([string]$ActiveDirectory, [string]$PanelDirectory)
    if ([string]::IsNullOrWhiteSpace($ActiveDirectory) -or [string]::IsNullOrWhiteSpace($PanelDirectory)) {
        throw 'A pasta central de backups deve estar definida.'
    }
    $active = [IO.Path]::GetFullPath($ActiveDirectory).TrimEnd('\', '/')
    $panel = [IO.Path]::GetFullPath($PanelDirectory).TrimEnd('\', '/')
    if (-not [string]::Equals($active, $panel, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Painel e Apply devem usar a mesma baseline central. Backups distintos nao serao copiados nem substituidos.'
    }
    if (-not [IO.Directory]::Exists($active)) { throw 'A pasta central de backups nao existe.' }
}

function Write-SkyPanelFile {
    param([string]$Path, [string]$Content, [switch]$Ascii)
    Assert-SkyNoReparsePoint $Path
    Write-SkyAtomicFile -Path $Path -Content $Content -Ascii:$Ascii
}

function Get-SkyPanelLauncher {
    param([ValidateSet('SkyRevert.ps1','SkyService.ps1')][string]$FileName,
        [ValidateSet('Spooler','bthserv')][string]$ServiceName)
    if (($FileName -eq 'SkyService.ps1') -ne [bool]$ServiceName) { throw 'Argumentos de atalho inconsistentes.' }
    $hostPath=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
    $scriptPath=Join-Path (Get-SkyStorageRoot) $FileName
    if ($scriptPath -match '[%"\r\n]') { throw 'Caminho nao representavel com seguranca no atalho CMD.' }
    $argument=if ($ServiceName) { " -Name $ServiceName" } else { '' }
    "@echo off`r`n`"$hostPath`" -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"$argument`r`nset `"SkyExit=%errorlevel%`"`r`npause`r`nexit /b %SkyExit%`r`n"
}

function Deploy-ClientPanel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ReportContent
    )

    try {
        Initialize-SkyStorage
        $permDir = Get-SkyStorageRoot
        $permBackups = Join-Path $permDir "Backups"
        Assert-SkyPanelBackupDirectory -ActiveDirectory $Global:SkyBackupDir -PanelDirectory $permBackups
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        if (-not (Test-Path $desktopPath)) {
            $desktopPath = Join-Path $env:USERPROFILE "Desktop"
        }
        $panelDir = Join-Path $desktopPath "SkyOptimizer - Painel de Controlo"
        Assert-SkyNoReparsePoint $panelDir
        if (-not (Test-Path $panelDir)) {
            New-Item -ItemType Directory -Path $panelDir -Force | Out-Null
        }

        # Apply e painel partilham a baseline central. Nao copiar backups nem apagar scripts existentes.

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
    try {
        $child = Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe') -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -Wait -PassThru -ErrorAction Stop
        if ($null -eq $child.ExitCode) { throw 'Processo elevado sem exit code.' }
        exit $child.ExitCode
    } catch { Write-Error $_; exit 1 }
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
Write-Host "    apenas quando existe uma baseline verificavel do recurso." -ForegroundColor Gray
Write-Host "    Backups legados e conflitos externos serao preservados para revisao.`n" -ForegroundColor Gray

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

# SKY_POWER_RESTORE_FUNCTIONS
try { Initialize-SkyStorage; $backupDir = $Global:SkyBackupDir }
catch { Write-Error $_; exit 1 }
$results = @(Invoke-SkyVerifiedUndo -BackupDirectory $backupDir)
foreach ($result in $results) { Write-Host "[$($result.Status)] $($result.Reason)" }
Write-Host 'Backups e painel preservados. Reinicie quando indicado; ganhos nao foram medidos.'
if (@($results | Where-Object Status -eq 'Failed').Count) { exit 1 }
if (@($results | Where-Object Status -eq 'Unverified').Count) { exit 2 }
exit 0

'@
        $revertScriptCode = $revertScriptCode.Replace('# SKY_POWER_RESTORE_FUNCTIONS', (Get-SkyPowerRestoreSource))
        Write-SkyAtomicFile -Path $revertScriptPath -Content $revertScriptCode

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
            if (Test-Path -LiteralPath $oldPath) { Remove-Item -LiteralPath $oldPath -Force -ErrorAction Stop }
        }

        # 1. Atalho Reverter Otimizações (Executa exclusivamente o motor SkyRevert.ps1)
        $undoCmd = Get-SkyPanelLauncher -FileName SkyRevert.ps1
        Write-SkyPanelFile -Path (Join-Path $panelDir "[1] Reverter Todas as Otimizacoes.cmd") -Content $undoCmd -Ascii

        Write-SkyAtomicFile -Path (Join-Path $Global:SkyPermDir 'SkyService.ps1') -Content (Get-SkyPanelServiceSource)

        # 2. Atalho Impressora
        $printerCmd = Get-SkyPanelLauncher -FileName SkyService.ps1 -ServiceName Spooler
        Write-SkyPanelFile -Path (Join-Path $panelDir "[2] Alternar Impressora (Ligar-Desligar).cmd") -Content $printerCmd -Ascii

        # 3. Atalho Bluetooth
        $btCmd = Get-SkyPanelLauncher -FileName SkyService.ps1 -ServiceName bthserv
        Write-SkyPanelFile -Path (Join-Path $panelDir "[3] Alternar Bluetooth (Ligar-Desligar).cmd") -Content $btCmd -Ascii

        # 4. Atalho Isolamento do Núcleo (VBS e Jogos)
        $vbsCmd = "@echo off`r`necho VBS: controlo suspenso nesta branch ate validar baseline, arranque e requisitos de anti-cheat.`r`necho Nenhuma configuracao foi alterada. Utilize as Definicoes do Windows.`r`npause"
        Write-SkyPanelFile -Path (Join-Path $panelDir "[4] Alternar Isolamento do Nucleo (VBS e Jogos).cmd") -Content $vbsCmd -Ascii

        # 5. Atalho Limpeza de Shaders e Caches de Jogos
        $cleanCmd = "@echo off`r`necho Limpeza automatica de shaders suspensa: reconstruir caches pode causar stuttering.`r`necho Use a limpeza de diagnostico no SkyOptimizer apenas com causa identificada.`r`npause"
        Write-SkyPanelFile -Path (Join-Path $panelDir "[5] Limpar Shaders e Caches de Jogos.cmd") -Content $cleanCmd -Ascii

        # 6. Atalho Alternar Localização e GPS
        $locCmd = "@echo off`r`necho Localizacao: use Undo para restaurar apenas a baseline gerida pelo SkyOptimizer.`r`necho Alternancia independente pendente de validacao. Nenhuma alteracao aplicada.`r`npause"
        Write-SkyPanelFile -Path (Join-Path $panelDir "[6] Alternar Localizacao e GPS (Ligar-Desligar).cmd") -Content $locCmd -Ascii

        # Relatório Antes vs. Depois
        if ($ReportContent) {
            Write-SkyPanelFile -Path (Join-Path $panelDir "Relatorio_Otimizacao.txt") -Content $ReportContent
        }

        # Ficheiro LÊ-ME (Suporte SkyOptimizer)
        $readmeTxt = @"
SkyOptimizer - painel de desenvolvimento

Esta branch ainda exige testes de integracao e benchmarks em laboratorio.
O relatorio descreve configuracoes verificadas, nao ganhos de FPS/input lag.

[1] Undo restaura apenas baselines verificaveis. Conflitos e backups antigos
    ficam preservados para revisao. Nao elimina o painel nem os backups.
[2]/[3] Impressora/Bluetooth: desativar com baseline; segundo clique restaura
    o estado original desse servico. Dependentes ativos impedem a paragem.
    Nao inventa defaults para um servico originalmente desativado.
[4] VBS: alternancia suspensa ate validar arranque e requisitos de anti-cheat.
[5] Shaders: limpeza automatica suspensa; recompilacao pode causar stuttering.
[6] Localizacao: restaurar pelo Undo geral; alternancia independente pendente.

Alteracoes NIC exigem reinicio e teste de ligacao. A confirmacao no registo
nao prova aplicacao pelo driver. Nao ha compatibilidade universal certificada.
"@
        Write-SkyPanelFile -Path (Join-Path $panelDir "LÊ-ME (Suporte SkyOptimizer).txt") -Content $readmeTxt

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
        return New-SkyActionResult -Status NotSelected -Reason 'Reparacao cancelada; nenhum comando executado.' -RestartRequired No
    }

    Write-SkyLog -Message "Início da reparação de integridade do Windows (DISM / SFC)." -Level "Info"

    Write-Host "`n[Passo 1/2] A reparar a base de componentes do Windows via DISM..." -ForegroundColor Magenta
    Write-Host "Comando: dism.exe /Online /Cleanup-Image /RestoreHealth`n" -ForegroundColor Gray
    Write-Host 'Aguarde; o resultado do comando sera mostrado quando terminar.' -ForegroundColor Gray
    try {
        $dism = Invoke-SkyNativeProcess -FileName dism.exe -Arguments @('/Online', '/Cleanup-Image', '/RestoreHealth', '/NoRestart')
        Write-Host $dism.Output
        if ($dism.ExitCode -eq 3010) {
            return New-SkyActionResult -Status Unverified -Reason 'DISM terminou com reinicio necessario (3010). SFC nao executado; reiniciar e repetir a verificacao.' -RestartRequired Yes
        }
        if ($null -eq $dism.ExitCode -or $dism.ExitCode -ne 0) { throw "DISM falhou ou nao devolveu exit code: $($dism.ExitCode). SFC nao executado." }

        Write-Host "`n[Passo 2/2] A analisar ficheiros protegidos via SFC. Aguarde pelo resultado..." -ForegroundColor Magenta
        $sfc = Invoke-SkyNativeProcess -FileName sfc.exe -Arguments @('/scannow')
        Write-Host $sfc.Output
        if ($null -eq $sfc.ExitCode -or $sfc.ExitCode -ne 0) { throw "SFC terminou com exit code nao confirmado como sucesso: $($sfc.ExitCode). Consultar output e CBS.log." }
        # SFC's localized summary/CBS evidence must be reviewed; exit 0 alone does not prove health.
        New-SkyActionResult -Status Unverified -Reason 'DISM e SFC terminaram com exit code 0. Integridade nao certificada: rever output, %windir%\Logs\CBS\CBS.log e %windir%\Logs\DISM\dism.log.' -RestartRequired Unknown
    } catch {
        New-SkyActionResult -Status Failed -Reason $_.Exception.Message -RestartRequired Unknown
    }
}

# ==============================================================================
# 5. FUNÇÃO PRINCIPAL DE OTIMIZAÇÃO (APLICAR 80 TWEAKS)
# ==============================================================================

function Invoke-SkyOptimize {
    [CmdletBinding()]
    param()
    $script:SkyLastExitCode = 1

    $experiments = if ($ExperimentalActions) { [int[]]$ExperimentalActions.Split(',') } else { @() }
    $selectedIds = @(Get-SkyProfileActionIds -Profile $Profile -Experiments $experiments)
    Write-Host "Gaming - $Profile | IDs selecionados: $($selectedIds -join ', ')" -ForegroundColor Cyan
    Write-Host 'Mudar de perfil não desfaz alterações anteriores. Para comparar perfis, executar Undo e confirmar a baseline primeiro.' -ForegroundColor Yellow
    if ($Profile -in @('Performance', 'Extreme')) {
        Write-Host 'Este perfil desativa capturas Game DVR e políticas de tarefas de browsers em fundo. Ganhos dependem da carga concorrente.' -ForegroundColor Yellow
    }

    if (@(Get-SkyLegacyBackupFiles $Global:SkyBackupDir).Count) {
        Write-SkyLog -Message 'Apply bloqueado: backups legados precisam de revisão. Não serão substituídos nem interpretados como baseline exata.' -Level Error
        return
    }

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
    Write-Host "Gaming - $Profile | IDs selecionados: $($selectedIds -join ', ')" -ForegroundColor Cyan
    Write-Host 'Experiencias exigem validacao; mudar perfil nao desfaz o anterior. NIC, energia e servicos podem alterar funcionalidades.' -ForegroundColor Yellow
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

        Checkpoint-Computer -Description "SkyOptimizer Pre-Tweak" -RestorePointType "MODIFY_SETTINGS" -WarningAction Stop -ErrorAction Stop
        Write-SkyLog -Message "Ponto de Restauro criado: 'SkyOptimizer Pre-Tweak'" -Level "Success"
        $restorePointCreated = $true
    } catch {
        $errMessage = $_.Exception.Message
        Write-SkyLog -Message "Não foi possível criar o Ponto de Restauro automaticamente. Motivo: $errMessage" -Level "Warning"
        Write-Host "`n[!] ATENÇÃO:" -ForegroundColor Yellow
        Write-Host "    O Windows pode restringir a frequência de criação de pontos de restauro" -ForegroundColor Gray
        Write-Host "    ou a funcionalidade de Proteção do Sistema pode estar desativada." -ForegroundColor Gray
        Write-Host "    Nota: O diario por recurso continua obrigatorio antes de cada alteracao; nao se criam exports .reg completos.`n" -ForegroundColor Gray

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

    # 2. Execução das 90 Otimizações
    Write-Host "`n>>> [Passo 2/3] A avaliar as 90 ações para Gaming - $Profile" -ForegroundColor Magenta
    Write-Host "Apenas ações selecionadas e migradas são executadas. Baselines por recurso em $Global:SkyBackupDir.`n" -ForegroundColor Gray

    $tweaks = @(
        # Categoria 1: Sistema e Desempenho
        [ordered]@{ Id = 1;  Category = "Sistema & Desempenho"; Name = "Plano de Energia Sky (cópia isolada do original)"; Action = { Set-UltimatePowerPlan } },
        [ordered]@{ Id = 2;  Category = "Sistema & Desempenho"; Name = "Resolução de Temporizador Global & Dynamic Tick"; Action = { Set-TimerResolution } },
        [ordered]@{ Id = 3;  Category = "Sistema & Desempenho"; Name = "Core Parking: configuração experimental em AC (DC preservado)"; Action = { Disable-CoreParking } },
        [ordered]@{ Id = 4;  Category = "Sistema & Desempenho"; Name = "Desativação de Hibernação (Libertar hiberfil.sys)"; Action = { Disable-Hibernation } },
        [ordered]@{ Id = 5;  Category = "Sistema & Desempenho"; Name = "Desativação de Fault Tolerant Heap (FTH)"; Action = { Disable-FaultTolerantHeap } },
        [ordered]@{ Id = 6;  Category = "Sistema & Desempenho"; Name = "SysMain: experiência com baseline de arranque e execução"; Action = { Disable-Superfetch } },

        # Categoria 2: Input e Gaming
        [ordered]@{ Id = 7;  Category = "Input & Gaming"; Name = "Desativação de Aceleração de Rato (1:1 Raw Input)"; Action = { Disable-MouseAcceleration } },
        [ordered]@{ Id = 8;  Category = "Input & Gaming"; Name = "USB: experiência AC no plano Sky (sem escritas por dispositivo)"; Action = { Disable-USBSelectiveSuspend } },
        [ordered]@{ Id = 9;  Category = "Input & Gaming"; Name = "Desativação de Gravação Xbox Game DVR / Game Bar"; Action = { Disable-GameDVR } },

        # Categoria 3: Otimizações de Rede
        [ordered]@{ Id = 10; Category = "Rede & Latência"; Name = "Algoritmo de Nagle (TCPNoDelay & TCPAckFrequency)"; Action = { Optimize-NetworkLatency } },
        [ordered]@{ Id = 11; Category = "Rede & Latência"; Name = "Network Throttling Index & SystemResponsiveness"; Action = { Optimize-NetworkThrottling } },
        [ordered]@{ Id = 12; Category = "Rede & Latência"; Name = "Retirada: suposta recuperacao generica de banda QoS"; Action = { Disable-QoSBandwidthLimit } },

        # Categoria 4: Privacidade e Telemetria
        [ordered]@{ Id = 13; Category = "Privacidade & Telemetria"; Name = "Telemetria no Nível Básico/Necessário (Seguro)"; Action = { Set-TelemetryBasic } },
        [ordered]@{ Id = 14; Category = "Privacidade & Telemetria"; Name = "Consolidada em 58: experiencias de consumidor (sem flags CDM)"; Action = { Disable-StartMenuSuggestions } },
        [ordered]@{ Id = 15; Category = "Privacidade & Telemetria"; Name = "Desativação de Pesquisa Web Bing e Dicas do Spotlight"; Action = { Disable-SearchAndSpotlight } },
        [ordered]@{ Id = 16; Category = "Privacidade & Telemetria"; Name = "Widgets Windows 11: politica documentada (sem flags Win10)"; Action = { Disable-TaskbarWidgets } },

        # Categoria 5: Explorador de Ficheiros
        [ordered]@{ Id = 17; Category = "Explorador & QoL"; Name = "Exibição de Extensões de Ficheiros Conhecidos"; Action = { Show-FileExtensions } },
        [ordered]@{ Id = 18; Category = "Explorador & QoL"; Name = "Desativação de Arquivamento Automático de Apps"; Action = { Disable-AppArchival } },

        # Categoria 6: Controlo Inteligente de Windows Update
        [ordered]@{ Id = 19; Category = "Controlo Windows Update"; Name = "Exclusão de drivers das atualizações de qualidade"; Action = { Block-AutomaticDriverUpdates } },
        [ordered]@{ Id = 20; Category = "Controlo Windows Update"; Name = "Delivery Optimization: HTTP-only sem peering"; Action = { Disable-DeliveryOptimizationP2P } },
        [ordered]@{ Id = 21; Category = "Controlo Windows Update"; Name = "Modo de Atualização Manual e Notificação (Sem Reinícios Forçados)"; Action = { Set-ManualWindowsUpdate } },

        # Categoria 7: Armazenamento, I/O & Limpeza de Disco
        [ordered]@{ Id = 22; Category = "Armazenamento & Limpeza"; Name = "Desativação de Armazenamento Reservado (Libertar 7GB-10GB)"; Action = { Disable-ReservedStorage } },
        [ordered]@{ Id = 23; Category = "Armazenamento & Limpeza"; Name = "Otimização de Sistema de Ficheiros NTFS (I/O Boost)"; Action = { Optimize-NTFS } },
        [ordered]@{ Id = 24; Category = "Armazenamento & Limpeza"; Name = "Manutenção de diagnóstico de shaders (confirmação explícita)"; Action = { Clear-ShaderCache } },

        # Categoria 8: Processos em Segundo Plano (Debloat)
        [ordered]@{ Id = 25; Category = "Processos em Segundo Plano"; Name = "Windows apps: política de background com exceções preservadas"; Action = { Disable-BackgroundUWPApps } },
        [ordered]@{ Id = 26; Category = "Processos em Segundo Plano"; Name = "Desativação de Registo Diagnóstico SleepStudy / Modern Standby"; Action = { Disable-SleepStudyLogging } },
        [ordered]@{ Id = 27; Category = "Processos em Segundo Plano"; Name = "Desativação de Windows Error Reporting (WER)"; Action = { Disable-WindowsErrorReporting } },

        # Categoria 9: Agilidade do Sistema & QoL
        [ordered]@{ Id = 28; Category = "Agilidade & QoL"; Name = "Eliminação de Delays de Interface e Menus (0 ms Instantâneo)"; Action = { Set-InterfaceDelays } },
        [ordered]@{ Id = 29; Category = "Agilidade & QoL"; Name = "Arranque Imediato de Aplicações Pós-Login (StartupDelay 0 ms)"; Action = { Disable-StartupDelay } },
        [ordered]@{ Id = 30; Category = "Agilidade & QoL"; Name = "Retirada: encerramento forcado com timeouts de 2 segundos"; Action = { Set-FastShutdown } },
        [ordered]@{ Id = 31; Category = "Agilidade & QoL"; Name = "Alt-Tab Limpo (Apenas Janelas Abertas, sem Separadores do Edge)"; Action = { Set-AltTabFilter } },
        [ordered]@{ Id = 32; Category = "Agilidade & QoL"; Name = "Atalho 'Terminar Tarefa' na Barra de Tarefas (Windows 11)"; Action = { Enable-TaskbarEndTask } },
        [ordered]@{ Id = 33; Category = "Agilidade & QoL"; Name = "Desativação de Processos em Fundo do Microsoft Copilot"; Action = { Disable-Copilot } },
        [ordered]@{ Id = 34; Category = "Agilidade & QoL"; Name = "Desativação de Popups de Teclas Presas (StickyKeys Shift 5x)"; Action = { Disable-StickyKeysPopup } },

        # Categoria 10: Escalonamento de CPU & Latência Gráfica (Fase 2)
        [ordered]@{ Id = 35; Category = "Escalonamento & Gráficos"; Name = "Escalonamento de CPU para Jogos (Win32PrioritySeparation 0x26)"; Action = { Set-CpuScheduling } },
        [ordered]@{ Id = 36; Category = "Escalonamento & Gráficos"; Name = "Prioridade Multimédia MMCSS para Jogos (Games Profile High)"; Action = { Set-MMCSSTasksGames } },
        [ordered]@{ Id = 37; Category = "Escalonamento & Gráficos"; Name = "HAGS: bloqueado até validar capacidade e estado por adaptador"; Action = { Enable-HAGSConditional } },

        # Categoria 11: Hardware, Rede & Periféricos (Baixa Latência)
        [ordered]@{ Id = 38; Category = "Hardware & Periféricos"; Name = "Adaptadores de Rede: Desativação de EEE / Green Ethernet (Desktop/AC)"; Action = { Optimize-NetworkAdapterPower } },
        [ordered]@{ Id = 39; Category = "Hardware & Periféricos"; Name = "Retirada: alteração indiscriminada de energia dos hubs USB"; Action = { Disable-UsbPowerManagement } },
        [ordered]@{ Id = 40; Category = "Hardware & Periféricos"; Name = "MSI: bloqueado até validar driver e interrupções por dispositivo"; Action = { Enable-GpuMsiMode } },

        # Categoria 12: Navegadores, Jogos em Janela & Armazenamento Avançado
        [ordered]@{ Id = 41; Category = "Navegadores & Janelas"; Name = "Desativação de Tarefas em Segundo Plano de Navegadores (Edge/Chrome)"; Action = { Disable-BrowserBackgroundTasks } },
        [ordered]@{ Id = 42; Category = "Navegadores & Janelas"; Name = "Apresentação em janela: experiência Windows 11 com flags alheias preservadas"; Action = { Enable-WindowedOptimizations } },
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
        [ordered]@{ Id = 54; Category = "Kernel, Memória & I/O"; Name = "Retirada: ocultacao de alertas de disco cheio"; Action = { Disable-LowDiskSpaceChecks } },
        [ordered]@{ Id = 55; Category = "Kernel, Memória & I/O"; Name = "Controlo de Falhas BSOD (Sem Reinício Instantâneo, Diagnóstico Visível)"; Action = { Set-CrashControlQuality } },

        # Categoria 16: Telemetria Silenciosa, Agendador & Caminhos Longos (Atlas Engine)
        [ordered]@{ Id = 56; Category = "Agendador & Telemetria Avançada"; Name = "Desativação de Tarefas Agendadas de Telemetria e Diagnóstico de Disco"; Action = { Disable-MaintenanceScheduledTasks } },
        [ordered]@{ Id = 57; Category = "Agendador & Telemetria Avançada"; Name = "Desativação de Histórico de Atividades e Tracing de Diagnóstico Contínuo"; Action = { Disable-ActivityHistoryAndDiagnosticTracing } },
        [ordered]@{ Id = 58; Category = "Agendador & Telemetria Avançada"; Name = "Consumer experiences: politica HKLM Enterprise/Education"; Action = { Disable-SilentAppInstallation } },
        [ordered]@{ Id = 59; Category = "Agendador & Telemetria Avançada"; Name = "Long paths: compatibilidade de apps opt-in"; Action = { Enable-LongFilePaths } },
        [ordered]@{ Id = 60; Category = "Agendador & Telemetria Avançada"; Name = "DMA Coalescing: experiência por adaptador Ethernet suportado"; Action = { Disable-NetworkDmaCoalescing } },

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
        [ordered]@{ Id = 70; Category = "Firmware & Diagnóstico"; Name = "Definicoes: impedir obtencao de dicas online"; Action = { Disable-SettingsOnlineTips } },
        [ordered]@{ Id = 71; Category = "Firmware & Diagnóstico"; Name = "Desativação de Serviços de Diagnóstico Silencioso (Hub, WerCpl, Sync)"; Action = { Disable-SilentDiagnosticServices } },
        [ordered]@{ Id = 72; Category = "Firmware & Diagnóstico"; Name = "Desativação de GameBarPresenceWriter em Fundo (Anti-Stutter no Arranque)"; Action = { Disable-GameBarPresenceWriter } },

        # Categoria 19: Rede Competitiva, Hitreg & Resposta de Movimento
        [ordered]@{ Id = 73; Category = "Competitivo: Hitreg & Movimento"; Name = "Resposta Rápida de Teclado & Strafe (Delay 0, Speed 31 Nativo)"; Action = { Optimize-KeyboardRepeatResponse } },
        [ordered]@{ Id = 74; Category = "Competitivo: Hitreg & Movimento"; Name = "Interrupt Moderation: experiência por NIC, medir CPU/DPC e latência"; Action = { Disable-NetworkInterruptModeration } },
        [ordered]@{ Id = 75; Category = "Competitivo: Hitreg & Movimento"; Name = "RSC/LSO: experiência por NIC, medir throughput e latência"; Action = { Disable-NetworkRscAndLso } },
        [ordered]@{ Id = 76; Category = "Competitivo: Hitreg & Movimento"; Name = "Flow Control: experiência Ethernet, sem promessa de eliminar bufferbloat"; Action = { Disable-NetworkFlowControl } },
        [ordered]@{ Id = 77; Category = "Competitivo: Hitreg & Movimento"; Name = "Gestão de Sockets e Portas Efémeras TCP/IP (MaxUserPort=65534, WaitDelay=30s)"; Action = { Optimize-TcpSocketsAndPorts } },
        [ordered]@{ Id = 78; Category = "Competitivo: Hitreg & Movimento"; Name = "Otimização de Pilha TCP Global (Timestamps/ECN Off, AutoTuning Normal)"; Action = { Optimize-NetshTcpGlobal } },

        # Categoria 20: Modo de Jogo & Apresentação Gráfica (FSO)
        [ordered]@{ Id = 79; Category = "Modo de Jogo & Apresentação"; Name = "Ativação do Modo de Jogo Nativo do Windows (AutoGameModeEnabled = 1)"; Action = { Enable-WindowsGameMode } },
        [ordered]@{ Id = 80; Category = "Modo de Jogo & Apresentação"; Name = "Otimização de Ecrã Inteiro e Renderização (FSEBehaviorMode = 2 / Anti-Input Lag)"; Action = { Optimize-FullscreenOptimizations } },

        # Categoria 21: Estabilidade de Frametimes & Otimizações Cirúrgicas
        [ordered]@{ Id = 81; Category = "Estabilidade & Frametimes"; Name = "Desativação de Power Throttling do Windows (Prioridade Contínua no Discord/OBS)"; Action = { Disable-PowerThrottling } },
        [ordered]@{ Id = 82; Category = "Armazenamento & I/O"; Name = "Desativação de Indexação de Ficheiros Comprimidos (.zip/mods no Windows Search)"; Action = { Disable-ZipIndexing } },
        [ordered]@{ Id = 83; Category = "Interface & Multimédia"; Name = "Otimização de Sombras do DWM e Compositor Gráfico (Sem Sombras / Texto Nítido)"; Action = { Optimize-DwmVisualEffects } },
        [ordered]@{ Id = 84; Category = "Privacidade & Telemetria"; Name = "Spotlight: politica HKCU Enterprise/Education"; Action = { Disable-WindowsSpotlightDownloads } },
        [ordered]@{ Id = 85; Category = "Explorador & QoL"; Name = "Acesso Rápido Limpo sem Histórico Contínuo no SSD (Menos Escritas)"; Action = { Optimize-QuickAccessHistory } },

        # Categoria 22: Latência Extrema & Resposta de Fundo
        [ordered]@{ Id = 86; Category = "Privacidade & Telemetria"; Name = "Desativação de Telemetria de Localização e Sensores (Serviço lfsvc Off)"; Action = { Disable-LocationAndSensors } },
        [ordered]@{ Id = 87; Category = "Processos em Segundo Plano"; Name = "Desativação de Aplicações Pré-Lançadas Especulativamente (ApplicationPreLaunch Off)"; Action = { Disable-ApplicationPreLaunch } },
        [ordered]@{ Id = 88; Category = "Armazenamento & I/O"; Name = "Storage Sense: suspender limpeza automatica por politica"; Action = { Disable-StorageSenseBackgroundScans } },
        [ordered]@{ Id = 89; Category = "Rede & Latência"; Name = "Desativação de Broadcasts Legados NetBIOS sobre TCP/IP (NetBT Off)"; Action = { Disable-NetBiosOverTcpip } },
        [ordered]@{ Id = 90; Category = "Privacidade & Telemetria"; Name = "Clipboard: impedir sync entre dispositivos, preservar historico"; Action = { Disable-CloudClipboardSync } }
    )

    $currentCategory = ""
    $totalSuccess = 0
    $totalFailed = 0
    $totalAlreadyCompliant = 0
    $totalIncompatible = 0
    $totalUnverified = 0
    $totalNotSelected = 0
    $totalDeferred = 0
    $actionResults = @()
    $failureDetails = @()

    foreach ($item in $tweaks) {
        if ($item.Category -ne $currentCategory) {
            $currentCategory = $item.Category
            Write-Host "`n--- [$currentCategory] ---" -ForegroundColor DarkCyan
        }

        Write-Host ("[*] [{0,2}/{1}] {2}" -f $item.Id, $tweaks.Count, $item.Name) -ForegroundColor White
        Write-SkyLog -Message "A iniciar: $($item.Name)" -Level "Info" -NoConsole

        $result = Invoke-SkyEligibleAction -Id $item.Id -Action $item.Action -SelectedIds $selectedIds
        $actionResults += [pscustomobject]@{
            Id = $item.Id; Name = $item.Name; Profile = $Profile; Status = $result.Status
            Reason = $result.Reason; RestartRequired = $result.RestartRequired
        }
        switch ($result.Status) {
            'Applied' {
                $totalSuccess++
                if ($Global:SkyManifest.AppliedTweaks -notcontains $item.Name) {
                    $Global:SkyManifest.AppliedTweaks += $item.Name
                }
                Write-SkyLog -Message $result.Reason -Level Success
            }
            'AlreadyCompliant' { $totalAlreadyCompliant++; Write-SkyLog -Message $result.Reason -Level Info }
            'Incompatible' { $totalIncompatible++; Write-SkyLog -Message $result.Reason -Level Warning }
            'NotSelected' { $totalNotSelected++; Write-SkyLog -Message $result.Reason -Level Info }
            'Deferred' { $totalDeferred++; Write-SkyLog -Message $result.Reason -Level Warning }
            'Unverified' { $totalUnverified++; Write-SkyLog -Message $result.Reason -Level Warning }
            'Failed' {
                $totalFailed++
                Write-SkyLog -Message "Falha em $($item.Name): $($result.Reason)" -Level Error
                $failureDetails += [pscustomobject]@{ Id = $item.Id; Name = $item.Name; Reason = $result.Reason }
            }
        }
        Write-SkyAtomicFile -Path (Join-Path $Global:SkyBackupDir 'execution_results.json') -Content (ConvertTo-Json -InputObject @($actionResults) -Depth 5)
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
                    SkyOptimizer - Snapshots de Estado (Antes vs. Depois)
================================================================================
  Data/Hora:     $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
  Computador:    $env:COMPUTERNAME
  Sistema:       $($Global:SkyManifest.OperatingSystem)
  Núcleo VBS:    $($baselineMetrics.VbsState)
--------------------------------------------------------------------------------
  Métrica                      Antes             Depois            Variação Observada
  ------------------------------------------------------------------------------
  Processos Ativos:            $($baselineMetrics.ProcessCount)               $($postMetrics.ProcessCount)               $(if ($deltaProcess -ge 0) { "-$deltaProcess processos" } else { "+$([math]::Abs($deltaProcess)) processos" })
  Memória RAM em Uso:          $([math]::Round($baselineMetrics.RamUsedMB / 1024, 2)) GB          $([math]::Round($postMetrics.RamUsedMB / 1024, 2)) GB          $([math]::Round(-$deltaRamMB / 1024, 2)) GB (depois - antes)
  Espaço Livre Disco C:        $($baselineMetrics.FreeDiskCGB) GB         $($postMetrics.FreeDiskCGB) GB         $deltaDiskGB GB (depois - antes)
  Resolução de Temporizador:   Não medida nesta execução.
  Modo de Interrupção GPU:     Não verificado nesta execução.
  FPS, frametimes/input lag:   Não medidos. Estes snapshots não demonstram ganhos em jogos.
  Ações aplicadas/verificadas: $totalSuccess
  Já conformes:               $totalAlreadyCompliant
  Incompatíveis:               $totalIncompatible
  Sem validação completa:     $totalUnverified
  Fora da selecao:            $totalNotSelected
  Migracao pendente:          $totalDeferred
  Falhas:                     $totalFailed
  Detalhe/reinício por ação:   $Global:SkyBackupDir\execution_results.json
================================================================================
  Comunidade & Suporte SkyOptimizer:
  Dúvidas ou novos setups? Dá um salto no nosso Discord:
  👉 https://discord.gg/cE8ZaDRGV5
================================================================================
"@

    $panelCreated = Deploy-ClientPanel -ReportContent $reportText
    Write-Host $reportText -ForegroundColor Cyan

    # Relatório Final de Execução
    $summaryBox = @"
================================================================================
                         RELATÓRIO DE EXECUÇÃO
================================================================================
  Total de entradas avaliadas: $($tweaks.Count)
  Perfil:                     Gaming - $Profile
  Fora da selecao:             $totalNotSelected
  Migracao pendente:           $totalDeferred
  Aplicadas e verificadas:     $totalSuccess
  Já conformes:                $totalAlreadyCompliant
  Incompatíveis:               $totalIncompatible
  Sem validação completa:      $totalUnverified
  Falhas:                      $totalFailed
  Ponto de Restauro:           $(if ($restorePointCreated) { "Criado com Sucesso" } else { "Ignorado / Restrito" })

  Painel do Cliente:           $(if ($panelCreated -eq $true) { 'Criado' } else { 'Falhou; consultar o log' })
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
    Write-Host 'Alteracoes de interface podem exigir nova sessao ou reinicio. O reinicio automatico do Explorer esta suspenso: terminava processos por nome sem limitar sessao nem verificar recuperacao.' -ForegroundColor Gray

    Write-Host "`nSessão terminada: $totalFailed falhas e $totalUnverified ações sem validação completa. Consulte o relatório antes de considerar o sistema validado." -ForegroundColor Cyan
    $script:SkyLastExitCode = if ($totalFailed -or $panelCreated -ne $true) { 1 } elseif ($totalDeferred -or $totalUnverified -or $totalIncompatible) { 2 } else { 0 }
    Read-Host "`nPressione ENTER para regressar ao menu principal..."
}

# ==============================================================================
# 6. FUNÇÃO DE REVERSÃO / UNDO (RESTAURAR ESTADO ORIGINAL)
# ==============================================================================



function Get-SkyWindowsBuild {
    [Environment]::OSVersion.Version.Build
}

function Get-SkyBrowserMajorVersion {
    param([ValidateSet('Edge', 'Chrome')][string]$Browser)
    $relative = if ($Browser -eq 'Edge') { 'Microsoft\Edge\Application\msedge.exe' } else { 'Google\Chrome\Application\chrome.exe' }
    foreach ($root in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
        if (-not $root) { continue }
        $path = Join-Path $root $relative
        if ([IO.File]::Exists($path)) { return (Get-Item -LiteralPath $path -ErrorAction Stop).VersionInfo.FileMajorPart }
    }
    return 0
}

function Disable-BrowserBackgroundTasks {
    [CmdletBinding()]
    param()
    # Machine policy is sufficient. Duplicating it in HKCU adds no performance benefit.
    $found = $false
    if ((Get-SkyBrowserMajorVersion Edge) -ge 88) {
        Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name StartupBoostEnabled -Type DWord -Value 0
        Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name BackgroundModeEnabled -Type DWord -Value 0
        $found = $true
    }
    if ((Get-SkyBrowserMajorVersion Chrome) -ge 19) {
        Set-SkyRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome' -Name BackgroundModeEnabled -Type DWord -Value 0
        $found = $true
    }
    if (-not $found) { New-SkyActionResult -Status Incompatible -Reason 'Nenhum browser suportado localizado; políticas preservadas.' -RestartRequired No }
}

function Merge-SkyGraphicsFlag {
    param([AllowEmptyString()][string]$Settings)
    $pattern = '(^|;)SwapEffectUpgradeEnable=[^;]*'
    $matches = [regex]::Matches($Settings, $pattern)
    if ($matches.Count -gt 1) { throw 'Flag gráfica duplicada: configuração ambígua preservada.' }
    if ($matches.Count -eq 1) { return [regex]::Replace($Settings, $pattern, '${1}SwapEffectUpgradeEnable=1') }
    if ($Settings -and -not $Settings.EndsWith(';')) { $Settings += ';' }
    return $Settings + 'SwapEffectUpgradeEnable=1;'
}

function Enable-WindowedOptimizations {
    [CmdletBinding()]
    param()
    if ((Get-SkyWindowsBuild) -lt 22621) {
        return New-SkyActionResult -Status Incompatible -Reason 'Esta experiência requer Windows 11 22H2 ou posterior.' -RestartRequired No
    }
    $path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $resource = ConvertTo-SkyRegistryResource $path 'DirectXUserGlobalSettings'
    $before = Get-SkyResourceState $resource
    if ($before.Exists -and $before.Kind -ne 'String') { throw 'Tipo inesperado das preferências gráficas; preservado.' }
    $value = Merge-SkyGraphicsFlag -Settings $(if ($before.Exists) { $before.Data } else { '' })
    # Leave Auto HDR, VRR and unknown flags intact. Do not impose overlapping FSE overrides.
    $result = Invoke-SkyTrackedChange -Resource $resource -Desired (ConvertTo-SkyRegistryState -Exists $true -Kind String -Value $value) -ExpectedBefore $before
    $result.Reason = 'Flag de apresentação configurada; outras flags preservadas. Reiniciar o jogo e validar apresentação/frametimes; o registo não prova consumo pelo Windows.'
    $result
}

function Get-SkyProfileActionIds {
    param([ValidateSet('Balanced', 'Performance', 'Extreme')][string]$Profile = 'Balanced', [int[]]$Experiments = @())
    # An empty pipeline in the CLI/menu arrives as null, not the default empty array.
    $Experiments = @($Experiments | Where-Object { $null -ne $_ })
    if (@($Experiments | Where-Object { $_ -lt 1 -or $_ -gt 90 }).Count) { throw 'IDs de ações devem estar entre 1 e 90.' }
    if ($Experiments.Count -and $Profile -ne 'Extreme') { throw 'Ações adicionais exigem o perfil Extreme e uma comparação de laboratório.' }
    $ids = @(79)
    if ($Profile -in @('Performance', 'Extreme')) { $ids += @(9, 41) }
    if ($Profile -eq 'Extreme') { $ids += $Experiments }
    if ($ids -contains 3 -or $ids -contains 8) { $ids += 1 }
    $ids | Sort-Object -Unique
}

function Get-SkyMigratedActionIds {
    @(1, 3, 6, 8, 9, 13, 16, 17, 19, 20, 25, 38, 41, 42, 48, 58, 59, 60, 70, 71, 74, 75, 76, 79, 84, 86, 88, 90)
}

function Get-SkyRetiredActionIds {
    # Historical IDs remain traceable; this implementation is no longer a tuning option.
    @(12, 14, 30, 39, 54)
}

function Get-SkyRetiredActionReason {
    param([int]$Id)
    switch ($Id) {
        14 { return 'Acao 14 consolidada em 58: usar a politica documentada de experiencias de consumidor quando suportada. Nao se repetem flags internas CDM nem se prometem todas as sugestoes removidas.' }
        12 { return 'Acao 12 retirada: limitar reservas QoS nao recupera uma percentagem de banda permanentemente perdida. Sem alteracao de NonBestEffortLimit.' }
        30 { return 'Acao 30 retirada: timeouts de encerramento forcado nao melhoram jogos em execucao e podem interromper trabalho por guardar. Nenhum timeout ou AutoEndTasks alterado.' }
        39 { return 'Acao 39 retirada: escritas indiscriminadas em hubs WDF nao constituem um contrato suportado. Nenhum dispositivo alterado.' }
        54 { return 'Acao 54 retirada: ocultar alertas de disco cheio nao liberta espaco nem resolve a sua causa. Nenhuma preferencia de alertas alterada.' }
        default { throw 'ID sem decisao de retirada.' }
    }
}

function Invoke-SkyEligibleAction {
    param([int]$Id, [scriptblock]$Action, [int[]]$SelectedIds = @(79))
    if ($Id -notin $SelectedIds) {
        return New-SkyActionResult -Status NotSelected -Reason 'Fora do perfil/experiência selecionado; não executada.' -RestartRequired No
    }
    if ($Id -in (Get-SkyRetiredActionIds)) {
        return New-SkyActionResult -Status Deferred -Reason (Get-SkyRetiredActionReason $Id) -RestartRequired No
    }
    if ($Id -notin (Get-SkyMigratedActionIds)) {
        return New-SkyActionResult -Status Deferred -Reason 'Não executada: migração da baseline/Undo ou compatibilidade ainda pendente.' -RestartRequired No
    }
    $minimumBuild = if ($Id -eq 59) { 14393 } else { 15063 }
    if ((Get-SkyWindowsBuild) -lt $minimumBuild) {
        return New-SkyActionResult -Status Incompatible -Reason 'Build anterior ao mínimo deste conjunto; nenhuma alteração aplicada.' -RestartRequired No
    }
    Invoke-SkyAction -Action $Action
}


function Invoke-SkyVerifiedUndo {
    param([string]$BackupDirectory)
    if (-not [IO.Directory]::Exists($BackupDirectory)) { return }
    try { Restore-SkyTrackedChanges -BackupDirectory $BackupDirectory }
    catch { New-SkyActionResult -Status Failed -Reason $_.Exception.Message }
    try { Restore-SkyPowerPlan -BackupDirectory $BackupDirectory }
    catch { New-SkyActionResult -Status Failed -Reason $_.Exception.Message }
    if (@(Get-SkyLegacyBackupFiles $BackupDirectory).Count) {
        New-SkyActionResult -Status Unverified -Reason 'Backups legados preservados. Sem prova das alterações por valor/recurso, não são importados nem substituídos por defaults.'
    }
}

function Invoke-SkyUndo {
    [CmdletBinding()]
    param()
    $script:SkyLastExitCode = 0
    if ((Get-SkyUndoScope $Global:SkyBackupDir) -eq 'None') {
        Write-SkyLog -Message 'Sem backups de alterações: nenhuma configuração será modificada.' -Level Warning
        return
    }
    $confirm = Read-Host 'Reverter apenas alterações com baseline verificável? (S/N)'
    if ($confirm -notmatch '^(s|sim|y|yes)$') { return }
    foreach ($result in @(Invoke-SkyVerifiedUndo -BackupDirectory $Global:SkyBackupDir)) {
        if ($result.Status -eq 'Failed') { $script:SkyLastExitCode = 1 }
        elseif ($result.Status -eq 'Unverified' -and $script:SkyLastExitCode -eq 0) { $script:SkyLastExitCode = 2 }
        $level = if ($result.Status -eq 'Failed') { 'Error' } else { 'Info' }
        Write-SkyLog -Message "[$($result.Status)] $($result.Reason)" -Level $level
    }
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

        Write-Host "  Capacidade Total:          $totalRamGB GB ($channelCount modulos reportados; canais ativos nao confirmados)" -ForegroundColor White
        Write-Host "  Velocidade Atual:          $currentSpeed MHz" -ForegroundColor $(if ($currentSpeed -ge $nominalSpeed -and $currentSpeed -gt 2400) { "Green" } else { "Yellow" })
        Write-Host "  Velocidade Nominal Módulo: $nominalSpeed MHz" -ForegroundColor White

        if ($currentSpeed -lt $nominalSpeed) {
            Write-Host "  [DIAGNÓSTICO TÉCNICO] RAM a $($currentSpeed) MHz (Capacidade Nominal: $($nominalSpeed) MHz)!" -ForegroundColor Yellow
            Write-Host "    -> Os valores WMI diferem; nao permitem concluir o estado de XMP/EXPO/DOCP." -ForegroundColor Cyan
            Write-Host "    -> Confirmar configuracao e estabilidade da memoria no hardware. Nenhum ganho de 1% lows foi medido." -ForegroundColor Green
        } elseif ($currentSpeed -in @(2133, 2400) -and $nominalSpeed -eq $currentSpeed) {
            Write-Host "  [INFO JEDEC] A RAM está a correr a $currentSpeed MHz (frequência base)." -ForegroundColor Gray
            Write-Host "    -> Confirmar com o cliente se as memórias suportam frequências superiores para ativar perfil na BIOS." -ForegroundColor Cyan
        } else {
            Write-Host "  [INFO] Valor configurado reportado: $currentSpeed. Perfil e estabilidade por confirmar." -ForegroundColor Green
        }
    } else {
        Write-Host "  Capacidade Total:          $totalRamGB GB" -ForegroundColor White
        Write-Host "  [INFO] Dados de modulos indisponiveis; isto nao identifica VM, chipset ou perfil de memoria." -ForegroundColor Gray
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
                Write-Host "  [OBSERVACAO] O driver reporta $hz Hz; confirmar taxa e monitor nas Definicoes." -ForegroundColor Yellow
                Write-Host "    -> Se o monitor do cliente for de 144Hz/165Hz/240Hz, ajustar nas definições do Windows (Ecrã Avançado)." -ForegroundColor Cyan
                Write-Host "    -> Confirmar se o cliente está a utilizar cabo DisplayPort (DP) adequado." -ForegroundColor Gray
            } else {
                Write-Host "  [INFO] Taxa reportada pelo driver: $hz Hz; nao mede frametimes ou latencia." -ForegroundColor Green
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
                Write-Host "    [!] $($s.Name) (entrada de arranque; consumo atual nao medido)" -ForegroundColor Yellow
            } else {
                Write-Host "    [-] $($s.Name)" -ForegroundColor Gray
            }
        }
        if ($detectedHeavy.Count -gt 0) {
            Write-Host "`n  [DIAGNÓSTICO TÉCNICO] Detetadas $($detectedHeavy.Count) entradas de arranque com nomes conhecidos; consumo por medir." -ForegroundColor Yellow
            Write-Host "    -> Recomenda-se abrir Gestor de Tarefas > Arranque e desativar com o consentimento do cliente." -ForegroundColor Cyan
            Write-Host "    -> Medir consumo real durante o jogo antes de alterar o arranque; nomes de aplicações não quantificam impacto." -ForegroundColor Gray
        } else {
            Write-Host "  [INFO] Nenhum nome da lista identificado. Outras fontes de arranque/carga nao foram excluidas." -ForegroundColor Green
        }
    } else {
        Write-Host "  [INFO] WMI nao devolveu entradas; ausencia/falha de dados nao prova um arranque sem carga." -ForegroundColor Green
    }

    # 4. Estado do Isolamento do Núcleo (VBS / HVCI)
    Write-Host "`n--- [4/4] Camada de Segurança e Jogos (Isolamento do Núcleo) ---" -ForegroundColor Yellow
    $vbsState = Get-VbsStatus
    Write-Host "  Estado observado do VBS:   $vbsState" -ForegroundColor White
    Write-Host '  Este estado não certifica HVCI, compatibilidade com anti-cheat nem ganhos de FPS.' -ForegroundColor Gray
    Write-Host '  Não são alteradas definições de segurança. O controlo VBS do painel está suspenso.' -ForegroundColor Gray

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "Inspeção Técnica de Hardware e Arranque concluída." -ForegroundColor Green
    Write-Host "Confirmar estas observacoes em laboratorio antes de propor alteracoes. Nao foram realizados benchmarks." -ForegroundColor Gray
    Write-Host "================================================================================" -ForegroundColor Cyan
    Read-Host "`nPressione ENTER para regressar ao menu principal..."
}

# ==============================================================================
# 7. MENU INTERATIVO & DESPACHO DE EXECUÇÃO
# ==============================================================================

# Se invocado com parâmetros diretos de linha de comando:
try { Initialize-SkyStorage }
catch { Write-Error "Armazenamento recusado; nenhuma acao executada: $($_.Exception.Message)"; exit 1 }

if ($Apply) {
    Invoke-SkyOptimize
    exit $script:SkyLastExitCode
}

if ($Clean) {
    Clear-Host
    $result = Clear-ShaderCache
    Write-Host "[$($result.Status)] $($result.Reason)"
    if ($result.Status -eq 'Failed') { exit 1 }
    exit 0
}

if ($Undo) {
    Invoke-SkyUndo
    exit $script:SkyLastExitCode
}

if ($DeployPanel) {
    Clear-Host
    Write-Host ">>> A gerar 'Painel do Cliente' no Ambiente de Trabalho..." -ForegroundColor Cyan
    if ((Deploy-ClientPanel) -ne $true) { Write-Error 'Falha na geração do painel.'; exit 1 }
    Write-Host "`nPainel gerado no Desktop." -ForegroundColor Green
    exit 0
}

if ($Repair) {
    $result = Repair-WindowsSystemIntegrity
    Write-Host "[$($result.Status)] $($result.Reason)"
    if ($result.Status -eq 'Failed') { exit 1 }
    if ($result.Status -eq 'Unverified') { exit 2 }
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
    Write-Host "                          Versão: 2.8.0" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Show-SystemHardwareInfo
    Write-Host "[1] Aplicar Gaming - $Profile (apenas ações selecionadas e migradas)" -ForegroundColor Green
    Write-Host "[2] Gerar 'Painel do Cliente' no Ambiente de Trabalho" -ForegroundColor Magenta
    Write-Host "[3] Inspeção do Técnico (Hardware, XMP, Hz do Ecrã & Arranque)" -ForegroundColor Yellow
    Write-Host "[4] Limpeza de Caches e Shaders" -ForegroundColor Cyan
    Write-Host "[5] Reverter alterações com baseline verificável" -ForegroundColor DarkYellow
    Write-Host "[6] Reparar Integridade do Windows (DISM / SFC)" -ForegroundColor Blue
    Write-Host "[7] Sair" -ForegroundColor Red
    Write-Host "[8] Selecionar perfil / experiências de laboratório" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Escolha uma opção (1-8)"

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
            Write-Host ">>> Limpeza de diagnóstico de shaders..." -ForegroundColor Cyan
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
            Write-Host "`nA sair do SkyOptimizer." -ForegroundColor Gray
            Start-Sleep -Seconds 1
            exit 0
        }
        "8" {
            Write-Host 'Balanced: Game Mode. Performance: acrescenta desativação de capturas e tarefas de browsers em fundo.'
            Write-Host 'Extreme: acrescenta apenas IDs escolhidos para laboratório. Alterações sem migração continuam bloqueadas.'
            Write-Host 'Nenhum perfil garante ganhos; Performance desativa funcionalidades de gravação/background.' -ForegroundColor Yellow
            $candidate = Read-Host 'Perfil (Balanced/Performance/Extreme)'
            if ($candidate -in @('Balanced', 'Performance', 'Extreme')) {
                $requested = if ($candidate -eq 'Extreme') { Read-Host 'IDs adicionais separados por vírgula (vazio = nenhum)' } else { '' }
                try {
                    if ($requested -notmatch '^(\d{1,2}(,\d{1,2})*)?$') { throw 'Lista de IDs inválida.' }
                    $ids = if ($requested) { [int[]]$requested.Split(',') } else { @() }
                    $null = Get-SkyProfileActionIds -Profile $candidate -Experiments $ids
                    $Profile = $candidate; $ExperimentalActions = $requested
                } catch { Write-Host $_.Exception.Message -ForegroundColor Red; Start-Sleep -Seconds 2 }
            }
        }
        Default {
            Write-Host "`nOpção inválida! Escolha de 1 a 8." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}






