# CameraBridgeAPI Rules

Use this file when working on HTTP behavior inside `packages/CameraBridgeAPI`.

## API Mission

`CameraBridgeAPI` translates localhost HTTP requests into Core operations and serializes results.
It does not own camera state.

## Route and Contract Rules

- Keep public endpoints under `/v1/...` except `/health`.
- Use explicit, machine-readable request and response shapes.
- Make error cases visible in structured responses.
- Avoid hidden side effects.

For a new mutating endpoint, define:

- auth requirements
- ownership requirements
- state preconditions
- expected error cases

## Boundary Rules

Keep AVFoundation logic out of the API layer.
Do not add alternate state tracking that diverges from Core.
Do not let the API layer become the source of truth for permission state, device state, or session state.
Keep the layer focused on translation, validation, auth, and serialization.

## Security Assumptions

Assume:

- localhost-only service
- single-user machine
- generally trusted local clients

Still require:

- bearer token or equivalent local secret for protected endpoints
- binding to `127.0.0.1`
- explicit ownership checks for mutating camera actions if ownership exists

Do not overclaim security properties in docs or code comments.

## Modeling Guidance

When adding an endpoint, ask:

1. Is this a new API surface or can an existing endpoint express it cleanly?
2. What Core method or state query should it call?
3. What are the valid and invalid preconditions?
4. What exact status code and body should clients receive for each outcome?

If the answer depends on new domain state, define that in Core first.

## Testing Guidance

Every meaningful API change should include tests for:

- request validation
- auth handling
- Core success mapping
- Core failure mapping
- invalid state or ownership conflicts

If tests become hard to write without real hardware, the Core/API boundary is probably too leaky.
