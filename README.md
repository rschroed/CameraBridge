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

The initial scaffold does not include camera, API, or UI implementation yet.

## Docs

- [Architecture Overview](docs/architecture-overview.md)
- [v1 Roadmap](docs/roadmap/v1.md)

## Build

```bash
swift build
swift test
```
