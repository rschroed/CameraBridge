# CameraBridgeApp

`CameraBridgeApp` is reserved for the macOS menu bar application, onboarding flow, and service status UI.

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
