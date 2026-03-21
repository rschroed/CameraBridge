# camd

`camd` hosts process startup, configuration bootstrap, dependency wiring, and logging for the local CameraBridge service.

When `camd` starts without `CAMERABRIDGE_AUTH_TOKEN`, it loads or creates the local bearer token at:

```text
~/Library/Application Support/CameraBridge/auth-token
```

This is the default local token contract used by both direct daemon startup and the packaged app launcher.
