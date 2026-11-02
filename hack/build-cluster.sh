#!/usr/bin/env bash
# Renders hack/build-job.yaml and runs it in the target cluster.
#
# Called from `make build BUILD_TARGET=<sun|nukedev|nukeprod|kubectl-context>`
# (Makefile.docker) with
# BUILD_TARGET, NAMESPACE, REPO_URL, REF, TAG, DOCKERFILE, IMAGE, PUSH,
# PUSH_SECRET and TIMEOUT in the environment. Not intended to be run by hand.
#
# Optional, for a service that sits below the repository root:
#   CONTEXT_SUBDIR    service directory relative to the repo root; the build
#                     context and dockerfile local both become /src/<subdir>
#   SERVICE_PATH      annotation value recorded on the Job (defaults to the
#                     image repository name); a fan-out verifies its population
#                     from this annotation
#   NODE_SELECTOR     node hostname to pin the build to (kubernetes.io/hostname).
#                     Unset means no nodeSelector at all — the line is removed,
#                     not rendered empty.
#   BUILD_MAX_CONCURRENT  how many build Jobs may be in flight at once (default
#                     3). The cap lives here, not in a caller, because ten
#                     independent `make build` invocations share nothing but the
#                     cluster — this script waits for a free slot before it
#                     creates its Job.
#
#                     A caller that already pools its own concurrency (a fan-out
#                     running N scripts in parallel) will double-throttle: the
#                     effective limit is the smaller of the two, and the outer
#                     pool holds slots doing nothing. Such a caller sets
#                     BUILD_MAX_CONCURRENT high and lets its own pool bound the
#                     work, deliberately — pick one, not both.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE:-${SCRIPT_DIR}/build-job.yaml}"

NAMESPACE="${NAMESPACE:-build}"
PUSH="${PUSH:-true}"
TIMEOUT="${TIMEOUT:-3600}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CONTEXT_SUBDIR="${CONTEXT_SUBDIR:-}"
MAX_CONCURRENT="${BUILD_MAX_CONCURRENT:-3}"
NODE_SELECTOR="${NODE_SELECTOR:-}"
CACHE_REF="${BUILD_CACHE_REF:-}"

die() {
	echo "build-cluster: $*" >&2
	exit 1
}

require() {
	local name="$1"
	[ -n "${!name:-}" ] || die "${name} is required; pass it on the make command line"
}

# BUILD_TARGET is resolved to a kubeconfig file and context by cluster-alias.sh,
# which also defines the kc() helper every kubectl call goes through. It is
# shared with hack/build-cluster-bootstrap.sh so the alias mapping cannot drift
# between provisioning and building.
source "${SCRIPT_DIR}/cluster-alias.sh"

# The equivalent invocation for messages the operator has to retype.
KUBE_HINT="kubectl --context ${KUBE_CONTEXT}"
[ -z "${KUBECONFIG_PATH}" ] || KUBE_HINT="KUBECONFIG=${KUBECONFIG_PATH} ${KUBE_HINT}"

require BUILD_TARGET
require REPO_URL
require REF
require TAG
require IMAGE
require PUSH_SECRET

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
printf '%s' "${PUSH_SECRET}" | grep -qE '^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$' ||
	die "PUSH_SECRET '${PUSH_SECRET}' is not a valid Kubernetes secret name"
printf '%s' "${MAX_CONCURRENT}" | grep -qE '^[1-9][0-9]*$' ||
	die "BUILD_MAX_CONCURRENT '${MAX_CONCURRENT}' is not a positive integer"
# Defaulted here, not at the top, because it derives from IMAGE.
CACHE_REF="${CACHE_REF:-${IMAGE}:buildcache}"
printf '%s' "${CACHE_REF}" | grep -qE '^[A-Za-z0-9._/:-]+$' ||
	die "BUILD_CACHE_REF '${CACHE_REF}' contains characters outside [A-Za-z0-9._/:-]"
if [ -n "${NODE_SELECTOR}" ]; then
	printf '%s' "${NODE_SELECTOR}" | grep -qE '^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$' ||
		die "NODE_SELECTOR '${NODE_SELECTOR}' is not a Kubernetes node name"
fi
if [ -n "${CONTEXT_SUBDIR}" ]; then
	printf '%s' "${CONTEXT_SUBDIR}" | grep -qE '^[A-Za-z0-9._/-]+$' ||
		die "CONTEXT_SUBDIR '${CONTEXT_SUBDIR}' contains characters outside [A-Za-z0-9._/-]"
	CONTEXT_SUBDIR="${CONTEXT_SUBDIR#./}"
	CONTEXT_SUBDIR="${CONTEXT_SUBDIR%/}"
fi
if [ -n "${CONTEXT_SUBDIR}" ]; then
	CONTEXT_PATH="/src/${CONTEXT_SUBDIR}"
