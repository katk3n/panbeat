class_name CalibrationView
extends Control

const Adapter := preload("res://infrastructure/godot_midi_adapter.gd")
const Calibration := preload("res://application/calibration_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const AppTheme := preload("res://presentation/panbeat_theme.gd")
const RichBackground := preload("res://presentation/rich_ui_background.gd")
const Presenter := preload("res://presentation/product_screen_presenter.gd")

const PROFILE_ID := "roland-mn10-handpan-minor-v1"
const CUE_INTERVAL_US := 1_500_000
const HIT_WINDOW_US := 400_000
const TARGET_CUES := 9

var repositories: RefCounted
var _adapter: Node
var _audio: AudioStreamPlayer
var _status: Label
var _midi_status: Label
var _samples_label: RichTextLabel
var _input_spin: SpinBox
var _audio_spin: SpinBox
var _samples: Array[Dictionary] = []
var _pending_stimulus_us := -1
var _next_cue_us := -1
var _early_input_us := -1
var _early_technique := ""
var _cues_emitted := 0
var _running := false
var _proposal: Dictionary = {}
var _diagnostics_output := ""
var _audio_output_id := "Default Output"
var _stage: Label

func _ready() -> void:
	theme = AppTheme.shared(); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _diagnostics_output = _argument("--calibration-diagnostics-output=")
	repositories = Repositories.new() if repositories == null else repositories
	_audio_output_id = AudioServer.output_device if not AudioServer.output_device.is_empty() else "Default Output"
	_build_ui(); _load_saved(); _adapter = Adapter.new() if _adapter == null else _adapter; _adapter.profile = _load_json("res://config/default-instrument-profile.json"); _adapter.record_received.connect(_on_record); add_child(_adapter); _refresh_midi_status.call_deferred()

func _process(_delta: float) -> void:
	if not _running: return
	var now := Time.get_ticks_usec()
	if _pending_stimulus_us >= 0 and now - _pending_stimulus_us > HIT_WINDOW_US:
		_samples.append(Calibration.sample(_pending_stimulus_us, -1, "miss", PROFILE_ID, _audio_output_id)); _pending_stimulus_us = -1; _refresh_samples()
	if _cues_emitted < TARGET_CUES and now >= _next_cue_us:
		_emit_cue(now)
	elif _cues_emitted >= TARGET_CUES and _pending_stimulus_us < 0:
		_running = false; _stage.text = "① START   →   ② CUE INPUT   →   【③ ANALYZE】   →   ④ APPLY & SAVE"; _status.text = "CAPTURE COMPLETE — Analyze samples. Miss and Extra Hit are excluded."

func _build_ui() -> void:
	var background := RichBackground.new(); background.intensity = 1.10; add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(key, 28)
	add_child(margin); var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 8); margin.add_child(layout)
	var title := Label.new(); title.text = "CALIBRATION"; title.add_theme_font_size_override("font_size", 38); layout.add_child(title)
	_stage = Label.new(); _stage.text = "① START   →   ② CUE INPUT   →   ③ ANALYZE   →   ④ APPLY & SAVE"; _stage.add_theme_color_override("font_color", Color("e4b45f")); _stage.add_theme_font_size_override("font_size", 18); layout.add_child(_stage)
	var explanation := Label.new(); explanation.text = "Strike Tone or Ding once when each cue sounds/flashes. Positive Input Offset moves input later; negative moves it earlier. Positive Audio Offset moves the judged note later."; explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; layout.add_child(explanation)
	_status = Label.new(); _status.text = "READY — Start when Mood Pan input is connected."; _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _status.custom_minimum_size.y = 48; _status.add_theme_font_size_override("font_size", 21); layout.add_child(_status)
	_midi_status = Label.new(); _midi_status.text = "MIDI — CHECKING…"; layout.add_child(_midi_status)
	var actions := HBoxContainer.new(); layout.add_child(actions)
	var refresh_midi := Button.new(); refresh_midi.text = "Refresh MIDI"; refresh_midi.pressed.connect(_refresh_midi); actions.add_child(refresh_midi)
	var start := Button.new(); start.text = "Start 9 Cues"; start.pressed.connect(_start); actions.add_child(start)
	var analyze := Button.new(); analyze.text = "Analyze"; analyze.pressed.connect(_analyze); actions.add_child(analyze)
	var apply := Button.new(); apply.text = "Apply & Save"; apply.pressed.connect(_apply); actions.add_child(apply)
	var reset := Button.new(); reset.text = "Reset"; reset.pressed.connect(_reset); actions.add_child(reset)
	var save := Button.new(); save.text = "Save Diagnostics"; save.pressed.connect(_save_diagnostics); actions.add_child(save)
	var quit := Button.new(); quit.text = "Quit"; quit.pressed.connect(func() -> void: get_tree().quit(0)); actions.add_child(quit)
	var input_row := HBoxContainer.new(); layout.add_child(input_row); var input_label := Label.new(); input_label.text = "Input Offset (ms)"; input_label.custom_minimum_size.x = 180; input_row.add_child(input_label); _input_spin = SpinBox.new(); _input_spin.min_value = -300; _input_spin.max_value = 300; _input_spin.step = 1; input_row.add_child(_input_spin)
	var audio_row := HBoxContainer.new(); layout.add_child(audio_row); var audio_label := Label.new(); audio_label.text = "Audio Offset (ms)"; audio_label.custom_minimum_size.x = 180; audio_row.add_child(audio_label); _audio_spin = SpinBox.new(); _audio_spin.min_value = -300; _audio_spin.max_value = 300; _audio_spin.step = 1; audio_row.add_child(_audio_spin)
	_input_spin.value_changed.connect(func(_value: float) -> void: _refresh_samples()); _audio_spin.value_changed.connect(func(_value: float) -> void: _refresh_samples())
	var key_label := Label.new(); key_label.text = "Saved key: %s + %s" % [PROFILE_ID, _audio_output_id]; layout.add_child(key_label)
	_samples_label = RichTextLabel.new(); _samples_label.fit_content = true; _samples_label.custom_minimum_size.y = 160; _samples_label.text = "No samples yet."; layout.add_child(_samples_label); start.grab_focus()

