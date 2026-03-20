# AGENTS.md

## Project Overview

CameraBridge is a local macOS camera service that exposes AVFoundation over a localhost API.

Primary goals:
- provide native macOS camera access to local apps without embedding AVFoundation code
- centralize macOS camera permission handling in a trusted local process
- expose a small, stable, versioned localhost API
- keep the architecture narrow, predictable, and easy to extend carefully

Primary deliverables:
- `camd`: local daemon / CLI entrypoint
- `CameraBridgeApp`: menu bar app for onboarding, status, and lifecycle
- localhost API for health, permissions, devices, session control, preview, and still capture
- docs, examples, and a simple public site

## Product Boundary

CameraBridge owns:
- camera permissions
- device discovery
- session lifecycle
- preview streaming
- still image capture
- minimal runtime metadata and config

CameraBridge does NOT own:
- host app lifecycle
- plotters or any non-camera hardware
- browser permission bypasses
- remote access
- cloud sync
- complex media editing or transcoding
- arbitrary host-app domain state

## Non-Goals

Do not introduce:
- microphone support
- virtual camera support
- remote/network camera control
- multi-user support
- multi-session concurrent camera ownership
- host app orchestration
- plugin systems in v1
- cross-platform abstractions in v1

## Architecture

Top-level structure:

- `apps/camd`
  - CLI entrypoint
  - process startup
  - config/bootstrap
  - wiring Core + API
  - logging

- `apps/CameraBridgeApp`
  - menu bar app
  - first-run onboarding
  - launch-at-login
  - status and error visibility

- `packages/CameraBridgeCore`
  - AVFoundation integration
  - permission manager
  - device discovery
  - session state machine
  - capture pipeline
  - core domain models

- `packages/CameraBridgeAPI`
  - HTTP routing
  - auth token validation
  - request/response models
  - endpoint handlers
  - preview transport

- `packages/CameraBridgeClientSwift`
  - tiny Swift client for internal app use and examples

- `examples/`
  - minimal JS, Python, and Swift clients

- `docs/`
  - RFCs
  - API docs
  - integration guides
  - roadmap

## Responsibility Rules

Keep responsibilities strict.

### `CameraBridgeCore`
May:
- talk to AVFoundation
- define device/session/permission models
- own state transitions
- expose testable abstractions

Must not:
- know about HTTP
- know about menu bar UI
- know about website/docs tooling

### `CameraBridgeAPI`
May:
- translate HTTP requests into Core calls
- validate auth and request shape
- serialize responses

Must not:
- contain AVFoundation logic
- invent state separate from Core
- directly manipulate app UI

### `camd`
May:
- load config
- start server
- wire dependencies
- expose CLI commands
- emit logs

Must not:
- duplicate Core business logic
- contain HTTP handler logic beyond bootstrapping
- own macOS onboarding UX

### `CameraBridgeApp`
May:
- show onboarding and service state
- request the user open/start the service
- display permission or failure status

Must not:
- become a second backend
- duplicate API logic
- own capture logic outside the public API

## API Rules

- All public endpoints must live under `/v1/...` except `/health`
- Prefer explicit machine-readable state over inferred behavior
- Return clear error codes and error bodies
- Avoid hidden side effects
- Any new mutating endpoint must define:
  - auth requirements
  - ownership requirements
  - state preconditions
  - expected error cases

## State Rules

Camera state must be explicit and centralized.

At minimum, model:
- permission state
- active device
- session state
- preview state
- last error
- current owner, if ownership is implemented

Do not scatter state across API handlers, UI, and core objects.

Use a clear state machine where possible.

## v1 Scope Guardrails

Allowed in v1:
- health endpoint
- permission status/request
- device discovery
- session claim/release
- session start/stop
- device selection
- preview start/stop
- one preview transport
- still photo capture
- local artifact metadata

Deferred until after v1 unless explicitly approved:
- recording
- advanced per-device tuning
- WebSocket preview if MJPEG already works
- file-serving endpoints if direct file paths are enough
- multi-client arbitration beyond simple ownership conflicts

## Testing Expectations

Every meaningful change should include one or more of:
- unit tests
- integration tests
- API handler tests
- manual verification notes

Minimum expectations:
- new Core logic -> unit tests
- new endpoint -> handler/integration tests
- UI changes -> manual verification notes and screenshots when practical

Avoid tests that require real hardware in CI.
Use protocol abstractions and mocks for AVFoundation-facing code.

## CI Expectations

Keep CI simple and reliable.
Prefer:
- build
- test
- lint/format if adopted

Do not add fragile CI dependencies early.

## Logging

Use structured, readable logs.
Logs should help answer:
- did the service start
- what port is bound
- permission state
- what device was selected
- why a request failed

Do not log secrets or bearer tokens.

## Config

Default config should live in standard macOS locations.

Preferred locations:
- app support: `~/Library/Application Support/CameraBridge/`
- logs: standard macOS app log locations or console
- token/config files in app support, not repo-local temp files

Never hardcode user-specific absolute paths.

## Security / Trust Model

Assume:
- localhost-only
- single-user machine
- host apps are generally trusted local software

Still require:
- bearer token or equivalent local secret for protected endpoints
- 127.0.0.1 binding only
- explicit ownership checks for mutating camera actions if ownership is implemented

Do not overclaim security properties in docs or code comments.

## Documentation Rules

Update docs when:
- public API changes
- setup/build steps change
- config path behavior changes
- roadmap/scope changes materially

At minimum, keep these current:
- `README.md`
- relevant `docs/api/*`
- relevant guide pages
- examples if the API contract changes

## Git Workflow

- `main` must remain releasable
- one issue per branch
- one branch per focused slice
- small PRs preferred

Recommended branch naming:
- `codex/health-endpoint`
- `codex/permissions-status`
- `codex/device-enumeration`

## Pull Request Rules

Each PR should include:
- summary
- files changed
- how it was tested
- what was intentionally deferred

Do not mix unrelated concerns in one PR.

## Codex / Agent Instructions

When implementing a task:
1. restate the scope
2. list files you plan to change
3. avoid touching unrelated files
4. implement the smallest complete slice
5. add/update tests
6. update docs if public behavior changes
7. report any follow-up issues explicitly

If the requested task conflicts with AGENTS.md:
- preserve the project boundary
- choose the narrower implementation
- note the conflict in the PR summary

## Definition of Done

A task is done when:
- acceptance criteria are met
- tests pass or manual verification is documented
- docs are updated if needed
- no unrelated architecture drift was introduced
- the change can merge safely into `main`
