extends SceneTree

const Calibration := preload("res://application/calibration_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")

func _initialize() -> void:
	var failures: Array[String] = []; var profile := "roland-mn10-handpan-minor-v1"; var output := "Built-in Output"
	var samples: Array[Dictionary] = []
	for delta: int in [40_000, 42_000, 38_000, 41_000, 39_000]: samples.append(Calibration.sample(1_000_000, 1_000_000 + delta, "hit", profile, output))
	var result := Calibration.analyze(samples)
	_check(result.get("ok") and result["median_delta_us"] == 40_000 and result["proposed"]["input_offset_us"] == -40_000, "recorded late input proposes negative input offset", failures)
	var early: Array[Dictionary] = []; for delta: int in [-30_000, -28_000, -32_000, -29_000, -31_000]: early.append(Calibration.sample(1_000_000, 1_000_000 + delta, "hit", profile, output))
	_check(Calibration.analyze(early)["proposed"]["input_offset_us"] == 30_000, "recorded early input proposes positive input offset", failures)
	_check(Calibration.assign_input(970_000, -1, 1_000_000, 400_000) == "next_cue", "input shortly before cue is assigned to that cue", failures)
	_check(Calibration.assign_input(1_030_000, 1_000_000, 2_500_000, 400_000) == "current_cue", "input shortly after cue is assigned to current cue", failures)
	_check(Calibration.assign_input(970_000, -1, 1_000_000, 400_000, true) == "extra_hit", "second early input is excluded as extra hit", failures)
	var audio_relative := Calibration.analyze(samples, 10_000, 25_000)
	_check(audio_relative["proposed"]["input_offset_us"] == -15_000 and audio_relative["before"]["input_offset_us"] == 10_000, "proposal preserves audio offset and distinguishes before", failures)
	var short := samples.slice(0, 4); short.append(Calibration.sample(1_000_000, -1, "miss", profile, output)); short.append(Calibration.sample(1_000_000, 1_010_000, "extra_hit", profile, output))
	var shortage := Calibration.analyze(short)
	_check(shortage.get("code") == "sample_shortage" and shortage["valid_count"] == 4 and shortage["excluded"].size() == 2, "Miss and Extra Hit excluded from sample count", failures)
	var wild: Array[Dictionary] = []; for delta: int in [-80_000, -40_000, 0, 40_000, 80_000]: wild.append(Calibration.sample(1_000_000, 1_000_000 + delta, "hit", profile, output))
	_check(Calibration.analyze(wild).get("code") == "variance_too_high", "excessive variance requests retry", failures)
	_check(not Calibration.sample(1_000_000, 1_450_000, "hit", profile, output)["included"], "out-of-range sample excluded", failures)
	var one_outlier: Array[Dictionary] = samples.duplicate(true); one_outlier.append(Calibration.sample(1_000_000, 1_180_000, "hit", profile, output))
	_check(Calibration.analyze(one_outlier).get("ok") and Calibration.analyze(one_outlier).get("outlier_count") == 1, "single timing outlier excluded without failing stable samples", failures)
	var settings := {"schema_version":"1.0.0", "selected_midi_port":"MN-10", "profile_id":profile, "offsets":[]}
	settings = Calibration.upsert_offset(settings, profile, output, -40_000, 5_000, samples)
	var found := Calibration.find_offset(settings, profile, output)
	_check(found["input_offset_us"] == -40_000 and found["audio_offset_us"] == 5_000 and found["calibration_samples"].size() == 5, "samples and offsets keyed by profile/output", failures)
	settings = Calibration.upsert_offset(settings, profile, "Headphones", 10_000, -2_000)
	_check(settings["offsets"].size() == 2 and Calibration.find_offset(settings, profile, output)["input_offset_us"] == -40_000, "different audio outputs remain independent", failures)
	settings = Calibration.upsert_offset(settings, profile, output, -35_000, 5_000, samples)
	_check(settings["offsets"].size() == 2 and Calibration.find_offset(settings, profile, output)["input_offset_us"] == -35_000, "manual fine tune replaces matching key", failures)
	var reset := Calibration.reset_offset(settings, profile, output)
	_check(Calibration.find_offset(reset, profile, output)["input_offset_us"] == 0 and Calibration.find_offset(reset, profile, output)["calibration_samples"].is_empty(), "reset clears value and samples", failures)
	_check("Positive Input Offset" in result["explanation"] and "Positive Audio Offset" in result["explanation"], "offset sign convention explained", failures)
	var root := "/tmp/panbeat-p210-settings"; _remove_tree(root); var repositories := Repositories.new(root, NativeBackend.new()); _check(repositories.settings.save(settings).get("ok"), "calibration settings save", failures)
	var restarted := Repositories.new(root, NativeBackend.new()); _check(Calibration.find_offset(restarted.settings.load()["document"], profile, "Headphones")["input_offset_us"] == 10_000, "offset restored after repository restart", failures)
	_remove_tree(root); _finish(failures, 16)

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var directory := DirAccess.open(path); directory.include_hidden = true; directory.list_dir_begin()
	while true:
		var name := directory.get_next(); if name.is_empty(): break
		var child := path.path_join(name)
		if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
	directory.list_dir_end(); directory = null; DirAccess.remove_absolute(path)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P210_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
