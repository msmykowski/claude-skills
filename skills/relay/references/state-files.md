# Relay run-state file formats

All run state lives in `.relay/<run-id>/`. These formats are contracts: subagents parse them.

## race-plan.md

The judge's final decomposition, in the decompose manual's output format, with two fields added
per chunk (`Branch`, and `Base`) and a header. Each `PR<n>` chunk is one **leg** — the two
vocabularies map 1:1:

```markdown
# Race plan: <run-id>
Judge notes: <one paragraph — what was synthesized/changed from the candidates>

PR1. <imperative title>
  Delivers:   <one sentence>
  Correct standalone because: <why>
  Depends on: <ids or "nothing">
  Size:       <S/M/L or LOC>
  Branch:     relay/<run-id>/leg-1
  Base:       <default branch>

PR2. ...
  Branch:     relay/<run-id>/leg-2
  Base:       relay/<run-id>/leg-1
```

If the failure protocol re-cuts legs, append a line to Judge notes:
`Re-cut after leg <n> failure: <what changed>`.

## status.md

Rewritten (not appended) by the orchestrator at every transition:

```markdown
# Status: <run-id>
Run:        active | halted | complete
Active leg: <n>
Phase:      decompose | implement | baton-pass | anchor

| Leg | Branch                  | Status                                  | PR    |
|-----|-------------------------|-----------------------------------------|-------|
| 1   | relay/<run-id>/leg-1    | done                                    | <url> |
| 2   | relay/<run-id>/leg-2    | todo | implement | baton-pass | failed  | —     |
```

`Phase` is the run's position; a leg's `Status` reuses the same tokens (`implement`,
`baton-pass`) while that leg is the active one, then settles to `done` or `failed`.

## learnings.md

Append-only one-line rules. Each line must be actionable and imperative — a rule the next agent
can obey without context. Never narrative.

```markdown
- Test suite needs `--forks=1`; parallel runs flake on the shared fixture DB.
- `make check` is the real gate; `make test` skips the linter.
```

Discipline: dedupe before appending; soft cap ~30 lines — at the cap, the orchestrator dispatches
a consolidation pass (merge overlapping rules, drop ones only relevant to completed legs).

## summary.md

Written once, by the anchor leg. The reader is the human reviewing the stack:

```markdown
# Run summary: <run-id>
Result: complete — <n> legs, <n> PRs, mergeable bottom-up

| Leg | PR                     | Delivers   |
|-----|------------------------|------------|
| 1   | <url or legs/1/pr.md>  | <one line> |

Read first: <what a reviewer should know before the stack — deviations, notable logged P3s,
or "nothing unusual">
Compounded: <CLAUDE.md rules added / docs/solutions entry / "nothing — run taught nothing new">
```

## legs/<n>/ contents

- `handoff-in.md` — the baton this leg received (leg 1: problem.md contents).
- `plan.md` — the implementer's plan (test list, files, wiring with quoted baton lines).
- `review.md` — triaged findings P1–P3 and their resolutions.
- `handoff-out.md` — the verified outgoing baton.
- `pr.md` — only when no remote/PR tooling exists: the would-be PR title and body.
