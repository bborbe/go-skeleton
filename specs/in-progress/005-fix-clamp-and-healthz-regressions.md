---
status: prompted
approved: "2026-11-07T22:32:00Z"
generating: "2026-11-07T22:33:06Z"
prompted: "2026-11-07T22:36:38Z"
---

## Summary

- Two independent regressions landed in `aa8a889` and turned `master` red: `Clamp` no longer clamps above `max`, and `/healthz` no longer advertises JSON.
- `pkg/mathutil/clamp.go`: the upper-bound branch became `if value >= max { return min }`. Both halves are wrong — the comparison must be strict (`>`) and the branch must return `max`, not `min`.
- `pkg/handler/healthz.go`: the `Content-Type` header is set to `"text/plain"` instead of the canonical `application/json` (`libhttp.ApplicationJSONContentType`).
- Filed by the build-fix agent for CI episode `aa8a88923c12fbe2b438e7e8f29ddbd083ab9f9d`; this spec replaces the agent's generic `specs/ideas/` note with the two concrete defects.

## Problem

`master` at `aa8a889` (`refactor: simplify Clamp bounds and healthz response setup`) broke two behaviours that CI covers:

1. `Clamp` is documented as constraining a value to the inclusive range `[min, max]`. With `if value >= max { return min }`, an above-max value returns `min` instead of `max`, and a value exactly equal to `max` is wrongly treated as out of range. Two table entries fail: `above max` (`42, 0, 10` → `0`, expected `10`) and `equal to max` (`10, 0, 10` → `0`, expected `10`).
2. `NewHealthzHandler` promises HTTP 200 with `Content-Type: application/json` and body `{"status":"ok"}`. The content type now reads `text/plain`, which breaks any client that parses the liveness response as JSON.

CI run `42420450490`, job `test`, failed in `make precommit` (exit 2): 2 of 14 `mathutil` specs and 1 of 5 `handler` specs fail.

## Goal

`Clamp` clamps to both bounds again — values above `max` return `max`, values equal to `max` return `max`, values below `min` return `min`, and swapped bounds still normalise — and `/healthz` sets `Content-Type: application/json` with its existing exact body. All specs in `pkg/mathutil` and `pkg/handler` pass and `make precommit` is green.

## Non-goals

- Changing `Clamp`'s signature, its bounds-swap behaviour, or its package documentation.
- Changing the `/healthz` status code, body bytes, or the `json.Marshal` fallback path.
- Touching any other package or handler.

## Acceptance Criteria

- [ ] **`Clamp` clamps above `max`** — evidence: `go test ./pkg/mathutil/...` passes, including the `above max` entry (`42, 0, 10` → `10`).
- [ ] **`Clamp` accepts a value equal to `max`** — evidence: the same run passes the `equal to max` entry (`10, 0, 10` → `10`), so the comparison is strict rather than `>=`.
- [ ] **`/healthz` advertises JSON** — evidence: `go test ./pkg/handler/...` passes the `sets Content-Type to application/json` spec, with the body still exactly `{"status":"ok"}`.
- [ ] **No other behaviour changes** — evidence: `git diff master -- pkg/mathutil/clamp.go pkg/handler/healthz.go` shows only the two restored behaviours; the bounds-swap, the lower-bound branch, the status code and the body bytes are untouched.
- [ ] **Precommit is green** — evidence: `make precommit` exits 0.
