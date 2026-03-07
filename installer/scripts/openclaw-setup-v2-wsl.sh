#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw Quick Setup v2-memory (Linux/WSL)
#
# 목적:
#   기존 openclaw-setup-wsl.sh는 그대로 두고,
#   V2에서는 core 설치 후 Memory V3 payload를 별도 단계로 붙인다.
#
# 범위:
#   1. 기존 Linux/WSL core setup 실행
#   2. memory payload staging
#   3. Native PostgreSQL + migration
#   4. Python venv + requirements
#   5. workspace bootstrap + plugin patch
#   6. systemd user service 또는 nohup bring-up + health check
# ============================================================================

DRY_RUN="${DRY_RUN:-0}"
SKIP_CORE_SETUP="${SKIP_CORE_SETUP:-0}"
GIST_BASE_URL="${GIST_BASE_URL:-https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORE_SCRIPT_LOCAL="${SCRIPT_DIR}/openclaw-setup-wsl.sh"
PAYLOAD_TEMPLATE_LOCAL="${REPO_ROOT}/installer/templates/memory-v3/payload"
BASE_SCHEMA_LOCAL="${REPO_ROOT}/installer/templates/memory-v3/001_base_schema.sql"
CORE_SCRIPT="${CORE_SCRIPT_LOCAL}"
PAYLOAD_TEMPLATE_DIR="${PAYLOAD_TEMPLATE_LOCAL}"
BASE_SCHEMA_TEMPLATE="${BASE_SCHEMA_LOCAL}"
ASSET_TMP=""

SERVICE_ROOT="${HOME}/.openclaw/services/memory-v2"
SERVICE_ENV_FILE="${SERVICE_ROOT}/.env"
CONFIG_DIR="${HOME}/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
WORKSPACE="${CONFIG_DIR}/workspace"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

PG_DB="${PG_DB:-memory_v2}"
PG_HOST="${PG_HOST:-/var/run/postgresql}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-$(whoami)}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"

SYSTEMD_USER_AVAILABLE=0
if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]] && systemctl --user show-environment >/dev/null 2>&1; then
  SYSTEMD_USER_AVAILABLE=1
fi

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

cleanup_assets() {
  if [[ -n "${ASSET_TMP}" && -d "${ASSET_TMP}" ]]; then
    rm -rf "${ASSET_TMP}"
  fi
}
trap cleanup_assets EXIT

download_to_file() {
  local url="$1"
  local path="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] curl -fsSL ${url} -o ${path}"
    return 0
  fi
  curl -fsSL "${url}" -o "${path}"
}

prepare_installer_assets() {
  if [[ -f "${CORE_SCRIPT_LOCAL}" && -d "${PAYLOAD_TEMPLATE_LOCAL}" && -f "${BASE_SCHEMA_LOCAL}" ]]; then
    CORE_SCRIPT="${CORE_SCRIPT_LOCAL}"
    PAYLOAD_TEMPLATE_DIR="${PAYLOAD_TEMPLATE_LOCAL}"
    BASE_SCHEMA_TEMPLATE="${BASE_SCHEMA_LOCAL}"
    return 0
  fi

  info "local installer assets 없음 — gist payload bootstrap 사용"
  ASSET_TMP="$(mktemp -d)"
  CORE_SCRIPT="${ASSET_TMP}/openclaw-setup-wsl.sh"
  local payload_archive_b64="${ASSET_TMP}/openclaw-memory-v3-payload.tar.gz.b64"
  local payload_archive="${ASSET_TMP}/openclaw-memory-v3-payload.tar.gz"

  download_to_file "${GIST_BASE_URL}/openclaw-setup-wsl.sh" "${CORE_SCRIPT}"
  download_to_file "${GIST_BASE_URL}/openclaw-memory-v3-payload.tar.gz.b64" "${payload_archive_b64}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    mkdir -p "${ASSET_TMP}/payload"
    : > "${CORE_SCRIPT}"
    : > "${ASSET_TMP}/001_base_schema.sql"
    PAYLOAD_TEMPLATE_DIR="${ASSET_TMP}/payload"
    BASE_SCHEMA_TEMPLATE="${ASSET_TMP}/001_base_schema.sql"
    return 0
  fi

  openssl base64 -d -A -in "${payload_archive_b64}" -out "${payload_archive}"
  tar -xzf "${payload_archive}" -C "${ASSET_TMP}"
  PAYLOAD_TEMPLATE_DIR="${ASSET_TMP}/payload"
  BASE_SCHEMA_TEMPLATE="${ASSET_TMP}/001_base_schema.sql"
}

