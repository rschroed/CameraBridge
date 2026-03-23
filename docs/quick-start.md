# CameraBridge Quick Start

If you are adopting CameraBridge as an external dependency, start with the
[Install Guide](./install.md) and [Compatibility](./compatibility.md). This
quick start remains the repo-local source-build path for contributors and local
verification.

This guide walks through the current working v1 loop on macOS:

1. build the repo
2. package and launch `CameraBridgeApp`
3. start the local service, confirm camera permission, and read the surfaced connection details
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
open "/tmp/CameraBridgeApp-local/CameraBridgeApp.app"
```

You can also open the bundle directly from Finder at:

```text
/tmp/CameraBridgeApp-local/CameraBridgeApp.app
```

## Start The Service And Confirm Permission

From the menu bar app:

1. click `Start CameraBridge Service`
2. confirm the app shows `Service: Running`
3. click `Request Camera Access` if permission is still undecided
4. allow the macOS camera prompt shown by `CameraBridgeApp`
5. confirm the app shows `Permission: Authorized`
6. note the `Base URL`, `Token`, `Log`, and `Captures` rows shown in the menu

The packaged app supervises the bundled daemon in the supported v1 flow:

- `Start CameraBridge Service` launches the bundled `camd` if the configured endpoint is not already healthy
- `Stop CameraBridge Service` stops only the daemon instance launched by the app
- `Quit CameraBridge` stops that managed daemon before exit
- if the app detects an already-running daemon that it did not launch, it shows `Running (External)` and leaves that process alone

The app surfaces the effective connection details in its menu. In the default packaged flow they are:

```text
Base URL: http://127.0.0.1:8731
Token: ~/Library/Application Support/CameraBridge/auth-token
Log: ~/Library/Application Support/CameraBridge/Logs/camd.log
Captures: ~/Library/Application Support/CameraBridge/Captures/
```

The packaged flow reads runtime configuration from:

```text
~/Library/Application Support/CameraBridge/runtime-configuration.json
```

If no configuration file exists, CameraBridge defaults to `127.0.0.1:8731`.

The daemon reads live AVFoundation permission status directly for
`/v1/permissions`, `/v1/permissions/request`, and the session-start permission
precondition.

## Verify The Local API

Use the base URL and token path surfaced by the app. With the default packaged
flow, check the service health and current permission state with:

```bash
curl -s http://127.0.0.1:8731/health
curl -s http://127.0.0.1:8731/v1/permissions
curl -s -X POST http://127.0.0.1:8731/v1/permissions/request \
  -H "Authorization: Bearer $(cat ~/Library/Application\\ Support/CameraBridge/auth-token)" \
  -H 'Content-Type: application/json' \
  -d '{}'
curl -s http://127.0.0.1:8731/v1/devices
```

`POST /v1/permissions/request` now returns `200 OK` for every permission state.
When permission is already decided, the response keeps `prompted: false` and
returns `message: null` and `next_step: null`. When permission is still
`not_determined`, the route returns guided next-step data instead of `409`:

```json
{
  "message": "Open CameraBridgeApp to request camera access.",
  "next_step": {
    "kind": "open_camera_bridge_app"
  },
  "prompted": false,
  "status": "not_determined"
}
```

On macOS, a local client can turn that next step into a concrete handoff with:

```bash
open "camerabridge://permission"
```

That handoff opens the existing `CameraBridgeApp` menu bar UI only. It does not
start the service or trigger the permission prompt automatically.

The mutating endpoints use the bearer token shown in the app. In the default
packaged flow:

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

- [Install Guide](./install.md)
- [Compatibility](./compatibility.md)
- [API v1 Contract](./api/v1.md)
- [Release Readiness](./release-readiness.md)
- [CameraBridgeApp README](../apps/CameraBridgeApp/README.md)
- [Python Example](../examples/python/capture_photo.py)
