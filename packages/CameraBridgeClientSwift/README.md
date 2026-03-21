# CameraBridgeClientSwift

`CameraBridgeClientSwift` is the small Swift client currently used by `CameraBridgeApp`.

Current app-focused surface:

- `health()` to confirm the local daemon is reachable
- `permissionStatus()` for `GET /v1/permissions`
- `requestPermission()` for `POST /v1/permissions/request`
- `serviceIsRunning()` convenience check for the app shell

This package is intentionally narrow in the current slice. Session and capture
helpers are tracked separately and are not part of the shipped client surface
yet.

For the current repo-level setup and first capture flow, see [docs/quick-start.md](../../docs/quick-start.md).
