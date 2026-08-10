#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import Ajv from "ajv/dist/2020.js";

const root = path.resolve(import.meta.dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const readJson = relative => JSON.parse(read(relative));
const hash = relative => crypto.createHash("sha256").update(fs.readFileSync(path.join(root, relative))).digest("hex");
const validate = new Ajv({ strict: true }).compile(readJson("schemas/run-manifest.schema.json"));
const manifests = [
  "artifacts/raw/unity-u06/run-manifest.json",
  "artifacts/raw/godot-g06/run-manifest.json",
  "artifacts/raw/e01-comparison/run-manifest.json",
  "artifacts/raw/e02-real-device/run-manifest.json",
  "artifacts/raw/e03-release-drift/run-manifest.json",
  "artifacts/raw/e03-engine-selection/run-manifest.json"
];
for (const relative of manifests) {
  const manifest = readJson(relative);
  if (!validate(manifest)) throw new Error(`${relative}: ${JSON.stringify(validate.errors)}`);
  for (const item of [...manifest.inputs, ...manifest.outputs])
    if (hash(item.path) !== item.sha256) throw new Error(`${relative}: hash mismatch ${item.path}`);
}
const result = readJson("artifacts/raw/e03-engine-selection/score-result.json");
if (result.status !== "Complete" || result.formal_recommendation?.engine !== "godot" || result.formal_recommendation?.version !== "4.6.stable.official.89cea1439")
  throw new Error("E03 formal recommendation is inconsistent");
const architecture = read("docs/architecture.md");
if (!architecture.includes("ADR-001: Godot 4.6 + typed GDScriptを採用") || !architecture.includes("**Status:** Accepted（2026-08-10）"))
  throw new Error("ADR-001 is not Accepted consistently");
const project = read("game/project.godot");
if (!project.includes('config/features=PackedStringArray("4.6", "GL Compatibility")')) throw new Error("game toolchain is not fixed to Godot 4.6");
console.log(`Phase 0 selection verified: ${manifests.length} manifests, Godot 4.6.stable.official.89cea1439 / typed GDScript`);
