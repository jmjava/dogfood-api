# dogfood-api

Playable **consumer** for the DIF + orchestrator ecosystem. This is the
product you iterate on. It is not the folder, not the runbook, and not
Guide.

```text
dogfood-api                 product (this repo)
sdlc-spdd-orchestrator      process + Dashboard :5051
embabel-dif                 fold (canvas → .gate.json)
orch-guide                  optional retrieve (Neo4j)
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

`up.sh` clones missing siblings under `.tools/` (or uses `ORCH_HOME` /
`DIF_HOME` / `GUIDE_HOME`), installs orch adapters, claims the Work ID,
folds when DIF is present, stages **both** harvests, and starts the
ops console:

```text
http://127.0.0.1:5051/?target=$PWD
```

Refresh is a readout. It does not fold or start Embabel.

```bash
./scripts/up.sh --setup-only     # install + claim + fold; no console
./scripts/up.sh --with-api       # also boot GET /api/orders on :8080
./scripts/up.sh --with-guide     # optional orch-guide + Neo4j
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
