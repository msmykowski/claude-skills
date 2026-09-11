---
name: improve-elixir-architecture
description: Use when asked to review an Elixir codebase's architecture, assess Phoenix context boundaries, find deepening opportunities, or simplify module and OTP interfaces before a refactor. Supports architecture surveys and exploration of a selected candidate; not routine feature implementation or isolated bug diagnosis.
---

# Improve Elixir Architecture

Find changes that let callers accomplish a domain operation while knowing less
about its implementation. Optimize for useful interfaces, local reasoning and
behavioral tests. A good outcome can be **no worthwhile refactor**.

## Working agreement

Default to a source review and an offline HTML survey. Respect a requested scope,
format, output path or report-only mode. The survey does not modify application
code, dependencies, configuration, domain documents or ADRs. If the user already
selected a candidate, reuse available evidence and enter the design step.

Keep this skill self-contained: no other skill, specific agent provider or
parallel-agent facility is required. Delegate independent exploration only when
the user's instructions and environment permit it; synthesize evidence yourself.

## Design vocabulary

| Term | Meaning for this review |
|---|---|
| Module | An abstraction with an interface and implementation; it may span several Elixir modules. |
| Interface | Everything callers must know: inputs, results, errors, ordering, authorization, configuration and runtime guarantees. |
| Depth | Useful behavior hidden behind an interface that is easier to understand than that behavior. Not a line-count ratio. |
| Seam / adapter | A point of replaceable behavior / an implementation used at that point. |
| Locality | A rule, its changes and its verification concentrate in one responsible place. |
| Leverage | Callers gain capability without learning the hidden coordination. |

Use the project's domain language. “Context,” “API,” “process” and “boundary” are
useful Elixir terms; distinguish what each means rather than banning them.

## 1. Establish scope and evidence

Read applicable project instructions, `mix.exs`, `mix.lock`, version files, domain
notes (such as `CONTEXT.md`) and relevant ADRs. Identify library vs application,
umbrella structure, dependencies and supervision entrypoints. Framework guidance
applies only when that framework is present; respect other stacks such as Ash.

Follow a user-named module, upcoming change or pain point. Otherwise examine recent
history, for example `git log -n 40 --oneline --name-only`, and prioritize recurring
changes. Treat generated files and formatting churn separately from domain churn.
If history is unavailable, say so and use current callers and tests.

Use `rg --files` and focused `rg -n` searches. Trace representative operations from
entrypoint through domain rules, data access and effects, then through their tests.
Read consumers as well as definitions. Distinguish observed facts from hypotheses
and omitted source. Stop expanding when the scoped findings have enough evidence
to compare; do not survey unrelated subsystems to fill a quota.

Start with [Elixir design](references/elixir-design.md). Read only relevant detail:

- Stateful or asynchronous work: [OTP runtime](references/otp-runtime.md).
- Phoenix, LiveView, Ecto or Oban: [framework boundaries](references/framework-boundaries.md).
- Tests and dependency substitution: [testing seams](references/testing-seams.md).
- A concrete functional example: [reservation example](references/reservations.exs).

Inspect versions before citing APIs or recommending commands. `mix xref` can help
with compile dependencies, but does not reveal every runtime message or dynamic
call. Mix commands may compile or run project code; use them only when appropriate
for the environment. A static survey can proceed without executing the project.

## 2. Evaluate candidate changes

For each suspected problem, identify the knowledge callers currently duplicate or
must coordinate. Apply the **deletion test** in both directions: remove the present
abstraction mentally, then remove the proposed abstraction. State where the rules,
protocol details and tests would go. Removing a pass-through may erase complexity;
removing a useful facade may spread it. A thin GenServer client API can hide a
substantial process contract. File size and function count alone prove neither.

Describe one ownership change per candidate. Group intertwined symptoms of the
same change, and distinguish a small useful improvement from optional later work.
Preserve meaningful pure modules and intentional isolation. Do not introduce a
process, behaviour, generic repository, umbrella app or macro just to add layers.

Rank by observed caller burden, relevance to upcoming changes, expected benefit
and migration cost. Surface an ADR conflict only with evidence worth reopening it.
Label uncertain benefits honestly. Use the report contract below; signatures,
new state schemas and implementation plans belong to the selected design step.

## 3. Deliver the survey

Follow [the offline report contract](references/report.md). Include evidence,
before/after relationships, benefits, risks and behavioral verification for each
candidate. List important healthy boundaries separately. Do not convert retention
decisions into refactoring candidates just to populate the report.

Return the artifact's actual path/link and a short top recommendation. In
**report-only** mode, end there. Otherwise ask which candidate the user wants to
explore, then wait. An empty finding set needs no selection question.

## 4. Explore one selected candidate

Resolve consequential unknowns from the code first. Ask focused questions only
where the user must decide; avoid repeating established constraints. Compare two
or three materially different designs when the tradeoff warrants it, including
retaining the current design when reasonable.

Produce a compact decision record covering:

1. Domain responsibility, public functions and representative callers.
2. Input/result/error contracts, authorization and invariants.
3. What remains behind the interface: data, private modules and dependencies.
4. When relevant: transaction ownership, process lifetime, concurrency, timeout,
   retry, recovery and ambiguous external outcomes.
5. Compatibility/migration steps and tests through the intended seam.
6. Rejected alternatives, tradeoffs and remaining decisions.

Finish at a reviewable design. Refactoring or saving project documentation is a
separate requested action; honor authorization already given in the conversation.
Offer an ADR only for a durable decision that future reviews would need to know.

## Attribution

Adapted from the concepts and survey workflow of Matt Pocock's
[improve-codebase-architecture](https://github.com/mattpocock/skills/tree/main/skills/engineering/improve-codebase-architecture)
and [codebase-design](https://github.com/mattpocock/skills/tree/main/skills/engineering/codebase-design).
See [the original MIT notice](LICENSE). Elixir-specific interpretations and the
example are included here; primary documentation is linked in each reference.
