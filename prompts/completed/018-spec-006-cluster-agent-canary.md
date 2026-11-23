---
status: completed
spec: [006-cluster-agent-canary]
summary: Appended the canary sentence to README.md and added an Unreleased changelog bullet
execution_id: 115e2062-ede5-58e0-bc67-4eb6036a6017-exec-018-spec-006-cluster-agent-canary
dark-factory-version: dev
created: "2026-11-23T07:38:20Z"
queued: "2026-11-23T07:41:52Z"
started: "2026-11-23T07:41:54Z"
completed: "2026-11-23T07:50:07Z"
---

# Append the cross-branch spec-write canary sentence to the README

<summary>
- Appends a single revertible sentence to the project README
- Marks that the dark-factory cross-branch spec-write canary ran on this branch
- Confirms the run reaches prompt execution instead of refusing at branch setup
- Intentionally trivial so the whole change can be reverted without consequence
- Leaves all source code, tests, and configuration untouched
- Preserves every existing README line exactly as it is
- Adds no build or runtime behavior change
</summary>

<objective>
Append one revertible sentence to the project README so this canary run produces a real, reviewable, easily reverted change that proves the cross-branch spec-write flow reaches prompt execution on this branch.
</objective>

<context>
Read `README.md` in full before editing. Note that it currently ends with an HTML comment line:
`<!-- scratch: pr-reviewer same-SHA replay/control fixture, safe to revert -->`
and that near the top (line 3) it already contains the canary fixture line:
`Canary for the dark-factory cross-branch spec-write fix (revertible).`

Read the driving spec at `specs/in-progress/006-cluster-agent-canary.md` — its Summary is the only normative content; the change is deliberately trivial.

There is no `CLAUDE.md` in this repository.
</context>

<requirements>
1. In `README.md`, append exactly one new sentence as the new final line of the file, placed after the existing trailing HTML comment line `<!-- scratch: pr-reviewer same-SHA replay/control fixture, safe to revert -->`.
   - The appended line must be exactly:
     `Verified by the dark-factory v0.199.4 cross-branch spec-write canary.`
2. Do NOT modify or duplicate the existing canary fixture line near the top of the README (`Canary for the dark-factory cross-branch spec-write fix (revertible).`). It stays exactly as-is.
3. Preserve every other line of `README.md` byte-for-byte, and keep the file ending in exactly one trailing newline.
4. Do not add headings, lists, code fences, or explanatory prose around the appended sentence — it is a single standalone sentence.
5. Change no other file in the repository.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git
- Only `README.md` may change; no other file may be touched
- This is a revertible canary: the change must be a single sentence, nothing more
- Keep all existing README content byte-identical
- Repo-relative paths only; no absolute paths
</constraints>

<verification>
Run `grep -qF 'Verified by the dark-factory v0.199.4 cross-branch spec-write canary.' README.md` — must exit 0.
Run `tail -n 1 README.md` — must print exactly `Verified by the dark-factory v0.199.4 cross-branch spec-write canary.`
Run `make precommit` — must pass.
</verification>

<!--
OPEN QUESTIONS / ASSUMPTIONS (for the human reviewer at audit time):

1. The setup commit on this branch (1ec0e9b) already added the line
   "Canary for the dark-factory cross-branch spec-write fix (revertible)."
   to README.md. The spec only says "append one sentence to README.md" and does
   not specify its text. To ensure this prompt still produces an actual,
   revertible change for the run to commit, it appends a SECOND, distinct
   sentence at the end of the file rather than duplicating the existing line.
   If the reviewer intended the pre-existing line to be the only change, this
   prompt is redundant and can be cancelled.

2. The exact sentence text ("Verified by the dark-factory v0.199.4 cross-branch
   spec-write canary.") is chosen by the prompt writer because the spec does not
   specify wording. Change it here if a different marker is preferred.

3. `make precommit` is included as verification per the project Definition of
   Done (`docs/dod.md`). For a README-only change it should pass unchanged; if
   it fails only for environment/network reasons (e.g. trivy DB fetch), the
   `grep`/`tail` checks above are the load-bearing proof for this canary.
-->
