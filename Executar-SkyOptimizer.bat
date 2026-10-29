@echo off
setlocal
title SkyOptimizer MAX
:: Elevation and exit-code propagation are handled by the PowerShell entry point.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0SkyOptimizer.ps1"
set "SkyExit=%errorlevel%"
if not "%SkyExit%"=="0" (
    echo [!] O SkyOptimizer terminou com o codigo: %SkyExit%
)
exit /b %SkyExit%
