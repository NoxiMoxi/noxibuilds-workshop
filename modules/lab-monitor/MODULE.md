# lab-monitor

A warden for the local build machine. Structural changes wait for an approval and a limit.

## What it adds

- A Lab Warden persona: folders, services, units, ports, containers, packages, and edits to installed loop files.
- Standard limits: loopback ports, pinned throwaway containers, no live data in tests, worktrees detached at an exact commit.
- [local-triage.md](local-triage.md): machine rules for an optional local model that triages a slice before a paid review. The attack method stays in the red-team module. This file is only the machine side.

## What it needs

- A local machine running the claude-code-loop watcher, or any other always-on build box for the project.
- Shell access the user chooses to grant.
- A list from the user of anything already running that must not be disturbed.
- The user's yes before anything is installed or started.
- [common.md](../claude-code-loop/common.md) appended to the persona.

## What it replaces

Ad-hoc installs and port choices on that machine. The Intro tier has no local build machine, so it has nothing for this module to replace until the loop module is on.

## How a bot enables it

The advanced Setup Guide creates the Lab Warden from [lab-warden.md](lab-warden.md) plus `common.md` before `init.sh` scaffolds the project, and again before the user installs the watcher unit. Other bots message the Warden when they want a folder, a port, a container, or an edit to an installed loop file. That request is the trigger. Do not add a health-check timer.

## How to turn it off

Retire the Lab Warden bot. Stop asking it for approvals. Anything it already approved keeps running until the user stops it. Disabling this module does not disable the watcher; stop the watcher from the claude-code-loop module if that is the goal.

## Files

- [lab-warden.md](lab-warden.md) — persona
- [local-triage.md](local-triage.md) — optional local-model machine limits

## Changelog

- 2026-11-22: Moved here from `bots/lab-warden.md`. Local-model triage notes that used to live only in the kit overview now have a home in `local-triage.md`. The review method stays in `modules/redteam/`.
