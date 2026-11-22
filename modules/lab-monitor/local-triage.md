# Local triage (optional)

A small local instruct model can read one slice and write a short note before a paid reviewer does. The shipped watcher does not call it. Nothing in the Intro tier uses it.

## When it is allowed

- The Lab Warden has approved the model, the folder it loads from, and a memory limit.
- The machine has memory to spare. Check free memory before loading. Do not evict or starve a model that is already serving.
- Unload the model when the sweep finishes.
- The sweep reads the slice diff only. It does not get secrets, the live checkout, or a network key.

## What the note is worth

The note is advisory. It does not pass or fail the gate in [../claude-code-loop/loop/GATES.md](../claude-code-loop/loop/GATES.md). The CTO may read it during the one review of a piece. The Red Team may use the same limits for a cheap first sweep over a slice, then run the real passes with different models ([../redteam/SLICING.md](../redteam/SLICING.md)).

## What it is not

It is not a trigger. Do not schedule it. Run it, if at all, inside a review that a person or the CTO already started.
