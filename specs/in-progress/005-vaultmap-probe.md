---
approved: "2026-11-04T09:30:00Z"
---

## Summary

- Throwaway routing probe. This spec exists only so a draft PR in `bborbe/go-skeleton` carries an approved-not-completed spec under `specs/in-progress/`, which is what the dark-factory watcher requires before it emits a `CreateTaskCommand`.
- The probe's purpose is to observe the `target_vault` the watcher stamps on that command on the **dev** stage, where `REPO_VAULT_MAP` maps `github.com/bborbe/go-skeleton=personal`.
- No functional change to the repository is intended. The PR is closed once the observation is recorded.

## Goal

A task file for this PR appears in the personal vault carrying `target_vault: personal`, with no manual materialization.

## Non-goals

- Any code change.
- Merging this PR.

## Acceptance Criteria

- [ ] A task file exists for this PR's `task_identifier` in `25 Tasks/` with `target_vault: personal`.
