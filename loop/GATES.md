# The gate (G0-G4)

After every slice the watcher runs a **zero-token** gate. Nothing here calls a model.

| Gate | Checks | On failure |
| --- | --- | --- |
| **G0** | Claude exited 0 and its final reply ends with `LOOP: done piece=<this slice>`. `LOOP: blocked` and `LOOP: limit` are honest stops, not failures. | Chain stops (`blocked`). No fix run: a wrong status line means Claude lost the thread. |
| **G1** | The worktree is clean, on the brief's `branch:`, and HEAD is pushed to `origin/<branch>`. | One fix run with the failure text in the prompt. |
| **G2** | At least one new commit since the slice started (waived only on a fix run, where the head may already be right). Every new commit carries `Piece: <slice>`; a wrong trailer is a **warning only** (squash-merge fixes it). | One fix run (missing commit). Trailer: logged only. |
| **G3** | App lines <= `max_changed_lines`, test lines <= `max_test_lines` (counted apart), and every changed non-test file matches a `may_touch:` glob. A brief with no `may_touch:` fails. | One fix run. |
| **G4** | Self-check passes for this exact head. **Partial** on a non-final slice (lint + only the test files the slice touched). **Full** on the final slice or when no test file was touched. A full pass is cached per sha (`state/gate/<sha>.full`) and reused; partial results never are. | One fix run. |

A second failure on the same slice stops the chain and notifies. A stopped chain marks the task hash as
handled; the CTO re-queues by committing a change to the open section (new brief, re-split, or a fix piece).

## Why each gate exists
- **G0** keeps the watcher from guessing: only the model's own explicit status counts.
- **G1** makes "done" mean "on the remote", so the reviewer and CI see exactly what the gate saw.
- **G2** catches runs that talked instead of committing. Trailers are a convenience, so they never block.
- **G3** is the scope fence. Small, declared diffs are what make bot-written code reviewable by a human.
- **G4** keeps test compute proportional: targeted tests while iterating, the full suite once per piece.

## Partial vs full self-check
`LOOP_SELF_CHECK` is one script with two modes (see `self-check.example.sh`):
- `--partial -- <test files>`: lint plus the named test files only. Paths must be test files; flags and `..` are refused.
- `--full`: lint plus the default suite. Slow, environment-bound suites (end-to-end, live services) stay deselected by default, so the loop never needs a live stack.

## Advisory checks (optional, never blocking)
You can add a cheap advisory review after G4 (for example a local model reading only this slice's diff and
writing a short JSON verdict). Keep it advisory: it informs the CTO's final review and never stops the chain.
