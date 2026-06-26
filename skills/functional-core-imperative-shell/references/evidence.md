# Evidence base — functional-core-imperative-shell

Findings behind the skill's defaults, from a deep-research pass across four angles (origin/theory,
Elixir specifics, practical mechanics, and an adversarial critique sweep). The **over-stated /
refuted** claims matter as much as the confirmed ones: they mark where popular advice over-reaches.

## Origin & core claim

- **Functional Core, Imperative Shell** was named by Gary Bernhardt in *Boundaries* (2012). Thesis:
  use simple **values** as the boundaries between subsystems; decision logic lives in a pure
  functional core (values in, values out, no mutation/I/O), wrapped by a thin imperative shell that
  "manipulates stdin, stdout, the database, and the network, all based on values produced by the
  functional core."
- **Directional rule:** the shell can call the core, but the core cannot call the shell and is
  unaware it exists. This follows from purity — a pure function calling an impure one becomes impure.
- **Testing payoff:** "many fast unit tests for the functional core and few integration tests for
  the imperative shell." The core's tests need no setup and **no test doubles** — the values are the
  seams.

## Patterns it generalizes / relates to

- **Impureim sandwich / dependency rejection (Mark Seemann):** "Pure functions can't have
  dependencies," so *reject* dependencies instead of injecting them — gather data (impure) → decide
  (pure) → act (impure). Refactor indirect input/output into direct input/output.
- **Decide-then-act / Decider (functional event sourcing):** `decide : cmd -> state -> events` and
  `evolve/apply : state -> event -> state`, both pure; the shell loads state, calls `decide`, and
  persists the returned events. The core returns *effects as data*.
- **Hexagonal / Ports & Adapters, Onion, Clean** are cousins — domain at the center, infrastructure
  at the edge. Key distinction: those **invert** dependencies (the core calls injected ports); FC/IS
  **rejects** them (no dependency in the core at all). Treating them as identical hides the design
  choice that matters.
- **Railway-oriented programming (Wlaschin)** and **parse-don't-validate (Alexis King)** are the
  typed-core entry/flow techniques: parse weak input into strong types once at the boundary; thread
  `Result` through the core's pipeline (Elixir `with`).

## Elixir specifics

- **"Designing Elixir Systems with OTP" (Gray & Tate)** layers: Data, **functional Core** ("plain
  old Elixir modules with functions" — explicitly no GenServer/processes), **Boundary** (GenServer +
  validations + side effects + public API), Lifecycle, Workers.
- **Phoenix Contexts** are the boundary; "never call `Repo` directly from controllers or LiveView."
  Controllers/LiveView/Plug are the shell. (Caveat: contexts are often thin delegators, not a true
  pure core.)
- **Ecto.Changeset** validates/casts/diffs with no DB — a pure decision core.
- **Ecto.Multi** is "a data structure for grouping multiple Repo operations," introspectable via
  `to_list/1`, executed by `Repo.transaction` — the canonical Elixir "effects as data."
- **GenServer-over-Impl:** keep state + transitions in a pure module; `handle_call` delegates. Test
  the pure module with plain calls.
- **Mox / "Mocks and explicit contracts" (José Valim):** define a `@callback` behaviour as the
  contract, inject at the boundary; "mock is a noun, not a verb." Back each with an integration test.

## Over-stated / refuted — read before overriding a default

- **"FC/IS eliminates mocks." → Over-stated.** Mocks disappear *for the core*; they're pushed to the
  shell. A fat (I/O-heavy) shell still needs integration tests or fakes. Honest claim: mocks are
  confined to a thin, rarely-changing layer.
- **"A green core means the system works." → False.** FC/IS **relocates** integration risk, doesn't
  remove it. A heavily-tested core can mask an under-tested shell. Budget shell integration tests.
- **"Always fetch everything up front, then run a pure core." → Not universal.** When the decision
  genuinely needs mid-flow I/O (decide → act → observe → decide), the sandwich breaks. Seemann
  concedes this and falls back to multiple core/shell cycles. Prefer letting the *shell* drive the
  loop and call the core per step; reach for an effects-as-data interpreter only when the loop is
  genuinely complex.
