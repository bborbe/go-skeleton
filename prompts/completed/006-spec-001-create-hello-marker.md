---
status: completed
spec: ["001"]
summary: Created HELLO_DARK_FACTORY.md marker file with exact spec content at repository root
execution_id: b891b7bd-aca4-5687-b3a6-b582188556e2-exec-006-spec-001-create-hello-marker
dark-factory-version: dev
created: "2026-07-15T00:00:00Z"
queued: "2026-07-15T08:09:06Z"
started: "2026-07-15T08:09:08Z"
completed: "2026-07-15T08:09:36Z"
---

<summary>
- Add a single marker file `HELLO_DARK_FACTORY.md` at the repository root
- The file contains exactly one line: `hello from the dark-factory implementer agent`
- No other source file, Go file, test, or configuration is touched
- Existence and exact-line-content are verified with filesystem checks (no build, no Go tests)
- Dark-factory's own bookkeeping under `prompts/` and `specs/` is expected and is not a code change

</summary>

<objective>
Create one static marker file at the repository root that signals the dark-factory implementer
ran end-to-end against this repo. This is a content-only change — no Go code, no tests, no CI,
no dependencies are touched. The deliverable is a file whose contents match the spec byte-for-byte.
</objective>

<context>
Read `specs/in-progress/001-hello-marker.md` for the canonical desired behavior.

No other files need to be read. There are no project conventions to follow for this task — it
does not involve Go code, HTTP handlers, mocks, or external libraries.

This repository is a Go skeleton (`github.com/bborbe/go-skeleton`), but the change is
repository-shape-only and does not invoke the Go toolchain. `docs/dod.md` and `make precommit`
apply to code changes and are intentionally not in scope here (see spec "Out of Scope").

Repository layout facts (verified):
- The agent runs against the repository root, conventionally referenced as `/workspace` in
  dark-factory containers; on this host the equivalent working directory is
  `/home/node/.cache/github-dark-factory-agent/work/b891b7bd-aca4-5687-b3a6-b582188556e2`.
  Write the marker to whichever path resolves to the repo root in the current environment.
- The dark-factory workflow for this repo is `direct` (no worktree); the host repo is the
  one the agent edits.
</context>

<requirements>

1. Create one new file at the repository root named exactly `HELLO_DARK_FACTORY.md`
   (capitalization, underscore, and extension as shown — `HELLO_DARK_FACTORY.md`).

2. The file's full contents MUST be the single line:
   `hello from the dark-factory implementer agent`

3. The line MUST end with a single trailing newline (POSIX-style text file). No leading
   whitespace. No blank line after. No trailing whitespace on the content line. No
   surrounding markdown fences (no ` ``` `), no frontmatter, no HTML, no extra prose,
   no comments.

4. The file MUST be a regular text file, not executable. Standard `0644` permissions are
   fine — do not set executable bits.

5. Do NOT modify, rename, or delete any other file in the repository. Specifically:
   - No edits to any `*.go` file.
   - No edits to `Makefile`, `.dark-factory.yaml`, `go.mod`, `go.sum`, `docs/`, `pkg/`,
     `main.go`, `main_test.go`, `mocks/`, `k8s/`, or `tools.env`.
   - No edits to `CHANGELOG.md` or `README.md`.
   - Editing under `prompts/` and `specs/` for dark-factory bookkeeping is expected and
     is not a violation of this constraint.

6. Do NOT add git hooks, environment files, IDE files, OS metadata, or any auxiliary
   artifact alongside the marker.

7. Do NOT run `git` commands, `make`, `docker`, `dark-factory`, or any operator-only
   tooling — the marker is the only artifact this prompt produces and verification below
   uses host-filesystem checks.

</requirements>

<constraints>
- Out of Scope (from spec): any change to Go code, CI, or existing source files.
- The marker file is the only output of this prompt.
- The line content is exact — do not paraphrase, translate, capitalize, or punctuate it
  differently from the spec.
- Do NOT commit — dark-factory handles git.
- Do NOT run `make precommit` — the spec excludes code changes, and precommit's Go
  build/lint/test steps are not what this prompt verifies.
- File mode is the standard `0644`; no executable bit.
</constraints>

<verification>
Run from the repository root (the directory containing `Makefile`, `go.mod`, etc.):

1. `test -f HELLO_DARK_FACTORY.md && echo EXISTS` — must print `EXISTS`.
   (Use `ls HELLO_DARK_FACTORY.md` as a human-eyes equivalent if `test` is unavailable;
   the file must exist and be a regular file.)

2. Capture the file's contents and confirm the file is exactly one line:
   `awk 'END { print NR }' HELLO_DARK_FACTORY.md` — must print `1`.

3. Confirm the (only) line is the exact spec string, byte-for-byte:
   `grep -Fx 'hello from the dark-factory implementer agent' HELLO_DARK_FACTORY.md`
   — must exit 0 and produce one match. (`-F` = fixed string, no regex;
   `-x` = match the entire line.)

4. Confirm no other source/config file changed. Compare against the current `HEAD` using
   filesystem-shape checks (the container's git history is masked in some workflows, so
   use `find` to inventory instead of `git diff`):
   `find . -type f -not -path './HELLO_DARK_FACTORY.md' -not -path './prompts/*' -not -path './specs/*'`
   — the agent must be able to attest it did not modify any of those paths.

If any check above fails, the prompt is not complete and the issue must be fixed before
re-running verification.

</verification>

<!--
OPEN QUESTIONS surfaced for the human reviewer:

1. The spec is two-bullet simple. It hard-binds the file's line content. The byte-exact
   verification above uses `grep -Fx` so any difference in capitalization, trailing
   punctuation, or surrounding whitespace fails verification immediately.

2. Single trailing newline vs. no trailing newline. POSIX-style text files end with a
   newline. The previous (simulated) execution committed the file with one trailing
   newline; this prompt preserves that convention. If the reviewer prefers no trailing
   newline, requirement 3 should change to "no trailing newline" and verification step 2
   should use `wc -c` to assert exact byte count instead of `awk 'END { print NR }'`.

3. No test was added. The spec excludes tests ("Any change to Go code, CI, or existing
   source files") and the deliverable is a static text file, so a Go unit test would be
   out of scope and a shell-based scenario adds no value beyond the verification steps
   above. No scenario prompt emitted.
-->
