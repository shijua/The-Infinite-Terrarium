#!/bin/zsh
set -euo pipefail

if [[ "${PRODUCT_TYPE:-}" != "com.apple.product-type.application" ]]; then
  echo "[offline-check] Skipping: not an application target."
  exit 0
fi

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${EXECUTABLE_PATH:-}" ]]; then
  echo "[offline-check] Skipping: build environment variables missing."
  exit 0
fi

BIN_PATH="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "[offline-check] Skipping: executable not found at $BIN_PATH"
  exit 0
fi

if ! command -v nm >/dev/null; then
  echo "[offline-check] Skipping: nm command unavailable"
  exit 0
fi

SYMBOLS=$(nm -gj "$BIN_PATH" 2>/dev/null || true)

BLOCKLIST=(
  "_URLSession"
  "_CFNetwork"
  "_nw_connection"
  "_NSURLConnection"
)

for sym in "${BLOCKLIST[@]}"; do
  if echo "$SYMBOLS" | grep -q "$sym"; then
    echo "error: [offline-check] Forbidden network symbol detected: $sym"
    exit 1
  fi
done

echo "[offline-check] OK: no forbidden network symbols"

if [[ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]]; then
  mkdir -p "$(dirname "$SCRIPT_OUTPUT_FILE_0")"
  echo "ok" > "$SCRIPT_OUTPUT_FILE_0"
fi
