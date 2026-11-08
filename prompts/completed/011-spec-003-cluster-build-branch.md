---
status: completed
spec: [003-build-target]
summary: Added hack/build-cluster.sh, which validates inputs, renders hack/build-job.yaml, applies it to the target kubectl context, waits for the Job, and reports the digest or the log tail; Makefile.docker already matched the contract and the CHANGELOG entry was added.
execution_id: go-skeleton-build-target-exec-011-spec-003-cluster-build-branch
dark-factory-version: v0.198.7
created: "2026-10-25T14:21:43Z"
queued: "2026-10-25T14:24:49Z"
started: "2026-10-25T14:26:23Z"
completed: "2026-10-25T14:28:37Z"
---

# Add the cluster build branch: render, apply, wait, report

<summary>
- Naming a cluster in the build selector now actually builds there: the Job manifest is filled in with this run's values and applied to the cluster.
- The make target blocks until the Job finishes instead of returning as soon as the Job is created.
- A successful build prints the image digest it pushed, so the caller does not need a second tool to find it.
- A failed build exits non-zero and prints the end of the build log, so the cause is visible without a separate kubectl call.
- A cluster name the kubeconfig does not know is rejected before anything is rendered, and the error lists the names that would work.
- Inputs are checked against a strict character whitelist before they are substituted into the manifest, so a crafted git ref cannot inject anything.
- Re-running a build whose Job still exists refuses rather than silently overwriting a running build.
- The local build path is untouched by this change.
</summary>

<objective>
Implement `hack/build-cluster.sh`, the receiver that `make build BUILD_TARGET=<cluster>` already calls: validate the run's inputs, render `hack/build-job.yaml`, apply it to the `build` namespace, wait for a terminal state, and report the digest on success or the log tail on failure. This is the only part of the feature that talks to a cluster, so every failure must be loud and attributable.
</objective>

<context>
Read these files before writing:

- `specs/in-progress/003-build-target.md` — read "Desired Behavior" items 2, 3, 7, 8 and the whole "Failure Modes" table; each row is a requirement below.
- `Makefile.docker` — its `build` target's `else` branch calls `hack/build-cluster.sh` with these environment variables, which the script must consume by exactly these names: `BUILD_TARGET`, `NAMESPACE`, `REPO_URL`, `REF`, `TAG`, `DOCKERFILE`, `IMAGE`, `PUSH`, `TIMEOUT`.
- `hack/build-job.yaml` — the template written by the previous prompt. Read it in full. It carries nine tokens: `__JOB_NAME__`, `__REPO_URL__`, `__REF__`, `__TAG__`, `__DOCKERFILE__`, `__IMAGE__`, `__PUSH__`, `__DEADLINE_SECONDS__`, `__SOURCE_DATE_EPOCH__`.
- `Makefile.k8s` — shows how this repo talks to a cluster: `kubectl --context=${CLUSTER_CONTEXT}`. `BUILD_TARGET` is a kubectl context name for the same reason.
- `k8s/skeleton-deploy.yaml` — the namespace and label conventions used elsewhere in the repo.

Design decisions this prompt fixes, so do not re-litigate them:

- **A cluster is a kubectl context.** The accepted values are whatever `kubectl config get-contexts -o name` reports. This distinguishes "unknown target" (not in the kubeconfig, detected offline) from "cluster unreachable" (known context, API call fails), which are two different rows of the spec's Failure Modes table.
- **The clock is resolved on the invoking machine and rendered literally** into the Job, because Acceptance Criterion 7 requires the Job's args to contain a literal `--opt build-arg:SOURCE_DATE_EPOCH=<epoch>`. The template's init container re-derives the epoch from the cloned commit and the build container refuses to run if the two disagree, which is what Desired Behavior 4 asks for and also catches a stale local checkout. An explicit `SOURCE_DATE_EPOCH` in the environment wins over the derivation, for a shallow or absent local clone.
- **Rendering uses `sed`, so every rendered value is charset-validated first.** Escaping is not attempted; a value outside the whitelist is rejected with a message naming the variable.
- **The wait is a poll loop, not `kubectl wait --for=condition=complete`.** `kubectl wait` blocks until its timeout even when the Job has already failed, which would hide a clone error for an hour. The loop exits on the first terminal signal and separately on its own deadline.
- **The caller's deadline is the Job's deadline plus a grace period.** The Job carries `activeDeadlineSeconds: <TIMEOUT>`; the script gives up at `TIMEOUT + 120`, so the Job's own deadline fires first and the pod log explains the stall.

Environment note: this container has no `kubectl` and a masked `.git`. That is why the verification below tests input validation and rendering with a stub `kubectl` and an explicit epoch, and leaves the live-cluster behaviour to the spec's operator rung.
</context>

<requirements>

## 1. Create `hack/build-cluster.sh`

