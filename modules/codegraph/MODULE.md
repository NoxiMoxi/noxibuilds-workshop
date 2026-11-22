# codegraph

A map of the code. A cloud agent builds it at the start of a run, then reads a small pack instead of the whole repository.

It is free, and the license is MIT. It needs no API key. It works for a project that lives only in the cloud, with no computer of your own in the loop.

## What it adds

- An index of the code, built at the start of each cloud-agent run. On a small repository that takes about five seconds.
- Context packs: exact line ranges and the callers that matter for a brief.
- For the advanced loop, a Cartographer bot: a route and page inventory after each deploy, and the surface-slice plan the red-team module reviews, using [../redteam/SLICING.md](../redteam/SLICING.md).
- For a large repository, an optional GitHub Actions workflow that builds the same index and uploads it as an artifact.

It indexes programming languages, including JavaScript, TypeScript, and Python. It does not index plain HTML, JSON, or Markdown. A simple static site gets little from it. Turn it on once the project has real code.

## What it needs

- No key, no account, and no paid plan.
- The three commands below, at the start of each cloud-agent run. Telemetry is on unless you turn it off. The commands turn it off.
- A standing Cartographer only on the advanced loop. That bot also needs [common.md](../claude-code-loop/common.md) and a heads-up from the CTO after a deploy. A cloud-only Intro project does not create that bot.
- The red-team module only when a go-live review is coming. The map is useful before that.

## What it replaces

Asking a builder or a reviewer to explore a repository of real code. The brief names the lines to read. The inventory replaces a hand-built list of routes after each deploy. It does not replace reading a page that is only HTML.

## How a bot enables it

Suggest this module only when the project has real code. Skip it for the hello page.

For a cloud-only project, do not install this on the user's computer. Tell the Manager to put these lines at the start of every cloud-agent brief. The agent runs them in one shell, in this order. Do not commit the index.

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
CODEGRAPH_TELEMETRY=0 codegraph init --yes
```

The index is the `.codegraph/` folder, including `.codegraph/codegraph.db`. Never commit it. Add `.codegraph/` to `.gitignore` if it is not already ignored.

On the advanced loop, the Setup Guide may also create the Cartographer from [cartographer.md](cartographer.md) plus `common.md`, and tell it where the clone is. The CTO messages it when a brief needs ranges and after each deploy. That message is the trigger. Do not add a schedule.

For a large repository, an optional GitHub Actions workflow can build the index and upload `.codegraph/` as an artifact. The workflow uses the same three commands, with telemetry off. It uploads the folder. It does not commit the index. The Guide walks any GitHub click that workflow needs, one step at a time.

## How to turn it off

Take the three lines out of the cloud agent's brief. Delete the Actions workflow if one was added. Retire the Cartographer if it exists. The index was never in git. Maps the Cartographer already wrote can stay in the review-log. Nothing in the running site depends on this.

## Files

- [cartographer.md](cartographer.md) — persona for the advanced loop

## Changelog

- 2026-11-22: Moved here from `bots/cartographer.md`.
- 2026-11-22: Recorded the cloud-agent install, telemetry off, and the rule to leave the index uncommitted. A static site skips this module.
