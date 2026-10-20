---
status: completed
spec: [003-json-readiness-endpoint]
summary: Replaced /readiness plain-text handler with JSON handler returning {"status":"ok"}
execution_id: 758d1fb0-46c1-5413-83d6-1f2c0ae1b547-exec-009-readiness-json-handler
dark-factory-version: dev
created: "2026-10-20T22:11:38Z"
queued: "2026-10-20T22:11:38Z"
started: "2026-10-20T22:11:40Z"
completed: "2026-10-20T22:22:38Z"
branch: dark-factory/json-readiness-endpoint
---
# Readiness JSON Handler

## Goal

Replace the plain-text `/readiness` response (`libhttp.NewPrintHandler("OK")`) with a JSON handler that returns `{"status":"ok"}` with `Content-Type: application/json`. The route path (`/readiness`), HTTP method (GET), and k8s readiness probe targeting are unchanged.

## Context

This is a **translation task**: the exact pattern already exists for the `/healthz` route.

- `pkg/handler/healthz.go:19` — `NewHealthzHandler()` http.Handler; returns 200 with `{"status":"ok"}` and `Content-Type: application/json`. Dependency-free.
- `pkg/factory/factory.go:28` — `CreateHealthzHandler()` factory function; returns `handler.NewHealthzHandler()`.
- `pkg/handler/healthz_test.go` — Ginkgo v2 test for the healthz handler. Use this as the exact template for the readiness test.
- `main.go:94` — current wiring: `router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))` — this line must change.

The spec says `CreateReadinessHandler()` may simply return `handler.NewHealthzHandler()` since both routes serve the identical contract. Reuse the existing handler to avoid duplication.

## Changes

### 1. `pkg/handler/readiness.go`

Create a new file with a `NewReadinessHandler()` function. Since the spec permits reusing the healthz handler, the simplest correct implementation is:

```go
func NewReadinessHandler() http.Handler {
    return NewHealthzHandler()
}
```

Alternative (if a separate handler is preferred): copy the `NewHealthzHandler` body and change the comment. Both are correct per the spec.

File must have the BSD license header (see `pkg/handler/healthz.go:1-3`).

### 2. `pkg/factory/factory.go`

Add:

```go
// CreateReadinessHandler creates an HTTP handler that serves the canonical
// `/readiness` response (HTTP 200, body `{"status":"ok"}`,
// Content-Type: application/json).
func CreateReadinessHandler() http.Handler {
    return handler.NewReadinessHandler()
}
```

### 3. `main.go:94`

Change:
```go
router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))
```
to:
```go
router.Path("/readiness").Handler(factory.CreateReadinessHandler())
```

No other line in main.go should change.

### 4. `pkg/handler/readiness_test.go`

Copy `pkg/handler/healthz_test.go` as the template. Change:
- `HealthzHandler` → `ReadinessHandler` (describe block and var name)
- `/healthz` → `/readiness` (in every `NewRequest` call)

The test structure, assertions, and imports must be identical. File must have the BSD license header.

### 5. `CHANGELOG.md`

Add under `## Unreleased`:

```markdown
- `/readiness` now returns HTTP 200 with JSON body `{"status":"ok"}` and
  Content-Type: application/json (was plain-text `OK`).
```

## Verification

After making changes, run:

```
go test -mod=mod ./pkg/handler/ -v -run ReadinessHandler
grep -c 'libhttp.NewPrintHandler' main.go   # must print 0
grep -n 'router.Path("/readiness")' main.go  # must print exactly 1 line
grep -n 'factory.CreateReadinessHandler()' main.go  # must print exactly 1 line
make precommit
```

All must pass.

## Constraints

- No new dependencies.
- No changes to k8s manifests.
- No auth middleware on the readiness route.
- The handler must be dependency-free (no Kafka, BoltDB, Sentry calls).
- All new files need the BSD license header.
- `make precommit` must pass.
