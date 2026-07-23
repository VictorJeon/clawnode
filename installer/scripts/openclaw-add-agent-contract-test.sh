#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROVISIONER="${ROOT_DIR}/installer/scripts/openclaw-add-agent.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [[ "${expected}" != "${actual}" ]]; then
    fail "${label}: expected '${expected}', got '${actual}'"
  fi
  printf 'PASS: %s\n' "${label}"
}

assert_exists() {
  [[ -e "$1" ]] || fail "$2: expected $1 to exist"
  printf 'PASS: %s\n' "$2"
}

assert_missing() {
  [[ ! -e "$1" ]] || fail "$2: expected $1 to be absent"
  printf 'PASS: %s\n' "$2"
}

assert_contains() {
  local needle="$1" file="$2" label="$3"
  grep -Fq -- "${needle}" "${file}" || fail "${label}: missing '${needle}'"
  printf 'PASS: %s\n' "${label}"
}

assert_not_contains() {
  local needle="$1" file="$2" label="$3"
  if grep -Fq -- "${needle}" "${file}"; then
    fail "${label}: unexpectedly found '${needle}'"
  fi
  printf 'PASS: %s\n' "${label}"
}

assert_true() {
  local label="$1"
  shift
  "$@" || fail "${label}"
  printf 'PASS: %s\n' "${label}"
}

assert_false() {
  local label="$1"
  shift
  if "$@"; then
    fail "${label}"
  fi
  printf 'PASS: %s\n' "${label}"
}

[[ -f "${PROVISIONER}" ]] || fail "missing provisioner: ${PROVISIONER}"

OPENCLAW_ADD_AGENT_TEST_MODE=1
# shellcheck source=/dev/null
source "${PROVISIONER}"

assert_eq "clawnode-sales-bot" "$(derive_agent_id '@ClawNode_Sales_Bot')" \
  "Telegram username becomes a safe agent id"

fixture_dir="$(mktemp -d)"
trap 'rm -rf "${fixture_dir}"' EXIT
source_workspace="${fixture_dir}/workspace-main"
target_workspace="${fixture_dir}/workspace-sales"
mkdir -p "${source_workspace}/skills/reporter" "${source_workspace}/memory" \
  "${source_workspace}/.git"
printf 'same operating rules\n' > "${source_workspace}/AGENTS.md"
printf 'same persona\n' > "${source_workspace}/SOUL.md"
printf 'same owner\n' > "${source_workspace}/USER.md"
printf 'shared skill snapshot\n' > "${source_workspace}/skills/reporter/SKILL.md"
printf 'private memory\n' > "${source_workspace}/MEMORY.md"
printf 'private detail\n' > "${source_workspace}/memory/private.md"
printf 'repository metadata\n' > "${source_workspace}/.git/config"

seed_workspace "${source_workspace}" "${target_workspace}"

assert_exists "${target_workspace}/AGENTS.md" "operating rules are seeded"
assert_exists "${target_workspace}/SOUL.md" "persona is seeded"
assert_exists "${target_workspace}/USER.md" "owner profile is seeded"
assert_exists "${target_workspace}/skills/reporter/SKILL.md" \
  "workspace skills are copied as an isolated snapshot"
assert_missing "${target_workspace}/MEMORY.md" "top-level memory is isolated"
assert_missing "${target_workspace}/memory" "memory directory is isolated"
assert_missing "${target_workspace}/.git" "repository metadata is not copied"

updates_fixture="${fixture_dir}/updates.json"
printf '%s\n' '{"ok":true,"result":[{"update_id":10,"message":{"text":"old-code","from":{"id":111,"is_bot":false},"chat":{"type":"private"}}},{"update_id":11,"message":{"text":"clawnode-link-a1b2c3d4","from":{"id":7484970138,"is_bot":false},"chat":{"type":"private"}}},{"update_id":12,"message":{"text":"clawnode-link-a1b2c3d4","from":{"id":999999,"is_bot":false},"chat":{"type":"group"}}}]}' \
  > "${updates_fixture}"
