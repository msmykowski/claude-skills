# OTP runtime boundaries

Read this when the scoped operation uses processes, Tasks, messages, ETS or other
stateful runtime infrastructure. Map the call graph and the process graph
separately: several modules can execute inside one process, and one module can
run in many processes.

## Decide what the process owns

Name its runtime purpose: shared state, exclusive resource access, concurrency,
isolation or lifecycle. A GenServer created only to organize pure code adds message
passing and often serialization. A thin public function wrapping GenServer.call
can nevertheless be a valuable interface: it hides names, message shapes and
runtime guarantees. Judge the whole contract.

Identify the state authority, including what is lost on process or node failure.
Supervision restarts processes; it does not reconstruct business state or undo
effects. ETS ownership/heirs and registry scope matter when they affect recovery.
Node-local names or tables do not establish cluster-wide uniqueness.

See [process anti-patterns](https://hexdocs.pm/elixir/process-anti-patterns.html)
and [GenServer client APIs](https://hexdocs.pm/elixir/GenServer.html#module-client-server-apis).

## Follow work through its full lifetime

For each asynchronous operation, make the review answer these questions:

| Event | Required architectural question |
|---|---|
| Work starts | Who admits it, tracks it and enforces the concurrency limit? |
| Caller exits or navigates away | Should work stop or survive? Who owns that decision? |
| Worker crashes | Who receives the failure and releases or recovers the operation? |
| Wait expires | Is work still running? Is its outcome unknown? |
| Owner restarts | Can an old worker continue or send a result to a replacement process? |
| Request is retried | What prevents a second business effect? What scope/lifetime does deduplication cover? |
| Work completes | Which identity proves this result belongs to the current operation? |

**A call timeout is not cancellation.** Retrying after a timeout can overlap the
original operation. Killing a worker also does not establish that its remote or
physical effect never occurred. Distinguish rejection, acceptance, completion and
unknown outcome before proposing retry policy.

When old results can overlap new work, consider owner PID, request identity,
monitor reference or generation as appropriate. Sending to a registered name may
reach a replacement process. Monitor and result handling must agree on which
operation they release. Do not reset a busy flag merely because a caller stopped
waiting while the underlying work can still mutate state.

Trace Task links and supervision explicitly. `Task.async` links to its caller;
`async_nolink` changes that relationship and requires deliberate result/failure
handling. Supervised work does not automatically die with its requesting process.
Choose topology based on the required lifetime, not a blanket “supervise it” fix.
See [Task.Supervisor](https://hexdocs.pm/elixir/Task.Supervisor.html).

## Capacity and recovery are part of the interface

Review bounded concurrency, queue growth, overload response and cancellation
ownership when callers depend on them. If a stream is involved, trace where it is
enumerated and how partial results and task exits are handled. A named GenServer
can intentionally serialize a resource; increasing concurrency can violate that
contract. A mailbox is not an unlimited work queue with free memory.

Keep only needed values in closures and messages; copying a full socket or large
state to a Task can create unnecessary cost. Establish actual data volume before
calling it a performance defect.

For effects that survive process failure, propose recovery in terms of what the
system can actually observe: operation status, durable intent, reconciliation or
operator intervention. Persistence alone cannot provide exactly-once effects at
a remote system that offers no deduplication or status mechanism. State the
availability/correctness tradeoff when uncertainty must block new work.

Design tests around controlled execution and failure boundaries; use the process
testing guidance in [testing seams](testing-seams.md). Pure transition tests alone
cannot verify links, monitors, restart behavior or message delivery.
