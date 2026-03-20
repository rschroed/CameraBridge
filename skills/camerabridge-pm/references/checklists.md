# CameraBridge PM Checklists

Use these checks to keep product recommendations aligned with the repository.

## Scope check

- Does the work stay inside camera permissions, discovery, session lifecycle, preview, still capture, or minimal local metadata?
- Does it avoid microphone, remote access, virtual cameras, plugin systems, and cross-platform abstraction?
- Does it keep ownership and state explicit?

## Slice quality check

- Can the work land as one focused PR?
- Are files touched limited to the relevant package, app target, docs path, or repo-local tooling path?
- If the work is workflow tooling, is it isolated under `skills/`?
- Are tests or manual verification notes defined?
- Is deferred work listed explicitly?

## API change check

- Are routes under `/v1/...` except `/health`?
- Are auth requirements explicit?
- Are ownership requirements explicit?
- Are state preconditions explicit?
- Are error cases explicit and machine-readable?
- Do docs and examples need updates?

## PR packaging check

- Does the branch contain only the intended slice?
- If not, should the work be split into a new branch?
- If it will not be split, does the PR body explicitly disclose the mixed scope?
- Does the PR summary match the actual commits and files changed?
- Are testing notes accurate for docs-only or tooling-only changes?

## Release check

- README updated if setup or behavior changed
- roadmap or API docs updated if the public contract changed
- tests pass or manual verification is documented
- no architecture drift across Core, API, daemon, app, docs, and workflow assets
- any repo-local workflow assets live under `skills/` when they are part of the repository
