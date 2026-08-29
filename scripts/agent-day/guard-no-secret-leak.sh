#!/usr/bin/env bash
# Fail closed if a live secret VALUE is present in git-tracked files.
# Complements GitGuardian CI. Does not print secret values.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FAIL: not a git checkout" >&2
  exit 1
fi

fail=0

check_name() {
  local name="$1"
  local val="${!name:-}"
  if [[ -z "$val" || ${#val} -lt 12 ]]; then
    return 0
  fi
  if git grep -F --cached -n -- "$val" >/dev/null 2>&1 \
    || git grep -F -n -- "$val" >/dev/null 2>&1; then
    echo "FAIL: value of ${name} is in a tracked file" >&2
    fail=1
  fi
}

IFS=',' read -r -a from_env <<< "${CLOUD_AGENT_ALL_SECRET_NAMES:-}"
names=(
  CORRECT_CURSOR_KEY
  CURSOR_API_KEY
  CURSOR_USER_API_KEY
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
  GITGUARDIAN_API_KEY
  "${from_env[@]}"
)

declare -A seen=()
for name in "${names[@]}"; do
  name="${name// /}"
  [[ -z "$name" || -n "${seen[$name]:-}" ]] && continue
  seen[$name]=1
  check_name "$name"
done

if git grep -nE -- 'sk-proj-[A-Za-z0-9_-]{16,}|sk-ant-[A-Za-z0-9_-]{16,}' \
  -- ':!**/*.md' >/dev/null 2>&1; then
  echo "FAIL: sk-proj / sk-ant token-shaped string in tracked non-doc files" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "secret leak guard failed" >&2
  exit 1
fi
echo "secret leak guard: OK"
