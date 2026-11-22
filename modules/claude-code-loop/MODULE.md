# claude-code-loop

The local micro-slice loop. A headless builder takes one slice of a queued piece, opens a draft pull request, and a zero-token gate accepts or rejects the diff.

## What it adds

- `init.sh` (at the kit root) scaffolds a per-project review-log, loop config, watcher, and user unit file. It does not install or start anything.
- The watcher starts when a committed queue change lands. Idle costs no model call.
- Gates G0–G4 check the status line, a clean push, new commits, declared files and line caps, and the project's self-check. See [loop/GATES.md](loop/GATES.md).
- The CTO persona turns journeys into briefs and reviews a piece once.
- The advanced Setup Guide walks this path one check at a time. Newcomers stay on the Intro until a wish no longer fits one slice.

## What it needs

- The Intro habit already in place: one role per bot, the user merges, triggers rather than timers.
- A machine that can run the watcher, with git, bash, jq, flock, and inotify.
- A Claude Code CLI signed in on that machine, and the GitHub CLI so the builder can open draft pull requests.
- Journey Keeper ([../journey-keeper/MODULE.md](../journey-keeper/MODULE.md)) once slices are large enough to drift from the journey. Add it with this module, not later.

Full steps: [GUIDE.md](GUIDE.md). Every config key is documented in [loop/loop.env.example](loop/loop.env.example).

## What it replaces

The Intro's one-slice cloud agent, for wishes that need more than one pull request's worth of work. The Manager's single issue becomes a queued piece of micro-slices with a brief, a file list, and a line cap per slice.

The Intro Manager and Build Watcher stay until you move that project onto this loop. This module does not delete them.

## How a bot enables it

The user asks the Manager (or Grok Bot) to follow [setup-guide.md](setup-guide.md). That guide creates the CTO and points it at `modules/claude-code-loop/cto.md` plus [common.md](common.md). The user runs `init.sh` themselves after a dry run, from the kit root. The watcher then wakes on a committed queue change. Do not add a timer beside it.

## How to turn it off

Stop and disable the user unit the guide installed. Leave the review-log in place so the journey and briefs stay. Stop committing changes to the open queue section, and the watcher will not start a run. Retire the CTO bot if nobody should write briefs. The Intro bots keep working for any repo you did not move onto this loop.

## Files

- [GUIDE.md](GUIDE.md) — setup, safety, and where the spec lives
- [setup-guide.md](setup-guide.md) — advanced setup, one check per step
- [cto.md](cto.md) — orchestrator persona
- [common.md](common.md) — rules shared by the advanced bots
- [loop/](loop/) — watcher, gates, queue and brief templates, env example, user unit template
- [brain/](brain/) — START, rules, decisions, and review-log templates (the journey template lives with Journey Keeper)

## Changelog

- 2026-11-22: Moved here from the kit root (`loop/`, `brain/` except the journey template, `bots/cto.md`, `bots/common.md`, `bots/setup-guide.md`) when the Workshop Intro tier split advanced material into modules.
