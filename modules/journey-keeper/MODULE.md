# journey-keeper

A strict gate for big slices. The user's journey stays in their own words, and a spec that drifts from it fails.

## What it adds

- A Journey Keeper bot that appends the user's words verbatim and answers a spec batch with one `PASS` line or a detailed `FAIL`.
- The journey template the loop scaffold writes to `docs/brain/journey.md` in the review-log.
- Checks on route inventories after a deploy, and a reject for tests that assert a refusal the journey does not ask for.

The Intro Manager still keeps `docs/journey.md` in the user's app repository. This module guards a second file, `docs/brain/journey.md` in the review-log, once the claude-code-loop is on.

## What it needs

- [claude-code-loop](../claude-code-loop/MODULE.md), so there is a review-log and a CTO sending spec batches.
- [common.md](../claude-code-loop/common.md) appended to the persona.
- Write access to the review-log, so the user's words can be committed.
- The user, for the words and for kept-or-dropped answers. Questions go out in the CTO's one card.

## What it replaces

The orchestrator checking its own briefs against the journey. On a large slice that self-check is too soft. Journey Keeper's PASS or FAIL is the gate that runs once per spec batch, before the queue opens.

## How a bot enables it

When the advanced Setup Guide creates bots, it creates Journey Keeper from [journey-keeper.md](journey-keeper.md) plus `common.md`. The CTO sends a whole spec batch in one message and waits for PASS. Do not give Journey Keeper a routine that wakes on a timer or on every commit. It wakes when the CTO sends a batch, or when the user is dictating a journey.

## How to turn it off

Stop sending batches. Retire the Journey Keeper bot. Leave `docs/brain/journey.md` in the review-log so the words are not lost. The Intro `docs/journey.md` is a different file and stays with the Manager.

## Files

- [journey-keeper.md](journey-keeper.md) — persona
- [journey.md.template](journey.md.template) — scaffolded to `review-log/docs/brain/journey.md` by `init.sh`

## Changelog

- 2026-11-22: Moved here from `bots/journey-keeper.md` and `brain/journey.md.template`.
