#!/bin/zsh
set -euo pipefail

if [[ "${PRODUCT_TYPE:-}" != "com.apple.product-type.application" ]]; then
  echo "[perf-log] Skipping: not an application target."
  exit 0
fi

if [[ -z "${PROJECT_DIR:-}" ]]; then
  echo "[perf-log] Skipping: PROJECT_DIR is undefined."
  exit 0
fi

OUT_DIR="${PROJECT_DIR}/build-metrics"
mkdir -p "$OUT_DIR"

STAMP=$(date +"%Y%m%d-%H%M%S")
OUT_FILE="$OUT_DIR/perf-$STAMP.json"

cat > "$OUT_FILE" <<JSON
{
  "timestamp": "$STAMP",
  "configuration": "${CONFIGURATION:-unknown}",
  "sdk": "${SDK_NAME:-unknown}",
  "target": "${TARGET_NAME:-unknown}",
  "note": "Runtime FPS/latency should be collected from in-app HUD during profiling runs."
}
JSON

echo "[perf-log] Exported build metric stub to $OUT_FILE"

if [[ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]]; then
  mkdir -p "$(dirname "$SCRIPT_OUTPUT_FILE_0")"
  echo "$OUT_FILE" > "$SCRIPT_OUTPUT_FILE_0"
fi
