# CameraBridge Quick Start

This guide walks through the current working v1 loop on macOS:

1. build the repo
2. package and launch `CameraBridgeApp`
3. start the local service and confirm camera permission
4. run one minimal example client that selects a device, starts a session, captures a still image, and stops the session

## Prerequisites

- macOS 14 or newer
- Swift 5.10 toolchain available through Xcode or Command Line Tools
- at least one working local camera device

## Build The Repo

From the repo root:

```bash
swift build
swift test
```

## Package And Launch The App

Package the app bundle:

```bash
apps/CameraBridgeApp/scripts/package-app.sh
```

Launch the packaged app:

```bash
open "$(swift build --show-bin-path)/CameraBridgeApp.app"
```

You can also open the bundle directly from Finder at:

```text
$(swift build --show-bin-path)/CameraBridgeApp.app
```

## Start The Service And Confirm Permission

From the menu bar app:

1. click `Start Service`
2. confirm the app shows `Service: running`
3. click `Request Camera Access` if permission is still undecided
4. allow the macOS camera prompt shown by `CameraBridgeApp`
5. confirm the app shows `Permission: authorized`

When `camd` starts without `CAMERABRIDGE_AUTH_TOKEN`, it loads or creates the local bearer token at:

```text
~/Library/Application Support/CameraBridge/auth-token
```

The packaged app uses that same daemon-owned token contract when it launches the bundled service.

The daemon reads live AVFoundation permission status directly for
`/v1/permissions`, `/v1/permissions/request`, and the session-start permission
precondition.

The packaged app starts `camd` as a localhost-only service intended to be reachable from other local clients at `127.0.0.1:8731`.

Camera captures are stored under:

```text
~/Library/Application Support/CameraBridge/Captures/
```

## Verify The Local API

Check the service health and current permission state:

```bash
curl -s http://127.0.0.1:8731/health
curl -s http://127.0.0.1:8731/v1/permissions
curl -s -X POST http://127.0.0.1:8731/v1/permissions/request \
  -H "Authorization: Bearer $(cat ~/Library/Application\\ Support/CameraBridge/auth-token)" \
  -H 'Content-Type: application/json' \
  -d '{}'
curl -s http://127.0.0.1:8731/v1/devices
```

If permission is already decided, `POST /v1/permissions/request` returns the
current daemon-visible status with `prompted: false`. The route remains in the
API so local clients have a stable token-protected way to check whether
permission is now usable. If it returns `409 invalid_state`, go back to the
menu bar app and request access there.

The mutating endpoints use the bearer token from Application Support:

```bash
TOKEN="$(cat ~/Library/Application\ Support/CameraBridge/auth-token)"
```

## Run The Minimal Example Client

The repository includes one minimal Python example with no external dependencies:

```bash
python3 examples/python/capture_photo.py --device-id "YOUR_DEVICE_ID"
```

Get a real device id from `GET /v1/devices`. Example output includes:

- selected device response
- started session response
- capture metadata including `local_path`
- stopped session response

Optional arguments:

```bash
python3 examples/python/capture_photo.py \
  --device-id "YOUR_DEVICE_ID" \
  --owner-id "client-1" \
  --token-file "$HOME/Library/Application Support/CameraBridge/auth-token"
```

The example is safe to rerun when the same `owner_id` already owns an active session. In that case it stops the existing session first and then repeats the flow.

## Manual Flow Without The Example Script

If you want to exercise the same flow manually:

```bash
TOKEN="$(cat ~/Library/Application\ Support/CameraBridge/auth-token)"

curl -s -X POST http://127.0.0.1:8731/v1/session/select-device \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"device_id":"YOUR_DEVICE_ID","owner_id":"client-1"}'

curl -s -X POST http://127.0.0.1:8731/v1/session/start \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"owner_id":"client-1"}'

curl -s -X POST http://127.0.0.1:8731/v1/capture/photo \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"owner_id":"client-1"}'

curl -s -X POST http://127.0.0.1:8731/v1/session/stop \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"owner_id":"client-1"}'
```

## Next References

- [API v1 Contract](./api/v1.md)
- [Release Readiness](./release-readiness.md)
- [CameraBridgeApp README](../apps/CameraBridgeApp/README.md)
- [Python Example](../examples/python/capture_photo.py)
