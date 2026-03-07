#!/usr/bin/env bash
set -euo pipefail

# OpenClaw Hetzner bootstrap (Ubuntu/Debian)
# - Root로 실행
# - 1회 실행/재실행 모두 안전하게 (멱등)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){ echo -e "${RED}[ERR ]${NC} $*"; }

usage() {
  cat <<'USAGE'
Usage:
  sudo bash openclaw-setup-hetzner.sh [options]

Options:
  --env-file <path>                env 파일 로드 (권장)
  --user-name <name>               사용자 표시 이름 (예: Kim)
  --telegram-bot-token <token>     Telegram Bot Token
  --telegram-chat-id <id>          Telegram Chat ID (음수 가능)
  --auth-mode <setup-token|token|skip>  인증 모드 (default: setup-token)
  --token-provider <id>            auth-mode=token일 때 provider (예: anthropic)
  --token <value>                  auth-mode=token일 때 토큰
  --openclaw-user <user>           리눅스 사용자 (default: openclaw)
  --workspace <path>               워크스페이스 경로
  --no-firewall                    UFW 설정 건너뜀

Env keys (env-file에서 사용 가능):
  OC_USER_NAME
  TELEGRAM_BOT_TOKEN
  TELEGRAM_CHAT_ID
  OC_AUTH_MODE
  OC_TOKEN_PROVIDER
  OC_TOKEN
  OC_OPENCLAW_USER
  OC_WORKSPACE
USAGE
}

[[ ${EUID:-$(id -u)} -eq 0 ]] || { err "root 권한으로 실행하세요."; exit 1; }

ENV_FILE=""
USER_NAME="${OC_USER_NAME:-}"
TG_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TG_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
AUTH_MODE="${OC_AUTH_MODE:-setup-token}"
TOKEN_PROVIDER="${OC_TOKEN_PROVIDER:-}"
TOKEN_VALUE="${OC_TOKEN:-}"
OC_USER="${OC_OPENCLAW_USER:-openclaw}"
WORKSPACE="${OC_WORKSPACE:-}"
USE_FIREWALL=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) ENV_FILE="${2:-}"; shift 2 ;;
    --user-name) USER_NAME="${2:-}"; shift 2 ;;
    --telegram-bot-token) TG_BOT_TOKEN="${2:-}"; shift 2 ;;
    --telegram-chat-id) TG_CHAT_ID="${2:-}"; shift 2 ;;
    --auth-mode) AUTH_MODE="${2:-}"; shift 2 ;;
    --token-provider) TOKEN_PROVIDER="${2:-}"; shift 2 ;;
    --token) TOKEN_VALUE="${2:-}"; shift 2 ;;
    --openclaw-user) OC_USER="${2:-}"; shift 2 ;;
    --workspace) WORKSPACE="${2:-}"; shift 2 ;;
    --no-firewall) USE_FIREWALL=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "알 수 없는 옵션: $1"; usage; exit 1 ;;
  esac
done

if [[ -n "$ENV_FILE" ]]; then
  [[ -f "$ENV_FILE" ]] || { err "env 파일 없음: $ENV_FILE"; exit 1; }
  # trusted input (관리자 스크립트가 생성)
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  USER_NAME="${OC_USER_NAME:-$USER_NAME}"
  TG_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$TG_BOT_TOKEN}"
  TG_CHAT_ID="${TELEGRAM_CHAT_ID:-$TG_CHAT_ID}"
  AUTH_MODE="${OC_AUTH_MODE:-$AUTH_MODE}"
  TOKEN_PROVIDER="${OC_TOKEN_PROVIDER:-$TOKEN_PROVIDER}"
  TOKEN_VALUE="${OC_TOKEN:-$TOKEN_VALUE}"
  OC_USER="${OC_OPENCLAW_USER:-$OC_USER}"
  WORKSPACE="${OC_WORKSPACE:-$WORKSPACE}"
fi

[[ -n "$USER_NAME" ]] || { err "--user-name 필요"; exit 1; }
[[ -n "$TG_BOT_TOKEN" ]] || { err "--telegram-bot-token 필요"; exit 1; }
[[ -n "$TG_CHAT_ID" ]] || { err "--telegram-chat-id 필요"; exit 1; }
[[ "$AUTH_MODE" == "setup-token" || "$AUTH_MODE" == "token" || "$AUTH_MODE" == "skip" ]] || { err "--auth-mode 는 setup-token|token|skip"; exit 1; }

