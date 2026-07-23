#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_ADD_AGENT_VERSION="1.0.0"
OPENCLAW_REQUIRED_VERSION="${OPENCLAW_REQUIRED_VERSION:-2026.7.1}"
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_STATE_DIR}/openclaw.json}"
OPENCLAW_TELEGRAM_DETECT_TIMEOUT="${OPENCLAW_TELEGRAM_DETECT_TIMEOUT:-120}"
OPENCLAW_TELEGRAM_DETECT_INTERVAL="${OPENCLAW_TELEGRAM_DETECT_INTERVAL:-2}"
OPENCLAW_ADD_AGENT_PROMPT_SMOKE="${OPENCLAW_ADD_AGENT_PROMPT_SMOKE:-1}"
OPENCLAW_BIN="${OPENCLAW_BIN:-}"

AGENT_ID=""
AGENT_WORKSPACE=""
AGENT_STATE_DIR=""
SECRET_FILE=""
TEMP_DIR=""
LOCK_DIR=""
RUN_DIR=""
CREATED_AGENT=0
CREATED_ACCOUNT=0
CREATED_BINDING=0
SECRET_WRITTEN=0
ROLLBACK_NEEDED=0
LANCEDB_AUTORECALL_CHANGED=0
LANCEDB_AUTOCAPTURE_CHANGED=0

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERR ] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: bash openclaw-add-agent.sh

Adds one isolated agent and one Telegram bot account to an existing
ClawNode/OpenClaw 2026.7.1 Gateway. Run it again to add another agent.

Interactive inputs:
  1. Bot display name
  2. Telegram bot token (hidden)
  3. Send the displayed one-time code to the bot

Automation overrides:
  OPENCLAW_AGENT_NAME
  OPENCLAW_TELEGRAM_BOT_TOKEN
  OPENCLAW_TELEGRAM_OWNER_ID
  OPENCLAW_ADD_AGENT_PROMPT_SMOKE=0
EOF
}

derive_agent_id() {
  local username="$1"
  username="${username#@}"
  printf '%s' "${username}" \
    | tr '[:upper:]_' '[:lower:]-' \
    | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
    | cut -c1-63
}

seed_workspace() {
  local source_workspace="$1" target_workspace="$2" file
  mkdir -p "${target_workspace}"

  for file in AGENTS.md SOUL.md USER.md TOOLS.md BOOT.md; do
    if [[ -f "${source_workspace}/${file}" ]]; then
      cp -p "${source_workspace}/${file}" "${target_workspace}/${file}"
    fi
  done

  if [[ -d "${source_workspace}/skills" ]]; then
    rm -rf "${target_workspace}/skills"
    cp -R "${source_workspace}/skills" "${target_workspace}/skills"
  fi
}

extract_owner_id_from_updates_file() {
  local updates_file="$1" verify_code="$2"
  python3 - "${updates_file}" "${verify_code}" <<'PYEOF'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
verify_code = sys.argv[2]
try:
    payload = json.loads(path.read_text())
except Exception:
    raise SystemExit(1)

matches = []
for update in payload.get("result") or []:
    if not isinstance(update, dict):
        continue
    message = update.get("message") or update.get("edited_message") or {}
    text = str(message.get("text") or message.get("caption") or "").strip()
    sender = message.get("from") or {}
    chat = message.get("chat") or {}
    sender_id = sender.get("id")
    if text != verify_code or sender.get("is_bot") is True or chat.get("type") != "private":
        continue
    if isinstance(sender_id, int) and sender_id > 0:
        matches.append((int(update.get("update_id") or 0), str(sender_id)))

if not matches:
    raise SystemExit(1)
matches.sort(reverse=True)
print(matches[0][1])
PYEOF
}

read_default_agent_context() {
  local agents_file="$1"
  python3 - "${agents_file}" <<'PYEOF'
import json
import pathlib
import sys

agents = json.loads(pathlib.Path(sys.argv[1]).read_text())
if not isinstance(agents, list):
    raise SystemExit("agents list output must be an array")
agent = next((item for item in agents if isinstance(item, dict) and item.get("isDefault") is True), None)
if agent is None:
    agent = next((item for item in agents if isinstance(item, dict) and item.get("id") == "main"), None)
if agent is None:
    raise SystemExit("default/main agent was not found")
model = agent.get("model")
if isinstance(model, dict):
    model = model.get("primary")
values = [str(agent.get("id") or ""), str(agent.get("workspace") or ""), str(model or "")]
if not all(values):
    raise SystemExit("default agent is missing id, workspace, or model")
print("\t".join(values))
PYEOF
}

read_file_secret_provider() {
  local config_file="$1"
  python3 - "${config_file}" <<'PYEOF'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
secrets = config.get("secrets") or {}
providers = secrets.get("providers") or {}
alias = (secrets.get("defaults") or {}).get("file")
provider = providers.get(alias) if isinstance(alias, str) else None
if not isinstance(provider, dict) or provider.get("source") != "file" or provider.get("mode") != "json":
    alias = ""
    provider = None
    for candidate, value in providers.items():
        if isinstance(value, dict) and value.get("source") == "file" and value.get("mode") == "json":
            alias = str(candidate)
            provider = value
            break
if not alias or not isinstance(provider, dict) or not provider.get("path"):
    raise SystemExit("no JSON file SecretRef provider is configured")
path = pathlib.Path(str(provider["path"])).expanduser()
print(f"{alias}\t{path}")
PYEOF
}

