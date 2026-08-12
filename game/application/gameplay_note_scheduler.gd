class_name GameplayNoteScheduler
extends RefCounted

const Kinematics := preload("res://domain/note_visual_kinematics.gd")
const Technique := preload("res://domain/input_technique.gd")

var _notes: Array[Dictionary] = []
var _slots: Array[Dictionary] = []
var _angle_by_target: Dictionary = {}
var _next_note_index: int = 0
var _lookahead_us: int
var _retire_after_us: int
var overflow_count: int = 0
var activated_count: int = 0
var retired_count: int = 0

func _init(chart: RefCounted, profile: Dictionary, capacity: int = 64, lookahead_us: int = 2_000_000, retire_after_us: int = 120_000) -> void:
	assert(capacity > 0 and lookahead_us > 0 and retire_after_us >= 0)
	_lookahead_us = lookahead_us
	_retire_after_us = retire_after_us
	for index: int in chart.note_count():
		_notes.append(chart.note_at(index))
	for tone_value: Variant in profile.get("layout", {}).get("tones", []):
		var tone: Dictionary = tone_value as Dictionary
		_angle_by_target[tone["target_id"]] = float(tone["angle_degrees"])
	for _index: int in capacity:
		_slots.append({"active":false, "note":{}, "angle_degrees":0.0, "feedback":"", "feedback_expires_us":0})

func update(song_time_us: int) -> void:
	for slot: Dictionary in _slots:
		if slot["active"] and song_time_us > int((slot["note"] as Dictionary)["timestamp_us"]) + _retire_after_us:
			slot["active"] = false
			slot["feedback"] = ""
			retired_count += 1
	while _next_note_index < _notes.size() and int(_notes[_next_note_index]["timestamp_us"]) <= song_time_us + _lookahead_us:
		var note: Dictionary = _notes[_next_note_index]
		var rented: Variant = _rent_slot()
		if rented == null:
			overflow_count += 1
		else:
			var slot: Dictionary = rented as Dictionary
			slot["active"] = true
			slot["note"] = note
			slot["angle_degrees"] = float(_angle_by_target.get(note["target_id"], 0.0))
			slot["feedback"] = ""
			activated_count += 1
		_next_note_index += 1

func mark_feedback(note_id: String, grade: String, song_time_us: int, duration_us: int = 180_000) -> bool:
	for slot: Dictionary in _slots:
		if slot["active"] and (slot["note"] as Dictionary).get("note_id") == note_id:
			slot["feedback"] = grade
			slot["feedback_expires_us"] = song_time_us + duration_us
			return true
	return false

func active_slots() -> Array[Dictionary]:
	return _slots

func active_count() -> int:
	var count: int = 0
	for slot: Dictionary in _slots:
		if slot["active"]:
			count += 1
	return count

func visual_state(slot: Dictionary, song_time_us: int) -> Vector3:
	var note: Dictionary = slot["note"]
	var technique: int = _technique_value(note["technique"])
	var hit_us: int = int(note["timestamp_us"])
	return Kinematics.evaluate(technique, float(slot["angle_degrees"]), hit_us - _lookahead_us, hit_us, song_time_us)

func _rent_slot() -> Variant:
	for slot: Dictionary in _slots:
		if not slot["active"]:
			return slot
	return null

func _technique_value(value: String) -> int:
	match value:
		"ding": return Technique.Value.DING
		"slap": return Technique.Value.SLAP
		_: return Technique.Value.TONE
