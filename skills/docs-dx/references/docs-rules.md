# CameraBridge Docs Rules

Use this file when updating `README.md`, `docs/`, or `examples/`.

## Documentation Mission

The docs should help a new developer understand CameraBridge quickly and trust what is written.
They should reflect the real repository state, not the intended future state.

## Required Update Triggers

Update docs when:

- public API changes
- setup or build steps change
- config path behavior changes
- roadmap or scope changes materially
- examples need to match a changed contract

At minimum, keep these current:

- `README.md`
- relevant files in `docs/`
- relevant guides
- relevant examples when the public contract changes

## Accuracy Rules

Do not overclaim:

- remote access
- browser permission bypasses
- advanced security properties
- features still deferred beyond v1
- examples that do not exist yet

Keep these constraints visible where relevant:

- macOS only
- localhost only
- single-user assumptions
- single active camera session in v1

## README Guidance

Use `README.md` for:

- what CameraBridge is
- the main repository layout
- quick-start build or run steps
- links to deeper docs

Do not overload the README with long design discussion when a doc page is clearer.

## API And Guide Guidance

When documenting endpoints or flows, use exact route names and method names.
Mention auth, ownership, state preconditions, and error behavior for mutating endpoints when that contract exists.
Prefer short examples that help users complete the main flow: start service, inspect status, list devices, start session, capture photo.

## Example Guidance

Examples should stay minimal and contract-focused.
They should demonstrate the public interface, not internal implementation shortcuts.
If examples are missing, note the absence honestly and create only what is needed to support the main v1 path.

## Tone Guidance

Write like the project is a narrow system component, not a platform.
Favor precise statements over marketing language.