agent_id_exists() {
  local agents_file="$1" agent_id="$2"
  python3 - "${agents_file}" "${agent_id}" <<'PYEOF'
import json
import pathlib
import sys

agents = json.loads(pathlib.Path(sys.argv[1]).read_text())
agent_id = sys.argv[2]
found = isinstance(agents, list) and any(
    isinstance(agent, dict) and agent.get("id") == agent_id for agent in agents
)
raise SystemExit(0 if found else 1)
PYEOF
}

telegram_account_exists() {
  local config_file="$1" account_id="$2"
  python3 - "${config_file}" "${account_id}" <<'PYEOF'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
accounts = config.get("channels", {}).get("telegram", {}).get("accounts", {})
found = isinstance(accounts, dict) and sys.argv[2] in accounts
raise SystemExit(0 if found else 1)
PYEOF
}

telegram_bot_id_exists_in_status_file() {
  local status_file="$1" bot_id="$2"
  python3 - "${status_file}" "${bot_id}" <<'PYEOF'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
expected = str(sys.argv[2])
accounts = payload.get("channelAccounts", {}).get("telegram", [])
for account in accounts if isinstance(accounts, list) else []:
    if not isinstance(account, dict):
        continue
    probe = account.get("probe") or {}
    identities = [probe.get("botInfo") or {}, probe.get("bot") or {}]
    if any(str(identity.get("id") or "") == expected for identity in identities):
        raise SystemExit(0)
raise SystemExit(1)
PYEOF
}

read_default_telegram_account_context() {
  local status_file="$1"
  python3 - "${status_file}" <<'PYEOF'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
accounts = payload.get("channelAccounts", {}).get("telegram", [])
if not isinstance(accounts, list) or not accounts:
    raise SystemExit("no existing Telegram account is available")
default_id = str(payload.get("channelDefaultAccountId", {}).get("telegram") or "default")
account = next(
    (
        item for item in accounts
        if isinstance(item, dict) and str(item.get("accountId") or "") == default_id
    ),
    None,
)
if not isinstance(account, dict):
    raise SystemExit("existing default Telegram account status is missing")
probe = account.get("probe") or {}
identities = [probe.get("botInfo") or {}, probe.get("bot") or {}]
bot_id = next((identity.get("id") for identity in identities if identity.get("id")), None)
if not isinstance(bot_id, int) or bot_id <= 0:
    raise SystemExit("existing default Telegram bot identity is missing")
print(f"{default_id}\t{bot_id}")
PYEOF
}

telegram_get_me() {
  local bot_token="$1"
  python3 - 3<<< "${bot_token}" <<'PYEOF'
import json
import os
import sys
import urllib.error
import urllib.request

token = os.fdopen(3).read().rstrip("\r\n")

def call(method):
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/{method}",
        headers={"User-Agent": "clawnode-openclaw-add-agent/1"},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"Telegram API rejected the token (HTTP {exc.code})")
    except Exception:
        raise SystemExit("Telegram API request failed")
    if payload.get("ok") is not True:
        raise SystemExit("Telegram API returned an unsuccessful response")
    return payload.get("result") or {}

bot = call("getMe")
username = str(bot.get("username") or "").strip()
bot_id = bot.get("id")
if not username or not isinstance(bot_id, int):
    raise SystemExit("Telegram bot identity is incomplete")
webhook = call("getWebhookInfo")
if str(webhook.get("url") or "").strip():
    raise SystemExit("Telegram bot has an active webhook; remove it before provisioning")
print(f"{bot_id}\t{username}")
PYEOF
}

generate_verify_code() {
  local suffix
  if command -v openssl >/dev/null 2>&1; then
    suffix="$(openssl rand -hex 4)"
  else
    suffix="$(printf '%s' "$$-$(date +%s%N)" | shasum -a 256 | awk '{print substr($1,1,8)}')"
  fi
  printf 'clawnode-link-%s\n' "${suffix}"
}

detect_telegram_owner_id() {
  local bot_token="$1" bot_username="$2" verify_code="$3"
  info "Send this exact code in a private message to @${bot_username}:"
  printf '\n  %s\n\n' "${verify_code}"

  TELEGRAM_VERIFY_CODE="${verify_code}" \
  TELEGRAM_DETECT_TIMEOUT="${OPENCLAW_TELEGRAM_DETECT_TIMEOUT}" \
  TELEGRAM_DETECT_INTERVAL="${OPENCLAW_TELEGRAM_DETECT_INTERVAL}" \
  python3 - 3<<< "${bot_token}" <<'PYEOF'
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

token = os.fdopen(3).read().rstrip("\r\n")
verify_code = os.environ["TELEGRAM_VERIFY_CODE"]
timeout = max(10, int(os.environ.get("TELEGRAM_DETECT_TIMEOUT") or "120"))
interval = max(1, int(os.environ.get("TELEGRAM_DETECT_INTERVAL") or "2"))

def get_updates(offset=None, long_poll=0):
    params = {
        "limit": 20,
        "timeout": long_poll,
        "allowed_updates": json.dumps(["message"]),
    }
    if offset is not None:
        params["offset"] = offset
    url = f"https://api.telegram.org/bot{token}/getUpdates?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": "clawnode-openclaw-add-agent/1"})
    try:
        with urllib.request.urlopen(request, timeout=max(10, long_poll + 5)) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Telegram update polling failed (HTTP {exc.code})")
    except Exception:
        raise RuntimeError("Telegram update polling failed")
    if payload.get("ok") is not True:
        raise RuntimeError("Telegram update polling returned an unsuccessful response")
    return payload.get("result") or []

