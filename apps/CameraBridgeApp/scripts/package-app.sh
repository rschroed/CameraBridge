#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
APP_NAME="CameraBridgeApp"
DAEMON_NAME="camd"
APP_IDENTIFIER="io.camerabridge.CameraBridgeApp"
DAEMON_IDENTIFIER="io.camerabridge.camd"
APP_REQUIREMENT="designated => identifier \"$APP_IDENTIFIER\""
DAEMON_REQUIREMENT="designated => identifier \"$DAEMON_IDENTIFIER\""

cd "$ROOT_DIR"

swift build --product "$APP_NAME"
swift build --product "$DAEMON_NAME"

BIN_DIR="$(swift build --show-bin-path)"
APP_DIR="$BIN_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/apps/CameraBridgeApp/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BIN_DIR/$DAEMON_NAME" "$RESOURCES_DIR/$DAEMON_NAME"
chmod +x "$RESOURCES_DIR/$DAEMON_NAME"

codesign --force --sign - -i "$DAEMON_IDENTIFIER" -r="$DAEMON_REQUIREMENT" \
    "$RESOURCES_DIR/$DAEMON_NAME" >/dev/null
codesign --force --sign - -i "$APP_IDENTIFIER" -r="$APP_REQUIREMENT" \
    "$APP_DIR" >/dev/null

echo "Packaged $APP_DIR"
