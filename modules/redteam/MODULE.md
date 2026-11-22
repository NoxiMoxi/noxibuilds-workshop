# redteam

Adversarial review in slices, so each pass sees a whole surface and the shared core is reviewed once.

## What it adds

- A Red Team persona: findings with severity, place, impact, and the smallest fix.
- [SLICING.md](SLICING.md): seed each surface, expand one hop, review shared core once, stub the core for the surfaces that call it, keep every slice under about 120K tokens.
- `slicer.py`: the same plan for a Python tree (other files join by glob). Standard library only.

## What it needs

- A merged `main` to review. The pass attacks what is about to go live.
- A slice plan from the [codegraph](../codegraph/MODULE.md) Cartographer, or a slice config for `slicer.py`.
- Two or three different models, one per pass. An optional local first sweep uses the limits in [../lab-monitor/local-triage.md](../lab-monitor/local-triage.md).
- A throwaway test stack. The Lab Warden approves it. The pass does not touch the live system.
- [common.md](../claude-code-loop/common.md) appended to the persona.

## What it replaces

One unstructured read of the whole repository before go-live. Slices give each pass a bounded, complete view, and high or critical findings are fixed between passes.

## How a bot enables it

Create the Red Team bot from [red-team.md](red-team.md) plus `common.md` when a go-live is real, not on day one. The CTO (or the user) starts a pass by sending the slice plan. The bot wakes for that message. Do not put it on a timer, and do not wake it on every pull request.

## How to turn it off

Do not start another pass. Retire the Red Team bot. Keep the finding notes in the scratch folder the Lab Warden approved, or delete that folder if the user wants it gone. The slicer is a local script; removing the bot does not uninstall anything else.

## Files

- [red-team.md](red-team.md) — persona
- [SLICING.md](SLICING.md) — method
- [slicer.py](slicer.py) — Python slicer
- [example-config.json](example-config.json) — example surface config

## Changelog

- 2026-11-22: Moved here from `redteam/` and `bots/red-team.md`.
