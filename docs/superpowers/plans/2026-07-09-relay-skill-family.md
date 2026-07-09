# Relay Skill Family Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the three new skills from the approved spec (`docs/superpowers/specs/2026-07-09-relay-design.md`): `handoff`, `implement-slice`, and `relay` — plus README updates and an end-to-end smoke test.

**Architecture:** Each skill is a directory under `skills/<name>/` containing a `SKILL.md` (YAML frontmatter + procedural body), with `references/` files for internal protocol. `relay` orchestrates by dispatching fresh subagents that are pointed at the sibling skills' SKILL.md paths. All run state lives on disk under `.relay/<run-id>/`.

**Tech Stack:** Markdown skills for Claude Code (no executable code in this repo). Validation via YAML parsing; functional testing via subagent dispatch.

## Global Constraints

- Skill `name:` in frontmatter must exactly match its directory name.
- Frontmatter `description:` uses the `>-` block style, is under 1024 characters, and contains: when to use, concrete trigger phrases, and explicit don't-use cases (match the style of `skills/decompose/SKILL.md`).
- Prose wraps at ~100 columns, matching existing skills.
- Since deliverables are markdown (not code), the TDD cycle per task is: **write → validate frontmatter → functional-test via subagent → commit**. A task is not done until its functional test passed.
- Baton (handoff document) hard budget: **≤150 lines**. `learnings.md` soft cap: **30 lines**. Branch naming: `relay/<run-id>/leg-<n>`. Run id format: `YYYY-MM-DD-<slug>`.
- Commit after every task with a short imperative message ending in the Claude co-author trailer.

---

### Task 1: `handoff` skill

**Files:**
- Create: `skills/handoff/SKILL.md`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the baton template (sections: World state / Interfaces you'll build on / Decisions and deviations / Warnings), the ≤150-line budget, and the verification **verdict block** format (`VERDICT / UNSUPPORTED / GAPS / DEAD WEIGHT`). Tasks 2 and 3 refer to "the handoff skill", "verification mode", and "the verdict block" — the names defined here.

- [ ] **Step 1: Write `skills/handoff/SKILL.md` with exactly this content**

````markdown
---
name: handoff
description: >-
  Use when transferring work-in-progress context to a reader who has the code, diff, and git
  history but not your head — before clearing context, compacting or ending a session, passing
  work to a fresh agent or next session, or finishing one phase of a multi-phase run. Produces a
  bounded handoff document (a "baton"): current world state, the interfaces to build on, decisions
  and deviations with their why, and warnings — a delta, never a chronicle. Also has a
  verification mode for auditing someone else's handoff against the actual diff for unsupported
  claims, omissions, and dead weight. Trigger on "write a handoff", "handoff doc", "brain dump
  before I clear context", "summarize state for the next session/agent", "pass the baton", or
  "verify this handoff". Don't use for user-facing status updates, PR descriptions, commit
  messages, or documenting finished work for humans.
---

# Handoff — Pass the Baton, Not the Bloat

Transfer working context to a reader who has the code, the diff, and the git history — but not
your head. The handoff (the **baton**) exists to carry exactly what those artifacts cannot say.
Everything else is bloat, and bloat in a handoff is not neutral: the reader starts life buried in
text that crowds out the few lines that mattered.

## The reader

Write for a skilled engineer or agent starting from zero context. They can read code, run tests,
and inspect `git log`. They cannot see why you chose A over B, what you tried and abandoned, or
which green signal is lying. That gap is the baton's entire job.

## The admission filter

For every line, ask: **could the reader discover this cheaply from the code, the diff, or git
log?** If yes, leave it out — let them discover it. If no — a *why*, a dead end, a buried body —
it goes in. History lives in git; the baton is a **delta, not a chronicle**. Never write a baton
by appending to a previous one; write fresh, for this specific reader and their specific next
step.

## Hard budget

**≤150 lines total.** If you're over, cut in this order: World state compresses first (it should
already be near-telegraphic), then Interfaces (pointers, not prose), then Decisions. Cut Warnings
last — they're the section whose absence hurts most.

## Template

```markdown
# Handoff: <one line — where the work stands and what comes next>

## World state            <!-- 5–10 lines. REPLACED each handoff, never grown. -->
- <capability that exists and works now, one line each, present tense>

## Interfaces you'll build on
- `path/to/file.ext:42` — `signature(args) -> return` — <one-line contract>

## Decisions and deviations   <!-- highest-value section -->
- <what was decided or changed vs. the plan/spec> — because <the why the code can't show>
- Tried <X>; abandoned because <reason>. Don't retry it blind.

## Warnings
- <gotcha / fragile spot / deliberate hack> — expires when <condition>.
```

