class_name ResultsView
extends Control

signal play_again_requested
signal song_library_requested

const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const Results := preload("res://application/results_service.gd")
const AppTheme := preload("res://presentation/panbeat_theme.gd")
const RichBackground := preload("res://presentation/rich_ui_background.gd")
const Presenter := preload("res://presentation/product_screen_presenter.gd")

var repositories: RefCounted
var _summary: RichTextLabel
var _history: ItemList
var _status: Label
var _records: Array[Dictionary] = []
var _technical: RichTextLabel
var _delete_button: Button
var _clear_button: Button
var _pending_action := ""
var _pending_target := ""
var completion_actions_enabled := false

func _ready() -> void:
	theme = AppTheme.shared(); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); repositories = Repositories.new() if repositories == null else repositories; _build_ui(); refresh()

func _build_ui() -> void:
	var background := RichBackground.new(); background.intensity = 1.16; add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(key, 40)
	add_child(margin)
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 10); margin.add_child(layout)
	var title := Label.new(); title.text = "RESULTS & HISTORY"; title.add_theme_font_size_override("font_size", 38); layout.add_child(title)
	_status = Label.new(); layout.add_child(_status)
	_summary = RichTextLabel.new(); _summary.fit_content = true; _summary.custom_minimum_size.y = 130; layout.add_child(_summary)
	_technical = RichTextLabel.new(); _technical.fit_content = true; _technical.custom_minimum_size.y = 76; _technical.text = "TECHNICAL DETAILS — Select a result."; layout.add_child(_technical)
	_history = ItemList.new(); _history.custom_minimum_size.y = 220; _history.item_selected.connect(_select); layout.add_child(_history)
	var actions := HBoxContainer.new(); layout.add_child(actions)
	if completion_actions_enabled:
		var play_again := Button.new(); play_again.text = "↻  Play Again"; play_again.theme_type_variation = "PrimaryButton"; play_again.tooltip_text = "Restart the completed song"; play_again.pressed.connect(func() -> void: play_again_requested.emit()); actions.add_child(play_again)
		var song_library := Button.new(); song_library.text = "Song Library"; song_library.tooltip_text = "Choose another song"; song_library.pressed.connect(func() -> void: song_library_requested.emit()); actions.add_child(song_library)
	_delete_button = Button.new(); _delete_button.text = "Delete Selected…"; _delete_button.pressed.connect(_delete_selected); actions.add_child(_delete_button)
	_clear_button = Button.new(); _clear_button.text = "Clear History…"; _clear_button.pressed.connect(_clear); actions.add_child(_clear_button)
	var quit := Button.new(); quit.text = "Quit"; quit.pressed.connect(func() -> void: get_tree().quit(0)); actions.add_child(quit)

static func completion_action_contract() -> Dictionary:
	return {"primary":"play_again", "secondary":"song_library", "process_restart_required":false, "preserves_result_history":true}

func refresh() -> void:
	_reset_confirmation()
	var loaded: Dictionary = repositories.results.load(); if not loaded.get("ok", false): _status.text = "HISTORY ERROR — %s" % loaded.get("error", "unavailable"); return
	var inspected := Results.inspect_history(loaded["document"]); _records = inspected["records"]; _history.clear()
	for record: Dictionary in _records: _history.add_item("%s  %s  Score %d  Accuracy %.1f%%" % [record["completed_at"], record["metadata"]["song_id"], int(record["summary"]["score"]), float(record["summary"]["accuracy"]) * 100.0])
	_status.text = "%d result(s)%s" % [_records.size(), " · %d broken record(s) isolated" % inspected["quarantined"].size() if not inspected["quarantined"].is_empty() else ""]
	if _records.is_empty(): _summary.text = "EMPTY — No results yet. Complete a song to create the first result."; _technical.text = "TECHNICAL DETAILS — No result metadata."; return
	_history.select(0); _show(_records[0])

func _show(record: Dictionary) -> void:
	var sections := Presenter.result_sections(record)
	_summary.text = "%s\n%s\n%s" % [sections["headline"], sections["grades"], sections["timing"]]
	_technical.text = "TECHNICAL DETAILS\n%s" % sections["technical"]

func _select(index: int) -> void:
	_reset_confirmation()
	if index >= 0 and index < _records.size(): _show(_records[index])

func _delete_selected() -> void:
	var selected := _history.get_selected_items(); if selected.is_empty(): _status.text = "Select a result first."; return
	var target: String = _records[selected[0]]["result_id"]
	if _pending_action != "delete" or _pending_target != target:
		var preview := Presenter.destructive_confirmation("delete", target); _pending_action = "delete"; _pending_target = target; _delete_button.text = preview["button"]; _status.text = preview["message"]; _delete_button.grab_focus(); return
	var loaded: Dictionary = repositories.results.load(); var deleted := Results.delete_result(loaded["document"], _records[selected[0]]["result_id"]); if deleted.get("ok", false): repositories.results.save(deleted["document"]); refresh()

func _clear() -> void:
	if _pending_action != "clear":
		var preview := Presenter.destructive_confirmation("clear", "all", _records.size()); _pending_action = "clear"; _pending_target = "all"; _clear_button.text = preview["button"]; _status.text = preview["message"]; _clear_button.grab_focus(); return
	var loaded: Dictionary = repositories.results.load(); if loaded.get("ok", false): repositories.results.save(Results.clear(loaded["document"])); refresh()

func _reset_confirmation() -> void:
	_pending_action = ""; _pending_target = ""
	if _delete_button != null: _delete_button.text = "Delete Selected…"
	if _clear_button != null: _clear_button.text = "Clear History…"