if [[ "$AUTH_MODE" == "token" ]]; then
  [[ -n "$TOKEN_PROVIDER" ]] || { err "auth-mode=token이면 --token-provider 필요"; exit 1; }
  [[ -n "$TOKEN_VALUE" ]] || { err "auth-mode=token이면 --token 필요"; exit 1; }
fi

if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="/home/${OC_USER}/.openclaw/workspace"
fi

export DEBIAN_FRONTEND=noninteractive

apt_install() {
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg jq git ufw sudo lsb-release
}

install_node_if_needed() {
  if command -v node >/dev/null 2>&1; then
    major=$(node -v | sed -E 's/^v([0-9]+).*/\1/')
    if [[ "$major" -ge 20 ]]; then
      ok "Node.js $(node -v) 이미 설치됨"
      return
    fi
    warn "Node.js 버전이 낮아 업그레이드합니다: $(node -v)"
  fi

  info "Node.js LTS 설치"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
  ok "Node.js 설치됨: $(node -v)"
}

install_openclaw_if_needed() {
  if command -v openclaw >/dev/null 2>&1; then
    ok "OpenClaw 이미 설치됨: $(openclaw --version 2>/dev/null || echo unknown)"
    return
  fi
  info "OpenClaw 설치 (npm -g)"
  npm install -g openclaw
  ok "OpenClaw 설치 완료: $(openclaw --version 2>/dev/null || echo unknown)"
}

ensure_user() {
  if id "$OC_USER" >/dev/null 2>&1; then
    ok "유저 존재: $OC_USER"
  else
    info "유저 생성: $OC_USER"
    useradd -m -s /bin/bash "$OC_USER"
    ok "유저 생성 완료"
  fi
}

run_as_oc() {
  sudo -u "$OC_USER" -H "$@"
}

write_workspace_templates() {
  local base="/home/${OC_USER}/.openclaw/workspace"
  mkdir -p "$base/memory"

  cat > "$base/SOUL.md" <<EOF
# SOUL.md — ${USER_NAME} 전용 OpenClaw

- 한국어로 짧고 명확하게 답하기
- 실행 우선, 장황한 설명 금지
- 추측 금지 (불확실하면 확인 후 답변)
EOF

  cat > "$base/AGENTS.md" <<'EOF'
# AGENTS.md — 운영 규칙

1. 안전 우선 (삭제/외부전송 주의)
2. 실행 우선 (작업은 바로 수행)
3. 완료 보고는 결과 중심
EOF

  cat > "$base/USER.md" <<EOF
# USER.md
- Name: ${USER_NAME}
- Telegram Chat ID: ${TG_CHAT_ID}
EOF

  touch "$base/MEMORY.md" "$base/SESSION-STATE.md"
  chown -R "$OC_USER:$OC_USER" "/home/${OC_USER}/.openclaw"
  ok "workspace 템플릿 준비 완료: $base"
}

configure_telegram() {
  local cfg="/home/${OC_USER}/.openclaw/openclaw.json"
  [[ -f "$cfg" ]] || echo '{}' > "$cfg"

  node -e '
    const fs = require("fs");
    const [,,path,botToken,chatId] = process.argv;
    const c = JSON.parse(fs.readFileSync(path, "utf8"));
    c.channels = c.channels || {};
    c.channels.telegram = c.channels.telegram || {};
    c.channels.telegram.enabled = true;
    c.channels.telegram.botToken = botToken;
    c.channels.telegram.dmPolicy = "allowlist";
    c.channels.telegram.allowFrom = [String(chatId)];
    fs.writeFileSync(path, JSON.stringify(c, null, 2));
  ' "$cfg" "$TG_BOT_TOKEN" "$TG_CHAT_ID"

  chown "$OC_USER:$OC_USER" "$cfg"
  chmod 600 "$cfg"
  ok "Telegram 설정 완료"
}

