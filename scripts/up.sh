#!/usr/bin/env bash
# Full-ecosystem demo install. Not a partial adapter install.
#   dogfood-api + orch (Cursor+Copilot+Claude+Guide marker) + DIF fold + both harvests + Dashboard.
#
#   ./scripts/up.sh                    # full install, claim, fold, both harvests, Dashboard :5051
#   ./scripts/up.sh --setup-only       # same without starting the console
#   ./scripts/up.sh --with-api         # also start GET /api/orders on :8080
#   ./scripts/up.sh --with-guide-stack # also boot live orch-guide + Neo4j
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${DOGFOOD_TOOLS:-$ROOT/.tools}"
PORT="${DASHBOARD_PORT:-5051}"
API_PORT="${API_PORT:-8080}"
SETUP_ONLY=0
WITH_API=0
WITH_GUIDE_STACK=0
CLONE="${DOGFOOD_CLONE:-1}"

usage() {
  sed -n '2,10p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --setup-only) SETUP_ONLY=1; shift ;;
    --with-api) WITH_API=1; shift ;;
    --with-guide|--with-guide-stack) WITH_GUIDE_STACK=1; shift ;;
    --no-clone) CLONE=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

resolve_or_clone() {
  local name="$1" env_var="$2" repo="$3"
  local current="${!env_var:-}"
  if [[ -n "$current" && -d "$current" ]]; then
    printf '%s\n' "$(cd "$current" && pwd)"
    return
  fi
  local candidate
  for candidate in \
    "$HOME/github/jmjava/$name" \
    "$(cd "$ROOT/.." && pwd)/$name" \
    "$TOOLS/$name"
  do
    if [[ -d "$candidate/.git" || -d "$candidate/engine/src" || -d "$candidate/scripts" ]]; then
      printf '%s\n' "$(cd "$candidate" && pwd)"
      return
    fi
  done
  if [[ "$CLONE" != "1" ]]; then
    echo "FAIL: $env_var not set and $name is not a sibling" >&2
    return 1
  fi
  mkdir -p "$TOOLS"
  if [[ ! -d "$TOOLS/$name/.git" ]]; then
    echo "==> cloning $repo → $TOOLS/$name"
    git clone --depth 1 "https://github.com/jmjava/$repo.git" "$TOOLS/$name"
  fi
  printf '%s\n' "$(cd "$TOOLS/$name" && pwd)"
}

ORCH_HOME="$(resolve_or_clone sdlc-spdd-orchestrator ORCH_HOME sdlc-spdd-orchestrator)"
DIF_HOME="$(resolve_or_clone embabel-dif DIF_HOME embabel-dif)"
export ORCH_HOME DIF_HOME

echo "==> ecosystem (full install)"
echo "    dogfood : $ROOT"
echo "    orch    : $ORCH_HOME"
echo "    dif     : $DIF_HOME"

if [[ ! -x "$DIF_HOME/scripts/dif-fold.sh" ]]; then
  echo "FAIL: DIF fold script missing at $DIF_HOME/scripts/dif-fold.sh" >&2
  exit 1
fi

if [[ ! -x "$ORCH_HOME/.venv/bin/python" ]]; then
  echo "==> orch engine venv"
  "$ORCH_HOME/scripts/setup-engine-venv.sh"
fi
ORCH_PY="$ORCH_HOME/.venv/bin/python"
if [[ ! -x "$ORCH_PY" ]]; then
  ORCH_PY="${ORCH_PYTHON:-/tmp/orch-venv/bin/python}"
fi
if [[ ! -x "$ORCH_PY" ]]; then
  echo "FAIL: no orch Python (run $ORCH_HOME/scripts/setup-engine-venv.sh)" >&2
  exit 1
fi

echo "==> full orch install (Cursor + Copilot + Claude + Guide marker)"
"$ORCH_HOME/scripts/init-project.sh" \
  --target "$ROOT" \
  --cursor --copilot --claude \
  --with-guide

echo "==> verify full install"
"$ORCH_HOME/scripts/verify-project-install.sh" \
  --target "$ROOT" \
  --require-cursor --require-copilot --require-claude
if [[ ! -f "$ROOT/sdlc-spdd/harness/guide-dice.md" ]]; then
  echo "FAIL: Guide marker missing (expected sdlc-spdd/harness/guide-dice.md)" >&2
  exit 1
