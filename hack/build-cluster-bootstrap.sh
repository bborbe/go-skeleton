#!/usr/bin/env bash
# Provisions the cluster-side prerequisites for a remote build: the `build`
# namespace, the push secret the Job mounts, and the pull secret for the mint
# image. Idempotent — running it twice exits 0 and leaves exactly one namespace
# and the same secrets.
#
# The mint-image pull secret is provisioned here because `hack/build-job.yaml`
# carries a `mint-token` init container unconditionally: the kubelet has to pull
# that image before any container runs, and it is served by a private registry.
# Without the pull secret the pod sits in ImagePullBackOff — including for a
# public repository, whose clone would otherwise need no credential at all. The
# container itself is cheap when unused: it exits 0 when the `git-app` secret is
# absent.
#
# It does NOT create the `git-app` secret that lets a private repository be
# cloned. That secret (a GitHub App's APP_ID, INSTALLATION_ID and PEM_KEY) is
# provisioned out of band for the build cluster, and this script must never
# start requiring it: its absence is what the anonymous clone path runs on, and a
# hard precondition here would break exactly that path.
#
# Called by hand before the first `make build BUILD_TARGET=<cluster>` against a
# cluster. It deliberately creates no Job: jobs are per-build, rendered by
# hack/build-cluster.sh, which refuses to run when one already exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE:-${SCRIPT_DIR}/dockerconfig.json.tpl}"
MINT_TEMPLATE="${MINT_TEMPLATE:-${SCRIPT_DIR}/dockerconfig-nuke.json.tpl}"

BUILD_TARGET="${1:-}"
NAMESPACE="${NAMESPACE:-build}"
BUILD_PUSH_SECRET="${BUILD_PUSH_SECRET:-buildkit-push}"
MINT_PULL_SECRET="${MINT_PULL_SECRET:-buildkit-push-nuke}"

die() {
	echo "build-cluster-bootstrap: $*" >&2
	exit 1
}

[ -n "${BUILD_TARGET}" ] || die "usage: $(basename "${BASH_SOURCE[0]}") <sun|nukedev|nukeprod|kubectl-context>"
[ -f "${TEMPLATE}" ] || die "template not found: ${TEMPLATE}"
[ -f "${MINT_TEMPLATE}" ] || die "mint template not found: ${MINT_TEMPLATE}"

# The same -teamvault-config value `make apply` takes (Makefile.k8s). Defaults to
# the config the repo's own .envrc uses, so an operator who has teamvault-cli set
# up does not have to export anything.
TEAMVAULT="${TEAMVAULT:-${HOME}/.config/teamvault-cli/config.json}"
[ -f "${TEAMVAULT}" ] || die "teamvault config not found: ${TEAMVAULT} (set TEAMVAULT to override)"
command -v teamvault-cli >/dev/null 2>&1 ||
	die "teamvault-cli not found on PATH; it resolves the lookup key in ${TEMPLATE}"

# Shared with hack/build-cluster.sh so the alias mapping cannot drift between
# provisioning and building.
source "${SCRIPT_DIR}/cluster-alias.sh"

# The rendered credential lives in a 600 temp file for the length of one
# `create secret --dry-run` and is removed on every exit path. It is never
# echoed, never logged, and never written into the repo. Reused across the two
# secrets: each render fully overwrites it before it is read.
RENDERED="$(mktemp)"
chmod 600 "${RENDERED}"
trap 'rm -f "${RENDERED}"' EXIT INT TERM

echo "build-cluster-bootstrap: cluster ${BUILD_TARGET} (kubectl context ${KUBE_CONTEXT})"

kc create namespace "${NAMESPACE}" --dry-run=client -o yaml | kc apply -f -
echo "build-cluster-bootstrap: namespace ${NAMESPACE} present"

command -v jq >/dev/null 2>&1 || die "jq is required to render the dockerconfig templates"

# One secret per template, so each template stays the single declaration of
# which TeamVault item and which registry that secret is for.
#
# The lookup key comes from the template. awk, not a `sed` pipeline truncated by
# `head`: `head` exits after the first match, so a template carrying a second
# `teamvaultUser` occurrence sends SIGPIPE to `sed`, which fails the pipeline
# under `pipefail` before the `die` below can report the real cause.
# `hack/build-cluster.sh` replaced the same shape for the same reason.
render_secret() {
	local template="$1" secret="$2"
	local teamvault_key registry tv_user tv_pass

	teamvault_key="$(awk '
		{
			if (match($0, /"[A-Za-z0-9]{6,12}" \| teamvaultUser/)) {
				key = substr($0, RSTART + 1, RLENGTH - 1)
				sub(/".*/, "", key)
				print key
				exit
			}
		}
	' "${template}")"
	[ -n "${teamvault_key}" ] || die "no teamvaultUser lookup key found in ${template}"

	# The registry is the template's own `auths` key, so adding a registry is a
	# new template rather than an edit to this function.
	registry="$(grep -oE '"auths":\{"[^"]+"' "${template}" | sed -e 's|.*"auths":{"||' -e 's|"$||')"
	[ -n "${registry}" ] || die "no auths registry found in ${template}"

	# teamvault-cli, not teamvault-config-parser: the parser takes its password
	# from the config file, which holds only url and user, so it authenticates
	# unprivileged and gets 403 on this item. The CLI reads the login from the
	# macOS Keychain.
	tv_user="$(teamvault-cli username --teamvault-config "${TEAMVAULT}" --teamvault-key="${teamvault_key}")"
	tv_pass="$(teamvault-cli password --teamvault-config "${TEAMVAULT}" --teamvault-key="${teamvault_key}")"
	[ -n "${tv_user}" ] && [ -n "${tv_pass}" ] || die "teamvault returned an empty credential for key ${teamvault_key}"

	# Render through jq rather than printf: a credential containing a quote, a
	# backslash or a newline makes raw interpolation produce malformed JSON — a
	# backslash can escape the closing quote and let a crafted value inject
	# fields into the dockerconfigjson.
	#
	# The password reaches jq as a file, never as `--arg`: an argv argument is
	# readable by every local process through `ps` or /proc/<pid>/cmdline for the
	# life of the process, which on a shared build host is an exposure the 600
	# tempfile below does not cover. The username is not secret and stays an
	# `--arg`.
	jq -n --arg reg "${registry}" --arg user "${tv_user}" --rawfile pass <(printf '%s' "${tv_pass}") \
		'{auths:{($reg):{username:$user,password:$pass}}}' \
		>"${RENDERED}"
	[ -s "${RENDERED}" ] || die "failed to render ${template}"

	kc create secret generic "${secret}" \
		-n "${NAMESPACE}" \
		--type=kubernetes.io/dockerconfigjson \
		--from-file=.dockerconfigjson="${RENDERED}" \
		--dry-run=client -o yaml | kc apply -f -
	echo "build-cluster-bootstrap: secret ${NAMESPACE}/${secret} present (registry ${registry})"
}

render_secret "${TEMPLATE}" "${BUILD_PUSH_SECRET}"
render_secret "${MINT_TEMPLATE}" "${MINT_PULL_SECRET}"

echo "build-cluster-bootstrap: ready — make build BUILD_TARGET=${BUILD_TARGET}"
