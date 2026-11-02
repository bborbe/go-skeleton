---
status: completed
spec: [003-build-target]
summary: Parameterized the build Job's push-credential secret name as __PUSH_SECRET__, defaulting to buildkit-push via BUILD_PUSH_SECRET and rendered by build-cluster.sh
execution_id: go-skeleton-build-target-exec-012-spec-003-push-secret-param
dark-factory-version: v0.198.7
created: "2026-10-25T15:45:00Z"
queued: "2026-10-25T15:53:23Z"
started: "2026-10-25T15:53:25Z"
completed: "2026-10-25T15:55:09Z"
---

# Parameterize the push-secret name so the Job can mount the real credential

<summary>
- The build Job currently names its credential secret after a placeholder, so on a real cluster the pod never starts.
- The secret name becomes a parameter, defaulting to the name this operator actually created.
- The build namespace's secret is mounted successfully and the build begins.
- Nothing else about the Job changes: same images, same tokens, same credential remap.
- The name stays configurable because a second cluster may hold the same credential under a different name.
</summary>

<objective>
Make the push-credential secret name a parameter of the build Job instead of a hardcoded placeholder, so `make build BUILD_TARGET=<cluster>` mounts the secret that actually exists. The first real run on sun failed with `MountVolume.SetUp failed for volume "docker-config": secret "docker-push" not found` and the pod never left `Init:0/1`.
</objective>

<context>
Read these files before editing:

- `hack/build-job.yaml` — the volume block near the end declares `secretName: docker-push`. That name does not exist on any cluster.
- `hack/build-cluster.sh` — renders the template by substituting `__TOKEN__` placeholders; it must fill the new one.
- `Makefile.docker` — its `else` branch passes the run's values to the script as environment variables.
- `specs/in-progress/003-build-target.md` — "Security / Abuse" and the `items:` remap requirement.

Ground truth from the live clusters (read 2026-10-25, names only, no values):

- sun `build` namespace holds `secret/buildkit-push` of type `kubernetes.io/dockerconfigjson`.
- nukedev and nukeprod `build` namespaces hold `secret/docker`, also `kubernetes.io/dockerconfigjson`, whose registry coverage is unverified.
- Nothing anywhere is named `docker-push`.

The `items:` remap (`.dockerconfigjson` → `config.json`) is already correct and must not change — without it the mount succeeds and the auth fails silently.
</context>

<requirements>

## 1. Replace the hardcoded secret name with a token

In `hack/build-job.yaml`, change `secretName: docker-push` to `secretName: __PUSH_SECRET__`. Update the file's header comment so it names the token rather than a fixed secret.

## 2. Add the variable to the Makefile

In `Makefile.docker`, alongside the other `BUILD_*` variables, add:

```make
BUILD_PUSH_SECRET ?= buildkit-push
```

and pass it from the `else` branch to the script as `PUSH_SECRET='$(BUILD_PUSH_SECRET)'`, keeping the existing alphabetical-ish grouping of the environment block. Do not change any other variable's name, value or order.

## 3. Fill the token in the renderer

In `hack/build-cluster.sh`, add `PUSH_SECRET` to the set of variables it reads from the environment, include it in the required-variable guard alongside the others, and substitute `__PUSH_SECRET__` when rendering. The existing "refuse if any `__TOKEN__` survives" check then covers it automatically.

## 4. Do not change anything else

Do not touch the images, the `items:` remap, the Job name derivation, the wait loop, the local build recipe, or any Go file. Do not add a `## Unreleased` CHANGELOG bullet — the last prompt in this series owns it.

## 5. Self-check before finishing

Re-run every command in `<verification>` and confirm each passes.

</requirements>

<constraints>

- The `items:` remap of `.dockerconfigjson` → `config.json` stays exactly as it is.
- `BUILD_PUSH_SECRET` defaults to `buildkit-push` — the secret that exists on sun today.
- The script must never read, print or copy the credential's contents; it only renders a reference to the secret by name.
- The local build path must not gain a dependency on any of this.
- Repo-relative paths only.
- Do NOT commit — dark-factory handles git.
- Existing tests must still pass.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `! grep -q 'docker-push' hack/build-job.yaml` — the placeholder name is gone.
2. `grep -q '__PUSH_SECRET__' hack/build-job.yaml` — the token is present.
3. `grep -q 'BUILD_PUSH_SECRET' Makefile.docker` — the variable is declared and passed.
4. `grep -q 'PUSH_SECRET' hack/build-cluster.sh` — the renderer reads and substitutes it.
5. `make -n build BUILD_TARGET=test BRANCH=test REF=v0.6.0 | grep -q "PUSH_SECRET='buildkit-push'"` — the default flows through.
6. `grep -q 'buildkit-push' Makefile.docker` — the default is the real secret name, not a placeholder.
7. `bash -n hack/build-cluster.sh` — syntax is still valid.
8. `ROOTDIR=/workspace make precommit` — must exit 0.

</verification>
