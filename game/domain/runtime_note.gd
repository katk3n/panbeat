class_name RuntimeChartNote
extends RefCounted

var _note_id: String
var _timestamp_us: int
var _technique: String
var _target_id: String

func _init(note_id: String, timestamp_us: int, technique: String, target_id: String) -> void:
	_note_id = note_id
	_timestamp_us = timestamp_us
	_technique = technique
	_target_id = target_id

func timestamp_us() -> int:
	return _timestamp_us

func to_dictionary() -> Dictionary:
	return {"note_id": _note_id, "timestamp_us": _timestamp_us, "technique": _technique, "target_id": _target_id}
