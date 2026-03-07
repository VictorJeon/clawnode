#!/bin/bash
set -uo pipefail
# ============================================================================
# OpenClaw Quick Setup v2 — 비개발자용 원클릭 세팅
#
# 사용법:
#   bash <(curl -fsSL <GIST_URL>)     ← 권장 (stdin 분리)
#   bash openclaw-setup.sh            ← 로컬 실행
#
# 멱등성: 이미 완료된 단계는 자동 스킵. 실패 후 재실행 안전.
#
# 사전 조건:
#   1. AI 모델 준비 (Claude Pro, ChatGPT Plus, 또는 API 키)
#   2. Telegram 봇 토큰 (@BotFather)
# ============================================================================

# --- Dry-run 모드 (색상/함수보다 먼저 설정) ---
DRY_RUN="${DRY_RUN:-0}"

# curl | bash 차단 방지 (DRY_RUN에서는 스킵)
if [[ "$DRY_RUN" != "1" ]]; then
  if [[ ! -t 0 ]] && [[ "${BASH_SOURCE[0]}" == "" || "${BASH_SOURCE[0]}" == "-" ]]; then
    echo "[ERR] curl | bash 대신 다음 형태로 실행하세요: bash <(curl -fsSL URL)"
    exit 1
  fi

  # stdin이 파이프면 tty로 전환
  if [[ ! -t 0 ]]; then
    exec < /dev/tty || { echo "[ERR] 대화형 입력 불가 — bash <(curl ...) 형태로 실행하세요."; exit 1; }
  fi
fi

# macOS 전용 가드
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERR] 이 스크립트는 macOS 전용입니다."
  exit 1
fi

# --- 설치 로그 자동 생성 ---
LOG_DIR="$HOME/.openclaw"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
if [[ "$DRY_RUN" != "1" ]]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "# OpenClaw Setup Log — $(date)"
  echo "# OS: $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
  echo "# User: $(whoami)"
  echo "---"
fi

# --- 비정상 종료 시 민감 파일 정리 (INT/TERM만 — 정상 종료는 스크립트 끝에서 처리) ---
cleanup_secrets() {
  rm -f "$HOME/.openclaw/.setup-env"
  echo ""
  warn "중단됨 — 민감 파일(.setup-env)을 삭제했습니다."
}
trap cleanup_secrets INT TERM

dry() {
  if [[ "$DRY_RUN" == "1" ]]; then
    ok "[DRY] $*"
    return 0
  fi
  "$@"
}

# --- 색상 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR ]${NC} $*"; }

FAILED=0
fail() { err "$*"; FAILED=$((FAILED + 1)); }

# --- 설정 ---
CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE="$CONFIG_DIR/workspace"
SETUP_ENV="$CONFIG_DIR/.setup-env"

# ============================================================================
# 0. 입력 수집 — 이전 입력값이 있으면 재사용
# ============================================================================

echo ""
echo "============================================"
echo "  🦞 OpenClaw 비개발자 퀵 셋업 v2"
echo "        by Yongwon Jeon"
echo "============================================"
echo ""

# 이전 입력값 로드
if [[ -f "$SETUP_ENV" ]]; then
  d64() { echo "$1" | base64 -d 2>/dev/null || echo "$1"; }
  while IFS='=' read -r key value; do
    case "$key" in
      USER_NAME)     USER_NAME="$(d64 "$value")" ;;
      TG_BOT_TOKEN)  TG_BOT_TOKEN="$(d64 "$value")" ;;
      CHAT_ID)       CHAT_ID="$(d64 "$value")" ;;
      MODEL_CHOICE)  MODEL_CHOICE="$(d64 "$value")" ;;
      API_KEY)       API_KEY="$(d64 "$value")" ;;
      AUTH_MODE)     AUTH_MODE="$(d64 "$value")" ;;
    esac
  done < "$SETUP_ENV"

  if [[ -n "${USER_NAME:-}" ]]; then
    info "이전 설정값 발견 — 재사용합니다."
    echo "  이름: ${USER_NAME:-}"
    echo "  Chat ID: ${CHAT_ID:-}"
    echo "  모델 선택: ${MODEL_CHOICE:-}"
    echo ""
    read -rp "이 설정으로 계속할까요? (Y/n): " REUSE
    if [[ "${REUSE,,}" == "n" ]]; then
      unset USER_NAME TG_BOT_TOKEN CHAT_ID MODEL_CHOICE API_KEY AUTH_MODE
    fi
  fi
