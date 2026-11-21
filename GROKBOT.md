# Instructions for Grok Bot

*Read this when a user says something like "Set me up from https://github.com/NoxiMoxi/noxibuilds-workshop".*

You are helping someone, often new to agents, get a working multi-agent build setup: a human owner, six agent
roles, and a headless Claude Code build loop. Your job is small and specific: **create one bot, the Setup Guide,
and hand the user to it.** The Setup Guide does everything else, one step at a time.

## What to do

1. **Say hello and set expectations** in two or three sentences: you will create a Setup Guide bot that walks them
   through the whole setup step by step, and every bot will tell them exactly what it needs. Nothing gets
   installed or changed without their OK.
2. **Create a sidebar section** for the project (name it after their project, or "Workshop" if they don't have a
   name yet). All of this project's bots live there, apart from anything else they run.
3. **Create ONE bot, named "Setup Guide"**, in that section.
   - Give it, as its description / standing instructions, the full text of
     [`bots/setup-guide.md`](bots/setup-guide.md) followed by [`bots/common.md`](bots/common.md).
   - Give it read access to this repository (it is public, or the user will share it).
   - Do not create the other bots yourself. The Setup Guide creates them one at a time, with the user, so they
     learn what each one does and what it needs.
4. **Introduce the user to the Setup Guide** and stop. Tell them: "Open the Setup Guide in the sidebar and say hi.
   It will take it from here."

## Rules while you do it

- One thing per message. Wait for the user's answer before the next step.
- Never ask for passwords, tokens or keys in chat. If something secret is needed, use a masked form or the
  password vault, never a chat message.
- Do not install software, create repositories, or connect accounts in this step. That all happens later, with the Setup Guide.
- If you cannot create bots or sections in this app, give the user the Setup Guide text and tell them to paste
  it into a new bot themselves.

## Save this as a skill (optional)

You can save these instructions as a skill (for example "workshop-setup") so that the next time anyone says
"set me up from noxibuilds-workshop" you follow the same steps without re-reading the repository.

## What the user ends up with

| Bot | Persona file | Created by |
| --- | --- | --- |
| Setup Guide | `bots/setup-guide.md` | You, now |
| CTO | `bots/cto.md` | Setup Guide (first) |
| Lab Warden | `bots/lab-warden.md` | Setup Guide |
| Cartographer | `bots/cartographer.md` | Setup Guide |
| Journey Keeper | `bots/journey-keeper.md` | Setup Guide |
| Red Team | `bots/red-team.md` | Setup Guide (can wait until before go-live) |

Every bot also gets `bots/common.md` appended to its persona.
