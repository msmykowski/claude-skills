---
name: decompose
description: >-
  Use when a user wants to split a large or unwieldy piece of work into multiple small
  pull requests before writing the code — the planning step that answers "how do I break
  this up into PRs?". Takes a ticket, epic, feature, bug, refactor, migration, or a
  finished plan/design doc and produces an ordered sequence of small, independently
  mergeable PRs (chunks, diffs, stacked PRs, shippable steps), each with what it delivers,
  why it's correct standalone, dependencies, and rough size. Trigger whenever the user asks
  to break up, chunk, decompose, sequence, or stack work into reviewable PRs; asks what the
  first or smallest PR should be; says something is too big for one PR or one review; or
  asks how to land a big change one PR at a time. Handles cross-cutting features and vague
  scope. Language- and stack-agnostic. Don't use for resolving merge conflicts,
  rebasing/squashing, story-point estimation, reviewing an existing PR,
  microservice/architecture design, or speeding up review turnaround.
---

# Decompose Work Into Small PRs

Turn one unit of work (a ticket, feature, bug, refactor, or migration) into an **ordered
sequence of small chunks**, each of which a reviewer can understand and merge with
confidence. This skill decides *how to split and sequence* — it does not implement the code.

The defaults below are grounded in verified research (the SmartBear/Cisco code-review study,
Fowler's Branch by Abstraction / Parallel Change, the tracer-bullet / walking-skeleton
literature, and stacked-PR practice). See `references/evidence.md` for the cited findings and
the claims that were *refuted* under adversarial verification — read it before overriding a
default, so you override the dogma and not the evidence.

## The one bar every chunk must clear

A chunk is well-formed only if **both** are true:

1. **Legible** — a reviewer can state in *one sentence* what capability or behavior it adds.
2. **Load-bearing** — something already uses it. Either it adds observable behavior to the
   running system, *or* it has a real caller in the same change (e.g., a helper extracted
   and immediately routed through by existing code). A module nothing calls yet fails the bar.

If a proposed chunk can't clear both, it's either too small (merge it forward into the chunk
that gives it a caller) or mis-cut (re-slice).

## First, decide whether to split at all

Decomposition is a cost, not a virtue. More PRs mean more review rounds, more rebase churn, and
more dependency bookkeeping. Before cutting, check the whole change against the bar: if it's
already one legible, load-bearing slice that fits the size budget below (~200 LOC, <60 min to
review), the right answer is **one PR — say so and stop**. The goal is the *fewest* chunks that
each clear the bar, not the most. Only split when the work genuinely exceeds what one reviewer can
hold, or when an internal seam (a contract change, a risky path, an atomic decision) makes a single
PR unsafe. Don't manufacture chunks to look thorough.

## Procedure

Work top to bottom. Stop when every chunk clears the bar and the sequence is dependency-ordered.

### 1. Map the whole before cutting
Identify, briefly: the end-to-end behavior the work delivers; the layers/components it
crosses; the integration seams (events, contracts, interfaces, transaction boundaries);
and **what already exists** vs. what's net-new. You can't find good seams without this map.

### 2. Find the spine (default: a vertical tracer bullet)
The first chunk should be the **thinnest end-to-end slice that produces observable behavior** —
a tracer bullet / walking skeleton that exercises the real critical path through every layer it
must touch, even if it handles only the simplest case. This validates the path early and means
every later chunk has something live to extend. The spine is usually the *largest* chunk because
it stands up the structure; that's expected and acceptable.

> Default, not dogma: vertical slicing wins because building layers in isolation produces
> unwired, untested code (verified 3-0). But "*every* slice must cut *all* layers and be
> independently demoable" was **refuted (0-3)**. See step 7 for when horizontal is right.

> Refactors are the special case: when you're restructuring existing code rather than adding
> behavior, there's nothing new to demo, so the spine is usually a **characterization-test
> safety net** instead — see step 5.

### 3. Grow one slice at a time
Each subsequent chunk adds **one** increment of observable behavior or capability on top of the
spine (the next case, the next field, the next outcome, the next integration). Each is small
because the structure already exists.

### 4. Respect the correctness floor
Do **not** split below the point where a chunk becomes incorrect or non-deliverable. Some
decisions are atomic: if a single branch point decides two outcomes, shipping only one outcome
leaves the other silently mishandled — they must land together. The floor is reached when any
further cut would force a chunk to be half-correct, leave the build red, or ship behavior the
system can't yet handle safely. Recognizing the floor is a feature: it's the smallest *honest*
slice, not a compromise.

