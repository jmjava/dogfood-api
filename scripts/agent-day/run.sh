#!/usr/bin/env bash
# Full test: spawn a real Cursor agent (CORRECT_CURSOR_KEY + @cursor/sdk).
# That agent executes /sdlc-next, then unstructured persist.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
export DOGFOOD_ROOT="$ROOT"
export ORCH_HOME="${ORCH_HOME:-$HOME/github/jmjava/sdlc-spdd-orchestrator}"
export DIF_HOME="${DIF_HOME:-$HOME/github/jmjava/embabel-dif}"

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

export LIVE_CURSOR_MODEL="${LIVE_CURSOR_MODEL:-composer-2.5}"
echo "==> spawn Cursor agent via SDK  model=$LIVE_CURSOR_MODEL"
exec node "$HERE/run-cursor-day.mjs"
