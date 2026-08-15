#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const readJson = file => JSON.parse(fs.readFileSync(file, "utf8"));
const sha256 = file => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const acceptance = readJson(path.join(root, "docs/phase1-acceptance.json"));

for (let number = 101; number <= 114; number += 1) {
  const story = `P${number}`;
  if (acceptance.stories[story] !== "complete") throw new Error(`${story} is not complete`);
  if (!acceptance.story_evidence[story]) throw new Error(`${story} has no evidence path`);
  if (story !== "P114" && !fs.existsSync(path.join(root, acceptance.story_evidence[story]))) throw new Error(`${story} evidence does not exist`);
}

if (acceptance.phase1_gate.decision !== "complete-with-deferred-release-gate-items" || acceptance.phase1_gate.mvp_complete !== false) throw new Error("Phase 1 must be complete without claiming MVP completion");
const risks = Object.fromEntries(acceptance.risks.map(risk => [risk.id, risk]));
if (acceptance.phase1_gate.phase1_blocking_risks.length !== 0) throw new Error("Phase 1 still has a blocking risk");
for (const blocker of acceptance.phase1_gate.deferred_release_gate_risks) {
  if (risks[blocker]?.status !== "deferred-release-gate-blocker" || risks[blocker]?.target_phase !== "Final Release Hardening") throw new Error(`${blocker} is not assigned to the final release gate`);
}

for (const inherited of acceptance.phase0_inheritance) {
  const file = path.join(root, inherited.path);
  if (!fs.existsSync(file)) throw new Error(`missing inherited Phase 0 evidence: ${inherited.path}`);
  if (inherited.sha256 && sha256(file) !== inherited.sha256) throw new Error(`Phase 0 evidence changed: ${inherited.path}`);
}

const p113 = readJson(path.join(root, acceptance.story_evidence.P113));
if (p113.status !== "complete" || p113.result !== "pass" || p113.completed_sessions !== 3) throw new Error("P113 is not a 3/3 pass");
const p112 = readJson(path.join(root, acceptance.story_evidence.P112));
if (p112.result !== "pass" || p112.runs.length !== 2 || !p112.determinism.byte_identical_across_runs) throw new Error("P112 two-run deterministic acceptance failed");

const report = fs.readFileSync(path.join(root, acceptance.phase1_gate.completion_report), "utf8");
for (const required of ["Decision: Complete with deferred release-gate items", "R-P1-001", "R-P1-003", "MVP完成やrelease許可を意味しない", "48 kHz mono signed 16-bit PCM WAV", "MusicXML", "Device Setup", "Calibration", "Song Library", "Results", "end-to-end latency", "Final Release Hardening Phaseへの必須引き継ぎ"]) {
  if (!report.includes(required)) throw new Error(`completion report is missing: ${required}`);
}
const architecture = fs.readFileSync(path.join(root, "docs/architecture.md"), "utf8");
for (const required of ["Phase 1 runtime音源形式", "48 kHz、mono、signed 16-bit PCM", "open-before-enumerate", "deferred-release-gate-blocker", "Final Phase: 現状予定なし"]) {
  if (!architecture.includes(required)) throw new Error(`architecture is missing: ${required}`);
}

const finalPlan = fs.readFileSync(path.join(root, acceptance.phase1_gate.final_phase_plan), "utf8");
for (const required of ["NOT PLANNED", "Archived plan", "FH01", "FH02", "FH03", "FH04", "6分以上", "p95が5 ms以下", "正式releaseを許可しない"]) {
  if (!finalPlan.includes(required)) throw new Error(`final phase plan is missing: ${required}`);
}

console.log("PANBEAT_PHASE1_GATE_AUDIT_OK historical-deferrals-retained-current-final-phase-not-planned");
