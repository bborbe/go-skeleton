---
status: approved
approved: "2026-11-07T21:26:00Z"
kind: bug
---

## Summary

- `pkg/mathutil.Clamp` regressed: the upper-bound branch was removed, so a value above `max` is returned unchanged instead of being clamped to `max`.
- `Clamp(42, 0, 10)` returns `42`; the `Clamp` table spec's `above max` entry expects `10`.
- The fix restores the `if value > max { return max }` branch, leaving the bounds-swap and lower-bound behaviour untouched.
- Filed by the build-fix agent for CI episode `d082cab2498f6f4b81bf9c775ef92c7b3605cf2b` (`specs/ideas/bug-build-failure-d082cab.md`); `master` was restored to green at `ca13875`, and this spec carries the change through the pipeline.

## Problem

`master` at `d082cab` (`refactor: simplify Clamp bounds handling`) removed the upper-bound clamp from `pkg/mathutil/clamp.go`. CI run `42414396294`, job `test`, failed in 2m5s with `make precommit` exiting 2 — one of seven `Clamp` specs failed (`above max`: expected `10`, got `42`).

`Clamp` is documented as constraining a value to the inclusive range `[min, max]`. Returning an out-of-range value breaks that contract for every caller, and the regression was invisible to the other six specs because they exercise values at or below the upper bound.

## Goal

`Clamp` constrains to both bounds again: values above `max` return `max`, values below `min` return `min`, in-range values pass through, and swapped bounds still normalise. `go test ./pkg/mathutil/...` passes all seven specs, and `make precommit` is green.

## Non-goals

- Changing `Clamp`'s signature, its bounds-swap behaviour, or its package documentation.
- Touching any other package.
- Adding new specs beyond restoring the removed branch — the existing table already covers the case.

## Acceptance Criteria

- [ ] **`Clamp` clamps above `max`** — evidence: `go test ./pkg/mathutil/... -run TestSuite` passes, and the `above max` entry (`42, 0, 10` → `10`) is among the passing specs.
- [ ] **No other behaviour changes** — evidence: `git diff master -- pkg/mathutil/clamp.go` shows only the restored `if value > max { return max }` branch; the bounds-swap and lower-bound branches are untouched.
- [ ] **Precommit is green** — evidence: `make precommit` exits 0.
