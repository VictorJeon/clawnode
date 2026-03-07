#!/usr/bin/env bash
set -euo pipefail

# Admin-side provisioner (local machine)
# - Hetzner API로 직원별 서버 생성
# - SSH로 접속해 openclaw-setup-hetzner.sh 자동 실행

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){ echo -e "${RED}[ERR ]${NC} $*"; }

usage() {
  cat <<'USAGE'
Usage:
  ./provision-hetzner-openclaw-user.sh [options]

Required:
  --hcloud-token <token>           Hetzner Cloud API token
  --employee <id>                  직원 식별자 (예: minsu)
  --ssh-pubkey-file <path>         직원 공개키 파일 (ed25519.pub)

Required when bootstrap enabled (default):
  --telegram-bot-token <token>     Telegram bot token
  --telegram-chat-id <id>          직원 Telegram chat id

Auth mode:
  --auth-mode <setup-token|token|skip>  default: setup-token
  --token-provider <id>            auth-mode=token일 때 필요
  --token <value>                  auth-mode=token일 때 필요

Optional:
  --server-type <type>             default: cax21
  --image <image>                  default: ubuntu-24.04
  --location <loc>                 default: nbg1
  --server-name <name>             default: oc-<employee>
  --setup-script <path>            default: ./openclaw-setup-hetzner.sh
  --no-bootstrap                   서버 생성만 하고 설치는 생략

Example:
  ./provision-hetzner-openclaw-user.sh \
    --hcloud-token "$HCLOUD_TOKEN" \
    --employee minsu \
    --ssh-pubkey-file ~/.ssh/minsu_ed25519.pub \
    --telegram-bot-token "123:abc" \
    --telegram-chat-id "819845604" \
    --auth-mode setup-token
USAGE
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "필수 명령어 없음: $1"; exit 1; }; }

HCLOUD_TOKEN=""
EMPLOYEE=""
SSH_PUBKEY_FILE=""
TG_BOT_TOKEN=""
TG_CHAT_ID=""
AUTH_MODE="setup-token"
TOKEN_PROVIDER=""
TOKEN_VALUE=""
SERVER_TYPE="cax21"
IMAGE="ubuntu-24.04"
LOCATION="nbg1"
SERVER_NAME=""
DO_BOOTSTRAP=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT_DEFAULT="${SCRIPT_DIR}/openclaw-setup-hetzner.sh"
SETUP_SCRIPT="$SETUP_SCRIPT_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hcloud-token) HCLOUD_TOKEN="${2:-}"; shift 2 ;;
    --employee) EMPLOYEE="${2:-}"; shift 2 ;;
    --ssh-pubkey-file) SSH_PUBKEY_FILE="${2:-}"; shift 2 ;;
    --telegram-bot-token) TG_BOT_TOKEN="${2:-}"; shift 2 ;;
    --telegram-chat-id) TG_CHAT_ID="${2:-}"; shift 2 ;;
    --auth-mode) AUTH_MODE="${2:-}"; shift 2 ;;
    --token-provider) TOKEN_PROVIDER="${2:-}"; shift 2 ;;
    --token) TOKEN_VALUE="${2:-}"; shift 2 ;;
    --server-type) SERVER_TYPE="${2:-}"; shift 2 ;;
    --image) IMAGE="${2:-}"; shift 2 ;;
    --location) LOCATION="${2:-}"; shift 2 ;;
    --server-name) SERVER_NAME="${2:-}"; shift 2 ;;
    --setup-script) SETUP_SCRIPT="${2:-}"; shift 2 ;;
    --no-bootstrap) DO_BOOTSTRAP=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "알 수 없는 옵션: $1"; usage; exit 1 ;;
  esac
done

[[ -n "$HCLOUD_TOKEN" ]] || { err "--hcloud-token 필요"; exit 1; }
[[ -n "$EMPLOYEE" ]] || { err "--employee 필요"; exit 1; }
[[ -n "$SSH_PUBKEY_FILE" ]] || { err "--ssh-pubkey-file 필요"; exit 1; }
[[ -f "$SSH_PUBKEY_FILE" ]] || { err "공개키 파일 없음: $SSH_PUBKEY_FILE"; exit 1; }
[[ "$AUTH_MODE" == "setup-token" || "$AUTH_MODE" == "token" || "$AUTH_MODE" == "skip" ]] || { err "--auth-mode 는 setup-token|token|skip"; exit 1; }

