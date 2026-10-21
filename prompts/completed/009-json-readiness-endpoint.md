---
status: completed
spec: [003-json-readiness-endpoint]
summary: Made GET /readiness return JSON {"status":"ok"} with Content-Type application/json by delegating to the existing healthz handler, with a new Ginkgo test, factory wiring, and changelog entry.
execution_id: 0987092c-e140-5de9-acca-a39d5172c065-exec-009-json-readiness-endpoint
dark-factory-version: dev
created: "2026-10-21T19:59:03Z"
queued: "2026-10-21T20:05:16Z"
started: "2026-10-21T20:05:18Z"
completed: "2026-10-21T20:17:36Z"
branch: dark-factory/json-readiness-endpoint
---

# JSON readiness endpoint

<summary>
- `GET /readiness` now answers with the canonical JSON body `{"status":"ok"}` instead of the plain-text `OK`.
- The response carries `Content-Type: application/json`, matching what `/healthz` already serves.
- The route path, the HTTP method (`GET`), and the k8s readiness-probe target stay unchanged.
- The plain-text wiring is removed from the server setup and replaced by the JSON handler.
- The new readiness handler delegates to the existing liveness handler, so the two probe contracts cannot drift apart.
- A new Ginkgo v2/Gomega unit test asserts status 200, the exact body, the content type, and that the endpoint needs no auth.
- The handler makes no backend calls — readiness reports that the process accepts traffic, never subsystem health.
- No k8s manifest changes, no config changes, no new dependencies.
- The changelog records the new readiness JSON contract under `## Unreleased`.
</summary>

<objective>
Make `GET /readiness` return HTTP 200 with the exact JSON body `{"status":"ok"}` and `Content-Type: application/json`, reachable unauthenticated whenever the process is up and accepting traffic. The route path and its role as the k8s readiness probe target must not change.
</objective>

<context>
Read these files before changing anything (paths are relative to the repo root, which is the working directory):

- `main.go` — router wiring in `createHTTPServer`. The readiness route is currently `router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))`. This is the only place `libhttp.NewPrintHandler` is used.
- `pkg/handler/healthz.go` — `NewHealthzHandler() http.Handler` already serves exactly `{"status":"ok"}` with `Content-Type: application/json`, using `json.Marshal` + raw `resp.Write` (no trailing newline). The readiness handler must reuse this behavior, not re-implement it.
- `pkg/handler/healthz_test.go` — the established Ginkgo v2/Gomega test layout for a static handler (`Describe`, `BeforeEach`, one `It` per assertion).
- `pkg/factory/factory.go` — existing `Create<Name>Handler()` factory functions; `CreateHealthzHandler()` is the direct template.
- `pkg/handler/test-loglevel.go` and `pkg/handler/sentry-alert.go` — established `New<Name>Handler(...) http.Handler` signatures and license-header convention.
- `k8s/skeleton-deploy.yaml` and `k8s/skeleton-sts.yaml` — both readiness probes use `httpGet` on path `/readiness`, port 9090, with no `responseContains`. DO NOT modify these files.
- `CHANGELOG.md` — the `## Unreleased` section where the new bullet belongs.

Reference docs (in-container paths):

- `/home/node/.claude/plugins/marketplaces/coding/docs/go-http-handler-refactoring-guide.md` — handler naming and factory wiring rules.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-factory-pattern.md` — `Create*` factories contain zero business logic.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-testing-guide.md` — Ginkgo v2/Gomega conventions.
- `/home/node/.claude/plugins/marketplaces/coding/docs/changelog-guide.md` — `## Unreleased` entry format.

Verified library facts (read from the module source, do not re-derive from memory):

- `func NewPrintHandler(format string, a ...any) http.Handler` in `github.com/bborbe/http` — produces plain text with no `Content-Type`. This is what is being removed from the readiness route.
- `ContentTypeHeaderName = "Content-Type"` and `ApplicationJSONContentType = "application/json"` in `github.com/bborbe/http` — already used by `NewHealthzHandler`; the readiness handler inherits them by delegation.
- `libhttp` remains imported in `main.go` after the change because `libhttp.NewGarbageCollectorHandler()` and `libhttp.NewServer(...)` still use it.
</context>

<requirements>

## 1. Create the readiness handler

Create `pkg/handler/readiness.go` with the repo's BSD license header (copy the two header lines from `pkg/handler/healthz.go`, using the current year 2026) and this content:

```go
package handler

import (
	"net/http"
)

// NewReadinessHandler creates an HTTP handler that serves the canonical
// readiness response: HTTP 200 with body `{"status":"ok"}` and
// Content-Type: application/json. It delegates to NewHealthzHandler so the
// liveness and readiness routes cannot drift apart, and it is
// dependency-free: it never touches Kafka, BoltDB, Sentry, or any other
// subsystem.
func NewReadinessHandler() http.Handler {
	return NewHealthzHandler()
}
```

Do NOT copy the JSON-building body from `healthz.go` into this file. Delegation is required so a future change to the canonical response cannot make the two routes disagree. Do NOT add imports for `context`, `errors`, `libkv`, `libsentry`, `encoding/json`, or `libhttp` — the file needs only `net/http`.

## 2. Add the factory function

In `pkg/factory/factory.go`, append a new function following the existing pattern. Leave `CreateTestLoglevelHandler`, `CreateSentryAlertHandler`, and `CreateHealthzHandler` unchanged.

```go
// CreateReadinessHandler creates an HTTP handler that serves the canonical
// `/readiness` response (HTTP 200, body `{"status":"ok"}`,
// Content-Type: application/json).
func CreateReadinessHandler() http.Handler {
	return handler.NewReadinessHandler()
}
```

