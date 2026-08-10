#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createTraceValidator, makeReplayFixture, readTrace, replayTrace, summarizeTrace } from "./lib/midi-trace.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const usage = () => process.stdout.write("Usage:\n  scripts/midi-trace validate --input PATH\n  scripts/midi-trace summarize --input PATH [--output PATH]\n  scripts/midi-trace replay --input PATH [--mode realtime|no-wait] [--speed NUMBER] [--output PATH]\n");
const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) { usage(); process.exit(0); }
const command = args.shift();
if (!["validate", "summarize", "replay"].includes(command)) { usage(); process.exit(64); }
const options = { mode: "realtime", speed: 1 };
while (args.length) {
  const key = args.shift(); const value = args.shift();
  if (!value || !["--input", "--output", "--mode", "--speed"].includes(key)) { process.stderr.write(`midi-trace: invalid option ${key}\n`); process.exit(64); }
  options[key.slice(2)] = value;
}
if (!options.input) { process.stderr.write("midi-trace: --input is required\n"); process.exit(64); }
if (options.mode !== "realtime" && options.mode !== "no-wait") { process.stderr.write("midi-trace: --mode must be realtime or no-wait\n"); process.exit(64); }
options.speed = Number(options.speed);
const schema = JSON.parse(fs.readFileSync(path.join(root, "schemas/raw-midi-trace.schema.json"), "utf8"));
try {
  const trace = readTrace(path.resolve(options.input), createTraceValidator(schema));
  if (command === "validate") { process.stdout.write(`Valid trace: ${trace.events.length} event(s).\n`); process.exit(0); }
  const write = (value) => {
    const text = `${JSON.stringify(value, null, 2)}\n`;
    if (options.output) fs.writeFileSync(path.resolve(options.output), text); else process.stdout.write(text);
  };
  if (command === "summarize") write(summarizeTrace(trace));
  if (command === "replay") {
    if (options.mode === "no-wait") write(makeReplayFixture(trace, options.speed));
    else {
      const emitted = [];
      const fixture = await replayTrace(trace, { speed: options.speed, emit: (item) => emitted.push(item) });
      write({ ...fixture, events: emitted });
    }
  }
} catch (error) {
  process.stderr.write(`midi-trace: ${error.message}\n`);
  process.exit(1);
}
