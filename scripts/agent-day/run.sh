#!/usr/bin/env bash
# Full test: spawn a real Cursor agent, then fail the *test* if the day
# outcomes did not land (gate / pointer / unstructured lesson).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
export DOGFOOD_ROOT="$ROOT"
export ORCH_HOME="${ORCH_HOME:-$HOME/github/jmjava/sdlc-spdd-orchestrator}"
export DIF_HOME="${DIF_HOME:-$HOME/github/jmjava/embabel-dif}"
export DOGFOOD_REQUIRE_CURSOR_SPAWN=1

export LIVE_CURSOR_MODEL="${LIVE_CURSOR_MODEL:-composer-2.5}"
if [[ "$LIVE_CURSOR_MODEL" != "composer-2.5" ]]; then
  echo "FAIL: refusing model=$LIVE_CURSOR_MODEL" >&2
  echo "  agent-day is locked to composer-2.5 (cheapest standard; not *-fast)." >&2
  echo "RESULT=FAILED"
  echo "WHY=wrong-model: $LIVE_CURSOR_MODEL"
  exit 1
fi

export CURSOR_RUN_TIMEOUT_MS="${CURSOR_RUN_TIMEOUT_MS:-480000}"
export CURSOR_MAX_TOTAL_TOKENS="${CURSOR_MAX_TOTAL_TOKENS:-150000}"
export CURSOR_HARD_DEADLINE_SEC="${CURSOR_HARD_DEADLINE_SEC:-720}"
export CURSOR_MAX_SENDS="${CURSOR_MAX_SENDS:-2}"

"$HERE/guard-no-secret-leak.sh"
# shellcheck source=load-cursor-key.sh
source "$HERE/load-cursor-key.sh"

if [[ ! -f "$ROOT/.cursor/commands/sdlc-next.md" ]]; then
  echo "FAIL: Cursor pack missing. Run ./scripts/up.sh --setup-only first." >&2
  echo "RESULT=FAILED"
  echo "WHY=missing-cursor-pack"
  exit 1
fi

if [[ ! -d "$HERE/node_modules/@cursor/sdk" ]]; then
  echo "==> npm install @cursor/sdk"
  (cd "$HERE" && npm install --no-fund --no-audit)
fi

echo "==> spawn Cursor agent via SDK  model=$LIVE_CURSOR_MODEL"
echo "    timeout/send=${CURSOR_RUN_TIMEOUT_MS}ms  tokens<=${CURSOR_MAX_TOTAL_TOKENS}  wall=${CURSOR_HARD_DEADLINE_SEC}s  sends<=${CURSOR_MAX_SENDS}"

set +e
if command -v timeout >/dev/null 2>&1; then
  timeout --kill-after=30s "${CURSOR_HARD_DEADLINE_SEC}" node "$HERE/run-cursor-day.mjs"
  rc=$?
else
  node "$HERE/run-cursor-day.mjs"
  rc=$?
fi
set -e

echo "==> did the actual Cursor day work (gate/lesson, not just spawn)?"
set +e
"$HERE/status.sh"
st=$?
set -e

if [[ "$st" -ne 0 || "$rc" -ne 0 ]]; then
  echo "TEST=FAILED"
  if [[ -f "$ROOT/sdlc-spdd/.sdlc/agent-day-result.txt" ]]; then
    grep -E '^(RESULT|WHY)=' "$ROOT/sdlc-spdd/.sdlc/agent-day-result.txt" || true
  fi
  if [[ -x "$ROOT/mvnw" ]]; then
    echo "==> feed failure into Maven test results"
    (cd "$ROOT" && ./mvnw -q -Dtest=CursorSpawnResultTest test) || true
  fi
  exit 1
fi

if [[ -x "$ROOT/mvnw" ]]; then
  echo "==> feed WORKED into Maven test results"
  (cd "$ROOT" && ./mvnw -q -Dtest=CursorSpawnResultTest test)
fi
echo "TEST=WORKED"
exit 0
