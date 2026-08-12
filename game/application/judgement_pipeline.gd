class_name JudgementPipeline
extends RefCounted

const TimingOffsets := preload("res://domain/timing_offsets.gd")

var _notes: Array[Dictionary] = []
var _rules: Dictionary
var _consumed: Dictionary = {}
var _missed: Dictionary = {}
var _records: Array[Dictionary] = []
var _record_sequence: int = 0
var _offsets: Dictionary

func _init(chart: RefCounted, rules: Dictionary, offsets: Dictionary = {}) -> void:
	_rules = rules.duplicate(true)
	_offsets = {"input_offset_us":int(offsets.get("input_offset_us", 0)), "audio_offset_us":int(offsets.get("audio_offset_us", 0))}
	_validate_rules()
	for index: int in chart.note_count():
		_notes.append(chart.note_at(index))

func process_input(input: Dictionary, actual_transport_us: int) -> Dictionary:
	assert(input.get("kind") == "normalized_input")
	var candidate: Dictionary = _best_candidate(input, actual_transport_us, true)
	if not candidate.is_empty():
		_consumed[candidate["note_id"]] = true
		var delta_us: int = _delta_us(candidate, actual_transport_us)
		var record: Dictionary = _record_for_match(candidate, input, actual_transport_us, delta_us, _grade(absi(delta_us)))
		_records.append(record)
		return record.duplicate(true)
	var nearest: Dictionary = _best_candidate(input, actual_transport_us, false)
	var reason: String = "no_candidate"
	if not nearest.is_empty():
		if nearest["technique"] != input.get("technique"):
			reason = "wrong_technique"
		elif nearest["target_id"] != input.get("target_id"):
			reason = "wrong_target"
	var extra: Dictionary = _record_for_extra(nearest, input, actual_transport_us, reason)
	_records.append(extra)
	return extra.duplicate(true)

func sweep_misses(current_time_us: int) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	for note: Dictionary in _notes:
		var note_id: String = note["note_id"]
		if _consumed.has(note_id) or _missed.has(note_id):
			continue
		if current_time_us > int(note["timestamp_us"]) + int(_offsets["audio_offset_us"]) + int(_rules["miss_window_us"]):
			_missed[note_id] = true
			var record: Dictionary = _record_for_miss(note)
			_records.append(record)
			emitted.append(record.duplicate(true))
	return emitted

func records() -> Array[Dictionary]:
	return _records.duplicate(true)

func is_resolved(note_id: String) -> bool:
	return _consumed.has(note_id) or _missed.has(note_id)

func _best_candidate(input: Dictionary, actual_us: int, require_identity: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_abs_delta: int = int(_rules["good_max_abs_delta_us"]) + 1
	for note: Dictionary in _notes:
		var note_id: String = note["note_id"]
		if _consumed.has(note_id) or _missed.has(note_id):
			continue
		var absolute_delta: int = absi(_delta_us(note, actual_us))
		if absolute_delta > int(_rules["good_max_abs_delta_us"]):
			continue
		if require_identity and (note["technique"] != input.get("technique") or note["target_id"] != input.get("target_id")):
			continue
		if best.is_empty() or absolute_delta < best_abs_delta or (absolute_delta == best_abs_delta and _comes_before(note, best)):
			best = note
			best_abs_delta = absolute_delta
	return best

func _comes_before(left: Dictionary, right: Dictionary) -> bool:
	var left_time: int = int(left["timestamp_us"])
	var right_time: int = int(right["timestamp_us"])
	return left_time < right_time or (left_time == right_time and String(left["note_id"]) < String(right["note_id"]))

func _grade(absolute_delta_us: int) -> String:
	if absolute_delta_us <= int(_rules["perfect_max_abs_delta_us"]):
		return "perfect"
	if absolute_delta_us <= int(_rules["great_max_abs_delta_us"]):
		return "great"
	return "good"

func _delta_us(note: Dictionary, actual_us: int) -> int:
	return TimingOffsets.adjusted_delta_us(int(note["timestamp_us"]), actual_us, _offsets)

func _record_for_match(note: Dictionary, input: Dictionary, actual_us: int, delta_us: int, grade: String) -> Dictionary:
	return _base_record(note, input, actual_us).merged({"delta_us":delta_us, "grade":grade, "outcome":"judged"})

func _record_for_extra(note: Dictionary, input: Dictionary, actual_us: int, reason: String) -> Dictionary:
	var record: Dictionary = _base_record(note, input, actual_us)
	record.merge({"delta_us":_delta_us(note, actual_us) if not note.is_empty() else null, "grade":"extra_hit", "outcome":"extra", "reason":reason})
	return record

func _record_for_miss(note: Dictionary) -> Dictionary:
	return _base_record(note, {}, -1).merged({"delta_us":null, "grade":"miss", "outcome":"miss"})

func _base_record(note: Dictionary, input: Dictionary, actual_us: int) -> Dictionary:
	_record_sequence += 1
	return {
		"schema_version":"1.0.0", "rule_id":_rules["rule_id"], "record_id":"judgement-%06d" % _record_sequence,
		"note_id":note.get("note_id"), "input_event_id":input.get("input_event_id", input.get("event_id")),
		"expected_timestamp_us":note.get("timestamp_us"), "actual_timestamp_us":actual_us if actual_us >= 0 else null,
		"clock_domain":"song_time", "expected_technique":note.get("technique"), "actual_technique":input.get("technique"),
		"expected_target_id":note.get("target_id"), "actual_target_id":input.get("target_id")
		,"input_offset_us":_offsets["input_offset_us"], "audio_offset_us":_offsets["audio_offset_us"]
	}

func _validate_rules() -> void:
	assert(_rules.get("schema_version") == "1.0.0")
	assert(_rules.get("clock_domain") == "song_time")
	assert(int(_rules["perfect_max_abs_delta_us"]) <= int(_rules["great_max_abs_delta_us"]))
	assert(int(_rules["great_max_abs_delta_us"]) <= int(_rules["good_max_abs_delta_us"]))
	assert(int(_rules["miss_window_us"]) == int(_rules["good_max_abs_delta_us"]))
