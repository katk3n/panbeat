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
const DeviceSetup := preload("res://presentation/device_setup_view.gd")
const SongLibrary := preload("res://presentation/song_library_view.gd")
const CalibrationView := preload("res://presentation/calibration_view.gd")
const ResultsView := preload("res://presentation/results_view.gd")
const ProductFlowView := preload("res://presentation/product_flow_view.gd")
const ProductFlow := preload("res://application/product_flow_service.gd")
const ResultsService := preload("res://application/results_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const CalibrationLogic := preload("res://application/calibration_service.gd")
const GameplayHudView := preload("res://presentation/gameplay_hud.gd")
const Accessibility := preload("res://presentation/accessibility_presenter.gd")

var midi_adapter: Node
var audio_player: AudioStreamPlayer
var session: RefCounted
var judgement_pipeline: RefCounted
var input_mode: String = ""
var developer_diagnostics: Array[String] = []
var final_summary: Dictionary = {}
var _score_rules: Dictionary = {}
var _hud: Dictionary = {"current_score":0,"current_combo":0,"current_accuracy":0.0,"latest_grade":"","latest_direction":"none"}
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
var _product_flow: RefCounted
var _imported_product_session := false
var _active_result_metadata: Dictionary = {}
var _repository_root_override := ""
var _gameplay_hud: GameplayHud
var _song_title := ""
var _song_duration_us := 0
var _results_opened := false
var _active_package_path := ""
var _completed_results_view: ResultsView

func _ready() -> void:
	super._ready()
	_maximize_window()
	if OS.get_cmdline_user_args().has("--results"):
		visible = false; set_process(false); set_process_unhandled_input(false); _open_results.call_deferred(); return
	if OS.get_cmdline_user_args().has("--calibration"):
		visible = false; set_process(false); set_process_unhandled_input(false); _open_calibration.call_deferred(); return
	if OS.get_cmdline_user_args().has("--song-library"):
		visible = false; set_process(false); set_process_unhandled_input(false); _open_song_library.call_deferred(); return
	if OS.get_cmdline_user_args().has("--device-setup"):
		visible = false
		set_process(false)
		set_process_unhandled_input(false)
		_open_device_setup.call_deferred()
		return
	if not _has_explicit_input_mode():
		visible = false; set_process(false); set_process_unhandled_input(false); _open_product_flow.call_deferred(); return
	_product_flow = ProductFlow.new()
	var automation_start: Dictionary = _product_flow.begin_session(true)
	if not automation_start.get("ok", false): _fail(automation_start.get("error", "automation flow start failed")); return
	_initialize_gameplay(_argument("--imported-package="))

func _maximize_window() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--windowed"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _initialize_gameplay(imported_package_path: String = "") -> void:
	_prepare_gameplay_state(imported_package_path)
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
		elif argument.begins_with("--repository-root="):
			_repository_root_override = argument.trim_prefix("--repository-root=")
	if _replay_speed <= 0.0 or (input_mode != InputMode.REPLAY and not is_equal_approx(_replay_speed, 1.0)):
		_fail("replay speed must be positive and is only available in replay mode")
		return
	if not _measurement_output.is_empty():
		Engine.max_fps = 60
	var profile: Dictionary = _load_json("res://config/default-instrument-profile.json")
	var package: Dictionary = _load_json("res://content/phase1-fixed-song-v1/package.json") if imported_package_path.is_empty() else _load_json_file(imported_package_path.path_join("package.json"))
	var judgement_rules: Dictionary = _load_json("res://config/judgement-rules-v1.json")
	_score_rules = _load_json("res://config/score-rules-v1.json")
	var settings: Dictionary = _load_json("res://config/gameplay-settings-v1.json")
	if profile.is_empty() or package.is_empty() or judgement_rules.is_empty() or _score_rules.is_empty() or settings.is_empty():
		_fail("required profile, package, rule, or settings JSON failed to load")
		return
	_profile_id = String(profile.get("profile_id", ""))
	_package_id = String(package.get("package_id", package.get("song_id", "")))
	_song_title = String(package.get("title", _package_id))
	_song_duration_us = int(package.get("duration_us", 0))
	_imported_product_session = not imported_package_path.is_empty()
	var persisted_settings: Dictionary = {}
	if _imported_product_session:
		var persisted_background: Dictionary = Repositories.new(_repository_root_override).settings.load()
		if persisted_background.get("ok", false): persisted_settings = persisted_background["document"]
	set_background_preset(BackgroundPresets.resolve(package, persisted_settings, _argument("--background-preset=")))
	var package_root: String = "res://content/phase1-fixed-song-v1/" if imported_package_path.is_empty() else imported_package_path.path_join("")
	var chart_name: String = str(package.get("chart_file", package.get("chart_path", "")))
	var loaded_chart: Dictionary = ChartSource.load_chart(ProjectSettings.globalize_path(package_root + chart_name) if imported_package_path.is_empty() else package_root.path_join(chart_name))
	if not loaded_chart.get("ok", false):
		_fail("chart load failed: %s" % loaded_chart.get("error", "unknown"))
		return
	var runtime_result: Dictionary = ChartFactory.build(loaded_chart["chart"], profile, int(package.get("duration_us", 0)))
	if not runtime_result.get("ok", false):
		_fail("chart validation failed: %s" % JSON.stringify(runtime_result.get("errors", [])))
		return
	var audio_name: String = str(package.get("audio_file", package.get("audio", {}).get("runtime_path", "")))
	var audio: AudioStream = load(package_root + audio_name) as AudioStream if imported_package_path.is_empty() else AudioStreamOggVorbis.load_from_file(package_root.path_join(audio_name))
	if audio == null:
		_fail("audio load failed: %s" % package.get("audio_file", ""))
		return
	if input_mode == InputMode.REPLAY:
		var replay_path := _argument("--replay-inputs=")
		var expected: Dictionary = _load_json(package_root + package.get("expected_events_file", "")) if imported_package_path.is_empty() else _load_json_file(replay_path)
		if expected.is_empty() or expected.get("inputs") is not Array:
			_fail("replay input load failed")
			return
		_replay_inputs = expected["inputs"]
	else:
		input_mode = InputMode.MIDI
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
	if _imported_product_session:
		var persisted: Dictionary = {"ok":not persisted_settings.is_empty(), "document":persisted_settings}
		if persisted.get("ok", false):
			var saved_offset: Dictionary = CalibrationLogic.find_offset(persisted["document"], profile.get("profile_id", ""), AudioServer.output_device if not AudioServer.output_device.is_empty() else "Default")
			_effective_input_offset_sec = int(saved_offset["input_offset_us"]) / 1000000.0; _effective_audio_offset_sec = int(saved_offset["audio_offset_us"]) / 1000000.0
	var offsets: Dictionary = TimingOffsets.from_seconds(_effective_input_offset_sec, _effective_audio_offset_sec)
	judgement_pipeline = Pipeline.new(runtime_result["chart"], judgement_rules, offsets)
	_active_result_metadata = {"song_id":_package_id, "importer_version":str(package.get("importer_version", "phase1-fixed-package-v1")), "chart_version":str(package.get("chart_schema_version", loaded_chart["chart"].get("schema_version", "1.0.0"))), "profile_id":str(profile.get("profile_id", "")), "judgement_rule_id":str(judgement_rules.get("rule_id", "")), "score_rule_id":str(_score_rules.get("rule_id", ""))}
	configure(runtime_result["chart"], profile)
	var accessibility_defaults := _load_json("res://config/accessibility-settings-v1.json")
	var accessibility := Accessibility.resolve(accessibility_defaults, OS.get_cmdline_user_args())
	glow_enabled = accessibility["glow_enabled"]
	monochrome = accessibility["monochrome"]
	high_contrast = accessibility["high_contrast"]
	combo_visual_enabled = false
	_gameplay_hud = GameplayHudView.new()
	_gameplay_hud.monochrome = monochrome
	_gameplay_hud.high_contrast = high_contrast
	_gameplay_hud.visible = not OS.get_cmdline_user_args().has("--hide-hud")
	_gameplay_hud.configure(_song_title, _song_duration_us)
	add_child(_gameplay_hud)
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

func _open_device_setup() -> void:
	get_tree().root.add_child(DeviceSetup.new())

func _open_song_library() -> void:
	get_tree().root.add_child(SongLibrary.new())

func _open_calibration() -> void:
	get_tree().root.add_child(CalibrationView.new())

func _open_results() -> void:
	get_tree().root.add_child(ResultsView.new())

func _open_product_flow() -> void:
	var view := ProductFlowView.new(); view.gameplay_requested.connect(_start_imported_gameplay); get_tree().root.add_child(view)

func _start_imported_gameplay(package_path: String, active_flow: RefCounted) -> void:
	for child: Node in get_tree().root.get_children():
		if child is ProductFlowView: get_tree().root.remove_child(child); child.queue_free()
	_teardown_gameplay_runtime()
	_product_flow = active_flow; visible = true; set_process(true); set_process_unhandled_input(true); _initialize_gameplay(package_path)

func _has_explicit_input_mode() -> bool:
	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--input-mode"): return true
	for argument: String in arguments:
		if argument.begins_with("--input-mode="): return true
	return false

func _process(delta: float) -> void:
	if transport == null or session.state() == Session.FAILED:
		_update_gameplay_hud()
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
		if _imported_product_session: _save_imported_result()
		if _product_flow != null: _product_flow.finish_session()
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
		elif _imported_product_session:
			_open_completed_results.call_deferred()
	super._process(delta)
	_update_gameplay_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	if session != null and session.state() == Session.FAILED:
		if (event as InputEventKey).keycode == KEY_R:
			get_tree().reload_current_scene()
		elif (event as InputEventKey).keycode == KEY_ESCAPE:
			get_tree().quit(1)
		return
	if (event as InputEventKey).keycode == KEY_SPACE:
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
	combo_value = int(_hud["current_combo"])

func _draw() -> void:
	super._draw()

func _update_gameplay_hud() -> void:
	if _gameplay_hud == null:
		return
	var state: String = transport.state() if transport != null else "idle"
	var now: int = transport.now_us() if transport != null else 0
	var failure: String = session.failure_reason() if session != null and session.state() == Session.FAILED else ""
	_gameplay_hud.present(_hud, now, state, input_mode, failure, _summary_emitted)

func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path)))
	return parsed as Dictionary if parsed is Dictionary else {}

