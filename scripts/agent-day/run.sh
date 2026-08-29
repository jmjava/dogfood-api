#!/usr/bin/env bash
# Full test: spawn a real Cursor agent (CORRECT_CURSOR_KEY + @cursor/sdk).
# Locked to cheapest model + hard time/token budgets so it cannot run away.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
export DOGFOOD_ROOT="$ROOT"
export ORCH_HOME="${ORCH_HOME:-$HOME/github/jmjava/sdlc-spdd-orchestrator}"
export DIF_HOME="${DIF_HOME:-$HOME/github/jmjava/embabel-dif}"

# Cheapest Cursor model (not Fast). Refuse anything else.
export LIVE_CURSOR_MODEL="${LIVE_CURSOR_MODEL:-composer-2.5}"
if [[ "$LIVE_CURSOR_MODEL" != "composer-2.5" ]]; then
  echo "FAIL: refusing model=$LIVE_CURSOR_MODEL" >&2
  echo "  agent-day is locked to composer-2.5 (cheapest standard; not *-fast)." >&2
  exit 1
fi

# Hard caps. Override only if you accept the spend.
export CURSOR_RUN_TIMEOUT_MS="${CURSOR_RUN_TIMEOUT_MS:-480000}"       # 8 min / send
export CURSOR_MAX_TOTAL_TOKENS="${CURSOR_MAX_TOTAL_TOKENS:-150000}"   # both sends
export CURSOR_HARD_DEADLINE_SEC="${CURSOR_HARD_DEADLINE_SEC:-720}"    # 12 min wall
export CURSOR_MAX_SENDS="${CURSOR_MAX_SENDS:-2}"

"$HERE/guard-no-secret-leak.sh"

# shellcheck source=load-cursor-key.sh
source "$HERE/load-cursor-key.sh"

if [[ ! -f "$ROOT/.cursor/commands/sdlc-next.md" ]]; then
  echo "FAIL: Cursor pack missing. Run ./scripts/up.sh --setup-only first." >&2
  exit 1
fi

if [[ ! -d "$HERE/node_modules/@cursor/sdk" ]]; then
  echo "==> npm install @cursor/sdk"
  (cd "$HERE" && npm install --no-fund --no-audit)
fi

echo "==> spawn Cursor agent via SDK  model=$LIVE_CURSOR_MODEL"
echo "    timeout/send=${CURSOR_RUN_TIMEOUT_MS}ms  tokens<=${CURSOR_MAX_TOTAL_TOKENS}  wall=${CURSOR_HARD_DEADLINE_SEC}s  sends<=${CURSOR_MAX_SENDS}"

if command -v timeout >/dev/null 2>&1; then
  exec timeout --kill-after=30s "${CURSOR_HARD_DEADLINE_SEC}" node "$HERE/run-cursor-day.mjs"
fi
exec node "$HERE/run-cursor-day.mjs"
