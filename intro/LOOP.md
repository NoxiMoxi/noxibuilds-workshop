# The Intro loop

One wish becomes one small slice. A cloud agent opens one pull request. The Build Watcher checks it. The Guide walks the user through accepting it. The live site updates. Then everyone waits until the next wish.

Read [CLOUDFLARE.md](CLOUDFLARE.md) for the preview link, the check name, and the rule that cloud agents wait for the build.

## Roles in the loop

| Who | Does this | Stays quiet about |
| --- | --- | --- |
| User | Says the wish in their own words. | Writing the slice |
| Guide | Every click, sign-up, login, approval, and merge. One step at a time. Reports back. | Deciding what the site should say |
| Manager | Turns the wish into one issue. Launches one cloud agent. Sends the Guide a handoff when the user must do something. | Clicks, logins, and pull request comments |
| Build Watcher | Checks the slice, the preview, and the tests. Sends fix rounds. Sends one digest. | The user. The Guide. Pull request comments |
| Cloud agent | Edits only the files in the issue and opens the pull request. Waits for the build. | New wishes, merging |

One role per bot. The Manager talks with the user about wishes. The Guide talks with the user about steps.

## End to end

1. The user says a wish in their own words. The Manager reads `docs/project.md` (the project brief) and `docs/journey.md`, then appends the new words to `docs/journey.md`.
2. The Manager opens one GitHub issue in the slice format below, then launches one Cursor cloud agent on that issue.
3. The cloud agent opens a pull request, puts a done note in the description, and waits until the check `Workers Builds: <worker-name>` finishes.
4. The Cloudflare bot `cloudflare-workers-and-pages[bot]` comments with the preview link. That comment wakes the Build Watcher (routine R1 in [ROUTINES.md](ROUTINES.md)).
5. The Build Watcher runs the review checklist. A failure sends a fix round straight to the same cloud agent, on the same pull request. A pass sends the Manager one `DIGEST ready`.
6. The Manager sends the Guide one handoff: show the preview, and if the user likes it, accept the change onto the live site. The Guide explains the first merge one click at a time, confirms the page shows it is merged, celebrates, and reports back to the Manager.
7. The merge wakes the Build Watcher (routine R2). It waits until the production build has succeeded and the live site shows the change, then sends one `DIGEST live`.
8. The Manager celebrates in plain words and suggests one next small wish from the journey. It does not start that wish, and it does not add click steps.

A comment by the user on the pull request is a change request. The Build Watcher treats it as a fix round. If the comment asks for files outside the slice, the Watcher does not widen the slice. It escalates to the Manager. If the user must click, sign in, or approve something, the digest says `needs_user: yes`, and the Manager sends that to the Guide. The Watcher never messages the user.

## Slice format

The Manager writes this as the GitHub issue. One issue, one pull request.

```markdown
## Goal
<the wish, in the user's words, one or two sentences>

## Files
- `<path>` — <why this file>

## Done when
- [ ] <something a person can see on the preview>
- [ ] The pull request description has a done note.
- [ ] The check `Workers Builds: <worker-name>` passed.

## Line cap
<number>
```

The line cap is a number the wish can finish inside. Use 80 changed lines (additions plus deletions) unless the wish is smaller. The Intro cap is 300. A wish that needs more than one slice waits for the [claude-code-loop module](../modules/claude-code-loop/MODULE.md), or the user picks the single slice to do first.

Journey quotes stay in `docs/journey.md`. The issue points at the journey lines it serves. The Manager does not paraphrase the journey inside the issue goal. The goal is the user's words.

## Prompt the Manager gives the cloud agent

Include the issue number, the line cap, the file list, and these rules:

- Change only the files listed on the issue.
- Stay inside the line cap.
- Do not add secrets, tokens, private keys, or environment files.
- Open one pull request. Put the done note in the pull request description: what changed, and how you checked it. Do not comment on the pull request.
- Do not finish when the push succeeds. Wait until the check `Workers Builds: <worker-name>` completes.
- If that check fails, read the log and fix the cause inside the slice, then wait again.
- If preview builds fail because `wrangler.jsonc` has no top-level `"previews": {}` block, add that block. It belongs in the hello site's config (see [CLOUDFLARE.md](CLOUDFLARE.md)).