offset = None
deadline = time.time() + timeout

while time.time() < deadline:
    try:
        updates = get_updates(offset=offset, long_poll=min(5, max(1, int(deadline - time.time()))))
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
    for update in updates:
        if not isinstance(update, dict):
            continue
        next_offset = int(update.get("update_id") or 0) + 1
        offset = next_offset if offset is None else max(offset, next_offset)
        message = update.get("message") or {}
        sender = message.get("from") or {}
        chat = message.get("chat") or {}
        text = str(message.get("text") or message.get("caption") or "").strip()
        sender_id = sender.get("id")
        if (
            text == verify_code
            and sender.get("is_bot") is not True
            and chat.get("type") == "private"
            and isinstance(sender_id, int)
            and sender_id > 0
        ):
            print(sender_id)
            raise SystemExit(0)
    remaining = max(0, int(deadline - time.time()))
    print(f"Waiting for the Telegram verification message... {remaining}s", file=sys.stderr)
    if not updates:
        time.sleep(interval)

print("Telegram owner detection timed out", file=sys.stderr)
raise SystemExit(1)
PYEOF
}

write_telegram_secret() {
  local secret_file="$1" account_id="$2" bot_token="$3"
  python3 - "${secret_file}" "${account_id}" 3<<< "${bot_token}" <<'PYEOF'
import json
import os
import pathlib
import sys

path = pathlib.Path(sys.argv[1]).expanduser()
account_id = sys.argv[2]
token = os.fdopen(3).read().rstrip("\r\n")
if path.is_symlink():
    raise SystemExit("refusing to write a symlinked SecretRef file")
if path.exists() and not path.is_file():
    raise SystemExit("SecretRef path is not a regular file")

path.parent.mkdir(parents=True, exist_ok=True)
os.chmod(path.parent, 0o700)
try:
    payload = json.loads(path.read_text()) if path.exists() else {}
except Exception as exc:
    raise SystemExit(f"invalid SecretRef JSON: {exc}")
if not isinstance(payload, dict):
    raise SystemExit("SecretRef JSON root must be an object")

node = payload.setdefault("openclaw-add-agent", {})
node = node.setdefault("telegram", {})
node = node.setdefault("accounts", {})
node = node.setdefault(account_id, {})
node["botToken"] = token

tmp = path.with_name(f".{path.name}.tmp.{os.getpid()}")
tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
os.chmod(tmp, 0o600)
os.replace(tmp, path)
os.chmod(path, 0o600)
print(f"/openclaw-add-agent/telegram/accounts/{account_id}/botToken")
PYEOF
}

remove_telegram_secret() {
  local secret_file="$1" account_id="$2"
  [[ -f "${secret_file}" ]] || return 0
  python3 - "${secret_file}" "${account_id}" <<'PYEOF'
import json
import os
import pathlib
import sys

path = pathlib.Path(sys.argv[1]).expanduser()
account_id = sys.argv[2]
if path.is_symlink() or not path.is_file():
    raise SystemExit(0)
try:
    payload = json.loads(path.read_text())
except Exception:
    raise SystemExit(0)

accounts = (
    payload.get("openclaw-add-agent", {})
    .get("telegram", {})
    .get("accounts", {})
)
if not isinstance(accounts, dict) or account_id not in accounts:
    raise SystemExit(0)
accounts.pop(account_id, None)

tmp = path.with_name(f".{path.name}.tmp.{os.getpid()}")
tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
os.chmod(tmp, 0o600)
os.replace(tmp, path)
os.chmod(path, 0o600)
PYEOF
}

json_string() {
  python3 -c 'import json, sys; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$1"
}

configure_telegram_account() {
  local account_id="$1" display_name="$2" owner_id="$3"
  local secret_provider="$4" secret_pointer="$5" bot_token="$6"
  local path="channels.telegram.accounts.${account_id}"
  local token_file="${TEMP_DIR}/telegram-${account_id}.token"

  (umask 077; printf '%s\n' "${bot_token}" > "${token_file}")
  if ! "${OPENCLAW_BIN}" channels add \
    --channel telegram \
    --account "${account_id}" \
    --name "${display_name}" \
    --token-file "${token_file}"; then
    rm -f "${token_file}"
    return 1
  fi
  CREATED_ACCOUNT=1
  if ! "${OPENCLAW_BIN}" config set "${path}.botToken" \
    --ref-provider "${secret_provider}" \
    --ref-source file \
    --ref-id "${secret_pointer}"; then
    return 1
  fi
  if ! "${OPENCLAW_BIN}" config unset "${path}.tokenFile"; then
    return 1
  fi
  rm -f "${token_file}"
  "${OPENCLAW_BIN}" config set "${path}.name" "$(json_string "${display_name}")" --strict-json || return 1
  "${OPENCLAW_BIN}" config set "${path}.dmPolicy" '"allowlist"' --strict-json || return 1
  "${OPENCLAW_BIN}" config set "${path}.allowFrom" "[\"${owner_id}\"]" --strict-json || return 1
  "${OPENCLAW_BIN}" config set "${path}.enabled" true --strict-json || return 1
}

