---
status: completed
spec: [003-build-target]
summary: 'Aligned the build pod''s security context with the proven rootless configuration: added container-level AppArmor and seccomp exemptions, moved runAsUser/runAsGroup to the container, dropped runAsNonRoot/fsGroup and the explicit XDG_RUNTIME_DIR, keeping the credential and state mounts unchanged.'
execution_id: go-skeleton-build-target-exec-014-spec-003-apparmor-exemption
dark-factory-version: v0.198.7
created: "2026-10-25T17:20:00Z"
queued: "2026-10-25T16:14:11Z"
started: "2026-10-25T16:14:13Z"
completed: "2026-10-25T16:15:48Z"
---

# Align the build pod's security context with the proven rootless configuration

<summary>
- Rootless BuildKit now gets far enough to start, but its sandbox layer is refused permission to set up its own mounts.
- The pod's security settings are aligned with the configuration already proven to work on this cluster.
- The build container is permitted to do the one privileged-ish operation rootless BuildKit needs, and nothing more.
- The pod stays non-root; no privileged container, no host namespaces, no Docker socket.
- Nothing about the parameterization, the pinned clock, or the clone changes.
</summary>

<objective>
Make rootless `buildkitd` actually start on the sun k3s nodes. The third run reached the build container and failed with `rootlesskit:child error: failed to share mount point: /: permission denied`. A previously proven Job on the same cluster — the one that established the push credential — succeeded with an additional AppArmor exemption that this manifest does not carry.
</objective>

<context>
Read these files before editing:

- `hack/build-job.yaml` — the pod-level `securityContext` (`runAsNonRoot`, `runAsUser: 1000`, `fsGroup: 1000`), the pod-level `seccompProfile: Unconfined`, the build container's `env` and `volumeMounts`.
- `specs/in-progress/003-build-target.md` — "Security / Abuse" and "Desired Behavior" item 5.

The known-good manifest, which built and pushed successfully on this same sun cluster on 2026-10-25, differs in exactly four ways:

| setting | proven Job | this manifest | action |
|---|---|---|---|
| `appArmorProfile: {type: Unconfined}` on the build container | present | **absent** | add it |
| `runAsUser` / `runAsGroup` | container level | pod level | move to container level |
| `runAsNonRoot: true` | absent | present at pod level | remove |
| `fsGroup: 1000` | absent | present at pod level | remove |
| `XDG_RUNTIME_DIR` + `/run/user/1000` mount | absent (tool default) | set explicitly | remove |
| `seccompProfile: Unconfined` | container level | pod level | move to container level |

The failure observed on sun (2026-10-25), verbatim:

```
[pod/…/build] could not connect to unix:///run/user/1000/buildkit/buildkitd.sock after 10 trials
[pod/…/build] [rootlesskit:child ] error: failed to share mount point: /: permission denied
[pod/…/build] [rootlesskit:parent] error: child exited: exit status 1
```

AppArmor confines the mount operations rootlesskit performs when it builds its user namespace; the proven Job exempted it and this one does not.
</context>

<requirements>

## 1. Add the AppArmor exemption to the build container

Give the `build` container its own `securityContext`:

```yaml
          securityContext:
            runAsUser: 1000
            runAsGroup: 1000
            seccompProfile:
              type: Unconfined
            appArmorProfile:
              type: Unconfined
```

## 2. Reduce the pod-level security context to what the proven Job used

Remove `runAsNonRoot: true` and `fsGroup: 1000` from the pod-level `securityContext`. If the pod-level block becomes empty after those removals, remove the block entirely rather than leaving `securityContext: {}`.

Do not add `privileged: true`, `allowPrivilegeEscalation: true`, `hostNetwork`, `hostPID`, or any host-path mount. The exemption is scoped to the sandbox profile, not to privilege.

## 3. Remove the explicit runtime directory

Delete the `XDG_RUNTIME_DIR` env entry and the `/run/user/1000` volumeMount from the build container, and the volume that backed it. `buildctl-daemonless.sh` picks its own default; the explicit path is what produced the `unix:///run/user/1000/buildkit/buildkitd.sock` failure line.

## 4. Keep the credential mount and the state mount

`DOCKER_CONFIG` stays pointed at the mounted secret directory, and the `items:` remap of `.dockerconfigjson` → `config.json` stays exactly as it is. The writable `emptyDir` at `/home/user/.local/share/buildkit` stays — rootless buildkitd needs a writable state directory.

## 5. Do not change anything else

Do not touch the images, the tokens, the clone container's `GIT_CONFIG_*` env, the epoch check, the build args, `hack/build-cluster.sh`, `Makefile.docker`, `Dockerfile`, `k8s/`, or any Go file. Do not add a `## Unreleased` CHANGELOG bullet.

## 6. Self-check before finishing

Re-run every command in `<verification>` and confirm each passes.

</requirements>

<constraints>

- The pod must not run as root: `runAsUser: 1000` stays, now on the build container.
- No privileged container, no host namespaces, no Docker socket, no host-path mounts.
- Both container images stay pinned by digest.
- The `__PUSH_SECRET__` token and the `items:` remap are unchanged.
- The token set (`__REPO_URL__`, `__REF__`, `__TAG__`, `__DOCKERFILE__`, `__IMAGE__`, `__PUSH__`, `__JOB_NAME__`, `__DEADLINE_SECONDS__`, `__SOURCE_DATE_EPOCH__`, `__PUSH_SECRET__`) keeps its names.
- Repo-relative paths only.
- Do NOT commit — dark-factory handles git.
- Existing tests must still pass.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `grep -q 'appArmorProfile' hack/build-job.yaml` — the exemption is present.
2. `grep -A1 'appArmorProfile' hack/build-job.yaml | grep -q 'Unconfined'` — it is set to Unconfined.
3. `! grep -q 'privileged: true' hack/build-job.yaml` — no privileged container.
4. `! grep -q 'runAsNonRoot' hack/build-job.yaml` — the pod-level flag is gone.
5. `! grep -q 'fsGroup' hack/build-job.yaml` — the group override is gone.
6. `! grep -q 'XDG_RUNTIME_DIR' hack/build-job.yaml` — the explicit runtime dir is gone.
7. `grep -q 'runAsUser: 1000' hack/build-job.yaml` — still non-root.
8. `grep -q 'config.json' hack/build-job.yaml` — the credential remap survives.
9. `grep -q 'GIT_CONFIG_KEY_0' hack/build-job.yaml` — the clone fix survives.
10. `ROOTDIR=/workspace make precommit` — must exit 0.

</verification>
