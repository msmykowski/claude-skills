# claude-skills

A small collection of [Claude](https://claude.com/claude-code) skills.

| Skill | What it does |
|-------|--------------|
| [`decompose`](skills/decompose) | Break a large piece of work into an ordered sequence of small, independently mergeable pull requests — before any code is written. |

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

## License

[MIT](LICENSE)
