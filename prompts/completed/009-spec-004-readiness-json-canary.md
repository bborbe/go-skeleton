---
status: completed
spec: [004-readiness-json-canary]
summary: Serve /readiness as JSON {"status":"ok"} with application/json via a delegating NewReadinessHandler wired through CreateReadinessHandler; tests, changelog, and precommit all pass
execution_id: a2562758-fe5e-505b-8799-367fde93dcc5-exec-009-spec-004-readiness-json-canary
dark-factory-version: dev
created: "2026-10-21T22:23:10Z"
queued: "2026-10-21T22:33:36Z"
started: "2026-10-21T22:33:38Z"
completed: "2026-10-21T22:44:44Z"
---

# Readiness JSON canary

<summary>
- `GET /readiness` now returns HTTP 200 with the exact JSON body `{"status":"ok"}` instead of the plain-text `OK`.
- The response carries `Content-Type: application/json`, matching the canonical `/healthz` contract.
- Both probe routes now serve one response shape, so a service cloned from this skeleton no longer inherits two disagreeing probe contracts.
- The route path `/readiness` and the k8s readiness probe targeting it are unchanged.
- The handler is static and dependency-free: it reports only that the process accepts traffic, never the health of Kafka, BoltDB, or Sentry.
- A new readiness handler lives in `pkg/handler/` and delegates to the existing healthz handler, so the JSON contract cannot drift out of sync.
- A factory function in `pkg/factory/` wires it into `main.go`, replacing the plain-text `libhttp.NewPrintHandler("OK")` on that route.
- A Ginkgo v2/Gomega test (httptest) asserts status, exact body, content type, and the no-auth request shape.
- No new dependencies, no manifest changes, and no other routes touched.
</summary>

<objective>
Make `GET /readiness` return HTTP 200 with the exact JSON body `{"status":"ok"}` and `Content-Type: application/json`, reachable unauthenticated whenever the process is up. The route path stays `/readiness` and the k8s readiness probe in `k8s/skeleton-deploy.yaml` / `k8s/skeleton-sts.yaml` continues to target it unchanged.
</objective>

<context>
Read `docs/dod.md` for the project's Definition of Done.

Read these files before changing anything:

- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/main.go` — router wiring. In `createHTTPServer` the current readiness line is `router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))` (line ~94). The `/healthz` line immediately above is already `router.Path("/healthz").Handler(factory.CreateHealthzHandler())`.
- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/handler/healthz.go` — the canonical `{"status":"ok"}` handler. `func NewHealthzHandler() http.Handler` is the function the readiness handler delegates to; do not change this file.
- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/handler/healthz_test.go` — the Ginkgo v2/Gomega test layout to mirror (`package handler_test`, `Describe`/`BeforeEach`/`It`, dot-imports).
- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/handler/handler_suite_test.go` — the shared Ginkgo suite runner for the `handler_test` package; the new test file relies on it and needs no runner of its own.
- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/factory/factory.go` — existing factory functions (`CreateTestLoglevelHandler`, `CreateSentryAlertHandler`, `CreateHealthzHandler`); `CreateReadinessHandler` follows the same shape.
- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/handler/sentry-alert.go` — representative handler file and license header.
- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/CHANGELOG.md` — the existing `## Unreleased` section where the new bullet goes.
- `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/k8s/skeleton-deploy.yaml` and `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/k8s/skeleton-sts.yaml` — both readiness probes use `httpGet` with `path: /readiness` and check HTTP status only (no `responseContains`). Read them to confirm the probe path, then DO NOT modify them.

Reference docs (inside the YOLO container):

