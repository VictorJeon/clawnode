#!/bin/bash
# Memory V2 flush trigger (incremental).
# LaunchAgent may run frequently; enforce minimum interval + non-overlap here.

set -u
set -o pipefail

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${WORKDIR}/.env" ]; then
  set -a
  . "${WORKDIR}/.env"
  set +a
fi

LOG_FILE="/tmp/memory-v2-flush.log"
LOG_MAX_BYTES="${FLUSH_LOG_MAX_BYTES:-5242880}"
STATE_DIR="/tmp/memory-v2-flush"
LOCK_DIR="${STATE_DIR}/lock"
STAMP_FILE="${STATE_DIR}/last_run_epoch"
MIN_INTERVAL_SEC="${FLUSH_MIN_INTERVAL_SEC:-300}"
CURL_MAX_TIME_SEC="${FLUSH_CURL_MAX_TIME_SEC:-45}"
OLLAMA_BASE_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
OLLAMA_HEALTH_URL="${OLLAMA_HEALTH_URL:-${OLLAMA_BASE_URL}/api/tags}"
OLLAMA_HEALTH_TIMEOUT_SEC="${OLLAMA_HEALTH_TIMEOUT_SEC:-1}"

mkdir -p "${STATE_DIR}"
if [ -f "${LOG_FILE}" ]; then
  log_size="$(wc -c < "${LOG_FILE}" 2>/dev/null || echo 0)"
  if [ "${log_size}" -gt "${LOG_MAX_BYTES}" ]; then
    tail -n 2000 "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null || true
    mv "${LOG_FILE}.tmp" "${LOG_FILE}" 2>/dev/null || true
  fi
fi

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  # Previous run still active.
  exit 0
fi

cleanup() {
  rmdir "${LOCK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

now="$(date +%s)"
last_run=0
if [ -f "${STAMP_FILE}" ]; then
  last_run="$(cat "${STAMP_FILE}" 2>/dev/null || echo 0)"
fi

elapsed=$(( now - last_run ))
if [ "${elapsed}" -lt "${MIN_INTERVAL_SEC}" ]; then
  exit 0
fi

if ! curl -sS --max-time "${OLLAMA_HEALTH_TIMEOUT_SEC}" "${OLLAMA_HEALTH_URL}" >/dev/null 2>&1; then
  {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] flush skipped: embedding backend unreachable (${OLLAMA_HEALTH_URL})"
    echo
  } >> "${LOG_FILE}" 2>&1
  exit 0
fi

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] flush start"
  curl -fsS --max-time "${CURL_MAX_TIME_SEC}" "http://${MEMORY_HOST:-127.0.0.1}:${MEMORY_PORT:-18790}/v1/memory/flush" \
    -H 'Content-Type: application/json' \
    -d '{}'
  rc=$?
  echo
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] flush done rc=${rc}"
  echo
} >> "${LOG_FILE}" 2>&1

if [ "${rc}" -eq 0 ]; then
  echo "${now}" > "${STAMP_FILE}"
fi
