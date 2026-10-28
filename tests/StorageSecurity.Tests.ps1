. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

function New-SkyTestAcl {
    param([string]$Sddl='O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetSecurityDescriptorSddlForm($Sddl)
    $acl
}

Describe 'Storage trust decisions using in-memory security descriptors' {
    $trusted=@('S-1-5-18','S-1-5-32-544')
    It 'accepts administrator-owned storage and optional read-only user access' {
        { Assert-SkyStorageAcl (New-SkyTestAcl) $trusted } | Should Not Throw
        { Assert-SkyStorageAcl (New-SkyTestAcl 'O:BAG:BAD:P(A;;FA;;;BA)(A;;FR;;;BU)') $trusted } | Should Not Throw
    }
    It 'builds a protected administrator and SYSTEM descriptor without applying it to the host' {
        $acl=New-SkyStorageSecurity
        $acl.AreAccessRulesProtected | Should Be $true
        $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value | Should Be 'S-1-5-32-544'
        @($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])).Count | Should Be 2
        { Assert-SkyStorageAcl $acl $trusted } | Should Not Throw
    }
    It 'allows parent child-creation but refuses parent permissions that permit replacing protected storage' {
        { Assert-SkyStorageAcl (New-SkyTestAcl 'O:SYG:SYD:P(A;;FA;;;SY)(A;;FW;;;BU)') $trusted -ParentDirectory } | Should Not Throw
        { Assert-SkyStorageAcl (New-SkyTestAcl 'O:SYG:SYD:P(A;;FA;;;SY)(A;;0x40;;;BU)') $trusted -ParentDirectory } | Should Throw
    }
    It 'rejects untrusted ownership even with a restrictive DACL' {
        { Assert-SkyStorageAcl (New-SkyTestAcl 'O:BUG:BAD:P(A;;FA;;;BA)') $trusted } | Should Throw
    }
    It 'rejects write, delete-child and permission takeover grants independently' {
        foreach ($right in @('FW','0x40','WD','WO','SD')) {
            { Assert-SkyStorageAcl (New-SkyTestAcl ('O:BAG:BAD:P(A;;FA;;;BA)(A;;'+$right+';;;BU)')) $trusted } | Should Throw
        }
    }
    It 'rejects a null DACL and does not treat deny rules as a reason to accept broad allow rules' {
        { Assert-SkyStorageAcl (New-SkyTestAcl 'O:BAG:BAD:NO_ACCESS_CONTROL') $trusted } | Should Throw
        { Assert-SkyStorageAcl (New-SkyTestAcl 'O:BAG:BAD:P(D;;FW;;;BU)(A;;FA;;;BA)(A;;FW;;;BU)') $trusted } | Should Throw
    }
}

Describe 'Storage initialization with mocked ACL and creation adapters' {
    BeforeEach {
        $script:root=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:unsafe=$false
    }
    Mock Get-SkyStorageRoot { $script:root }
    Mock Get-SkyStorageTrustedSids { @('S-1-5-18','S-1-5-32-544') }
    Mock Get-Acl {
        if ($script:unsafe -and $LiteralPath -like '*tampered.json') { New-SkyTestAcl 'O:BUG:BAD:P(A;;FA;;;BA)' }
        else { New-SkyTestAcl }
    }
    # Only temporary directories are created. No real DACL or host directory is changed.
    Mock New-SkyProtectedDirectory { $null=[IO.Directory]::CreateDirectory($Path) }
    It 'creates only the dedicated root, backup and log directories and is repeatable' {
        Initialize-SkyStorage
        Initialize-SkyStorage
        $Global:SkyBackupDir | Should Be (Join-Path $script:root 'Backups')
        Assert-MockCalled New-SkyProtectedDirectory -Times 3 -Exactly -Scope It
    }
    It 'refuses unsafe existing evidence before creating or replacing anything' {
        $null=[IO.Directory]::CreateDirectory($script:root)
        $path=Join-Path $script:root 'tampered.json'
        [IO.File]::WriteAllText($path,'preserve evidence')
        $script:unsafe=$true
        { Initialize-SkyStorage } | Should Throw
        [IO.File]::ReadAllText($path) | Should Be 'preserve evidence'
        Assert-MockCalled New-SkyProtectedDirectory -Times 0 -Exactly -Scope It
    }
    It 'uses atomic ASCII panel files without a BOM or truncating the existing content on failure' {
        $path=Join-Path $TestDrive 'fixture.cmd'
        Write-SkyPanelFile $path '@echo off' -Ascii
        [IO.File]::ReadAllBytes($path)[0] | Should Be 64
        $held=[IO.File]::Open($path,'Open','Read','Read')
        try { { Write-SkyPanelFile $path 'replacement' -Ascii } | Should Throw }
        finally { $held.Dispose() }
        [IO.File]::ReadAllText($path) | Should Be '@echo off'
    }
    It 'generates fixed executable launchers with child exit status and no CMD elevation command' {
        $cmd=Get-SkyPanelLauncher SkyService.ps1 Spooler
        $cmd.Contains('WindowsPowerShell\v1.0\powershell.exe') | Should Be $true
        $cmd.Contains('-Name Spooler') | Should Be $true
        $cmd.Contains('exit /b %SkyExit%') | Should Be $true
        $cmd.Contains('Start-Process cmd') | Should Be $false
        { Get-SkyPanelLauncher SkyRevert.ps1 Spooler } | Should Throw
    }
}

Describe 'Path redirection guard without real junctions or links' {
    Mock Test-Path { $true }
    Mock Get-Item {
        [pscustomobject]@{Attributes=$(if ($LiteralPath -eq 'C:\SkyTest\link') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Directory })}
    }
    It 'rejects an ancestor junction before writing a panel file' {
        Mock Write-SkyAtomicFile { throw 'Writer must not be reached.' }
        { Write-SkyPanelFile 'C:\SkyTest\link\target.cmd' 'payload' -Ascii } | Should Throw
        Assert-MockCalled Write-SkyAtomicFile -Times 0 -Exactly -Scope It
    }
}

Describe 'Generated recovery includes the storage boundary' {
    It 'embeds and invokes storage validation in the service panel' {
        $source=Get-SkyPanelServiceSource
        $tokens=$null; $errors=$null
        $null=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
        $errors.Count | Should Be 0
        $source.Contains('function Assert-SkyStorageAcl') | Should Be $true
        $source.Contains("Initialize-SkyStorage`r`n") -or $source.Contains("Initialize-SkyStorage`n") | Should Be $true
        $source.Contains('-Wait -PassThru') | Should Be $true
        $source.Contains('$session = Enter-SkySessionLock') | Should Be $true
    }
    It 'excludes a second app or panel session and permits recovery after the handle closes' {
        $held=Enter-SkySessionLock $TestDrive
        try { { Enter-SkySessionLock $TestDrive } | Should Throw }
        finally { $held.Dispose() }
        $retry=Enter-SkySessionLock $TestDrive
        $retry.Dispose()
        [IO.File]::Exists((Join-Path $TestDrive 'session.lock')) | Should Be $true
    }
}
