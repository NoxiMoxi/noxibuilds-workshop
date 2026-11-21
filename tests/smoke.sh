#!/usr/bin/env bash
# smoke.sh - end-to-end smoke tests for the kit. Needs bash, git, jq, flock, python3. No network, no systemd.
#
#   1. init.sh --dry-run into a temp root creates nothing, is repeatable, and passes collision checks.
#   2. init.sh rejects bad names and refuses existing dirs and units.
#   3. init.sh (real) scaffolds a complete project with no leftover placeholders and nothing installed.
#   4. queue-watch.sh: baseline on first check, --plan, then a full slice with a FAKE claude binary through
#      G0-G4 to `done`; then a scope violation that gets one fix run and stops `blocked`.
#   5. slicer.py puts a module shared by two surfaces into the core.
# shellcheck disable=SC2016  # backticks in sed patterns are literal queue text
set -euo pipefail
KIT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export SYSTEMD_USER_DIR=$T/units PK_SKIP_SYSTEMCTL=1
export GIT_AUTHOR_NAME=kit-test GIT_AUTHOR_EMAIL=kit-test@localhost GIT_COMMITTER_NAME=kit-test GIT_COMMITTER_EMAIL=kit-test@localhost
pass=0
ok() { pass=$((pass + 1)); echo "ok $pass - $*"; }
no() { echo "FAIL - $*" >&2; exit 1; }

# --- 1. dry run --------------------------------------------------------------------------------------------
out1=$("$KIT/init.sh" demo-app --root "$T/root" --dry-run)
out2=$("$KIT/init.sh" demo-app --root "$T/root" --dry-run)
[ ! -e "$T/root" ] || no "dry run created $T/root"
[ "$out1" = "$out2" ] || no "dry run output is not repeatable"
grep -q 'demo-app-claude-watch.service' <<< "$out1" || no "dry run does not name the unit"
grep -q '^OK: dry run' <<< "$out1" || no "dry run did not finish"
ok "init.sh --dry-run creates nothing and is repeatable"

# --- 2. refusals -------------------------------------------------------------------------------------------
for bad in "" "Bad" "1abc" "a" "has space" "trailing-" "../x"; do
  rc=0; "$KIT/init.sh" "$bad" --root "$T/root" --dry-run >/dev/null 2>&1 || rc=$?
  [ "$rc" = 2 ] || no "bad name '$bad' gave rc=$rc, want 2"
done
ok "init.sh rejects bad project names"
mkdir -p "$SYSTEMD_USER_DIR" && touch "$SYSTEMD_USER_DIR/taken-claude-watch.service"
rc=0; "$KIT/init.sh" taken --root "$T/root" --dry-run >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] || no "existing unit not refused (rc=$rc)"
ok "init.sh refuses an existing unit name"

# --- 3. real scaffold --------------------------------------------------------------------------------------
"$KIT/init.sh" demo-app --root "$T/root" > "$T/init.out"
P=$T/root/demo-app
for f in review-log/docs/claude-queue.md review-log/docs/briefs/_loop.md review-log/docs/briefs/TEMPLATE.md \
         review-log/docs/briefs/F0.1.md review-log/docs/brain/START.md review-log/docs/brain/rules.md \
         review-log/docs/brain/journey.md review-log/docs/brain/review-log.md loop/loop.env loop/notify.env \
         loop/demo-app-claude-watch.service loop/bin/queue-watch.sh loop/bin/self-check.sh; do
  [ -f "$P/$f" ] || no "missing $f"
done
[ "$(stat -c %a "$P/loop/loop.env")" = 600 ] && [ "$(stat -c %a "$P/loop/notify.env")" = 600 ] || no "env files not 600"
! grep -rqE '@(PROJECT|PROJECT_DIR|SELF_CHECK|PIECE_USD|SLICE_USD|BRIEF_BYTES)@' "$P" || no "placeholders left"
[ "$(git -C "$P/review-log" symbolic-ref --short HEAD)" = review-log ] || no "review-log branch"
[ "$(git -C "$P/review-log" rev-list --count HEAD)" = 1 ] || no "expected one commit"
[ ! -e "$SYSTEMD_USER_DIR/demo-app-claude-watch.service" ] || no "unit was installed"
for d in "$T/root"/.demo-app.init*; do [ ! -e "$d" ] || no "temp dir left behind: $d"; done
grep -q 'systemctl --user enable --now demo-app-claude-watch.service' "$T/init.out" || no "next steps missing"
ok "init.sh scaffolds the project, installs nothing, prints next steps"
rc=0; "$KIT/init.sh" demo-app --root "$T/root" >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] || no "re-run did not refuse (rc=$rc)"
ok "init.sh refuses to overwrite an existing project"

