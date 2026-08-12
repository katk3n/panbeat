#!/usr/bin/env node
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const rawDir = path.join(root, "artifacts/raw/phase1-p111-performance");
const readJsonl = file => fs.readFileSync(file, "utf8").trim().split(/\r?\n/u).filter(Boolean).map(JSON.parse);
const percentile = (values, p) => [...values].sort((a,b)=>a-b)[Math.max(0, Math.ceil(values.length*p/100)-1)];
const maximum = values => values.reduce((result,value)=>Math.max(result,value),Number.NEGATIVE_INFINITY);
const minimum = values => values.reduce((result,value)=>Math.min(result,value),Number.POSITIVE_INFINITY);
const stats = values => ({samples:values.length,p50:percentile(values,50),p95:percentile(values,95),p99:percentile(values,99),max:maximum(values)});
const sha = file => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const relative = file => path.relative(root,file).split(path.sep).join("/");
const trials = [];
const finalAbsoluteDrift = [];
const allFrames = [];
const allMemory = [];
let maximumPool = 0;
let overflow = 0;
let firstSession;
for (let trial=1; trial<=3; trial++) {
  const file = path.join(rawDir,`trial-${trial}.jsonl`);
  const records = readJsonl(file);
  const session = records.find(r=>r.record_type==="session");
  firstSession ??= session;
  const frames = records.filter(r=>r.record_type==="frame");
  const events = records.filter(r=>r.record_type==="event");
  const durationUs = frames.at(-1).monotonic_elapsed_us;
  const finalDriftUs = frames.at(-1).drift_us;
  finalAbsoluteDrift.push(Math.abs(finalDriftUs));
  const warmupIndex = Math.floor(frames.length*0.1);
  for (let index=0; index<frames.length; index++) {
    const frame = frames[index];
    allFrames.push(frame.frame_time_us);
    if (index >= warmupIndex) allMemory.push(frame.static_memory_bytes);
    maximumPool = Math.max(maximumPool,frame.active_notes);
    overflow = Math.max(overflow,frame.pool_overflow_count);
  }
  const stallEnd = events.find(r=>r.kind==="stall_end");
  const recovery = stallEnd ? frames.find(r=>r.monotonic_elapsed_us>=stallEnd.monotonic_elapsed_us+1_000_000) : null;
  trials.push({trial,duration_us:durationUs,valid_duration:durationUs>=300_000_000,final_drift_us:finalDriftUs,final_absolute_drift_us:Math.abs(finalDriftUs),stall_recovery_drift_us:recovery?.drift_us??null,audio_driver:session.audio_driver,sample_rate_hz:session.sample_rate_hz,output_latency_seconds:session.output_latency_seconds,evidence:relative(file),sha256:sha(file)});
}
const midiFile = path.join(rawDir,"midi-burst.jsonl");
const midiRecords = readJsonl(midiFile);
const midiSession = midiRecords.find(r=>r.record_type==="session");
const midiLatencies = midiRecords.filter(r=>r.record_type==="dispatch").map(r=>r.accepted_to_processed_us);
const frameStats = stats(allFrames);
const driftStats = stats(finalAbsoluteDrift);
const midiStats = stats(midiLatencies);
const summary = {
  schema_version:"1.0.0", story:"P111", trials,
  environment:{hardware_model:os.cpus()[0]?.model??"unknown",logical_cpu_count:os.cpus().length,hostname:os.hostname(),os:`${os.type()} ${os.release()}`,architecture:os.arch(),godot_version:firstSession.engine_version,build_type:firstSession.build_type,renderer:firstSession.renderer,resolution:firstSession.resolution,configured_max_fps:firstSession.configured_max_fps,display_refresh_rate_hz:firstSession.display_refresh_rate_hz,audio_device:"CoreAudio default output; device name unavailable through the selected Godot API",audio_driver:firstSession.audio_driver,sample_rate_hz:firstSession.sample_rate_hz,output_latency_seconds:firstSession.output_latency_seconds,buffer_frames_estimate:Math.round(firstSession.output_latency_seconds*firstSession.sample_rate_hz)},
  final_absolute_drift_us:driftStats,
  frame_time_us:frameStats,
  frame_target:{minimum_fps:60,budget_us:16667,over_budget_samples:allFrames.filter(v=>v>16667).length},
  pool:{maximum_active_notes:maximumPool,overflow_count:overflow},
  steady_memory:{available:maximum(allMemory)>0,minimum_bytes:minimum(allMemory),maximum_bytes:maximum(allMemory),range_bytes:maximum(allMemory)-minimum(allMemory),note:"Godot's static-memory monitor returned zero in this release export. Product scheduling uses 64 preallocated note slots; the recorder uses 200,000 preallocated samples; judgement creates 45 event records and no product code performs per-frame collection growth."},
  allocation_contract:{note_slots_preallocated:64,measurement_samples_preallocated:200000,judgement_records_event_driven:45,per_frame_product_collection_growth_observed:false,runtime_heap_counter_available:false,classification:"phase2-risk: release heap allocation counter unavailable"},
  midi_dispatch_us:{...midiStats,os_receive_timestamp_available:midiSession.os_receive_timestamp_available,scope:midiSession.latency_scope,evidence:relative(midiFile),sha256:sha(midiFile)},
  targets:{drift_final_abs_us:5000,midi_dispatch_p95_us:5000,minimum_fps:60},
  classification:{drift:driftStats.max<=5000?"meets-target":"phase1-blocker",midi:midiStats.p95<=5000?"meets-target":"phase1-blocker",frame:frameStats.p95<=16667?"meets-target":"phase2-risk"}
};
fs.writeFileSync(path.join(rawDir,"summary.json"),`${JSON.stringify(summary,null,2)}\n`);
const fixtureFiles = [path.join(root,"game/content/phase1-fixed-song-v1/chart.json"),path.join(root,"game/content/phase1-fixed-song-v1/orbit-practice.wav"),path.join(root,"shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json")];
const sourceRevision = execFileSync("git",["rev-parse","HEAD"],{cwd:root,encoding:"utf8"}).trim();
const dirty = execFileSync("git",["status","--porcelain","--untracked-files=no"],{cwd:root,encoding:"utf8"}).trim().length>0;
const manifest = {schema_version:"1.0.0",run_id:"phase1-p111-performance",engine:"godot",started_at:new Date().toISOString(),source_revision:sourceRevision,source_dirty:dirty,build_type:"release",clock_domains:["song_time","monotonic","godot_audio"],environment:summary.environment,inputs:[...fixtureFiles.map(file=>({path:relative(file),sha256:sha(file)})),...trials.map(t=>({path:t.evidence,sha256:t.sha256})),{path:relative(midiFile),sha256:sha(midiFile)}],outputs:[{path:relative(path.join(rawDir,"summary.json")),sha256:sha(path.join(rawDir,"summary.json"))}],invalid_attempt_preserved:"artifacts/raw/phase1-p111-performance/attempt-capacity-truncated"};
fs.writeFileSync(path.join(rawDir,"run-manifest.json"),`${JSON.stringify(manifest,null,2)}\n`);
console.log(`P111 summary drift=${summary.classification.drift} midi=${summary.classification.midi} frame=${summary.classification.frame}`);
