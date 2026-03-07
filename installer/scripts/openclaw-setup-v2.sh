#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw Quick Setup v2-memory — 개발용 V2 래퍼
#
# 목적:
#   기존 openclaw-setup.sh는 그대로 두고,
#   V2에서는 core 설치 후 Memory V3 payload를 별도 단계로 붙인다.
#
# 현재 범위:
#   1. 기존 core setup 실행
#   2. memory payload staging
#   3. Native PostgreSQL + migration
#   4. Python venv + requirements
#   5. workspace bootstrap + plugin patch
#
# 아직 미구현:
#   - launchd 등록
#   - health check / daemon bring-up
# ============================================================================

DRY_RUN="${DRY_RUN:-0}"
SKIP_CORE_SETUP="${SKIP_CORE_SETUP:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/openclaw-setup.sh"
PAYLOAD_TEMPLATE_DIR="${REPO_ROOT}/installer/templates/memory-v3/payload"
BASE_SCHEMA_TEMPLATE="${REPO_ROOT}/installer/templates/memory-v3/001_base_schema.sql"

SERVICE_ROOT="${HOME}/.openclaw/services/memory-v2"
SERVICE_ENV_FILE="${SERVICE_ROOT}/.env"
CONFIG_DIR="${HOME}/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
WORKSPACE="${CONFIG_DIR}/workspace"

PG_FORMULA="${PG_FORMULA:-postgresql@16}"
PG_DB="${PG_DB:-memory_v2}"
PG_HOST="${PG_HOST:-127.0.0.1}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-$(whoami)}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"

info()  { printf '[INFO] %s\n' "$*"; }
ok()    { printf '[ OK ] %s\n' "$*"; }
warn()  { printf '[WARN] %s\n' "$*"; }
err()   { printf '[ERR ] %s\n' "$*" >&2; }

dry() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] $*"
    return 0
  fi
  "$@"
}

run_core_setup() {
  if [[ "${SKIP_CORE_SETUP}" == "1" ]]; then
    warn "SKIP_CORE_SETUP=1 — 기존 core setup 단계는 건너뜁니다."
    return 0
  fi

  info "기존 core setup 실행"
  dry bash "${CORE_SCRIPT}"
}

replace_or_append_env() {
  local key="$1"
  local value="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] env ${key}=${value}"
    return 0
  fi

  touch "${SERVICE_ENV_FILE}"
  chmod 600 "${SERVICE_ENV_FILE}"
  if grep -q "^${key}=" "${SERVICE_ENV_FILE}" 2>/dev/null; then
    perl -0pi -e "s#^${key}=.*#${key}=${value//\\/\\\\}#m" "${SERVICE_ENV_FILE}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${SERVICE_ENV_FILE}"
  fi
}

get_pg_prefix() {
  if command -v brew >/dev/null 2>&1; then
    brew --prefix "${PG_FORMULA}"
    return 0
  fi
  return 1
}

get_psql_bin() {
  local prefix
  prefix="$(get_pg_prefix 2>/dev/null || true)"
  if [[ -n "${prefix}" && -x "${prefix}/bin/psql" ]]; then
    printf '%s\n' "${prefix}/bin/psql"
    return 0
  fi
  if command -v psql >/dev/null 2>&1; then
    command -v psql
    return 0
  fi
  return 1
}

get_createdb_bin() {
  local prefix
  prefix="$(get_pg_prefix 2>/dev/null || true)"
  if [[ -n "${prefix}" && -x "${prefix}/bin/createdb" ]]; then
    printf '%s\n' "${prefix}/bin/createdb"
    return 0
  fi
  if command -v createdb >/dev/null 2>&1; then
    command -v createdb
    return 0
  fi
  return 1
}

