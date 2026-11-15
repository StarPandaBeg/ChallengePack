@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\modcfg.ps1" -Action uninstall
if errorlevel 1 exit /b 1
if /I not "%~1"=="/q" pause
