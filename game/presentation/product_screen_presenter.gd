class_name ProductScreenPresenter
extends RefCounted

static func calibration_retry(result: Dictionary) -> String:
	match String(result.get("code", "")):
		"sample_shortage":
			return "再試行が必要です — 有効な打撃は %d / %d 回です。Miss、Extra Hit、範囲外の入力を除き、合図ごとに Tone または Ding を1回だけ叩いてください。" % [int(result.get("valid_count", 0)), int(result.get("required_count", 5))]
		"variance_too_high":
			return "再試行が必要です — 打撃タイミングのばらつきが大きすぎます。一定の姿勢で、繰り返す合図に合わせて明確な1打ずつを入力してください。"
		_:
			return "再試行が必要です — %s" % result.get("message", "Calibration を完了できませんでした。")

static func result_sections(record: Dictionary) -> Dictionary:
	var summary: Dictionary = record.get("summary", {})
	var breakdown: Dictionary = summary.get("breakdown", {})
	var timing: Dictionary = record.get("timing_distribution", {})
	var errors: Dictionary = record.get("error_breakdown", {})
	var metadata: Dictionary = record.get("metadata", {})
	return {
		"headline":"SCORE %d     ACCURACY %.2f%%     MAX COMBO %d" % [int(summary.get("score", 0)), float(summary.get("accuracy", 0.0)) * 100.0, int(summary.get("max_combo", 0))],
		"grades":"PERFECT %d   GREAT %d   GOOD %d   MISS %d   EXTRA %d" % [int(breakdown.get("perfect", 0)), int(breakdown.get("great", 0)), int(breakdown.get("good", 0)), int(breakdown.get("miss", 0)), int(breakdown.get("extra_hit", 0))],
		"timing":"EARLY %d   ON TIME %d   LATE %d   MEDIAN %s" % [int(timing.get("early_count", 0)), int(timing.get("on_time_count", 0)), int(timing.get("late_count", 0)), "N/A" if timing.get("median_delta_us") == null else "%+.1f ms" % (int(timing["median_delta_us"]) / 1000.0)],
		"technical":"Result %s · importer %s · chart %s · profile %s\njudgement %s · score %s · identity errors T%d / K%d / N%d" % [record.get("result_id", "unknown"), metadata.get("importer_version", "?"), metadata.get("chart_version", "?"), metadata.get("profile_id", "?"), metadata.get("judgement_rule_id", "?"), metadata.get("score_rule_id", "?"), int(errors.get("wrong_target", 0)), int(errors.get("wrong_technique", 0)), int(errors.get("no_candidate", 0))]
	}

static func destructive_confirmation(action: String, target: String, count: int = 1) -> Dictionary:
	if action == "clear":
		return {"button":"Confirm Clear All", "message":"CONFIRM — Clear all %d result(s)? This removes local result history." % count}
	return {"button":"Confirm Delete", "message":"CONFIRM — Delete result %s? Other results are not changed." % target}

static func state_fixture(kind: String) -> Dictionary:
	match kind:
		"loading": return {"label":"LOADING", "message":"Reading local songs…", "action_enabled":false, "tone":"info"}
		"empty": return {"label":"EMPTY", "message":"No local songs. Import MusicXML and audio to begin.", "action_enabled":false, "tone":"info"}
		"disabled": return {"label":"PLAY UNAVAILABLE", "message":"Select a compatible valid song first.", "action_enabled":false, "tone":"warning"}
		"warning": return {"label":"PROFILE WARNING", "message":"Re-import with the active Instrument Profile before playing.", "action_enabled":false, "tone":"warning"}
		_: return {"label":"IMPORT FAILED", "message":"The file was not changed. Review diagnostics and retry.", "action_enabled":true, "tone":"error"}
