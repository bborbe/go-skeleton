---
status: completed
spec: [006-cluster-agent-canary]
summary: Appended the reference-implementation sentence to README.md after the trailing scratch comment; no other files were modified and make precommit passes.
execution_id: f4c288d5-7723-5956-926c-a43e87a8598b-exec-018-spec-006-readme-reference-implementation
dark-factory-version: dev
created: "2026-11-22T21:18:06Z"
queued: "2026-11-22T21:22:45Z"
started: "2026-11-22T21:22:47Z"
completed: "2026-11-22T21:30:07Z"
branch: dark-factory/cluster-agent-canary
---

# Append README sentence naming the cluster-build reference implementation

<summary>
- The repository's README now explains why it exists as a standalone skeleton
- One sentence is added stating the repository is the reference implementation for cluster-side builds
- No source code, tests, configuration, dependencies, or toolchain change
- Existing README content is left completely untouched
- The trailing HTML scratch comment already present in the README is preserved as-is
- The full pre-commit checks still pass
</summary>

<objective>
Make the repository's purpose discoverable: a reader arriving from the org should learn from `README.md` alone that this repository is the reference implementation for cluster-side builds, instead of having to infer it from the build scripts.
</objective>

<context>
Read `README.md` — the file currently ends with a `## License` section followed by a single trailing HTML comment (`<!-- scratch: pr-reviewer ... -->`). The new sentence is appended after that comment.
Read `docs/dod.md` for the project's Definition of Done.
This repository builds with the standard `make precommit` target (`Makefile.precommit`), which is the required end state.
</context>

<requirements>
1. In `README.md`, append one new paragraph at the very end of the file, after the existing trailing HTML comment line:
   `This repository is the reference implementation for cluster-side builds.`
   - Separate it from the preceding line by exactly one blank line.
   - This is the only content addition; the sentence wording above is the required text.
2. Do not add a heading around the sentence, and do not add a Table of Contents entry for it — it is a plain trailing paragraph, not a new section.
3. Change nothing else in `README.md`: do not reword, reflow, reorder, or delete any existing line, and leave the trailing HTML scratch comment intact.
4. Do not modify any other file. In particular, do not touch application source, tests, `Makefile*`, `tools.env`, `go.mod`, `go.sum`, `example.env`, or `CHANGELOG.md`.
5. Before finishing, re-run the `<verification>` commands and confirm they pass; walk each item in this `<requirements>` list against the final file.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git
- Scope is a single appended README sentence: no source-code, test, configuration, dependency, or toolchain changes
- Do NOT rewrite or restructure the existing README content
- Do NOT modify `CHANGELOG.md` — the spec requires that nothing else changes
- Do NOT delete or edit the existing trailing HTML scratch comment
- Existing tests must still pass
</constraints>

<verification>
Run `grep -q 'This repository is the reference implementation for cluster-side builds.' README.md` — must exit 0.
Run `grep -q '^## License' README.md` — must exit 0 (existing README structure is preserved).
Run `make precommit` — must pass.
</verification>
