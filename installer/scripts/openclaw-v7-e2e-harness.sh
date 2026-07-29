#!/usr/bin/env bash
set -euo pipefail

# Operator-only harness for OpenClaw installer v7 E2E.
# This is intentionally separate from the customer-facing installer.

REMOTE="${REMOTE:-yongwon@100.123.92.57}"
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-8}"
EVIDENCE_DIR="${EVIDENCE_DIR:-.omx/ultragoal/evidence/e2e}"
INSTALLER_URL="${INSTALLER_URL:-}"
INSTALLER_LOCAL="${INSTALLER_LOCAL:-}"
INSTALLER_SHA256="${INSTALLER_SHA256:-}"
E2E_ALLOW_DESTRUCTIVE="${E2E_ALLOW_DESTRUCTIVE:-0}"
AUTH_CHOICE="${AUTH_CHOICE:-}"
AUTH_SECRET_ENV="${AUTH_SECRET_ENV:-}"
AUTH_SECRET_FILE="${AUTH_SECRET_FILE:-}"
GEMINI_SECRET_ENV="${GEMINI_SECRET_ENV:-}"
GEMINI_SECRET_FILE="${GEMINI_SECRET_FILE:-}"
RUN_PROMPT_SMOKE="${RUN_PROMPT_SMOKE:-0}"
RUN_IMAGE_SMOKE="${RUN_IMAGE_SMOKE:-0}"
PROMPT_SMOKE_TEXT="${PROMPT_SMOKE_TEXT:-1+1을 한 문장으로 답해줘.}"
PROMPT_SMOKE_TIMEOUT="${PROMPT_SMOKE_TIMEOUT:-120}"
PROMPT_SMOKE_AGENT="${PROMPT_SMOKE_AGENT:-main}"
PROMPT_SMOKE_SESSION_KEY="${PROMPT_SMOKE_SESSION_KEY:-agent:main:installer-v7-smoke}"
MEMORY_ENGINE="${MEMORY_ENGINE:-auto}"
ENABLE_MEMORY_LANCEDB="${ENABLE_MEMORY_LANCEDB:-1}"
LANCEDB_EMBEDDING_PROVIDER="${LANCEDB_EMBEDDING_PROVIDER:-auto}"
ENABLE_SKILL_WORKSHOP="${ENABLE_SKILL_WORKSHOP:-1}"
EXPECT_MEMORY_LANCEDB="${EXPECT_MEMORY_LANCEDB:-auto}"
EXPECT_CODEX_HARNESS="${EXPECT_CODEX_HARNESS:-1}"
CODEX_COMPUTER_USE_MARKETPLACE_PATH="${CODEX_COMPUTER_USE_MARKETPLACE_PATH:-/Applications/Codex.app/Contents/Resources/plugins/openai-bundled/.agents/plugins/marketplace.json}"
IMAGE_GENERATION_MODEL="${IMAGE_GENERATION_MODEL:-google/gemini-3-pro-image-preview}"
EXPECTED_OPENCLAW_VERSION="${EXPECTED_OPENCLAW_VERSION:-2026.7.1}"
EXPECTED_DEFAULT_MODEL="${EXPECTED_DEFAULT_MODEL:-openai/gpt-5.6-sol}"
EXPECTED_CODEX_VERSION="${EXPECTED_CODEX_VERSION:-2026.7.1}"
EXPECTED_CODEX_CLI_VERSION="${EXPECTED_CODEX_CLI_VERSION:-0.144.3}"
EXPECTED_LANCEDB_VERSION="${EXPECTED_LANCEDB_VERSION:-2026.7.1}"
MANUAL_AUTH_CHOICE="${MANUAL_AUTH_CHOICE:-openai-codex-device-code}"
MANUAL_PROMPT_SMOKE_SESSION_KEY="${MANUAL_PROMPT_SMOKE_SESSION_KEY:-agent:main:installer-v7-manual}"
DEFAULT_INSTALLER_URL="https://gist.githubusercontent.com/VictorJeon/d5a5759cd69f9ed73e087512f7af65d8/raw/openclaw-setup-v7.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok() { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err() { printf "${RED}[ERR ]${NC} %s\n" "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage:
  openclaw-v7-e2e-harness.sh <command>

