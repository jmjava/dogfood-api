# Cursor agent day

Full orch/DIF proof: **spawn a real Cursor agent**. Needs the Cloud Agent
secret **`CORRECT_CURSOR_KEY`** (Integrations user key, `cursor_…`).

Do not use the injected `CURSOR_API_KEY` (`sk-proj…` → SDK 401).

```bash
./scripts/up.sh --setup-only
./scripts/agent-day/run.sh
# same as: ./scripts/up.sh --prove
```

After you add `CORRECT_CURSOR_KEY` in the environment secrets, start a
**new** Cloud Agent. This VM only sees secrets that existed at boot.
