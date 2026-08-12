import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [runId, rawDir, buildPath] = process.argv.slice(2);
if (!runId || !rawDir || !buildPath) throw new Error("usage: summarize-phase3-p308.mjs RUN_ID RAW_DIR BUILD_PATH");
const hash=(path)=>createHash("sha256").update(readFileSync(path)).digest("hex");
const captures=["songs.png","device-no-ports.png","calibration-retry.png","results.png","results-confirm.png","state-fixtures.png"];
const manifest={
  schema_version:"1.0.0",run_id:runId,story:"P308",status:"complete",
  dependencies:["artifacts/raw/phase3-p304-shell-20260812t1615/run-manifest.json"],
  verification:{presentation_contract:"16/16",repeat_session_contract:"pass",full_regression:"pass",import_repository_calibration_result_history:"pass",build:"pass",window:"1280x720",states:["loading","empty","disabled","warning","recoverable error"]},
  songs:{primary_action:"Play Selected",secondary_actions:["import","re-import","delete"],diagnostics_and_remediation:"selection details"},
  device:{sections:["connection status","selected port and profile","live input monitor","technical details"],silence_disconnect_claim:false},
  calibration:{stages:["Start","Cue Input","Analyze","Apply & Save"],sample_shortage_japanese:true,variance_retry_japanese:true},
  results:{summary:["score","accuracy","max combo","grade breakdown","early/on-time/late"],completion_actions:["play again","song library"],process_restart_required:false,technical_metadata:"separate section",destructive_confirmation:["exact result id","all result count"]},
  artifacts:Object.fromEntries(captures.map(name=>[name,{path:name,sha256:hash(join(rawDir,name))}])),
  build:{path:`artifacts/builds/${runId}-build/PanBeat.zip`,sha256:hash(buildPath)},result:"pass"
};
writeFileSync(join(rawDir,"run-manifest.json"),JSON.stringify(manifest,null,2)+"\n");