Commands:
  preflight          Capture SSH-safe remote metadata.
  reset              Destructive OpenClaw reset/cleanup. Requires E2E_ALLOW_DESTRUCTIVE=1.
  stage-credentials  Stage one test credential on the remote with masked local evidence.
  install            Run v7 installer from INSTALLER_URL or INSTALLER_LOCAL.
  verify             Run OpenClaw post-install checks.
  manual-login       Run the public v7 installer interactively for browser/device login.
  final-verify       Run final post-manual-login verification with prompt smoke enabled.
  e2e                Run preflight -> reset -> stage-credentials -> install -> verify.
  cleanup-staged     Remove harness-staged credential files from the remote.

Important environment:
  REMOTE=yongwon@100.123.92.57
  INSTALLER_URL=https://gist.githubusercontent.com/.../raw/openclaw-setup-v7.sh
  INSTALLER_LOCAL=installer/scripts/openclaw-setup-v7.sh
  INSTALLER_SHA256=64-character-lowercase-sha256
  AUTH_CHOICE=openai-api-key|openai-codex-api-key|setup-token|...
  AUTH_SECRET_ENV=ENV_VAR_NAME_CONTAINING_SECRET
  AUTH_SECRET_FILE=/path/to/secret-file
  GEMINI_SECRET_ENV=GEMINI_API_KEY
  GEMINI_SECRET_FILE=/path/to/gemini-api-key
  E2E_ALLOW_DESTRUCTIVE=1
  RUN_PROMPT_SMOKE=1
  RUN_IMAGE_SMOKE=1
  CODEX_COMPUTER_USE_MARKETPLACE_PATH=/Applications/Codex.app/Contents/Resources/plugins/openai-bundled/.agents/plugins/marketplace.json
  MEMORY_ENGINE=auto|qmd|builtin|lancedb
  EXPECT_MEMORY_LANCEDB=auto|0|1
  MANUAL_AUTH_CHOICE=openai-codex-device-code
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "missing command: $1"
    exit 1
  }
}

ensure_evidence_dir() {
  mkdir -p "${EVIDENCE_DIR}"
}

timestamp() {
  date -u +"%Y%m%dT%H%M%SZ"
}

cache_busted_url() {
  local url="$1"
  local separator="?"
  [[ "${url}" == *\?* ]] && separator="&"
  printf '%s%scodex_e2e_ts=%s\n' "${url}" "${separator}" "$(date +%s)"
}

ssh_base() {
  ssh -o BatchMode=yes -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" "$@"
}

ssh_remote() {
  ssh_base "${REMOTE}" "$@"
}

scp_to_remote() {
  scp -q -o BatchMode=yes -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" "$1" "${REMOTE}:$2"
}

mask_file() {
  local file="$1"
  local size sha
  size="$(wc -c < "${file}" | tr -d ' ')"
  sha="$(shasum -a 256 "${file}" | awk '{print $1}')"
  printf 'len=%s sha256=%s\n' "${size}" "${sha:0:16}..."
}

require_destructive() {
  if [[ "${E2E_ALLOW_DESTRUCTIVE}" != "1" ]]; then
    err "destructive command blocked. Set E2E_ALLOW_DESTRUCTIVE=1 after confirming SSH preservation."
    exit 2
  fi
}

preflight() {
  require_cmd ssh
  ensure_evidence_dir
  local out
  out="${EVIDENCE_DIR}/preflight-$(timestamp).txt"
  info "capturing remote SSH-safe metadata: ${REMOTE}"
  ssh_remote 'bash -s' > "${out}" <<'REMOTE'
set -euo pipefail
export PATH="${HOME}/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}"
printf 'host=%s\n' "$(hostname)"
printf 'user=%s\n' "$(whoami)"
printf 'os=%s\n' "$(sw_vers -productVersion 2>/dev/null || uname -s)"
printf 'arch=%s\n' "$(uname -m)"
if [[ -f "${HOME}/.ssh/authorized_keys" ]]; then
  stat -f 'authorized_keys_mode=%Lp size=%z mtime=%Sm' "${HOME}/.ssh/authorized_keys" 2>/dev/null || true
  shasum -a 256 "${HOME}/.ssh/authorized_keys" | awk '{print "authorized_keys_sha256=" $1}'
else
  printf 'authorized_keys=missing\n'
fi
if command -v openclaw >/dev/null 2>&1; then
  openclaw --version 2>/dev/null | sed 's/^/openclaw_version=/'
else
  printf 'openclaw_version=missing\n'
fi
if command -v node >/dev/null 2>&1; then
  node --version | sed 's/^/node_version=/'
else
  printf 'node_version=missing\n'
fi
REMOTE
  cat "${out}"
  ok "preflight saved: ${out}"
}

