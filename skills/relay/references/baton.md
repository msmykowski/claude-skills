# Baton Manual — Write a Bounded Handoff, Verify It Against the Diff

Transfer working context to a reader who has the code, the diff, and the git history — but not
your head. The handoff (the **baton**) exists to carry exactly what those artifacts cannot say.
Everything else is bloat, and bloat in a handoff is not neutral: the reader starts life buried in
text that crowds out the few lines that mattered.

## The reader

Write for a skilled engineer or agent starting from zero context. They can read code, run tests,
and inspect `git log`. They cannot see why you chose A over B, what you tried and abandoned, or
which green signal is lying. That gap is the baton's entire job.

## The admission filter

For every line, ask: **could the reader discover this cheaply from the code, the diff, or git
log?** If yes, leave it out — let them discover it. If no — a *why*, a dead end, a buried body —
it goes in. History lives in git; the baton is a **delta, not a chronicle**. Never write a baton
by appending to a previous one; write fresh, for this specific reader and their specific next
step.

## Hard budget

**≤150 lines total.** If you're over, cut in this order: World state compresses first (it should
already be near-telegraphic), then Interfaces (pointers, not prose), then Decisions. Cut Warnings
last — they're the section whose absence hurts most.

## Template

```markdown
# Handoff: <one line — where the work stands and what comes next>

## World state            <!-- 5–10 lines. REPLACED each handoff, never grown. -->
- <capability that exists and works now, one line each, present tense>

## Interfaces you'll build on
- `path/to/file.ext:42` — `signature(args) -> return` — <one-line contract>

## Decisions and deviations   <!-- highest-value section -->
- <what was decided or changed vs. the plan/spec> — because <the why the code can't show>
- Tried <X>; abandoned because <reason>. Don't retry it blind.

## Warnings
- <gotcha / fragile spot / deliberate hack> — expires when <condition>.
```

Section guidance:

- **World state** — what exists and works *now*. One line per capability. Present tense, no
  history, no adjectives.
- **Interfaces you'll build on** — `file:line` pointers plus signatures and a one-line contract.
  Never paste function bodies; the reader has the code. Take pointers from the branch tip you are
  handing off, not from memory — post-review fix commits shift line numbers.
- **Decisions and deviations** — every departure from the plan or spec, with its why. Every
  approach tried and abandoned, so the reader doesn't re-walk dead ends. This is where the
  embarrassing stuff goes; the embarrassing stuff is the valuable stuff.
- **Warnings** — fragile spots, deliberate hacks (each with the condition under which it should be
  removed), and lying signals (the flaky test, the stale fixture, the cache that masks bugs).

Never include: narrative ("first I did X, then Y"), a restated spec or plan, test output, pasted
code, or assessments of your own work's quality.

## Verification mode

When asked to *verify* a handoff, you receive the draft baton, the actual diff, and the task
spec/plan. You are an auditor, not an editor: your job is to catch what the next reader would
trip on. Check, in order:

1. **Unsupported claims** — the baton asserts something the diff doesn't support ("retries are
   handled" but no retry code exists). Quote the claim, cite what's missing.
2. **Gaps** — a deviation, hack, or dead end visible in the diff that the baton omits. The
   omitted embarrassing thing is the most common and most damaging handoff failure.
3. **Dead weight** — lines that fail the admission filter (discoverable from code/diff/git).
   Flag them for deletion; the budget exists to protect the reader.

Return exactly this verdict block:

```
VERDICT: pass | fail
UNSUPPORTED: <claim quoted> — <evidence that's missing>     (repeat per finding, or "none")
GAPS: <what the diff shows that the baton omits>            (repeat per finding, or "none")
DEAD WEIGHT: <line(s) to delete and why>                    (repeat per finding, or "none")
```

Any unsupported claim or gap → `fail`. Dead weight alone → `pass`, but the listed trims are
required, not suggestions. After the writer applies fixes, re-check only the changed lines.
