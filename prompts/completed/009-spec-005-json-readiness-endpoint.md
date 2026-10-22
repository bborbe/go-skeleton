---
status: completed
spec: [005-control-canary-readiness]
summary: Made GET /readiness return 200 with exact JSON body {"status":"ok"} and Content-Type application/json via a new dependency-free handler, factory wiring, and Ginkgo tests
execution_id: 2ac1a154-1145-40d3-bd45-785372d3d96d-exec-009-spec-005-json-readiness-endpoint
dark-factory-version: dev
created: "2026-10-22T07:27:58Z"
queued: "2026-10-22T07:42:16Z"
started: "2026-10-22T07:42:18Z"
completed: "2026-10-22T07:52:51Z"
branch: dark-factory/control-canary-readiness
---

# JSON readiness endpoint

<summary>
- `/readiness` now returns a JSON body `{"status":"ok"}` instead of the plain-text `OK`.
- The response carries `Content-Type: application/json`.
- The route path and HTTP method (`GET`) stay unchanged, so the k8s readiness probe in both manifests still targets it.
- The response is byte-identical to the `/healthz` body, so the service models one probe-response contract, not two.
- The handler stays dependency-free: it never consults Kafka, BoltDB, Sentry, or any other subsystem.
- A new handler lives in `pkg/handler/`, wired through `pkg/factory/`, replacing the inline `libhttp.NewPrintHandler("OK")` in `main.go`.
- A Ginkgo v2/Gomega unit test (httptest) asserts the status code, exact body, and content type.
- No new dependencies, no manifest changes, no other routes touched, no config knobs added.

</summary>

<objective>
Make `GET /readiness` return HTTP 200 with the exact JSON body `{"status":"ok"}` and `Content-Type: application/json`, reachable unauthenticated whenever the process is up. The route path stays `/readiness` and the k8s readiness probes in `k8s/skeleton-deploy.yaml` and `k8s/skeleton-sts.yaml` continue to target it unchanged.
</objective>

<context>
Read `CLAUDE.md` if present for project conventions; otherwise follow the existing package patterns below. Read these files before changing anything:

- `main.go` — router wiring inside `createHTTPServer`. The readiness route is currently `router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))`. The neighbouring `/healthz` route is already `router.Path("/healthz").Handler(factory.CreateHealthzHandler())`.
- `pkg/handler/healthz.go` — the handler this one must mirror byte-for-byte in response shape. `func NewHealthzHandler() http.Handler` uses `json.Marshal` + raw `resp.Write` specifically to avoid a trailing newline.
- `pkg/handler/healthz_test.go` — the test layout to mirror (three `It` blocks: status, exact body, content type).
- `pkg/factory/factory.go` — existing factory functions (`CreateTestLoglevelHandler`, `CreateSentryAlertHandler`, `CreateHealthzHandler`) are the pattern to follow.
- `pkg/handler/sentry-alert.go` — established handler signature style (`func New<Name>Handler(...) http.Handler`) and the `_, _ = resp.Write(...)` error-discard idiom.
- `k8s/skeleton-deploy.yaml` and `k8s/skeleton-sts.yaml` — the readiness probes point at `path: /readiness`, port 9090. DO NOT modify either file.
- `CHANGELOG.md` — the `## Unreleased` section where the new bullet goes.

Reference docs (inside the YOLO container):

- `/home/node/.claude/plugins/marketplaces/coding/docs/go-http-handler-refactoring-guide.md` — handler naming (`New<Purpose>Handler`), factory wiring (`Create<Purpose>Handler`), and kebab-case handler filenames.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-factory-pattern.md` — factory layer conventions.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-testing-guide.md` — Ginkgo v2/Gomega conventions (no stdlib table tests, no direct `*testing.T` in suite packages).
- `/home/node/.claude/plugins/marketplaces/coding/docs/changelog-guide.md` — conventional `feat:` / `fix:` prefix style and `## Unreleased` placement.

