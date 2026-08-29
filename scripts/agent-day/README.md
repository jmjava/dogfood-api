# Cursor agent day

This is the dogfood test that proves **agent linkage**. It is not `./mvnw test`.

`sdlc.sh` does not embed an LLM. The test **hits Cursor**: `@cursor/sdk` + `CURSOR_API_KEY` spawn a real agent on this repo. That agent reads `.cursor/commands/sdlc-next.md` and runs `sdlc.sh next`, then harvests an unstructured pitfall (`kind+area+body`, id slot `(none)`).

```bash
export CURSOR_API_KEY=cursor_...
./scripts/up.sh --setup-only
./scripts/agent-day/run.sh
# same as: ./scripts/up.sh --prove
```

Needs the full install (Cursor+Copilot+Claude pack already on the tree). Missing key is a fail, not a skip.
