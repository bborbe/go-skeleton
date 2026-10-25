---
status: verifying
approved: "2026-10-25T14:14:20Z"
generating: "2026-10-25T14:14:21Z"
verifying: "2026-10-25T14:28:37Z"
branch: dark-factory/build-target
---

## Summary

- `make build` gains a `BUILD_TARGET` selector. `local` — the default — keeps today's `docker build` invocation; naming a cluster instead renders and applies a Kubernetes Job, waits for it, and reports its result.
- The Job runs `buildctl-daemonless.sh` against a rootless `moby/buildkit` image, clones the requested git ref, builds `linux/amd64`, and pushes to `docker.io/bborbe/go-skeleton:<TAG>` using a credential mounted inside the pod.
- The Job spec lives at `hack/build-job.yaml` and is parameterized by six tokens — repo URL, git ref, image tag, Dockerfile path, target image, push flag — so the same spec serves other repositories.
- The build clock is pinned: `SOURCE_DATE_EPOCH` derives from the built commit and the exporter rewrites layer timestamps, so two builds of the same ref can produce the same image digest.
- The local path's observable behaviour is unchanged: same tag, same platform, image present in the local Docker store, `make upload` still pushes it.

## Problem

Every `bborbe` image build today runs `docker build` on whichever machine invokes `make build`. That serialises releases on one Mac and makes it a single point of failure: if the machine is asleep, unavailable, or its Docker daemon is stopped, no release image can be cut.

This repo is the reference implementation for moving that build onto cluster infrastructure, so it must demonstrate two things at once — that the default path is unchanged, and that a cluster can produce the same artifact. It also settles the executor question: the buildx Kubernetes driver forwards the client's registry credentials, which keeps the push credential on the invoking machine, so it cannot be used. A `buildctl-daemonless.sh` Job holds the credential inside the pod instead.

## Goal

`make build` with no `BUILD_TARGET` behaves exactly as it does today. `BUILD_TARGET=<cluster> make build BRANCH=<tag> REF=<git-ref>` creates a Job in that cluster, which clones the ref, builds and pushes the image; the make target blocks until the Job reaches a terminal state and exits non-zero if it failed. The Job spec is one reusable, parameterized file at `hack/build-job.yaml` that `make apply` never adopts as deploy state.

## Non-goals

- Migrating any other repository. This is the reference implementation only.
- Changing image naming or tagging — `$(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH)` stays.
- Build cache export/import (`--cache-to` / `--cache-from`). Cold-cache cost is recorded, not solved.
- Loading the built image back to the invoking machine (`--load`). Rejected, not deferred: it keeps the push credential on the local machine.
- Pushing to the in-cluster registries. Those stay a mirror; the build's push target is `docker.io`.
- Multi-arch images. `linux/amd64` only, matching the cluster nodes.
- Provisioning cluster namespaces or credentials. Those are prerequisites, not deliverables.
- A buildx Kubernetes driver path, a Kaniko path, or any second executor. One executor ships.

## Acceptance Criteria