Section guidance:

- **World state** — what exists and works *now*. One line per capability. Present tense, no
  history, no adjectives.
- **Interfaces you'll build on** — `file:line` pointers plus signatures and a one-line contract.
  Never paste function bodies; the reader has the code.
- **Decisions and deviations** — every departure from the plan or spec, with its why. Every
  approach tried and abandoned, so the reader doesn't re-walk dead ends. This is where the
  embarrassing stuff goes; the embarrassing stuff is the valuable stuff.
- **Warnings** — fragile spots, deliberate hacks (each with the condition under which it should be
  removed), and lying signals (the flaky test, the stale fixture, the cache that masks bugs).

Never include: narrative ("first I did X, then Y"), a restated spec or plan, test output, pasted
code, or assessments of your own work's quality.

## Verification mode

When asked to *verify* a handoff, you receive the draft baton, the actual diff, and the task
spec/plan. You are an auditor, not an editor: your job is to catch what the next reader would
trip on. Check, in order:

1. **Unsupported claims** — the baton asserts something the diff doesn't support ("retries are
   handled" but no retry code exists). Quote the claim, cite what's missing.
2. **Gaps** — a deviation, hack, or dead end visible in the diff that the baton omits. The
   omitted embarrassing thing is the most common and most damaging handoff failure.
3. **Dead weight** — lines that fail the admission filter (discoverable from code/diff/git).
   Flag them for deletion; the budget exists to protect the reader.

Return exactly this verdict block:

```
VERDICT: pass | fail
UNSUPPORTED: <claim quoted> — <evidence that's missing>     (repeat per finding, or "none")
GAPS: <what the diff shows that the baton omits>            (repeat per finding, or "none")
DEAD WEIGHT: <line(s) to delete and why>                    (repeat per finding, or "none")
```

Any unsupported claim or gap → `fail`. Dead weight alone → `pass`, but the listed trims are
required, not suggestions. After the writer applies fixes, re-check only the changed lines.
````

- [ ] **Step 2: Validate frontmatter**

Run:
```bash
python3 -c "
import yaml
raw = open('skills/handoff/SKILL.md').read().split('---')[1]
d = yaml.safe_load(raw)
assert d['name'] == 'handoff', d['name']
assert len(d['description']) < 1024, len(d['description'])
print('ok — name matches, description', len(d['description']), 'chars')"
```
Expected: `ok — name matches, description <N> chars` with N < 1024.

- [ ] **Step 3: Functional test — writing mode**

Dispatch one general-purpose subagent with this prompt (adjust nothing except the absolute path):

> Read /Users/smykowski/Projects/claude-skills/skills/handoff/SKILL.md and follow it to write a
> handoff for this situation: You just implemented a rate limiter for an API gateway. The plan
> said to use Redis, but you used an in-process token bucket instead because the test environment
> has no Redis. You tried a sliding-window-log approach first but abandoned it (memory grew
> unbounded per client). The limiter lives in `gateway/ratelimit.py` as
> `TokenBucket.allow(client_id: str) -> bool`. There is one hack: limits are hardcoded at 100
> req/min; config wiring was deferred. The integration test `test_gateway.py::test_burst` is
> flaky under parallel runs. Return only the handoff document.

Verify the output: has exactly the four template sections; ≤150 lines; the Redis deviation and
abandoned sliding-window approach appear under Decisions and deviations; the hardcoded limit and
flaky test appear under Warnings; no narrative or pasted code. If any check fails, fix the SKILL.md
guidance (not the test) and re-run.

- [ ] **Step 4: Functional test — verification mode**

Dispatch one general-purpose subagent:

> Read /Users/smykowski/Projects/claude-skills/skills/handoff/SKILL.md, verification mode. Verify
> this draft handoff against this diff summary. Draft: "# Handoff: rate limiter done. ## World
> state\n- Rate limiting fully works with Redis-backed storage. ## Interfaces you'll build on\n-
> `gateway/ratelimit.py:10` — `TokenBucket.allow(client_id) -> bool`. ## Decisions and
> deviations\n- none. ## Warnings\n- none." Diff summary: adds `gateway/ratelimit.py` implementing
> an in-process TokenBucket class (no Redis imports anywhere), hardcodes LIMIT=100, and adds a
> test marked `@pytest.mark.flaky`. Task spec: "Add Redis-backed rate limiting to the gateway."
> Return only the verdict block.

