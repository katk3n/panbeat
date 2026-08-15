class_name SongLibraryView
extends Control

const AppTheme := preload("res://presentation/panbeat_theme.gd")
const RichBackground := preload("res://presentation/rich_ui_background.gd")

signal play_requested(package_path: String)

const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Library := preload("res://application/song_library_service.gd")
const Importer := preload("res://application/song_import_service.gd")
const AudioConverter := preload("res://infrastructure/ffmpeg_audio_converter.gd")
const BackgroundPresets := preload("res://application/background_preset_catalog.gd")
const NoteScrollSpeeds := preload("res://application/note_scroll_speed_catalog.gd")
const PracticeTempos := preload("res://application/practice_tempo_catalog.gd")
const MidiAdapter := preload("res://infrastructure/godot_midi_adapter.gd")
const PerformanceLayouts := preload("res://application/performance_layout_service.gd")
const HandpanLayout := preload("res://presentation/handpan_layout_view.gd")

var repository_root := ""
var repositories: RefCounted
var library: RefCounted
var _status: Label
var _list: Tree
var _details: RichTextLabel
var _delete: Button
var _pending_delete := ""
var _songs: Array[Dictionary] = []
var _score_path := ""
var _audio_path := ""
var _overlay_path := ""
var _title_input: LineEdit
var _score_button: Button
var _audio_button: Button
var _overlay_button: Button
var _import_dialog: Window
var _import_message: Label
var _import_scroll: ScrollContainer
var _import_reimport := false
var _play: Button
var _background_picker: OptionButton
var _note_scroll_speed_picker: OptionButton
var _practice_tempo_picker: OptionButton
var _written_octave_high: CheckBox
var _layout_status: Label
var _handpan_layout: Control
var _midi_adapter: Node
var _selected_layout: Dictionary = {}
var _verified_targets: Dictionary = {}

func _ready() -> void:
	theme = AppTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	repository_root = OS.get_user_data_dir().path_join("v1/songs") if repository_root.is_empty() else repository_root
	if repositories == null: repositories = Repositories.new()
	if library == null: library = Library.new(Files.new())
	_build_ui()
	_midi_adapter = MidiAdapter.new(); _midi_adapter.profile = _base_profile(); _midi_adapter.record_received.connect(_on_layout_midi_record); add_child(_midi_adapter)
	refresh.call_deferred()