# --- 4. watcher with a fake claude -------------------------------------------------------------------------
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/app" 2>/dev/null
printf '# app\n' > "$T/app/README.md"; mkdir -p "$T/app/src"; printf 'x = 1\n' > "$T/app/src/other.py"
git -C "$T/app" add -A && git -C "$T/app" commit -qm init && git -C "$T/app" push -q origin main

cat > "$T/fake-claude" <<'FAKE'
#!/usr/bin/env bash
# Plays Claude: follows _loop.md for slice F0.1, then prints a stream-json result line.
set -euo pipefail
git fetch -q origin
if git rev-parse -q --verify refs/remotes/origin/task/F0.1-hello-loop >/dev/null; then
  git switch -q task/F0.1-hello-loop 2>/dev/null || git switch -q -c task/F0.1-hello-loop origin/task/F0.1-hello-loop
  git merge -q --ff-only origin/task/F0.1-hello-loop
else
  git switch -q -c task/F0.1-hello-loop origin/main
fi
if [ "${FAKE_MODE:-good}" = scope ]; then echo "y = 2" >> src/other.py; else echo "Built with the loop." >> README.md; fi
git commit -qam "readme: hello loop

Piece: F0.1"
git push -q origin HEAD 2>/dev/null
printf '{"type":"result","is_error":false,"total_cost_usd":0.0123,"result":"Done.\\nLOOP: done piece=F0.1"}\n'
FAKE
chmod +x "$T/fake-claude"
printf '#!/usr/bin/env bash\nexit 0\n' > "$P/loop/bin/self-check.sh"
sed -i "s|^LOOP_APP_REPO=.*|LOOP_APP_REPO=$T/app|; s|^LOOP_CLAUDE_BIN=.*|LOOP_CLAUDE_BIN=$T/fake-claude|; s|^LOOP_DEBOUNCE=.*|LOOP_DEBOUNCE=1|" "$P/loop/loop.env"
export LOOP_CONFIG=$P/loop/loop.env
W=$P/loop/bin/queue-watch.sh
RL=$P/review-log
LOG=$P/state/last-run.log

"$W" --check 2>/dev/null
grep -q 'idle (no open task' "$LOG" || no "expected idle with only staged work"
sed -i 's/^## F0: Hello loop - status: `staged`/## F0: Hello loop - status: `open`/' "$RL/docs/claude-queue.md"
git -C "$RL" commit -qam "queue: open F0"
"$W" --check 2>/dev/null
grep -q 'baseline (first start runs nothing)' "$LOG" || no "first check did not baseline"
[ ! -d "$P/wt-loop-run" ] || no "baseline started a run"
ok "watcher: first check records a baseline and runs nothing"

plan=$("$W" --plan 2>/dev/null)
grep -q 'slice=F0.1 final=yes branch=task/F0.1-hello-loop' <<< "$plan" || no "plan: $plan"
grep -q 'cap_usd=2.00' <<< "$plan" || no "plan cap: $plan"
ok "watcher --plan: $plan"

rm "$P/state/last-task.sha"; echo 0000 > "$P/state/last-task.sha"   # pretend the baseline was an older queue
"$W" --check 2>/dev/null
grep -q 'slice=F0.1 gate pass' "$LOG" || { cat "$LOG"; no "gate did not pass"; }
grep -q ' done piece=F0.1 every slice passed' "$LOG" || { cat "$LOG"; no "chain did not finish"; }
grep -q '^F0.1 [0-9a-f]\{40\} full$' "$P/state/passed/F0.1.txt" || no "passed record"
grep -q '0.0123 F0.1' "$P/state/cost/F0.1.txt" || no "cost not recorded"
ok "watcher: fake slice passes G0-G4 and the chain ends done"

