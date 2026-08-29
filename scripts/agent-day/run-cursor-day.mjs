#!/usr/bin/env node
/**
 * Hit Cursor with CORRECT_CURSOR_KEY. The spawned agent runs /sdlc-next
 * then unstructured persist. Do not use the Cloud-injected sk-proj token.
 *
 * Spend locks: composer-2.5 only, 2 sends, per-run timeout, total token cap.
 * Cancel the run if any lock trips. Never write secret values to disk.
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
const RUN_TIMEOUT_MS = Number(process.env.CURSOR_RUN_TIMEOUT_MS || 480_000);
const MAX_TOTAL_TOKENS = Number(process.env.CURSOR_MAX_TOTAL_TOKENS || 150_000);
const MAX_SENDS = Number(process.env.CURSOR_MAX_SENDS || 2);

const BUDGET = [
  "Spend locks (do not fight them):",
  `- Model is ${MODEL} only. Do not switch models or enable Fast.`,
  "- Do not spawn sub-agents, Cloud Agents, or extra SDK agents.",
  "- Do not retry, loop, or open a second investigation.",
  "- Do not print, echo, or write API keys / secrets / .env values.",
  "- Stop as soon as the requested sdlc commands succeed.",
].join("\n");

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
    BUDGET,
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
  BUDGET,
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

function usageTotal(usage) {
  if (!usage) return 0;
  return Number(usage.totalTokens || 0);
}

async function send(agent, prompt, spentTokens) {
  const run = await agent.send(prompt);
  let cancelled = "";
  const started = Date.now();
  const watch = setInterval(() => {
    const used = spentTokens + usageTotal(run.usage);
    if (!cancelled && Date.now() - started > RUN_TIMEOUT_MS) {
      cancelled = `timeout ${RUN_TIMEOUT_MS}ms`;
      run.cancel().catch(() => {});
    } else if (!cancelled && used > MAX_TOTAL_TOKENS) {
      cancelled = `token cap ${used}>${MAX_TOTAL_TOKENS}`;
      run.cancel().catch(() => {});
    }
  }, 2000);
  try {
    const result = await run.wait();
    const used = usageTotal(result.usage || run.usage);
    return {
      runId: run.id,
      status: result.status,
      tokens: used,
      cancelled,
    };
  } finally {
    clearInterval(watch);
  }
}

function writeReceipt(payload) {
  fs.mkdirSync(path.dirname(RECEIPT), { recursive: true });
  const text = JSON.stringify(payload, null, 2) + "\n";
  for (const name of ["CORRECT_CURSOR_KEY", "CURSOR_API_KEY", "CURSOR_USER_API_KEY"]) {
    const val = process.env[name];
    if (val && val.length >= 12 && text.includes(val)) {
      throw new Error(`refusing to write receipt: contains ${name}`);
    }
  }
  fs.writeFileSync(RECEIPT, text, "utf8");
}

async function main() {
  if (MODEL !== "composer-2.5") {
    console.error(`FAIL: refusing model=${MODEL}. Locked to composer-2.5.`);
    process.exit(1);
  }
  if (!API_KEY) {
    console.error("FAIL: CURSOR_API_KEY empty after load-cursor-key.sh");
    process.exit(1);
  }
  if (API_KEY.startsWith("sk-")) {
    console.error("FAIL: refusing sk-… token. Use CORRECT_CURSOR_KEY (crsr_… / cursor_…).");
    process.exit(1);
  }

  console.log("Cursor agent day (hits Cursor via SDK)");
  console.log(`  dogfood: ${ROOT}`);
  console.log(`  model:   ${MODEL}`);
  console.log(`  locks:   ${MAX_SENDS} sends, ${RUN_TIMEOUT_MS}ms/send, ${MAX_TOTAL_TOKENS} tokens`);

  const agent = await Agent.create({
    apiKey: API_KEY,
    model: { id: MODEL },
    local: { cwd: ROOT, settingSources: ["project"] },
    disallowedTools: ["task"],
  });

  const receipt = {
    schema: 2,
    hitCursor: true,
    mode: "sdk-spawn",
    extraKey: "CORRECT_CURSOR_KEY",
    agentId: agent.agentId || "",
    model: MODEL,
    locks: {
      maxSends: MAX_SENDS,
      runTimeoutMs: RUN_TIMEOUT_MS,
      maxTotalTokens: MAX_TOTAL_TOKENS,
    },
    commands: [],
    workId: WORK_ID,
    tokens: 0,
  };

  let spent = 0;
  try {
    console.log(`  agentId: ${agent.agentId}`);
    const jobs = [
      { slug: "sdlc-next", prompt: slashPrompt("sdlc-next") },
      { slug: "persist-lesson-unstructured", prompt: UNSTRUCTURED_PROMPT },
    ];
    if (jobs.length > MAX_SENDS) throw new Error(`jobs ${jobs.length} > CURSOR_MAX_SENDS=${MAX_SENDS}`);

    for (const job of jobs) {
      if (spent > MAX_TOTAL_TOKENS) throw new Error(`token cap before ${job.slug}: ${spent}>${MAX_TOTAL_TOKENS}`);
      console.log(`== ${job.slug} ==`);
      process.stdout.write("  running Cursor agent... ");
      const out = await send(agent, job.prompt, spent);
      spent += out.tokens;
      console.log(`runId=${out.runId} status=${out.status} tokens=${out.tokens} spent=${spent}`);
      receipt.commands.push({
        slug: job.slug,
        runId: out.runId,
        status: out.status,
        tokens: out.tokens,
        cancelled: out.cancelled || undefined,
      });
      receipt.tokens = spent;
      if (out.cancelled) throw new Error(`${job.slug} cancelled: ${out.cancelled}`);
      if (out.status !== "finished") throw new Error(`${job.slug} status=${out.status}`);
    }
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
  receipt.ok = verify.status === 0;
  receipt.verifiedAt = new Date().toISOString();
  if (verify.status !== 0) {
    receipt.error = receipt.error || `verify.sh exit ${verify.status}`;
    writeReceipt(receipt);
    process.exit(verify.status || 1);
  }
  writeReceipt(receipt);
  const status = spawnSync(path.join(ROOT, "scripts", "agent-day", "status.sh"), [], {
    encoding: "utf8",
    cwd: ROOT,
    env: { ...process.env, DOGFOOD_AGENT_RECEIPT: RECEIPT },
  });
  if (status.stdout) process.stdout.write(status.stdout);
  if (status.stderr) process.stderr.write(status.stderr);
  if (status.status !== 0) process.exit(status.status || 1);
  console.log("dogfood Cursor agent day: OK");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