run_onboard() {
  local common=(
    onboard
    --flow quickstart
    --mode local
    --workspace "$WORKSPACE"
    --install-daemon
    --skip-ui
    --skip-skills
    --skip-health
    --accept-risk
    --non-interactive
  )

  if [[ "$AUTH_MODE" == "token" ]]; then
    info "OpenClaw onboard (token 모드)"
    run_as_oc openclaw "${common[@]}" \
      --auth-choice token \
      --token-provider "$TOKEN_PROVIDER" \
      --token "$TOKEN_VALUE"
    ok "onboard 완료 (token)"
  elif [[ "$AUTH_MODE" == "setup-token" ]]; then
    info "OpenClaw onboard (setup-token 모드: auth 단계는 수동)"
    run_as_oc openclaw "${common[@]}" --auth-choice skip
    ok "기본 onboard 완료 (auth skip)"
  else
    info "OpenClaw onboard (skip 모드: 직원이 SSH에서 원하는 provider 직접 로그인)"
    run_as_oc openclaw "${common[@]}" --auth-choice skip
    ok "기본 onboard 완료 (auth 미설정)"
  fi
}

start_gateway() {
  if run_as_oc openclaw gateway status >/dev/null 2>&1; then
    run_as_oc openclaw gateway restart >/dev/null 2>&1 || true
  else
    run_as_oc openclaw gateway start >/dev/null 2>&1 || true
  fi
  sleep 2
  if run_as_oc openclaw gateway status >/dev/null 2>&1; then
    ok "Gateway 실행 확인"
  else
    warn "Gateway 상태 확인 필요: sudo -u ${OC_USER} -H openclaw gateway status"
  fi
}

notify_model_selection() {
  local msg
  msg=$'✅ OpenClaw 서버 세팅이 완료됐습니다.\n\n'
  msg+=$'이제 Telegram에서 모델을 직접 고르세요:\n'
  msg+=$'1) /model\n'
  msg+=$'2) 번호 선택 또는 /model <provider/model>\n'
  msg+=$'3) 상태 확인: /model status\n\n'
  msg+=$'팁) 세션별 빠른 변경은 /model, 서버 기본값 고정은 관리자에게 요청하세요.'

  curl -fsS "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_CHAT_ID}" \
    --data-urlencode "text=${msg}" >/dev/null 2>&1 \
    && ok "모델 선택 안내 메시지 발송" \
    || warn "모델 선택 안내 메시지 발송 실패"
}

setup_firewall() {
  [[ "$USE_FIREWALL" -eq 1 ]] || { warn "UFW 설정 생략"; return; }
  info "UFW 설정 (OpenSSH 허용)"
  ufw allow OpenSSH >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || true
  ufw status | grep -q "Status: active" && ok "UFW 활성화" || warn "UFW 상태 확인 필요"
}

main() {
  info "패키지 설치"
  apt_install
  install_node_if_needed
  install_openclaw_if_needed

  ensure_user
  write_workspace_templates
  run_onboard
  configure_telegram
  setup_firewall
  start_gateway
  notify_model_selection

  echo ""
  echo "=================================================="
  ok "Hetzner OpenClaw bootstrap 완료"
  echo "- User: $OC_USER"
  echo "- Workspace: $WORKSPACE"
  echo "- Auth mode: $AUTH_MODE"

  if [[ "$AUTH_MODE" == "setup-token" ]]; then
    echo ""
    warn "아직 인증 1단계가 남았습니다 (직원 1회 실행)"
    echo "  sudo -u ${OC_USER} -H openclaw onboard --flow quickstart --auth-choice setup-token --workspace ${WORKSPACE}"
    echo "  (링크로 로그인 후 종료)"
  elif [[ "$AUTH_MODE" == "skip" ]]; then
    echo ""
    warn "인증은 직원이 SSH에서 직접 선택해야 합니다"
    echo "  # 대화형(권장):"
    echo "  sudo -u ${OC_USER} -H openclaw models auth add"
    echo "  # 또는 provider 지정:"
    echo "  sudo -u ${OC_USER} -H openclaw models auth login --provider <provider-id> --set-default"
  fi

  echo ""
  echo "헬스체크:"
  echo "  sudo -u ${OC_USER} -H openclaw status --json | head"
  echo "  sudo -u ${OC_USER} -H openclaw security audit --deep"
  echo "=================================================="
}

main
