extends SceneTree

const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Audio := preload("res://infrastructure/ffmpeg_audio_converter.gd")
const Importer := preload("res://application/song_import_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const Replay := preload("res://application/deterministic_replay_session.gd")
const Results := preload("res://application/results_service.gd")
const Scheduler := preload("res://application/gameplay_note_scheduler.gd")

func _initialize() -> void:
	var failures: Array[String] = []; var files := Files.new(); var root := "/tmp/panbeat-p213-tests"; files.remove_tree(root); DirAccess.make_dir_recursive_absolute(root)
	var score := ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance.musicxml"); var overlay := ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance-overlay.json"); var audio := ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/orbit-practice.wav")
	var profile: Dictionary = _json("res://config/default-instrument-profile.json"); var repositories := Repositories.new(root.path_join("documents")); var request := {"score_path":score, "overlay_path":overlay, "audio_path":audio, "profile":profile, "song_id":"p213-acceptance", "title":"P213 Acceptance", "artist":"PanBeat"}
	var imported := Importer.new(files, Audio.new()).import_song(request, root.path_join("library"), repositories.songs)
	_check(imported.get("ok") and FileAccess.file_exists(imported["published_path"].path_join("runtime.ogg")), "MusicXML overlay and audio imported as playable package", failures)
	var package: Dictionary = files.read_json(imported["published_path"].path_join("package.json"), 1024 * 1024)["document"]; var chart_result := ChartSource.load_chart(imported["published_path"].path_join(package["chart_path"])); var chart: Dictionary = chart_result.get("chart", {})
	_check(package.get("schema_version") == "1.2.0" and package.get("handpan_scale_name") == "D Kurd 9" and not chart.has("handpan_scale_name"), "handpan scale remains package metadata rather than Runtime Chart data", failures)
	_check(chart_result.get("ok") and chart["notes"].size() == 4, "tied notes merge into one runtime event", failures)
	var techniques: Array[String] = []; for note: Dictionary in chart["notes"]: techniques.append(note["technique"])
	_check(techniques.has("tone") and techniques.has("ding") and techniques.has("slap"), "Tone Ding and Slap survive imported package", failures)
	_check(chart["tempo_map"].size() == 2 and chart["tempo_map"][0]["bpm_milli"] == 120000 and chart["tempo_map"][1]["bpm_milli"] == 90000, "tempo change retained", failures)
	_check(chart["notes"][0]["timestamp_us"] == 0 and chart["notes"][1]["timestamp_us"] == 1000000 and chart["notes"][2]["timestamp_us"] == 1500000 and chart["notes"][3]["timestamp_us"] == 2000000, "golden imported timestamps are deterministic", failures)
	var runtime_result := ChartFactory.build(chart, profile, int(package["duration_us"])); _check(runtime_result.get("ok"), "imported chart enters existing Runtime Chart factory", failures)
	var stream := AudioStreamOggVorbis.load_from_file(imported["published_path"].path_join(package["audio"]["runtime_path"])); _check(stream != null and stream.get_length() > 2.0, "external runtime Ogg is loadable by Godot", failures)
	_check(stream != null and absi(int(package["duration_us"]) - roundi(stream.get_length() * 1_000_000.0)) <= 1_000 and int(package["duration_us"]) > int(chart["duration_us"]), "package and transport duration follow audio rather than shorter score", failures)
	var scheduler := Scheduler.new(runtime_result["chart"], profile, 64); scheduler.update(0); var active: Array[Dictionary] = []
	for slot: Dictionary in scheduler.active_slots():
		if slot["active"]: active.append(slot["note"])
	_check(not active.is_empty() and active[0]["target_id"] == "tone-4", "existing radial scheduler uses imported target mapping", failures)
	var inputs: Array = []; var sequence := 0
	for note: Dictionary in chart["notes"]: sequence += 1; inputs.append({"event_id":"p213-%d" % sequence, "timestamp_us":note["timestamp_us"], "technique":note["technique"], "target_id":note["target_id"]})
	var judgement_rules: Dictionary = _json("res://config/judgement-rules-v1.json"); var score_rules: Dictionary = _json("res://config/score-rules-v1.json"); var replay := Replay.run(runtime_result["chart"], inputs, judgement_rules, score_rules)
	_check(replay["summary"]["perfect"] if replay["summary"].has("perfect") else replay["summary"]["breakdown"]["perfect"] == 4, "imported package reuses judgement pipeline", failures)
	var metadata := {"song_id":package["song_id"], "importer_version":package["importer_version"], "chart_version":package["chart_schema_version"], "profile_id":package["profile_id"], "judgement_rule_id":judgement_rules["rule_id"], "score_rule_id":score_rules["rule_id"]}
	var result: Dictionary = Results.create_result("p213-result", "2026-08-12T04:00:00Z", metadata, replay["records"], score_rules)["record"]; var history := {"schema_version":"1.0.0", "max_records":100, "records":[]}; var once := Results.append(history, result)
	_check(once.get("ok") and once["document"]["records"].size() == 1, "completed imported session saved to Results once", failures)
	_check(Results.append(once["document"], result).get("code") == "duplicate_result_id", "duplicate completion cannot save twice", failures)
	_check(result["metadata"]["song_id"] == "p213-acceptance" and result["metadata"]["importer_version"] == Importer.IMPORTER_VERSION, "Results retains imported package provenance", failures)
	var index: Dictionary = repositories.songs.load()["document"]; _check(index["songs"][0]["package_path"] in imported["published_path"], "Song Library entry resolves published package", failures)
	_check(FileAccess.get_sha256(score) == package["source"]["sha256"], "rights-safe source remains unchanged and checksummed", failures)
	files.remove_tree(root); _finish(failures, 16)

func _json(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))) as Dictionary
func _check(condition: bool, label: String, failures: Array[String]) -> void: if not condition: failures.append(label)
func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P213_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
