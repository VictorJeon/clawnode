#!/bin/bash
# ============================================================================
# 🦞 OpenClaw 원클릭 설치 (macOS)
#
# 사용법: 이 파일을 더블클릭하세요.
# ============================================================================

# 터미널 타이틀
printf '\033]0;🦞 OpenClaw 설치\007'

clear
echo ""
echo "  ============================================"
echo "  🦞 OpenClaw 원클릭 설치 프로그램"
echo "  ============================================"
echo ""
echo "  최신 설치 스크립트를 다운로드합니다..."
echo ""

# --- 스크립트 다운로드 & 실행 ---
GIST_URL="https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup-v4.sh"

TMPDIR_SETUP=$(mktemp -d)
SCRIPT_PATH="$TMPDIR_SETUP/openclaw-setup-v4.sh"

if ! curl -fsSL "$GIST_URL" -o "$SCRIPT_PATH" 2>/dev/null; then
  echo ""
  echo "  ❌ 다운로드 실패!"
  echo "  인터넷 연결을 확인하고 다시 시도해주세요."
  echo ""
  echo "  아무 키나 누르면 창이 닫힙니다."
  read -n1 -s
  exit 1
fi

bash "$SCRIPT_PATH"
EXIT_CODE=$?

rm -rf "$TMPDIR_SETUP"

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "  ✅ 완료! 아무 키나 누르면 창이 닫힙니다."
else
  echo "  ⚠️  오류가 발생했습니다. (코드: $EXIT_CODE)"
  echo "  설치 로그를 담당자에게 전달해주세요."
  echo "  아무 키나 누르면 창이 닫힙니다."
fi
read -n1 -s
