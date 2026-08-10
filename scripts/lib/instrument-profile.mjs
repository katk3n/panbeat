export function validateProfileSemantics(profile) {
  const errors = [];
  const keys = new Set();
  for (const mapping of profile.mappings) {
    const key = `${mapping.channel_wire}:${mapping.note}`;
    if (keys.has(key)) errors.push(`duplicate mapping for channel_wire:note ${key}`);
    keys.add(key);
    if (mapping.velocity_min > mapping.velocity_max) {
      errors.push(`velocity_min exceeds velocity_max for channel_wire:note ${key}`);
    }
  }
  if (profile.deduplication.mode === "none" && profile.deduplication.window_us !== 0) {
    errors.push("deduplication window_us must be 0 when mode is none");
  }
  return errors;
}

export function mapMidiEvent(event, profile) {
  if (event.message_type !== "note_on") {
    return {
      kind: "diagnostic",
      code: "non_trigger_message",
      source_sequence: event.sequence,
      message_type: event.message_type,
      raw_bytes: event.raw_bytes
    };
  }

  const mapping = profile.mappings.find((candidate) =>
    candidate.channel_wire === event.channel_wire
    && candidate.note === event.data1
    && event.data2 >= candidate.velocity_min
    && event.data2 <= candidate.velocity_max);

  if (!mapping) {
    return {
      kind: "diagnostic",
      code: "unknown_mapping",
      source_sequence: event.sequence,
      message_type: event.message_type,
      channel_wire: event.channel_wire,
      note: event.data1,
      velocity: event.data2,
      raw_bytes: event.raw_bytes
    };
  }

  return {
    kind: "normalized_input",
    source_sequence: event.sequence,
    timestamp_us: event.timestamp_us,
    clock_domain: event.clock_domain,
    technique: mapping.technique,
    target_id: mapping.target_id,
    velocity: event.data2
  };
}

export function auditTrace(trace, profile) {
  const results = trace.events.map((event) => mapMidiEvent(event, profile));
  const noteOnCount = trace.events.filter((event) => event.message_type === "note_on").length;
  const normalized = results.filter((result) => result.kind === "normalized_input");
  const diagnostics = results.filter((result) => result.kind === "diagnostic");
  return {
    event_count: trace.events.length,
    note_on_count: noteOnCount,
    mapped_count: normalized.length,
    unmapped_note_on_count: diagnostics.filter((item) => item.code === "unknown_mapping").length,
    diagnostic_count: diagnostics.length,
    diagnostic_codes: Object.fromEntries([...new Set(diagnostics.map((item) => item.code))]
      .sort().map((code) => [code, diagnostics.filter((item) => item.code === code).length])),
    technique_counts: Object.fromEntries([...new Set(normalized.map((item) => item.technique))]
      .sort().map((technique) => [technique, normalized.filter((item) => item.technique === technique).length]))
  };
}
