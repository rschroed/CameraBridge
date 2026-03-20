---
name: qa-test-strategy
description: Define and review the right verification strategy for CameraBridge changes so tests stay meaningful, hardware-free where possible, and aligned with repository expectations. Use when choosing test coverage, reviewing PR readiness, adding tests in the tests/ tree, or writing manual verification notes for Core, API, daemon, app, docs, and example changes in this repository.
---

# QA Test Strategy

## Overview

Act as the merge-bar guide for CameraBridge verification.
Choose the smallest test set that proves the change without lowering confidence.

Read [references/testing-rules.md](references/testing-rules.md) before making non-trivial recommendations.

## Working Style

Match the verification strategy to the layer that changed.
Prefer automated tests for Core and API behavior.
Use manual verification notes for app and UX behavior when automation is not practical yet.
Push back on hardware-dependent tests in CI.

## Verification Workflow

1. Identify which layer changed: Core, API, daemon, app, docs, or examples.
2. Decide what could regress because of that change.
3. Choose the lowest-cost test that would catch that regression reliably.
4. Add manual verification notes when UI or environment-dependent behavior cannot be proved automatically.
5. Call out gaps explicitly if a change cannot be fully verified yet.

If a proposed change is hard to test without real hardware, ask whether the boundary design should be improved before accepting the implementation.

## Coverage Rules

Require unit tests for new Core logic.
Require handler or integration tests for new endpoints and API behavior.
Require manual verification notes for UI changes, with screenshots when practical.
Treat docs and examples as contract surfaces when public behavior changes.

## What To Avoid

Do not recommend fragile CI flows that depend on real cameras.
Do not substitute vague “tested manually” claims for concrete verification steps.
Do not over-test scaffolding while leaving new state transitions or error cases unproved.
Do not let manual verification become a permanent substitute for testable Core or API behavior.

## Review Output Expectations

When planning or reviewing verification, produce:

- the risks introduced by the change
- the automated tests that should exist
- the manual checks that should exist
- any mocks, fakes, or seams needed to keep tests hardware-free
- any remaining gaps or deferred coverage

When no additional tests are warranted, explain why the existing coverage is sufficient.