assert_eq "7484970138" \
  "$(extract_owner_id_from_updates_file "${updates_fixture}" 'clawnode-link-a1b2c3d4')" \
  "one-time Telegram message identifies only its sender"

secret_fixture="${fixture_dir}/secrets-v7.json"
printf '%s\n' '{"existing":{"value":"preserved"}}' > "${secret_fixture}"
secret_pointer="$(write_telegram_secret "${secret_fixture}" 'clawnode-sales-bot' '123456:fixture_token_value_abcdefghijklmnopqrstuvwxyz')"
assert_eq "/openclaw-add-agent/telegram/accounts/clawnode-sales-bot/botToken" \
  "${secret_pointer}" "Telegram token gets a stable SecretRef pointer"
assert_eq "preserved" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["existing"]["value"])' "${secret_fixture}")" \
  "existing secrets are preserved"
assert_eq "123456:fixture_token_value_abcdefghijklmnopqrstuvwxyz" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["openclaw-add-agent"]["telegram"]["accounts"]["clawnode-sales-bot"]["botToken"])' "${secret_fixture}")" \
  "Telegram token is stored outside openclaw.json"
secret_mode="$(stat -f '%Lp' "${secret_fixture}" 2>/dev/null || stat -c '%a' "${secret_fixture}")"
assert_eq "600" "${secret_mode}" "SecretRef file permissions stay private"

fake_openclaw="${fixture_dir}/openclaw"
command_log="${fixture_dir}/openclaw-commands.log"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" >> "${FAKE_OPENCLAW_LOG:?}"' \
  > "${fake_openclaw}"
chmod +x "${fake_openclaw}"
OPENCLAW_BIN="${fake_openclaw}"
FAKE_OPENCLAW_LOG="${command_log}"
TEMP_DIR="${fixture_dir}"
export OPENCLAW_BIN FAKE_OPENCLAW_LOG

configure_telegram_account \
  "clawnode-sales-bot" \
  "ClawNode Sales" \
  "7484970138" \
  "openclawv7" \
  "${secret_pointer}" \
  "123456:fixture_token_value_abcdefghijklmnopqrstuvwxyz"

assert_contains \
  "channels add --channel telegram --account clawnode-sales-bot --name ClawNode Sales --token-file ${TEMP_DIR}/telegram-clawnode-sales-bot.token" \
  "${command_log}" "OpenClaw promotes the legacy default before adding a named account"
assert_contains \
  "config set channels.telegram.accounts.clawnode-sales-bot.botToken --ref-provider openclawv7 --ref-source file --ref-id ${secret_pointer}" \
  "${command_log}" "Telegram account references the external secret"
assert_contains \
  "config unset channels.telegram.accounts.clawnode-sales-bot.tokenFile" \
  "${command_log}" "temporary Telegram token-file config is removed"
assert_contains \
  "config set channels.telegram.accounts.clawnode-sales-bot.dmPolicy \"allowlist\" --strict-json" \
  "${command_log}" "new Telegram account is allowlist-only"
assert_contains \
  "config set channels.telegram.accounts.clawnode-sales-bot.allowFrom [\"7484970138\"] --strict-json" \
  "${command_log}" "detected owner is the only allowed sender"
assert_not_contains \
  "123456:fixture_token_value_abcdefghijklmnopqrstuvwxyz" \
  "${command_log}" "bot token never enters OpenClaw command arguments"

failing_openclaw="${fixture_dir}/openclaw-failing"
failure_log="${fixture_dir}/openclaw-failures.log"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" >> "${FAKE_OPENCLAW_LOG:?}"' \
  'if [[ "$*" == "${FAKE_OPENCLAW_FAIL_PREFIX:-}"* ]]; then exit 42; fi' \
  > "${failing_openclaw}"
chmod +x "${failing_openclaw}"
OPENCLAW_BIN="${failing_openclaw}"
FAKE_OPENCLAW_LOG="${failure_log}"
export OPENCLAW_BIN FAKE_OPENCLAW_LOG

