class_name MidiNormalizer
extends RefCounted

static func normalize(record: Dictionary, profile: Dictionary) -> Dictionary:
	if record["message_type"] != "note_on":
		return {"kind":"diagnostic", "code":"non_trigger_message", "raw":record}
	for mapping: Dictionary in profile.get("mappings", []):
		if mapping["channel_wire"] == record["channel_wire"] and mapping["note"] == record["data1"] and record["data2"] >= mapping["velocity_min"] and record["data2"] <= mapping["velocity_max"]:
			return {"kind":"normalized_input", "arrival_timestamp_us":record["arrival_timestamp_us"], "technique":mapping["technique"], "target_id":mapping["target_id"], "velocity":record["data2"]}
	return {"kind":"diagnostic", "code":"unknown_mapping", "raw":record}

static func load_profile(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary
