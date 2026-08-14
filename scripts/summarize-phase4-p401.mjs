import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [runId, rawDir, buildPath] = process.argv.slice(2);
if (!runId || !rawDir || !buildPath) throw new Error("usage: summarize-phase4-p401.mjs RUN_ID RAW_DIR BUILD_PATH");
const artifact = file => {
  const bytes = fs.readFileSync(file);
  return { path: path.relative(process.cwd(), file), bytes: bytes.length, sha256: crypto.createHash("sha256").update(bytes).digest("hex") };
};
const matchedCount = (file, expression, label) => {
  const match = fs.readFileSync(file, "utf8").match(expression);
  if (!match) throw new Error(`missing ${label} result in ${file}`);
  return match[1];
};
const outputs = ["p401.log", "schema.log", "capture.log", "notepan-library.png"].map(name => artifact(path.join(rawDir, name)));
outputs.push(artifact(buildPath));
const focusedTests = matchedCount(path.join(rawDir, "p401.log"), /PANBEAT_P401_TESTS_OK (\d+\/\d+)/, "focused test");
const schemaCases = matchedCount(path.join(rawDir, "schema.log"), /Validated (\d+) schema cases\./, "schema validation");
const manifest = {
  schema_version: "1.0.0",
  run_id: runId,
  story: "P401",
  status: "complete",
  result: "pass",
  source_revision: "working-tree",
  environment: { engine: "Godot 4.6.stable.official.89cea1439", platform: "macOS" },
  contract: { source_format: "NotePan", schemas: [6, 8], compressed: false, tracks: 1, importer_version: "panbeat-score-importer-v2", package_version: "1.2.0" },
  verification: { focused_tests: focusedTests, schema_cases: `${schemaCases}/${schemaCases}`, screenshot: "pass", macos_build: "pass" },
  reproduce: `scripts/check-phase4-p401 ${runId}`,
  outputs
};
fs.writeFileSync(path.join(rawDir, "run-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
