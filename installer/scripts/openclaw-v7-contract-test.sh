#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="${ROOT_DIR}/installer/scripts/openclaw-setup-v7.sh"
HARNESS="${ROOT_DIR}/installer/scripts/openclaw-v7-e2e-harness.sh"

# Load the installer contract without executing main. macOS Bash 3.2 scopes
# process-substitution sources unexpectedly, so evaluate the stripped script.
eval "$(sed '/^main "\$@"$/,$d' "${INSTALLER}")"
trap - EXIT

fail_test() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  [[ "${actual}" == "${expected}" ]] || fail_test "${label}: expected=${expected} actual=${actual}"
  printf 'ok - %s\n' "${label}"
}

assert_true() {
  local label="$1"
  shift
  "$@" || fail_test "${label}"
  printf 'ok - %s\n' "${label}"
}

assert_false() {
  local label="$1"
  shift
  if "$@"; then
    fail_test "${label}"
  fi
  printf 'ok - %s\n' "${label}"
}

assert_eq "openclaw@2026.7.1" "${OPENCLAW_NPM_SPEC}" "default OpenClaw stable pin"
assert_eq "npm:@openclaw/memory-lancedb@2026.7.1" "${OPENCLAW_V7_LANCEDB_INSTALL_SPEC}" "memory-lancedb stable npm pin"
assert_eq "2026.7.1" "${OPENCLAW_V7_CODEX_MIN_OPENCLAW_VERSION}" "Codex host minimum"
assert_eq "@openai/codex@0.144.3" "${OPENCLAW_V7_CODEX_CLI_INSTALL_SPEC}" "Codex CLI Sol compatibility pin"
assert_eq "openai/gpt-5.6-sol" "${OPENCLAW_V7_DEFAULT_MODEL}" "default GPT-5.6 Sol model"

assert_eq \
  "2026.7.1" \
  "$(openclaw_version_number 'OpenClaw 2026.7.1 (2d2ddc4)')" \
  "CLI stable version parsing"

OPENCLAW_NPM_SPEC="openclaw@2026.7.1"
assert_eq "2026.7.1" "$(openclaw_spec_version_number)" "npm stable spec parsing"
assert_eq \
  "2026.7.1" \
  "$(codex_install_spec_version_number 'npm:@openclaw/codex@2026.7.1')" \
  "Codex npm stable spec parsing"

assert_true "beta.2 sorts after beta.1" version_ge "2026.7.1-beta.2" "2026.7.1-beta.1"
assert_false "beta.1 sorts before beta.2" version_ge "2026.7.1-beta.1" "2026.7.1-beta.2"
assert_true "stable sorts after prerelease" version_ge "2026.7.1" "2026.7.1-beta.2"
assert_false "prerelease sorts before stable" version_ge "2026.7.1-beta.2" "2026.7.1"

assert_true "Node 22.22.3 is supported" node_version_supported "22.22.3"
assert_false "Node 22.22.2 is rejected" node_version_supported "22.22.2"
assert_false "Node 23 is rejected" node_version_supported "23.11.0"
assert_true "Node 24.15 is supported" node_version_supported "24.15.0"
assert_false "Node 24.14 is rejected" node_version_supported "24.14.99"
assert_true "Node 25.9 is supported" node_version_supported "25.9.0"
assert_false "Node 25.8 is rejected" node_version_supported "25.8.99"
assert_true "Node 26 is supported" node_version_supported "26.0.0"

DRY_RUN=1
OPENCLAW_V7_CODEX_INSTALL_SPEC=auto
resolve_codex_harness_install_spec
assert_eq \
  "npm:@openclaw/codex@2026.7.1" \
  "${OPENCLAW_V7_CODEX_RESOLVED_INSTALL_SPEC}" \
  "Codex auto pin uses the trusted npm package"
assert_eq "2026.7.1" "${OPENCLAW_V7_CODEX_TARGET_VERSION}" "Codex target stable"

assert_eq "npm" "$(plugin_install_spec_source 'npm:@openclaw/codex@2026.7.1')" "npm plugin source parsing"
assert_eq "clawhub" "$(plugin_install_spec_source 'clawhub:@openclaw/codex@2026.7.1')" "ClawHub plugin source parsing"
plugin_fixture='{"plugin":{"id":"codex","version":"2026.7.1"},"install":{"source":"npm","version":"2026.7.1"}}'
assert_true "matching plugin version and source are reusable" plugin_install_metadata_matches "${plugin_fixture}" "2026.7.1" "npm"
assert_false "same-version ClawHub plugin is not reused for npm target" plugin_install_metadata_matches "${plugin_fixture}" "2026.7.1" "clawhub"
assert_false "beta plugin is not reused for stable target" plugin_install_metadata_matches "${plugin_fixture}" "2026.7.1-beta.2" "npm"

