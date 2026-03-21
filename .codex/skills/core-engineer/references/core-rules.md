# CameraBridgeCore Rules

Use this file when working on domain behavior inside `packages/CameraBridgeCore`.

## Core Mission

`CameraBridgeCore` owns camera permissions, device discovery, session lifecycle, capture coordination, and Core domain models.
It is the source of truth for camera state.

## Preferred Shapes

Prefer small domain types with names that match the camera problem space.
Prefer explicit enums or state objects for permission state, session state, preview state, and capture outcomes.
Prefer protocols around AVFoundation-facing services so tests can substitute fakes.
Prefer narrow methods that express one transition or query clearly.

## Anti-Patterns

Do not let HTTP concepts leak into Core APIs.
Do not hide state changes behind unrelated method calls.
Do not spread ownership across multiple singleton-style managers when one state owner would be clearer.
Do not make tests depend on macOS camera hardware.
Do not add abstractions only to make future cross-platform work easier; that is outside v1 scope.

## Modeling Guidance

When behavior changes camera runtime state, ask:

1. What exact state changes?
2. Who owns that state today?
3. Should the change be represented as a new enum case, property, or transition result?
4. What errors or invalid preconditions need to be modeled explicitly?

If the answer is unclear, simplify the state model before adding more entry points.

## AVFoundation Boundary Guidance

Keep AVFoundation interaction behind Core-owned abstractions.
Translate framework-specific details into repository domain models as close to the integration boundary as practical.
Do not force downstream packages to reason about AVFoundation concepts unless they are truly part of the public domain contract.

## Testing Guidance

Every meaningful Core change should come with tests for:

- expected state transitions
- invalid preconditions
- error propagation
- mock or fake interaction with native-facing dependencies

If a change introduces behavior that is hard to test without hardware, revisit the boundary design before accepting it.
