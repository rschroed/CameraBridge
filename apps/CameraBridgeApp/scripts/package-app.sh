#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
APP_NAME="CameraBridgeApp"

cd "$ROOT_DIR"

swift build --product "$APP_NAME"

BIN_DIR="$(swift build --show-bin-path)"
APP_DIR="$BIN_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/apps/CameraBridgeApp/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --sign - "$APP_DIR" >/dev/null

echo "Packaged $APP_DIR"