else
	CONTEXT_PATH="/src"
fi
# The dockerfile local follows the context so that the plain `Dockerfile` name
# stays valid; BuildKit resolves `filename` against the dockerfile local.
DOCKERFILE_PATH="${CONTEXT_PATH}"
# Owner-qualified by default: the image path with the registry host stripped, so
# two repositories sharing an image basename stay distinguishable in the
# annotation a fan-out or dispatcher dedupes on.
SERVICE_PATH="${SERVICE_PATH:-${IMAGE#*/}}"
printf '%s' "${SERVICE_PATH}" | grep -qE '^[A-Za-z0-9._/-]*$' ||
	die "SERVICE_PATH '${SERVICE_PATH}' contains characters outside [A-Za-z0-9._/-]"
printf '%s' "${TIMEOUT}" | grep -qE '^[0-9]+$' ||
	die "TIMEOUT '${TIMEOUT}' is not a number of seconds"
case "${PUSH}" in
true | false) ;;
*) die "PUSH '${PUSH}' must be true or false" ;;
esac

if [ -n "${KUBECONFIG_PATH}" ] && [ ! -f "${KUBECONFIG_PATH}" ]; then
	die "BUILD_TARGET '${BUILD_TARGET}' needs the kubeconfig ${KUBECONFIG_PATH}, which does not exist"
fi

# The accepted targets are the contexts the resolved kubeconfig knows about, so
# an unknown target fails here with the list instead of at apply time. The
# aliases are listed too: they are valid inputs without being contexts.
contexts="$(kc config get-contexts -o name 2>/dev/null || true)"
printf '%s\n' "${contexts}" | grep -qxF "${KUBE_CONTEXT}" ||
	die "unknown BUILD_TARGET '${BUILD_TARGET}'; accepted values: sun nukedev nukeprod $(printf '%s' "${contexts}" | tr '\n' ' ')"

# The build clock is the built commit's timestamp. It is rendered literally so
# the Job states the epoch it will use; the init container re-derives it from
# the cloned commit and the build container refuses to run on a mismatch.
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
	SOURCE_DATE_EPOCH="$(git log -1 --format=%ct "${REF}" 2>/dev/null || true)"
fi
printf '%s' "${SOURCE_DATE_EPOCH}" | grep -qE '^[0-9]+$' ||
	die "cannot resolve REF '${REF}' to a commit in the local repository; run git fetch and retry"

