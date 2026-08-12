import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { validateManifest } from "./check-phase1-baseline.mjs";

const manifest = JSON.parse(readFileSync(new URL("../docs/phase1-acceptance.json", import.meta.url), "utf8"));

test("the repository Phase 1 baseline is valid", () => {
  assert.deepEqual(validateManifest(manifest), []);
});

test("an unknown engine version is rejected", () => {
  const changed = structuredClone(manifest);
  changed.contract.engine_version = "unknown";
  assert.match(validateManifest(changed).join("\n"), /unexpected Godot version/);
});

test("a missing required risk is rejected", () => {
  const changed = structuredClone(manifest);
  changed.risks = changed.risks.filter((risk) => risk.id !== "R-P1-002");
  assert.match(validateManifest(changed).join("\n"), /R-P1-002/);
});