fi

# 1. 사용자 이름
if [[ -z "${USER_NAME:-}" ]]; then
  read -rp "사용자 이름 (예: Mason): " USER_NAME
  [[ -z "$USER_NAME" ]] && { err "이름 필수"; exit 1; }
fi

# 2. Telegram 봇 토큰
if [[ -z "${TG_BOT_TOKEN:-}" ]]; then
  read -rp "Telegram 봇 토큰 (BotFather): " TG_BOT_TOKEN
  [[ -z "$TG_BOT_TOKEN" ]] && { err "봇 토큰 필수"; exit 1; }
fi

# 3. Chat ID 자동 감지
if [[ -z "${CHAT_ID:-}" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    CHAT_ID="123456789"
    ok "[DRY] Chat ID 자동 설정: $CHAT_ID"
  else
    echo ""
    info "Chat ID 자동 감지 중... 봇에게 아무 메시지나 보내주세요."
    echo "  (이미 /start를 보냈다면 자동으로 잡힙니다)"
    echo ""

    MAX_WAIT=60
    CHAT_ID=""
    for i in $(seq 1 $MAX_WAIT); do
      RESULT=$(curl -s "https://api.telegram.org/bot${TG_BOT_TOKEN}/getUpdates?limit=1&offset=-1" 2>/dev/null)
      CHAT_ID=$(echo "$RESULT" | grep -o '"chat":{"id":-\?[0-9]*' | head -1 | grep -o -- '-\?[0-9]*$')
      if [[ -n "$CHAT_ID" ]]; then
        break
      fi
      printf "\r  대기 중... %ds" "$i"
      sleep 1
    done
    echo ""

    if [[ -z "$CHAT_ID" ]]; then
      warn "Chat ID 감지 실패. 수동 입력:"
      read -rp "Telegram Chat ID: " CHAT_ID
    fi
  fi
fi
ok "Chat ID: $CHAT_ID"

# 4. AI 모델 선택
if [[ -z "${MODEL_CHOICE:-}" ]]; then
  echo ""
  echo "사용할 AI 모델을 선택하세요:"
  echo "  1) Claude Pro/Max (구독형)  ⭐ 추천 — 가장 똑똑함"
  echo "  2) Claude (API Key)         — console.anthropic.com에서 발급"
  echo "  3) ChatGPT Plus (구독형)    — OAuth 로그인 필요"
  echo "  4) ChatGPT (API Key)        — 개발자용"
  echo "  5) Gemini (API Key)         — 무료 티어 가능"
  echo "  6) 기타 (직접 설정)"
  
  while true; do
    read -rp "선택 (1-6): " MODEL_CHOICE
    [[ "$MODEL_CHOICE" =~ ^[1-6]$ ]] && break
  done

  # 추가 정보 수집
  case "$MODEL_CHOICE" in
    1) # Claude Subscription
       AUTH_MODE="setup-token"
       echo ""
       echo "  설치 과정에서 Claude setup-token 입력 화면이 나옵니다."
       echo "  아직 토큰이 없다면, 그때 발급 안내를 따라주세요."
       API_KEY=""
       ;;
    2) # Claude API
       AUTH_MODE="anthropic-key"
       read -rsp "Anthropic API Key 입력: " API_KEY
       echo ""
       ;;
    3) # ChatGPT OAuth
       AUTH_MODE="openai-oauth"
       echo "  * 설치 중 브라우저가 열리면 로그인 후 코드를 복사해주세요."
       ;;
    4) # ChatGPT API
       AUTH_MODE="openai-key"
       read -rsp "OpenAI API Key 입력: " API_KEY
       echo ""
       ;;
    5) # Gemini API
       AUTH_MODE="gemini-key"
       read -rsp "Gemini API Key 입력: " API_KEY
       echo ""
       ;;
    6) # Custom
       AUTH_MODE="custom"
       ;;
  esac
