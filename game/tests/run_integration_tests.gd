extends SceneTree

const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const AudioBackend := preload("res://infrastructure/godot_audio_backend.gd")
const AudioTransport := preload("res://application/audio_transport_service.gd")
const Session := preload("res://application/game_session.gd")
const Scheduler := preload("res://application/gameplay_note_scheduler.gd")
const JudgementPipeline := preload("res://application/judgement_pipeline.gd")
const ReplaySession := preload("res://application/deterministic_replay_session.gd")

class TestChart extends RefCounted:
	var notes: Array[Dictionary]
	func _init(values: Array[Dictionary]) -> void: notes = values
	func note_count() -> int: return notes.size()
	func note_at(index: int) -> Dictionary: return notes[index]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	var profile_path: String = ProjectSettings.globalize_path("res://config/default-instrument-profile.json")
	var profile: Dictionary = Normalizer.load_profile(profile_path)
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/judgement-rules-v1.json"))) as Dictionary
	var score_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/score-rules-v1.json"))) as Dictionary
	var gameplay_settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/gameplay-settings-v1.json"))) as Dictionary
	_check(profile.get("profile_id") == "roland-mn10-handpan-minor-v1", "product profile", failures)
	_check(rules.get("rule_id") == "panbeat-phase1-standard-v1" and rules.get("delta_sign_convention", "").begins_with("actual_minus_expected"), "versioned judgement rule and delta convention", failures)
	_check(score_rules.get("rule_id") == "panbeat-phase1-score-v1" and gameplay_settings.get("settings_id") == "panbeat-phase1-local-v1", "versioned score and local offset settings", failures)
	var chart_path: String = ProjectSettings.globalize_path("res://tests/fixtures/minimal-chart.json")
	var loaded: Dictionary = ChartSource.load_chart(chart_path)
	_check(loaded.get("ok") == true and loaded["chart"].get("duration_us") == 2_000_000, "JSON chart source", failures)
	_check(ChartSource.load_chart(chart_path + ".missing").get("ok") == false, "missing chart diagnostic", failures)
	_check(ChartSource.parse_chart("not-json").get("ok") == false, "invalid JSON diagnostic", failures)
	_check(load("res://presentation/main.tscn") != null, "main scene", failures)
	var package_path: String = ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/package.json")
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(package_path)) as Dictionary
	_check(package.get("chart_file") == "chart.json" and package.get("audio_file") == "orbit-practice.wav" and package.get("expected_summary_file") == "expected-summary.json", "fixed song relative paths", failures)
	var audio: AudioStream = load("res://content/phase1-fixed-song-v1/orbit-practice.wav") as AudioStream
	_check(audio != null, "fixed song WAV decodes", failures)
	_check(audio != null and absf(audio.get_length() - 36.0) < 0.001, "fixed song WAV duration", failures)
	var product_chart_result: Dictionary = ChartSource.load_chart(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/chart.json"))
	var runtime_result: Dictionary = ChartFactory.build(product_chart_result["chart"], profile, 36_000_000)
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/expected-events.json"))) as Dictionary
	var expected_notes: Array[Dictionary] = []
	for input: Dictionary in expected["inputs"]:
		expected_notes.append({"note_id": (input["event_id"] as String).trim_suffix(":input"), "timestamp_us": int(input["timestamp_us"]), "technique": input["technique"], "target_id": input["target_id"]})
	var runtime_notes_json: String = JSON.stringify(runtime_result["chart"].to_dictionary()["notes"]) if runtime_result.get("ok") == true else JSON.stringify(runtime_result)
	var expected_notes_json: String = JSON.stringify(expected_notes)
	_check(runtime_result.get("ok") == true and runtime_notes_json == expected_notes_json, "golden product Runtime Chart", failures)
	var expected_summary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/expected-summary.json"))) as Dictionary
	var replay_run: Dictionary = ReplaySession.run(runtime_result["chart"], expected["inputs"], rules, score_rules)
	var replay_summary: Dictionary = replay_run["summary"]
	_check(replay_run["records"].size() == runtime_result["chart"].note_count(), "vertical slice replay resolves every chart note once", failures)
	var summary_counts_match: bool = true
	for grade: String in ["perfect", "great", "good", "miss", "extra_hit"]:
		summary_counts_match = summary_counts_match and int(replay_summary["breakdown"][grade]) == int(expected_summary["breakdown"][grade])
	_check(int(replay_summary["score"]) == int(expected_summary["score"]) and is_equal_approx(float(replay_summary["accuracy"]), float(expected_summary["accuracy"])) and int(replay_summary["max_combo"]) == int(expected_summary["max_combo"]) and summary_counts_match, "P103 replay final summary matches golden", failures)
	var angles: Dictionary = {}
	for tone_value: Variant in profile["layout"]["tones"]:
		var tone: Dictionary = tone_value as Dictionary
		angles[tone["target_id"]] = tone["angle_degrees"]
	_check(angles.get("tone-8") == 337.5 and angles.get("tone-7") == 22.5, "acoustic layout upper-left 8 upper-right 7", failures)
	_check(angles.get("tone-1") == 157.5 and angles.get("tone-2") == 202.5, "outer fields start at one on player side", failures)
	var full_scheduler := Scheduler.new(runtime_result["chart"], profile, 64)
	for song_time_us: int in range(-2_000_000, 36_000_001, 16_667):
		full_scheduler.update(song_time_us)
	full_scheduler.update(36_000_000)
	_check(full_scheduler.overflow_count == 0 and full_scheduler.activated_count == 45, "P103 chart does not exhaust fixed note pool", failures)
	var snapshots: Array[String] = []
	for hz: int in [60, 120, 144]:
		var scheduler := Scheduler.new(runtime_result["chart"], profile, 64)
		var now_us: int = -2_000_000
		var step_us: int = roundi(1_000_000.0 / hz)
		while now_us < 10_000_000:
			scheduler.update(now_us)
			now_us = mini(now_us + step_us, 10_000_000)
		scheduler.update(10_000_000)
		snapshots.append(_scheduler_snapshot(scheduler, 10_000_000))
	_check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "scheduler positions are frame-sequence independent", failures)
	var overflow_scheduler := Scheduler.new(runtime_result["chart"], profile, 1)
	overflow_scheduler.update(10_000_000)
	_check(overflow_scheduler.overflow_count > 0, "pool overflow is measured", failures)
	var two_notes: Array[Dictionary] = [
		{"note_id":"earlier", "timestamp_us":950_000, "technique":"tone", "target_id":"tone-1"},
		{"note_id":"later", "timestamp_us":1_050_000, "technique":"tone", "target_id":"tone-1"}
	]
	var closest_pipeline := JudgementPipeline.new(TestChart.new(two_notes), rules)
	var closest: Dictionary = closest_pipeline.process_input(_input("input-tie", "tone", "tone-1"), 1_000_000)
	_check(closest["note_id"] == "earlier" and closest["delta_us"] == 50_000 and closest["grade"] == "great", "minimum absolute delta with deterministic tie break", failures)
	var target_pipeline := JudgementPipeline.new(TestChart.new([two_notes[0]]), rules)
	var wrong_target: Dictionary = target_pipeline.process_input(_input("wrong-target", "tone", "tone-2"), 950_000)
	_check(wrong_target["outcome"] == "extra" and wrong_target["reason"] == "wrong_target" and not target_pipeline.is_resolved("earlier"), "wrong target does not consume note", failures)
	var target_misses: Array[Dictionary] = target_pipeline.sweep_misses(1_050_001)
	_check(target_misses.size() == 1 and target_pipeline.sweep_misses(2_000_000).is_empty(), "strict miss boundary emits once", failures)
	var technique_pipeline := JudgementPipeline.new(TestChart.new([two_notes[0]]), rules)
	var wrong_technique: Dictionary = technique_pipeline.process_input(_input("wrong-technique", "ding", "tone-1"), 950_000)
	_check(wrong_technique["reason"] == "wrong_technique" and not technique_pipeline.is_resolved("earlier"), "wrong technique does not consume note", failures)
	var outside_pipeline := JudgementPipeline.new(TestChart.new([two_notes[0]]), rules)
	var outside: Dictionary = outside_pipeline.process_input(_input("outside", "tone", "tone-1"), 1_050_001)
	_check(outside["grade"] == "extra_hit" and outside["reason"] == "no_candidate", "outside window is Extra Hit", failures)
	var stall_pipeline := JudgementPipeline.new(TestChart.new(two_notes), rules)
	_check(stall_pipeline.sweep_misses(2_000_000).size() == 2 and stall_pipeline.sweep_misses(3_000_000).is_empty(), "frame stall miss sweep is complete and idempotent", failures)
	_check(closest.has("expected_timestamp_us") and closest.has("actual_timestamp_us") and closest.has("expected_target_id") and closest.has("actual_target_id") and closest.has("expected_technique") and closest.has("actual_technique"), "judgement record preserves expected and actual fields", failures)
	var offset_note: Dictionary = {"note_id":"offset-note", "timestamp_us":1_000_000, "technique":"tone", "target_id":"tone-1"}
	var no_offset_pipeline := JudgementPipeline.new(TestChart.new([offset_note]), rules)
	_check(no_offset_pipeline.process_input(_input("zero-offset", "tone", "tone-1"), 1_100_000)["grade"] == "good", "zero offset boundary", failures)
	var input_offset_pipeline := JudgementPipeline.new(TestChart.new([offset_note]), rules, {"input_offset_us":1, "audio_offset_us":0})
	var crossed: Dictionary = input_offset_pipeline.process_input(_input("input-offset", "tone", "tone-1"), 1_100_000)
	_check(crossed["grade"] == "extra_hit" and crossed["delta_us"] == null, "positive input offset crosses outside boundary", failures)
	var negative_input_pipeline := JudgementPipeline.new(TestChart.new([offset_note]), rules, {"input_offset_us":-70_000, "audio_offset_us":0})
	_check(negative_input_pipeline.process_input(_input("negative-input", "tone", "tone-1"), 1_100_000)["delta_us"] == 30_000, "negative input offset applied once", failures)
	var audio_offset_pipeline := JudgementPipeline.new(TestChart.new([offset_note]), rules, {"input_offset_us":0, "audio_offset_us":70_000})
	var audio_adjusted: Dictionary = audio_offset_pipeline.process_input(_input("audio-offset", "tone", "tone-1"), 1_100_000)
	_check(audio_adjusted["grade"] == "perfect" and audio_adjusted["delta_us"] == 30_000, "positive audio offset delays judged note once", failures)
	var delayed_miss_pipeline := JudgementPipeline.new(TestChart.new([offset_note]), rules, {"audio_offset_us":70_000})
	_check(delayed_miss_pipeline.sweep_misses(1_100_001).is_empty() and delayed_miss_pipeline.sweep_misses(1_170_001).size() == 1, "audio offset delays miss boundary", failures)
	var empty_chart: Dictionary = product_chart_result["chart"].duplicate(true)
	empty_chart["notes"] = []
	_check(ChartFactory.build(empty_chart, profile, 36_000_000).get("ok") == false, "empty chart diagnostic", failures)
	var future_chart: Dictionary = product_chart_result["chart"].duplicate(true)
	future_chart["schema_version"] = "2.0.0"
	_check(ChartFactory.build(future_chart, profile, 36_000_000).get("ok") == false, "unknown major diagnostic", failures)
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	await process_frame
	player.stream = audio
	var session := Session.new()
	session.transition(Session.READY)
	var godot_transport := AudioTransport.new(AudioBackend.new(player), 36_000_000, session)
	_check(godot_transport.schedule_start(0.0).get("ok") == true and godot_transport.update().get("ok") == true, "product WAV starts through transport", failures)
	_check(godot_transport.state() == AudioTransport.PLAYING and godot_transport.accepts_input(), "transport enters playing", failures)
	_check(godot_transport.pause().get("ok") == true and godot_transport.resume().get("ok") == true, "transport pause and resume", failures)
	await process_frame
	player.stop()
	player.stream = null
	player.free()
	player = null
	godot_transport = null
	audio = null
	for _frame: int in 3:
		await process_frame
	_finish(failures, 35)

func _scheduler_snapshot(scheduler: RefCounted, song_time_us: int) -> String:
	var snapshot: Array[Dictionary] = []
	for slot: Dictionary in scheduler.active_slots():
		if slot["active"]:
			var visual: Vector3 = scheduler.visual_state(slot, song_time_us)
			snapshot.append({"note_id":slot["note"]["note_id"], "radius":visual.x, "angle":visual.y, "progress":visual.z})
	return JSON.stringify(snapshot)

func _input(event_id: String, technique: String, target_id: String) -> Dictionary:
	return {"kind":"normalized_input", "input_event_id":event_id, "technique":technique, "target_id":target_id, "velocity":96}

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty():
		print("PANBEAT_INTEGRATION_TESTS_OK %d/%d" % [count, count])
		_quit_with_code.call_deferred(0)
	else:
		for failure: String in failures:
			push_error(failure)
		_quit_with_code.call_deferred(1)

func _quit_with_code(code: int) -> void:
	quit(code)