Library API verified by reading source (`github.com/bborbe/http`, pinned at `v1.26.30` in `go.mod`; the checked-out module cache copy is `v1.26.16`, whose constants are unchanged):

- `http.NewPrintHandler(format string, a ...any) http.Handler` — currently used; writes plain text via `fmt.Fprintf` with NO Content-Type. This is what we replace.
- `http.NewJSONHandler(jsonHandler JSONHandler) WithError` — uses `json.NewEncoder(resp).Encode(result)`, which APPENDS A TRAILING `\n`. **Do not use this** — the spec requires the body to exactly equal `{"status":"ok"}` with no extra bytes.
- `http.ApplicationJSONContentType = "application/json"` and `http.ContentTypeHeaderName = "Content-Type"` — the canonical constants for the header.

So this handler must call `json.Marshal` and write the raw bytes to the response, exactly as `NewHealthzHandler` does.
</context>

<requirements>

## 1. Create the readiness handler file

Create `pkg/handler/readiness.go`, mirroring `pkg/handler/healthz.go` exactly except for the name and doc comment. Use the repo license header (copy from `pkg/handler/healthz.go`, year `2026`):

```go
// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler

import (
	"encoding/json"
	"net/http"

	libhttp "github.com/bborbe/http"
)

// NewReadinessHandler creates an HTTP handler that serves the canonical
// readiness response. It returns HTTP 200 with body `{"status":"ok"}` and
// Content-Type: application/json. The handler is dependency-free: it never
// touches Kafka, BoltDB, Sentry, or any other subsystem, so it reports only
// whether the process is up and accepting traffic.
func NewReadinessHandler() http.Handler {
	return http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
		resp.Header().Add(libhttp.ContentTypeHeaderName, libhttp.ApplicationJSONContentType)
		// Use json.Marshal + write raw bytes instead of json.NewEncoder.Encode
		// so the response body is exactly {"status":"ok"} with no trailing newline.
		body, err := json.Marshal(struct {
			Status string `json:"status"`
		}{Status: "ok"})
		if err != nil {
			// Marshal of a static struct literal cannot fail in practice; if it
			// ever does, fall back to the exact bytes which are guaranteed valid JSON.
			body = []byte(`{"status":"ok"}`)
		}
		_, _ = resp.Write(body)
	})
}
```

Notes:
- The `_, _ = resp.Write(body)` intentionally discards the error, matching `pkg/handler/sentry-alert.go`. For an unauthenticated static ~15-byte write to a live listener, a failed `Write` only means the client hung up; there is nothing to recover to.
- No imports for `context`, `errors`, `libkv`, or `libsentry`. The handler must remain dependency-free so the readiness probe never reflects subsystem health (spec Non-goals).
- No `//nolint` directives.

## 2. Add the factory function

In `pkg/factory/factory.go`, append a new factory function after `CreateHealthzHandler`, following the existing pattern:

```go
// CreateReadinessHandler creates an HTTP handler that serves the canonical
// `/readiness` response (HTTP 200, body `{"status":"ok"}`,
// Content-Type: application/json).
func CreateReadinessHandler() http.Handler {
	return handler.NewReadinessHandler()
}
```

The existing import block already covers `net/http` and the `handler` package — no new imports.

## 3. Wire the route in main.go

In `main.go`, inside `createHTTPServer`, replace the readiness line:

```go
// Before
router.Path("/readiness").Handler(libhttp.NewPrintHandler("OK"))

// After
router.Path("/readiness").Handler(factory.CreateReadinessHandler())
```

Leave `/healthz` and every other route untouched. Do not modify the `application` struct, `Run`, `service.Run`, or `libhttp.NewServer`. After the edit, confirm `libhttp` is still referenced in `main.go` — it is, by `libhttp.NewGarbageCollectorHandler()` and `libhttp.NewServer(...)`, so the import stays.

