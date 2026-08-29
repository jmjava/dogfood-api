#!/usr/bin/env bash
# Product proof for dogfood: spawn a real Cursor agent (CURSOR_API_KEY)
# and have it execute /sdlc-next + an unstructured persist.
#
#   ./scripts/up.sh --setup-only
#   ./scripts/agent-day/run.sh
#
# This is not ./mvnw test. This hits Cursor.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ORCH_HOME="${ORCH_HOME:-$HOME/github/jmjava/sdlc-spdd-orchestrator}"

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "FAIL: CURSOR_API_KEY is required. This test hits Cursor." >&2
  echo "  https://cursor.com/dashboard/integrations" >&2
  echo "  export CURSOR_API_KEY=cursor_..." >&2
  exit 1
fi
if [[ ! -f "$ROOT/.cursor/commands/sdlc-next.md" ]]; then
  echo "FAIL: Cursor pack missing. Run ./scripts/up.sh --setup-only first." >&2
  exit 1
fi
if [[ ! -x "$ORCH_HOME/scripts/sdlc.sh" && ! -x "$ROOT/sdlc-spdd/scripts/sdlc.sh" ]]; then
  echo "FAIL: sdlc.sh missing (need orch install on this tree)" >&2
  exit 1
fi

if [[ ! -d "$HERE/node_modules/@cursor/sdk" ]]; then
  if [[ -d "$ORCH_HOME/tests/live-consumer/cursor-agent/node_modules/@cursor/sdk" ]]; then
    echo "==> using orch @cursor/sdk"
    ln -sfn "$ORCH_HOME/tests/live-consumer/cursor-agent/node_modules" "$HERE/node_modules"
  else
    echo "==> npm install @cursor/sdk"
    (cd "$HERE" && npm install --no-fund --no-audit)
  fi
fi

export DOGFOOD_ROOT="$ROOT"
export ORCH_HOME
export DIF_HOME="${DIF_HOME:-$HOME/github/jmjava/embabel-dif}"
export LIVE_CURSOR_MODEL="${LIVE_CURSOR_MODEL:-composer-2.5}"
echo "==> Cursor agent day  dogfood=$ROOT  model=$LIVE_CURSOR_MODEL"
exec node "$HERE/run-cursor-day.mjs"