func _start() -> void:
	_samples = []; _proposal = {}; _pending_stimulus_us = -1; _early_input_us = -1; _early_technique = ""; _cues_emitted = 0; _running = true; _next_cue_us = Time.get_ticks_usec() + 1_000_000; _stage.text = "① START   →   【② CUE INPUT】   →   ③ ANALYZE   →   ④ APPLY & SAVE"; _status.text = "GET READY — First cue in one second."; _refresh_samples()

func _emit_cue(now: int) -> void:
	if _pending_stimulus_us >= 0: _samples.append(Calibration.sample(_pending_stimulus_us, -1, "miss", PROFILE_ID, _audio_output_id))
	_cues_emitted += 1; _next_cue_us = now + CUE_INTERVAL_US; _status.text = "HIT NOW — Cue %d/%d (Tone or Ding)" % [_cues_emitted, TARGET_CUES]; _play_click()
	if _early_input_us >= 0:
		_samples.append(Calibration.sample(now, _early_input_us, "hit", PROFILE_ID, _audio_output_id, _early_technique)); _pending_stimulus_us = -1; _early_input_us = -1; _early_technique = ""
	else: _pending_stimulus_us = now
	_refresh_samples()

func _on_record(_raw: Dictionary, normalized: Dictionary) -> void:
	if normalized.get("kind") != "normalized_input" or normalized.get("technique") not in ["tone", "ding"]: return
	_midi_status.text = "MIDI READY — %s received from %s" % [str(normalized.get("technique", "input")).to_upper(), ", ".join(_adapter.ports())]
	var now := Time.get_ticks_usec()
	var assignment := Calibration.assign_input(now, _pending_stimulus_us if _running else -1, _next_cue_us if _running and _cues_emitted < TARGET_CUES else -1, HIT_WINDOW_US, _early_input_us >= 0)
	if assignment == "current_cue":
		_samples.append(Calibration.sample(_pending_stimulus_us, now, "hit", PROFILE_ID, _audio_output_id, normalized["technique"])); _pending_stimulus_us = -1
	elif assignment == "next_cue":
		_early_input_us = now; _early_technique = normalized["technique"]; _status.text = "EARLY HIT CAPTURED — waiting for cue %d/%d" % [_cues_emitted + 1, TARGET_CUES]
	else: _samples.append(Calibration.sample(now, now, "extra_hit", PROFILE_ID, _audio_output_id, normalized["technique"]))
	_refresh_samples()

func _refresh_midi() -> void:
	_adapter.reopen()
	_refresh_midi_status()

func _refresh_midi_status() -> void:
	if _adapter == null:
		return
	var ports: PackedStringArray = _adapter.ports()
	_midi_status.text = "MIDI READY — %s. Strike Tone or Ding before starting." % ", ".join(ports) if not ports.is_empty() else "MIDI NOT READY — No ports. Connect Mood Pan, then press Refresh MIDI; relaunch PanBeat if it remains unavailable."

func _analyze() -> void:
	_stage.text = "① START   →   ② CUE INPUT   →   【③ ANALYZE】   →   ④ APPLY & SAVE"
	_proposal = Calibration.analyze(_samples, roundi(_input_spin.value * 1000.0), roundi(_audio_spin.value * 1000.0))
	for excluded: Dictionary in _proposal.get("excluded", []):
		if excluded.get("exclusion_reason") != "timing_outlier": continue
		for index: int in _samples.size():
			if _samples[index].get("stimulus_timestamp_us") == excluded.get("stimulus_timestamp_us") and _samples[index].get("input_timestamp_us") == excluded.get("input_timestamp_us"):
				_samples[index]["included"] = false; _samples[index]["exclusion_reason"] = "timing_outlier"
	_refresh_samples()
	if not _proposal.get("ok", false): _status.text = Presenter.calibration_retry(_proposal); return
	_input_spin.value = int(_proposal["proposed"]["input_offset_us"]) / 1000.0; _audio_spin.value = int(_proposal["proposed"]["audio_offset_us"]) / 1000.0
	_stage.text = "① START   →   ② CUE INPUT   →   ③ ANALYZE   →   【④ APPLY & SAVE】"; _status.text = "PASS — PROPOSAL READY: median %+.1f ms, MAD %.1f ms, %d outlier(s) excluded. Review/fine-tune, then Apply & Save." % [int(_proposal["median_delta_us"]) / 1000.0, int(_proposal["mad_us"]) / 1000.0, int(_proposal.get("outlier_count", 0))]

