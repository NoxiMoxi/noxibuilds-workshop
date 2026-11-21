#!/usr/bin/env bash
# init.sh - scaffold a new project for the multi-bot build loop.
#
#   ./init.sh <project-name> [--root DIR] [--dry-run]
#
# Creates <root>/<project-name>/ with its own review-log repo (brain docs, queue, briefs), loop config,
# watcher copy, self-check stub and a systemd USER unit file named <project-name>-claude-watch.service.
# Everything is namespaced by the project name, so two projects can never share paths, state or units.
#
# Safety:
#   - Refuses if <root>/<project-name> exists or a unit with that name is already installed.
#   - Builds in a temp dir and moves it into place in one step, so a failure leaves nothing half-made.
#   - Never installs, enables or starts anything. It prints the exact next steps instead.
#   - --dry-run prints every action and changes nothing (safe to run any number of times).
#
# Env (mostly for tests): SYSTEMD_USER_DIR (default ~/.config/systemd/user), PK_SKIP_SYSTEMCTL=1,
# PK_PIECE_USD (5), PK_SLICE_USD (2), PK_BRIEF_BYTES (20480).
set -euo pipefail

KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="${HOME}/projects"
DRY=0
NAME=""

die() { echo "init.sh: $*" >&2; exit "${2:-1}"; }
usage() { sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || die "--root needs a directory" 2; ROOT=$2; shift 2 ;;
    --root=*) ROOT=${1#--root=}; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" 2 ;;
    *) [ -z "$NAME" ] || die "only one project name" 2; NAME=$1; shift ;;
  esac
done

