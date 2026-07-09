---
name: implement-slice
description: >-
  Use when implementing one well-scoped task or slice (roughly one PR of work, ≤~400 changed
  lines) with full rigor, especially in a fresh context — orient against inherited state, plan,
  test-driven implementation, multi-lens review by parallel subagents, fix, then end-to-end
  verification before opening the PR. Trigger when asked to "implement this task/slice/chunk
  thoroughly", when executing a single chunk from a decomposition plan, or when dispatched as one
  leg of a relay run with a handoff and a base branch. Works standalone on any single scoped
  coding task. Don't use for multi-slice features (decompose first, or use relay), trivial
  one-line fixes, or exploration/research with no deliverable.
---

# Implement One Slice, at Full Speed

Take one well-scoped task from zero context to an open PR with full rigor. This skill is written
to be run by an agent whose entire knowledge is its briefing — read everything you're given
before touching anything.

## Input contract

You need (ask for, or discover, whatever is missing):

- **Slice spec** — what this task delivers, ideally one sentence, plus constraints.
- **Base branch** — what to build on. Default: the repo's main branch.
- Optional: **handoff-in** — a baton from whoever worked before you. Optional: **learnings** — a
  list of one-line rules from earlier work in the same run.

## Phase 1 — Orient (before touching code)

- Read the handoff and learnings first, fully. They override your assumptions: they were written
  by someone who has already tripped on this codebase.
- Check out the base branch; create your working branch from it.
- Run the test suite. If inherited tests fail: **stop** and write a failure report (format
  below). Never build on sand — and never silently fix earlier work, even if the fix looks easy;
  that corrupts the branch stack and the blame trail. Report it instead.

## Phase 2 — Plan

Write a short plan (to `plan.md` in your run directory if you were given one, else keep it in
your working notes) containing:

- **Test list** — the concrete tests that will prove the deliverable works, named individually.
- **Files to touch.**
- **Wiring** — which existing interfaces you will consume. If you have a handoff, **quote the
  exact handoff lines you're relying on**. This forces a real read, and it gives the handoff
  verifier something to check your usage against later.

## Phase 3 — Implement, test-first

- TDD loop: write a failing test → run it and watch it fail → minimal code to pass → run it →
  refactor. The slice spec's "delivers" sentence is the acceptance test — write that test first.
- Commit in small increments, one behavior per commit, so review findings can be bisected.

## Phase 4 — Review and fix

Dispatch 3–4 parallel review subagents over this slice's full diff, one lens each. Give each the
diff, the slice spec, and (if present) the handoff-in:

- **correctness** — does it deliver the spec? Edge cases, error paths, off-by-ones.
- **tests** — do the tests pin behavior, or merely pass? Would they catch a plausible bug in the
  code they cover?
- **integration** — does the code consume inherited interfaces as the handoff documents them, or
  did it quietly work around them? A workaround means either the code or the baton is wrong —
  fix the code or report the baton. (Skip this lens when there's no handoff.)
- **simplification** — reuse missed, dead weight, abstraction the slice doesn't need.

If your environment cannot dispatch subagents, run each lens yourself as a separate, explicit
sequential pass over the diff — and say so in `review.md`.

Triage every finding: **P1** (must fix — correctness or spec violation), **P2** (should fix —
real but bounded), **P3** (note only). Fix all P1s and P2s. Log P3s in `review.md` (run
directory) or the PR body. Re-run the full suite after fixes.

## Phase 5 — Verify and ship

- Exercise the slice's observable behavior end-to-end: run the real flow (the CLI command, the
  endpoint, the UI action), not just the test suite.
- Push the branch and open a PR onto the base branch. Title = the slice's one-line deliverable.
  Body = what it delivers, deviations from the spec/plan and why, and logged P3s. If there is no
  remote or PR tooling, commit locally and write the would-be PR title and body to `pr.md` in
  your run directory instead.
- If you're part of a relay run: write your outgoing baton with the **handoff** skill and save it
  where your briefing told you to.

## Failure report

On any unrecoverable stop — inherited breakage, tests that won't pass, a P1 you can't fix —
return exactly this block and stop:

```
FAILED: <one line — what could not be done>
PHASE: orient | plan | implement | review | verify
ATTEMPTED: <what was tried, in order>
EVIDENCE: <exact errors/output, trimmed to the relevant lines>
HYPOTHESIS: <best guess at root cause>
SUGGEST: <what a re-plan should consider — re-cut the slice, different approach, missing prereq>
```

Do not thrash: two genuinely different failed attempts at the same obstacle is the threshold. A
third try without new information is thrashing — report instead.
