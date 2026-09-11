# Behavioral testing at useful seams

The report proposes verification; it does not claim tests ran. When implementation
is requested, use the project's test conventions and run focused checks for the
changed behavior. Formatting, Dialyzer and Credo are useful when configured, but
passing them does not establish sound ownership or transaction semantics.

## Match the test boundary to the guarantee

| Guarantee | Useful verification |
|---|---|
| Pure domain rule | Direct public function tests using real values; property tests when invariants justify them. |
| Context persistence/authorization | Call the context against the real test database; assert scoped results, constraints and rollback outcomes. |
| External-provider translation | A controllable provider substitute plus focused adapter/contract checks where practical. |
| GenServer lifecycle | Start the real process, drive its client API, control its dependency and observe completion/failure. |
| LiveView behavior | User events and rendered outcomes through LiveViewTest; wait on supported async completion helpers. |
| Durable job semantics | Test enqueueing, worker outcomes and relevant retry/idempotency behavior using the installed Oban testing facilities. |

Keep useful tests of cohesive pure modules. Add the orchestration test when bugs
live between steps; do not delete unit tests wholesale in the name of depth. When
replacing a brittle test, preserve its meaningful behavior coverage before removing
its dependence on private helper calls, callback tuples or internal state layout.

## SQL Sandbox and process lifetime

The SQL Sandbox connection belongs to an owner process. A spawned process needs
appropriate access through supported caller tracking or explicit allowances.
Inspect the project's DataCase and sandbox setup rather than copying boilerplate.
Shared mode prevents normal concurrent test isolation; choose it deliberately.
Ensure database-using workers finish or stop before the sandbox owner exits.

Do not infer production concurrency correctness from two workers sharing one
sandbox connection. When independent transactions or uniqueness races matter, use
a test arrangement that actually supplies those conditions and document its setup.

Source: [SQL Sandbox ownership and shared mode](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html).

## Mox and dependency configuration

Mox expectations are process-owned. Give collaborating processes the supported
allowance/caller relationship, and synchronize their completion before verifying
expectations. Global application environment changes in per-test setup can race
with async tests. Prefer stable test-environment configuration with process-local
expectations, or an existing explicit injection mechanism. If a test must mutate
global configuration, restore it and isolate it appropriately.

Use behaviours where they define a meaningful external contract. Mocking Repo or
every internal module often verifies wiring while skipping the database and rules
the interface is supposed to own. A provider fake that can accept an effect and
then lose its reply can reveal bugs a simple `{:error, :timeout}` stub misses.

Source: [Mox, including multi-process collaboration](https://hexdocs.pm/mox/Mox.html).

## Deterministic process tests

Use supervised test processes where appropriate, unique names or unnamed instances,
and explicit messages/monitors/barriers to establish ordering. `Process.sleep/1`
does not prove another process completed. A synchronous client call is only a
barrier for the work its contract actually waits for.

Select failure cases from the real contract: worker crash, owner restart, caller
death, late completion, timeout with work still running, or duplicate submission.
Assert business effects and observable lifecycle outcomes. Directly calling
`handle_info/2` can test a transition but cannot establish the running system's
mailbox, supervision or failure behavior.

Sources: [ExUnit supervised processes](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#start_supervised/2),
[LiveView async testing](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-testing-async-operations).