if [[ "$DO_BOOTSTRAP" -eq 1 ]]; then
  [[ -n "$TG_BOT_TOKEN" ]] || { err "bootstrap 모드에서는 --telegram-bot-token 필요"; exit 1; }
  [[ -n "$TG_CHAT_ID" ]] || { err "bootstrap 모드에서는 --telegram-chat-id 필요"; exit 1; }

  if [[ "$AUTH_MODE" == "token" ]]; then
    [[ -n "$TOKEN_PROVIDER" ]] || { err "auth-mode=token이면 --token-provider 필요"; exit 1; }
    [[ -n "$TOKEN_VALUE" ]] || { err "auth-mode=token이면 --token 필요"; exit 1; }
  fi
else
  if [[ -n "$TG_BOT_TOKEN" || -n "$TG_CHAT_ID" ]]; then
    warn "--no-bootstrap 모드에서는 Telegram 인자를 사용하지 않습니다 (무시됨)"
  fi
  if [[ "$AUTH_MODE" == "token" ]]; then
    warn "--no-bootstrap 모드에서는 auth-mode=token 인자가 설치 단계에서 사용되지 않습니다"
  fi
fi

[[ -f "$SETUP_SCRIPT" ]] || { err "setup script 없음: $SETUP_SCRIPT"; exit 1; }
[[ -n "$SERVER_NAME" ]] || SERVER_NAME="oc-${EMPLOYEE}"

require_cmd curl
require_cmd jq
require_cmd ssh
require_cmd scp

api() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"

  if [[ -n "$data" ]]; then
    curl -fsS -X "$method" \
      -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$data" \
      "https://api.hetzner.cloud/v1${path}"
  else
    curl -fsS -X "$method" \
      -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
      "https://api.hetzner.cloud/v1${path}"
  fi
}

SSH_KEY_NAME="oc-${EMPLOYEE}-key"
PUBKEY_CONTENT="$(cat "$SSH_PUBKEY_FILE")"

info "SSH key 확인: ${SSH_KEY_NAME}"
ssh_key_id="$(api GET "/ssh_keys?name=${SSH_KEY_NAME}" | jq -r '.ssh_keys[0].id // empty')"
if [[ -z "$ssh_key_id" ]]; then
  info "Hetzner SSH key 생성"
  payload="$(jq -n --arg name "$SSH_KEY_NAME" --arg key "$PUBKEY_CONTENT" '{name:$name, public_key:$key}')"
  ssh_key_id="$(api POST /ssh_keys "$payload" | jq -r '.ssh_key.id')"
  ok "SSH key 생성 완료 (id=${ssh_key_id})"
else
  ok "SSH key 재사용 (id=${ssh_key_id})"
fi

info "서버 생성: ${SERVER_NAME} (${SERVER_TYPE}, ${IMAGE}, ${LOCATION})"
server_payload="$(jq -n \
  --arg name "$SERVER_NAME" \
  --arg type "$SERVER_TYPE" \
  --arg image "$IMAGE" \
  --arg location "$LOCATION" \
  --arg employee "$EMPLOYEE" \
  --argjson ssh_key_id "$ssh_key_id" \
  '{name:$name, server_type:$type, image:$image, location:$location, ssh_keys:[$ssh_key_id], labels:{role:"openclaw", employee:$employee}}')"

create_resp="$(api POST /servers "$server_payload")"
server_id="$(echo "$create_resp" | jq -r '.server.id')"
if [[ -z "$server_id" || "$server_id" == "null" ]]; then
  err "서버 생성 실패"
  echo "$create_resp" | jq . >&2 || true
  exit 1
fi
ok "서버 생성 요청 완료 (id=${server_id})"

