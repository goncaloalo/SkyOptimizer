# ==============================================================================
# SkyOptimizer - 0-Common.ps1
# Funções partilhadas de Logging, Backup de Registo e Gestão de Estado
# ==============================================================================

# Definição do ficheiro de log global caso ainda não exista
if (-not $Global:SkyLogFile) {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
    $logsFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\Logs"
    if (-not (Test-Path $logsFolder)) {
        New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
    }
    $Global:SkyLogFile = Join-Path -Path $logsFolder -ChildPath "SkyOptimizer_$timestamp.log"
}

# Inicialização do diretório de backups
if (-not $Global:SkyBackupDir) {
    $backupFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\Backups"
    if (-not (Test-Path $backupFolder)) {
        New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
    }
    $Global:SkyBackupDir = (Resolve-Path $backupFolder).Path
}

# Inicialização do manifesto de estado em memória
if (-not $Global:SkyManifest) {
    $Global:SkyManifest = [ordered]@{
        Timestamp       = (Get-Date -Format "o")
        MachineName     = $env:COMPUTERNAME
        OperatingSystem = (Get-CimInstance Win32_OperatingSystem).Caption
        PowerPlan       = $null
        Hibernation     = $null
        SysMain         = $null
        DynamicTick     = $null
        AppliedTweaks   = @()
    }
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

    $timeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileLogEntry = "[$timeStr] [$($Level.ToUpper())] $Message"

    # Escrita em ficheiro de log
    try {
        if ($Global:SkyLogFile) {
            Add-Content -Path $Global:SkyLogFile -Value $fileLogEntry -ErrorAction SilentlyContinue
        }
    } catch {}

    if ($NoConsole) { return }

    # Escrita na consola com cores temáticas
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

    # Se a chave existe, exportar antes de modificar (apenas se ainda não houver backup)
    if (Test-Path $psPath) {
        if (-not (Test-Path $backupFile)) {
            Write-SkyLog -Message "A criar backup de registo para '$stdPath' -> '$BackupName.reg'" -Level "Info" -NoConsole
            $regProc = Start-Process -FilePath "reg.exe" -ArgumentList "export `"$stdPath`" `"$backupFile`" /y" -Wait -NoNewWindow -PassThru
            if ($regProc.ExitCode -ne 0) {
                Write-SkyLog -Message "Falha ao exportar registo de '$stdPath' (ExitCode: $($regProc.ExitCode))" -Level "Warning"
            }
        }
    } else {
        # Se a chave não existia previamente, registamos para que o UNDO saiba que deve eliminá-la
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

function Test-IsAdministrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentUser
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
