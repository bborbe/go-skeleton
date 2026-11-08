---
status: completed
spec: [005-fix-clamp-and-healthz-regressions]
summary: Restored Clamp's upper-bound branch (return max for value > max) and set healthz Content-Type to application/json, with CHANGELOG Unreleased entry; tests and make precommit pass.
execution_id: 887f0be6-e507-5e73-87e6-a3b98ae87858-exec-017-fix-clamp-and-healthz-regressions
dark-factory-version: dev
created: "2026-11-07T22:33:48Z"
queued: "2026-11-07T22:41:20Z"
started: "2026-11-07T22:41:22Z"
completed: "2026-11-07T22:48:57Z"
---

<summary>
- `Clamp` constrains values to both ends of the inclusive range `[min, max]` again.
- A value above `max` now returns `max` instead of `min`; a value exactly equal to `max` returns `max` instead of being treated as out of range.
- Values below `min` still return `min`, in-range values still pass through unchanged, and swapped bounds still normalise.
- `/healthz` again advertises `Content-Type: application/json` instead of `text/plain`.
- The `/healthz` status code, body bytes (`{"status":"ok"}`), and the `json.Marshal` fallback path are unchanged.
- Both regressions are one-line restorations; no signatures, docs, tests, or other packages change.
- `go test ./pkg/mathutil/... ./pkg/handler/...` passes and `make precommit` is green.
</summary>

<objective>
Restore the two behaviours broken by commit `aa8a889` so `master` is green again: `pkg/mathutil.Clamp` must clamp above `max` (returning `max`) and accept a value equal to `max`, and `handler.NewHealthzHandler` must set `Content-Type: application/json`. The existing Ginkgo specs already cover both cases, so no test changes are needed.
</objective>

<context>
Read `docs/dod.md` for the project's definition of done.

Files to read before making changes:
- `pkg/mathutil/clamp.go` — the `Clamp(value, min, max int) int` function. Current upper-bound branch is `if value >= max { return min }`; both the comparison and the returned value are wrong.
- `pkg/mathutil/clamp_test.go` — existing `DescribeTable("Clamp", ...)` spec. It already has the failing entries `Entry("above max", 42, 0, 10, 10)` and `Entry("equal to max", 10, 0, 10, 10)`. Do NOT modify it.
- `pkg/handler/healthz.go` — `NewHealthzHandler() http.Handler`. Current header line is `resp.Header().Add(libhttp.ContentTypeHeaderName, "text/plain")`.
- `pkg/handler/healthz_test.go` — existing spec `It("sets Content-Type to application/json", ...)`. Do NOT modify it.
- `pkg/mathutil/mathutil_suite_test.go` and `pkg/handler/handler_suite_test.go` — Ginkgo suite entry points (`TestSuite`).

Reference docs (in-container paths):
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-library-guide.md` — package/library style.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-testing-guide.md` — Ginkgo v2/Gomega conventions (read-only reference; no test edits in this prompt).

Library API verified by reading the module source: `libhttp.ContentTypeHeaderName = "Content-Type"` and `libhttp.ApplicationJSONContentType = "application/json"` are exported constants in `github.com/bborbe/http`. The handler already imports this package as `libhttp`.
</context>

<requirements>
1. In `pkg/mathutil/clamp.go`, replace the broken upper-bound branch in `Clamp` so the body after the bounds-swap block is exactly:

```go
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
```

   Concretely, change `if value >= max {` to `if value > max {` and change the branch body from `return min` to `return max`. The comparison must be strict (`>`, not `>=`).

2. Leave the bounds-swap block at the top of `Clamp` exactly as it is:

```go
	if min > max {
		min, max = max, min
	}
```

3. Do NOT change `Clamp`'s signature (`func Clamp(value, min, max int) int`), its doc comment, the package doc comment, or the package declaration.

4. In `pkg/handler/healthz.go`, change the header line from:

```go
		resp.Header().Add(libhttp.ContentTypeHeaderName, "text/plain")
```

   to:

```go
		resp.Header().Add(libhttp.ContentTypeHeaderName, libhttp.ApplicationJSONContentType)
```

   Keep `Header().Add` (not `Set`), keep `libhttp.ContentTypeHeaderName`, and use the exported constant `libhttp.ApplicationJSONContentType` rather than a raw string literal. No import changes are required.

5. Do NOT change the `/healthz` status code, the body bytes (`{"status":"ok"}` with no trailing newline), the `json.Marshal` call, or the `json.Marshal` error-fallback branch. Those are explicitly out of scope.

6. Do NOT modify any test file (`pkg/mathutil/clamp_test.go`, `pkg/handler/healthz_test.go`, the suite files) and do NOT touch any other package or handler. The existing specs already assert both restored behaviours.

7. Run the two package suites and confirm they pass:

```
go test ./pkg/mathutil/... ./pkg/handler/...
```

8. Run `make precommit` from the repo root and confirm it exits 0.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Do NOT change `Clamp`'s signature, its bounds-swap behaviour, or its package documentation.
- Do NOT change the `/healthz` status code, body bytes, or the `json.Marshal` fallback path.
- Do NOT touch any other package or handler.
- Do NOT modify tests — the existing Ginkgo specs already cover `above max`, `equal to max`, and `Content-Type: application/json`.
- Existing tests must still pass.
- Follow the existing code style of the files being modified (tabs for indentation, no extra comments on the restored branches).
- If the spec is ambiguous anywhere, do not invent scope: make only the two one-line restorations above. (No ambiguity is expected; the spec is explicit about both changes.)
</constraints>

<verification>
Run `make precommit` in the repo root — must pass with exit code 0.

Run the two package suites and confirm all entries pass:

```
go test ./pkg/mathutil/... ./pkg/handler/...
```

Confirm the restored upper bound is present and the old broken form is gone:

- `grep -n "value > max" pkg/mathutil/clamp.go` — one match
- `grep -n "value >= max" pkg/mathutil/clamp.go` — no matches
- `grep -n "return max" pkg/mathutil/clamp.go` — one match
- `grep -n "value < min" pkg/mathutil/clamp.go` — one match
- `grep -n "min, max = max, min" pkg/mathutil/clamp.go` — one match (bounds swap untouched)
- `grep -n "func Clamp(value, min, max int) int" pkg/mathutil/clamp.go` — one match (signature unchanged)

Confirm the healthz content type is JSON and the old value is gone:

- `grep -n "libhttp.ApplicationJSONContentType" pkg/handler/healthz.go` — one match
- `grep -n "text/plain" pkg/handler/healthz.go` — no matches
- `grep -n '"status":"ok"' pkg/handler/healthz.go` — one match (body fallback untouched)

Confirm no test files were modified:
- `git status --short` — only `pkg/mathutil/clamp.go` and `pkg/handler/healthz.go` show as changed (plus pre-existing spec/prompt files).
</verification>