remote_assert_ssh_assets() {
  # shellcheck disable=SC2016
  ssh_remote 'test -d "$HOME/.ssh" && test -f "$HOME/.ssh/authorized_keys"'
}

reset_remote() {
  require_destructive
  ensure_evidence_dir
  info "running pre-reset SSH check"
  preflight >/dev/null
  remote_assert_ssh_assets
  info "running destructive OpenClaw reset without touching SSH/network/Tailscale"
  ssh_remote 'bash -s' <<'REMOTE'
set -euo pipefail
export PATH="${HOME}/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}"

deny_if_path_is_ssh() {
  case "$1" in
    "$HOME/.ssh"|"$HOME/.ssh/"*|"$HOME/.ssh/authorized_keys")
      echo "refusing to touch SSH path: $1" >&2
      exit 40
      ;;
  esac
}

safe_rm() {
  local target
  for target in "$@"; do
    [[ -n "${target}" ]] || continue
    deny_if_path_is_ssh "${target}"
    rm -rf "${target}"
  done
}

if command -v openclaw >/dev/null 2>&1; then
  openclaw gateway stop >/dev/null 2>&1 || true
  openclaw reset --scope full --yes --non-interactive >/dev/null 2>&1 || true
fi

uid="$(id -u)"
find "${HOME}/Library/LaunchAgents" -maxdepth 1 -type f \
  \( -name '*openclaw*.plist' -o -name 'ai.openclaw.*.plist' -o -name 'com.openclaw.*.plist' \) \
  2>/dev/null | while IFS= read -r plist; do
    label="$(basename "${plist}" .plist)"
    launchctl bootout "gui/${uid}/${label}" >/dev/null 2>&1 || true
    launchctl unload "${plist}" >/dev/null 2>&1 || true
    rm -f "${plist}"
  done

safe_rm "${HOME}/.openclaw"
safe_rm "${HOME}/.openclaw-v7-e2e"
safe_rm "/tmp/openclaw-v7-install.sh"
safe_rm "/tmp/openclaw-v7-e2e"

mkdir -p "${HOME}/.openclaw-v7-e2e"
chmod 700 "${HOME}/.openclaw-v7-e2e"
REMOTE
  info "running post-reset SSH check"
  preflight >/dev/null
  ok "remote reset completed with SSH still reachable"
}

secret_source_file() {
  local generated_path="${1:-}"
  if [[ -n "${AUTH_SECRET_FILE}" ]]; then
    [[ -f "${AUTH_SECRET_FILE}" ]] || {
      err "AUTH_SECRET_FILE does not exist"
      exit 3
    }
    printf '%s\n' "${AUTH_SECRET_FILE}"
    return 0
  fi
  if [[ -n "${AUTH_SECRET_ENV}" ]]; then
    local value="${!AUTH_SECRET_ENV:-}"
    [[ -n "${value}" ]] || {
      err "AUTH_SECRET_ENV is set but empty: ${AUTH_SECRET_ENV}"
      exit 3
    }
    [[ -n "${generated_path}" ]] || {
      err "generated auth secret path is required"
      exit 3
    }
    (umask 077; printf '%s' "${value}" > "${generated_path}")
    printf '%s\n' "${generated_path}"
    return 0
  fi
  return 1
}

