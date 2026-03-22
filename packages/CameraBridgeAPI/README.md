# CameraBridgeAPI

`CameraBridgeAPI` translates localhost HTTP requests into Core operations and
serializes responses without owning camera state.

The current v1 surface includes:

- `GET /health`
- `GET /v1/permissions`
- `POST /v1/permissions/request`
- `GET /v1/devices`
- `GET /v1/session`
- `POST /v1/session/start`
- `POST /v1/session/stop`
- `POST /v1/session/select-device`
- `POST /v1/capture/photo`

`POST /v1/permissions/request` does not invoke the macOS permission prompt from
the daemon. It returns the live daemon-visible permission state and directs
callers to `CameraBridgeApp` when permission is still undecided. The route
remains in the API as the stable token-protected programmatic permission-check
endpoint for local clients.
