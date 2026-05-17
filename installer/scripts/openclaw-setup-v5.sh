#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw Quick Setup v5 — Core Memory Stack
#
# v4 -> v5 migration:
#   Memory V3 (PostgreSQL + pgvector + Python + 11 launchd services) removed.
#   Switched to OpenClaw native memory-core + QMD + dreaming + memory-wiki.
#
# Scope:
#   1. Core setup (reuse existing or run fresh)
#   2. QMD install + --glob compatibility patch
#   3. Workspace bootstrap
#   4. openclaw.json patch (memory-core + QMD + dreaming + wiki)
#   5. Bundled hooks
#   6. memory-wiki vault init
#   7. Gateway restart + health check
#   8. Optional: Google API key (embedding fallback)
#   9. V3 service cleanup
#  10. Final report
# ============================================================================

DRY_RUN="${DRY_RUN:-0}"
SKIP_CORE_SETUP="${SKIP_CORE_SETUP:-0}"
FORCE_CORE_SETUP="${FORCE_CORE_SETUP:-0}"
MEMORY_ONLY="${MEMORY_ONLY:-0}"
GIST_BASE_URL="${GIST_BASE_URL:-https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORE_SCRIPT_LOCAL="${SCRIPT_DIR}/openclaw-setup.sh"
BOOT_TEMPLATE_LOCAL="${REPO_ROOT}/installer/templates/BOOT-customer.md"
CORE_SCRIPT="${CORE_SCRIPT_LOCAL}"
ASSET_TMP=""

CONFIG_DIR="${HOME}/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
SETUP_ENV="${CONFIG_DIR}/.setup-env"
WORKSPACE="${CONFIG_DIR}/workspace"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LOG_FILE="${CONFIG_DIR}/setup-v5-$(date +%Y%m%d-%H%M%S).log"
CLAWNODE_VERSION_FILE="${CONFIG_DIR}/.clawnode-version"
WIKI_VAULT_PATH="${CONFIG_DIR}/wiki/main"

INSTALLER_V5_URL="${INSTALLER_V5_URL:-${GIST_BASE_URL}/openclaw-setup-v5.sh}"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-2026.5.12}"
OPENCLAW_PKG="openclaw@${OPENCLAW_VERSION}"
GOOGLE_API_KEY_MODE="${GOOGLE_API_KEY_MODE:-ask}"
GOOGLE_API_KEY_SKIPPED_BY_USER=0
CORE_STEP_RESULT="pending"
UPDATE_MODE=0
USER_NAME="${USER_NAME:-}"
CHAT_ID="${CHAT_ID:-}"

DREAMING_TIMEZONE="${DREAMING_TIMEZONE:-Asia/Seoul}"
DREAMING_FREQUENCY="${DREAMING_FREQUENCY:-0 3 * * *}"
QMD_SEARCH_MODE="${QMD_SEARCH_MODE:-search}"
QMD_TIMEOUT_MS="${QMD_TIMEOUT_MS:-8000}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err()   { printf "${RED}[ERR ]${NC} %s\n" "$*" >&2; }

print_hero() {
  echo ""
  echo "============================================================"
  printf '  %b\n' "${BOLD}OpenClaw V5 — Core Memory Stack${NC}"
  echo "  local agent runtime + memory-core + QMD + dreaming + wiki"
  echo "============================================================"
  echo ""
  printf '  %b\n' "${CYAN}Components${NC}"
  echo "  - OpenClaw core runtime (${OPENCLAW_VERSION})"
  echo "  - memory-core (active memory plugin)"
  echo "  - QMD search backend (BM25 + vector + reranking)"
  echo "  - Dreaming (background consolidation)"
  echo "  - memory-wiki (compiled knowledge vault)"
  echo ""
}

stage() {
  echo ""
  printf "${BOLD}[%s]${NC}\n" "$1"
}

config_json_value() {
  local expr="$1"
  local python_bin
  python_bin="$(command -v python3 2>/dev/null || true)"
  [[ -n "${python_bin}" && -f "${CONFIG_FILE}" ]] || return 1
  "${python_bin}" - "${CONFIG_FILE}" "${expr}" <<'PYEOF'
import json, sys
path = sys.argv[1]
keys = sys.argv[2].split(".")
with open(path, "r", encoding="utf-8") as fh:
    obj = json.load(fh)
for k in keys:
    if isinstance(obj, dict):
        obj = obj.get(k)
    else:
        obj = None
        break
if obj is None:
    raise SystemExit(1)
if isinstance(obj, bool):
    print("true" if obj else "false")
elif isinstance(obj, (dict, list)):
    print(json.dumps(obj))
else:
    print(obj)
PYEOF
}

write_log_header() {
  echo "# OpenClaw Setup V5 Log — $(date)"
  echo "# OS: $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"
  echo "# User: $(whoami)"
  echo "---"
}

core_step_label() {
  case "${CORE_STEP_RESULT}" in
    memory-only) printf '%s\n' "existing OpenClaw + core memory stack applied" ;;
    skipped-existing) printf '%s\n' "existing OpenClaw + core memory stack upgrade" ;;
    skipped-env) printf '%s\n' "core skipped (SKIP_CORE_SETUP=1)" ;;
    ran) printf '%s\n' "fresh OpenClaw core + core memory stack" ;;
    *) printf '%s\n' "core memory stack applied" ;;
  esac
}

