#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw one-click install (macOS, V3 memory)
#
# Usage: double-click this file.
# ============================================================================

printf '\033]0;OpenClaw Install V3\007'

clear
echo ""
echo "  ============================================"
echo "  OpenClaw one-click installer (V3)"
echo "  ============================================"
echo ""
echo "  Downloading the latest V3 setup script..."
echo ""

GIST_URL="https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup-v3.sh"

TMPDIR_SETUP="$(mktemp -d)"
SCRIPT_PATH="${TMPDIR_SETUP}/openclaw-setup-v3.sh"

cleanup() {
  rm -rf "${TMPDIR_SETUP}"
}
trap cleanup EXIT

if ! curl -fsSL "${GIST_URL}" -o "${SCRIPT_PATH}" 2>/dev/null; then
  echo ""
  echo "  Download failed."
  echo "  Check your internet connection and try again."
  echo ""
  echo "  Press any key to close."
  read -n1 -s
  exit 1
fi

bash "${SCRIPT_PATH}"
EXIT_CODE=$?

echo ""
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "  Completed. Press any key to close."
else
  echo "  Installation failed. (exit: ${EXIT_CODE})"
  echo "  Send the installer log to the operator."
  echo "  Press any key to close."
fi
read -n1 -s