[ -n "$NAME" ] || { usage >&2; exit 2; }
[[ $NAME =~ ^[a-z][a-z0-9-]{1,38}$ ]] || die "project name must match ^[a-z][a-z0-9-]{1,38}$ (got '$NAME')" 2
[[ $NAME != *- ]] || die "project name must not end with '-'" 2
case "$ROOT" in /*) ;; *) ROOT="$(pwd)/$ROOT" ;; esac
ROOT=${ROOT%/}

PROJECT_DIR=$ROOT/$NAME
UNIT=$NAME-claude-watch.service
UNIT_DIR=${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}
PIECE_USD=${PK_PIECE_USD:-5}
SLICE_USD=${PK_SLICE_USD:-2}
BRIEF_BYTES=${PK_BRIEF_BYTES:-20480}

# --- refuse to collide -----------------------------------------------------------------------------------
[ ! -e "$PROJECT_DIR" ] || die "$PROJECT_DIR already exists; refusing to overwrite (pick another name or --root)" 3
[ ! -e "$UNIT_DIR/$UNIT" ] || die "unit $UNIT_DIR/$UNIT already exists; refusing to overwrite" 3
if [ "${PK_SKIP_SYSTEMCTL:-0}" != 1 ] && command -v systemctl >/dev/null 2>&1; then
  if systemctl --user list-unit-files "$UNIT" --no-legend 2>/dev/null | grep -q "^$UNIT"; then
    die "systemd already knows a user unit named $UNIT; refusing" 3
  fi
fi
for f in queue-watch.sh self-check.example.sh _loop.md.template brief.template.md claude-queue.md.template \
         loop.env.example notify.env.example claude-watch.service.template F0.1.brief.md.template; do
  [ -f "$KIT_DIR/loop/$f" ] || die "kit file missing: loop/$f (run init.sh from a full kit checkout)"
done

# --- the plan --------------------------------------------------------------------------------------------
# Each entry: "<kind>|<kit source or ->|<destination relative to the project dir>"
PLAN=(
  "dir|-|review-log/docs/brain"
  "dir|-|review-log/docs/briefs"
  "dir|-|review-log/docs/review-log"
  "dir|-|loop/bin"
  "dir|-|state"
  "tpl|brain/START.md.template|review-log/docs/brain/START.md"
  "tpl|brain/rules.md.template|review-log/docs/brain/rules.md"
  "tpl|brain/journey.md.template|review-log/docs/brain/journey.md"
  "tpl|brain/decisions.md.template|review-log/docs/brain/decisions.md"
  "tpl|brain/review-log.md.template|review-log/docs/brain/review-log.md"
  "tpl|loop/claude-queue.md.template|review-log/docs/claude-queue.md"
  "tpl|loop/_loop.md.template|review-log/docs/briefs/_loop.md"
  "tpl|loop/brief.template.md|review-log/docs/briefs/TEMPLATE.md"
  "tpl|loop/F0.1.brief.md.template|review-log/docs/briefs/F0.1.md"
  "tpl|loop/loop.env.example|loop/loop.env"
  "cpy|loop/notify.env.example|loop/notify.env"
  "tpl|loop/claude-watch.service.template|loop/$UNIT"
  "exe|loop/queue-watch.sh|loop/bin/queue-watch.sh"
  "exe|loop/self-check.example.sh|loop/bin/self-check.sh"
  "git|-|review-log (git init, branch review-log, first commit)"
)

say() { printf '%s\n' "$*"; }
if [ "$DRY" = 1 ]; then
  say "DRY RUN - nothing will be created."
  say "project:  $NAME"
  say "dir:      $PROJECT_DIR"
  say "unit:     $UNIT (file only, written to $PROJECT_DIR/loop/; not installed)"
  for p in "${PLAN[@]}"; do
    IFS='|' read -r kind src dst <<< "$p"
    case "$kind" in
      dir) say "mkdir    $PROJECT_DIR/$dst" ;;
      tpl) say "render   $src -> $PROJECT_DIR/$dst" ;;
      cpy) say "copy     $src -> $PROJECT_DIR/$dst (chmod 600)" ;;
      exe) say "install  $src -> $PROJECT_DIR/$dst (chmod 755)" ;;
      git) say "git      $PROJECT_DIR/$dst" ;;
    esac
  done
  say "OK: dry run passed all collision checks."
  exit 0
fi

# --- build in a temp dir, then move into place in one step -----------------------------------------------
mkdir -p "$ROOT"
TMP=$(mktemp -d "$ROOT/.${NAME}.init.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

esc() { printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'; }
render() { # $1 src (kit-relative), $2 dst (absolute)
  sed -e "s|@PROJECT@|$(esc "$NAME")|g" \
      -e "s|@PROJECT_DIR@|$(esc "$PROJECT_DIR")|g" \
      -e "s|@SELF_CHECK@|$(esc "$PROJECT_DIR/loop/bin/self-check.sh")|g" \
      -e "s|@PIECE_USD@|$(esc "$PIECE_USD")|g" \
      -e "s|@SLICE_USD@|$(esc "$SLICE_USD")|g" \
      -e "s|@BRIEF_BYTES@|$(esc "$BRIEF_BYTES")|g" \
      "$KIT_DIR/$1" > "$2"
}

for p in "${PLAN[@]}"; do
  IFS='|' read -r kind src dst <<< "$p"
  case "$kind" in
    dir) mkdir -p "$TMP/$dst" ;;
    tpl) render "$src" "$TMP/$dst" ;;
    cpy) cp "$KIT_DIR/$src" "$TMP/$dst"; chmod 600 "$TMP/$dst" ;;
    exe) cp "$KIT_DIR/$src" "$TMP/$dst"; chmod 755 "$TMP/$dst" ;;
    git) ;;
  esac
done
chmod 600 "$TMP/loop/loop.env"
sed -i "s|^LOOP_PIECE_BUDGET_USD=.*|LOOP_PIECE_BUDGET_USD=$PIECE_USD|; s|^LOOP_SLICE_BUDGET_USD=.*|LOOP_SLICE_BUDGET_USD=$SLICE_USD|; s|^LOOP_BRIEF_MAX_BYTES=.*|LOOP_BRIEF_MAX_BYTES=$BRIEF_BYTES|" "$TMP/loop/loop.env"
touch "$TMP/review-log/docs/review-log/.gitkeep"
printf 'notify.env\n*.env\n' > "$TMP/review-log/.gitignore"

gitc() {
  local args=()
  git config user.name >/dev/null 2>&1 || args+=(-c user.name=project-kit)
  git config user.email >/dev/null 2>&1 || args+=(-c user.email=project-kit@localhost)
  git -C "$TMP/review-log" "${args[@]}" "$@"
}
gitc init -q -b review-log
gitc add -A
gitc commit -q -m "init: scaffold $NAME review-log (project-kit)"

mv -T "$TMP" "$PROJECT_DIR"
trap - EXIT

cat <<NEXT
Created $PROJECT_DIR

Nothing was installed, enabled or started. Next steps:

  1. Write the owner's journeys:   \$EDITOR $PROJECT_DIR/review-log/docs/brain/journey.md
     (the journey interview comes first; every spec cites this file)
  2. Fill START.md and rules.md:   $PROJECT_DIR/review-log/docs/brain/
  3. Configure the loop:           \$EDITOR $PROJECT_DIR/loop/loop.env
       LOOP_APP_REPO=<path to your app clone>   LOOP_CLAUDE_BIN=\$(command -v claude)
       LOOP_CLAUDE_FLAGS=<your permission allowlist>
  4. Make the gate real:           \$EDITOR $PROJECT_DIR/loop/bin/self-check.sh   (LINT_CMD, TEST_CMD)
  5. Optional webhook:             set LOOP_NOTIFY_URL in loop.env, LOOP_NOTIFY_KEY in loop/notify.env (chmod 600)
  6. Preview the first run:        LOOP_CONFIG=$PROJECT_DIR/loop/loop.env $PROJECT_DIR/loop/bin/queue-watch.sh --plan
  7. Install the watcher (after your lab owner / Lab Warden approves):
       mkdir -p $UNIT_DIR
       cp $PROJECT_DIR/loop/$UNIT $UNIT_DIR/
       systemctl --user daemon-reload
       systemctl --user enable --now $UNIT
     The first start only records a baseline. To run F0.1, flip it to status \`open\` in
     docs/claude-queue.md and commit on the review-log branch.
  8. Give each bot its persona from the kit's bots/ folder, pointed at $PROJECT_DIR/review-log/docs/brain/START.md
NEXT
