#!/usr/bin/env bash
# queue-watch.sh - start a headless Claude Code run when the top `open` task in the queue changes.
#
#   queue-watch.sh           watch the review-log (what the systemd user unit runs)
#   queue-watch.sh --check   one check now, then exit (same code path as a watch event)
#   queue-watch.sh --plan    print what the next run would be (slice, model, budget, prompt size); runs nothing
#
# Configuration comes from the file named by $LOOP_CONFIG (shell syntax, re-read before every check, so edits
# take effect without a restart). See modules/claude-code-loop/loop/loop.env.example for every key. Nothing is hardcoded: project name,
# paths, models, budgets, brief size cap and the notification webhook all come from config or env.
#
# WHY events, not a timer: the loop should cost zero model calls while idle. inotify costs nothing until a file
# is written; a timer wakes all day.
#
# How one queue change becomes (at most) one chain of runs:
#   1. inotifywait watches the docs/ DIRECTORY (git replaces files by rename, so a watch on the file itself is
#      lost after the first commit) AND the review-log branch's ref directory (a commit moves the ref but does not
#      always rewrite docs/).
#   2. Debounce: wait until LOOP_DEBOUNCE seconds pass with no further event.
#   3. Fire only on a real change: the top `open` task section of the COMMITTED queue at HEAD is hashed and
#      compared with $STATE/last-task.sha. Claude's prompt is built from that same commit, so what was hashed is
#      what runs. Uncommitted edits change nothing.
#   4. One run at a time (flock -n run.lock). An event during a run sets `pending`; the run re-checks after.
#   5. Safety stop: more than LOOP_MAX_STARTS attempts at one task hash logs `needs-owner` and runs nothing.
#   6. First start ever: the current top task is recorded as the baseline and NOT run, so installing the unit
#      never starts Claude by itself.
#
# Micro-slice chain (one piece = one draft PR, built as small slices):
#   - The first piece bullet in the open section that carries `brief:` and `branch: task/...` is the piece.
#     Optional `slices: a,b,c`; without it the piece is one slice.
#   - The prompt is docs/briefs/_loop.md + the slice brief, read from the hashed commit, at most
#     LOOP_BRIEF_MAX_BYTES (default 20480). Claude never reads the queue itself.
#   - The watcher picks the next slice: the first one in `slices:` without a passed-gate record whose sha is
#     still on origin/<branch>. A restart resumes there.
#   - After every slice, a zero-token gate (see modules/claude-code-loop/loop/GATES.md): G0 LOOP line, G1 clean+pushed on the branch,
#     G2 new commits (trailer warn-only), G3 line caps + may_touch scope, G4 self-check (partial on non-final
#     slices, full on the final slice). One fix run per slice on G1-G4 failure; a second failure stops.
#   - Budget: each slice gets min(LOOP_SLICE_BUDGET_USD, piece budget left). The piece shares
#     LOOP_PIECE_BUDGET_USD. Spend is tracked in $STATE/cost/<piece>.txt from the stream's exact totals.
#
# Notification: when a chain ends (done, blocked, limit, needs-owner, error) and LOOP_NOTIFY_URL is set, a
# small JSON payload is POSTed there. The key (LOOP_NOTIFY_KEY, usually from the chmod-600 file named by
# LOOP_NOTIFY_ENV) is sent as a Bearer header through curl's stdin config, never on argv. Failures are logged,
# never fatal.
#
# Log lines (UTC) go to $STATE/last-run.log:  <time> task=<id> sha=<12> <event> [k=v ...]
# Per run, $STATE/runs/ keeps <ts>-<slice>.jsonl (raw stream), .err (stderr) and .gate.txt (gate output).
set -euo pipefail

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; }

MODE=watch
case "${1:-}" in
  --check) MODE=check ;;
  --plan) MODE=plan ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

: "${LOOP_CONFIG:?set LOOP_CONFIG to the project loop.env (see loop/loop.env.example)}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "queue-watch: missing dependency: $1" >&2; exit 3; }; }
need git; need jq; need flock; need awk
[ "$MODE" != watch ] || need inotifywait

