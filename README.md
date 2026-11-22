# Workshop Intro

[![checks](https://github.com/NoxiMoxi/noxibuilds-workshop/actions/workflows/checks.yml/badge.svg)](https://github.com/NoxiMoxi/noxibuilds-workshop/actions/workflows/checks.yml)

Point a Grok Bot at this repo and it will set up a small website team: you ask for a change, the bots shepherd a pull request until it is ready with a preview link, you press Merge, and the change shows on your live site.

When one wish no longer fits one change, the optional modules are the next step: [modules/README.md](modules/README.md).

## What you need

1. One paid plan, [The X Subscription](https://docs.x.ai/x-subscription/pricing), at Premium or higher. The bots, their wake-ups, and the cloud coding agents that open pull requests all run on it. Free and Plus ($8 a month) include neither. Premium ($30 a month) is the minimum that includes Grok Bot and Cursor Cloud Agents. Super and Ultra include both, with a bigger weekly allowance. Grok Bot and Cloud Agents share one weekly usage pool. An older Cursor Pro, Pro+, Ultra, or Teams plan that already includes both is fine. If you have SuperGrok or X Premium+ linked, check first: it may unlock Grok Bot, and it is not confirmed to include Cloud Agents. Prices as of Nov 2026, check the [pricing page](https://cursor.com/pricing).
2. A free GitHub account.
3. A free Cloudflare account. The free Workers plan is enough.

## The one sentence

Tell your Grok Bot:

> Read GROKBOT.md in <repo URL> and set me up

Use the URL of this repository.

## What happens

Your main Grok Bot reads [GROKBOT.md](GROKBOT.md) and asks a few plain questions. If the paid plan is not there yet, it explains what you need and stops before it creates any bot. When the plan is in place, it creates a Guide that already has your answers. The Guide stays with you. It walks you one step at a time through accounts, a private page, and the clicks that connect the site. You then meet two bots named after your project, a Manager and a Build Watcher. You make one wish. The Manager plans it and hands the coding to a cloud agent, so your chat with the Manager stays about the wish. When the change is ready, you get a preview link, and the Guide walks you through accepting it, the first time with every click explained. About a minute later the live site shows the change, and the Watcher confirms it.

The Intro tier is instructions the bots read. This kit does not copy a starter project into your repository.

Details live in [intro/LOOP.md](intro/LOOP.md), [intro/ROUTINES.md](intro/ROUTINES.md), and [intro/CLOUDFLARE.md](intro/CLOUDFLARE.md).

## Cost

The one cost is that paid plan. GitHub Free and Cloudflare Workers Free are enough: 3,000 build minutes a month, and one build at a time. Preview links are public by default. The first time a cloud agent runs, it asks you to set a spend limit. This kit adds no other paid service. Prices as of Nov 2026, check the pricing page. How cloud agents are billed is on the [Cloud Agents page](https://cursor.com/docs/cloud-agent).

## The team

One role per bot.

| Bot | File | Role |
| --- | --- | --- |
| Guide | [intro/bots/guide.md](intro/bots/guide.md) | Stays with you. Walks every click, login, and merge |
| `<Project> Manager` | [intro/bots/manager.md](intro/bots/manager.md) | Talks about wishes. Hands the coding to a cloud agent. Sends clicks to the Guide |
| `<Project> Build Watcher` | [intro/bots/build-watcher.md](intro/bots/build-watcher.md) | Watches the change, then sends one note: ready or not, and later that the live site updated |

## Advanced

The modules are for a project that has outgrown a single slice. They add a local micro-slice loop, a stricter journey gate, a code map, a red-team pass, and a warden for a local build machine. Start at [modules/README.md](modules/README.md). The loop module includes `init.sh` for that path. The Intro steps above stand on their own without it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md). License: [MIT](LICENSE).
