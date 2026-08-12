extends SceneTree

const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Audio := preload("res://infrastructure/ffmpeg_audio_converter.gd")
const Importer := preload("res://application/song_import_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args(); var root_index := arguments.find("--root"); if root_index < 0: quit(64); return
	var root: String = arguments[root_index + 1]; var files := Files.new(); files.remove_tree(root); DirAccess.make_dir_recursive_absolute(root); var repositories := Repositories.new(root.path_join("documents")); var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	var request := {"score_path":ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance.musicxml"), "overlay_path":ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance-overlay.json"), "audio_path":ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/orbit-practice.wav"), "profile":profile, "song_id":"p215-acceptance", "title":"P215 Acceptance", "artist":"PanBeat"}; var imported := Importer.new(files, Audio.new()).import_song(request, root.path_join("songs"), repositories.songs)
	if not imported.get("ok", false): push_error(str(imported)); quit(1); return
	var chart: Dictionary = files.read_json(imported["published_path"].path_join("chart.json"), 16 * 1024 * 1024)["document"]; var inputs: Array = []; var index := 0
	for note: Dictionary in chart["notes"]: index += 1; inputs.append({"event_id":"p215-%03d" % index, "timestamp_us":note["timestamp_us"], "technique":note["technique"], "target_id":note["target_id"], "velocity":96})
	var package_relative_path := str(imported["published_path"]).trim_prefix(root.rstrip("/") + "/")
	files.write_text(root.path_join("replay-inputs.json"), JSON.stringify({"schema_version":"1.0.0", "inputs":inputs}, "  ") + "\n"); files.write_text(root.path_join("prepared.json"), JSON.stringify({"schema_version":"1.0.0", "package_relative_path":package_relative_path, "chart_sha256":FileAccess.get_sha256(imported["published_path"].path_join("chart.json")), "replay_input_count":inputs.size()}, "  ") + "\n"); print("PANBEAT_P215_PREPARED %s" % package_relative_path); quit(0)