load_config() {
  [ -r "$LOOP_CONFIG" ] || { echo "queue-watch: cannot read LOOP_CONFIG=$LOOP_CONFIG" >&2; exit 3; }
  # shellcheck disable=SC1090
  source "$LOOP_CONFIG"
  : "${LOOP_PROJECT:?LOOP_PROJECT is not set in $LOOP_CONFIG}"
  : "${LOOP_DOCS:?LOOP_DOCS is not set}" "${LOOP_STATE:?LOOP_STATE is not set}" "${LOOP_WT:?LOOP_WT is not set}"
  [[ $LOOP_PROJECT =~ ^[a-z][a-z0-9-]{1,38}$ ]] || { echo "queue-watch: bad LOOP_PROJECT '$LOOP_PROJECT'" >&2; exit 3; }
  LOOP_APP_REPO=${LOOP_APP_REPO:-}
  LOOP_MAIN_BRANCH=${LOOP_MAIN_BRANCH:-main}
  LOOP_QUEUE=${LOOP_QUEUE:-claude-queue.md}
  LOOP_CLAUDE_BIN=${LOOP_CLAUDE_BIN:-}
  LOOP_CLAUDE_FLAGS=${LOOP_CLAUDE_FLAGS:-}
  LOOP_MODEL_SECURITY=${LOOP_MODEL_SECURITY-opus}
  LOOP_MODEL_FEATURE=${LOOP_MODEL_FEATURE-sonnet}
  LOOP_PIECE_BUDGET_USD=${LOOP_PIECE_BUDGET_USD:-5}
  LOOP_SLICE_BUDGET_USD=${LOOP_SLICE_BUDGET_USD:-2}
  LOOP_BRIEF_MAX_BYTES=${LOOP_BRIEF_MAX_BYTES:-20480}
  LOOP_MAX_STARTS=${LOOP_MAX_STARTS:-4}
  LOOP_DEBOUNCE=${LOOP_DEBOUNCE:-20}
  LOOP_DEFAULT_MAX_LINES=${LOOP_DEFAULT_MAX_LINES:-300}
  LOOP_DEFAULT_MAX_TEST_LINES=${LOOP_DEFAULT_MAX_TEST_LINES:-120}
  LOOP_SELF_CHECK=${LOOP_SELF_CHECK:-}
  LOOP_TEST_PATH_REGEX=${LOOP_TEST_PATH_REGEX:-'(^|/)tests?/|(^|/)test_[^/]*$|_test\.[a-z]+$|\.(test|spec)\.[a-z]+$'}
  LOOP_SECURITY_KEYWORDS=${LOOP_SECURITY_KEYWORDS:-'security|auth|sign-?in|login|permission|rls|migration|audit|egress|sandbox|secret|fix round|debug'}
  LOOP_NOTIFY_URL=${LOOP_NOTIFY_URL:-}
  LOOP_NOTIFY_KEY=${LOOP_NOTIFY_KEY:-}
  if [ -n "${LOOP_NOTIFY_ENV:-}" ] && [ -r "$LOOP_NOTIFY_ENV" ]; then
    # shellcheck disable=SC1090
    source "$LOOP_NOTIFY_ENV"
  fi
  DOCS=${LOOP_DOCS%/}
  STATE=${LOOP_STATE%/}
  mkdir -p "$STATE/starts" "$STATE/runs" "$STATE/passed" "$STATE/cost" "$STATE/gate"
  LOG=$STATE/last-run.log
  PREFIX=$(git -C "$DOCS" rev-parse --show-prefix)
  BRANCH=$(git -C "$DOCS" symbolic-ref --short HEAD) \
    || { echo "queue-watch: $DOCS is on a detached HEAD; check out the review-log branch" >&2; exit 3; }
  REF=$(git -C "$DOCS" rev-parse --path-format=absolute --git-common-dir)/refs/heads/$BRANCH
  REFDIR=$(dirname "$REF")
}

log() {
  local line
  line="$(date -u '+%FT%TZ') $*"
  printf '%s\n' "$line" >> "$LOG"
  [ "$MODE" = watch ] || printf '%s\n' "$line" >&2
}

