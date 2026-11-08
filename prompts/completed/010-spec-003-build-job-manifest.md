---
status: completed
spec: [003-build-target]
summary: Authored hack/build-job.yaml as a parameterized, digest-pinned rootless BuildKit Kubernetes Job with clone initContainer, mounted push credential, pinned SOURCE_DATE_EPOCH, and digest reporting.
execution_id: go-skeleton-build-target-exec-010-spec-003-build-job-manifest
dark-factory-version: v0.198.7
created: "2026-10-25T14:21:43Z"
queued: "2026-10-25T14:23:39Z"
started: "2026-10-25T14:24:57Z"
completed: "2026-10-25T14:26:21Z"
---

# Add the parameterized BuildKit build Job manifest

<summary>
- A single reusable Kubernetes Job manifest exists that builds one image from one git ref inside a cluster.
- The manifest carries no repository-specific values: the repository URL, git ref, image tag, Dockerfile path, target image and push flag are all placeholders.
- The build runs rootless, without a privileged pod, without a Docker socket and without host namespaces.
- The push credential is mounted into the build pod from a cluster secret, remapped to the filename Docker expects, and never appears on the invoking machine.
- The clone and the build are separate steps, so a failed clone reports the ref and the git error rather than a build error.
- The manifest records the image digest it pushed, so the caller can report it.
- The file is placed where the deploy pipeline cannot pick it up, so it never becomes cluster state by accident.
- Both container images are pinned to immutable digests rather than floating tags.
</summary>

<objective>
Author `hack/build-job.yaml`: a parameterized Kubernetes Job that clones a git ref, builds a `linux/amd64` image with rootless BuildKit and pushes it to the target registry using a credential mounted inside the pod. It is the artifact the cluster branch of `make build` renders and applies, and it must be generic enough to serve other repositories unchanged.
</objective>

<context>
Read these files before writing:

- `specs/in-progress/003-build-target.md` — read "Desired Behavior" items 4, 5, 6, 8; "Security / Abuse"; "Failure Modes"; and the "Constraints" lines about placement and digest pinning.
- `Makefile.docker` — after the previous prompt it defines `BUILD_TARGET`, `BUILD_NAMESPACE`, `BUILD_TIMEOUT`, `BUILD_REPO_URL` and `BUILD_DOCKERFILE`, and its `else` branch passes `NAMESPACE`, `REPO_URL`, `REF`, `TAG`, `DOCKERFILE`, `IMAGE`, `PUSH`, `TIMEOUT` to `hack/build-cluster.sh`.
- `k8s/Makefile` — it includes `../Makefile.k8s`, whose `apply` target runs `find . -name "*.yaml"` from inside `k8s/`. Any YAML under `k8s/` is therefore adopted as deploy state. `hack/` is not under `k8s/`, which is exactly why the template lives there.
- `k8s/skeleton-deploy.yaml` — the repo's manifest style: `apiVersion`/`kind`/`metadata` first, `{}` for empty objects, explicit resources. Follow it.
- `/home/node/.claude/plugins/marketplaces/coding/docs/go-kubernetes-crd-controller-guide.md` — only if you need the repo's general k8s conventions; the manifest itself is plain batch/v1.

Upstream facts that this manifest depends on, verified against the BuildKit project rather than assumed:

- `moby/buildkit:<version>-rootless` runs BuildKit as a non-root user. Rootless BuildKit in Kubernetes needs `seccompProfile: Unconfined` and an `emptyDir` mounted at `/home/user/.local/share/buildkit`; without the writable mount the daemon fails at startup.
- `buildctl-daemonless.sh` (present at `/usr/bin/buildctl-daemonless.sh` in that image) launches `buildkitd` and then `buildctl`. When it runs as non-root it derives its socket path from `XDG_RUNTIME_DIR`, so that variable must be set and its directory must be writable.
- `buildkitd` flags go through the `BUILDKITD_FLAGS` environment variable, not through `buildctl` arguments. `--oci-worker-no-process-sandbox` is a `buildkitd` flag, so it belongs in `BUILDKITD_FLAGS`.
- `rewrite-timestamp` is an **exporter** option, so it is passed inside the `--output` value (`type=image,...,rewrite-timestamp=true`), not as a `--opt`. The spec writes it as `--opt rewrite-timestamp=true`; that spelling does not reach the exporter. Use the `--output` form — it is the one BuildKit acts on — and do not also pass it as a `--opt`.
- `--opt build-arg:SOURCE_DATE_EPOCH=<epoch>` is the correct way to hand the epoch to the dockerfile frontend; BuildKit reads that key and clamps layer and config timestamps to it.
- `--metadata-file <path>` makes `buildctl` write a JSON file that includes `containerimage.digest`; the Job `cat`s it so the digest appears in the pod log.

