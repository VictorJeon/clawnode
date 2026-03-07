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
#   6. launchd 등록 + health check
# ============================================================================

DRY_RUN="${DRY_RUN:-0}"
SKIP_CORE_SETUP="${SKIP_CORE_SETUP:-0}"
FORCE_CORE_SETUP="${FORCE_CORE_SETUP:-0}"
GIST_BASE_URL="${GIST_BASE_URL:-https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORE_SCRIPT_LOCAL="${SCRIPT_DIR}/openclaw-setup.sh"
PAYLOAD_TEMPLATE_LOCAL="${REPO_ROOT}/installer/templates/memory-v3/payload"
EXTENSION_TEMPLATE_LOCAL="${REPO_ROOT}/installer/templates/memory-v3/extension"
BASE_SCHEMA_LOCAL="${REPO_ROOT}/installer/templates/memory-v3/001_base_schema.sql"
CORE_SCRIPT="${CORE_SCRIPT_LOCAL}"
PAYLOAD_TEMPLATE_DIR="${PAYLOAD_TEMPLATE_LOCAL}"
EXTENSION_TEMPLATE_DIR="${EXTENSION_TEMPLATE_LOCAL}"
BASE_SCHEMA_TEMPLATE="${BASE_SCHEMA_LOCAL}"
ASSET_TMP=""

SERVICE_ROOT="${HOME}/.openclaw/services/memory-v2"
SERVICE_ENV_FILE="${SERVICE_ROOT}/.env"
CONFIG_DIR="${HOME}/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
EXTENSIONS_DIR="${CONFIG_DIR}/extensions"
PLUGIN_ROOT="${EXTENSIONS_DIR}/memory-v3"
WORKSPACE="${CONFIG_DIR}/workspace"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LOG_FILE="${CONFIG_DIR}/setup-v2-$(date +%Y%m%d-%H%M%S).log"

PG_FORMULA="${PG_FORMULA:-postgresql@17}"
PG_DB="${PG_DB:-memory_v2}"
PG_HOST="${PG_HOST:-127.0.0.1}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-$(whoami)}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
CORE_STEP_RESULT="pending"

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
  printf "  ${BOLD}OpenClaw V2 + Memory V3${NC}\n"
  echo "  local agent runtime + recall memory + hybrid search stack"
  echo "============================================================"
  echo ""
  printf "  ${CYAN}Components${NC}\n"
  echo "  - OpenClaw core runtime"
  echo "  - Memory V3 plugin"
  echo "  - Memory API + atomize worker"
  echo "  - PostgreSQL + pgvector"
  echo "  - Workspace memory protocol"
  echo ""
}

stage() {
  echo ""
  printf "${BOLD}[%s]${NC}\n" "$1"
}

write_log_header() {
  echo "# OpenClaw Setup V2 Log — $(date)"
  echo "# OS: $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"
  echo "# User: $(whoami)"
  echo "---"
}

core_step_label() {
  case "${CORE_STEP_RESULT}" in
    skipped-existing) printf '%s\n' "기존 OpenClaw 유지 + Memory V3 업그레이드" ;;
    skipped-env) printf '%s\n' "core 단계 생략 (SKIP_CORE_SETUP=1)" ;;
    ran) printf '%s\n' "OpenClaw core 신규/재실행 후 Memory V3 적용" ;;
    *) printf '%s\n' "Memory V3 적용" ;;
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
  local oc_ver sys_ip sys_host sys_os sys_user ts_ip memory_api plugin_state report_file report

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] final summary"
    return 0
  fi

  oc_ver="$(openclaw --version 2>/dev/null || echo "미설치")"
  sys_ip="$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "감지실패")"
  sys_host="$(hostname)"
  sys_os="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"
  sys_user="$(whoami)"
  ts_ip="$(tailscale_ip)"

  if curl -fsS "http://127.0.0.1:18790/health" >/dev/null 2>&1; then
    memory_api="online"
  else
    memory_api="offline"
  fi

  if [[ -f "${PLUGIN_ROOT}/openclaw.plugin.json" && -f "${PLUGIN_ROOT}/index.ts" ]]; then
    plugin_state="installed"
  else
    plugin_state="missing"
  fi

  report="OpenClaw V2 설치 결과
