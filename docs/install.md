# CameraBridge Install Guide

This guide describes the supported external installation flow for CameraBridge
as a standalone macOS dependency.

## Supported Install Flow

The supported external install target is:

```text
/Applications/CameraBridgeApp.app
```

That path is a support and documentation convention for the packaged flow. It
is not the downstream runtime-discovery contract. External apps should rely on
the localhost service and documented support-directory artifacts at runtime, not
on finding or inspecting the app bundle path.

## Install

1. Download the current official maintainer-signed and maintainer-notarized
   release assets from GitHub Releases:
   - `CameraBridgeApp-v0.x.y-macos.zip`
   - `CameraBridgeApp-v0.x.y-macos.zip.sha256`
2. Verify the checksum before installation:

```bash
shasum -a 256 CameraBridgeApp-v0.x.y-macos.zip
cat CameraBridgeApp-v0.x.y-macos.zip.sha256
```

Compare the SHA-256 digest values. The hexadecimal digest should match before
you install the app.

For the published `v0.1.1` release specifically, the `.sha256` file still
contains the original build-path filename rather than the downloaded asset
filename. Treat the digest as authoritative for that release.

3. Unzip the archive.
4. Move `CameraBridgeApp.app` into `/Applications/`.
5. Launch `CameraBridgeApp.app` from `/Applications`.
6. From the menu bar app, click `Start CameraBridge Service`.
7. If prompted, click `Request Camera Access` and complete the macOS camera
   permission prompt.

## Runtime Expectations

In the supported packaged flow:

- `CameraBridgeApp` is the manager of the bundled `camd`
- the service is not guaranteed to be available unless the app is running and
  the user has started the service
- `Start CameraBridge Service` launches the bundled daemon
- `Stop CameraBridge Service` stops the app-managed daemon
- `Quit CameraBridge` stops the managed daemon before the app exits

External apps should treat CameraBridge as an external local service that may
require the user to launch the app first.

If a local macOS client receives `next_step.kind = open_camera_bridge_app`, it
can hand off the user to the installed app with:

```bash
open "camerabridge://permission"
```

## Upgrade

1. Quit `CameraBridgeApp`.
2. Download the newer signed release zip and verify its checksum.
3. Replace `/Applications/CameraBridgeApp.app` with the newer app bundle.
4. Relaunch `CameraBridgeApp`.

Upgrades preserve the existing support directory by default:

```text
~/Library/Application Support/CameraBridge/
```

That means existing token, logs, runtime metadata, and captures remain in
place across upgrades unless explicitly removed.

## Uninstall

Default uninstall:

1. Quit `CameraBridgeApp`.
2. Remove `/Applications/CameraBridgeApp.app`.

Default uninstall leaves support files in place:

```text
~/Library/Application Support/CameraBridge/
```

Full uninstall:

1. Quit `CameraBridgeApp`.
2. Remove `/Applications/CameraBridgeApp.app`.
3. Remove `~/Library/Application Support/CameraBridge/` if you also want to
   delete:
   - `auth-token`
   - `runtime-configuration.json`
   - `runtime-info.json`
   - `Logs/`
   - `Captures/`

For maintainers producing those official artifacts, use
[docs/release-process.md](./release-process.md).