- [ ] **`BUILD_TARGET` defaults to `local` and the local invocation is unchanged** — evidence: `make -n build` with no `BUILD_TARGET` emits the same `docker build` arguments as `git show origin/master:Makefile.docker` apart from the clock pinning, specifically `--platform=linux/amd64`, `-t $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH)` and `-f Dockerfile .`.
- [ ] **The local path still produces an image in the local Docker store** — evidence: after `docker rmi docker.io/bborbe/go-skeleton:<tag>` and `make build BRANCH=<tag>` with no `BUILD_TARGET`, `docker image inspect -f '{{.Id}}' docker.io/bborbe/go-skeleton:<tag>` exits 0.
- [ ] **The local path does not create a cluster Job** — evidence: `kubectl -n build get jobs -o name | grep <tag>` returns 0 lines on every configured cluster during a default `make build`.
- [ ] **`make upload` still works** — evidence: `make upload BRANCH=<tag>` exits 0 and `crane digest docker.io/bborbe/go-skeleton:<tag>` returns a digest for a tag that did not exist before the run.
- [ ] **A cluster target creates and completes a Job** — evidence: `BUILD_TARGET=<cluster> make build BRANCH=<tag> REF=<ref>` exits 0, and `kubectl -n build get job build-<tag> -o jsonpath='{.status.succeeded}'` returns `1`.
- [ ] **The Job pushes the image and the make target reports the digest** — evidence: the Job's log contains `pushing manifest for docker.io/bborbe/go-skeleton:<tag>@sha256:` and `containerimage.digest` appears in the catted `--metadata-file` output; `crane digest docker.io/bborbe/go-skeleton:<tag>` returns the same digest.
- [ ] **The build clock is pinned** — evidence: two consecutive builds of the same ref on the same machine produce the same image ID, and the Job's `.spec.template.spec.containers[0].args` contains a literal `--opt build-arg:SOURCE_DATE_EPOCH=<epoch>` equal to `git log -1 --format=%ct <ref>`.
- [ ] **The Job spec is parameterized, not hardcoded** — evidence: `grep -cE 'REPO_URL|REF|TAG|DOCKERFILE|IMAGE|push=' hack/build-job.yaml` returns ≥ 6, and `grep -c 'bborbe/go-skeleton' hack/build-job.yaml` returns 0 outside a comment.
- [ ] **The Job spec is never adopted as deploy state** — evidence: `hack/build-job.yaml` exists, `k8s/build-job.yaml` does not, and `make -C k8s -n apply` output contains no reference to it.
- [ ] **The push credential is mounted in the pod, not on the invoking machine** — evidence: the Job's `.spec.template.spec.volumes` references a secret with an `items:` remap from `.dockerconfigjson` to `config.json`, and the cluster build succeeds on a host with no Docker credential configured.
- [ ] **`make precommit` passes** — evidence: exit code 0.

## Verification

### Container-executable (runs inside the YOLO container at prompt time)

- `make precommit` — lint, vet and the test suite exit 0
- `grep -n 'BUILD_TARGET' Makefile.docker` — the selector exists
- `grep -cE 'REPO_URL|REF|TAG|DOCKERFILE|IMAGE|push=' hack/build-job.yaml` — returns ≥ 6
- `test -f hack/build-job.yaml && test ! -e k8s/build-job.yaml` — placement assertion
- `make -n build` — the default recipe still emits the unchanged `docker build` arguments

### Operator-executable (runs on the host after PR merge)

- `docker rmi docker.io/bborbe/go-skeleton:<tag> && make build BRANCH=<tag>` — the local path still lands an image
- `make upload BRANCH=<tag>` — the upload path still pushes
- `BUILD_TARGET=<cluster> make build BRANCH=<tag> REF=<ref>` — a cluster Job runs to completion
- `kubectl -n build get job build-<tag> -o jsonpath='{.status.succeeded}'` — returns `1`
- `crane digest docker.io/bborbe/go-skeleton:<tag>` — returns the digest the Job pushed

## Desired Behavior

1. `make build` with no `BUILD_TARGET`, or `BUILD_TARGET=local`, runs the existing `docker build` recipe and leaves the image in the local Docker store under `$(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH)`.
2. `BUILD_TARGET=<cluster>` renders `hack/build-job.yaml` with the run's values, applies it to the cluster's `build` namespace, and blocks until the Job reaches a terminal state.
3. The make target exits 0 when the Job succeeded and non-zero when it failed, printing the Job's pod log tail in the failure case so the cause is visible without a separate `kubectl` call.
4. The Job's git initContainer clones the requested `REF` — not the default branch — into an `emptyDir`, and derives `SOURCE_DATE_EPOCH` from that commit.
5. The build container runs `buildctl-daemonless.sh build` with `--opt rewrite-timestamp=true`, `--opt build-arg:SOURCE_DATE_EPOCH=<epoch>`, and `--output type=image,name=<IMAGE>:<TAG>,push=<push>`.
6. The push credential is read from a mounted secret whose `items:` remap presents it as `config.json` under `DOCKER_CONFIG`.
7. `BUILD_TARGET=local` never touches a cluster: no Job is created, no cluster context is required, and the target works on a machine with no kubeconfig.
8. The Job is named `build-<TAG>` so a run can be located by the tag it produced.

