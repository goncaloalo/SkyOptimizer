@echo off
title SkyOptimizer - Windows 10/11 Performance Toolkit
:: SkyOptimizer - Launcher Oficial AnyDesk / Suporte Remoto
:: Eleva automaticamente para Administrador (UAC) e executa o SkyOptimizer.ps1

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [SkyOptimizer] A solicitar privilegios de Administrador...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SkyOptimizer.ps1"
if %errorLevel% neq 0 (
    echo.
    echo [!] O SkyOptimizer terminou com o codigo: %errorLevel%
    pause
)
