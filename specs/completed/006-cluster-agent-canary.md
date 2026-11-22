---
status: completed
tags:
    - dark-factory
    - spec
approved: "2026-11-22T21:25:00Z"
generating: "2026-11-22T21:17:29Z"
prompted: "2026-11-22T21:20:52Z"
verifying: "2026-11-22T21:30:07Z"
completed: "2026-11-22T21:30:13Z"
branch: dark-factory/cluster-agent-canary
---

## Summary

- Append one sentence to `README.md` noting that this repository is the reference implementation for cluster-side builds.
- Scope is that single sentence — no source-code changes, no configuration changes, no dependency changes.

## Problem

The repository's README does not say why it exists as a standalone skeleton. A reader arriving from the org has to infer it from the build scripts.

## Goal

`README.md` carries one additional sentence stating that the repository is the reference implementation for cluster-side builds, and `make precommit` still passes.

## Non-goals

- Any change to application source code, tests, or configuration.
- Rewriting or restructuring the existing README content.
- Dependency or toolchain changes.

## Desired Behavior

1. Append one sentence to `README.md` recording that this repository is the reference implementation for cluster-side builds.
2. Change nothing else.
3. `make precommit` passes.
