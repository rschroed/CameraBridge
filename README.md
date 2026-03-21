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
metadata, plus a minimal menu bar app shell. Preview transport, example clients,
and fuller onboarding UI are still in progress.

## v1 Auth And Ownership

CameraBridge v1 keeps the trust model intentionally narrow:

- read-only localhost endpoints may remain unauthenticated in the early v1 slices
- planned mutating endpoints use a bearer token or equivalent local secret
- v1 does not add separate session `claim` or `release` endpoints
- successful `POST /v1/session/start` establishes implicit session ownership
- session ownership is released by `POST /v1/session/stop` or when the session ends
- ownership-conflict and invalid-state failures are explicit parts of the planned contract

## Docs

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

The packaged app bundle is written to:

```text
$(swift build --show-bin-path)/CameraBridgeApp.app
```
