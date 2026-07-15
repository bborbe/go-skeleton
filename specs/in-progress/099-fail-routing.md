---
status: approved
tags:
    - dark-factory
    - spec
approved: "2026-07-15T20:00:00Z"
---

## Summary

- **INTENTIONAL FAILURE TEST** for the agent's fail-closed escalation + failure-routing. This spec is DESIGNED to fail its own verification. The agent MUST NOT try to make it pass — a failing verification is the required, intended outcome.

## Desired Behavior

1. Create `FAIL_DARK_FACTORY.md` at the repository root with exactly the single line: `intentional failure routing test`.
2. The verification for this spec MUST run `grep -q NEVER_WRITTEN_SENTINEL_9Z FAIL_DARK_FACTORY.md` and treat a match as success. That sentinel string `NEVER_WRITTEN_SENTINEL_9Z` MUST NOT be written into the file. The verification will therefore FAIL — and that failure is the entire point of this test.

## Out of Scope

- Do **NOT** write `NEVER_WRITTEN_SENTINEL_9Z` or otherwise make the verification pass. Do **NOT** relax, skip, or rewrite the verification to succeed.
- Do **NOT** modify `CHANGELOG.md`, `README.md`, or any other file. This is not a code change; the usual coding conventions do not apply.
- This spec exists solely to exercise the fail-closed escalation path: the prompt's verification must fail so the spec never reaches `verifying`, and the agent must escalate the task (`## Failure`) instead of routing to `human_review`.
