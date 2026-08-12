#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const parsedArgs = Object.fromEntries(process.argv.slice(2).map(value => {
  const [key, ...rest] = value.split("=");
  return [key, rest.join("=")];
}));
for (const key of ["--repository-root", "--run-dir", "--build", "--build-manifest", "--scenario", "--expected-input-offset-sec"]) {
  if (!parsedArgs[key]) throw new Error(`missing ${key}=...`);
}

const root = path.resolve(parsedArgs["--repository-root"]);
const runDir = path.resolve(parsedArgs["--run-dir"]);
const build = path.resolve(parsedArgs["--build"]);
const buildManifest = path.resolve(parsedArgs["--build-manifest"]);
const scenario = parsedArgs["--scenario"];
const expectedInputOffsetSec = Number(parsedArgs["--expected-input-offset-sec"]);
const readJson = file => JSON.parse(fs.readFileSync(file, "utf8"));
const sha256 = file => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const relative = file => path.relative(root, file).split(path.sep).join("/");
const artifact = file => ({ path: relative(file), sha256: sha256(file), bytes: fs.statSync(file).size });

const recordsPath = path.join(runDir, "judgement-records.json");
const diagnosticsPath = path.join(runDir, "diagnostics.json");
const summaryPath = path.join(runDir, "summary.json");
const diagnostics = readJson(diagnosticsPath);
if (diagnostics.status !== "completed" || diagnostics.session_state !== "completed") {
  throw new Error(`session did not complete: ${diagnostics.failure_reason || diagnostics.status || "unknown failure"}`);
}
const recordsDocument = readJson(recordsPath);
const p112 = readJson(buildManifest);
const profilePath = path.join(root, "shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json");
const profile = readJson(profilePath);

if (diagnostics.input_mode !== "midi") throw new Error(`expected midi input mode, got ${diagnostics.input_mode}`);
if (diagnostics.profile_id !== profile.profile_id) throw new Error(`profile mismatch: ${diagnostics.profile_id}`);
if (Math.abs(Number(diagnostics.input_offset_sec) - expectedInputOffsetSec) > 0.0000001) throw new Error("effective input offset mismatch");
if (!Array.isArray(recordsDocument.records) || recordsDocument.records.length < 45) throw new Error("judgement records are incomplete");
if (!recordsDocument.summary || typeof recordsDocument.summary.score !== "number") throw new Error("summary is missing");

const opened = diagnostics.midi_lifecycle?.filter(event => event.code === "opened" && event.ok) ?? [];
if (!opened.length) throw new Error("no successful MIDI open lifecycle event");
const ports = [...new Set(opened.flatMap(event => event.ports ?? []))];
if (!ports.some(port => String(port).includes("MN-10"))) throw new Error(`MN-10 port was not recorded: ${ports.join(", ")}`);

const normalizedInputs = (diagnostics.midi_records ?? [])
  .map(entry => entry.normalized)
  .filter(entry => entry?.kind === "normalized_input");
const techniques = [...new Set(normalizedInputs.map(entry => entry.technique))].sort();
for (const technique of ["tone", "ding", "slap"]) {
  if (!techniques.includes(technique)) throw new Error(`no physical ${technique} input was normalized`);
}

const expectedInputOffsetUs = Math.round(expectedInputOffsetSec * 1_000_000);
for (const record of recordsDocument.records) {
  if (record.input_offset_us !== expectedInputOffsetUs) throw new Error(`record ${record.record_id} has the wrong input offset`);
  if (record.outcome === "judged") {
    const expectedDelta = record.actual_timestamp_us + record.input_offset_us - record.expected_timestamp_us - record.audio_offset_us;
    if (record.delta_us !== expectedDelta) throw new Error(`record ${record.record_id} applies offset incorrectly`);
  }
}

const sessionEvents = diagnostics.session_events ?? [];
const paused = sessionEvents.some(event => event.event === "paused");
const resumed = sessionEvents.some(event => event.event === "resumed");
if (scenario === "pause-reconnect" && !(paused && resumed)) throw new Error("pause-reconnect scenario has no pause/resume pair");
let normalizedPausedInputs = [];
if (scenario === "pause-reconnect") {
  const pauseEvent = sessionEvents.find(event => event.event === "paused");
  const resumeEvent = sessionEvents.find(event => event.event === "resumed" && event.monotonic_timestamp_us >= pauseEvent.monotonic_timestamp_us);
  normalizedPausedInputs = (diagnostics.midi_records ?? []).filter(entry =>
    entry.normalized?.kind === "normalized_input" &&
    entry.raw?.arrival_timestamp_us >= pauseEvent.monotonic_timestamp_us &&
    entry.raw?.arrival_timestamp_us <= resumeEvent.monotonic_timestamp_us
  );
  if (!normalizedPausedInputs.length) throw new Error("no physical input was captured during pause");
  if (normalizedPausedInputs.some(entry => entry.accepted_for_judgement !== false)) throw new Error("a paused physical input was accepted for judgement");
}
const firstUnavailable = diagnostics.midi_lifecycle?.findIndex(event => !event.ok) ?? -1;
const reopened = firstUnavailable >= 0 && diagnostics.midi_lifecycle.slice(firstUnavailable + 1).some(event => event.code === "opened" && event.ok);

fs.writeFileSync(summaryPath, `${JSON.stringify(recordsDocument.summary, null, 2)}\n`);
const outputs = [build, buildManifest, profilePath, recordsPath, summaryPath, diagnosticsPath].map(artifact);
const manifest = {
  schema_version: "1.0.0",
  story: "P113",
  run_id: path.basename(runDir),
  scenario,
  result: "software-evidence-pass-operator-observation-pending",
  source_build: {
    p112_run_id: p112.run_id,
    target: p112.target,
    engine_version: p112.engine_version,
    build: artifact(build)
  },
  environment: {
    platform: process.platform,
    architecture: process.arch,
    os_release: os.release()
  },
  device: {
    manufacturer: profile.device.manufacturer,
    model: profile.device.model,
    midi_ports: ports,
    profile_id: profile.profile_id,
    profile_sha256: sha256(profilePath)
  },
  completion: {
    judgement_record_count: recordsDocument.records.length,
    summary: recordsDocument.summary,
    normalized_physical_input_count: normalizedInputs.length,
    normalized_techniques: techniques,
    effective_input_offset_sec: diagnostics.input_offset_sec,
    offset_formula_verified_for_all_judged_records: true,
    pause_observed: paused,
    resume_observed: resumed,
    normalized_inputs_during_pause: normalizedPausedInputs.length,
    paused_inputs_rejected_from_judgement: normalizedPausedInputs.length > 0 && normalizedPausedInputs.every(entry => entry.accepted_for_judgement === false),
    disconnect_observed_by_api: firstUnavailable >= 0,
    reopen_after_disconnect_observed_by_api: reopened
  },
  evidence_separation: {
    software_log: relative(diagnosticsPath),
    judgement_records: relative(recordsPath),
    summary: relative(summaryPath),
    operator_observations: relative(path.join(runDir, "operator-observations.json"))
  },
  limitations: [
    "Godot exposes no OS MIDI receive timestamp; physical strike-to-audio/display latency is not derived from software timestamps.",
    "Only Handpan / Minor Tone, Ding, and Slap are in scope; BLE, Pressure, Mute, and other Tone/Style modes are unverified."
  ],
  outputs
};
fs.writeFileSync(path.join(runDir, "software-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`PANBEAT_P113_SOFTWARE_EVIDENCE_OK ${manifest.run_id}`);
