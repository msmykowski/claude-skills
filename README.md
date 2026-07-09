# claude-skills

A small collection of [Claude](https://claude.com/claude-code) skills.

| Skill | What it does |
|-------|--------------|
| [`decompose`](skills/decompose) | Break a large piece of work into an ordered sequence of small, independently mergeable pull requests — before any code is written. |
| [`functional-core-imperative-shell`](skills/functional-core-imperative-shell) | Write or restructure code so decisions live in a pure functional core and side effects (DB, network, time, randomness) sit in a thin imperative shell. Elixir-first; principles general. |
| [`relay`](skills/relay) | Implement a large problem end-to-end, autonomously: decompose into vertical slices, run each in a fresh context, pass verified handoffs between them, ship a stack of small PRs. |
| [`implement-slice`](skills/implement-slice) | Implement one well-scoped task with full rigor: orient, plan, TDD, multi-lens review, end-to-end verification. |
| [`handoff`](skills/handoff) | Write (and verify) a bounded context handoff — a "baton" that carries what code and git can't say, without the bloat. |

---

## `decompose`

Turns one large or unwieldy piece of work — a ticket, feature, bug, refactor, or migration — into
an **ordered sequence of small, independently mergeable pull requests** before any code is written.

It answers the planning question *"how do I break this up into PRs?"* — it does **not** write the
implementation. Think of it as the step between "here's the work" and "here's the first PR."

### What it does

Given a unit of work, the skill produces an ordered PR plan where each chunk:

- is **legible** — a reviewer can state in one sentence what it adds;
- is **load-bearing** — something already calls it (no dead-layer PRs that nothing uses yet);
- is **correct standalone** — it merges without breaking trunk;
- sits in the **~50–200 LOC** sweet spot, reviewable in under an hour.

It defaults to **vertical slicing** (a thin end-to-end "tracer bullet" first, then one increment
per PR) and reaches for **branch-by-abstraction**, **parallel change (expand → migrate →
contract)**, **characterization-test safety nets** (for refactors), **feature flags**, and
**stacked PRs** when a clean vertical slice isn't possible. It also knows when *not* to split — it
will tell you to ship a single PR when the work already clears the bar, and it refuses to cut
through a "correctness floor" where a further split would ship half-correct behavior.

### Why trust the defaults

The skill's defaults aren't opinion — they're grounded in verified research (the SmartBear/Cisco
peer-review study, Martin Fowler's *Branch by Abstraction* and *Parallel Change*, the
tracer-bullet / walking-skeleton literature, and Feathers' characterization-testing). The findings,
with vote tallies and the claims that were **refuted** under adversarial verification, are in
[`skills/decompose/references/evidence.md`](skills/decompose/references/evidence.md). Read it
before overriding a default, so you override the dogma and not the evidence.

## Install

Each skill lives under `skills/<name>`. To install one, copy or symlink its folder into your
Claude skills directory so the folder name matches the skill name. For `decompose`:

```bash
git clone https://github.com/<your-username>/claude-skills.git
ln -s "$(pwd)/claude-skills/skills/decompose" ~/.claude/skills/decompose
```

(Or just `cp -r claude-skills/skills/decompose ~/.claude/skills/decompose`.)

The skill is then discovered automatically. Trigger it by asking things like:

- "This feature is too big for one PR — how should I split it?"
- "How do I land this column rename without one giant scary PR?"
- "What should the first/smallest PR be here?"

### What `decompose` is *not* for

Resolving merge conflicts, rebasing/squashing, story-point estimation, reviewing an existing PR,
microservice/architecture design, or speeding up review turnaround.

---

## `functional-core-imperative-shell`

Separates the code that **decides** from the code that **acts**. Business rules, validation,
calculations, and state transitions go in a **functional core** of pure functions (data in, data
out, no I/O); everything impure — database, network, queues, the clock, randomness, UUIDs, logging —
lives in a thin **imperative shell** that wraps the core. The shell calls the core; the core never
calls the shell. The payoff: the core is deterministic, so it's tested with plain input/output
assertions and *no mocks*, and the shell shrinks to thin glue.

It guides both **writing new code** and **refactoring** tangled code (the "needs the DB and mocks
the HTTP client to test" function) into a pure core + thin shell. **Elixir-first** — Ecto changesets
as a pure validation core, `Repo`/`Ecto.Multi` at the edge, GenServer as a thin shell over a pure
`Impl` module, Mox + behaviours for boundary tests, `with` for railway sequencing — but the
principles are language-agnostic.

It is deliberately **not dogmatic**: it tells you to skip FC/IS for thin CRUD/glue and for set-based
or streaming database work (let the DB decide), warns that "a green core is not a green system"
(budget shell integration tests), and flags the predicate-in-shell anemic-core smell. The cited
sources and the over-stated/refuted claims are in
[`skills/functional-core-imperative-shell/references/evidence.md`](skills/functional-core-imperative-shell/references/evidence.md).

---

## `relay`

Implements a large problem **end-to-end, autonomously**, as a relay race: the work is decomposed
into vertically-sliced legs (multi-candidate decomposition with a judge, built on
[`decompose`](skills/decompose)), each leg is implemented by a **fresh-context agent** running the
full [`implement-slice`](skills/implement-slice) loop on a stacked branch, and a bounded, verified
**baton** ([`handoff`](skills/handoff)) passes between legs. You come back to a stack of small
reviewable PRs, mergeable bottom-up, plus distilled learnings.

Context rot is the enemy it's built against: every leg starts at zero context, batons are
hard-capped and audited for bloat, and run-local learnings are one-line rules with a
consolidation cap. A failed leg gets one evidence-informed re-plan; a second failure halts the run
with a stuck-report written for a human decision. All run state lives on disk under
`.relay/<run-id>/`, so a dead session resumes where it stopped.

---

## `implement-slice`

Runs **one PR-sized task at full rigor**, designed for a fresh context: orient against inherited
state (never build on sand), plan with an explicit test list, implement test-first, review the
diff with 3–4 parallel single-lens subagents (correctness, tests, integration, simplification),
fix P1/P2 findings, then verify the real flow end-to-end before opening the PR. Useful standalone
on any scoped task; it's also the engine `relay` dispatches per leg.

---

## `handoff`

Writes — and adversarially **verifies** — context handoffs. The baton is a **delta, not a
chronicle**: ≤150 lines, four sections (world state, interfaces, decisions & deviations,
warnings), admitting only what the reader can't discover from code, diff, or git log. Verification
mode audits a draft against the actual diff for unsupported claims, omissions, and dead weight.
Use it before clearing context, ending a session, or passing work to any fresh agent.

## License

[MIT](LICENSE)
