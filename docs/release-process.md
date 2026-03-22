# CameraBridge Release Process

This document defines the canonical maintainer-only process for producing an
official CameraBridge external release.

Official external releases are:

- signed on a trusted maintainer Mac
- notarized on that trusted maintainer Mac
- published to GitHub Releases

GitHub Actions is not the signing or notarization authority for CameraBridge
releases.

## Prerequisites

On the trusted maintainer Mac:

- Apple Developer credentials required for Developer ID signing
- local notarization credentials configured for the maintainer
- `gh` authenticated with permission to create or edit GitHub Releases
- clean working copy of the CameraBridge repository

The existing release scripts remain the source of truth:

- `scripts/release/package-app-bundle.sh`
- `scripts/release/create-release-artifacts.sh`

## Official Release Procedure

1. Start from clean, up-to-date `main`:

```bash
git checkout main
git pull --ff-only
git status --short
```

2. Choose the release version:

```text
v0.x.y
```

3. Export the local signing and notarization environment expected by the
   artifact script:

```bash
export CAMERABRIDGE_SIGNING_IDENTITY="Developer ID Application: ..."
export CAMERABRIDGE_NOTARY_KEY_ID="..."
export CAMERABRIDGE_NOTARY_ISSUER_ID="..."
export CAMERABRIDGE_NOTARY_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXX.p8)"
```

4. Build the official release artifacts locally:

```bash
scripts/release/create-release-artifacts.sh --version v0.x.y --signing-mode developer-id
```

Expected outputs:

- `dist/CameraBridgeApp-v0.x.y-macos.zip`
- `dist/CameraBridgeApp-v0.x.y-macos.zip.sha256`

The script is responsible for:

- release-mode build
- Developer ID signing
- notarization submission
- stapling
- zip creation
- checksum generation

5. Create and push the release tag:

```bash
git tag v0.x.y
git push origin v0.x.y
```

6. Create or update the GitHub Release and upload the official artifacts:

```bash
gh release create v0.x.y \
  dist/CameraBridgeApp-v0.x.y-macos.zip \
  dist/CameraBridgeApp-v0.x.y-macos.zip.sha256 \
  --generate-notes
```

If the release already exists:

```bash
gh release upload v0.x.y \
  dist/CameraBridgeApp-v0.x.y-macos.zip \
  dist/CameraBridgeApp-v0.x.y-macos.zip.sha256 \
  --clobber
```

7. Validate the distributed artifact, not the local app bundle:

- download the uploaded zip and checksum from GitHub Releases
- verify the checksum against the downloaded zip
- install the downloaded app bundle into `/Applications`
- confirm Gatekeeper accepts launch
- complete the packaged-flow smoke test in `docs/release-readiness.md`

8. Record release-readiness verification notes for the release.

## Validation Workflow

The repository keeps a validation-only GitHub Actions workflow for release
contract checks.

Use it in two ways:

- tag push: validates tag shape and required docs/links
- manual dispatch: validates the release asset names after the maintainer has
  uploaded the official artifacts

This workflow does not sign, notarize, or upload the official app bundle.

## Contributor Packaging Versus Official Releases

Contributor-local packaging:

- uses `apps/CameraBridgeApp/scripts/package-app.sh`
- is ad-hoc signed
- is intended for development and local verification

Official external release packaging:

- uses `scripts/release/create-release-artifacts.sh --signing-mode developer-id`
- is maintainer-signed and maintainer-notarized
- produces the only official external release artifacts
