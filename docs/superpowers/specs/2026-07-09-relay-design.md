# Relay — Design

**Date:** 2026-07-09
**Status:** Approved design, pre-implementation

## Problem

Large pieces of work exceed what one agent context can implement well. Long sessions
degrade: context fills with stale detail, quality drops, and the end of the work is
built worse than the beginning. The existing `decompose` skill answers *how to cut*
work into small, vertically-sliced, independently mergeable PRs — but nothing
orchestrates *executing* that sequence with fresh context per slice, high-quality
handoffs between slices, and a thorough implementation loop inside each slice.

## Solution overview

A family of four skills (three new, one existing) that together run a problem
end-to-end, fully autonomously, as a **relay race**: the work is cut into legs,
each leg is run by a fresh agent at full quality, and a bounded, verified **baton**
(handoff) passes between legs.

```
skills/
  decompose/         # existing — plans the legs (unchanged, reused verbatim)
  relay/             # NEW: orchestrator — runs the whole race
  implement-slice/   # NEW: one leg — the full plan→TDD→review→verify loop
  handoff/           # NEW: the baton — write + verify a bounded context handoff
```

Each new skill is independently valuable and independently triggerable:
`implement-slice` is "implement this one well-scoped task thoroughly" (a portable
lfg loop for a single task); `handoff` is "write a handoff before clearing
context / ending a session / passing work to a fresh agent."

Internal protocol (templates, rubrics, state-file formats) lives in `references/`
files inside the owning skill — not as separate skills.

## Key decisions (with rationale)

| Decision | Choice | Why |
|---|---|---|
| Execution model | Orchestrator session + fresh subagent per phase | Context clearing is automatic and absolute — each leg starts empty. Orchestrator stays small (routing, not thinking). |
| Human gates | Fully autonomous | Point it at a problem, come back to a stack of PRs. No pauses. |
| Git strategy | Stacked branches + PRs | Slice N branches from slice N-1's branch; each leg ends by opening a PR onto the branch below. The stack mirrors the decomposition, mergeable bottom-up. |
| Handoff authorship | Implementer drafts, fresh agent verifies | Self-reports omit the embarrassing parts; a cold auditor loses the implementer's private knowledge. Draft + adversarial verify gets both. |
| Compounding | Within-run (learnings.md) + persistent (CLAUDE.md / docs/solutions) | Mistakes stop repeating mid-run; the next run starts smarter. |
| Decomposition rigor | Multi-candidate + judge | 2–3 independent decomposers, one judge synthesizes. No human gate means a mis-cut sequence poisons the whole run — worth the extra agents, once per run. |
| Per-slice loop | Full lfg: plan → TDD → multi-lens review → fix → verify | "Thorough implementation" is a stated requirement. |
| Failure policy | Re-plan once with failure evidence, then halt with stuck-report | Later slices depend on earlier ones; pressing on compounds damage. One informed retry recovers most failures cheaply. |

## Architecture

### The orchestrator (`relay`)

The main session, following `relay/SKILL.md`, is a **coach with a clipboard, not a
runner**. It holds only: the slice sequence, which leg is active, and pointers to
state files. All real work happens in fresh subagents. This keeps orchestrator
context from degrading across a long run.

### State lives on disk

Every run gets a run directory, making the run inspectable while it happens and
resumable if the orchestrator session dies:

```
.relay/<run-id>/
  problem.md          # the original ask, verbatim
  slices.md           # judge-approved decomposition (race plan): ordered legs with
                      #   deliverable, dependencies, size, branch name
  learnings.md        # append-only run-local lessons; every later agent reads it
  status.md           # active leg, per-leg phase, PR links
  legs/<n>/
    handoff-in.md     # baton this leg received (leg 1 gets problem.md + slices.md)
    plan.md           # this leg's implementation plan
    review.md         # triaged findings P1–P3 and resolutions
    handoff-out.md    # the verified baton passed forward
```

### Phase sequence

1. **Decompose.** 2–3 parallel subagents each research the codebase and
   independently produce a slice sequence using the `decompose` skill. A judge
   subagent scores candidates against decompose's own bar (spine-first,
   load-bearing, correctness floors, honest sizing) and synthesizes the winning
   race plan into `slices.md`.
2. **Loop over legs.** For each slice in order: spawn a fresh `implement-slice`
   subagent whose entire briefing is `handoff-in.md`, its slice spec from
   `slices.md`, `learnings.md`, and the base branch. It works on a branch stacked
   on the previous leg's branch and ends by opening a PR.
3. **Baton pass.** The implementer drafts `handoff-out.md` via the `handoff`
   skill; a fresh verifier subagent audits it against the actual diff; the
   verified baton becomes the next leg's `handoff-in.md`.
4. **Anchor leg.** After the last slice, a final subagent distills `learnings.md`
   into persistent compounding (CLAUDE.md corrections, a `docs/solutions/` entry)
   and writes a run summary linking the PR stack.

### Failure protocol

