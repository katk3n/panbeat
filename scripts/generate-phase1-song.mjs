#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const packageDirectory = join(repositoryRoot, "game/content/phase1-fixed-song-v1");
const sourcePath = join(packageDirectory, "source.json");
const json = (value) => Buffer.from(`${JSON.stringify(value, null, 2)}\n`, "utf8");
const sha256 = (value) => createHash("sha256").update(value).digest("hex");

function validateSource(source) {
  if (source.schema_version !== "1.0.0" || source.package_id !== "phase1-fixed-song-v1") throw new Error("unsupported package source");
  if (source.bpm !== 120 || source.sample_rate_hz !== 48000 || source.duration_us !== 36000000) throw new Error("fixed timing contract changed");
  if (!Array.isArray(source.events) || source.events.length === 0) throw new Error("events are required");
  const allowedTargets = new Set(["ding", "outer-hit-radius", ...Array.from({ length: 8 }, (_, index) => `tone-${index + 1}`)]);
  let previousBeat = -1;
  for (const event of source.events) {
    if (!Number.isFinite(event.beat) || event.beat < previousBeat) throw new Error("events must be ordered by beat");
    if (!allowedTargets.has(event.target_id)) throw new Error(`unknown target ${event.target_id}`);
    if ((event.technique === "ding") !== (event.target_id === "ding")) throw new Error("ding target mismatch");
    if ((event.technique === "slap") !== (event.target_id === "outer-hit-radius")) throw new Error("slap target mismatch");
    if (event.technique === "tone" && !event.target_id.startsWith("tone-")) throw new Error("tone target mismatch");
    if (!new Set(["right", "left"]).has(event.hand)) throw new Error(`event hand must be explicit: ${event.hand}`);
    previousBeat = event.beat;
  }
}

function makeAudio(source, notes) {
  const sampleCount = source.duration_us * source.sample_rate_hz / 1000000;
  const samples = new Float64Array(sampleCount);
  const addBurst = (start, length, sampleAt) => {
    for (let offset = 0; offset < length && start + offset < sampleCount; offset += 1) samples[start + offset] += sampleAt(offset, length);
  };
  const beatSamples = source.sample_rate_hz * 60 / source.bpm;
  let noiseState = 0x51f15e;
  const noise = () => {
    noiseState = (1664525 * noiseState + 1013904223) >>> 0;
    return noiseState / 0xffffffff * 2 - 1;
  };
  for (let beat = 0; beat < source.duration_us / 500000; beat += 1) {
    const start = beat * beatSamples;
    addBurst(start, 4800, (offset, length) => Math.sin(2 * Math.PI * (72 - 28 * offset / length) * offset / source.sample_rate_hz) * 0.19 * (1 - offset / length));
    addBurst(start + beatSamples / 2, 1200, (offset, length) => noise() * 0.035 * (1 - offset / length));
  }
  const chordFrequencies = [110, 130.8128, 146.8324, 164.8138];
  for (let sample = 0; sample < sampleCount; sample += 1) {
    const measure = Math.floor(sample / (beatSamples * 4));
    const frequency = chordFrequencies[measure % chordFrequencies.length];
    samples[sample] += Math.sin(2 * Math.PI * frequency * sample / source.sample_rate_hz) * 0.035;
  }
  for (const note of notes) {
    const start = note.timestamp_us * source.sample_rate_hz / 1000000;
    const frequency = note.technique === "ding" ? 660 : note.technique === "slap" ? 180 : 330 + Number(note.target_id.slice(5)) * 22;
    addBurst(start, 7200, (offset, length) => Math.sin(2 * Math.PI * frequency * offset / source.sample_rate_hz) * 0.12 * (1 - offset / length));
  }
  const dataSize = sampleCount * 2;
  const wav = Buffer.alloc(44 + dataSize);
  wav.write("RIFF", 0); wav.writeUInt32LE(36 + dataSize, 4); wav.write("WAVE", 8);
  wav.write("fmt ", 12); wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22); wav.writeUInt32LE(source.sample_rate_hz, 24);
  wav.writeUInt32LE(source.sample_rate_hz * 2, 28); wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34); wav.write("data", 36); wav.writeUInt32LE(dataSize, 40);
  for (let index = 0; index < sampleCount; index += 1) wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[index])) * 32767), 44 + index * 2);
  return wav;
}