func _build_ui() -> void:
	var background := RichBackground.new(); background.intensity = 1.18; add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(key, 40)
	add_child(margin)
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 12); margin.add_child(layout)
	var title := Label.new(); title.text = "SONG LIBRARY"; title.add_theme_font_size_override("font_size", 38); layout.add_child(title)
	_status = Label.new(); _status.text = library.loading_state()["label"]; _status.add_theme_font_size_override("font_size", 18); layout.add_child(_status)
	var primary_actions := HBoxContainer.new(); layout.add_child(primary_actions)
	_play = Button.new(); _play.text = "▶  Play Selected"; _play.theme_type_variation = "PrimaryButton"; _play.custom_minimum_size = Vector2(190, 48); _play.disabled = true; _play.pressed.connect(_play_selected); primary_actions.add_child(_play)
	var primary_hint := Label.new(); primary_hint.text = "Select a compatible song below, then play."; primary_actions.add_child(primary_hint)
	var refresh_button := Button.new(); refresh_button.text = "Refresh"; refresh_button.pressed.connect(refresh); primary_actions.add_child(refresh_button)
	var import_button := Button.new(); import_button.text = "Import Song…"; import_button.tooltip_text = "Import a MusicXML or NotePan score"; import_button.pressed.connect(func() -> void: _open_import_dialog(false)); primary_actions.add_child(import_button)
	var reimport := Button.new(); reimport.text = "Re-import Selected…"; reimport.pressed.connect(func() -> void: _open_import_dialog(true)); primary_actions.add_child(reimport)
	_delete = Button.new(); _delete.text = "Delete…"; _delete.pressed.connect(_on_delete); primary_actions.add_child(_delete)
	var settings_row := HBoxContainer.new(); settings_row.add_theme_constant_override("separation", 12); layout.add_child(settings_row)
	var background_label := Label.new(); background_label.text = "BACKGROUND"; background_label.add_theme_color_override("font_color", Color("d6b66d")); settings_row.add_child(background_label)
	_background_picker = OptionButton.new(); _background_picker.custom_minimum_size.x = 260
	for preset: Dictionary in BackgroundPresets.all():
		_background_picker.add_item(str(preset["label"])); _background_picker.set_item_metadata(_background_picker.item_count - 1, preset["id"])
	_background_picker.tooltip_text = "Gameplay background; saved per song"
	_background_picker.item_selected.connect(_on_background_selected); settings_row.add_child(_background_picker)
	_select_background_id(_global_background_id())
	var speed_label := Label.new(); speed_label.text = "NOTE SPEED"; speed_label.add_theme_color_override("font_color", Color("d6b66d")); settings_row.add_child(speed_label)
	_note_scroll_speed_picker = OptionButton.new(); _note_scroll_speed_picker.custom_minimum_size.x = 260
	for preset: Dictionary in NoteScrollSpeeds.all():
		_note_scroll_speed_picker.add_item(str(preset["label"])); _note_scroll_speed_picker.set_item_metadata(_note_scroll_speed_picker.item_count - 1, preset["id"])
	_note_scroll_speed_picker.tooltip_text = "Faster speeds reduce overlapping notes; saved per song"
	_note_scroll_speed_picker.item_selected.connect(_on_note_scroll_speed_selected); settings_row.add_child(_note_scroll_speed_picker)
	_select_note_scroll_speed_id(_global_note_scroll_speed_id())
	var tempo_label := Label.new(); tempo_label.text = "TEMPO"; tempo_label.add_theme_color_override("font_color", Color("d6b66d")); settings_row.add_child(tempo_label)
	_practice_tempo_picker = OptionButton.new(); _practice_tempo_picker.custom_minimum_size.x = 190
	for preset: Dictionary in PracticeTempos.all():
		_practice_tempo_picker.add_item(str(preset["label"])); _practice_tempo_picker.set_item_metadata(_practice_tempo_picker.item_count - 1, preset["id"])
	_practice_tempo_picker.tooltip_text = "Slow audio without changing pitch, with notes and judgement kept in sync; saved per song"
	_practice_tempo_picker.item_selected.connect(_on_practice_tempo_selected); settings_row.add_child(_practice_tempo_picker)
	_select_practice_tempo_id(_global_practice_tempo_id())
	_list = Tree.new(); _list.columns = 5; _list.column_titles_visible = true; _list.hide_root = true; _list.select_mode = Tree.SELECT_ROW; _list.custom_minimum_size.y = 150; _list.size_flags_vertical = Control.SIZE_EXPAND_FILL; _list.size_flags_stretch_ratio = 2.0
	for column: int in 5: _list.set_column_title(column, ["STATUS", "TITLE", "ARTIST", "SCALE", "DURATION"][column])
	_list.set_column_expand(0, false); _list.set_column_custom_minimum_width(0, 105)
	_list.set_column_expand(1, true); _list.set_column_custom_minimum_width(1, 260)
	_list.set_column_expand(2, true); _list.set_column_custom_minimum_width(2, 190)
	_list.set_column_expand(3, false); _list.set_column_custom_minimum_width(3, 155)
	_list.set_column_expand(4, false); _list.set_column_custom_minimum_width(4, 95)
	_list.item_selected.connect(_on_list_selected); layout.add_child(_list)
	var selection_detail := HBoxContainer.new(); selection_detail.add_theme_constant_override("separation", 20); selection_detail.custom_minimum_size.y = 250; selection_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL; selection_detail.size_flags_stretch_ratio = 1.15; layout.add_child(selection_detail)
	var detail_column := VBoxContainer.new(); detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; selection_detail.add_child(detail_column)
	_layout_status = Label.new(); _layout_status.visible = false; _layout_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail_column.add_child(_layout_status)
	_details = RichTextLabel.new(); _details.fit_content = false; _details.size_flags_vertical = Control.SIZE_EXPAND_FILL; detail_column.add_child(_details)
	_handpan_layout = HandpanLayout.new(); _handpan_layout.visible = false; _handpan_layout.size_flags_horizontal = Control.SIZE_SHRINK_END; _handpan_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL; selection_detail.add_child(_handpan_layout)
	_build_import_dialog()
	_play.grab_focus()

