---
status: completed
spec: [003-build-target]
summary: Added GIT_CONFIG_COUNT/GIT_CONFIG_KEY_0/GIT_CONFIG_VALUE_0 safe.directory env vars to the clone initContainer in hack/build-job.yaml so git accepts the root-owned /src mount while the pod stays rootless
execution_id: go-skeleton-build-target-exec-013-spec-003-clone-safe-directory
dark-factory-version: v0.198.7
created: "2026-10-25T17:05:00Z"
queued: "2026-10-25T16:11:10Z"
started: "2026-10-25T16:11:13Z"
completed: "2026-10-25T16:12:53Z"
---

# Let the clone initContainer read the directory it just created

<summary>
- The build pod now starts and mounts its credential, but the clone step fails before any build begins.
- Git refuses the working directory because the mount is owned by a different user than the one running the clone.
- The clone container is told the directory is safe, without needing a writable home directory.
- Nothing else about the Job changes: same images, same tokens, same clone sequence.
</summary>

<objective>
Make the clone initContainer able to operate on `/src`, which the emptyDir mount creates owned by root while the pod runs as uid 1000. The first run after the secret fix failed at the clone step with `fatal: detected dubious ownership in repository at '/src'`, so the build container never started.
</objective>

<context>
Read these files before editing:

- `hack/build-job.yaml` — the `clone` initContainer's script begins `set -eu` then `git init -q /src`. The pod-level `securityContext` sets `runAsNonRoot: true`, `runAsUser: 1000` and `fsGroup: 1000`.
- `specs/in-progress/003-build-target.md` — "Desired Behavior" item 4 and the "Failure Modes" row for a failed clone.

Observed failure, from the pod log on sun (2026-10-25):

```
[pod/build-proof-1792944604-64r56/clone] fatal: detected dubious ownership in repository at '/src'
[pod/build-proof-1792944604-64r56/clone] To add an exception for this directory, call:
[pod/build-proof-1792944604-64r56/clone] 	git config --global --add safe.directory /src
```

The mount point `/src` is created by Kubernetes as `root:root`, so git sees a repository owned by another user and refuses. `git config --global` is not the fix here — the container runs as uid 1000 and has no writable home directory, so a global config write would fail with a different error.
</context>

<requirements>

## 1. Mark the directory safe via the environment

In `hack/build-job.yaml`, in the `clone` initContainer's `env` list (add the list if it has none), set:

```yaml
          env:
            - name: GIT_CONFIG_COUNT
              value: "1"
            - name: GIT_CONFIG_KEY_0
              value: safe.directory
            - name: GIT_CONFIG_VALUE_0
              value: /src
```

These are read by git on every invocation, need no writable home directory, and apply to all `git` calls in that container without repeating a flag. Do not use `git config --global`, and do not use `git -c safe.directory=…` per command.

## 2. Do not weaken anything else

Do not change `runAsNonRoot`, `runAsUser`, `fsGroup`, the images, the clone sequence, the token set, or the build container. Do not add a `HOME` override. Do not switch the pod to run as root — the rootless requirement is the point of the task.

## 3. Keep the failure loud

The clone container already fails the Job when git exits non-zero. Preserve that: if the clone still fails, the Job must fail and the log must still name the ref and the git error.

## 4. Do not touch anything else

Do not edit `Makefile.docker`, `hack/build-cluster.sh`, `Dockerfile`, `k8s/`, or any Go file. Do not add a `## Unreleased` CHANGELOG bullet — the last prompt in this series owns it.

## 5. Self-check before finishing

Re-run every command in `<verification>` and confirm each passes.

</requirements>

<constraints>

- The `items:` remap of `.dockerconfigjson` → `config.json` stays exactly as it is.
- Both container images stay pinned by digest.
- The pod must stay rootless: `runAsNonRoot: true`, `runAsUser: 1000`.
- The `__PUSH_SECRET__`, `__REPO_URL__`, `__REF__`, `__TAG__`, `__DOCKERFILE__`, `__IMAGE__`, `__PUSH__`, `__JOB_NAME__`, `__DEADLINE_SECONDS__` and `__SOURCE_DATE_EPOCH__` tokens keep their names.
- Repo-relative paths only.
- Do NOT commit — dark-factory handles git.
- Existing tests must still pass.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `grep -q 'GIT_CONFIG_KEY_0' hack/build-job.yaml` — the safe-directory mechanism is present.
2. `grep -q 'value: /src' hack/build-job.yaml` — it points at the clone destination.
3. `! grep -q 'config --global' hack/build-job.yaml` — the unwritable-home variant was not used.
4. `grep -q 'runAsNonRoot: true' hack/build-job.yaml` — the pod is still rootless.
5. `grep -q 'runAsUser: 1000' hack/build-job.yaml` — the uid is unchanged.
6. `python3 -c "import yaml,sys; yaml.safe_load(open('hack/build-job.yaml'))"` — the manifest still parses. (If PyYAML is unavailable in the container, skip this step and say so.)
7. `ROOTDIR=/workspace make precommit` — must exit 0.

</verification>
