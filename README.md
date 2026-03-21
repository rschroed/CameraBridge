# CameraBridge

CameraBridge is a local macOS camera service that exposes AVFoundation over a localhost API.

This repository is intentionally scaffolded with strict package boundaries:

- `apps/camd` for the daemon and CLI entrypoint
- `apps/CameraBridgeApp` for the macOS menu bar app
- `packages/CameraBridgeCore` for camera domain and AVFoundation-facing abstractions
- `packages/CameraBridgeAPI` for localhost API translation and request handling
- `packages/CameraBridgeClientSwift` for a minimal Swift client
- `docs/` for RFCs and API documentation
- `examples/` for small example clients

The repository currently includes early daemon and API slices for health,
permission status and request, device listing and selection, session state,
basic session lifecycle control, and still photo capture with local artifact
metadata, plus a minimal menu bar app shell, with the remaining v1 surface
defined in the docs. Preview transport, example clients, and fuller onboarding
UI are still in progress.

## v1 Auth And Ownership

CameraBridge v1 keeps the trust model intentionally narrow:

- read-only localhost endpoints may remain unauthenticated in the early v1 slices
- planned mutating endpoints use a bearer token or equivalent local secret
- when `camd` starts without `CAMERABRIDGE_AUTH_TOKEN`, it loads or creates the local bearer token at `~/Library/Application Support/CameraBridge/auth-token`
- v1 does not add separate session `claim` or `release` endpoints
- successful `POST /v1/session/start` establishes implicit session ownership
- session ownership is released by `POST /v1/session/stop` or when the session ends
- ownership-conflict and invalid-state failures are explicit parts of the planned contract

## Docs

- [Quick Start](docs/quick-start.md)
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

Package the local menu bar app bundle with:

```bash
apps/CameraBridgeApp/scripts/package-app.sh
```

The packaged app bundle, including the bundled `camd` executable, is written to:

```text
$(swift build --show-bin-path)/CameraBridgeApp.app
```

## First Capture

Follow the full setup and first-capture path in [docs/quick-start.md](docs/quick-start.md).

The shortest successful path is:

1. package and launch `CameraBridgeApp.app`
2. click `Start Service`
3. confirm `Permission: authorized`
4. run the minimal Python example with a real device id from `GET /v1/devices`

```bash
python3 examples/python/capture_photo.py --device-id "YOUR_DEVICE_ID"
```

The example reads the bearer token from:

```text
~/Library/Application Support/CameraBridge/auth-token
```

and writes captures under:

```text
~/Library/Application Support/CameraBridge/Captures/
```
