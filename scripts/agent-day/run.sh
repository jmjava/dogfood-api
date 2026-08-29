#!/usr/bin/env bash
# Product proof: real Cursor linkage.
#
#   Inside a Cursor / Cloud Agent environment (CURSOR_AGENT=1):
#     this process IS the agent. We run /sdlc-next + unstructured persist.
#   Otherwise:
#     CURSOR_API_KEY + @cursor/sdk spawn a Cursor agent that does the same.
#
#   ./scripts/up.sh --setup-only && ./scripts/agent-day/run.sh
#   ./scripts/up.sh --prove
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
export DOGFOOD_ROOT="$ROOT"
export ORCH_HOME="${ORCH_HOME:-$HOME/github/jmjava/sdlc-spdd-orchestrator}"
export DIF_HOME="${DIF_HOME:-$HOME/github/jmjava/embabel-dif}"

if [[ ! -f "$ROOT/.cursor/commands/sdlc-next.md" ]]; then
  echo "FAIL: Cursor pack missing. Run ./scripts/up.sh --setup-only first." >&2
  exit 1
fi

# Already inside Cursor (Cloud Agent / IDE agent) — that is the linkage.
if [[ "${CURSOR_AGENT:-}" == "1" || "${DOGFOOD_AGENT_SELF:-}" == "1" ]]; then
  echo "==> in-environment Cursor agent (CURSOR_AGENT=${CURSOR_AGENT:-} self=${DOGFOOD_AGENT_SELF:-})"
  exec "$HERE/run-in-env.sh"
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "FAIL: not inside Cursor and CURSOR_API_KEY is unset." >&2
  echo "  Run this from a Cursor Cloud Agent, or set a User API key:" >&2
  echo "  https://cursor.com/dashboard/integrations" >&2
  exit 1
fi

if [[ ! -d "$HERE/node_modules/@cursor/sdk" ]]; then
  if [[ -d "$ORCH_HOME/tests/live-consumer/cursor-agent/node_modules/@cursor/sdk" ]]; then
    ln -sfn "$ORCH_HOME/tests/live-consumer/cursor-agent/node_modules" "$HERE/node_modules"
  else
    (cd "$HERE" && npm install --no-fund --no-audit)
  fi
fi

export LIVE_CURSOR_MODEL="${LIVE_CURSOR_MODEL:-composer-2.5}"
echo "==> spawn Cursor agent via SDK  model=$LIVE_CURSOR_MODEL"
exec node "$HERE/run-cursor-day.mjs"
