import fs from "node:fs";
import Ajv2020 from "ajv/dist/2020.js";

export function createTraceValidator(schema) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  return ajv.compile(schema);
}

export function parseTrace(text, validate) {
  const records = text.split(/\r?\n/u).filter((line) => line.trim().length > 0).map((line, index) => {
    let record;
    try { record = JSON.parse(line); } catch (error) { throw new Error(`line ${index + 1}: invalid JSON: ${error.message}`); }
    if (!validate(record)) throw new Error(`line ${index + 1}: ${validate.errors.map((item) => `${item.instancePath || "/"} ${item.message}`).join("; ")}`);
    return record;
  });
  if (records.length === 0) return { session: null, events: [] };
  if (records[0].record_type !== "session") throw new Error("line 1: first record must be a session");
  const session = records[0];
  const events = records.slice(1);
  if (events.some((record) => record.record_type !== "event")) throw new Error("only the first record may be a session");
  let previous = -1;
  for (const event of events) {
    if (event.session_id !== session.session_id) throw new Error(`sequence ${event.sequence}: session_id mismatch`);
    if (event.clock_domain !== session.clock_domain) throw new Error(`sequence ${event.sequence}: clock_domain mismatch`);
    if (event.timestamp_us < previous) throw new Error(`sequence ${event.sequence}: timestamp order is invalid`);
    previous = event.timestamp_us;
  }
  return { session, events };
}

const nearestRank = (sorted, percentile) => sorted.length === 0 ? null : sorted[Math.ceil(percentile * sorted.length) - 1];
const counts = (values) => Object.fromEntries([...new Set(values)].sort((a, b) => String(a).localeCompare(String(b))).map((value) => [value, values.filter((item) => item === value).length]));

export function summarizeTrace(trace) {
  const intervals = trace.events.slice(1).map((event, index) => event.timestamp_us - trace.events[index].timestamp_us).sort((a, b) => a - b);
  const noteEvents = trace.events.filter((event) => event.message_type === "note_on" || event.message_type === "note_off");
  const summary = {
    schema_version: "1.0.0",
    event_count: trace.events.length,
    message_types: counts(trace.events.map((event) => event.message_type)),
    channels_wire: counts(trace.events.filter((event) => event.channel_wire !== undefined).map((event) => event.channel_wire)),
    channels_display: counts(trace.events.filter((event) => event.channel_display !== undefined).map((event) => event.channel_display)),
    notes: counts(noteEvents.filter((event) => event.data1 !== undefined).map((event) => event.data1)),
    intervals_us: { count: intervals.length }
  };
  if (trace.session) summary.session_id = trace.session.session_id;
  if (intervals.length) Object.assign(summary.intervals_us, {
    min: intervals[0], max: intervals.at(-1),
    mean: intervals.reduce((sum, value) => sum + value, 0) / intervals.length,
    p50: nearestRank(intervals, 0.5), p95: nearestRank(intervals, 0.95), p99: nearestRank(intervals, 0.99)
  });
  return summary;
}

export function makeReplayFixture(trace, speed = 1) {
  if (!Number.isFinite(speed) || speed <= 0) throw new Error("speed must be a positive number");
  const origin = trace.events[0]?.timestamp_us ?? 0;
  return {
    schema_version: "1.0.0", fixture_type: "midi_replay", time_unit: "microseconds",
    source_clock_domain: trace.session?.clock_domain ?? "synthetic", replay_clock_domain: "replay_elapsed",
    speed,
    events: trace.events.map((event) => ({ scheduled_offset_us: Math.round((event.timestamp_us - origin) / speed), event }))
  };
}

export async function replayTrace(trace, { speed = 1, noWait = false, emit }) {
  const fixture = makeReplayFixture(trace, speed);
  const started = performance.now();
  for (const item of fixture.events) {
    if (!noWait) {
      const remainingMs = item.scheduled_offset_us / 1000 - (performance.now() - started);
      if (remainingMs > 0) await new Promise((resolve) => setTimeout(resolve, remainingMs));
    }
    emit(item);
  }
  return fixture;
}

export function readTrace(filePath, validate) { return parseTrace(fs.readFileSync(filePath, "utf8"), validate); }
