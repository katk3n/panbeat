#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourcePath = path.join(root, "shared/fixtures/test-pack-source.json");
const outputDirectory = path.join(root, "shared/fixtures/test-pack");
const mode = process.argv[2] ?? "generate";

if (mode === "-h" || mode === "--help") {
  process.stdout.write("Usage: scripts/generate-test-pack [generate|verify]\n");
  process.exit(0);
}
if (mode !== "generate" && mode !== "verify") {
  process.stderr.write(`generate-test-pack: unknown mode: ${mode}\n`);
  process.exit(64);
}

const source = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
const json = (value) => Buffer.from(`${JSON.stringify(value, null, 2)}\n`, "utf8");
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");
const beatUs = 60000000 / source.bpm;
if (!Number.isInteger(beatUs) || source.duration_us !== 30000000 || source.drift_loop_count !== 10) {
  throw new Error("source must describe an exact 30-second pack and ten 30-second drift loops");
}

let noteNumber = 0;
const notes = source.events.flatMap((event) => event.notes.map((note) => ({
  note_id: `note-${String(++noteNumber).padStart(3, "0")}`,
  timestamp_us: event.beat * beatUs,
  technique: note.technique,
  target_id: note.target_id
})));
const chart = {
  schema_version: "1.0.0",
  chart_id: source.pack_id,
  clock_domain: "song_time",
  time_unit: "microseconds",
  duration_us: source.duration_us,
  notes
};

const clickSamples = [...new Set(notes.map((note) => note.timestamp_us * source.sample_rate_hz / 1000000))];
if (!clickSamples.every(Number.isInteger)) throw new Error("every click must align to an integer audio sample");
const clickMap = {
  schema_version: "1.0.0",
  audio_file: "click.wav",
  sample_rate_hz: source.sample_rate_hz,
  clock_domain: "song_time",
  entries: source.events.map((event) => ({
    timestamp_us: event.beat * beatUs,
    sample_index: event.beat * beatUs * source.sample_rate_hz / 1000000,
    note_ids: notes.filter((note) => note.timestamp_us === event.beat * beatUs).map((note) => note.note_id)
  }))
};

function makeWav() {
  const sampleCount = source.duration_us * source.sample_rate_hz / 1000000;
  const dataSize = sampleCount * 2;
  const wav = Buffer.alloc(44 + dataSize);
  wav.write("RIFF", 0); wav.writeUInt32LE(36 + dataSize, 4); wav.write("WAVE", 8);
  wav.write("fmt ", 12); wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22); wav.writeUInt32LE(source.sample_rate_hz, 24);
  wav.writeUInt32LE(source.sample_rate_hz * 2, 28); wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34); wav.write("data", 36); wav.writeUInt32LE(dataSize, 40);
  for (const start of clickSamples) {
    for (let index = 0; index < source.click_duration_samples; index += 1) {
      const sign = Math.floor(index / 24) % 2 === 0 ? 1 : -1;
      const amplitude = Math.trunc(source.click_peak_amplitude * (source.click_duration_samples - index) / source.click_duration_samples);
      wav.writeInt16LE(sign * amplitude, 44 + (start + index) * 2);
    }
  }
  return wav;
}

const techniques = ["tone", "ding", "slap"];
const goldenCases = source.golden_deltas_us.map((delta, index) => ({
  case_id: `boundary-${String(index + 1).padStart(2, "0")}`,
  note_timestamp_us: 1000000,
  input_timestamp_us: 1000000 + delta,
  delta_us: delta,
  technique: techniques[index % techniques.length],
  target_id: techniques[index % techniques.length] === "tone" ? "tone-1" : techniques[index % techniques.length] === "ding" ? "ding" : "outer-hit-radius"
}));
if (source.include_no_input_miss) goldenCases.push({ case_id: "no-input-miss", note_timestamp_us: 1000000, technique: "tone", target_id: "tone-1" });

const classify = (testCase) => {
  if (testCase.input_timestamp_us === undefined) return "miss";
  const absolute = Math.abs(testCase.delta_us);
  if (absolute <= source.timing_windows_us.perfect) return "perfect";
  if (absolute <= source.timing_windows_us.great) return "great";
  if (absolute <= source.timing_windows_us.good) return "good";
  return "miss";
};
const judgements = goldenCases.map((testCase) => {
  const judgement = classify(testCase);
  const result = {
    schema_version: "1.0.0", record_id: testCase.case_id, note_id: testCase.case_id,
    note_timestamp_us: testCase.note_timestamp_us, clock_domain: "song_time",
    technique: testCase.technique, target_id: testCase.target_id, judgement
  };
  if (judgement !== "miss") {
    result.input_event_id = `${testCase.case_id}:input`;
    result.input_timestamp_us = testCase.input_timestamp_us;
    result.delta_us = testCase.delta_us;
  }
  return result;
});

const driftManifest = {
  schema_version: "1.0.0", test_id: "phase0-5min-drift-v1",
  source_pack: source.pack_id, audio_file: "click.wav", loop_count: 10,
  loop_duration_us: source.duration_us, expected_duration_us: source.duration_us * 10,
  sample_rate_hz: source.sample_rate_hz,
  expected_total_samples: source.duration_us * 10 * source.sample_rate_hz / 1000000,
  clock_domain: "song_time"
};
const license = {
  schema_version: "1.0.0", file: "click.wav", spdx_license: "CC0-1.0",
  provenance: "Generated from test-pack-source.json by scripts/generate-test-pack; no third-party audio samples are used.",
  waveform: "integer alternating-square pulse with linear decay"
};

const outputs = new Map([
  ["chart.json", json(chart)], ["click-samples.json", json(clickMap)],
  ["click.wav", makeWav()], ["golden-inputs.json", json({ schema_version: "1.0.0", clock_domain: "song_time", timing_windows_us: source.timing_windows_us, cases: goldenCases })],
  ["golden-results.json", json(judgements)], ["drift-loop-manifest.json", json(driftManifest)],
  ["audio-license.json", json(license)]
]);
const checksums = {};
for (const [name, contents] of outputs) checksums[name] = sha256(contents);
outputs.set("checksums.json", json({ schema_version: "1.0.0", algorithm: "sha256", files: checksums }));

const ajv = new Ajv2020({ allErrors: true, strict: true });
const validateChart = ajv.compile(JSON.parse(fs.readFileSync(path.join(root, "schemas/panbeat-chart.schema.json"), "utf8")));
const validateJudgement = ajv.compile(JSON.parse(fs.readFileSync(path.join(root, "schemas/judgement-record.schema.json"), "utf8")));
if (!validateChart(chart)) throw new Error(ajv.errorsText(validateChart.errors));
for (const judgement of judgements) if (!validateJudgement(judgement)) throw new Error(ajv.errorsText(validateJudgement.errors));

if (mode === "generate") fs.mkdirSync(outputDirectory, { recursive: true });
let differences = 0;
for (const [name, expected] of outputs) {
  const destination = path.join(outputDirectory, name);
  if (mode === "generate") fs.writeFileSync(destination, expected);
  const actual = fs.existsSync(destination) ? fs.readFileSync(destination) : null;
  if (!actual || !actual.equals(expected)) {
    differences += 1;
    process.stderr.write(`MISMATCH ${path.relative(root, destination)}\n`);
  } else process.stdout.write(`OK ${checksums[name] ?? sha256(expected)} ${path.relative(root, destination)}\n`);
}
if (differences) process.exit(1);
process.stdout.write(`${mode === "generate" ? "Generated" : "Verified"} 30-second pack and 300-second drift manifest.\n`);
