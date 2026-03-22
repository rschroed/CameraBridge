#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_NAME="CameraBridgeApp"
DAEMON_NAME="camd"
APP_IDENTIFIER="io.camerabridge.CameraBridgeApp"
DAEMON_IDENTIFIER="io.camerabridge.camd"
APP_REQUIREMENT="designated => identifier \"$APP_IDENTIFIER\""
DAEMON_REQUIREMENT="designated => identifier \"$DAEMON_IDENTIFIER\""

BUILD_CONFIGURATION="release"
OUTPUT_DIR=""
SIGNING_MODE="adhoc"
SIGNING_IDENTITY="${CAMERABRIDGE_SIGNING_IDENTITY:-}"
BUNDLE_VERSION=""

usage() {
    cat <<'EOF'
Usage:
  package-app-bundle.sh [options]

Options:
  --build-configuration <debug|release>
  --output-dir <path>
  --signing-mode <adhoc|developer-id>
  --signing-identity <identity>
  --bundle-version <0.x.y>
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-configuration)
            BUILD_CONFIGURATION="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --signing-mode)
            SIGNING_MODE="$2"
            shift 2
            ;;
        --signing-identity)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --bundle-version)
            BUNDLE_VERSION="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "$BUILD_CONFIGURATION" != "debug" && "$BUILD_CONFIGURATION" != "release" ]]; then
    echo "Unsupported build configuration: $BUILD_CONFIGURATION" >&2
    exit 1
fi

if [[ "$SIGNING_MODE" != "adhoc" && "$SIGNING_MODE" != "developer-id" ]]; then
    echo "Unsupported signing mode: $SIGNING_MODE" >&2
    exit 1
fi

if [[ -n "$BUNDLE_VERSION" && ! "$BUNDLE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Bundle version must match 0.x.y when provided" >&2
    exit 1
fi

cd "$ROOT_DIR"

swift build --configuration "$BUILD_CONFIGURATION" --product "$APP_NAME"
swift build --configuration "$BUILD_CONFIGURATION" --product "$DAEMON_NAME"

BIN_DIR="$(swift build --configuration "$BUILD_CONFIGURATION" --show-bin-path)"
OUTPUT_DIR="${OUTPUT_DIR:-$BIN_DIR}"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/apps/CameraBridgeApp/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BIN_DIR/$DAEMON_NAME" "$RESOURCES_DIR/$DAEMON_NAME"
chmod +x "$RESOURCES_DIR/$DAEMON_NAME"

if [[ -n "$BUNDLE_VERSION" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUNDLE_VERSION" \
        "$CONTENTS_DIR/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" \
        "$CONTENTS_DIR/Info.plist"
fi

xattr -cr "$APP_DIR" || true

sign_path() {
    local target_path="$1"
    local identifier="$2"
    local requirement="$3"

    if [[ "$SIGNING_MODE" == "adhoc" ]]; then
        codesign --force --sign - -i "$identifier" -r="$requirement" \
            "$target_path" >/dev/null
        return
    fi

    if [[ -z "$SIGNING_IDENTITY" ]]; then
        echo "CAMERABRIDGE_SIGNING_IDENTITY or --signing-identity is required for developer-id signing" >&2
        exit 1
    fi

    codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime \
        -i "$identifier" "$target_path" >/dev/null
}

sign_path "$RESOURCES_DIR/$DAEMON_NAME" "$DAEMON_IDENTIFIER" "$DAEMON_REQUIREMENT"
sign_path "$APP_DIR" "$APP_IDENTIFIER" "$APP_REQUIREMENT"

codesign --verify --strict --verbose=2 "$APP_DIR"

echo "Packaged $APP_DIR"