create_openclaw_agent() {
  local agent_id="$1" display_name="$2" source_workspace="$3"
  local target_workspace="$4" model="$5"

  if ! "${OPENCLAW_BIN}" agents add "${agent_id}" \
    --workspace "${target_workspace}" \
    --model "${model}" \
    --non-interactive \
    --json; then
    return 1
  fi
  CREATED_AGENT=1
  seed_workspace "${source_workspace}" "${target_workspace}" || return 1
  "${OPENCLAW_BIN}" agents set-identity \
    --agent "${agent_id}" \
    --name "${display_name}" \
    --json || return 1
}

bind_telegram_account() {
  local agent_id="$1"
  if ! "${OPENCLAW_BIN}" agents bind \
    --agent "${agent_id}" \
    --bind "telegram:${agent_id}" \
    --json; then
    return 1
  fi
  CREATED_BINDING=1
}

apply_secondary_memory_isolation() {
  local config_file="$1" agent_id="$2" context index active auto_recall auto_capture
  local deny_json
  context="$(python3 - "${config_file}" "${agent_id}" <<'PYEOF'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
agent_id = sys.argv[2]
agents = config.get("agents", {}).get("list", [])
index = next((i for i, item in enumerate(agents) if isinstance(item, dict) and item.get("id") == agent_id), -1)
agent = agents[index] if index >= 0 else {}
plugins = config.get("plugins", {})
entry = plugins.get("entries", {}).get("memory-lancedb", {})
active = plugins.get("slots", {}).get("memory") == "memory-lancedb" and entry.get("enabled") is not False
plugin_config = entry.get("config", {}) if isinstance(entry, dict) else {}
required_denies = [
    "memory_recall", "memory_store", "memory_forget",
    "wiki_status", "wiki_lint", "wiki_apply", "wiki_search", "wiki_get",
]
existing_denies = (agent.get("tools") or {}).get("deny") or []
merged_denies = [str(value) for value in existing_denies if isinstance(value, str)]
for value in required_denies:
    if value not in merged_denies:
        merged_denies.append(value)
print("\t".join([
    str(index),
    "1" if active else "0",
    "1" if plugin_config.get("autoRecall") is True else "0",
    "1" if plugin_config.get("autoCapture") is True else "0",
    json.dumps(merged_denies, separators=(",", ":")),
]))
PYEOF
)"
  IFS=$'\t' read -r index active auto_recall auto_capture deny_json <<< "${context}"
  [[ "${index}" =~ ^[0-9]+$ ]] || die "new agent config entry was not found for memory isolation"

  if [[ "${active}" == "1" && "${auto_recall}" == "1" ]]; then
    warn "OpenClaw 2026.7.1 LanceDB is global; disabling auto-recall for agent memory isolation"
    "${OPENCLAW_BIN}" config set plugins.entries.memory-lancedb.config.autoRecall false --strict-json
    LANCEDB_AUTORECALL_CHANGED=1
  fi
  if [[ "${active}" == "1" && "${auto_capture}" == "1" ]]; then
    warn "OpenClaw 2026.7.1 LanceDB is global; disabling auto-capture for agent memory isolation"
    "${OPENCLAW_BIN}" config set plugins.entries.memory-lancedb.config.autoCapture false --strict-json
    LANCEDB_AUTOCAPTURE_CHANGED=1
  fi
  "${OPENCLAW_BIN}" config set "agents.list[${index}].tools.deny" "${deny_json}" --strict-json
}

remove_owned_openclaw_config_entries() {
  local config_file="$1" agent_id="$2" workspace="$3"
  local remove_binding="$4" remove_account="$5" remove_agent="$6"
  [[ -f "${config_file}" ]] || return 0
  python3 - "${config_file}" "${agent_id}" "${workspace}" \
    "${remove_binding}" "${remove_account}" "${remove_agent}" <<'PYEOF'
import json
import os
import pathlib
import stat
import sys

path = pathlib.Path(sys.argv[1])
agent_id, workspace = sys.argv[2:4]
remove_binding, remove_account, remove_agent = (value == "1" for value in sys.argv[4:7])
if path.is_symlink() or not path.is_file():
    raise SystemExit("refusing local rollback through a non-regular config file")
config = json.loads(path.read_text())
changed = False

if remove_binding:
    bindings = config.get("bindings")
    if isinstance(bindings, list):
        kept = []
        for binding in bindings:
            match = binding.get("match") if isinstance(binding, dict) else None
            owned = (
                isinstance(binding, dict)
                and binding.get("agentId") == agent_id
                and isinstance(match, dict)
                and match.get("channel") == "telegram"
                and match.get("accountId") == agent_id
            )
            if owned:
                changed = True
            else:
                kept.append(binding)
        config["bindings"] = kept

if remove_account:
    accounts = config.get("channels", {}).get("telegram", {}).get("accounts")
    if isinstance(accounts, dict) and agent_id in accounts:
        accounts.pop(agent_id)
        changed = True

if remove_agent:
    agents = config.get("agents", {}).get("list")
    if isinstance(agents, list):
        kept = []
        for agent in agents:
            owned = (
                isinstance(agent, dict)
                and agent.get("id") == agent_id
                and agent.get("workspace") == workspace
            )
            if owned:
                changed = True
            else:
                kept.append(agent)
        config["agents"]["list"] = kept

if not changed:
    raise SystemExit(0)
mode = stat.S_IMODE(path.stat().st_mode)
tmp = path.with_name(f".{path.name}.rollback.{os.getpid()}")
tmp.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")
os.chmod(tmp, mode)
os.replace(tmp, path)
PYEOF
}

