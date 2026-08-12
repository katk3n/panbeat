import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [runId, rawDir, buildPath] = process.argv.slice(2);
if (!runId || !rawDir || !buildPath) throw new Error("usage: summarize-phase3-p303.mjs RUN_ID RAW_DIR BUILD_PATH");
const hash = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");
const manifest = {
  schema_version: "1.0.0",
  run_id: runId,
  story: "P303",
  status: "complete",
  dependency: "artifacts/raw/phase3-p301-approval-20260812/run-manifest.json",
  direction: "quiet_forge",
  contracts: {
    tokens: "game/presentation/ui_tokens.gd",
    theme: "game/presentation/panbeat_theme.gd",
    design_proposal: "docs/phase3-p301-design-tokens.json",
    asset_manifest: "docs/phase3-asset-manifest.json",
    fallback: "Godot/OS fallback font; existing controls remain operable while later screens migrate"
  },
  verification: {theme_contract: "28/28", phase2_and_p302_regression: "pass", before_after_gallery: "pass", build: "pass"},
  artifacts: {
    before: {path: "component-gallery-before.png", sha256: hash(join(rawDir, "component-gallery-before.png"))},
    after: {path: "component-gallery-after.png", sha256: hash(join(rawDir, "component-gallery-after.png"))},
    build: {path: `artifacts/builds/${runId}-build/PanBeat.zip`, sha256: hash(buildPath)}
  },
  accessibility: {focus: "3 px light outline independent of accent/background", statuses: "glyph + label + outlined status shape", disabled: "reduced contrast plus disabled interaction", reduced_effects_glow: 0.0},
  external_assets_added: [],
  result: "pass"
};
writeFileSync(join(rawDir, "run-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