func _build_import_dialog() -> void:
	_import_dialog = Window.new(); _import_dialog.title = "Import Song"; _import_dialog.size = Vector2i(720, 560); _import_dialog.min_size = Vector2i(640, 540); _import_dialog.visible = false; _import_dialog.transient = true; _import_dialog.exclusive = true; _import_dialog.unresizable = true; _import_dialog.theme = AppTheme.shared(); _import_dialog.close_requested.connect(_import_dialog.hide); add_child(_import_dialog)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(key, 24)
	_import_dialog.add_child(margin)
	var dialog_layout := VBoxContainer.new(); dialog_layout.add_theme_constant_override("separation", 12); margin.add_child(dialog_layout)
	_import_scroll = ScrollContainer.new(); _import_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; _import_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _import_scroll.follow_focus = true; dialog_layout.add_child(_import_scroll)
	var form := VBoxContainer.new(); form.add_theme_constant_override("separation", 10); form.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _import_scroll.add_child(form)
	var heading := Label.new(); heading.text = "Choose the score and optional playback assets."; heading.add_theme_font_size_override("font_size", 20); form.add_child(heading)
	var title_label := Label.new(); title_label.text = "SONG TITLE (OPTIONAL)"; title_label.add_theme_color_override("font_color", Color("d6b66d")); form.add_child(title_label)
	_title_input = LineEdit.new(); _title_input.placeholder_text = "Use the score title when empty"; form.add_child(_title_input)
	var score_label := Label.new(); score_label.text = "SCORE"; score_label.add_theme_color_override("font_color", Color("d6b66d")); form.add_child(score_label)
	_score_button = Button.new(); _score_button.text = "Choose MusicXML or NotePan…"; _score_button.clip_text = true; _score_button.pressed.connect(func() -> void: _choose_file("score")); form.add_child(_score_button)
	var audio_label := Label.new(); audio_label.text = "BACKING AUDIO (OPTIONAL)"; audio_label.add_theme_color_override("font_color", Color("d6b66d")); form.add_child(audio_label)
	var audio_row := HBoxContainer.new(); form.add_child(audio_row)
	_audio_button = Button.new(); _audio_button.text = "Choose WAV or Ogg…"; _audio_button.clip_text = true; _audio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _audio_button.pressed.connect(func() -> void: _choose_file("audio")); audio_row.add_child(_audio_button)
	var clear_audio := Button.new(); clear_audio.text = "No Audio"; clear_audio.tooltip_text = "Import without backing audio; Mood Pan provides the sound"; clear_audio.pressed.connect(_clear_audio); audio_row.add_child(clear_audio)
	var overlay_label := Label.new(); overlay_label.text = "PANBEAT OVERLAY (OPTIONAL)"; overlay_label.add_theme_color_override("font_color", Color("d6b66d")); form.add_child(overlay_label)
	_overlay_button = Button.new(); _overlay_button.text = "Choose Overlay…"; _overlay_button.clip_text = true; _overlay_button.pressed.connect(func() -> void: _choose_file("overlay")); form.add_child(_overlay_button)
	_written_octave_high = CheckBox.new(); _written_octave_high.text = "Written 1 octave high"; _written_octave_high.tooltip_text = "Map every written pitch to the Mood Pan note one octave lower"; form.add_child(_written_octave_high)
	_import_message = Label.new(); _import_message.visible = false; _import_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _import_message.add_theme_color_override("font_color", Color("ef8f8f")); form.add_child(_import_message)
	var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_END; dialog_layout.add_child(buttons)
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.pressed.connect(_import_dialog.hide); buttons.add_child(cancel)
	var submit := Button.new(); submit.text = "Import"; submit.theme_type_variation = "PrimaryButton"; submit.pressed.connect(func() -> void: _run_import(_import_reimport)); buttons.add_child(submit)

