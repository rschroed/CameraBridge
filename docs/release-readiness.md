# CameraBridge Release Readiness

This document defines the manual smoke test for the current v1 first-capture
flow and the checklist to record release-readiness results.

This validation requires:

- a real Mac
- a real local camera device
- the packaged `CameraBridgeApp.app` bundle

It is intentionally manual. CI should continue to avoid hardware dependencies.

## External Artifact Validation

Before treating a GitHub Release as ready for external adopters, validate the
published artifact path as well as the repo-local smoke test.

Expected checks:

- download the published maintainer-produced
  `CameraBridgeApp-v0.x.y-macos.zip` asset from GitHub Releases
- verify the published checksum matches the downloaded zip
- install the downloaded app bundle into `/Applications`
- confirm Gatekeeper accepts launch of the notarized app
- confirm the installed app can complete the packaged-flow smoke test

## First-Capture Smoke Test

### Goal

Validate the packaged app, app-supervised daemon lifecycle, local token path,
permission flow, developer-info surfacing, device selection, still capture, and
capture artifact path in one repeatable manual run.

### Prerequisites

- macOS 14 or newer
- Xcode or Command Line Tools with Swift 5.10 available
- at least one working local camera device
- permission to grant Camera access when prompted

### Procedure

1. Build and package the app:

```bash
swift build
swift test
apps/CameraBridgeApp/scripts/package-app.sh
```

Before treating camera permission continuity as a regression signal, note that
older locally packaged builds used plain cdhash-only ad-hoc signing. After
adopting the current packaging flow, re-grant camera access once so TCC can
store the newer identifier-based local requirement for `CameraBridgeApp.app`.

2. Launch the packaged app:

```bash
open "$(swift build --show-bin-path)/CameraBridgeApp.app"
```

Expected checkpoints:

- the menu bar app appears
- the initial state reports the service as stopped
- `Start CameraBridge Service` is available
- developer info rows are visible even before capture

3. Start the service from the menu bar app.

Expected checkpoints:

- the menu updates to `Service: Running`
- `Stop CameraBridge Service` becomes available
- `camd` binds to `127.0.0.1:8731`
- `~/Library/Application Support/CameraBridge/auth-token` exists
- the menu surfaces the effective base URL, token path, log path, and captures path

4. Request camera access from the menu bar app if permission is not already
   authorized.

Expected checkpoints:

- the macOS permission prompt appears from `CameraBridgeApp` when status is `not_determined`
- the menu reaches `Permission: Authorized`
- failures are surfaced in the menu with readable text

If the machine is in a fresh `not_determined` state before permission is
granted, `POST /v1/permissions/request` should return `200 OK` with a guided
`next_step.kind` of `open_camera_bridge_app` rather than `409 invalid_state`.

5. Verify the local API:

```bash
curl -s http://127.0.0.1:8731/health
curl -s http://127.0.0.1:8731/v1/permissions
TOKEN="$(cat ~/Library/Application\ Support/CameraBridge/auth-token)"
curl -s -X POST http://127.0.0.1:8731/v1/permissions/request \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{}'
curl -s http://127.0.0.1:8731/v1/devices
```

Expected checkpoints:

- `/health` returns `{"status":"ok"}`
- `/v1/permissions` returns `authorized`
- `/v1/permissions/request` returns `{"message":null,"next_step":null,"prompted":false,"status":"authorized"}`
- `/v1/devices` returns at least one real camera device

5a. Verify stale file non-involvement:

```bash
mkdir -p ~/Library/Application\ Support/CameraBridge
printf 'denied' > ~/Library/Application\ Support/CameraBridge/permission-state
curl -s http://127.0.0.1:8731/v1/permissions
curl -s -X POST http://127.0.0.1:8731/v1/permissions/request \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Expected checkpoints:

- the stale `permission-state` file does not change daemon permission responses
- `/v1/permissions` and `/v1/permissions/request` still reflect live OS permission state

6. Run the first-capture example with a real device id:

```bash
python3 examples/python/capture_photo.py --device-id "YOUR_DEVICE_ID"
```

Expected checkpoints:

- device selection succeeds
- session start succeeds
- still capture succeeds
- session stop succeeds
- the reported `local_path` exists on disk under `~/Library/Application Support/CameraBridge/Captures/`

7. Confirm cleanup behavior:

Expected checkpoints:

- `GET /v1/session` reports `state: stopped`
- the selected `active_device_id` is preserved for later restart
- the app remains responsive after capture
- stopping the service from the app returns the menu to the stopped state
- quitting the app after a managed start leaves no healthy managed daemon behind

## Failure Surfaces To Record

Record any failure in these areas:

- packaged app fails to launch
- daemon fails to start or bind localhost
- auth token file is missing or unreadable
- permission prompt does not appear when expected
- permission state does not update after the prompt
- daemon permission routes do not reflect live OS permission state
- permission request route returns an error instead of guided `200 OK` data for undecided permission
- device listing is empty despite connected hardware
- session start or device selection fails unexpectedly
- capture fails or no artifact is written
- app UI shows stale or misleading status

## Release Checklist

Use this checklist to record one real-hardware validation run before a v1
release:

- [ ] Machine and macOS version recorded
- [ ] Camera device model or built-in camera noted
- [ ] `swift build` passed
- [ ] `swift test` passed
- [ ] Published GitHub Release zip downloaded successfully
- [ ] Published checksum matched the downloaded zip
- [ ] Installed app bundle launched successfully from `/Applications`
- [ ] Gatekeeper accepted the notarized app
- [ ] Packaged `CameraBridgeApp.app` launched successfully
- [ ] `camd` started from the app and reported healthy on `127.0.0.1:8731`
- [ ] Auth token file existed at `~/Library/Application Support/CameraBridge/auth-token`
- [ ] App surfaced base URL, token path, log path, and captures path
- [ ] Camera permission reached `authorized`
- [ ] `GET /v1/permissions` reflected live OS permission state
- [ ] `POST /v1/permissions/request` returned `message:null`, `next_step:null`, and `prompted:false` after authorization
- [ ] Stale `permission-state` file had no effect on daemon permission responses
- [ ] `GET /v1/devices` returned the expected camera
- [ ] Python first-capture example completed successfully
- [ ] Capture artifact existed at the reported `local_path`
- [ ] `GET /v1/session` returned `stopped` after cleanup
- [ ] `Stop CameraBridge Service` returned the app to the stopped state
- [ ] Quitting the app stopped the managed daemon
- [ ] Any issues or follow-up fixes were recorded before release

## Result Template

Fill this in during the manual run:

- Date:
- Machine:
- macOS version:
- Camera device:
- Result:
- Notes:

### Latest Recorded Run

- Date: 2026-03-22
- Machine: Mac17,3
- macOS version: 26.3.1 (25D2128)
- Camera device: Insta360 Link 2
- Result: Passed
- Notes:
  - Packaged `CameraBridgeApp.app` launched successfully
  - Managed `camd` started from the app and reported healthy on `127.0.0.1:8731`
  - App surfaced base URL, token path, log path, and captures path
  - `GET /health` returned `200 OK`
  - `GET /v1/permissions` returned `authorized`
  - `POST /v1/permissions/request` returned `{"message":null,"next_step":null,"prompted":false,"status":"authorized"}`
  - A stale `~/Library/Application Support/CameraBridge/permission-state` file did not affect daemon permission responses
  - `GET /v1/devices` returned the expected connected cameras, including `Insta360 Link 2`
  - `examples/python/capture_photo.py --device-id 0x1220002e1a4c04` completed successfully
  - Capture artifact written to `~/Library/Application Support/CameraBridge/Captures/capture-20260322T181648347Z-ed4b866a-ac2a-4791-8847-b1e893c702ca.jpg`
  - `GET /v1/session` returned `stopped` after cleanup while preserving `active_device_id`
  - `Stop CameraBridge Service` returned the app to the stopped state, removed `runtime-info.json`, and took `/health` down
  - `Quit CameraBridge` exited the app cleanly and left no managed daemon running
