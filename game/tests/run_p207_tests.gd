extends SceneTree

const Mxl := preload("res://infrastructure/secure_mxl_reader.gd")
const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Audio := preload("res://infrastructure/ffmpeg_audio_converter.gd")
const Importer := preload("res://application/song_import_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")

class FailingRepository extends RefCounted:
	func load() -> Dictionary: return {"ok":true, "document":{"schema_version":"1.0.0", "songs":[]}}
	func save(_document: Dictionary) -> Dictionary: return {"ok":false, "code":"disk_full", "error":"simulated index failure"}

class CancelCounter extends RefCounted:
	var calls := 0
	var cancel_at := 1
	func check() -> bool: calls += 1; return calls >= cancel_at

func _initialize() -> void:
	var failures: Array[String] = []
	var files := Files.new()
	var root := "/tmp/panbeat-p207-tests"
	var initial_cleanup := files.remove_tree(root)
	if not initial_cleanup.get("ok", false): push_error("P207 test cleanup failed: %s" % str(initial_cleanup)); quit(1); return
	DirAccess.make_dir_recursive_absolute(root)
	var xml := ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/musescore-minimal.musicxml")
	var audio := ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/orbit-practice.wav")
	var profile := JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))) as Dictionary
	var source_before := FileAccess.get_sha256(xml); var audio_before := FileAccess.get_sha256(audio)
	var repositories := Repositories.new(root.path_join("documents"))
	var importer := Importer.new(files, Audio.new())
	var aligned := importer.reconcile_chart_audio_duration({"duration_us":1_000_007, "notes":[{"timestamp_us":900_000}], "tempo_map":[{"start_us":0}]}, 1_000_000)
	_check(aligned.get("ok", false) and aligned.get("chart", {}).get("duration_us") == 1_000_000, "sub-10ms score/audio end rounding is aligned to audio duration", failures)
	_check(_code(importer.reconcile_chart_audio_duration({"duration_us":1_010_001, "notes":[], "tempo_map":[]}, 1_000_000)) == "chart_exceeds_audio_duration", "material score overrun remains rejected", failures)
	_check(_code(importer.reconcile_chart_audio_duration({"duration_us":1_000_007, "notes":[{"timestamp_us":1_000_001}], "tempo_map":[]}, 1_000_000)) == "chart_exceeds_audio_duration", "an attack beyond audio remains rejected inside end tolerance", failures)
	var request := {"score_path":xml, "audio_path":audio, "profile":profile, "song_id":"p207-song", "title":"P207 Fixture", "artist":"PanBeat"}
	var imported := importer.import_song(request, root.path_join("library"), repositories.songs)
	_check(imported.get("ok") and not imported.get("duplicate") and int(imported.get("song", {}).get("import_version", 0)) == 1, "valid MusicXML/audio imported: %s" % str(imported), failures)
	_check(FileAccess.file_exists(str(imported.get("published_path", "")).path_join("chart.json")) and FileAccess.file_exists(str(imported.get("published_path", "")).path_join("runtime.ogg")), "validated package assets published", failures)
	_check(FileAccess.get_sha256(xml) == source_before and FileAccess.get_sha256(audio) == audio_before, "source files remain unchanged", failures)
	var duplicate := importer.import_song(request, root.path_join("library"), repositories.songs)
	_check(duplicate.get("ok") and duplicate.get("duplicate") and repositories.songs.load()["document"]["songs"].size() == 1, "identical content is idempotent duplicate", failures)
	var mxl_path := root.path_join("valid.mxl")
	_create_mxl(mxl_path, FileAccess.get_file_as_bytes(xml), true)
	var read_mxl := Mxl.read_file(mxl_path)
	_check(read_mxl.get("ok") and read_mxl.get("rootfile") == "score.musicxml", "MXL container rootfile resolved", failures)
	var mxl_request := request.duplicate(true); mxl_request["score_path"] = mxl_path
	_check(importer.import_song(mxl_request, root.path_join("library"), repositories.songs).get("duplicate") == true, "MXL and plain XML with identical root content deduplicate", failures)
	var changed := request.duplicate(true); changed["pitch_mapping"] = {"D4":{"technique":"tone", "target_id":"tone-1"}}
	var updated := importer.import_song(changed, root.path_join("library"), repositories.songs)
	_check(updated.get("ok") and int(updated["song"]["import_version"]) == 2 and repositories.songs.load()["document"]["songs"].size() == 1, "changed cache contract increments stable song version", failures)
	var silent_request := {"score_path":ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/chord.musicxml"), "profile":profile, "song_id":"p207-silent", "title":"P207 Chord Without Backing Audio"}
	var silent_imported := importer.import_song(silent_request, root.path_join("library"), repositories.songs)
	var silent_package: Dictionary = silent_imported.get("package", {})
	var silent_chart_result: Dictionary = files.read_json(str(silent_imported.get("published_path", "")).path_join("chart.json"), 1024 * 1024) if silent_imported.get("ok") else {}
	var silent_notes: Array = silent_chart_result.get("document", {}).get("notes", [])
	_check(silent_imported.get("ok") and not FileAccess.file_exists(str(silent_imported.get("published_path", "")).path_join("runtime.ogg")) and not silent_package.get("audio", {}).get("present", true) and silent_notes.size() == 3 and silent_notes[0]["timestamp_us"] == silent_notes[1]["timestamp_us"], "MusicXML chord imports as simultaneous notes without optional backing audio", failures)
	var mixed_pitch_request := {"score_path":ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/mixed-supported-unsupported-pitch.musicxml"), "profile":profile, "song_id":"p207-mixed-pitch", "title":"P207 Mixed Pitch"}
	var mixed_pitch_imported := importer.import_song(mixed_pitch_request, root.path_join("library"), repositories.songs)
	var mixed_pitch_chart_result: Dictionary = files.read_json(str(mixed_pitch_imported.get("published_path", "")).path_join("chart.json"), 1024 * 1024) if mixed_pitch_imported.get("ok") else {}
	var mixed_pitch_diagnostics: Array = mixed_pitch_imported.get("package", {}).get("import_diagnostics", [])
	_check(mixed_pitch_imported.get("ok") and mixed_pitch_chart_result.get("document", {}).get("notes", []).size() == 2 and mixed_pitch_diagnostics.is_empty() and mixed_pitch_imported.get("package", {}).get("performance_layout", {}).get("slots", []).size() == 2, "non-D-Kurd MusicXML pitches receive a complete song-specific layout", failures)
	var octave_request := {"score_path":xml, "profile":profile, "notation_octave_shift":-1, "song_id":"p207-octave-high", "title":"P207 Written Octave High"}
	var octave_imported := importer.import_song(octave_request, root.path_join("library"), repositories.songs)
	var octave_chart_result: Dictionary = files.read_json(str(octave_imported.get("published_path", "")).path_join("chart.json"), 1024 * 1024) if octave_imported.get("ok") else {}
	_check(octave_imported.get("ok") and octave_imported.get("package", {}).get("notation_octave_shift") == -1 and octave_chart_result.get("document", {}).get("notes", [])[0]["target_id"] == "ding", "one-octave-high notation imports against sounding pitches one octave lower", failures)
	var scale_request := request.duplicate(true); scale_request["song_id"] = "p207-scale"; scale_request["overlay_path"] = ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p205-slap-overlay.json")
	var scale_imported := importer.import_song(scale_request, root.path_join("library"), repositories.songs)
	_check(scale_imported.get("ok") and scale_imported.get("package", {}).get("schema_version") == "1.3.0" and scale_imported.get("package", {}).get("handpan_scale_name") == "D Kurd 9" and not scale_imported.get("package", {}).get("chart_path", "").is_empty(), "overlay scale metadata is persisted with the song-specific layout", failures)
	var changed_overlay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(scale_request["overlay_path"]))) as Dictionary; changed_overlay["handpan_scale_name"] = "E Amara 9"
	var changed_overlay_path := root.path_join("changed-scale-overlay.json"); files.write_text(changed_overlay_path, JSON.stringify(changed_overlay) + "\n")
	var changed_scale_request := scale_request.duplicate(true); changed_scale_request["overlay_path"] = changed_overlay_path
	var changed_scale_import := importer.import_song(changed_scale_request, root.path_join("library"), repositories.songs)
	_check(changed_scale_import.get("ok") and int(changed_scale_import.get("song", {}).get("import_version", 0)) == 2 and changed_scale_import.get("package", {}).get("handpan_scale_name") == "E Amara 9", "changing only overlay scale metadata invalidates cache and increments import version", failures)
	var invalid_octave_request := octave_request.duplicate(true); invalid_octave_request["song_id"] = "invalid-octave"; invalid_octave_request["notation_octave_shift"] = -2
	_check(_code(importer.import_song(invalid_octave_request, root.path_join("invalid-octave-root"), repositories.songs)) == "invalid_notation_octave_shift", "unsupported notation octave shift is diagnosed", failures)
	var cancelled := CancelCounter.new(); cancelled.cancel_at = 1
	_check(_code(importer.import_song(request, root.path_join("cancelled"), repositories.songs, cancelled.check)) == "import_cancelled", "early cancellation publishes nothing", failures)
	var late_cancel := CancelCounter.new(); late_cancel.cancel_at = 4
	var late_request := request.duplicate(true); late_request["song_id"] = "cancel-late"; late_request["pitch_mapping"] = {"D4":{"technique":"tone", "target_id":"tone-2"}}
	_check(_code(importer.import_song(late_request, root.path_join("cancelled-late"), repositories.songs, late_cancel.check)) == "import_cancelled" and not files.directory_exists(root.path_join("cancelled-late/packages")), "post-conversion cancellation cleans staging and remains invisible", failures)
	var bad_overlay := ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p205-slap-overlay.json")
	var mismatch_request := request.duplicate(true); mismatch_request["overlay_path"] = bad_overlay; mismatch_request["score_path"] = ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/unsupported.musicxml")
	_check(not importer.import_song(mismatch_request, root.path_join("invalid"), repositories.songs).get("ok"), "invalid score publishes no package", failures)
	var extension_request := request.duplicate(true); extension_request["score_path"] = audio
	var extension_result := importer.import_song(extension_request, root.path_join("invalid-extension"), repositories.songs)
	_check(_code(extension_result) == "unsupported_extension" and _diagnostic_complete(extension_result), "source extension diagnostic is actionable", failures)

	var missing_container := root.path_join("missing-container.mxl")
	_create_mxl(missing_container, FileAccess.get_file_as_bytes(xml), false)
	_check(_code(Mxl.read_file(missing_container)) == "mxl_container_missing", "MXL missing container rejected", failures)

	_check(_manifest_code([_entry("../escape.xml", 10, 10)]) == "archive_path_traversal", "Zip Slip traversal rejected", failures)
	_check(_manifest_code([_entry("/absolute.xml", 10, 10)]) == "archive_absolute_or_backslash_path", "absolute archive path rejected", failures)
	var symlink := _entry("score.musicxml", 10, 10); symlink["file_type"] = 0xA000
	_check(_manifest_code([symlink]) == "archive_special_entry", "archive symlink rejected", failures)
	_check(_manifest_code([_entry("bomb.xml", 1, 101)]) == "archive_compression_ratio", "per-entry zip bomb rejected", failures)
	_check(_manifest_code([_entry("huge.xml", 700000, Mxl.MAX_EXPANDED_BYTES + 1)]) == "archive_expanded_size_limit", "expanded-size limit rejected", failures)
	var duplicates: Array[Dictionary] = [_entry("score.xml", 10, 10), _entry("score.xml", 10, 10)]
	_check(_manifest_code(duplicates) == "archive_duplicate_entry", "duplicate archive entry rejected", failures)
	var too_many: Array[Dictionary] = []; for index: int in Mxl.MAX_ENTRIES + 1: too_many.append(_entry("f%d.xml" % index, 10, 10))
	_check(_manifest_code(too_many) == "archive_entry_limit", "archive entry count limit rejected", failures)

	var failing_request := request.duplicate(true); failing_request["song_id"] = "index-failure"
	var failed_root := root.path_join("failed-index")
	var index_failure := importer.import_song(failing_request, failed_root, FailingRepository.new())
	_check(_code(index_failure) == "disk_full" and _directory_is_empty(failed_root.path_join("packages/index-failure")), "index failure removes unpublished package", failures)
	var corrupt_audio := root.path_join("corrupt.wav"); files.write_text(corrupt_audio, "not audio")
	var audio_request := request.duplicate(true); audio_request["song_id"] = "bad-audio"; audio_request["audio_path"] = corrupt_audio
	_check(_code(importer.import_song(audio_request, root.path_join("bad-audio-root"), repositories.songs)) == "corrupt_or_unreadable_audio", "corrupt audio rejected before publication", failures)
	files.remove_tree(root)
	_finish(failures, 29)

