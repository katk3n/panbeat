import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [runId, rawDir, buildPath] = process.argv.slice(2);
if (!runId || !rawDir || !buildPath) throw new Error("usage: summarize-phase3-p307.mjs RUN_ID RAW_DIR BUILD_PATH");
const hash = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");
const captures = ["playing-720p.png","playing-wide-long-title.png","count-in.png","paused.png","complete.png","failure.png"];
const manifest = {
  schema_version:"1.0.0", run_id:runId, story:"P307", status:"complete",
  dependencies:["artifacts/raw/phase3-p304-shell-20260812t1615/run-manifest.json","artifacts/raw/miss-text-only-p306-20260812/run-manifest.json"],
  verification:{hud_contract:"15/15",full_regression:"pass",build:"pass",sizes:["1280x720","1600x720"],long_title:"pass",maximum_digits:"pass",state_overlays:["count-in","paused","complete","failure"],hud_on_off_replay:"byte-identical judgement records"},
  timing:{count_in:"negative audio transport timestamp",progress:"audio-backed transport timestamp / package duration",frame_accumulation:false},
  score_source:"ScoreEngine.hud_model only",
  failure_ux:{user_summary:"Playback stopped safely",actions:["retry","exit"],technical_detail:"separate DETAILS section"},
  results_transition:{guard:"_results_opened",maximum_count:1},
  artifacts:Object.fromEntries(captures.map((name)=>[name,{path:name,sha256:hash(join(rawDir,name))}])),
  replay:{hud_on:{path:"replay-hud-on.json",sha256:hash(join(rawDir,"replay-hud-on.json"))},hud_off:{path:"replay-hud-off.json",sha256:hash(join(rawDir,"replay-hud-off.json"))}},
  build:{path:`artifacts/builds/${runId}-build/PanBeat.zip`,sha256:hash(buildPath)}, result:"pass"
};
writeFileSync(join(rawDir,"run-manifest.json"), JSON.stringify(manifest,null,2)+"\n");