tailscale_ip() {
  if command -v tailscale >/dev/null 2>&1; then
    tailscale ip -4 2>/dev/null | head -n 1 || true
    return 0
  fi
  if [[ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
    /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null | head -n 1 || true
  fi
}

render_final_summary() {
  local oc_ver sys_ip sys_host sys_os sys_user ts_ip memory_slot qmd_state dreaming_state wiki_state report_file report openclaw_bin

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] final summary"
    return 0
  fi

  openclaw_bin="$(resolve_openclaw_bin 2>/dev/null || true)"
  if [[ -n "${openclaw_bin}" ]]; then
    oc_ver="$("${openclaw_bin}" --version 2>/dev/null || echo "unknown")"
  else
    oc_ver="unknown"
  fi
  sys_ip="$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "unknown")"
  sys_host="$(hostname)"
  sys_os="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"
  sys_user="$(whoami)"
  ts_ip="$(tailscale_ip)"

  memory_slot="$(config_json_value 'plugins.slots.memory' 2>/dev/null || echo "unknown")"

  if command -v qmd >/dev/null 2>&1; then
    qmd_state="installed ($(qmd --version 2>/dev/null | head -1 || echo 'unknown'))"
  else
    qmd_state="not installed"
  fi

  dreaming_state="enabled (${DREAMING_FREQUENCY}, ${DREAMING_TIMEZONE})"

  if [[ -d "${WIKI_VAULT_PATH}" ]]; then
    wiki_state="ready (${WIKI_VAULT_PATH})"
  else
    wiki_state="not initialized"
  fi

  local gemini_state
  if has_google_api_key; then
    gemini_state="enabled"
  else
    gemini_state="disabled (optional)"
  fi

  report="OpenClaw V5 Setup Result
Status: Core Memory Stack Ready
Mode: $(core_step_label)
Host: ${sys_host}
OS: ${sys_os}
OpenClaw: ${oc_ver}
Public IP: ${sys_ip}
User: ${sys_user}
Memory Slot: ${memory_slot}
QMD: ${qmd_state}
Dreaming: ${dreaming_state}
Wiki: ${wiki_state}
Gemini API: ${gemini_state}
Workspace: ${WORKSPACE}
Report: ${CONFIG_DIR}/install-report-v5.txt
Log: ${LOG_FILE}"

  if [[ -n "${ts_ip}" ]]; then
    report="${report}
Tailscale IP: ${ts_ip}"
  fi

  report_file="${CONFIG_DIR}/install-report-v5.txt"
  printf '%s\n' "${report}" > "${report_file}"

  echo ""
  echo "============================================================"
  printf '  %b\n' "${GREEN}${BOLD}OpenClaw V5 — Core Memory Stack Ready${NC}"
  echo "============================================================"
  echo ""
  printf '  %b\n' "${CYAN}Provisioned Stack${NC}"
  echo "  - OpenClaw core (${oc_ver})"
  echo "  - memory-core (active memory plugin)"
  echo "  - QMD search backend"
  echo "  - Dreaming (${DREAMING_FREQUENCY} ${DREAMING_TIMEZONE})"
  echo "  - memory-wiki (isolated vault)"
  echo ""
  printf '  %b\n' "${CYAN}Report${NC}"
  printf '%s\n' "${report}"
  echo ""

  if printf '%s' "${report}" | pbcopy 2>/dev/null; then
    ok "clipboard copy done"
  else
    info "manual copy: ${report_file}"
  fi
}

# ============================================================================
# Utility Functions
# ============================================================================

ensure_homebrew_on_path() {
  local prefix
  for prefix in /opt/homebrew /usr/local; do
    if [[ -x "${prefix}/bin/brew" ]]; then
      case ":${PATH}:" in
        *":${prefix}/bin:"*) ;;
        *) PATH="${prefix}/bin:${prefix}/sbin:${PATH}" ;;
      esac
      export PATH
      return 0
    fi
  done
  return 1
}

dry() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] $*"
    return 0
  fi
  "$@"
}

