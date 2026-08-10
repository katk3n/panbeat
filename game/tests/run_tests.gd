extends SceneTree

const InputTechnique := preload("res://domain/input_technique.gd")
const Judgement := preload("res://domain/judgement_engine.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const ChartLoader := preload("res://infrastructure/phase0_chart_loader.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_check(InputTechnique.count() == 3, "three techniques", failures)
	_check(Judgement.judge(1_000_000, 1_000_000)["judgement"] == "perfect", "judgement domain", failures)
	var profile_path: String = ProjectSettings.globalize_path("res://config/default-instrument-profile.json")
	var profile: Dictionary = Normalizer.load_profile(profile_path)
	_check(profile.get("profile_id") == "roland-mn10-handpan-minor-v1", "product profile", failures)
	var canonical_profile: Dictionary = Normalizer.load_profile(ProjectSettings.globalize_path("res://../shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json"))
	_check(profile == canonical_profile, "product profile matches canonical fixture", failures)
	var chart_path: String = ProjectSettings.globalize_path("res://../shared/fixtures/test-pack/chart.json")
	var chart: Dictionary = ChartLoader.load_chart(chart_path)
	_check(chart.get("duration_us") == 30_000_000, "shared chart", failures)
	_check(load("res://presentation/main.tscn") != null, "main scene", failures)
	if failures.is_empty():
		print("PANBEAT_GAME_TESTS_OK 6/6")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
