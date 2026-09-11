# Offline architecture survey contract

Write a single HTML file to an OS-provided temporary directory, with a unique name
such as `elixir-architecture-review-<timestamp>-<suffix>.html`. Respect an explicit
user output path or format. Keep the artifact outside the reviewed repository by
default. Use a file-writing API or correct shell quoting for source-derived text.

## Contents

1. **Scope and evidence:** repository/snapshot, relevant versions, inspected area,
   history signal and review limits. Distinguish static reading from executed tests.
2. **Verdict:** the top opportunity, or a clear no-change conclusion.
3. **Ranked candidates:** group symptoms belonging to the same ownership change.
4. **Healthy boundaries:** brief retention notes, not numbered refactor findings.
5. **Next step:** top candidate and why; in report-only mode, finish without asking
   for selection or starting a design interview.

An empty candidate set is a successful report. Do not pad it with speculative
refactors. A small number of well-supported findings is better than a quota.

## Each candidate card

| Field | What the reader needs |
|---|---|
| Domain title and strength | `Strong`, `Worth exploring` or `Speculative`, with a reason for the confidence. |
| Evidence | Actual file paths, inspected symbols/line locations and representative callers/tests. Label unavailable line numbers; do not invent them. |
| Current friction | The knowledge, sequencing or state coordination callers must currently own. |
| Proposed ownership | What responsibility would move behind which domain boundary, in plain language. |
| Deletion test | Where complexity goes when removing the present abstraction and the proposed one. |
| Before / after | Relationships among callers, responsible modules and effects; label calls, messages and transaction/process boundaries accurately. |
| Benefit and tests | What becomes easier to change or verify; which public behavior tests establish it. |
| Cost and uncertainty | Compatibility impact, runtime/transaction tradeoffs, assumptions and ADR conflicts. |

`Strong` requires concrete friction and a credible improvement. `Worth exploring`
means the benefit depends on an unresolved requirement. Include `Speculative` only
when useful to the user's scope; never manufacture it to avoid an empty result.

The survey compares opportunities. Describe future interfaces by their domain
responsibility; reserve exact new signatures, schemas and migration plans for the
candidate the user selects. Existing signatures can be cited as evidence.

## Rendering and delivery

Use inline CSS, system fonts and inline SVG or simple HTML/CSS diagrams. There
must be no CDN, external script, font or image needed to read the report. Ordinary
source links are fine. JavaScript is optional and should not be needed to expose
essential content. Escape code and other source text as text, not executable HTML.

Make cards readable on narrow screens and in print. Use readable text sizes,
sufficient contrast, visible strength labels and text explanations alongside
diagrams. Every candidate needs understandable before/after relationships; a
healthy-boundaries-only report needs no artificial diagram.

Check the saved artifact for correct content, escaped snippets, resolvable local
links where applicable, and absence of required remote assets. When a local
browser/rendering tool is available, inspect the actual rendering and fix clipping
or unreadable diagrams. Otherwise state that visual rendering was not checked.

Return the real absolute path or supported artifact link. If the environment
supports opening local artifacts within current authorization, show it; otherwise
the clickable file link is sufficient. Do not publish or upload source-derived
reports to an external service without the corresponding user request.