resolve_openclaw_bin() {
  local candidate
  for candidate in \
    openclaw \
    "${HOME}/.local/share/pnpm/openclaw" \
    "${HOME}/Library/pnpm/openclaw" \
    "${HOME}/.npm-global/bin/openclaw" \
    "${HOME}/.local/bin/openclaw" \
    "${HOME}/.bun/bin/openclaw" \
    /opt/homebrew/bin/openclaw \
    /usr/local/bin/openclaw \
    /usr/bin/openclaw
  do
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return 0
    fi
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

gateway_health_ok() {
  curl -fsS "http://127.0.0.1:18789/health" >/dev/null 2>&1
}

wait_for_gateway_health() {
  local timeout_secs="${1:-15}"
  local i=0
  while [[ "${i}" -lt "${timeout_secs}" ]]; do
    if gateway_health_ok; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

start_gateway_manual_fallback() {
  local oc_bin="$1"
  local manual_log="${CONFIG_DIR}/logs/gateway.manual.log"
  mkdir -p "${CONFIG_DIR}/logs"
  pkill -f "[o]penclaw-gateway" >/dev/null 2>&1 || true
  pkill -f "[d]ist/index.js gateway --port 18789" >/dev/null 2>&1 || true
  nohup "${oc_bin}" gateway --port 18789 > "${manual_log}" 2>&1 < /dev/null &
}

core_install_present() {
  if [[ -z "$(resolve_openclaw_bin 2>/dev/null || true)" ]]; then
    return 1
  fi
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    return 1
  fi
  if ! node -e 'const fs=require("fs"); const p=process.argv[1]; const c=JSON.parse(fs.readFileSync(p,"utf8")); const ok=typeof c==="object" && c !== null && (c.agents || c.channels || c.plugins || c.global || c.sessions || c.model || c.providers); process.exit(ok ? 0 : 1);' "${CONFIG_FILE}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

core_auth_present() {
  local auth_file
  auth_file="$(find "${CONFIG_DIR}/agents" -name "auth-profiles.json" -path "*/main/agent/*" 2>/dev/null | head -1)"
  if [[ -z "${auth_file}" || ! -f "${auth_file}" ]]; then
    return 1
  fi

  local auth_tuple provider auth_type secret_field secret
  auth_tuple="$(AUTH_FILE="${auth_file}" python3 - <<'PYEOF' 2>/dev/null
import json, os, sys
KNOWN_PROVIDERS = {"anthropic", "openai", "google", "gemini", "openai-codex"}
SECRET_FIELDS = ("token", "accessToken", "access", "key", "apiKey")
try:
    d = json.load(open(os.environ['AUTH_FILE']))
    profiles = d.get('profiles', {})
    for _k, v in profiles.items():
        if not isinstance(v, dict):
            continue
        provider = (v.get('provider') or '').lower().strip()
        if provider not in KNOWN_PROVIDERS:
            continue
        auth_type = (v.get('type') or v.get('mode') or '').lower().strip()
        for field in SECRET_FIELDS:
            value = v.get(field) or ''
            if isinstance(value, str) and len(value) >= 20:
                print(provider, auth_type or 'unknown', field, value, sep='\t')
                sys.exit(0)
except Exception:
    pass
sys.exit(1)
PYEOF
)"
  if [[ -z "${auth_tuple}" ]]; then return 1; fi

  IFS=$'\t' read -r provider auth_type secret_field secret <<< "${auth_tuple}"
  if [[ -z "${provider}" || -z "${secret}" ]]; then return 1; fi

  # Provider validation with 1 retry on transient failure (timeout 15s)
  local attempt
  for attempt in 1 2; do
    case "${provider}" in
      anthropic)
        [[ "${auth_type}" == "token" || "${secret}" == sk-ant-oat* ]] && return 0
        curl -fsS --max-time 15 -H "x-api-key: ${secret}" -H "anthropic-version: 2023-06-01" "https://api.anthropic.com/v1/models" -o /dev/null 2>/dev/null && return 0
        ;;
      openai|openai-codex)
        curl -fsS --max-time 15 -H "Authorization: Bearer ${secret}" "https://api.openai.com/v1/models" -o /dev/null 2>/dev/null && return 0
        ;;
      google|gemini)
        curl -fsS --max-time 15 "https://generativelanguage.googleapis.com/v1beta/models?key=${secret}" -o /dev/null 2>/dev/null && return 0
        ;;
      *) return 1 ;;
    esac
    [[ "${attempt}" == "1" ]] && sleep 2
  done
  warn "auth credential validation failed for ${provider} (type=${auth_type:-unknown}) after retry."
  return 1
}

# Provider re-auth menu — invoked when core_auth_present fails on an existing
# install. Replaces the v5 default of forcing a full core script re-run, which
# always presented the Anthropic onboarding screen even for OpenAI/Codex users.
prompt_reauth_provider() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] prompt_reauth_provider"
    return 0
  fi
  echo ""
  printf '%b\n' "${BOLD}Auth Validation Failed — Re-authenticate${NC}"
  echo ""
  echo "  [1] Anthropic (setup-token or API key) — full core re-run"
  echo "  [2] OpenAI / Codex (API key) — auth-only patch"
  echo "  [3] Skip (configure manually later)"
  echo ""
  local reauth_choice
  if [[ -t 0 ]]; then
    read -rp "  Choice [1-3]: " reauth_choice
  else
    read -rp "  Choice [1-3]: " reauth_choice < /dev/tty
  fi
  case "${reauth_choice}" in
    1)
      info "delegating to core script for Anthropic re-auth"
      SUPPRESS_FINAL_REPORT=1 OPENCLAW_PARENT_LOG=1 OPENCLAW_LOG_FILE="${LOG_FILE}" OPENCLAW_VERSION="${OPENCLAW_VERSION}" bash "${CORE_SCRIPT}"
      ;;
    2)
      local reauth_key
      if [[ -t 0 ]]; then
        read -rsp "  OpenAI API Key: " reauth_key
      else
        read -rsp "  OpenAI API Key: " reauth_key < /dev/tty
      fi
      echo ""
      [[ -z "${reauth_key}" ]] && { warn "empty key — skipping"; return 0; }
      local auth_dir="${CONFIG_DIR}/agents/main/agent"
      mkdir -p "${auth_dir}"
      AUTH_FILE="${auth_dir}/auth-profiles.json" REAUTH_KEY="${reauth_key}" python3 - <<'PYEOF'
import json, os
auth_file = os.environ['AUTH_FILE']
try:
    with open(auth_file) as f:
        d = json.load(f)
except Exception:
    d = {"version": 1, "profiles": {}}
d.setdefault("profiles", {})
d["profiles"]["openai:default"] = {
    "type": "apiKey",
    "provider": "openai",
    "apiKey": os.environ['REAUTH_KEY']
}
with open(auth_file, "w") as f:
    json.dump(d, f, indent=2)
os.chmod(auth_file, 0o600)
print("OK: openai:default")
PYEOF
      ok "OpenAI key written to auth-profiles.json"
      ;;
    *)
      warn "skipping auth — configure manually via 'openclaw onboard'"
      ;;
  esac
}

require_existing_core_for_memory_only() {
  if [[ "${MEMORY_ONLY}" != "1" ]]; then return 0; fi
  SKIP_CORE_SETUP="1"
  if core_install_present; then
    CORE_STEP_RESULT="memory-only"
    return 0
  fi
  err "MEMORY_ONLY=1 requires an existing OpenClaw installation."
  exit 1
}

load_existing_identity() {
  local user_file
  if [[ -z "${USER_NAME}" || -z "${CHAT_ID}" ]]; then
    if [[ -f "${SETUP_ENV}" ]]; then
      d64() { echo "$1" | base64 -d 2>/dev/null || echo "$1"; }
      while IFS= read -r line; do
        [[ "${line}" == *=* ]] || continue
        key="${line%%=*}"; value="${line#*=}"
        case "$key" in
          USER_NAME) [[ -z "${USER_NAME}" ]] && USER_NAME="$(d64 "$value")" ;;
          CHAT_ID)   [[ -z "${CHAT_ID}" ]]   && CHAT_ID="$(d64 "$value")" ;;
        esac
      done < "${SETUP_ENV}"
    fi
  fi
  user_file="${WORKSPACE}/USER.md"
  if [[ -f "${user_file}" ]]; then
    [[ -z "${USER_NAME}" ]] && USER_NAME="$(sed -n 's/^- 이름: //p' "${user_file}" | head -n 1)"
    [[ -z "${CHAT_ID}" ]]   && CHAT_ID="$(sed -n 's/^- Chat ID: //p' "${user_file}" | head -n 1)"
  fi
  [[ -n "${USER_NAME}" ]] || USER_NAME="$(whoami)"
  [[ -n "${CHAT_ID}" ]]   || CHAT_ID="unknown"
}

cleanup_assets() {
  if [[ -n "${ASSET_TMP}" && -d "${ASSET_TMP}" ]]; then
    rm -rf "${ASSET_TMP}"
  fi
}
trap cleanup_assets EXIT

if [[ "${DRY_RUN}" != "1" ]]; then
  mkdir -p "${CONFIG_DIR}"
  exec > >(tee -a "${LOG_FILE}") 2>&1
  write_log_header
fi

print_hero

download_to_file() {
  local url="$1" path="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] curl -fsSL ${url} -o ${path}"
    return 0
  fi
  curl -fsSL "${url}" -o "${path}"
}

prepare_installer_assets() {
  if [[ -f "${CORE_SCRIPT_LOCAL}" ]]; then
    CORE_SCRIPT="${CORE_SCRIPT_LOCAL}"
    return 0
  fi
  info "local core script not found — downloading from gist"
  ASSET_TMP="$(mktemp -d)"
  CORE_SCRIPT="${ASSET_TMP}/openclaw-setup.sh"
  download_to_file "${GIST_BASE_URL}/openclaw-setup.sh" "${CORE_SCRIPT}"
}

# ============================================================================
# Core Setup
# ============================================================================

run_core_setup() {
  if [[ "${MEMORY_ONLY}" == "1" ]]; then
    warn "MEMORY_ONLY=1 — preserving existing OpenClaw core."
    UPDATE_MODE=1; CORE_STEP_RESULT="memory-only"
    return 0
  fi
  if [[ "${SKIP_CORE_SETUP}" == "1" ]]; then
    warn "SKIP_CORE_SETUP=1 — skipping core setup."
    core_install_present && UPDATE_MODE=1
    CORE_STEP_RESULT="skipped-env"
    return 0
  fi
  if [[ "${FORCE_CORE_SETUP}" != "1" ]] && core_install_present; then
    if core_auth_present; then
      warn "existing core + valid auth detected — applying core memory stack only."
      UPDATE_MODE=1; CORE_STEP_RESULT="skipped-existing"
      return 0
    fi
    warn "existing core found but auth invalid — running re-auth menu."
    UPDATE_MODE=1
    prompt_reauth_provider
    CORE_STEP_RESULT="skipped-existing"
    return 0
  fi
  info "running core setup"
  CORE_STEP_RESULT="ran"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] bash ${CORE_SCRIPT}"
    return 0
  fi
  SUPPRESS_FINAL_REPORT=1 OPENCLAW_PARENT_LOG=1 OPENCLAW_LOG_FILE="${LOG_FILE}" OPENCLAW_VERSION="${OPENCLAW_VERSION}" bash "${CORE_SCRIPT}"
}

# ============================================================================
# QMD Installation
# ============================================================================

install_qmd() {
  info "QMD search backend installation"
  if command -v qmd >/dev/null 2>&1; then
    ok "QMD already installed: $(qmd --version 2>/dev/null | head -1)"
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] install QMD"
    return 0
  fi

  # Refresh PATH + bash hash table — npm/node may have been installed earlier
  # in this same shell session by the core script's `brew install node`, but
  # bash caches command lookups so a stale `command -v npm` can return false.
  ensure_homebrew_on_path || true
  hash -r 2>/dev/null || true

  # Bootstrap: if no JS package manager is available even after PATH refresh,
  # try Homebrew Node install
  if ! command -v npm >/dev/null 2>&1 \
     && ! command -v pnpm >/dev/null 2>&1 \
     && ! command -v bun >/dev/null 2>&1; then
    warn "no JS package manager (npm/pnpm/bun) found — attempting Homebrew Node bootstrap"
    if command -v brew >/dev/null 2>&1; then
      brew install node 2>/dev/null || warn "brew install node returned non-zero"
      ensure_homebrew_on_path || true
      hash -r 2>/dev/null || true
    fi
  fi

  if ! command -v npm >/dev/null 2>&1 \
     && ! command -v pnpm >/dev/null 2>&1 \
     && ! command -v bun >/dev/null 2>&1; then
    err "QMD requires npm, pnpm, or bun but none was found and bootstrap failed."
    err "Install Node.js manually (e.g. 'brew install node') then re-run this script."
    return 1
  fi

  if command -v npm >/dev/null 2>&1; then
    info "installing QMD via npm"
    npm install -g @tobilu/qmd || { err "QMD npm install failed"; return 1; }
  elif command -v pnpm >/dev/null 2>&1; then
    info "installing QMD via pnpm"
    pnpm install -g @tobilu/qmd || { err "QMD pnpm install failed"; return 1; }
    # Ensure pnpm global bin is on PATH for gateway LaunchAgent
    local pnpm_bin
    pnpm_bin="$(pnpm bin -g 2>/dev/null || true)"
    if [[ -n "${pnpm_bin}" && -x "${pnpm_bin}/qmd" && ! -e "/opt/homebrew/bin/qmd" ]]; then
      ln -sf "${pnpm_bin}/qmd" /opt/homebrew/bin/qmd 2>/dev/null || true
    fi
  elif command -v bun >/dev/null 2>&1; then
    info "installing QMD via bun"
    bun install -g @tobilu/qmd || { err "QMD bun install failed"; return 1; }
    # Symlink to PATH if bun bin is not accessible by gateway LaunchAgent
    local bun_qmd
    bun_qmd="$(command -v qmd 2>/dev/null || echo "${HOME}/.bun/bin/qmd")"
    if [[ -x "${bun_qmd}" && ! -e "/opt/homebrew/bin/qmd" ]]; then
      ln -sf "${bun_qmd}" /opt/homebrew/bin/qmd 2>/dev/null || true
    fi
  fi

  if ! command -v qmd >/dev/null 2>&1; then
    err "QMD binary not found after install"
    return 1
  fi
  ok "QMD installed: $(qmd --version 2>/dev/null | head -1)"
}

patch_qmd_glob_compat() {
  info "QMD --glob compatibility patch"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] patch QMD CLI for --glob alias"
    return 0
  fi

  local qmd_cli=""
  local search_dirs=(
    "$(npm root -g 2>/dev/null)/@tobilu/qmd/dist/cli/qmd.js"
    "${HOME}/.bun/install/global/node_modules/@tobilu/qmd/dist/cli/qmd.js"
  )
  for candidate in "${search_dirs[@]}"; do
    if [[ -f "${candidate}" ]]; then
      qmd_cli="${candidate}"
      break
    fi
  done

  if [[ -z "${qmd_cli}" ]]; then
    warn "QMD CLI source not found — skipping patch. Search will fall back to builtin."
    return 0
  fi

  if grep -q 'glob.*type.*string.*alias for mask' "${qmd_cli}" 2>/dev/null; then
    ok "QMD --glob patch already applied"
    return 0
  fi

  # Patch 1: Add glob option to parseArgs
  if grep -q 'mask: { type: "string" }' "${qmd_cli}"; then
    sed -i '' 's/mask: { type: "string" }, \/\/ glob pattern/mask: { type: "string" }, \/\/ glob pattern\
            glob: { type: "string" }, \/\/ glob pattern (alias for mask, OpenClaw compat)/' "${qmd_cli}"
  fi

  # Patch 2: Use glob as fallback for mask in collection add
  if grep -q 'const globPattern = cli.values.mask || DEFAULT_GLOB;' "${qmd_cli}"; then
    sed -i '' 's/const globPattern = cli.values.mask || DEFAULT_GLOB;/const globPattern = cli.values.mask || cli.values.glob || DEFAULT_GLOB;/' "${qmd_cli}"
  fi

  if grep -q 'cli.values.glob' "${qmd_cli}"; then
    ok "QMD --glob patch applied"
  else
    warn "QMD --glob patch may not have applied correctly"
  fi
}

# ============================================================================
# Workspace Bootstrap
# ============================================================================

bootstrap_workspace_memory() {
  info "workspace memory bootstrap"
  if [[ "${MEMORY_ONLY}" == "1" || "${UPDATE_MODE}" == "1" ]]; then
    dry mkdir -p "${WORKSPACE}/memory"
    ok "workspace preserved, directories prepared"
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] create ${WORKSPACE}/MEMORY.md and memory dirs"
    return 0
  fi

  mkdir -p "${WORKSPACE}/memory"
  if [[ ! -f "${WORKSPACE}/MEMORY.md" ]]; then
    cat > "${WORKSPACE}/MEMORY.md" <<'MEMEOF'
# MEMORY.md

Long-term memory root. Stores user preferences, durable decisions, and important context.
MEMEOF
    ok "MEMORY.md created"
  else
    ok "MEMORY.md exists — preserved"
  fi
}

write_default_boot_template() {
  cat <<'EOF'
# BOOT.md — Gateway Startup Checklist

Run automatically when the gateway (re)starts.

## 1. Context Recovery
- Read `SESSION-STATE.md`
- Read latest daily logs from `memory/` (today + yesterday)

## 2. Infrastructure Check
- `openclaw memory status` — verify memory-core + QMD active
- `openclaw wiki status` — verify wiki vault ready
- `openclaw gateway status` — verify gateway running

## 3. Dreaming
- Runs on schedule (default: 3AM). No manual check needed.
- After first sweep, verify `DREAMS.md` was created.

## 4. Resume Work
- Search memory for in-progress work
- Resume if found, otherwise report and wait
EOF
}

ensure_boot_md() {
  local target_file="${WORKSPACE}/BOOT.md"
  info "BOOT.md check"
  if [[ -f "${target_file}" ]]; then
    ok "BOOT.md exists — preserved"
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] create ${target_file}"
    return 0
  fi
  mkdir -p "${WORKSPACE}"
  if [[ -f "${BOOT_TEMPLATE_LOCAL}" ]]; then
    cp "${BOOT_TEMPLATE_LOCAL}" "${target_file}"
  else
    write_default_boot_template > "${target_file}"
  fi
  ok "BOOT.md created"
}

# ============================================================================
# OpenClaw Config Patching
# ============================================================================

patch_openclaw_config() {
  info "OpenClaw config: memory-core + QMD + dreaming + wiki"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] patch ${CONFIG_FILE}"
    return 0
  fi

  mkdir -p "${CONFIG_DIR}"
  [[ -f "${CONFIG_FILE}" ]] || printf '{}\n' > "${CONFIG_FILE}"

  OC_PATH="${CONFIG_FILE}" \
  DREAM_TZ="${DREAMING_TIMEZONE}" \
  DREAM_FREQ="${DREAMING_FREQUENCY}" \
  QMD_MODE="${QMD_SEARCH_MODE}" \
  QMD_TIMEOUT="${QMD_TIMEOUT_MS}" \
  WIKI_PATH="${WIKI_VAULT_PATH}" \
  node - <<'JSEOF'
const fs = require("fs");
const path = process.env.OC_PATH;
const raw = fs.readFileSync(path, "utf8");
const c = raw.trim() ? JSON.parse(raw) : {};

// Top-level memory config (QMD backend)
c.memory = c.memory || {};
c.memory.backend = "qmd";
c.memory.citations = c.memory.citations || "auto";
c.memory.qmd = c.memory.qmd || {};
Object.assign(c.memory.qmd, {
  includeDefaultMemory: true,
  searchMode: process.env.QMD_MODE || "search",
  update: { interval: "5m", debounceMs: 15000, onBoot: true },
  limits: { maxResults: 6, timeoutMs: parseInt(process.env.QMD_TIMEOUT) || 8000 },
  scope: { "default": "allow" },
});

// Plugin allowlist
c.plugins = c.plugins || {};
c.plugins.allow = Array.isArray(c.plugins.allow) ? c.plugins.allow : [];
for (const name of ["memory-core", "memory-wiki"]) {
  if (!c.plugins.allow.includes(name)) c.plugins.allow.unshift(name);
}
c.plugins.allow = c.plugins.allow.filter(n => n !== "memory-v3");

// Active memory slot
c.plugins.slots = c.plugins.slots || {};
c.plugins.slots.memory = "memory-core";

// Plugin entries
c.plugins.entries = c.plugins.entries || {};

c.plugins.entries["memory-core"] = {
  enabled: true,
  config: {
    dreaming: {
      enabled: true,
      timezone: process.env.DREAM_TZ || "Asia/Seoul",
      frequency: process.env.DREAM_FREQ || "0 3 * * *",
    },
  },
};

c.plugins.entries["memory-wiki"] = {
  enabled: true,
  config: {
    vaultMode: "isolated",
    vault: { path: process.env.WIKI_PATH || "~/.openclaw/wiki/main" },
    bridge: { enabled: false },
    ingest: { autoCompile: true, maxConcurrentJobs: 1 },
    search: { backend: "shared", corpus: "wiki" },
    context: { includeCompiledDigestPrompt: false },
    render: { preserveHumanBlocks: true, createBacklinks: true, createDashboards: true },
  },
};

// Disable memory-v3 if present
if (c.plugins.entries["memory-v3"]) {
  c.plugins.entries["memory-v3"].enabled = false;
}

fs.writeFileSync(path, JSON.stringify(c, null, 2));
JSEOF
  chmod 600 "${CONFIG_FILE}"
  ok "config patched: memory-core + QMD + dreaming + wiki"
}

# ============================================================================
# Bundled Hooks + Token (atomic — both land in the same write to prevent
# the gateway from observing hooks.enabled=true without a token, which would
# otherwise trigger crash-loop on config hot-reload)
# ============================================================================

enable_bundled_hooks() {
  info "bundled hooks + token check"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] enable hooks (atomic with token)"
    return 0
  fi
  [[ -f "${CONFIG_FILE}" ]] || return 0

  OC_PATH="${CONFIG_FILE}" node - <<'JSEOF'
const fs = require("fs");
const crypto = require("crypto");
const path = process.env.OC_PATH;
const raw = fs.readFileSync(path, "utf8");
const c = raw.trim() ? JSON.parse(raw) : {};
c.hooks = c.hooks || {};
// Token MUST be present before enabled flips on; set token first in object,
// then write atomically so the gateway never observes enabled=true without a token.
if (typeof c.hooks.token !== "string" || c.hooks.token.length < 32) {
  c.hooks.token = crypto.randomBytes(24).toString("hex");
}
c.hooks.enabled = true;
c.hooks.internal = c.hooks.internal || {};
c.hooks.internal.enabled = true;
const entries = c.hooks.internal.entries = c.hooks.internal.entries || {};
for (const key of ["boot-md", "command-logger", "session-memory", "pre-action-reminder"]) {
  entries[key] = entries[key] || {};
  entries[key].enabled = true;
}
fs.writeFileSync(path, JSON.stringify(c, null, 2));
JSEOF
  ok "bundled hooks enabled with hooks.token"
}

# ============================================================================
# Wiki Initialization
# ============================================================================

init_wiki_vault() {
  info "memory-wiki vault initialization"
  if [[ -d "${WIKI_VAULT_PATH}/.openclaw-wiki" ]]; then
    ok "wiki vault already initialized"
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] openclaw wiki init"
    return 0
  fi
  local oc_bin
  oc_bin="$(resolve_openclaw_bin 2>/dev/null || true)"
  if [[ -z "${oc_bin}" ]]; then
    warn "openclaw binary not found — skipping wiki init"
    return 0
  fi
  "${oc_bin}" wiki init 2>/dev/null || true
  if [[ -d "${WIKI_VAULT_PATH}" ]]; then
    ok "wiki vault initialized: ${WIKI_VAULT_PATH}"
  else
    warn "wiki init may have failed — verify with 'openclaw wiki status'"
  fi
}

# ============================================================================
# Gateway Management
# ============================================================================

restart_openclaw_gateway() {
  info "OpenClaw gateway restart"
  local oc_bin
  oc_bin="$(resolve_openclaw_bin 2>/dev/null || true)"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] gateway restart"
    return 0
  fi
  if [[ -z "${oc_bin}" ]]; then
    warn "openclaw binary not found — skipping gateway restart"
    return 0
  fi

  "${oc_bin}" gateway stop >/dev/null 2>&1 || true
  sleep 2

  # Reinstall plist to ensure correct binary path
  rm -f "${LAUNCH_AGENTS_DIR}/ai.openclaw.gateway.plist" 2>/dev/null || true
  "${oc_bin}" gateway install >/dev/null 2>&1 || true
  "${oc_bin}" gateway start >/dev/null 2>&1 || true

  if wait_for_gateway_health 15; then
    ok "gateway started"
    return 0
  fi

  warn "launchd gateway failed — manual fallback"
  start_gateway_manual_fallback "${oc_bin}"
  if wait_for_gateway_health 15; then
    warn "gateway started via manual fallback"
    return 0
  fi

  err "gateway start failed — run 'openclaw gateway install --force && openclaw gateway start'"
  return 1
}

patch_gateway_throttle_interval() {
  local gateway_plist="${LAUNCH_AGENTS_DIR}/ai.openclaw.gateway.plist"
  [[ -f "${gateway_plist}" ]] || return 0
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ThrottleInterval >= 45"
    return 0
  fi
  local throttle
  throttle="$(/usr/libexec/PlistBuddy -c 'Print :ThrottleInterval' "${gateway_plist}" 2>/dev/null || true)"
  if [[ -z "${throttle}" ]]; then
    /usr/libexec/PlistBuddy -c 'Add :ThrottleInterval integer 45' "${gateway_plist}" >/dev/null 2>&1 || true
  elif [[ "${throttle}" =~ ^[0-9]+$ ]] && (( throttle < 45 )); then
    /usr/libexec/PlistBuddy -c 'Set :ThrottleInterval 45' "${gateway_plist}" >/dev/null 2>&1 || true
  fi
}

# ============================================================================
# Security
# ============================================================================

ensure_exec_approvals_security() {
  local approvals_file="${CONFIG_DIR}/exec-approvals.json"
  info "exec-approvals.json security check"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ensure exec-approvals defaults"
    return 0
  fi

  python3 - "${approvals_file}" <<'PYEOF'
import json, os, secrets, sys
path = sys.argv[1]
home = os.environ.get("HOME", os.path.expanduser("~"))
default_socket_path = os.path.join(home, ".openclaw", "exec-approvals.sock")
if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as fh:
        try: obj = json.load(fh)
        except: obj = {}
else:
    obj = {}
changed = False
if obj.get("version") != 1: obj["version"] = 1; changed = True
socket = obj.setdefault("socket", {})
if not socket.get("path"): socket["path"] = default_socket_path; changed = True
if not socket.get("token"): socket["token"] = secrets.token_hex(24); changed = True
defaults = obj.setdefault("defaults", {})
for key, want in (("security", "full"), ("ask", "off"), ("askFallback", "full")):
    if defaults.get(key) != want: defaults[key] = want; changed = True
if "agents" not in obj: obj["agents"] = {}; changed = True
if not changed: sys.exit(0)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(obj, fh, indent=2, ensure_ascii=False); fh.write("\n")
PYEOF
  chmod 600 "${approvals_file}"
  ok "exec-approvals.json configured"
}

# ============================================================================
# Google API Key (optional — embedding fallback)
# ============================================================================

has_google_api_key() {
  config_json_value 'env.vars.GOOGLE_API_KEY' 2>/dev/null | grep -q '.' && return 0
  config_json_value 'models.providers.google.apiKey' 2>/dev/null | grep -q '.' && return 0
  [[ -n "${GOOGLE_API_KEY:-}" ]] && return 0
  return 1
}

configure_optional_google_api_key() {
  info "Google API key check (optional — embedding fallback)"
  if has_google_api_key; then
    ok "Google API key already configured"
    return 0
  fi
  if [[ "${GOOGLE_API_KEY_MODE}" == "skip" ]]; then
    ok "Google API key skipped"
    GOOGLE_API_KEY_SKIPPED_BY_USER=1
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] prompt for optional Google API key"
    return 0
  fi

  echo ""
  printf '%b\n' "${CYAN}[Optional] Google Gemini API Key${NC}"
  echo "  QMD handles search locally — no API key required."
  echo "  A Gemini key enables additional embedding fallback."
  echo ""
  printf "  Enter Gemini API key (or press Enter to skip): "
  if [[ -t 0 ]]; then
    read -r api_key
  else
    read -r api_key < /dev/tty
  fi

  if [[ -z "${api_key}" ]]; then
    ok "Google API key skipped"
    GOOGLE_API_KEY_SKIPPED_BY_USER=1
    return 0
  fi

  OC_PATH="${CONFIG_FILE}" GKEY="${api_key}" node - <<'JSEOF'
const fs = require("fs");
const path = process.env.OC_PATH;
const raw = fs.readFileSync(path, "utf8");
const c = raw.trim() ? JSON.parse(raw) : {};
c.env = c.env || {};
c.env.vars = c.env.vars || {};
c.env.vars.GOOGLE_API_KEY = process.env.GKEY;
c.models = c.models || {};
c.models.providers = c.models.providers || {};
c.models.providers.google = c.models.providers.google || {};
c.models.providers.google.apiKey = process.env.GKEY;
fs.writeFileSync(path, JSON.stringify(c, null, 2));
JSEOF
  ok "Google API key configured"
}

# ============================================================================
# Health Check
# ============================================================================

health_check_memory() {
  info "core memory stack health check"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] health check"
    return 0
  fi

  local oc_bin
  oc_bin="$(resolve_openclaw_bin 2>/dev/null || true)"
  if [[ -z "${oc_bin}" ]]; then
    warn "openclaw binary not found — skipping health check"
    return 0
  fi

  if ! wait_for_gateway_health 20; then
    err "gateway not responding"
    return 1
  fi
  ok "gateway responding"

  local mem_status
  mem_status="$("${oc_bin}" memory status 2>&1 || true)"

  if echo "${mem_status}" | grep -q "Provider: qmd"; then
    ok "QMD provider active"
  elif echo "${mem_status}" | grep -q "Provider:"; then
    ok "memory search active (builtin fallback)"
  else
    warn "memory provider unclear — verify with 'openclaw memory status'"
  fi

  if echo "${mem_status}" | grep -q "Dreaming:"; then
    ok "dreaming configured"
  fi

  local wiki_status
  wiki_status="$("${oc_bin}" wiki status 2>&1 || true)"
  if echo "${wiki_status}" | grep -q "Vault: ready"; then
    ok "wiki vault ready"
  else
    warn "wiki status unclear — verify with 'openclaw wiki status'"
  fi

  ok "health check passed"
}

# ============================================================================
# V3 Cleanup (removes old Memory V3 launchd services if present)
# ============================================================================

cleanup_v3_services() {
  info "checking for old Memory V3 services"

  local v3_labels=(
    "ai.openclaw.memory-v3-api"
    "ai.openclaw.memory-v3-atomize"
    "ai.openclaw.memory-v3-flush"
    "ai.openclaw.memory-v3-snapshot"
    "ai.openclaw.memory-v3-eviction"
    "ai.openclaw.memory-v3-distill"
    "ai.openclaw.memory-v3-weekly"
    "ai.openclaw.memory-v3-llm-atomize"
    "ai.openclaw.memory-v3-backfill-ko"
  )

  local found=0
  for label in "${v3_labels[@]}"; do
    [[ -f "${LAUNCH_AGENTS_DIR}/${label}.plist" ]] && found=1 && break
  done

  if [[ "${found}" == "0" ]]; then
    ok "no V3 services found"
    return 0
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] remove V3 service plists"
    return 0
  fi

  info "removing old Memory V3 launchd services"
  local uid
  uid="$(id -u)"
  for label in "${v3_labels[@]}"; do
    local plist="${LAUNCH_AGENTS_DIR}/${label}.plist"
    if [[ -f "${plist}" ]]; then
      launchctl bootout "gui/${uid}/${label}" 2>/dev/null || true
      rm -f "${plist}"
      ok "removed: ${label}"
    fi
  done
}

# ============================================================================
# Version Stamp
# ============================================================================

write_clawnode_version_stamp() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] write ${CLAWNODE_VERSION_FILE}"
    return 0
  fi
  cat > "${CLAWNODE_VERSION_FILE}" <<STAMPEOF
CHANNEL=v5
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CORE_STEP_RESULT=${CORE_STEP_RESULT}
UPDATE_MODE=${UPDATE_MODE}
MEMORY_BACKEND=qmd
DREAMING_FREQUENCY=${DREAMING_FREQUENCY}
DREAMING_TIMEZONE=${DREAMING_TIMEZONE}
INSTALLER_URL=${INSTALLER_V5_URL}
STAMPEOF
  chmod 600 "${CLAWNODE_VERSION_FILE}"
  ok "version stamp written"
}

# ============================================================================
# Main
# ============================================================================

main() {
  ensure_homebrew_on_path || true
  prepare_installer_assets
  require_existing_core_for_memory_only

  if [[ ! -f "${CORE_SCRIPT}" ]]; then
    err "core script not found: ${CORE_SCRIPT}"
    exit 1
  fi

  stage "Core"
  run_core_setup

  stage "QMD"
  install_qmd
  patch_qmd_glob_compat

  stage "Runtime"
  bootstrap_workspace_memory
  ensure_boot_md
  patch_openclaw_config
  enable_bundled_hooks

  stage "Wiki"
  init_wiki_vault

  stage "Post-Wizard"
  ensure_exec_approvals_security
  configure_optional_google_api_key

  stage "V3 Cleanup"
  cleanup_v3_services

  stage "Gateway"
  restart_openclaw_gateway
  patch_gateway_throttle_interval

  stage "Verify"
  health_check_memory

  write_clawnode_version_stamp
  render_final_summary

  ok "setup v5 core memory stack complete"
}

main "$@"