"$W" --check 2>/dev/null
[ "$(grep -c ' start piece=' "$LOG")" = 1 ] || no "unchanged queue started another run"
ok "watcher: an unchanged queue starts nothing"

# Webhook: a local catcher records what the watcher POSTs when the next chain stops.
cat > "$T/catch.py" <<'PY'
import http.server, json, sys
out, portfile = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"])).decode()
        with open(out, "a") as f:
            f.write(json.dumps({"auth": self.headers.get("Authorization"), "body": json.loads(body)}) + "\n")
        self.send_response(204); self.end_headers()
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(portfile, "w").write(str(s.server_address[1]))
s.serve_forever()
PY
python3 "$T/catch.py" "$T/hook.jsonl" "$T/hook.port" & HOOK_PID=$!
trap 'kill "$HOOK_PID" 2>/dev/null; rm -rf "$T"' EXIT
for _ in $(seq 50); do [ -s "$T/hook.port" ] && break; sleep 0.1; done
sed -i "s|^LOOP_NOTIFY_URL=.*|LOOP_NOTIFY_URL=http://127.0.0.1:$(cat "$T/hook.port")/hook|" "$P/loop/loop.env"
echo 'LOOP_NOTIFY_KEY=test-key-not-secret' > "$P/loop/notify.env"

# Scope violation: a new piece whose run edits a file outside may_touch.
git -C "$T/app" push -q origin --delete task/F0.1-hello-loop
rm -rf "$P/state/passed" "$P/state/cost"
printf '\n' >> "$RL/docs/claude-queue.md"; sed -i 's/^## F0: Hello loop - status: `open`/## F0: Hello loop again - status: `open`/' "$RL/docs/claude-queue.md"
git -C "$RL" commit -qam "queue: retry F0"
git -C "$P/wt-loop-run" switch -q --detach origin/main
git -C "$P/wt-loop-run" branch -qD task/F0.1-hello-loop
FAKE_MODE=scope "$W" --check 2>/dev/null
grep -q 'gate fail -> one fix run: G3 files outside may_touch: src/other.py' "$LOG" || { cat "$LOG"; no "no G3 fix run"; }
grep -q 'blocked slice=F0.1 gate failed twice' "$LOG" || { cat "$LOG"; no "second failure did not block"; }
ok "watcher: G3 scope violation gets one fix run, then blocks"
jq -e 'select(.body.event == "blocked" and .body.project == "demo-app" and .body.slice == "F0.1"
       and .auth == "Bearer test-key-not-secret")' "$T/hook.jsonl" >/dev/null || { cat "$T/hook.jsonl"; no "webhook payload"; }
! grep -q 'test-key-not-secret' "$LOG" || no "key leaked into the log"
ok "watcher: webhook gets the blocked event with the Bearer key from notify.env (not logged)"

# --- 5. slicer -----------------------------------------------------------------------------------------------
R=$T/slicerepo; mkdir -p "$R/app/auth" "$R/app/search" "$R/app/db"
printf 'def connect():\n    """Open a connection."""\n    return 1\n' > "$R/app/db/core.py"
printf 'from app.db import core\n\ndef login():\n    return core.connect()\n' > "$R/app/auth/login.py"
printf 'from app.db.core import connect\n\ndef find():\n    return connect()\n' > "$R/app/search/find.py"
touch "$R/app/__init__.py" "$R/app/db/__init__.py"
printf '{"surfaces": {"auth": ["app/auth/**"], "search": ["app/search/**"]}}' > "$T/slices.json"
python3 "$KIT/redteam/slicer.py" --repo "$R" --config "$T/slices.json" --json "$T/plan.json" --emit "$T/emit" > "$T/plan.md"
python3 - "$T/plan.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
core = [s for s in p["slices"] if s["kind"] == "core"]
assert core and "app/db/core.py" in core[0]["files"], p
auth = next(s for s in p["slices"] if s["name"] == "auth")
assert auth["files"] == ["app/auth/login.py"] and auth["stubs"] == ["app/db/core.py"], auth
PY
grep -q 'CORE STUB app/db/core.py' "$T/emit/auth.txt" || no "slice bundle lacks core stub"
grep -q 'def connect():  # Open a connection.' "$T/emit/auth.txt" || no "stub lacks signature"
ok "slicer: shared module goes to core once; surfaces get stubs"

echo "all $pass smoke tests passed"