## Constraints

- `Makefile.docker`'s `buca` target keeps its current composition — `build upload clean apply`.
- `DOCKER_REGISTRY`, `SERVICE` and `BRANCH` keep their current definitions and meanings. `BRANCH` remains the image tag.
- The `local` recipe's `docker build` arguments must not change beyond the clock pinning; `--platform=linux/amd64`, `-f Dockerfile .` and `--rm=true` stay.
- `hack/build-job.yaml` must not live under `k8s/`, where `Makefile.k8s:3`'s `find . -name "*.yaml" | … kubectl apply` would adopt it.
- The Job image is referenced by digest, not by a floating tag.
- No new runtime dependency in the built image; the change is build tooling only.
- The `local` path must work with no kubeconfig and no cluster credentials present.

## Failure Modes

| Trigger | Expected behavior | Recovery |
|---|---|---|
| `BUILD_TARGET` names an unknown cluster | The make target fails before rendering, listing the accepted values | Rerun with a valid target |
| The cluster is unreachable | The make target fails with the connection error; no partial Job is left | Rerun when the cluster is available |
| The Job is rejected at admission (pod-security, RBAC) | The make target prints the Job's events and exits non-zero | Fix the namespace's policy or the Job's security context |
| The git clone fails in the initContainer | The Job fails; its log names the ref and the git error | Correct `REF`, or verify the ref exists on the remote |
| The registry push is refused | The Job fails at the push; its log carries the registry error | Verify the mounted secret and its `items:` remap |
| The Job exceeds its deadline | The make target fails and names the deadline it waited | Raise the deadline, or investigate why the build stalled |
| `make build` is interrupted mid-wait | The Job continues in the cluster; a later `kubectl get job build-<TAG>` reports its state | Read the Job's state, or delete it explicitly |

## Security / Abuse

- The push credential exists only as a cluster secret, mounted into the build pod. It is never written to the invoking machine, never passed as a make variable, and never printed.
- The `items:` remap is load-bearing: without it the secret file keeps its own name while Docker looks for `config.json`, and auth fails silently in the same shape a missing credential produces.
- `buildctl-daemonless.sh` runs rootless with `--oci-worker-no-process-sandbox`. No privileged pod, no host namespace, no Docker socket.
- The build container carries no cluster credentials — it cannot create, read or modify other resources.
- `REF` is passed as a clone argument, not interpolated into a shell string, so a crafted ref cannot execute commands in the initContainer.

## Suggested Decomposition

| # | Prompt focus | Covers DBs | Covers ACs | Depends on |
|---|---|---|---|---|
| 1 | `BUILD_TARGET` selector and clock pinning in `Makefile.docker` | 1, 7 | 1, 2, 3, 4, 7, 11 | — |
| 2 | `hack/build-job.yaml` — the parameterized Job | 4, 5, 6, 8 | 6, 8, 9, 10 | — |
| 3 | The cluster branch: render, apply, wait, report | 2, 3 | 5, 6 | prompts 1, 2 |

Rationale: prompt 1 changes only the local recipe and is independently verifiable; prompt 2 authors a static manifest with no Go code; prompt 3 is the only prompt that shells out to a cluster and needs both prior artifacts.

## Do-Nothing Option

Every `bborbe` release image keeps requiring the Mac. The migration guide has no reference implementation to point at, and the fleet rollout stays blocked on a design nobody has executed. The cost of not doing this is that the goal's other five tasks rest on an unverified assumption — that a cluster can build this repo at all.