Create the file with exactly this content, then `chmod +x hack/build-cluster.sh`.

```bash
#!/usr/bin/env bash
# Renders hack/build-job.yaml and runs it in the target cluster.
#
# Called from `make build BUILD_TARGET=<kubectl-context>` (Makefile.docker) with
# BUILD_TARGET, NAMESPACE, REPO_URL, REF, TAG, DOCKERFILE, IMAGE, PUSH and
# TIMEOUT in the environment. Not intended to be run by hand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE:-${SCRIPT_DIR}/build-job.yaml}"

NAMESPACE="${NAMESPACE:-build}"
PUSH="${PUSH:-true}"
TIMEOUT="${TIMEOUT:-3600}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"

die() {
	echo "build-cluster: $*" >&2
	exit 1
}

require() {
	local name="$1"
	[ -n "${!name:-}" ] || die "${name} is required; pass it on the make command line"
}

require BUILD_TARGET
require REPO_URL
require REF
require TAG
require IMAGE

# Values are substituted into the manifest with sed and land in shell scripts
# inside it, so each one is restricted to a whitelist before rendering. A value
# outside the whitelist is rejected, never escaped.
printf '%s' "${REF}" | grep -qE '^[A-Za-z0-9._/-]+$' ||
	die "REF '${REF}' contains characters outside [A-Za-z0-9._/-]"
printf '%s' "${TAG}" | grep -qE '^[A-Za-z0-9._-]+$' ||
	die "TAG '${TAG}' contains characters outside [A-Za-z0-9._-]"
printf '%s' "${IMAGE}" | grep -qE '^[A-Za-z0-9._/:-]+$' ||
	die "IMAGE '${IMAGE}' contains characters outside [A-Za-z0-9._/:-]"
printf '%s' "${REPO_URL}" | grep -qE '^[A-Za-z0-9._/:@-]+$' ||
	die "REPO_URL '${REPO_URL}' contains characters outside [A-Za-z0-9._/:@-]"
printf '%s' "${DOCKERFILE}" | grep -qE '^[A-Za-z0-9._/-]+$' ||
	die "DOCKERFILE '${DOCKERFILE}' contains characters outside [A-Za-z0-9._/-]"
printf '%s' "${TIMEOUT}" | grep -qE '^[0-9]+$' ||
	die "TIMEOUT '${TIMEOUT}' is not a number of seconds"
case "${PUSH}" in
true | false) ;;
*) die "PUSH '${PUSH}' must be true or false" ;;
esac

# The accepted targets are the contexts this kubeconfig knows about, so an
# unknown target fails here with the list instead of at apply time.
contexts="$(kubectl config get-contexts -o name 2>/dev/null || true)"
printf '%s\n' "${contexts}" | grep -qxF "${BUILD_TARGET}" ||
	die "unknown BUILD_TARGET '${BUILD_TARGET}'; accepted values: $(printf '%s' "${contexts}" | tr '\n' ' ')"

# The build clock is the built commit's timestamp. It is rendered literally so
# the Job states the epoch it will use; the init container re-derives it from
# the cloned commit and the build container refuses to run on a mismatch.
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
	SOURCE_DATE_EPOCH="$(git log -1 --format=%ct "${REF}" 2>/dev/null || true)"
fi
printf '%s' "${SOURCE_DATE_EPOCH}" | grep -qE '^[0-9]+$' ||
	die "cannot resolve REF '${REF}' to a commit in the local repository; run git fetch and retry"

JOB_NAME="build-$(printf '%s' "${TAG}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9.-]/-/g')"
JOB_NAME="${JOB_NAME:0:63}"

rendered="$(mktemp)"
trap 'rm -f "${rendered}"' EXIT

sed \
	-e "s|__JOB_NAME__|${JOB_NAME}|g" \
	-e "s|__REPO_URL__|${REPO_URL}|g" \
	-e "s|__REF__|${REF}|g" \
	-e "s|__TAG__|${TAG}|g" \
	-e "s|__DOCKERFILE__|${DOCKERFILE}|g" \
	-e "s|__IMAGE__|${IMAGE}|g" \
	-e "s|__PUSH__|${PUSH}|g" \
	-e "s|__DEADLINE_SECONDS__|${TIMEOUT}|g" \
	-e "s|__SOURCE_DATE_EPOCH__|${SOURCE_DATE_EPOCH}|g" \
	"${TEMPLATE}" >"${rendered}"

if kubectl --context "${BUILD_TARGET}" -n "${NAMESPACE}" get job "${JOB_NAME}" --ignore-not-found -o name | grep -q .; then
	die "job ${NAMESPACE}/${JOB_NAME} already exists; delete it with: kubectl --context ${BUILD_TARGET} -n ${NAMESPACE} delete job ${JOB_NAME}"
fi

if ! kubectl --context "${BUILD_TARGET}" apply -f "${rendered}"; then
	echo "build-cluster: job ${NAMESPACE}/${JOB_NAME} was not accepted; events:" >&2
	kubectl --context "${BUILD_TARGET}" -n "${NAMESPACE}" get events \
		--field-selector "involvedObject.name=${JOB_NAME}" \
		--sort-by=.lastTimestamp >&2 || true
	die "could not create job ${NAMESPACE}/${JOB_NAME}"
fi

deadline=$(( $(date +%s) + TIMEOUT + 120 ))
outcome=""
while [ -z "${outcome}" ]; do
	succeeded="$(kubectl --context "${BUILD_TARGET}" -n "${NAMESPACE}" get job "${JOB_NAME}" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
	failed="$(kubectl --context "${BUILD_TARGET}" -n "${NAMESPACE}" get job "${JOB_NAME}" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
	if [ "${succeeded:-0}" -ge 1 ]; then
		outcome=succeeded
	elif [ "${failed:-0}" -ge 1 ]; then
		outcome=failed
	elif [ "$(date +%s)" -ge "${deadline}" ]; then
		outcome=timeout
	else
		sleep 5
	fi
done

logs() {
	kubectl --context "${BUILD_TARGET}" -n "${NAMESPACE}" logs \
		-l "job-name=${JOB_NAME}" --all-containers --prefix "$@" 2>/dev/null || true
}

if [ "${outcome}" = succeeded ]; then
	logs --tail=-1 | grep -E 'pushing manifest for|containerimage\.digest' || true
	echo "build-cluster: job ${NAMESPACE}/${JOB_NAME} succeeded"
	exit 0
fi

echo "build-cluster: job ${NAMESPACE}/${JOB_NAME} ${outcome}; last log lines:" >&2
logs --tail=100 >&2
if [ "${outcome}" = timeout ]; then
	die "job ${NAMESPACE}/${JOB_NAME} did not finish within ${TIMEOUT}s (+120s grace)"
fi
die "job ${NAMESPACE}/${JOB_NAME} failed"
```

