---
status: completed
spec: [003-json-readiness-endpoint]
summary: 'Implemented GET /readiness returning HTTP 200 with body {"status":"ok"} and Content-Type: application/json, replacing the plain-text OK handler'
execution_id: cfa6018d-fd58-58d9-ae87-25de7c834e1d-exec-009-readiness-json-handler
dark-factory-version: dev
created: "2026-10-20T21:57:10Z"
queued: "2026-10-20T21:57:10Z"
started: "2026-10-20T21:57:12Z"
completed: "2026-10-20T22:08:06Z"
branch: dark-factory/json-readiness-endpoint
---
# Readiness JSON Handler

## Goal

Implement `GET /readiness` returning HTTP 200 with body `{"status":"ok"}` and `Content-Type: application/json`, replacing the existing plain-text `OK` handler wired in `main.go`.

## Context

- **Spec:** `specs/in-progress/003-json-readiness-endpoint.md`
- **Repo root:** `.` (current working directory)

## Requirements

### 1. New file: `pkg/handler/readiness.go`

Create `pkg/handler/readiness.go` with a `NewReadinessHandler() http.Handler` function.

Follow the **exact same structure** as `pkg/handler/healthz.go`:
- Return an `http.HandlerFunc` that sets `Content-Type: application/json` header
- Marshal a `struct{Status string}{Status: "ok"}` via `json.Marshal`
- Fall back to the raw bytes `[]byte(`{"status":"ok"}`)` if marshal ever fails (cannot in practice for a static struct, but the fallback pattern from `healthz.go` must be reproduced)
- Write the body with `resp.Write(body)`
- No imports beyond `encoding/json`, `net/http`, and `libhttp "github.com/bborbe/http"` (the Content-Type header constant comes from `libhttp`)
- BSD license header (see `pkg/handler/healthz.go:1-3`)

**Pattern reference:** `pkg/handler/healthz.go` (the identical structure for `/healthz`)

### 2. New file: `pkg/handler/readiness_test.go`

Create `pkg/handler/readiness_test.go` in package `handler_test` (not `handler`).

Follow the **exact same structure** as `pkg/handler/healthz_test.go`:
- Three `It` blocks:
  1. `"returns HTTP 200"` — asserts `resp.Code == http.StatusOK`
  2. `"returns the exact JSON body"` — asserts `resp.Body.String() == "{\"status\":\"ok\"}"`
  3. `"sets Content-Type to application/json"` — asserts `resp.Header().Get("Content-Type") == "application/json"`
- Use `httptest.NewRecorder` + `httptest.NewRequest("GET", "/readiness", nil)`
- Call `httpHandler.ServeHTTP(resp, req)` and then Gomega `Expect` assertions
- `//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6@v6.12.2 -generate` line (same as suite test)
- BSD license header

**Pattern reference:** `pkg/handler/healthz_test.go` (the identical test structure for `/healthz`)

### 3. Update: `pkg/factory/factory.go`

Add a `CreateReadinessHandler()` factory function that returns `handler.NewReadinessHandler()`.

Follow the same pattern as `CreateHealthzHandler()` in the same file:
```go
// CreateReadinessHandler creates an HTTP handler that serves the canonical
// `/readiness` readiness response (HTTP 200, body `{"status":"ok"}`,
// Content-Type: application/json).
func CreateReadinessHandler() http.Handler {
    return handler.NewReadinessHandler()
}
```

**Pattern reference:** `pkg/factory/factory.go:25-30` (`CreateHealthzHandler`)

### 4. Update: `main.go`

In the `createHTTPServer` function, replace:
```go
router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))
```
with:
```go
router.Path("/readiness").Handler(factory.CreateReadinessHandler())
```

The `libhttp.NewPrintHandler` import line stays (it's used by other routes); only the `/readiness` handler swap is required.

**Pattern reference:** `main.go:93-94` (current wiring) and `main.go:93` (healthz wiring as a model for the same form)

### 5. Update: `CHANGELOG.md`

Add an `## Unreleased` bullet (if not already present at top of `## Unreleased` section):
```
- feat: serve `/readiness` as JSON (`{"status":"ok"}` with `Content-Type: application/json`) — the readiness probe target now returns the same canonical JSON contract as `/healthz`, eliminating the two-contract probe surface in the skeleton template
```

**Pattern reference:** Existing `## Unreleased` bullets in `CHANGELOG.md` for format and tense conventions.

## Verification

After completing all changes, run:
```
go test -mod=mod ./pkg/handler/ -v -run ReadinessHandler
```
The output must show three passing `It` blocks for `ReadinessHandler`.

Also verify:
- `grep -c 'libhttp.NewPrintHandler' main.go` returns `0`
- `grep -n 'CreateReadinessHandler' main.go pkg/factory/factory.go` returns at least 2 lines
- `grep -n 'router.Path("/readiness")' main.go` returns exactly 1 line

## Open Questions

None — all decisions are resolved in the spec.

## Dependencies

None — no new dependencies.
