#!/usr/bin/env bash
# In-environment path: this process is already a Cursor agent (CURSOR_AGENT=1).
# Follow /sdlc-next the way the pack tells an agent to, then unstructured persist.
set -euo pipefail
ROOT="${DOGFOOD_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
ORCH_HOME="${ORCH_HOME:-$HOME/github/jmjava/sdlc-spdd-orchestrator}"
DIF_HOME="${DIF_HOME:-$HOME/github/jmjava/embabel-dif}"
WORK_ID="FEAT-001-order-status-api"
RECEIPT="$ROOT/sdlc-spdd/.sdlc/agent-day.json"

if [[ -x "$ROOT/sdlc-spdd/scripts/sdlc.sh" ]]; then
  SDLC=("$ROOT/sdlc-spdd/scripts/sdlc.sh" --target "$ROOT")
elif [[ -x "$ORCH_HOME/scripts/sdlc.sh" ]]; then
  SDLC=("$ORCH_HOME/scripts/sdlc.sh" --target "$ROOT")
else
  echo "FAIL: sdlc.sh missing" >&2
  exit 1
fi

echo "==> /sdlc-next (this Cursor agent runs sdlc)"
next_out="$("${SDLC[@]}" next 2>&1 || true)"
echo "$next_out" | tail -n 40

dif_line=""
mkdir -p "$ROOT/.dif/projections"
if [[ -x "$DIF_HOME/scripts/dif-fold.sh" ]]; then
  echo "==> silent DIF attach (from /sdlc-next pack)"
  dif_line="$(cd "$DIF_HOME" && ./scripts/dif-fold.sh architect --quiet \
    --canvas "$ROOT/sdlc-spdd/spdd/canvas/${WORK_ID}.md" \
    --out "$ROOT/.dif/projections" || true)"
  echo "$dif_line"
fi

echo "==> unstructured persist (kind+area+body, no FEAT)"
ORCH_PY="${ORCH_PYTHON:-}"
if [[ -z "$ORCH_PY" && -x "$ORCH_HOME/.venv/bin/python" ]]; then
  ORCH_PY="$ORCH_HOME/.venv/bin/python"
fi
if [[ -z "$ORCH_PY" && -x /tmp/orch-venv/bin/python ]]; then
  ORCH_PY=/tmp/orch-venv/bin/python
fi
if [[ -z "$ORCH_PY" ]]; then
  ORCH_PY=python3
fi
export PYTHONPATH="$ORCH_HOME/engine/src${PYTHONPATH:+:$PYTHONPATH}"
unstructured_out="$("$ORCH_PY" -m sdlc_engine --root "$ROOT" context persist-lesson \
  --kind pitfall --area notify --source dogfood-agent-day \
  --body "Cursor agent day: retry without an idempotency key double-posts." \
  --no-guide)"
echo "$unstructured_out" | tail -n 8
if echo "$unstructured_out" | grep -q 'FEAT-ADHOC'; then
  echo "FAIL: invented FEAT-ADHOC" >&2
  exit 1
fi

mkdir -p "$(dirname "$RECEIPT")"
cat > "$RECEIPT" <<EOF
{
  "schema": 1,
  "hitCursor": true,
  "mode": "in-environment",
  "agent": "CURSOR_AGENT",
  "commands": ["sdlc-next", "persist-lesson-unstructured"],
  "workId": "$WORK_ID",
  "dif": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$dif_line")
}
EOF

exec "$ROOT/scripts/agent-day/verify.sh"
