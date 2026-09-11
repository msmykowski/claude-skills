# Elixir module and context design

## Organize around knowledge and invariants

A useful domain interface owns a coherent operation: accepting an order, planning
an import or issuing an invitation. Callers should not need to reproduce its
validation sequence, state transitions, persistence ordering or error translation.
Look for repeated coordination, not merely repeated syntax.

A context can expose several related operations and contain private helpers,
schemas, query modules and other focused modules. Deepening need not create one
large source file. Splitting by CRUD verb, table, callback or arbitrary line count
can scatter one rule. Conversely, unrelated operations do not belong together
just because they use the same Repo or schema.

Distinguish an Elixir namespace from an enforced architectural boundary:

- `defp` limits function calls to the defining module. A nested name such as
  `MyApp.Orders.Pricing` is still an independent module.
- `@moduledoc false` hides documentation; public functions remain callable.
- Structs intentionally expose data for construction and pattern matching.
  `@opaque` communicates a representation contract to analysis tools; it is not
  runtime access control. Typespecs do not replace input validation.
- Umbrella applications create application/dependency structure, not automatic
  privacy for every module. Justify them through ownership, lifecycle or existing
  project needs, rather than using them as folders.

When callers bypass an intended interface, describe the specific dependency and
why it hurts. Use existing boundary checks if installed. A new enforcement tool
is an optional proposal with cost, not a prerequisite for a sound design.

See [Kernel.defp](https://hexdocs.pm/elixir/Kernel.html#defp/2),
[module documentation](https://hexdocs.pm/elixir/Module.html#module-moduledoc) and
[typespecs](https://hexdocs.pm/elixir/typespecs.html).

## Choose the smallest useful abstraction

| Evidence | Usually appropriate |
|---|---|
| Cohesive calculation or transformation | Ordinary functions; keep useful pure modules. |
| Related steps repeat across callers | One domain operation owning their coordination. |
| Real runtime state, resource serialization or failure isolation | Evaluate an OTP process and its lifecycle separately from module organization. |
| Interchangeable provider or infrastructure implementations | A small behaviour at that dependency seam, or a function argument when sufficient. |
| Dispatch should follow the type of a data value | A protocol, if the polymorphism is actually needed. |
| Repeated compile-time syntax that functions cannot express well | Consider a macro with its expansion and compile dependency costs. |

One production provider plus a meaningful test substitute can justify an external
I/O seam. Do not require two production providers. Equally, do not wrap every
internal module in a behaviour to mock it. Identify what varies and which tests
need that variation. Use the existing project's dependency-selection convention;
avoid passing a dependency bag through every domain call.

Protocols are data-type dispatch; behaviours are module contracts. Neither is
Elixir's replacement for a class hierarchy. See
[Protocol](https://hexdocs.pm/elixir/Protocol.html) and
[Mox's explicit contracts](https://hexdocs.pm/mox/Mox.html).

## Make function contracts carry the right information

Use domain-shaped inputs and result values, conventional tagged tuples when
appropriate, and explicit expected failures. Preserve established bang/non-bang
semantics. Pattern matching and guards can make cases clear; a long `with` whose
`else` cannot distinguish failure origins may need local error normalization.
Do not rescue all failures into an undifferentiated error that hides a defect.

Fewer arguments are not automatically a simpler contract. A map of unrelated flags
can hide more obligations than explicit arguments. Returning Ecto schemas or
changesets can be the intended interface; do not add DTOs reflexively. Review
which fields, loaded associations and error details consumers actually rely on.

Configuration is also part of the interface. Distinguish runtime reads from values
captured at compile time. Prefer functions over macros when no compile-time
capability is needed; inspect `use`, `require`, struct expansion and callbacks when
compile coupling is the actual friction. Use the installed Mix version's xref
options, and label graph evidence as compile, export or runtime dependencies.

Sources: [design anti-patterns](https://hexdocs.pm/elixir/design-anti-patterns.html),
[code anti-patterns](https://hexdocs.pm/elixir/code-anti-patterns.html),
[Mix xref](https://hexdocs.pm/mix/Mix.Tasks.Xref.html).

## Counterexamples that protect good code

- Keep a stable `defdelegate` facade when it shields consumers from internal
  names or preserves compatibility. Its size is not its value.
- Keep a pure parser, validator or pricing engine when it owns a coherent rule.
  Its direct tests can be useful alongside tests of the surrounding operation.
- Keep process isolation and deliberate serialization when they satisfy runtime
  requirements; module consolidation is not a reason to remove either.
- Keep a public struct when client construction and pattern matching are intended.
- A bug or flaky test alone does not prove the module boundary needs changing.

For a runnable illustration of private helpers behind one pure domain operation,
read [reservations.exs](reservations.exs). It deliberately makes no claim about
concurrent or durable inventory ownership.
