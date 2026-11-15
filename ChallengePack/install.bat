@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0modcfg.ps1" -Action install
if errorlevel 1 exit /b 1
if /I not "%~1"=="/q" pause