Verify the output: `VERDICT: fail`; UNSUPPORTED includes the Redis claim; GAPS includes the
hardcoded limit and/or flaky test omissions. If the subagent passes the bad draft, tighten the
rubric wording in SKILL.md and re-run.

- [ ] **Step 5: Commit**

```bash
git add skills/handoff/SKILL.md
git commit -m "Add handoff skill: bounded, verified context batons

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `implement-slice` skill

**Files:**
- Create: `skills/implement-slice/SKILL.md`

**Interfaces:**
- Consumes: the `handoff` skill by name (Phase 5 tells relay-dispatched agents to write their
  outgoing baton with it).
- Produces: the five-phase loop, the P1/P2/P3 triage vocabulary, and the **failure report** block
  (`FAILED / PHASE / ATTEMPTED / EVIDENCE / HYPOTHESIS / SUGGEST`). Task 3's relay skill quotes
  the failure report format and the phase names exactly.

- [ ] **Step 1: Write `skills/implement-slice/SKILL.md` with exactly this content**

````markdown
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
````

- [ ] **Step 2: Validate frontmatter**

Run the same check as Task 1 Step 2 with `skills/implement-slice/SKILL.md` and
`assert d['name'] == 'implement-slice'`.
Expected: `ok — name matches, description <N> chars` with N < 1024.

- [ ] **Step 3: Functional test — comprehension and edge behavior**

Dispatch one general-purpose subagent:

> Read /Users/smykowski/Projects/claude-skills/skills/implement-slice/SKILL.md. Answer three
> questions, citing the phase you're relying on: (1) You check out the base branch and the
> inherited test suite fails. What exactly do you do? (2) You were given a handoff. What must
> your plan contain regarding it? (3) A reviewer finds the code bypasses an interface the
> handoff documented. What are the two legitimate resolutions? Answer in six sentences or fewer.

Verify: (1) stop + failure report, never silently fix; (2) quote the exact handoff lines relied
on; (3) fix the code to use the interface, or report the baton as wrong. If any answer misses,
clarify the SKILL.md wording and re-run.

- [ ] **Step 4: Commit**

```bash
git add skills/implement-slice/SKILL.md
git commit -m "Add implement-slice skill: full-rigor loop for one scoped task

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `relay` skill (orchestrator + references)

**Files:**
- Create: `skills/relay/SKILL.md`
- Create: `skills/relay/references/state-files.md`
- Create: `skills/relay/references/stuck-report.md`

**Interfaces:**
- Consumes: `decompose` skill (Phase 1 rubric and output format), `implement-slice` (dispatched
  per leg; its failure report format and phase names), `handoff` (baton template, verification
  mode, verdict block).
- Produces: the run directory layout under `.relay/<run-id>/`, branch naming
  `relay/<run-id>/leg-<n>`, and the file formats in `references/state-files.md`.

- [ ] **Step 1: Write `skills/relay/SKILL.md` with exactly this content**

````markdown
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
   consecutive fails → treat as a leg failure (protocol below).
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
````

- [ ] **Step 2: Write `skills/relay/references/state-files.md` with exactly this content**

````markdown
# Relay run-state file formats

All run state lives in `.relay/<run-id>/`. These formats are contracts: subagents parse them.

## slices.md

The judge's final decomposition, in the decompose skill's output format, with two fields added
per chunk (`Branch`, and `Base`) and a header:

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

If the failure protocol re-cuts slices, append a line to Judge notes:
`Re-cut after leg <n> failure: <what changed>`.

## status.md

Rewritten (not appended) by the orchestrator at every transition:

```markdown
# Status: <run-id>
Run:        active | halted | complete
Active leg: <n>
Phase:      decompose | implement | baton-pass | anchor

| Leg | Branch                  | Status                              | PR    |
|-----|-------------------------|-------------------------------------|-------|
| 1   | relay/<run-id>/leg-1    | done                                | <url> |
| 2   | relay/<run-id>/leg-2    | implementing | baton | failed | todo | —     |
```

## learnings.md

Append-only one-line rules. Each line must be actionable and imperative — a rule the next agent
can obey without context. Never narrative.

```markdown
- Test suite needs `--forks=1`; parallel runs flake on the shared fixture DB.
- `make check` is the real gate; `make test` skips the linter.
```

Discipline: dedupe before appending; soft cap ~30 lines — at the cap, the orchestrator dispatches
a consolidation pass (merge overlapping rules, drop ones only relevant to completed legs).

## legs/<n>/ contents

- `handoff-in.md` — the baton this leg received (leg 1: problem.md contents).
- `plan.md` — the implementer's plan (test list, files, wiring with quoted baton lines).
- `review.md` — triaged findings P1–P3 and their resolutions.
- `handoff-out.md` — the verified outgoing baton.
- `pr.md` — only when no remote/PR tooling exists: the would-be PR title and body.
````

