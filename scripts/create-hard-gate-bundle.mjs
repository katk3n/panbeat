#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

const root = path.resolve(import.meta.dirname, "..");
const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) args.set(process.argv[i], process.argv[i + 1]);
const engine = args.get("--engine");
const buildSeconds = Number(args.get("--clean-build-seconds"));
const testSeconds = Number(args.get("--clean-test-seconds"));
if (!new Set(["unity", "godot"]).has(engine) || !Number.isFinite(buildSeconds) || !Number.isFinite(testSeconds)) {
  console.error("Usage: create-hard-gate-bundle.mjs --engine unity|godot --clean-build-seconds N --clean-test-seconds N");
  process.exit(64);
}

const story = engine === "unity" ? "u06" : "g06";
const outputDir = path.join(root, "artifacts", "raw", `${engine}-${story}`);
fs.mkdirSync(outputDir, { recursive: true });
const rel = value => value.split(path.sep).join("/");
const sha = relative => crypto.createHash("sha256").update(fs.readFileSync(path.join(root, relative))).digest("hex");
const artifact = relative => ({ path: rel(relative), sha256: sha(relative) });
const readJson = relative => JSON.parse(fs.readFileSync(path.join(root, relative), "utf8"));

const profile = "shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json";
const slapTrace = "artifacts/raw/m02-mood-pan-20260810/handpan-minor-slap-left3-then-right3.jsonl";
const lifecycle = `artifacts/raw/${engine}-${engine === "unity" ? "u03" : "g03"}/lifecycle-verified.jsonl`;
const drift = `artifacts/raw/${engine}-${engine === "unity" ? "u02" : "g02"}/summary.json`;
const judgements = `artifacts/raw/${engine}-${engine === "unity" ? "u05" : "g05"}/judgements-60hz.json`;
const screenshot = `artifacts/reports/${engine}-${engine === "unity" ? "u04" : "g04"}/three-techniques.png`;
const buildZip = `artifacts/builds/${engine}-${story}/PanBeat.zip`;
const testLog = `artifacts/reports/${engine}-${story}/${engine === "unity" ? "editmode.log" : "headless-verified.log"}`;
const testResult = engine === "unity" ? `artifacts/reports/${engine}-${story}/editmode-results.xml` : null;
const driftSummary = readJson(drift);

const hardGates = engine === "unity" ? [
  { id: "slap-identification", status: "Pass", rationale: "Handpan left/right Slap produced the dedicated profile mapping in the retained real-device trace; mapper regression tests passed.", evidence: [slapTrace, profile] },
  { id: "input-jitter", status: "Not Measured", rationale: "CoreMIDI packet timestamps were retained, but this run has no independent engine-dispatch timestamp from which callback-to-engine jitter can be computed without fabrication.", evidence: [lifecycle] },
  { id: "audio-visual-drift", status: "Fail", rationale: `The retained 5-minute DSP-versus-monotonic diagnostic ended at ${Math.abs(driftSummary.runs.find(run => run.label === "5m").final) / 1000} ms absolute drift, above the fixed 5 ms target.`, evidence: [drift] },
  { id: "frame-independence", status: "Pass", rationale: "60 Hz, 120 Hz, and intentional frame-stall judgement records all equal the shared golden result.", evidence: [judgements] },
  { id: "device-lifecycle", status: "Pass", rationale: "The actual trace records present, absent, present and six mapped strikes with zero native queue drops.", evidence: [lifecycle] },
  { id: "automation", status: "Pass", rationale: "A fresh project import, EditMode suite, release build, slice generation, and capture are CLI-driven with zero GUI interventions.", evidence: [testLog, buildZip] }
] : [
  { id: "slap-identification", status: "Pass", rationale: "Handpan left/right Slap produced the dedicated profile mapping in the retained real-device trace; mapper regression tests passed.", evidence: [slapTrace, profile] },
  { id: "input-jitter", status: "Pass", rationale: "The standard adapter arrival-handling spread was 0.069 ms p95 over 24 retained messages, below the fixed 5 ms target; this is not physical or CoreMIDI latency.", evidence: [lifecycle] },
  { id: "audio-visual-drift", status: "Not Measured", rationale: "The 5-minute headless run used Godot's Dummy audio driver, so it is diagnostic evidence and not a real-output drift measurement.", evidence: [drift] },
  { id: "frame-independence", status: "Pass", rationale: "60 Hz, 120 Hz, and intentional frame-stall judgement records all equal the shared golden result.", evidence: [judgements] },
  { id: "device-lifecycle", status: "Pass", rationale: "Godot kept the port listed, stopped receiving while disconnected, and automatically resumed; six mapped strikes were retained across the disconnect.", evidence: [lifecycle] },
  { id: "automation", status: "Pass", rationale: "A fresh project import, headless suite, release export, slice generation, and capture are CLI-driven with zero GUI interventions.", evidence: [testLog, buildZip] }
];