run_core_setup() {
  if [[ "${SKIP_CORE_SETUP}" == "1" ]]; then
    warn "SKIP_CORE_SETUP=1 — 기존 core setup 단계는 건너뜁니다."
    return 0
  fi

  info "기존 Linux/WSL core setup 실행"
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

ensure_apt_updated() {
  if [[ -f /tmp/.openclaw-v2-apt-updated ]]; then
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] sudo apt-get update -qq"
    return 0
  fi
  sudo apt-get update -qq
  touch /tmp/.openclaw-v2-apt-updated
}

apt_install() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] sudo apt-get install -y -qq $*"
    return 0
  fi
  sudo apt-get install -y -qq "$@"
}

get_psql_bin() {
  if command -v psql >/dev/null 2>&1; then
    command -v psql
    return 0
  fi
  return 1
}

get_createdb_bin() {
  if command -v createdb >/dev/null 2>&1; then
    command -v createdb
    return 0
  fi
  return 1
}

is_supported_python() {
  local python_bin="$1"
  "${python_bin}" - <<'PYEOF' >/dev/null 2>&1
import sys
raise SystemExit(0 if (3, 11) <= sys.version_info[:2] <= (3, 13) else 1)
PYEOF
}

resolve_python_bin() {
  local candidate

  if [[ -n "${PYTHON_BIN_OVERRIDE:-}" ]]; then
    if [[ ! -x "${PYTHON_BIN_OVERRIDE}" ]]; then
      err "PYTHON_BIN_OVERRIDE 경로가 실행 가능하지 않습니다: ${PYTHON_BIN_OVERRIDE}"
      return 1
    fi
    if ! is_supported_python "${PYTHON_BIN_OVERRIDE}"; then
      err "PYTHON_BIN_OVERRIDE는 Python 3.11~3.13 이어야 합니다: ${PYTHON_BIN_OVERRIDE}"
      return 1
    fi
    printf '%s\n' "${PYTHON_BIN_OVERRIDE}"
    return 0
  fi

  for candidate in python3.13 python3.12 python3.11 python3; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      candidate="$(command -v "${candidate}")"
      if is_supported_python "${candidate}"; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    fi
  done

  ensure_apt_updated
  apt_install python3 python3-venv

  for candidate in python3.13 python3.12 python3.11 python3; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      candidate="$(command -v "${candidate}")"
      if is_supported_python "${candidate}"; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    fi
  done

  err "호환되는 Python 3.11~3.13을 찾을 수 없습니다."
  return 1
}

python_mm() {
  local python_bin="$1"
  "${python_bin}" - <<'PYEOF'
import sys
print(f"{sys.version_info[0]}.{sys.version_info[1]}")
PYEOF
}

