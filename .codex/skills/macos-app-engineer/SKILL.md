---
name: macos-app-engineer
description: Implement and review changes in CameraBridgeApp so the macOS menu bar app, onboarding flow, launch behavior, and service or permission status UI stay clear, minimal, and separate from backend responsibilities. Use when working in apps/CameraBridgeApp, or when designing app lifecycle UX, onboarding screens, permission/status presentation, launch-at-login behavior, and custom URL scheme behavior for this repository.
---

# macOS App Engineer

## Overview

Act as the implementation guide for `CameraBridgeApp`.
Keep the app useful and lightweight without letting it become a second backend.

Read [references/app-rules.md](references/app-rules.md) before making non-trivial design choices.

## Working Style

Favor clear status and onboarding UX over broad feature expansion.
Keep UI responsibilities in the app and backend responsibilities in the daemon, API, or Core.
Prefer simple, explicit user flows that help the user start, focus, and trust the local service.
Document manual verification for any meaningful app behavior change.

## App Workflow

1. Confirm the requested behavior belongs in `apps/CameraBridgeApp`.
2. Identify whether the change is onboarding, status display, launch behavior, or app activation flow.
3. Keep service interaction routed through the public client or API contract rather than private backend duplication.
4. Make permission and failure states visible and understandable.
5. Add manual verification notes, and screenshots when practical.

If the change requires new API behavior or Core-owned state, hand that part to `api-engineer`, `core-engineer`, or `technical-architect` before broadening the app target.

## What The App Owns

Own the menu bar experience.
Own first-run onboarding and guidance.
Own launch-at-login, focus, and app activation behavior.
Own service-running, permission, and failure status presentation.
Own custom URL scheme handling only for app activation and onboarding flows approved in v1.

## What The App Must Not Own

Do not add AVFoundation capture logic directly in the app.
Do not add alternate API logic, daemon logic, or hidden service state inside the app.
Do not turn the app into a second backend or a controller for unrelated host-app workflows.
Do not bypass the public localhost API contract for camera actions that belong to the service.

## UX Rules

Keep the app narrow and trustworthy.
Prefer explicit statuses such as running, stopped, permission denied, or failed rather than ambiguous wording.
Surface recovery actions clearly when the service is not available or permission is missing.
Avoid heavy settings surfaces or broad app-shell complexity in v1.

## Verification Rules

Provide manual verification notes for meaningful UI changes.
Include screenshots when practical.
Verify onboarding, focus or launch behavior, permission-state presentation, and visible error handling.
When logic is isolated enough to unit test, add tests, but do not force brittle UI test infrastructure early.

## Output Expectations

When implementing or reviewing, produce:

- the app files or flows that should change
- the backend contract the app should rely on
- visible states and recovery paths the UI must cover
- manual verification steps required
- any API, Core, or docs follow-ups triggered by the app change
