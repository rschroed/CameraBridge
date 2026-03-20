# CameraBridgeApp Rules

Use this file when working on `apps/CameraBridgeApp`.

## App Mission

`CameraBridgeApp` exists for:

- menu bar UI
- first-run onboarding
- launch-at-login
- status and error visibility

It does not exist to replace the daemon or API.

## v1 App Scope

The minimal app shell in v1 includes:

- menu bar app
- first-run onboarding
- permission status visibility
- basic service status, such as running or stopped
- custom URL scheme support for activation and onboarding only

Approved URL scheme examples in v1:

- `camerabridge://open`
- `camerabridge://request-permissions`

## Boundary Rules

The app may:

- show onboarding and service state
- request that the user open or start the service
- display permission or failure status

The app must not:

- become a second backend
- duplicate API logic
- own capture logic outside the public API

## UX Guidance

Prefer short, explicit states and actions.
Help the user answer:

- Is the service running?
- Does CameraBridge have camera permission?
- What should I do next?

Do not hide failure states behind generic labels.
Do not expand the app into a broad preferences surface unless the user explicitly changes scope.

## Verification Guidance

For app changes, provide manual verification notes covering:

- app launch or focus behavior
- onboarding flow
- status display updates
- permission prompts or permission status messaging
- error and recovery messaging

When practical, attach screenshots and mention the exact environment or preconditions used.
