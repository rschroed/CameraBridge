#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

cd "$ROOT_DIR"
BIN_DIR="$(swift build --show-bin-path)"
"$ROOT_DIR/scripts/release/package-app-bundle.sh" \
    --build-configuration debug \
    --output-dir "$BIN_DIR" \
    --signing-mode adhoc