- `/home/node/.claude/plugins/marketplaces/coding/docs/go-http-handler-refactoring-guide.md` — handler naming and factory wiring rules.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-factory-pattern.md` — the `Create<Name>Handler` DI convention.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-testing-guide.md` — Ginkgo v2/Gomega conventions.
- `/home/node/.claude/plugins/marketplaces/coding/docs/changelog-guide.md` — `## Unreleased` entry format.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-licensing-guide.md` — BSD license header requirement.

Verified API facts (read from the repo, not from memory):

- `func NewHealthzHandler() http.Handler` exists in `pkg/handler/healthz.go`; it writes exactly `{"status":"ok"}` with `Content-Type: application/json` using `json.Marshal` (no trailing newline).
- `func CreateHealthzHandler() http.Handler` exists in `pkg/factory/factory.go` and returns `handler.NewHealthzHandler()`.
- `main.go` imports `libhttp "github.com/bborbe/http"`; after removing the readiness `NewPrintHandler` line it is still used by `libhttp.NewGarbageCollectorHandler()` and `libhttp.NewServer(...)`, so the import stays.

Open question for the reviewer (resolved in this prompt, flagged for audit): the spec's Constraints say `CreateReadinessHandler()` *may* simply return `handler.NewHealthzHandler()`, while Acceptance Criterion "handler makes no backend calls" greps `pkg/handler/readiness.go`. To satisfy both without duplicating the JSON body, this prompt creates a thin `NewReadinessHandler()` that delegates to `NewHealthzHandler()`. No response-body code is duplicated, so the two routes cannot drift apart.
</context>

<requirements>

## 1. Create the readiness handler

Create `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/handler/readiness.go` with exactly this content (the license header is required by `addlicense` inside `make precommit`):

```go
// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler

import "net/http"

// NewReadinessHandler creates an HTTP handler that serves the canonical readiness
// response. It delegates to NewHealthzHandler so both probe routes serve the
// identical `{"status":"ok"}` JSON contract and cannot drift apart. The handler is
// dependency-free: it performs no backend calls and reports only that the process
// is up and accepting traffic.
func NewReadinessHandler() http.Handler {
	return NewHealthzHandler()
}
```

Notes:
- Do NOT copy the JSON-writing code from `healthz.go`. Delegation is deliberate: the spec prefers reusing the existing handler over a second copy that could drift out of sync.
- Keep the doc comment free of lowercase backend words. Acceptance Criterion 8 runs `grep -cE 'kafka|bolt|kv\.|sentry' pkg/handler/readiness.go` and requires `0`; the wording above contains none of those tokens.
- Do not add `//nolint` directives.

## 2. Add the factory function

In `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/factory/factory.go`, append a new function after the existing `CreateHealthzHandler`. Leave the existing three functions unchanged. The existing imports (`net/http`, `handler`) already cover it, so add no imports:

```go
// CreateReadinessHandler creates an HTTP handler that serves the canonical
// `/readiness` response (HTTP 200, body `{"status":"ok"}`,
// Content-Type: application/json).
func CreateReadinessHandler() http.Handler {
	return handler.NewReadinessHandler()
}
```

## 3. Wire the route in main.go

In `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/main.go`, inside `createHTTPServer`, replace exactly this line:

```go
// Before
router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))

// After
router.Path("/readiness").Handler(factory.CreateReadinessHandler())
```

Rules for this edit:
- Keep the path string exactly `/readiness` and the HTTP method unconstrained (the existing route accepts `GET`). Do not add `.Methods(...)` or any middleware wrapper — the endpoint must stay unauthenticated and reachable by the bare k8s probe.
- Do not touch `/healthz`, `/metrics`, `/resetdb`, `/resetbucket/{BucketName}`, `/setloglevel/{level}`, `/gc`, `/testloglevel`, or `/sentryalert`.
- Do not modify the `application` struct, `Run`, `service.Run`, or `createHTTPServer`'s signature.
- Leave the `libhttp` import in place: it is still used by `libhttp.NewGarbageCollectorHandler()` and `libhttp.NewServer(...)`.

## 4. Add the handler test

