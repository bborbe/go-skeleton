---
status: completed
spec: [003-build-target]
summary: Taught hack/build-cluster.sh to resolve BUILD_TARGET aliases sun/nukedev/nukeprod to their kubeconfig files and contexts, routing every kubectl call through a kc helper that also validates against the resolved kubeconfig
execution_id: go-skeleton-cluster-alias-exec-015-spec-003-cluster-alias-mapping
dark-factory-version: v0.198.7
created: "2026-10-25T17:58:00Z"
queued: "2026-10-25T17:06:36Z"
started: "2026-10-25T17:07:35Z"
completed: "2026-10-25T17:10:19Z"
---

# Let BUILD_TARGET name a cluster, not only a kubectl context

<summary>
- `make build BUILD_TARGET=sun` currently fails, because sun's kubectl context is literally named `default` and lives in a separate kubeconfig file.
- The three build clusters become nameable by the names people actually use for them.
- A plain kubectl context name keeps working exactly as it does now.
- An unknown name still fails loudly, listing what would work.
- The migration guide can document `BUILD_TARGET=sun` and be correct.
</summary>

<objective>
Teach `hack/build-cluster.sh` to resolve the three build clusters by the names this operator already uses — `sun`, `nukedev`, `nukeprod` — mapping each to its own kubeconfig file and context. Without this, the only working invocation is `KUBECONFIG=~/.kube/sun make build BUILD_TARGET=default …`, which is unusable as a documented instruction and would ship broken to every repo the migration guide covers.
</objective>

<context>
Read these files before editing:

- `hack/build-cluster.sh` — validates `BUILD_TARGET` against `kubectl config get-contexts -o name` (around the `contexts=` line) and then uses `kubectl --context "${BUILD_TARGET}"` throughout.
- `Makefile.docker` — its `else` branch passes `BUILD_TARGET` through unchanged. Do not change the Makefile.
- `specs/in-progress/003-build-target.md` — "Desired Behavior" items 2 and 7.

Ground truth, read from the machine on 2026-10-25 (real binary, not the interactive shell's `kubectl` function):

```
$ KUBECONFIG=~/.kube/sun       kubectl config get-contexts -o name   → default
$ KUBECONFIG=~/.kube/nuke-dev  kubectl config get-contexts -o name   → nuke-dev
$ KUBECONFIG=~/.kube/nuke-prod kubectl config get-contexts -o name   → nuke-prod
$ kubectl config get-contexts -o name   (default ~/.kube/config)     → gke_…, rancher-desktop
```

So today `BUILD_TARGET=sun` is rejected with `unknown BUILD_TARGET 'sun'; accepted values: gke_… rancher-desktop`, and the working invocation requires an undocumented `KUBECONFIG=` prefix.

The mapping to implement:

| `BUILD_TARGET` | kubeconfig file | kubectl context |
|---|---|---|
| `sun` | `~/.kube/sun` | `default` |
| `nukedev` | `~/.kube/nuke-dev` | `nuke-dev` |
| `nukeprod` | `~/.kube/nuke-prod` | `nuke-prod` |
</context>

<requirements>

## 1. Add the alias mapping

At the top of `hack/build-cluster.sh`, after the `set -euo pipefail` line and before the required-variable guards, resolve the alias into two variables — a kubeconfig path and a context name — leaving both empty when `BUILD_TARGET` is not one of the three aliases:

- `sun` → `KUBECONFIG_PATH="$HOME/.kube/sun"`, `KUBE_CONTEXT=default`
- `nukedev` → `KUBECONFIG_PATH="$HOME/.kube/nuke-dev"`, `KUBE_CONTEXT=nuke-dev`
- `nukeprod` → `KUBECONFIG_PATH="$HOME/.kube/nuke-prod"`, `KUBE_CONTEXT=nuke-prod`
- anything else → both empty, and `KUBE_CONTEXT="${BUILD_TARGET}"`

Use a `case` statement. Do not add an associative array — the script targets bash 3.2, which macOS still ships as `/bin/bash`.

## 2. Route every kubectl call through the resolved pair

Introduce one helper function, e.g. `kc()`, that runs kubectl with the resolved kubeconfig and context and forwards all arguments:

```bash
kc() {
	if [ -n "${KUBECONFIG_PATH}" ]; then
		KUBECONFIG="${KUBECONFIG_PATH}" kubectl --context "${KUBE_CONTEXT}" "$@"
	else
		kubectl --context "${KUBE_CONTEXT}" "$@"
	fi
}
```

Replace **every** `kubectl --context "${BUILD_TARGET}" …` invocation with `kc …`. There must be none left: grep the file afterwards.

## 3. Validate against the kubeconfig that will actually be used

The existing context check must run against the resolved kubeconfig, not the default one — otherwise `sun` validates against `~/.kube/config` and fails. Reuse `kc` for the check (`kc config get-contexts -o name`) so the two cannot drift.

Keep the failure message's shape: name the rejected value and list what would work. **Extend the list to include the three aliases**, because `sun`/`nukedev`/`nukeprod` are now valid inputs even though they are not contexts — a reader who typos `nukedv` should see them.

Also fail with a clear message when an alias's kubeconfig file does not exist (`test -f`), naming the path — a missing file currently surfaces as a confusing kubectl error.

## 4. Do not change anything else

Do not edit `Makefile.docker`, `hack/build-job.yaml`, `Dockerfile`, `k8s/`, or any Go file. Do not change the render, apply, wait or report logic. Do not add a `## Unreleased` CHANGELOG bullet.

## 5. Self-check before finishing

Re-run every command in `<verification>` and confirm each passes.

</requirements>

<constraints>

- Bash 3.2 compatible: no associative arrays, no `${var,,}`, no `mapfile`.
- A bare kubectl context name must keep working exactly as before — `BUILD_TARGET=rancher-desktop` still resolves through the default kubeconfig.
- The alias names are exactly `sun`, `nukedev`, `nukeprod` — lowercase, no separators.
- The kubeconfig paths are `$HOME/.kube/<file>`; do not hardcode `/Users/bborbe`.
- No new dependency. `kubectl` stays the only tool.
- The script must never print or copy a credential; it only selects a kubeconfig.
- Repo-relative paths only for repo files.
- Do NOT commit — dark-factory handles git.
- Existing tests must still pass.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `grep -q 'nukeprod' hack/build-cluster.sh` — the alias mapping exists.
2. `grep -q 'KUBECONFIG_PATH' hack/build-cluster.sh` — the resolved path variable exists.
3. `! grep -q 'kubectl --context "\${BUILD_TARGET}"' hack/build-cluster.sh` — no call still uses the raw target. Prove the pattern fires first: `echo 'kubectl --context "${BUILD_TARGET}" get pods' | grep -q 'kubectl --context "\${BUILD_TARGET}"'` must succeed.
4. `bash -n hack/build-cluster.sh` — syntax is valid.
5. `command -v shellcheck >/dev/null && shellcheck hack/build-cluster.sh` — no findings; skip cleanly if shellcheck is absent.
6. `! grep -qE 'declare -A|mapfile|\$\{[a-zA-Z_]+,,\}' hack/build-cluster.sh` — no bash-4-only constructs.
7. `grep -c 'kc ' hack/build-cluster.sh` — the helper is used at least 4 times (validation plus apply/wait/log calls).
8. `ROOTDIR=/workspace make precommit` — must exit 0.

</verification>
