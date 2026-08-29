# Cursor agent day

This is the dogfood test that proves **agent linkage**. It is not `./mvnw test`.

Dogfood exists so we can run this **inside a Cursor environment**. When
`CURSOR_AGENT=1` (Cloud Agent / IDE agent), this process **is** the agent:
it follows `/sdlc-next` and runs `sdlc.sh`, then an unstructured persist.

Outside Cursor, `CURSOR_API_KEY` + `@cursor/sdk` spawn an agent that does
the same. A Cloud-injected token that is not a [User API key](https://cursor.com/dashboard/integrations)
will 401 — use the in-environment path instead.

```bash
# already in Cursor / this Cloud Agent:
./scripts/up.sh --setup-only
./scripts/agent-day/run.sh
# same as: ./scripts/up.sh --prove
```
