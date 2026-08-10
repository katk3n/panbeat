#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const root = path.resolve(import.meta.dirname, "..");
const scoresPath = path.join(root, "shared/fixtures/engine-evaluation-scores.json");
const outputDir = path.join(root, "artifacts/raw/e03-engine-selection");
const scores = JSON.parse(fs.readFileSync(scoresPath, "utf8"));
const summaries = {
  unity: JSON.parse(fs.readFileSync(path.join(root, "artifacts/raw/unity-u06/hard-gate-summary.json"), "utf8")),
  godot: JSON.parse(fs.readFileSync(path.join(root, "artifacts/raw/godot-g06/hard-gate-summary.json"), "utf8"))
};
const releaseDrift = JSON.parse(fs.readFileSync(path.join(root, "artifacts/raw/e03-release-drift/summary.json"), "utf8"));
for (const engine of ["unity", "godot"]) {
  const gate = summaries[engine].hard_gates.find(item => item.id === "audio-visual-drift");
  gate.status = releaseDrift.engines[engine].hard_gate;
  gate.rationale = `EC-001 release measurement completed 3/3 one-minute trials; final absolute drift max was ${releaseDrift.engines[engine].final_absolute_us.max / 1000} ms against the 5 ms threshold.`;
  gate.evidence = ["artifacts/raw/e03-release-drift/summary.json"];
}
const weight = scores.items.reduce((sum, item) => sum + item.weight, 0);
if (weight !== 100) throw new Error(`weights must total 100, got ${weight}`);
for (const item of scores.items) for (const engine of ["unity", "godot"])
  if (!Number.isInteger(item[engine].score) || item[engine].score < scores.scale.minimum || item[engine].score > scores.scale.maximum || !item[engine].rationale)
    throw new Error(`invalid score: ${engine}/${item.id}`);

const engines = {};
for (const engine of ["unity", "godot"]) {
  const gates = summaries[engine].hard_gates;
  const failed = gates.filter(gate => gate.status === "Fail").map(gate => gate.id);
  const notMeasured = gates.filter(gate => gate.status === "Not Measured").map(gate => gate.id);
  const items = scores.items.map(item => ({ id: item.id, weight: item.weight, score: item[engine].score, weighted: item[engine].score / 5 * item.weight, rationale: item[engine].rationale }));
  engines[engine] = {
    hard_gates: gates,
    eligibility: failed.length ? "Excluded" : notMeasured.length ? "Pending risk acceptance or measurement" : "Eligible",
    failed_gates: failed,
    not_measured_gates: notMeasured,
    items,
    weighted_total: Number(items.reduce((sum, item) => sum + item.weighted, 0).toFixed(2))
  };
}
const result = {
  schema_version: "1.0.0",
  story: "E03",
  status: engines.godot.eligibility === "Eligible" ? "Complete" : "Pending",
  engines,
  formal_recommendation: engines.godot.eligibility === "Eligible" ? { engine: "godot", language: "typed GDScript", version: "4.6.stable.official.89cea1439", weighted_total: engines.godot.weighted_total } : null,
  blocker: engines.godot.eligibility === "Eligible" ? null : "No eligible engine is available.",
  residual_risks: ["Unity input dispatch jitter remains Not Measured, so Unity is not eligible without risk acceptance.", "Drift beyond one minute remains a Phase 1 measurement after EC-001.", "Godot's public MIDI API does not expose physical disconnect state or OS receive timestamps."]
};
fs.mkdirSync(outputDir, { recursive: true });
const resultPath = path.join(outputDir, "score-result.json");
fs.writeFileSync(resultPath, `${JSON.stringify(result, null, 2)}\n`);
const relative = file => path.relative(root, file).split(path.sep).join("/");
const artifact = file => ({ path: relative(file), sha256: crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex") });
const manifest = {
  schema_version: "1.0.0",
  run_id: "e03-engine-selection",
  engine: "common",
  started_at: new Date().toISOString(),
  source_revision: "working-tree",
  build_type: "tool",
  clock_domains: ["monotonic"],
  inputs: [scoresPath, path.join(root, "artifacts/raw/unity-u06/hard-gate-summary.json"), path.join(root, "artifacts/raw/godot-g06/hard-gate-summary.json"), path.join(root, "artifacts/raw/e02-real-device/summary.json"), path.join(root, "artifacts/raw/e03-release-drift/summary.json")].map(artifact),
  outputs: [resultPath].map(artifact)
};
fs.writeFileSync(path.join(outputDir, "run-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Unity ${engines.unity.weighted_total}; Godot ${engines.godot.weighted_total}; selection ${result.status}`);