: > "${failure_log}"
FAKE_OPENCLAW_FAIL_PREFIX="agents add"
export FAKE_OPENCLAW_FAIL_PREFIX
CREATED_AGENT=0
assert_false "failed agent creation returns failure" \
  create_openclaw_agent "failed-agent" "Failed Agent" "${source_workspace}" \
    "${fixture_dir}/state-failed/workspace-failed-agent" "openai/gpt-5.6-sol"
assert_eq "0" "${CREATED_AGENT}" "failed agent creation is not rollback-owned"
AGENT_ID="failed-agent"
OPENCLAW_STATE_DIR="${fixture_dir}/state-failed"
AGENT_WORKSPACE="${OPENCLAW_STATE_DIR}/workspace-${AGENT_ID}"
rollback_provision
assert_not_contains "agents delete failed-agent" "${failure_log}" \
  "rollback does not delete an agent this run failed to create"

: > "${failure_log}"
FAKE_OPENCLAW_FAIL_PREFIX="agents bind"
CREATED_BINDING=0
assert_false "failed binding creation returns failure" \
  bind_telegram_account "failed-agent"
assert_eq "0" "${CREATED_BINDING}" "failed binding creation is not rollback-owned"
rollback_provision
assert_not_contains "agents unbind --agent failed-agent" "${failure_log}" \
  "rollback does not unbind a route this run failed to create"

: > "${failure_log}"
FAKE_OPENCLAW_FAIL_PREFIX="channels add"
CREATED_ACCOUNT=0
assert_false "failed Telegram account creation returns failure" \
  configure_telegram_account "failed-agent" "Failed Agent" "7484970138" \
    "openclawv7" "/openclaw-add-agent/telegram/accounts/failed-agent/botToken" \
    "123456:fixture_token_value_abcdefghijklmnopqrstuvwxyz"
assert_eq "0" "${CREATED_ACCOUNT}" "failed Telegram account creation is not rollback-owned"
rollback_provision
assert_not_contains "channels remove --channel telegram --account failed-agent" "${failure_log}" \
  "rollback does not remove an account this run failed to create"

OPENCLAW_BIN="${fake_openclaw}"
FAKE_OPENCLAW_LOG="${command_log}"
unset FAKE_OPENCLAW_FAIL_PREFIX
export OPENCLAW_BIN FAKE_OPENCLAW_LOG

: > "${command_log}"
agent_workspace="${fixture_dir}/workspace-clawnode-sales-bot"
create_openclaw_agent \
  "clawnode-sales-bot" \
  "ClawNode Sales" \
  "${source_workspace}" \
  "${agent_workspace}" \
  "openai/gpt-5.6-sol"
bind_telegram_account "clawnode-sales-bot"

assert_contains \
  "agents add clawnode-sales-bot --workspace ${agent_workspace} --model openai/gpt-5.6-sol --non-interactive --json" \
  "${command_log}" "new agent uses the default agent model in an isolated workspace"
assert_contains \
  "agents set-identity --agent clawnode-sales-bot --name ClawNode Sales --json" \
  "${command_log}" "agent display identity uses the requested bot name"
assert_contains \
  "agents bind --agent clawnode-sales-bot --bind telegram:clawnode-sales-bot --json" \
  "${command_log}" "agent binding targets exactly one Telegram account"
assert_exists "${agent_workspace}/AGENTS.md" "new agent receives seeded operating rules"
assert_missing "${agent_workspace}/MEMORY.md" "new agent never receives main memory"