## 4. Add the handler test

Create `pkg/handler/readiness_test.go`, mirroring `pkg/handler/healthz_test.go`:

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
})
```

Three `It` blocks — one per spec requirement (status, exact body, content type). All three must pass. The existing `pkg/handler/handler_suite_test.go` already provides the Ginkgo suite entry point, so do not add another `TestSuite` function.

## 5. Update CHANGELOG.md

In `CHANGELOG.md`, add a new bullet at the top of the existing `## Unreleased` section, following the `feat:` prefix style:

```
- feat: serve `/readiness` as JSON (`{"status":"ok"}` with `Content-Type: application/json`) so it matches the `/healthz` liveness contract; route path and k8s readiness probes unchanged
```

Do not bump the version header. Do not add a new `##` version section. Do not edit the preamble.

</requirements>

<constraints>
- The `/readiness` route path, HTTP method (`GET`), and k8s readiness-probe role MUST NOT change (spec Goal + Non-goals).
- The handler MUST remain dependency-free — no DB, Kafka, Sentry, or other subsystem calls (spec Non-goal: "No readiness-style dependency checks (Kafka, BoltDB, Sentry) in the response").
- Response body MUST be exactly `{"status":"ok"}` — NO trailing newline, NO surrounding whitespace, NO extra fields. This is why `libhttp.NewJSONHandler` is the wrong tool (it uses `json.NewEncoder.Encode`, which appends `\n`); the handler MUST use `json.Marshal` + raw `resp.Write`.
- Response body MUST be byte-identical to the `/healthz` body (spec Requirement #2), which the identical `json.Marshal` of the same struct shape guarantees.
- Response `Content-Type` MUST be exactly `application/json`. Use the constant `libhttp.ApplicationJSONContentType`.
- Do NOT modify `/healthz`, `/metrics`, `/resetdb`, `/resetbucket/{BucketName}`, `/setloglevel/{level}`, `/gc`, `/testloglevel`, `/sentryalert`, the `application` struct, `Run`, `service.Run`, `libkafka`, `libboltkv`, `libmetrics`, `libsentry`, `libhttp.NewServer`, or anything in `k8s/`. The change is scoped to the readiness response.
- No new dependencies — do not edit `go.mod` or `go.sum`.
- Do NOT add configurability, feature flags, opt-out knobs, or tunable thresholds. The spec ships one static response; there is nothing to configure.
- Do NOT add Prometheus metrics. The spec's observability surface is unchanged.
- Handler naming follows the repo convention: `func New<Name>Handler(...) http.Handler` in `pkg/handler/`, wired by `func Create<Name>Handler(...) http.Handler` in `pkg/factory/`.
- Tests use Ginkgo v2 / Gomega with `httptest`. No `//nolint` without explanation.
- `make precommit` MUST pass (format + generate + test + lint + security checks).
- Existing tests MUST still pass.
- Do NOT commit — dark-factory handles git.
</constraints>

<verification>
Run these commands in order. Each must succeed before moving to the next:

1. `go build ./...` — confirms `main.go` still compiles after the route wiring change.
2. `go test -mod=mod ./pkg/handler/` — must pass and include the three new `ReadinessHandler` `It` blocks. Run with `-v` if you need the Ginkgo reporter output.
3. `go test -mod=mod ./pkg/factory/` — must pass; confirms the factory package still compiles after the new factory function lands.
4. `make precommit` — full format + generate + test + lint + security pipeline. Must exit 0.

If the exact-body assertion fails, the most likely cause is the `json.NewEncoder` newline issue described in `<context>` — re-check that the handler uses `json.Marshal` + `resp.Write`, NOT `libhttp.NewJSONHandler`.

If lint complains about the header name, the constant form `libhttp.ContentTypeHeaderName` (`"Content-Type"`) is the canonical reference; `healthz.go` already uses it without issue.
</verification>