## 2. Confirm the caller's contract still matches

Read the `else` branch of the `build` target in `Makefile.docker` and confirm it passes exactly `BUILD_TARGET`, `NAMESPACE`, `REPO_URL`, `REF`, `TAG`, `DOCKERFILE`, `IMAGE`, `PUSH`, `TIMEOUT` and invokes `hack/build-cluster.sh`. If a name differs, change the Makefile to match the script — the script is the contract owner for these names. Do not otherwise edit `Makefile.docker`.

## 3. Add the CHANGELOG entry

This is the last prompt of the feature, so the single `## Unreleased` bullet lands here. Add it to the existing `## Unreleased` section of `CHANGELOG.md` (do not create a new version heading, do not rewrite existing bullets):

```
- feat: add a `BUILD_TARGET` selector to `make build` so a release image can be built inside a cluster instead of only on the invoking machine. `local` (the default) keeps the existing `docker build`; naming a kubectl context renders `hack/build-job.yaml`, applies it to the `build` namespace and blocks until the Job finishes, reporting the pushed digest. The build clock is pinned to the built commit (`SOURCE_DATE_EPOCH` with `rewrite-timestamp`), so repeated builds of one commit can produce the same image. The Job clones the requested ref, builds `linux/amd64` with rootless `buildctl-daemonless.sh` and pushes with a credential mounted from a cluster secret; the template lives in `hack/` so `make apply` never adopts it.
```

## 4. Self-check before finishing

Run the whole `<verification>` block as one script and confirm it exits 0 and prints the expected markers. Then walk the spec's Failure Modes table row by row and point at the line in the script that implements it: unknown target (the `contexts` check), unreachable cluster (`kubectl apply` failure path), admission rejection (the events dump), clone failure (wait loop → `failed` → log tail), push refusal (same), deadline exceeded (the `timeout` outcome naming `TIMEOUT`), and interruption (nothing deletes the Job; a rerun refuses while it exists).

</requirements>

<constraints>

- `BUILD_TARGET=local` must never reach this script and must never require a cluster: the script is only called from the `else` branch of `Makefile.docker`. Do not add a `local` case to the script.
- The push credential is never read, written, echoed or passed by this script. It exists only as the cluster secret the Job mounts. Do not add `--docker-config`, `DOCKER_CONFIG`, or any credential path to the script.
- The script must never delete or replace an existing Job. A rerun against an existing Job fails with the delete command in the message, so an interrupted build stays inspectable.
- The script must not print the rendered manifest, the repository URL credential (there is none), or the secret contents. Printing the Job's log tail on failure and the digest lines on success is required; printing more is not.
- `REF`, `TAG`, `IMAGE`, `REPO_URL` and `DOCKERFILE` are validated against a whitelist before rendering. Do not replace the whitelist with `sed` escaping.
- The wait must report the deadline it waited (`TIMEOUT` seconds, plus the 120s grace) on the timeout path.
- Exit codes: 0 only when the Job's `.status.succeeded` is at least 1. Every failure path exits non-zero.
- No new runtime dependency in the built image; this is build tooling only.
- Do not change image naming or tagging; the image reference is `IMAGE:TAG` exactly as passed.
- Do not edit `hack/build-job.yaml`, `Dockerfile`, `k8s/`, or any Go file.
- Do NOT commit — dark-factory handles git.
- Existing tests must still pass.