상태: ✅ 성공
설치 모드: $(core_step_label)
호스트: ${sys_host}
OS: ${sys_os}
OpenClaw: ${oc_ver}
공인IP: ${sys_ip}
유저: ${sys_user}
Memory API: ${memory_api}
Memory Plugin: ${plugin_state}
Memory DB: ${PG_FORMULA} / ${PG_DB}
Memory URL: http://127.0.0.1:18790
Workspace: ${WORKSPACE}
AGENTS.md: memory protocol applied
설치 로그: ${LOG_FILE}"

  if [[ -n "${ts_ip}" ]]; then
    report="${report}
Tailscale IP: ${ts_ip}"
  fi

  report_file="${CONFIG_DIR}/install-report-v2.txt"
  printf '%s\n' "${report}" > "${report_file}"

  echo ""
  echo "============================================================"
  printf "  ${GREEN}${BOLD}OpenClaw V2 Ready${NC}\n"
  echo "============================================================"
  echo ""
  printf "  ${CYAN}Installed Stack${NC}\n"
  echo "  - OpenClaw core"
  echo "  - Memory V3 plugin"
  echo "  - Memory API + atomize worker"
  echo "  - PostgreSQL pgvector backend"
  echo "  - Workspace memory protocol"
  echo ""
  printf "  ${CYAN}Report${NC}\n"
  printf '%s\n' "${report}"
  echo ""

  if printf '%s' "${report}" | pbcopy 2>/dev/null; then
    ok "클립보드 복사 완료"
  else
    info "수동 복사: ${report_file}"
  fi
}

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

core_install_present() {
  if ! command -v openclaw >/dev/null 2>&1; then
    return 1
  fi
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    return 1
  fi
  if ! node -e 'const fs=require("fs"); const p=process.argv[1]; const c=JSON.parse(fs.readFileSync(p,"utf8")); process.exit(c?.channels?.telegram ? 0 : 1);' "${CONFIG_FILE}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
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
  local url="$1"
  local path="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] curl -fsSL ${url} -o ${path}"
    return 0
  fi
  curl -fsSL "${url}" -o "${path}"
}

prepare_installer_assets() {
  if [[ -f "${CORE_SCRIPT_LOCAL}" && -d "${PAYLOAD_TEMPLATE_LOCAL}" && -d "${EXTENSION_TEMPLATE_LOCAL}" && -f "${BASE_SCHEMA_LOCAL}" ]]; then
    CORE_SCRIPT="${CORE_SCRIPT_LOCAL}"
    PAYLOAD_TEMPLATE_DIR="${PAYLOAD_TEMPLATE_LOCAL}"
    EXTENSION_TEMPLATE_DIR="${EXTENSION_TEMPLATE_LOCAL}"
    BASE_SCHEMA_TEMPLATE="${BASE_SCHEMA_LOCAL}"
    return 0
  fi

  info "local installer assets 없음 — gist payload bootstrap 사용"
  ASSET_TMP="$(mktemp -d)"
  CORE_SCRIPT="${ASSET_TMP}/openclaw-setup.sh"
  local payload_archive_b64="${ASSET_TMP}/openclaw-memory-v3-payload.tar.gz.b64"
  local payload_archive="${ASSET_TMP}/openclaw-memory-v3-payload.tar.gz"

  download_to_file "${GIST_BASE_URL}/openclaw-setup.sh" "${CORE_SCRIPT}"
  download_to_file "${GIST_BASE_URL}/openclaw-memory-v3-payload.tar.gz.b64" "${payload_archive_b64}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    mkdir -p "${ASSET_TMP}/payload" "${ASSET_TMP}/extension"
    : > "${CORE_SCRIPT}"
    : > "${ASSET_TMP}/001_base_schema.sql"
    PAYLOAD_TEMPLATE_DIR="${ASSET_TMP}/payload"
    EXTENSION_TEMPLATE_DIR="${ASSET_TMP}/extension"
    BASE_SCHEMA_TEMPLATE="${ASSET_TMP}/001_base_schema.sql"
    return 0
  fi

  openssl base64 -d -A -in "${payload_archive_b64}" -out "${payload_archive}"
  tar -xzf "${payload_archive}" -C "${ASSET_TMP}"
  PAYLOAD_TEMPLATE_DIR="${ASSET_TMP}/payload"
  EXTENSION_TEMPLATE_DIR="${ASSET_TMP}/extension"
  BASE_SCHEMA_TEMPLATE="${ASSET_TMP}/001_base_schema.sql"
}