: > "${command_log}"
CREATED_BINDING=1
CREATED_ACCOUNT=1
CREATED_AGENT=1
SECRET_WRITTEN=1
AGENT_ID="clawnode-sales-bot"
SECRET_FILE="${secret_fixture}"
OPENCLAW_STATE_DIR="${fixture_dir}/state"
AGENT_WORKSPACE="${OPENCLAW_STATE_DIR}/workspace-${AGENT_ID}"
AGENT_STATE_DIR="${OPENCLAW_STATE_DIR}/agents/${AGENT_ID}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_STATE_DIR}/openclaw.json"
mkdir -p "${AGENT_WORKSPACE}" "${AGENT_STATE_DIR}"
printf '%s\n' \
  '{"agents":{"list":[{"id":"main","workspace":"/tmp/main"},{"id":"other-agent","workspace":"/tmp/other"},{"id":"clawnode-sales-bot","workspace":"PLACEHOLDER"}]},"bindings":[{"agentId":"other-agent","match":{"channel":"telegram","accountId":"other"}},{"agentId":"clawnode-sales-bot","match":{"channel":"telegram","accountId":"clawnode-sales-bot"}}],"channels":{"telegram":{"accounts":{"other":{"enabled":true},"clawnode-sales-bot":{"enabled":true}}}}}' \
  | sed "s#PLACEHOLDER#${AGENT_WORKSPACE}#" > "${OPENCLAW_CONFIG_PATH}"
rollback_provision

assert_contains \
  "agents unbind --agent clawnode-sales-bot --bind telegram:clawnode-sales-bot --json" \
  "${command_log}" "rollback removes only the new exact binding"
assert_contains \
  "channels remove --channel telegram --account clawnode-sales-bot --delete" \
  "${command_log}" "rollback removes only the new Telegram account"
assert_contains \
  "agents delete clawnode-sales-bot --force --json" \
  "${command_log}" "rollback removes only the new agent"
assert_eq "missing" \
  "$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print("present" if "clawnode-sales-bot" in p.get("openclaw-add-agent",{}).get("telegram",{}).get("accounts",{}) else "missing")' "${secret_fixture}")" \
  "rollback removes only the new Telegram secret"
assert_eq "preserved" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["existing"]["value"])' "${secret_fixture}")" \
  "rollback preserves unrelated secrets"
assert_missing "${AGENT_WORKSPACE}" "rollback removes the new agent workspace"
assert_missing "${AGENT_STATE_DIR}" "rollback removes the new agent state directory"
assert_eq "absent" \
  "$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print("present" if any(a.get("id")=="clawnode-sales-bot" for a in p["agents"]["list"]) else "absent")' "${OPENCLAW_CONFIG_PATH}")" \
  "local rollback fallback removes the owned agent config"
assert_eq "absent" \
  "$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print("present" if "clawnode-sales-bot" in p["channels"]["telegram"]["accounts"] else "absent")' "${OPENCLAW_CONFIG_PATH}")" \
  "local rollback fallback removes the owned Telegram account config"
assert_eq "absent" \
  "$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print("present" if any(b.get("agentId")=="clawnode-sales-bot" for b in p["bindings"]) else "absent")' "${OPENCLAW_CONFIG_PATH}")" \
  "local rollback fallback removes the owned exact binding"
assert_eq "preserved" \
  "$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); ok=any(a.get("id")=="other-agent" for a in p["agents"]["list"]) and "other" in p["channels"]["telegram"]["accounts"] and any(b.get("agentId")=="other-agent" for b in p["bindings"]); print("preserved" if ok else "missing")' "${OPENCLAW_CONFIG_PATH}")" \
  "local rollback fallback preserves unrelated resources"

agents_fixture="${fixture_dir}/agents.json"
config_fixture="${fixture_dir}/openclaw.json"
printf '%s\n' '[{"id":"main","name":"Main","workspace":"/tmp/workspace-main","agentDir":"/tmp/agents/main/agent","model":"openai/gpt-5.6-sol","isDefault":true}]' \
  > "${agents_fixture}"
printf '%s\n' '{"secrets":{"providers":{"openclawv7":{"source":"file","path":"/tmp/secrets-v7.json","mode":"json"}},"defaults":{"file":"openclawv7"}}}' \
  > "${config_fixture}"
assert_eq $'main\t/tmp/workspace-main\topenai/gpt-5.6-sol' \
  "$(read_default_agent_context "${agents_fixture}")" \
  "default agent context supplies the inherited workspace and model"