rollback_provision() {
  local agent_id="${AGENT_ID:-}"
  [[ -n "${agent_id}" ]] || return 0

  if [[ "${CREATED_BINDING:-0}" == "1" ]]; then
    "${OPENCLAW_BIN}" agents unbind \
      --agent "${agent_id}" \
      --bind "telegram:${agent_id}" \
      --json >/dev/null 2>&1 || true
  fi
  if [[ "${CREATED_ACCOUNT:-0}" == "1" ]]; then
    "${OPENCLAW_BIN}" channels remove \
      --channel telegram \
      --account "${agent_id}" \
      --delete >/dev/null 2>&1 || true
  fi
  if [[ "${CREATED_AGENT:-0}" == "1" ]]; then
    "${OPENCLAW_BIN}" agents delete "${agent_id}" \
      --force \
      --json >/dev/null 2>&1 || true
  fi

  remove_owned_openclaw_config_entries \
    "${OPENCLAW_CONFIG_PATH}" "${agent_id}" "${AGENT_WORKSPACE:-}" \
    "${CREATED_BINDING:-0}" "${CREATED_ACCOUNT:-0}" "${CREATED_AGENT:-0}" || \
    warn "local config rollback could not remove every owned entry"

  if [[ "${CREATED_AGENT:-0}" == "1" ]]; then
    if [[ -n "${AGENT_WORKSPACE:-}" && \
      "${AGENT_WORKSPACE}" == "${OPENCLAW_STATE_DIR}/workspace-${agent_id}" ]]; then
      rm -rf -- "${AGENT_WORKSPACE}"
    fi
    if [[ -n "${AGENT_STATE_DIR:-}" && \
      "${AGENT_STATE_DIR}" == "${OPENCLAW_STATE_DIR}/agents/${agent_id}" ]]; then
      rm -rf -- "${AGENT_STATE_DIR}"
    fi
  fi
  if [[ "${SECRET_WRITTEN:-0}" == "1" && -n "${SECRET_FILE:-}" ]]; then
    remove_telegram_secret "${SECRET_FILE}" "${agent_id}" || true
  fi
  if [[ "${LANCEDB_AUTORECALL_CHANGED:-0}" == "1" ]]; then
    "${OPENCLAW_BIN}" config set plugins.entries.memory-lancedb.config.autoRecall true --strict-json \
      >/dev/null 2>&1 || true
  fi
  if [[ "${LANCEDB_AUTOCAPTURE_CHANGED:-0}" == "1" ]]; then
    "${OPENCLAW_BIN}" config set plugins.entries.memory-lancedb.config.autoCapture true --strict-json \
      >/dev/null 2>&1 || true
  fi

  CREATED_BINDING=0
  CREATED_ACCOUNT=0
  CREATED_AGENT=0
  SECRET_WRITTEN=0
  LANCEDB_AUTORECALL_CHANGED=0
  LANCEDB_AUTOCAPTURE_CHANGED=0
}

find_openclaw() {
  if [[ -n "${OPENCLAW_BIN}" && -x "${OPENCLAW_BIN}" ]]; then
    return 0
  fi
  if command -v openclaw >/dev/null 2>&1; then
    OPENCLAW_BIN="$(command -v openclaw)"
    return 0
  fi
  for candidate in \
    "${HOME}/.npm-global/bin/openclaw" \
    "/opt/homebrew/bin/openclaw" \
    "/usr/local/bin/openclaw"; do
    if [[ -x "${candidate}" ]]; then
      OPENCLAW_BIN="${candidate}"
      return 0
    fi
  done
  return 1
}

acquire_lock() {
  LOCK_DIR="${OPENCLAW_STATE_DIR}/setup-v7/add-agent.lock"
  mkdir -p "$(dirname "${LOCK_DIR}")"
  chmod 700 "$(dirname "${LOCK_DIR}")" 2>/dev/null || true
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    printf '%s\n' "$$" > "${LOCK_DIR}/pid"
    return 0
  fi

  local owner_pid=""
  owner_pid="$(sed -n '1p' "${LOCK_DIR}/pid" 2>/dev/null || true)"
  if [[ "${owner_pid}" =~ ^[0-9]+$ ]] && kill -0 "${owner_pid}" 2>/dev/null; then
    die "another add-agent run is active (pid ${owner_pid})"
  fi
  warn "removing a stale add-agent lock"
  rm -rf "${LOCK_DIR}"
  mkdir "${LOCK_DIR}"
  printf '%s\n' "$$" > "${LOCK_DIR}/pid"
}

release_lock() {
  [[ -n "${LOCK_DIR}" && -d "${LOCK_DIR}" ]] || return 0
  rm -rf "${LOCK_DIR}"
}

on_exit() {
  local status=$?
  trap - EXIT
  if [[ ${status} -ne 0 && "${ROLLBACK_NEEDED}" == "1" ]]; then
    warn "provisioning failed; removing the new agent resources"
    rollback_provision
  fi
  [[ -z "${TEMP_DIR}" || ! -d "${TEMP_DIR}" ]] || rm -rf "${TEMP_DIR}"
  release_lock
  exit "${status}"
}