fi

echo "==> claim FEAT-001-order-status-api (structured)"
PYTHONPATH="$ORCH_HOME/engine/src${PYTHONPATH:+:$PYTHONPATH}" \
  SDLC_USER="${SDLC_USER:-dogfood}" \
  "$ORCH_PY" -m sdlc_engine --root "$ROOT" claim FEAT-001-order-status-api \
    --phase architect --note "dogfood full demo" --force

GATE_DIR="$ROOT/.dif/projections"
echo "==> DIF fold (required)"
mkdir -p "$GATE_DIR"
fold_line="$(cd "$DIF_HOME" && ./scripts/dif-fold.sh architect --quiet \
  --canvas "$ROOT/sdlc-spdd/spdd/canvas/FEAT-001-order-status-api.md" \
  --out "$GATE_DIR")"
echo "$fold_line"
if [[ "$fold_line" != *dif=ready* ]]; then
  echo "FAIL: expected dif=ready, got: $fold_line" >&2
  exit 1
fi
if [[ ! -f "$GATE_DIR/FEAT-001-order-status-api.gate.json" ]]; then
  echo "FAIL: missing $GATE_DIR/FEAT-001-order-status-api.gate.json" >&2
  exit 1
fi

echo "==> structured harvest (Work ID + area)"
PYTHONPATH="$ORCH_HOME/engine/src${PYTHONPATH:+:$PYTHONPATH}" \
  "$ORCH_PY" -m sdlc_engine --root "$ROOT" context persist-lesson \
    --kind decision \
    --work-id FEAT-001-order-status-api \
    --area api \
    --source dogfood-up \
    --body "GET /api/orders?email= stays unpaginated; invalid email is 400." \
    --no-guide >/dev/null

echo "==> unstructured harvest (kind + area + body, no FEAT)"
unstructured_out="$(
  PYTHONPATH="$ORCH_HOME/engine/src${PYTHONPATH:+:$PYTHONPATH}" \
    "$ORCH_PY" -m sdlc_engine --root "$ROOT" context persist-lesson \
      --kind pitfall \
      --area notify \
      --source adhoc-prompt \
      --body "Retry without an idempotency key double-posts webhook deliveries." \
      --no-guide
)"
echo "$unstructured_out" | tail -n 5
if ! echo "$unstructured_out" | grep -q 'pitfall:(none):notify:adhoc-prompt'; then
  echo "FAIL: unstructured persist must write pitfall:(none):notify:adhoc-prompt (orch #213+)" >&2
  exit 1
fi
if echo "$unstructured_out" | grep -q 'FEAT-ADHOC'; then
  echo "FAIL: unstructured harvest invented a FEAT" >&2
  exit 1
fi

if [[ "$WITH_GUIDE_STACK" == "1" ]]; then
  GUIDE_HOME="$(resolve_or_clone orch-guide GUIDE_HOME orch-guide)"
  export GUIDE_HOME
  echo "==> Guide + Neo4j live stack"
  GUIDE_KEEP=1 SDLC_GUIDE_STACK_LIVE=1 \
    "$ORCH_HOME/tests/test-guide-stack-live.sh"
fi

if [[ "$WITH_API" == "1" ]]; then
  echo "==> dogfood API :$API_PORT"
  (cd "$ROOT" && ./mvnw -q -DskipTests spring-boot:run -Dspring-boot.run.arguments="--server.port=$API_PORT") &
  echo "    GET http://127.0.0.1:$API_PORT/api/orders?email=ops@example.com"
fi

echo
echo "Install    : Cursor + Copilot + Claude + Guide marker"
echo "Structured : claim FEAT-001-order-status-api + fold + persist --work-id"
echo "Unstructured: persist-lesson --area notify --source adhoc-prompt (no FEAT)"
echo "Dashboard  : http://127.0.0.1:$PORT/?target=$ROOT"
echo "API        : ./mvnw spring-boot:run   then GET /api/orders?email=ops@example.com"
echo

if [[ "$SETUP_ONLY" == "1" ]]; then
  echo "setup-only: console not started"
  exit 0
fi

echo "==> ops console Dashboard :$PORT"
cd "$ORCH_HOME"
exec "$ORCH_HOME/scripts/sdlc.sh" --target "$ROOT" console --no-browser --port "$PORT"