func _load_json_file(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)); return parsed as Dictionary if parsed is Dictionary else {}

func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

func _save_imported_result() -> void:
	var datetime: Dictionary = Time.get_datetime_dict_from_system(true)
	var completed_at := "%04d-%02d-%02dT%02d:%02d:%02dZ" % [datetime.year, datetime.month, datetime.day, datetime.hour, datetime.minute, datetime.second]
	var result_id := "%s-%d" % [_package_id, roundi(Time.get_unix_time_from_system() * 1000.0)]
	var created: Dictionary = ResultsService.create_result(result_id, completed_at, _active_result_metadata, judgement_pipeline.records(), _score_rules)
	if not created.get("ok", false): developer_diagnostics.append("result creation failed: %s" % created.get("error", "unknown")); return
	var repositories := Repositories.new(_repository_root_override); var loaded: Dictionary = repositories.results.load()
	if not loaded.get("ok", false): developer_diagnostics.append("result history load failed: %s" % loaded.get("error", "unknown")); return
	var appended: Dictionary = ResultsService.append(loaded["document"], created["record"])
	if not appended.get("ok", false): developer_diagnostics.append("result history append failed: %s" % appended.get("error", "unknown")); return
	var saved: Dictionary = repositories.results.save(appended["document"]); if not saved.get("ok", false): developer_diagnostics.append("result history save failed: %s" % saved.get("error", "unknown"))

