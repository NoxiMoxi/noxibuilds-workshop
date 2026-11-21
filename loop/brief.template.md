# <slice id>: <short title> [tier: feature]

piece: <piece id>
slice: <slice id>
branch: task/<piece id>-<slug>
final: no                      # yes on the last slice of the piece (runs the full self-check)
max_changed_lines: 120         # app lines (tests counted separately)
max_test_lines: 60

may_touch:
  - src/<module>/<file>        # one glob per line; `# why` comments are allowed
  - src/<module>/<other file>

## Goal
One or two sentences: what changes for the user when this slice lands.

## Journey (owner's words, verbatim)
> Quote the exact line(s) from docs/brain/journey.md this slice serves, with commit and line: `journey.md <sha> :<line>`.

## Kept or dropped
Every existing behavior this slice removes or changes, each with the owner's answer:
- <behavior> - KEPT / DROPPED (owner, <date>, `journey.md <sha> :<line>` or the decision card)
Write `none` if nothing existing changes. Never queue a brief with an unanswered item here.

## Context
Exact files and line ranges to read (`path:start-end`), and the one or two facts Claude needs. No essays.

## Ask
Numbered, concrete steps.

## Rules
- What NOT to do (files, behaviors, shortcuts).
- If the work needs files outside may_touch, stop with `LOOP: blocked needs <file> because <why>`.

## Done looks like (acceptance)
- Observable results, each checkable from the diff, the tests, or the gate.
- Self-check passes on the new head (partial on a non-final slice, full when `final: yes`).
- New commits carry `Piece: <slice id>`; draft PR pushed to the branch.
- Ends with `LOOP: done piece=<slice id>`.
