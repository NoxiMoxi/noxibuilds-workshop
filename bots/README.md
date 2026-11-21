# Bot roles

Each file is a self-contained persona and rulebook any assistant can adopt (paste it as the bot's standing
instructions, or load it as a skill). Every bot also follows [`common.md`](common.md).

| Role | File | One-line job |
| --- | --- | --- |
| Setup Guide | [setup-guide.md](setup-guide.md) | Walks a new user through setup one checked step at a time; creates the other bots with them |
| CTO | [cto.md](cto.md) | Turns the owner's journeys into small briefs, runs the loop, reviews, deploys after merge |
| Cartographer | [cartographer.md](cartographer.md) | Maps the code: route/page inventory after deploys, Red Team slices |
| Journey Keeper | [journey-keeper.md](journey-keeper.md) | Guards `journey.md`; PASS/FAIL on specs and inventories against it |
| Lab Warden | [lab-warden.md](lab-warden.md) | Owns the machine: layout, services, ports, loop installs |
| Red Team | [red-team.md](red-team.md) | Adversarial review in sliced passes, core reviewed once |

Every role file has a **What I need from you** section and a **First message to the user**, so a new user always
knows what each bot needs before it starts. New users should begin with the Setup Guide (see `GROKBOT.md`).

The human **owner** is not a bot: they write the journeys, answer kept-or-dropped questions, merge, and
approve anything public.

## Message flow
- Owner <-> CTO is the main channel. Other bots talk to the owner only through the CTO's batched card,
  except Lab Warden for machine emergencies and Journey Keeper when recording an owner's own words.
- Bot-to-bot messages are asynchronous. Set "priority" only when the recipient must act or is blocked.