info "서버 running 대기"
server_ip=""
for _ in $(seq 1 60); do
  desc="$(api GET "/servers/${server_id}")"
  status="$(echo "$desc" | jq -r '.server.status')"
  server_ip="$(echo "$desc" | jq -r '.server.public_net.ipv4.ip // empty')"
  if [[ "$status" == "running" && -n "$server_ip" ]]; then
    break
  fi
  sleep 2
done

[[ -n "$server_ip" ]] || { err "서버 IP 확인 실패"; exit 1; }
ok "서버 준비 완료: ${server_ip}"

if [[ "$DO_BOOTSTRAP" -eq 1 ]]; then
  info "원격 bootstrap 시작"

  tmp_env="$(mktemp)"
  chmod 600 "$tmp_env"
  {
    echo "OC_USER_NAME=$(printf '%q' "$EMPLOYEE")"
    echo "TELEGRAM_BOT_TOKEN=$(printf '%q' "$TG_BOT_TOKEN")"
    echo "TELEGRAM_CHAT_ID=$(printf '%q' "$TG_CHAT_ID")"
    echo "OC_AUTH_MODE=$(printf '%q' "$AUTH_MODE")"
    if [[ "$AUTH_MODE" == "token" ]]; then
      echo "OC_TOKEN_PROVIDER=$(printf '%q' "$TOKEN_PROVIDER")"
      echo "OC_TOKEN=$(printf '%q' "$TOKEN_VALUE")"
    fi
  } > "$tmp_env"

  SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

  for _ in $(seq 1 30); do
    if ssh "${SSH_OPTS[@]}" "root@${server_ip}" "echo ready" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  scp "${SSH_OPTS[@]}" "$SETUP_SCRIPT" "root@${server_ip}:/root/openclaw-setup-hetzner.sh"
  scp "${SSH_OPTS[@]}" "$tmp_env" "root@${server_ip}:/root/openclaw-bootstrap.env"
  rm -f "$tmp_env"

  ssh "${SSH_OPTS[@]}" "root@${server_ip}" \
    "chmod +x /root/openclaw-setup-hetzner.sh && /root/openclaw-setup-hetzner.sh --env-file /root/openclaw-bootstrap.env"

  ok "bootstrap 완료"
fi

echo ""
echo "=================================================="
ok "완료"
echo "Server: ${SERVER_NAME}"
echo "IP: ${server_ip}"
echo "SSH: ssh root@${server_ip}"

if [[ "$DO_BOOTSTRAP" -eq 1 ]]; then
  if [[ "$AUTH_MODE" == "setup-token" ]]; then
    echo ""
    warn "직원 1회 인증 필요 (setup-token)"
    echo "  ssh root@${server_ip}"
    echo "  sudo -u openclaw -H openclaw onboard --flow quickstart --auth-choice setup-token --workspace /home/openclaw/.openclaw/workspace"
  elif [[ "$AUTH_MODE" == "skip" ]]; then
    echo ""
    warn "직원이 SSH에서 원하는 provider로 직접 인증해야 합니다"
    echo "  ssh root@${server_ip}"
    echo "  sudo -u openclaw -H openclaw models auth add"
    echo "  # 또는"
    echo "  sudo -u openclaw -H openclaw models auth login --provider <provider-id> --set-default"
  fi
else
  echo ""
  warn "--no-bootstrap 모드: 서버만 생성됨 (설치 미실행)"
  echo "직원에게 아래 순서를 전달하세요:"
  echo "  1) ssh root@${server_ip}"
  echo "  2) 설치 스크립트 업로드 또는 다운로드"
  echo "     - 업로드: scp ./openclaw-setup-hetzner.sh root@${server_ip}:/root/"
  echo "     - 다운로드: curl -fsSL <RAW_URL>/openclaw-setup-hetzner.sh -o /root/openclaw-setup-hetzner.sh"
  echo "  3) bash /root/openclaw-setup-hetzner.sh --user-name \"${EMPLOYEE}\" --telegram-bot-token \"<EMPLOYEE_TG_BOT_TOKEN>\" --telegram-chat-id \"<EMPLOYEE_CHAT_ID>\" --auth-mode skip"
fi

echo "=================================================="