- [ ] **Step 3: Write `skills/relay/references/stuck-report.md` with exactly this content**

````markdown
# Stuck-report format

Written to `.relay/<run-id>/stuck-report.md` when a leg fails twice. The reader is a human
deciding what to do next — write for that decision, not as a log.

```markdown
# Stuck: <run-id> — leg <n> (<leg title>)

## What this run was building
<two sentences: the problem, and how far the race got — legs done / legs remaining>

## Where it stopped
Leg <n>, phase <phase from the failure report>. <One sentence on the obstacle.>

## Attempt 1 (original plan)
Approach: <what the leg tried>
Evidence: <the trimmed errors/output that ended it>

## Attempt 2 (after re-plan)
What the re-plan changed: <how the second attempt differed>
Evidence: <the trimmed errors/output that ended it>

## Hypothesis
<best root-cause guess, and what evidence would confirm or kill it>

## Your options
1. <option> — <tradeoff>
2. <option> — <tradeoff>
3. <option> — <tradeoff>

## State of the stack
<which branches/PRs are complete and sound (safe to review/merge bottom-up), which are
abandoned; where the run directory is>
```

Both attempt sections quote the implement-slice failure reports — don't re-summarize evidence
into vagueness. Options must be genuinely different decisions (re-cut differently, change the
approach, drop the feature, do it manually), not three phrasings of "try again".
````

- [ ] **Step 4: Validate frontmatter**

Run the Task 1 Step 2 check with `skills/relay/SKILL.md` and `assert d['name'] == 'relay'`.
Expected: `ok — name matches, description <N> chars` with N < 1024.

- [ ] **Step 5: Functional test — tabletop run**

Dispatch one general-purpose subagent:

> Read /Users/smykowski/Projects/claude-skills/skills/relay/SKILL.md and both files in
> /Users/smykowski/Projects/claude-skills/skills/relay/references/. Without executing anything,
> walk through a run for this toy problem: "Add CSV export to a reporting web app" in a repo whose
> default branch is `main`, assuming the judge approves 3 slices. List, in order, every subagent
> dispatch you would make (one line each: purpose + which SKILL.md path it receives), every file
> you would write with its exact path, and every git branch with its exact name and base. Then
> answer: leg 2's implementer reports a FAILED block — what are your next two actions, exactly?

Verify: dispatch order is 2–3 decomposers → judge → per-leg (implementer → verifier) ×3 → anchor;
paths match `.relay/<run-id>/...` layout; branches are `relay/<run-id>/leg-{1,2,3}` with leg 1
based on `main`, leg 2 on leg 1, leg 3 on leg 2; failure answer is (1) dispatch re-plan planner
with failure report + artifacts, (2) resume loop at leg 2, and halt with stuck-report only on a
second failure. Fix SKILL.md ambiguities if the walkthrough diverges, re-run.

- [ ] **Step 6: Commit**

```bash
git add skills/relay/
git commit -m "Add relay skill: autonomous decompose-and-implement orchestrator

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: README update

**Files:**
- Modify: `README.md` (table at lines 5–8; new sections before the License section)

**Interfaces:**
- Consumes: final skill names and one-line purposes from Tasks 1–3.
- Produces: nothing downstream.

- [ ] **Step 1: Add three rows to the skills table (after the existing two rows)**

```markdown
| [`relay`](skills/relay) | Implement a large problem end-to-end, autonomously: decompose into vertical slices, run each in a fresh context, pass verified handoffs between them, ship a stack of small PRs. |
| [`implement-slice`](skills/implement-slice) | Implement one well-scoped task with full rigor: orient, plan, TDD, multi-lens review, end-to-end verification. |
| [`handoff`](skills/handoff) | Write (and verify) a bounded context handoff — a "baton" that carries what code and git can't say, without the bloat. |
```

- [ ] **Step 2: Add skill sections before the `## License` heading**