wait_for_postgres() {
  local user="$1"
  local i
  for i in $(seq 1 20); do
    if psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${user}" -d postgres -Atqc 'SELECT 1' >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

find_vector_control() {
  find /usr/share /usr/lib -path '*extension/vector.control' 2>/dev/null | head -n 1
}

ensure_pgvector_package() {
  local pkg
  pkg="$(apt-cache search '^postgresql-[0-9]+-pgvector$' 2>/dev/null | awk '{print $1}' | sort -V | tail -1)"
  if [[ -z "${pkg}" ]]; then
    pkg="$(apt-cache search 'pgvector' 2>/dev/null | awk '/postgresql/ {print $1; exit}')"
  fi
  if [[ -z "${pkg}" ]]; then
    return 1
  fi
  apt_install "${pkg}"
}

stage_memory_payload() {
  info "memory-v3 payload staging"
  dry mkdir -p "${SERVICE_ROOT}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] rsync -a ${PAYLOAD_TEMPLATE_DIR}/ ${SERVICE_ROOT}/"
  else
    rsync -a --delete \
      --exclude='.env' \
      --exclude='.venv/' \
      --exclude='state/' \
      --exclude='logs/' \
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
  local psql_bin createdb_bin

  info "native PostgreSQL 준비"
  ensure_apt_updated
  apt_install postgresql postgresql-contrib

  if [[ -z "$(find_vector_control || true)" ]]; then
    if ! ensure_pgvector_package; then
      err "pgvector 패키지를 찾지 못했습니다. apt source에서 pgvector 제공이 필요합니다."
      return 1
    fi
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] sudo systemctl start postgresql || sudo service postgresql start"
    ok "[DRY] ensure postgres role ${PG_USER}"
    ok "[DRY] ensure database ${PG_DB}"
    return 0
  fi

  sudo systemctl start postgresql >/dev/null 2>&1 || sudo service postgresql start >/dev/null 2>&1 || true

  if ! wait_for_postgres postgres; then
    err "PostgreSQL 기동 확인 실패"
    return 1
  fi
  ok "PostgreSQL 응답 확인"

  if ! sudo -u postgres psql -Atqc "SELECT 1 FROM pg_roles WHERE rolname='${PG_USER}'" | grep -q '^1$'; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "CREATE ROLE \"${PG_USER}\" LOGIN CREATEDB;" >/dev/null
    ok "DB role 생성: ${PG_USER}"
  else
    ok "DB role 이미 존재: ${PG_USER}"
  fi

  psql_bin="$(get_psql_bin)"
  createdb_bin="$(get_createdb_bin)"
  if [[ -z "${psql_bin}" || -z "${createdb_bin}" ]]; then
    err "PostgreSQL CLI를 찾을 수 없습니다."
    return 1
  fi

  if ! wait_for_postgres "${PG_USER}"; then
    err "현재 사용자 role로 PostgreSQL 접속 확인 실패"
    return 1
  fi

  if ! psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname='${PG_DB}'" | grep -q '^1$'; then
    "${createdb_bin}" -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" "${PG_DB}"
    ok "DB 생성: ${PG_DB}"
  else
    ok "DB 이미 존재: ${PG_DB}"
  fi
}

setup_python_env() {
  local python_bin venv_python target_mm existing_mm
  info "memory-v3 Python 환경 준비"

  python_bin="$(resolve_python_bin)"
  ok "Python 런타임 선택: $("${python_bin}" --version 2>&1)"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ${python_bin} -m venv ${SERVICE_ROOT}/.venv"
    ok "[DRY] ${SERVICE_ROOT}/.venv/bin/pip install -r ${SERVICE_ROOT}/requirements.txt"
    return 0
  fi

  target_mm="$(python_mm "${python_bin}")"
  venv_python="${SERVICE_ROOT}/.venv/bin/python"
  if [[ -x "${venv_python}" ]]; then
    existing_mm="$(python_mm "${venv_python}" 2>/dev/null || true)"
  else
    existing_mm=""
  fi

  if [[ ! -x "${venv_python}" || "${existing_mm}" != "${target_mm}" ]]; then
    "${python_bin}" -m venv --clear "${SERVICE_ROOT}/.venv"
    venv_python="${SERVICE_ROOT}/.venv/bin/python"
  else
    ok "기존 venv 재사용: Python ${existing_mm}"
  fi

  "${venv_python}" -m pip install --upgrade pip
  "${venv_python}" -m pip install -r "${SERVICE_ROOT}/requirements.txt"
  ok "venv 준비 완료"
}

ensure_migration_tracking() {
  local psql_bin="$1"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ensure installer_schema_migrations table"
    return 0
  fi
  "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -Atqc "
    CREATE TABLE IF NOT EXISTS installer_schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  " >/dev/null
}

migration_recorded() {
  local psql_bin="$1"
  local name="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 1
  fi
  "${psql_bin}" -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -Atqc \
    "SELECT 1 FROM installer_schema_migrations WHERE name = '${name}'" | grep -q '^1$'
}

mark_migration_recorded() {
  local psql_bin="$1"
  local name="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] mark migration ${name}"
    return 0
  fi
  "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -Atqc \
    "INSERT INTO installer_schema_migrations (name) VALUES ('${name}') ON CONFLICT (name) DO NOTHING;" >/dev/null
}

