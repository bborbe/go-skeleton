#!/usr/bin/env bash
# Renders hack/build-job.yaml and runs it in the target cluster.
#
# Called from `make build BUILD_TARGET=<sun|nukedev|nukeprod|kubectl-context>`
# (Makefile.docker) with
# BUILD_TARGET, NAMESPACE, REPO_URL, REF, TAG, DOCKERFILE, IMAGE, PUSH,
# PUSH_SECRET and TIMEOUT in the environment, and optionally GIT_SECRET,
# MINT_IMAGE and MINT_PULL_SECRET to override the private-repository credential
# values baked into build-job.yaml. Not intended to be run by hand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE:-${SCRIPT_DIR}/build-job.yaml}"

NAMESPACE="${NAMESPACE:-build}"
PUSH="${PUSH:-true}"
TIMEOUT="${TIMEOUT:-3600}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"

# The private-repository credential. Its values are literals in
# build-job.yaml, not `__TOKEN__`s, because that template is also rendered by
# the release-to-image dispatcher, which knows a fixed token set and aborts the
# whole dispatch on a survivor — see the template header. The three below are
# the literals, kept here so this script can override them for the direct
# `make build BUILD_TARGET=<cluster>` path, where no renderer is involved.
#
# The `git-app` secret holds a GitHub App's APP_ID, INSTALLATION_ID and PEM_KEY
# and is provisioned out of band — hack/build-cluster-bootstrap.sh neither
# creates it nor requires it. Its absence is a supported state: the template's
# secret volume is `optional: true`, so a public repository builds anonymously.
GIT_SECRET_DEFAULT=git-app
MINT_IMAGE_DEFAULT=docker.prod.nuke.benjamin-borbe.de:443/scripts-mint-iat@sha256:cdda1554dcc203b408fe4f9a734c07204ee0a0971b3dc062c599c98b63388e81
# The mint image is served by the nuke registry while this repo pushes to
# docker.io (`__PUSH_SECRET__` = `docker`), so the pod needs a pull credential
# for it that is NOT the push secret. The template hardcodes this name; the
# override exists so a repo that pushes to the nuke registry itself can point it
# at its own push secret.
MINT_PULL_SECRET_DEFAULT=buildkit-push-nuke
GIT_SECRET="${GIT_SECRET:-${GIT_SECRET_DEFAULT}}"
MINT_IMAGE="${MINT_IMAGE:-${MINT_IMAGE_DEFAULT}}"
MINT_PULL_SECRET="${MINT_PULL_SECRET:-${MINT_PULL_SECRET_DEFAULT}}"

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
# The credential overrides reach the manifest by replacing a literal, and the
# values land in `secretName:` fields and `image:` — the same exposure as
# everything above, so they are validated the same way.
printf '%s' "${GIT_SECRET}" | grep -qE '^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$' ||
	die "GIT_SECRET '${GIT_SECRET}' is not a valid Kubernetes secret name"
printf '%s' "${MINT_PULL_SECRET}" | grep -qE '^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$' ||
	die "MINT_PULL_SECRET '${MINT_PULL_SECRET}' is not a valid Kubernetes secret name"
# `@` is required: the image is pinned by digest (`repo@sha256:...`).
printf '%s' "${MINT_IMAGE}" | grep -qE '^[A-Za-z0-9._/:@-]+$' ||
	die "MINT_IMAGE '${MINT_IMAGE}' contains characters outside [A-Za-z0-9._/:@-]"
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

JOB_NAME="build-$(printf '%s' "${TAG}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9.-]/-/g')"
JOB_NAME="${JOB_NAME:0:63}"

rendered="$(mktemp)"
trap 'rm -f "${rendered}"' EXIT

# The credential values are literals in the template, so the override is a
# replacement of the literal default rather than a token substitution. The
# defaults are distinctive strings that appear exactly once each, and the
# overrides are validated above, so this cannot silently rewrite something else.
sed \
	-e "s|secretName: ${GIT_SECRET_DEFAULT}$|secretName: ${GIT_SECRET}|g" \
	-e "s|image: ${MINT_IMAGE_DEFAULT}$|image: ${MINT_IMAGE}|g" \
	-e "s|- name: ${MINT_PULL_SECRET_DEFAULT}$|- name: ${MINT_PULL_SECRET}|g" \
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
	"${TEMPLATE}" >"${rendered}"

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