```markdown
---

## `relay`

Implements a large problem **end-to-end, autonomously**, as a relay race: the work is decomposed
into vertically-sliced legs (multi-candidate decomposition with a judge, built on
[`decompose`](skills/decompose)), each leg is implemented by a **fresh-context agent** running the
full [`implement-slice`](skills/implement-slice) loop on a stacked branch, and a bounded, verified
**baton** ([`handoff`](skills/handoff)) passes between legs. You come back to a stack of small
reviewable PRs, mergeable bottom-up, plus distilled learnings.

Context rot is the enemy it's built against: every leg starts at zero context, batons are hard-
capped and audited for bloat, and run-local learnings are one-line rules with a consolidation
cap. A failed leg gets one evidence-informed re-plan; a second failure halts the run with a
stuck-report written for a human decision. All run state lives on disk under `.relay/<run-id>/`,
so a dead session resumes where it stopped.

## `implement-slice`

Runs **one PR-sized task at full rigor**, designed for a fresh context: orient against inherited
state (never build on sand), plan with an explicit test list, implement test-first, review the
diff with 3–4 parallel single-lens subagents (correctness, tests, integration, simplification),
fix P1/P2 findings, then verify the real flow end-to-end before opening the PR. Useful standalone
on any scoped task; it's also the engine `relay` dispatches per leg.

## `handoff`

Writes — and adversarially **verifies** — context handoffs. The baton is a **delta, not a
chronicle**: ≤150 lines, four sections (world state, interfaces, decisions & deviations,
warnings), admitting only what the reader can't discover from code, diff, or git log. Verification
mode audits a draft against the actual diff for unsupported claims, omissions, and dead weight.
Use it before clearing context, ending a session, or passing work to any fresh agent.

```

- [ ] **Step 3: Verify README renders sanely**

Run: `grep -c '^| \[' README.md`
Expected: `5` (five table rows). Skim the table and new sections for broken links
(`skills/relay`, `skills/implement-slice`, `skills/handoff` all exist by now).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Document relay, implement-slice, and handoff skills in README

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: End-to-end smoke test in a scratch repo

**Files:**
- Create (scratch, not committed to this repo): a throwaway git repo `relay-smoke/` in the
  session scratchpad directory (listed in your system prompt; fall back to `/tmp` if none).

**Interfaces:**
- Consumes: all three skills as installed files (pass absolute paths into the dispatched run).
- Produces: evidence the family works together; any fixes discovered feed back into Tasks 1–3
  files (amend with follow-up commits).

- [ ] **Step 1: Create the scratch target repo**

```bash
SCRATCH="$YOUR_SCRATCHPAD_DIR/relay-smoke"   # substitute the scratchpad path from your system prompt
mkdir -p "$SCRATCH" && cd "$SCRATCH" && git init -b main
cat > todo.py <<'EOF'
"""A tiny todo CLI. Usage: todo.py <command> [args]"""
import sys

def main():
    print("no commands yet")

if __name__ == "__main__":
    main()
EOF
cat > test_todo.py <<'EOF'
import todo

def test_placeholder():
    assert callable(todo.main)
EOF
git add -A && git commit -m "Scaffold tiny todo CLI"
python3 -m pytest -q
```
Expected: `1 passed`.

- [ ] **Step 2: Run a relay on a 2–3 slice problem**

In the scratch repo, act as the relay orchestrator yourself (or dispatch a subagent to do so):
follow `/Users/smykowski/Projects/claude-skills/skills/relay/SKILL.md` for the problem:

> Add persistent todos to todo.py: `add <text>` and `list` commands storing items in a JSON file,
> then `done <n>` to mark an item complete (shown in list output). Tests with pytest.

Pass the absolute SKILL.md paths from this repo for decompose/implement-slice/handoff. Expect the
judge to settle on 2–3 legs (spine: add+list end-to-end; then done). No remote exists, so legs
produce `pr.md` files instead of PRs.

- [ ] **Step 3: Verify the run artifacts**

Check, in the scratch repo:
- `.relay/<run-id>/` contains `problem.md`, `slices.md`, `status.md` (Run: complete),
  `learnings.md`, `summary.md`, and a `legs/<n>/` dir per leg with all four files.
- Every `handoff-out.md` is ≤150 lines: `wc -l .relay/*/legs/*/handoff-out.md`.
- Branches exist and stack: `git branch --list 'relay/*'` shows leg-1..N; leg N contains leg
  N-1's commits (`git log --oneline relay/<run-id>/leg-2` includes leg-1 commits).
- The final leg's branch passes tests: `git checkout relay/<run-id>/leg-<last> && python3 -m
  pytest -q` → all pass; `python3 todo.py add "x" && python3 todo.py list` shows the item.

- [ ] **Step 4: Feed fixes back and commit**

Any skill ambiguity or failure the smoke run exposed: fix the relevant SKILL.md/references file
in this repo, re-verify the specific step that failed, then:

```bash
cd /Users/smykowski/Projects/claude-skills
git add skills/ && git commit -m "Tighten relay-family skills from smoke-test findings

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
(Skip the commit if the smoke run surfaced nothing — do not manufacture changes.)