read_inputs() {
  local name="${OPENCLAW_AGENT_NAME:-}" token="${OPENCLAW_TELEGRAM_BOT_TOKEN:-}"
  if [[ -z "${name}" ]]; then
    [[ -r /dev/tty ]] || die "OPENCLAW_AGENT_NAME is required without an interactive terminal"
    printf 'Bot display name: ' > /dev/tty
    IFS= read -r name < /dev/tty || true
  fi
  name="$(printf '%s' "${name}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "${name}" ]] || die "bot display name cannot be empty"

  if [[ -z "${token}" ]]; then
    [[ -r /dev/tty ]] || die "OPENCLAW_TELEGRAM_BOT_TOKEN is required without an interactive terminal"
    printf 'Telegram bot token: ' > /dev/tty
    IFS= read -r -s token < /dev/tty || true
    printf '\n' > /dev/tty
  fi
  [[ "${token}" =~ ^[0-9]{5,}:[A-Za-z0-9_-]{20,}$ ]] || die "Telegram bot token format is invalid"
  DISPLAY_NAME="${name}"
  BOT_TOKEN="${token}"
}

backup_state() {
  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  RUN_DIR="${OPENCLAW_STATE_DIR}/setup-v7/add-agent-runs/${stamp}-${AGENT_ID}"
  mkdir -p "${RUN_DIR}"
  chmod 700 "${RUN_DIR}"
  cp -p "${OPENCLAW_CONFIG_PATH}" "${RUN_DIR}/openclaw.json.before"
  if [[ -f "${SECRET_FILE}" ]]; then
    cp -p "${SECRET_FILE}" "${RUN_DIR}/secrets.before.json"
    chmod 600 "${RUN_DIR}/secrets.before.json"
  fi
}

verify_provisioned_config() {
  local config_file="$1" agent_id="$2" owner_id="$3"
  local secret_provider="$4" secret_pointer="$5"
  python3 - "${config_file}" "${agent_id}" "${owner_id}" "${secret_provider}" "${secret_pointer}" <<'PYEOF'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
agent_id, owner_id, provider, pointer = sys.argv[2:]
account = config.get("channels", {}).get("telegram", {}).get("accounts", {}).get(agent_id)
if not isinstance(account, dict):
    raise SystemExit("new Telegram account is missing")
expected_ref = {"source": "file", "provider": provider, "id": pointer}
if account.get("botToken") != expected_ref:
    raise SystemExit("new Telegram account is not SecretRef-backed")
if account.get("enabled") is not True:
    raise SystemExit("new Telegram account is disabled")
if account.get("dmPolicy") != "allowlist" or account.get("allowFrom") != [owner_id]:
    raise SystemExit("new Telegram account owner allowlist is incorrect")
agents = config.get("agents", {}).get("list", [])
agent = next((item for item in agents if isinstance(item, dict) and item.get("id") == agent_id), None)
if not isinstance(agent, dict):
    raise SystemExit("new agent config is missing")
required_denies = {
    "memory_recall", "memory_store", "memory_forget",
    "wiki_status", "wiki_lint", "wiki_apply", "wiki_search", "wiki_get",
}
actual_denies = set((agent.get("tools") or {}).get("deny") or [])
if not required_denies.issubset(actual_denies):
    raise SystemExit("new agent can access globally shared plugin memory")
plugins = config.get("plugins", {})
lancedb = (plugins.get("entries") or {}).get("memory-lancedb") or {}
if plugins.get("slots", {}).get("memory") == "memory-lancedb" and lancedb.get("enabled") is not False:
    plugin_config = lancedb.get("config") or {}
    if plugin_config.get("autoRecall") is True or plugin_config.get("autoCapture") is True:
        raise SystemExit("shared LanceDB hooks are still enabled")
PYEOF
}

verify_agent_list() {
  local agents_file="$1" agent_id="$2" workspace="$3" model="$4"
  python3 - "${agents_file}" "${agent_id}" "${workspace}" "${model}" <<'PYEOF'
import json
import pathlib
import sys

agents = json.loads(pathlib.Path(sys.argv[1]).read_text())
agent_id, workspace, model = sys.argv[2:]
agent = next((item for item in agents if isinstance(item, dict) and item.get("id") == agent_id), None)
if not isinstance(agent, dict):
    raise SystemExit("new agent is missing")
if agent.get("workspace") != workspace:
    raise SystemExit("new agent workspace does not match")
if agent.get("model") != model:
    raise SystemExit("new agent model does not match")
PYEOF
}

verify_binding_file() {
  local bindings_file="$1" agent_id="$2"
  python3 - "${bindings_file}" "${agent_id}" <<'PYEOF'
import json
import pathlib
import sys

bindings = json.loads(pathlib.Path(sys.argv[1]).read_text())
agent_id = sys.argv[2]
if not isinstance(bindings, list):
    raise SystemExit("bindings output must be an array")
matched = any(
    isinstance(item, dict)
    and item.get("agentId") == agent_id
    and isinstance(item.get("match"), dict)
    and item["match"].get("channel") == "telegram"
    and item["match"].get("accountId") == agent_id
    for item in bindings
)
if not matched:
    raise SystemExit("exact Telegram account binding is missing")
PYEOF
}

verify_telegram_account_status() {
  local status_file="$1" account_id="$2" expected_bot_id="$3"
  python3 - "${status_file}" "${account_id}" "${expected_bot_id}" <<'PYEOF'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
account_id, expected_bot_id = sys.argv[2:]
accounts = payload.get("channelAccounts", {}).get("telegram", [])
account = next(
    (
        item for item in accounts
        if isinstance(item, dict) and item.get("accountId") == account_id
    ),
    None,
) if isinstance(accounts, list) else None
if not isinstance(account, dict):
    raise SystemExit("new Telegram account status is missing")
for field in ("enabled", "configured", "running", "connected"):
    if account.get(field) is not True:
        raise SystemExit(f"new Telegram account is not {field}")
probe = account.get("probe") or {}
if probe.get("ok") is not True:
    raise SystemExit("new Telegram account probe failed")
identities = [probe.get("botInfo") or {}, probe.get("bot") or {}]
if not any(str(identity.get("id") or "") == expected_bot_id for identity in identities):
    raise SystemExit("new Telegram account bot identity does not match")
PYEOF
}

