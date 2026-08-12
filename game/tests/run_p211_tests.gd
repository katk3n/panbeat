extends SceneTree

const Results := preload("res://application/results_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")

func _initialize() -> void:
	var failures: Array[String] = []; var rules: Dictionary = _json("res://config/score-rules-v1.json"); var metadata := _metadata()
	var records: Array[Dictionary] = [_record("perfect", -20_000), _record("great", 40_000), _record("miss", null), _record("extra_hit", null, "wrong_target"), _record("extra_hit", 10_000, "wrong_technique")]
	var created := Results.create_result("result-1", "2026-08-12T01:00:00Z", metadata, records, rules); var result: Dictionary = created.get("record", {})
	_check(created.get("ok") and result["summary"]["score"] == 1750 and result["summary"]["max_combo"] == 2, "score and combo recomputed by versioned rules", failures)
	_check(is_equal_approx(float(result["summary"]["accuracy"]), 0.35) and result["summary"]["breakdown"]["extra_hit"] == 2, "accuracy and grade breakdown recomputed", failures)
	_check(result["timing_distribution"] == {"sample_count":2, "median_delta_us":10000, "early_count":1, "on_time_count":0, "late_count":1}, "judged timing distribution excludes Miss and Extra Hit", failures)
	_check(result["error_breakdown"]["wrong_target"] == 1 and result["error_breakdown"]["wrong_technique"] == 1, "identity errors remain separate from timing grades", failures)
	_check(result["judgements"][2]["actual_timestamp_us"] == null and result["judgements"][2]["delta_us"] == null, "Miss null timestamps remain null", failures)
	_check(result["metadata"] == metadata, "song importer chart profile and rule versions retained", failures)
	_check(Results.create_result("bad", "now", {}, records, rules).get("code") == "missing_metadata", "missing version metadata rejected", failures)
	var wrong_rules := rules.duplicate(true); wrong_rules["rule_id"] = "other"; _check(Results.create_result("bad", "now", metadata, records, wrong_rules).get("code") == "score_rule_mismatch", "score rule mismatch rejected", failures)
	var history := {"schema_version":"1.0.0", "max_records":2, "records":[]}; history = Results.append(history, result)["document"]
	var result2: Dictionary = Results.create_result("result-2", "2026-08-12T02:00:00Z", metadata, records, rules)["record"]; history = Results.append(history, result2)["document"]
	var result3: Dictionary = Results.create_result("result-3", "2026-08-12T03:00:00Z", metadata, records, rules)["record"]; history = Results.append(history, result3)["document"]
	_check(history["records"].size() == 2 and history["records"][0]["result_id"] == "result-3" and history["records"][1]["result_id"] == "result-2", "history bounded and newest first", failures)
	_check(Results.append(history, result2).get("code") == "duplicate_result_id", "duplicate result ID rejected", failures)
	var broken_records: Array = []; broken_records.assign(history["records"]); broken_records.append({"schema_version":"1.0.0", "result_id":"broken"}); broken_records.append("not-object"); var broken := {"schema_version":"1.0.0", "max_records":2, "records":broken_records}; var inspected := Results.inspect_history(broken)
	_check(inspected["records"].size() == 2 and inspected["quarantined"].size() == 2, "broken records isolated without hiding valid history", failures)
	var deleted := Results.delete_result(history, "result-3"); _check(deleted.get("ok") and deleted["document"]["records"].size() == 1, "selected history deletion", failures)
	_check(Results.delete_result(history, "missing").get("code") == "result_not_found", "missing deletion reports concrete error", failures)
	_check(Results.clear(history)["records"].is_empty() and Results.clear(history)["max_records"] == 2, "clear preserves configured history limit", failures)
	var root := "/tmp/panbeat-p211-results"; _remove_tree(root); var repositories := Repositories.new(root, NativeBackend.new()); _check(repositories.results.save(history).get("ok"), "result history atomic save", failures)
	var restarted := Repositories.new(root, NativeBackend.new()); _check(Results.inspect_history(restarted.results.load()["document"])["records"].size() == 2, "result history restored after restart", failures)
	_remove_tree(root); _finish(failures, 16)

func _metadata() -> Dictionary: return {"song_id":"phase1-fixed-song-v1", "importer_version":"panbeat-importer-v1", "chart_version":"1.0.0", "profile_id":"roland-mn10-handpan-minor-v1", "judgement_rule_id":"panbeat-phase1-judgement-v1", "score_rule_id":"panbeat-phase1-score-v1"}

func _record(grade: String, delta: Variant, reason: String = "") -> Dictionary:
	var outcome := "judged" if grade not in ["miss", "extra_hit"] else ("miss" if grade == "miss" else "extra")
	var value := {"schema_version":"1.0.0", "rule_id":"panbeat-phase1-judgement-v1", "record_id":"r-%s-%s" % [grade, str(delta)], "note_id":"n" if grade != "extra_hit" else null, "input_event_id":null if grade == "miss" else "i", "expected_timestamp_us":1000000 if grade != "extra_hit" else null, "actual_timestamp_us":null if grade == "miss" else 1000000, "delta_us":delta, "clock_domain":"song_time", "expected_technique":"tone" if grade != "extra_hit" else null, "actual_technique":null if grade == "miss" else "tone", "expected_target_id":"tone-1" if grade != "extra_hit" else null, "actual_target_id":null if grade == "miss" else "tone-1", "grade":grade, "outcome":outcome}
	if not reason.is_empty(): value["reason"] = reason
	return value

func _json(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))) as Dictionary
func _check(condition: bool, label: String, failures: Array[String]) -> void: if not condition: failures.append(label)
func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P211_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var directory := DirAccess.open(path); directory.include_hidden = true; directory.list_dir_begin()
	while true:
		var name := directory.get_next(); if name.is_empty(): break
		var child := path.path_join(name); if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
	directory.list_dir_end(); directory = null; DirAccess.remove_absolute(path)