A failed leg gets one re-plan: a fresh planner receives the structured failure
report (what was attempted, evidence, hypothesis) and may re-cut the remaining
slices, not just retry the failed one. A second failure halts the run and writes a
stuck-report to the run directory: what was tried, why it failed, what a human
should decide. `skip and continue` is rejected — with vertical slices nearly
everything depends on the spine chain.

## `implement-slice` — one leg, run at full speed

Input contract: slice spec, `handoff-in.md`, `learnings.md`, base branch.

1. **Orient.** Read the baton and learnings before touching code. Verify the
   inherited world: check out the base branch, run the test suite. If inherited
   tests fail, stop and report — never build on sand, never silently "fix" a
   previous leg (that corrupts the stack and the blame trail).
2. **Plan.** Write `plan.md`: test list (what proves the deliverable works),
   files to touch, how it wires into what previous legs built. The plan must
   quote which parts of the baton it relies on — forcing a real read, and giving
   the handoff verifier something to check later. Planning stays in the same
   agent: for a well-scoped ~200 LOC slice, a separate planner subagent inserts a
   lossy handoff exactly where context is most valuable.
3. **Implement, test-first.** TDD: failing test → pass → refactor. The slice
   spec's "Delivers" sentence is the acceptance test. Small commits so review
   findings can be bisected.
4. **Review and fix.** 3–4 parallel reviewer subagents over the leg's diff, one
   lens each:
   - *correctness* — delivers the spec; edge cases; error paths
   - *tests* — do they pin behavior or merely pass
   - *integration* — does it use previous legs' interfaces as documented, or did
     it quietly work around them (unique to relay; catches baton-rot early)
   - *simplification* — reuse, altitude, dead weight
   Findings triaged P1–P3 into `review.md`; fix P1/P2, log P3. Re-run suite.
5. **Verify and ship.** Exercise the slice's observable behavior end-to-end (run
   the real flow, not just tests), push the branch, open the stacked PR, hand
   off to the baton pass.

Any unrecoverable stop in any phase produces the structured failure report the
orchestrator feeds to the re-plan.

## `handoff` — the baton, kept light on purpose

**Context-rot containment is a first-class requirement.** The failure mode: naive
handoff chains grow monotonically until "fresh context" agents start life buried
in narrative. Countermeasures:

**The baton is a delta, not a chronicle.** `handoff-out.md` is written fresh for
the next leg specifically — never the previous baton plus additions. History
lives in git, the PRs, and the run directory; the baton links instead of
retelling. Admission filter for every line: *could the next leg discover this
cheaply from the code or git log?* If yes, it stays out. What earns a place is
what code can't say: why decisions went a certain way, what was tried and
abandoned, where the bodies are buried.

**Hard budget: ~150 lines.** Template sections:
- **World state** (5–10 lines): what exists and works now, one line per
  capability — *replaced* each pass, never grown.
- **Interfaces you'll build on**: signatures/contracts the next leg consumes,
  with file:line pointers, not pasted code.
- **Decisions and deviations**: where implementation departed from `slices.md`
  and why. Highest-value section.
- **Warnings**: gotchas, fragile spots, deliberate hacks with expiry conditions.
- Nothing else. No narrative, no restated spec, no test output.

**Verifier rubric — three checks:**
1. *Unsupported claims* — baton says X, diff doesn't support it.
2. *Gaps* — deviation visible in the diff that the baton omits.
3. *Dead weight* — content discoverable from code/git, flagged for deletion.
   Trimming is part of verification passing.

**Other growth surfaces get the same discipline:**
- `learnings.md`: one-line actionable rules only, never narrative. Verifier
  dedupes against existing entries. Soft cap ~30 lines; if hit, the orchestrator
  has a leg consolidate before continuing.
- Between runs: only the anchor leg touches persistent files. CLAUDE.md gets at
  most a few one-line rules (after checking existing coverage); narrative goes
  to `docs/solutions/` where it is retrieved on demand, not loaded every
  session. A run that teaches nothing writes nothing — no obligatory residue.

## Error handling summary

- Inherited test failure at leg start → halt leg, report (never build on sand).
- Leg failure (tests won't pass, unfixable P1, can't build on previous leg) →
  structured failure report → one re-plan (may re-cut remaining slices) → on
  second failure, halt run with stuck-report.
- Orchestrator session death → run directory on disk allows a fresh session to
  resume from `status.md`.

## Testing strategy

- Each new skill is exercised standalone first (`handoff` on a real session end,
  `implement-slice` on a single well-scoped task) before wiring into `relay`.
- First full relay run on a small, low-stakes problem (2–3 slices) in a throwaway
  branch stack; inspect the run directory, batons, and PR stack by hand.
- Skill-writing conventions from this repo apply (frontmatter description
  quality, references/ layout, evidence style where claims are made).

## Out of scope

- Parallel leg execution (legs are sequential by design — the stack depends on it).
- Merge automation (the human reviews and merges the PR stack).
- Changes to the existing `decompose` skill.