verify_secrets_audit() {
  local audit_file="$1"
  python3 - "${audit_file}" <<'PYEOF'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
summary = payload.get("summary") or {}
for field in ("plaintextCount", "unresolvedRefCount", "shadowedRefCount"):
    value = summary.get(field)
    if not isinstance(value, int) or value != 0:
        raise SystemExit(f"secrets audit has nonzero or missing {field}")
PYEOF
}

verify_prompt_smoke() {
  local prompt_file="$1" expected_model="$2"
  python3 - "${prompt_file}" "${expected_model}" <<'PYEOF'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
expected = sys.argv[2]
if "/" not in expected:
    raise SystemExit("expected model must include a provider")
expected_provider, expected_model = expected.split("/", 1)
result = payload.get("result") or {}
trace = (result.get("meta") or {}).get("executionTrace") or {}
if trace.get("winnerProvider") != expected_provider or trace.get("winnerModel") != expected_model:
    actual = f"{trace.get('winnerProvider')}/{trace.get('winnerModel')}"
    raise SystemExit(f"prompt winner model mismatch: {actual}")
texts = [
    str(item.get("text") or "")
    for item in result.get("payloads") or []
    if isinstance(item, dict)
]
if not any("AGENT_OK" in text for text in texts):
    raise SystemExit("prompt smoke response is missing AGENT_OK")
PYEOF
}

restart_gateway() {
  info "Restarting the Gateway safely"
  "${OPENCLAW_BIN}" gateway restart --safe
}

verify_provision() {
  local agent_id="$1" workspace="$2" model="$3" owner_id="$4" bot_id="$5"
  local previous_account_id="$6" previous_bot_id="$7"
  local secret_provider="$8" secret_pointer="$9"
  local agents_file="${RUN_DIR}/agents.json"
  local bindings_file="${RUN_DIR}/bindings.json"

  "${OPENCLAW_BIN}" config validate --json > "${RUN_DIR}/config-validate.json"
  verify_provisioned_config "${OPENCLAW_CONFIG_PATH}" "${agent_id}" "${owner_id}" \
    "${secret_provider}" "${secret_pointer}"
  "${OPENCLAW_BIN}" agents list --json > "${agents_file}"
  verify_agent_list "${agents_file}" "${agent_id}" "${workspace}" "${model}"
  "${OPENCLAW_BIN}" agents bindings --agent "${agent_id}" --json > "${bindings_file}"
  verify_binding_file "${bindings_file}" "${agent_id}"
  "${OPENCLAW_BIN}" channels status --channel telegram --probe --json \
    > "${RUN_DIR}/telegram-status.json"
  verify_telegram_account_status "${RUN_DIR}/telegram-status.json" "${agent_id}" "${bot_id}"
  verify_telegram_account_status \
    "${RUN_DIR}/telegram-status.json" "${previous_account_id}" "${previous_bot_id}"
  "${OPENCLAW_BIN}" models status --agent "${agent_id}" --json \
    > "${RUN_DIR}/models-status.json"
  "${OPENCLAW_BIN}" secrets audit --json > "${RUN_DIR}/secrets-audit.json"
  verify_secrets_audit "${RUN_DIR}/secrets-audit.json"

  if [[ "${OPENCLAW_ADD_AGENT_PROMPT_SMOKE}" == "1" ]]; then
    "${OPENCLAW_BIN}" agent \
      --agent "${agent_id}" \
      --session-key "agent:${agent_id}:add-agent-smoke" \
      --message "Reply exactly with AGENT_OK." \
      --json \
      --timeout 120 \
      > "${RUN_DIR}/prompt-smoke.json"
    verify_prompt_smoke "${RUN_DIR}/prompt-smoke.json" "${model}"
  else
    warn "prompt smoke skipped by OPENCLAW_ADD_AGENT_PROMPT_SMOKE=0"
  fi
}

