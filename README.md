# Workshop Intro

[![checks](https://github.com/NoxiMoxi/noxibuilds-workshop/actions/workflows/checks.yml/badge.svg)](https://github.com/NoxiMoxi/noxibuilds-workshop/actions/workflows/checks.yml)

You get a live website, and a way to change it that waits for your yes.

You say what you want. Helpers bring you a preview, a look at the change before it goes live. You press Merge, the button that accepts the change. The live site updates.

You are looking at a repo, a project folder of files. GitHub is the free site that stores that folder. The instructions here tell your Grok Bot, the chat helper you talk to, how to set up a small team for the work above. The badge at the top links to the automatic checks for this repo.

When one wish, one thing you ask for, no longer fits one change, the optional extras are the next step. They are listed in [modules/README.md](modules/README.md).

## What you need

You need three things.

1. One paid plan, [The X Subscription](https://docs.x.ai/x-subscription/pricing), at Premium or higher. The bots, the signals that wake them when something happens, and the cloud agents that open pull requests all run on it. A cloud agent is a helper that writes the code in its own workspace. A pull request is a proposed change you accept to put it on the live site.

   Free and Plus ($8 a month) include neither Grok Bot nor Cloud Agents. Premium ($30 a month) is the minimum that includes Grok Bot and Cursor Cloud Agents. Super and Ultra include both, with a bigger weekly allowance. Where both are included, Grok Bot and Cloud Agents share one weekly pool.

   An older Cursor Pro, Pro+, Ultra, or Teams plan that already includes both is fine. If you have SuperGrok or X Premium+ linked, check first. It may unlock Grok Bot, and it is not confirmed to include Cloud Agents. Prices as of Nov 2026. Check the [pricing page](https://cursor.com/pricing).

2. A free GitHub account.
3. A free Cloudflare account. The free Workers plan is enough. A Worker is your site running on Cloudflare. Cloudflare is what shows the site to the world.

## How to start

Tell your Grok Bot this. Where it says `<repo URL>`, put the web address of this repo.

> Read GROKBOT.md in <repo URL> and set me up

[GROKBOT.md](GROKBOT.md) is the note your main bot reads first.

## What happens

Your main Grok Bot reads [GROKBOT.md](GROKBOT.md) and asks a few plain questions. If the paid plan is not there yet, it explains what you need and stops before it creates any bot. When the plan is in place, it creates a Guide that already has your answers. The Guide stays with you. It walks you one step at a time through accounts, a private folder for the site, and the clicks that connect the site.

You then meet two bots named after your project, a Manager and a Build Watcher. You make one wish. The Manager plans it and hands the writing of the code to a cloud agent, so your chat with the Manager stays about the wish.

When the change is ready, you get a preview link. The Guide walks you through accepting it. The first time, every click is explained. About a minute later the live site shows the change, and the Watcher confirms it.

These starting steps are instructions the bots read. These instructions do not copy a starter project into your folder.

Details live in [intro/LOOP.md](intro/LOOP.md), [intro/ROUTINES.md](intro/ROUTINES.md), and [intro/CLOUDFLARE.md](intro/CLOUDFLARE.md).

## Cost

The one cost is that paid plan. GitHub Free and Cloudflare Workers Free are enough.

Free Workers Builds include 3,000 build minutes a month, and one build at a time. Preview links are public by default, even when the GitHub folder is private.

The first time a cloud agent runs, it asks you to set a spend limit, a cap on what it can spend. These instructions add no other paid service. Prices as of Nov 2026. Check the pricing page. How cloud agents are billed is on the [Cloud Agents page](https://cursor.com/docs/cloud-agent).

## The team

Each bot has one job. The names pick up your project name. A site called Bakery Site gets a Bakery Site Manager and a Bakery Site Build Watcher.

| Bot | File | What it does |
| --- | --- | --- |
| Guide | [intro/bots/guide.md](intro/bots/guide.md) | Stays with you. Walks every click, login, and Merge |
| `<Project> Manager` | [intro/bots/manager.md](intro/bots/manager.md) | Talks about wishes. Hands the writing of the code to a cloud agent. Sends clicks to the Guide |
| `<Project> Build Watcher` | [intro/bots/build-watcher.md](intro/bots/build-watcher.md) | Watches the change, then sends one note: ready or not, and later that the live site updated |

## Advanced

This part is for a project that has outgrown a single change.

The extras add a loop on your own computer that takes big work in tiny steps. They add a stricter check that the work still matches your words, a map of the code, a security review in small passes, and a helper that looks after a computer you use to build.

Start at [modules/README.md](modules/README.md). The loop extra includes `init.sh`, a setup script, for that path. The steps above stand on their own without it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md). License: [MIT](LICENSE).
