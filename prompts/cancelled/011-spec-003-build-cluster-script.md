---
status: cancelled
spec: [003-build-target]
created: "2026-10-25T14:35:00Z"
queued: "2026-10-25T14:24:40Z"
cancelled: "2026-10-25T14:24:49Z"
---

# Add the cluster build script that renders and runs the build Job

<summary>
- A single script turns the parameterized build Job into a running cluster build: it renders the template, applies it, waits, and reports the result.
- It refuses to run with a missing or empty git ref rather than silently building the default branch.
- It exits non-zero when the build fails, and prints the build pod's own log so the cause is visible without a second command.
- On success it prints the image digest the build pushed, so the caller can record it.
- The template it renders is the one from the previous prompt; the script does not duplicate the manifest.
- It works with any repository, not just this one, because every value comes from its environment.
- The default local build path never reaches this script.
</summary>

<objective>
Author `hack/build-cluster.sh`: the receiving end of `make build`'s cluster branch. It renders `hack/build-job.yaml` with the run's values, applies the Job to the named cluster, waits for a terminal state, and reports the digest — so a release image can be built without the invoking machine's Docker daemon.
</objective>

<context>
Read these files before writing:

- `specs/in-progress/003-build-target.md` — read "Desired Behavior" items 2, 3, 4, 8 and the "Failure Modes" table.
- `Makefile.docker` — its `else` branch invokes this script with these environment variables, and they are the script's entire interface. Do not add, rename or reorder them.
- `hack/build-job.yaml` — the template this script renders. Read its `__TOKEN__` placeholders; the names must match exactly.
- `k8s/Makefile` and `Makefile.k8s` — the repo's existing `kubectl` invocation style.

Script interface, fixed by `Makefile.docker` (treat as a contract):

| variable | meaning | required |
|---|---|---|
| `BUILD_TARGET` | kubectl context / cluster name to build on | yes |
| `NAMESPACE` | namespace holding the build Job | yes, defaults to `build` in the Makefile |
| `REPO_URL` | git URL to clone | yes |
| `REF` | git ref (branch, tag or commit) to build | yes — refuse if empty |
| `TAG` | image tag to push | yes |
| `DOCKERFILE` | Dockerfile path inside the repository | yes |
| `IMAGE` | target image repository, without tag | yes |
| `PUSH` | `true` or `false` | yes |
| `TIMEOUT` | seconds to wait for the Job | yes |

`SOURCE_DATE_EPOCH` is not passed in — this script derives it from `REF` itself, because a `$(shell git …)` in the Makefile would interpolate a caller-supplied ref into a shell string.

The cluster wrapper: `kubectl` here must be invoked as `kubectl --context "$BUILD_TARGET"`. Do not hardcode any cluster name; `BUILD_TARGET` is the only source.
</context>

<requirements>

## 1. Create `hack/build-cluster.sh`

Executable, `#!/usr/bin/env bash`, `set -euo pipefail`. Read every variable from the environment; define none of them. Guard each required variable at the top and exit 2 with a message naming the variable when it is empty. `REF` is the one whose absence must be a hard refusal: an empty ref means "build the default branch", which is the exact silent wrong-source failure the spec exists to prevent.

## 2. Derive the pinned clock from `REF`

Resolve `REF` to a commit and take its timestamp as `SOURCE_DATE_EPOCH` (decimal seconds). A ref that does not resolve must exit non-zero with a message naming the ref — do not fall back to `HEAD`.

## 3. Render the template

Read `hack/build-job.yaml` from the repository root (resolve the root from the script's own location, not from the caller's working directory, so the script works from any cwd). Substitute every `__TOKEN__` placeholder with its value: repo URL, ref, tag, Dockerfile path, image, push flag, Job name, deadline seconds and the epoch from step 2. Write the rendered manifest to a temp file and clean it up on exit.

The Job name must be `build-<tag>` sanitized to a valid DNS-1123 label (lowercase, `.` and `_` to `-`, truncate to 63 characters). A tag that sanitizes to an empty name must be refused.

Refuse to render if any placeholder remains after substitution — a leftover `__TOKEN__` means the template gained a token this script does not fill, and applying it would ship a manifest with a literal placeholder.

