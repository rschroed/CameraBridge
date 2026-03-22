# CameraBridge

CameraBridge is a local macOS camera service with a small, versioned localhost API for camera permissions, device discovery, session control, and still image capture.

This repository is organized with strict package boundaries:

- `apps/camd` for the daemon and CLI entrypoint
- `apps/CameraBridgeApp` for the macOS menu bar app
- `packages/CameraBridgeCore` for camera domain and AVFoundation-facing abstractions
- `packages/CameraBridgeAPI` for localhost API translation and request handling
- `packages/CameraBridgeClientSwift` for a minimal Swift client
- `docs/` for RFCs and API documentation
- `examples/` for small example clients

The repository currently ships a narrow v1 first-capture loop: health,
permission status and request, device listing and selection, session state,
session lifecycle control, and still photo capture with local artifact
metadata. It also includes the minimal menu bar app shell, the Python
first-capture example, and the core v1 docs needed to run that flow end to end.
Preview transport and broader client surfaces remain deferred until after v1.

CameraBridge product releases start at `v0.x`. The supported localhost API
surface remains `/v1`.

In the shipped v1 permission flow, `CameraBridgeApp` owns the macOS camera
permission prompt. `camd` reads live AVFoundation permission status directly
for `/v1/permissions`, `/v1/permissions/request`, and the session-start
permission precondition.

## Packaged Flow

The packaged `CameraBridgeApp.app` bundle is the canonical pre-launch v1
onboarding path.

- `CameraBridgeApp` is the supported manager for the bundled `camd`
- `Start CameraBridge Service` launches the bundled daemon if the configured
  local endpoint is not already healthy
- `Stop CameraBridge Service` stops only the daemon instance launched and
  managed by the app
- `Quit CameraBridge` stops the managed daemon before the app exits
- if another healthy local CameraBridge service is already running, the app
  shows `Running (External)` and does not kill that service
- the app surfaces the current base URL plus the token, log, and captures paths
  needed by local integrators

The packaged flow reads runtime configuration from:

```text
~/Library/Application Support/CameraBridge/runtime-configuration.json
```

If no configuration file exists, CameraBridge defaults to:

```json
{
  "host": "127.0.0.1",
  "port": 8731
}
```

At runtime, the app surfaces the effective base URL and the default support
paths:

- token: `~/Library/Application Support/CameraBridge/auth-token`
- log: `~/Library/Application Support/CameraBridge/Logs/camd.log`
- captures: `~/Library/Application Support/CameraBridge/Captures/`

## v1 Auth And Ownership

CameraBridge v1 keeps the trust model intentionally narrow:

- read-only localhost endpoints may remain unauthenticated in the early v1 slices
- mutating endpoints use a bearer token or equivalent local secret
- when `camd` starts without `CAMERABRIDGE_AUTH_TOKEN`, it loads or creates the local bearer token at `~/Library/Application Support/CameraBridge/auth-token`
- `CameraBridgeApp` performs permission prompting when access is still `not_determined`
- `POST /v1/permissions/request` does not prompt from `camd`; it remains the token-protected programmatic permission-check route and always returns `200 OK` with current daemon-visible state plus guided next-step data when the app must request access
- v1 does not add separate session `claim` or `release` endpoints
- successful `POST /v1/session/start` establishes implicit session ownership
- session ownership is released by `POST /v1/session/stop` or when the session ends
- ownership-conflict and invalid-state failures are explicit parts of the current contract

## Docs

- The documents below describe the shipped first-capture v1 slice and the
  deferred work that remains outside that slice.
- [Install Guide](docs/install.md)
- [Compatibility](docs/compatibility.md)
- [Release Process](docs/release-process.md)
- [Quick Start](docs/quick-start.md)
- [Release Readiness](docs/release-readiness.md)
- [Architecture Overview](docs/architecture-overview.md)
- [v1 Roadmap](docs/roadmap/v1.md)
- [API v1 Contract](docs/api/v1.md)
- [Engineering Workflow](docs/workflow.md)

## Marketing Site

- Source lives in `site/`
- GitHub Pages deploys the static files from `site/` via `.github/workflows/github-pages.yml`
- Update page copy in `site/index.html` and styling in `site/styles.css`
- Default Pages URL: `https://rschroed.github.io/CameraBridge/`

## Build

```bash
swift build
swift test
```

## External Install

The supported external install flow uses signed GitHub Release artifacts, not a
source checkout. Download the current `CameraBridgeApp-v0.x.y-macos.zip`,
verify the checksum, move `CameraBridgeApp.app` to `/Applications`, and launch
the app from there.

Use these docs as the source of truth for external adopters:

- [Install Guide](docs/install.md)
- [Compatibility](docs/compatibility.md)

`/Applications/CameraBridgeApp.app` is the supported user install target for
the packaged flow. It is not the downstream runtime-discovery contract.
External apps should rely on the localhost service and documented support-path
artifacts at runtime.

Package the local menu bar app bundle with:

```bash
apps/CameraBridgeApp/scripts/package-app.sh
```

The local packaging script signs `CameraBridgeApp.app` and its bundled `camd`
with stable identifier-based ad-hoc requirements so local TCC permission checks
can survive rebuilds more predictably than plain cdhash-only ad-hoc signing.
If your machine previously granted camera access to an older packaged build,
re-request permission once after adopting the newer packaging flow so macOS can
record the updated local code requirement.

For published external releases, use the official maintainer-signed and
maintainer-notarized GitHub Release artifact path instead of this local
contributor packaging flow.

The packaged app bundle, including the bundled `camd` executable, is written to:

```text
$(swift build --show-bin-path)/CameraBridgeApp.app
```

## First Capture

Follow the full setup and first-capture path in [docs/quick-start.md](docs/quick-start.md).

The shortest successful path is:

1. package and launch `CameraBridgeApp.app`
2. click `Start CameraBridge Service`
3. click `Request Camera Access` if permission is not already authorized
4. confirm `Permission: Authorized`
5. use the base URL and token path shown in the app if you are integrating from another local client
6. run the minimal Python example with a real device id from `GET /v1/devices`

The app shows the effective connection details in its menu. In the default
packaged flow, those values are:

```text
Base URL: http://127.0.0.1:8731
Token: ~/Library/Application Support/CameraBridge/auth-token
Log: ~/Library/Application Support/CameraBridge/Logs/camd.log
Captures: ~/Library/Application Support/CameraBridge/Captures/
```

```bash
python3 examples/python/capture_photo.py --device-id "YOUR_DEVICE_ID"
```

By default the example reads the bearer token from:

```text
~/Library/Application Support/CameraBridge/auth-token
```

and writes captures under:

```text
~/Library/Application Support/CameraBridge/Captures/
```

If you stop the managed service from the app or quit the app, that managed
daemon shuts down before exit. If the app detects an already-running external
daemon, it leaves that process running.

## License

CameraBridge is licensed under the MIT License. See [LICENSE](LICENSE).
