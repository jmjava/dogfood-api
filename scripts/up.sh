#!/usr/bin/env bash
# Bootstrap the extended ecosystem against this consumer:
#   dogfood-api (this repo) + orch Dashboard + DIF fold + optional Guide.
#
#   ./scripts/up.sh                 # install, claim, fold, both-mode harvest, Dashboard :5051
#   ./scripts/up.sh --setup-only    # same without starting the console
#   ./scripts/up.sh --with-api      # also start GET /api/orders on :8080
#   ./scripts/up.sh --with-guide    # clone/start orch-guide if Docker is available
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${DOGFOOD_TOOLS:-$ROOT/.tools}"
PORT="${DASHBOARD_PORT:-5051}"
API_PORT="${API_PORT:-8080}"
SETUP_ONLY=0
WITH_API=0
WITH_GUIDE=0
CLONE="${DOGFOOD_CLONE:-1}"

usage() {
  sed -n '2,10p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --setup-only) SETUP_ONLY=1; shift ;;
    --with-api) WITH_API=1; shift ;;
    --with-guide) WITH_GUIDE=1; shift ;;
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
    echo "FAIL: $env_var not set and $name is not a sibling (pass --no-clone?)" >&2
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
DIF_HOME="$(resolve_or_clone embabel-dif DIF_HOME embabel-dif || true)"
export ORCH_HOME DIF_HOME

echo "==> ecosystem"
echo "    dogfood : $ROOT"
echo "    orch    : $ORCH_HOME"
echo "    dif     : ${DIF_HOME:-<missing>}"

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

echo "==> install orch adapters into dogfood-api"
"$ORCH_HOME/scripts/init-project.sh" --target "$ROOT" --cursor

echo "==> claim FEAT-001-order-status-api (structured)"
PYTHONPATH="$ORCH_HOME/engine/src${PYTHONPATH:+:$PYTHONPATH}" \
  SDLC_USER="${SDLC_USER:-dogfood}" \
  "$ORCH_PY" -m sdlc_engine --root "$ROOT" claim FEAT-001-order-status-api \
    --phase architect --note "dogfood play" --force

GATE_DIR="$ROOT/.dif/projections"
if [[ -n "${DIF_HOME:-}" && -x "$DIF_HOME/scripts/dif-fold.sh" ]]; then
  echo "==> DIF fold (structured gate the Dashboard will read)"
  mkdir -p "$GATE_DIR"
  (cd "$DIF_HOME" && ./scripts/dif-fold.sh architect --quiet \
    --canvas "$ROOT/sdlc-spdd/spdd/canvas/FEAT-001-order-status-api.md" \
    --out "$GATE_DIR") || true
else
  echo "==> DIF missing — Dashboard will show no dif chip (skipped is silence)"
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
if PYTHONPATH="$ORCH_HOME/engine/src${PYTHONPATH:+:$PYTHONPATH}" \
  "$ORCH_PY" -m sdlc_engine --root "$ROOT" context persist-lesson \
    --kind pitfall \
    --area notify \
    --source adhoc-prompt \
    --body "Retry without an idempotency key double-posts webhook deliveries." \
    --no-guide >/dev/null
then
  echo "    staged pitfall:(none):notify:adhoc-prompt"
else
  echo "    orch persist-lesson still requires --work-id; pull cursor/capture-area-148e"
fi

if [[ "$WITH_GUIDE" == "1" ]]; then
  GUIDE_HOME="$(resolve_or_clone orch-guide GUIDE_HOME orch-guide || true)"
  export GUIDE_HOME
  if [[ -n "${GUIDE_HOME:-}" && -f "$ORCH_HOME/tests/test-guide-stack-live.sh" ]]; then
    echo "==> Guide + Neo4j (optional retrieve)"
    GUIDE_KEEP=1 SDLC_GUIDE_STACK_LIVE=1 \
      "$ORCH_HOME/tests/test-guide-stack-live.sh" || echo "Guide stack failed (optional)"
  else
    echo "==> Guide skipped (no orch-guide clone)"
  fi
fi

if [[ "$WITH_API" == "1" ]]; then
  echo "==> dogfood API :$API_PORT"
  (cd "$ROOT" && ./mvnw -q -DskipTests spring-boot:run -Dspring-boot.run.arguments="--server.port=$API_PORT") &
  echo "    GET http://127.0.0.1:$API_PORT/api/orders?email=ops@example.com"
fi

echo
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