func _create_mxl(path: String, score: PackedByteArray, include_container: bool) -> void:
	var packer := ZIPPacker.new(); packer.open(path)
	if include_container:
		packer.start_file("META-INF/container.xml")
		packer.write_file("<?xml version=\"1.0\"?><container><rootfiles><rootfile full-path=\"score.musicxml\" media-type=\"application/vnd.recordare.musicxml+xml\"/></rootfiles></container>".to_utf8_buffer())
		packer.close_file()
	packer.start_file("score.musicxml"); packer.write_file(score); packer.close_file(); packer.close()

func _entry(path: String, compressed: int, expanded: int) -> Dictionary:
	return {"path":path, "compressed_bytes":compressed, "expanded_bytes":expanded, "encrypted":false, "file_type":0x8000}

func _manifest_code(entries: Array[Dictionary]) -> String:
	return _code(Mxl.validate_declared_entries(entries))

func _code(result: Dictionary) -> String:
	var diagnostics: Array = result.get("diagnostics", [])
	return str(diagnostics[0].get("code", "")) if not diagnostics.is_empty() else ""

func _diagnostic_complete(result: Dictionary) -> bool:
	var diagnostics: Array = result.get("diagnostics", [])
	return not diagnostics.is_empty() and diagnostics[0].has_all(["severity", "code", "file", "part", "measure", "element", "remediation"])

func _directory_is_empty(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path): return true
	var directory := DirAccess.open(path); return directory != null and directory.get_files().is_empty() and directory.get_directories().is_empty()

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P207_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