fi

# 설정 저장
mkdir -p "$CONFIG_DIR"
# base64 인코딩으로 특수문자/한글 안전 저장
b64() { printf '%s' "$1" | base64; }
{
  echo "USER_NAME=$(b64 "$USER_NAME")"
  echo "TG_BOT_TOKEN=$(b64 "$TG_BOT_TOKEN")"
  echo "CHAT_ID=$(b64 "$CHAT_ID")"
  echo "MODEL_CHOICE=$(b64 "$MODEL_CHOICE")"
  echo "AUTH_MODE=$(b64 "${AUTH_MODE:-}")"
  echo "API_KEY=$(b64 "${API_KEY:-}")"
} > "$SETUP_ENV"
chmod 600 "$SETUP_ENV"

# ============================================================================
# Step 1: 기본 도구 (Brew, Node, Git)
# ============================================================================
echo ""
info "Step 1/6: 기본 도구 설치"

# Homebrew
if ! command -v brew &>/dev/null; then
  info "Homebrew 설치 중..."
  dry bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' || fail "Brew 설치 실패"
  if [[ -f /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [[ -f /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
else
  ok "Homebrew 확인됨"
fi

# Node.js (22+ 필요)
if command -v node &>/dev/null; then
  NODE_VER=$(node --version)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
  if [[ "$NODE_MAJOR" -ge 22 ]]; then
    ok "Node.js $NODE_VER 확인됨"
  else
    warn "Node.js $NODE_VER → 22+ 필요. 업그레이드 중..."
    dry brew install node || fail "Node.js 업그레이드 실패"
  fi
else
  info "Node.js 설치 중..."
  dry brew install node || fail "Node.js 설치 실패"
fi

# Git
if ! command -v git &>/dev/null; then
  dry brew install git || fail "Git 설치 실패"
fi

# ============================================================================
# Step 2: OpenClaw 설치
# ============================================================================
echo ""
info "Step 2/6: OpenClaw 설치"

if ! command -v openclaw &>/dev/null; then
  dry npm install -g openclaw || fail "OpenClaw 설치 실패"
else
  ok "OpenClaw $(openclaw --version) 확인됨"
fi

# ============================================================================
# Step 3: 인증 및 온보딩 (모델별 분기)
# ============================================================================
echo ""
info "Step 3/6: AI 모델 연결 및 Gateway 설정"

# 이미 인증된 경우 스킵 체크 (생략 - 덮어쓰기 로직으로 간소화)

case "$AUTH_MODE" in
  "setup-token")
    # setup-token은 interactive-only (non-interactive 불가)
    echo "  * Claude setup-token 입력을 요청합니다."
    if [[ -n "${API_KEY:-}" ]]; then
      echo "  (사전 입력된 토큰이 있으면 붙여넣기 하세요)"
    fi
    dry openclaw onboard --auth-choice setup-token \
      --gateway-port 18789 --gateway-bind loopback \
      --install-daemon --daemon-runtime node \
      --skip-channels --skip-skills \
      --accept-risk
    ;;
  "anthropic-key")
    dry openclaw onboard --non-interactive \
      --auth-choice apiKey \
      --anthropic-api-key "$API_KEY" \
      --gateway-port 18789 --gateway-bind loopback \
      --install-daemon --daemon-runtime node \
      --skip-channels --skip-skills \
      --accept-risk
    ;;
  "openai-oauth")
    echo ""
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │  ChatGPT 로그인 안내                      │"
    echo "  │                                           │"
    echo "  │  1. 곧 브라우저가 열립니다                  │"
    echo "  │  2. ChatGPT 계정으로 로그인하세요           │"
    echo "  │  3. 나오는 코드를 복사하세요                │"
    echo "  │  4. 이 터미널에 붙여넣기 하세요             │"
    echo "  └─────────────────────────────────────────┘"
    echo ""
    read -rp "  준비되셨으면 Enter를 눌러주세요..."
    dry openclaw onboard --auth-choice openai-codex \
      --gateway-port 18789 --gateway-bind loopback \
      --install-daemon --daemon-runtime node \
      --skip-channels --skip-skills \
      --accept-risk
    ;;
  "openai-key")
    dry openclaw onboard --non-interactive \
      --auth-choice openai-api-key \
      --openai-api-key "$API_KEY" \
      --gateway-port 18789 --gateway-bind loopback \
      --install-daemon --daemon-runtime node \
      --skip-channels --skip-skills \
      --accept-risk
    ;;
  "gemini-key")
    dry openclaw onboard --non-interactive \
      --auth-choice gemini-api-key \
      --gemini-api-key "$API_KEY" \
      --gateway-port 18789 --gateway-bind loopback \
      --install-daemon --daemon-runtime node \
      --skip-channels --skip-skills \
      --accept-risk
    ;;
  *)
    echo "  * 사용자 정의 설정 모드 (대화형)"
    dry openclaw onboard --flow manual \
      --skip-channels --skip-skills
    ;;
