# CameraBridgeCore

`CameraBridgeCore` owns the camera-facing domain model for CameraBridge:

- permission status and permission requests
- device discovery and selection
- session lifecycle state
- still capture coordination
- artifact storage metadata

It does not know about HTTP, app UI, or site/docs tooling.
