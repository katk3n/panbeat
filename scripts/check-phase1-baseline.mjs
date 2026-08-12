#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

export function validateManifest(manifest, root = repositoryRoot) {
  const errors = [];
  const requiredStoryIds = Array.from({ length: 14 }, (_, index) => `P${101 + index}`);
  if (manifest.schema_version !== "1.0.0") errors.push("schema_version must be 1.0.0");
  if (manifest.story !== "P101") errors.push("story must be P101");
  if (manifest.contract?.engine_version !== "4.6.stable.official.89cea1439") {
    errors.push("unexpected Godot version");
  }
  if (manifest.contract?.renderer !== "gl_compatibility") errors.push("unexpected renderer");
  if (manifest.contract?.canonical_profile?.profile_id !== "roland-mn10-handpan-minor-v1") {
    errors.push("unexpected canonical profile");
  }
  if (!Array.isArray(manifest.scope?.included) || manifest.scope.included.length === 0) {
    errors.push("included scope is empty");
  }
  if (!Array.isArray(manifest.scope?.deferred_to_phase2) || manifest.scope.deferred_to_phase2.length === 0) {
    errors.push("Phase 2 deferrals are empty");
  }
  for (const storyId of requiredStoryIds) {
    if (!(storyId in (manifest.stories ?? {}))) errors.push(`missing story ${storyId}`);
  }
  for (const item of manifest.phase0_inheritance ?? []) {
    const absolutePath = resolve(root, item.path);
    if (!existsSync(absolutePath)) {
      errors.push(`missing inherited artifact: ${item.path}`);
      continue;
    }
    if (item.sha256) {
      const actual = createHash("sha256").update(readFileSync(absolutePath)).digest("hex");
      if (actual !== item.sha256) errors.push(`checksum mismatch: ${item.path}`);
    }
  }
  for (const riskId of ["R-P1-001", "R-P1-002", "R-P1-003"]) {
    const risk = (manifest.risks ?? []).find((candidate) => candidate.id === riskId);
    if (!risk || typeof risk.status !== "string" || risk.status.length === 0 || risk.owner_story !== "P111") {
      errors.push(`required P111 risk is not registered: ${riskId}`);
    }
  }
  return errors;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const manifestPath = resolve(repositoryRoot, process.argv[2] ?? "docs/phase1-acceptance.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const errors = validateManifest(manifest);
  if (errors.length > 0) {
    for (const error of errors) console.error(`phase1-baseline: ${error}`);
    process.exitCode = 1;
  } else {
    console.log("PHASE1_P101_BASELINE_OK");
  }
}
