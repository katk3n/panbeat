import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import test from "node:test";
import { validatePhase2Baseline } from "./check-phase2-baseline.mjs";

const root = resolve(import.meta.dirname, "..");
const manifest = JSON.parse(readFileSync(resolve(root, "docs/phase2-acceptance.json"), "utf8"));

test("P201 acceptance manifest matches immutable Phase 1 assets", () => {
  assert.deepEqual(validatePhase2Baseline(manifest, root), []);
});

test("unknown release-gate resolution is rejected", () => {
  const changed = structuredClone(manifest);
  changed.risks.find((risk) => risk.id === "R-P1-001").status = "resolved";
  assert.match(validatePhase2Baseline(changed, root).join("\n"), /R-P1-001/);
});

test("Phase 2 cannot grant release permission", () => {
  const changed = structuredClone(manifest);
  changed.gates.phase2.release_allowed = true;
  assert.match(validatePhase2Baseline(changed, root).join("\n"), /gates are not separated/);
});

test("missing security and unsupported case inventory is rejected", () => {
  const changed = structuredClone(manifest);
  changed.musicxml_cases.rejected = [];
  assert.match(validatePhase2Baseline(changed, root).join("\n"), /rejected MusicXML/);
});
