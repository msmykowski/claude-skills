# Phoenix, Ecto, LiveView and jobs

Apply only the sections supported by the project's dependencies and conventions.
Read the locked versions; examples in current online docs may use newer APIs.
An Ash project or another domain framework needs its own established action and
authorization boundaries respected, not a parallel Ecto service layer imposed.

## Phoenix contexts and entrypoints

Trace the same operation from controllers, LiveViews, workers and other callers.
Domain ownership is weak when each caller rebuilds eligibility checks, transaction
ordering and side-effect policy. A context's public domain operation can own that
coordination, including authorization scope or tenant checks required across all
entrypoints. Transport authentication alone does not cover jobs and internal calls.

Keep request decoding, rendering and socket-specific presentation in the web
layer. UI validation can give immediate feedback while the domain operation
rechecks authoritative invariants. Contexts can group related schemas; they are
not mechanically one context per table. Cross-context reads and reporting queries
may be intentional—look for ownership leaks, cycles and change coupling rather
than declaring every shared schema or Repo reference a defect.

Source: [Phoenix contexts](https://hexdocs.pm/phoenix/contexts.html).

## Ecto data and transaction ownership

Identify the operation that owns atomicity. Keep query construction and preloading
where their domain meaning is understood; explicit composable queries can remain
useful internal modules. Returning a changeset for form errors or a schema for
domain data may be appropriate. Record required preloads and persistence semantics
when consumers depend on them instead of wrapping these values automatically.

Ecto.Multi is useful for named/composed transaction steps; ordinary transactional
control flow may be simpler for a fixed operation. Use the transaction API supported
by the project's Ecto version. Do not introduce Multi just to increase abstraction,
or replace Ecto.Repo with a generic repository solely to mock local SQL calls.

Changeset validation is not a substitute for database constraints under competing
writes. Review the actual constraint and the operation's locking, conditional
update or idempotency strategy where concurrency affects correctness. A constraint
annotation on a changeset does not itself create a database constraint.

A SQL rollback cannot undo a payment, email or PubSub notification. Moving an
external call outside the transaction also leaves a partial-failure window. Name
which state represents an accepted, completed or uncertain operation. Choose
provider idempotency, reconciliation, compensation or a persisted delivery/outbox
mechanism according to the required guarantee; do not assume all applications
need every mechanism. Publishing after commit prevents rollback-time visibility,
but alone does not guarantee delivery across a crash after commit.

Sources: [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html),
[Ecto.Repo transactions](https://hexdocs.pm/ecto/Ecto.Repo.html),
[database constraints](https://hexdocs.pm/ecto/Ecto.Changeset.html#unique_constraint/3).

## LiveView state and asynchronous work

Distinguish transient UI state from authoritative domain state and durable work.
A large LiveView may need a domain operation extracted, a cohesive presentation
component, or clearer async ownership; its line count alone does not select one.
LiveComponents are presentation/state tools, not automatic domain boundaries.

Trace subscription setup, reconnect behavior and result identity. Look for stale
results after an input/selection changes, overlapping tasks and events discarded
during loading. A successful async helper extraction should hide repeated
lifecycle coordination without making its callers reconstruct that coordination.

Use the installed LiveView async facilities where their lifetimes and semantics
fit. Determine what happens to work on navigation, including nested Tasks or
external jobs. Domain work that must outlive the page needs an appropriate owner.
Pass needed values into async closures, rather than capturing the entire socket.

Source: [LiveView async operations](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-async-operations).

## Oban and durable workflows

A worker can translate job arguments into a domain operation and map its results
to the existing retry/cancel/discard policy. An operation already owned by a
cohesive worker does not need a context wrapper merely for symmetry.

Separate job admission from execution and business-effect idempotency. Oban job
uniqueness is not a general exactly-once guarantee or per-resource execution lock.
Check configured engine, uniqueness fields/states/period and actual database
invariants. Queue concurrency is another independent concern.

If recording domain state and enqueuing a job must be atomic, inspect the actual
Repo, transaction connection and supported Oban integration. A network effect
performed by the job remains outside that database atomicity. Retries should use
the same business operation identity when required, and distinguish known failure
from unknown external outcome.

Source: [Oban unique jobs](https://hexdocs.pm/oban/unique_jobs.html).

## Example of the design question, after candidate selection

Suppose a controller, LiveView and worker each validate a draft, reserve stock,
charge a provider and write a purchase. Compare a synchronous context operation
with a durable submission/status operation. Decide the required lifetime and
response contract before choosing public functions. If acknowledgment changes
from “paid” to “queued,” record that consumer-visible behavior change explicitly.
The smaller interface is valuable only if the chosen owner also handles scope,
concurrency, transaction boundaries and ambiguous payment outcomes.
