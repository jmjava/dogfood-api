# dogfood-api

Playable **consumer** for the DIF + orchestrator ecosystem. This is the
product you iterate on. It is not the folder, not the runbook, and not
Guide.

```text
dogfood-api                 product (this repo)
sdlc-spdd-orchestrator      process + Dashboard :5051
embabel-dif                 fold (canvas → .gate.json)
orch-guide                  retrieve (marker always installed; live stack optional)
```

Both usage modes land on the **same tree**:

| Mode | What you do | What is stored |
| --- | --- | --- |
| **Structured** | Claim `FEAT-001-order-status-api`, fold the REASONS canvas, code one T## | Work ID + canvas + `.gate.json` + optional lesson with `--work-id` |
| **Unstructured** | Open a prompt and fix `notify/` | `kind + area + body` (`source=adhoc-prompt`). **No** `FEAT-ADHOC`. **No** fold |

## Bootstrap the whole ecosystem

```bash
git clone https://github.com/jmjava/dogfood-api.git
cd dogfood-api
./scripts/up.sh
```

`up.sh` is a **full** install for this demo — not `--cursor` only.
It clones missing siblings under `.tools/` (or uses `ORCH_HOME` /
`DIF_HOME` / `GUIDE_HOME`), installs Cursor + Copilot + Claude + the
Guide marker, claims the Work ID, **requires** a DIF fold, stages
**both** harvests, and starts the ops console:

```text
http://127.0.0.1:5051/?target=$PWD
```

Refresh is a readout. It does not fold or start Embabel.

```bash
./scripts/up.sh --setup-only        # full install + claim + fold; no console
./scripts/up.sh --prove             # then /sdlc-next + unstructured persist (no extra key)
./scripts/up.sh --with-api          # also boot GET /api/orders on :8080
./scripts/up.sh --with-guide-stack  # also boot live orch-guide + Neo4j
```

## What the tests prove

| Lane | Command | LLM? |
| --- | --- | --- |
| API | `./mvnw test` | No |
| Install + both harvests | `./scripts/up.sh --setup-only` | No |
| **Agent linkage** | `./scripts/agent-day/run.sh` | **Yes — this Cursor environment** |

`./mvnw test` is the API. The linkage test is `./scripts/agent-day/run.sh`:
it spawns a Cursor agent with the Cloud secret **`CORRECT_CURSOR_KEY`**
(Integrations user key, `crsr_…` / `cursor_…`), locked to **`composer-2.5`**
plus time/token caps. Do not use the injected `CURSOR_API_KEY` (`sk-proj…` →
401). Add the secret, then start a **new** agent — this VM only sees secrets
from boot. GitGuardian CI (`.github/workflows/gitguardian.yml`) fails closed
unless `GITGUARDIAN_API_KEY` is a repo Actions secret.

```bash
# new Cloud Agent: from embabel-dif
./scripts/bootstrap-cursor-agent-day.sh
# or already on the feature branch:
./scripts/up.sh --setup-only
./scripts/agent-day/run.sh
```

From `embabel-dif` the same path is `./scripts/ecosystem-up.sh`.

## What is in the product

| Package | Job | Mode |
| --- | --- | --- |
| `api` / `service` / `persist` | `GET /api/orders?email=` — 400 / empty 200 | Structured `FEAT-001` |
| `auth` | `X-Dogfood-Key` on `/api/admin/**` only | Safeguard — do not change |
| `notify` | Webhook retry **without** an idempotency key | Unstructured pitfall |

```bash
./mvnw test
./mvnw spring-boot:run
curl 'http://127.0.0.1:8080/api/orders?email=ops@example.com'
```

T03 on the canvas (document the API) is still **Not Started**. Fold
reports that as a `MissingObligation`. That is intentional.

## Play both days

Structured (Work ID already claimed by `up.sh`):

```bash
# orch pointer + canvas + gate chip on the Dashboard
$ORCH_HOME/scripts/sdlc.sh --target . next
# fold again after you edit sdlc-spdd/spdd/canvas/FEAT-001-order-status-api.md
$DIF_HOME/scripts/dif-fold.sh architect --quiet \
  --canvas sdlc-spdd/spdd/canvas/FEAT-001-order-status-api.md \
  --out .dif/projections
```

Unstructured (do **not** invent a Work ID):

```bash
# after you poke notify/WebhookNotifier.java in a raw prompt:
$ORCH_HOME/scripts/sdlc.sh --target . context persist-lesson \
  --kind pitfall --area notify --source adhoc-prompt \
  --body "Retry without an idempotency key double-posts." --no-guide
$ORCH_HOME/scripts/sdlc.sh --target . context retrieve --area notify
```

The Dashboard Memory card counts the staged row. Active work still
shows `FEAT-001` and `dif=ready` if a gate file exists.

## What this repo is not

- Not a second orchestrator
- Not a DIF / Embabel runtime
- Not a reason to fold ad hoc chat
- Not a fake `FEAT-ADHOC-*` so capture validates
