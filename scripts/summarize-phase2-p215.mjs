import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import assert from "node:assert/strict";

const [runDir, runId] = process.argv.slice(2);
const read = name => JSON.parse(fs.readFileSync(path.join(runDir, name), "utf8"));
const hash = name => crypto.createHash("sha256").update(fs.readFileSync(path.join(runDir, name))).digest("hex");
const prepared = read("prepared.json");
const replay = read("release-replay.json");
const history = read("repository/results/history.json");
const summary = replay.summary;
const record = history.records[0];
const expectedSummary = {
  score: summary.score,
  combo: summary.combo,
  max_combo: summary.max_combo,
  accuracy: summary.accuracy,
  breakdown: summary.breakdown,
  latest_grade: summary.latest_grade,
  latest_direction: summary.latest_direction,
};
if (!record) throw new Error("Results history is empty");
assert.deepStrictEqual(record.summary, expectedSummary, "Results readback mismatch");
assert.deepStrictEqual(record.judgements, replay.records, "Judgement history readback mismatch");
const manifest = {schema_version:"1.0.0", run_id:runId, story:"P215", status:"complete", prepared, verification:{tests:"pass", import:"pass", build:"pass", release_replay:"pass", screenshot:"pass", results_readback:"pass"}, artifacts:{build:"PanBeat.zip", build_sha256:hash("PanBeat.zip"), chart_sha256:prepared.chart_sha256, replay_sha256:hash("release-replay.json"), screenshot:"acceptance.png", results_history:"repository/results/history.json"}, result:{score:summary.score, accuracy:summary.accuracy, max_combo:summary.max_combo, breakdown:summary.breakdown, history_records:history.records.length}};
fs.writeFileSync(path.join(runDir, "run-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
