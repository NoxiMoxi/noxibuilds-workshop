# codegraph

A code map. Other bots ask for a small context pack instead of reading the whole repository.

## What it adds

- A Cartographer bot, read-only on the product code.
- Context packs: exact line ranges and the callers that matter for a brief.
- A route and page inventory after each deploy, diffed against the previous one.
- The surface-slice plan the red-team module reviews, using [../redteam/SLICING.md](../redteam/SLICING.md).

## What it needs

- A clone of the app at an exact commit, read-only.
- [common.md](../claude-code-loop/common.md) appended to the persona.
- A heads-up from the CTO after a deploy, with the commit that went live.
- The red-team module only when a go-live review is coming. The map is useful before that.

## What it replaces

Asking a builder or a reviewer to explore the repository. The brief names the lines to read. The inventory replaces a hand-built list of routes after each deploy.

## How a bot enables it

The advanced Setup Guide creates the Cartographer from [cartographer.md](cartographer.md) plus `common.md`, and tells it where the clone is. The CTO messages it when a brief needs ranges and after each deploy. That message is the trigger. Do not add a schedule.

## How to turn it off

Stop asking for packs and inventories. Retire the Cartographer bot. Maps it already wrote can stay in the review-log. Nothing in the running site depends on this bot.

## Files

- [cartographer.md](cartographer.md) — persona

## Changelog

- 2026-11-22: Moved here from `bots/cartographer.md`.
