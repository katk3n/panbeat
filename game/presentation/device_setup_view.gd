class_name DeviceSetupView
extends Control

const AppTheme := preload("res://presentation/panbeat_theme.gd")
const RichBackground := preload("res://presentation/rich_ui_background.gd")

const MidiAdapter := preload("res://infrastructure/godot_midi_adapter.gd")
const DeviceModel := preload("res://application/device_setup_model.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")

var _adapter: Node
var _profile: Dictionary = {}
var _status: Label
var _ports: OptionButton
var _monitor: Label
var _history: RichTextLabel
var _save_status: Label
var _diagnostics_output := ""
var _monitor_records: Array[Dictionary] = []
var repositories: RefCounted

func _ready() -> void:
	theme = AppTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_diagnostics_output = _argument("--device-diagnostics-output=")
	_profile = _load_json("res://config/default-instrument-profile.json")
	repositories = Repositories.new() if repositories == null else repositories
	var loaded_settings: Dictionary = repositories.settings.load()
	_build_ui()
	_adapter = MidiAdapter.new() if _adapter == null else _adapter
	_adapter.profile = _profile
	_adapter.preferred_port = str(loaded_settings.get("document", {}).get("selected_midi_port", "")) if loaded_settings.get("ok", false) else ""
	_adapter.record_received.connect(_on_record)
	add_child(_adapter)
	_refresh_ui.call_deferred()
	if OS.get_cmdline_user_args().has("--device-setup-auto-quit"):
		_auto_quit_after_ready.call_deferred()

func _auto_quit_after_ready() -> void:
	for _frame: int in 4: await get_tree().process_frame
	print("PANBEAT_DEVICE_SETUP_READY")
	get_tree().quit(0)

func _build_ui() -> void:
	var background := RichBackground.new(); background.intensity = 1.12; add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.add_theme_constant_override("margin_left", 48); margin.add_theme_constant_override("margin_right", 48); margin.add_theme_constant_override("margin_top", 36); margin.add_theme_constant_override("margin_bottom", 36); add_child(margin)
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 14); margin.add_child(layout)
	var title := Label.new(); title.text = "DEVICE SETUP"; title.add_theme_font_size_override("font_size", 38); layout.add_child(title)
	var intro := Label.new(); intro.text = "1. Connect Mood Pan by USB  2. Select the MN-10 port  3. Confirm Tone / Ding / Slap below"; intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; layout.add_child(intro)
	var connection_heading := Label.new(); connection_heading.text = "CONNECTION STATUS"; connection_heading.add_theme_color_override("font_color", Color("e4b45f")); layout.add_child(connection_heading)
	_status = Label.new(); _status.text = "OPENING MIDI…"; _status.add_theme_font_size_override("font_size", 22); layout.add_child(_status)
	var port_row := HBoxContainer.new(); layout.add_child(port_row)
	var port_label := Label.new(); port_label.text = "MIDI Port"; port_label.custom_minimum_size.x = 130; port_row.add_child(port_label)
	_ports = OptionButton.new(); _ports.custom_minimum_size.x = 360; _ports.item_selected.connect(_on_port_selected); port_row.add_child(_ports)
	var profile_row := HBoxContainer.new(); layout.add_child(profile_row)
	var profile_label := Label.new(); profile_label.text = "Profile"; profile_label.custom_minimum_size.x = 130; profile_row.add_child(profile_label)
	var profile_value := Label.new(); profile_value.text = "%s — Handpan / Minor" % _profile.get("profile_id", "missing profile"); profile_row.add_child(profile_value)
	var actions := HBoxContainer.new(); layout.add_child(actions)
	var reopen := Button.new(); reopen.text = "Reopen MIDI"; reopen.tooltip_text = "Close and open MIDI once, without duplicate registration"; reopen.pressed.connect(_on_reopen); actions.add_child(reopen)
	var save := Button.new(); save.text = "Save Diagnostics"; save.pressed.connect(_save_diagnostics); actions.add_child(save)
	var quit := Button.new(); quit.text = "Quit"; quit.pressed.connect(func() -> void: get_tree().quit(0)); actions.add_child(quit)
	var monitor_heading := Label.new(); monitor_heading.text = "LIVE INPUT MONITOR"; monitor_heading.add_theme_color_override("font_color", Color("e4b45f")); layout.add_child(monitor_heading)
	_monitor = Label.new(); _monitor.text = "Strike Tone, Ding, and Slap"; _monitor.add_theme_font_size_override("font_size", 24); layout.add_child(_monitor)
	_history = RichTextLabel.new(); _history.fit_content = true; _history.custom_minimum_size.y = 170; _history.text = "No MIDI events yet."; layout.add_child(_history)
	var limitation := Label.new(); limitation.text = "TECHNICAL DETAILS — Godot does not expose physical disconnect state or the OS receive timestamp. Silence alone does not prove disconnection. Use Reopen MIDI; if input does not return, quit and relaunch PanBeat after reconnecting the USB cable."; limitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; layout.add_child(limitation)
	_save_status = Label.new(); _save_status.text = "Diagnostics are saved only when requested."; layout.add_child(_save_status)

