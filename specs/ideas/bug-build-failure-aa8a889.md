---
status: idea
kind: bug
---

# Build Failure: bborbe/go-skeleton

Filed automatically by the build-fix agent for the CI episode `aa8a88923c12fbe2b438e7e8f29ddbd083ab9f9d`.

## Summary

The default-branch build for `bborbe/go-skeleton` is failing; the build-fix diagnosis classified this as a code/test bug (verdict `file_spec`).

## Reproduction

Failing workflow(s): test

Episode SHA: `aa8a88923c12fbe2b438e7e8f29ddbd083ab9f9d`

Log evidence:

```text
| Workflow | Job | Failed Step | Run |
|---|---|---|---|
| CI | test | Run precommit checks | [Run](https://github.com/bborbe/go-skeleton/actions/runs/42420450490) |

```
2026-11-07T22:26:21.7140321Z Temporarily overriding HOME='/home/runner/work/_temp/03dba284-73d6-412f-88ab-9c7d392f70de' before making global git config changes
2026-11-07T22:26:21.7141206Z Adding repository directory to the temporary git global config as a safe directory
2026-11-07T22:26:21.7145114Z [command]/usr/bin/git config --global --add safe.directory /home/runner/work/go-skeleton/go-skeleton
2026-11-07T22:26:21.7178027Z Removing SSH command configuration
2026-11-07T22:26:21.7183598Z [command]/usr/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-11-07T22:26:21.7217185Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-11-07T22:26:21.7433873Z Removing HTTP extra header
2026-11-07T22:26:21.7439517Z [command]/usr/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-11-07T22:26:21.7473564Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-11-07T22:26:21.7735172Z Removing includeIf entries pointing to credentials config files
2026-11-07T22:26:21.7742158Z [command]/usr/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-11-07T22:26:21.7774381Z includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git.path
2026-11-07T22:26:21.7775042Z includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git/worktrees/*.path
2026-11-07T22:26:21.7788056Z includeif.gitdir:/github/workspace/.git.path
2026-11-07T22:26:21.7788543Z includeif.gitdir:/github/workspace/.git/worktrees/*.path
2026-11-07T22:26:21.7789828Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git.path
2026-11-07T22:26:21.7812946Z /home/runner/work/_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.7823715Z [command]/usr/bin/git config --local --unset includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git.path /home/runner/work/_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.7867352Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git/worktrees/*.path
2026-11-07T22:26:21.7897815Z /home/runner/work/_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.7908493Z [command]/usr/bin/git config --local --unset includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git/worktrees/*.path /home/runner/work/_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.7989247Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/github/workspace/.git.path
2026-11-07T22:26:21.8017272Z /github/runner_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.8025756Z [command]/usr/bin/git config --local --unset includeif.gitdir:/github/workspace/.git.path /github/runner_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.8104551Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/github/workspace/.git/worktrees/*.path
2026-11-07T22:26:21.8133585Z /github/runner_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.8140588Z [command]/usr/bin/git config --local --unset includeif.gitdir:/github/workspace/.git/worktrees/*.path /github/runner_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config
2026-11-07T22:26:21.8189273Z [command]/usr/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-11-07T22:26:21.8406083Z Removing credentials config '/home/runner/work/_temp/git-credentials-84c70ab9-47da-4ad7-b456-923ae5289ebb.config'
2026-11-07T22:26:21.8571443Z Cleaning up orphan processes
```
```

## Expected vs Actual

**Expected:** green CI on the default branch.
**Actual:** ``make precommit` fails in `go test` with repo-code assertions: `HealthzHandler` returns Content-Type `text/plain` instead of `application/json` (healthz_test.go:49) and `Clamp` returns `0` instead of `10` for above-max/equal-to-max cases (clamp_test.go:16), with no dependency-resolution, go.sum, or vulnerability evidence in the log.`

## Why this is a bug

The default-branch build is the repository's quality gate; a red build blocks merges. Diagnosis: ``make precommit` fails in `go test` with repo-code assertions: `HealthzHandler` returns Content-Type `text/plain` instead of `application/json` (healthz_test.go:49) and `Clamp` returns `0` instead of `10` for above-max/equal-to-max cases (clamp_test.go:16), with no dependency-resolution, go.sum, or vulnerability evidence in the log.`