run_core_setup() {
  if [[ "${SKIP_CORE_SETUP}" == "1" ]]; then
    warn "SKIP_CORE_SETUP=1 — 기존 core setup 단계는 건너뜁니다."
    CORE_STEP_RESULT="skipped-env"
    return 0
  fi

  if [[ "${FORCE_CORE_SETUP}" != "1" ]] && core_install_present; then
    warn "기존 OpenClaw core 설치 감지 — V2 memory 단계만 적용합니다."
    warn "core를 다시 설치하려면 FORCE_CORE_SETUP=1 로 실행하세요."
    CORE_STEP_RESULT="skipped-existing"
    return 0
  fi

  info "기존 core setup 실행"
  CORE_STEP_RESULT="ran"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] SUPPRESS_FINAL_REPORT=1 OPENCLAW_PARENT_LOG=1 bash ${CORE_SCRIPT}"
    return 0
  fi
  SUPPRESS_FINAL_REPORT=1 OPENCLAW_PARENT_LOG=1 OPENCLAW_LOG_FILE="${LOG_FILE}" bash "${CORE_SCRIPT}"
}

replace_or_append_env() {
  local key="$1"
  local value="$2"
  local tmp_file
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] env ${key}=${value}"
    return 0
  fi

  touch "${SERVICE_ENV_FILE}"
  chmod 600 "${SERVICE_ENV_FILE}"
  tmp_file="$(mktemp)"
  awk -v key="${key}" -v value="${value}" '
    BEGIN { replaced = 0 }
    index($0, key "=") == 1 {
      print key "=" value
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) print key "=" value
    }
  ' "${SERVICE_ENV_FILE}" > "${tmp_file}"
  mv "${tmp_file}" "${SERVICE_ENV_FILE}"
  chmod 600 "${SERVICE_ENV_FILE}"
}

stage_memory_extension() {
  info "memory-v3 plugin staging"

  if [[ ! -d "${EXTENSION_TEMPLATE_DIR}" ]]; then
    err "extension template을 찾을 수 없습니다: ${EXTENSION_TEMPLATE_DIR}"
    return 1
  fi

  dry mkdir -p "${PLUGIN_ROOT}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] rsync -a ${EXTENSION_TEMPLATE_DIR}/ ${PLUGIN_ROOT}/"
    return 0
  fi

  rsync -a --delete \
    --exclude='memory.db' \
    --exclude='*.log' \
    --exclude='__pycache__' \
    "${EXTENSION_TEMPLATE_DIR}/" "${PLUGIN_ROOT}/"
  ok "plugin 복사 완료: ${PLUGIN_ROOT}"
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

ensure_pgvector_extension_files() {
  local pg_prefix pg_major target_dir target_lib_dir source_control source_dir source_lib

  pg_prefix="$(get_pg_prefix 2>/dev/null || true)"
  if [[ -z "${pg_prefix}" ]]; then
    err "PostgreSQL prefix를 찾을 수 없습니다."
    return 1
  fi

  pg_major="${PG_FORMULA#postgresql@}"
  target_dir="${pg_prefix}/share/postgresql@${pg_major}/extension"
  target_lib_dir="$("${pg_prefix}/bin/pg_config" --pkglibdir)"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ensure pgvector files in ${target_dir} and ${target_lib_dir}"
    return 0
  fi

  mkdir -p "${target_dir}"
  mkdir -p "${target_lib_dir}"
  if [[ -f "${target_dir}/vector.control" && ( -f "${target_lib_dir}/vector.dylib" || -f "${target_lib_dir}/vector.so" ) ]]; then
    ok "pgvector extension 파일 확인: ${target_dir}"
    return 0
  fi

  source_control="$(find /opt/homebrew /usr/local -path "*/share/postgresql@${pg_major}/extension/vector.control" 2>/dev/null | head -n 1)"
  if [[ -z "${source_control}" ]]; then
    source_control="$(find /opt/homebrew /usr/local -name 'vector.control' 2>/dev/null | head -n 1)"
  fi
  if [[ -z "${source_control}" ]]; then
    err "vector.control 파일을 찾지 못했습니다. pgvector 설치 상태를 확인하세요."
    return 1
  fi

  source_dir="$(dirname "${source_control}")"
  if [[ "${source_dir}" != "${target_dir}" ]]; then
    cp -f "${source_dir}"/vector* "${target_dir}/"
  fi

  source_lib="$(find /opt/homebrew /usr/local \( -path "*/lib/postgresql@${pg_major}/vector.dylib" -o -path "*/lib/postgresql@${pg_major}/vector.so" -o -path "*/lib/postgresql/vector.dylib" -o -path "*/lib/postgresql/vector.so" \) 2>/dev/null | head -n 1)"
  if [[ -z "${source_lib}" ]]; then
    err "pgvector shared library를 찾지 못했습니다. ${PG_FORMULA} 조합이 현재 Homebrew bottle과 호환되는지 확인하세요."
    return 1
  fi
  if [[ "${source_lib}" != "${target_lib_dir}/$(basename "${source_lib}")" ]]; then
    cp -f "${source_lib}" "${target_lib_dir}/"
  fi

  if [[ ! -f "${target_dir}/vector.control" ]]; then
    err "pgvector extension 파일 복사 후에도 vector.control 이 없습니다."
    return 1
  fi
  if [[ ! -f "${target_lib_dir}/vector.dylib" && ! -f "${target_lib_dir}/vector.so" ]]; then
    err "pgvector shared library 복사 후에도 vector 라이브러리가 없습니다."
    return 1
  fi
  ok "pgvector extension 파일 보정 완료: ${target_dir}, ${target_lib_dir}"
}

is_supported_python() {
  local python_bin="$1"
  "${python_bin}" - <<'EOF' >/dev/null 2>&1
import sys
raise SystemExit(0 if (3, 11) <= sys.version_info[:2] <= (3, 13) else 1)
EOF
}

resolve_python_bin() {
  local candidate brew_python_prefix brew_python_bin

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

  for candidate in \
    /opt/homebrew/bin/python3.13 \
    /opt/homebrew/bin/python3.12 \
    /opt/homebrew/bin/python3.11 \
    python3.13 \
    python3.12 \
    python3.11 \
    python3
  do
    if [[ -x "${candidate}" ]] || command -v "${candidate}" >/dev/null 2>&1; then
      candidate="$(command -v "${candidate}" 2>/dev/null || printf '%s' "${candidate}")"
      if is_supported_python "${candidate}"; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    fi
  done

  if ! command -v brew >/dev/null 2>&1; then
    err "Python 3.11~3.13이 필요하지만 brew를 찾을 수 없습니다."
    return 1
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] brew install python@3.13"
    printf '%s\n' "/opt/homebrew/bin/python3.13"
    return 0
  fi

  brew list --versions python@3.13 >/dev/null 2>&1 || brew install python@3.13 >&2
  brew_python_prefix="$(brew --prefix python@3.13)"
  brew_python_bin="${brew_python_prefix}/bin/python3.13"
  if [[ ! -x "${brew_python_bin}" ]] || ! is_supported_python "${brew_python_bin}"; then
    err "brew로 설치한 python@3.13을 확인할 수 없습니다."
    return 1
  fi
  printf '%s\n' "${brew_python_bin}"
}

python_mm() {
  local python_bin="$1"
  "${python_bin}" - <<'EOF'
import sys
print(f"{sys.version_info[0]}.{sys.version_info[1]}")
EOF
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
  ensure_pgvector_extension_files

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
  local python_bin venv_python target_mm existing_mm
  info "memory-v3 Python 환경 준비"

  python_bin="$(resolve_python_bin)"
  if [[ -z "${python_bin}" ]]; then
    err "호환되는 Python 3.11~3.13을 찾을 수 없습니다."
    return 1
  fi
  ok "Python 런타임 선택: $(${python_bin} --version 2>&1)"

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

  venv_python="${SERVICE_ROOT}/.venv/bin/python"
  "${venv_python}" -m pip install --upgrade pip
  "${venv_python}" -m pip install -r "${SERVICE_ROOT}/requirements.txt"
  ok "venv 준비 완료"
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

ensure_migration_tracking() {
  local psql_bin="$1"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ensure installer_schema_migrations table"
    return 0
  fi

  "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DB}" -Atqc "
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

  "${psql_bin}" -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DB}" -Atqc \
    "SELECT 1 FROM installer_schema_migrations WHERE name = '${name}'" | grep -q '^1$'
}

mark_migration_recorded() {
  local psql_bin="$1"
  local name="$2"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] mark migration ${name}"
    return 0
  fi

  "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DB}" -Atqc \
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

  "${psql_bin}" -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DB}" -Atqc "${query}" | grep -q '^1$'
}

apply_tracked_migration() {
  local psql_bin="$1"
  local name="$2"
  local file="$3"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] ${psql_bin} -h ${PG_HOST} -p ${PG_PORT} -d ${PG_DB} -f ${file}"
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

  "${psql_bin}" -v ON_ERROR_STOP=1 -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DB}" -f "${file}"
  mark_migration_recorded "${psql_bin}" "${name}"
  ok "migration 적용: ${name}"
}

configure_memory_env() {
  local db_dsn python_bin
  info "memory-v3 .env 설정"

  db_dsn="postgresql://${PG_USER}@${PG_HOST}:${PG_PORT}/${PG_DB}"
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
    ok "[DRY] create ${WORKSPACE}/MEMORY.md, AGENTS.md and memory dirs"
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

  ensure_agents_memory_guidance
}

ensure_agents_memory_guidance() {
  local agents_file tmp_file out_file
  agents_file="${WORKSPACE}/AGENTS.md"
  tmp_file="$(mktemp)"
  out_file="$(mktemp)"

  cat > "${tmp_file}" <<'EOF'
<!-- OPENCLAW_MEMORY_V3_START -->
## Memory

### SESSION-STATE.md
5줄 이하. 현재 활성 작업 이름만 적는다. 상세는 Memory V3 검색으로 복구한다.

### MEMORY.md
장기 선호, 반복되는 요청, 중요한 결정사항을 기록한다.

### 일일 로그
`memory/YYYY-MM-DD.md` 에 당일 작업 흐름, 실패, 결정, 결과를 기록한다.
당일 작업이 있으면 반드시 갱신한다.

### Memory V3 검색 프로토콜
- 실행형 요청을 받으면 시작 전에 관련 기억을 먼저 검색한다.
- 프로젝트 루트에 `PROJECT-STATE.md`가 있으면 반드시 먼저 읽는다.
- 기본 엔드포인트: `http://127.0.0.1:18790/v1/memory/search`
- 최소 2회 검색:
  1. `<entity> 현재 상태`
  2. `<entity> 최근 변경`
- 둘 다 실패할 때만 "기억 없음"으로 간주한다.

### Memory V3 기록 프로토콜
- 장기적으로 재사용할 정보는 `MEMORY.md`
- 당일 작업 로그는 `memory/YYYY-MM-DD.md`
- 프로젝트 상태 요약은 `PROJECT-STATE.md`
- 메모리 인프라/장애/동기화 이슈는 `memory/infra.md`
<!-- OPENCLAW_MEMORY_V3_END -->
EOF

  if [[ ! -f "${agents_file}" ]]; then
    cat > "${agents_file}" <<'EOF'
# AGENTS.md

이 워크스페이스에서 일하는 에이전트 운영 규칙.

EOF
  fi

  if grep -q '<!-- OPENCLAW_MEMORY_V3_START -->' "${agents_file}" 2>/dev/null; then
    awk '
      BEGIN { skip = 0 }
      /<!-- OPENCLAW_MEMORY_V3_START -->/ {
        while ((getline line < blockfile) > 0) print line
        close(blockfile)
        skip = 1
        next
      }
      /<!-- OPENCLAW_MEMORY_V3_END -->/ {
        skip = 0
        next
      }
      skip == 0 { print }
    ' blockfile="${tmp_file}" "${agents_file}" > "${out_file}"
    mv "${out_file}" "${agents_file}"
  else
    printf '\n' >> "${agents_file}"
    cat "${tmp_file}" >> "${agents_file}"
  fi

  rm -f "${tmp_file}" "${out_file}"
  ok "AGENTS.md memory 규칙 반영"
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
  local server_wrapper atomize_wrapper llm_wrapper
  server_wrapper="${SERVICE_ROOT}/run-server.sh"
  atomize_wrapper="${SERVICE_ROOT}/run-atomize.sh"
  llm_wrapper="${SERVICE_ROOT}/run-llm-atomize.sh"

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

  if [[ "${DRY_RUN}" != "1" ]]; then
    chmod 755 "${server_wrapper}" "${atomize_wrapper}" "${llm_wrapper}"
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

write_launchd_plists() {
  info "memory-v3 launchd plist 생성"
  local path_env api_plist atomize_plist flush_plist llm_plist
  path_env="$(get_pg_prefix 2>/dev/null || true)/bin:/opt/homebrew/bin:/usr/bin:/bin"
  api_plist="${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-api.plist"
  atomize_plist="${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-atomize.plist"
  flush_plist="${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-flush.plist"
  llm_plist="${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-llm-atomize.plist"

  write_file_if_changed "${api_plist}" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
  <key>Label</key>
  <string>ai.openclaw.memory-v3-api</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SERVICE_ROOT}/run-server.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${SERVICE_ROOT}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${path_env}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/openclaw-memory-v3-api.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/openclaw-memory-v3-api.log</string>
</dict>
</plist>
"

  write_file_if_changed "${atomize_plist}" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
  <key>Label</key>
  <string>ai.openclaw.memory-v3-atomize</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SERVICE_ROOT}/run-atomize.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${SERVICE_ROOT}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${path_env}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/openclaw-memory-v3-atomize.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/openclaw-memory-v3-atomize.log</string>
