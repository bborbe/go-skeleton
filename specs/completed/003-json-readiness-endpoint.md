---
status: completed
approved: "2026-10-20T21:46:45Z"
generating: "2026-10-20T23:46:04Z"
prompted: "2026-10-20T23:46:44Z"
verifying: "2026-10-21T00:00:11Z"
completed: "2026-10-21T00:00:18Z"
branch: dark-factory/json-readiness-endpoint
---

## Summary

- Add a readiness handler that answers `GET /readiness` with HTTP 200 and a JSON body exactly matching `{"status":"ok"}` and `Content-Type: application/json`.
- The existing `/readiness` route (currently a plain-text `OK` body from `libhttp.NewPrintHandler`) is replaced by this JSON response; the route path and its role as the k8s readiness probe target are unchanged.
- The endpoint is unauthenticated, static, and dependency-free: it reports that the process is ready to accept traffic, never the health of Kafka, BoltDB, or Sentry.
- Ships as a pure code change via PR — no k8s manifest changes, no config changes, no new dependencies.

## Problem

`/healthz` already serves the canonical JSON liveness body `{"status":"ok"}`, but `/readiness` still answers with a plain-text `OK`. The skeleton therefore models two different probe-response contracts in the same service, and the one every cloned service inherits is the inconsistent pair. A service copied from this template starts life with two probe routes that disagree on their response shape.

## Goal

`GET /readiness` returns HTTP 200 with a JSON body exactly `{"status":"ok"}` and `Content-Type: application/json`, reachable without authentication whenever the process is up and accepting traffic. The route path, the k8s readiness probe targeting it, and all other routes are unchanged.

## Non-goals

- No readiness-style dependency checks (Kafka, BoltDB, Sentry) in the response.
- No changes to `/healthz`, `/metrics`, `/resetdb`, `/resetbucket`, `/gc`, `/setloglevel`, `/testloglevel`, or `/sentryalert`.
- No changes to k8s manifests or probe configuration.
- No authentication, rate limiting, or access logging on `/readiness`.
- No body fields beyond `status`.
- Keeping the plain-text body alongside a JSON one, or serving JSON only on a new path, was considered and rejected — the contract is one canonical JSON response on the existing probe path.

## Desired Behavior

1. `GET /readiness` returns HTTP status 200 whenever the process is up and accepting traffic.
2. The response body is the exact JSON document `{"status":"ok"}`.
3. The response `Content-Type` header is `application/json`.
4. The endpoint requires no auth, no headers, no query parameters, and no request body.
5. The route is served at exactly `/readiness` and remains the k8s readiness probe target (probe config untouched).
6. The handler makes no backend calls (DB, Kafka, Sentry) — readiness reports that the process accepts traffic, not subsystem health.

## Acceptance Criteria

- [ ] `GET /readiness` returns HTTP 200 — evidence: the Ginkgo `ReadinessHandler` spec in `pkg/handler/` asserts `resp.Code == http.StatusOK`; `go test -mod=mod ./pkg/handler/` exits 0.
- [ ] Response body exactly matches `{"status":"ok"}` — evidence: the same spec asserts `resp.Body.String() == "{\"status\":\"ok\"}"` (no extra fields, no surrounding whitespace, no trailing newline).
- [ ] Response `Content-Type` header starts with `application/json` — evidence: the same spec asserts `resp.Header().Get("Content-Type") == "application/json"`.
- [ ] The plain-text wiring is gone and the JSON handler is wired — evidence: `grep -c 'libhttp.NewPrintHandler' main.go` returns 0, and `grep -n 'factory.CreateReadinessHandler()' main.go` returns exactly 1 line.
- [ ] The route is still declared exactly once at `/readiness` — evidence: `grep -n 'router.Path("/readiness")' main.go` returns exactly 1 line.
- [ ] No change to k8s probe manifests — evidence: `git diff origin/master..HEAD -- k8s/` returns empty.
- [ ] The endpoint needs no auth — evidence: the same Ginkgo spec drives the handler with `httptest.NewRequest("GET", "/readiness", nil)` — no headers, cookies, or query — and still asserts 200; `grep -n 'readiness' main.go` shows the bare `router.Path(...)` line with no middleware wrapper.
- [ ] The handler makes no backend calls — evidence: `grep -cE 'kafka|bolt|kv\.|sentry' pkg/handler/readiness.go` returns 0.

## Verification

### Container-executable (runs inside the YOLO container at prompt time)

