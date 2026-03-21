# CameraBridge Release Readiness

This document defines the manual smoke test for the current v1 first-capture
flow and the checklist to record release-readiness results.

This validation requires:

- a real Mac
- a real local camera device
- the packaged `CameraBridgeApp.app` bundle

It is intentionally manual. CI should continue to avoid hardware dependencies.

## First-Capture Smoke Test

### Goal

Validate the packaged app, daemon bootstrap, local token path, permission flow,
device selection, still capture, and capture artifact path in one repeatable
manual run.

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

2. Launch the packaged app:

```bash
open "$(swift build --show-bin-path)/CameraBridgeApp.app"
```

Expected checkpoints:

- the menu bar app appears
- the initial state reports the service as stopped
- `Start CameraBridge Service` is available

3. Start the service from the menu bar app.

Expected checkpoints:

- the menu updates to `Service: Running`
- `camd` binds to `127.0.0.1:8731`
- `~/Library/Application Support/CameraBridge/auth-token` exists

4. Request camera access from the menu bar app if permission is not already
   authorized.

Expected checkpoints:

- the macOS permission prompt appears when status is `not_determined`
- the menu reaches `Permission: Authorized`
- failures are surfaced in the menu with readable text

5. Verify the local API:

```bash
curl -s http://127.0.0.1:8731/health
curl -s http://127.0.0.1:8731/v1/permissions
curl -s http://127.0.0.1:8731/v1/devices
```

Expected checkpoints:

- `/health` returns `{"status":"ok"}`
- `/v1/permissions` returns `authorized`
- `/v1/devices` returns at least one real camera device

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

## Failure Surfaces To Record

Record any failure in these areas:

- packaged app fails to launch
- daemon fails to start or bind localhost
- auth token file is missing or unreadable
- permission prompt does not appear when expected
- permission state does not update after the prompt
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
- [ ] Packaged `CameraBridgeApp.app` launched successfully
- [ ] `camd` started from the app and reported healthy on `127.0.0.1:8731`
- [ ] Auth token file existed at `~/Library/Application Support/CameraBridge/auth-token`
- [ ] Camera permission reached `authorized`
- [ ] `GET /v1/devices` returned the expected camera
- [ ] Python first-capture example completed successfully
- [ ] Capture artifact existed at the reported `local_path`
- [ ] `GET /v1/session` returned `stopped` after cleanup
- [ ] Any issues or follow-up fixes were recorded before release

## Result Template

Fill this in during the manual run:

- Date:
- Machine:
- macOS version:
- Camera device:
- Result:
- Notes:
