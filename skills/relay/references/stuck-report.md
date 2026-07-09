# Stuck-report format

Written to `.relay/<run-id>/stuck-report.md` when a leg fails twice. The reader is a human
deciding what to do next — write for that decision, not as a log.

```markdown
# Stuck: <run-id> — leg <n> (<leg title>)

## What this run was building
<two sentences: the problem, and how far the race got — legs done / legs remaining>

## Where it stopped
Leg <n>, phase <phase from the failure report>. <One sentence on the obstacle.>

## Attempt 1 (original plan)
Approach: <what the leg tried>
Evidence: <the trimmed errors/output that ended it>

## Attempt 2 (after re-plan)
What the re-plan changed: <how the second attempt differed>
Evidence: <the trimmed errors/output that ended it>

## Hypothesis
<best root-cause guess, and what evidence would confirm or kill it>

## Your options
1. <option> — <tradeoff>
2. <option> — <tradeoff>
3. <option> — <tradeoff>

## State of the stack
<which branches/PRs are complete and sound (safe to review/merge bottom-up), which are
abandoned; where the run directory is>
```

Both attempt sections quote the implement-slice failure reports (or, for baton-verification
failures, the stand-in verdict blocks) — don't re-summarize evidence into vagueness. Options must
be genuinely different decisions (re-cut differently, change the approach, drop the feature, do it
manually), not three phrasings of "try again".
