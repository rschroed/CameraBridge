#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
OUTPUT_DIR="${CAMERABRIDGE_LOCAL_APP_OUTPUT_DIR:-/tmp/CameraBridgeApp-local}"
APP_PATH="$OUTPUT_DIR/CameraBridgeApp.app"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/release/package-app-bundle.sh" \
    --build-configuration debug \
    --output-dir "$OUTPUT_DIR" \
    --signing-mode adhoc

echo "Local app: $APP_PATH"