migration_signature_present() {
  local psql_bin="$1"
  local name="$2"
  local query

  case "${name}" in
    001_base_schema.sql)
      query="SELECT CASE WHEN to_regclass('public.memory_documents') IS NOT NULL AND to_regclass('public.memory_chunks') IS NOT NULL THEN 1 ELSE 0 END"
      ;;
    003_memories.sql)
      query="SELECT CASE WHEN to_regclass('public.memories') IS NOT NULL AND to_regclass('public.pending_atomize') IS NOT NULL AND to_regclass('public.project_snapshots') IS NOT NULL THEN 1 ELSE 0 END"
      ;;
    004_memory_v3_phase2.sql)
      query="SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'hit_count') THEN 1 ELSE 0 END"
      ;;
    005_bilingual_facts.sql)
      query="SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'fact_ko') THEN 1 ELSE 0 END"
      ;;
    006_eviction.sql)
      query="SELECT CASE
        WHEN to_regclass('public.memories') IS NULL THEN 0
        WHEN EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conrelid = 'public.memories'::regclass
            AND conname = 'memories_status_check'
            AND pg_get_constraintdef(oid) LIKE '%archived%'
        ) AND EXISTS (
          SELECT 1
          FROM pg_indexes
          WHERE schemaname = 'public'
            AND tablename = 'memories'
            AND indexname = 'idx_memories_eviction'
        ) THEN 1
        ELSE 0
      END"
      ;;
    *)
      return 1
      ;;
  esac

  if [[ "${DRY_RUN}" == "1" ]]; then
    return 1
  fi

  "${psql_bin}" -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -Atqc "${query}" | grep -q '^1$'
}

apply_tracked_migration() {
  local psql_bin="$1"
  local name="$2"
  local file="$3"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ${psql_bin} -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DB} -f ${file}"
    ok "[DRY] record migration ${name}"
    return 0
  fi

  if migration_recorded "${psql_bin}" "${name}"; then
    ok "migration already recorded: ${name}"
    return 0
  fi

  if migration_signature_present "${psql_bin}" "${name}"; then
    mark_migration_recorded "${psql_bin}" "${name}"
    ok "기존 스키마 감지 — migration 기록만 추가: ${name}"
    return 0
  fi

  "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" -f "${file}"
  mark_migration_recorded "${psql_bin}" "${name}"
  ok "migration 적용: ${name}"
}

run_memory_migrations() {
  local psql_bin
  info "memory-v3 migration 실행"

  psql_bin="$(get_psql_bin)"
  if [[ -z "${psql_bin}" ]]; then
    err "psql을 찾을 수 없습니다."
    return 1
  fi

  ensure_migration_tracking "${psql_bin}"
  apply_tracked_migration "${psql_bin}" "001_base_schema.sql" "${SERVICE_ROOT}/001_base_schema.sql"
  apply_tracked_migration "${psql_bin}" "003_memories.sql" "${SERVICE_ROOT}/migrations/003_memories.sql"
  apply_tracked_migration "${psql_bin}" "004_memory_v3_phase2.sql" "${SERVICE_ROOT}/migrations/004_memory_v3_phase2.sql"
  apply_tracked_migration "${psql_bin}" "005_bilingual_facts.sql" "${SERVICE_ROOT}/migrations/005_bilingual_facts.sql"
  apply_tracked_migration "${psql_bin}" "006_eviction.sql" "${SERVICE_ROOT}/migrations/006_eviction.sql"
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
    cat > "${WORKSPACE}/MEMORY.md" <<'MD'
# MEMORY.md

이 파일은 사용자 선호, 장기 상태, 중요한 결정사항을 기록하는 메모리 루트입니다.
MD
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

  OC_PATH="${CONFIG_FILE}" node - <<'NODEEOF'
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
NODEEOF
  chmod 600 "${CONFIG_FILE}"
  ok "plugin patch 완료"
}

write_file_if_changed() {
  local path="$1"
  local content="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] write ${path}"
    return 0
  fi
  mkdir -p "$(dirname "${path}")"
  printf '%s' "${content}" > "${path}"
}

