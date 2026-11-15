@echo off
setlocal
pushd "%~dp0"
if errorlevel 1 exit /b 1

python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3 is required. Install it and add it to PATH.
    goto failed
)

if not exist "..\godot\Godot_v4.1.1-stable_win64.exe" (
    echo [ERROR] Godot 4.1.1 was not found in the adjacent godot folder.
    goto failed
)

echo Building assets...
python tools\run_godot.py --path tools --script res://build_assets.gd
if errorlevel 1 goto failed

echo Packaging release...
python tools\package.py
if errorlevel 1 goto failed

echo [OK] Release archive and SHA-256 checksum are in dist.
popd
if /I not "%~1"=="/q" pause
exit /b 0

:failed
echo [ERROR] Build failed. See the output above.
popd
if /I not "%~1"=="/q" pause
exit /b 1
