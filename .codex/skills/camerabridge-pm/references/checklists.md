# CameraBridge PM Checklists

## Scope check

- Does the work stay inside camera permissions, discovery, session lifecycle, preview, or still capture?
- Does it avoid microphone, remote access, virtual cameras, plugins, and cross-platform abstraction?
- Does it keep ownership and state explicit?

## API change check

- Are routes under `/v1/...` except `/health`?
- Are auth requirements explicit?
- Are ownership requirements explicit?
- Are state preconditions explicit?
- Are error cases explicit and machine-readable?
- Do docs and examples need updates?

## Slice quality check

- Can the work land as one focused PR?
- Are files touched limited to the relevant package or app boundary?
- Are tests or manual verification notes defined?
- Is deferred work listed explicitly?

## Release check

- README updated if setup or behavior changed
- roadmap or API docs updated if public contract changed
- tests pass or manual verification is documented
- no architecture drift across Core, API, daemon, and app