const buildMetadata = {
  schema_version: "1.0.0",
  engine,
  build_type: "release",
  clean_checkout_equivalent: true,
  excluded_from_clean_copy: [".git", ".tools", "node_modules", "pocs/unity/Library", "pocs/unity/UserSettings", "pocs/godot/.godot", "artifacts/builds", "artifacts/reports"],
  clean_test_seconds: testSeconds,
  clean_build_seconds: buildSeconds,
  gui_intervention_count: 0,
  automatic_retry_count: 0,
  attempted_clean_test_runs: engine === "godot" ? 2 : 1,
  failed_clean_test_runs: engine === "godot" ? 1 : 0,
  machine: { hostname: os.hostname(), platform: os.platform(), release: os.release(), architecture: os.arch(), cpu: os.cpus()[0]?.model ?? "unknown", logical_cpu_count: os.cpus().length, memory_bytes: os.totalmem() },
  build_artifact: artifact(buildZip)
};
const metadataPath = `artifacts/raw/${engine}-${story}/build-metadata.json`;
fs.writeFileSync(path.join(root, metadataPath), `${JSON.stringify(buildMetadata, null, 2)}\n`);

const summary = {
  schema_version: "1.0.0",
  engine,
  story: story.toUpperCase(),
  build_type: "release",
  gui_intervention_count: 0,
  automatic_retry_count: 0,
  run_accounting: engine === "godot"
    ? { attempted: 2, valid: 1, failed: 1, missing: 0, failure: "Initial clean-cache parse exposed an implicit global-class dependency; the failed log is retained and the source was fixed before a separately invoked verification run." }
    : { attempted: 1, valid: 1, failed: 0, missing: 0 },
  hard_gates: hardGates,
  limitations: engine === "unity"
    ? ["Input dispatch jitter is not measured by the retained lifecycle trace.", "The 5-minute DSP-versus-monotonic diagnostic fails the fixed drift target and is not an audio-loopback measurement."]
    : ["Godot exposes no OS receive timestamp through its public MIDI API.", "Headless Dummy-driver drift is not real-output latency evidence."],
};
const summaryPath = `artifacts/raw/${engine}-${story}/hard-gate-summary.json`;
fs.writeFileSync(path.join(root, summaryPath), `${JSON.stringify(summary, null, 2)}\n`);

const inputs = [profile, slapTrace, lifecycle, drift, judgements].map(artifact);
const outputPaths = [summaryPath, metadataPath, screenshot, buildZip, testLog];
if (testResult) outputPaths.push(testResult);
if (engine === "godot") outputPaths.push("artifacts/reports/godot-g06/headless.log");
const manifest = {
  schema_version: "1.0.0",
  run_id: `${engine}-${story}`,
  engine,
  started_at: new Date().toISOString(),
  source_revision: "working-tree",
  build_type: "release",
  clock_domains: ["song_time", "monotonic", engine === "unity" ? "unity_dsp" : "godot_audio"],
  inputs,
  outputs: outputPaths.map(artifact)
};
fs.writeFileSync(path.join(outputDir, "run-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`${engine.toUpperCase()} ${story.toUpperCase()} measurement bundle generated`);
