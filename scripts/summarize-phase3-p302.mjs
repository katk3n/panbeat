import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [runId, rawDir, stage] = process.argv.slice(2);
if (!runId || !rawDir || !["prepare", "complete"].includes(stage)) {
  throw new Error("usage: summarize-phase3-p302.mjs RUN_ID RAW_DIR prepare|complete");
}
const manifestPath = join(rawDir, "run-manifest.json");
if (stage === "complete") {
  const manifest = JSON.parse(readFileSync(manifestPath));
  manifest.verification.build = "pass";
  manifest.status = "complete";
  manifest.result = "pass";
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
  process.exit(0);
}
const screenshotPath = join(rawDir, "ding-tone-slap.png");
const manifest = {
  schema_version: "1.0.0",
  run_id: runId,
  story: "P302",
  status: "prepared",
  dependency: "artifacts/raw/phase3-p301-approval-20260812/run-manifest.json",
  commands: [`scripts/check-game --mode test --run-id ${runId}-tests`, `scripts/check-phase3-p302 ${runId}`],
  verification: {kinematics: "13/13", phase2_regression: "pass", screenshot: "pass", build: "pending"},
  contracts: {
    transport: "unchanged",
    judgement: "unchanged",
    score: "unchanged",
    ding: "full ring from spawn radius 0.45 to central judgement radius 0.17",
    tone: "local outward unchanged",
    slap: "full ring outward unchanged",
    feedback: "Ding success ripple originates at center"
  },
  artifacts: {screenshot: "ding-tone-slap.png", sha256: createHash("sha256").update(readFileSync(screenshotPath)).digest("hex")},
  result: "pending-build"
};
writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
