#!/bin/bash
# Memory eviction — runs daily via cron
# Archives active memories older than EVICTION_AGE_DAYS with hit_count=0.
#
# Add to crontab (runs at 03:00 daily):
#   0 3 * * * ~/.openclaw/services/memory-v2/eviction-cron.sh
#
# First run (dry-run, inspect before committing):
#   ~/.openclaw/services/memory-v2/.venv/bin/python ~/.openclaw/services/memory-v2/eviction_worker.py --dry-run
set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${WORKDIR}/.env" ]; then
    set -a
    . "${WORKDIR}/.env"
    set +a
fi
LOCK_DIR="/tmp/memory-eviction.lockdir"
LOG_FILE="/tmp/memory-eviction.log"
PYTHON_BIN="${PYTHON_BIN:-${WORKDIR}/.venv/bin/python}"
if [ ! -x "${PYTHON_BIN}" ]; then
    PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi

# Prevent overlap if previous run is still active
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [skip] eviction already running" >> "$LOG_FILE"
    exit 0
fi
trap "rmdir '$LOCK_DIR' 2>/dev/null || true" EXIT INT TERM

cd "$WORKDIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') [start] memory eviction" >> "$LOG_FILE"
"${PYTHON_BIN}" eviction_worker.py >> "$LOG_FILE" 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') [done]" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
