---
status: idea
kind: bug
---

# Build Failure: bborbe/go-skeleton

Filed automatically by the build-fix agent for the CI episode `d082cab2498f6f4b81bf9c775ef92c7b3605cf2b`.

## Summary

The default-branch build for `bborbe/go-skeleton` is failing; the build-fix diagnosis classified this as a code/test bug (verdict `file_spec`).

## Reproduction

Failing workflow(s): test

Episode SHA: `d082cab2498f6f4b81bf9c775ef92c7b3605cf2b`

Log evidence:

```text
| Workflow | Job | Failed Step | Run |
|---|---|---|---|
| CI | test | Run precommit checks | [Run](https://github.com/bborbe/go-skeleton/actions/runs/42414396294) |

```
2026-11-07T21:10:17.3894134Z Temporarily overriding HOME='/home/runner/work/_temp/7010af43-7fb5-488e-8338-a7d0fb61f661' before making global git config changes
2026-11-07T21:10:17.3895241Z Adding repository directory to the temporary git global config as a safe directory
2026-11-07T21:10:17.3898357Z [command]/usr/bin/git config --global --add safe.directory /home/runner/work/go-skeleton/go-skeleton
2026-11-07T21:10:17.3926911Z Removing SSH command configuration
2026-11-07T21:10:17.3932047Z [command]/usr/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-11-07T21:10:17.3962904Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-11-07T21:10:17.4179873Z Removing HTTP extra header
2026-11-07T21:10:17.4184793Z [command]/usr/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-11-07T21:10:17.4218672Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-11-07T21:10:17.4449892Z Removing includeIf entries pointing to credentials config files
2026-11-07T21:10:17.4457200Z [command]/usr/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-11-07T21:10:17.4488811Z includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git.path
2026-11-07T21:10:17.4489886Z includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git/worktrees/*.path
2026-11-07T21:10:17.4490795Z includeif.gitdir:/github/workspace/.git.path
2026-11-07T21:10:17.4491461Z includeif.gitdir:/github/workspace/.git/worktrees/*.path
2026-11-07T21:10:17.4498263Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git.path
2026-11-07T21:10:17.4526949Z /home/runner/work/_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4536543Z [command]/usr/bin/git config --local --unset includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git.path /home/runner/work/_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4577451Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git/worktrees/*.path
2026-11-07T21:10:17.4606838Z /home/runner/work/_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4615170Z [command]/usr/bin/git config --local --unset includeif.gitdir:/home/runner/work/go-skeleton/go-skeleton/.git/worktrees/*.path /home/runner/work/_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4652840Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/github/workspace/.git.path
2026-11-07T21:10:17.4681824Z /github/runner_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4688674Z [command]/usr/bin/git config --local --unset includeif.gitdir:/github/workspace/.git.path /github/runner_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4727075Z [command]/usr/bin/git config --local --get-all includeif.gitdir:/github/workspace/.git/worktrees/*.path
2026-11-07T21:10:17.4754236Z /github/runner_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4761692Z [command]/usr/bin/git config --local --unset includeif.gitdir:/github/workspace/.git/worktrees/*.path /github/runner_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config
2026-11-07T21:10:17.4806244Z [command]/usr/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-11-07T21:10:17.5013205Z Removing credentials config '/home/runner/work/_temp/git-credentials-2d699cf2-b83e-420e-a277-ca4cdf5c6590.config'
2026-11-07T21:10:17.5170543Z Cleaning up orphan processes
```
```

## Expected vs Actual

**Expected:** green CI on the default branch.
**Actual:** `The failing step is `go test` on repo code, where pkg/mathutil's Clamp "above max" spec fails because Clamp(42, …, 10) returned 42 instead of 10, indicating a code/test bug rather than dependency or vulnerability drift.`

## Why this is a bug

The default-branch build is the repository's quality gate; a red build blocks merges. Diagnosis: `The failing step is `go test` on repo code, where pkg/mathutil's Clamp "above max" spec fails because Clamp(42, …, 10) returned 42 instead of 10, indicating a code/test bug rather than dependency or vulnerability drift.`
