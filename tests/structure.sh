#!/usr/bin/env bash
# structure.sh - Workshop Intro files exist, and every module has a MODULE.md.
# No network. No secrets. Safe to run any number of times.
set -euo pipefail

KIT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$KIT"

pass=0
ok() { pass=$((pass + 1)); echo "ok $pass - $*"; }
no() { echo "FAIL - $*" >&2; exit 1; }

required=(
  intro/bots/setup-guide.md
  intro/bots/manager.md
  intro/bots/build-watcher.md
  intro/ROUTINES.md
  intro/LOOP.md
  intro/CLOUDFLARE.md
  GROKBOT.md
  README.md
  SECURITY.md
  modules/README.md
)

for f in "${required[@]}"; do
  [ -s "$f" ] || no "missing or empty: $f"
done
ok "intro entry files exist"

for bot in intro/bots/setup-guide.md intro/bots/manager.md intro/bots/build-watcher.md; do
  mapfile -t heads < <(grep '^## ' "$bot" | head -2)
  [ "${#heads[@]}" -eq 2 ] || no "$bot needs two opening sections"
  [ "${heads[0]}" = "## What I need from you" ] || no "$bot opens with '${heads[0]}'"
  [ "${heads[1]}" = "## What I do / don't do" ] || no "$bot second section is '${heads[1]}'"
done
ok "intro bots open with the two required sections"

modules=(claude-code-loop journey-keeper codegraph redteam lab-monitor)
for m in "${modules[@]}"; do
  [ -d "modules/$m" ] || no "missing module directory: $m"
  [ -s "modules/$m/MODULE.md" ] || no "missing modules/$m/MODULE.md"
  while IFS= read -r heading; do
    grep -q "^${heading}$" "modules/$m/MODULE.md" || no "modules/$m/MODULE.md missing heading: $heading"
  done <<'HEADINGS'
## What it adds
## What it needs
## What it replaces
## How a bot enables it
## How to turn it off
## Files
## Changelog
HEADINGS
done
ok "each module has a complete MODULE.md"

found=0
for d in modules/*/; do
  found=$((found + 1))
  [ -s "${d}MODULE.md" ] || no "$d has no MODULE.md"
done
[ "$found" -eq "${#modules[@]}" ] || no "expected ${#modules[@]} modules, found $found"
ok "no extra module directory"

for gone in bots loop redteam brain; do
  [ ! -e "$gone" ] || no "old root path still present: $gone"
done
ok "old root paths are gone"

if grep -RInE -i 'systemd|ollama|init\.sh|terminal' intro GROKBOT.md >/dev/null; then
  grep -RInE -i 'systemd|ollama|init\.sh|terminal' intro GROKBOT.md >&2 || true
  no "intro copy mentions an advanced-only tool"
fi
ok "intro copy stays on the Intro tier"

intro_readme=$(awk 'BEGIN{p=1} /^## Advanced/{p=0} p' README.md)
if printf '%s\n' "$intro_readme" | grep -E -i -q 'systemd|ollama|init\.sh|terminal'; then
  no "README intro section mentions an advanced-only tool"
fi
printf '%s\n' "$intro_readme" | grep -q 'Read GROKBOT.md in <repo URL> and set me up' \
  || no "README is missing the sentence for Grok Bot"
grep -q 'modules/README.md' README.md || no "README does not link to modules"
ok "README leads with the Intro and links to modules"

for heading in "Starting another project" "Adding a module later"; do
  grep -q "^## ${heading}$" GROKBOT.md || no "GROKBOT.md missing section: ${heading}"
done
grep -q 'docs/journey.md' GROKBOT.md || no "GROKBOT.md does not record docs/journey.md"
grep -q 'docs/project.md' GROKBOT.md || no "GROKBOT.md does not record the project brief"
ok "GROKBOT.md is the primary-bot onboarding manual"

echo "all $pass structure tests passed"
