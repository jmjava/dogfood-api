#!/usr/bin/env bash
# Did the Cursor *day* work — not merely that an agent spawned.
# Checks harvest/gate/lesson outcomes. Does not spawn. No LLM.
# Exit 0 = WORKED, 1 = FAILED. Always prints RESULT= and WHY=.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${DOGFOOD_STATUS_ROOT:-$(cd "$HERE/../.." && pwd)}"
WORK_ID="FEAT-001-order-status-api"
RECEIPT="${DOGFOOD_AGENT_RECEIPT:-$ROOT/sdlc-spdd/.sdlc/agent-day.json}"
RESULT_TXT="${DOGFOOD_AGENT_RESULT:-$ROOT/sdlc-spdd/.sdlc/agent-day-result.txt}"
JUNIT="${DOGFOOD_AGENT_JUNIT:-$ROOT/target/surefire-reports/TEST-com.jmjava.dogfood.CursorSpawnResultTest.xml}"
WHYS=()

why() { WHYS+=("$1"); }

if [[ ! -f "$RECEIPT" ]]; then
  why "no-receipt: spawn never wrote agent-day.json (test did not run)"
else
  eval "$(python3 - "$RECEIPT" <<'PY'
import json, shlex, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf8"))
except Exception as e:
    print(f"parse_error={shlex.quote(str(e))}")
    raise SystemExit(0)

def q(v):
    return shlex.quote("" if v is None else str(v))

cmds = {c.get("slug"): c for c in (data.get("commands") or []) if isinstance(c, dict)}
nxt = cmds.get("sdlc-next") or {}
raw = cmds.get("persist-lesson-unstructured") or {}
print(f"hit={q(data.get('hitCursor'))}")
print(f"mode={q(data.get('mode'))}")
print(f"extra={q(data.get('extraKey'))}")
print(f"model={q(data.get('model'))}")
print(f"agent={q(data.get('agentId'))}")
print(f"err={q(data.get('error'))}")
print(f"next_id={q(nxt.get('runId'))}")
print(f"next_st={q(nxt.get('status'))}")
print(f"raw_id={q(raw.get('runId'))}")
print(f"raw_st={q(raw.get('status'))}")
PY
)"
  if [[ -n "${parse_error:-}" ]]; then
    why "receipt-not-json: $parse_error"
  else
    [[ "$hit" == "True" || "$hit" == "true" ]] || why "hitCursor-not-true: receipt did not record a real Cursor hit"
    [[ "$mode" == "sdk-spawn" ]] || why "not-sdk-spawn: mode=${mode:-empty} (stand-in/in-env does not count as the Cursor test)"
    [[ "$extra" == "CORRECT_CURSOR_KEY" ]] || why "wrong-key: extraKey=${extra:-empty} (must be CORRECT_CURSOR_KEY)"
    [[ "$model" == "composer-2.5" ]] || why "wrong-model: model=${model:-empty} (locked to composer-2.5)"
    [[ -n "${agent:-}" ]] || why "missing-agentId: spawn did not record an agent"
    if [[ "${next_st:-}" != "finished" || -z "${next_id:-}" ]]; then
      why "sdlc-next-did-not-finish: status=${next_st:-missing} runId=${next_id:-missing}"
    fi
    if [[ "${raw_st:-}" != "finished" || -z "${raw_id:-}" ]]; then
      why "persist-lesson-did-not-finish: status=${raw_st:-missing} runId=${raw_id:-missing}"
    fi
    if [[ -n "${err:-}" ]]; then
      why "spawn-error: $err"
    fi
  fi
fi

# Actual day outcomes — spawn-finished is not enough.
[[ -f "$ROOT/.cursor/commands/sdlc-next.md" ]] || why "missing-cursor-pack: .cursor/commands/sdlc-next.md (full install did not land)"
[[ -f "$ROOT/.github/prompts/sdlc-next.prompt.md" ]] || why "missing-copilot-pack: .github/prompts/sdlc-next.prompt.md"
[[ -f "$ROOT/.claude/commands/sdlc-next.md" ]] || why "missing-claude-pack: .claude/commands/sdlc-next.md"

gate="$ROOT/.dif/projections/${WORK_ID}.gate.json"
if [[ ! -f "$gate" ]]; then
  why "missing-ready-gate: $gate (/sdlc-next/fold did not write a gate)"
elif ! grep -q '"readyForImplementation"' "$gate" || ! grep -q 'true' "$gate"; then
  why "gate-not-ready: $gate (fold ran but readyForImplementation is not true)"
fi

pointer="$ROOT/sdlc-spdd/.sdlc/pointer"
if [[ ! -f "$pointer" ]]; then
  why "missing-pointer: $pointer (structured claim did not land)"
elif ! grep -q "$WORK_ID" "$pointer"; then
  why "pointer-wrong-work: $(tr '\n' ' ' < "$pointer") (want $WORK_ID)"
fi

staged="$ROOT/sdlc-spdd/.sdlc/staged/lessons.jsonl"
if [[ ! -f "$staged" ]]; then
  why "missing-lessons: $staged (unstructured persist did not write)"
else
  grep -q 'pitfall:(none):notify:dogfood-agent-day' "$staged" \
    || why "missing-unstructured-lesson: staged lessons lack pitfall:(none):notify:dogfood-agent-day"
  grep -q 'FEAT-ADHOC' "$staged" \
    && why "invented-FEAT-ADHOC: unstructured persist invented a Work ID"
fi

why_line=""
if [[ ${#WHYS[@]} -gt 0 ]]; then
  why_line=$(IFS=' | '; echo "${WHYS[*]}")
fi

mkdir -p "$(dirname "$RESULT_TXT")" "$(dirname "$JUNIT")"
{
  if [[ -n "$why_line" ]]; then
    echo "RESULT=FAILED"
    echo "WHY=$why_line"
  else
    echo "RESULT=WORKED"
    echo "WHY="
  fi
  echo "receipt=$RECEIPT"
  echo "agentId=${agent:-}"
  echo "model=${model:-}"
  echo "sdlc-next=${next_id:-} ${next_st:-}"
  echo "persist-lesson-unstructured=${raw_id:-} ${raw_st:-}"
} | tee "$RESULT_TXT"

python3 - "$RECEIPT" "$RESULT_TXT" "$JUNIT" "$why_line" <<'PY'
import json, pathlib, sys, xml.sax.saxutils as x
receipt, result_txt, junit, why = sys.argv[1:5]
ok = not why
receipt_path = pathlib.Path(receipt)
try:
    data = json.load(receipt_path.open(encoding="utf8")) if receipt_path.is_file() else {}
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
data["ok"] = ok
data["why"] = why
receipt_path.parent.mkdir(parents=True, exist_ok=True)
receipt_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf8")
name = "com.jmjava.dogfood.CursorSpawnResultTest"
cls = "actualCursorDayWorked"
esc = x.escape(why or "Cursor day worked")
pathlib.Path(junit).parent.mkdir(parents=True, exist_ok=True)
if ok:
    body = f'''<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="{name}" tests="1" failures="0" errors="0">
  <testcase classname="{name}" name="{cls}"/>
</testsuite>
'''
else:
    body = f'''<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="{name}" tests="1" failures="1" errors="0">
  <testcase classname="{name}" name="{cls}">
    <failure message="{esc}">{esc}</failure>
  </testcase>
</testsuite>
'''
pathlib.Path(junit).write_text(body, encoding="utf8")
PY

if [[ -n "$why_line" ]]; then
  echo "TEST=FAILED"
  exit 1
fi
echo "TEST=WORKED"
exit 0
