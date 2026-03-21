---
name: third-party-developer-pov
description: Evaluate CameraBridge features, public APIs, permission flows, and architecture decisions from the perspective of a third-party developer integrating the system into another app. Use when introducing or changing endpoints, reusable library seams, ownership between app/backend/helper processes, system-level interactions, or any behavior that may feel clever internally but confusing externally.
---

# Third-Party Developer POV

## Overview

Act as the external integrator's sanity check.
Keep public behavior understandable, predictable, and honest without requiring repository-specific tribal knowledge.

Use this skill when the question is not only "does this work?" but also "would another developer understand how to use it correctly?"

## Working Style

Start from the interface a third-party developer sees, not the implementation details we already know.
Prefer explicit ownership and explicit failure semantics over convenience hidden behind abstractions.
Treat surprising behavior, overloaded terminology, and setup friction as product flaws even if the code is technically correct.

## Inputs To Gather

Before evaluating, collect the smallest set of context needed:

- the feature or decision being proposed
- the intended integrating developer or host app
- the ownership model across app, backend, and helper or daemon
- the public interface: endpoints, methods, models, state transitions, or user-visible flows
- defaults and configuration knobs
- known failure modes and recovery paths

If any of these are unclear, call that out as part of the evaluation instead of filling gaps with internal assumptions.

## Evaluation Workflow

1. State the mental model a first-time integrator will likely infer from the interface.
2. Compare that expectation with the real ownership, state, and side effects.
3. Identify where setup burden, naming, or defaults make first success harder than necessary.
4. Check whether failures are understandable and whether the next step is obvious.
5. Judge whether the surface feels reusable outside this repository or too tailored to current internals.

## Evaluation Dimensions

Evaluate explicitly across these dimensions:

- mental model
- API honesty
- integration burden
- defaults and configuration
- failure and recovery
- portability and reusability

## Output Expectations

Return a concise, decision-oriented evaluation with these sections:

- `Expected Mental Model`
- `Likely Confusion`
- `Integration Burden`
- `API Honesty`
- `What Feels Clean`
- `What Feels Leaky or Overloaded`
- `Recommendation`

Choose exactly one recommendation:

- `Public-ready`
- `Internal-only for now`
- `Promising but needs cleanup before reuse`

End with 1 to 3 concrete suggestions such as renaming an API, splitting a responsibility, moving behavior to the correct owner, or clarifying docs and constraints.

## Guardrails

Optimize for first-time developer understanding, not internal convenience.
Prefer explicit ownership over hidden behavior.
Treat misleading interfaces as worse than incomplete ones.
Avoid "it works if you already know how it works" reasoning.
Keep the evaluation concise and actionable rather than theoretical.
