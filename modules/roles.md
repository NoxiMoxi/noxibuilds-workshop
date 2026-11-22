# Advanced bot roles

The Intro tier is the starting point (`GROKBOT.md` at the kit root). The roles below belong to the optional modules. Turn one on only when its `MODULE.md` says you need it.

Each file is a persona any assistant can adopt (paste it as standing instructions, or load it as a skill). Every advanced bot also follows [`claude-code-loop/common.md`](claude-code-loop/common.md).

| Role | File | One-line job |
| --- | --- | --- |
| Setup Guide (advanced) | [claude-code-loop/setup-guide.md](claude-code-loop/setup-guide.md) | Walks the local-loop setup one checked step at a time |
| CTO | [claude-code-loop/cto.md](claude-code-loop/cto.md) | Turns journeys into small briefs, runs the loop, reviews, deploys after merge |
| Cartographer | [codegraph/cartographer.md](codegraph/cartographer.md) | Maps the code: route and page inventory, red-team slices |
| Journey Keeper | [journey-keeper/journey-keeper.md](journey-keeper/journey-keeper.md) | Guards `journey.md`; PASS or FAIL on specs and inventories |
| Lab Warden | [lab-monitor/lab-warden.md](lab-monitor/lab-warden.md) | Owns the machine: layout, services, ports, loop installs |
| Red Team | [redteam/red-team.md](redteam/red-team.md) | Adversarial review in sliced passes, core reviewed once |

The human owner writes the journeys, answers kept-or-dropped questions, merges, and approves anything public.

## Message flow
- The owner and the CTO are the main channel. Other bots reach the owner through the CTO's batched card, except the Lab Warden for machine emergencies and the Journey Keeper when recording the owner's own words.
- Bot-to-bot messages are asynchronous. Set "priority" only when the recipient must act or is blocked.
