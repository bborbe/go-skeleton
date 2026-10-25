#!/usr/bin/env bash
# Provisions the cluster-side prerequisites for a remote build: the `build`
# namespace and the docker.io push secret the Job mounts. Idempotent — running
# it twice exits 0 and leaves exactly one namespace and one secret.
#
# Called by hand before the first `make build BUILD_TARGET=<cluster>` against a
# cluster. It deliberately creates no Job: jobs are per-build, rendered by
# hack/build-cluster.sh, which refuses to run when one already exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE:-${SCRIPT_DIR}/dockerconfig.json.tpl}"

BUILD_TARGET="${1:-}"
NAMESPACE="${NAMESPACE:-build}"
BUILD_PUSH_SECRET="${BUILD_PUSH_SECRET:-buildkit-push}"

die() {
	echo "build-cluster-bootstrap: $*" >&2
	exit 1
}

[ -n "${BUILD_TARGET}" ] || die "usage: $(basename "${BASH_SOURCE[0]}") <sun|nukedev|nukeprod|kubectl-context>"
[ -f "${TEMPLATE}" ] || die "template not found: ${TEMPLATE}"
[ -n "${TEAMVAULT:-}" ] || die "TEAMVAULT is not set; it is the -teamvault-config the parser needs, the same variable 'make apply' uses (see Makefile.k8s)"
command -v teamvault-config-parser >/dev/null 2>&1 ||
	die "teamvault-config-parser not found on PATH; it resolves the lookup key in ${TEMPLATE}"

# Shared with hack/build-cluster.sh so the alias mapping cannot drift between
# provisioning and building.
source "${SCRIPT_DIR}/cluster-alias.sh"

# The rendered credential lives in a 600 temp file for the length of one
# `create secret --dry-run` and is removed on every exit path. It is never
# echoed, never logged, and never written into the repo.
RENDERED="$(mktemp)"
chmod 600 "${RENDERED}"
trap 'rm -f "${RENDERED}"' EXIT INT TERM

echo "build-cluster-bootstrap: cluster ${BUILD_TARGET} (kubectl context ${KUBE_CONTEXT})"

kc create namespace "${NAMESPACE}" --dry-run=client -o yaml | kc apply -f -
echo "build-cluster-bootstrap: namespace ${NAMESPACE} present"

teamvault-config-parser -teamvault-config="${TEAMVAULT}" -logtostderr -v=0 \
	<"${TEMPLATE}" >"${RENDERED}"
[ -s "${RENDERED}" ] || die "teamvault-config-parser produced no output from ${TEMPLATE}"

kc create secret generic "${BUILD_PUSH_SECRET}" \
	-n "${NAMESPACE}" \
	--type=kubernetes.io/dockerconfigjson \
	--from-file=.dockerconfigjson="${RENDERED}" \
	--dry-run=client -o yaml | kc apply -f -
echo "build-cluster-bootstrap: secret ${NAMESPACE}/${BUILD_PUSH_SECRET} present"

echo "build-cluster-bootstrap: ready — make build BUILD_TARGET=${BUILD_TARGET}"
