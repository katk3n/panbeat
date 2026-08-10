import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { auditTrace, mapMidiEvent, validateProfileSemantics } from "./lib/instrument-profile.mjs";

const profile = JSON.parse(fs.readFileSync(new URL("../shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json", import.meta.url), "utf8"));
const event = (message_type, channel_wire, note, velocity = 100, sequence = 0) => ({
  schema_version: "1.0.0", record_type: "event", session_id: "t", sequence,
  timestamp_us: 1000 + sequence, clock_domain: "synthetic",
  raw_bytes: [0x90 | channel_wire, note, velocity], message_type,
  channel_wire, channel_display: channel_wire + 1, data1: note, data2: velocity
});

test("profile has unique mappings and valid velocity ranges", () => {
  assert.deepEqual(validateProfileSemantics(profile), []);
});

test("all nine Handpan Minor pads map to ding or their tone target", () => {
  const notes = [50, 57, 58, 60, 62, 64, 65, 67, 69];
  const mapped = notes.map((note, index) => mapMidiEvent(event("note_on", 0, note, 127, index), profile));
  assert.deepEqual(mapped.map((item) => item.target_id), ["ding", "tone-2", "tone-3", "tone-4", "tone-5", "tone-6", "tone-7", "tone-8", "tone-9"]);
});

test("left and right Handpan Slaps are distinguished from Pad 1", () => {
  assert.equal(mapMidiEvent(event("note_on", 0, 50), profile).technique, "ding");
  assert.equal(mapMidiEvent(event("note_on", 0, 93), profile).technique, "slap");
  assert.equal(mapMidiEvent(event("note_on", 0, 95), profile).technique, "slap");
  assert.equal(mapMidiEvent(event("note_on", 1, 50), profile).code, "unknown_mapping");
});

test("unknown and non-trigger messages remain diagnostics", () => {
  assert.equal(mapMidiEvent(event("note_on", 0, 99), profile).code, "unknown_mapping");
  const pressure = mapMidiEvent(event("poly_pressure", 0, 47), profile);
  assert.equal(pressure.kind, "diagnostic");
  assert.deepEqual(pressure.raw_bytes, [0x90, 47, 100]);
});

test("deduplication mode none preserves repeated mapped hits", () => {
  const repeated = [event("note_on", 0, 50, 100, 0), event("note_on", 0, 50, 100, 1)];
  const audit = auditTrace({ events: repeated }, profile);
  assert.equal(profile.deduplication.mode, "none");
  assert.equal(audit.mapped_count, 2);
});
