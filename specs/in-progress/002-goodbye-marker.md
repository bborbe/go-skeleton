---
status: approved
tags:
    - dark-factory
    - spec
approved: "2026-07-15T08:00:00Z"
---

## Summary

- Add a second marker file `GOODBYE_DARK_FACTORY.md` at the repo root, to prove the agent drains MORE THAN ONE approved spec on the same draft PR autonomously.

## Desired Behavior

1. A file `GOODBYE_DARK_FACTORY.md` exists at the repository root.
2. Its contents are exactly the single line: `goodbye from the dark-factory implementer agent`.
3. No other source file is modified. (dark-factory's own prompt/spec bookkeeping under `prompts/` and `specs/` is expected and does not count.)

## Out of Scope

- Any change to Go code, CI, or existing source files.
