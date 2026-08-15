class_name SongLibraryService
extends RefCounted

const PerformanceLayouts := preload("res://application/performance_layout_service.gd")

var _files: RefCounted

func _init(file_backend: RefCounted) -> void:
	_files = file_backend

func loading_state() -> Dictionary:
	return {"state":"loading", "label":"LOADING — Reading local song metadata.", "songs":[]}

func query(repository_root: String, song_repository: RefCounted, selected_profile_id: String) -> Dictionary:
	var loaded: Dictionary = song_repository.load()
	if not loaded.get("ok", false): return {"ok":false, "state":"invalid", "songs":[], "diagnostics":[_diagnostic(str(loaded.get("code", "song_index_error")), "song-index", str(loaded.get("error", "Song index could not be loaded.")), "Restore the index backup or check storage permissions.")]}
	var songs: Array[Dictionary] = []
	for value: Variant in loaded["document"].get("songs", []):
		if value is not Dictionary: continue
		songs.append(_inspect_entry(repository_root, value as Dictionary, selected_profile_id))
	songs.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key := "%s|%s" % [str(left.get("title", "")).to_lower(), left.get("song_id", "")]
		var right_key := "%s|%s" % [str(right.get("title", "")).to_lower(), right.get("song_id", "")]
		return left_key < right_key)
	return {"ok":true, "state":"empty" if songs.is_empty() else "ready", "label":"EMPTY — Import a MusicXML or NotePan score to begin." if songs.is_empty() else "%d song(s)" % songs.size(), "songs":songs, "diagnostics":[]}

func delete_preview(repository_root: String, song_repository: RefCounted, song_id: String) -> Dictionary:
	var loaded: Dictionary = song_repository.load()
	if not loaded.get("ok", false): return {"ok":false, "diagnostics":[_diagnostic(str(loaded.get("code", "song_index_error")), "song-index", str(loaded.get("error", "Song index could not be loaded.")), "Check storage permissions.")]}
	for value: Variant in loaded["document"].get("songs", []):
		if value is Dictionary and value.get("song_id") == song_id:
			var package_root: Dictionary = _files.resolve_relative(repository_root, "packages/%s" % song_id)
			if not package_root.get("ok", false): return package_root
			return {"ok":true, "song_id":song_id, "title":value.get("title", song_id), "active_package":value.get("package_path", ""), "delete_relative_paths":["packages/%s" % song_id], "message":"Delete '%s' and all cached import versions under packages/%s? Original score and audio are not changed." % [value.get("title", song_id), song_id]}
	return {"ok":false, "diagnostics":[_diagnostic("song_not_found", song_id, "Song is not present in the index.", "Refresh Song Library.")]}

func delete_song(repository_root: String, song_repository: RefCounted, song_id: String, confirmed: bool) -> Dictionary:
	var preview := delete_preview(repository_root, song_repository, song_id)
	if not preview.get("ok", false): return preview
	if not confirmed: return {"ok":false, "confirmation_required":true, "preview":preview, "diagnostics":[]}
	var loaded: Dictionary = song_repository.load()
	if not loaded.get("ok", false): return loaded
	var index: Dictionary = loaded["document"]
	var retained: Array = []
	for value: Variant in index.get("songs", []):
		if value is Dictionary and value.get("song_id") != song_id: retained.append(value)
	index["songs"] = retained
	var saved: Dictionary = song_repository.save(index)
	if not saved.get("ok", false): return {"ok":false, "diagnostics":[_diagnostic(str(saved.get("code", "song_index_error")), "song-index", str(saved.get("error", "Song index could not be saved.")), "Check storage permissions and retry.")]}
	var package_root: Dictionary = _files.resolve_relative(repository_root, "packages/%s" % song_id)
	if not package_root.get("ok", false): return package_root
	var removed: Dictionary = _files.remove_tree(package_root["path"])
	if not removed.get("ok", false): return {"ok":true, "song_id":song_id, "warning":removed, "message":"Song was removed from Library, but orphan cache cleanup failed."}
	return {"ok":true, "song_id":song_id, "deleted_relative_paths":preview["delete_relative_paths"], "source_files_untouched":true}