rg -q '^EXPECTED_DEFAULT_MODEL="\$\{EXPECTED_DEFAULT_MODEL:-openai/gpt-5\.6-sol\}"$' "${HARNESS}" \
  || fail_test "harness default model contract"
rg -q '^EXPECT_CODEX_HARNESS="\$\{EXPECT_CODEX_HARNESS:-1\}"$' "${HARNESS}" \
  || fail_test "stable harness requires Codex verification by default"
rg -q 'openclaw models list --all --provider openai --json' "${HARNESS}" \
  || fail_test "harness GPT-5.6 model catalog probe"
rg -q 'openclaw plugins inspect codex --runtime --json' "${HARNESS}" \
  || fail_test "harness Codex runtime inspection contract"
rg -q 'plugins inspect codex --runtime --json' "${INSTALLER}" \
  || fail_test "installer Codex runtime inspection contract"
rg -q 'app_server\["command"\] = os.environ\["CODEX_CLI_COMMAND"\]' "${INSTALLER}" \
  || fail_test "Codex app-server external CLI contract"
rg -q 'plugin_install_matches memory-lancedb' "${INSTALLER}" \
  || fail_test "memory-lancedb version and source reuse contract"
rg -q 'plugin_install_matches codex' "${INSTALLER}" \
  || fail_test "Codex version and source reuse contract"
rg -q '^approve_local_cli_scope_upgrade()' "${INSTALLER}" \
  || fail_test "local CLI scope upgrade repair contract"
rg -q 'devices approve "\$\{request_id\}" --json' "${INSTALLER}" \
  || fail_test "local CLI scope approval command"
printf 'ok - harness GPT-5.6 contract\n'

scope_fixture_dir="$(mktemp -d)"
trap 'rm -rf "${scope_fixture_dir}"' EXIT
printf '%s\n' '{"paired":[{"deviceId":"same","clientId":"cli","role":"operator","scopes":["operator.read"]}],"pending":[{"requestId":"safe-request","deviceId":"same","clientId":"cli","platform":"darwin","role":"operator","scopes":["operator.write","operator.admin"]}]}' \
  > "${scope_fixture_dir}/safe.json"
printf '%s\n' '{"paired":[{"deviceId":"same","clientId":"cli","role":"operator","scopes":["operator.read"]}],"pending":[{"requestId":"other-device","deviceId":"other","clientId":"cli","platform":"darwin","role":"operator","scopes":["operator.write","operator.admin"]},{"requestId":"unknown-scope","deviceId":"same","clientId":"cli","platform":"darwin","role":"operator","scopes":["operator.write","operator.admin","operator.root"]}]}' \
  > "${scope_fixture_dir}/unsafe.json"
assert_eq "safe-request" "$(local_cli_scope_upgrade_request_id "${scope_fixture_dir}/safe.json")" "same-device CLI scope upgrade selection"
assert_eq "" "$(local_cli_scope_upgrade_request_id "${scope_fixture_dir}/unsafe.json")" "unsafe device scope upgrades rejected"

printf '%s\n' '{"auth":{"runtimeAuthRoutes":[{"provider":"openai","status":"usable"}],"providers":[{"provider":"openai","effective":{"kind":"profiles"},"profiles":{"count":1}},{"provider":"google","effective":{"kind":"profiles"},"profiles":{"count":1}}]}}' \
  > "${scope_fixture_dir}/sqlite-auth.json"
printf '%s\n' '{"auth":{"runtimeAuthRoutes":[{"provider":"openai","runtime":"codex","status":"usable","effective":{"kind":"synthetic","detail":"codex-app-server"}}],"providers":[{"provider":"openai","effective":{"kind":"synthetic","detail":"codex-app-server"},"profiles":{"count":0}}]}}' \
  > "${scope_fixture_dir}/synthetic-codex-auth.json"
printf '%s\n' '{"auth":{"runtimeAuthRoutes":[],"providers":[]}}' \
  > "${scope_fixture_dir}/empty-auth.json"
assert_eq "2" "$(models_status_auth_count_from_file "${scope_fixture_dir}/sqlite-auth.json")" "SQLite auth profiles detected from models status"
assert_eq "0" "$(models_status_auth_count_from_file "${scope_fixture_dir}/empty-auth.json")" "empty models status has no auth"
assert_eq "0" "$(models_status_auth_count_from_file "${scope_fixture_dir}/synthetic-codex-auth.json")" "synthetic Codex route does not count as account auth"
assert_false \
  "synthetic Codex route is not a stored OpenAI credential" \
  models_status_provider_has_direct_auth_from_file \
  "${scope_fixture_dir}/synthetic-codex-auth.json" \
  openai

