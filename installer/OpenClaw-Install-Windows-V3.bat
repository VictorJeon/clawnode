@echo off
chcp 65001 >nul 2>&1
title OpenClaw Install V3 (Windows)
setlocal

echo.
echo  ============================================
echo  OpenClaw one-click installer (Windows, V3)
echo  ============================================
echo.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  Administrator privileges are required.
    echo  Right-click this file and run it as administrator.
    echo.
    pause
    exit /b 1
)

echo  [1/3] Checking WSL...
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  WSL is not installed. Installing it now.
    echo.
    wsl --install --no-launch
    if %errorlevel% neq 0 (
        echo  WSL install failed.
        pause
        exit /b 1
    )
    echo.
    echo  WSL install completed. Reboot Windows and run this file again.
    pause
    exit /b 0
)

echo  [2/3] Checking Ubuntu...
set "DISTRO="
for /f "tokens=*" %%i in ('wsl -l -q 2^>nul ^| findstr /i "ubuntu"') do (
    set "DISTRO=%%i"
    goto :found_distro
)

:install_ubuntu
    echo.
    echo  Ubuntu is not installed. Installing it now.
    echo.
    wsl --install -d Ubuntu --no-launch
    if %errorlevel% neq 0 (
        echo  Ubuntu install failed.
        pause
        exit /b 1
    )
    set "DISTRO=Ubuntu"
    echo.
    echo  Ubuntu install completed.
    echo  Open Ubuntu once, create the Linux username/password, then rerun this file.
    pause
    wsl -d %DISTRO%
    pause
    exit /b 0

:found_distro
for /f "tokens=* delims= " %%a in ("%DISTRO%") do set "DISTRO=%%a"
echo  Ubuntu found: %DISTRO%

wsl -d %DISTRO% bash -lc "exit 0" >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  Ubuntu first-run setup is not complete.
    echo  Open Ubuntu, create the Linux username/password, then rerun this file.
    echo.
    pause
    wsl -d %DISTRO%
    pause
    exit /b 0
)

echo  [3/3] Starting OpenClaw V3 install...
echo.

set "GIST_URL=https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup-v3-wsl.sh"
set "SCRIPT_PATH=%TEMP%\openclaw-setup-v3-wsl.sh"

echo  Downloading the V3 setup script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing $env:GIST_URL -OutFile $env:SCRIPT_PATH" >nul 2>&1
if %errorlevel% neq 0 (
    echo  Download failed.
    pause
    exit /b 1
)

set "WSL_SCRIPT_PATH="
for /f "usebackq delims=" %%p in (`wsl -d %DISTRO% wslpath -a "%SCRIPT_PATH%"`) do set "WSL_SCRIPT_PATH=%%p"
if not defined WSL_SCRIPT_PATH (
    echo  WSL path conversion failed.
    del /q "%SCRIPT_PATH%" >nul 2>&1
    pause
    exit /b 1
)

wsl -d %DISTRO% bash -lc "bash \"\$1\"; STATUS=\$?; rm -f \"\$1\"; exit \$STATUS" _ "%WSL_SCRIPT_PATH%"
set "INSTALL_EXIT=%errorlevel%"
del /q "%SCRIPT_PATH%" >nul 2>&1

if %INSTALL_EXIT% equ 0 (
    echo.
    echo  OpenClaw V3 installation completed.
) else (
    echo.
    echo  Installation failed.
    echo  Check the log in WSL: ~/.openclaw/setup-v3-*.log
)

echo.
pause