func _inspect_entry(repository_root: String, entry: Dictionary, selected_profile_id: String) -> Dictionary:
	var view := entry.duplicate(true)
	view["diagnostics"] = []
	view["display_status"] = "valid"
	view["playable"] = true
	var resolved: Dictionary = _files.resolve_relative(repository_root, str(entry.get("package_path", "")))
	if not resolved.get("ok", false): return _invalid(view, resolved.get("diagnostics", []))
	var package_path: String = resolved["path"]
	var package_result: Dictionary = _files.read_json(package_path.path_join("package.json"), 1024 * 1024)
	if not package_result.get("ok", false): return _invalid(view, package_result.get("diagnostics", []))
	var package: Dictionary = package_result["document"]
	var package_version := str(package.get("schema_version", ""))
	if package_version not in ["1.0.0", "1.1.0", "1.2.0", "1.3.0"] or package.get("song_id") != entry.get("song_id") or int(package.get("import_version", 0)) != int(entry.get("import_version", -1)):
		return _invalid(view, [_diagnostic("package_metadata_mismatch", entry.get("package_path", ""), "Package identity/version does not match the song index.", "Re-import or delete this song.")])
	var handpan_scale_name := ""
	if package.has("handpan_scale_name"):
		var scale_value: Variant = package["handpan_scale_name"]
		if package_version not in ["1.1.0", "1.2.0", "1.3.0"] or scale_value is not String or not _valid_handpan_scale_name(str(scale_value)):
			return _invalid(view, [_diagnostic("invalid_handpan_scale_name", entry.get("package_path", ""), "Package handpan_scale_name is not valid for its schema version.", "Re-import with supported scale metadata and a trimmed single-line scale name of at most 80 characters.")])
		handpan_scale_name = str(scale_value)
	var required_assets: Array[String] = [str(package.get("chart_path", ""))]
	if package_version in ["1.2.0", "1.3.0"]:
		var source_format := str(package.get("source", {}).get("format", ""))
		var source_asset := str(package.get("source", {}).get("stored_path", ""))
		var source_extension := str(package.get("source", {}).get("extension", ""))
		var expected_importer := ("panbeat-score-importer-v3" if package_version == "1.3.0" else "panbeat-score-importer-v2") if source_format == "notepan" else ("panbeat-musicxml-importer-v2" if package_version == "1.3.0" else "panbeat-musicxml-importer-v1")
		var extension_valid := source_extension == ".pan" if source_format == "notepan" else source_extension in [".musicxml", ".xml", ".mxl"]
		if source_format not in ["musicxml", "notepan"] or source_asset != ("source.pan" if source_format == "notepan" else "source.musicxml") or package.get("importer_version") != expected_importer or not extension_valid:
			return _invalid(view, [_diagnostic("package_source_metadata_invalid", entry.get("package_path", ""), "Package source format and stored path do not agree.", "Re-import or delete this song.")])
		required_assets.append(source_asset)
	var runtime_audio_path := str(package.get("audio", {}).get("runtime_path", ""))
	if not runtime_audio_path.is_empty(): required_assets.append(runtime_audio_path)
	for asset: String in required_assets:
		var asset_result: Dictionary = _files.resolve_relative(package_path, asset)
		if not asset_result.get("ok", false) or not _files.file_exists(str(asset_result.get("path", ""))): return _invalid(view, [_diagnostic("package_asset_missing", asset, "An imported package asset is missing.", "Re-import or delete this song.")])
	view["title"] = package.get("title", entry.get("title", entry.get("song_id", "")))
	view["artist"] = package.get("artist", "")
	view["handpan_scale_name"] = handpan_scale_name
	view["performance_layout"] = package.get("performance_layout", {})
	if package_version == "1.3.0" and not _valid_performance_layout(view["performance_layout"]):
		return _invalid(view, [_diagnostic("invalid_performance_layout", entry.get("package_path", ""), "Package performance layout is invalid.", "Re-import the song.")])
	view["duration_us"] = int(package.get("duration_us", 0))
	view["chart_schema_version"] = package.get("chart_schema_version", "unknown")
	view["artwork_label"] = "No artwork"
	if package_version in ["1.2.0", "1.3.0"]:
		var import_diagnostics: Variant = package.get("import_diagnostics", [])
		if import_diagnostics is not Array: return _invalid(view, [_diagnostic("package_diagnostics_invalid", entry.get("package_path", ""), "Package import diagnostics are invalid.", "Re-import or delete this song.")])
		for diagnostic: Variant in import_diagnostics:
			if diagnostic is not Dictionary or diagnostic.get("severity") != "warning": return _invalid(view, [_diagnostic("package_diagnostics_invalid", entry.get("package_path", ""), "Package import diagnostics are invalid.", "Re-import or delete this song.")])
			(view["diagnostics"] as Array).append((diagnostic as Dictionary).duplicate(true))
		if not (view["diagnostics"] as Array).is_empty(): view["display_status"] = "warning"
	view["profile_compatibility"] = "compatible" if package.get("profile_id") == selected_profile_id else "incompatible"
	if view["profile_compatibility"] == "incompatible":
		view["display_status"] = "warning"
		view["playable"] = false
		(view["diagnostics"] as Array).append(_diagnostic("profile_incompatible", entry.get("package_path", ""), "Song requires profile %s; selected profile is %s." % [package.get("profile_id", ""), selected_profile_id], "Select the required Instrument Profile before playing."))
	return view

func _valid_handpan_scale_name(value: String) -> bool:
	return not value.is_empty() and value.length() <= 80 and value == value.strip_edges() and "\n" not in value and "\r" not in value and "\t" not in value

func _valid_performance_layout(value: Variant) -> bool:
	return value is Dictionary and PerformanceLayouts.validate(value as Dictionary)

func _invalid(view: Dictionary, diagnostics: Array) -> Dictionary:
	view["display_status"] = "invalid"; view["playable"] = false; view["profile_compatibility"] = "unknown"; view["artwork_label"] = "Unavailable"; view["diagnostics"] = diagnostics
	return view

func _diagnostic(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"severity":"error" if code != "profile_incompatible" else "warning", "code":code, "file":file, "part":"", "measure":"", "element":"song-library", "message":message, "remediation":remediation}
