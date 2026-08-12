extends SceneTree

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Score := preload("res://domain/symbolic_score.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var parsed := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/musescore-minimal.musicxml"))
	var compiled := Compiler.compile(parsed.get("score"), "p204-golden") if parsed.get("ok") else parsed
	_check(compiled.get("ok") == true, "golden score compiles: %s" % [compiled.get("diagnostics", [])], failures)
	if compiled.get("ok") == true:
		var chart: RefCounted = compiled["chart"]
		_check(chart.tempo_map.size() == 2 and chart.tempo_map[0]["bpm_milli"] == 120000 and chart.tempo_map[1]["tick"] == 8 and chart.tempo_map[1]["start_us"] == 1000000, "tempo segments anchored before conversion", failures)
		_check(chart.notes.size() == 1 and chart.notes[0]["tick"] == 0 and chart.notes[0]["duration_ticks"] == 12 and chart.notes[0]["duration_us"] == 1666667, "measure-spanning tie normalized to one sustain", failures)
		_check(chart.duration_ticks == 16 and chart.duration_us == 2333333, "rest and tempo change determine chart duration", failures)
		_check(chart.notes[0]["source"]["part"] == "P1" and chart.notes[0]["source"]["measure"] == "1" and chart.notes[0]["source"]["tick"] == 0 and chart.notes[0]["source"]["voice"] == "1", "runtime note preserves source coordinates", failures)
		_check(chart.notes[0]["note_id"] == "P1:m1:t0:v1:D4:0", "stable note ID", failures)
		var compiled_again := Compiler.compile(parsed["score"], "p204-golden")
		_check(compiled["canonical_json"] == compiled_again["canonical_json"], "same input produces byte-identical canonical chart", failures)
		var golden_path := ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p204-golden-chart.json")
		var golden := FileAccess.get_file_as_string(golden_path)
		if golden.is_empty(): print("P204_CANONICAL_OUTPUT_BEGIN\n%sP204_CANONICAL_OUTPUT_END" % compiled["canonical_json"])
		_check(not golden.is_empty() and compiled["canonical_json"] == golden, "canonical chart matches golden bytes", failures)
	var boundary_score := _score([{ "tick":0, "bpm":120.0 }, { "tick":4, "bpm":60.0 }], [_note(4, 4)])
	var boundary := Compiler.compile(boundary_score, "boundary")
	_check(boundary.get("ok") and boundary["chart"].notes[0]["timestamp_us"] == 500000 and boundary["chart"].notes[0]["duration_us"] == 1000000, "tempo boundary conversion", failures)
	var chord_parsed := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/chord.musicxml"))
	var chord_compiled := Compiler.compile(chord_parsed.get("score"), "chord") if chord_parsed.get("ok") else chord_parsed
	_check(chord_compiled.get("ok") and chord_compiled["chart"].notes.size() == 3 and chord_compiled["chart"].notes[0]["timestamp_us"] == 0 and chord_compiled["chart"].notes[1]["timestamp_us"] == 0 and chord_compiled["chart"].notes[2]["timestamp_us"] == 500_000, "chord compiles as independently identified simultaneous runtime notes", failures)
	var long_score := _score([{ "tick":0, "bpm":123.456 }], [_note(1_000_000_000, 4)])
	var long_run_a := Compiler.compile(long_score, "long")
	var long_run_b := Compiler.compile(long_score, "long")
	_check(long_run_a.get("ok") and long_run_a["canonical_json"] == long_run_b["canonical_json"] and long_run_a["chart"].notes[0]["timestamp_us"] > 0, "long chart uses deterministic integer conversion", failures)
	var stop_only := _score([], [_note(0, 4, ["stop"])])
	_check(_code(Compiler.compile(stop_only, "stop")) == "tie_stop_without_start", "tie stop without start rejected", failures)
	var start_only := _score([], [_note(0, 4, ["start"])])
	_check(_code(Compiler.compile(start_only, "start")) == "unclosed_tie", "unclosed tie rejected", failures)
	var gap := _score([], [_note(0, 4, ["start"]), _note(8, 4, ["stop"])])
	_check(_code(Compiler.compile(gap, "gap")) == "tie_gap_or_overlap", "tie gap rejected", failures)
	var conflicting := _score([{ "tick":0, "bpm":120.0 }, { "tick":0, "bpm":90.0 }], [_note(0, 4)])
	_check(_code(Compiler.compile(conflicting, "tempo")) == "conflicting_tempo", "conflicting tempo rejected", failures)
	_finish(failures, 15)

func _score(tempos: Array[Dictionary], notes: Array[Dictionary]) -> RefCounted:
	var tempo_events: Array[Dictionary] = []
	for tempo: Dictionary in tempos: tempo_events.append({"tick":tempo["tick"], "bpm":tempo["bpm"], "source":"test", "part":"P1", "measure":"1", "line":1})
	return Score.new("test", "4.0", "P1", 4, [{"number":"1", "start_tick":0}], notes, tempo_events, [{"tick":0,"beats":4,"beat_type":4,"part":"P1","measure":"1","line":1}], [{"tick":0,"divisions":4}])

func _note(tick: int, duration: int, ties: Array = []) -> Dictionary:
	return {"part":"P1", "measure":"1", "measure_index":0, "tick":tick, "duration_ticks":duration, "line":1, "is_rest":false, "tie_types":ties, "voice":"1", "step":"D", "octave":4, "divisions":4}

func _code(result: Dictionary) -> String:
	return str(result.get("diagnostics", [{}])[0].get("code", ""))

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P204_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