telegram_fixture_dir="${scope_fixture_dir}/telegram-progress"
mkdir -p "${telegram_fixture_dir}"
printf '%s\n' '{"channels":{"telegram":{"enabled":true,"botToken":"fixture-token"}}}' \
  > "${telegram_fixture_dir}/openclaw.json"
(
  DRY_RUN=0
  CONFIG_DIR="${telegram_fixture_dir}"
  OPENCLAW_V7_ENABLE_FULL_TOOLS=0
  configure_premium_defaults >/dev/null
)
python3 - "${telegram_fixture_dir}/openclaw.json" <<'PYEOF'
import json, pathlib, sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
telegram = config["channels"]["telegram"]
streaming = telegram["streaming"]
assert streaming["mode"] == "progress"
assert streaming["progress"] == {"toolProgress": True, "commandText": "status"}
assert streaming["block"]["enabled"] is False
assert telegram["richMessages"] is False
PYEOF
printf 'ok - Telegram progress streaming defaults\n'

no_telegram_fixture_dir="${scope_fixture_dir}/no-telegram"
mkdir -p "${no_telegram_fixture_dir}"
printf '%s\n' '{}' > "${no_telegram_fixture_dir}/openclaw.json"
(
  DRY_RUN=0
  CONFIG_DIR="${no_telegram_fixture_dir}"
  OPENCLAW_V7_ENABLE_FULL_TOOLS=0
  configure_premium_defaults >/dev/null
)
python3 - "${no_telegram_fixture_dir}/openclaw.json" <<'PYEOF'
import json, pathlib, sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert "telegram" not in config.get("channels", {})
PYEOF
printf 'ok - absent Telegram config stays absent\n'

existing_auth_count() { printf '%s\n' 1; }
model_provider_auth_available() { return 1; }
read_yes_no_default_yes() { return 0; }
choose_auth_interactive() { printf '%s\n' openai-codex-device-code; }
common_onboard_args() { ONBOARD_ARGS=(onboard); }
openclaw_cmd() { printf 'onboard-called:%s\n' "$*"; }
OPENCLAW_V7_AUTH_CHOICE=""
OPENCLAW_V7_EFFECTIVE_AUTH_CHOICE=""
assert_eq \
  "onboard-called:onboard --auth-choice openai-codex-device-code" \
  "$(onboard_interactive | tail -n 1)" \
  "unrelated provider auth does not skip default-model login"

rg -q 'codex_e2e_ts=' "${HARNESS}" \
  || fail_test "harness public installer cache busting"
rg -q 'INSTALLER_SHA256' "${HARNESS}" \
  || fail_test "harness installer SHA verification"
printf 'ok - harness public installer freshness contract\n'

credential_cleanup_dir="${scope_fixture_dir}/credential-cleanup"
mkdir -p "${credential_cleanup_dir}/evidence"
set +e
TMPDIR="${credential_cleanup_dir}" \
EVIDENCE_DIR="${credential_cleanup_dir}/evidence" \
AUTH_CHOICE="openai-api-key" \
AUTH_SECRET_ENV="TEST_AUTH_SECRET" \
TEST_AUTH_SECRET="sentinel-auth-secret" \
GEMINI_SECRET_ENV="TEST_GEMINI_SECRET" \
TEST_GEMINI_SECRET="sentinel-gemini-secret" \
bash -c '
set -euo pipefail
HARNESS="$1"
eval "$(sed '\''/^main \"\$@\"$/,$d'\'' "${HARNESS}")"
ssh_remote() { exit 91; }
scp_to_remote() { exit 92; }
stage_credentials
' _ "${HARNESS}" >/dev/null 2>&1
credential_cleanup_rc=$?
set -e
if [[ "${credential_cleanup_rc}" == "0" ]]; then
  fail_test "credential staging propagates remote failure"
fi
printf 'ok - credential staging propagates remote failure\n'
if rg -q 'sentinel-(auth|gemini)-secret' "${credential_cleanup_dir}"; then
  fail_test "credential staging removes generated local secret files after failure"
fi
printf 'ok - credential staging removes generated local secret files after failure\n'

rg -q '"hooks": \{"allowConversationAccess": True\}' "${INSTALLER}" \
  || fail_test "memory-lancedb conversation hook permission"
printf 'ok - memory-lancedb conversation hook permission\n'
