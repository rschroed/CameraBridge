# CameraBridgeClientSwift

`CameraBridgeClientSwift` is the small Swift client currently used by `CameraBridgeApp`.

Current shipped surface:

- `health()` to confirm the local daemon is reachable
- `serviceIsRunning()` convenience check for the app shell
- `permissionStatus()` for `GET /v1/permissions`
- `requestPermission()` for `POST /v1/permissions/request`
- `devices()` for `GET /v1/devices`
- `sessionState()` for `GET /v1/session`
- `selectDevice(deviceID:ownerID:)` for `POST /v1/session/select-device`
- `startSession(ownerID:)` for `POST /v1/session/start`
- `stopSession(ownerID:)` for `POST /v1/session/stop`
- `capturePhoto(ownerID:)` for `POST /v1/capture/photo`

The client exposes typed models for:

- permission status and permission request results
- device inventory
- session state snapshots
- captured photo artifact metadata

Protected endpoints use the same bearer-token contract as the daemon and app:

```swift
let client = CameraBridgeClient(tokenProvider: { try? String(contentsOfFile: tokenPath) })
```

The request and response contract for the full shipped client surface is
covered by `swift test` in `tests/CameraBridgeClientSwiftTests`.

`requestPermission()` no longer triggers a macOS prompt from `camd`. It returns
the daemon's live permission state with `prompted: false`, or surfaces the
`409 invalid_state` response that tells callers to use `CameraBridgeApp` when
permission is still `not_determined`. The route remains available so local
clients can programmatically check whether permission is now usable before
camera actions.

For the current repo-level setup and first capture flow, see [docs/quick-start.md](../../docs/quick-start.md).
