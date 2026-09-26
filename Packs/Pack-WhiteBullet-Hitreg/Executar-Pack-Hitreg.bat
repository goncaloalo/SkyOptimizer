@echo off
title SkyOptimizer - Pack White Bullet & Hitreg Competitivo
:: SkyOptimizer Gaming Community - https://discord.gg/cE8ZaDRGV5
:: Elevação automática para Administrador (UAC)

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [SkyOptimizer] A solicitar privilegios de Administrador...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SkyHitreg.ps1"
