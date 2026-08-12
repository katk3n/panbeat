class_name ProductFlowView
extends Control

signal gameplay_requested(package_path: String, active_flow: RefCounted)

const Flow := preload("res://application/product_flow_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const DeviceSetup := preload("res://presentation/device_setup_view.gd")
const SongLibrary := preload("res://presentation/song_library_view.gd")
const Calibration := preload("res://presentation/calibration_view.gd")
const Results := preload("res://presentation/results_view.gd")

var flow: RefCounted
var repositories: RefCounted
var _content: Control
var _status: Label
var _error_summary: Label
var _technical: RichTextLabel
var _back: Button
var _retry: Button
var _cancel: Button
var _previous := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); flow = Flow.new() if flow == null else flow; repositories = Repositories.new() if repositories == null else repositories; _build_shell()
	var settings: Dictionary = repositories.settings.load(); var songs: Dictionary = repositories.songs.load(); var route: Dictionary = flow.initial_route(settings, songs, OS.get_connected_midi_inputs())
	if route.get("ok", false): _show(flow.state(), false)
	else: _show_error(route)

func _build_shell() -> void:
	var root_layout := VBoxContainer.new(); root_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root_layout)
	var navigation := HBoxContainer.new(); navigation.add_theme_constant_override("separation", 8); root_layout.add_child(navigation)
	var first_button: Button
	for entry: Dictionary in [{"label":"Device", "state":Flow.DEVICE_SETUP}, {"label":"Songs", "state":Flow.SONG_LIBRARY}, {"label":"Calibration", "state":Flow.CALIBRATION}, {"label":"Results", "state":Flow.RESULTS}]:
		var button := Button.new(); button.text = entry["label"]; button.pressed.connect(func() -> void: _navigate(entry["state"])); navigation.add_child(button)
		if first_button == null: first_button = button
	_back = Button.new(); _back.text = "Back"; _back.pressed.connect(_go_back); navigation.add_child(_back)
	_retry = Button.new(); _retry.text = "Retry"; _retry.visible = false; _retry.pressed.connect(func() -> void: _show(flow.state(), false)); navigation.add_child(_retry)
	_cancel = Button.new(); _cancel.text = "Cancel"; _cancel.visible = false; _cancel.pressed.connect(_cancel_operation); navigation.add_child(_cancel)
	_status = Label.new(); _status.text = "BOOT — Checking settings, songs, and MIDI."; navigation.add_child(_status)
	_error_summary = Label.new(); _error_summary.visible = false; _error_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root_layout.add_child(_error_summary)
	_technical = RichTextLabel.new(); _technical.visible = false; _technical.fit_content = true; _technical.custom_minimum_size.y = 70; root_layout.add_child(_technical)
	_content = Control.new(); _content.size_flags_vertical = Control.SIZE_EXPAND_FILL; root_layout.add_child(_content)
	first_button.grab_focus()

func _navigate(next_state: String) -> void:
	var moved: Dictionary = flow.transition(next_state)
	if not moved.get("ok", false): _show_error(flow.failure("navigation", "That screen is not available from the current step.", moved.get("error", "invalid transition"), true)); return
	_show(next_state)

func _show(state: String, remember: bool = true) -> void:
	if remember: _previous = flow.state() if flow.state() != state else _previous
	for child: Node in _content.get_children(): _content.remove_child(child); child.queue_free()
	_error_summary.visible = false; _technical.visible = false; _retry.visible = false; _cancel.visible = false; _status.text = state.replace("_", " ").to_upper()
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
	_error_summary.visible = true; _technical.visible = true; _retry.visible = error.get("actions", []).has("retry"); _cancel.visible = error.get("actions", []).has("cancel"); _error_summary.text = "%s — %s Actions: %s" % [str(error.get("severity", "error")).to_upper(), error.get("user_message", "Operation failed."), ", ".join(error.get("actions", []))]; _technical.text = "Technical details: %s" % error.get("technical_detail", "Unavailable")
	if _retry.visible: _retry.grab_focus()

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
