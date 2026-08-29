#!/usr/bin/env bash
# Fail-closed checks after the Cursor agent day. No LLM here — the agent already ran.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK_ID="FEAT-001-order-status-api"
RECEIPT="${DOGFOOD_AGENT_RECEIPT:-$ROOT/sdlc-spdd/.sdlc/agent-day.json}"
fail=0
ok() { echo "  ok   $1"; }
bad() { echo "  FAIL $1" >&2; fail=$((fail + 1)); }

[[ -f "$ROOT/.cursor/commands/sdlc-next.md" ]] && ok "/sdlc-next pack" || bad "/sdlc-next pack"
[[ -f "$ROOT/.github/prompts/sdlc-next.prompt.md" ]] && ok "Copilot /sdlc-next" || bad "Copilot pack"
[[ -f "$ROOT/.claude/commands/sdlc-next.md" ]] && ok "Claude /sdlc-next" || bad "Claude pack"

gate="$ROOT/.dif/projections/${WORK_ID}.gate.json"
if [[ -f "$gate" ]] && grep -q '"readyForImplementation"' "$gate" && grep -q 'true' "$gate"; then
  ok "dif=ready $WORK_ID"
else
  bad "missing ready gate $gate"
fi

pointer="$ROOT/sdlc-spdd/.sdlc/pointer"
if [[ -f "$pointer" ]] && grep -q "$WORK_ID" "$pointer"; then
  ok "pointer $WORK_ID"
else
  bad "pointer is not $WORK_ID"
fi

staged="$ROOT/sdlc-spdd/.sdlc/staged/lessons.jsonl"
if [[ -f "$staged" ]] && grep -q 'pitfall:(none):notify:dogfood-agent-day' "$staged"; then
  ok "unstructured pitfall:(none):notify:dogfood-agent-day"
else
  bad "no unscoped notify pitfall in staged lessons"
fi
if [[ -f "$staged" ]] && grep -q 'FEAT-ADHOC' "$staged"; then
  bad "invented FEAT-ADHOC"
fi

if [[ -f "$RECEIPT" ]]; then
  if grep -q '"hitCursor": true' "$RECEIPT"; then
    ok "receipt hitCursor=true"
  else
    bad "receipt did not hit Cursor"
  fi
  if grep -q '"mode": "sdk-spawn"' "$RECEIPT"; then
    ok "receipt mode=sdk-spawn"
  else
    bad "receipt is not sdk-spawn (stand-in does not count)"
  fi
  eval "$(python3 - "$RECEIPT" <<'PY'
import json, shlex, sys
data = json.load(open(sys.argv[1], encoding="utf8"))
cmds = {c.get("slug"): c for c in (data.get("commands") or []) if isinstance(c, dict)}
nxt, raw = cmds.get("sdlc-next") or {}, cmds.get("persist-lesson-unstructured") or {}
print(f"next_st={shlex.quote(str(nxt.get('status') or ''))}")
print(f"raw_st={shlex.quote(str(raw.get('status') or ''))}")
print(f"next_id={shlex.quote(str(nxt.get('runId') or ''))}")
print(f"raw_id={shlex.quote(str(raw.get('runId') or ''))}")
PY
)"
  if [[ "$next_st" == "finished" && -n "$next_id" ]]; then
    ok "receipt /sdlc-next finished $next_id"
  else
    bad "receipt /sdlc-next not finished (status=$next_st)"
  fi
  if [[ "$raw_st" == "finished" && -n "$raw_id" ]]; then
    ok "receipt unstructured persist finished $raw_id"
  else
    bad "receipt unstructured persist not finished (status=$raw_st)"
  fi
else
  bad "missing $RECEIPT (agent day did not run)"
fi

if [[ "$fail" -gt 0 ]]; then
  echo "agent-day verify failed ($fail)" >&2
  exit 1
fi
echo "agent-day verify: OK"
