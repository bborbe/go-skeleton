---
status: completed
spec: [003-json-readiness-endpoint]
summary: Replaced /readiness plain-text OK response with JSON {"status":"ok"} matching /healthz contract
execution_id: 002b87c8-fa1f-5999-b943-2c97ff896c12-exec-009-readiness-handler
dark-factory-version: dev
created: "2026-10-20T23:48:21Z"
queued: "2026-10-20T23:48:21Z"
started: "2026-10-20T23:48:23Z"
completed: "2026-10-21T00:00:11Z"
branch: dark-factory/json-readiness-endpoint
---
# Prompt: Readiness Handler JSON Response

## Repo
`github.com/bborbe/go-skeleton`

## Task
Replace the `/readiness` route's plain-text `OK` response with a JSON body `{"status":"ok"}` and `Content-Type: application/json`, matching the `/healthz` contract exactly. The route path, its role as the k8s readiness probe target, and all other routes are unchanged.

## Context

### What exists today
- `pkg/handler/healthz.go` — the **canonical exemplar** for this change. `NewHealthzHandler()` serves `{"status":"ok"}` with `Content-Type: application/json`. The readiness handler MUST produce the identical response.
- `pkg/factory/factory.go` — factory wiring for handlers (bcom-style `Create<Name>Handler()`). `CreateHealthzHandler()` already exists; add `CreateReadinessHandler()` the same way.
- `main.go:94` — the current wiring: `router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))`. Replace with `factory.CreateReadinessHandler()`.
- `pkg/handler/test-loglevel_test.go` — Ginkgo v2 test pattern (package `handler_test`, `Describe`/`It`/gomega `Expect`). Use as the test template.
- `pkg/handler/handler_suite_test.go` — suite setup; no changes needed.

### What to do
1. **Handler** (`pkg/handler/readiness.go`): Create `NewReadinessHandler() http.Handler` that returns `{"status":"ok"}` with `Content-Type: application/json`. The simplest implementation is to call `NewHealthzHandler()` directly — both routes serve the identical contract and reusing the existing handler avoids future drift.
2. **Factory** (`pkg/factory/factory.go`): Add `CreateReadinessHandler() http.Handler` that returns `handler.NewReadinessHandler()`.
3. **Wiring** (`main.go:94`): Replace `libhttp.NewPrintHandler("OK")` with `factory.CreateReadinessHandler()` on the `/readiness` route.
4. **Test** (`pkg/handler/readiness_test.go`): Ginkgo v2 spec in `package handler_test` that asserts:
   - `GET /readiness` → `resp.Code == http.StatusOK`
   - `resp.Body.String() == "{\"status\":\"ok\"}"` (exact match, no extra whitespace, no trailing newline)
   - `resp.Header().Get("Content-Type") == "application/json"`
   - Request sent with no auth headers, no query params, no body
5. **CHANGELOG**: Add `## Unreleased` bullet to `CHANGELOG.md` describing the readiness JSON contract change.

### Constraints
- BSD license header on all new files (see `pkg/handler/healthz.go:1-3`)
- `github.com/bborbe/errors` for error wrapping (no `fmt.Errorf`)
- No `//nolint` without explanation
- No new dependencies
- Handler must be dependency-free: no Kafka, BoltDB, Sentry, or any backend calls
- `make precommit` must pass (runs `addlicense`, `gofmt`, `go generate`, `golangci-lint`, tests)

## Verification
After implementation, these must all pass:
- `go test -mod=mod ./pkg/handler/ -v` — the new `ReadinessHandler` spec passes
- `grep -c 'libhttp.NewPrintHandler' main.go` → `0`
- `grep -n 'router.Path("/readiness")' main.go` → exactly 1 line
- `grep -n 'factory.CreateReadinessHandler()' main.go` → exactly 1 line
- `grep -cE 'kafka|bolt|kv\.|sentry' pkg/handler/readiness.go` → `0`
- `make precommit` → exit 0

## Acceptance Criteria (from spec)
- `GET /readiness` returns HTTP 200
- Response body exactly `{"status":"ok"}`
- `Content-Type: application/json`
- No auth required
- Handler makes no backend calls
- Route still at `/readiness` (k8s probe unchanged)
- No k8s manifest changes
