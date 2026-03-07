@echo off
chcp 65001 >nul 2>&1
title 🦞 OpenClaw 설치 (Windows)
setlocal

echo.
echo  ============================================
echo  🦞 OpenClaw 원클릭 설치 프로그램 (Windows)
echo  ============================================
echo.

:: 관리자 권한 체크
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  ⚠️  관리자 권한이 필요합니다.
    echo  이 파일을 마우스 우클릭 → "관리자 권한으로 실행" 해주세요.
    echo.
    pause
    exit /b 1
)

:: WSL 설치 여부 확인
echo  [1/3] WSL 확인 중...
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  WSL이 설치되어 있지 않습니다. 자동 설치합니다.
    echo  (설치 후 재부팅이 필요할 수 있습니다)
    echo.
    
    wsl --install --no-launch
    if %errorlevel% neq 0 (
        echo  ❌ WSL 설치 실패!
        echo  Windows 10 버전 2004 이상이 필요합니다.
        echo  Windows Update를 먼저 실행해주세요.
        pause
        exit /b 1
    )
    
    echo.
    echo  ✅ WSL 설치 완료!
    echo  ⚠️  컴퓨터를 재부팅한 후, 이 파일을 다시 실행해주세요.
    echo.
    pause
    exit /b 0
)

:: WSL 배포판 확인 (Ubuntu 또는 Ubuntu-XX.XX)
echo  [2/3] Ubuntu 확인 중...

set "DISTRO="
for /f "tokens=*" %%i in ('wsl -l -q 2^>nul ^| findstr /i "ubuntu"') do (
    set "DISTRO=%%i"
    goto :found_distro
)

:install_ubuntu
    echo.
    echo  Ubuntu가 설치되어 있지 않습니다. 설치합니다...
    echo  (몇 분 소요될 수 있습니다)
    echo.
    
    wsl --install -d Ubuntu --no-launch
    if %errorlevel% neq 0 (
        echo  ❌ Ubuntu 설치 실패!
        pause
        exit /b 1
    )
    set "DISTRO=Ubuntu"
    
    echo.
    echo  ✅ Ubuntu 설치 완료!
    echo  이제 Ubuntu 안에서 Linux 사용자 이름과 비밀번호를 1회 설정해야 합니다.
    echo.
    echo  1. 아래에서 Enter를 누르면 Ubuntu가 현재 창에서 열립니다.
    echo  2. 사용자 이름을 입력하세요.
    echo  3. 비밀번호를 설정하세요. (화면에 안 보이는 게 정상)
    echo  4. 설정이 끝나면 'exit' 를 입력하세요.
    echo  5. 그 후 이 파일을 다시 실행하세요.
    echo.
    pause
    
    wsl -d %DISTRO%
    
    echo.
    echo  Ubuntu 설정이 끝났으면, 이 파일을 다시 실행해주세요.
    pause
    exit /b 0

:found_distro
for /f "tokens=* delims= " %%a in ("%DISTRO%") do set "DISTRO=%%a"
echo  Ubuntu 발견: %DISTRO%

wsl -d %DISTRO% bash -lc "exit 0" >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  Ubuntu 초기 설정이 아직 완료되지 않았습니다.
    echo  Linux 사용자 이름과 비밀번호를 먼저 만들어야 합니다.
    echo.
    echo  1. 아래에서 Enter를 누르면 Ubuntu가 현재 창에서 열립니다.
    echo  2. 사용자 이름을 입력하세요.
    echo  3. 비밀번호를 설정하세요. (화면에 안 보이는 게 정상)
    echo  4. 설정이 끝나면 'exit' 를 입력하세요.
    echo  5. 그 후 이 파일을 다시 실행하세요.
    echo.
    pause
    wsl -d %DISTRO%
    echo.
    echo  Ubuntu 설정이 끝났으면, 이 파일을 다시 실행해주세요.
    pause
    exit /b 0
)

:: WSL에서 OpenClaw 설치 스크립트 실행
echo  [3/3] OpenClaw 설치 시작...
echo.

set "GIST_URL=https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup-wsl.sh"
set "SCRIPT_PATH=%TEMP%\openclaw-setup-wsl.sh"

echo  설치 스크립트 다운로드 중...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing $env:GIST_URL -OutFile $env:SCRIPT_PATH" >nul 2>&1
if %errorlevel% neq 0 (
    echo  ❌ 설치 스크립트 다운로드 실패!
    echo  네트워크 연결을 확인한 뒤 다시 시도해주세요.
    pause
    exit /b 1
)

set "WSL_SCRIPT_PATH="
for /f "usebackq delims=" %%p in (`wsl -d %DISTRO% wslpath -a "%SCRIPT_PATH%"`) do set "WSL_SCRIPT_PATH=%%p"
if not defined WSL_SCRIPT_PATH (
    echo  ❌ WSL 경로 변환 실패!
    echo  Ubuntu 초기 설정이 완료되었는지 확인한 뒤 다시 실행해주세요.
    del /q "%SCRIPT_PATH%" >nul 2>&1
    pause
    exit /b 1
)

wsl -d %DISTRO% bash -lc "bash \"\$1\"; STATUS=\$?; rm -f \"\$1\"; exit \$STATUS" _ "%WSL_SCRIPT_PATH%"
set "INSTALL_EXIT=%errorlevel%"
del /q "%SCRIPT_PATH%" >nul 2>&1

if %INSTALL_EXIT% equ 0 (
    echo.
    echo  ✅ OpenClaw 설치가 완료되었습니다!
) else (
    echo.
    echo  ⚠️  설치 중 오류가 발생했습니다.
    echo  설치 로그를 담당자에게 전달해주세요.
    echo  로그 위치: WSL 내부 ~/.openclaw/setup-*.log
)

echo.
pause
