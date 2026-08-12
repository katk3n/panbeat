extends SceneTree

const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Audio := preload("res://infrastructure/ffmpeg_audio_converter.gd")
const Importer := preload("res://application/song_import_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args(); var output_index := arguments.find("--output"); if output_index < 0: quit(64); return
	var root := "/tmp/panbeat-p214-import"; var files := Files.new(); files.remove_tree(root); DirAccess.make_dir_recursive_absolute(root); var repositories := Repositories.new(root.path_join("documents")); var importer := Importer.new(files, Audio.new())
	var request := {"score_path":ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance.musicxml"), "overlay_path":ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance-overlay.json"), "audio_path":ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/orbit-practice.wav"), "profile":_json("res://config/default-instrument-profile.json"), "song_id":"p214-cache", "title":"P214 Cache"}
	var started := Time.get_ticks_usec(); var imported := importer.import_song(request, root.path_join("library"), repositories.songs); var cold_us := Time.get_ticks_usec() - started; started = Time.get_ticks_usec(); var duplicate := importer.import_song(request, root.path_join("library"), repositories.songs); var duplicate_us := Time.get_ticks_usec() - started
	var package_bytes := _tree_bytes(str(imported.get("published_path", ""))); var file := FileAccess.open(arguments[output_index + 1], FileAccess.WRITE); file.store_string(JSON.stringify({"schema_version":"1.0.0", "cold_import_us":cold_us, "duplicate_cache_lookup_us":duplicate_us, "duplicate_detected":duplicate.get("duplicate", false), "package_bytes":package_bytes, "index_records":repositories.songs.load()["document"]["songs"].size(), "source_audio_bytes":FileAccess.get_file_as_bytes(request["audio_path"]).size()}, "  ") + "\n"); files.remove_tree(root); quit(0 if imported.get("ok") and duplicate.get("duplicate") else 1)

func _tree_bytes(path: String) -> int:
	if not DirAccess.dir_exists_absolute(path): return 0
	var total := 0; var directory := DirAccess.open(path); directory.list_dir_begin()
	while true:
		var name := directory.get_next(); if name.is_empty(): break
		var child := path.path_join(name); total += _tree_bytes(child) if directory.current_is_dir() else FileAccess.get_file_as_bytes(child).size()
	directory.list_dir_end(); return total

func _json(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))) as Dictionary
