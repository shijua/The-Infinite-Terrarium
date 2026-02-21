#!/bin/zsh
set -euo pipefail

if [[ "${PRODUCT_TYPE:-}" != "com.apple.product-type.application" ]]; then
  echo "[bundle-size] Skipping: not an application target."
  exit 0
fi

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${WRAPPER_NAME:-}" ]]; then
  echo "[bundle-size] Skipping: build environment variables missing."
  exit 0
fi

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
if [[ ! -d "$APP_PATH" ]]; then
  echo "[bundle-size] Skipping: app bundle not found at $APP_PATH"
  exit 0
fi

SIZE_BYTES=$(du -sk "$APP_PATH" | awk '{print $1 * 1024}')
MAX_BYTES=$((25 * 1024 * 1024))

if (( SIZE_BYTES > MAX_BYTES )); then
  echo "error: [bundle-size] Bundle is $SIZE_BYTES bytes, exceeding 25MB limit ($MAX_BYTES bytes)."
  exit 1
fi

echo "[bundle-size] OK: $SIZE_BYTES bytes"

if [[ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]]; then
  mkdir -p "$(dirname "$SCRIPT_OUTPUT_FILE_0")"
  echo "$SIZE_BYTES" > "$SCRIPT_OUTPUT_FILE_0"
fi
