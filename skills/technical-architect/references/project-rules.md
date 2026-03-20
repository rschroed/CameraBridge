# CameraBridge Project Rules

Use this file as the repository-specific source of truth for architectural recommendations.

## Product Boundary

CameraBridge owns:

- camera permissions
- device discovery
- session lifecycle
- preview streaming
- still image capture
- minimal runtime metadata and config

CameraBridge does not own:

- host app lifecycle outside the local camera service contract
- plotters or any non-camera hardware
- browser permission bypasses
- remote access
- cloud sync
- complex media editing or transcoding
- arbitrary host-app domain state

## Package Responsibilities

`packages/CameraBridgeCore`

- Own AVFoundation integration, permission management, device discovery, session state, and capture pipeline.
- Do not put HTTP, menu bar UI, or website/docs tooling logic here.

`packages/CameraBridgeAPI`

- Translate HTTP requests into Core calls, validate auth and request shape, and serialize responses.
- Do not put AVFoundation logic, parallel state machines, or UI behavior here.

`apps/camd`

- Own config/bootstrap, server start, dependency wiring, CLI behavior, and logs.
- Do not duplicate Core or API business logic here.

`apps/CameraBridgeApp`

- Own onboarding, launch/focus UX, and service or permission status visibility.
- Do not make this target a second backend.

## API Rules

- Keep public endpoints under `/v1/...` except `/health`.
- Prefer explicit machine-readable state over inferred behavior.
- Return clear error codes and error bodies.
- Avoid hidden side effects.
- For new mutating endpoints, define auth requirements, ownership requirements, state preconditions, and expected errors.

## State Rules

Keep camera state explicit and centralized in Core.
At minimum, model permission state, active device, session state, preview state, last error, and current owner if ownership exists.
Do not scatter state across API handlers, UI objects, and core objects.

## v1 Scope Guardrails

Allowed in v1:

- health endpoint
- permission status and request
- device discovery
- session claim or release if ownership is implemented simply
- session start and stop
- device selection
- preview start and stop
- one preview transport
- still photo capture
- local artifact metadata

Deferred until after v1 unless the user explicitly changes scope:

- recording
- advanced per-device tuning
- WebSocket preview if MJPEG already works
- file-serving endpoints if direct file paths are sufficient
- multi-client arbitration beyond simple ownership conflicts

## Security and Runtime Assumptions

- Bind to `127.0.0.1` only.
- Require a bearer token or equivalent local secret for protected endpoints.
- Do not log secrets or bearer tokens.
- Assume a single-user local machine, but do not overclaim security properties.

## Testing and Docs Expectations

- New Core logic needs unit tests.
- New endpoints need handler or integration tests.
- UI changes need manual verification notes and screenshots when practical.
- Avoid CI tests that require real hardware.
- Update `README.md`, relevant docs, and examples when the public contract changes.
