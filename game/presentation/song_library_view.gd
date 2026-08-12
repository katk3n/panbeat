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

var repository_root := ""
var repositories: RefCounted
var library: RefCounted
var _status: Label
var _list: ItemList
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
var _play: Button
var _background_picker: OptionButton

func _ready() -> void:
	theme = AppTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	repository_root = OS.get_user_data_dir().path_join("v1/songs") if repository_root.is_empty() else repository_root
	if repositories == null: repositories = Repositories.new()
	if library == null: library = Library.new(Files.new())
	_build_ui(); refresh.call_deferred()

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
	var background_row := HBoxContainer.new(); background_row.add_theme_constant_override("separation", 12); layout.add_child(background_row)
	var background_label := Label.new(); background_label.text = "GAMEPLAY BACKGROUND"; background_label.add_theme_color_override("font_color", Color("d6b66d")); background_row.add_child(background_label)
	_background_picker = OptionButton.new(); _background_picker.custom_minimum_size.x = 260
	for preset: Dictionary in BackgroundPresets.all():
		_background_picker.add_item(str(preset["label"])); _background_picker.set_item_metadata(_background_picker.item_count - 1, preset["id"])
	_background_picker.item_selected.connect(_on_background_selected); background_row.add_child(_background_picker)
	var background_hint := Label.new(); background_hint.text = "Saved per song; applied when gameplay starts."; background_row.add_child(background_hint)
	_select_background_id(_global_background_id())
	var manage_label := Label.new(); manage_label.text = "LIBRARY MANAGEMENT — IMPORT / RE-IMPORT / DELETE"; manage_label.add_theme_color_override("font_color", Color("aaa79f")); layout.add_child(manage_label)
	var actions := HBoxContainer.new(); layout.add_child(actions)
	_title_input = LineEdit.new(); _title_input.placeholder_text = "Song title"; _title_input.custom_minimum_size.x = 190; actions.add_child(_title_input)
	_score_button = Button.new(); _score_button.text = "Choose Score…"; _score_button.pressed.connect(func() -> void: _choose_file("score")); actions.add_child(_score_button)
	_audio_button = Button.new(); _audio_button.text = "Choose Audio…"; _audio_button.pressed.connect(func() -> void: _choose_file("audio")); actions.add_child(_audio_button)
	_overlay_button = Button.new(); _overlay_button.text = "Overlay (optional)…"; _overlay_button.pressed.connect(func() -> void: _choose_file("overlay")); actions.add_child(_overlay_button)
	var import_button := Button.new(); import_button.text = "Import"; import_button.tooltip_text = "Validate and import selected MusicXML and audio"; import_button.pressed.connect(func() -> void: _run_import(false)); actions.add_child(import_button)
	var reimport := Button.new(); reimport.text = "Re-import"; reimport.pressed.connect(func() -> void: _run_import(true)); actions.add_child(reimport)
	_delete = Button.new(); _delete.text = "Delete…"; _delete.pressed.connect(_on_delete); actions.add_child(_delete)
	_list = ItemList.new(); _list.custom_minimum_size.y = 240; _list.item_selected.connect(_on_selected); layout.add_child(_list)
	_details = RichTextLabel.new(); _details.fit_content = true; _details.custom_minimum_size.y = 170; _details.text = "Select a song to view validation diagnostics."; layout.add_child(_details)
	import_button.grab_focus()

func _choose_file(kind: String) -> void:
	var dialog := FileDialog.new(); dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.use_native_dialog = true
	match kind:
		"score": dialog.filters = PackedStringArray(["*.musicxml, *.xml, *.mxl ; MusicXML score"])
		"audio": dialog.filters = PackedStringArray(["*.wav, *.ogg ; WAV or Ogg audio"])
		"overlay": dialog.filters = PackedStringArray(["*.json ; PanBeat overlay"])
	dialog.file_selected.connect(func(path: String) -> void:
		match kind:
			"score": _score_path = path; _score_button.text = path.get_file()
			"audio": _audio_path = path; _audio_button.text = path.get_file()
			"overlay": _overlay_path = path; _overlay_button.text = path.get_file()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); add_child(dialog); dialog.popup_centered_ratio(0.75)