# --- notification ----------------------------------------------------------------------------------------
notify() { # $1 event, $2 task, $3 slice, $4 detail
  [ -n "$LOOP_NOTIFY_URL" ] || return 0
  command -v curl >/dev/null 2>&1 || { log "task=$2 notify skipped (no curl)"; return 0; }
  local payload
  payload=$(mktemp "$STATE/notify.XXXXXX")
  jq -n --arg project "$LOOP_PROJECT" --arg event "$1" --arg task "$2" --arg slice "$3" --arg detail "$4" \
        --arg log "$LOG" '{project:$project, event:$event, task:$task, slice:$slice, detail:$detail, log:$log}' \
        > "$payload"
  # The key travels on curl's stdin config, so it never appears in argv or `ps`.
  if ! { [ -n "$LOOP_NOTIFY_KEY" ] && printf 'header = "Authorization: Bearer %s"\n' "$LOOP_NOTIFY_KEY"; } \
       | curl -fsS --max-time 15 --config - -H 'Content-Type: application/json' \
              --data-binary "@$payload" "$LOOP_NOTIFY_URL" >/dev/null 2>&1; then
    log "task=$2 notify failed event=$1"
  fi
  rm -f "$payload"
}

# --- queue parsing ---------------------------------------------------------------------------------------
# The first `## ` section whose heading says status `open`, verbatim. Reads all input (no early exit), so
# `git show | top_open_task` never dies of SIGPIPE under pipefail.
top_open_task() { awk '/^## /{ if (found) done=1; else if (index($0, "status: `open`")) found=1 } found && !done'; }

# id of the section: first word after `## `, trailing colon dropped.
task_id() { sed -n '1s/^## \([^ :]*\).*/\1/p'; }

# `<name>: <value>` on a line (backticks optional), "" when absent.
field() { printf '%s\n' "$2" | grep -oE "$1: *\`?[A-Za-z0-9._/,*-]+" | head -1 | sed -E "s/^$1: *\`?//" || true; }

# First open piece bullet that has a brief: `- **<id>** ... brief: docs/briefs/<id>.md branch: task/...`.
first_piece() {
  local head line id
  head=$(printf '%s\n' "$1" | sed -n 1p)
  while IFS='' read -r line; do
    id=$(printf '%s\n' "$line" | sed -nE 's/^- \*\*([A-Za-z0-9._-]+)\*\*.*/\1/p')
    [ -n "$id" ] || continue
    printf '%s\n' "$head" | grep -qF "$id closed" && continue
    printf '%s\n' "$line" | grep -qE 'status: `(closed|re-split)' && continue
    printf '%s\n' "$line"; return 0
  done < <(printf '%s\n' "$1" | grep -E '^- \*\*[A-Za-z0-9._-]+\*\*.*brief: *`?[^ ]*briefs/' || true)
  return 0
}

# Model: explicit `[model: x]` / `[tier: x]` tag on the bullet > security keyword > feature model.
pick_model() {
  local line=$1 tag
  tag=$(printf '%s\n' "$line" | grep -oiE '(model|tier): *[A-Za-z0-9._-]+' | head -1 | tr '[:upper:]' '[:lower:]' | tr -d ' ' || true)
  case "$tag" in
    model:opus|tier:security|tier:fix|tier:debug) echo "$LOOP_MODEL_SECURITY"; return ;;
    model:sonnet|tier:feature) echo "$LOOP_MODEL_FEATURE"; return ;;
    model:*) echo "${tag#model:}"; return ;;
  esac
  if printf '%s\n' "$line" | grep -qiE "$LOOP_SECURITY_KEYWORDS"; then echo "$LOOP_MODEL_SECURITY"; else echo "$LOOP_MODEL_FEATURE"; fi
}

brief_value() { printf '%s\n' "$2" | sed -nE "s/^$1: *\`?([^\` #]+).*/\1/p" | head -1; }
brief_globs() { printf '%s\n' "$1" | awk '/^may_touch:/ {on=1; next} on && /^ *- / {sub(/^ *- */, ""); sub(/ *#.*/, ""); gsub(/`/, ""); print; next} on {exit}'; }

# --- app repo helpers ------------------------------------------------------------------------------------
app() { git -C "$LOOP_APP_REPO" "$@"; }
remote_head() { app fetch -q origin "$1" 2>/dev/null || true; app rev-parse -q --verify "refs/remotes/origin/$1" 2>/dev/null || true; }

