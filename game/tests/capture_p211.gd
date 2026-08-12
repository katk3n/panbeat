extends SceneTree

const View := preload("res://presentation/results_view.gd")
const Results := preload("res://application/results_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args(); var index := arguments.find("--output"); if index < 0: quit(64); return
	var repository_root := "/tmp/panbeat-p211-capture"; _remove_tree(repository_root); var repositories := Repositories.new(repository_root, NativeBackend.new())
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/score-rules-v1.json")))
	var metadata := {"song_id":"orbit-practice", "importer_version":"panbeat-importer-v1", "chart_version":"1.0.0", "profile_id":"roland-mn10-handpan-minor-v1", "judgement_rule_id":"panbeat-phase1-judgement-v1", "score_rule_id":"panbeat-phase1-score-v1"}
	var records: Array[Dictionary] = [_record("perfect", -12000), _record("great", 41000), _record("good", 76000), _record("miss", null), _record("extra_hit", null, "wrong_technique")]
	var result: Dictionary = Results.create_result("capture-result", "2026-08-12T03:00:00Z", metadata, records, rules)["record"]
	repositories.results.save({"schema_version":"1.0.0", "max_records":100, "records":[result]})
	root.size = Vector2i(1280, 720); RenderingServer.set_default_clear_color(Color("101620")); var view := View.new(); view.repositories = repositories; root.add_child(view)
	for _frame: int in 5: await process_frame
	var error := root.get_texture().get_image().save_png(arguments[index + 1]); quit(0 if error == OK else 1)

func _record(grade: String, delta: Variant, reason: String = "") -> Dictionary:
	var outcome := "judged" if grade not in ["miss", "extra_hit"] else ("miss" if grade == "miss" else "extra")
	var value := {"schema_version":"1.0.0", "rule_id":"panbeat-phase1-judgement-v1", "record_id":"capture-%s" % grade, "note_id":"note" if grade != "extra_hit" else null, "input_event_id":null if grade == "miss" else "input", "expected_timestamp_us":1000000 if grade != "extra_hit" else null, "actual_timestamp_us":null if grade == "miss" else 1000000, "delta_us":delta, "clock_domain":"song_time", "expected_technique":"tone" if grade != "extra_hit" else null, "actual_technique":null if grade == "miss" else "tone", "expected_target_id":"tone-1" if grade != "extra_hit" else null, "actual_target_id":null if grade == "miss" else "tone-1", "grade":grade, "outcome":outcome}
	if not reason.is_empty(): value["reason"] = reason
	return value

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var directory := DirAccess.open(path); directory.include_hidden = true; directory.list_dir_begin()
	while true:
		var name := directory.get_next(); if name.is_empty(): break
		var child := path.path_join(name); if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
	directory.list_dir_end(); directory = null; DirAccess.remove_absolute(path)