write_wrapper_scripts() {
  info "memory-v3 wrapper 스크립트 생성"
  local server_wrapper atomize_wrapper llm_wrapper flush_wrapper
  server_wrapper="${SERVICE_ROOT}/run-server.sh"
  atomize_wrapper="${SERVICE_ROOT}/run-atomize.sh"
  llm_wrapper="${SERVICE_ROOT}/run-llm-atomize.sh"
  flush_wrapper="${SERVICE_ROOT}/run-flush.sh"

  write_file_if_changed "${server_wrapper}" '#!/bin/bash
set -euo pipefail
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${WORKDIR}/.env" ]; then
  set -a
  . "${WORKDIR}/.env"
  set +a
fi
PYTHON_BIN="${PYTHON_BIN:-${WORKDIR}/.venv/bin/python}"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi
cd "${WORKDIR}"
exec "${PYTHON_BIN}" server.py
'

  write_file_if_changed "${atomize_wrapper}" '#!/bin/bash
set -euo pipefail
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${WORKDIR}/.env" ]; then
  set -a
  . "${WORKDIR}/.env"
  set +a
fi
PYTHON_BIN="${PYTHON_BIN:-${WORKDIR}/.venv/bin/python}"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi
cd "${WORKDIR}"
exec "${PYTHON_BIN}" atomize_worker.py --interval 60
'

  write_file_if_changed "${llm_wrapper}" '#!/bin/bash
set -euo pipefail
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${WORKDIR}/.env" ]; then
  set -a
  . "${WORKDIR}/.env"
  set +a
fi
PYTHON_BIN="${PYTHON_BIN:-${WORKDIR}/.venv/bin/python}"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi
cd "${WORKDIR}"
exec "${PYTHON_BIN}" llm_atomize_worker.py
'

  write_file_if_changed "${flush_wrapper}" '#!/bin/bash
set -euo pipefail
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
cd "${WORKDIR}"
exec /bin/bash "${WORKDIR}/flush-cron.sh"
'

  if [[ "${DRY_RUN}" != "1" ]]; then
    chmod 755 "${server_wrapper}" "${atomize_wrapper}" "${llm_wrapper}" "${flush_wrapper}"
  fi
}

has_google_api_key() {
  if [[ -f "${SERVICE_ENV_FILE}" ]] && grep -q '^GOOGLE_API_KEY=' "${SERVICE_ENV_FILE}" 2>/dev/null; then
    return 0
  fi
  if [[ -f "${CONFIG_FILE}" ]] && command -v jq >/dev/null 2>&1; then
    jq -e '.env.vars.GOOGLE_API_KEY? // empty' "${CONFIG_FILE}" >/dev/null 2>&1
    return $?
  fi
  return 1
}

write_systemd_units() {
  local api_service atomize_service llm_service flush_service flush_timer
  api_service="${SYSTEMD_USER_DIR}/ai.openclaw.memory-v3-api.service"
  atomize_service="${SYSTEMD_USER_DIR}/ai.openclaw.memory-v3-atomize.service"
  llm_service="${SYSTEMD_USER_DIR}/ai.openclaw.memory-v3-llm-atomize.service"
  flush_service="${SYSTEMD_USER_DIR}/ai.openclaw.memory-v3-flush.service"
  flush_timer="${SYSTEMD_USER_DIR}/ai.openclaw.memory-v3-flush.timer"

  write_file_if_changed "${api_service}" "[Unit]
Description=OpenClaw Memory V3 API
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${SERVICE_ROOT}
ExecStart=/bin/bash ${SERVICE_ROOT}/run-server.sh
Restart=always
RestartSec=3
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
"

  write_file_if_changed "${atomize_service}" "[Unit]
Description=OpenClaw Memory V3 Atomize Worker
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${SERVICE_ROOT}
ExecStart=/bin/bash ${SERVICE_ROOT}/run-atomize.sh
Restart=always
RestartSec=3
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
"

  write_file_if_changed "${flush_service}" "[Unit]
Description=OpenClaw Memory V3 Flush

[Service]
Type=oneshot
WorkingDirectory=${SERVICE_ROOT}
ExecStart=/bin/bash ${SERVICE_ROOT}/run-flush.sh
Environment=PATH=/usr/local/bin:/usr/bin:/bin
"

  write_file_if_changed "${flush_timer}" "[Unit]
Description=Run OpenClaw Memory V3 Flush every 5 minutes

[Timer]
OnBootSec=3min
OnUnitActiveSec=5min
Unit=ai.openclaw.memory-v3-flush.service

[Install]
WantedBy=timers.target
"

  if has_google_api_key; then
    write_file_if_changed "${llm_service}" "[Unit]
Description=OpenClaw Memory V3 LLM Atomize Worker
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${SERVICE_ROOT}
ExecStart=/bin/bash ${SERVICE_ROOT}/run-llm-atomize.sh
Restart=always
RestartSec=3
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
"
  elif [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] skip llm systemd unit (no GOOGLE_API_KEY)"
  else
    rm -f "${llm_service}"
    ok "llm worker unit 생략"
  fi
}