# First slice of the comma list $2 (piece $1, branch $3) without a passed-gate record still on origin/<branch>.
next_slice() {
  local piece=$1 slices=$2 branch=$3 s ps psha rec=$STATE/passed/$1.txt d
  [ -z "$LOOP_APP_REPO" ] || app fetch -q origin "$branch" 2>/dev/null || true
  for s in ${slices//,/ }; do
    d=
    if [ -f "$rec" ] && [ -n "$LOOP_APP_REPO" ]; then
      while read -r ps psha _; do
        [ "$ps" = "$s" ] && [[ $psha =~ ^[0-9a-f]{40}$ ]] \
          && app merge-base --is-ancestor "$psha" "refs/remotes/origin/$branch" 2>/dev/null && { d=1; break; }
      done < "$rec"
    fi
    [ -n "$d" ] || { echo "$s"; return 0; }
  done
  return 0   # all slices done: print nothing
}

spent() { [ -f "$STATE/cost/$1.txt" ] && awk '{s+=$1} END{printf "%.4f", s+0}' "$STATE/cost/$1.txt" || echo 0; }

ensure_worktree() {
  [ -n "$LOOP_APP_REPO" ] || { log "task=$1 not-configured LOOP_APP_REPO is empty"; return 1; }
  [ -d "$LOOP_WT" ] && return 0
  app fetch -q origin "$LOOP_MAIN_BRANCH"
  app worktree add -q --detach "$LOOP_WT" "refs/remotes/origin/$LOOP_MAIN_BRANCH"
  log "task=$1 worktree added $LOOP_WT (detached at origin/$LOOP_MAIN_BRANCH)"
}

# "<app lines> <test lines>" changed between $1 and $2 in the worktree. Binary files count 0.
diff_split() {
  git -C "$LOOP_WT" diff --numstat "$1" "$2" | awk -F'\t' -v re="$LOOP_TEST_PATH_REGEX" '
    { a = ($1 == "-") ? 0 : $1; d = ($2 == "-") ? 0 : $2; p = $3
      if (p ~ / => /) { sub(/[{][^}]* => /, "{", p); gsub(/[{}]/, "", p); sub(/.* => /, "", p) }
      if (p ~ re) t += a + d; else s += a + d }
    END { print s + 0, t + 0 }'
}

# --- gate G1-G4 (zero model tokens). Prints the failure, rc 1; silent rc 0 on pass. -----------------------
gate() { # $1 slice, $2 branch, $3 base sha, $4 brief, $5 final(yes|no), $6 fix-run(1|"")
  local slice=$1 branch=$2 prev=$3 brief=$4 final=$5 fixrun=$6 head max tmax n nt globs bad f g ok tests=()
  if [ -n "$(git -C "$LOOP_WT" status --porcelain | head -1)" ]; then
    echo "G1 uncommitted files: $(git -C "$LOOP_WT" status --porcelain | head -8 | tr '\n' ' ')"; return 1
  fi
  [ "$(git -C "$LOOP_WT" symbolic-ref -q --short HEAD || true)" = "$branch" ] \
    || { echo "G1 the worktree is not on $branch"; return 1; }
  head=$(git -C "$LOOP_WT" rev-parse HEAD)
  [ "$head" = "$(remote_head "$branch")" ] || { echo "G1 HEAD ${head:0:12} is not pushed to origin/$branch"; return 1; }
  [ -n "$prev" ] || prev=$(git -C "$LOOP_WT" merge-base HEAD "refs/remotes/origin/$LOOP_MAIN_BRANCH")
  if [ "$prev" = "$head" ]; then
    [ -n "$fixrun" ] || { echo "G2 no new commit for $slice"; return 1; }
    log "slice=$slice G2 waived on fix run: head ${head:0:12} must still pass G3/G4"
  fi
  bad=$(git -C "$LOOP_WT" log --format='%h %(trailers:key=Piece,valueonly,separator=%x2C)' "$prev..$head" \
        | awk -v s="$slice" '$2 != s || NF != 2' | head -5)
  [ -z "$bad" ] || log "slice=$slice G2 warn commits without exactly 'Piece: $slice': $(printf '%s' "$bad" | tr '\n' ' ')"
  max=$(brief_value max_changed_lines "$brief"); max=${max:-$LOOP_DEFAULT_MAX_LINES}
  tmax=$(brief_value max_test_lines "$brief"); tmax=${tmax:-$LOOP_DEFAULT_MAX_TEST_LINES}
  read -r n nt < <(diff_split "$prev" "$head")
  log "slice=$slice g3 app_lines=$n test_lines=$nt max_changed_lines=$max max_test_lines=$tmax"
  [ "$n" -le "$max" ] || { echo "G3 $n app lines > max_changed_lines $max"; return 1; }
  [ "$nt" -le "$tmax" ] || { echo "G3 $nt test lines > max_test_lines $tmax"; return 1; }
  globs=$(brief_globs "$brief")
  [ -n "$globs" ] || { echo "G3 the brief has no may_touch: list"; return 1; }
  bad=
  while IFS='' read -r f; do
    [ -n "$f" ] || continue
    ok=
    if [[ $f =~ $LOOP_TEST_PATH_REGEX ]]; then ok=1; tests+=("$f"); fi
    if [ -z "$ok" ]; then
      while IFS='' read -r g; do
        # shellcheck disable=SC2053  # $g is a glob on purpose
        if [[ $f == $g ]]; then ok=1; break; fi
      done <<< "$globs"
    fi
    [ -n "$ok" ] || bad="$bad $f"
  done < <(git -C "$LOOP_WT" diff --name-only "$prev" "$head")
  [ -z "$bad" ] || { echo "G3 files outside may_touch:$bad" | cut -c1-800; return 1; }
  # G4: a full self-check result for this exact sha is reused; partial results never are.
  [ -n "$LOOP_SELF_CHECK" ] || { echo "G4 LOOP_SELF_CHECK is not configured"; return 1; }
  if [ -f "$STATE/gate/$head.full" ]; then log "slice=$slice g4 reuse full $head"; return 0; fi
  if [ "$final" = yes ] || [ "${#tests[@]}" -eq 0 ]; then
    (cd "$LOOP_WT" && "$LOOP_SELF_CHECK" --full) > "$STATE/gate/$head.log" 2>&1 \
      || { echo "G4 full self-check failed: $(tail -n 20 "$STATE/gate/$head.log" | cut -c1-200)" | head -c 2000; return 1; }
    touch "$STATE/gate/$head.full"; log "slice=$slice g4 full pass ${head:0:12}"
  else
    (cd "$LOOP_WT" && "$LOOP_SELF_CHECK" --partial -- "${tests[@]}") > "$STATE/gate/$head.partial.log" 2>&1 \
      || { echo "G4 partial self-check failed: $(tail -n 20 "$STATE/gate/$head.partial.log" | cut -c1-200)" | head -c 2000; return 1; }
    log "slice=$slice g4 partial pass ${head:0:12} tests=${#tests[@]}"
  fi
  return 0
}

# --- one chain: every remaining slice of the piece -------------------------------------------------------
stop_chain() { # $1 task, $2 sha, $3 event, $4 slice, $5 detail. The task hash counts as handled.
  log "task=$1 sha=${2:0:12} $3${4:+ slice=$4} $5"
  echo "$2" > "$STATE/last-task.sha"
  notify "$3" "$1" "$4" "$5"
}

run_piece() { # $1 task id, $2 task hash, $3 commit, $4 section
  local id=$1 sha=$2 commit=$3 section=$4 bullet piece branch slices bpath rules brief slice final model
  local prompt bytes left cap fail='' retry='' base rc loop status lpiece cost prev gout ts flags=()
  bullet=$(first_piece "$section")
  [ -n "$bullet" ] || { stop_chain "$id" "$sha" blocked "" "no open piece bullet with brief: and branch:"; return; }
  piece=$(printf '%s\n' "$bullet" | sed -nE 's/^- \*\*([A-Za-z0-9._-]+)\*\*.*/\1/p')
  branch=$(field branch "$bullet"); slices=$(field slices "$bullet"); bpath=$(field brief "$bullet")
  [ -n "$slices" ] || slices=$piece
  case "$branch" in task/?*) ;; *) stop_chain "$id" "$sha" blocked "" "piece=$piece needs 'branch: task/...'"; return ;; esac
  rules=$(git -C "$DOCS" show "$commit:${PREFIX}briefs/_loop.md" 2>/dev/null) \
    || { stop_chain "$id" "$sha" blocked "" "missing ${PREFIX}briefs/_loop.md at ${commit:0:7}"; return; }
  model=$(pick_model "$bullet")
  while :; do
    slice=$(next_slice "$piece" "$slices" "$branch" || true)
    if [ -z "$slice" ]; then stop_chain "$id" "$sha" "done" "" "piece=$piece every slice passed the gate on $branch"; return; fi
    local this=$bpath
    if [ "$slice" != "$piece" ] || [ -z "$this" ]; then this=${PREFIX}briefs/$slice.md; fi
    brief=$(git -C "$DOCS" show "$commit:$this" 2>/dev/null) \
      || { stop_chain "$id" "$sha" blocked "$slice" "brief missing: $this at ${commit:0:7}"; return; }
    final=no; [ "$slice" = "${slices##*,}" ] && final=yes
    [ "$(brief_value final "$brief")" = yes ] && final=yes
    prompt="$rules"$'\n\n'"$brief"
    bytes=$(printf '%s' "$prompt" | wc -c | tr -d ' ')
    if [ "$bytes" -gt "$LOOP_BRIEF_MAX_BYTES" ]; then
      stop_chain "$id" "$sha" blocked "$slice" "brief-too-big $bytes > $LOOP_BRIEF_MAX_BYTES bytes ($this)"; return
    fi
    if [ -n "$fail" ]; then
      prompt+=$'\n\n## Gate failed on your previous attempt at this slice\n'
      prompt+="Fix only this. Commit on top with the trailer \`Piece: $slice\` (no rebase, no force-push), run the self-check, push, then the LOOP line."
      prompt+=$'\n\n'"$fail"
    fi
    prompt="You build ONE slice ($slice) of piece $piece in project $LOOP_PROJECT. The loop rules and the slice brief below are all the context you need. End your final reply with exactly one line: \`LOOP: done piece=$slice\`, \`LOOP: blocked <why>\` or \`LOOP: limit\`."$'\n\n'"$prompt"
    left=$(awk -v c="$LOOP_PIECE_BUDGET_USD" -v s="$(spent "$piece")" 'BEGIN{printf "%.2f", c-s}')
    cap=$(awk -v l="$left" -v m="$LOOP_SLICE_BUDGET_USD" 'BEGIN{printf "%.2f", (l<m)?l:m}')
    if [ "$MODE" = plan ]; then
      printf 'project=%s task=%s piece=%s slice=%s final=%s branch=%s model=%s cap_usd=%s piece_left_usd=%s prompt_bytes=%s/%s brief=%s\n' \
        "$LOOP_PROJECT" "$id" "$piece" "$slice" "$final" "$branch" "${model:-default}" "$cap" "$left" "$bytes" "$LOOP_BRIEF_MAX_BYTES" "$this"
      return
    fi
    if awk -v x="$cap" 'BEGIN{exit !(x < 0.10)}'; then
      stop_chain "$id" "$sha" blocked "$slice" "budget piece=$piece spent \$$(spent "$piece") of \$$LOOP_PIECE_BUDGET_USD"; return
    fi
    [ -x "$LOOP_CLAUDE_BIN" ] || { log "task=$id not-configured LOOP_CLAUDE_BIN"; return; }
    ensure_worktree "$id" || return
    [ -n "$fail" ] || prev=$(remote_head "$branch")
    ts=$(date -u +%Y%m%dT%H%M%SZ); base=$STATE/runs/$ts-$slice
    read -r -a flags <<< "$LOOP_CLAUDE_FLAGS"
    log "task=$id sha=${sha:0:12} start piece=$piece slice=$slice${fail:+ fix-run} model=${model:-default} cap=$cap bytes=$bytes"
    rc=0
    (cd "$LOOP_WT" && "$LOOP_CLAUDE_BIN" -p "$prompt" --output-format stream-json --verbose \
        ${model:+--model "$model"} --max-budget-usd "$cap" "${flags[@]}") > "$base.jsonl" 2> "$base.err" || rc=$?
    cost=$(jq -Rr 'fromjson? | select(.type == "result") | .total_cost_usd // 0' "$base.jsonl" 2>/dev/null | tail -1)
    echo "${cost:-0} $slice $ts" >> "$STATE/cost/$piece.txt"
    loop=$(jq -Rr 'fromjson? | select(.type == "result") | .result // ""' "$base.jsonl" 2>/dev/null | grep -E '^LOOP: ' | tail -1 || true)
    status=$(printf '%s' "$loop" | sed -n 's/^LOOP: \([a-z]*\).*/\1/p')
    lpiece=$(printf '%s' "$loop" | sed -n 's/.*piece=\([A-Za-z0-9._-]*\).*/\1/p')
    log "task=$id sha=${sha:0:12} end slice=$slice rc=$rc cost_usd=${cost:-0} loop=${status:-none}"
    case "$status" in
      limit) log "task=$id usage-limit (retried on the next queue event)"; notify limit "$id" "$slice" "usage limit"; return ;;
      blocked) stop_chain "$id" "$sha" blocked "$slice" "claude: ${loop#LOOP: blocked }"; return ;;
      done) ;;
      *) log "task=$id sha=${sha:0:12} error slice=$slice rc=$rc no LOOP line (counts toward the start cap)"
         notify error "$id" "$slice" "rc=$rc, no LOOP line"; return ;;
    esac
    if [ "$rc" -ne 0 ] || [ "$lpiece" != "$slice" ]; then
      stop_chain "$id" "$sha" blocked "$slice" "G0 rc=$rc LOOP line '$loop' (expected done piece=$slice)"; return
    fi
    if gout=$(gate "$slice" "$branch" "$prev" "$brief" "$final" "$retry"); then
      echo "$slice $(git -C "$LOOP_WT" rev-parse HEAD) $([ "$final" = yes ] && echo full || echo partial)" >> "$STATE/passed/$piece.txt"
      log "task=$id slice=$slice gate pass"
      fail='' retry=''
      continue
    fi
    printf '%s\n' "$gout" > "$base.gate.txt"
    if [ -n "$retry" ]; then stop_chain "$id" "$sha" blocked "$slice" "gate failed twice: $(head -c 300 <<< "$gout")"; return; fi
    log "task=$id slice=$slice gate fail -> one fix run: $(head -c 300 <<< "$gout")"
    fail=$gout retry=1
  done
}

