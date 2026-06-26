---
name: functional-core-imperative-shell
description: >-
  Use when writing or restructuring code that mixes decisions with side effects — pull the
  decision-making into a pure functional core and push I/O (DB, network, time, randomness, logging)
  out to a thin imperative shell. Trigger whenever the user asks to write a feature/module/service
  that touches a database, API, queue, or filesystem and also has real business logic; whenever they
  say code is "hard to test", "needs the DB to test", "mocks everything", is a "god function", or
  mixes logic and I/O; whenever they ask to separate pure logic from side effects, make a GenServer
  testable, or structure a Phoenix context / Ecto write path cleanly; or whenever they mention
  "functional core imperative shell", FC/IS, "decide then act", "impureim sandwich", hexagonal /
  ports-and-adapters, or "dependency rejection". Elixir-first (Ecto, Phoenix contexts, GenServer,
  with), but the principles apply to any language. Don't use for pure-algorithm work with no I/O,
  thin CRUD/glue with no real decisions, or performance-critical set-based/streaming data work where
  the database or a stream should make the decisions.
---

# Functional Core, Imperative Shell

Separate the code that **decides** from the code that **acts**. Decisions — business rules,
validation, calculations, state transitions — go in a **functional core** of pure functions: data
in, data out, no I/O. Everything impure — database, network, queues, the clock, randomness, UUIDs,
logging — lives in a thin **imperative shell** that wraps the core.

The one directional rule that makes it work: **the shell calls the core; the core never calls the
shell and doesn't know it exists.** A pure function that calls an impure one becomes impure, so the
core can't reach outward — impurity has to be lifted out to the edges. That single constraint is
what buys the payoff: the core is deterministic, so you test it with plain input/output assertions
and *no test doubles*, and the shell shrinks to straight-line glue with few branches.

This skill decides *how to structure* code (new or existing). It is Elixir-first in its examples,
but the shape is language-agnostic.

## The shape: fetch → decide → act

Most flows fit an **impureim sandwich** (Seemann): impure *gather*, pure *decide*, impure *act*.

```elixir
def renew_subscription(id, now) do
  sub = Repo.get!(Subscription, id)                 # 1. fetch (shell / impure)
  case Billing.renew(sub, now) do                   # 2. decide (core / pure)
    {:charge, amount, next_period} ->               #    core returns a decision as DATA
      with {:ok, _} <- PaymentGateway.charge(sub.customer_id, amount),   # 3. act (shell)
           {:ok, sub} <- Repo.update(Subscription.extend(sub, next_period)) do
        {:ok, sub}
      end
    {:skip, reason} -> {:ok, sub, reason}
    {:past_due} -> Repo.update(Subscription.mark_past_due(sub))
  end
end
```

`Billing.renew/2` takes plain data (a struct + the current time passed *in*) and returns a plain
decision. It can be unit-tested across every branch — active, expired, loyalty discount, charge
declined — with no database, no payment sandbox, no mocking. The shell does the I/O the decision
calls for.

## Writing new code

1. **Name the decisions and the effects separately.** Decisions: given inputs, what *should*
   happen? Effects: what touches the outside world (DB, HTTP, time, random, log, publish)? The list
   of effects tells you what the shell must gather up front and perform at the end.
2. **Gather inputs in the shell, before the core runs.** The core can't fetch, so the shell loads
   the rows/records/config the decision needs and passes them in as values.
3. **Make the core return the decision, not a predicate the shell branches on.** This is the
   sharpest tell of a real functional core. The core should return the *outcome itself* as data — a
   tagged command like `{:charge, amount}` / `{:skip, reason}` / `{:past_due}`, a changeset, or a
   list of events — and the shell should only *dispatch* on it (`case decision do ... end`,
   performing the matching effect). If instead the core exposes a boolean (`renewable?/1`,
   `payable?/1`) and the shell writes `if core.renewable?(x), do: charge(), else: skip()`, then the
   *decision still lives in the shell* — that's an anemic core wearing a pure-function costume, and
   the branch you most want to unit-test is back in the untestable layer. Push the whole branch
   into the core; let the shell carry out a verdict it didn't make. Pattern-match and `case` keep
   the core's branching pure; `with` sequences happy-path steps and short-circuits on error.
4. **Perform the effects in the shell** based on what the core returned. Keep this layer thin — it
   should read like a list of actions, not contain business logic.
5. **Pass impurity in as data, never reach for it in the core.** Time, randomness, UUIDs, the
   current user, and config are *inputs* the shell supplies (`now`, a seed, `actor`). A core that
   calls `DateTime.utc_now/0` or `Ecto.UUID.generate/0` is no longer deterministic and loses the
   property that makes it cheap to test.

## Refactoring tangled code into core + shell