## Review checklist

The Build Watcher checks every item. Any miss is a failed check.

1. **Planned files only.** Every changed file is on the issue's file list. The lockfile is allowed when `package.json` changed.
2. **Line cap.** Additions plus deletions are at or under the issue's line cap.
3. **No secrets.** The diff has no tokens, private keys, passwords, or environment files.
4. **Done note.** The pull request description says what changed and how the agent checked it.
5. **Preview shows the change.** Open the preview link from the Cloudflare comment. The wish is visible there.
6. **Tests.** If `package.json` has a test script, or the repository has a test directory, run those tests. If the repository has neither, record `none`.

## Fix rounds and caps

- A **start** is one launch of a cloud agent for this slice, including the Manager's first launch and every fix round.
- A **fix round** is a start the Build Watcher sends because a check failed or the user commented.
- Maximum **2 fix rounds** per slice.
- Maximum **4 starts** per slice.
- Stop at whichever cap you hit first. Send `DIGEST escalate` to the Manager. Do not launch again.
- The Watcher keeps the counts in its own notes, keyed by issue number. It does not write them on the pull request. If it wakes with no notes, it counts the cloud-agent runs that already exist for the issue before it sends another.
- A fix round goes straight to the cloud agent that owns the pull request. The Manager is not in that path.
- The message names the failed checklist item, quotes the user's comment when there is one, and repeats the cloud-agent rules above.

Build-failure comments that have no preview link do not wake the Watcher. The cloud agent handles those while it waits for the check. If an agent stops with a failing check and no preview comment, the slice is stuck until the user tells the Manager. That message is a judgment call. The Manager asks the Watcher for the counts and does not launch a start that would pass the cap.

## Digest format

The Build Watcher sends exactly one of these to the Manager, and nothing else about that wake.

```text
DIGEST ready
issue: <number>
pr: <link>
preview: <link>
lines: <used>/<cap>
tests: pass | none
```

```text
DIGEST live
issue: <number>
pr: <link>
live: <link>
```

```text
DIGEST escalate
issue: <number>
pr: <link>
starts: <used>/4
fix_rounds: <used>/2
why: <one line>
needs_user: yes | no
```

`needs_user: yes` means the next step is a click, a login, a code from their phone, an approval, or a merge. The Manager then sends the Guide a handoff. `needs_user: no` means the Manager can decide from the journey, or ask one plain product question, with no screens to walk through.

## Handoff to the Guide

Any bot that needs the user to do something sends this to the Guide and waits. The Manager uses it for every merge and for every escalation with `needs_user: yes`. The primary bot uses it for sign-ups and connections during setup only by creating the Guide and letting the Guide run the checklist. Nobody else writes the click path.

```text
HANDOFF
to: Guide
from: <bot name>
project: <display name>
needed: <what the user must do, in plain words>
why: <one sentence>
done when: <what the Guide confirms before it reports back>
```

The Guide answers with `HANDOFF done`, as written in [bots/guide.md](bots/guide.md).

The Manager turns a `ready` digest into that handoff, and a `live` digest into one celebration plus one suggested next wish. It does not add a running commentary, and it does not tell the user which buttons to press.

## Habits

- Triggers wake bots. Timers, polling, and heartbeats do not.
- Read `docs/journey.md` before planning. Write the user's words there unchanged.
- One wish, one slice, one pull request.
- The user accepts a change onto the live site. The Guide is who walks them through it. Bots do not merge, approve, or push to the pull request branch.
- The Manager never instructs the user through a technical step. That handoff goes to the Guide.
- The Manager and the Build Watcher never comment on pull requests, so a comment cannot wake them.
- One digest, then stop. A quiet result does not produce a second message.
- Private repository by default.
- A judgment call is a product question the journey does not answer, a wish that no longer fits the slice, or an escalate digest. A failed test is a fix round, not a judgment.