wait_for_postgres() {
  local psql_bin="$1"
  local i
  for i in $(seq 1 20); do
    if "${psql_bin}" -h "${PG_HOST}" -p "${PG_PORT}" -d postgres -Atqc 'SELECT 1' >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

stage_memory_payload() {
  info "memory-v3 payload staging"
  dry mkdir -p "${SERVICE_ROOT}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] rsync -a ${PAYLOAD_TEMPLATE_DIR}/ ${SERVICE_ROOT}/"
  else
    rsync -a --delete \
      --exclude='__pycache__' \
      --exclude='.pytest_cache' \
      "${PAYLOAD_TEMPLATE_DIR}/" "${SERVICE_ROOT}/"
    cp "${BASE_SCHEMA_TEMPLATE}" "${SERVICE_ROOT}/001_base_schema.sql"
    ok "payload 복사 완료: ${SERVICE_ROOT}"
  fi

  if [[ ! -f "${SERVICE_ENV_FILE}" ]]; then
    if [[ "${DRY_RUN}" == "1" ]]; then
      ok "[DRY] create ${SERVICE_ENV_FILE} from .env.example"
    else
      cp "${PAYLOAD_TEMPLATE_DIR}/.env.example" "${SERVICE_ENV_FILE}"
      chmod 600 "${SERVICE_ENV_FILE}"
      ok ".env 초안 생성: ${SERVICE_ENV_FILE}"
    fi
  else
    ok ".env 이미 존재 — 보존"
  fi
}

ensure_native_postgres() {
  local psql_bin createdb_bin pg_prefix

  info "native PostgreSQL 준비"
  if ! command -v brew >/dev/null 2>&1; then
    err "brew가 필요합니다. core setup이 먼저 완료되어야 합니다."
    return 1
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] brew install ${PG_FORMULA} pgvector"
    ok "[DRY] brew services start ${PG_FORMULA}"
    return 0
  fi

  brew list --versions "${PG_FORMULA}" >/dev/null 2>&1 || brew install "${PG_FORMULA}"
  if ! find /opt/homebrew "$(brew --prefix 2>/dev/null || true)" -name 'vector.control' 2>/dev/null | grep -q 'vector.control'; then
    brew list --versions pgvector >/dev/null 2>&1 || brew install pgvector
  fi

  brew services start "${PG_FORMULA}" >/dev/null 2>&1 || true
  psql_bin="$(get_psql_bin)"
  createdb_bin="$(get_createdb_bin)"
  pg_prefix="$(get_pg_prefix)"

  if [[ -z "${psql_bin}" || -z "${createdb_bin}" ]]; then
    err "PostgreSQL CLI를 찾을 수 없습니다."
    return 1
  fi
  if [[ -d "${pg_prefix}/share/${PG_FORMULA}/extension" ]]; then
    ok "PostgreSQL formula 확인: ${pg_prefix}"
  fi
  if ! wait_for_postgres "${psql_bin}"; then
    err "PostgreSQL 기동 확인 실패"
    return 1
  fi
  ok "PostgreSQL 응답 확인"

  if ! "${psql_bin}" -h "${PG_HOST}" -p "${PG_PORT}" -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname='${PG_DB}'" | grep -q 1; then
    "${createdb_bin}" -h "${PG_HOST}" -p "${PG_PORT}" "${PG_DB}"
    ok "DB 생성: ${PG_DB}"
  else
    ok "DB 이미 존재: ${PG_DB}"
  fi
}

setup_python_env() {
  local python_bin venv_python
  info "memory-v3 Python 환경 준비"

  python_bin="${PYTHON_BIN_OVERRIDE:-$(command -v python3 || true)}"
  if [[ -z "${python_bin}" ]]; then
    err "python3를 찾을 수 없습니다."
    return 1
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ${python_bin} -m venv ${SERVICE_ROOT}/.venv"
    ok "[DRY] ${SERVICE_ROOT}/.venv/bin/pip install -r ${SERVICE_ROOT}/requirements.txt"
    return 0
  fi

  "${python_bin}" -m venv "${SERVICE_ROOT}/.venv"
  venv_python="${SERVICE_ROOT}/.venv/bin/python"
  "${venv_python}" -m pip install --upgrade pip
  "${venv_python}" -m pip install -r "${SERVICE_ROOT}/requirements.txt"
  ok "venv 준비 완료"
}

run_memory_migrations() {
  local psql_bin migration
  info "memory-v3 migration 실행"

  psql_bin="$(get_psql_bin)"
  if [[ -z "${psql_bin}" ]]; then
    err "psql을 찾을 수 없습니다."
    return 1
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ${psql_bin} -h ${PG_HOST} -p ${PG_PORT} -d ${PG_DB} -f ${SERVICE_ROOT}/001_base_schema.sql"
    for migration in 003_memories.sql 004_memory_v3_phase2.sql 005_bilingual_facts.sql 006_eviction.sql; do
      ok "[DRY] ${psql_bin} -h ${PG_HOST} -p ${PG_PORT} -d ${PG_DB} -f ${SERVICE_ROOT}/migrations/${migration}"
    done
    return 0
  fi

  "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DB}" -f "${SERVICE_ROOT}/001_base_schema.sql"
  for migration in 003_memories.sql 004_memory_v3_phase2.sql 005_bilingual_facts.sql 006_eviction.sql; do
    "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DB}" -f "${SERVICE_ROOT}/migrations/${migration}"
  done
  ok "migration 완료"
}

