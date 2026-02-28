# Go Skeleton Improvement Backlog

This file captures concrete improvements for this skeleton so we can implement them step by step.

## Priority Legend

- `HIGH`: reliability/security risk, should be addressed first
- `MEDIUM`: important template quality and maintainability improvements
- `LOW`: useful hardening/cleanup

## 1. Nil-safe Sentry alert handler

- Priority: `HIGH`
- Area: `pkg/handler/sentry-alert.go`
- Problem:
  - Handler dereferences `*result` from `CaptureException` without checking for `nil`.
  - If the Sentry client returns `nil`, endpoint panics.
- Suggestion:
  - Add nil check before formatting response.
  - Return a stable fallback message when event ID is unavailable.
- Acceptance criteria:
  - Endpoint never panics when Sentry returns `nil`.
  - Unit test covers nil return path.

## 2. Restrict dangerous/debug endpoints

- Priority: `HIGH`
- Area: `main.go` router (`/resetdb`, `/resetbucket/{BucketName}`, `/setloglevel/{level}`, `/gc`, `/testloglevel`, `/sentryalert`)
- Problem:
  - Operational and test endpoints are exposed on same server as health/readiness/metrics.
  - In production this can become a security and stability risk.
- Suggestion:
  - Gate endpoints by env/config flag (e.g. `ENABLE_DEBUG_ENDPOINTS=false` by default).
  - Optional: protect with auth or IP allowlist.
- Acceptance criteria:
  - Sensitive endpoints disabled by default.
  - Explicit config required to enable in dev/ops use cases.

## 3. Real readiness checks

- Priority: `HIGH`
- Area: `main.go` `/readiness`
- Problem:
  - Readiness always returns `OK`, independent of Kafka/DB state.
  - Service may receive traffic while dependencies are unavailable.
- Suggestion:
  - Implement readiness probe that validates required dependencies.
  - Keep `/healthz` as lightweight process liveness signal.
- Acceptance criteria:
  - `/readiness` fails when mandatory dependencies are not ready.
  - Behavior documented in README.

## 4. Remove or wire currently unused Kafka clients

- Priority: `MEDIUM`
- Area: `main.go`
- Problem:
  - Sarama client and sync producer are initialized and closed but not used.
  - Adds startup failure coupling and confusion in a template.
- Suggestion:
  - Either remove from baseline skeleton, or connect to actual producer/consumer example logic.
- Acceptance criteria:
  - No unused critical dependencies created on startup.
  - Template intent is clear from code and README.

## 5. Align Sentry requirement between code and docs

- Priority: `MEDIUM`
- Area: `main.go`, `README.md`
- Problem:
  - Code marks `SENTRY_DSN` as required.
  - README says required only for production.
- Suggestion:
  - Choose one behavior and align both implementation + documentation.
  - Recommended: optional in local development, enforced in production mode.
- Acceptance criteria:
  - No contradiction between runtime behavior and README configuration table.

## 6. Parameterize template-specific constants

- Priority: `MEDIUM`
- Area: `pkg/build-info-metrics.go`, `k8s/*.yaml`
- Problem:
  - Hardcoded values (`trading` metric namespace, image name/service labels) leak source project context.
- Suggestion:
  - Parameterize service/namespace/image naming.
  - Keep defaults generic and clearly replaceable.
- Acceptance criteria:
  - New users do not need broad search/replace to remove domain-specific values.

## 7. Make dependency bootstrap portable

- Priority: `MEDIUM`
- Area: `Makefile` target `deps`
- Problem:
  - `sudo port install trivy` is platform-specific (macOS + MacPorts) and requires elevated privileges.
- Suggestion:
  - Replace with cross-platform install guidance or run tooling via containerized/pinned binaries.
- Acceptance criteria:
  - `deps` works on common dev setups (Linux/macOS) without privileged package manager assumptions.

## 8. Strengthen tests beyond smoke checks

- Priority: `LOW`
- Area: `main_test.go`, `pkg/handler/*_test.go`
- Problem:
  - Current tests mostly check compile/status code/basic invocation.
- Suggestion:
  - Add failure-path coverage:
    - nil Sentry result
    - readiness failure behavior
    - endpoint gating configuration
- Acceptance criteria:
  - Tests catch expected regressions for key operational behavior.

## 9. Harden container runtime defaults

- Priority: `LOW`
- Area: `Dockerfile`, `k8s/*.yaml`
- Problem:
  - Runtime user/security context is not explicitly hardened.
- Suggestion:
  - Run as non-root UID/GID and set restrictive container security context.
- Acceptance criteria:
  - Container runs as non-root by default.
  - K8s manifests include explicit security context where appropriate.

## 10. Isolate tool dependencies from app module graph

- Priority: `LOW`
- Area: `go.mod`, `tools.go`
- Problem:
  - Tooling dependencies are direct module requirements, inflating dependency graph for consumers of template.
- Suggestion:
  - Move tools to separate `tools/go.mod` or pin via dedicated tooling container.
- Acceptance criteria:
  - Application module dependency graph is focused on runtime/test requirements.

## Suggested Implementation Order

1. Nil-safe Sentry handler + tests
2. Endpoint gating + docs
3. Real readiness checks + tests
4. Kafka startup cleanup
5. Config/docs alignment
6. Template parameterization
7. Dev tooling portability
8. Container hardening
9. Tool dependency isolation