Create `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/pkg/handler/readiness_test.go` with exactly this content (license header required):

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

	It("requires no auth, headers, or query parameters", func() {
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Code).To(Equal(http.StatusOK))
		Expect(resp.Body.String()).To(Equal(`{"status":"ok"}`))
	})
})
```

The four `It` blocks map one-to-one to the spec's Acceptance Criteria: status 200, exact body, content type, and the bare `httptest.NewRequest("GET", "/readiness", nil)` no-auth request shape. All four must pass. The suite runner already exists in `handler_suite_test.go`; do not add another.

## 5. Update CHANGELOG.md

In `/home/node/.cache/github-dark-factory-agent/work/a2562758-fe5e-505b-8799-367fde93dcc5/CHANGELOG.md`, add one bullet under the existing `## Unreleased` section, matching the file's `- feat:` prefix style:

```
- feat: serve `/readiness` as JSON (`{"status":"ok"}` with `Content-Type: application/json`), replacing the plain-text `OK` so both probe routes share one canonical response contract; route path and k8s readiness probe unchanged
```

Do not bump the version header and do not add a new version section.

</requirements>

<constraints>

- The `/readiness` route path and its readiness-probe role MUST NOT change. Both `k8s/skeleton-deploy.yaml` and `k8s/skeleton-sts.yaml` use `httpGet` with `path: /readiness` and no `responseContains`, so only the HTTP status matters — but the path must stay exactly `/readiness`.
- The handler MUST remain dependency-free: no DB, Kafka, Sentry, or other subsystem calls. Readiness reports that the process accepts traffic, not subsystem health (spec Non-goal 1 and Failure Mode row 3).
- Response body MUST be exactly `{"status":"ok"}` — no trailing newline, no surrounding whitespace, no extra fields. Delegating to `NewHealthzHandler()` guarantees this; do not re-implement the body.
- Response `Content-Type` MUST be exactly `application/json`.
- Do NOT modify `/healthz`, `/metrics`, `/resetdb`, `/resetbucket/{BucketName}`, `/setloglevel/{level}`, `/gc`, `/testloglevel`, `/sentryalert`, the `application` struct, `Run`, `service.Run`, or anything in `k8s/`.
- No new dependencies — do not edit `go.mod` or `go.sum`.
- Handler naming follows the repo's frozen convention: `func New<Name>Handler(...) http.Handler` in `pkg/handler/`, wired by `func Create<Name>Handler(...) http.Handler` in `pkg/factory/`.
- New `.go` files MUST carry the BSD license header — `addlicense` runs inside `make precommit` and fails the run without it.
- Tests use Ginkgo v2/Gomega with `httptest`; no `//nolint` without explanation; errors wrapped via `github.com/bborbe/errors` where applicable (this handler has no fallible call path).
- `make precommit` MUST pass. Existing tests MUST still pass.
- Do NOT commit — dark-factory handles git.

</constraints>

<verification>

Run these in order; each must succeed before moving to the next.

1. `go build ./...` — confirms `main.go` compiles after the route swap and the `libhttp` import is still needed.
2. `go test -mod=mod ./pkg/handler/ -v` — must exit 0 and list a `ReadinessHandler` spec whose `It` blocks assert status 200, the exact body, the content type, and the bare no-auth request.
3. `go test -mod=mod ./pkg/factory/` — must exit 0; confirms the factory package compiles with the new function.
4. `make precommit` — full `ensure format generate test check addlicense` pipeline; must exit 0.
5. `grep -c 'libhttp.NewPrintHandler' main.go` — must print `0`.
6. `grep -n 'router.Path("/readiness")' main.go` — must print exactly one line, and that line must contain `factory.CreateReadinessHandler()` with no middleware wrapper.
7. `grep -n 'factory.CreateReadinessHandler()' main.go` — must print exactly one line.
8. `grep -cE 'kafka|bolt|kv\.|sentry' pkg/handler/readiness.go` — must print `0`.
9. `git diff origin/master..HEAD -- k8s/` — must print nothing (no manifest changes).

If `go test -mod=mod ./pkg/handler/` fails on the exact-body assertion, check that `readiness.go` delegates to `NewHealthzHandler()` and did not re-implement the body with `json.NewEncoder` (which appends a trailing newline).

If `make precommit` fails on the license check, the header year/owner must match the existing files (`// Copyright (c) 2026 Benjamin Borbe All rights reserved.`).

</verification>
