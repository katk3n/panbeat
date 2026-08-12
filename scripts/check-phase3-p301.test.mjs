import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const contract = JSON.parse(readFileSync(new URL("../docs/phase3-p301-design-tokens.json", import.meta.url)));

test("P301 options share one immutable gameplay fixture", () => {
  assert.equal(contract.story, "P301");
  assert.equal(contract.status, "approved");
  assert.equal(contract.selected_option, "quiet_forge");
  assert.deepEqual(Object.keys(contract.options).sort(), ["polar_resonance", "quiet_forge"]);
  assert.equal(contract.fixture_contract.song_time_us, 10_000_000);
  assert.deepEqual(contract.fixture_contract.techniques, ["tone", "ding", "slap"]);
  for (const option of Object.values(contract.options)) {
    assert.deepEqual(Object.keys(option.palette).sort(), ["accent", "background", "error", "focus", "muted", "primary", "success", "surface", "warning"]);
    assert.ok(option.glow.idle <= option.glow.active && option.glow.active <= option.glow.hit);
  }
});

test("P301 accessibility and asset provenance candidates are explicit", () => {
  assert.equal(contract.shared_tokens.reduced_effects.glow_multiplier, 0);
  assert.equal(contract.shared_tokens.reduced_effects.particle_count, 0);
  assert.deepEqual(contract.assets.bundled_external_assets, []);
  for (const kind of ["font", "icons", "textures"]) {
    assert.match(contract.assets[kind].license_check, /license|SPDX/i);
  }
});
