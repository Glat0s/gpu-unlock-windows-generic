@echo off
title NVIDIA RTX 3000 (GA10x) ^& RTX 4000 (AD10x) UEFI Unlocker - USB Stick Creator
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0UsbCreatorGui.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] UsbCreatorGui.ps1 exited with error code %ERRORLEVEL%.
    pause
)
