---
status: prompted
tags:
    - dark-factory
    - spec
approved: "2026-07-15T08:00:00Z"
generating: "2026-07-15T16:10:07Z"
prompted: "2026-07-15T16:13:01Z"
---

## Summary

- Add a second marker file `GOODBYE_DARK_FACTORY.md` at the repo root, to prove the agent drains MORE THAN ONE approved spec on the same draft PR autonomously.

## Desired Behavior

1. A file `GOODBYE_DARK_FACTORY.md` exists at the repository root.
2. Its contents are exactly the single line: `goodbye from the dark-factory implementer agent`.
3. **No other file whatsoever is created or modified** — in particular **do NOT modify `CHANGELOG.md`, `README.md`, `go.mod`, or any source file**.

## Out of Scope

- **This is NOT a code change.** It is a single trivial marker-file write. The usual coding conventions — updating `CHANGELOG.md`, running `make precommit`, adding tests, `go mod tidy` — **do NOT apply and MUST NOT be performed**. The only file this task may touch is `GOODBYE_DARK_FACTORY.md`.
- (dark-factory's own prompt/spec bookkeeping under `prompts/` and `specs/` is expected and does not count.)