## 4. Apply, wait, report

Apply the rendered manifest with `kubectl --context "$BUILD_TARGET" -n "$NAMESPACE" apply -f <rendered>`.

Wait for the Job to reach a terminal state, bounded by `TIMEOUT`. Poll `kubectl … get job <name> -o jsonpath='{.status.succeeded}{" "}{.status.failed}'` rather than using `kubectl wait`, so a failed Job is detected as fast as a succeeded one.

- **Success** (`succeeded >= 1`): print the build pod's log, and print the image digest on its own line in the form `digest: <sha256:…>`, taken from the `containerimage.digest` value the Job cats from its metadata file. Exit 0.
- **Failure** (`failed >= 1`, or the deadline elapsed): print the build pod's log tail, then the Job's events, then exit non-zero. The deadline case must name the timeout value it waited.

Never leave a failed Job behind silently: print its name so the operator can inspect or delete it. Do not delete it automatically — a failed build's pod log is the evidence.

## 5. Render-only mode for verification

Support `RENDER_ONLY=1` in the environment: render, print the manifest to stdout, and exit 0 without touching a cluster. This is what makes the script verifiable inside the build container, which has no `kubectl` and no cluster credentials. It must still perform every guard and every substitution.

## 6. Do not touch anything else

Do not edit `hack/build-job.yaml`, `Makefile.docker`, `Dockerfile`, `k8s/`, or any Go file. Do not add a `## Unreleased` CHANGELOG bullet — the last prompt in this series owns it.

## 7. Self-check before finishing

Re-run every command in `<verification>` and confirm each passes. Then walk the spec's Acceptance Criteria 5, 6 and 10 against the change and confirm none is contradicted.

</requirements>

<constraints>

- The script is the only file this prompt creates. `hack/build-job.yaml` already exists from the previous prompt.
- Repo-relative paths only. Resolve the repo root from the script's location (`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`), never from the caller's cwd.
- `BUILD_TARGET` is the only cluster selector. Never hardcode a cluster name, a context, or a namespace.
- The script must never write, print or copy a registry credential. The credential lives in the cluster secret the Job mounts; the script only renders a reference to it.
- No new runtime dependency in the built image; this is build tooling only.
- The local build path must never reach this script — it is invoked only from `Makefile.docker`'s `else` branch.
- Do NOT commit — dark-factory handles git.
- Existing tests must still pass.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `bash -n hack/build-cluster.sh` — syntax is valid.
2. `test -x hack/build-cluster.sh` — the file is executable.
3. `command -v shellcheck >/dev/null && shellcheck hack/build-cluster.sh` — no findings; skip cleanly if shellcheck is absent.
4. `grep -q 'set -euo pipefail' hack/build-cluster.sh` — strict mode is on.
5. `! grep -qE 'kubectl[^|]*--context *"?[a-z0-9-]+' hack/build-cluster.sh` — no hardcoded context. Prove the pattern fires first: `echo 'kubectl --context prod get pods' | grep -qE 'kubectl[^|]*--context *"?[a-z0-9-]+'` must succeed.
6. `RENDER_ONLY=1 BUILD_TARGET=test NAMESPACE=build REPO_URL=https://example.test/r.git REF=v0.0.0 TAG=proof DOCKERFILE=Dockerfile IMAGE=example.test/img PUSH=true TIMEOUT=60 bash hack/build-cluster.sh > /tmp/rendered.yaml` — exits 0 and writes a manifest.
7. `! grep -q '__[A-Z_]*__' /tmp/rendered.yaml` — no placeholder survived rendering.
8. `grep -q 'name: build-proof' /tmp/rendered.yaml` — the Job name is derived from the tag.
9. `! RENDER_ONLY=1 BUILD_TARGET=test NAMESPACE=build REPO_URL=https://example.test/r.git REF= TAG=proof DOCKERFILE=Dockerfile IMAGE=example.test/img PUSH=true TIMEOUT=60 bash hack/build-cluster.sh` — an empty `REF` is refused (non-zero exit). Prove the command form fails for the right reason by capturing stderr and confirming it names `REF`.
10. `ROOTDIR=/workspace make precommit` — must exit 0.

</verification>