gemini_secret_source_file() {
  local generated_path="${1:-}"
  if [[ -n "${GEMINI_SECRET_FILE}" ]]; then
    [[ -f "${GEMINI_SECRET_FILE}" ]] || {
      err "GEMINI_SECRET_FILE does not exist"
      exit 3
    }
    printf '%s\n' "${GEMINI_SECRET_FILE}"
    return 0
  fi
  if [[ -n "${GEMINI_SECRET_ENV}" ]]; then
    local value="${!GEMINI_SECRET_ENV:-}"
    [[ -n "${value}" ]] || {
      err "GEMINI_SECRET_ENV is set but empty: ${GEMINI_SECRET_ENV}"
      exit 3
    }
    [[ -n "${generated_path}" ]] || {
      err "generated Gemini secret path is required"
      exit 3
    }
    (umask 077; printf '%s' "${value}" > "${generated_path}")
    printf '%s\n' "${generated_path}"
    return 0
  fi
  return 1
}

stage_credentials() {
  local stage_temp_dir status
  stage_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-v7-credentials.XXXXXX")"
  chmod 700 "${stage_temp_dir}"
  set +e
  (
    set -e
    stage_credentials_impl "${stage_temp_dir}"
  )
  status=$?
  set -e
  rm -f -- \
    "${stage_temp_dir}/auth.secret" \
    "${stage_temp_dir}/gemini.secret" \
    "${stage_temp_dir}/env"
  rmdir "${stage_temp_dir}" 2>/dev/null || true
  return "${status}"
}

stage_credentials_impl() {
  local stage_temp_dir="$1"
  ensure_evidence_dir
  [[ -n "${AUTH_CHOICE}" ]] || {
    err "AUTH_CHOICE is required for stage-credentials"
    exit 3
  }
  local src gemini_src="" env_tmp="${stage_temp_dir}/env"
  src="$(secret_source_file "${stage_temp_dir}/auth.secret")"
  gemini_src="$(gemini_secret_source_file "${stage_temp_dir}/gemini.secret" || true)"
  local evidence
  evidence="${EVIDENCE_DIR}/credential-stage-$(timestamp).txt"
  {
    printf 'auth_choice=%s\n' "${AUTH_CHOICE}"
    printf 'secret_fingerprint=%s\n' "$(mask_file "${src}")"
    if [[ -n "${gemini_src}" ]]; then
      printf 'gemini_secret_fingerprint=%s\n' "$(mask_file "${gemini_src}")"
    else
      printf 'gemini_secret=not-staged\n'
    fi
  } > "${evidence}"
  info "staging credential for ${AUTH_CHOICE}; evidence: ${evidence}"
  ssh_remote 'mkdir -p ~/.openclaw-v7-e2e/credentials && chmod 700 ~/.openclaw-v7-e2e ~/.openclaw-v7-e2e/credentials'
  scp_to_remote "${src}" ".openclaw-v7-e2e/credentials/auth.secret"
  if [[ -n "${gemini_src}" ]]; then
    scp_to_remote "${gemini_src}" ".openclaw-v7-e2e/credentials/gemini.secret"
  fi
  (umask 077; {
    printf 'OPENCLAW_E2E_AUTH_CHOICE=%q\n' "${AUTH_CHOICE}"
    # shellcheck disable=SC2016
    printf 'OPENCLAW_E2E_SECRET_FILE="${HOME}/.openclaw-v7-e2e/credentials/auth.secret"\n'
    printf 'OPENCLAW_V7_MEMORY_ENGINE=%q\n' "${MEMORY_ENGINE}"
    printf 'OPENCLAW_V7_ENABLE_MEMORY_LANCEDB=%q\n' "${ENABLE_MEMORY_LANCEDB}"
    printf 'OPENCLAW_V7_LANCEDB_EMBEDDING_PROVIDER=%q\n' "${LANCEDB_EMBEDDING_PROVIDER}"
    printf 'OPENCLAW_V7_ENABLE_SKILL_WORKSHOP=%q\n' "${ENABLE_SKILL_WORKSHOP}"
    printf 'OPENCLAW_V7_ENABLE_PREMIUM_DEFAULTS=1\n'
    printf 'OPENCLAW_V7_ENABLE_CODEX_HARNESS=%q\n' "${EXPECT_CODEX_HARNESS}"
    printf 'OPENCLAW_V7_ENABLE_CODEX_COMPUTER_USE=%q\n' "${EXPECT_CODEX_HARNESS}"
    printf 'OPENCLAW_V7_CODEX_COMPUTER_USE_MARKETPLACE_PATH=%q\n' "${CODEX_COMPUTER_USE_MARKETPLACE_PATH}"
    printf 'OPENCLAW_V7_ENABLE_IMAGE_GENERATION=1\n'
    printf 'OPENCLAW_V7_IMAGE_GENERATION_MODEL=%q\n' "${IMAGE_GENERATION_MODEL}"
    printf 'OPENCLAW_V7_IMAGE_SMOKE=%q\n' "${RUN_IMAGE_SMOKE}"
    if [[ -n "${gemini_src}" ]]; then
      # shellcheck disable=SC2016
      printf 'OPENCLAW_E2E_GEMINI_SECRET_FILE="${HOME}/.openclaw-v7-e2e/credentials/gemini.secret"\n'
    fi
  } > "${env_tmp}")
  scp_to_remote "${env_tmp}" ".openclaw-v7-e2e/env"
  ssh_remote 'chmod 600 ~/.openclaw-v7-e2e/credentials/auth.secret ~/.openclaw-v7-e2e/credentials/gemini.secret ~/.openclaw-v7-e2e/env 2>/dev/null || true'
  ok "credential staged without printing raw secret"
}

