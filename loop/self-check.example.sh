#!/usr/bin/env bash
# self-check.sh - the G4 gate for one project. Copy, then replace the two commands below with your
# project's lint and test runners. Run from the worktree root.
#
#   self-check.sh --full                      lint everything + the whole default test suite
#   self-check.sh --partial -- tests/a tests/b lint + only the named test files (non-final slices)
#
# Rules this script enforces for the loop:
#   - --partial accepts only paths under a tests directory: no flags, no `..`, no bare directory.
#   - Slow or environment-bound suites (end-to-end, live services) are deselected by default and never run here.
#   - Exit 0 only when everything passed.
set -euo pipefail

LINT_CMD=(echo "configure LINT_CMD in self-check.sh")     # e.g. (ruff check .)  or  (npm run -s lint)
TEST_CMD=(echo "configure TEST_CMD in self-check.sh")     # e.g. (pytest -q -m "not e2e")  or  (npm test --)

mode=${1:-}
case "$mode" in
  --full)
    "${LINT_CMD[@]}"
    "${TEST_CMD[@]}"
    ;;
  --partial)
    shift
    [ "${1:-}" = -- ] || { echo "self-check: --partial needs -- <test files>" >&2; exit 2; }
    shift
    [ "$#" -gt 0 ] || { echo "self-check: --partial needs at least one test file" >&2; exit 2; }
    for p in "$@"; do
      case "$p" in
        -*|*..*) echo "self-check: refusing argument: $p" >&2; exit 2 ;;
        tests/*|*/tests/*|test/*|*/test/*) [ -f "$p" ] || { echo "self-check: not a file: $p" >&2; exit 2; } ;;
        *) echo "self-check: only test files are allowed: $p" >&2; exit 2 ;;
      esac
    done
    "${LINT_CMD[@]}"
    "${TEST_CMD[@]}" "$@"
    ;;
  *) echo "usage: $0 --full | --partial -- <test files>" >&2; exit 2 ;;
esac
