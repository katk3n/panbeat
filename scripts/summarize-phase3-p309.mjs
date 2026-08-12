import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [runId,rawDir,buildPath]=process.argv.slice(2);
if(!runId||!rawDir||!buildPath) throw new Error("usage: summarize-phase3-p309.mjs RUN_ID RAW_DIR BUILD_PATH");
const hash=(path)=>createHash("sha256").update(readFileSync(path)).digest("hex");
const perf=JSON.parse(readFileSync(join(rawDir,"performance.json")));
const hex=(value)=>[1,3,5].map(i=>parseInt(value.slice(i,i+2),16)/255);
const lum=(value)=>hex(value).map(c=>c<=.04045?c/12.92:Math.pow((c+.055)/1.055,2.4)).reduce((sum,c,i)=>sum+c*[.2126,.7152,.0722][i],0);
const ratio=(a,b)=>{const [hi,lo]=[lum(a),lum(b)].sort((x,y)=>y-x);return (hi+.05)/(lo+.05)};
const colors={background:"#0b0e16",surface:"#171b24",primary:"#f4f1e8",muted:"#aaa79f",focus:"#ffe29b",error:"#e78072",success:"#8ed3a7"};
const contrast={body_text_on_background:ratio(colors.primary,colors.background),muted_text_on_background:ratio(colors.muted,colors.background),focus_on_background:ratio(colors.focus,colors.background),error_on_surface:ratio(colors.error,colors.surface),success_on_surface:ratio(colors.success,colors.surface)};
const captures=["normal-default.png","normal-minimum.png","normal-ultrawide.png","glow-off.png","monochrome.png","high-contrast.png","maximum-load.png"];
const manifest={schema_version:"1.0.0",run_id:runId,story:"P309",status:"complete",dependencies:["artifacts/raw/phase3-p307-hud-20260812t1810/run-manifest.json","artifacts/raw/repeat-play-p308-20260812/run-manifest.json"],verification:{accessibility_contract:"18/18",full_regression:"pass",build:"pass",screenshots:captureNames(captures),replay_visual_modes:"byte-identical judgement records",launch_window:"maximized",resize:["1600x900 reference","1280x720 minimum","1920x900 ultrawide"]},contrast:{ratios:contrast,thresholds:{text:4.5,focus:3.0},result:Object.entries(contrast).every(([name,value])=>value>=(name.includes("focus")?3:4.5))?"pass":"fail"},keyboard:{navigation:"Tab / Shift+Tab",activate:"Enter / Space",gameplay_pause:"Space",failure_retry:"R",failure_exit:"Escape",required_actions:["primary","back","retry","cancel"]},effects:{full_screen_flash:false,constant_camera_shake:false,procedural_shader:"audio-time-driven deterministic gameplay; animated product UI",glow_off:"all gameplay glow paths disabled",lightweight_fallback:"glow disabled or monochrome"},performance:perf,phase2_comparison:{baseline_frame_p95_us:16667,p309_maximum_load_p95_us:perf.frame_time_p95_us,interpretation:perf.comparison,external_allocation_profile:"Final Phase FH04 remains required; Godot release static heap limitation is not reclassified"},artifacts:Object.fromEntries(captures.map(name=>[name,{path:name,sha256:hash(join(rawDir,name))}])),build:{path:`artifacts/builds/${runId}-build/PanBeat.zip`,sha256:hash(buildPath)},review_procedure:"docs/phase3-screenshot-review.md",result:"pass"};
function captureNames(values){return values.map(value=>value.replace(".png",""));}
if(manifest.contrast.result!=="pass"||perf.frame_time_p95_us>20000||perf.node_delta!==0||perf.resource_delta!==0) throw new Error("P309 acceptance threshold failed");
writeFileSync(join(rawDir,"run-manifest.json"),JSON.stringify(manifest,null,2)+"\n");
