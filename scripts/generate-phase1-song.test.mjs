import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { buildPackage } from "./generate-phase1-song.mjs";

const source = JSON.parse(readFileSync(new URL("../game/content/phase1-fixed-song-v1/source.json", import.meta.url), "utf8"));

test("generation is byte-for-byte deterministic", () => {
  const first = buildPackage(source).outputs;
  const second = buildPackage(source).outputs;
  for (const [name, contents] of first) assert.deepEqual(contents, second.get(name), name);
});

test("chart covers techniques, rests, density, and exact margins", () => {
  const { notes, metadata } = buildPackage(source);
  assert.deepEqual(new Set(notes.map((note) => note.technique)), new Set(["tone", "ding", "slap"]));
  assert.ok(notes.some((note, index) => index > 0 && note.timestamp_us - notes[index - 1].timestamp_us >= 4000000));
  assert.ok(notes.some((note, index) => index > 0 && note.timestamp_us - notes[index - 1].timestamp_us === 250000));
  assert.equal(metadata.sync.first_note_timestamp_us, metadata.preload_margin_us);
  assert.equal(metadata.duration_us - metadata.sync.last_note_timestamp_us, metadata.ending_margin_us);
});

test("unknown profile targets are rejected", () => {
  const invalid = structuredClone(source);
  invalid.events[0].target_id = "tone-9";
  assert.throws(() => buildPackage(invalid), /unknown target/);
});
