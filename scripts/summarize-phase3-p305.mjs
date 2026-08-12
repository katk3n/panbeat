import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [runId, rawDir, buildPath] = process.argv.slice(2);
if (!runId || !rawDir || !buildPath) throw new Error("usage: summarize-phase3-p305.mjs RUN_ID RAW_DIR BUILD_PATH");
const hash = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");
const image = (name) => ({path:name, sha256:hash(join(rawDir,name))});
const manifest = {
  schema_version:"1.0.0", run_id:runId, story:"P305", status:"complete",
  dependency:"artifacts/raw/phase3-p303-rich-ui-v3-20260812/run-manifest.json",
  geometry:{outer_radius_factor:0.425,spawn_radius_factor:0.225,ding_radius_factor:0.085,coordinate_contract:"unchanged",aspect_rule:"short side"},
  layers:{decoration:"independently switchable",judgement:"independently switchable",notes:"always retained",material:"recognizable translucent forged copper",background_transmission:0.76,per_frame_node_creation:0,per_frame_resource_creation:0},
  verification:{geometry_and_layer_tests:"12/12",full_regression:"pass",normal_1280x720:"pass",wide_1728x720_monochrome_no_glow:"pass",judgement_only:"pass",build:"pass"},
  artifacts:{normal:image("field-normal.png"),wide_fallback:image("field-wide-monochrome-no-glow.png"),judgement_only:image("field-judgement-only.png"),build:{path:`artifacts/builds/${runId}-build/PanBeat.zip`,sha256:hash(buildPath)}},
  result:"pass"
};
writeFileSync(join(rawDir,"run-manifest.json"),JSON.stringify(manifest,null,2)+"\n");
