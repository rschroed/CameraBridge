# CameraBridge Skills

This directory contains repo-local skills for recurring CameraBridge work. The individual `SKILL.md` files are the detailed instructions. This index is the quick guide for humans deciding which skill to reach for first.

## Current skills

- [camerabridge-pm](./camerabridge-pm/SKILL.md): Use for scope framing, PRD or roadmap shaping, issue or PR breakdowns, acceptance criteria, and honest PR packaging.
- [technical-architect](./technical-architect/SKILL.md): Use for package placement, boundary decisions, explicit state ownership, v1 scope guardrails, and architecture ambiguity.
- [third-party-developer-pov](./third-party-developer-pov/SKILL.md): Use for evaluating public APIs, permission flows, helper or daemon ownership, and reusable seams from the perspective of an external integrator.
- [core-engineer](./core-engineer/SKILL.md): Use for `CameraBridgeCore` models, state machines, permission and device logic, AVFoundation isolation, and hardware-free Core tests.
- [api-engineer](./api-engineer/SKILL.md): Use for `CameraBridgeAPI` routes, request and response models, auth checks, error handling, and handler or integration tests.
- [qa-test-strategy](./qa-test-strategy/SKILL.md): Use for choosing the right automated tests, manual verification notes, and merge-bar evidence for a change.
- [macos-app-engineer](./macos-app-engineer/SKILL.md): Use for `CameraBridgeApp` onboarding, menu bar UX, launch and focus behavior, and permission or service status UI.
- [docs-dx](./docs-dx/SKILL.md): Use for `README.md`, `docs/`, API references, install guidance, and examples when the public contract or setup changes.

## Recommended order

Use this order when a task touches multiple concerns:

1. [camerabridge-pm](./camerabridge-pm/SKILL.md) for scope and slice definition.
2. [technical-architect](./technical-architect/SKILL.md) for placement and boundary decisions.
3. [third-party-developer-pov](./third-party-developer-pov/SKILL.md) when the slice changes public semantics or may be reused outside this repo.
4. The implementation skill for the owning layer:
   [core-engineer](./core-engineer/SKILL.md),
   [api-engineer](./api-engineer/SKILL.md), or
   [macos-app-engineer](./macos-app-engineer/SKILL.md).
5. [qa-test-strategy](./qa-test-strategy/SKILL.md) to set verification expectations.
6. [docs-dx](./docs-dx/SKILL.md) if public behavior, setup, or examples changed.

## Handoff rules

- If the question is “should we build this now, and how small can the slice be?”, start with [camerabridge-pm](./camerabridge-pm/SKILL.md).
- If the question is “where should this logic live?”, start with [technical-architect](./technical-architect/SKILL.md).
- If the question is “would an external developer understand and trust this interface?”, use [third-party-developer-pov](./third-party-developer-pov/SKILL.md).
- If the question is “how do we implement this inside the owning layer?”, use the matching engineer skill.
- If the question is “what evidence is enough to merge this safely?”, use [qa-test-strategy](./qa-test-strategy/SKILL.md).
- If the question is “what docs or examples must change?”, use [docs-dx](./docs-dx/SKILL.md).

## Conventions

- Keep repo-local workflow assets under `skills/`.
- Keep each skill narrow and non-overlapping.
- When a skill cannot answer a question cleanly because ownership is ambiguous, defer to [technical-architect](./technical-architect/SKILL.md).
