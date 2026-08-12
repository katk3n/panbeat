#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

export function validatePhase2Baseline(manifest, root = repositoryRoot) {
  const errors = [];
  if (manifest.schema_version !== "1.0.0") errors.push("schema_version must be 1.0.0");
  if (manifest.story !== "P201" || manifest.status !== "complete") errors.push("P201 must be complete");
  if (manifest.contract?.musicxml_version !== "4.0" || manifest.contract?.musicxml_root !== "score-partwise") {
    errors.push("MusicXML 4.0 score-partwise contract is missing");
  }
  if ((manifest.musicxml_cases?.accepted ?? []).length < 6) errors.push("accepted MusicXML fixture inventory is incomplete");
  if ((manifest.musicxml_cases?.rejected ?? []).length < 12) errors.push("rejected MusicXML fixture inventory is incomplete");
  const requiredLimits = ["max_source_bytes", "max_xml_depth", "max_xml_elements"];
  for (const key of requiredLimits) {
    if (!Number.isInteger(manifest.input_contracts?.score?.[key]) || manifest.input_contracts.score[key] <= 0) {
      errors.push(`invalid score limit: ${key}`);
    }
  }
  for (const storyId of Array.from({ length: 17 }, (_, index) => `P${201 + index}`)) {
    if (!(storyId in (manifest.stories ?? {}))) errors.push(`missing story ${storyId}`);
  }
  const trackedText = JSON.stringify(manifest.handoff_tracking ?? []);
  for (const token of ["P203", "P209", "P210", "P211", "P214", "P206", "FH01", "FH03", "FH04"]) {
    if (!trackedText.includes(token)) errors.push(`missing handoff target ${token}`);
  }
  for (const riskId of ["R-P1-001", "R-P1-003"]) {
    const risk = (manifest.risks ?? []).find((candidate) => candidate.id === riskId);
    if (risk?.status !== "deferred-release-gate-blocker") errors.push(`${riskId} must remain a release blocker`);
  }
  if (manifest.gates?.phase2?.release_allowed !== false || manifest.gates?.final_release_hardening?.required_for_release !== true) {
    errors.push("Phase 2 and release gates are not separated");
  }
  for (const asset of manifest.phase1_baseline?.immutable_assets ?? []) {
    const path = resolve(root, asset.path);
    if (!existsSync(path)) {
      errors.push(`missing baseline asset: ${asset.path}`);
      continue;
    }
    const actual = createHash("sha256").update(readFileSync(path)).digest("hex");
    if (actual !== asset.sha256) errors.push(`baseline checksum mismatch: ${asset.path}`);
  }
  return errors;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const manifestPath = resolve(repositoryRoot, process.argv[2] ?? "docs/phase2-acceptance.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const errors = validatePhase2Baseline(manifest);
  if (errors.length > 0) {
    for (const error of errors) console.error(`phase2-baseline: ${error}`);
    process.exitCode = 1;
  } else {
    console.log("PHASE2_P201_BASELINE_OK");
  }
}