func _run_import(reimport: bool) -> void:
	if _score_path.is_empty() or _audio_path.is_empty(): _details.text = "IMPORT INPUT REQUIRED — Choose a MusicXML score and WAV/Ogg audio file."; return
	if reimport and _pending_delete.is_empty(): _details.text = "Select an existing song before Re-import."; return
	var profile_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	if profile_value is not Dictionary: _details.text = "IMPORT FAILED — Instrument Profile could not be loaded."; return
	var song_id := _pending_delete if reimport else _portable_id(_title_input.text if not _title_input.text.strip_edges().is_empty() else _score_path.get_file().get_basename())
	var request := {"score_path":_score_path, "audio_path":_audio_path, "overlay_path":_overlay_path, "profile":profile_value, "song_id":song_id, "title":_title_input.text if not _title_input.text.strip_edges().is_empty() else song_id}
	var result: Dictionary = Importer.new(Files.new(), AudioConverter.new()).import_song(request, repository_root, repositories.songs)
	if result.get("ok", false): _details.text = "IMPORTED — %s%s" % [result.get("song", {}).get("title", song_id), " (duplicate content)" if result.get("duplicate", false) else ""] ; refresh()
	else:
		var lines: Array[String] = ["IMPORT FAILED"]
		for diagnostic: Dictionary in result.get("diagnostics", []): lines.append("%s: %s\nFix: %s" % [diagnostic.get("code", "unknown"), diagnostic.get("message", ""), diagnostic.get("remediation", "")])
		_details.text = "\n".join(lines)

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
	_list.clear(); _pending_delete = ""; _play.disabled = true
	_select_background_id(_global_background_id())
	for song: Dictionary in _songs:
		var marker: String = str({"valid":"VALID", "warning":"WARNING", "invalid":"INVALID"}.get(song.get("display_status", "invalid"), "INVALID"))
		var duration := float(song.get("duration_us", 0)) / 1000000.0
		_list.add_item("%s — %s · %s · %.1fs · chart %s · profile %s · %s" % [marker, song.get("title", song.get("song_id", "Untitled")), song.get("artist", ""), duration, song.get("chart_schema_version", "unknown"), song.get("profile_compatibility", "unknown"), song.get("artwork_label", "No artwork")])
	if _songs.is_empty(): _details.text = "EMPTY — No local songs. Import MusicXML and audio to begin."

func _on_selected(index: int) -> void:
	if index < 0 or index >= _songs.size(): return
	var song := _songs[index]; _pending_delete = str(song.get("song_id", "")); _play.disabled = song.get("display_status") != "valid"; var lines: Array[String] = ["%s — import v%s" % [song.get("title", _pending_delete), song.get("import_version", "?")]]
	var selected_background := _resolved_background_id(_pending_delete); _select_background_id(selected_background); lines.append("BACKGROUND — %s" % BackgroundPresets.preset(selected_background).get("label", selected_background))
	for diagnostic: Dictionary in song.get("diagnostics", []): lines.append("%s %s: %s\nFix: %s" % [str(diagnostic.get("severity", "error")).to_upper(), diagnostic.get("code", "unknown"), diagnostic.get("message", ""), diagnostic.get("remediation", "")])
	if song.get("diagnostics", []).is_empty(): lines.append("VALID — No import diagnostics.")
	_details.text = "\n".join(lines)

func _play_selected() -> void:
	if _pending_delete.is_empty(): _details.text = "Select a valid song before playing."; return
	for song: Dictionary in _songs:
		if song.get("song_id") == _pending_delete and song.get("display_status") == "valid": play_requested.emit(repository_root.path_join(str(song["package_path"]))); return
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

func _on_delete() -> void:
	if _pending_delete.is_empty(): _details.text = "Select a song before deleting."; return
	var preview: Dictionary = library.delete_preview(repository_root, repositories.songs, _pending_delete)
	if not preview.get("ok", false): _details.text = "DELETE FAILED — %s" % str(preview); return
	if _delete.text != "Confirm Delete": _delete.text = "Confirm Delete"; _details.text = preview["message"]; return
	var result: Dictionary = library.delete_song(repository_root, repositories.songs, _pending_delete, true)
	_delete.text = "Delete…"; _details.text = "DELETED — Original source files were not changed." if result.get("ok", false) else "DELETE FAILED — %s" % str(result); refresh()