func _refresh_ui() -> void:
	_ports.clear()
	var ports: PackedStringArray = _adapter.ports()
	if ports.is_empty(): _ports.add_item("No MIDI ports")
	else:
		for port: String in ports: _ports.add_item(port)
	var lifecycle: Dictionary = _adapter.lifecycle_diagnostics.back() if not _adapter.lifecycle_diagnostics.is_empty() else {}
	var status := DeviceModel.lifecycle_status(lifecycle)
	_status.text = "%s — %s" % [status["label"], status["message"]]
	if not ports.is_empty():
		var compatibility := DeviceModel.compatibility(ports[0], _profile)
		if not compatibility.get("ok", false): _status.text += "  UNSUPPORTED DEVICE / PROFILE MISMATCH — %s" % compatibility["message"]
	_update_history()

func _on_port_selected(index: int) -> void:
	if index < 0 or index >= _adapter.ports().size(): return
	_adapter.select_port(_adapter.ports()[index])
	var loaded: Dictionary = repositories.settings.load()
	if loaded.get("ok", false):
		var settings: Dictionary = loaded["document"]; settings["selected_midi_port"] = _adapter.ports()[index]; settings["profile_id"] = _profile.get("profile_id", settings.get("profile_id", "")); var saved: Dictionary = repositories.settings.save(settings)
		if not saved.get("ok", false): _save_status.text = "SETTINGS SAVE FAILED — %s" % saved.get("error", "storage error")
	_refresh_ui()

func _on_reopen() -> void:
	_adapter.reopen()
	_refresh_ui()

func _on_record(raw: Dictionary, normalized: Dictionary) -> void:
	var entry := DeviceModel.monitor_entry(raw, normalized)
	entry["timestamp_us"] = Time.get_ticks_usec()
	_monitor_records.append(entry)
	if _monitor_records.size() > 64: _monitor_records.pop_front()
	_monitor.text = "INPUT MONITOR: %s | note %s | velocity %s" % [entry["message"], entry["note"], entry["velocity"]]
	_update_history()

func _update_history() -> void:
	var lines: Array[String] = []
	for lifecycle: Dictionary in _adapter.lifecycle_diagnostics if _adapter != null else []: lines.append("MIDI %s — ports: %s" % [lifecycle.get("code", "unknown"), lifecycle.get("ports", [])])
	for entry: Dictionary in _monitor_records: lines.append("%s — %s" % [entry["status"], entry["message"]])
	_history.text = "\n".join(lines) if not lines.is_empty() else "No diagnostics yet."

func _save_diagnostics() -> void:
	if _diagnostics_output.is_empty():
		_save_status.text = "No output path was supplied. Relaunch with --device-diagnostics-output=/absolute/path.json"
		return
	var file := FileAccess.open(_diagnostics_output, FileAccess.WRITE)
	if file == null:
		_save_status.text = "SAVE FAILED — check output permissions."
		return
	file.store_string(JSON.stringify({"schema_version":"1.0.0", "story":"P209", "profile_id":_profile.get("profile_id", ""), "profile_settings":_profile.get("settings", {}), "ports":Array(_adapter.ports()), "lifecycle":_adapter.lifecycle_diagnostics, "monitor_records":_monitor_records, "godot_limitations":{"physical_disconnect_observable":false, "os_receive_timestamp_available":false}}, "  ") + "\n")
	_save_status.text = "SAVED — %s" % _diagnostics_output

func _load_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path)))
	return value as Dictionary if value is Dictionary else {}

func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""
