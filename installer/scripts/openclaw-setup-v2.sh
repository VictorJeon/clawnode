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
#   3. .env 초안 생성
#
# 아직 미구현:
#   - Native PostgreSQL bring-up
#   - migration 실행
#   - launchd 등록
#   - plugin patch / health check
# ============================================================================

DRY_RUN="${DRY_RUN:-0}"
SKIP_CORE_SETUP="${SKIP_CORE_SETUP:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/openclaw-setup.sh"
PAYLOAD_TEMPLATE_DIR="${REPO_ROOT}/installer/templates/memory-v3/payload"

SERVICE_ROOT="${HOME}/.openclaw/services/memory-v2"
SERVICE_ENV_FILE="${SERVICE_ROOT}/.env"

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

  warn "이 스크립트는 아직 개발 중입니다."
  warn "DB/migration/launchd/plugin patch 단계는 다음 배치에서 추가됩니다."
}

main "$@"
