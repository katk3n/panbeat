extends SceneTree

const Presenter := preload("res://presentation/product_screen_presenter.gd")
const ThemeFactory := preload("res://presentation/panbeat_theme.gd")
const ResultsView := preload("res://presentation/results_view.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var shortage := Presenter.calibration_retry({"code":"sample_shortage","valid_count":3,"required_count":5})
	_check(shortage.contains("3 / 5") and shortage.contains("1回だけ") and shortage.contains("再試行"), "sample shortage explains count and retry in Japanese", failures)
	var variance := Presenter.calibration_retry({"code":"variance_too_high"})
	_check(variance.contains("ばらつき") and variance.contains("明確な1打"), "variance retry is actionable in Japanese", failures)
	var record := _record()
	var sections := Presenter.result_sections(record)
	_check(sections["headline"].contains("SCORE 45000") and sections["headline"].contains("ACCURACY 98.50%") and sections["headline"].contains("MAX COMBO 41"), "result headline compares primary metrics", failures)
	_check(sections["grades"].contains("PERFECT 40") and sections["grades"].contains("MISS 1"), "grade breakdown remains visible", failures)
	_check(sections["timing"].contains("EARLY 8") and sections["timing"].contains("LATE 11") and sections["timing"].contains("+4.0 ms"), "timing distribution remains visible", failures)
	_check(sections["technical"].contains("importer import-v1") and sections["technical"].contains("profile profile-v1"), "technical metadata remains available separately", failures)
	var delete := Presenter.destructive_confirmation("delete", "result-17")
	_check(delete["button"] == "Confirm Delete" and delete["message"].contains("result-17"), "delete confirmation names exact target", failures)
	var clear := Presenter.destructive_confirmation("clear", "all", 12)
	_check(clear["button"] == "Confirm Clear All" and clear["message"].contains("12 result"), "clear confirmation names result count", failures)
	for kind: String in ["loading","empty","disabled","warning","error"]:
		var fixture := Presenter.state_fixture(kind)
		_check(not String(fixture["label"]).is_empty() and not String(fixture["message"]).is_empty(), "%s fixture has label and guidance" % kind, failures)
	_check(not Presenter.state_fixture("disabled")["action_enabled"] and Presenter.state_fixture("error")["action_enabled"], "disabled and recoverable error actions differ", failures)
	var theme := ThemeFactory.shared()
	_check(theme.get_type_variation_base("PrimaryButton") == "Button" and theme.has_stylebox("normal", "PrimaryButton"), "primary Play action has shared visual variation", failures)
	var completion_actions := ResultsView.completion_action_contract()
	_check(completion_actions["primary"] == "play_again" and completion_actions["secondary"] == "song_library" and not completion_actions["process_restart_required"] and completion_actions["preserves_result_history"], "completed Results supports replay and song selection in the same process", failures)
	_finish(failures, 16)

func _record() -> Dictionary:
	return {"result_id":"result-17","metadata":{"song_id":"orbit","importer_version":"import-v1","chart_version":"chart-v1","profile_id":"profile-v1","judgement_rule_id":"judge-v1","score_rule_id":"score-v1"},"summary":{"score":45000,"accuracy":0.985,"max_combo":41,"breakdown":{"perfect":40,"great":3,"good":1,"miss":1,"extra_hit":0}},"timing_distribution":{"early_count":8,"on_time_count":26,"late_count":11,"median_delta_us":4000},"error_breakdown":{"wrong_target":1,"wrong_technique":0,"no_candidate":0}}

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P308_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