The existing import block (`net/http`, `libsentry`, `handler`) already covers this — no new imports.

## 3. Wire the route in `main.go`

In `createHTTPServer`, replace the readiness line:

```go
// Before
router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))

// After
router.Path("/readiness").Handler(factory.CreateReadinessHandler())
```

The route path string `/readiness` and the fact that it is a bare `router.Path(...)` with no middleware wrapper must stay exactly as they are. Do not touch any other route line (`/healthz`, `/metrics`, `/resetdb`, `/resetbucket/{BucketName}`, `/setloglevel/{level}`, `/gc`, `/testloglevel`, `/sentryalert`). Do not modify the `application` struct, `Run`, `service.Run`, or any k8s file.

After the edit, confirm `libhttp` is still referenced in `main.go` (it is, via `libhttp.NewGarbageCollectorHandler()` and `libhttp.NewServer(...)`), so the import stays.

## 4. Add the readiness handler test

Create `pkg/handler/readiness_test.go` with the repo's BSD license header (copy from `pkg/handler/healthz_test.go`, year 2026) and this content:

```go
package handler_test

import (
	"net/http"
	"net/http/httptest"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/bborbe/go-skeleton/pkg/handler"
)

var _ = Describe("ReadinessHandler", func() {
	var httpHandler http.Handler

	BeforeEach(func() {
		httpHandler = handler.NewReadinessHandler()
	})

	It("returns HTTP 200", func() {
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Code).To(Equal(http.StatusOK))
	})

	It("returns the exact JSON body", func() {
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		// Exactly {"status":"ok"} — no surrounding whitespace, no trailing newline.
		Expect(resp.Body.String()).To(Equal(`{"status":"ok"}`))
	})

	It("sets Content-Type to application/json", func() {
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Header().Get("Content-Type")).To(Equal("application/json"))
	})

	It("requires no authentication", func() {
		// No headers, no cookies, no query parameters, no request body.
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Code).To(Equal(http.StatusOK))
	})
})
```

Four `It` blocks, one per behavior the spec calls out. Use `It`, not `DescribeTable`, matching the existing handler tests.

## 5. Update `CHANGELOG.md`

Add one bullet under the existing `## Unreleased` section, following the existing `- feat:` prefix style:

```
- feat: serve `/readiness` as JSON (`{"status":"ok"}` with `Content-Type: application/json`) so the readiness contract matches `/healthz`; route path and k8s readiness probe unchanged
```

Do not bump a version header and do not add a new `##` section.

</requirements>

<constraints>

- The `/readiness` route path, the `GET` method, and its k8s readiness-probe role MUST NOT change (spec Goal, Non-goal, Failure Mode row 4).
- The response body MUST be exactly `{"status":"ok"}` — no trailing newline, no surrounding whitespace, no extra fields. Delegating to `NewHealthzHandler` is what guarantees this; do not replace the delegation with `libhttp.NewJSONHandler`, which appends a newline.
- The response `Content-Type` MUST be `application/json`.
- The endpoint MUST require no auth, no headers, no query parameters, and no request body.
- The handler MUST make no backend calls (DB, Kafka, Sentry). Readiness reports that the process accepts traffic, not subsystem health (spec Non-goal).
- Do NOT change k8s manifests or probe configuration — `git diff origin/master..HEAD -- k8s/` must be empty.
- Do NOT touch `/healthz`, `/metrics`, `/resetdb`, `/resetbucket`, `/gc`, `/setloglevel`, `/testloglevel`, or `/sentryalert`.
- Do NOT add a second JSON-building implementation that could drift from `NewHealthzHandler`.
- Handler naming follows the repo's frozen conventions: `func New<Name>Handler(...) http.Handler` in `pkg/handler/`, wired by `func Create<Name>Handler(...) http.Handler` in `pkg/factory/`.
- New files carry the repo's BSD license header; `addlicense` runs inside `make precommit` and fails without it.
- Tests use Ginkgo v2/Gomega with `httptest`. No `//nolint` without explanation.
- No new dependencies — do not edit `go.mod` or `go.sum`.
- `make precommit` MUST pass; existing tests MUST still pass.
- Do NOT commit — dark-factory handles git.

</constraints>

<verification>

Run these in order; each must succeed before moving on:

1. `go build ./...` — confirms `main.go` and the new handler/factory compile.
2. `go test -mod=mod ./pkg/handler/ -v` — must pass and the output must list a `ReadinessHandler` spec whose `It` blocks assert status 200, the exact body, the content type, and the no-auth request shape.
3. `go test -mod=mod ./pkg/factory/` — must pass; confirms the factory package still compiles.
4. `make precommit` — full format + generate + lint + test + security pipeline. Must exit 0.
5. `grep -c 'libhttp.NewPrintHandler' main.go` — prints `0` (grep exits 1 because there are no matches; that exit code is expected here).
6. `grep -n 'router.Path("/readiness")' main.go` — prints exactly one line.
7. `grep -cE 'kafka|bolt|kv\.|sentry' pkg/handler/readiness.go` — prints `0`.
8. `git diff origin/master..HEAD -- k8s/` — prints nothing.

If step 2 fails on the exact-body assertion, the cause is almost certainly a trailing newline from `json.NewEncoder`; confirm `NewReadinessHandler` delegates to `NewHealthzHandler` and does not build its own JSON response.

If `make precommit` fails in `addlicense`, add the two-line BSD header to every new `.go` file and re-run.

</verification>
