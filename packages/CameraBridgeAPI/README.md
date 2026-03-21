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