configure_memory_env() {
  local db_dsn python_bin
  info "memory-v3 .env 설정"

  db_dsn="host=${PG_HOST} port=${PG_PORT} dbname=${PG_DB} user=${PG_USER}"
  python_bin="${SERVICE_ROOT}/.venv/bin/python"

  replace_or_append_env "DATABASE_URL" "${db_dsn}"
  replace_or_append_env "OLLAMA_URL" "${OLLAMA_URL}"
  replace_or_append_env "MEMORY_HOST" "127.0.0.1"
  replace_or_append_env "MEMORY_PORT" "18790"
  replace_or_append_env "MEMORY_WORKSPACE_GLOBAL" "${WORKSPACE}"
  replace_or_append_env "MEMORY_SESSION_DIR_AGENT_NOVA" "${HOME}/.openclaw/agents/nova/sessions"
  replace_or_append_env "MEMORY_STATE_DIR" "${SERVICE_ROOT}/state"
  replace_or_append_env "MEMORY_SESSION_OFFSET_FILE" "${SERVICE_ROOT}/state/session-offsets.json"
  replace_or_append_env "OPENCLAW_CONFIG_PATH" "${CONFIG_FILE}"
  replace_or_append_env "PYTHON_BIN" "${python_bin}"

  if [[ "${DRY_RUN}" != "1" ]]; then
    chmod 600 "${SERVICE_ENV_FILE}"
  fi
}

bootstrap_workspace_memory() {
  info "workspace memory bootstrap"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] create ${WORKSPACE}/MEMORY.md and memory dirs"
    return 0
  fi

  mkdir -p "${WORKSPACE}/memory/logs" "${WORKSPACE}/memory/system"
  if [[ ! -f "${WORKSPACE}/MEMORY.md" ]]; then
    cat > "${WORKSPACE}/MEMORY.md" <<'EOF'
# MEMORY.md

이 파일은 사용자 선호, 장기 상태, 중요한 결정사항을 기록하는 메모리 루트입니다.
EOF
    ok "MEMORY.md 생성"
  else
    ok "MEMORY.md 이미 존재 — 보존"
  fi
}

patch_openclaw_plugin() {
  info "OpenClaw memory plugin 설정"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] patch ${CONFIG_FILE} plugins.memory-v3"
    return 0
  fi

  mkdir -p "${CONFIG_DIR}"
  [[ -f "${CONFIG_FILE}" ]] || printf '{}\n' > "${CONFIG_FILE}"

  OC_PATH="${CONFIG_FILE}" node - <<'EOF'
const fs = require("fs");
const path = process.env.OC_PATH;
const raw = fs.readFileSync(path, "utf8");
const c = raw.trim() ? JSON.parse(raw) : {};

c.plugins = c.plugins || {};
c.plugins.allow = Array.isArray(c.plugins.allow) ? c.plugins.allow : [];
for (const name of ["memory-v3"]) {
  if (!c.plugins.allow.includes(name)) c.plugins.allow.push(name);
}
c.plugins.slots = c.plugins.slots || {};
c.plugins.slots.memory = "memory-v3";
c.plugins.entries = c.plugins.entries || {};

const prev = c.plugins.entries["memory-v3"] || {};
const prevConfig = prev.config || {};
c.plugins.entries["memory-v3"] = {
  ...prev,
  enabled: true,
  config: {
    baseUrl: prevConfig.baseUrl || "http://127.0.0.1:18790",
    autoRecall: prevConfig.autoRecall ?? true,
    maxResults: prevConfig.maxResults ?? 8,
    minScore: prevConfig.minScore ?? 0.3,
    prefetchTimeoutMs: prevConfig.prefetchTimeoutMs ?? 1200,
    maxInflightPrefetch: prevConfig.maxInflightPrefetch ?? 1,
    smartEntityLimit: prevConfig.smartEntityLimit ?? 0,
    qualityFirstAgents: prevConfig.qualityFirstAgents ?? ["nova", "main"],
    qualityFirstPrefetchTimeoutMs: prevConfig.qualityFirstPrefetchTimeoutMs ?? 3000,
    qualityFirstMaxInflightPrefetch: prevConfig.qualityFirstMaxInflightPrefetch ?? 3,
    qualityFirstSmartEntityLimit: prevConfig.qualityFirstSmartEntityLimit ?? 1,
    prefetchFailureCooldownMs: prevConfig.prefetchFailureCooldownMs ?? 15000,
  },
};

fs.writeFileSync(path, JSON.stringify(c, null, 2));
EOF
  chmod 600 "${CONFIG_FILE}"
  ok "plugin patch 완료"
}

main() {
  if [[ ! -f "${CORE_SCRIPT}" ]]; then
    err "core script를 찾을 수 없습니다: ${CORE_SCRIPT}"
    exit 1
  fi
  if [[ ! -d "${PAYLOAD_TEMPLATE_DIR}" ]]; then
    err "payload template을 찾을 수 없습니다: ${PAYLOAD_TEMPLATE_DIR}"
    exit 1
  fi

  run_core_setup
  stage_memory_payload
  ensure_native_postgres
  setup_python_env
  run_memory_migrations
  configure_memory_env
  bootstrap_workspace_memory
  patch_openclaw_plugin

  warn "launchd 등록과 health check는 아직 남아 있습니다."
}

main "$@"
