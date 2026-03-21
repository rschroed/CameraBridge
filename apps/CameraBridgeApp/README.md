# CameraBridgeApp

`CameraBridgeApp` is reserved for the macOS menu bar application, onboarding flow, and service status UI.

The app remains a thin client of the localhost CameraBridge service. Its menu bar shell is limited to:

- service running or stopped visibility
- camera permission visibility
- onboarding guidance for the next user action
- starting the bundled `camd` service
- requesting camera access through the public API
- quitting the app

## Local Packaging

Package a local `.app` bundle with:

```bash
apps/CameraBridgeApp/scripts/package-app.sh
```

This produces a menu bar app bundle that includes the `camd` executable:

```text
$(swift build --show-bin-path)/CameraBridgeApp.app
```

Launch the packaged app from Finder or with:

```bash
open "$(swift build --show-bin-path)/CameraBridgeApp.app"
```

When the app starts the service itself, it persists the local bearer token at:

```text
~/Library/Application Support/CameraBridge/auth-token
```

## Manual Verification

Use the packaged app bundle for manual verification:

1. Run `apps/CameraBridgeApp/scripts/package-app.sh`.
2. Launch `CameraBridgeApp.app` from Finder or with `open "$(swift build --show-bin-path)/CameraBridgeApp.app"`.
3. Confirm the menu shows:
   - a clear service status row
   - a clear permission status row
   - a guidance row describing the next onboarding step
4. With the service stopped, confirm `Start CameraBridge Service` is enabled and permission request is disabled.
5. After starting the service, confirm the menu updates to show the running state.
6. With permission not yet granted, confirm `Request Camera Access` is enabled and the guidance text points the user to that action.
7. After granting permission, confirm the menu reports that CameraBridge is ready.
8. If service launch or permission request fails, confirm the last error row appears with readable wording.

Capture screenshots of the refined menu states when practical for PR notes.
