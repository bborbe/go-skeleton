---
status: completed
spec: [004-probe-111928]
summary: Added a dependency-free GET /probe handler returning HTTP 200 with body `ok`, wired it through the factory and router, and documented it in README and CHANGELOG with a three-case Ginkgo test.
execution_id: 9decb0cd-1359-5982-92a5-ef8ab8a41bd2-exec-016-spec-004-probe-endpoint
dark-factory-version: dev
created: "2026-11-03T17:18:28Z"
queued: "2026-11-03T17:30:18Z"
started: "2026-11-03T17:30:20Z"
completed: "2026-11-03T17:39:34Z"
branch: dark-factory/probe-111928
---

# Add `/probe` endpoint

<summary>
- The service gains a new `/probe` endpoint that always answers HTTP 200 with the exact body `ok`.
- The endpoint is dependency-free: it never consults Kafka, the database, Sentry, or any other subsystem, so it reports only that the process is up and the listener is reachable.
- Existing endpoints keep their paths, status codes, and behaviour.
- Startup, configuration flags, and k8s manifests are untouched.
- A unit test asserts the status code, the exact body, and the content type.
- The README endpoint table and the CHANGELOG record the new route.
- The endpoint is intentionally trivial: its purpose is to be shipped through the full build/release pipeline so a pipeline failure is distinguishable from a feature failure.

</summary>

<objective>
Add a `GET /probe` HTTP endpoint to the service that returns HTTP `200 OK` with the exact response body `ok`. It exists only to be shipped end-to-end through the cluster ship path (Route D), so the implementation must be minimal, dependency-free, and must not disturb any existing route or the service's startup behaviour.
</objective>

<context>
Read these files before changing anything:

- `main.go` — the router wiring lives in `func (a *application) createHTTPServer(...)`. The `/healthz` route is `router.Path("/healthz").Handler(factory.CreateHealthzHandler())`. Add the new route next to it.
- `pkg/factory/factory.go` — existing factory wrappers (`CreateHealthzHandler`, `CreateTestLoglevelHandler`, `CreateSentryAlertHandler`). Follow this exact pattern.
- `pkg/handler/healthz.go` — the closest analogue: a dependency-free handler that returns a static body and sets `Content-Type`. Copy its license header and shape.
- `pkg/handler/healthz_test.go` — the established Ginkgo v2/Gomega + `httptest` test layout to mirror.
- `README.md` — the `## Standard Endpoints` table (around line 74) lists every route the service serves.
- `CHANGELOG.md` — add one bullet under the existing `## Unreleased` section.

Reference docs (in-container paths):

- `/home/node/.claude/plugins/marketplaces/coding/docs/go-http-handler-refactoring-guide.md` — handler naming and factory wiring rules.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-testing-guide.md` — Ginkgo v2 / Gomega conventions.

Verified library facts (read from the module source at `github.com/bborbe/http@v1.26.16`; `go.mod` pins `v1.26.31` and the API is unchanged):

- `func NewPrintHandler(format string, a ...any) http.Handler` writes via `fmt.Fprintf(writer, format, a...)` — no trailing newline, no `Content-Type`. It would produce the right body but gives no unit-testable function.
- `func WriteAndGlog(w io.Writer, format string, a ...any) (n int, err error)` writes `fmt.Fprintf(w, format+"\n", a...)` — it **appends a newline**, so it would produce body `ok\n`, not `ok`. **Do not use it.**
- `libhttp.ContentTypeHeaderName` is the string constant `"Content-Type"`.

Because the spec's Proof requires the body to be exactly `ok`, the handler must write the raw bytes itself (`resp.Write([]byte("ok"))`), not use `WriteAndGlog`.
</context>

<requirements>

## 1. Create the handler

Create `pkg/handler/probe.go` with this exact content shape (license header per repo convention — copy the header from `pkg/handler/healthz.go`; the year is 2026):

```go
// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler

import (
	"net/http"

	libhttp "github.com/bborbe/http"
)

// NewProbeHandler creates an HTTP handler that serves the `/probe` pipeline
// probe response. It returns HTTP 200 with the exact body `ok` and
// Content-Type `text/plain; charset=utf-8`. The handler is dependency-free: it
// never touches Kafka, BoltDB, Sentry, or any other subsystem, so it reports
// only that the process is up and the listener is reachable.
func NewProbeHandler() http.Handler {
	return http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
		resp.Header().Set(libhttp.ContentTypeHeaderName, "text/plain; charset=utf-8")
		_, _ = resp.Write([]byte("ok"))
	})
}
```

Notes:
- `resp.Write([]byte("ok"))` writes exactly the two bytes `ok` — no trailing newline. The discarded error matches the repo's existing convention for static responses (see `pkg/handler/healthz.go`); a failed write only means the client hung up.
- The handler MUST remain dependency-free — no imports for `context`, `errors`, `libkv`, `libkafka`, or `libsentry`.
- Do not add `//nolint` directives.

## 2. Add the factory wrapper

In `pkg/factory/factory.go`, append a new function following the existing pattern (leave `CreateTestLoglevelHandler`, `CreateSentryAlertHandler`, and `CreateHealthzHandler` untouched):

```go
// CreateProbeHandler creates an HTTP handler that serves the `/probe` pipeline
// probe response (HTTP 200, body `ok`).
func CreateProbeHandler() http.Handler {
	return handler.NewProbeHandler()
}
```

