#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/installer/templates/memory-v3"
OUTPUT_PATH="${1:-${REPO_ROOT}/dist/openclaw-memory-v3-payload.tar.gz}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"
TMPDIR_BUNDLE="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_BUNDLE}"' EXIT

cp "${SOURCE_DIR}/001_base_schema.sql" "${TMPDIR_BUNDLE}/001_base_schema.sql"

required_payload_files=(
  "llm_atomizer.py"
  "llm_atomize_worker.py"
  "ollama_helper.py"
)
for rel in "${required_payload_files[@]}"; do
  if [[ ! -f "${SOURCE_DIR}/payload/${rel}" ]]; then
    echo "missing required payload file: ${SOURCE_DIR}/payload/${rel}" >&2
    exit 1
  fi
done

rsync -a \
  --exclude='__pycache__' \
  --exclude='.pytest_cache' \
  "${SOURCE_DIR}/payload/" "${TMPDIR_BUNDLE}/payload/"
rsync -a \
  --exclude='memory.db' \
  --exclude='*.log' \
  "${SOURCE_DIR}/extension/" "${TMPDIR_BUNDLE}/extension/"

tar -czf "${OUTPUT_PATH}" -C "${TMPDIR_BUNDLE}" 001_base_schema.sql payload extension
printf 'bundle=%s\n' "${OUTPUT_PATH}"

if [[ "${2:-}" == "--base64" ]]; then
  openssl base64 -A -in "${OUTPUT_PATH}" -out "${OUTPUT_PATH}.b64"
  printf 'bundle_b64=%s.b64\n' "${OUTPUT_PATH}"
fi
