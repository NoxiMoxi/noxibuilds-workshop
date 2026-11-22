# Routines

The Build Watcher owns exactly two routines, on the one project repository. The Manager has none. The Guide creates these when it creates the Build Watcher, then never adds another.

Both routines are event triggers. The filter lives on the routine, so a non-matching event does not start the bot. A bot that wakes and finds nothing to do is an empty run. Do not create that routine.

Do not create a schedule, a cron, a heartbeat, an "every few minutes" check, or a routine that lists pull requests on a timer.

Name the routines after the project: `<Project> preview or user comment` and `<Project> merged to main`.

## R1 — preview comment or user comment

**Trigger.** A new comment on the conversation of a pull request in this repository (a GitHub issue comment on a pull request). Subscribe to that one event. Do not also subscribe to "any pull request activity", review submissions, or pushes.

**Filter.** Start the Build Watcher only when every line below is true.

- The comment is on an open pull request in this repository.
- The author is either:
  - `cloudflare-workers-and-pages[bot]`, and the comment body contains a preview link on `workers.dev` (shape in [CLOUDFLARE.md](CLOUDFLARE.md)), or
  - the human who owns the repository (their login, and the author is not a bot).
- The author is not the Build Watcher, not the Manager, and not the cloud agent.

**Ignore.** Drop these before the bot starts.

- Comments by any other bot or app, including a cloud agent done note.
- Comments on issues that are not pull requests.
- A Cloudflare comment that has no preview link. The cloud agent is still waiting on that build (see [LOOP.md](LOOP.md)).
- Edits, reactions, labels, reviews, and check runs.

**Action.** Wake the Build Watcher once with the pull request number, the comment author, and the comment body. The Watcher runs the R1 checklist in [LOOP.md](LOOP.md). It does not schedule a follow-up.

## R2 — pull request merged

**Trigger.** A pull request closed in this repository.

**Filter.** Start the Build Watcher only when every line below is true.

- The pull request was merged.
- The base branch is `main`.

**Ignore.** A pull request that was closed without merging. A merge into any branch other than `main`.

**Action.** Wake the Build Watcher once with the pull request number and the merge commit. Inside that run the Watcher waits until the check `Workers Builds: <worker-name>` on that commit has succeeded, opens the live site, and sends one `DIGEST live`. Waiting inside the run that the merge already started is part of the job. A second routine that checks back later is a timer. Do not create one.

If the production check fails, send one `DIGEST escalate` and stop. Do not schedule a retry.

## Why the bots never comment

R1 fires on comments. The Build Watcher and the Manager do not comment on pull requests, so they cannot wake this routine themselves. The cloud agent's done note goes in the pull request description, not a comment. The only comments that should match R1 are the Cloudflare preview comment and a comment from the user.
