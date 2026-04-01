# Changelog

All notable changes to this project will be documented in this file.

Please choose versions by [Semantic Versioning](http://semver.org/).

* MAJOR version when you make incompatible API changes,
* MINOR version when you add functionality in a backwards-compatible manner, and
* PATCH version when you make backwards-compatible bug fixes.

## v0.3.10

- update bborbe/* deps (errors, http, kafka, log, sentry, service)
- update indirect deps (grpc, google APIs, genai, containerd)
- add replace directives for anthropic-sdk-go and other modules

## v0.3.9

- Update dependencies (boltkv, kv, run, go-git, anthropic-sdk-go, and others)
- Replace ginkgolinter/types replace directive with opencontainers/runtime-spec
- Enable dark-factory autoRelease

## v0.3.8

- Update go-git/go-git to v5.17.1 (fix security vulnerabilities)
- Clean up unused osv-scanner ignore entries
- Add .trivyignore for docker indirect dep CVEs
- Improve trivy Makefile target with .trivyignore support and vendor skip

## v0.3.7

- Update bborbe/* libraries (boltkv, errors, http, kafka, kv, log, run, sentry, service, time)
- Update golangci-lint to v2.11.4 and gosec to v2.25.0
- Update docker, containerd, moby dependencies
- Update golang.org/x/* and opentelemetry packages
- Remove unused exclude directives and clean up go.mod

## v0.3.6

- chore: validate project health — all tests, linting, and precommit checks pass

## v0.3.5

- go mod update

## v0.3.4

- go mod update

## v0.3.3

- remove accidentally committed docs/improvements.md

## v0.3.2

- go mod update

## v0.3.1

- Update GitHub workflows to v1 plugin system
- Simplify Claude Code action with inline conditions
- Add ready_for_review and reopened triggers

## v0.3.0

- optimize Docker build with BuildKit cache mounts for dependencies and build artifacts
- remove go mod vendor step from build process
- remove --no-cache flag to leverage Docker layer caching
- sanitize branch names in Docker tags (replace / with -)
- fix k8s Makefile include paths

## v0.2.14

- Update Go to 1.25.7
- Update github.com/bborbe/errors to v1.5.2
- Update github.com/bborbe/log to v1.6.2
- Update github.com/bborbe/sentry to v1.9.6
- Update github.com/bborbe/time to v1.22.0

## v0.2.13

- Update Go dependencies (sentry, time, ginkgo, gomega, etc.)
- Remove Gemini CI workflows
- Add doc comment to BuildInfoMetrics

## v0.2.12

- add build info Prometheus metrics with timestamp tracking
- change BuildDate field to use libtime.DateTime type
- add GoDoc comments for exported types and functions

## v0.2.11

- update golang to 1.25.6
- update alpine to 3.23
- update github.com/bborbe/* dependencies
- update getsentry/sentry-go to v0.41.0
- update IBM/sarama to v1.46.3

## v0.2.10
- Update Docker image name from bborbe/skeleton to bborbe/go-skeleton

## v0.2.9
- Fix module path URLs from skeleton to go-skeleton across all files
- Update all dependencies to latest versions

## v0.2.8
- Fix security vulnerabilities by updating Go version and dependencies
- Disable unparam linter for tests to resolve build failures

## v0.2.7

- Update Go version from 1.25.3 to 1.25.4
- Update containerd from 1.7.27 to 1.7.29 to fix security vulnerabilities
- Update opencontainers/selinux from 1.12.0 to 1.13.0 to fix security vulnerabilities
- Update cyphar/filepath-securejoin from 0.5.0 to 0.6.0
- Add gomodprepare Makefile target for consistent go.mod configuration
- Add additional k8s.io version excludes to go.mod

## v0.2.6

- Add depguard rule to block deprecated io/ioutil package
- Add depguard rule to block deprecated golang.org/x/lint/golint package

## v0.2.5

- Use relative path in gexec.Build test for improved portability

## v0.2.4

- Add OCI image labels to Dockerfile for better container metadata
- Enable race detection in test suite for improved concurrency safety testing
- Add table of contents to README for easier navigation
- Expand configuration documentation with runtime and build/deployment variables
- Clean up unused dependencies (move k8s.io/code-generator and gogen-avro to indirect)
- Remove unused tool imports from tools.go

## v0.2.3

- Remove codecov badge from README

## v0.2.2

- Add standard Go project badges (Go Reference, CI, Go Report Card, codecov)
- Add Installation, API Documentation, and License sections to README
- Add Ginkgo v2 to tools.go for consistent test framework dependency tracking
- Improve README structure with horizontal rules for better visual separation

## v0.2.1

- Add GoDoc comments for all exported handler and factory functions
- Improve error handling consistency by replacing errors.Wrapf with errors.Wrap
- Add pkg test suite setup with Ginkgo v2 and Gomega

## v0.2.0

- Add build metadata support (Git version, commit hash, and build timestamp)
- Docker container now exposes build information via environment variables
- Build metadata automatically injected during Docker build process

## v0.1.0

- Initial release
