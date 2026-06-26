# Evidence base — decompose

Findings behind the skill's defaults, from a deep-research pass that fanned out across five
angles, fetched 20 sources, extracted 96 claims, and adversarially verified the top 25
(3-vote, kill on 2/3 refutes). Vote tallies shown as `confirms-refutes`. The **refuted** claims
matter as much as the confirmed ones: they mark where popular advice over-reaches.

## Size & review effectiveness

- **Effective review band ≈ 100–300 LOC per review; recommended ceiling 200, do not exceed ~400.**
  (3-0) — SmartBear/Cisco *Best Kept Secrets of Peer Code Review* + Cisco case study.
- **Defect-finding drops sharply past ~200 LOC.** No review >250 lines exceeded 37 defects/kLOC,
  while sub-200-line reviews often found several× that density. (3-0)
- **Reviewers wear out after ~60 minutes** and stop finding defects; a reviewer can't effectively
  review more than ~300–400 LOC. Keep sessions <60 min (max ~90). (3-0)
- **Slower inspection rate → higher defect detection.** (3-0)
- **PRs ~50–200 LOC review faster with fewer bugs** than larger ones. (3-0) — industry benchmarks.
- **Small, atomic PRs correlate with engineer productivity;** even single-line changes warrant
  ≥5 minutes because small changes can have system-wide ramifications. (3-0)

## Slicing strategy (vertical vs horizontal)

- **Vertical slicing is the default.** A tracer bullet / walking skeleton — "a small, end-to-end
  slice of functionality that touches all the layers of your system at once" — validates the
  critical path early. (2-1: *preferable*, i.e. a default, not an absolute.)
- **Building layers in isolation produces unwired/untested code whose critical path is never
  verified end-to-end.** (3-0) — the core reason to avoid horizontal-by-default and the basis for
  the skill's "load-bearing" bar.
- **REFUTED (0-3):** "A valid slice must deliver a complete path through *every* layer and be
  demoable on its own." → Do not require every chunk to cut all layers or be independently demoable.
- **REFUTED (1-2):** "Decompose via vertical slicing *rather than* horizontal." → Not an either/or.
  Horizontal slicing keeps legitimate uses: **pure infrastructure, fixed/known requirements, and
  independently-developed layers.**
- **REFUTED (1-2):** "At Microsoft, *understanding* (not defect detection) is the key determinant
  of review effectiveness." → Don't assert this; the comprehension framing didn't survive.

## Incremental-delivery patterns (keep trunk releasable while splitting)

- **Branch by Abstraction** (3-0) — make a large-scale change gradually while the system stays
  continuously releasable, as an alternative to a long-lived feature branch. Ordered steps:
  introduce an abstraction over the current implementation → migrate clients to it → build the new
  implementation behind the same abstraction → swap progressively (optionally via feature flags) →
  delete the old code and the abstraction once unused. (Fowler; continuousdelivery.com)
- **Parallel Change / expand–migrate–contract** (3-0) — decompose an interface-impacting change
  into three sequential, independently-releasable phases (expand the interface to support old +
  new, migrate callers, contract away the old), shippable at any phase boundary. (Fowler)
- **Stacked diffs/PRs** (3-0) — let engineers create many small dependent PRs without waiting for
  each one's review, keeping them unblocked; the conventional single-branch flow blocks this.
  (Graphite, GitLab, Greiler, Pragmatic Engineer)
- **Tracer bullet / walking skeleton** (3-0) — the thin end-to-end slice that stands up the whole
  path so later slices extend something live. (Pragmatic Programmer; codeclimate)
- **Characterization tests before refactoring** — pin existing behavior with tests *before*
  restructuring legacy/untested code, so each step is provably behavior-preserving; the test net is
  the prerequisite that makes incremental, mergeable refactor PRs safe. Recurring real-world signal:
  independent decompositions of an untested "god function" all reach for this net first, unprompted —
  which is why the skill now names it explicitly rather than leaving the model to rediscover it.
  (Feathers, *Working Effectively with Legacy Code* — characterization tests; approval / golden-master
  testing.)

## Key sources

- SmartBear/Cisco — *Best Kept Secrets of Peer Code Review* / Cisco case study (PDF, primary).
- Martin Fowler — *ParallelChange*: https://martinfowler.com/bliki/ParallelChange.html
- Martin Fowler — *BranchByAbstraction*: https://martinfowler.com/bliki/BranchByAbstraction.html
- *Make large-scale changes incrementally with branch by abstraction* — continuousdelivery.com
- *Tracer bullets* — https://www.aihero.dev/tracer-bullets ; walking skeleton — codeclimate blog
- Stacked PRs — git-tower.com/blog/stacked-prs ; michaelagreiler.com/stacked-pull-requests ;
  newsletter.pragmaticengineer.com/p/stacked-diffs
- Splitting large changes — pullrequest.com ; thedroidsonroids.com/blog/splitting-pull-request ;
  blog.thepete.net (6 practices for effective pull requests)
- LinearB 2025 engineering benchmarks (PR-size vs cycle-time data)

## How to use this file

The skill's defaults *are* these findings. When a situation pushes you to override a default,
check it against the refuted claims first: overriding "vertical-by-default" for pure infrastructure
is evidence-aligned; requiring every chunk to be independently demoable is not.
