#!/bin/bash
set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${WORKDIR}/.env" ]; then
  set -a
  . "${WORKDIR}/.env"
  set +a
fi
LOCK_DIR="/tmp/memory-v3-backfill-ko.lockdir"
LOG_FILE="/tmp/memory-v3-backfill-ko.log"
PYTHON_BIN="${PYTHON_BIN:-${WORKDIR}/.venv/bin/python}"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi

mkdir -p /tmp

# Prevent overlap if previous run is still active (portable lock)
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [skip] backfill already running" >> "$LOG_FILE"
  exit 0
fi
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

cd "$WORKDIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') [start] incremental ko backfill" >> "$LOG_FILE"
"${PYTHON_BIN}" backfill_fact_ko.py \
  --batch-size 25 \
  --sleep 0 \
  --max-batches 4 \
  --failures-file backfill_failures_cron.json \
  >> "$LOG_FILE" 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') [done] incremental ko backfill" >> "$LOG_FILE"
echo >> "$LOG_FILE"
