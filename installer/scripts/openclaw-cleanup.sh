#!/bin/bash
# ============================================================================
# OpenClaw Cleanup — 재설치를 위한 초기화 스크립트
#
# 사용법:
#   bash <(curl -fsSL <GIST_URL> cleanup)
#   bash openclaw-cleanup.sh
#
# 모드:
#   --soft   OpenClaw만 제거 (brew/node/git 유지) ← 기본값
#   --hard   OpenClaw + brew 패키지까지 제거 (brew 자체는 유지)
#   --full   모든 것 제거 (brew 포함, 완전 초기화)
# ============================================================================

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR ]${NC} $*"; }

MODE="${1:---soft}"

echo ""
echo "============================================"
echo "  🧹 OpenClaw Cleanup"
echo "============================================"
echo ""

case "$MODE" in
  --soft) echo "  모드: Soft (OpenClaw만 제거, brew/node 유지)" ;;
  --hard) echo "  모드: Hard (OpenClaw + brew 패키지 제거)" ;;
  --full) echo "  모드: Full (모든 것 제거)" ;;
  *)      echo "  사용법: $0 [--soft|--hard|--full]"; exit 1 ;;
esac
echo ""

read -rp "정말 진행할까요? (y/N): " CONFIRM
CONFIRM_LOWER="$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')"
if [[ "$CONFIRM_LOWER" != "y" ]]; then
  echo "취소됨."
  exit 0
fi

echo ""

# ============================================================================
# 1. Gateway 중지
# ============================================================================
if command -v openclaw &>/dev/null; then
  info "OpenClaw Gateway 중지 중..."
  openclaw gateway stop 2>/dev/null && ok "Gateway 중지됨" || warn "Gateway가 실행 중이 아님"
else
  warn "openclaw 명령어 없음 — 스킵"
fi

# ============================================================================
# 2. LaunchAgent 제거 (자동 시작 해제)
# ============================================================================
PLIST="$HOME/Library/LaunchAgents/com.openclaw.gateway.plist"
if [[ -f "$PLIST" ]]; then
  info "LaunchAgent 제거 중..."
  launchctl unload "$PLIST" 2>/dev/null
  rm -f "$PLIST"
  ok "LaunchAgent 제거됨"
fi

# ============================================================================
# 3. OpenClaw 언인스톨
# ============================================================================
if command -v npm &>/dev/null; then
  info "OpenClaw npm 패키지 제거 중..."
  npm uninstall -g openclaw 2>/dev/null && ok "openclaw 제거됨" || warn "openclaw npm 패키지 없음"

  # Claude CLI도 제거
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null && ok "claude-code 제거됨" || true
fi

# ============================================================================
# 4. OpenClaw 설정 디렉토리 제거
# ============================================================================
if [[ -d "$HOME/.openclaw" ]]; then
  info "~/.openclaw 디렉토리 제거 중..."
  rm -rf "$HOME/.openclaw"
  ok "~/.openclaw 제거됨"
fi

# config 파일
if [[ -f "$HOME/.config/openclaw/config.json" ]]; then
  rm -rf "$HOME/.config/openclaw"
  ok "~/.config/openclaw 제거됨"
fi

# ============================================================================
# 5. Hard 모드: brew 패키지 제거
# ============================================================================
if [[ "$MODE" == "--hard" || "$MODE" == "--full" ]]; then
  if command -v brew &>/dev/null; then
    info "brew 패키지 제거 중..."

    PACKAGES=(node git gh ffmpeg)
    for pkg in "${PACKAGES[@]}"; do
      if brew list "$pkg" &>/dev/null; then
        brew uninstall "$pkg" 2>/dev/null && ok "  $pkg 제거됨" || warn "  $pkg 제거 실패"
      fi
    done

    # brew cleanup
    brew cleanup 2>/dev/null
    ok "brew cleanup 완료"
  fi
fi

# ============================================================================
# 6. Full 모드: Homebrew 자체 제거
# ============================================================================
if [[ "$MODE" == "--full" ]]; then
  if command -v brew &>/dev/null; then
    info "Homebrew 제거 중..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" 2>/dev/null
    ok "Homebrew 제거됨"
  fi

  # /opt/homebrew 잔여물
  if [[ -d "/opt/homebrew" ]]; then
    sudo rm -rf /opt/homebrew 2>/dev/null && ok "/opt/homebrew 제거됨" || warn "/opt/homebrew 제거 실패 (sudo 필요)"
  fi

  # PATH에서 homebrew 제거
  if [[ -f "/etc/paths.d/homebrew" ]]; then
    sudo rm -f /etc/paths.d/homebrew 2>/dev/null
  fi
fi

# ============================================================================
# 완료
# ============================================================================
echo ""
echo "============================================"
echo "  ✅ Cleanup 완료"
echo "============================================"
echo ""

case "$MODE" in
  --soft) echo "  brew/node/git은 남아있습니다." 
          echo "  재설치: bash <(curl -fsSL <GIST_URL>)" ;;
  --hard) echo "  brew는 남아있지만 패키지는 제거됐습니다."
          echo "  재설치하면 brew install부터 다시 진행합니다." ;;
  --full) echo "  완전 초기화됐습니다. 깡통 상태입니다."
          echo "  재설치하면 Homebrew부터 다시 시작합니다." ;;
esac
echo ""

