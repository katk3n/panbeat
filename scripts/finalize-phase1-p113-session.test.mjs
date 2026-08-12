import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const scriptsDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(scriptsDir);

test("P113 finalizer verifies physical techniques, offset formula, and paused input", () => {
  const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "panbeat-p113-finalizer-"));
  try {
    const runDir = path.join(temporaryRoot, "session");
    fs.mkdirSync(runDir);
    const build = path.join(temporaryRoot, "PanBeat.zip");
    const buildManifest = path.join(temporaryRoot, "p112.json");
    fs.writeFileSync(build, "build");
    fs.writeFileSync(buildManifest, JSON.stringify({run_id:"p112-test", target:"macOS universal release", engine_version:"4.6"}));
    const records = Array.from({length:45}, (_, index) => ({
      record_id:`judgement-${index + 1}`,
      outcome:"judged",
      actual_timestamp_us:1_000_000 + index,
      expected_timestamp_us:970_000 + index,
      input_offset_us:30_000,
      audio_offset_us:0,
      delta_us:60_000
    }));
    fs.writeFileSync(path.join(runDir, "judgement-records.json"), JSON.stringify({records, summary:{score:123, accuracy:0.5}}));
    const midiRecords = [
      ["tone", "tone-8"],
      ["ding", "ding"],
      ["slap", "outer-hit-radius"]
    ].map(([technique, target_id], index) => ({
      raw:{arrival_timestamp_us:index === 0 ? 200 : 400 + index},
      normalized:{kind:"normalized_input", technique, target_id},
      accepted_for_judgement:index !== 0
    }));
    fs.writeFileSync(path.join(runDir, "diagnostics.json"), JSON.stringify({
      status:"completed",
      session_state:"completed",
      input_mode:"midi",
      profile_id:"roland-mn10-handpan-minor-v1",
      input_offset_sec:0.03,
      midi_lifecycle:[{code:"opened", ok:true, ports:["MN-10"]}],
      midi_records:midiRecords,
      session_events:[
        {event:"paused", monotonic_timestamp_us:100},
        {event:"resumed", monotonic_timestamp_us:300},
        {event:"completed", monotonic_timestamp_us:500}
      ]
    }));
    fs.writeFileSync(path.join(runDir, "operator-observations.json"), "{}\n");

    execFileSync(process.execPath, [
      path.join(scriptsDir, "finalize-phase1-p113-session.mjs"),
      `--repository-root=${root}`,
      `--run-dir=${runDir}`,
      `--build=${build}`,
      `--build-manifest=${buildManifest}`,
      "--scenario=pause-reconnect",
      "--expected-input-offset-sec=0.030"
    ]);
    const manifest = JSON.parse(fs.readFileSync(path.join(runDir, "software-manifest.json"), "utf8"));
    assert.equal(manifest.result, "software-evidence-pass-operator-observation-pending");
    assert.deepEqual(manifest.completion.normalized_techniques, ["ding", "slap", "tone"]);
    assert.equal(manifest.completion.offset_formula_verified_for_all_judged_records, true);
    assert.equal(manifest.completion.normalized_inputs_during_pause, 1);
    assert.equal(manifest.completion.paused_inputs_rejected_from_judgement, true);
    assert.equal(JSON.parse(fs.readFileSync(path.join(runDir, "summary.json"), "utf8")).score, 123);
  } finally {
    fs.rmSync(temporaryRoot, {recursive:true, force:true});
  }
});
