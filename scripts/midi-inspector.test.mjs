import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import test from "node:test";

const command = path.resolve("scripts/midi-inspector");
test("help and list work without a device", () => {
  assert.equal(spawnSync(command, ["--help"], { encoding: "utf8" }).status, 0);
  assert.equal(spawnSync(command, ["list"], { encoding: "utf8" }).status, 0);
});
test("synthetic capture preserves raw bytes and normalizes velocity-zero note-on", () => {
  const output = path.join(os.tmpdir(), `panbeat-midi-inspector-${process.pid}.jsonl`);
  const run = spawnSync(command, ["synthetic", "--output", output], { encoding: "utf8" });
  assert.equal(run.status, 0, run.stderr);
  const records = fs.readFileSync(output, "utf8").trim().split("\n").map(JSON.parse);
  assert.equal(records[0].source_kind, "synthetic");
  assert.deepEqual(records[2].raw_bytes, [0x90, 60, 0]);
  assert.equal(records[2].message_type, "note_off");
  assert.equal(records[3].channel_wire, 1);
  assert.equal(records[3].channel_display, 2);
  fs.unlinkSync(output);
});
test("SIGINT flushes and closes a live capture", async () => {
  const output = path.join(os.tmpdir(), `panbeat-midi-inspector-signal-${process.pid}.jsonl`);
  const child = spawn(command, ["synthetic", "--output", output, "--hold"], { stdio: "ignore" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  child.kill("SIGINT");
  const status = await new Promise((resolve) => child.once("exit", resolve));
  assert.equal(status, 0);
  const records = fs.readFileSync(output, "utf8").trim().split("\n").map(JSON.parse);
  assert.equal(records.length, 5);
  fs.unlinkSync(output);
});
