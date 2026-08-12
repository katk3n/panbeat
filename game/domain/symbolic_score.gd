class_name SymbolicScore
extends RefCounted

var source_id: String
var version: String
var part_id: String
var ticks_per_quarter: int
var measures: Array[Dictionary]
var notes: Array[Dictionary]
var tempo_events: Array[Dictionary]
var time_signatures: Array[Dictionary]
var divisions_events: Array[Dictionary]

func _init(
	source_value: String,
	version_value: String,
	part_value: String,
	ticks_value: int,
	measure_values: Array[Dictionary],
	note_values: Array[Dictionary],
	tempo_values: Array[Dictionary],
	time_values: Array[Dictionary],
	divisions_values: Array[Dictionary]
) -> void:
	source_id = source_value
	version = version_value
	part_id = part_value
	ticks_per_quarter = ticks_value
	measures = measure_values.duplicate(true)
	notes = note_values.duplicate(true)
	tempo_events = tempo_values.duplicate(true)
	time_signatures = time_values.duplicate(true)
	divisions_events = divisions_values.duplicate(true)

func to_dictionary() -> Dictionary:
	return {
		"source_id": source_id,
		"musicxml_version": version,
		"part_id": part_id,
		"ticks_per_quarter": ticks_per_quarter,
		"measures": measures.duplicate(true),
		"notes": notes.duplicate(true),
		"tempo_events": tempo_events.duplicate(true),
		"time_signatures": time_signatures.duplicate(true),
		"divisions_events": divisions_events.duplicate(true),
	}
