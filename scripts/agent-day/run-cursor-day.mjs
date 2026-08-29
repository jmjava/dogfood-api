#!/usr/bin/env node
/**
 * Hit Cursor with CORRECT_CURSOR_KEY. The spawned agent runs /sdlc-next
 * then unstructured persist. Do not use the Cloud-injected sk-proj token.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { Agent, CursorAgentError } from "@cursor/sdk";

const ROOT = process.env.DOGFOOD_ROOT || path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const WORK_ID = "FEAT-001-order-status-api";
const MODEL = process.env.LIVE_CURSOR_MODEL || "composer-2.5";
const API_KEY = process.env.CURSOR_API_KEY;
const RECEIPT = path.join(ROOT, "sdlc-spdd", ".sdlc", "agent-day.json");

function sdlcBin() {
  const local = path.join(ROOT, "sdlc-spdd", "scripts", "sdlc.sh");
  if (fs.existsSync(local)) return local;
  const orch = process.env.ORCH_HOME;
  if (orch) return path.join(orch, "scripts", "sdlc.sh");
  throw new Error("sdlc.sh not found");
}

function readCmd(slug) {
  return fs.readFileSync(path.join(ROOT, ".cursor", "commands", `${slug}.md`), "utf8");
}

function slashPrompt(slug, extra = "") {
  return [
    `You are the agent a user would use on dogfood-api.`,
    `Execute the Cursor slash command /${slug} against this repository.`,
    `When the command says to run sdlc.sh, run: ${sdlcBin()} --target ${ROOT} <subcommand>`,
    `Work ID if one is already claimed: ${WORK_ID}`,
    extra,
    "Stay in this working tree. Do not invent a FEAT-ADHOC Work ID.",
    "----- BEGIN COMMAND DEFINITION -----",
    readCmd(slug).trim(),
    "----- END COMMAND DEFINITION -----",
  ].join("\n");
}

const UNSTRUCTURED_PROMPT = [
  "This is the unstructured day. There is no new Work ID.",
  "A user opened a raw prompt about notify/WebhookNotifier.java (retry without an idempotency key).",
  `Run this exact harvest (do not invent FEAT-ADHOC):`,
  "",
  `${sdlcBin()} --target ${ROOT} context persist-lesson \\`,
  "  --kind pitfall --area notify --source dogfood-agent-day \\",
  '  --body "Cursor agent day: retry without an idempotency key double-posts." \\',
  "  --no-guide",
  "",
  "The persisted id must be pitfall:(none):notify:dogfood-agent-day.",
  "Then run retrieve:",
  `${sdlcBin()} --target ${ROOT} context retrieve --area notify`,
  "Do not fold the chat. Do not create a canvas.",
].join("\n");

async function send(agent, prompt) {
  const run = await agent.send(prompt);
  const result = await run.wait();
  return { runId: run.id, status: result.status };
}

function writeReceipt(payload) {
  fs.mkdirSync(path.dirname(RECEIPT), { recursive: true });
  fs.writeFileSync(RECEIPT, JSON.stringify(payload, null, 2) + "\n", "utf8");
}

async function main() {
  if (!API_KEY) {
    console.error("FAIL: CURSOR_API_KEY empty after load-cursor-key.sh");
    process.exit(1);
  }
  if (API_KEY.startsWith("sk-")) {
    console.error("FAIL: refusing sk-… token. Use CORRECT_CURSOR_KEY (cursor_…).");
    process.exit(1);
  }

  console.log("Cursor agent day (hits Cursor via SDK)");
  console.log(`  dogfood: ${ROOT}`);
  console.log(`  model:   ${MODEL}`);

  const agent = await Agent.create({
    apiKey: API_KEY,
    model: { id: MODEL },
    local: { cwd: ROOT, settingSources: ["project"] },
  });

  const receipt = {
    schema: 1,
    hitCursor: true,
    mode: "sdk-spawn",
    extraKey: "CORRECT_CURSOR_KEY",
    agentId: agent.agentId || "",
    model: MODEL,
    commands: [],
    workId: WORK_ID,
  };

  try {
    console.log(`  agentId: ${agent.agentId}`);
    console.log("== /sdlc-next ==");
    process.stdout.write("  running Cursor agent... ");
    const next = await send(agent, slashPrompt("sdlc-next"));
    console.log(`runId=${next.runId} status=${next.status}`);
    receipt.commands.push({ slug: "sdlc-next", runId: next.runId, status: next.status });
    if (next.status !== "finished") throw new Error(`/sdlc-next status=${next.status}`);

    console.log("== unstructured persist ==");
    process.stdout.write("  running Cursor agent... ");
    const raw = await send(agent, UNSTRUCTURED_PROMPT);
    console.log(`runId=${raw.runId} status=${raw.status}`);
    receipt.commands.push({ slug: "persist-lesson-unstructured", runId: raw.runId, status: raw.status });
    if (raw.status !== "finished") throw new Error(`unstructured status=${raw.status}`);
  } catch (err) {
    if (err instanceof CursorAgentError) {
      console.error(`FAIL Cursor: ${err.message} retryable=${err.isRetryable}`);
    } else {
      console.error(`FAIL: ${err}`);
    }
    receipt.error = String(err);
    writeReceipt(receipt);
    process.exit(1);
  } finally {
    if (typeof agent[Symbol.asyncDispose] === "function") await agent[Symbol.asyncDispose]();
    else if (typeof agent.close === "function") await agent.close();
  }

  writeReceipt(receipt);
  const verify = spawnSync(path.join(ROOT, "scripts", "agent-day", "verify.sh"), [], {
    encoding: "utf8",
    cwd: ROOT,
    env: { ...process.env, DOGFOOD_AGENT_RECEIPT: RECEIPT },
  });
  if (verify.stdout) process.stdout.write(verify.stdout);
  if (verify.stderr) process.stderr.write(verify.stderr);
  if (verify.status !== 0) process.exit(verify.status || 1);
  console.log("dogfood Cursor agent day: OK");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
