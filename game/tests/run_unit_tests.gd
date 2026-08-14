extends SceneTree

const InputTechnique := preload("res://domain/input_technique.gd")
const Judgement := preload("res://domain/judgement_engine.gd")
const ObjectPool := preload("res://domain/fixed_object_pool.gd")
const Kinematics := preload("res://domain/note_visual_kinematics.gd")
const AudioTransport := preload("res://application/audio_transport_service.gd")
const AudioBackend := preload("res://infrastructure/godot_audio_backend.gd")
const PitchPreserver := preload("res://infrastructure/practice_pitch_preserver.gd")
const SilentClockBackend := preload("res://infrastructure/silent_clock_backend.gd")
const InputQueue := preload("res://application/normalized_input_queue.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const JudgementPipeline := preload("res://application/judgement_pipeline.gd")
const Session := preload("res://application/game_session.gd")
const MidiPorts := preload("res://application/midi_port_service.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const RadialView := preload("res://presentation/radial_view.gd")
const TimingOffsets := preload("res://domain/timing_offsets.gd")
const ScoreEngine := preload("res://domain/score_engine.gd")
const InputMode := preload("res://application/input_mode_selection.gd")

class FakeAudioBackend extends RefCounted:
	var monotonic: float = 0.0
	var audio_position: float = 0.0
	var available: bool = true
	var playing: bool = false
	var paused: bool = false
	func ready() -> bool: return available
	func monotonic_seconds() -> float: return monotonic
	func audio_position_seconds() -> float: return audio_position
	func play() -> bool: playing = available; return playing
	func is_playing() -> bool: return playing
	func set_paused(value: bool) -> void: paused = value
	func sample_rate_hz() -> int: return 48000
	func output_latency_seconds() -> float: return 0.01
	func buffer_frames_estimate() -> int: return 480

class FakeClock extends RefCounted:
	var now := 0.0
	func monotonic_seconds() -> float: return now

class FakeMidiPortBackend extends RefCounted:
	var port_values: PackedStringArray = []
	var opened: bool = false
	var open_allowed: bool = true
	var requires_open_for_ports: bool = false
	var now_us: int = 100
	func connected_ports() -> PackedStringArray: return port_values.duplicate() if not requires_open_for_ports or opened else PackedStringArray()
	func open_inputs() -> bool: opened = open_allowed; return opened
	func close_inputs() -> void: opened = false
	func monotonic_us() -> int: now_us += 1; return now_us

func _initialize() -> void:
	var failures: Array[String] = []
	_check(InputTechnique.count() == 3, "three techniques", failures)
	_check(Judgement.judge(1_000_000, 1_000_000)["judgement"] == "perfect", "perfect boundary", failures)
	_check(Judgement.judge(1_000_000, 970_000)["judgement"] == "perfect" and Judgement.judge(1_000_000, 1_030_001)["judgement"] == "great", "perfect inclusive boundary and sign", failures)
	_check(Judgement.judge(1_000_000, 940_000)["judgement"] == "great" and Judgement.judge(1_000_000, 1_060_001)["judgement"] == "good", "great inclusive boundary", failures)
	_check(Judgement.judge(1_000_000, 900_000)["judgement"] == "good" and Judgement.judge(1_000_000, 899_999)["judgement"] == "miss", "good inclusive boundary", failures)
	_check(Judgement.judge(1_000_000, 1_100_001)["judgement"] == "miss", "miss boundary", failures)
	var pool := ObjectPool.new(2)
	_check(pool.available() == 2 and pool.rent() != null, "fixed object pool", failures)
	var visual: Vector3 = Kinematics.evaluate(InputTechnique.Value.DING, 0.0, 0, 1_000_000, 1_000_000)
	_check(is_equal_approx(visual.x, Kinematics.DING_HIT_RADIUS), "ding converges to its central judgement ring", failures)
	var backend := FakeAudioBackend.new()
	backend.monotonic = 10.0
	var transport := AudioTransport.new(backend, 2_000_000)
	_check(transport.schedule_start(0.1).get("ok") == true and transport.now_us() == -100_000, "scheduled negative count-in", failures)
	backend.monotonic = 10.2
	transport.update()
	backend.audio_position = 0.25
	_check(transport.now_us() == 250_000, "audio position clock", failures)
	transport.pause()
	backend.monotonic = 20.0
	backend.audio_position = 1.5
	_check(transport.now_us() == 250_000 and not transport.accepts_input(), "paused transport and input gate", failures)
	transport.resume()
	backend.audio_position = 0.3
	_check(transport.now_us() == 300_000, "resume rebuilds from audio position", failures)
	backend.monotonic = 25.0
	backend.audio_position = 0.4
	_check(transport.now_us() == 400_000, "frame stall does not accumulate delta", failures)
	_check(transport.diagnostics()["sample_rate_hz"] == 48000, "transport diagnostics", failures)
	_check(is_equal_approx(AudioBackend.corrected_audio_position_seconds(2.0, 0.02, 0.01, 0.5), 2.005), "audio clock interpolation converts wall latency into slowed song time", failures)
	var pitch_player := AudioStreamPlayer.new(); var pitch_preserver := PitchPreserver.new(); var original_bus_count := AudioServer.get_bus_count()
	var original_pitch := pitch_preserver.configure(pitch_player, 1.0)
	_check(original_pitch.get("ok") and not original_pitch.get("active") and AudioServer.get_bus_count() == original_bus_count, "original tempo bypasses PitchShift without creating an audio bus", failures)
	var preserved := pitch_preserver.configure(pitch_player, 0.7); var practice_bus_index := AudioServer.get_bus_index(StringName(preserved.get("bus_name", ""))); var pitch_effect: AudioEffect = AudioServer.get_bus_effect(practice_bus_index, 0) if practice_bus_index >= 0 else null
	_check(preserved.get("ok") and preserved.get("active") and AudioServer.get_bus_count() == original_bus_count + 1 and pitch_effect is AudioEffectPitchShift and is_equal_approx((pitch_effect as AudioEffectPitchShift).pitch_scale, 1.0 / 0.7), "slowed audio uses an inverse PitchShift on an isolated practice bus", failures)
	_check(pitch_preserver.estimated_latency_seconds() > 0.0 and is_equal_approx(PitchPreserver.compensation_scale(0.5), 2.0), "pitch preservation exposes FFT latency and deterministic inverse compensation", failures)
	pitch_preserver.release(pitch_player)
	_check(AudioServer.get_bus_count() == original_bus_count and pitch_player.bus == &"Master" and pitch_preserver.estimated_latency_seconds() == 0.0, "practice audio bus is removed after the session", failures)
	pitch_player.free()
	backend.audio_position = 2.0
	backend.playing = false
	transport.update()
	_check(transport.state() == AudioTransport.COMPLETED and transport.now_us() == 2_000_000, "audio completion", failures)
	var missing_backend := FakeAudioBackend.new()
	missing_backend.available = false
	var failed_transport := AudioTransport.new(missing_backend, 1_000_000)
	_check(failed_transport.schedule_start(0.0).get("ok") == false and failed_transport.state() == AudioTransport.FAILED, "audio load failure", failures)
	var clock := FakeClock.new(); clock.now = 5.0
	var silent_transport := AudioTransport.new(SilentClockBackend.new(1_000_000, clock), 1_000_000)
	_check(silent_transport.schedule_start(0.0).get("ok"), "silent clock transport schedules", failures)
	silent_transport.update(); clock.now = 5.4
	_check(silent_transport.now_us() == 400_000, "silent clock transport advances without audio", failures)
	var slow_clock := FakeClock.new(); slow_clock.now = 10.0
	var slow_transport := AudioTransport.new(SilentClockBackend.new(1_000_000, slow_clock, 0.5), 1_000_000)
	slow_transport.schedule_start(0.0); slow_transport.update(); slow_clock.now = 10.4
	_check(slow_transport.now_us() == 200_000, "practice tempo slows the silent transport musical clock", failures)
	silent_transport.pause(); clock.now = 6.0; silent_transport.resume(); clock.now = 6.6; silent_transport.update()
	_check(silent_transport.state() == AudioTransport.COMPLETED and silent_transport.now_us() == 1_000_000, "silent clock transport pauses and completes at score duration", failures)
	var midi_backend := FakeMidiPortBackend.new()
	var midi_ports := MidiPorts.new(midi_backend, "MN-10")
	_check(midi_ports.open()["code"] == "no_ports", "MIDI no-port diagnostic", failures)
	var cold_midi_backend := FakeMidiPortBackend.new()
	cold_midi_backend.port_values = PackedStringArray(["MN-10"])
	cold_midi_backend.requires_open_for_ports = true
	var cold_midi_ports := MidiPorts.new(cold_midi_backend, "MN-10")
	_check(cold_midi_ports.open().get("ok") == true and cold_midi_ports.is_open(), "MIDI backend opens before cold-start enumeration", failures)
	midi_backend.port_values = PackedStringArray(["MN-10"])
	_check(midi_ports.refresh().get("ok") == true and midi_ports.is_open(), "MIDI startup-after-connect reopen", failures)
	_check(midi_ports.close().get("ok") == true and not midi_ports.is_open() and midi_ports.open().get("ok") == true, "MIDI close and reopen", failures)
	midi_backend.open_allowed = false
	midi_ports.close()
	_check(midi_ports.open()["code"] == "open_failed", "MIDI open-failure diagnostic", failures)
	var mini_profile: Dictionary = {"mappings":[{"channel_wire":0,"note":50,"velocity_min":1,"velocity_max":127,"technique":"ding","target_id":"ding"}]}
	var raw_base: Dictionary = {"message_type":"note_on","arrival_timestamp_us":1,"channel_wire":0,"data1":50,"data2":90}
	_check(Normalizer.normalize(raw_base, mini_profile).get("kind") == "normalized_input", "MIDI note-on normalized", failures)
	var zero_velocity: Dictionary = raw_base.duplicate(); zero_velocity["data2"] = 0
	_check(Normalizer.normalize(zero_velocity, mini_profile).get("code") == "note_on_zero_velocity", "MIDI note-on velocity zero", failures)
	var note_off: Dictionary = raw_base.duplicate(); note_off["message_type"] = "note_off"
	_check(Normalizer.normalize(note_off, mini_profile).get("code") == "note_off", "MIDI note-off", failures)
	var cc: Dictionary = raw_base.duplicate(); cc["message_type"] = "control_change"
	_check(Normalizer.normalize(cc, mini_profile).get("code") == "control_change", "MIDI control change", failures)
	var pressure: Dictionary = raw_base.duplicate(); pressure["message_type"] = "poly_pressure"
	_check(Normalizer.normalize(pressure, mini_profile).get("code") == "aftertouch", "MIDI aftertouch", failures)
	var unknown: Dictionary = raw_base.duplicate(); unknown["channel_wire"] = 4
	_check(Normalizer.normalize(unknown, mini_profile).get("code") == "unknown_mapping", "MIDI unknown channel", failures)
	var queue := InputQueue.new()
	_check(not queue.submit({"kind": "diagnostic"}), "input queue rejects diagnostics", failures)
	_check(queue.submit({"kind": "normalized_input", "technique": "ding"}) and queue.drain().size() == 1, "input queue accepts replay or physical input", failures)
	var profile: Dictionary = {"mappings": [{"technique":"ding", "target_id":"ding"}]}
	var chart: Dictionary = {"schema_version":"1.0.0", "chart_id":"unit", "duration_us":2_000_000, "notes":[{"note_id":"one", "timestamp_us":1_000_000, "technique":"ding", "target_id":"ding"}]}
	var built: Dictionary = ChartFactory.build(chart, profile, 2_000_000)
	var chord_chart := {"schema_version":"1.0.0", "chart_id":"unit-chord", "duration_us":2_000_000, "notes":[{"note_id":"chord-ding","timestamp_us":1_000_000,"technique":"ding","target_id":"ding"},{"note_id":"chord-tone","timestamp_us":1_000_000,"technique":"tone","target_id":"tone-1"}]}
	var chord_profile := {"mappings":[{"technique":"ding","target_id":"ding"},{"technique":"tone","target_id":"tone-1"}]}
	var chord_built := ChartFactory.build(chord_chart, chord_profile, 2_000_000)
	var chord_pipeline := JudgementPipeline.new(chord_built["chart"], {"schema_version":"1.0.0","rule_id":"chord-test","clock_domain":"song_time","perfect_max_abs_delta_us":30_000,"great_max_abs_delta_us":60_000,"good_max_abs_delta_us":100_000,"miss_window_us":100_000})
	var chord_ding := chord_pipeline.process_input({"kind":"normalized_input","input_event_id":"ding-hit","technique":"ding","target_id":"ding"}, 1_000_000)
	var chord_tone := chord_pipeline.process_input({"kind":"normalized_input","input_event_id":"tone-hit","technique":"tone","target_id":"tone-1"}, 1_020_000)
	_check(chord_ding["note_id"] == "chord-ding" and chord_tone["note_id"] == "chord-tone" and chord_pipeline.records().size() == 2, "simultaneous chord notes are judged and consumed independently", failures)
	var partial_chord_pipeline := JudgementPipeline.new(chord_built["chart"], {"schema_version":"1.0.0","rule_id":"chord-test","clock_domain":"song_time","perfect_max_abs_delta_us":30_000,"great_max_abs_delta_us":60_000,"good_max_abs_delta_us":100_000,"miss_window_us":100_000})
	partial_chord_pipeline.process_input({"kind":"normalized_input","input_event_id":"partial-hit","technique":"ding","target_id":"ding"}, 1_000_000)
	var partial_misses := partial_chord_pipeline.sweep_misses(1_100_001)
	_check(partial_misses.size() == 1 and partial_misses[0]["note_id"] == "chord-tone" and partial_chord_pipeline.records()[0]["grade"] == "perfect", "one successful chord note does not hide another chord note miss", failures)
	_check(built.get("ok") == true and built["chart"].notes_between(999_999, 1_000_000).size() == 1, "runtime chart binary search", failures)
	var duplicate: Dictionary = chart.duplicate(true)
	duplicate["notes"].append(duplicate["notes"][0].duplicate(true))
	_check(ChartFactory.build(duplicate, profile, 2_000_000).get("ok") == false, "duplicate note rejected", failures)
	var session := Session.new()
	_check(session.transition(Session.READY).get("ok") == true and session.transition(Session.PLAYING).get("ok") == true, "valid session transitions", failures)
	_check(session.transition(Session.READY).get("ok") == false, "invalid session transition rejected", failures)
	_check(Session.new().transition(Session.FAILED).get("ok") == false, "session failure requires reason", failures)
	var wide_geometry: Dictionary = RadialView.geometry_for_size(Vector2(1280, 720))
	var tall_geometry: Dictionary = RadialView.geometry_for_size(Vector2(720, 1280))
	_check(wide_geometry["short_side"] == 720.0 and tall_geometry["short_side"] == 720.0, "radial safe area uses short side", failures)
	_check(wide_geometry["outer_radius"] == tall_geometry["outer_radius"], "radial layout stays circular across aspect ratios", failures)
	var zero_offsets: Dictionary = TimingOffsets.from_seconds(0.0, 0.0)
	var positive_input: Dictionary = TimingOffsets.from_seconds(0.025, 0.0)
	var positive_audio: Dictionary = TimingOffsets.from_seconds(0.0, 0.025)
	_check(TimingOffsets.adjusted_delta_us(1_000_000, 1_000_000, zero_offsets) == 0, "zero timing offsets", failures)
	_check(TimingOffsets.adjusted_delta_us(1_000_000, 1_000_000, positive_input) == 25_000, "positive input offset moves logical input later", failures)
	_check(TimingOffsets.adjusted_delta_us(1_000_000, 1_000_000, positive_audio) == -25_000, "positive audio offset moves judged note later", failures)
	var score_rules: Dictionary = {"weights":{"perfect":1000,"great":750,"good":500,"miss":0,"extra_hit":0}, "accuracy_weights":{"perfect":1.0,"great":0.75,"good":0.5,"miss":0.0,"extra_hit":0.0}, "combo_increments":["perfect","great","good"], "combo_breaks":["miss","extra_hit"], "extra_hit_counts_toward_accuracy":true}
	var score_records: Array[Dictionary] = [{"grade":"perfect","delta_us":0},{"grade":"great","delta_us":-40_000},{"grade":"good","delta_us":80_000},{"grade":"miss","delta_us":null},{"grade":"perfect","delta_us":10_000},{"grade":"extra_hit","delta_us":20_000}]
	var score_summary: Dictionary = ScoreEngine.summarize(score_records, score_rules)
	_check(score_summary["score"] == 3250 and score_summary["max_combo"] == 3 and score_summary["combo"] == 0, "pure score and combo recomputation", failures)
	_check(is_equal_approx(score_summary["accuracy"], 3.25 / 6.0) and score_summary["breakdown"]["perfect"] == 2 and score_summary["breakdown"]["extra_hit"] == 1, "pure accuracy and breakdown recomputation", failures)
	var hud: Dictionary = ScoreEngine.hud_model(score_records, score_rules)
	_check(hud == {"current_score":3250,"current_combo":0,"current_accuracy":3.25 / 6.0,"latest_grade":"extra_hit","latest_direction":"late"}, "HUD score combo accuracy grade and direction model", failures)
	_check(InputMode.from_arguments(PackedStringArray(["--input-mode", "midi"]))["mode"] == "midi" and InputMode.from_arguments(PackedStringArray(["--input-mode=replay"]))["mode"] == "replay", "exclusive MIDI or replay startup selection", failures)
	_check(InputMode.from_arguments(PackedStringArray(["--input-mode", "mixed"])).get("ok") == false, "mixed or unknown input mode rejected", failures)
	_finish(failures, 55)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty():
		print("PANBEAT_UNIT_TESTS_OK %d/%d" % [count, count])
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
