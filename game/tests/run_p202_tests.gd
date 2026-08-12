extends SceneTree

const MigrationRunner := preload("res://application/schema_migration_runner.gd")
const AtomicStore := preload("res://infrastructure/atomic_json_store.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")

class MemoryBackend extends RefCounted:
	var files: Dictionary = {}
	var fail_write_code: String = ""
	var fail_publish_once: bool = false
	func ensure_directory(_path: String) -> Dictionary: return {"ok": true}
	func exists(path: String) -> bool: return files.has(path)
	func read_text(path: String) -> Dictionary:
		if not files.has(path): return {"ok": false, "code": "not_found", "error": "missing"}
		return {"ok": true, "text": files[path]}
	func write_text(path: String, text: String) -> Dictionary:
		if not fail_write_code.is_empty():
			var code := fail_write_code; fail_write_code = ""
			return {"ok": false, "code": code, "error": "%s simulated" % code}
		files[path] = text
		return {"ok": true}
	func rename(from_path: String, to_path: String) -> Dictionary:
		if fail_publish_once and from_path.ends_with(".tmp"):
			fail_publish_once = false
			return {"ok": false, "code": "io_error", "error": "publish interrupted"}
		if not files.has(from_path): return {"ok": false, "code": "not_found", "error": "missing source"}
		files[to_path] = files[from_path]
		files.erase(from_path)
		return {"ok": true}
	func remove(path: String) -> Dictionary:
		files.erase(path)
		return {"ok": true}

func _initialize() -> void:
	var failures: Array[String] = []
	var migrated := MigrationRunner.migrate("settings", {"schema_version":"0.1.0", "selected_port":"MN-10", "profile_id":"profile", "offsets":[]})
	_check(migrated.get("ok") == true and migrated["document"].get("selected_midi_port") == "MN-10" and not migrated["document"].has("selected_port"), "known schema migration", failures)
	_check(MigrationRunner.migrate("settings", {"schema_version":"2.0.0"}).get("code") == "unknown_schema_major", "unknown major rejected", failures)
	_check(MigrationRunner.migrate("song_index", {"songs":[]}).get("code") == "missing_schema_version", "missing version rejected", failures)
	_check(MigrationRunner.migrate("settings", {"schema_version":"1.0.0", "profile_id":"profile"}).get("code") == "invalid_settings", "missing field diagnostic", failures)

	var memory := MemoryBackend.new()
	var repositories := Repositories.new("/isolated", memory)
	_check(repositories.settings.path() != repositories.songs.path() and repositories.songs.path() != repositories.results.path(), "separate retention paths", failures)
	var defaults: Dictionary = repositories.settings.load()
	_check(defaults.get("created_default") == true and defaults["document"].get("schema_version") == "1.0.0", "default settings without user data", failures)
	var settings := MigrationRunner.empty_document("settings")
	settings["selected_midi_port"] = "MN-10"
	_check(repositories.settings.save(settings).get("ok") == true and repositories.settings.load()["document"].get("selected_midi_port") == "MN-10", "settings save and readback", failures)
	settings["selected_midi_port"] = "replacement"
	_check(repositories.settings.save(settings).get("ok") == true, "second settings version", failures)
	memory.files[repositories.settings.path()] = "{corrupt"
	var recovered: Dictionary = repositories.settings.load()
	_check(recovered.get("ok") == true and recovered.get("recovered_from_backup") == true and recovered["document"].get("selected_midi_port") == "MN-10", "corrupt primary recovers backup", failures)

	var fault_backend := MemoryBackend.new()
	var fault_repositories := Repositories.new("/faults", fault_backend)
	fault_backend.fail_write_code = "disk_full"
	_check(fault_repositories.settings.save(MigrationRunner.empty_document("settings")).get("code") == "disk_full", "disk full diagnostic", failures)
	fault_backend.fail_write_code = "permission_denied"
	_check(fault_repositories.settings.save(MigrationRunner.empty_document("settings")).get("code") == "permission_denied", "permission diagnostic", failures)
	var old_settings := MigrationRunner.empty_document("settings")
	old_settings["selected_midi_port"] = "old"
	fault_repositories.settings.save(old_settings)
	var new_settings := old_settings.duplicate(true); new_settings["selected_midi_port"] = "new"
	fault_backend.fail_publish_once = true
	var interrupted: Dictionary = fault_repositories.settings.save(new_settings)
	_check(interrupted.get("ok") == false and interrupted.get("previous_restored") == true and fault_repositories.settings.load()["document"].get("selected_midi_port") == "old", "interrupted publication restores previous data", failures)

	var retained := Repositories.new("/retention", MemoryBackend.new())
	retained.settings.save(MigrationRunner.empty_document("settings"))
	retained.songs.save(MigrationRunner.empty_document("song_index"))
	retained.results.save(MigrationRunner.empty_document("result_history"))
	retained.settings.delete()
	_check(retained.settings.load().get("created_default") == true and not retained.songs.load().get("created_default", false) and not retained.results.load().get("created_default", false), "settings deletion does not delete songs or results", failures)

	var temporary_root := OS.get_temp_dir().path_join("panbeat-p202-%d" % Time.get_ticks_usec())
	var native_repositories := Repositories.new(temporary_root, NativeBackend.new())
	var native_document := MigrationRunner.empty_document("result_history")
	native_document["records"] = [{"record_id":"one"}]
	var native_save: Dictionary = native_repositories.results.save(native_document)
	_check(native_save.get("ok") == true, "native temporary directory atomic write: %s" % native_save, failures)
	var restarted_repositories := Repositories.new(temporary_root, NativeBackend.new())
	var native_load: Dictionary = restarted_repositories.results.load()
	_check(native_load.get("ok") == true and native_load.get("document", {}).get("records", []).size() == 1, "native persistence survives repository restart: %s" % native_load, failures)
	_remove_tree(temporary_root)
	_finish(failures, 15)

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty():
		print("PANBEAT_P202_TESTS_OK %d/%d" % [count, count])
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
