---
status: approved
tags:
    - dark-factory
    - spec
approved: "2026-07-15T08:00:00Z"
---

## Summary

- Add a marker file `HELLO_DARK_FACTORY.md` at the repo root so downstream tooling can detect the dark-factory implementer ran end-to-end.

## Desired Behavior

1. A file `HELLO_DARK_FACTORY.md` exists at the repository root.
2. Its contents are exactly the single line: `hello from the dark-factory implementer agent`.
3. **No other file whatsoever is created or modified** — in particular **do NOT modify `CHANGELOG.md`, `README.md`, `go.mod`, or any source file**.

## Out of Scope

- **This is NOT a code change.** It is a single trivial marker-file write. The usual coding conventions — updating `CHANGELOG.md`, running `make precommit`, adding tests, `go mod tidy` — **do NOT apply and MUST NOT be performed**. The only file this task may touch is `HELLO_DARK_FACTORY.md`.
- (dark-factory's own prompt/spec bookkeeping under `prompts/` and `specs/` is expected and does not count.)
