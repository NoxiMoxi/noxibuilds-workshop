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

`<branch-slug>` is the pull request branch reduced to a slug. `<subdomain>` is the account's workers.dev subdomain. Read the real link from the Cloudflare comment. Do not invent it.

## Connecting Git

Grok Bot's Cloudflare connector can create and deploy a Worker. It may lack Workers CI permission. Connecting Git is a dashboard step the user does, with the bot guiding one click at a time:

Workers & Pages → the worker → Settings → Builds → Connect → GitHub.

On that step:

- Install the Cloudflare GitHub app on only this repository.
- Production branch: `main`.
- Turn on preview builds for non-production branches.
- Set the preview command and the deploy command to the values above.

## Cloud agents finish early

A cloud agent tends to finish as soon as its edit is pushed, while `Workers Builds: <worker-name>` is still running. Tell every cloud agent to keep waiting until that check completes. If the check fails, the agent reads the log and fixes the cause inside the slice before it stops. A missing `"previews": {}` block is a common cause.
