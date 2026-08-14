class_name SongImportService
extends RefCounted

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const NotePanReader := preload("res://infrastructure/safe_notepan_reader.gd")
const MxlReader := preload("res://infrastructure/secure_mxl_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")
const Canonical := preload("res://application/canonical_json.gd")
const IMPORTER_VERSION := "panbeat-musicxml-importer-v1"
const NOTEPAN_IMPORTER_VERSION := "panbeat-score-importer-v2"
const PACKAGE_VERSION := "1.2.0"
const CACHE_CONTRACT_VERSION := "notepan-hand-lanes-v2"
const AUDIO_END_TOLERANCE_US := 10_000

var _files: RefCounted
var _audio: RefCounted

func _init(file_backend: RefCounted, audio_converter: RefCounted) -> void:
	_files = file_backend
	_audio = audio_converter

func import_song(request: Dictionary, repository_root: String, song_repository: RefCounted, cancelled: Callable = Callable()) -> Dictionary:
	var required := ["score_path", "profile"]
	for key: String in required:
		if not request.has(key): return _failure("missing_import_field", str(request.get("score_path", "request")), "Import request requires %s." % key, "Select a score and Instrument Profile.")
	if _cancelled(cancelled): return _failure("import_cancelled", "request", "Import was cancelled before validation.", "Start import again when ready.")
	var score_path := str(request["score_path"])
	var extension := "." + score_path.get_extension().to_lower()
	var score_limit := MxlReader.MAX_ARCHIVE_BYTES if extension == ".mxl" else NotePanReader.MAX_SOURCE_BYTES if extension == ".pan" else Reader.MAX_SOURCE_BYTES
	var score_file: Dictionary = _files.inspect_file(score_path, [".musicxml", ".xml", ".mxl", ".pan"], score_limit)
	if not score_file.get("ok", false): return score_file
	var source_format := "notepan" if score_file["extension"] == ".pan" else "musicxml"
	if source_format == "notepan" and not str(request.get("overlay_path", "")).is_empty(): return _failure("notepan_overlay_unsupported", score_path, "PanBeat overlay cannot be combined with a NotePan source.", "Clear the overlay selection before importing .pan.")
	if source_format == "notepan" and int(request.get("notation_octave_shift", 0)) != 0: return _failure("notepan_octave_shift_unsupported", score_path, "Written-octave mapping does not apply to NotePan absolute pitches.", "Turn off Written 1 octave high for .pan import.")
	var score_bytes: PackedByteArray
	var score_location := str(request["score_path"])
	var archive_manifest: Array = []
	if score_file["extension"] == ".mxl":
		var mxl := MxlReader.read_file(score_location)
		if not mxl.get("ok", false): return mxl
		score_bytes = mxl["bytes"]; score_location = "%s#%s" % [score_location, mxl["rootfile"]]; archive_manifest = mxl["entries"]
	else: score_bytes = score_file["bytes"]
	var source_sha: String = _files.hash_bytes(score_bytes)
	var parsed := NotePanReader.read_bytes(score_bytes, score_location) if source_format == "notepan" else Reader.read_bytes(score_bytes, score_location)
	if not parsed.get("ok", false): return parsed
	var import_diagnostics: Array = parsed.get("diagnostics", []).duplicate(true)
	if source_format == "notepan":
		for diagnostic: Dictionary in import_diagnostics: diagnostic["file"] = score_path.get_file()
	if _cancelled(cancelled): return _failure("import_cancelled", score_location, "Import was cancelled after score validation.", "No song was published.")
	var overlay: Dictionary = {}
	var overlay_sha := "none"
	var overlay_bytes := PackedByteArray()
	if not str(request.get("overlay_path", "")).is_empty():
		var overlay_file: Dictionary = _files.read_json(str(request["overlay_path"]), 1024 * 1024)
		if not overlay_file.get("ok", false): return overlay_file
		overlay = overlay_file["document"]; overlay_sha = overlay_file["sha256"]; overlay_bytes = overlay_file["bytes"]
	var chart_id := str(request.get("song_id", "song-%s" % source_sha.substr(0, 16)))
	if not _valid_id(chart_id): return _failure("invalid_song_id", "request", "song_id may contain only letters, digits, dot, underscore, and hyphen.", "Choose a portable song ID.")
	var source_metadata: Dictionary = parsed.get("metadata", {})
	var title := str(request.get("title", "")).strip_edges()
	if title.is_empty(): title = str(source_metadata.get("title", "")).strip_edges()
	if title.is_empty(): title = chart_id
	var artist := str(request.get("artist", "")).strip_edges()
	if artist.is_empty(): artist = str(source_metadata.get("artist", "")).strip_edges()
	var importer_version := NOTEPAN_IMPORTER_VERSION if source_format == "notepan" else IMPORTER_VERSION
	var compiled := Compiler.compile(parsed["score"], chart_id, importer_version)
	if not compiled.get("ok", false): return compiled
	var profile: Dictionary = request["profile"]
	if profile.get("schema_version") != "1.0.0" or str(profile.get("profile_id", "")).is_empty(): return _failure("unsupported_profile_version", "profile", "Instrument Profile must use schema 1.0.0 and contain profile_id.", "Select a supported versioned Instrument Profile.")
	var notation_octave_shift := int(request.get("notation_octave_shift", 0))
	if notation_octave_shift not in [-1, 0]: return _failure("invalid_notation_octave_shift", "request", "notation_octave_shift must be 0 or -1.", "Use -1 only when the score is written one octave above sounding pitch.")
	var merged := Merger.merge(compiled["chart"], overlay, source_sha, profile, request.get("pitch_mapping", {}), notation_octave_shift)
	if not merged.get("ok", false): return merged
	var audio_path := str(request.get("audio_path", ""))
	var has_audio := not audio_path.is_empty()
	var audio_file: Dictionary = {"sha256":"none"}
	if has_audio:
		audio_file = _files.inspect_file(audio_path, [".wav", ".ogg"], 512 * 1024 * 1024)
		if not audio_file.get("ok", false): return audio_file
	var profile_sha: String = _files.hash_bytes((Canonical.encode(profile) + "\n").to_utf8_buffer())
	var mapping_sha: String = _files.hash_bytes((Canonical.encode(request.get("pitch_mapping", {})) + "\n").to_utf8_buffer())
	var cache_contract := {"importer_version":importer_version, "cache_contract_version":CACHE_CONTRACT_VERSION, "source_format":source_format, "source_sha256":source_sha, "overlay_sha256":overlay_sha, "profile_sha256":profile_sha, "pitch_mapping_sha256":mapping_sha, "notation_octave_shift":notation_octave_shift, "audio_sha256":audio_file["sha256"]}
	var cache_key: String = _files.hash_bytes((Canonical.encode(cache_contract) + "\n").to_utf8_buffer())
	var loaded: Dictionary = song_repository.load()
	if not loaded.get("ok", false): return _repository_failure(loaded)
	var index: Dictionary = loaded["document"]
	for value: Variant in index.get("songs", []):
		if value is Dictionary and value.get("cache_key") == cache_key: return {"ok":true, "duplicate":true, "song":value, "diagnostics":[]}
	var import_version := 1
	for value: Variant in index.get("songs", []):
		if value is Dictionary and value.get("song_id") == chart_id: import_version = maxi(import_version, int(value.get("import_version", 0)) + 1)
	var token := "%s-v%d-%s" % [chart_id, import_version, cache_key.substr(0, 12)]
	var staging_result: Dictionary = _files.create_staging(repository_root, token)
	if not staging_result.get("ok", false): return staging_result
	var staging: String = staging_result["path"]
	var final_path := repository_root.path_join("packages").path_join(chart_id).path_join("v%d-%s" % [import_version, cache_key.substr(0, 12)])
	var completed := false
	var result: Dictionary = {}
	if _cancelled(cancelled): result = _failure("import_cancelled", score_location, "Import was cancelled before conversion.", "No song was published.")
	var source_asset := "source.pan" if source_format == "notepan" else "source.musicxml"
	if result.is_empty(): result = _files.write_bytes(staging.path_join(source_asset), score_bytes)
	if result.get("ok", false) and not overlay_bytes.is_empty(): result = _files.write_bytes(staging.path_join("overlay.json"), overlay_bytes)
	if result.get("ok", false) and has_audio: result = _audio.convert(audio_path, staging.path_join("runtime.ogg"))
	var runtime_duration_us := roundi(float(result.get("duration_sec", 0.0)) * 1_000_000.0) if result.get("ok", false) and has_audio else int(merged["chart"].get("duration_us", 0))
	var runtime_chart: Dictionary = merged["chart"]
	if result.get("ok", false) and has_audio:
		var reconciled := reconcile_chart_audio_duration(runtime_chart, runtime_duration_us, score_location)
		if reconciled.get("ok", false): runtime_chart = reconciled["chart"]
		else: result = reconciled
	if result.get("ok", false): result = _files.write_text(staging.path_join("chart.json"), Canonical.encode(runtime_chart) + "\n")
	if result.get("ok", false) and _cancelled(cancelled): result = _failure("import_cancelled", score_location, "Import was cancelled after conversion.", "No song was published.")
	var package := {"schema_version":PACKAGE_VERSION, "song_id":chart_id, "import_version":import_version, "title":title, "artist":artist, "duration_us":runtime_duration_us, "chart_schema_version":str(merged["chart"].get("schema_version", "1.0.0")), "artwork_path":"", "status":"valid", "importer_version":importer_version, "profile_id":profile.get("profile_id", ""), "cache_key":cache_key, "notation_octave_shift":notation_octave_shift, "source":{"format":source_format, "stored_path":source_asset, "original_name":str(request["score_path"]).get_file(), "archive_rootfile":score_location.get_slice("#", 1) if "#" in score_location else "", "extension":score_file["extension"], "sha256":source_sha, "bytes":score_bytes.size(), "archive_entries":archive_manifest}, "overlay_sha256":overlay_sha, "audio":{"present":has_audio, "source_sha256":audio_file["sha256"], "runtime_path":"runtime.ogg" if has_audio else ""}, "chart_path":"chart.json", "import_diagnostics":import_diagnostics}
	if not merged.get("song_metadata", {}).is_empty(): package.merge(merged["song_metadata"])
	if source_format == "notepan":
		var scale_name := str(source_metadata.get("handpan_scale_name", ""))
		if _valid_scale_name(scale_name): package["handpan_scale_name"] = scale_name
		elif not scale_name.is_empty():
			var warning := _warning("invalid_notepan_scale_name", score_path.get_file(), "NotePan scale name is not a trimmed single-line value of at most 80 characters.", "The song remains playable and its scale is shown as Not specified.")
			import_diagnostics.append(warning); package["import_diagnostics"] = import_diagnostics
	if result.get("ok", false): result = _files.write_text(staging.path_join("package.json"), Canonical.encode(package) + "\n")
	if result.get("ok", false): result = _files.publish(staging, final_path)
	if result.get("ok", false):
		var relative_package_path := "packages/%s/v%d-%s" % [chart_id, import_version, cache_key.substr(0, 12)]
		var entry := {"song_id":chart_id, "import_version":import_version, "status":"valid", "title":package["title"], "artist":package["artist"], "duration_us":package["duration_us"], "chart_schema_version":package["chart_schema_version"], "artwork_path":package["artwork_path"], "profile_id":package["profile_id"], "cache_key":cache_key, "package_path":relative_package_path}
		var songs: Array = []
		for value: Variant in index.get("songs", []):
			if value is Dictionary and value.get("song_id") != chart_id: songs.append(value)
		songs.append(entry); songs.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left["song_id"]) < str(right["song_id"]))
		index["songs"] = songs
		var saved: Dictionary = song_repository.save(index)
		if not saved.get("ok", false):
			_files.remove_tree(final_path); result = _repository_failure(saved)
		else:
			completed = true; result = {"ok":true, "duplicate":false, "song":entry, "package":package, "published_path":final_path, "diagnostics":import_diagnostics}
	if not completed and _files.directory_exists(staging): _files.remove_tree(staging)
	return result

