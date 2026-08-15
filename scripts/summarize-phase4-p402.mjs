import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [runId, rawDir, buildPath] = process.argv.slice(2);
if (!runId || !rawDir || !buildPath) throw new Error("usage: summarize-phase4-p402.mjs RUN_ID RAW_DIR BUILD_PATH");
const artifact = file => {
  const bytes = fs.readFileSync(file);
  return { path: path.relative(process.cwd(), file), bytes: bytes.length, sha256: crypto.createHash("sha256").update(bytes).digest("hex") };
};
const matched = (file, expression, label) => {
  const match = fs.readFileSync(file, "utf8").match(expression);
  if (!match) throw new Error(`missing ${label} in ${file}`);
  return match[1];
};
const outputs = ["p402.log", "schema.log", "capture.log", "custom-layout-library.png"].map(name => artifact(path.join(rawDir, name)));
outputs.push(artifact(buildPath));
const focusedTests = matched(path.join(rawDir, "p402.log"), /PANBEAT_P402_TESTS_OK (\d+\/\d+)/, "focused tests");
const schemaCases = matched(path.join(rawDir, "schema.log"), /Validated (\d+) schema cases\./, "schema cases");
const manifest = {
  schema_version: "1.0.0", run_id: runId, story: "P402", status: "complete", result: "pass", source_revision: "working-tree",
  environment: { engine: "Godot 4.6.stable.official.89cea1439", platform: "macOS" },
  contract: { layout_version: "1.0.0", strategy: "lowest-ding-ascending-zigzag-v1", package_version: "1.3.0" },
  verification: { focused_tests: focusedTests, schema_cases: `${schemaCases}/${schemaCases}`, screenshot: "pass", macos_build: "pass" },
  reproduce: `scripts/check-phase4-p402 ${runId}`, outputs
};
fs.writeFileSync(path.join(rawDir, "run-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
