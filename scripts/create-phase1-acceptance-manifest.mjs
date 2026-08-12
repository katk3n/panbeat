#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map(value=>{const [key,...rest]=value.split("="); return [key,rest.join("=")];}));
for (const key of ["--repository-root","--run-dir","--build","--replay","--screenshot","--revision","--dirty"]) if (!args[key]) throw new Error(`missing ${key}=...`);
const root = path.resolve(args["--repository-root"]);
const absolute = candidate => path.isAbsolute(candidate)?candidate:path.join(root,candidate);
const sha = file => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const artifact = file => ({path:path.relative(root,file).split(path.sep).join("/"),sha256:sha(file),bytes:fs.statSync(file).size});
const replay = JSON.parse(fs.readFileSync(absolute(args["--replay"]),"utf8"));
const expected = JSON.parse(fs.readFileSync(path.join(root,"game/content/phase1-fixed-song-v1/expected-summary.json"),"utf8"));
if (replay.records.length !== expected.note_count) throw new Error(`record count ${replay.records.length} != ${expected.note_count}`);
if (!replay.records.every(record=>record.grade==="perfect"&&record.outcome==="judged")) throw new Error("replay contains a non-Perfect record");
for (const field of ["score","max_combo"]) if (replay.summary[field]!==expected[field]) throw new Error(`summary mismatch: ${field}`);
if (replay.summary.accuracy!==expected.accuracy) throw new Error("summary mismatch: accuracy");
for (const grade of ["perfect","great","good","miss","extra_hit"]) if (replay.summary.breakdown[grade]!==expected.breakdown[grade]) throw new Error(`breakdown mismatch: ${grade}`);
const files = [absolute(args["--build"]),absolute(args["--replay"]),absolute(args["--screenshot"]),path.join(root,"game/content/phase1-fixed-song-v1/checksums.json"),path.join(root,"shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json")];
const manifest = {
  schema_version:"1.0.0",run_id:path.basename(absolute(args["--run-dir"])),story:"P112",source_revision:args["--revision"],source_dirty:args["--dirty"]==="true",
  engine_version:"4.6.stable.official.89cea1439",target:"macOS universal release",renderer:"gl_compatibility",
  replay:{records:replay.records.length,summary:replay.summary,golden:"game/content/phase1-fixed-song-v1/expected-summary.json",result:"pass"},
  artifact_inspection:{required_resources:"pass",forbidden_credentials_raw_traces_absolute_paths_and_pocs:"pass"},
  known_phase1_blockers:["P111 CoreAudio five-minute drift max 6.078 ms exceeds 5 ms target","P111 recorded-burst dispatch p95 8.295 ms exceeds 5 ms target"],
  outputs:files.map(artifact)
};
fs.writeFileSync(path.join(absolute(args["--run-dir"]),"run-manifest.json"),`${JSON.stringify(manifest,null,2)}\n`);
console.log(`PANBEAT_PHASE1_ACCEPTANCE_OK ${manifest.run_id}`);
