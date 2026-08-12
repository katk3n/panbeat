class_name ResultsService
extends RefCounted

const ScoreEngine := preload("res://domain/score_engine.gd")

const REQUIRED_METADATA: Array[String] = ["song_id", "importer_version", "chart_version", "profile_id", "judgement_rule_id", "score_rule_id"]

static func create_result(result_id: String, completed_at: String, metadata: Dictionary, records: Array[Dictionary], score_rules: Dictionary) -> Dictionary:
	if result_id.is_empty() or completed_at.is_empty(): return _failure("missing_identity", "result_id and completed_at are required")
	for key: String in REQUIRED_METADATA:
		if str(metadata.get(key, "")).is_empty(): return _failure("missing_metadata", "result metadata requires %s" % key)
	if score_rules.get("schema_version") != "1.0.0" or score_rules.get("rule_id") != metadata.get("score_rule_id"):
		return _failure("score_rule_mismatch", "score rule version does not match result metadata")
	var summary := ScoreEngine.summarize(records, score_rules)
	var deltas: Array[int] = []; var reasons := {"wrong_target":0, "wrong_technique":0, "no_candidate":0}
	for record: Dictionary in records:
		if record.get("outcome") == "judged" and record.get("delta_us") is int: deltas.append(int(record["delta_us"]))
		var reason := str(record.get("reason", "")); if reasons.has(reason): reasons[reason] = int(reasons[reason]) + 1
	deltas.sort(); var early := 0; var on_time := 0; var late := 0
	for delta: int in deltas:
		if delta < 0: early += 1
		elif delta > 0: late += 1
		else: on_time += 1
	var distribution := {"sample_count":deltas.size(), "median_delta_us":_median(deltas) if not deltas.is_empty() else null, "early_count":early, "on_time_count":on_time, "late_count":late}
	return {"ok":true, "record":{"schema_version":"1.0.0", "result_id":result_id, "completed_at":completed_at, "metadata":metadata.duplicate(true), "summary":summary, "timing_distribution":distribution, "error_breakdown":reasons, "judgements":records.duplicate(true)}}

static func validate_record(record: Dictionary) -> Dictionary:
	for key: String in ["result_id", "completed_at"]:
		if str(record.get(key, "")).is_empty(): return _failure("invalid_result", "result requires %s" % key)
	if record.get("schema_version") != "1.0.0" or record.get("metadata") is not Dictionary or record.get("summary") is not Dictionary or record.get("timing_distribution") is not Dictionary or record.get("judgements") is not Array:
		return _failure("invalid_result", "result record shape is invalid")
	for key: String in REQUIRED_METADATA:
		if str(record["metadata"].get(key, "")).is_empty(): return _failure("invalid_result_metadata", "result metadata requires %s" % key)
	return {"ok":true}

static func inspect_history(history: Dictionary) -> Dictionary:
	var valid: Array[Dictionary] = []; var quarantined: Array[Dictionary] = []
	for index: int in history.get("records", []).size():
		var value: Variant = history["records"][index]
		if value is not Dictionary: quarantined.append({"index":index, "code":"not_an_object"}); continue
		var validation := validate_record(value)
		if validation.get("ok", false): valid.append((value as Dictionary).duplicate(true))
		else: quarantined.append({"index":index, "result_id":value.get("result_id"), "code":validation.get("code"), "error":validation.get("error")})
	valid.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left["completed_at"]) > str(right["completed_at"]))
	return {"records":valid, "quarantined":quarantined}

static func append(history: Dictionary, record: Dictionary) -> Dictionary:
	var validation := validate_record(record); if not validation.get("ok", false): return validation
	var inspected := inspect_history(history); var records: Array = inspected["records"]
	for value: Dictionary in records:
		if value.get("result_id") == record.get("result_id"): return _failure("duplicate_result_id", "result_id already exists")
	records.append(record.duplicate(true)); records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left["completed_at"]) > str(right["completed_at"]))
	var maximum := int(history.get("max_records", 100)); if maximum < 1: return _failure("invalid_history_limit", "max_records must be positive")
	if records.size() > maximum: records.resize(maximum)
	return {"ok":true, "document":{"schema_version":"1.0.0", "max_records":maximum, "records":records}, "quarantined":inspected["quarantined"]}

static func delete_result(history: Dictionary, result_id: String) -> Dictionary:
	var inspected := inspect_history(history); var retained: Array[Dictionary] = []; var found := false
	for record: Dictionary in inspected["records"]:
		if record.get("result_id") == result_id: found = true
		else: retained.append(record)
	if not found: return _failure("result_not_found", "result does not exist: %s" % result_id)
	return {"ok":true, "document":{"schema_version":"1.0.0", "max_records":int(history.get("max_records", 100)), "records":retained}, "quarantined":inspected["quarantined"]}

static func clear(history: Dictionary) -> Dictionary:
	return {"schema_version":"1.0.0", "max_records":int(history.get("max_records", 100)), "records":[]}

static func _median(sorted: Array[int]) -> int:
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 == 1 else roundi((sorted[middle - 1] + sorted[middle]) / 2.0)

static func _failure(code: String, error: String) -> Dictionary: return {"ok":false, "code":code, "error":error}