- **"Pull the data into a pure core to decide." → Wrong for set-based / streaming / perf work.**
  Materializing large or streaming datasets in memory discards SQL query planning, indexes, and
  transactional guarantees (e.g. optimistic-concurrency `UPDATE ... WHERE`). Let the database decide
  when the database is the right engine.
- **"Effects-as-data is the clean way." → Only sometimes.** Returning command data pays off with
  multiple, reorderable, or post-processable effects; for a single write it's net-negative ceremony
  over a plain returned value. In Elixir specifically, `Ecto.Multi` is "not meant to be Ecto's
  general interface to transactions" — it's for genuinely interdependent multi-step plans; for
  simple sequences `Repo.transaction`/`Repo.transact` with a function is clearer and less noisy
  (and `Multi.run/3` smuggles effects back into the "declarative" value).
- **"Wrap it in a GenServer." → Anti-pattern for pure logic.** Elixir docs: use processes only for
  runtime properties (concurrency, shared state, fault isolation), never for code organization. A
  process around pure logic convolutes it and serializes it. (But thin holder processes are
  legitimate for expensive state, isolation, or deliberate rate-limiting — don't cargo-cult either
  way.)
- **"Hexagonal/Clean/FC/IS, just add layers." → Over-engineering risk.** These can balloon into
  boilerplate and cross-boundary type conversion. FC/IS is the lighter cousin but inherits the dogma
  risk — combine patterns with judgment; skip them for small projects.

## Key sources

- Bernhardt — *Boundaries* (2012): https://www.destroyallsoftware.com/talks/boundaries ; FC/IS
  screencast: destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell
- Seemann — *Dependency rejection*: https://blog.ploeh.dk/2017/02/02/dependency-rejection/ ;
  *Conditional sandwich example*: https://blog.ploeh.dk/2022/02/14/a-conditional-sandwich-example/
- Wlaschin — *Railway Oriented Programming* & *Against ROP* & *Six approaches to dependency
  injection*: https://fsharpforfunandprofit.com/
- King — *Parse, don't validate*: https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/
- *Functional event sourcing / Decider*: https://thinkbeforecoding.com/post/2021/12/17/functional-event-sourcing-decider
- Gray & Tate — *Designing Elixir Systems with OTP*: https://pragprog.com/titles/jgotp/
- Valim — *Mocks and explicit contracts*: https://dashbit.co/blog/mocks-and-explicit-contracts ;
  Mox: https://github.com/dashbitco/mox
- GenServer testability (Tyler Young): https://tylerayoung.com/2021/09/12/architecting-genservers-for-testability/
- Ecto.Multi docs: https://ecto.hexdocs.pm/Ecto.Multi.html ; *The Case Against Ecto.Multi*:
  https://tomkonidas.com/repo-transact/
- Phoenix Contexts: https://hexdocs.pm/phoenix/contexts.html
- Elixir process anti-patterns: https://hexdocs.pm/elixir/process-anti-patterns.html
- FC/IS testing critique (relocates risk): https://sanchez.ws/functional-core-imperative-shell-and-unit-testing-vs-integration-testing/
- Mid-flow-I/O objection (kbilsted): https://gist.github.com/kbilsted/abdc017858cad68c3e7926b03646554e
- DB query-planning / perf critique (HN): https://news.ycombinator.com/item?id=12605209
- Working Effectively with Legacy Code (seams, characterization): https://understandlegacycode.com/blog/key-points-of-working-effectively-with-legacy-code/

## How to use this file

The skill's defaults *are* these findings. When a situation pushes you to override a default, check
it against the over-stated/refuted section first: skipping FC/IS for set-based DB work or thin glue
is evidence-aligned; forcing a pure core to make I/O-dependent mid-flow decisions, or claiming a
green core means a green system, is not.
