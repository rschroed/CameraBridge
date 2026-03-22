# CameraBridge Compatibility

This document defines the supported external runtime contract for pre-1.0
CameraBridge adopters.

## Product And API Versioning

- CameraBridge product releases start at `v0.x`
- the supported localhost API surface remains `/v1`
- downstream apps should pin to an explicit tested CameraBridge release or a
  narrow tested `v0.x` range
- broad “latest” dependencies are not supported
- official external release artifacts are maintainer-signed and
  maintainer-notarized before publication to GitHub Releases

## Supported Runtime Contract

The supported packaged-flow defaults are:

- endpoint: `http://127.0.0.1:8731`
- health signal: `GET /health` returning `200 OK`
- permission signals:
  - `GET /v1/permissions`
  - `POST /v1/permissions/request`
- auth token path:
  - `~/Library/Application Support/CameraBridge/auth-token`

For this slice, external adopters should rely on those runtime signals and
support-directory artifacts. They should not rely on discovering CameraBridge
by app bundle path, bundle identifier inspection, or direct daemon process
management.

## Availability And Readiness

- CameraBridge is **available** when the localhost service responds at
  `http://127.0.0.1:8731/health`
- CameraBridge is **ready for capture** when the service is available and the
  permission/session preconditions exposed by the published API are satisfied
- if permission is still undecided, downstream apps should expect the guided
  `POST /v1/permissions/request` response and direct the user to
  `CameraBridgeApp`

## Packaged Flow Assumptions

- `CameraBridgeApp` is the supported manager of bundled `camd`
- the service is not guaranteed to be available unless the app is running and
  the user has started the service
- downstream apps must not assume the daemon persists independently of the app
  in the supported packaged flow

## Install Path Policy

`/Applications/CameraBridgeApp.app` is the supported install target for user
guidance, support, and manual verification.

That path is not the downstream runtime compatibility guarantee. Downstream
code should not hardcode the bundle path as a discovery mechanism. If an
integrating app wants to help the user find or launch CameraBridge, it should
do so as a UX convenience rather than as part of the runtime contract.
