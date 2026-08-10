#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const outputDir = path.join(root, "artifacts/raw/e03-release-drift");
const nearest = (values, percentile) => [...values].sort((a, b) => a - b)[Math.ceil(percentile / 100 * values.length) - 1];
const statistics = values => ({ samples: values.length, mean: values.reduce((a, b) => a + b, 0) / values.length, p50: nearest(values, 50), p95: nearest(values, 95), p99: nearest(values, 99), max: Math.max(...values) });
const relative = file => path.relative(root, file).split(path.sep).join("/");
const sha = file => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const artifact = file => ({ path: relative(file), sha256: sha(file) });
const trialFiles = [];
const engines = {};
for (const engine of ["unity", "godot"]) {
  const trials = [];
  const allAbsolute = [];
  for (let trial = 1; trial <= 3; trial++) {
    const file = path.join(outputDir, engine, `trial-${trial}.jsonl`);
    trialFiles.push(file);
    const records = fs.readFileSync(file, "utf8").trim().split("\n").map(JSON.parse);
    const session = records.find(record => record.record_type === "session");
    const samples = records.filter(record => record.record_type === "sample");
    const absolute = samples.map(record => Math.abs(record.drift_us));
    allAbsolute.push(...absolute);
    const final = samples.at(-1);
    trials.push({ trial, status: "valid", samples: samples.length, final_drift_us: final.drift_us, final_absolute_drift_us: Math.abs(final.drift_us), audio_driver: session.audio_driver ?? "Unity audio output", output_sample_rate_hz: session.output_sample_rate_hz ?? session.mix_rate_hz, evidence: relative(file) });
  }
  const finals = trials.map(trial => trial.final_absolute_drift_us);
  const driverValid = engine === "unity" || trials.every(trial => trial.audio_driver !== "Dummy");
  engines[engine] = { planned: 3, attempted: 3, valid: 3, failed: 0, missing: 0, duration_seconds: 60, threshold_us: 5000, audio_driver_valid: driverValid, final_absolute_us: statistics(finals), all_sample_absolute_us: statistics(allAbsolute), trials, hard_gate: driverValid && finals.every(value => value <= 5000) ? "Pass" : "Fail" };
}
const summary = { schema_version: "1.0.0", contract_change: "EC-001", fixture: "shared/fixtures/test-pack/click.wav", engines, residual_risk: "Drift beyond one minute is not a Phase 0 hard gate after EC-001 and remains a Phase 1 measurement." };
const summaryPath = path.join(outputDir, "summary.json");
fs.writeFileSync(summaryPath, `${JSON.stringify(summary, null, 2)}\n`);
const manifest = { schema_version: "1.0.0", run_id: "e03-release-drift-1m-x3", engine: "common", started_at: new Date().toISOString(), source_revision: "working-tree", build_type: "release", clock_domains: ["monotonic", "unity_dsp", "godot_audio"], inputs: [path.join(root, "shared/fixtures/test-pack/click.wav"), ...trialFiles].map(artifact), outputs: [summaryPath].map(artifact) };
fs.writeFileSync(path.join(outputDir, "run-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`release drift: Unity ${engines.unity.hard_gate}; Godot ${engines.godot.hard_gate}`);
