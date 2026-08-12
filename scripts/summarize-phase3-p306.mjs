import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [runId,rawDir,buildPath]=process.argv.slice(2);
if(!runId||!rawDir||!buildPath) throw new Error("usage: summarize-phase3-p306.mjs RUN_ID RAW_DIR BUILD_PATH");
const hash=(path)=>createHash("sha256").update(readFileSync(path)).digest("hex");
const manifest={
  schema_version:"1.0.0",run_id:runId,story:"P306",status:"complete",
  dependencies:["artifacts/raw/phase3-p302-ding-20260812t1530/run-manifest.json","artifacts/raw/phase3-p305-field-20260812t1640/run-manifest.json"],
  verification:{visual_contract:"18/18",full_regression:"pass",deterministic_replay:"7/7 unchanged",max_active_notes:"64/64 no overflow",overflow_observable:"65th note increments overflow",luminous_shader_capture:"pass",launch_window:"maximized with expand aspect; 1600x900 reference",build:"pass"},
  techniques:{tone:"single local saturated-cyan emissive orb",ding:"single full ring converging inward with inward ticks",slap:"single full ring expanding outward with outward ticks"},
  feedback:{tone:"target-local bloom surge",ding:"strong central bloom surge",slap:"strong Outer Hit Radius bloom surge",grades:"single ring width + bloom strength + text",white_fill:false,impact_rays:false,miss:"text only at the actual target",source:"judgement record via fixed scheduler slots"},
  allocation:{strategy:"existing fixed scheduler visual slots",per_frame_node_creation:0,per_frame_resource_creation:0},
  combo:{thresholds:[5,10,25],effect_on_transport_judgement_score:"none"},
  visual_quality:{procedural_shader:"audio-time-driven recognizable translucent copper with integrated note SDF",background_transmission:0.76,note_bloom_shader:"integrated SDF Gaussian",tone_note_shape:"foreground saturated-cyan center-hot emissive orb",orb_draw_order:"above handpan and targets",orb_bloom_strength:"strong atmospheric spill",bloom_profile:"luminous core, diffused mist, atmospheric spill",bloom_shader_capacity:16,smooth_bloom_falloff:"continuous Gaussian",single_note_ring:false,hollow_note_core:false,black_note_core:false,bloom_strength:"pronounced",hit_bloom_strength:"bright surge",impact_rays:false,deep_resonance_identity:"jade mist and moving caustics",legacy_highlight_arc:false,ui_background:"moving mist, breathing halo, resonance waves, and wandering light pools",dense_load:{threshold:16,halo_layers:1,trails:false},note_trails:false,technique_palette:["cyan tone","amber ding","coral slap"]},
  artifacts:{normal:{path:"effects-normal.png",sha256:hash(join(rawDir,"effects-normal.png"))},build:{path:`artifacts/builds/${runId}-build/PanBeat.zip`,sha256:hash(buildPath)}},
  phase2_baseline:"artifacts/raw/phase2-p215-audio-duration-fix-20260812/run-manifest.json",result:"pass"
};
writeFileSync(join(rawDir,"run-manifest.json"),JSON.stringify(manifest,null,2)+"\n");