esac

if [[ $? -eq 0 ]]; then
  ok "OpenClaw Onboard 완료"
else
  fail "Onboard 과정에서 오류 발생"
fi

# ============================================================================
# Step 4: Telegram 채널 설정 (수동 패치)
# ============================================================================
echo ""
info "Step 4/6: Telegram 채널 연동"

if [[ "$DRY_RUN" == "1" ]]; then
  ok "[DRY] Telegram config 패치 (botToken: ${TG_BOT_TOKEN:0:10}..., chatId: $CHAT_ID)"
else
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{}' > "$CONFIG_FILE"
  fi

  # 환경변수로 전달 (ps 노출 방지)
  OC_PATH="$CONFIG_FILE" OC_TOKEN="$TG_BOT_TOKEN" OC_CHAT="$CHAT_ID" node -e '
    const fs = require("fs");
    const {OC_PATH, OC_TOKEN, OC_CHAT} = process.env;
    try {
      const c = JSON.parse(fs.readFileSync(OC_PATH, "utf8"));
      c.channels = c.channels || {};
      c.channels.telegram = {
        enabled: true,
        botToken: OC_TOKEN,
        dmPolicy: "allowlist",
        allowFrom: [OC_CHAT]
      };
      fs.writeFileSync(OC_PATH, JSON.stringify(c, null, 2));
      console.log("Telegram config updated.");
    } catch (e) { console.error(e); process.exit(1); }
  '

  if [[ $? -eq 0 ]]; then
    chmod 600 "$CONFIG_FILE"
    ok "Telegram 설정 완료 (ChatID: $CHAT_ID)"
  else
    fail "Telegram 설정 실패"
  fi
fi

# ============================================================================
# Step 5: Workspace & Persona 생성
# ============================================================================
echo ""
info "Step 5/6: Workspace 및 Persona 생성"

# DRY_RUN이면 임시 디렉토리에 생성
if [[ "$DRY_RUN" == "1" ]]; then
  WORKSPACE=$(mktemp -d)/workspace
  info "[DRY] Workspace → $WORKSPACE"
fi
mkdir -p "$WORKSPACE/memory"

