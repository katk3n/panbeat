class_name RecordedMidiReplay
extends RefCounted

const Normalizer := preload("res://infrastructure/midi_normalizer.gd")

static func load_jsonl(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "recorded MIDI trace could not be opened", "events": []}
	var events: Array[Dictionary] = []
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is not Dictionary:
			return {"ok": false, "error": "invalid JSONL at line %d" % line_number, "events": []}
		var record: Dictionary = parsed as Dictionary
		if record.get("record_type") == "event":
			var raw: Dictionary = record.duplicate(true)
			raw["arrival_timestamp_us"] = int(record.get("timestamp_us", 0))
			raw["arrival_clock_domain"] = record.get("clock_domain", "monotonic")
			raw["source_kind"] = "recorded_replay"
			events.append(raw)
	return {"ok": true, "events": events}

static func normalize_events(events: Array[Dictionary], profile: Dictionary) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for raw: Dictionary in events:
		var result: Dictionary = Normalizer.normalize(raw, profile)
		if result.get("kind") == "normalized_input":
			normalized.append(result)
	return normalized