</constraints>

<verification>

Run the following as one script from the repository root. It must exit 0 and print every `ok` marker.

```bash
set -euo pipefail

test -x hack/build-cluster.sh && echo "ok executable"
bash -n hack/build-cluster.sh && echo "ok syntax"
if command -v shellcheck >/dev/null; then shellcheck -S warning hack/build-cluster.sh; fi
grep -q 'hack/build-cluster.sh' Makefile.docker && echo "ok wired"
grep -q 'SOURCE_DATE_EPOCH' hack/build-cluster.sh && echo "ok epoch"
grep -q 'BUILD_TARGET' CHANGELOG.md && echo "ok changelog"

# unknown target: rejected before rendering, listing the accepted values
BUILD_TARGET=definitely-not-a-context REPO_URL=https://example.com/x.git \
	REF=master TAG=test IMAGE=example.com/x ./hack/build-cluster.sh 2>&1 |
	grep -q "unknown BUILD_TARGET 'definitely-not-a-context'" && echo "ok unknown target"

# charset rejection runs before any cluster access
REF='master;rm -rf /' BUILD_TARGET=definitely-not-a-context REPO_URL=https://example.com/x.git \
	TAG=test IMAGE=example.com/x ./hack/build-cluster.sh 2>&1 |
	grep -q "REF 'master;rm -rf /' contains characters" && echo "ok ref rejected"

# render + apply + wait against a stub kubectl, with an explicit epoch
stub="$(mktemp -d)"
trap 'rm -rf "${stub}"' EXIT
cat >"${stub}/kubectl" <<'STUB'
#!/usr/bin/env bash
case "$*" in
"config get-contexts -o name") echo test ;;
*"get job"*"-o name"*) exit 0 ;;
*"get job"*"status.succeeded"*) echo 1 ;;
*"get job"*) exit 0 ;;
*"apply -f"*) cp "${@: -1}" "${FAKE_RENDERED}" ;;
*"logs"*) echo "containerimage.digest: sha256:0123456789abcdef" ;;
esac
exit 0
STUB
chmod +x "${stub}/kubectl"

PATH="${stub}:${PATH}" FAKE_RENDERED="${stub}/rendered.yaml" SOURCE_DATE_EPOCH=1793000000 \
	BUILD_TARGET=test NAMESPACE=build REPO_URL=https://example.com/x.git REF=master \
	TAG=v1.2.3 IMAGE=example.com/x DOCKERFILE=Dockerfile PUSH=true TIMEOUT=60 \
	./hack/build-cluster.sh | grep -q 'containerimage.digest' && echo "ok success path"

grep -q 'name: build-v1.2.3' "${stub}/rendered.yaml" && echo "ok job name"
grep -q 'build-arg:SOURCE_DATE_EPOCH=1793000000' "${stub}/rendered.yaml" && echo "ok epoch rendered"
grep -q 'name=example.com/x:v1.2.3,push=true' "${stub}/rendered.yaml" && echo "ok output rendered"
grep -q 'https://example.com/x.git' "${stub}/rendered.yaml" && echo "ok repo rendered"
grep -q 'activeDeadlineSeconds: 60' "${stub}/rendered.yaml" && echo "ok deadline rendered"
! grep -q '__[A-Z_]*__' "${stub}/rendered.yaml" && echo "ok no tokens left"

ROOTDIR=/workspace make precommit
echo "ok precommit"
```

Notes on the assertions:

- The stub `kubectl` answers `get job … -o name` with nothing (no pre-existing Job), `apply` by copying the rendered file to `$FAKE_RENDERED`, the jsonpath query with `1` (Job succeeded), and `logs` with a digest line. This exercises the real render, apply and report paths without a cluster.
- `SOURCE_DATE_EPOCH=1793000000` is supplied explicitly because `.git` is masked in this container; the script honours the environment value over the derivation.
- `! grep -q '__[A-Z_]*__'` is the absence assertion for leftover tokens; do not rewrite it as `grep -c`, which exits 1 on a zero count.

If `make precommit` fails, fix the cause and re-run only the failing target before re-running the full pipeline. A `trivy` failure caused by an unreachable vulnerability database is environmental — report it rather than silencing it in the Makefile.

</verification>