- `make precommit` exits 0 — format + generate + lint + test + security checks (includes the license-header check).
- `make test` exits 0 — full suite including the new handler test.
- `go test -mod=mod ./pkg/handler/ -v` exits 0 and lists a `ReadinessHandler` spec whose `It` blocks assert status 200, the exact body, the content type, and the no-auth request shape.
- `grep -c 'libhttp.NewPrintHandler' main.go` prints `0`.
- `grep -n 'router.Path("/readiness")' main.go` prints exactly one line.
- `git diff origin/master..HEAD -- k8s/` prints nothing.

The behavior in Desired Behavior 1–3 is observed through an `httptest`-driven Ginkgo spec rather than a live socket, because the service cannot boot in the container (its config marks `KAFKA_BROKERS` and `DATADIR` required).

## Constraints

- The `/readiness` route path and its readiness-probe role must not change.
- Handler code follows the repo's frozen conventions: HTTP handlers in `pkg/handler/` as `New<Name>Handler() http.Handler`; DI wiring via factory functions in `pkg/factory/` as `Create<Name>Handler()` (bcom-style service framework).
- `main.go` wiring swaps `libhttp.NewPrintHandler("OK")` on the `/readiness` route for `factory.CreateReadinessHandler()`; no other route changes.
- `CreateReadinessHandler()` may simply return `handler.NewHealthzHandler()` — both routes serve the identical `{"status":"ok"}` contract, and reusing the existing handler is preferred over a second copy that could drift back out of sync.
- New files carry the repo's BSD license header — `addlicense` runs inside `make precommit` and fails the run without it (see `pkg/handler/healthz.go:1-3`).
- Add an `## Unreleased` bullet to `CHANGELOG.md` describing the readiness JSON contract.
- Tests use Ginkgo v2/Gomega with `httptest` (Counterfeiter for mocks); errors wrapped via `github.com/bborbe/errors`; no `//nolint` without explanation.
- Assumption: the k8s readiness probe checks HTTP status only — both probe manifests (`k8s/skeleton-deploy.yaml`, `k8s/skeleton-sts.yaml`) use `httpGet` with no `responseContains` — so changing the response body does not affect probe behavior.
- Assumption: nothing in the repo parses the current plain-text `OK` body. Verified at authoring time: the only reference to the route is `main.go`'s wiring line; no Go code reads the body.
- `make precommit` must pass; no new dependencies.

## Failure Modes

| Trigger | Expected behavior | Recovery |
|---|---|---|
| Handler returns non-200 or wrong body after change | Targeted handler test fails; readiness probe would flap in future deploys | Fix handler to return 200 + exact body; re-run `go test -mod=mod ./pkg/handler/` until green |
| Content-Type missing or wrong | Handler test asserting the header fails | Set `application/json` on the response; re-run the targeted test |
| Handler wired to backend deps (DB/Kafka) | Readiness starts reflecting subsystem health; test with deps absent fails | Keep handler dependency-free (static response); `grep -cE 'kafka\|bolt\|kv\.\|sentry' pkg/handler/readiness.go` returns 0 |
| Route path or method changed (e.g. GET→POST) | k8s readiness probe (GET) stops reaching the route while the manifest is unchanged | Restore `GET /readiness`; confirm the probe path in the manifest is still `/readiness` |
| Out-of-scope files changed (other routes, manifests) | `git diff origin/master..HEAD -- k8s/` non-empty; unrelated route tests fail | Revert out-of-scope changes; keep the PR scoped to the readiness change |

## Security / Abuse Cases

`/readiness` is an unauthenticated public endpoint serving a static ~15-byte response. It accepts no user input, performs no state mutation, touches no filesystem or network, and reflects no attacker-controlled data, so the abuse surface is minimal: no injection, no amplification (tiny static body), no sensitive-data exposure (the body is fixed and contains no versions, config, or environment information). No auth or rate limiting is warranted — the endpoint is the readiness probe path and must stay reachable by the unauthenticated k8s probe.

## Suggested Decomposition

| # | Prompt focus | Covers DBs | Covers ACs | Depends on |
|---|---|---|---|---|
| 1 | Readiness handler + factory wiring + Ginkgo test | 1–6 | 1–8 | — |

Rationale: one layer, one behavior; a single prompt covers it.

## Do-Nothing Option

If not done, `/readiness` keeps returning plain-text `OK`. The readiness probe still works (status 200), so the operational cost is low — but the skeleton keeps modeling a two-contract probe surface, and every service cloned from it inherits the inconsistency. Doing it now is a small change; deferring leaves the wrong example in the template indefinitely.