# --- check: one pass over the committed queue ------------------------------------------------------------
check() {
  load_config
  exec 9> "$STATE/run.lock"
  if ! flock -n 9; then touch "$STATE/pending"; [ "$MODE" = watch ] || echo "queue-watch: a run holds run.lock" >&2; return 0; fi
  local commit section id sha starts
  while :; do
    rm -f "$STATE/pending"
    commit=$(git -C "$DOCS" rev-parse HEAD)
    section=$(git -C "$DOCS" show "$commit:$PREFIX$LOOP_QUEUE" 2>/dev/null | top_open_task || true)
    if [ -z "$section" ]; then log "task=- sha=- idle (no open task in $LOOP_QUEUE)"; break; fi
    id=$(printf '%s\n' "$section" | task_id)
    sha=$(printf '%s\n' "$section" | sha256sum | cut -c1-40)
    if [ "$MODE" = plan ]; then run_piece "$id" "$sha" "$commit" "$section"; break; fi
    if [ ! -f "$STATE/last-task.sha" ]; then
      echo "$sha" > "$STATE/last-task.sha"; log "task=$id sha=${sha:0:12} baseline (first start runs nothing)"; break
    fi
    if [ "$sha" = "$(cat "$STATE/last-task.sha")" ]; then break; fi
    starts=$(( $(cat "$STATE/starts/$sha" 2>/dev/null || echo 0) + 1 ))
    echo "$starts" > "$STATE/starts/$sha"
    if [ "$starts" -gt "$LOOP_MAX_STARTS" ]; then
      log "task=$id sha=${sha:0:12} needs-owner start $starts > $LOOP_MAX_STARTS for one task; runs nothing until the queue changes"
      notify needs-owner "$id" "" "start cap $LOOP_MAX_STARTS reached"
      break
    fi
    run_piece "$id" "$sha" "$commit" "$section"
    [ -f "$STATE/pending" ] || break
  done
  flock -u 9
}

watch() {
  local dir file ino
  load_config
  log "task=- sha=- watching $DOCS/$LOOP_QUEUE and $REF"
  check
  exec 3< <(exec inotifywait -mq -e close_write,moved_to,create --format '%w|%f' "$DOCS/" "$REFDIR/")
  ino=$!
  trap 'kill "$ino" 2>/dev/null; exit 0' TERM INT
  while IFS='|' read -r -u 3 dir file; do
    if ! { [ "$dir" = "$DOCS/" ] && [ "$file" = "$LOOP_QUEUE" ]; } \
       && ! { [ "$dir" = "$REFDIR/" ] && [ "$file" = "$(basename "$REF")" ]; }; then
      continue
    fi
    while read -r -u 3 -t "$LOOP_DEBOUNCE" _; do :; done
    check
  done
  log "task=- sha=- inotifywait exited"
  return 1   # systemd restarts the unit (Restart=on-failure)
}

case "$MODE" in
  watch) watch ;;
  check|plan) check ;;
esac
