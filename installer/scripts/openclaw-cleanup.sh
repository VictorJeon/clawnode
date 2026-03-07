#!/bin/bash
# ============================================================================
# OpenClaw Cleanup — 재설치를 위한 초기화 스크립트
#
# 사용법:
#   bash <(curl -fsSL <GIST_URL>)
#   bash openclaw-cleanup.sh [--soft|--hard|--full]
#
# 모드:
#   --soft   OpenClaw만 제거 (brew/node/git/Tailscale/Postgres 유지) ← 기본값
#   --hard   OpenClaw + Memory V2/V3 + Postgres + brew 패키지 + Tailscale 제거 (brew 자체는 유지)
#   --full   모든 것 제거 (brew 포함, 완전 깡통 초기화)
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
  --soft) echo "  모드: Soft (OpenClaw만 제거, brew/node/Tailscale/Postgres 유지)" ;;
  --hard) echo "  모드: Hard (OpenClaw + Memory/Postgres + brew 패키지 + Tailscale 제거)" ;;
  --full) echo "  모드: Full (모든 것 제거, 깡통 초기화)" ;;
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
info "OpenClaw 중지 중..."
if command -v openclaw &>/dev/null; then
  openclaw gateway stop 2>/dev/null && ok "Gateway 중지됨" || warn "Gateway가 실행 중이 아님"
else
  warn "openclaw 명령어 없음 — 스킵"
fi

# ============================================================================
# 2. SSH 터널 종료
# ============================================================================
info "원격 접속 정리 중..."

# localhost.run 터널 종료
pkill -f "localhost.run" 2>/dev/null && ok "localhost.run 터널 종료됨" || true

# ============================================================================
# 3. SSH 비활성화
# ============================================================================
if [[ "$(uname)" == "Darwin" ]]; then
  if systemsetup -getremotelogin 2>/dev/null | grep -qi "on"; then
    info "SSH(원격 로그인) 비활성화 중..."
    sudo systemsetup -setremotelogin off 2>/dev/null && ok "SSH 비활성화됨" || warn "SSH 비활성화 실패 (sudo 필요)"
  else
    ok "SSH 이미 비활성화 상태"
  fi
fi

# ============================================================================
# 4. Tailscale 로그아웃 및 제거
# ============================================================================
info "Tailscale 정리 중..."

# Tailscale 로그아웃 (Tailnet에서 이 디바이스 제거)
if command -v tailscale &>/dev/null; then
  tailscale logout 2>/dev/null && ok "Tailscale 로그아웃됨 (Tailnet에서 디바이스 제거)" || true
fi

if [[ "$MODE" == "--hard" || "$MODE" == "--full" ]]; then
  # Tailscale 앱 종료
  pkill -f "Tailscale" 2>/dev/null || true

  # Tailscale 앱 삭제
  if [[ -d "/Applications/Tailscale.app" ]]; then
    rm -rf "/Applications/Tailscale.app" 2>/dev/null && ok "Tailscale 앱 삭제됨" || warn "Tailscale 앱 삭제 실패"
  fi

  # brew cask로 설치된 경우
  if command -v brew &>/dev/null; then
    brew uninstall --cask tailscale 2>/dev/null && ok "Tailscale (brew) 제거됨" || true
  fi

  # Tailscale 설정 파일 제거
  rm -rf "$HOME/Library/Containers/io.tailscale.ipn.macos" 2>/dev/null
  rm -rf "$HOME/Library/Group Containers/"*tailscale* 2>/dev/null
  ok "Tailscale 설정 파일 제거됨"
else
  ok "Tailscale 유지 (--hard 또는 --full로 제거)"
fi

# ============================================================================
# 5. LaunchAgent 제거 (자동 시작 해제)
# ============================================================================
info "LaunchAgent 제거 중..."
PLISTS=(
  "$HOME/Library/LaunchAgents/com.openclaw.gateway.plist"
  "$HOME/Library/LaunchAgents/ai.openclaw.memory-v3-api.plist"
  "$HOME/Library/LaunchAgents/ai.openclaw.memory-v3-atomize.plist"
  "$HOME/Library/LaunchAgents/ai.openclaw.memory-v3-flush.plist"
  "$HOME/Library/LaunchAgents/ai.openclaw.memory-v3-llm-atomize.plist"
  "$HOME/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist"
  "$HOME/Library/LaunchAgents/homebrew.mxcl.postgresql@17.plist"
)

for plist in "${PLISTS[@]}"; do
  if [[ -f "$plist" ]]; then
    launchctl unload "$plist" 2>/dev/null || true
    launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
    rm -f "$plist"
    ok "  $(basename "$plist") 제거됨"
  fi
done

# ============================================================================
# 5.1 Memory / PostgreSQL 프로세스 중지
# ============================================================================
info "Memory / PostgreSQL 프로세스 정리 중..."
pkill -f "server.py" 2>/dev/null || true
pkill -f "atomize_worker.py" 2>/dev/null || true
pkill -f "llm_atomize_worker.py" 2>/dev/null || true
pkill -f "postgres -D /opt/homebrew/var/postgresql@17" 2>/dev/null || true
pkill -f "postgres -D /opt/homebrew/var/postgresql@16" 2>/dev/null || true
pkill -f "postgres -D /usr/local/var/postgresql@17" 2>/dev/null || true
pkill -f "postgres -D /usr/local/var/postgresql@16" 2>/dev/null || true

