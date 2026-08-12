class_name PanBeatMain
extends "res://presentation/radial_view.gd"

const MidiAdapter := preload("res://infrastructure/godot_midi_adapter.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const Session := preload("res://application/game_session.gd")
const AudioBackend := preload("res://infrastructure/godot_audio_backend.gd")
const AudioTransport := preload("res://application/audio_transport_service.gd")
const Pipeline := preload("res://application/judgement_pipeline.gd")
const InputMode := preload("res://application/input_mode_selection.gd")
const TimingOffsets := preload("res://domain/timing_offsets.gd")
const ScoreEngine := preload("res://domain/score_engine.gd")
const MetricsRecorder := preload("res://infrastructure/runtime_metrics_recorder.gd")

var midi_adapter: Node
var audio_player: AudioStreamPlayer
var session: RefCounted
var judgement_pipeline: RefCounted
var input_mode: String = ""
var developer_diagnostics: Array[String] = []
var final_summary: Dictionary = {}
var _score_rules: Dictionary = {}
var _hud: Dictionary = {"current_score":0,"current_combo":0,"latest_grade":"","latest_direction":"none"}
var _replay_inputs: Array = []
var _replay_index: int = 0
var _summary_emitted: bool = false
var _quit_on_complete: bool = false
var _replay_speed: float = 1.0
var _metrics: RefCounted
var _measurement_output: String = ""
var _stall_at_seconds: float = -1.0
var _stall_injected: bool = false
var _records_output: String = ""
var _diagnostics_output: String = ""
var _input_offset_override: Variant = null
var _audio_offset_override: Variant = null
var _midi_records: Array[Dictionary] = []
var _effective_input_offset_sec: float = 0.0
var _effective_audio_offset_sec: float = 0.0
var _profile_id: String = ""
var _package_id: String = ""
var _session_events: Array[Dictionary] = []

func _ready() -> void:
	session = Session.new()
	_quit_on_complete = OS.get_cmdline_user_args().has("--quit-on-complete")
	var selected: Dictionary = InputMode.from_arguments(OS.get_cmdline_user_args())
	if not selected.get("ok", false):
		_fail(selected.get("error", "input mode selection failed"))
		return
	input_mode = selected["mode"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--replay-speed="):
			_replay_speed = float(argument.trim_prefix("--replay-speed="))
		elif argument.begins_with("--measurement-output="):
			_measurement_output = argument.trim_prefix("--measurement-output=")
		elif argument.begins_with("--inject-stall-at-sec="):
			_stall_at_seconds = float(argument.trim_prefix("--inject-stall-at-sec="))
		elif argument.begins_with("--records-output="):
			_records_output = argument.trim_prefix("--records-output=")
		elif argument.begins_with("--diagnostics-output="):
			_diagnostics_output = argument.trim_prefix("--diagnostics-output=")
		elif argument.begins_with("--input-offset-sec="):
			_input_offset_override = float(argument.trim_prefix("--input-offset-sec="))
		elif argument.begins_with("--audio-offset-sec="):
			_audio_offset_override = float(argument.trim_prefix("--audio-offset-sec="))
	if _replay_speed <= 0.0 or (input_mode != InputMode.REPLAY and not is_equal_approx(_replay_speed, 1.0)):
		_fail("replay speed must be positive and is only available in replay mode")
		return
	if not _measurement_output.is_empty():
		Engine.max_fps = 60
	var profile: Dictionary = _load_json("res://config/default-instrument-profile.json")
	var package: Dictionary = _load_json("res://content/phase1-fixed-song-v1/package.json")
	var judgement_rules: Dictionary = _load_json("res://config/judgement-rules-v1.json")
	_score_rules = _load_json("res://config/score-rules-v1.json")
	var settings: Dictionary = _load_json("res://config/gameplay-settings-v1.json")
	if profile.is_empty() or package.is_empty() or judgement_rules.is_empty() or _score_rules.is_empty() or settings.is_empty():
		_fail("required profile, package, rule, or settings JSON failed to load")
		return
	_profile_id = String(profile.get("profile_id", ""))
	_package_id = String(package.get("package_id", ""))
	var package_root: String = "res://content/phase1-fixed-song-v1/"
	var loaded_chart: Dictionary = ChartSource.load_chart(ProjectSettings.globalize_path(package_root + package.get("chart_file", "")))
	if not loaded_chart.get("ok", false):
		_fail("chart load failed: %s" % loaded_chart.get("error", "unknown"))
		return
	var runtime_result: Dictionary = ChartFactory.build(loaded_chart["chart"], profile, int(package.get("duration_us", 0)))
	if not runtime_result.get("ok", false):
		_fail("chart validation failed: %s" % JSON.stringify(runtime_result.get("errors", [])))
		return
	var audio: AudioStream = load(package_root + package.get("audio_file", "")) as AudioStream
	if audio == null:
		_fail("audio load failed: %s" % package.get("audio_file", ""))
		return
	if input_mode == InputMode.REPLAY:
		var expected: Dictionary = _load_json(package_root + package.get("expected_events_file", ""))
		if expected.is_empty() or expected.get("inputs") is not Array:
			_fail("replay input load failed")
			return
		_replay_inputs = expected["inputs"]
	else:
		midi_adapter = MidiAdapter.new()
		midi_adapter.profile = profile
		midi_adapter.preferred_port = "MN-10"
		midi_adapter.record_received.connect(_on_midi_record)
		add_child(midi_adapter)
		var lifecycle: Dictionary = midi_adapter.lifecycle_diagnostics.back() if not midi_adapter.lifecycle_diagnostics.is_empty() else {}
		if not lifecycle.get("ok", false):
			_fail("MIDI initialization failed: %s" % lifecycle.get("code", lifecycle.get("error", "unknown")))
			return
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = audio
	audio_player.pitch_scale = _replay_speed
	if not _measurement_output.is_empty():
		audio_player.volume_db = -60.0
	add_child(audio_player)
	_effective_input_offset_sec = float(settings["input_offset_sec"]) if _input_offset_override == null else float(_input_offset_override)
	_effective_audio_offset_sec = float(settings["audio_offset_sec"]) if _audio_offset_override == null else float(_audio_offset_override)
	var offsets: Dictionary = TimingOffsets.from_seconds(_effective_input_offset_sec, _effective_audio_offset_sec)
	judgement_pipeline = Pipeline.new(runtime_result["chart"], judgement_rules, offsets)
	configure(runtime_result["chart"], profile)
	transport = AudioTransport.new(AudioBackend.new(audio_player), int(package["duration_us"]), session)
	if not _measurement_output.is_empty():
		_metrics = MetricsRecorder.new(_measurement_output, _replay_speed, {"input_mode":input_mode,"profile_id":profile["profile_id"],"package_id":package["package_id"],"stall_at_seconds":_stall_at_seconds})
	if not session.transition(Session.READY).get("ok", false):
		_fail("session could not become ready")
		return
	var scheduled: Dictionary = transport.schedule_start(1.0)
	if not scheduled.get("ok", false):
		_fail("audio schedule failed: %s" % scheduled.get("error", "unknown"))
		return
	_record_session_event("scheduled")
	developer_diagnostics.append("ready input_mode=%s replay_speed=%.2f chart_notes=%d audio_us=%d" % [input_mode, _replay_speed, runtime_result["chart"].note_count(), package["duration_us"]])
	queue_redraw()

func _process(delta: float) -> void:
	if transport == null or session.state() == Session.FAILED:
		queue_redraw()
		return
	var updated: Dictionary = transport.update()
	if not updated.get("ok", false):
		_fail("transport failed: %s" % updated.get("error", "unknown"))
		return
	var now_us: int = transport.now_us()
	if _metrics != null and transport.state() == AudioTransport.PLAYING:
		_metrics.observe(now_us, delta, scheduler)
		if not _stall_injected and _stall_at_seconds >= 0.0 and now_us >= roundi(_stall_at_seconds * 1_000_000.0):
			_stall_injected = true
			_metrics.event("stall_begin", {"song_time_us":now_us,"duration_us":150_000})
			var stall_until_us: int = Time.get_ticks_usec() + 150_000
			while Time.get_ticks_usec() < stall_until_us:
				pass
			_metrics.event("stall_end", {"song_time_us_before_transport_refresh":now_us})
	if transport.accepts_input():
		if input_mode == InputMode.REPLAY:
			_process_replay_until(now_us)
		_apply_records(judgement_pipeline.sweep_misses(now_us))
	if transport.state() == AudioTransport.COMPLETED and not _summary_emitted:
		_process_replay_until(now_us)
		_apply_records(judgement_pipeline.sweep_misses(now_us + 100_001))
		final_summary = ScoreEngine.summarize(judgement_pipeline.records(), _score_rules)
		_summary_emitted = true
		_record_session_event("completed")
		developer_diagnostics.append("completed %s" % JSON.stringify(final_summary))
		if _metrics != null:
			_metrics.finish(final_summary)
		if not _records_output.is_empty():
			var records_file := FileAccess.open(_records_output, FileAccess.WRITE)
			if records_file == null:
				_fail("could not write judgement records: %s" % _records_output)
				return
			records_file.store_string(JSON.stringify({"schema_version":"1.0.0","records":judgement_pipeline.records(),"summary":final_summary}, "  ") + "\n")
			records_file.close()
		_write_diagnostics("completed")
		print("PANBEAT_VERTICAL_SLICE_COMPLETE %s" % JSON.stringify(final_summary))
		if _quit_on_complete:
			get_tree().quit(0)
	super._process(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_SPACE:
		if transport != null and transport.state() == AudioTransport.PLAYING:
			var paused: Dictionary = transport.pause()
			if paused.get("ok", false):
				_record_session_event("paused")
		elif transport != null and transport.state() == AudioTransport.PAUSED:
			var resumed: Dictionary = transport.resume()
			if resumed.get("ok", false):
				_record_session_event("resumed")

func _on_midi_record(raw: Dictionary, normalized: Dictionary) -> void:
	_midi_records.append({"raw":raw.duplicate(true),"normalized":normalized.duplicate(true),"transport_timestamp_us":transport.now_us() if transport != null else null,"accepted_for_judgement":transport != null and transport.accepts_input() and normalized.get("kind") == "normalized_input"})
	if normalized.get("kind") != "normalized_input":
		developer_diagnostics.append("MIDI diagnostic: %s" % normalized.get("code", "unknown"))
		return
	if transport == null or not transport.accepts_input():
		developer_diagnostics.append("MIDI input ignored while transport is not playing")
		return
	_apply_record(judgement_pipeline.process_input(normalized, transport.now_us()))

func _process_replay_until(now_us: int) -> void:
	while _replay_index < _replay_inputs.size() and int((_replay_inputs[_replay_index] as Dictionary)["timestamp_us"]) <= now_us:
		var event: Dictionary = _replay_inputs[_replay_index] as Dictionary
		var normalized: Dictionary = {"kind":"normalized_input", "input_event_id":event["event_id"], "source_kind":"deterministic_replay", "technique":event["technique"], "target_id":event["target_id"], "velocity":event.get("velocity", 96)}
		_apply_record(judgement_pipeline.process_input(normalized, int(event["timestamp_us"])))
		_replay_index += 1

func _apply_records(records: Array[Dictionary]) -> void:
	for record: Dictionary in records:
		_apply_record(record)

func _apply_record(record: Dictionary) -> void:
	if record.get("note_id") != null:
		show_feedback(record["note_id"], record["grade"])
	_hud = ScoreEngine.hud_model(judgement_pipeline.records(), _score_rules)

func _draw() -> void:
	super._draw()
	var font: Font = ThemeDB.fallback_font
	var ink := Color(0.94, 0.95, 0.98)
	draw_string(font, Vector2(28, 40), "SCORE %d    COMBO %d" % [_hud["current_score"], _hud["current_combo"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
	draw_string(font, Vector2(28, 70), "%s  %s" % [String(_hud["latest_grade"]).to_upper(), String(_hud["latest_direction"]).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	if session != null and session.state() == Session.FAILED:
		draw_string(font, Vector2(28, 112), "FAILED: %s" % session.failure_reason(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.65, 0.65))
	elif _summary_emitted:
		draw_string(font, Vector2(28, 112), "COMPLETE  ACCURACY %.2f%%  MAX COMBO %d" % [float(final_summary["accuracy"]) * 100.0, final_summary["max_combo"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
		var counts: Dictionary = final_summary["breakdown"]
		draw_string(font, Vector2(28, 140), "P %d  G %d  GOOD %d  MISS %d" % [counts["perfect"], counts["great"], counts["good"], counts["miss"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	elif transport != null and transport.state() == AudioTransport.SCHEDULED:
		draw_string(font, Vector2(28, 112), "COUNT IN  %.2f" % (-transport.now_us() / 1_000_000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(font, Vector2(28, get_viewport_rect().size.y - 24), "INPUT: %s    SPACE: PAUSE / RESUME" % input_mode.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ink, 0.72))

func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path)))
	return parsed as Dictionary if parsed is Dictionary else {}

func _fail(reason: String) -> void:
	developer_diagnostics.append(reason)
	_record_session_event("failed")
	if session != null and session.state() != Session.FAILED:
		session.transition(Session.FAILED, reason)
	push_error(reason)
	_write_diagnostics("failed")
	if _quit_on_complete and is_inside_tree():
		get_tree().quit(1)
	queue_redraw()

func _write_diagnostics(status: String) -> void:
	if _diagnostics_output.is_empty():
		return
	var diagnostics_file := FileAccess.open(_diagnostics_output, FileAccess.WRITE)
	if diagnostics_file == null:
		push_error("could not write diagnostics: %s" % _diagnostics_output)
		return
	diagnostics_file.store_string(JSON.stringify({"schema_version":"1.0.0","status":status,"input_mode":input_mode,"profile_id":_profile_id,"package_id":_package_id,"session_state":session.state() if session != null else null,"failure_reason":session.failure_reason() if session != null else "","developer_diagnostics":developer_diagnostics,"session_events":_session_events,"transport":transport.diagnostics() if transport != null else {},"midi_lifecycle":midi_adapter.lifecycle_diagnostics if midi_adapter != null else [],"midi_records":_midi_records,"input_offset_sec":_effective_input_offset_sec,"audio_offset_sec":_effective_audio_offset_sec,"input_offset_overridden":_input_offset_override != null,"audio_offset_overridden":_audio_offset_override != null}, "  ") + "\n")
	diagnostics_file.close()

func _record_session_event(event_name: String) -> void:
	_session_events.append({"event":event_name,"monotonic_timestamp_us":Time.get_ticks_usec(),"transport_timestamp_us":transport.now_us() if transport != null else null})
