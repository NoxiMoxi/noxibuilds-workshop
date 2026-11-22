# Workshop Intro

Point a Grok Bot at this repo and it will set up a small website team: you ask for a change, the bots shepherd a pull request until it is ready with a preview link, you press Merge, and the change shows on your live site.

When one wish no longer fits one change, the optional modules are the next step: [modules/README.md](modules/README.md).

## What you need

1. A Grok Bot (Cursor) subscription.
2. A free GitHub account.
3. A free Cloudflare account.

## The one sentence

Tell your Grok Bot:

> Read GROKBOT.md in <repo URL> and set me up

Use the URL of this repository.

## What happens

Your main Grok Bot reads [GROKBOT.md](GROKBOT.md), asks a few plain questions, and creates a Guide that already has your answers. The Guide stays with you. It walks you one step at a time through accounts, a private page, and the clicks that connect the site. You then meet two bots named after your project, a Manager and a Build Watcher. You make one wish. The Manager plans it and hands the coding to a cloud agent, so your chat with the Manager stays about the wish. When the change is ready, you get a preview link, and the Guide walks you through accepting it, the first time with every click explained. About a minute later the live site shows the change, and the Watcher confirms it.

The Intro tier is instructions the bots read. This kit does not copy a starter project into your repository.

Details live in [intro/LOOP.md](intro/LOOP.md), [intro/ROUTINES.md](intro/ROUTINES.md), and [intro/CLOUDFLARE.md](intro/CLOUDFLARE.md).

## Cost

The cost is your Grok Bot subscription plus the free GitHub and Cloudflare tiers. The Intro adds no other paid service.

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
