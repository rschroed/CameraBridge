# CameraBridge Testing Rules

Use this file when deciding what evidence is required for a change to merge safely.

## Repository Expectations

Every meaningful change should include one or more of:

- unit tests
- integration tests
- API handler tests
- manual verification notes

Minimum expectations:

- new Core logic -> unit tests
- new endpoint -> handler or integration tests
- UI changes -> manual verification notes and screenshots when practical

## General Principles

Prefer reliable, simple tests over elaborate infrastructure.
Keep CI simple: build and test first, add other steps only when they are stable and justified.
Avoid tests that require real camera hardware.
Use protocol abstractions, mocks, or fakes for AVFoundation-facing behavior.

## Layer-Specific Guidance

### Core

Test:

- state transitions
- invalid preconditions
- error propagation
- interaction with mocked native-facing dependencies

### API

Test:

- request validation
- auth handling
- state preconditions
- success mapping from Core to HTTP response
- failure mapping from Core to HTTP error response

### App

Use manual verification notes for:

- onboarding flow
- permission/status presentation
- launch or focus behavior
- user-visible error handling

When practical, include screenshots and exact reproduction steps.

### Daemon

Verify:

- startup and dependency wiring behavior
- config loading paths
- localhost binding assumptions
- logging for start and failure paths

Use automated tests where the behavior is isolated enough. Use manual verification notes otherwise.

## Good Verification Notes

A good manual verification note states:

- exact environment or precondition
- exact steps taken
- expected result
- actual result

Avoid notes that only say “works” or “smoke tested.”

## Escalation Rule

If a change cannot be verified convincingly without live hardware or a fragile environment, say so explicitly and propose the smallest additional seam or abstraction that would make it testable next time.