export function buildPackage(source) {
  validateSource(source);
  const beatUs = 60000000 / source.bpm;
  const notes = source.events.map((event, index) => ({
    note_id: `orbit-${String(index + 1).padStart(3, "0")}`,
    timestamp_us: event.beat * beatUs,
    technique: event.technique,
    target_id: event.target_id,
    hand: event.hand
  }));
  if (!notes.every((note) => Number.isSafeInteger(note.timestamp_us))) throw new Error("note timestamp is not an integer microsecond");
  const lastNoteUs = notes.at(-1).timestamp_us;
  if (lastNoteUs + source.ending_margin_us !== source.duration_us) throw new Error("ending margin contract changed");
  const chart = { schema_version: "1.0.0", chart_id: source.package_id, clock_domain: "song_time", time_unit: "microseconds", duration_us: source.duration_us, notes };
  const expected = {
    schema_version: "1.0.0", clock_domain: "song_time", time_unit: "microseconds",
    inputs: notes.map((note) => ({ event_id: `${note.note_id}:input`, timestamp_us: note.timestamp_us, technique: note.technique, target_id: note.target_id, velocity: 96 }))
  };
  const expectedSummary = {
    schema_version: "1.0.0", score_rule_id: "panbeat-phase1-score-v1", note_count: notes.length,
    score: notes.length * 1000, accuracy: 1.0, max_combo: notes.length,
    breakdown: { perfect: notes.length, great: 0, good: 0, miss: 0, extra_hit: 0 }
  };
  const metadata = {
    schema_version: "1.0.0", package_id: source.package_id, title: source.title,
    chart_file: "chart.json", audio_file: "orbit-practice.wav", expected_events_file: "expected-events.json", expected_summary_file: "expected-summary.json",
    bpm: source.bpm, duration_us: source.duration_us, sample_rate_hz: source.sample_rate_hz,
    preload_margin_us: source.preload_margin_us, ending_margin_us: source.ending_margin_us,
    sync: { clock_domain: "song_time", audio_sample_zero_timestamp_us: 0, first_note_timestamp_us: notes[0].timestamp_us, last_note_timestamp_us: lastNoteUs }
  };
  const provenance = {
    schema_version: "1.0.0", file: "orbit-practice.wav", spdx_license: "CC0-1.0",
    provenance: "Deterministically synthesized by scripts/generate-phase1-song.mjs from source.json; no third-party samples or compositions are used.",
    format: "RIFF/WAVE PCM, mono, signed 16-bit little-endian, 48000 Hz",
    generator: "scripts/generate-phase1-song.mjs"
  };
  const outputs = new Map([
    ["package.json", json(metadata)], ["chart.json", json(chart)], ["expected-events.json", json(expected)], ["expected-summary.json", json(expectedSummary)],
    ["audio-provenance.json", json(provenance)], ["orbit-practice.wav", makeAudio(source, notes)]
  ]);
  const checksums = { "source.json": sha256(json(source)) };
  for (const [name, contents] of outputs) checksums[name] = sha256(contents);
  outputs.set("checksums.json", json({ schema_version: "1.0.0", algorithm: "sha256", files: checksums }));
  return { outputs, notes, metadata };
}

export function run(mode = "verify") {
  if (!["generate", "verify"].includes(mode)) throw new Error(`unknown mode: ${mode}`);
  const source = JSON.parse(readFileSync(sourcePath, "utf8"));
  const { outputs } = buildPackage(source);
  if (mode === "generate") mkdirSync(packageDirectory, { recursive: true });
  let differences = 0;
  for (const [name, expected] of outputs) {
    const destination = join(packageDirectory, name);
    if (mode === "generate") writeFileSync(destination, expected);
    const actual = existsSync(destination) ? readFileSync(destination) : null;
    if (!actual?.equals(expected)) {
      differences += 1;
      console.error(`MISMATCH ${relative(repositoryRoot, destination)}`);
    } else console.log(`OK ${sha256(expected)} ${relative(repositoryRoot, destination)}`);
  }
  if (differences > 0) return 1;
  console.log(`${mode === "generate" ? "Generated" : "Verified"} Phase 1 fixed-song package.`);
  return 0;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try { process.exitCode = run(process.argv[2] ?? "verify"); }
  catch (error) { console.error(`generate-phase1-song: ${error.message}`); process.exitCode = 1; }
}
