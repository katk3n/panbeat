extends SceneTree

const InputTechnique := preload("res://domain/input_technique.gd")
const Profile := preload("res://infrastructure/profile_contract.gd")
const Transport := preload("res://domain/game_transport.gd")
const MidiAdapter := preload("res://infrastructure/godot_midi_adapter.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const Kinematics := preload("res://domain/note_visual_kinematics.gd")
const Pool := preload("res://domain/fixed_object_pool.gd")
const ChartLoader := preload("res://infrastructure/phase0_chart_loader.gd")
const Judgement := preload("res://domain/judgement_engine.gd")

class FakeClock extends RefCounted:
	var now: float = 0.0
	func time_seconds() -> float:
		return now

func _initialize() -> void:
	var failures: Array[String] = []
	_check(InputTechnique.count() == 3, "domain defines Tone/Ding/Slap", failures)
	_check(Profile.SCHEMA_VERSION == "1.0.0", "profile schema version", failures)
	_check(Profile.supported_technique_count() == 3, "infrastructure references domain", failures)
	_check(load("res://presentation/phase0.tscn") != null, "text main scene loads", failures)
	var clock := FakeClock.new()
	clock.now = 10.0
	var transport: RefCounted = Transport.new(clock)
	transport.start(12.0)
	clock.now = 11.0
	_check(transport.song_time_us() == 0, "scheduled lead clamps at zero", failures)
	clock.now = 17.5
	_check(transport.song_time_us() == 5_500_000, "frame stall follows audio clock", failures)
	transport.pause()
	clock.now = 25.0
	_check(transport.song_time_us() == 5_500_000, "pause freezes song time", failures)
	transport.resume()
	clock.now = 26.0
	_check(transport.song_time_us() == 6_500_000, "resume excludes pause duration", failures)
	var note_on := InputEventMIDI.new()
	note_on.message = MIDI_MESSAGE_NOTE_ON
	note_on.channel = 0
	note_on.pitch = 50
	note_on.velocity = 127
	var raw: Dictionary = MidiAdapter.event_to_record(note_on, 123456, 77)
	_check(raw["arrival_timestamp_us"] == 123456 and not raw["os_receive_timestamp_available"], "arrival timestamp is honest", failures)
	var profile_path: String = ProjectSettings.globalize_path("res://../../shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json")
	var profile: Dictionary = Normalizer.load_profile(profile_path)
	var normalized: Dictionary = Normalizer.normalize(raw, profile)
	_check(normalized.get("technique") == "ding", "Handpan Pad 1 normalizes", failures)
	note_on.velocity = 0
	_check(MidiAdapter.event_to_record(note_on, 1, 1)["message_type"] == "note_off", "velocity-zero Note On normalizes to Note Off", failures)
	var cc := InputEventMIDI.new()
	cc.message = MIDI_MESSAGE_CONTROL_CHANGE
	cc.controller_number = 81
	cc.controller_value = 64
	_check(MidiAdapter.event_to_record(cc, 1, 1)["data1"] == 81, "CC fields preserved", failures)
	var pressure := InputEventMIDI.new()
	pressure.message = MIDI_MESSAGE_AFTERTOUCH
	pressure.pitch = 50
	pressure.pressure = 99
	_check(MidiAdapter.event_to_record(pressure, 1, 1)["data2"] == 99, "poly pressure preserved", failures)
	_check(Normalizer.normalize(MidiAdapter.event_to_record(cc, 1, 1), profile)["kind"] == "diagnostic", "non-trigger remains diagnostic", failures)
	var pose: Vector3 = Kinematics.evaluate(InputTechnique.Value.TONE, 67.5, 0, 2_000_000, 1_234_567)
	for refresh_rate: int in [60, 120, 144]:
		var frame_index: float = 1.234567 * refresh_rate
		_check(frame_index > 0.0 and Kinematics.evaluate(InputTechnique.Value.TONE, 67.5, 0, 2_000_000, 1_234_567).is_equal_approx(pose), "position independent at %d Hz" % refresh_rate, failures)
	var pool: RefCounted = Pool.new(2)
	var first: RefCounted = pool.rent()
	var second: RefCounted = pool.rent()
	_check(pool.rent() == null and pool.overflow_count == 1, "pool overflow observable", failures)
	pool.give_back(first)
	pool.give_back(second)
	_check(pool.available() == 2, "pool reuses objects", failures)
	for index: int in 10_000:
		var pooled: RefCounted = pool.rent()
		pool.give_back(pooled)
	_check(pool.created_count == 2, "pool steady loop creates no new objects", failures)
	var chart_path: String = ProjectSettings.globalize_path("res://../../shared/fixtures/test-pack/chart.json")
	var chart: Dictionary = ChartLoader.load_chart(chart_path)
	_check(chart.get("duration_us") == 30_000_000 and chart.get("notes", []).size() == 13, "shared 30-second chart loads", failures)
	var golden_inputs: Dictionary = ChartLoader.load_chart(ProjectSettings.globalize_path("res://../../shared/fixtures/test-pack/golden-inputs.json"))
	var golden_results_file := FileAccess.open(ProjectSettings.globalize_path("res://../../shared/fixtures/test-pack/golden-results.json"), FileAccess.READ)
	var golden_results: Array = JSON.parse_string(golden_results_file.get_as_text())
	for index: int in golden_inputs.get("cases", []).size():
		var golden_case: Dictionary = golden_inputs["cases"][index]
		var input_timestamp: Variant = null if golden_case["case_id"] == "no-input-miss" else golden_case.get("input_timestamp_us")
		var outcome: Dictionary = Judgement.judge(golden_case["note_timestamp_us"], input_timestamp)
		_check(outcome["judgement"] == golden_results[index]["judgement"] and outcome.get("input_timestamp_us") == golden_results[index].get("input_timestamp_us") and outcome.get("delta_us") == golden_results[index].get("delta_us"), "golden judgement " + golden_case["case_id"], failures)
	for refresh_rate: int in [60, 120, 0]:
		_check(Judgement.judge(1_000_000, 1_030_000) == {"judgement":"perfect","input_timestamp_us":1_030_000,"delta_us":30_000}, "judgement independent at scenario %d" % refresh_rate, failures)
	var lifecycle_file := FileAccess.open(ProjectSettings.globalize_path("res://../../artifacts/raw/godot-g03/lifecycle-verified.jsonl"), FileAccess.READ)
	var recorded_note_on_count: int = 0
	while lifecycle_file.get_position() < lifecycle_file.get_length():
		var lifecycle_record: Variant = JSON.parse_string(lifecycle_file.get_line())
		if lifecycle_record is Dictionary and lifecycle_record.get("record_type") == "event" and lifecycle_record.get("raw", {}).get("message_type") == "note_on":
			_check(lifecycle_record.get("normalized", {}).get("kind") == "normalized_input", "recorded MIDI normalized", failures)
			recorded_note_on_count += 1
	_check(recorded_note_on_count == 6, "six real Note On events replayed", failures)
	if failures.is_empty():
		print("PANBEAT_GODOT_TESTS_OK 45/45")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