func _open_import_dialog(reimport: bool) -> void:
	if reimport and _pending_delete.is_empty():
		_layout_status.visible = true; _layout_status.add_theme_color_override("font_color", Color("e0bc67")); _layout_status.text = "WARNING — Select a song before re-importing."
		return
	_import_reimport = reimport; _import_dialog.title = "Re-import Song" if reimport else "Import Song"; _import_message.visible = false; _import_message.text = ""
	_import_scroll.scroll_vertical = 0
	if reimport:
		for song: Dictionary in _songs:
			if song.get("song_id") == _pending_delete: _title_input.text = str(song.get("title", "")); break
	_import_dialog.popup_centered()

func _choose_file(kind: String) -> void:
	var dialog := FileDialog.new(); dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.use_native_dialog = true
	match kind:
		"score": dialog.filters = PackedStringArray(["*.musicxml, *.xml, *.mxl, *.pan ; MusicXML or NotePan score"])
		"audio": dialog.filters = PackedStringArray(["*.wav, *.ogg ; WAV or Ogg audio"])
		"overlay": dialog.filters = PackedStringArray(["*.json ; PanBeat overlay"])
	dialog.file_selected.connect(func(path: String) -> void:
		_apply_chosen_file(kind, path)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); add_child(dialog); dialog.popup_centered_ratio(0.75)

func _run_import(reimport: bool) -> void:
	if _score_path.is_empty(): _show_import_error("Choose a MusicXML or NotePan score."); return
	if reimport and _pending_delete.is_empty(): _show_import_error("Select an existing song before re-importing."); return
	var profile_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	if profile_value is not Dictionary: _show_import_error("Instrument Profile could not be loaded."); return
	var song_id := _pending_delete if reimport else _portable_id(_title_input.text if not _title_input.text.strip_edges().is_empty() else _score_path.get_file().get_basename())
	var request := {"score_path":_score_path, "audio_path":_audio_path, "overlay_path":_overlay_path, "profile":profile_value, "notation_octave_shift":-1 if _written_octave_high.button_pressed else 0, "song_id":song_id, "title":_title_input.text.strip_edges()}
	var result: Dictionary = Importer.new(Files.new(), AudioConverter.new()).import_song(request, repository_root, repositories.songs)
	if result.get("ok", false):
		_import_dialog.hide(); refresh()
	else:
		var lines: Array[String] = ["IMPORT FAILED"]
		for diagnostic: Dictionary in result.get("diagnostics", []): lines.append("%s: %s\nFix: %s" % [diagnostic.get("code", "unknown"), diagnostic.get("message", ""), diagnostic.get("remediation", "")])
		_show_import_error("\n".join(lines))

func _show_import_error(message: String) -> void:
	_import_message.text = "ERROR — %s" % message; _import_message.visible = true

func _clear_audio() -> void:
	_audio_path = ""
	_audio_button.text = "Choose WAV or Ogg…"
	_audio_button.tooltip_text = "Optional backing audio; leave empty to hear Mood Pan only"

func _apply_chosen_file(kind: String, path: String) -> void:
	match kind:
		"score":
			_score_path = path; _score_button.text = "Score ✓  %s" % path.get_file(); _score_button.tooltip_text = path; _update_score_options()
		"audio":
			_audio_path = path; _audio_button.text = "Audio ✓  %s" % path.get_file(); _audio_button.tooltip_text = path
		"overlay":
			_overlay_path = path; _overlay_button.text = "Overlay ✓  %s" % path.get_file(); _overlay_button.tooltip_text = path