func _open_completed_results() -> void:
	if _results_opened:
		return
	_results_opened = true
	visible = false; set_process(false); set_process_unhandled_input(false)
	_completed_results_view = ResultsView.new()
	_completed_results_view.completion_actions_enabled = true
	_completed_results_view.repositories = Repositories.new(_repository_root_override)
	_completed_results_view.play_again_requested.connect(_play_again)
	_completed_results_view.song_library_requested.connect(_return_to_song_library)
	get_tree().root.add_child(_completed_results_view)

func _play_again() -> void:
	if _product_flow == null or _active_package_path.is_empty():
		return
	_close_completed_results()
	_teardown_gameplay_runtime()
	var moved: Dictionary = _product_flow.transition(ProductFlow.GAMEPLAY)
	if not moved.get("ok", false): _fail(moved.get("error", "retry transition failed")); return
	var started: Dictionary = _product_flow.begin_session()
	if not started.get("ok", false): _fail(started.get("error", "retry session failed")); return
	visible = true; set_process(true); set_process_unhandled_input(true)
	_initialize_gameplay(_active_package_path)

func _return_to_song_library() -> void:
	if _product_flow == null:
		return
	_close_completed_results()
	_teardown_gameplay_runtime()
	var moved: Dictionary = _product_flow.transition(ProductFlow.SONG_LIBRARY)
	if not moved.get("ok", false): _fail(moved.get("error", "song library transition failed")); return
	visible = false; set_process(false); set_process_unhandled_input(false)
	var view := ProductFlowView.new()
	view.flow = _product_flow
	view.repositories = Repositories.new(_repository_root_override)
	view.gameplay_requested.connect(_start_imported_gameplay)
	get_tree().root.add_child(view)

func _close_completed_results() -> void:
	if is_instance_valid(_completed_results_view):
		get_tree().root.remove_child(_completed_results_view)
		_completed_results_view.queue_free()
	_completed_results_view = null
	_results_opened = false

func _prepare_gameplay_state(imported_package_path: String) -> void:
	_active_package_path = imported_package_path
	final_summary = {}
	_hud = {"current_score":0,"current_combo":0,"current_accuracy":0.0,"latest_grade":"","latest_direction":"none"}
	_replay_inputs = []
	_replay_index = 0
	_summary_emitted = false
	_stall_injected = false
	_midi_records = []
	_session_events = []
	_active_result_metadata = {}
	_results_opened = false
	combo_value = 0

func _teardown_gameplay_runtime() -> void:
	if is_instance_valid(audio_player):
		audio_player.stop()
		remove_child(audio_player)
		audio_player.queue_free()
	if is_instance_valid(midi_adapter):
		remove_child(midi_adapter)
		midi_adapter.queue_free()
	if is_instance_valid(_gameplay_hud):
		remove_child(_gameplay_hud)
		_gameplay_hud.queue_free()
	audio_player = null
	midi_adapter = null
	_gameplay_hud = null
	transport = null
	judgement_pipeline = null
	session = null
	scheduler = null
	_metrics = null

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
