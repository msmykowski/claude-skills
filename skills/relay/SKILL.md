---
name: relay
description: >-
  Use when a problem is too large to implement well in one context and the user wants it built
  end-to-end autonomously — decompose it into vertically-sliced legs, implement each leg in a
  fresh subagent at full rigor, pass a bounded verified handoff (baton) between legs, and finish
  with a stack of small reviewable PRs plus distilled learnings. Trigger on "build this whole
  feature autonomously", "run a relay on this", "decompose and implement this end to end",
  "implement this as a stack of small PRs while I'm away", or pointing at a large
  ticket/epic/spec and asking for the full build. Requires a git repo. Don't use for single
  PR-sized tasks (use implement-slice), planning-only requests (use decompose), or work that
  needs human decisions mid-run.
---

# Relay — Run the Whole Race

Implement a large problem end-to-end, autonomously, as a sequence of vertically-sliced **legs**.
Each leg runs in a fresh subagent at full quality; a bounded, verified **baton** passes between
legs; the output is a stack of small reviewable PRs, mergeable bottom-up.

You are the **coach with the clipboard, not a runner**. You dispatch subagents, route batons, and
track state. You never implement, review, or write handoffs yourself — fresh contexts do, because
fresh context is the entire quality mechanism. Keep your own context small: everything durable
lives on disk, and you hold only the race plan, the active leg, and pointers.

## Preconditions

- A git repository with a discoverable test command. If the repo has no tests at all, that is
  itself the first leg — the decomposition must include it (a characterization/smoke net).
- The sibling skills **decompose**, **implement-slice**, and **handoff** installed. Locate their
  SKILL.md absolute paths now (they live in the same skills directory as this file). Subagent
  contexts start empty — every dispatch below passes the relevant path explicitly.

## Run directory

Create `.relay/<run-id>/` where run-id is `YYYY-MM-DD-<slug>`:

```
.relay/<run-id>/
  problem.md          # the original ask, verbatim
  slices.md           # judge-approved race plan (format: references/state-files.md)
  learnings.md        # append-only one-line rules; every later agent reads it
  status.md           # active leg, per-leg phase, PR links
  legs/<n>/           # handoff-in.md, plan.md, review.md, handoff-out.md, (pr.md)
```

File formats: `references/state-files.md`. Write `problem.md` first, verbatim — no paraphrase.

## Phase 1 — Decompose (multi-candidate + judge)

1. Dispatch **2–3 parallel subagents** with the same prompt:

   > Read <decompose SKILL.md path> and follow it. The problem: <contents of problem.md>. Research
   > the codebase first — structure, existing seams, test setup, what already exists. Produce the
   > ordered chunk list in the skill's output format, plus the sequencing rationale. Return only
   > that.

2. Dispatch **one judge**:

   > Here are N independent decompositions of the same problem: <all candidates>. Read
   > <decompose SKILL.md path> — its bar is your rubric. Score each candidate: is the first chunk a
   > thin end-to-end spine? Is every chunk legible and load-bearing? Are correctness floors
   > respected? Is sizing honest (~50–200 LOC, ≤400)? Is it the fewest chunks that clear the bar?
   > Then synthesize the winner: take the strongest candidate and graft specific better cuts from
   > the others. Return the final ordered slice list in the same format, plus one paragraph on what
   > you changed and why.

3. Write the result to `slices.md`, assign each leg its branch name (`relay/<run-id>/leg-<n>`,
   leg 1 based on the default branch, each later leg based on the previous leg's branch), and
   initialize `status.md`.

## Phase 2 — The leg loop

For each leg N in order:

1. Prepare `legs/N/handoff-in.md`: for leg 1, the contents of `problem.md`; for later legs, the
   verified `handoff-out.md` from leg N-1.
2. Dispatch a **fresh implementer**:

   > Read <implement-slice SKILL.md path> and follow it exactly. Slice spec: <leg N's block from
   > slices.md>. Base branch: <leg N-1's branch, or the default branch for leg 1>. Working branch:
   > <leg N's branch>. Handoff-in: <contents>. Learnings: <contents of learnings.md>. Write your
   > plan.md, review.md, and outgoing baton (via the handoff skill at <handoff SKILL.md path>) to
   > <run dir>/legs/N/. Report back: PR URL (or pr.md path), deviations from the slice spec, and
   > any new one-line learnings.

3. On success: append reported learnings to `learnings.md` (one-line actionable rules only —
   dedupe against existing lines; if the file exceeds ~30 lines, dispatch a consolidation pass
   before continuing). Update `status.md`. Go to Phase 3.
4. On a failure report (the implement-slice `FAILED:` block): go to the failure protocol.

## Phase 3 — Baton pass

1. The implementer left a draft at `legs/N/handoff-out.md`. If it's missing, dispatch a writer:
   read the handoff skill, write the baton given the leg's diff, slice spec, and plan.md.
2. Dispatch a **fresh verifier**:

   > Read <handoff SKILL.md path>, verification mode. Draft: <handoff-out.md contents>. The diff:
   > run `git diff <base branch>...<leg branch>`. Spec and plan: <slice spec + plan.md>. Return
   > only the verdict block.

3. On `fail`: dispatch a fixer with the draft, the verdict, and the diff; then re-verify. Two
   consecutive fails → treat as a leg failure (protocol below), with the two verdict blocks and
   the draft baton standing in for the implement-slice failure report.
4. The verified baton becomes `legs/N+1/handoff-in.md`.

## Phase 4 — Anchor leg

After the last leg, dispatch one final subagent:

> Read everything under <run dir> (slices, learnings, statuses, PR links). Two jobs. (1) Distill
> learnings.md into persistent compounding: at most a few one-line rules into the repo's
> CLAUDE.md — but first check they aren't already covered, and if nothing generalizes beyond this
> run, write nothing. If there is a narrative worth keeping (a non-obvious problem solved),
> write one docs/solutions/<run-id>.md entry. A run that teaches nothing writes nothing. (2)
> Write <run dir>/summary.md: the PR stack bottom-up, one line per leg, plus anything a reviewer
> should read first.

Then report to the user: the PR stack, ready to review bottom-up, and where the summary lives.

## Failure protocol

On a leg failure report:

1. **Re-plan once.** Dispatch a fresh planner with: the failure report, `slices.md`,
   `learnings.md`, and the failed leg's artifacts. It may re-scope the failed leg or re-cut it
   *and all unstarted legs* (never completed ones). It updates `slices.md` with a note of what
   changed. Resume the leg loop at the failed leg.
2. **Second failure of the same leg → halt.** Write `<run dir>/stuck-report.md` (format:
   `references/stuck-report.md`), set `status.md` to `halted`, and stop. Do not attempt later
   legs — they build on the failed one. Merged/open PRs from completed legs remain valid;
   say so in the report.

## Resuming

If your session died mid-run: read `status.md` — it names the active leg and phase. Resume
exactly there. Never redo a completed leg; its branch, PR, and verified baton are on disk.