func reconcile_chart_audio_duration(chart: Dictionary, audio_duration_us: int, source: String = "score") -> Dictionary:
	var chart_duration_us := int(chart.get("duration_us", 0))
	if chart_duration_us <= audio_duration_us: return {"ok":true, "chart":chart}
	if chart_duration_us - audio_duration_us > AUDIO_END_TOLERANCE_US:
		return _failure("chart_exceeds_audio_duration", source, "The score extends beyond the selected audio file.", "Choose matching audio or shorten the score.")
	for note: Dictionary in chart.get("notes", []):
		if int(note.get("timestamp_us", 0)) > audio_duration_us:
			return _failure("chart_exceeds_audio_duration", source, "A score attack occurs beyond the selected audio file.", "Choose matching audio or shorten the score.")
	for tempo: Dictionary in chart.get("tempo_map", []):
		if int(tempo.get("start_us", 0)) > audio_duration_us:
			return _failure("chart_exceeds_audio_duration", source, "A score tempo event occurs beyond the selected audio file.", "Choose matching audio or shorten the score.")
	var aligned := chart.duplicate(true)
	aligned["duration_us"] = audio_duration_us
	return {"ok":true, "chart":aligned}

func _cancelled(callback: Callable) -> bool:
	return callback.is_valid() and bool(callback.call())

func _valid_id(value: String) -> bool:
	if value.is_empty(): return false
	for index: int in value.length():
		var character := value.substr(index, 1)
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-": return false
	return true

func _valid_scale_name(value: String) -> bool:
	return not value.is_empty() and value.length() <= 80 and value == value.strip_edges() and "\n" not in value and "\r" not in value and "\t" not in value

func _warning(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"severity":"warning", "code":code, "file":file, "part":"", "measure":"", "element":"import", "message":message, "remediation":remediation}

func _repository_failure(result: Dictionary) -> Dictionary:
	return _failure(str(result.get("code", "repository_error")), str(result.get("path", "song-index")), str(result.get("error", "Song index operation failed.")), "Check storage permissions, free space, and index version.")

func _failure(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"ok":false, "diagnostics":[{"severity":"error", "code":code, "file":file, "part":"", "measure":"", "element":"import", "message":message, "remediation":remediation}]}
