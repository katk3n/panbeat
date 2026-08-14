class_name ValidatedRuntimeChart
extends RefCounted

const RuntimeNote := preload("res://domain/runtime_note.gd")

var _chart_id: String
var _duration_us: int
var _notes: Array[RuntimeChartNote] = []
var _tempo_map: Array[Dictionary] = []

func _init(chart_id: String, duration_us: int, note_values: Array[Dictionary], tempo_values: Array[Dictionary] = []) -> void:
	_chart_id = chart_id
	_duration_us = duration_us
	_tempo_map = tempo_values.duplicate(true)
	for value: Dictionary in note_values:
		_notes.append(RuntimeNote.new(value["note_id"], value["timestamp_us"], value["technique"], value["target_id"], value.get("hand", "unspecified")))

func chart_id() -> String:
	return _chart_id

func duration_us() -> int:
	return _duration_us

func note_count() -> int:
	return _notes.size()

func tempo_map() -> Array[Dictionary]:
	return _tempo_map.duplicate(true)

func note_at(index: int) -> Dictionary:
	return _notes[index].to_dictionary()

func notes_between(start_us: int, end_us: int) -> Array[Dictionary]:
	if end_us < start_us:
		return []
	var result: Array[Dictionary] = []
	var index: int = _lower_bound(start_us)
	while index < _notes.size() and _notes[index].timestamp_us() <= end_us:
		result.append(_notes[index].to_dictionary())
		index += 1
	return result

func to_dictionary() -> Dictionary:
	var note_values: Array[Dictionary] = []
	for note: RuntimeChartNote in _notes:
		note_values.append(note.to_dictionary())
	return {"chart_id": _chart_id, "duration_us": _duration_us, "notes": note_values}

func _lower_bound(timestamp_us: int) -> int:
	var low: int = 0
	var high: int = _notes.size()
	while low < high:
		var middle: int = (low + high) / 2
		if _notes[middle].timestamp_us() < timestamp_us:
			low = middle + 1
		else:
			high = middle
	return low
