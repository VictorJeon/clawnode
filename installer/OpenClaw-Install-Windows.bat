@echo off
chcp 65001 >nul 2>&1
title 🦞 OpenClaw 설치 (Windows)

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
    echo  처음 실행 시 사용자 이름과 비밀번호를 설정합니다.
    echo.
    echo  1. 곧 열리는 창에서 사용자 이름을 입력하세요
    echo  2. 비밀번호를 설정하세요 (화면에 안 보이는 게 정상)
    echo  3. 설정이 끝나면 'exit' 를 입력하세요
    echo  4. 이 파일을 다시 실행하세요
    echo.
    pause
    
    wsl -d %DISTRO% echo "Ubuntu 초기화 완료"
    
    echo.
    echo  Ubuntu 설정이 끝났으면, 이 파일을 다시 실행해주세요.
    pause
    exit /b 0

:found_distro
for /f "tokens=* delims= " %%a in ("%DISTRO%") do set "DISTRO=%%a"
echo  Ubuntu 발견: %DISTRO%

:: WSL에서 OpenClaw 설치 스크립트 실행
echo  [3/3] OpenClaw 설치 시작...
echo.

set "GIST_URL=https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup-wsl.sh"

wsl -d %DISTRO% bash -c "curl -fsSL '%GIST_URL%' -o /tmp/openclaw-setup-wsl.sh && bash /tmp/openclaw-setup-wsl.sh; rm -f /tmp/openclaw-setup-wsl.sh"

if %errorlevel% equ 0 (
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