# 파일 생성 함수
write_file() {
  local path="$1"
  local content="$2"
  local sig="${3:-}"  # 선택적 시그니처 (첫 줄)
  if [[ ! -f "$path" ]]; then
    printf '%s\n' "$content" > "$path"
    ok "$(basename "$path") 생성"
  elif [[ -n "$sig" ]] && head -1 "$path" | grep -qF "$sig"; then
    # 우리 템플릿이면 업데이트 (이름/ChatID 변경 반영)
    printf '%s\n' "$content" > "$path"
    ok "$(basename "$path") 업데이트"
  else
    ok "$(basename "$path") 이미 존재 — 스킵 (사용자 커스텀 보존)"
  fi
}

SOUL_CONTENT="# SOUL.md — 봇의 성격
## 핵심
- 동료 같은 AI 비서. 딱딱한 말투 금지.
- 결과를 먼저 말하고, 근거는 뒤에.
- 모르면 '찾아볼게요'라고 솔직하게.
## 말투
- 부드러운 해요체 (ex. 알겠습니다, 처리할게요)
- 이모지 적절히 사용"

AGENTS_CONTENT="# AGENTS.md — 운영 규칙
## 우선순위
1. **안전**: 데이터 삭제 시 신중하게 (trash 사용)
2. **실행**: 지시하면 즉시 수행
## 메모리
- 사용자의 선호, 결정사항은 MEMORY.md에 기록
- 이름: ${USER_NAME}"

USER_CONTENT="# USER.md
- 이름: ${USER_NAME}
- Chat ID: ${CHAT_ID}"

write_file "$WORKSPACE/SOUL.md" "$SOUL_CONTENT" "# SOUL.md"
write_file "$WORKSPACE/AGENTS.md" "$AGENTS_CONTENT" "# AGENTS.md"
write_file "$WORKSPACE/USER.md" "$USER_CONTENT" "# USER.md"

# ============================================================================
# Step 6: 스킬 설치 & Gateway 재시작
# ============================================================================
echo ""
info "Step 6/6: 스킬 설치 및 시작"

# 필수 스킬 의존성
if ! command -v gh &>/dev/null; then dry brew install gh; fi
if ! command -v ffmpeg &>/dev/null; then dry brew install ffmpeg; fi

# Gateway 재시작 (설정 적용)
if [[ "$DRY_RUN" == "1" ]]; then
  ok "[DRY] Gateway start/restart"
elif openclaw gateway status 2>/dev/null | grep -q "running"; then
  openclaw gateway restart
  ok "Gateway 재시작 완료"
else
  openclaw gateway start
  ok "Gateway 시작 완료"
fi

# ============================================================================
# 완료 & 보안 가이드
# ============================================================================
echo ""
echo "============================================"
if [[ $FAILED -eq 0 ]]; then
  echo -e "  ${GREEN}✅ 모든 설치가 완료되었습니다!${NC}"
else
  echo -e "  ${YELLOW}⚠️  설치 완료 (일부 오류 발생)${NC}"
fi
echo "============================================"
echo ""
echo "  [테스트 방법]"
echo "  Telegram 봇에게 '안녕'이라고 메시지를 보내보세요."
echo ""
echo "  [원격 최적화 설정]"
echo "  담당자가 원격으로 봇을 최적화할 수 있도록 설정합니다."
echo ""
if [[ "$DRY_RUN" == "1" ]]; then
  ok "[DRY] SSH + 터널 설정 스킵"