When logic and I/O are already interleaved (the classic "this function needs the DB and mocks the
HTTP client to test"):

1. **Characterize first, and preserve behavior exactly.** Before moving anything, pin current
   behavior with characterization tests (snapshot what it *does*, bugs and all). They're the oracle
   that proves the refactor changed nothing. A restructure is *not* a license to fix bugs: if
   pulling the logic into a pure core makes a latent bug obvious (a missing transaction, an
   off-by-one, an unhandled case), **surface it but don't fix it in the same change** — note it for
   a separate, behavior-changing commit. Quietly "improving" behavior mid-refactor is exactly how
   refactors smuggle in regressions, and it defeats the characterization tests you just wrote. (See
   the [[decompose]] skill on splitting behavior changes out from restructures.)
2. **Find the seam** between gather, decide, and act in the existing function.
3. **Extract the decision into a new pure module** that takes data and returns data (or a command).
   Move the calculations and branching there; leave the `Repo`/HTTP/`Logger`/clock calls behind.
4. **Hoist the effects outward** — fetch before the pure call, act after it — so the shell brackets
   the core.
5. **Repeat**, growing the core and shrinking the shell until the shell is thin orchestration.

## Elixir idioms

- **Keep the core in plain modules and structs — not processes.** Wrapping pure logic in a GenServer
  "for organization" is a documented Elixir anti-pattern: processes model *runtime* concerns
  (concurrency, shared mutable state, fault isolation), code organization is done with modules and
  functions. A core in a process is also a serialization bottleneck.
- **GenServer as a thin shell over a pure `Impl` module.** Put the state struct and its transition
  functions in `RateLimiter.Core` (pure: `state -> {decision, state}`); have the `RateLimiter`
  GenServer's `handle_call/3` delegate to it. Test the core exhaustively with plain calls; test the
  process only for wiring and timer behavior — don't start a process and `sleep` to test math.
- **`Ecto.Changeset` is a pure decision core.** `cast/4` + `validate_*` cast, validate, and compute
  the diff with *no database*. Build and validate changesets in pure code; hand them to `Repo.*`
  only at the shell.
- **`Repo` lives at the edge.** Never call `Repo` from a controller, LiveView, or the core — route
  DB access through context/boundary functions. Phoenix contexts are the boundary; controllers and
  LiveView are shell.
- **Effects-as-data, in moderation.** `Ecto.Multi` is a value that *describes* a transaction and is
  run later by `Repo.transaction` — a clean decide-then-act when a write genuinely has multiple
  interdependent steps. For a single write or a simple sequence, a plain returned value the shell
  persists (or `with` inside `Repo.transaction`) is clearer; `Multi` adds real noise (and its
  `run/3` callbacks smuggle effects back in). Reach for command/effect data when effects are
  *multiple, reorderable, or need inspecting* — not by default.
- **Testing the boundary: mock as a noun, via a behaviour.** When the shell calls an external
  service, define a `@callback` behaviour as the contract and inject the implementation
  (`Application.get_env`/Mox). The pure core needs none of this. Back every mock-based test with one
  real integration test.

## When NOT to reach for it

This is a default for code that *has decisions worth isolating*, not a universal law. Skip or soften
it when:

- **It's thin CRUD, glue, or a one-off script** — mostly I/O with trivial logic. There's no core to
  extract; the indirection is pure ceremony. If you already have a thin imperative shell and no real
  logic, leave it and write integration tests.
- **The database or a stream should make the decision.** Set-based SQL (filters, aggregates,
  optimistic-concurrency `UPDATE ... WHERE`), large result sets, and streaming/perf-sensitive paths
  are *worse* if you pull everything into memory for a pure core — you'd discard query planning,
  indexes, and transactional guarantees. Let the engine that's good at it decide.
- **The decision genuinely needs mid-flow I/O** (decide → act → observe → decide, where the next
  step depends on a result you can't fetch up front). Don't force a fetch-everything sandwich.
  Prefer letting the *shell* drive the loop and call the core per step; escalate to effects-as-data
  only when that loop is genuinely complex.

And remember the honest limit: **a green core is not a green system.** FC/IS relocates integration
risk to the shell, it doesn't delete it. Budget real integration tests for the shell, especially
when it's fat.

## Anti-patterns

- **Leaky core** — a `Repo`/HTTP/`DateTime.utc_now` call hiding inside the "pure" module. It's no
  longer pure; the test-without-doubles property is gone.
- **Anemic core / predicate-in-shell** — the core only answers *questions* (`valid?`, `payable?`,
  `eligible?`) and the shell makes the *decision* by branching on the answer. The decision — the
  thing worth testing — never left the shell. Have the core return the verdict as a tagged command
  and let the shell merely dispatch on it.
- **Logic in the shell** — `if`/`case` business branching in the controller/GenServer/handler. The
  shell should read like a list of actions; branching belongs in the core.
- **Process-as-namespace** — a GenServer wrapping pure logic for organization. Use a module.
- **Effects-as-data everywhere** — a command/interpreter layer for a path that does one write.
  Ceremony. Reach for it only with multiple/heterogeneous/reorderable effects.
- **Ambient impurity** — the core reading the clock, RNG, env, or current user instead of receiving
  them as arguments. Kills determinism.

## Quick checklist

- [ ] Decisions and effects are named separately; the core holds the decisions
- [ ] The core *returns* the decision as a tagged command; the shell only dispatches on it (no `if core.valid?` branching in the shell)
- [ ] Core functions are pure: data in, data out, no I/O — and time/random/uuid/user passed *in*
- [ ] Shell follows fetch → decide → act; it reads like orchestration, not business logic
- [ ] Core is tested with plain assertions and no test doubles; branches covered
- [ ] The shell has integration tests (a green core is not a green system)
- [ ] In Elixir: core in modules/structs not processes; `Repo` at the edge; changeset built pure
- [ ] Effects-as-data (`Multi`/commands) used only where multiple interdependent effects justify it
- [ ] Confirmed FC/IS is even warranted (not thin CRUD, not set-based/streaming DB work)
- [ ] If refactoring: behavior preserved exactly; any latent bug surfaced separately, not fixed inline

See `references/evidence.md` for the cited sources behind these defaults and the claims that were
**over-stated or refuted** — read it before overriding a default, so you override the dogma and not
the evidence.