Images (pinned by digest; the tag is kept for readability, the digest is authoritative and immutable):

- build: `moby/buildkit:v0.34.1-rootless@sha256:f68752a5a94acfcdad2d07867b7075601a421638e17fc5f28efc1c814d0c4f89`
- clone: `alpine/git:v2.54.0@sha256:e8ceedc73bd80992ae8d58a7d24c58b8322146c354f1d2e81a97db4452068ec0`

Template tokens (the first six are the spec's repository-parameterization tokens; the rest are run-scoped values the rendering script substitutes):

| token | meaning |
|---|---|
| `__REPO_URL__` | git URL to clone |
| `__REF__` | git ref (branch, tag or commit) to build |
| `__TAG__` | image tag to push |
| `__DOCKERFILE__` | Dockerfile path inside the repository |
| `__IMAGE__` | target image repository, without tag |
| `__PUSH__` | `true` or `false` |
| `__JOB_NAME__` | Job name, `build-<tag>` sanitized for DNS |
| `__DEADLINE_SECONDS__` | Job deadline and the caller's wait budget |
| `__SOURCE_DATE_EPOCH__` | commit timestamp, rendered as a decimal integer |

Reviewer note: the spec's Summary says "six tokens". The six above are exactly those; the last three are run-scoped and do not carry repository identity, so the file still serves other repositories unchanged. The epoch is rendered rather than derived in-pod because Acceptance Criterion 7 requires a literal `--opt build-arg:SOURCE_DATE_EPOCH=<epoch>` in the Job's args. Desired Behavior 4's "derives SOURCE_DATE_EPOCH from that commit" is honoured by the initContainer, which computes the cloned commit's epoch and the build container fails loudly if it disagrees with the rendered value.
</context>

<requirements>

## 1. Create `hack/build-job.yaml`

Create the directory `hack/` and the file `hack/build-job.yaml` with exactly this content. Do not add a `kustomization.yaml`, do not add a second manifest, and do not create `k8s/build-job.yaml`.

```yaml
# Parameterized BuildKit build Job.
#
# Rendered by hack/build-cluster.sh, which is called from
# `make build BUILD_TARGET=<kubectl-context>`; never applied by hand.
#
# This file lives outside k8s/ on purpose: k8s/Makefile applies every *.yaml
# under k8s/, so a template kept there would be adopted as deploy state.
#
# Template tokens:
#   __JOB_NAME__           Job name, derived from __TAG__ and sanitized for DNS
#   __REPO_URL__           git URL to clone
#   __REF__                git ref (branch, tag or commit) to build
#   __TAG__                image tag to push
#   __DOCKERFILE__         Dockerfile path inside the repository
#   __IMAGE__              target image repository, without tag
#   __PUSH__               "true" to push the built image
#   __DEADLINE_SECONDS__   Job deadline in seconds
#   __SOURCE_DATE_EPOCH__  commit timestamp, decimal seconds
#
# Prerequisite (not created by this manifest): a kubernetes.io/dockerconfigjson
# secret named docker-push in the build namespace, holding a credential that may
# push to the target registry.
apiVersion: batch/v1
kind: Job
metadata:
  name: __JOB_NAME__
  namespace: build
  labels:
    app.kubernetes.io/name: image-build
    app.kubernetes.io/component: build
    app.kubernetes.io/version: "__TAG__"
spec:
  backoffLimit: 0
  activeDeadlineSeconds: __DEADLINE_SECONDS__
  ttlSecondsAfterFinished: 86400
  template:
    metadata:
      labels:
        app.kubernetes.io/name: image-build
        app.kubernetes.io/component: build
        app.kubernetes.io/version: "__TAG__"
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: Unconfined
      initContainers:
        - name: clone
          image: alpine/git:v2.54.0@sha256:e8ceedc73bd80992ae8d58a7d24c58b8322146c354f1d2e81a97db4452068ec0
          command: ["/bin/sh", "-c"]
          args:
            - |
              set -eu
              git init -q /src
              git -C /src remote add origin "$1"
              git -C /src fetch -q --depth=1 origin "$2"
              git -C /src checkout -q --detach FETCH_HEAD
              git -C /src log -1 --format=%ct > /meta/source-date-epoch
              echo "cloned $1 at $2: $(git -C /src rev-parse HEAD) epoch=$(cat /meta/source-date-epoch)"
            - clone
            - "__REPO_URL__"
            - "__REF__"
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: "1"
              memory: 1Gi
          volumeMounts:
            - name: src
              mountPath: /src
            - name: meta
              mountPath: /meta
      containers:
        - name: build
          image: moby/buildkit:v0.34.1-rootless@sha256:f68752a5a94acfcdad2d07867b7075601a421638e17fc5f28efc1c814d0c4f89
          command: ["/bin/sh", "-c"]
          args:
            - |
              set -eu
              cloned_epoch="$(cat /meta/source-date-epoch)"
              if [ "${cloned_epoch}" != "__SOURCE_DATE_EPOCH__" ]; then
                echo "REF __REF__ is commit epoch ${cloned_epoch} in the cluster but __SOURCE_DATE_EPOCH__ in the local repository; run git fetch and retry" >&2
                exit 1
              fi
              mkdir -p "${XDG_RUNTIME_DIR}"
              buildctl-daemonless.sh build \
                --frontend dockerfile.v0 \
                --local context=/src \
                --local dockerfile=/src \
                --opt filename=__DOCKERFILE__ \
                --opt platform=linux/amd64 \
                --opt build-arg:SOURCE_DATE_EPOCH=__SOURCE_DATE_EPOCH__ \
                --metadata-file /meta/metadata.json \
                --output type=image,name=__IMAGE__:__TAG__,push=__PUSH__,rewrite-timestamp=true
              cat /meta/metadata.json
          env:
            - name: BUILDKITD_FLAGS
              value: "--oci-worker-no-process-sandbox"
            - name: XDG_RUNTIME_DIR
              value: "/run/user/1000"
            - name: DOCKER_CONFIG
              value: "/docker-config"
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: "2"
              memory: 4Gi
          volumeMounts:
            - name: src
              mountPath: /src
            - name: meta
              mountPath: /meta
            - name: buildkitd
              mountPath: /home/user/.local/share/buildkit
            - name: runtime
              mountPath: /run/user/1000
            - name: docker-config
              mountPath: /docker-config
              readOnly: true
      volumes:
        - name: src
          emptyDir: {}
        - name: meta
          emptyDir: {}
        - name: buildkitd
          emptyDir: {}
        - name: runtime
          emptyDir: {}
        - name: docker-config
          secret:
            secretName: docker-push
            items:
              - key: .dockerconfigjson
                path: config.json
```

## 2. Why each non-obvious line is there — do not "simplify" these away

- `args` on the init container ends with `- clone`, `- "__REPO_URL__"`, `- "__REF__"`. The first element is `$0` for `sh -c`; the ref arrives as `$2` and is never spliced into the script text, so a crafted ref cannot execute anything. Keep that shape.
- `git fetch --depth=1 origin "$2"` followed by `checkout --detach FETCH_HEAD` handles a branch, a tag and a full commit SHA; `git clone --branch` would fail on a SHA.
- The init container writes `/meta/source-date-epoch`; the build container compares it with the rendered `__SOURCE_DATE_EPOCH__` and exits non-zero on a mismatch. This catches a stale local checkout that would otherwise build a different commit than the pinned clock claims.
- `BUILDKITD_FLAGS` carries `--oci-worker-no-process-sandbox`; `XDG_RUNTIME_DIR` and the two writable mounts (`/home/user/.local/share/buildkit`, `/run/user/1000`) are what rootless BuildKit needs to start.
- `DOCKER_CONFIG` points at the mounted secret directory; `items:` remaps `.dockerconfigjson` to `config.json`, which is the filename BuildKit reads. Without the remap, auth fails in the same shape as a missing credential.
- `backoffLimit: 0` keeps a failed build from being retried into a second push; `ttlSecondsAfterFinished` keeps the Job and its logs readable for a day so the caller can fetch the digest after completion.
- `namespace: build` is fixed by the spec. The namespace and the `docker-push` secret are prerequisites, not deliverables.

## 3. Do not touch anything else

Do not edit `Makefile.docker`, `Makefile.k8s`, `k8s/Makefile`, `k8s/*.yaml`, `Dockerfile`, or any Go file. Do not create `hack/build-cluster.sh` — the next prompt owns it. Do not add a `CHANGELOG.md` bullet; the feature's single entry is written by the last prompt in this series.

## 4. Self-check before finishing

Re-run every command in `<verification>` and confirm each passes. Then walk Acceptance Criteria 6, 8, 9 and 10 against the file: the digest is catted into the log, the six repository tokens are present, the file is not under `k8s/`, and the secret mount carries the `items:` remap.

</requirements>

<constraints>

- `hack/build-job.yaml` must not live under `k8s/`, where `Makefile.k8s`'s `find . -name "*.yaml" | … kubectl apply` would adopt it as deploy state. `k8s/build-job.yaml` must not exist.
- The Job image is referenced by digest, not by a floating tag. Both container images carry a `@sha256:` digest.
- The push credential exists only as a cluster secret, mounted into the build pod. It is never written to the invoking machine, never passed as a make variable, and never printed. Do not add a `kind: Secret` to this file and do not inline any credential.
- The build must run rootless with `--oci-worker-no-process-sandbox`. No `privileged: true`, no `hostNetwork`, no `hostPID`, no `hostPath`, no Docker socket, no `hostIPC`.
- The build container carries no cluster credentials: no service-account token mount is needed, and no `automountServiceAccountToken: true` may be added.
- `REF` is passed as a clone argument, not interpolated into a shell string.
- The manifest must contain no occurrence of the string `bborbe/go-skeleton`: the repository identity arrives only through `__REPO_URL__` and `__IMAGE__`.
- Multi-arch is out of scope: the build targets `linux/amd64` only.
- No cache export/import (`--cache-to` / `--cache-from`) and no `--load`.
- Do not change image naming or tagging.
- Do NOT commit — dark-factory handles git.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `test -f hack/build-job.yaml` — the template exists.
2. `test ! -e k8s/build-job.yaml` — the template is not deploy state.
3. `[ "$(grep -cE 'REPO_URL|REF|TAG|DOCKERFILE|IMAGE|push=' hack/build-job.yaml)" -ge 6 ]` — the spec's parameterization tokens are present on at least six lines. Do not use bare `grep -c` as the assertion: it exits 1 when the count is 0.
4. `! grep -q 'bborbe/go-skeleton' hack/build-job.yaml` — no hardcoded repository identity.
5. `[ "$(grep -c 'sha256:' hack/build-job.yaml)" -eq 2 ]` — both images are digest-pinned.
6. `grep -q 'key: .dockerconfigjson' hack/build-job.yaml` and `grep -q 'path: config.json' hack/build-job.yaml` — the credential remap is present.
7. `grep -q 'buildctl-daemonless.sh build' hack/build-job.yaml` — the daemonless entrypoint is used.
8. `grep -q -- '--opt build-arg:SOURCE_DATE_EPOCH=__SOURCE_DATE_EPOCH__' hack/build-job.yaml` — the epoch reaches the frontend as a build arg.
9. `grep -q 'rewrite-timestamp=true' hack/build-job.yaml` — the exporter rewrites timestamps.
10. `grep -q 'oci-worker-no-process-sandbox' hack/build-job.yaml` — rootless worker flag present.
11. `! grep -q 'privileged' hack/build-job.yaml` — no privileged pod.
12. `! grep -q 'hostPath' hack/build-job.yaml` — no host filesystem access.
13. `grep -q 'namespace: build' hack/build-job.yaml` and `grep -q 'activeDeadlineSeconds: __DEADLINE_SECONDS__' hack/build-job.yaml`.
14. `grep -q 'kind: Job' hack/build-job.yaml` and `! grep -q 'kind: Secret' hack/build-job.yaml` — one workload, no inline credential.
15. `ROOTDIR=/workspace make precommit` — must exit 0. Only YAML and a new directory changed, so this is a regression gate rather than a compile gate; if `trivy` cannot reach its database, treat that as environmental and report it, but do not silence it in the Makefile.

Structural validation of the manifest against the Kubernetes schema is operator-side (it needs a cluster); the spec's Verification section already carries it.

</verification>
