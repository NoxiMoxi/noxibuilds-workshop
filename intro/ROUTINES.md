# Routines

The Build Watcher owns the four routines below, on the one project repository. The Manager owns none. The Guide creates these when it creates the Build Watcher, then never adds another.

Each routine is one event. The filter lives on the routine, so a non-matching event does not start the bot. A bot that wakes and finds nothing to do sends nothing. Do not create a schedule, a cron, a heartbeat, an "every few minutes" check, or a routine that lists pull requests on a timer. Do not poll.

Name them after the project:

- `<Project> pull request opened`
- `<Project> pull request merged`
- `<Project> main build passed`
- `<Project> main build failed`

The Watcher also adopts each cloud agent the Manager hands it. That watch is not one of these routines. It is `CloudAgent` action `watch` with `confirm: true`, from [LOOP.md](LOOP.md). Do not turn it into a timer.

## Facts that were tested

Use these as written.

- Repo-wide `pr-opened` works.
- Repo-wide `pr-merged` works.
- Repo-wide `ci-passed` and `ci-failed` work when `ciBranch` is `main`, for the Cloudflare check `Workers Builds: <worker-name>`.
- A `ci-passed` or `ci-failed` watch scoped to one pull request number did not fire. Not for the Cloudflare check, and not for a GitHub Actions check. Do not create one. The cloud agent's finish is the signal that the preview is ready to look at.
- Cloudflare's preview comment on a pull request does not fire a `pr-comment` trigger. Do not subscribe to comments. Get the preview URL from the agent's report or the check-run details.
- Repo-wide pull request triggers need a `userAllowlist`. Cloud agents open pull requests as the user, so the allowlist is `<your-github-login>`, the person's own GitHub login. Do not put a bot login there, and do not leave it empty.
- Every wake is an event. There is no polling and no timer.

## R1 — pull request opened

**Trigger.** `pr-opened`, repo-wide, on this repository.

**userAllowlist.** `<your-github-login>`

**Filter.** An open pull request in this repository, opened as that login.

**Ignore.** Pull requests by anyone else. Issues that are not pull requests. Comments, reviews, labels, and check runs.

**Action.** Wake the Build Watcher once with the pull request number. It checks the current check state first, because Cloudflare builds when the branch is pushed and the build may already be done. If the checks are still running, it sends nothing. The cloud agent's finish is the next wake. It does not schedule a follow-up. The rest is in [LOOP.md](LOOP.md).

## R2 — pull request merged

**Trigger.** `pr-merged`, repo-wide, on this repository.

**userAllowlist.** `<your-github-login>`

**Filter.** The pull request was merged, and the base branch is `main`.

**Ignore.** A pull request closed without merging. A merge into any branch other than `main`.

**Action.** Wake the Build Watcher once with the pull request number and the merge commit. It remembers that merge. It does not wait in this run for the production build, and it does not send the live digest yet. The live confirmation is R3. A routine that checks back later is a timer. Do not create one.

## R3 — main build passed

**Trigger.** `ci-passed` with `ciBranch` set to `main`.

**Filter.** The check name is `Workers Builds: <worker-name>`.

**Ignore.** Any other check. A pass on a pull request branch. A pass on `main` when the Watcher is not remembering a merge it has not reported yet.

**Action.** Wake the Build Watcher once. If it is not remembering a merge it has not reported, it sends nothing. Otherwise it opens the live site, sees whether the change is there, and sends one `DIGEST live` line to the Manager. It does not launch a fix. It does not look again later.

This routine is repo-wide on `main`. It is not scoped to a pull request number. A watch on one pull request's checks did not fire.

## R4 — main build failed

**Trigger.** `ci-failed` with `ciBranch` set to `main`.

**Filter.** The check name is `Workers Builds: <worker-name>`.

**Ignore.** Any other check. A failure on a pull request branch. A failure on `main` when the Watcher is not remembering a merge it has not reported yet.

**Action.** Wake the Build Watcher once. If it is not remembering a merge it has not reported, it sends nothing. Otherwise it sends one `DIGEST live-fail` line and stops. It does not launch a fix, and it does not schedule a retry.

## Why there is no comment routine

A Cloudflare preview comment does not fire `pr-comment`. The cloud agent's done note belongs in the pull request description, not a comment. The Manager and the Build Watcher do not comment on pull requests. A wish, or a change of mind, comes to the Manager in the chat.

## The agent watch

When the Manager sends an agent id, the Watcher runs `CloudAgent` action `watch` with `confirm: true` on that agent. The agent's finish wakes the Watcher. The Manager has already called `unwatch`, so the same finish does not wake the Manager. The Watcher creates this watch in the run that receives the handoff. It is not a fifth routine, and it is not a timer.
