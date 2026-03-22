# Engineering Workflow

This repository uses GitHub as the system of record for planning, review, and merge decisions.

The default workflow is:

1. Create or refine a GitHub issue for the slice of work.
2. Create one focused branch from `main`.
3. Implement the smallest complete slice that closes the issue.
4. Open a draft pull request early.
5. Run local verification and let CI validate the branch.
6. Merge on GitHub after the PR is ready.

This keeps `main` releasable and matches the repository rules in `AGENTS.md`.

## Default Policy

- `main` is protected and stays releasable.
- Use one GitHub issue per branch.
- Use one pull request per focused slice.
- Prefer draft PRs while a slice is still moving.
- Merge through GitHub, not with a local merge to `main`.
- Keep each PR small enough to review quickly.

Recommended branch naming:

- `codex/health-endpoint`
- `codex/permissions-status`
- `codex/device-enumeration`

## What Lives Where

GitHub issue:
- problem statement
- acceptance criteria
- constraints
- out-of-scope items

Branch:
- implementation for exactly one issue-sized slice

Pull request:
- summary of the change
- files or areas changed
- test or manual verification notes
- explicitly deferred follow-up work

Chat with an agent:
- implementation assistance
- investigation
- local iteration

Do not leave final scope or testing decisions only in chat. Capture them in the issue or PR.

## Pull Request Flow

1. Start from up-to-date `main`.
2. Create a focused branch for a single issue.
3. Push early and open a draft PR.
4. Keep the PR scoped to the issue. If scope changes materially, update the issue and PR description.
5. Resolve CI failures before merge.
6. Merge on GitHub once the PR summary, testing notes, and deferred work are clear.

Preferred merge style:

- squash merge by default for small focused slices

Alternative merge styles are acceptable when preserving commit history adds value, but avoid merge noise.

## Local Merge Guidance

Do not treat local merges to `main` as the standard workflow.

Local merge to `main` is acceptable only as a narrow exception, such as:

- a trivial docs or typo fix
- a repository admin change that does not justify review overhead
- an urgent repair when GitHub is temporarily unavailable

If a local merge exception is used:

1. Push immediately afterward.
2. Document the reason in the commit message or follow-up issue.
3. Keep the change as small as possible.

Behavior changes, API changes, architecture changes, and anything that carries regression risk should go through a GitHub PR.

## Agent Workflow

Agents should work inside the same branch and issue boundary as a human contributor.

When using an agent:

1. Start from a GitHub issue with acceptance criteria.
2. Create the issue branch before implementation begins.
3. Ask the agent to keep scope narrow and avoid unrelated files.
4. Require the agent to include tests or manual verification notes.
5. Open or update the draft PR as the work evolves.
6. Merge only after the PR describes what changed, how it was tested, and what was deferred.

Useful defaults for agentic work:

- no direct pushes to `main`
- no silent scope expansion
- no mixing unrelated fixes into the same PR
- no architecture changes without updating docs or the relevant issue

## GitHub Repository Settings

Recommended branch protection for `main`:

- require pull requests before merging
- require status checks to pass before merging
- require branches to be up to date before merging, if CI cost stays reasonable
- restrict direct pushes
- enable squash merge
- optionally disable merge commits if you want a stricter linear history

Recommended labels:

- `bug`
- `feature`
- `docs`
- `chore`
- `api`
- `core`
- `app`
- `hardware-needed`
- `agent-safe`

## Release Workflow

External CameraBridge releases should be published from GitHub tags, not from a
local manually distributed app bundle.

For the external release path:

1. Tag the release with `v0.x.y`.
2. Let the macOS release workflow build, sign, notarize, staple, zip, and
   checksum the app bundle.
3. Publish the signed artifact and checksum to GitHub Releases.
4. Treat the GitHub Release assets as the source of truth for external adopters.

Required GitHub Actions secrets:

- `CAMERABRIDGE_DEVELOPER_ID_APPLICATION_CERT_P12_BASE64`
- `CAMERABRIDGE_DEVELOPER_ID_APPLICATION_CERT_PASSWORD`
- `CAMERABRIDGE_CI_KEYCHAIN_PASSWORD`
- `CAMERABRIDGE_SIGNING_IDENTITY`
- `CAMERABRIDGE_NOTARY_KEY_ID`
- `CAMERABRIDGE_NOTARY_ISSUER_ID`
- `CAMERABRIDGE_NOTARY_PRIVATE_KEY`

## Definition Of Ready

Before starting implementation, the issue should answer:

- what problem is being solved
- what is explicitly in scope
- what is explicitly out of scope
- how the change will be verified

## Definition Of Done

A slice is done when:

- the issue acceptance criteria are met
- the PR explains the change clearly
- tests pass or manual verification is documented
- docs are updated if public behavior changed
- deferred work is called out explicitly
- the change merges safely into `main`
