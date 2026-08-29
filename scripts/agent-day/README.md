# Cursor agent day

Full orch/DIF proof: **spawn a real Cursor agent**. Needs the Cloud Agent
secret **`CORRECT_CURSOR_KEY`** (Integrations user key, `crsr_…` or `cursor_…`).

Do not use the injected `CURSOR_API_KEY` (`sk-proj…` → SDK 401).

```bash
./scripts/up.sh --setup-only
./scripts/agent-day/run.sh
# same as: ./scripts/up.sh --prove
```

`run.sh` is locked to **`composer-2.5`** (cheapest standard model, not Fast)
with a 2-send / 8-minute / 150k-token / 12-minute wall budget. It cancels
the SDK run if a cap trips. GitGuardian CI (`.github/workflows/gitguardian.yml`)
fails closed without `GITGUARDIAN_API_KEY`. `guard-no-secret-leak.sh` refuses
to continue if a live secret value is in a tracked file.

After you add `CORRECT_CURSOR_KEY` in the environment secrets, start a
**new** Cloud Agent. This VM only sees secrets that existed at boot.
