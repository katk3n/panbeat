class_name ProductFlowView
extends Control

signal gameplay_requested(package_path: String, active_flow: RefCounted)

const Flow := preload("res://application/product_flow_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const DeviceSetup := preload("res://presentation/device_setup_view.gd")
const SongLibrary := preload("res://presentation/song_library_view.gd")
const Calibration := preload("res://presentation/calibration_view.gd")
const Results := preload("res://presentation/results_view.gd")
const AppTheme := preload("res://presentation/panbeat_theme.gd")
const RichBackground := preload("res://presentation/rich_ui_background.gd")

var flow: RefCounted
var repositories: RefCounted
var _content: Control
var _status: Label
var _midi_status: Label
var _error_summary: Label
var _technical: RichTextLabel
var _details_button: Button
var _back: Button
var _retry: Button
var _cancel: Button
var _previous := ""
var _nav_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme = AppTheme.shared(); flow = Flow.new() if flow == null else flow; repositories = Repositories.new() if repositories == null else repositories; _build_shell()
	if flow.state() != Flow.BOOT:
		_show(flow.state(), false)
		return
	var settings: Dictionary = repositories.settings.load(); var songs: Dictionary = repositories.songs.load(); var route: Dictionary = flow.initial_route(settings, songs, OS.get_connected_midi_inputs())
	if route.get("ok", false): _show(flow.state(), false)
	else: _show_error(route)

func _build_shell() -> void:
	var background := RichBackground.new(); background.intensity = 1.18; add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(key, 28)
	add_child(margin)
	var root_layout := VBoxContainer.new(); root_layout.add_theme_constant_override("separation", 10); margin.add_child(root_layout)
	var header := PanelContainer.new(); root_layout.add_child(header)
	var navigation := HBoxContainer.new(); navigation.add_theme_constant_override("separation", 8); header.add_child(navigation)
	var brand := Label.new(); brand.text = "PANBEAT"; brand.add_theme_font_size_override("font_size", 34); brand.add_theme_color_override("font_color", UiTokens.color("focus")); brand.custom_minimum_size.x = 210; navigation.add_child(brand)
	var first_button: Button
	for entry: Dictionary in [{"label":"Device", "state":Flow.DEVICE_SETUP}, {"label":"Songs", "state":Flow.SONG_LIBRARY}, {"label":"Calibration", "state":Flow.CALIBRATION}, {"label":"Results", "state":Flow.RESULTS}]:
		var button := Button.new(); button.text = entry["label"].to_upper(); button.tooltip_text = "Open %s" % entry["label"]; button.pressed.connect(func() -> void: _navigate(entry["state"])); navigation.add_child(button); _nav_buttons[entry["state"]] = button
		if first_button == null: first_button = button
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; navigation.add_child(spacer)
	_midi_status = Label.new(); _midi_status.text = midi_status_text(OS.get_connected_midi_inputs()); _midi_status.tooltip_text = midi_status_detail(OS.get_connected_midi_inputs()); navigation.add_child(_midi_status)
	var context_row := HBoxContainer.new(); context_row.add_theme_constant_override("separation", 10); root_layout.add_child(context_row)
	_status = Label.new(); _status.text = "BOOT · Checking settings, songs, and MIDI"; _status.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _status.add_theme_font_size_override("font_size", 21); context_row.add_child(_status)
	_back = Button.new(); _back.text = "← BACK"; _back.tooltip_text = "Return to the previous product step"; _back.pressed.connect(_go_back); context_row.add_child(_back)
	_retry = Button.new(); _retry.text = "↻ RETRY"; _retry.visible = false; _retry.pressed.connect(func() -> void: _show(flow.state(), false)); context_row.add_child(_retry)
	_cancel = Button.new(); _cancel.text = "× CANCEL"; _cancel.visible = false; _cancel.pressed.connect(_cancel_operation); context_row.add_child(_cancel)
	var error_panel := PanelContainer.new(); error_panel.theme_type_variation = "ErrorPanel"; error_panel.visible = false; error_panel.name = "RecoverableError"; error_panel.z_index = 20; error_panel.set_anchor(SIDE_LEFT, 0.52); error_panel.set_anchor(SIDE_RIGHT, 1.0); error_panel.offset_left = 0; error_panel.offset_top = 178; error_panel.offset_right = -28; add_child(error_panel)
	var error_layout := VBoxContainer.new(); error_layout.add_theme_constant_override("separation", 6); error_panel.add_child(error_layout)
	_error_summary = Label.new(); _error_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; error_layout.add_child(_error_summary)
	_details_button = Button.new(); _details_button.text = "SHOW TECHNICAL DETAILS"; _details_button.pressed.connect(_toggle_technical_details); error_layout.add_child(_details_button)
	_technical = RichTextLabel.new(); _technical.visible = false; _technical.fit_content = true; _technical.custom_minimum_size.y = 54; error_layout.add_child(_technical)
	_error_summary.set_meta("panel", error_panel)
	_content = Control.new(); _content.size_flags_vertical = Control.SIZE_EXPAND_FILL; root_layout.add_child(_content)
	first_button.grab_focus()

func _navigate(next_state: String) -> void:
	var moved: Dictionary = flow.transition(next_state)
	if not moved.get("ok", false): _show_error(flow.failure("navigation", "That screen is not available from the current step.", moved.get("error", "invalid transition"), true)); return
	_show(next_state)

func _show(state: String, remember: bool = true) -> void:
	if remember: _previous = flow.state() if flow.state() != state else _previous
	for child: Node in _content.get_children(): _content.remove_child(child); child.queue_free()
	var error_panel: PanelContainer = _error_summary.get_meta("panel") as PanelContainer
	error_panel.visible = false; _technical.visible = false; _details_button.text = "SHOW TECHNICAL DETAILS"; _retry.visible = false; _cancel.visible = false; _status.text = "CURRENT · %s" % state.replace("_", " ").to_upper(); _midi_status.text = midi_status_text(OS.get_connected_midi_inputs()); _update_navigation(state)
	var screen: Control
	match state:
		Flow.DEVICE_SETUP: screen = DeviceSetup.new(); screen.repositories = repositories
		Flow.SONG_LIBRARY: screen = SongLibrary.new(); screen.repositories = repositories; screen.play_requested.connect(_start_gameplay)
		Flow.CALIBRATION: screen = Calibration.new(); screen.repositories = repositories
		Flow.RESULTS: screen = Results.new(); screen.repositories = repositories
		_: screen = _message_screen("GAMEPLAY — Select a valid song. Imported-song playback is connected in P213.")
	_content.add_child(screen); screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _message_screen(message: String) -> Control:
	var panel := VBoxContainer.new(); var label := Label.new(); label.text = message; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(label); return panel

func _show_error(error: Dictionary) -> void:
	var presentation := error_presentation(error)
	var error_panel: PanelContainer = _error_summary.get_meta("panel") as PanelContainer
	error_panel.visible = true; _technical.visible = false; _details_button.visible = true; _details_button.text = "SHOW TECHNICAL DETAILS"; _retry.visible = presentation["actions"].has("retry"); _cancel.visible = presentation["actions"].has("cancel"); _error_summary.text = presentation["summary"]; _technical.text = presentation["technical"]
	if _retry.visible: _retry.grab_focus()
	elif _cancel.visible: _cancel.grab_focus()
	else: _details_button.grab_focus()

func _toggle_technical_details() -> void:
	_technical.visible = not _technical.visible
	_details_button.text = "HIDE TECHNICAL DETAILS" if _technical.visible else "SHOW TECHNICAL DETAILS"

func _update_navigation(state: String) -> void:
	for route: String in _nav_buttons:
		var button: Button = _nav_buttons[route]
		button.text = navigation_label(route.replace("_", " "), route == state)
		button.set_meta("current", route == state)
		button.accessibility_name = "%s%s" % [route.replace("_", " "), ", current screen" if route == state else ""]

func _go_back() -> void:
	var target := Flow.SONG_LIBRARY if flow.state() in [Flow.CALIBRATION, Flow.RESULTS, Flow.GAMEPLAY] else Flow.BOOT
	var moved: Dictionary = flow.transition(target); if moved.get("ok", false): _show(target, false)
	else: _show_error(flow.failure("navigation", "Cannot go back from this screen.", moved.get("error", "invalid transition"), true))

func _cancel_operation() -> void:
	if flow.session_active(): flow.cancel_session()
	if flow.state() != Flow.SONG_LIBRARY:
		var moved: Dictionary = flow.transition(Flow.SONG_LIBRARY); if not moved.get("ok", false): _show_error(flow.failure("cancel", "The operation could not be cancelled.", moved.get("error", "invalid transition"), true)); return
	_show(Flow.SONG_LIBRARY, false)

func _start_gameplay(package_path: String) -> void:
	var moved: Dictionary = flow.transition(Flow.GAMEPLAY); if not moved.get("ok", false): _show_error(flow.failure("playback", "Gameplay could not start.", moved.get("error", "invalid transition"), true)); return
	var started: Dictionary = flow.begin_session(); if not started.get("ok", false): _show_error(flow.failure("playback", "Gameplay is already active.", started.get("error", "duplicate session"), true)); return
	gameplay_requested.emit(package_path, flow)

static func navigation_label(label: String, selected: bool) -> String:
	return "● %s" % label.to_upper() if selected else label.to_upper()

static func midi_status_text(ports: PackedStringArray, reopen_required: bool = false) -> String:
	if not ports.is_empty(): return "✓ MIDI READY · %s" % ", ".join(ports)
	if reopen_required: return "△ MIDI REOPEN REQUIRED"
	return "△ MIDI NO PORTS"

static func midi_status_detail(ports: PackedStringArray, reopen_required: bool = false) -> String:
	if not ports.is_empty(): return "MIDI input ready: %s" % ", ".join(ports)
	if reopen_required: return "Reconnect Mood Pan, then relaunch PanBeat because the backend requires reopen."
	return "Connect Mood Pan by USB and reopen MIDI; relaunch PanBeat if the port remains unavailable."

static func error_presentation(error: Dictionary) -> Dictionary:
	var actions: Array = error.get("actions", []) if error.get("actions", []) is Array else []
	var recommended := "Use %s." % ", ".join(actions) if not actions.is_empty() else "Open technical details for diagnosis."
	return {"summary":"! %s %s" % [error.get("user_message", "Operation failed."), recommended], "technical":"Technical details · %s" % error.get("technical_detail", "Unavailable"), "actions":actions.duplicate()}
