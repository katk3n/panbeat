class_name MidiNormalizer
extends RefCounted

static func normalize(record: Dictionary, profile: Dictionary) -> Dictionary:
	var message_type: String = record.get("message_type", "unknown")
	if message_type == "note_on" and int(record.get("data2", 0)) == 0:
		return _diagnostic("note_on_zero_velocity", record)
	if message_type != "note_on":
		var code_by_type: Dictionary = {"note_off":"note_off", "control_change":"control_change", "poly_pressure":"aftertouch", "channel_pressure":"aftertouch", "unknown":"unknown_message"}
		return _diagnostic(code_by_type.get(message_type, "unsupported_message"), record)
	for mapping: Dictionary in profile.get("mappings", []):
		if mapping["channel_wire"] == record["channel_wire"] and mapping["note"] == record["data1"] and record["data2"] >= mapping["velocity_min"] and record["data2"] <= mapping["velocity_max"]:
			return {"kind":"normalized_input", "input_event_id":"midi-%s-%s-%s" % [record.get("arrival_timestamp_us", 0), record.get("channel_wire", -1), record.get("data1", -1)], "source_kind":record.get("source_kind", "physical_midi"), "arrival_timestamp_us":int(record.get("arrival_timestamp_us", 0)), "arrival_clock_domain":record.get("arrival_clock_domain", "godot_time_ticks"), "technique":mapping["technique"], "target_id":mapping["target_id"], "velocity":record["data2"]}
	return _diagnostic("unknown_mapping", record)

static func _diagnostic(code: String, record: Dictionary) -> Dictionary:
	return {"kind":"diagnostic", "code":code, "raw":record}

static func load_profile(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary
