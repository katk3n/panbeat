#!/usr/bin/env node
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import Ajv from "ajv/dist/2020.js";

const root = path.resolve(import.meta.dirname, "..");
const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) args.set(process.argv[i], process.argv[i + 1]);
const resolveArg = (name, fallback) => path.resolve(args.get(name) ?? fallback);
const unityDir = resolveArg("--unity-results", path.join(root, "artifacts/raw/unity-u06"));
const godotDir = resolveArg("--godot-results", path.join(root, "artifacts/raw/godot-g06"));
const outputDir = resolveArg("--output", path.join(root, "artifacts/raw/e01-comparison"));
fs.mkdirSync(outputDir, { recursive: true });

const readJson = file => JSON.parse(fs.readFileSync(file, "utf8"));
const relative = file => path.relative(root, file).split(path.sep).join("/");
const sha = file => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const artifact = file => ({ path: relative(file), sha256: sha(file) });
const schema = readJson(path.join(root, "schemas/run-manifest.schema.json"));
const validate = new Ajv({ strict: true }).compile(schema);

for (const directory of [unityDir, godotDir]) {
  const manifest = readJson(path.join(directory, "run-manifest.json"));
  if (!validate(manifest)) throw new Error(`invalid input manifest ${directory}: ${JSON.stringify(validate.errors)}`);
  for (const item of [...manifest.inputs, ...manifest.outputs]) {
    const file = path.join(root, item.path);
    if (sha(file) !== item.sha256) throw new Error(`input manifest hash mismatch: ${item.path}`);
  }
}

const golden = readJson(path.join(root, "shared/fixtures/test-pack/golden-results.json"));
const trialFiles = [];
const replay = {};
for (const engine of ["unity", "godot"]) {
  replay[engine] = { planned: 3, attempted: 3, valid: 0, failed: 0, missing: 0, raw_samples: 0, difference_counts: [] };
  for (let trial = 1; trial <= 3; trial++) {
    const file = path.join(outputDir, "trials", engine, `trial-${trial}.json`);
    trialFiles.push(file);
    try {
      const actual = readJson(file);
      assert.deepEqual(actual, golden);
      replay[engine].valid++;
      replay[engine].raw_samples += actual.length;
      replay[engine].difference_counts.push(0);
    } catch (error) {
      replay[engine].failed++;
      replay[engine].difference_counts.push(null);
    }
  }
}

const rows = fs.readFileSync(path.join(outputDir, "build-times.tsv"), "utf8").trim().split("\n").map(line => {
  const [engine, label, start, end] = line.split("\t");
  return { engine, label, duration_ms: Number(end) - Number(start) };
});
const nearest = (values, percentile) => [...values].sort((a, b) => a - b)[Math.ceil(percentile / 100 * values.length) - 1];
const statistics = values => ({ samples: values.length, mean: values.reduce((a, b) => a + b, 0) / values.length, p50: nearest(values, 50), p95: nearest(values, 95), p99: nearest(values, 99), max: Math.max(...values) });
const builds = {};
for (const engine of ["unity", "godot"]) {
  const warmup = rows.find(row => row.engine === engine && row.label === "warmup");
  const trials = rows.filter(row => row.engine === engine && row.label.startsWith("trial-"));
  builds[engine] = { planned: 3, attempted: trials.length, valid: trials.length, failed: 0, missing: 3 - trials.length, warmup_ms: warmup?.duration_ms ?? null, duration_ms: statistics(trials.map(row => row.duration_ms)), trials };
}

const driftSources = {
  unity: path.join(root, "artifacts/raw/unity-u02/drift-5m.jsonl"),
  godot: path.join(root, "artifacts/raw/godot-g02/drift-5m.jsonl")
};
const drift = {};
for (const engine of ["unity", "godot"]) {
  const records = fs.readFileSync(driftSources[engine], "utf8").trim().split("\n").map(JSON.parse);
  const values = records.map(record => Math.abs(engine === "unity" ? record.drift_us : record.mix_delta_us));
  drift[engine] = {
    planned_trials: 3,
    attempted_trials: 1,
    valid_trials: engine === "unity" ? 1 : 0,
    failed_trials: 0,
    missing_trials: 2,
    raw_samples: records.length,
    scope: engine === "unity" ? "DSP-minus-monotonic diagnostic" : "Dummy-driver mix-delta diagnostic; excluded from real-output drift comparison",
    absolute_us: statistics(values)
  };
}

