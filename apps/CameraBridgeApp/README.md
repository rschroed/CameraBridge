# CameraBridgeApp

`CameraBridgeApp` is reserved for the macOS menu bar application, onboarding flow, and service status UI.

The app remains a thin client of the localhost CameraBridge service. Its menu bar shell is limited to:

- service running or stopped visibility
- camera permission visibility
- onboarding guidance for the next user action
- starting the bundled `camd` service
- requesting camera access directly from the app process
- quitting the app

`CameraBridgeApp` is the only supported camera-permission prompt initiator in v1.
It reads and requests camera access through the app bundle, then syncs the
observed permission state to:

```text
~/Library/Application Support/CameraBridge/permission-state
```

The bundled daemon reads that stored permission state for `/v1/permissions`,
`/v1/permissions/request`, and session-start preconditions.

## Local Packaging

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

## Manual Verification

Use the packaged app bundle for manual verification:

1. Run `apps/CameraBridgeApp/scripts/package-app.sh`.
2. Launch `CameraBridgeApp.app` from Finder or with `open "$(swift build --show-bin-path)/CameraBridgeApp.app"`.
3. Confirm the menu shows:
   - a clear service status row
   - a clear permission status row
   - a guidance row describing the next onboarding step
4. With permission not yet granted, confirm `Request Camera Access` is enabled even before the service is started.
5. After starting the service, confirm the menu updates to show the running state.
6. Confirm that clicking `Request Camera Access` prompts from `CameraBridgeApp`.
7. After granting permission, confirm the menu reports that CameraBridge is ready and `~/Library/Application Support/CameraBridge/permission-state` contains `authorized`.
8. If service launch or permission request fails, confirm the last error row appears with readable wording.

Capture screenshots of the refined menu states when practical for PR notes.
