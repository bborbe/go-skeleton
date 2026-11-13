---
status: completed
spec: [003-build-target]
summary: Added BUILD_TARGET selector (local default / cluster handoff) and commit-pinned build clock to Makefile.docker, leaving all other targets unchanged
execution_id: go-skeleton-build-target-exec-009-spec-003-build-target-selector
dark-factory-version: v0.198.7
created: "2026-10-25T14:21:43Z"
queued: "2026-10-25T14:23:39Z"
started: "2026-10-25T14:23:41Z"
completed: "2026-10-25T14:24:56Z"
---

# Add BUILD_TARGET selector and pinned build clock to Makefile.docker

<summary>
- `make build` behaves exactly as it does today when no target is named: same platform, same image tag, same Dockerfile, same build context.
- A new selector decides whether a build runs on the local Docker daemon or inside a cluster.
- The build clock is taken from the built commit instead of the wall clock, so two builds of the same commit can produce the same image.
- The local build no longer stamps a fresh timestamp into every image, which is the only change to its arguments.
- Naming a cluster stops the local Docker path from running and hands off to a cluster build script instead.
- That cluster script does not exist yet; it arrives in a later prompt, and until then only the cluster branch is affected.
- `make upload`, `make clean` and `make buca` keep their current composition and behaviour.
- An operator can see which path a given invocation will take with `make -n build`, before anything executes.
</summary>

<objective>
Introduce a `BUILD_TARGET` selector in `Makefile.docker` so that `make build` defaults to the existing local `docker build` and can instead delegate to an in-cluster build, while pinning the build clock to the built commit so repeated builds of one commit can be byte-identical. The local path must remain observably unchanged apart from that clock, because it is the release path that must keep working while the cluster path is proven.
</objective>

<context>
Read these files before editing (repo-relative):

- `specs/in-progress/003-build-target.md` — the source spec. Read "Goal", "Constraints", "Desired Behavior" items 1 and 7, and "Failure Modes".
- `Makefile.docker` — the file you change. It defines `build`, `upload`, `clean`, `apply`, `buca`, and `DIRS`.
- `Makefile.variables` — `BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD | tr '/' '-')` and `ROOTDIR`. `BRANCH` stays the image tag; do not redefine it.
- `Makefile` — `SERVICE = bborbe/go-skeleton` is defined **after** the `include` lines, and `include example.env` supplies `DOCKER_REGISTRY=docker.io`. A variable defined in `Makefile.docker` with `?=` is expanded lazily, so it can reference `$(SERVICE)` even though `SERVICE` is defined later.
- `example.env` — `DOCKER_REGISTRY=docker.io`, `IMAGE=bborbe/go-skeleton`, `CLUSTER_CONTEXT=test`.
- `Dockerfile` — consumes `DOCKER_REGISTRY`, `BRANCH`, `BUILD_GIT_VERSION`, `BUILD_GIT_COMMIT`, `BUILD_DATE` as build args. It does **not** declare `ARG SOURCE_DATE_EPOCH`; BuildKit still consumes that build arg for timestamp clamping, so a benign "unused build-arg" warning is expected and must not be "fixed" by editing the Dockerfile.

Environment note: this repository's `.git` is masked inside the execution container, so every `git` invocation in a shell function expands to an empty string there. That is why the verification steps below never assert on the value of a git-derived variable — only on the flags that surround it.

Cluster-build handoff contract (load-bearing: a later prompt implements the receiving script, and the two must agree exactly). The `else` branch of the `build` target invokes `hack/build-cluster.sh` with these environment variables:

| variable | value passed by the recipe |
|---|---|
| `BUILD_TARGET` | `$(BUILD_TARGET)` |
| `NAMESPACE` | `$(BUILD_NAMESPACE)` (default `build`) |
| `REPO_URL` | `$(BUILD_REPO_URL)` (default `https://github.com/$(SERVICE).git`) |
| `REF` | `$(REF)` |
| `TAG` | `$(BRANCH)` |
| `DOCKERFILE` | `$(BUILD_DOCKERFILE)` (default `Dockerfile`) |
| `IMAGE` | `$(DOCKER_REGISTRY)/$(SERVICE)` |
| `PUSH` | `true` |
| TIMEOUT` | `$(BUILD_TIMEOUT)` (default `3600`) |

`SOURCE_DATE_EPOCH` is **not** passed to the script: the script derives it from `REF` itself (a `$(shell git ...)` in the Makefile would interpolate a user-supplied `REF` into a shell string, and would also break the local path when `REF` is unset). The local branch computes `SOURCE_DATE_EPOCH` from `HEAD`.
</context>

<requirements>

## 1. Add the selector and clock variables

In `Makefile.docker`, immediately after the existing `DIRS += $(shell find */* -maxdepth 0 -name Makefile -exec dirname "{}" \;)` line and before `.PHONY: build`, add:

```make
# BUILD_TARGET selects where `make build` runs. `local` (the default) uses the
# local Docker daemon; any other value must name a kubectl context and builds
# inside that cluster as a Job rendered from hack/build-job.yaml.
BUILD_TARGET ?= local
BUILD_NAMESPACE ?= build
BUILD_TIMEOUT ?= 3600
BUILD_REPO_URL ?= https://github.com/$(SERVICE).git
BUILD_DOCKERFILE ?= Dockerfile

# Build clock, pinned to the built commit instead of the wall clock so that two
# builds of the same commit can produce the same image. SOURCE_DATE_EPOCH is
# consumed by BuildKit for timestamp clamping; BUILD_DATE is the value the
# Dockerfile bakes into the image labels.
SOURCE_DATE_EPOCH ?= $(shell git log -1 --format=%ct)
BUILD_DATE ?= $(shell git log -1 --format=%cI)
```

## 2. Split the `build` target on `BUILD_TARGET`

Replace the whole existing `build` target with the following. The `local` recipe is the current recipe verbatim except for two clock lines: `BUILD_DATE` now reads `$(BUILD_DATE)` instead of `$$(date -u +%Y-%m-%dT%H:%M:%SZ)`, and one `--build-arg SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH)` line is added. Every other argument — `--rm=true`, `--platform=linux/amd64`, `-t $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH)`, `-f Dockerfile .` — is unchanged, in the same order.

```make
.PHONY: build
build:
ifeq ($(BUILD_TARGET),local)
	DOCKER_BUILDKIT=1 \
	docker build \
	--rm=true \
	--platform=linux/amd64 \
	--build-arg DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	--build-arg BRANCH=$(BRANCH) \
	--build-arg BUILD_GIT_VERSION=$$(git describe --tags --always --dirty) \
	--build-arg BUILD_GIT_COMMIT=$$(git rev-parse --short HEAD) \
	--build-arg BUILD_DATE=$(BUILD_DATE) \
	--build-arg SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	-t $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH) \
	-f Dockerfile .
else
	BUILD_TARGET='$(BUILD_TARGET)' \
	NAMESPACE='$(BUILD_NAMESPACE)' \
	REPO_URL='$(BUILD_REPO_URL)' \
	REF='$(REF)' \
	TAG='$(BRANCH)' \
	DOCKERFILE='$(BUILD_DOCKERFILE)' \
	IMAGE='$(DOCKER_REGISTRY)/$(SERVICE)' \
	PUSH='true' \
	TIMEOUT='$(BUILD_TIMEOUT)' \
	hack/build-cluster.sh
endif
```

The `ifeq` / `else` / `endif` directives must start in column 0 (no leading tab). Command-line and environment assignments are in effect before makefiles are parsed, so `make build BUILD_TARGET=test` selects the `else` branch.

Do **not** add a `REF` default. An unset `REF` must stay empty and reach the script as an empty string, so the script can refuse it with a message naming the variable. Do not add an `ifeq` case for `local` spelled any other way; `local` is the only local value.

## 3. Leave the rest of the file alone

`upload`, `clean`, `apply` and `buca` must stay byte-identical. In particular `buca: build upload clean apply` keeps that order, so `make buca` with the default `BUILD_TARGET` still builds locally and uploads.

## 4. Do not touch CHANGELOG.md

This prompt is the first of three for one user-visible feature. The single `## Unreleased` bullet for the feature is written by the last prompt in the series. Do not add a bullet here; a second bullet for the same feature is a defect.

## 5. Self-check before finishing

Re-run every command in `<verification>` and confirm each passes. Then walk the spec's Acceptance Criteria 1, 2, 3, 4, 7 and 11 against the change and confirm that none of them is contradicted by the new recipe (the cluster-side criteria 5, 6, 8, 9 and 10 are out of scope for this prompt).

</requirements>

<constraints>

- `DOCKER_REGISTRY`, `SERVICE` and `BRANCH` keep their current definitions and meanings. `BRANCH` remains the image tag. Do not redefine or rename them.
- The `local` recipe's `docker build` arguments must not change beyond the clock pinning. `--platform=linux/amd64`, `--rm=true`, `-t $(DOCKER_REGISTRY)/$(SERVICE):$(BRANCH)` and `-f Dockerfile .` stay exactly as they are.
- `Makefile.docker`'s `buca` target keeps its current composition — `build upload clean apply`.
- `BUILD_TARGET=local` must never touch a cluster: no Job is created, no cluster context is required, and the target must work on a machine with no kubeconfig. This is why the script is invoked only from the `else` branch and why `kubectl` appears nowhere in `Makefile.docker`.
- Do not change image naming or tagging.
- Do not add a new runtime dependency to the built image; this is build tooling only.
- Do not edit `Dockerfile`, `k8s/`, `hack/`, or any Go file.
- Do not create `hack/build-cluster.sh` — a later prompt in this series owns that file. Until it lands, only `make build BUILD_TARGET=<cluster>` fails, and it fails loudly with "No such file or directory".
- Do NOT commit — dark-factory handles git.
- Existing tests must still pass.

</constraints>

<verification>

Run each command from the repository root. Each must succeed.

1. `grep -n 'BUILD_TARGET' Makefile.docker` — prints at least the three occurrences (assignment, `ifeq`, recipe pass-through).
2. `make -n build BRANCH=test | grep -q -- '--platform=linux/amd64'` — the local platform is unchanged.
3. `make -n build BRANCH=test | grep -q -- '-t docker.io/bborbe/go-skeleton:test'` — the local tag is unchanged.
4. `make -n build BRANCH=test | grep -q -- '-f Dockerfile .'` — the local Dockerfile and context are unchanged.
5. `make -n build BRANCH=test | grep -q -- '--rm=true'` — still present.
6. `make -n build BRANCH=test | grep -q -- '--build-arg SOURCE_DATE_EPOCH='` — the clock arg is present. Do not assert its value: `.git` is masked in this container, so it expands empty here.
7. `! make -n build BRANCH=test | grep -q 'build-cluster.sh'` — the default path does not reach the cluster branch.
8. `! make -n build BRANCH=test | grep -q 'kubectl'` — the default path requires no cluster tooling.
9. `make -n build BUILD_TARGET=test BRANCH=test REF=master | grep -q 'hack/build-cluster.sh'` — naming a cluster reaches the script.
10. `make -n build BUILD_TARGET=test BRANCH=test REF=master | grep -q "REF='master'"` — the ref is passed through as an environment assignment.
11. `make -n upload BRANCH=test | grep -q 'docker push docker.io/bborbe/go-skeleton:test'` — upload is untouched.
12. `make -n buca BRANCH=test | grep -q 'docker build'` and `make -n buca BRANCH=test | grep -q 'docker push'` — `buca` still composes build and upload.
13. `ROOTDIR=/workspace make precommit` — must exit 0. Note: this repository's `make` does not read a `default.env`, but `ROOTDIR` is passed for consistency with the container convention; the run must not fail because of the masked `.git`.

</verification>
