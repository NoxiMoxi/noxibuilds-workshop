# Cloudflare facts for the Intro tier

These are facts from a real hello-site test. Use them as written. The Intro tier has no project template in this kit: when a bot creates the user's site, it writes the files below into their private repository.

## Hello site files

Write these three files. Fill `<worker>` with the project slug and `<date>` with the day you create the worker (`YYYY-MM-DD`). Fill `<project name>` with the name the user chose.

`public/index.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Hello</title>
</head>
<body>
  <h1>Hello</h1>
  <p>This is <project name>. It is live.</p>
</body>
</html>
```

`wrangler.jsonc`

```jsonc
{
  "name": "<worker>",
  "compatibility_date": "<date>",
  "assets": { "directory": "./public" },
  "previews": {}
}
```

A minimal assets-only config is `{"name":"<worker>","compatibility_date":"<date>","assets":{"directory":"./public"},"previews":{}}`.

The top-level `"previews": {}` block is required. Preview builds fail when it is missing.

`package.json`

```json
{
  "name": "<worker>",
  "private": true,
  "devDependencies": {
    "wrangler": ">=4.135.0"
  }
}
```

Pin `wrangler` at `>=4.135.0` in `devDependencies`. Older wrangler breaks the preview path below.

## Builds

- Preview command: `npx wrangler preview`
- Deploy command: `npx wrangler deploy`
- Check name: `Workers Builds: <worker-name>`
- Preview link shape: `https://<branch-slug>-<worker>.<subdomain>.workers.dev`
- The live site after a merge to `main` updates in about a minute. The production host is the worker on `workers.dev` without a branch slug, usually `https://<worker>.<subdomain>.workers.dev`.

`<branch-slug>` is the pull request branch reduced to a slug. `<subdomain>` is the account's workers.dev subdomain. Read the real preview link from the cloud agent's report or the check-run details. Do not invent it. A Cloudflare comment on the pull request is not where this loop gets the link.

## Connecting Git

Grok Bot's Cloudflare connector can create and deploy a Worker. It may lack Workers CI permission. Connecting Git is a dashboard step the user does, with the bot guiding one click at a time:

Workers & Pages → the worker → Settings → Builds → Connect → GitHub.

On that step:

- Install the Cloudflare GitHub app on only this repository.
- Production branch: `main`.
- Turn on preview builds for non-production branches.
- Set the preview command and the deploy command to the values above.

## What the cloud agent waits for

Tell every cloud agent to keep going after the push. It waits until the pull request's checks finish, then it reports three things: the preview URL, the check results, and what changed. The checks are `Workers Builds: <worker-name>` and any tests the repository runs. If a check fails, the agent reports the failure and stops. The Manager decides the fix. The Build Watcher does not.

The build starts when the branch is pushed. By the time a `pr-opened` routine runs, the check may already be finished. That is why the Watcher looks up the current check state first.

The agent's finish is the signal that the preview is ready to look at. Two things that look like signals are not:

- Cloudflare's preview comment on the pull request does not fire a `pr-comment` trigger. Do not subscribe to it, and do not wait for it. The preview URL is in the agent's report or the check-run details.
- A `ci-passed` or `ci-failed` watch on one pull request number did not fire, for this Cloudflare check or for a GitHub Actions check. Do not create one.

What does fire, repo-wide, is in [ROUTINES.md](ROUTINES.md): `pr-opened`, `pr-merged`, and `ci-passed` / `ci-failed` with `ciBranch` set to `main` for `Workers Builds: <worker-name>`. The main-branch check is how the Watcher confirms the live deploy after a merge. Pull request routines need a `userAllowlist` of `<your-github-login>`, because the cloud agent opens the pull request as that person.

A missing top-level `"previews": {}` block is a common reason a preview build fails. The hello site's config includes it. If a later change drops it, the agent reports that failure and the Manager sends the fix.