preflight() {
  [[ "$(uname -s)" == "Darwin" ]] || die "this provisioner currently supports the macOS v7 installer only"
  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  find_openclaw || die "openclaw was not found; run openclaw-setup-v7.sh first"
  local version_output
  version_output="$("${OPENCLAW_BIN}" --version 2>/dev/null || true)"
  [[ "${version_output}" == *"${OPENCLAW_REQUIRED_VERSION}"* ]] || \
    die "OpenClaw ${OPENCLAW_REQUIRED_VERSION} is required (found: ${version_output:-unknown})"
  [[ -f "${OPENCLAW_CONFIG_PATH}" ]] || die "OpenClaw config is missing: ${OPENCLAW_CONFIG_PATH}"
  "${OPENCLAW_BIN}" config validate --json >/dev/null
  "${OPENCLAW_BIN}" gateway status --deep --require-rpc --json >/dev/null
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    return 0
  fi
  [[ $# -eq 0 ]] || die "unknown argument: $1"

  if [[ -r "${OPENCLAW_STATE_DIR}/setup-v7/shell-env" ]]; then
    # shellcheck source=/dev/null
    source "${OPENCLAW_STATE_DIR}/setup-v7/shell-env"
  fi
  export OPENCLAW_STATE_DIR OPENCLAW_CONFIG_PATH
  trap on_exit EXIT
  acquire_lock
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-add-agent.XXXXXX")"

  preflight
  read_inputs

  local bot_context bot_id bot_username verify_code owner_id channels_before_file
  local default_telegram_context default_telegram_account_id default_telegram_bot_id
  local agents_file default_context default_agent_id source_workspace model
  local provider_context secret_provider secret_pointer
  bot_context="$(telegram_get_me "${BOT_TOKEN}")"
  IFS=$'\t' read -r bot_id bot_username <<< "${bot_context}"
  AGENT_ID="$(derive_agent_id "${bot_username}")"
  [[ "${AGENT_ID}" =~ ^[a-z][a-z0-9-]{0,62}$ ]] || die "could not derive a safe agent id from @${bot_username}"
  AGENT_WORKSPACE="${OPENCLAW_STATE_DIR}/workspace-${AGENT_ID}"
  AGENT_STATE_DIR="${OPENCLAW_STATE_DIR}/agents/${AGENT_ID}"
  ok "Telegram bot verified: @${bot_username} (${bot_id})"

  agents_file="${TEMP_DIR}/agents-before.json"
  "${OPENCLAW_BIN}" agents list --json > "${agents_file}"
  agent_id_exists "${agents_file}" "${AGENT_ID}" && die "agent already exists: ${AGENT_ID}"
  telegram_account_exists "${OPENCLAW_CONFIG_PATH}" "${AGENT_ID}" && \
    die "Telegram account already exists: ${AGENT_ID}"
  [[ ! -e "${AGENT_WORKSPACE}" ]] || die "workspace already exists: ${AGENT_WORKSPACE}"
  [[ ! -e "${AGENT_STATE_DIR}" ]] || die "agent state already exists: ${AGENT_STATE_DIR}"
  channels_before_file="${TEMP_DIR}/channels-before.json"
  "${OPENCLAW_BIN}" channels status --channel telegram --probe --json > "${channels_before_file}"
  default_telegram_context="$(read_default_telegram_account_context "${channels_before_file}")"
  IFS=$'\t' read -r default_telegram_account_id default_telegram_bot_id \
    <<< "${default_telegram_context}"
  telegram_bot_id_exists_in_status_file "${channels_before_file}" "${bot_id}" && \
    die "this Telegram bot is already configured in the Gateway"

  default_context="$(read_default_agent_context "${agents_file}")"
  IFS=$'\t' read -r default_agent_id source_workspace model <<< "${default_context}"
  [[ "${default_agent_id}" == "main" ]] || \
    die "the default agent must be main for safe auth inheritance (found: ${default_agent_id})"
  [[ -d "${source_workspace}" ]] || die "default agent workspace is missing: ${source_workspace}"
  provider_context="$(read_file_secret_provider "${OPENCLAW_CONFIG_PATH}")"
  IFS=$'\t' read -r secret_provider SECRET_FILE <<< "${provider_context}"

  owner_id="${OPENCLAW_TELEGRAM_OWNER_ID:-}"
  if [[ -n "${owner_id}" ]]; then
    [[ "${owner_id}" =~ ^[0-9]+$ ]] || die "OPENCLAW_TELEGRAM_OWNER_ID must be numeric"
    ok "Using the supplied Telegram owner id"
  else
    verify_code="$(generate_verify_code)"
    owner_id="$(detect_telegram_owner_id "${BOT_TOKEN}" "${bot_username}" "${verify_code}")" || \
      die "Telegram owner verification failed"
    [[ "${owner_id}" =~ ^[0-9]+$ ]] || die "detected Telegram owner id is invalid"
    ok "Telegram owner verified: ${owner_id}"
  fi

  backup_state
  ROLLBACK_NEEDED=1
  info "Creating isolated agent ${AGENT_ID} with model ${model}"
  create_openclaw_agent "${AGENT_ID}" "${DISPLAY_NAME}" \
    "${source_workspace}" "${AGENT_WORKSPACE}" "${model}"
  apply_secondary_memory_isolation "${OPENCLAW_CONFIG_PATH}" "${AGENT_ID}"

  secret_pointer="$(write_telegram_secret "${SECRET_FILE}" "${AGENT_ID}" "${BOT_TOKEN}")"
  SECRET_WRITTEN=1
  configure_telegram_account "${AGENT_ID}" "${DISPLAY_NAME}" "${owner_id}" \
    "${secret_provider}" "${secret_pointer}" "${BOT_TOKEN}"
  bind_telegram_account "${AGENT_ID}"
  restart_gateway
  verify_provision "${AGENT_ID}" "${AGENT_WORKSPACE}" "${model}" "${owner_id}" \
    "${bot_id}" "${default_telegram_account_id}" "${default_telegram_bot_id}" \
    "${secret_provider}" "${secret_pointer}"

  ROLLBACK_NEEDED=0
  ok "Agent added: ${AGENT_ID}"
  printf '  Name: %s\n' "${DISPLAY_NAME}"
  printf '  Telegram: @%s\n' "${bot_username}"
  printf '  Model: %s\n' "${model}"
  printf '  Workspace: %s\n' "${AGENT_WORKSPACE}"
  printf '  Verification: %s\n' "${RUN_DIR}"
}

if [[ "${OPENCLAW_ADD_AGENT_TEST_MODE:-0}" != "1" ]]; then
  main "$@"
fi
