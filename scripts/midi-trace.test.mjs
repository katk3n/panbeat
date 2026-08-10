import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { createTraceValidator, makeReplayFixture, parseTrace, summarizeTrace } from "./lib/midi-trace.mjs";

const schema = JSON.parse(fs.readFileSync(new URL("../schemas/raw-midi-trace.schema.json", import.meta.url), "utf8"));
const validator = () => createTraceValidator(schema);
const header = '{"schema_version":"1.0.0","record_type":"session","session_id":"t","started_at":"2026-08-09T00:00:00+09:00","clock_domain":"synthetic","time_unit":"microseconds"}';
const event = (sequence, timestamp, note = 60) => JSON.stringify({ schema_version:"1.0.0", record_type:"event", session_id:"t", sequence, timestamp_us:timestamp, clock_domain:"synthetic", raw_bytes:[144,note,100], message_type:"note_on", channel_wire:0, channel_display:1, data1:note, data2:100 });

test("empty trace", () => assert.equal(summarizeTrace(parseTrace("", validator())).event_count, 0));
test("single event omits unavailable interval statistics", () => assert.deepEqual(summarizeTrace(parseTrace(`${header}\n${event(0, 1000)}\n`, validator())).intervals_us, { count:0 }));
test("simultaneous events preserve order", () => assert.deepEqual(makeReplayFixture(parseTrace(`${header}\n${event(0, 1000)}\n${event(1, 1000, 61)}\n`, validator())).events.map((item) => item.scheduled_offset_us), [0, 0]));
test("rapid events summarize intervals", () => assert.equal(summarizeTrace(parseTrace(`${header}\n${event(0, 1000)}\n${event(1, 1100)}\n${event(2, 1200)}\n`, validator())).intervals_us.p95, 100));
test("out-of-order trace is rejected", () => assert.throws(() => parseTrace(`${header}\n${event(0, 2000)}\n${event(1, 1000)}\n`, validator()), /timestamp order/));
test("speed scales deterministic offsets", () => assert.deepEqual(makeReplayFixture(parseTrace(`${header}\n${event(0, 1000)}\n${event(1, 3000)}\n`, validator()), 2).events.map((item) => item.scheduled_offset_us), [0, 1000]));
