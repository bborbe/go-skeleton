# Moving `make build` off the Mac

How to take a `bborbe` repo that builds its container image on the invoking machine and move that build into a cluster. Written against `go-skeleton`, which carries the reference implementation in `hack/` and `Makefile.docker`.

The build does not change shape: same Dockerfile, same build args, same tag. Only the machine running BuildKit changes. The executor is a `buildctl-daemonless.sh` Job, which mounts the push credential inside the pod — so the registry credential never sits on the Mac. (A buildx builder with the kubernetes driver would forward the client's registry auth and keep the credential where this change exists to remove it.)

## Prerequisites

| You need | Why | Check |
|---|---|---|
| `kubectl` and a kubeconfig for the target cluster | the build is a Job in that cluster | `kubectl config get-contexts` |
| `crane` | read the pushed digest back without pulling | `crane version` |
| `teamvault-config-parser` | resolves the credential template | `command -v teamvault-config-parser` |
| `TEAMVAULT` exported | the parser's `-teamvault-config` value, same as `make apply` | `test -n "$TEAMVAULT"` |
| A docker.io credential for the pushing account | the Job pushes on your behalf | — |
| The `build` namespace and push secret | see below | `kubectl -n build get secret` |

The cluster must be able to pull the source repo at the ref being built, and reach the registry it pushes to.

## Bootstrap the cluster

One command, idempotent, run once per cluster:

```
hack/build-cluster-bootstrap.sh sun
```

It creates the `build` namespace and the `kubernetes.io/dockerconfigjson` secret named by `BUILD_PUSH_SECRET` (default `buildkit-push`). Running it twice exits 0 and changes nothing.

It creates **no Job**. Jobs are per-build, rendered from `hack/build-job.yaml` by `hack/build-cluster.sh`, which refuses to run when one already exists:

```
build-cluster: job build/build-proof already exists; delete it with: kubectl --context default -n build delete job build-proof
```

The Job name is `build-` plus the tag, lowercased and DNS-sanitised (`hack/build-cluster.sh`), so it is per-branch, not per-repo.

That message is not an error in provisioning — it means a previous build's Job is still there. Delete it and re-run.

The credential comes from `hack/dockerconfig.json.tpl`, which holds a TeamVault lookup key, not a value. The rendered JSON is written to a `600` temp file, used for one `kubectl create secret --dry-run`, and removed. Never print it, never commit it.

## Change the repo

### 1. The `Makefile.docker` diff

`BUILD_TARGET` already selects the path in `go-skeleton`:

```make
BUILD_TARGET ?= local
BUILD_NAMESPACE ?= build
BUILD_TIMEOUT ?= 3600
BUILD_REPO_URL ?= https://github.com/$(SERVICE).git
BUILD_DOCKERFILE ?= Dockerfile
BUILD_PUSH_SECRET ?= buildkit-push

build:
ifeq ($(BUILD_TARGET),local)
	DOCKER_BUILDKIT=1 docker build ... -t $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH) -f Dockerfile .
else
	BUILD_TARGET='$(BUILD_TARGET)' NAMESPACE='$(BUILD_NAMESPACE)' \
	REPO_URL='$(BUILD_REPO_URL)' REF='$(REF)' TAG='$(BRANCH)' \
	DOCKERFILE='$(BUILD_DOCKERFILE)' IMAGE='$(DOCKER_REGISTRY)/$(SERVICE)' \
	PUSH='true' PUSH_SECRET='$(BUILD_PUSH_SECRET)' TIMEOUT='$(BUILD_TIMEOUT)' \
	hack/build-cluster.sh
endif
```

`REF` is what gets cloned. Set it explicitly for a release build — a Job that clones the default branch while claiming to build a tag produces an image that matches no release and cannot be reproduced later.

The `build` target alone is not enough. `upload` and `clean` must also become no-ops for remote targets, because the Job already pushed and no local image exists:

```make
upload:
ifeq ($(BUILD_TARGET),local)
	docker push $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH)
endif

clean:
ifeq ($(BUILD_TARGET),local)
	docker rmi $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH) || true
	docker builder prune --max-used-space 21474836480 -f || true
endif
```

Without the `upload` guard, `make buca BUILD_TARGET=sun` fails at the end of an otherwise successful build with `An image does not exist locally with the tag` — the build worked, the push step is looking in the wrong place.

### 2. The variables

| Variable | Default | What it does |
|---|---|---|
| `BUILD_TARGET` | `local` | `local` keeps the Docker daemon; anything else names a cluster |
| `BUILD_PUSH_SECRET` | `buildkit-push` | name of the `dockerconfigjson` secret the Job mounts |
| `BUILD_NAMESPACE` | `build` | namespace the Job runs in |
| `BUILD_REPO_URL` | `https://github.com/$(SERVICE).git` | what the init container clones |
| `BUILD_TIMEOUT` | `3600` | seconds before the runner gives up |
| `REF` | — | the ref to clone; **set this for a release build** |

### 3. `upload` becomes a no-op

Covered by the guard above. The symptom of missing it is at the *end* of a successful run, which makes it look like a build failure rather than a Makefile one.

### 4. A remote build pushes and never loads

There is no `--load` path. The image exists in the registry and nowhere on the Mac. `docker images` will not show it; you cannot `docker run` it locally. Read the result back with `crane`:

```
crane digest $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH)
```

This is deliberate. Loading would require pulling the image back over the network to a machine the change exists to take out of the build path.

### 5. The secret name is not portable

`BUILD_PUSH_SECRET` defaults to `buildkit-push`, and both `sun` and `nukedev` carry a secret of that name. `nukedev` *also* carries a `docker` secret — a reflector mirror of `docker-registry/docker`. Do not reuse it: it is a different credential for a different registry.

**Symptom:** the pod sits `Pending` and the event is `FailedMount`. That reads as a build failure; it is a missing secret.

**Check:** `kubectl -n build get secret -o name`.

### 6. The init container's clone trips git's ownership guard

The init container clones into the shared `src` volume, and the build container runs as a different uid (`runAsUser: 1000`). Git sees a repository owned by someone else and refuses:

```
fatal: detected dubious ownership in repository at '/src'
```

Exit **128**, inside the init container, while the Job still reports `Running` — so the outer `make` looks alive while the build never started.

**Fix:** mark the checkout safe in the init container's environment:

```yaml
env:
  - name: GIT_CONFIG_COUNT
    value: "1"
  - name: GIT_CONFIG_KEY_0
    value: safe.directory
  - name: GIT_CONFIG_VALUE_0
    value: /src
```

or make `git config --global --add safe.directory /src` the init container's first command.

`hack/build-job.yaml` in `go-skeleton` already carries the env block. The failure appears when a repo hand-rolls its own manifest, or copies an older one.

### 7. `BUILD_TARGET` names a cluster, not a kubectl context

The contexts are not the cluster names: sun's context is literally `default`, and it lives in its own kubeconfig file. `hack/cluster-alias.sh` resolves the alias so nobody has to type the raw form:

| Alias | Kubeconfig | Context |
|---|---|---|
| `sun` | `${HOME}/.kube/sun` | `default` |
| `nukedev` | `${HOME}/.kube/nuke-dev` | `nuke-dev` |
| `nukeprod` | `${HOME}/.kube/nuke-prod` | `nuke-prod` |

A value that is not an alias is treated as a plain context name, so the raw form still works. Both `build-cluster.sh` and `build-cluster-bootstrap.sh` source the same file, so provisioning and building cannot disagree.

**Symptom of a wrong target:** the build runs, succeeds, and lands in a cluster you did not mean — or fails with `context "sun" does not exist` on an older revision that had no mapping.

## Costs

### Cold caches

A first build against a cluster downloads every dependency; later builds reuse the cache mount. The numbers are measured on this repo and recorded below.

| Run | Wall clock | Notes |
|---|---|---|
| first remote build | _pending measurement_ | empty cache mount |
| warm local build | _pending measurement_ | populated local cache |

Treat the first number as a one-off per cluster. It is not a regression.

### `upload` is a no-op

`make buca` still works, but on a remote target its `upload` step does nothing — the Job already pushed. Anything that depended on a local image being present afterwards (`docker run`, a local compose stack, an image scan run on the Mac) needs a `docker pull` first.

## Verify

From a clean cluster-side state — secret deleted, no rendered Job, no local image — follow only this page:

1. `hack/build-cluster-bootstrap.sh sun` → exits 0
2. `make build BUILD_TARGET=sun BRANCH=proof REF=v0.6.0` → exits 0 and prints a digest
3. `kubectl -n build get pod` → the build pod's `spec.nodeName` is a node in the **sun** cluster, not the Mac
4. `crane digest <image>:proof` → resolves, and matches the digest the build printed

All four, or the run did not pass. Steps 3 and 4 are the ones a no-op cannot fake: a build that silently ran on the Mac cannot name a sun node, and a build that never pushed cannot produce a resolvable digest.

## Rollback

Set `BUILD_TARGET=local` (or unset it) — the default path is untouched. Deleting the `build` namespace removes the secret and any rendered Job; the next bootstrap recreates both.
