---
status: approved
spec: [002-goodbye-marker]
created: "2026-07-15T12:47:00Z"
queued: "2026-07-15T12:49:58Z"
---

<summary>
- Creates a single marker file `GOODBYE_DARK_FACTORY.md` at the repository root
- Marker contains exactly one line: `goodbye from the dark-factory implementer agent`
- Proves the dark-factory agent can drain MORE THAN ONE approved spec on the same draft PR autonomously
- Parallel to spec 001's `HELLO_DARK_FACTORY.md` marker, but uses the goodbye text the spec mandates
- No Go code, test, CI, or config changes — file addition only
- Existing `prompts/` and `specs/` bookkeeping continues unchanged
- No new dependencies, no Makefile target, no Dockerfile edit
</summary>

<objective>
Satisfy spec 002 by adding the literal marker file `GOODBYE_DARK_FACTORY.md` at the repository
root with the exact single-line contents the spec mandates, proving that the dark-factory
implementer can drain more than one approved spec on a single draft PR.
</objective>

<context>
Read `CLAUDE.md` for project conventions (if present).

Spec 002 (verbatim, key points):
- File must exist at the repository root with the absolute name `GOODBYE_DARK_FACTORY.md`.
- File contents must be exactly the single line:
  `goodbye from the dark-factory implementer agent`
- No other source file is modified. (`prompts/` and `specs/` bookkeeping done by dark-factory
  itself does not count.)
- Out of scope: any change to Go code, CI, or existing source files.

Repo facts (verified):
- This repo uses `workflow: direct` in `.dark-factory.yaml`, so `.git` is NOT masked in the
  container and bare `git` commands in `<verification>` are safe.
- `make precommit` runs `format generate test check addlicense` — it is the standard gate.
  For this prompt it is a sanity check only: the marker file is a plain markdown file, not
  source, and `make precommit` does not gate repository-root markdown.
- The repo ALREADY contains `HELLO_DARK_FACTORY.md` (created by spec 001, prompt
  `006-spec-001-create-hello-marker.md`). `HELLO_DARK_FACTORY.md` is fine to leave in place —
  it is owned by spec 001, not by you. Do not modify or delete it.
- `git status` at the time of writing shows `specs/in-progress/001-hello-marker.md`,
  `specs/in-progress/002-goodbye-marker.md` as modified, plus
  `prompts/in-progress/006-spec-001-create-hello-marker.md` as an untracked path. None of
  those are your concern; do not touch them.
</context>

<requirements>
1. Create the file at the repository root at the path `GOODBYE_DARK_FACTORY.md` (absolute:
   `/home/node/.cache/github-dark-factory-agent/work/d10ca340-5af6-5d2b-b3e8-5ad4a1c603c1/GOODBYE_DARK_FACTORY.md`).
2. Set the file contents to EXACTLY the single line (no leading or trailing whitespace,
   no surrounding blank lines, no encoding preamble):
   `goodbye from the dark-factory implementer agent`
3. Verify byte-exactness after writing: the file must be exactly 48 bytes (47 ASCII bytes
   for the line content plus 1 byte for the trailing newline). If `wc -c` reports any other
   size, fix the file before continuing.
4. Verify line-exactness: `cat GOODBYE_DARK_FACTORY.md` must print exactly two lines on the
   terminal — the marker text and then an empty line from the trailing newline — and
   nothing else. No UTF-8 BOM. No CRLF line endings.
5. Do NOT modify any other file in the repository. Do NOT edit Go source, tests, the
   Makefile, Dockerfile, `go.mod`/`go.sum`, CI config, or the `CHANGELOG.md`.
   (`prompts/` and `specs/` changes are dark-factory bookkeeping, not your concern.)
   In particular, do NOT touch `HELLO_DARK_FACTORY.md` — it is owned by spec 001.
6. Do NOT add license headers, code fences, or markdown formatting to the marker file.
   The spec mandates raw text, not a formatted markdown document.
7. Run `make precommit` to confirm the addition does not break the build/lint/test suite.
   This is a sanity check; the marker is not a Go file and should not affect any target.
8. If `make precommit` fails for a reason unrelated to the marker (pre-existing flake,
   environment issue), record the failure in the completion report and still consider the
   prompt's stated objective achieved if the marker file is correct per requirements 1–4.
</requirements>

<constraints>
- Single file addition only: `GOODBYE_DARK_FACTORY.md` at the repo root.
- Contents must be EXACTLY one line: `goodbye from the dark-factory implementer agent` plus
  a single trailing newline. Nothing else.
- No Go code, test, CI, config, or existing-file edits.
- No license header, no markdown formatting, no code fences.
- No new dependency, no Makefile target, no Dockerfile change.
- Do NOT commit — dark-factory handles git.
- This repo uses `workflow: direct`, so git operations work normally in the container.
</constraints>

<verification>
Run from the repository root (`/home/node/.cache/github-dark-factory-agent/work/d10ca340-5af6-5d2b-b3e8-5ad4a1c603c1`):

1. `test -f GOODBYE_DARK_FACTORY.md` — must succeed (file exists at the repo root).
2. `wc -c GOODBYE_DARK_FACTORY.md` — must report exactly `48` (47 bytes content + 1 byte
   trailing newline). Any other size means extra/missing whitespace or wrong text.
3. `cat GOODBYE_DARK_FACTORY.md` — must print exactly the marker line followed by a newline,
   no other characters.
4. `git diff --name-only HEAD -- GOODBYE_DARK_FACTORY.md` (or `git status --short`) — must
   show `GOODBYE_DARK_FACTORY.md` as the only changed path outside `prompts/` and `specs/`
   for this prompt's work. No hand-edited `.go`, `.yaml`, `Makefile*`, `Dockerfile`,
   `go.mod`, `go.sum`, or `HELLO_DARK_FACTORY.md` (HELLO_DARK_FACTORY.md belongs to spec 001,
   not to this prompt).
5. `git diff --stat HEAD -- GOODBYE_DARK_FACTORY.md` — must show exactly `1 file changed,
   1 insertion(+)`.
6. `make precommit` — must exit 0 (sanity check; the marker should not affect it).
</verification>