The existing import block (`net/http`, `libsentry`, and the project's `pkg/handler`) already covers this function — no new imports are needed.

## 3. Wire the route in main.go

In `func (a *application) createHTTPServer(...)` in `main.go`, add one route next to the `/healthz` route:

```go
router.Path("/healthz").Handler(factory.CreateHealthzHandler())
router.Path("/probe").Handler(factory.CreateProbeHandler())
```

Do not reorder or modify any other `router.Path(...)` line. Do not change the `application` struct, `Run`, `createHTTPServer`'s signature, or `service.Run`.

## 4. Add the handler test

Create `pkg/handler/probe_test.go` with this exact content shape (license header per repo convention — copy from `pkg/handler/healthz_test.go`; the year is 2026):

```go
// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler_test

import (
	"net/http"
	"net/http/httptest"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/bborbe/go-skeleton/pkg/handler"
)

var _ = Describe("ProbeHandler", func() {
	var httpHandler http.Handler

	BeforeEach(func() {
		httpHandler = handler.NewProbeHandler()
	})

	It("returns HTTP 200", func() {
		req := httptest.NewRequest("GET", "/probe", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Code).To(Equal(http.StatusOK))
	})

	It("returns the exact body ok", func() {
		req := httptest.NewRequest("GET", "/probe", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		// Exactly `ok` — no trailing newline, no surrounding whitespace.
		Expect(resp.Body.String()).To(Equal("ok"))
	})

	It("sets Content-Type to text/plain; charset=utf-8", func() {
		req := httptest.NewRequest("GET", "/probe", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Header().Get("Content-Type")).To(Equal("text/plain; charset=utf-8"))
	})
})
```

Three `It` blocks — one per observable behaviour (status, exact body, content type). All must pass. The `pkg/handler` test suite already exists (`pkg/handler/handler_suite_test.go`); do not modify it.

## 5. Document the endpoint in the README

In `README.md`, add one row to the `## Standard Endpoints` table:

```
| `/probe` | Pipeline probe (returns `ok`) |
```

Place it after the `/readiness` row. Do not alter any other row.

## 6. Record the change in the CHANGELOG

In `CHANGELOG.md`, add one bullet under the existing `## Unreleased` section, following the `- feat:` prefix style already used there:

```
- feat: add a dependency-free `GET /probe` endpoint that returns HTTP 200 with body `ok`, giving the cluster ship path (Route D) an end-to-end probe so a pipeline failure is distinguishable from a feature failure
```

Do not bump a version header and do not add a new `##` section.

</requirements>

<constraints>

- The new endpoint MUST return HTTP `200 OK` and the exact body `ok` (spec Goal + Proof).
- The handler MUST be dependency-free — no DB, Kafka, Sentry, or other subsystem calls (spec Goal: it "exists only to be shipped through the pipeline").
- Existing routes (`/healthz`, `/readiness`, `/metrics`, `/resetdb`, `/resetbucket/{BucketName}`, `/setloglevel/{level}`, `/gc`, `/testloglevel`, `/sentryalert`), their status codes, and their handlers MUST NOT change (spec "Must not change").
- The service's startup behaviour MUST NOT change: do not touch the `application` struct, `Run`, `service.Run`, the `libhttp.NewServer` call, or any argument/env tag (spec "Must not change").
- Do NOT add a k8s liveness/readiness probe pointing at `/probe`, and do not edit anything in `k8s/`. The endpoint is to be shipped, not wired into cluster health checks.
- Do NOT use `libhttp.WriteAndGlog` for the response — it appends a newline and would make the body `ok\n`.
- No new dependencies — do not edit `go.mod` or `go.sum`.
- Handler naming follows the repo's frozen convention: `func New<Name>Handler(...) http.Handler` in `pkg/handler/`, wrapped by `func Create<Name>Handler(...) http.Handler` in `pkg/factory/`.
- Tests use Ginkgo v2 / Gomega with `httptest`. No `//nolint` without explanation.
- `make precommit` MUST pass (format + generate + lint + test + security checks).
- Existing tests MUST still pass.
- Do NOT commit — dark-factory handles git.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `go build ./...` — confirms `main.go`, the new handler, and the new factory function compile together.
2. `go test -mod=mod ./pkg/handler/` — must pass and include the three new `ProbeHandler` `It` blocks (add `-v` if you need the Ginkgo reporter output).
3. `go test -mod=mod ./pkg/factory/` — must pass; confirms the factory package still compiles with the added wrapper.
4. `grep -n 'router.Path("/probe")' main.go` — must print the new route line.
5. `grep -c 'router.Path(' main.go` — must be exactly one more than the count before this change (10 routes now: the original 9 plus `/probe`). No existing route line was removed or reordered.
6. `grep -n '| `/probe`' README.md` — must print the new table row.
7. `make precommit` — full format + generate + lint + test + security pipeline. Must exit 0.

The spec's Proof (`curl -s -o /dev/null -w '%{http_code}' http://localhost:<port>/probe` prints `200`, body `ok`) is exercised by the operator/pipeline after this change ships — the container has no Kafka or BoltDB and therefore cannot start the full service. Do not attempt to run the service or `curl` here; the unit test in step 2 covers the response contract.

If step 2 fails on the exact-body assertion, the most likely cause is a trailing newline introduced by `libhttp.WriteAndGlog` — the handler must use `resp.Write([]byte("ok"))`.

</verification>
