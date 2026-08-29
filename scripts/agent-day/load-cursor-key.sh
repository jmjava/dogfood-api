#!/usr/bin/env bash
# Resolve the Cursor *User API* key. Do not use the Cloud-injected CURSOR_API_KEY
# (that one is sk-proj-… and Agent.create returns 401).
#
# Preferred name: CORRECT_CURSOR_KEY (Cloud Agent secret).
# Also accepts CURSOR_USER_API_KEY, or CURSOR_API_KEY only if it looks like cursor_…
set -euo pipefail

_looks_like_user_key() {
  local v="$1"
  [[ "$v" == cursor_* ]]
}

if [[ -n "${CORRECT_CURSOR_KEY:-}" ]]; then
  export CURSOR_API_KEY="$CORRECT_CURSOR_KEY"
  echo "using CORRECT_CURSOR_KEY (len=${#CORRECT_CURSOR_KEY})"
  return 0 2>/dev/null || exit 0
fi
if [[ -n "${CURSOR_USER_API_KEY:-}" ]]; then
  export CURSOR_API_KEY="$CURSOR_USER_API_KEY"
  echo "using CURSOR_USER_API_KEY"
  return 0 2>/dev/null || exit 0
fi
if [[ -n "${CURSOR_API_KEY:-}" ]] && _looks_like_user_key "$CURSOR_API_KEY"; then
  echo "using CURSOR_API_KEY (user-shaped)"
  return 0 2>/dev/null || exit 0
fi

echo "FAIL: no Cursor User API key in this process." >&2
echo "  This Cloud Agent secret must be named CORRECT_CURSOR_KEY" >&2
echo "  (Integrations key from https://cursor.com/dashboard/integrations)." >&2
echo "  A new agent run is required after you add it — this VM was started without it." >&2
echo "  Do not reuse the injected CURSOR_API_KEY (sk-proj… → SDK 401)." >&2
return 1 2>/dev/null || exit 1
