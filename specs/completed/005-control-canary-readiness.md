---
status: completed
approved: "2026-10-22T07:17:04Z"
generating: "2026-10-22T07:25:50Z"
prompted: "2026-10-22T07:36:21Z"
verifying: "2026-10-22T07:52:51Z"
completed: "2026-10-22T07:52:58Z"
branch: dark-factory/control-canary-readiness
---

## Summary

- Add a readiness handler that answers `GET /readiness` with HTTP 200 and a JSON body exactly matching `{"status":"ok"}` and `Content-Type: application/json`.
- The existing `/readiness` route (currently a plain-text `OK` body from `libhttp.NewPrintHandler`) is replaced by this JSON response; the route path and its role as the k8s readiness probe target are unchanged.
- The endpoint is unauthenticated, static, and dependency-free.
- Ships as a pure code change via PR — no k8s manifest changes, no config changes, no new dependencies.

## Problem

`/healthz` already serves the canonical JSON liveness body `{"status":"ok"}`, but `/readiness` still answers with a plain-text `OK`. The skeleton therefore models two different probe-response contracts in the same service.

## Goal

`GET /readiness` returns HTTP 200 with a JSON body exactly `{"status":"ok"}` and `Content-Type: application/json`, reachable without authentication whenever the process is up and accepting traffic. The route path, the k8s readiness probe targeting it, and all other routes are unchanged.

## Non-goals

- No readiness-style dependency checks (Kafka, BoltDB, Sentry) in the response.
- No changes to `/healthz`, `/metrics`, `/resetdb`, `/resetbucket`, `/gc`, `/setloglevel`, `/testloglevel`, or `/sentryalert`.
- No changes to k8s manifests or probe configuration.

## Requirements

- `GET /readiness` responds `200` with body `{"status":"ok"}` and `Content-Type: application/json`.
- The response body is byte-identical to the `/healthz` body.
- A unit test covers the handler's status code, content type, and body.
- `make precommit` passes.

## Acceptance

- `curl -s localhost:8080/readiness` prints `{"status":"ok"}`.
- `curl -sI localhost:8080/readiness` shows `200` and `Content-Type: application/json`.
- The existing `/healthz` behaviour is unchanged.
