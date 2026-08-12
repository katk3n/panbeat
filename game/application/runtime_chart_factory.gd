class_name RuntimeChartFactory
extends RefCounted

const RuntimeChart := preload("res://domain/runtime_chart.gd")
const TECHNIQUES: Array[String] = ["tone", "ding", "slap"]

static func build(chart: Dictionary, profile: Dictionary, audio_duration_us: int) -> Dictionary:
	var errors: Array[String] = []
	var schema_version: Variant = chart.get("schema_version")
	if schema_version is not String:
		errors.append("schema_version must be a string")
	elif schema_version != "1.0.0":
		var major: String = (schema_version as String).split(".")[0]
		errors.append("unsupported chart schema major version: %s" % major)
	var chart_id: Variant = chart.get("chart_id")
	if chart_id is not String or (chart_id as String).is_empty():
		errors.append("chart_id must be a non-empty string")
	var duration_value: Variant = chart.get("duration_us")
	if not _is_integer_value(duration_value) or int(duration_value) < 0:
		errors.append("duration_us must be a non-negative integer")
	var duration_us: int = int(duration_value) if _is_integer_value(duration_value) else 0
	if audio_duration_us < 0:
		errors.append("audio duration must be non-negative")
	elif duration_us > audio_duration_us:
		errors.append("chart duration exceeds audio duration")
	var note_values: Variant = chart.get("notes")
	if note_values is not Array:
		errors.append("notes must be an array")
		return {"ok": false, "errors": errors}
	if (note_values as Array).is_empty():
		errors.append("chart must contain at least one note")
	var allowed_pairs: Dictionary = _allowed_profile_pairs(profile)
	var ids: Dictionary = {}
	var previous_timestamp_us: int = -1
	var validated_notes: Array[Dictionary] = []
	for index: int in (note_values as Array).size():
		var value: Variant = (note_values as Array)[index]
		if value is not Dictionary:
			errors.append("notes[%d] must be an object" % index)
			continue
		var note: Dictionary = value as Dictionary
		var note_id: Variant = note.get("note_id")
		var timestamp: Variant = note.get("timestamp_us")
		var technique: Variant = note.get("technique")
		var target_id: Variant = note.get("target_id")
		if note_id is not String or (note_id as String).is_empty():
			errors.append("notes[%d].note_id must be a non-empty string" % index)
		elif ids.has(note_id):
			errors.append("duplicate note_id: %s" % note_id)
		else:
			ids[note_id] = true
		if not _is_integer_value(timestamp):
			errors.append("notes[%d].timestamp_us must be an integer" % index)
		elif int(timestamp) < 0:
			errors.append("negative note timestamp: %s" % note_id)
		elif int(timestamp) < previous_timestamp_us:
			errors.append("note timestamps must be ordered")
		elif int(timestamp) > duration_us or int(timestamp) > audio_duration_us:
			errors.append("note outside audio range: %s" % note_id)
		else:
			previous_timestamp_us = int(timestamp)
		if technique is not String or not TECHNIQUES.has(technique as String):
			errors.append("unknown note technique: %s" % technique)
		elif target_id is not String or not allowed_pairs.has("%s:%s" % [technique, target_id]):
			errors.append("target is not available in canonical profile: %s:%s" % [technique, target_id])
		if note_id is String and _is_integer_value(timestamp) and technique is String and target_id is String:
			validated_notes.append({"note_id": note_id, "timestamp_us": int(timestamp), "technique": technique, "target_id": target_id})
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {"ok": true, "chart": RuntimeChart.new(chart_id, duration_us, validated_notes)}

static func _allowed_profile_pairs(profile: Dictionary) -> Dictionary:
	var pairs: Dictionary = {}
	for value: Variant in profile.get("mappings", []):
		if value is Dictionary:
			var mapping: Dictionary = value as Dictionary
			pairs["%s:%s" % [mapping.get("technique", ""), mapping.get("target_id", "")]] = true
	return pairs

static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value as float) and floorf(value as float) == value as float
	return false
