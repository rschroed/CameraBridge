#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PACKAGE_SCRIPT="$ROOT_DIR/scripts/release/package-app-bundle.sh"

VERSION="${CAMERABRIDGE_VERSION:-}"
OUTPUT_DIR="${CAMERABRIDGE_RELEASE_OUTPUT_DIR:-$ROOT_DIR/dist}"
SIGNING_MODE="${CAMERABRIDGE_RELEASE_SIGNING_MODE:-developer-id}"
SKIP_NOTARIZATION="${CAMERABRIDGE_SKIP_NOTARIZATION:-0}"
NOTARY_KEYCHAIN_PROFILE="${CAMERABRIDGE_NOTARY_KEYCHAIN_PROFILE:-}"

usage() {
    cat <<'EOF'
Usage:
  create-release-artifacts.sh --version <v0.x.y> [options]

Options:
  --version <version>
  --output-dir <path>
  --signing-mode <adhoc|developer-id>
  --skip-notarization
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
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
        --skip-notarization)
            SKIP_NOTARIZATION="1"
            shift 1
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

if [[ -z "$VERSION" ]]; then
    echo "A release version is required" >&2
    exit 1
fi

if [[ ! "$VERSION" =~ ^v0\.[0-9]+\.[0-9]+([-.][A-Za-z0-9._-]+)?$ ]]; then
    echo "Release version must match v0.x.y or a tagged pre-release derived from v0.x.y" >&2
    exit 1
fi

if [[ "$SIGNING_MODE" != "adhoc" && "$SIGNING_MODE" != "developer-id" ]]; then
    echo "Unsupported signing mode: $SIGNING_MODE" >&2
    exit 1
fi

ARTIFACT_PREFIX="CameraBridgeApp-${VERSION}-macos"
BUNDLE_VERSION="$(printf '%s' "$VERSION" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)([-.].*)?$/\1/')"
STAGE_DIR="$OUTPUT_DIR/stage"
APP_PATH="$STAGE_DIR/CameraBridgeApp.app"
NOTARIZATION_ZIP="$OUTPUT_DIR/${ARTIFACT_PREFIX}-notarization.zip"
RELEASE_ZIP="$OUTPUT_DIR/${ARTIFACT_PREFIX}.zip"
CHECKSUM_FILE="$OUTPUT_DIR/${ARTIFACT_PREFIX}.zip.sha256"
RELEASE_ZIP_NAME="$(basename "$RELEASE_ZIP")"

mkdir -p "$STAGE_DIR"
rm -f "$NOTARIZATION_ZIP" "$RELEASE_ZIP" "$CHECKSUM_FILE"

"$PACKAGE_SCRIPT" \
    --build-configuration release \
    --output-dir "$STAGE_DIR" \
    --signing-mode "$SIGNING_MODE" \
    --bundle-version "$BUNDLE_VERSION"

if [[ "$SIGNING_MODE" == "developer-id" && "$SKIP_NOTARIZATION" != "1" ]]; then
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZATION_ZIP"

    if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
        xcrun notarytool submit "$NOTARIZATION_ZIP" \
            --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
            --wait
    else
        : "${CAMERABRIDGE_NOTARY_KEY_ID:?CAMERABRIDGE_NOTARY_KEY_ID is required for notarization when CAMERABRIDGE_NOTARY_KEYCHAIN_PROFILE is unset}"
        : "${CAMERABRIDGE_NOTARY_ISSUER_ID:?CAMERABRIDGE_NOTARY_ISSUER_ID is required for notarization when CAMERABRIDGE_NOTARY_KEYCHAIN_PROFILE is unset}"
        : "${CAMERABRIDGE_NOTARY_PRIVATE_KEY:?CAMERABRIDGE_NOTARY_PRIVATE_KEY is required for notarization when CAMERABRIDGE_NOTARY_KEYCHAIN_PROFILE is unset}"

        PRIVATE_KEY_FILE="$(mktemp "$OUTPUT_DIR/notary-key.XXXXXX.p8")"
        trap 'rm -f "$PRIVATE_KEY_FILE"' EXIT
        printf '%s' "$CAMERABRIDGE_NOTARY_PRIVATE_KEY" > "$PRIVATE_KEY_FILE"

        xcrun notarytool submit "$NOTARIZATION_ZIP" \
            --key "$PRIVATE_KEY_FILE" \
            --key-id "$CAMERABRIDGE_NOTARY_KEY_ID" \
            --issuer "$CAMERABRIDGE_NOTARY_ISSUER_ID" \
            --wait
    fi

    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"

    if ! SPCTL_OUTPUT="$(spctl -a -vv --type open "$APP_PATH" 2>&1)"; then
        echo "Warning: staged app Gatekeeper assessment did not pass for $APP_PATH" >&2
        echo "$SPCTL_OUTPUT" >&2
        echo "Continue with downloaded-artifact validation from GitHub Releases before treating the release as ready." >&2
    else
        echo "$SPCTL_OUTPUT"
    fi
fi

ditto -c -k --keepParent "$APP_PATH" "$RELEASE_ZIP"
(
    cd "$OUTPUT_DIR"
    shasum -a 256 "$RELEASE_ZIP_NAME"
) > "$CHECKSUM_FILE"

codesign --verify --strict --verbose=2 "$APP_PATH"

echo "Release app: $APP_PATH"
echo "Bundle version: $BUNDLE_VERSION"
echo "Release zip: $RELEASE_ZIP"
echo "Checksum: $CHECKSUM_FILE"
