---
status: completed
spec: [004-restore-clamp-upper-bound]
summary: Confirmed Clamp's upper-bound branch is present (value > max returns max), all seven Clamp specs pass, and added the required Unreleased changelog entry.
execution_id: 8f5ab120-48f1-5942-92bd-e2db157641d9-exec-016-spec-004-restore-clamp-upper-bound
dark-factory-version: dev
created: "2026-11-07T21:30:00Z"
queued: "2026-11-07T21:31:47Z"
started: "2026-11-07T21:31:50Z"
completed: "2026-11-07T21:40:38Z"
---

<summary>
- `pkg/mathutil.Clamp` again constrains values to the inclusive range `[min, max]` on both ends.
- A value above `max` now returns `max` instead of being passed through unchanged.
- Values below `min` still return `min`, in-range values still pass through unchanged, and swapped bounds still normalise.
- The existing `Clamp` table spec passes all seven entries, including the `above max` case (`42, 0, 10` → `10`).
- The function signature, its package documentation, and its bounds-swap behaviour are unchanged.
- No other package is touched.
- `make precommit` is green.
</summary>

<objective>
Restore the removed upper-bound branch in `pkg/mathutil.Clamp` so the function constrains values to both ends of the inclusive range `[min, max]` again, returning `max` for any value greater than `max`. The existing table-driven Ginkgo spec already covers the case; no new tests are required.
</objective>

<context>
Read `docs/dod.md` for the project's definition of done.

Files to read before making changes:
- `pkg/mathutil/clamp.go` — the function under fix. Current body normalises swapped bounds, clamps below `min`, then returns `value` unchanged; the `value > max` branch is missing.
- `pkg/mathutil/clamp_test.go` — the existing Ginkgo `DescribeTable("Clamp", ...)` spec. It already contains the `Entry("above max", 42, 0, 10, 10)` case that currently fails.
- `pkg/mathutil/mathutil_suite_test.go` — the Ginkgo suite entry point (`TestSuite`) used to run the spec.

Reference for library style (optional): `/home/node/.claude/plugins/marketplaces/coding/docs/go-library-guide.md`.

Background: commit `d082cab` ("refactor: simplify Clamp bounds handling") removed the `if value > max { return max }` branch, causing `Clamp(42, 0, 10)` to return `42`. This prompt restores exactly that branch.
</context>

<requirements>
1. In `pkg/mathutil/clamp.go`, restore the upper-bound check in `Clamp(value, min, max int) int` so the final part of the body is:

```go
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
```

   The restored branch must sit after the existing lower-bound check and before the final `return value`.

2. Leave the bounds-swap block at the top of the function exactly as it is:

```go
	if min > max {
		min, max = max, min
	}
```

3. Do NOT change `Clamp`'s signature (`func Clamp(value, min, max int) int`), the package doc comment, the function doc comment, or the package declaration.

4. Do NOT modify `pkg/mathutil/clamp_test.go` or `pkg/mathutil/mathutil_suite_test.go`. The existing table already covers `above max`; do not add new specs.

5. Do NOT touch any file outside `pkg/mathutil/clamp.go`.

6. Run the package suite and confirm all seven `Clamp` entries pass:
   `go test ./pkg/mathutil/... -run TestSuite`

7. Run `make precommit` from the repo root and confirm it exits 0.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Do NOT change `Clamp`'s signature, its bounds-swap behaviour, or its package documentation.
- Do NOT touch any other package.
- Do NOT add new specs beyond restoring the removed branch — the existing table already covers the case.
- Existing tests must still pass.
- Follow the existing code style of `pkg/mathutil/clamp.go` (tabs for indentation, no extra comments on the restored branch).
</constraints>

<verification>
Run `make precommit` in the repo root — must pass with exit code 0.

Run the package suite and confirm the `above max` entry passes:
- `go test ./pkg/mathutil/... -run TestSuite -v`

Confirm the restored branch is present and the file is otherwise unchanged:
- `grep -n "value > max" pkg/mathutil/clamp.go` — one match
- `grep -n "value < min" pkg/mathutil/clamp.go` — one match
- `grep -n "min, max = max, min" pkg/mathutil/clamp.go` — one match
- `grep -n "func Clamp(value, min, max int) int" pkg/mathutil/clamp.go` — one match, signature unchanged
</verification>