install_remote() {
  ensure_evidence_dir
  local log remote_sha download_url
  log="${EVIDENCE_DIR}/install-$(timestamp).txt"
  if [[ -n "${INSTALLER_LOCAL}" ]]; then
    [[ -f "${INSTALLER_LOCAL}" ]] || {
      err "INSTALLER_LOCAL does not exist: ${INSTALLER_LOCAL}"
      exit 4
    }
    info "copying local installer to remote"
    scp_to_remote "${INSTALLER_LOCAL}" "/tmp/openclaw-v7-install.sh"
  elif [[ -n "${INSTALLER_URL}" ]]; then
    info "downloading installer on remote from INSTALLER_URL"
    download_url="$(cache_busted_url "${INSTALLER_URL}")"
    ssh_remote "curl -fsSL '${download_url}' -o /tmp/openclaw-v7-install.sh && chmod 700 /tmp/openclaw-v7-install.sh"
  else
    err "INSTALLER_URL or INSTALLER_LOCAL is required"
    exit 4
  fi

  if [[ -n "${INSTALLER_SHA256}" ]]; then
    [[ "${INSTALLER_SHA256}" =~ ^[0-9a-f]{64}$ ]] || {
      err "INSTALLER_SHA256 must be a 64-character lowercase SHA-256 digest"
      exit 4
    }
    remote_sha="$(ssh_remote 'shasum -a 256 /tmp/openclaw-v7-install.sh')"
    remote_sha="${remote_sha%% *}"
    [[ "${remote_sha}" == "${INSTALLER_SHA256}" ]] || {
      err "remote installer SHA mismatch: expected=${INSTALLER_SHA256} actual=${remote_sha}"
      exit 4
    }
    ok "remote installer SHA verified: ${remote_sha}"
  fi

  info "running installer on remote; log: ${log}"
  # shellcheck disable=SC2016
  ssh_remote 'bash -lc '"'"'
set -euo pipefail
if [[ -f "${HOME}/.openclaw-v7-e2e/env" ]]; then
  set -a
  source "${HOME}/.openclaw-v7-e2e/env"
  set +a
fi
bash /tmp/openclaw-v7-install.sh
'"'"'' > "${log}" 2>&1
  ok "installer run completed"
}

