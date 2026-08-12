extends SceneTree

const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Library := preload("res://application/song_library_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const Canonical := preload("res://application/canonical_json.gd")

func _initialize() -> void:
	var failures: Array[String] = []; var files := Files.new(); var root := "/tmp/panbeat-p208-tests"
	var cleanup := files.remove_tree(root); if not cleanup.get("ok", false): push_error(str(cleanup)); quit(1); return
	DirAccess.make_dir_recursive_absolute(root)
	var repositories := Repositories.new(root.path_join("documents")); var service := Library.new(files); var repository_root := root.path_join("songs")
	_check(service.loading_state()["state"] == "loading", "loading state is textual", failures)
	var empty := service.query(repository_root, repositories.songs, "profile-a")
	_check(empty.get("ok") and empty.get("state") == "empty" and "EMPTY" in empty.get("label", ""), "empty state is textual", failures)
	_make_package(files, repository_root, "z-song", "Zulu", "profile-a", true)
	_make_package(files, repository_root, "a-song", "alpha", "profile-b", true)
	_make_package(files, repository_root, "silent-song", "Silent", "profile-a", true, false)
	var index := {"schema_version":"1.0.0", "songs":[_entry("z-song", "Zulu"), _entry("broken", "Broken"), _entry("a-song", "alpha"), _entry("silent-song", "Silent")]}
	repositories.songs.save(index)
	var query := service.query(repository_root, repositories.songs, "profile-a")
	_check(query.get("ok") and query["songs"].size() == 4, "broken song does not prevent library query", failures)
	_check(query["songs"][0]["song_id"] == "a-song" and query["songs"][1]["song_id"] == "broken" and query["songs"][2]["song_id"] == "silent-song" and query["songs"][3]["song_id"] == "z-song", "library ordering is deterministic title then ID", failures)
	var alpha: Dictionary = query["songs"][0]; var broken: Dictionary = query["songs"][1]
	_check(alpha["display_status"] == "warning" and alpha["profile_compatibility"] == "incompatible", "profile mismatch is non-color warning", failures)
	_check(broken["display_status"] == "invalid" and not broken["diagnostics"].is_empty(), "corrupt package is isolated with diagnostics", failures)
	_check(query["songs"][2]["display_status"] == "valid", "package without backing audio remains playable", failures)
	var zulu: Dictionary = query["songs"][3]
	_check(zulu["display_status"] == "valid" and zulu["duration_us"] == 1250000 and zulu["chart_schema_version"] == "1.0.0" and zulu["artwork_label"] == "No artwork", "library exposes required metadata", failures)
	var source := root.path_join("original.musicxml"); files.write_text(source, "original source")
	var preview := service.delete_preview(repository_root, repositories.songs, "z-song")
	_check(preview.get("ok") and "packages/z-song" in preview["message"] and "Original MusicXML and audio are not changed" in preview["message"], "delete preview names exact cache and source policy", failures)
	var not_confirmed := service.delete_song(repository_root, repositories.songs, "z-song", false)
	_check(not_confirmed.get("confirmation_required") and files.directory_exists(repository_root.path_join("packages/z-song")), "delete requires confirmation", failures)
	var deleted := service.delete_song(repository_root, repositories.songs, "z-song", true)
	_check(deleted.get("ok") and not files.directory_exists(repository_root.path_join("packages/z-song")) and FileAccess.get_file_as_string(source) == "original source", "confirmed delete removes cache but not source", failures)
	_check(service.query(repository_root, repositories.songs, "profile-a")["songs"].size() == 3, "delete updates atomic index", failures)
	var unsafe_index: Dictionary = repositories.songs.load()["document"]; unsafe_index["songs"].append({"song_id":"unsafe", "import_version":1, "status":"valid", "title":"Unsafe", "package_path":"../outside"}); repositories.songs.save(unsafe_index)
	var unsafe: Dictionary = service.query(repository_root, repositories.songs, "profile-a")["songs"].filter(func(song: Dictionary) -> bool: return song.get("song_id") == "unsafe")[0]
	_check(unsafe["display_status"] == "invalid" and unsafe["diagnostics"][0]["code"] == "unsafe_repository_path", "index path traversal is isolated", failures)
	files.remove_tree(root); _finish(failures, 13)

func _make_package(files: RefCounted, root: String, song_id: String, title: String, profile_id: String, assets: bool, has_audio: bool = true) -> void:
	var relative := "packages/%s/v1-cache" % song_id; var path := root.path_join(relative); DirAccess.make_dir_recursive_absolute(path)
	var package := {"schema_version":"1.0.0", "song_id":song_id, "import_version":1, "title":title, "artist":"Artist", "duration_us":1250000, "chart_schema_version":"1.0.0", "artwork_path":"", "profile_id":profile_id, "chart_path":"chart.json", "audio":{"present":has_audio, "runtime_path":"runtime.ogg" if has_audio else ""}}
	files.write_text(path.path_join("package.json"), Canonical.encode(package) + "\n")
	if assets: files.write_text(path.path_join("chart.json"), "{}\n")
	if assets and has_audio: files.write_text(path.path_join("runtime.ogg"), "fixture")

func _entry(song_id: String, title: String) -> Dictionary:
	return {"song_id":song_id, "import_version":1, "status":"valid", "title":title, "package_path":"packages/%s/v1-cache" % song_id}

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P208_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