else
  info "원격 접속 설정 중..."

  # SSH 활성화
  sudo systemsetup -setremotelogin on 2>/dev/null
  ok "SSH 활성화 완료"

  # SSH 키가 없으면 생성 (localhost.run 접속용)
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]] && [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q
    ok "SSH 키 생성 완료"
  fi

  # 리버스 터널 (localhost.run — 설치 불필요, 계정 불필요)
  info "원격 접속 터널을 여는 중..."
  TUNNEL_LOG="/tmp/openclaw-tunnel.log"
  ssh -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 \
    -R 0:localhost:22 nokey@localhost.run > "$TUNNEL_LOG" 2>&1 &
  TUNNEL_PID=$!

  # 터널 주소 대기 (최대 15초)
  TUNNEL_ADDR=""
  for i in $(seq 1 15); do
    TUNNEL_ADDR=$(grep -oE '[a-z0-9]+\.localhost\.run' "$TUNNEL_LOG" 2>/dev/null | head -1)
    if [[ -n "$TUNNEL_ADDR" ]]; then break; fi
    sleep 1
  done

  if [[ -n "$TUNNEL_ADDR" ]]; then
    ok "원격 접속 준비 완료!"
    echo ""
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │  🔗 원격 접속 주소 (담당자에게 전달)      │"
    echo "  │                                           │"
    echo "  │  ssh $(whoami)@${TUNNEL_ADDR}             │"
    echo "  │                                           │"
    echo "  │  ⚠️ 이 창을 닫으면 접속이 끊깁니다        │"
    echo "  └─────────────────────────────────────────┘"
    echo ""
    # 설치 결과에 터널 주소 추가
    TUNNEL_INFO="원격접속: ssh $(whoami)@${TUNNEL_ADDR}"
  else
    warn "터널 연결 실패 — 담당자에게 공인IP를 알려주세요"
    TUNNEL_INFO=""
    kill $TUNNEL_PID 2>/dev/null
  fi
fi

# setup-env 삭제 (보안)
rm -f "$SETUP_ENV"

# ============================================================================
# 설치 결과 요약 (고객이 담당자에게 전달)
# ============================================================================
if [[ "$DRY_RUN" != "1" ]]; then
  SYS_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "감지실패")
  LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "N/A")
  SYS_USER=$(whoami)
  SYS_HOST=$(hostname)
  SYS_OS="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"
  OC_VER=$(openclaw --version 2>/dev/null || echo "미설치")
  SSH_ON=$(systemsetup -getremotelogin 2>/dev/null | grep -ci "on" || true)

  if [[ $FAILED -eq 0 ]]; then STATUS="✅ 성공"; else STATUS="⚠️ 일부 오류 (${FAILED}건)"; fi

  INSTALL_REPORT="🦞 OpenClaw 설치 결과
상태: ${STATUS}
이름: ${USER_NAME}
호스트: ${SYS_HOST}
OS: ${SYS_OS}
OpenClaw: ${OC_VER}
공인IP: ${SYS_IP}
유저: ${SYS_USER}
${TUNNEL_INFO:-원격접속: 설정안됨}
ChatID: ${CHAT_ID}
모델: ${MODEL_CHOICE}"

  # 파일로 저장
  REPORT_FILE="$HOME/.openclaw/install-report.txt"
  printf '%s\n' "$INSTALL_REPORT" > "$REPORT_FILE"

  echo ""
  echo "  ┌─────────────────────────────────────────┐"
  echo "  │  📋 아래 내용을 담당자에게 보내주세요     │"
  echo "  └─────────────────────────────────────────┘"
  echo ""
  echo "$INSTALL_REPORT"
  echo ""
  echo "  (위 내용이 클립보드에 복사되었습니다)"

  # macOS 클립보드에 자동 복사
  printf '%s' "$INSTALL_REPORT" | pbcopy 2>/dev/null && \
    ok "클립보드 복사 완료 — Telegram에 붙여넣기(Cmd+V) 하세요" || \
    info "수동 복사: cat $REPORT_FILE"
fi

echo ""
if [[ "$DRY_RUN" != "1" ]]; then
  echo "  📋 설치 로그: $LOG_FILE"
  echo "  (문제 발생 시 이 파일을 담당자에게 전달해주세요)"
  echo ""
fi
echo "  설치가 끝났습니다. 창을 닫아도 됩니다."