</dict>
</plist>
"

  write_file_if_changed "${flush_plist}" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
  <key>Label</key>
  <string>ai.openclaw.memory-v3-flush</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SERVICE_ROOT}/flush-cron.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${SERVICE_ROOT}</string>
  <key>StartInterval</key>
  <integer>300</integer>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>/tmp/openclaw-memory-v3-flush.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/openclaw-memory-v3-flush.log</string>
</dict>
</plist>
"

  if has_google_api_key; then
    write_file_if_changed "${llm_plist}" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
  <key>Label</key>
  <string>ai.openclaw.memory-v3-llm-atomize</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SERVICE_ROOT}/run-llm-atomize.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${SERVICE_ROOT}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${path_env}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/openclaw-memory-v3-llm-atomize.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/openclaw-memory-v3-llm-atomize.log</string>
</dict>
</plist>
"
  elif [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] skip llm worker plist (no GOOGLE_API_KEY)"
  else
    rm -f "${llm_plist}"
    ok "llm worker plist 생략"
  fi
}

bootstrap_launchd_service() {
  local plist="$1"
  local label="$2"
  local gui_target
  gui_target="gui/$(id -u)"

  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] launchctl bootout ${gui_target} ${plist}"
    ok "[DRY] launchctl bootstrap ${gui_target} ${plist}"
    return 0
  fi

  launchctl bootout "${gui_target}" "${plist}" >/dev/null 2>&1 || true
  launchctl bootstrap "${gui_target}" "${plist}"
  launchctl kickstart -k "${gui_target}/${label}" >/dev/null 2>&1 || true
}

install_launchd_services() {
  info "memory-v3 launchd 등록"
  write_wrapper_scripts
  write_launchd_plists

  bootstrap_launchd_service "${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-api.plist" "ai.openclaw.memory-v3-api"
  bootstrap_launchd_service "${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-atomize.plist" "ai.openclaw.memory-v3-atomize"
  bootstrap_launchd_service "${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-flush.plist" "ai.openclaw.memory-v3-flush"
  if [[ -f "${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-llm-atomize.plist" || "${DRY_RUN}" == "1" ]]; then
    bootstrap_launchd_service "${LAUNCH_AGENTS_DIR}/ai.openclaw.memory-v3-llm-atomize.plist" "ai.openclaw.memory-v3-llm-atomize"
  fi
}

restart_openclaw_gateway() {
  info "OpenClaw gateway 재시작"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ok "[DRY] openclaw gateway restart"
    return 0
  fi

  if openclaw gateway status 2>/dev/null | grep -q "running"; then
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

  for i in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:18790/health" >/dev/null 2>&1; then
      ok "memory API health 확인"
      curl -fsS "http://127.0.0.1:18790/v1/memory/stats" >/dev/null 2>&1 && ok "memory stats 확인"
      return 0
    fi
    sleep 1
  done
  err "memory API health check 실패"
  return 1
}

main() {
  ensure_homebrew_on_path || true
  prepare_installer_assets

  if [[ ! -f "${CORE_SCRIPT}" ]]; then
    err "core script를 찾을 수 없습니다: ${CORE_SCRIPT}"
    exit 1
  fi
  if [[ ! -d "${PAYLOAD_TEMPLATE_DIR}" ]]; then
    err "payload template을 찾을 수 없습니다: ${PAYLOAD_TEMPLATE_DIR}"
    exit 1
  fi
  if [[ ! -d "${EXTENSION_TEMPLATE_DIR}" ]]; then
    err "extension template을 찾을 수 없습니다: ${EXTENSION_TEMPLATE_DIR}"
    exit 1
  fi

  stage "Core"
  run_core_setup
  stage "Memory Payload"
  stage_memory_payload
  stage_memory_extension
  stage "Database"
  ensure_native_postgres
  stage "Runtime"
  setup_python_env
  run_memory_migrations
  configure_memory_env
  bootstrap_workspace_memory
  patch_openclaw_plugin
  stage "Bring-up"
  install_launchd_services
  restart_openclaw_gateway
  health_check_memory
  render_final_summary

  ok "setup v2 memory bring-up 완료"
}

main "$@"
