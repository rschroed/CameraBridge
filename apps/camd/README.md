# camd

`camd` hosts process startup, configuration bootstrap, dependency wiring, and logging for the local CameraBridge service.

In the packaged flow, `camd` reads runtime configuration from:

```text
~/Library/Application Support/CameraBridge/runtime-configuration.json
```

If no configuration file exists, the daemon defaults to `127.0.0.1:8731`.
Direct developer startup can still override host and port with
`CAMERABRIDGE_HOST` and `CAMERABRIDGE_PORT`.

When `camd` starts without `CAMERABRIDGE_AUTH_TOKEN`, it loads or creates the local bearer token at:

```text
~/Library/Application Support/CameraBridge/auth-token
```

This is the default local token contract used by both direct daemon startup and the packaged app launcher.

On successful startup, `camd` also writes runtime metadata for the packaged app
under:

```text
~/Library/Application Support/CameraBridge/runtime-info.json
```
