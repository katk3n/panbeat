#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const sessions = [
  "phase1-p113-device-01-baseline-retry1-20260812",
  "phase1-p113-device-02-offset-positive-20260812",
  "phase1-p113-device-03-pause-reconnect-20260812"
];
const outputDir = path.join(root, "artifacts/raw/phase1-p113-device-acceptance-20260812");
const readJson = file => JSON.parse(fs.readFileSync(file, "utf8"));
const sha256 = file => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const relative = file => path.relative(root, file).split(path.sep).join("/");
const artifact = file => ({path:relative(file), sha256:sha256(file), bytes:fs.statSync(file).size});

const accepted = [];
for (const runId of sessions) {
  const runDir = path.join(root, "artifacts/raw", runId);
  const paths = {
    software:path.join(runDir, "software-manifest.json"),
    records:path.join(runDir, "judgement-records.json"),
    summary:path.join(runDir, "summary.json"),
    diagnostics:path.join(runDir, "diagnostics.json"),
    observations:path.join(runDir, "operator-observations.json")
  };
  for (const [kind, file] of Object.entries(paths)) if (!fs.existsSync(file)) throw new Error(`${runId}: missing ${kind}`);
  const software = readJson(paths.software);
  const observations = readJson(paths.observations);
  if (software.result !== "software-evidence-pass-operator-observation-pending") throw new Error(`${runId}: software evidence did not pass`);
  if (observations.status !== "complete" || observations.session_id !== runId) throw new Error(`${runId}: operator observation incomplete`);
  if (observations.device_setting !== "Handpan / Minor") throw new Error(`${runId}: wrong device setting`);
  if (!observations.clean_launch_usb_recognized || !observations.audio_and_visual_played_normally || !observations.completion_summary_observed) throw new Error(`${runId}: operator acceptance failed`);
  if (!Object.values(observations.technique_and_target_display).every(Boolean)) throw new Error(`${runId}: a technique/target display was not accepted`);
  if (software.device.profile_id !== "roland-mn10-handpan-minor-v1" || software.device.profile_sha256 !== "abfe1eae01e2b2c1e24801a7946354f35924426adc33c903672dce4d036fb42d") throw new Error(`${runId}: canonical profile mismatch`);
  if (!software.device.midi_ports.includes("MN-10")) throw new Error(`${runId}: MN-10 port missing`);
  if (!["ding", "slap", "tone"].every(value => software.completion.normalized_techniques.includes(value))) throw new Error(`${runId}: physical technique coverage incomplete`);
  accepted.push({run_id:runId, scenario:software.scenario, software, observations, evidence:Object.values(paths).map(artifact)});
}

const byScenario = Object.fromEntries(accepted.map(item => [item.scenario, item]));
for (const scenario of ["baseline", "offset-positive", "pause-reconnect"]) if (!byScenario[scenario]) throw new Error(`missing scenario ${scenario}`);
if (byScenario["offset-positive"].software.completion.effective_input_offset_sec !== 0.03 || !byScenario["offset-positive"].software.completion.offset_formula_verified_for_all_judged_records) throw new Error("+30 ms offset acceptance failed");
const pause = byScenario["pause-reconnect"];
if (!pause.software.completion.pause_observed || !pause.software.completion.resume_observed || !pause.software.completion.paused_inputs_rejected_from_judgement) throw new Error("software pause/resume acceptance failed");
if (!pause.observations.pause_resume.no_double_audio_or_notes || !pause.observations.pause_resume.no_input_accepted_while_paused) throw new Error("operator pause/resume acceptance failed");
if (!pause.observations.disconnect_reconnect.performed || !pause.observations.disconnect_reconnect.automatic_recovery_observed || pause.observations.disconnect_reconnect.relaunch_required) throw new Error("operator reconnect acceptance failed");

fs.mkdirSync(outputDir, {recursive:true});
const manifest = {
  schema_version:"1.0.0",
  run_id:path.basename(outputDir),
  story:"P113",
  status:"complete",
  result:"pass",
  device_setting:"Handpan / Minor",
  completed_sessions:accepted.length,
  accepted_build:{
    p112_run_id:"phase1-p112-acceptance-k-20260812",
    sha256:"45ad64f9c6662f3aa973fd7d3a4edae22af3f0126c2d49fedefead56cbee44e6"
  },
  canonical_profile:{
    profile_id:"roland-mn10-handpan-minor-v1",
    sha256:"abfe1eae01e2b2c1e24801a7946354f35924426adc33c903672dce4d036fb42d"
  },
  sessions:accepted.map(item => ({
    run_id:item.run_id,
    scenario:item.scenario,
    judgement_records:item.software.completion.judgement_record_count,
    normalized_physical_inputs:item.software.completion.normalized_physical_input_count,
    techniques:item.software.completion.normalized_techniques,
    summary:item.software.completion.summary,
    effective_input_offset_sec:item.software.completion.effective_input_offset_sec,
    evidence:item.evidence
  })),
  acceptance:{
    clean_launch_and_three_techniques:true,
    three_completed_sessions_with_separate_records_summary_diagnostics:true,
    pause_resume_and_paused_input_gate:true,
    positive_input_offset_applied_once:true,
    physical_disconnect_reconnect_recovered:true,
    godot_disconnect_event_observed:false,
    subjective_observations_separate_from_software_logs:true
  },
  failed_attempt_preserved:{
    run_id:"phase1-p113-device-01-baseline-20260812",
    result:"MIDI initialization failed: no ports",
    cause:"P106 product regression enumerated ports before opening CoreMIDI",
    correction:"P106 now opens the backend before cold-start enumeration; P112 was rerun twice as j/k."
  },
  limitations:[
    "Godot did not expose the physical disconnect as a port-list change, although the operator observed recovery after reconnect.",
    "Physical strike-to-audio/display latency was accepted subjectively and is not calculated from software timestamps.",
    "Tone/Style modes other than Handpan / Minor, BLE, Pressure, and Mute remain unverified."
  ]
};
fs.writeFileSync(path.join(outputDir, "run-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`PANBEAT_P113_ACCEPTANCE_OK ${manifest.completed_sessions}/3`);