func _update_score_options() -> void:
	var is_notepan := _score_path.get_extension().to_lower() == "pan"
	_overlay_button.disabled = is_notepan
	_written_octave_high.disabled = is_notepan
	if is_notepan:
		_overlay_path = ""; _overlay_button.text = "Overlay (N/A)"; _overlay_button.tooltip_text = "PanBeat overlay is available only for MusicXML sources"
		_written_octave_high.button_pressed = false
	else:
		_overlay_button.text = "Choose Overlay…" if _overlay_path.is_empty() else "Overlay ✓  %s" % _overlay_path.get_file()
		_overlay_button.tooltip_text = "Optional source-bound PanBeat overlay for MusicXML" if _overlay_path.is_empty() else _overlay_path

func _portable_id(source: String) -> String:
	var result := ""
	for index: int in source.length():
		var character := source.substr(index, 1); result += character if character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" else "-"
	while result.begins_with("-"): result = result.trim_prefix("-")
	while result.ends_with("-"): result = result.trim_suffix("-")
	return result if not result.is_empty() else "imported-song"

func refresh() -> void:
	var queried: Dictionary = library.query(repository_root, repositories.songs, "roland-mn10-handpan-minor-v1")
	_status.text = str(queried.get("label", "LIBRARY ERROR")); _songs.clear()
	for value: Variant in queried.get("songs", []):
		if value is Dictionary: _songs.append((value as Dictionary).duplicate(true))
	_list.clear(); var tree_root := _list.create_item(); _pending_delete = ""; _play.disabled = true; _selected_layout = {}; _verified_targets.clear(); _handpan_layout.show_layout({}); _layout_status.visible = false; _layout_status.text = ""; _details.text = ""
	_select_background_id(_global_background_id())
	_select_note_scroll_speed_id(_global_note_scroll_speed_id())
	_select_practice_tempo_id(_global_practice_tempo_id())
	for index: int in _songs.size():
		var song := _songs[index]; var values := song_row_values(song); var item := _list.create_item(tree_root); item.set_metadata(0, index)
		for column: int in values.size(): item.set_text(column, values[column]); item.set_tooltip_text(column, values[column])
		item.set_custom_color(0, _status_color(str(song.get("display_status", "invalid"))))

static func song_row_values(song: Dictionary) -> PackedStringArray:
	var marker: String = str({"valid":"VALID", "warning":"WARN", "invalid":"INVALID"}.get(song.get("display_status", "invalid"), "INVALID"))
	var title := str(song.get("title", song.get("song_id", "Untitled")))
	var artist := str(song.get("artist", "")); if artist.is_empty(): artist = "Unknown artist"
	var scale := str(song.get("handpan_scale_name", "")); if scale.is_empty(): scale = "Not specified"
	var duration := "%.1f s" % (float(song.get("duration_us", 0)) / 1000000.0)
	return PackedStringArray([marker, title, artist, scale, duration])

static func _status_color(status: String) -> Color:
	return {"valid":Color("8fd3a7"), "warning":Color("e0bc67"), "invalid":Color("ef8f8f")}.get(status, Color("ef8f8f"))

func _on_list_selected() -> void:
	var selected := _list.get_selected()
	if selected != null: _on_selected(int(selected.get_metadata(0)))

func _select_song_row(index: int) -> void:
	var root_item := _list.get_root()
	if root_item == null or index < 0 or index >= root_item.get_child_count(): return
	root_item.get_child(index).select(0); _on_selected(index)

func _on_selected(index: int) -> void:
	if index < 0 or index >= _songs.size(): return
	var song := _songs[index]; _pending_delete = str(song.get("song_id", "")); _play.disabled = not bool(song.get("playable", false)); var lines: Array[String] = []
	var scale_name := str(song.get("handpan_scale_name", ""))
	_selected_layout = song.get("performance_layout", {}).duplicate(true); _verified_targets.clear()
	_layout_status.visible = false; _layout_status.text = ""
	if not _selected_layout.is_empty():
		_handpan_layout.show_layout(_selected_layout, scale_name)
		_midi_adapter.profile = PerformanceLayouts.effective_profile(_base_profile(), _selected_layout)
	else:
		_handpan_layout.show_layout({})
		_midi_adapter.profile = _base_profile(); _layout_status.visible = true; _layout_status.add_theme_color_override("font_color", Color("e0bc67")); _layout_status.text = "WARNING — Re-import this song to generate its handpan map."
	for diagnostic: Dictionary in song.get("diagnostics", []): lines.append("%s %s: %s\nFix: %s" % [str(diagnostic.get("severity", "error")).to_upper(), diagnostic.get("code", "unknown"), diagnostic.get("message", ""), diagnostic.get("remediation", "")])
	var selected_background := _resolved_background_id(_pending_delete); _select_background_id(selected_background)
	var selected_speed := _resolved_note_scroll_speed_id(_pending_delete); _select_note_scroll_speed_id(selected_speed)
	var selected_tempo := _resolved_practice_tempo_id(_pending_delete); _select_practice_tempo_id(selected_tempo)
	_details.text = "\n".join(lines)

