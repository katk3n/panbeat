class_name ResultsView
extends Control

const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const Results := preload("res://application/results_service.gd")

var repositories: RefCounted
var _summary: RichTextLabel
var _history: ItemList
var _status: Label
var _records: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); repositories = Repositories.new() if repositories == null else repositories; _build_ui(); refresh()

func _build_ui() -> void:
	var background := ColorRect.new(); background.color = Color("101620"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(key, 40)
	add_child(margin)
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 10); margin.add_child(layout)
	var title := Label.new(); title.text = "RESULTS & HISTORY"; title.add_theme_font_size_override("font_size", 30); layout.add_child(title)
	_status = Label.new(); layout.add_child(_status)
	_summary = RichTextLabel.new(); _summary.fit_content = true; _summary.custom_minimum_size.y = 225; layout.add_child(_summary)
	_history = ItemList.new(); _history.custom_minimum_size.y = 220; _history.item_selected.connect(_select); layout.add_child(_history)
	var actions := HBoxContainer.new(); layout.add_child(actions)
	var delete := Button.new(); delete.text = "Delete Selected"; delete.pressed.connect(_delete_selected); actions.add_child(delete)
	var clear := Button.new(); clear.text = "Clear History"; clear.pressed.connect(_clear); actions.add_child(clear)
	var quit := Button.new(); quit.text = "Quit"; quit.pressed.connect(func() -> void: get_tree().quit(0)); actions.add_child(quit)

func refresh() -> void:
	var loaded: Dictionary = repositories.results.load(); if not loaded.get("ok", false): _status.text = "HISTORY ERROR — %s" % loaded.get("error", "unavailable"); return
	var inspected := Results.inspect_history(loaded["document"]); _records = inspected["records"]; _history.clear()
	for record: Dictionary in _records: _history.add_item("%s  %s  Score %d  Accuracy %.1f%%" % [record["completed_at"], record["metadata"]["song_id"], int(record["summary"]["score"]), float(record["summary"]["accuracy"]) * 100.0])
	_status.text = "%d result(s)%s" % [_records.size(), " · %d broken record(s) isolated" % inspected["quarantined"].size() if not inspected["quarantined"].is_empty() else ""]
	if _records.is_empty(): _summary.text = "No results yet."; return
	_history.select(0); _show(_records[0])

func _show(record: Dictionary) -> void:
	var summary: Dictionary = record["summary"]; var timing: Dictionary = record["timing_distribution"]; var errors: Dictionary = record.get("error_breakdown", {})
	_summary.text = "Song: %s\nScore: %d · Accuracy: %.2f%% · Max Combo: %d\nGrades: PERFECT %d · GREAT %d · GOOD %d · MISS %d · EXTRA HIT %d\nTiming: EARLY %d · ON TIME %d · LATE %d · Median %s\nIdentity errors: WRONG TARGET %d · WRONG TECHNIQUE %d · NO CANDIDATE %d\nVersions: importer %s · chart %s · profile %s · judgement %s · score %s" % [record["metadata"]["song_id"], int(summary["score"]), float(summary["accuracy"]) * 100.0, int(summary["max_combo"]), int(summary["breakdown"]["perfect"]), int(summary["breakdown"]["great"]), int(summary["breakdown"]["good"]), int(summary["breakdown"]["miss"]), int(summary["breakdown"]["extra_hit"]), int(timing["early_count"]), int(timing["on_time_count"]), int(timing["late_count"]), "N/A" if timing["median_delta_us"] == null else "%+.1f ms" % (int(timing["median_delta_us"]) / 1000.0), int(errors.get("wrong_target", 0)), int(errors.get("wrong_technique", 0)), int(errors.get("no_candidate", 0)), record["metadata"]["importer_version"], record["metadata"]["chart_version"], record["metadata"]["profile_id"], record["metadata"]["judgement_rule_id"], record["metadata"]["score_rule_id"]]

func _select(index: int) -> void: if index >= 0 and index < _records.size(): _show(_records[index])

func _delete_selected() -> void:
	var selected := _history.get_selected_items(); if selected.is_empty(): _status.text = "Select a result first."; return
	var loaded: Dictionary = repositories.results.load(); var deleted := Results.delete_result(loaded["document"], _records[selected[0]]["result_id"]); if deleted.get("ok", false): repositories.results.save(deleted["document"]); refresh()

func _clear() -> void:
	var loaded: Dictionary = repositories.results.load(); if loaded.get("ok", false): repositories.results.save(Results.clear(loaded["document"])); refresh()