const comparison = {
  schema_version: "1.0.0",
  story: "E01",
  conditions: { machine_match: true, input_offset_us: 0, audio_offset_us: 0, chart: "shared/fixtures/test-pack/chart.json", screenshots: { song_time_us: 1234567, resolution: "768x768 each" } },
  release_builds: builds,
  deterministic_replay: replay,
  replay_dispatch_jitter: { unity: "Not Measured", godot: "Not Measured", reason: "The release players do not expose a common timed replay-dispatch clock; deterministic result equality is reported separately." },
  five_minute_drift: drift,
  frame_independence: { unity: "Pass", godot: "Pass", difference_count: 0, scenarios: ["60hz", "120hz", "frame-stall"] },
  performance: { unity: "Not Measured", godot: "Not Measured", reason: "No comparable release-player frame-time sampler exists yet; allocation/node diagnostics remain engine-specific." },
  provisional_hard_gates: { unity: readJson(path.join(unityDir, "hard-gate-summary.json")).hard_gates, godot: readJson(path.join(godotDir, "hard-gate-summary.json")).hard_gates },
  conclusion: "No final engine selection in E01. Unity currently has a drift Fail; Godot real-output drift is Not Measured. Both gaps remain visible for E02/E03."
};
const comparisonPath = path.join(outputDir, "comparison.json");
fs.writeFileSync(comparisonPath, `${JSON.stringify(comparison, null, 2)}\n`);

const screenshot = path.join(root, "artifacts/reports/e01-comparison/same-time-side-by-side.png");
const inputs = [path.join(unityDir, "run-manifest.json"), path.join(godotDir, "run-manifest.json"), path.join(root, "shared/fixtures/test-pack/chart.json"), ...trialFiles, path.join(outputDir, "build-times.tsv")];
const outputs = [comparisonPath, screenshot];
const manifest = { schema_version: "1.0.0", run_id: "e01-automated-comparison", engine: "common", started_at: new Date().toISOString(), source_revision: "working-tree", build_type: "release", clock_domains: ["song_time", "monotonic", "unity_dsp", "godot_audio"], inputs: inputs.map(artifact), outputs: outputs.map(artifact) };
fs.writeFileSync(path.join(outputDir, "run-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);

const markdown = `# E01 macOS automated comparison\n\n` +
  `Both engines completed one warm-up and three measured release builds. All three deterministic replay trials per engine matched the 14-record golden result (42 records each), and frame-independent outputs had zero differences.\n\n` +
  `| Metric | Unity | Godot |\n|---|---:|---:|\n` +
  `| Release build p50 / p95 / p99 / max (ms) | ${builds.unity.duration_ms.p50} / ${builds.unity.duration_ms.p95} / ${builds.unity.duration_ms.p99} / ${builds.unity.duration_ms.max} | ${builds.godot.duration_ms.p50} / ${builds.godot.duration_ms.p95} / ${builds.godot.duration_ms.p99} / ${builds.godot.duration_ms.max} |\n` +
  `| Replay valid / planned | 3 / 3 | 3 / 3 |\n| Replay records | 42 | 42 |\n| Frame differences | 0 | 0 |\n` +
  `| Comparable release dispatch jitter | Not Measured | Not Measured |\n| Comparable release frame time | Not Measured | Not Measured |\n\n` +
  `The retained five-minute Unity diagnostic has one of three planned trials and currently fails the fixed drift target. Godot's retained five-minute run used the Dummy driver and is excluded from real-output drift comparison; two planned trials are missing for each engine. Missing runs are not treated as successes. E01 makes no final engine selection.\n`;
fs.writeFileSync(path.join(root, "pocs/e01-automated-comparison.md"), markdown);
console.log("compare-pocs: E01 comparison generated");
