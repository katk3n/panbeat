class_name TimedScoreChart
extends RefCounted

var chart_id: String
var importer_version: String
var ticks_per_quarter: int
var duration_ticks: int
var duration_us: int
var tempo_map: Array[Dictionary]
var time_signature_map: Array[Dictionary]
var notes: Array[Dictionary]

func _init(id_value: String, importer_value: String, ticks_value: int, duration_ticks_value: int, duration_us_value: int, tempo_values: Array[Dictionary], time_values: Array[Dictionary], note_values: Array[Dictionary]) -> void:
	chart_id = id_value
	importer_version = importer_value
	ticks_per_quarter = ticks_value
	duration_ticks = duration_ticks_value
	duration_us = duration_us_value
	tempo_map = tempo_values.duplicate(true)
	time_signature_map = time_values.duplicate(true)
	notes = note_values.duplicate(true)

func to_dictionary() -> Dictionary:
	return {"schema_version":"1.0.0", "importer_version":importer_version, "chart_id":chart_id, "ticks_per_quarter":ticks_per_quarter, "duration_ticks":duration_ticks, "duration_us":duration_us, "tempo_map":tempo_map.duplicate(true), "time_signature_map":time_signature_map.duplicate(true), "notes":notes.duplicate(true)}