verify_remote() {
  ensure_evidence_dir
  local log
  log="${EVIDENCE_DIR}/verify-$(timestamp).txt"
  info "running remote verification; log: ${log}"
ssh_remote 'bash -s' > "${log}" 2>&1 <<REMOTE
set -euo pipefail
export PATH="\${HOME}/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:\${PATH}"
if [[ -r "\${HOME}/.openclaw/setup-v7/shell-env" ]]; then
  set -a
  source "\${HOME}/.openclaw/setup-v7/shell-env"
  set +a
elif [[ -r "\${HOME}/.openclaw/service-env/ai.openclaw.gateway.env" ]]; then
  set -a
  source "\${HOME}/.openclaw/service-env/ai.openclaw.gateway.env"
  set +a
fi
command -v openclaw
version_line="\$(openclaw --version)"
printf '%s\n' "\${version_line}"
[[ "\${version_line}" == *"${EXPECTED_OPENCLAW_VERSION}"* ]]
openclaw gateway status --require-rpc
openclaw health --json --timeout 10000
openclaw config validate
openclaw plugins registry --refresh >/dev/null
if [[ "${EXPECT_CODEX_HARNESS}" == "1" ]]; then
  codex_inspect="\$(mktemp)"
  openclaw plugins inspect codex --runtime --json | tee "\${codex_inspect}"
  python3 - "\${codex_inspect}" "${EXPECTED_CODEX_VERSION}" <<'PYCODEX'
import json, pathlib, sys
raw = pathlib.Path(sys.argv[1]).read_text()
data = json.loads(raw[raw.find("{"):])
assert data.get("plugin", {}).get("version") == sys.argv[2], data
assert data.get("install", {}).get("source") == "npm", data
diagnostics = []
for collection in (data.get("diagnostics"), (data.get("runtime") or {}).get("diagnostics")):
    if isinstance(collection, list):
        diagnostics.extend(
            item for item in collection
            if isinstance(item, dict) and item.get("level") in {"warn", "error"}
        )
assert not diagnostics, diagnostics
print("codex_version_ok=true")
PYCODEX
  rm -f "\${codex_inspect}"
  codex_cli_command="\${HOME}/.npm-global/bin/codex"
  test -x "\${codex_cli_command}"
  codex_cli_version="\$("\${codex_cli_command}" --version)"
  [[ "\${codex_cli_version}" == *"${EXPECTED_CODEX_CLI_VERSION}"* ]]
  test -f "${CODEX_COMPUTER_USE_MARKETPLACE_PATH}"
fi
openclaw plugins inspect memory-wiki
openclaw wiki status --json
openclaw wiki doctor --json
python3 - "\${HOME}/.openclaw/openclaw.json" <<'PY'
import json, pathlib, sys
cfg = json.loads(pathlib.Path(sys.argv[1]).read_text())
defaults = cfg.get("agents", {}).get("defaults", {})
assert defaults.get("model") == "${EXPECTED_DEFAULT_MODEL}", defaults.get("model")
assert defaults.get("thinkingDefault") == "xhigh", defaults.get("thinkingDefault")
assert defaults.get("reasoningDefault") == "stream", defaults.get("reasoningDefault")
assert defaults.get("blockStreamingDefault") == "on", defaults.get("blockStreamingDefault")
assert cfg.get("messages", {}).get("queue", {}).get("mode") == "steer"
assert defaults.get("models", {}).get("${EXPECTED_DEFAULT_MODEL}", {}).get("params", {}).get("fastMode") is True
assert defaults.get("imageGenerationModel", {}).get("primary") == "${IMAGE_GENERATION_MODEL}"
tools = cfg.get("tools", {})
assert tools.get("profile") == "full", tools.get("profile")
assert tools.get("exec", {}).get("host") == "gateway"
assert tools.get("exec", {}).get("security") == "full"
assert tools.get("exec", {}).get("ask") == "off"
assert tools.get("elevated", {}).get("enabled") is True
if "${EXPECT_CODEX_HARNESS}" == "1":
    codex = cfg.get("plugins", {}).get("entries", {}).get("codex", {})
    assert codex.get("enabled") is True
    app_server = codex.get("config", {}).get("appServer", {})
    assert app_server.get("command") == str(pathlib.Path.home() / ".npm-global/bin/codex"), app_server.get("command")
    computer_use = codex.get("config", {}).get("computerUse", {})
    assert computer_use.get("enabled") is True
    assert computer_use.get("autoInstall") is True
    assert computer_use.get("marketplacePath") == "${CODEX_COMPUTER_USE_MARKETPLACE_PATH}", computer_use.get("marketplacePath")
print("premium_config_ok=true")
PY
active_memory_slot="\$(python3 - "\${HOME}/.openclaw/openclaw.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
print(json.loads(path.read_text()).get("plugins", {}).get("slots", {}).get("memory", ""))
PY
)"
printf 'active_memory_slot=%s\n' "\${active_memory_slot}"
expected_lancedb=0
if [[ "${EXPECT_MEMORY_LANCEDB}" == "1" ]]; then
  expected_lancedb=1
elif [[ "${EXPECT_MEMORY_LANCEDB}" == "auto" && "${AUTH_CHOICE}" == "openai-api-key" && "${MEMORY_ENGINE}" != "qmd" && "${MEMORY_ENGINE}" != "builtin" && "${ENABLE_MEMORY_LANCEDB}" == "1" ]]; then
  expected_lancedb=1
fi
if [[ "\${active_memory_slot}" == "memory-lancedb" ]]; then
  lancedb_inspect="\$(mktemp)"
  openclaw plugins inspect memory-lancedb --runtime --json | tee "\${lancedb_inspect}"
  python3 - "\${lancedb_inspect}" "${EXPECTED_LANCEDB_VERSION}" <<'PYLANCEDB'
import json, pathlib, sys
raw = pathlib.Path(sys.argv[1]).read_text()
data = json.loads(raw[raw.find("{"):])
assert data.get("plugin", {}).get("version") == sys.argv[2], data
diagnostics = [item for item in data.get("diagnostics", []) if item.get("level") in {"warn", "error"}]
assert not diagnostics, diagnostics
print("lancedb_version_ok=true")
PYLANCEDB
  rm -f "\${lancedb_inspect}"
  openclaw ltm stats
elif [[ "\${expected_lancedb}" == "1" ]]; then
  echo "expected memory-lancedb active slot, got \${active_memory_slot}" >&2
  exit 42
fi
if [[ "${ENABLE_SKILL_WORKSHOP}" == "1" ]]; then
  openclaw skills workshop --help >/dev/null
  openclaw skills workshop list
fi
openai_models="\$(mktemp)"
openclaw models list --all --provider openai --json > "\${openai_models}"
python3 - "\${openai_models}" "${EXPECTED_DEFAULT_MODEL}" <<'PYMODELS'
import json, pathlib, sys
raw = pathlib.Path(sys.argv[1]).read_text()
data = json.loads(raw[raw.find("{"):])
assert any(model.get("key") == sys.argv[2] for model in data.get("models", [])), sys.argv[2]
print("default_model_catalog_ok=true")
PYMODELS
rm -f "\${openai_models}"
openclaw models list --provider google
openclaw skills list >/dev/null
secrets_audit_file="\$(mktemp)"
openclaw secrets audit --json > "\${secrets_audit_file}" 2>&1 || true
python3 - "\${secrets_audit_file}" <<'PYSECRETS'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
raw = path.read_text()
start = raw.find("{")
end = raw.rfind("}")
if start == -1 or end == -1 or end < start:
    raise SystemExit("secrets audit output did not contain JSON")
data = json.loads(raw[start:end + 1])
bad = []
for finding in data.get("findings", []):
    if finding.get("code") == "LEGACY_RESIDUE":
        continue
    if (
        finding.get("code") == "PLAINTEXT_FOUND"
        and finding.get("jsonPath") == "providers.codex.apiKey"
        and str(finding.get("file") or "").endswith("/models.json")
    ):
        try:
            models = json.loads(pathlib.Path(finding["file"]).read_text())
            value = models.get("providers", {}).get("codex", {}).get("apiKey")
        except Exception:
            value = None
        if value == "codex-app-server":
            continue
    bad.append(finding)
if bad:
    for finding in bad[:8]:
        print(f"{finding.get('code')}: {finding.get('file')} {finding.get('jsonPath')} {finding.get('message')}", file=sys.stderr)
    raise SystemExit(f"disallowed_secrets_findings={len(bad)}")
print("secrets_audit_ok=true")
PYSECRETS
rm -f "\${secrets_audit_file}"
for f in MEMORY.md PROJECT-STATE.md BOOT.md SOUL.md AGENTS.md; do
  test -f "\${HOME}/.openclaw/workspace/\${f}"
done
test -d "\${HOME}/.openclaw/workspace/memory"
test -d "\${HOME}/.openclaw/wiki/main"
command -v qmd
qmd --version
doctor_preflight="\$(mktemp)"
if ! openclaw doctor --lint --json --severity-min warning > "\${doctor_preflight}" 2>&1; then
  python3 - "\${HOME}/.openclaw/openclaw.json" "\${doctor_preflight}" <<'PY'
import json, pathlib, re, sys

config_path = pathlib.Path(sys.argv[1])
doctor_path = pathlib.Path(sys.argv[2])
raw = doctor_path.read_text()
start = raw.find("{")
end = raw.rfind("}")
if start == -1 or end == -1 or end < start:
    raise SystemExit("doctor output did not contain a JSON object")
data = json.loads(raw[start : end + 1])
skills = []
for finding in data.get("findings", []):
    if finding.get("checkId") != "core/doctor/skills-readiness":
        continue
    match = re.fullmatch(r"skills\.entries\.([^.]+)\.enabled", finding.get("path") or "")
    if match:
        skills.append(match.group(1))
if skills:
    cfg = json.loads(config_path.read_text())
    entries = cfg.setdefault("skills", {}).setdefault("entries", {})
    for skill in sorted(set(skills)):
        value = entries.get(skill)
        if not isinstance(value, dict):
            value = {}
        value["enabled"] = False
        entries[skill] = value
    config_path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
    config_path.chmod(0o600)
print(f"disabled_unavailable_optional_skills={len(set(skills))}")
PY
fi
rm -f "\${doctor_preflight}"
openclaw doctor --lint --json --severity-min warning
if [[ "${RUN_PROMPT_SMOKE}" == "1" ]]; then
  openclaw agent --agent "${PROMPT_SMOKE_AGENT}" --session-key "${PROMPT_SMOKE_SESSION_KEY}" --message "${PROMPT_SMOKE_TEXT}" --json --timeout "${PROMPT_SMOKE_TIMEOUT}"
fi
if [[ "${RUN_IMAGE_SMOKE}" == "1" ]]; then
  openclaw infer image generate --prompt "A tiny monochrome checkmark icon on a plain white background." --model "${IMAGE_GENERATION_MODEL}" --count 1 --json --timeout-ms 180000
fi
REMOTE
  ok "verification completed"
}

manual_login() {
  ensure_evidence_dir
  local url="${INSTALLER_URL:-${DEFAULT_INSTALLER_URL}}"
  info "starting interactive manual-login installer on ${REMOTE}"
  info "installer URL: ${url}"
  info "auth choice: ${MANUAL_AUTH_CHOICE}"
  info "complete the browser/device login when OpenClaw prints the code"
  ssh -tt -o BatchMode=yes -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" "${REMOTE}" \
    "OPENCLAW_V7_AUTH_CHOICE='${MANUAL_AUTH_CHOICE}' bash -lc 'bash <(curl -fsSL \"${url}\")'"
}

final_verify() {
  local old_run_prompt="${RUN_PROMPT_SMOKE}"
  local old_session_key="${PROMPT_SMOKE_SESSION_KEY}"
  RUN_PROMPT_SMOKE=1
  PROMPT_SMOKE_SESSION_KEY="${MANUAL_PROMPT_SMOKE_SESSION_KEY}"
  verify_remote
  RUN_PROMPT_SMOKE="${old_run_prompt}"
  PROMPT_SMOKE_SESSION_KEY="${old_session_key}"
}

cleanup_staged() {
  ssh_remote 'rm -rf ~/.openclaw-v7-e2e /tmp/openclaw-v7-e2e /tmp/openclaw-v7-install.sh'
  ok "staged harness files removed"
}

e2e() {
  preflight
  reset_remote
  if [[ -n "${AUTH_SECRET_FILE}" || -n "${AUTH_SECRET_ENV}" ]]; then
    stage_credentials
  else
    warn "no AUTH_SECRET_FILE/AUTH_SECRET_ENV set; continuing without credential staging"
  fi
  install_remote
  verify_remote
}

main() {
  case "${1:-}" in
    preflight) preflight ;;
    reset) reset_remote ;;
    stage-credentials) stage_credentials ;;
    install) install_remote ;;
    verify) verify_remote ;;
    manual-login) manual_login ;;
    final-verify) final_verify ;;
    e2e) e2e ;;
    cleanup-staged) cleanup_staged ;;
    -h|--help|help|"") usage ;;
    *) err "unknown command: $1"; usage; exit 1 ;;
  esac
}

main "$@"