func _on_layout_midi_record(raw: Dictionary, _normalized: Dictionary) -> void:
	if _selected_layout.is_empty() or raw.get("message_type") != "note_on" or int(raw.get("data2", 0)) <= 0: return
	var midi := int(raw.get("data1", -1)); var matched: Dictionary = {}
	for slot: Dictionary in _selected_layout.get("slots", []):
		if int(slot.get("midi_note", -2)) == midi: matched = slot; break
	if matched.is_empty():
		_handpan_layout.show_midi_target("")
		_layout_status.visible = true
		_layout_status.add_theme_color_override("font_color", Color("ef8f8f"))
		_layout_status.text = "ERROR — Unexpected %s (MIDI %d). This note is not used by the selected song." % [PerformanceLayouts.midi_label(midi), midi]
		return
	_verified_targets[str(matched["target_id"])] = true
	_handpan_layout.show_midi_target(str(matched["target_id"]))
	_layout_status.visible = false; _layout_status.text = ""

func _base_profile() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	return value as Dictionary if value is Dictionary else {}

func _play_selected() -> void:
	if _pending_delete.is_empty(): _details.text = "Select a valid song before playing."; return
	for song: Dictionary in _songs:
		if song.get("song_id") == _pending_delete and bool(song.get("playable", false)): play_requested.emit(repository_root.path_join(str(song["package_path"]))); return
	_details.text = "PLAY UNAVAILABLE — Re-import the selected song or choose a compatible valid package."

func _on_background_selected(index: int) -> void:
	if index < 0 or index >= _background_picker.item_count: return
	var preset_id := str(_background_picker.get_item_metadata(index))
	var loaded: Dictionary = repositories.settings.load()
	if not loaded.get("ok", false): _status.text = "BACKGROUND SAVE FAILED — Settings unavailable."; return
	var settings: Dictionary = loaded["document"]
	if _pending_delete.is_empty(): settings["background_preset_id"] = preset_id
	else: settings = BackgroundPresets.assign_to_song(settings, _pending_delete, preset_id)
	var saved: Dictionary = repositories.settings.save(settings)
	_status.text = "BACKGROUND SAVED — %s%s" % [BackgroundPresets.preset(preset_id).get("label", preset_id), " for %s" % _pending_delete if not _pending_delete.is_empty() else " as default"] if saved.get("ok", false) else "BACKGROUND SAVE FAILED — %s" % saved.get("error", "storage error")

func _global_background_id() -> String:
	var loaded: Dictionary = repositories.settings.load()
	return BackgroundPresets.resolve({}, loaded.get("document", {}) if loaded.get("ok", false) else {})

func _resolved_background_id(song_id: String) -> String:
	var loaded: Dictionary = repositories.settings.load()
	return BackgroundPresets.resolve({"song_id":song_id}, loaded.get("document", {}) if loaded.get("ok", false) else {})

func _select_background_id(preset_id: String) -> void:
	if _background_picker == null: return
	for index: int in _background_picker.item_count:
		if str(_background_picker.get_item_metadata(index)) == preset_id: _background_picker.select(index); return

