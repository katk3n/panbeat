extends SceneTree

const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const InputQueue := preload("res://application/normalized_input_queue.gd")
const RecordedReplay := preload("res://infrastructure/recorded_midi_replay.gd")
const JudgementPipeline := preload("res://application/judgement_pipeline.gd")

class TestChart extends RefCounted:
	var notes: Array[Dictionary]
	func _init(values: Array[Dictionary]) -> void: notes = values
	func note_count() -> int: return notes.size()
	func note_at(index: int) -> Dictionary: return notes[index]

func _initialize() -> void:
	var failures: Array[String] = []
	var profile: Dictionary = Normalizer.load_profile(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))
	var replay_text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/fixtures/normalized-replay.json"))
	var replay: Array = JSON.parse_string(replay_text) as Array
	var queue := InputQueue.new()
	var techniques: Array[String] = []
	for raw_value: Variant in replay:
		var normalized: Dictionary = Normalizer.normalize(raw_value as Dictionary, profile)
		if queue.submit(normalized):
			techniques.append(normalized["technique"] as String)
	_check(techniques == ["tone", "ding", "slap"], "deterministic three-technique replay", failures)
	_check(queue.size() == 3, "replay uses normalized input queue", failures)
	var trace_paths: Array[String] = [
		"res://../artifacts/raw/m02-mood-pan-20260810/handpan-minor-pads1-9-medium.jsonl",
		"res://../artifacts/raw/m02-mood-pan-20260810/handpan-minor-slap-left3-then-right3.jsonl",
	]
	var real_techniques: Dictionary = {}
	for trace_path: String in trace_paths:
		var loaded: Dictionary = RecordedReplay.load_jsonl(ProjectSettings.globalize_path(trace_path))
		_check(loaded.get("ok") == true, "canonical replay fixture loads: %s" % trace_path, failures)
		if loaded.get("ok") == true:
			for normalized: Dictionary in RecordedReplay.normalize_events(loaded["events"], profile):
				real_techniques[normalized["technique"]] = true
				_check(normalized.get("source_kind") == "recorded_replay", "recorded source contract", failures)
	_check(real_techniques.size() == 3 and real_techniques.has("tone") and real_techniques.has("ding") and real_techniques.has("slap"), "canonical real trace maps Tone Ding Slap", failures)
	_check(RecordedReplay.load_jsonl("/missing/trace.jsonl").get("ok") == false, "missing replay diagnostic", failures)
	var golden_inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../shared/fixtures/test-pack/golden-inputs.json"))) as Dictionary
	var golden_results: Array = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../shared/fixtures/test-pack/golden-results.json"))) as Array
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/judgement-rules-v1.json"))) as Dictionary
	var expected_grades: Array[String] = []
	for value: Variant in golden_results:
		expected_grades.append((value as Dictionary)["judgement"])
	var results_by_hz: Array[String] = []
	for hz: int in [60, 120, 144]:
		var actual_grades: Array[String] = []
		for value: Variant in golden_inputs["cases"]:
			var test_case: Dictionary = value as Dictionary
			var note: Dictionary = {"note_id":test_case["case_id"], "timestamp_us":test_case["note_timestamp_us"], "technique":test_case["technique"], "target_id":test_case["target_id"]}
			var pipeline := JudgementPipeline.new(TestChart.new([note]), rules)
			if test_case.has("input_timestamp_us"):
				pipeline.process_input({"kind":"normalized_input", "input_event_id":"%s:input" % test_case["case_id"], "technique":test_case["technique"], "target_id":test_case["target_id"]}, int(test_case["input_timestamp_us"]))
			var now_us: int = 0
			var step_us: int = roundi(1_000_000.0 / hz)
			while now_us <= 1_100_000:
				pipeline.sweep_misses(now_us)
				now_us += step_us
			pipeline.sweep_misses(1_100_001)
			var note_grade: String = ""
			for record: Dictionary in pipeline.records():
				if record["note_id"] == test_case["case_id"] and record["outcome"] != "extra":
					note_grade = record["grade"]
			actual_grades.append(note_grade)
		results_by_hz.append(JSON.stringify(actual_grades))
	_check(JSON.parse_string(results_by_hz[0]) == expected_grades, "unchanged Phase 0 golden grades", failures)
	_check(results_by_hz[0] == results_by_hz[1] and results_by_hz[1] == results_by_hz[2], "60 120 144 Hz replay results are identical", failures)
	_finish(failures, 7)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty():
		print("PANBEAT_REPLAY_TESTS_OK %d/%d" % [count, count])
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
