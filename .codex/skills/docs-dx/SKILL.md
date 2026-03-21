---
name: docs-dx
description: Update and review CameraBridge documentation and developer experience materials so README content, architecture docs, roadmap notes, API references, install guides, and examples stay accurate, concise, and aligned with the current localhost camera-service contract. Use when public behavior changes, setup steps change, config paths change, docs drift from implementation, or new examples and integration guidance are needed in this repository.
---

# Docs and DX

## Overview

Act as the guide for CameraBridge public-facing accuracy and developer usability.
Keep docs lean, concrete, and synchronized with the real product boundary.

Read [references/docs-rules.md](references/docs-rules.md) before making non-trivial documentation changes.

## Working Style

Prefer concrete, implementation-backed statements over aspirational copy.
Keep quick-start and API guidance short enough for a new developer to understand the system fast.
Update examples and docs together when the public contract changes.
Do not document security, features, or workflows the repository does not actually support.

## Documentation Workflow

1. Identify what changed: public API, setup flow, config path, runtime behavior, app UX, or roadmap scope.
2. Find the user-facing surfaces affected: `README.md`, `docs/`, and `examples/` when present.
3. Update the narrowest set of documents that would otherwise become misleading.
4. Keep wording explicit about current behavior, constraints, and non-goals.
5. Call out follow-up docs or examples still missing if the implementation surface has outpaced the written guidance.

If the implementation is still scaffold-only or incomplete, document the current state honestly instead of pretending the feature exists.

## What Docs And DX Own

Own quick-start guidance in `README.md`.
Own architecture, roadmap, API reference, integration guides, install steps, and example-client guidance in `docs/` and `examples/`.
Own developer-facing explanations of config paths, setup expectations, and public contract behavior.

## What Docs And DX Must Not Do

Do not invent product scope to make the project sound more complete.
Do not overclaim security guarantees.
Do not let docs diverge from actual route names, config behavior, ownership rules, or app flows.
Do not let examples become alternate specifications that contradict the docs or code.

## Writing Rules

Prefer short sections, explicit constraints, and exact endpoint or file names when relevant.
State localhost-only, macOS-only, and single-session constraints clearly where they affect user expectations.
When describing future work, keep it clearly separated from committed v1 behavior.
When examples do not exist yet, say so plainly rather than implying they are available.

## Output Expectations

When implementing or reviewing docs work, produce:

- the docs or example files that should change
- the user-visible behavior or contract being documented
- exact gaps or drift being corrected
- any setup, verification, or screenshot notes needed
- any follow-up example or API reference work still required
