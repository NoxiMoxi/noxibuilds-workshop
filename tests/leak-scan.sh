#!/usr/bin/env bash
# leak-scan.sh - fail if the kit contains secrets or private identifiers.
#
#   tests/leak-scan.sh [DIR]          scan DIR (default: the kit root)
#   LEAK_TERMS_FILE=~/my-terms.txt    also fail on these words (one per line, case-insensitive).
#                                     Keep that file OUTSIDE the repo: it holds the private names you are guarding.
#   LEAK_TERMS_ALLOW='regex'          term hits matching this ERE are allowed (e.g. your own public repo URL).
set -euo pipefail
ROOT=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
cd "$ROOT"

files() { find . -path ./.git -prune -o -type f ! -name '*.pyc' -print; }

fail=0
scan() { # $1 label, $2 ERE, [$3 ERE of allowed matches]
  local hits
  hits=$(files | xargs grep -nIoE -- "$2" 2>/dev/null || true)
  if [ -n "${3:-}" ] && [ -n "$hits" ]; then hits=$(printf '%s\n' "$hits" | grep -vE -- "$3" || true); fi
  if [ -n "$hits" ]; then echo "LEAK [$1]:"; printf '%s\n' "$hits" | head -20; fail=1; fi
}

scan "private key"   '-----BEGIN [A-Z ]*PRIVATE KEY-----'
scan "github token"  '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'
scan "api key"       '(sk|rk)-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[abposr]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}'
scan "uuid / machine id" '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
scan "long hex secret" '[0-9a-f]{48,}'
scan "email"         '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' '@(localhost|example\.(com|org)|users\.noreply\.invalid)|:[A-Z_]+@'
scan "url"           'https?://[^ )"`>]+' 'https?://(example\.(com|org)|127\.0\.0\.1|localhost|x\.com/NoxiBuilds$|github\.com/NoxiMoxi/noxibuilds-workshop$|docs\.anthropic\.com/|ollama\.com$|cli\.github\.com$|img\.shields\.io/badge/license-MIT-blue\.svg$|<branch-slug$|<worker$)'
scan "home path"     '/home/[a-z][a-z0-9_-]+|/Users/[A-Za-z][A-Za-z0-9_-]+'

if [ -n "${LEAK_TERMS_FILE:-}" ]; then
  while IFS= read -r term; do
    [ -n "$term" ] && [ "${term#\#}" = "$term" ] || continue
    hits=$(files | xargs grep -nIiF -- "$term" 2>/dev/null || true)
    if [ -n "${LEAK_TERMS_ALLOW:-}" ] && [ -n "$hits" ]; then
      hits=$(printf '%s\n' "$hits" | sed -E "s#${LEAK_TERMS_ALLOW}##g" | grep -iF -- "$term" || true)
    fi
    if [ -n "$hits" ]; then echo "LEAK [term]: $(printf '%s\n' "$hits" | head -5)"; fail=1; fi
  done < "$LEAK_TERMS_FILE"
fi

if [ "$fail" = 0 ]; then echo "leak-scan: clean ($(files | wc -l | tr -d ' ') files)"; fi
exit "$fail"