assert_eq $'openclawv7\t/tmp/secrets-v7.json' \
  "$(read_file_secret_provider "${config_fixture}")" \
  "installer SecretRef provider is reused"
duplicate_agents_fixture="${fixture_dir}/agents-duplicate.json"
duplicate_config_fixture="${fixture_dir}/config-duplicate.json"
printf '%s\n' '[{"id":"main","isDefault":true},{"id":"clawnode-sales-bot"}]' \
  > "${duplicate_agents_fixture}"
printf '%s\n' '{"channels":{"telegram":{"accounts":{"clawnode-sales-bot":{"enabled":true}}}}}' \
  > "${duplicate_config_fixture}"
assert_true "existing agent ids are rejected before mutation" \
  agent_id_exists "${duplicate_agents_fixture}" "clawnode-sales-bot"
assert_false "unused agent ids remain available" \
  agent_id_exists "${duplicate_agents_fixture}" "clawnode-support-bot"
assert_true "existing Telegram account ids are rejected before mutation" \
  telegram_account_exists "${duplicate_config_fixture}" "clawnode-sales-bot"

channel_status_fixture="${fixture_dir}/channels-status.json"
printf '%s\n' '{"channelAccounts":{"telegram":[{"accountId":"default","enabled":true,"configured":true,"running":true,"connected":true,"probe":{"ok":true,"botInfo":{"id":8687155886,"username":"existing_bot"}}}]}}' \
  > "${channel_status_fixture}"
assert_true "existing Telegram bot identities are rejected before mutation" \
  telegram_bot_id_exists_in_status_file "${channel_status_fixture}" "8687155886"
assert_false "unused Telegram bot identities remain available" \
  telegram_bot_id_exists_in_status_file "${channel_status_fixture}" "9999999999"
assert_true "final Telegram account probe confirms the exact bot" \
  verify_telegram_account_status "${channel_status_fixture}" "default" "8687155886"
assert_eq $'default\t8687155886' \
  "$(read_default_telegram_account_context "${channel_status_fixture}")" \
  "existing default Telegram route is captured before mutation"
python3 - "${channel_status_fixture}" "${fixture_dir}/channels-disconnected.json" <<'PYEOF'
import json, pathlib, sys
payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
payload["channelAccounts"]["telegram"][0]["connected"] = False
pathlib.Path(sys.argv[2]).write_text(json.dumps(payload) + "\n")
PYEOF
assert_false "final Telegram account probe rejects a disconnected bot" \
  verify_telegram_account_status "${fixture_dir}/channels-disconnected.json" "default" "8687155886"

memory_config_fixture="${fixture_dir}/config-memory.json"
printf '%s\n' '{"agents":{"list":[{"id":"main"},{"id":"clawnode-sales-bot"}]},"plugins":{"slots":{"memory":"memory-lancedb"},"entries":{"memory-lancedb":{"enabled":true,"config":{"autoRecall":true,"autoCapture":false}},"memory-wiki":{"enabled":true}}}}' \
  > "${memory_config_fixture}"
: > "${command_log}"
apply_secondary_memory_isolation "${memory_config_fixture}" "clawnode-sales-bot"
assert_contains \
  "config set plugins.entries.memory-lancedb.config.autoRecall false --strict-json" \
  "${command_log}" "shared LanceDB auto-recall is disabled before secondary-agent use"
assert_contains \
  "config set agents.list[1].tools.deny [\"memory_recall\",\"memory_store\",\"memory_forget\",\"wiki_status\",\"wiki_lint\",\"wiki_apply\",\"wiki_search\",\"wiki_get\"] --strict-json" \
  "${command_log}" "secondary agent cannot access globally shared plugin memory"
memory_merge_fixture="${fixture_dir}/config-memory-merge.json"
printf '%s\n' '{"agents":{"list":[{"id":"main"},{"id":"clawnode-sales-bot","tools":{"deny":["existing_tool"]}}]},"plugins":{"slots":{"memory":"memory-lancedb"},"entries":{"memory-lancedb":{"enabled":true,"config":{"autoRecall":false,"autoCapture":false}}}}}' \
  > "${memory_merge_fixture}"
