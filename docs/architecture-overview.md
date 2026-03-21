# CameraBridge Architecture Overview

## 1. Purpose

CameraBridge is a local macOS camera service that exposes AVFoundation over a localhost API.

It exists to separate:
- native camera complexity
- from application-level logic

This allows local apps (desktop apps, local web apps, scripts) to use the camera without embedding native macOS code.

---

## 2. System Position

CameraBridge sits between:

`[ Local App ]  <->  [ CameraBridge (camd) ]  <->  [ AVFoundation / macOS ]`

- Apps talk HTTP
- CameraBridge owns all native camera interaction
- The OS enforces permissions

CameraBridge is:
- local-only
- single-user
- not a cloud service
- not a remote API

---

## 3. Core Responsibilities

CameraBridge owns:

- camera permission state and requests
- device discovery
- capture session lifecycle
- still image capture
- minimal runtime state

CameraBridge does NOT own:

- application state
- UI beyond minimal onboarding
- non-camera hardware
- remote access
- media processing pipelines

---

## 4. Core Concepts

### Camera State

A single, centralized representation of:

- permission state
- session state
- preview state reserved for future preview work
- active device
- last error

This state lives in `CameraBridgeCore` and is the source of truth.
Permission reads, permission requests, and permission-dependent session
preconditions must all flow through this Core-owned state path.
The shipped v1 surface does not expose preview transport or preview endpoints.

---

### Session

Represents the lifecycle of camera usage.

In v1:
- only one active session
- no multi-client arbitration beyond basic ownership

---

### Device

A normalized representation of a camera device.

Includes:
- identifier
- name
- position (front/back/external)

---

### Permission

Explicit model of macOS camera permission state.

Must never be inferred implicitly.

---

## 5. Architecture Layers

### Core (`CameraBridgeCore`)

- AVFoundation integration
- domain models
- state management
- permission status and request coordination

No HTTP, no UI.

---

### API (`CameraBridgeAPI`)

- HTTP interface
- request/response models
- auth validation
- translation of HTTP permission routes into Core-owned permission operations

No AVFoundation logic and no parallel permission state.

---

### Daemon (`camd`)

- process entrypoint
- config + bootstrap
- dependency wiring

No domain logic.

---

### App (`CameraBridgeApp`)

- menu bar UI
- onboarding
- status display
- app-owned camera permission prompting
- permission-state sync to Application Support

No backend logic.

---

## 6. API Design Principles

- versioned under `/v1/...`
- explicit state over implicit behavior
- clear error responses
- no hidden side effects
- localhost-only

---

## 7. Constraints

- macOS only (v1)
- localhost only
- one active camera session
- no remote access
- no cross-platform abstraction
- no plugin system (v1)

---

## 8. Non-Goals

CameraBridge will not:

- act as a virtual camera
- bypass browser permissions
- stream video remotely
- expose preview transport in the shipped v1 surface
- manage application workflows
- support multiple concurrent sessions (v1)

---

## 9. Evolution Strategy

CameraBridge should evolve by:

1. stabilizing the API contract
2. adding capabilities incrementally
3. avoiding expansion of responsibility

New features must:
- fit within the camera service boundary
- not introduce cross-domain complexity

---

## 10. Guiding Principle

CameraBridge should feel like:

> a missing system component on macOS

Not:
- a full application
- a backend platform
- a general-purpose media system
