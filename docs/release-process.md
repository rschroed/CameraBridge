# CameraBridge Release Process

This document defines the canonical maintainer-only process for producing an
official CameraBridge external release.

Official external releases are:

- signed on a trusted maintainer Mac
- notarized on that trusted maintainer Mac
- published to GitHub Releases
- stamped with bundle metadata derived from the tag core version

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

3. Store the App Store Connect key in the local Keychain once on the trusted
   maintainer Mac:

```bash
xcrun notarytool store-credentials camerabridge-notary \
  --key "/path/to/AuthKey_XXXX.p8" \
  --key-id "XXXXXXXXXX" \
  --issuer "00000000-0000-0000-0000-000000000000"
```

4. Export the local signing and notarization environment expected by the
   artifact script:

```bash
export CAMERABRIDGE_SIGNING_IDENTITY="Developer ID Application: Example Maintainer (TEAMID1234)"
export CAMERABRIDGE_NOTARY_KEYCHAIN_PROFILE="camerabridge-notary"
```

The preferred flow keeps the notary private key in the maintainer's local
Keychain rather than in the repository or shell history. If needed, the release
script also supports the previous environment-variable fallback:

```bash
export CAMERABRIDGE_NOTARY_KEY_ID="..."
export CAMERABRIDGE_NOTARY_ISSUER_ID="..."
export CAMERABRIDGE_NOTARY_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXX.p8)"
```

These are the only maintainer-side release inputs required by the current
scripts. No provisioning profiles, App Store packaging, or additional
certificate types are part of the release flow.

5. Build the official release artifacts locally:

```bash
scripts/release/create-release-artifacts.sh --version v0.x.y --signing-mode developer-id
```

Expected outputs:

- `dist/CameraBridgeApp-v0.x.y-macos.zip`
- `dist/CameraBridgeApp-v0.x.y-macos.zip.sha256`

Bundle metadata inside the packaged app is stamped from the tag core version.
Examples:

- `v0.2.0` -> `CFBundleShortVersionString=0.2.0`, `CFBundleVersion=0.2.0`
- `v0.2.0-rc.1` -> `CFBundleShortVersionString=0.2.0`, `CFBundleVersion=0.2.0`

The script is responsible for:

- release-mode build
- Developer ID signing
- notarization submission
- stapling
- stapler validation
- best-effort staged app-open Gatekeeper assessment
- zip creation
- checksum generation

6. Create and push the release tag:

```bash
git tag v0.x.y
git push origin v0.x.y
```

7. Create or update the GitHub Release and upload the official artifacts:

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

8. Validate the distributed artifact, not the local app bundle:

- download the uploaded zip and checksum from GitHub Releases
- verify the checksum against the downloaded zip
- confirm the maintainer build completed `xcrun notarytool submit --wait`
- confirm the maintainer build completed `xcrun stapler validate`
- review any staged-path `spctl --assess --type open` warning from the maintainer build, but do not treat `source=Insufficient Context` on the staged app as a release blocker by itself
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
- stamps bundle metadata from the tag core version
- produces the only official external release artifacts