# The name carries a run id. A tag-derived name collides on the second run of
# the same tag, and a finished Job still blocks a same-name re-create for its
# whole TTL — so ten same-tag runs would fail before any concurrency cap could
# queue them.
SLUG="$(printf '%s-%s' "${IMAGE##*/}" "${TAG}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9.-]/-/g')"
SLUG="${SLUG:0:32}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$(printf '%04x' "${RANDOM}")"
JOB_NAME="build-${SLUG}-${RUN_ID}"
JOB_NAME="${JOB_NAME:0:63}"

rendered="$(mktemp)"
LOCK_HELD=0
cleanup() {
	rm -f "${rendered:-}" "${rendered:-}.tmp"
	if [ "${LOCK_HELD:-0}" = 1 ]; then
		kc -n "${NAMESPACE}" delete configmap "build-slot-lock" --ignore-not-found >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

sed \
	-e "s|__JOB_NAME__|${JOB_NAME}|g" \
	-e "s|__REPO_URL__|${REPO_URL}|g" \
	-e "s|__REF__|${REF}|g" \
	-e "s|__TAG__|${TAG}|g" \
	-e "s|__DOCKERFILE__|${DOCKERFILE}|g" \
	-e "s|__IMAGE__|${IMAGE}|g" \
	-e "s|__PUSH__|${PUSH}|g" \
	-e "s|__PUSH_SECRET__|${PUSH_SECRET}|g" \
	-e "s|__DEADLINE_SECONDS__|${TIMEOUT}|g" \
	-e "s|__SOURCE_DATE_EPOCH__|${SOURCE_DATE_EPOCH}|g" \
	-e "s|__SERVICE_PATH__|${SERVICE_PATH}|g" \
	-e "s|__CONTEXT_PATH__|${CONTEXT_PATH}|g" \
	-e "s|__DOCKERFILE_PATH__|${DOCKERFILE_PATH}|g" \
	-e "s|__NODE_SELECTOR__|${NODE_SELECTOR}|g" \
	-e "s|__NAMESPACE__|${NAMESPACE}|g" \
	-e "s|__CACHE_REF__|${CACHE_REF}|g" \
	"${TEMPLATE}" >"${rendered}"

# An unset NODE_SELECTOR must render as no nodeSelector at all. Substituting the
# empty string would leave `nodeSelector: {kubernetes.io/hostname: }`, which is
# not a node selector, so the whole line goes instead.
if [ -z "${NODE_SELECTOR}" ]; then
	awk '!/^[[:space:]]*nodeSelector:[[:space:]]*\{kubernetes\.io\/hostname:[[:space:]]*\}[[:space:]]*$/' \
		"${rendered}" >"${rendered}.tmp"
	mv "${rendered}.tmp" "${rendered}"
fi

# Concurrency cap. Ten simultaneous `make build` calls share nothing but the
# cluster, so the throttle has to live there.
#
# Counting and creating must be one step. A plain "count, then apply" does not
# work: measured with ten simultaneous starts, all ten read a count of zero
# before any Job existed and eight were created at once — a peak of 8 against a
# cap of 3. The count is therefore taken inside a cluster-side mutex, so the
# next caller sees this caller's Job before it takes its own count.
#
# The mutex is a ConfigMap, because `create` is atomic: it either creates or
# fails with AlreadyExists, with no read-modify-write window. A stale lock from
# a killed run is broken after LOCK_STALE_SECONDS; the EXIT trap releases the
# lock on every normal path.
LOCK_CM="build-slot-lock"
LOCK_STALE_SECONDS=300

acquire_lock() {
	local deadline=$(( $(date +%s) + TIMEOUT ))
	local since
	while true; do
		if kc -n "${NAMESPACE}" create configmap "${LOCK_CM}" \
			--from-literal=holder="${JOB_NAME}" \
			--from-literal=since="$(date +%s)" >/dev/null 2>&1; then
			LOCK_HELD=1
			return 0
		fi
		since="$(kc -n "${NAMESPACE}" get configmap "${LOCK_CM}" \
			-o jsonpath='{.data.since}' 2>/dev/null || true)"
		if [ -n "${since}" ] && [ "$(( $(date +%s) - since ))" -gt "${LOCK_STALE_SECONDS}" ]; then
			echo "build-cluster: breaking stale build-slot lock held ${since}" >&2
			kc -n "${NAMESPACE}" delete configmap "${LOCK_CM}" --ignore-not-found >/dev/null 2>&1 || true
			continue
		fi
		if [ "$(date +%s)" -ge "${deadline}" ]; then
			die "waited ${TIMEOUT}s for the build-slot lock; another build may have died holding it"
		fi
		sleep 2
	done
}

release_lock() {
	[ "${LOCK_HELD}" = 1 ] || return 0
	kc -n "${NAMESPACE}" delete configmap "${LOCK_CM}" --ignore-not-found >/dev/null 2>&1 || true
	LOCK_HELD=0
}

active_builds() {
	local n=""
	n="$(kc -n "${NAMESPACE}" get jobs \
		-l app.kubernetes.io/component=build \
		-o jsonpath='{range .items[*]}{.status.succeeded}{" "}{.status.failed}{"\n"}{end}' 2>/dev/null |
		awk '$1 != 1 && $2 != 1' | wc -l | tr -d ' ')" || n=""
	printf '%s' "${n:-0}"
}

slot_deadline=$(( $(date +%s) + TIMEOUT ))
queued=0
while true; do
	acquire_lock
	active="$(active_builds)"
	if [ "${active}" -lt "${MAX_CONCURRENT}" ]; then
		break
	fi
	release_lock
	if [ "$(date +%s)" -ge "${slot_deadline}" ]; then
		die "waited ${TIMEOUT}s for a free build slot; ${MAX_CONCURRENT} build Jobs are still in flight in ${NAMESPACE}"
	fi
	if [ "${queued}" = 0 ]; then
		echo "build-cluster: ${active} builds in flight, queued for a free slot"
		queued=1
	fi
	sleep 5
done

if kc -n "${NAMESPACE}" get job "${JOB_NAME}" --ignore-not-found -o name | grep -q .; then
	die "job ${NAMESPACE}/${JOB_NAME} already exists; delete it with: ${KUBE_HINT} -n ${NAMESPACE} delete job ${JOB_NAME}"
fi

if ! kc apply -f "${rendered}"; then
	echo "build-cluster: job ${NAMESPACE}/${JOB_NAME} was not accepted; events:" >&2
	kc -n "${NAMESPACE}" get events \
		--field-selector "involvedObject.name=${JOB_NAME}" \
		--sort-by=.lastTimestamp >&2 || true
	die "could not create job ${NAMESPACE}/${JOB_NAME}"
fi

# The Job now exists and is counted by the next caller, so the lock has done
# its job. Holding it through the build would serialise every build instead of
# capping them.
release_lock

deadline=$(( $(date +%s) + TIMEOUT + 120 ))
outcome=""
while [ -z "${outcome}" ]; do
	succeeded="$(kc -n "${NAMESPACE}" get job "${JOB_NAME}" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
	failed="$(kc -n "${NAMESPACE}" get job "${JOB_NAME}" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
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
	kc -n "${NAMESPACE}" logs \
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