func _on_note_scroll_speed_selected(index: int) -> void:
	if index < 0 or index >= _note_scroll_speed_picker.item_count: return
	var preset_id := str(_note_scroll_speed_picker.get_item_metadata(index))
	var loaded: Dictionary = repositories.settings.load()
	if not loaded.get("ok", false): _status.text = "NOTE SPEED SAVE FAILED — Settings unavailable."; return
	var settings: Dictionary = loaded["document"]
	if _pending_delete.is_empty(): settings["note_scroll_speed_id"] = preset_id
	else: settings = NoteScrollSpeeds.assign_to_song(settings, _pending_delete, preset_id)
	var saved: Dictionary = repositories.settings.save(settings)
	_status.text = "NOTE SPEED SAVED — %s%s" % [NoteScrollSpeeds.preset(preset_id).get("label", preset_id), " for %s" % _pending_delete if not _pending_delete.is_empty() else " as default"] if saved.get("ok", false) else "NOTE SPEED SAVE FAILED — %s" % saved.get("error", "storage error")

func _global_note_scroll_speed_id() -> String:
	var loaded: Dictionary = repositories.settings.load()
	return NoteScrollSpeeds.resolve({}, loaded.get("document", {}) if loaded.get("ok", false) else {})

func _resolved_note_scroll_speed_id(song_id: String) -> String:
	var loaded: Dictionary = repositories.settings.load()
	return NoteScrollSpeeds.resolve({"song_id":song_id}, loaded.get("document", {}) if loaded.get("ok", false) else {})

func _select_note_scroll_speed_id(preset_id: String) -> void:
	if _note_scroll_speed_picker == null: return
	for index: int in _note_scroll_speed_picker.item_count:
		if str(_note_scroll_speed_picker.get_item_metadata(index)) == preset_id: _note_scroll_speed_picker.select(index); return

func _on_practice_tempo_selected(index: int) -> void:
	if index < 0 or index >= _practice_tempo_picker.item_count: return
	var preset_id := str(_practice_tempo_picker.get_item_metadata(index))
	var loaded: Dictionary = repositories.settings.load()
	if not loaded.get("ok", false): _status.text = "PRACTICE TEMPO SAVE FAILED — Settings unavailable."; return
	var settings: Dictionary = loaded["document"]
	if _pending_delete.is_empty(): settings["practice_tempo_id"] = preset_id
	else: settings = PracticeTempos.assign_to_song(settings, _pending_delete, preset_id)
	var saved: Dictionary = repositories.settings.save(settings)
	_status.text = "PRACTICE TEMPO SAVED — %s%s" % [PracticeTempos.preset(preset_id).get("label", preset_id), " for %s" % _pending_delete if not _pending_delete.is_empty() else " as default"] if saved.get("ok", false) else "PRACTICE TEMPO SAVE FAILED — %s" % saved.get("error", "storage error")

func _global_practice_tempo_id() -> String:
	var loaded: Dictionary = repositories.settings.load()
	return PracticeTempos.resolve({}, loaded.get("document", {}) if loaded.get("ok", false) else {})

func _resolved_practice_tempo_id(song_id: String) -> String:
	var loaded: Dictionary = repositories.settings.load()
	return PracticeTempos.resolve({"song_id":song_id}, loaded.get("document", {}) if loaded.get("ok", false) else {})

func _select_practice_tempo_id(preset_id: String) -> void:
	if _practice_tempo_picker == null: return
	for index: int in _practice_tempo_picker.item_count:
		if str(_practice_tempo_picker.get_item_metadata(index)) == preset_id: _practice_tempo_picker.select(index); return

func _on_delete() -> void:
	if _pending_delete.is_empty(): _details.text = "Select a song before deleting."; return
	var preview: Dictionary = library.delete_preview(repository_root, repositories.songs, _pending_delete)
	if not preview.get("ok", false): _details.text = "DELETE FAILED — %s" % str(preview); return
	if _delete.text != "Confirm Delete": _delete.text = "Confirm Delete"; _details.text = preview["message"]; return
	var result: Dictionary = library.delete_song(repository_root, repositories.songs, _pending_delete, true)
	_delete.text = "Delete…"; _details.text = "DELETED — Original source files were not changed." if result.get("ok", false) else "DELETE FAILED — %s" % str(result); refresh()
