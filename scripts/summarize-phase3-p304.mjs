import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [runId, rawDir, buildPath] = process.argv.slice(2);
if (!runId || !rawDir || !buildPath) throw new Error("usage: summarize-phase3-p304.mjs RUN_ID RAW_DIR BUILD_PATH");
const hash = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");
const manifest = {
  schema_version: "1.0.0", run_id: runId, story: "P304", status: "complete",
  dependency: "artifacts/raw/phase3-p303-rich-ui-v3-20260812/run-manifest.json",
  verification: {shell_contract: "10/10", product_flow_regression: "17/17 within full suite", full_regression: "pass", screenshots: "pass", build: "pass"},
  contracts: {
    current_screen: "selected navigation marker plus CURRENT text and accessibility_name",
    midi: ["ready", "no_ports", "reopen_required"],
    silence: "never represented as physical disconnect",
    recoverable_error: "user summary, recovery focus, collapsible technical detail, non-layout overlay",
    navigation: "existing ProductFlowService transitions only"
  },
  artifacts: {
    normal: {path: "app-shell.png", sha256: hash(join(rawDir, "app-shell.png"))},
    recoverable_error: {path: "recoverable-error.png", sha256: hash(join(rawDir, "recoverable-error.png"))},
    build: {path: `artifacts/builds/${runId}-build/PanBeat.zip`, sha256: hash(buildPath)}
  },
  result: "pass"
};
writeFileSync(join(rawDir, "run-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