: > "${command_log}"
apply_secondary_memory_isolation "${memory_merge_fixture}" "clawnode-sales-bot"
assert_contains \
  "config set agents.list[1].tools.deny [\"existing_tool\",\"memory_recall\",\"memory_store\",\"memory_forget\",\"wiki_status\",\"wiki_lint\",\"wiki_apply\",\"wiki_search\",\"wiki_get\"] --strict-json" \
  "${command_log}" "memory isolation preserves existing agent tool denials"

verified_config_fixture="${fixture_dir}/config-verified.json"
printf '%s\n' '{"agents":{"list":[{"id":"main"},{"id":"clawnode-sales-bot","tools":{"deny":["memory_recall","memory_store","memory_forget","wiki_status","wiki_lint","wiki_apply","wiki_search","wiki_get"]}}]},"channels":{"telegram":{"accounts":{"clawnode-sales-bot":{"enabled":true,"botToken":{"source":"file","provider":"openclawv7","id":"/openclaw-add-agent/telegram/accounts/clawnode-sales-bot/botToken"},"dmPolicy":"allowlist","allowFrom":["7484970138"]}}}},"plugins":{"slots":{"memory":"memory-lancedb"},"entries":{"memory-lancedb":{"enabled":true,"config":{"autoRecall":false,"autoCapture":false}}}}}' \
  > "${verified_config_fixture}"
assert_true "final config verifier accepts isolated secondary memory" \
  verify_provisioned_config "${verified_config_fixture}" "clawnode-sales-bot" "7484970138" "openclawv7" \
    "/openclaw-add-agent/telegram/accounts/clawnode-sales-bot/botToken"
python3 - "${verified_config_fixture}" "${fixture_dir}/config-leaky.json" <<'PYEOF'
import json, pathlib, sys
cfg = json.loads(pathlib.Path(sys.argv[1]).read_text())
cfg["plugins"]["entries"]["memory-lancedb"]["config"]["autoRecall"] = True
pathlib.Path(sys.argv[2]).write_text(json.dumps(cfg) + "\n")
PYEOF
assert_false "final config verifier rejects shared LanceDB auto-recall" \
  verify_provisioned_config "${fixture_dir}/config-leaky.json" "clawnode-sales-bot" "7484970138" "openclawv7" \
    "/openclaw-add-agent/telegram/accounts/clawnode-sales-bot/botToken"

secrets_audit_fixture="${fixture_dir}/secrets-audit.json"
printf '%s\n' '{"status":"findings","summary":{"plaintextCount":0,"unresolvedRefCount":0,"shadowedRefCount":0,"legacyResidueCount":1}}' \
  > "${secrets_audit_fixture}"
assert_true "secrets audit accepts unrelated legacy OAuth residue" \
  verify_secrets_audit "${secrets_audit_fixture}"
python3 - "${secrets_audit_fixture}" "${fixture_dir}/secrets-unresolved.json" <<'PYEOF'
import json, pathlib, sys
payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
payload["summary"]["unresolvedRefCount"] = 1
pathlib.Path(sys.argv[2]).write_text(json.dumps(payload) + "\n")
PYEOF
assert_false "secrets audit rejects unresolved SecretRefs" \
  verify_secrets_audit "${fixture_dir}/secrets-unresolved.json"

prompt_fixture="${fixture_dir}/prompt-smoke.json"
printf '%s\n' '{"result":{"payloads":[{"text":"AGENT_OK"}],"meta":{"executionTrace":{"winnerProvider":"openai","winnerModel":"gpt-5.6-sol"}}}}' \
  > "${prompt_fixture}"
assert_true "prompt smoke proves inherited GPT-5.6 Sol execution" \
  verify_prompt_smoke "${prompt_fixture}" "openai/gpt-5.6-sol"

printf 'All openclaw add-agent contract tests passed.\n'
