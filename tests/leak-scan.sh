#!/usr/bin/env bash
# leak-scan.sh - fail if the kit contains secrets or private identifiers.
#
#   tests/leak-scan.sh [DIR]          scan DIR (default: the kit root)
#   LEAK_TERMS_FILE=~/my-terms.txt    also fail on these words (one per line, case-insensitive).
#                                     Keep that file OUTSIDE the repo: it holds the private names you are guarding.
#   LEAK_TERMS_ALLOW='regex'          term hits matching this ERE are allowed (e.g. your own public repo URL).
#
# A hit is printed as file:line only. The matched text stays out of the output, so a
# secret or a private term cannot be copied into a log. Open that line to see it.
set -euo pipefail
ROOT=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
cd "$ROOT"

files() { find . -path ./.git -prune -o -type f ! -name '*.pyc' -print; }

# grep -nH writes "file:line:text". Keep file:line. Never print the text.
locations() {
  awk -F: '
    /^[^:]+:[0-9]+:/ {
      loc = $1 ":" $2
      if (!seen[loc]++ && ++n <= 20) print loc
      next
    }
    NF { if (!seen["unparsed-hit"]++) print "unparsed-hit" }
  '
}

fail=0
scan() { # $1 label, $2 ERE, [$3 ERE of allowed matches]
  local hits locs
  hits=$(files | xargs grep -nHIoE -- "$2" 2>/dev/null || true)
  if [ -n "${3:-}" ] && [ -n "$hits" ]; then
    hits=$(printf '%s\n' "$hits" | grep -vE -- "$3" || true)
  fi
  if [ -n "$hits" ]; then
    locs=$(printf '%s\n' "$hits" | locations)
    if [ -n "$locs" ]; then
      printf 'LEAK [%s]:\n%s\n' "$1" "$locs"
    else
      printf 'LEAK [%s]: hit could not be reduced to file:line\n' "$1"
    fi
    fail=1
  fi
}

scan "private key"   '-----BEGIN [A-Z ]*PRIVATE KEY-----'
scan "github token"  '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'
scan "api key"       '(sk|rk)-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[abposr]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}'
scan "uuid / machine id" '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
scan "long hex secret" '[0-9a-f]{48,}'
scan "email"         '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' '@(localhost|example\.(com|org)|users\.noreply\.invalid)|:[A-Z_]+@'
# Pricing pages the Intro links so a reader can check the paid plan.
# The public repo URL is allowed at its root and at the checks badge.
scan "url"           'https?://[^ )"`>]+' 'https?://(example\.(com|org)|127\.0\.0\.1|localhost|x\.com/NoxiBuilds$|github\.com/NoxiMoxi/noxibuilds-workshop($|/actions/workflows/checks\.yml(/badge\.svg)?$)|docs\.anthropic\.com/|ollama\.com$|cli\.github\.com$|img\.shields\.io/badge/license-MIT-blue\.svg$|raw\.githubusercontent\.com/colbymchenry/codegraph/main/install\.sh$|cursor\.com/pricing$|cursor\.com/docs/cloud-agent$|docs\.x\.ai/x-subscription/pricing$|<branch-slug$|<worker$)'
scan "home path"     '/home/[a-z][a-z0-9_-]+|/Users/[A-Za-z][A-Za-z0-9_-]+'

if [ -n "${LEAK_TERMS_FILE:-}" ]; then
  if [ ! -r "$LEAK_TERMS_FILE" ]; then
    echo "leak-scan: cannot read LEAK_TERMS_FILE" >&2
    exit 1
  fi
  term_locs=""
  while IFS= read -r term || [ -n "$term" ]; do
    term=${term%$'\r'}
    if [ -z "$term" ] || [ "${term#\#}" != "$term" ]; then
      continue
    fi
    hits=$(files | xargs grep -nHIiF -- "$term" 2>/dev/null || true)
    if [ -n "${LEAK_TERMS_ALLOW:-}" ] && [ -n "$hits" ]; then
      hits=$(printf '%s\n' "$hits" | sed -E "s#${LEAK_TERMS_ALLOW}##g" | grep -iF -- "$term" || true)
    fi
    if [ -n "$hits" ]; then
      reduced=$(printf '%s\n' "$hits" | locations)
      if [ -n "$reduced" ]; then
        term_locs+="$reduced"$'\n'
      else
        term_locs+="unparsed-hit"$'\n'
      fi
    fi
  done < "$LEAK_TERMS_FILE"
  if [ -n "$term_locs" ]; then
    locs=$(printf '%s\n' "$term_locs" | awk '($0 ~ /^[^:]+:[0-9]+$/ || $0 == "unparsed-hit") && !seen[$0]++ && ++n <= 20')
    if [ -n "$locs" ]; then
      printf 'LEAK [private term]:\n%s\n' "$locs"
    else
      echo "LEAK [private term]: hit could not be reduced to file:line"
    fi
    fail=1
  fi
fi

if [ "$fail" = 0 ]; then echo "leak-scan: clean ($(files | wc -l | tr -d ' ') files)"; fi
exit "$fail"