func _apply() -> void:
	var loaded: Dictionary = repositories.settings.load(); if not loaded.get("ok", false): _status.text = "SAVE FAILED — %s" % loaded.get("error", "settings unavailable"); return
	var updated := Calibration.upsert_offset(loaded["document"], PROFILE_ID, _audio_output_id, roundi(_input_spin.value * 1000.0), roundi(_audio_spin.value * 1000.0), _samples)
	var saved: Dictionary = repositories.settings.save(updated); _status.text = "SAVED — Applies after restart for this profile/output." if saved.get("ok", false) else "SAVE FAILED — %s" % saved.get("error", "storage error")

func _reset() -> void:
	var loaded: Dictionary = repositories.settings.load(); if not loaded.get("ok", false): return
	var saved: Dictionary = repositories.settings.save(Calibration.reset_offset(loaded["document"], PROFILE_ID, _audio_output_id)); if saved.get("ok", false): _input_spin.value = 0; _audio_spin.value = 0; _samples = []; _proposal = {}; _status.text = "RESET — Both offsets are 0 ms."; _refresh_samples()

func _load_saved() -> void:
	var loaded: Dictionary = repositories.settings.load(); if not loaded.get("ok", false): return
	var saved := Calibration.find_offset(loaded["document"], PROFILE_ID, _audio_output_id); _input_spin.value = int(saved["input_offset_us"]) / 1000.0; _audio_spin.value = int(saved["audio_offset_us"]) / 1000.0

func _refresh_samples() -> void:
	var lines: Array[String] = ["Samples (stimulus / input / raw delta / status)"]
	for value: Dictionary in _samples: lines.append("%d / %s / %s ms / %s%s" % [value["stimulus_timestamp_us"], str(value["input_timestamp_us"]), "—" if value["delta_us"] == null else "%+.1f" % (int(value["delta_us"]) / 1000.0), str(value["status"]).to_upper(), " · EXCLUDED (%s)" % value.get("exclusion_reason", value.get("status", "invalid")) if not value["included"] else ""])
	var valid: Array[Dictionary] = []
	for value: Dictionary in _samples:
		if value.get("included", false): valid.append(value)
	if not valid.is_empty():
		var preview := Calibration.analyze(valid if valid.size() >= Calibration.MIN_SAMPLES else valid + valid.slice(0, maxi(0, Calibration.MIN_SAMPLES - valid.size())), roundi(_input_spin.value * 1000.0), roundi(_audio_spin.value * 1000.0))
		if preview.get("median_delta_us") != null: lines.append("Adjusted median preview: %+.1f ms = raw %+.1f + Input %+.1f − Audio %+.1f" % [(int(preview["median_delta_us"]) + roundi(_input_spin.value * 1000.0) - roundi(_audio_spin.value * 1000.0)) / 1000.0, int(preview["median_delta_us"]) / 1000.0, _input_spin.value, _audio_spin.value])
	_samples_label.text = "\n".join(lines)

func _play_click() -> void:
	if _audio == null: _audio = AudioStreamPlayer.new(); add_child(_audio)
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 48000; stream.stereo = false; var bytes := PackedByteArray(); bytes.resize(2400 * 2)
	for index: int in 2400: bytes.encode_s16(index * 2, roundi(sin(TAU * 880.0 * index / 48000.0) * 12000.0 * (1.0 - index / 2400.0)))
	stream.data = bytes; _audio.stream = stream; _audio.play()

func _save_diagnostics() -> void:
	if _diagnostics_output.is_empty(): _status.text = "No diagnostics path. Relaunch with --calibration-diagnostics-output=/absolute/path.json"; return
	var file := FileAccess.open(_diagnostics_output, FileAccess.WRITE); if file == null: _status.text = "DIAGNOSTICS SAVE FAILED"; return
	file.store_string(JSON.stringify({"schema_version":"1.0.0", "story":"P210", "profile_id":PROFILE_ID, "audio_output_id":_audio_output_id, "samples":_samples, "analysis":_proposal, "selected_offsets":{"input_offset_us":roundi(_input_spin.value * 1000.0), "audio_offset_us":roundi(_audio_spin.value * 1000.0)}}, "  ") + "\n"); _status.text = "DIAGNOSTICS SAVED — %s" % _diagnostics_output

func _load_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))); return value as Dictionary if value is Dictionary else {}

func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""