### 5. When a clean vertical slice isn't possible, use an enabling pattern
Large or interface-breaking changes often can't be delivered as one thin slice without breaking
trunk. Reach for (see `references/evidence.md` for mechanics):
- **Characterization tests first** — when the work is a refactor of code that lacks trustworthy
  tests, the first chunk is a test-only PR that pins the *current* behavior (bugs and all). It
  ships no behavior change, but it's load-bearing: it's the oracle every later extraction is
  verified against, the thing that makes "behavior unchanged" a checkable claim instead of a hope.
  Without it you can't tell a safe refactor from a silent regression, so it comes before any code
  moves. Expect it to exceed the size budget — thorough coverage of tangled paths isn't small,
  and that's the correct call (tests are cheaper to review than logic).
- **Branch by Abstraction** — introduce an abstraction over the current implementation, migrate
  callers, build the new implementation behind it, swap (optionally behind a flag), delete the old.
  Each step is its own releasable chunk.
- **Parallel Change (expand → migrate → contract)** — for changing a contract/interface/schema:
  add the new shape alongside the old (expand), move callers (migrate), remove the old (contract).
  Each phase ships independently.
- **Feature flag / dark launch** — merge incomplete or not-yet-exposed behavior in a dormant
  state so partial work lands safely on trunk.
- **Stacked PRs** — when chunks genuinely depend on each other, stack them so each stays small
  and reviewable and you don't block waiting on the one below.

### 6. Size to the evidence
Target **~50–200 lines** per chunk; treat ~**400** as a hard ceiling and **~60 minutes** of
review as the budget. Past ~200 LOC, defect-finding drops sharply. If a chunk blows the ceiling,
it's a signal to re-cut — but never at the cost of the correctness floor (step 4). A correct
300-line chunk beats two incorrect 150-line chunks.

### 7. Know when horizontal / foundational is legitimately right
Override the vertical default when the slice is **pure infrastructure** with no behavior to
demo (a shared library, a config primitive), the **requirements are fixed and fully known** so
late critical-path surprises are unlikely, or **layers are genuinely developed independently**
by different people/teams. In these cases a horizontal chunk can still clear the bar if it has a
real caller — otherwise defer it until the chunk that would use it.

### 8. Sequence by dependency and stack to stay unblocked
Order chunks so each depends only on earlier ones. Put the riskiest critical-path validation
early (that's usually the spine). Where chunks depend on each other, prefer stacking over one
big PR.

## Output format

Produce an ordered list. For each chunk:

```
PR<n>. <imperative title>
  Delivers:   <one sentence — the capability/behavior a reviewer will see>
  Correct standalone because: <why it's safe to merge alone — passes tests, doesn't break
                               trunk, handles its cases fully, or is dormant behind a flag>
  Depends on: <earlier PR ids, or "nothing">
  Size:       <rough LOC / S-M-L>
  Pattern:    <only if relevant: branch-by-abstraction | parallel-change | feature-flag | stacked | spine>
```

Close with a one-line **sequencing rationale** (what the spine validates, why this order) and
flag any chunk that sits at the **correctness floor** (cannot be split further without becoming
incorrect).

## Anti-patterns to avoid

- **Dead-layer PRs** — a module/class/schema nothing calls yet. Fails the load-bearing bar;
  merge it forward into the chunk that gives it a caller.
- **Horizontal-by-default** — slicing strictly by layer (all schema, then all logic, then all
  UI) so the critical path is never exercised until the end. Use only with step-7 justification.
- **Splitting through a correctness floor** — cutting an atomic decision in half so one case
  ships mishandled. Keep atomic decisions together.
- **Size over correctness** — shaving a chunk under a LOC target by leaving it half-correct.
  Correctness wins; re-cut elsewhere.
- **The mega-spine** — cramming every case into the first end-to-end slice. The spine handles
  the *simplest* case; everything else grows in later chunks.
- **Hidden mega-PR via stacking** — a stack of ten interdependent PRs that must all land
  together is one big PR wearing a costume. Stacks should be independently valuable where possible.
- **Over-splitting** — manufacturing chunks from work that already clears the bar as one PR.
  Fragmentation has real costs (review rounds, rebase churn). Fewest chunks that clear the bar wins.
- **Blind refactor** — restructuring untested code without a characterization-test net first, so
  "behavior unchanged" is a hope, not a checkable claim.

## Quick checklist

- [ ] Confirmed the work actually needs splitting (not already one honest, in-budget PR)
- [ ] Mapped end-to-end behavior, layers, seams, and what already exists
- [ ] First chunk is a thin end-to-end spine that runs (or, for refactors, a characterization-test net)
- [ ] Every chunk: one-sentence delivery + a real caller (load-bearing bar)
- [ ] No chunk split through a correctness floor; atomic decisions kept together
- [ ] Refactors of untested code establish a behavior-pinning test net before any code moves
- [ ] Interface/contract changes use parallel-change or branch-by-abstraction
- [ ] Chunks target ~50–200 LOC (≤~400), reviewable in <60 min
- [ ] Ordered by dependency; stacked where dependent
- [ ] Horizontal slices justified by step 7, else deferred to their caller