systemd_enable_user_unit() {
  local unit="$1"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] systemctl --user enable --now ${unit}"
    return 0
  fi
  systemctl --user enable --now "${unit}" >/dev/null
}

start_manual_service() {
  local name="$1"
  local cmd="$2"
  local log_file="/tmp/${name}.log"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] nohup ${cmd} > ${log_file} 2>&1 &"
    return 0
  fi
  if pgrep -f "${cmd}" >/dev/null 2>&1; then
    ok "manual service already running: ${name}"
    return 0
  fi
  nohup /bin/bash -lc "${cmd}" > "${log_file}" 2>&1 &
  ok "manual service 시작: ${name}"
}

install_linux_services() {
  info "memory-v3 Linux 서비스 등록"
  write_wrapper_scripts

  if [[ "${SYSTEMD_USER_AVAILABLE}" == "1" ]]; then
    write_systemd_units
    if [[ "${DRY_RUN}" == "1" ]]; then
      ok "[DRY] systemctl --user daemon-reload"
    else
      systemctl --user daemon-reload
    fi
    systemd_enable_user_unit "ai.openclaw.memory-v3-api.service"
    systemd_enable_user_unit "ai.openclaw.memory-v3-atomize.service"
    systemd_enable_user_unit "ai.openclaw.memory-v3-flush.timer"
    if [[ -f "${SYSTEMD_USER_DIR}/ai.openclaw.memory-v3-llm-atomize.service" || "${DRY_RUN}" == "1" ]]; then
      systemd_enable_user_unit "ai.openclaw.memory-v3-llm-atomize.service"
    fi
  else
    warn "systemd user session이 없어 nohup 방식으로 memory 서비스를 시작합니다."
    start_manual_service "openclaw-memory-v3-api" "cd '${SERVICE_ROOT}' && exec /bin/bash '${SERVICE_ROOT}/run-server.sh'"
    start_manual_service "openclaw-memory-v3-atomize" "cd '${SERVICE_ROOT}' && exec /bin/bash '${SERVICE_ROOT}/run-atomize.sh'"
    if has_google_api_key; then
      start_manual_service "openclaw-memory-v3-llm-atomize" "cd '${SERVICE_ROOT}' && exec /bin/bash '${SERVICE_ROOT}/run-llm-atomize.sh'"
    fi
    if [[ "${DRY_RUN}" == "1" ]]; then
      ok "[DRY] /bin/bash ${SERVICE_ROOT}/flush-cron.sh"
    else
      /bin/bash "${SERVICE_ROOT}/flush-cron.sh" >/tmp/openclaw-memory-v3-flush.log 2>&1 || true
    fi
  fi
}

restart_openclaw_gateway() {
  info "OpenClaw gateway 재시작"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] openclaw gateway restart"
    return 0
  fi

  if openclaw gateway status 2>/dev/null | grep -q 'running'; then
    openclaw gateway restart >/dev/null 2>&1 || openclaw gateway start >/dev/null 2>&1 || true
  else
    openclaw gateway start >/dev/null 2>&1 || true
  fi
}

health_check_memory() {
  local i
  info "memory-v3 health check"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] curl http://127.0.0.1:18790/health"
    ok "[DRY] curl http://127.0.0.1:18790/v1/memory/stats"
    return 0
  fi

  for i in $(seq 1 30); do
    if curl -fsS 'http://127.0.0.1:18790/health' >/dev/null 2>&1; then
      ok "memory API health 확인"
      curl -fsS 'http://127.0.0.1:18790/v1/memory/stats' >/dev/null 2>&1 && ok "memory stats 확인"
      return 0
    fi
    sleep 1
  done
  err "memory API health check 실패"
  return 1
}

main() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    err "이 스크립트는 Linux/WSL 전용입니다. macOS에서는 openclaw-setup-v2.sh를 사용하세요."
    exit 1
  fi

  prepare_installer_assets
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
  install_linux_services
  restart_openclaw_gateway
  health_check_memory

  ok "setup v2 memory bring-up 완료"
}

main "$@"