if command -v brew &>/dev/null; then
  brew services stop postgresql@17 2>/dev/null || true
  brew services stop postgresql@16 2>/dev/null || true
fi
ok "Memory / PostgreSQL 프로세스 정리 완료"

# ============================================================================
# 6. OpenClaw 언인스톨
# ============================================================================
if command -v npm &>/dev/null; then
  info "OpenClaw npm 패키지 제거 중..."
  npm uninstall -g openclaw 2>/dev/null && ok "openclaw 제거됨" || warn "openclaw npm 패키지 없음"

  # Claude CLI도 제거
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null && ok "claude-code 제거됨" || true
fi

# ============================================================================
# 7. OpenClaw 설정 디렉토리 제거
# ============================================================================
if [[ -d "$HOME/.openclaw" ]]; then
  info "~/.openclaw 디렉토리 제거 중..."
  rm -rf "$HOME/.openclaw"
  ok "~/.openclaw 제거됨"
fi

# config 파일
rm -rf "$HOME/.config/openclaw" 2>/dev/null

# Claude Code 설정도 제거
rm -rf "$HOME/.claude" 2>/dev/null && ok "~/.claude 제거됨" || true

# ============================================================================
# 8. 담당자 SSH 키 제거
# ============================================================================
if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
  if grep -q "clawnode-admin" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
    sed -i '' '/clawnode-admin/d' "$HOME/.ssh/authorized_keys" 2>/dev/null
    ok "담당자 SSH 키 제거됨"
  fi
fi

# ============================================================================
# 9. 임시 파일 제거
# ============================================================================
info "임시 파일 제거 중..."
rm -f /tmp/openclaw-tunnel.log
rm -f /tmp/openclaw-setup*.sh
rm -f /tmp/openclaw-cleanup.sh
rm -f /tmp/openclaw-memory-v3-api.log
rm -f /tmp/openclaw-memory-v3-atomize.log
rm -f /tmp/openclaw-memory-v3-flush.log
rm -f /tmp/openclaw-memory-v3-llm-atomize.log
rm -f "$HOME/.openclaw/.setup-env" 2>/dev/null
ok "임시 파일 제거됨"

# ============================================================================
# 9.1 Hard 모드: PostgreSQL 데이터/캐시 제거
# ============================================================================
if [[ "$MODE" == "--hard" || "$MODE" == "--full" ]]; then
  info "PostgreSQL 데이터 제거 중..."
  for data_dir in \
    /opt/homebrew/var/postgresql@17 \
    /opt/homebrew/var/postgresql@16 \
    /usr/local/var/postgresql@17 \
    /usr/local/var/postgresql@16
  do
    if [[ -d "$data_dir" ]]; then
      rm -rf "$data_dir" 2>/dev/null && ok "  $(basename "$data_dir") data 제거됨" || warn "  $(basename "$data_dir") data 제거 실패"
    fi
  done
  rm -rf "$HOME/Library/Application Support/Postgres" 2>/dev/null || true
fi

# ============================================================================
# 10. Hard 모드: brew 패키지 제거
# ============================================================================
if [[ "$MODE" == "--hard" || "$MODE" == "--full" ]]; then
  if command -v brew &>/dev/null; then
    info "brew 패키지 제거 중..."

    PACKAGES=(
      postgresql@17
      postgresql@16
      pgvector
      python@3.13
      python@3.12
      python@3.11
      node
      git
      gh
      ffmpeg
    )
    for pkg in "${PACKAGES[@]}"; do
      if brew list "$pkg" &>/dev/null; then
        brew uninstall "$pkg" 2>/dev/null && ok "  $pkg 제거됨" || warn "  $pkg 제거 실패"
      fi
    done

    brew cleanup 2>/dev/null
    ok "brew cleanup 완료"
  fi
fi

# ============================================================================
# 11. Full 모드: Homebrew 자체 제거
# ============================================================================
if [[ "$MODE" == "--full" ]]; then
  if command -v brew &>/dev/null; then
    info "Homebrew 제거 중..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" 2>/dev/null
    ok "Homebrew 제거됨"
  fi

  if [[ -d "/opt/homebrew" ]]; then
    sudo rm -rf /opt/homebrew 2>/dev/null && ok "/opt/homebrew 제거됨" || warn "/opt/homebrew 제거 실패 (sudo 필요)"
  fi

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
  --soft)
    echo "  제거됨: OpenClaw, Gateway, LaunchAgent, SSH터널"
    echo "  유지됨: brew, node, git, Tailscale, PostgreSQL"
    echo ""
    echo "  SSH는 비활성화됨. Tailscale은 로그아웃됨."
    echo "  재설치: bash <(curl -fsSL <GIST_URL>)"
    ;;
  --hard)
    echo "  제거됨: OpenClaw + Memory V2/V3 + PostgreSQL + brew 패키지 + Tailscale + SSH"
    echo "  유지됨: Homebrew 자체"
    echo ""
    echo "  재설치하면 brew install부터 다시 진행합니다."
    ;;
  --full)
    echo "  완전 초기화됐습니다. 깡통 상태입니다."
    echo ""
    echo "  재설치하면 Homebrew부터 다시 시작합니다."
    ;;
esac
echo ""
