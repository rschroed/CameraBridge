# CameraBridgeApp

`CameraBridgeApp` is reserved for the macOS menu bar application, onboarding flow, and service status UI.

The app remains a thin client of the localhost CameraBridge service. Its menu bar shell is limited to:

- service running or stopped visibility
- managed versus external service-state visibility
- camera permission visibility
- onboarding guidance for the next user action
- starting the bundled `camd` service
- stopping the bundled `camd` service when this app owns that process
- requesting camera access directly from the app process
- surfacing base URL, token path, log path, and captures path for local integrators
- quitting the app

`CameraBridgeApp` is the only supported camera-permission prompt initiator in v1.
It reads and requests camera access through the app bundle. The bundled daemon
reads live AVFoundation permission status directly for `/v1/permissions`,
`/v1/permissions/request`, and session-start preconditions.

The packaged app is also the supported lifecycle manager for the bundled daemon:

- `Start CameraBridge Service` launches the bundled daemon when the configured endpoint is not already healthy
- `Stop CameraBridge Service` stops only the daemon instance managed by this app
- `Quit CameraBridge` stops the managed daemon before the app exits
- if the app detects an already-running daemon that it did not launch, it reports `Running (External)` and does not kill that process

## Local Packaging

For external adopters, the supported install path is the signed GitHub Release
artifact flow documented in [docs/install.md](../../docs/install.md). This
section remains the contributor-focused local packaging path.

Package a local `.app` bundle with:

```bash
apps/CameraBridgeApp/scripts/package-app.sh
```

The packaging script signs the app bundle and bundled `camd` with stable
identifier-based ad-hoc requirements for local testing. That is intended to
avoid the plain cdhash-only identity drift that can make macOS camera
permission checks fall back to `not_determined` after a rebuild. If you granted
camera access to an older locally packaged build before this signing flow was
added, request access once again so TCC can record the newer requirement.

This produces a menu bar app bundle that includes the `camd` executable:

```text
$(swift build --show-bin-path)/CameraBridgeApp.app
```

Launch the packaged app from Finder or with:

```bash
open "$(swift build --show-bin-path)/CameraBridgeApp.app"
```

When the app starts the bundled service, `camd` loads or creates the local bearer token at:

```text
~/Library/Application Support/CameraBridge/auth-token
```

The app then reads that same token file for its protected localhost API requests.

The packaged flow reads runtime configuration from:

```text
~/Library/Application Support/CameraBridge/runtime-configuration.json
```

If no configuration file exists, the app-managed daemon defaults to
`http://127.0.0.1:8731`. The app surfaces the effective connection details in
the menu, including:

```text
Base URL: http://127.0.0.1:8731
Token: ~/Library/Application Support/CameraBridge/auth-token
Log: ~/Library/Application Support/CameraBridge/Logs/camd.log
Captures: ~/Library/Application Support/CameraBridge/Captures/
```

For the supported packaged flow, external apps should rely on the localhost
service and support-path artifacts above at runtime. They should not depend on
hardcoded app-bundle path discovery.

## Manual Verification

Use the packaged app bundle for manual verification:

1. Run `apps/CameraBridgeApp/scripts/package-app.sh`.
2. Launch `CameraBridgeApp.app` from Finder or with `open "$(swift build --show-bin-path)/CameraBridgeApp.app"`.
3. Confirm the menu shows:
   - a clear service status row
   - a clear permission status row
   - a guidance row describing the next onboarding step
   - developer-info rows for base URL, token path, log path, and captures path
4. With permission not yet granted, confirm `Request Camera Access` is enabled even before the service is started.
5. After starting the service, confirm the menu updates to show the managed running state and enables `Stop CameraBridge Service`.
6. Confirm that clicking `Request Camera Access` prompts from `CameraBridgeApp`.
7. After granting permission, confirm the menu reports that CameraBridge is ready.
8. Confirm `Stop CameraBridge Service` returns the menu to the stopped state.
9. Confirm quitting the app stops the managed daemon before exit.
10. If service launch or permission request fails, confirm the last error row appears with readable wording.

Capture screenshots of the refined menu states when practical for PR notes.
