---
status: approved
approved: "2026-11-23T07:30:00Z"
---

## Summary

- Canary for the dark-factory cross-branch spec-write fix (dark-factory `v0.199.4`, agent image `v0.8.2`). A trivial, revertible change: append one sentence to `README.md`.
- The run starts on the default branch and must switch onto this PR branch, so the spec-status write is dirty at branch setup. `v0.199.4` stashes the write, switches, pops it on this branch, and commits it there — the run reaches prompt execution instead of refusing with `working tree is not clean; cannot switch to branch`.
