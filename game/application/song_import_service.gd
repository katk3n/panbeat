class_name SongImportService
extends RefCounted

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const MxlReader := preload("res://infrastructure/secure_mxl_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")
const Canonical := preload("res://application/canonical_json.gd")
const IMPORTER_VERSION := "panbeat-musicxml-importer-v1"
const PACKAGE_VERSION := "1.0.0"
const CACHE_CONTRACT_VERSION := "audio-duration-v1"

var _files: RefCounted
var _audio: RefCounted

func _init(file_backend: RefCounted, audio_converter: RefCounted) -> void:
	_files = file_backend
	_audio = audio_converter

func import_song(request: Dictionary, repository_root: String, song_repository: RefCounted, cancelled: Callable = Callable()) -> Dictionary:
	var required := ["score_path", "audio_path", "profile"]
	for key: String in required:
		if not request.has(key): return _failure("missing_import_field", str(request.get("score_path", "request")), "Import request requires %s." % key, "Select a score, audio file, and Instrument Profile.")
	if _cancelled(cancelled): return _failure("import_cancelled", "request", "Import was cancelled before validation.", "Start import again when ready.")
	var score_path := str(request["score_path"])
	var score_limit := MxlReader.MAX_ARCHIVE_BYTES if score_path.get_extension().to_lower() == "mxl" else Reader.MAX_SOURCE_BYTES
	var score_file: Dictionary = _files.inspect_file(score_path, [".musicxml", ".xml", ".mxl"], score_limit)
	if not score_file.get("ok", false): return score_file
	var score_bytes: PackedByteArray
	var score_location := str(request["score_path"])
	var archive_manifest: Array = []
	if score_file["extension"] == ".mxl":
		var mxl := MxlReader.read_file(score_location)
		if not mxl.get("ok", false): return mxl
		score_bytes = mxl["bytes"]; score_location = "%s#%s" % [score_location, mxl["rootfile"]]; archive_manifest = mxl["entries"]
	else: score_bytes = score_file["bytes"]
	var source_sha: String = _files.hash_bytes(score_bytes)
	var parsed := Reader.read_bytes(score_bytes, score_location)
	if not parsed.get("ok", false): return parsed
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
	if str(request.get("title", chart_id)).strip_edges().is_empty(): return _failure("invalid_title", "request", "Song title must not be empty.", "Enter a title or omit it to use the song ID.")
	var compiled := Compiler.compile(parsed["score"], chart_id)
	if not compiled.get("ok", false): return compiled
	var profile: Dictionary = request["profile"]
	if profile.get("schema_version") != "1.0.0" or str(profile.get("profile_id", "")).is_empty(): return _failure("unsupported_profile_version", "profile", "Instrument Profile must use schema 1.0.0 and contain profile_id.", "Select a supported versioned Instrument Profile.")
	var merged := Merger.merge(compiled["chart"], overlay, source_sha, profile, request.get("pitch_mapping", {}))
	if not merged.get("ok", false): return merged
	var audio_file: Dictionary = _files.inspect_file(str(request["audio_path"]), [".wav", ".ogg"], 512 * 1024 * 1024)
	if not audio_file.get("ok", false): return audio_file
	var profile_sha: String = _files.hash_bytes((Canonical.encode(profile) + "\n").to_utf8_buffer())
	var mapping_sha: String = _files.hash_bytes((Canonical.encode(request.get("pitch_mapping", {})) + "\n").to_utf8_buffer())
	var cache_contract := {"importer_version":IMPORTER_VERSION, "cache_contract_version":CACHE_CONTRACT_VERSION, "source_sha256":source_sha, "overlay_sha256":overlay_sha, "profile_sha256":profile_sha, "pitch_mapping_sha256":mapping_sha, "audio_sha256":audio_file["sha256"]}
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
	if result.is_empty(): result = _files.write_bytes(staging.path_join("source.musicxml"), score_bytes)
	if result.get("ok", false) and not overlay_bytes.is_empty(): result = _files.write_bytes(staging.path_join("overlay.json"), overlay_bytes)
	if result.get("ok", false): result = _files.write_text(staging.path_join("chart.json"), merged["canonical_json"])
	if result.get("ok", false): result = _audio.convert(str(request["audio_path"]), staging.path_join("runtime.ogg"))
	var runtime_audio_duration_us := roundi(float(result.get("duration_sec", 0.0)) * 1_000_000.0) if result.get("ok", false) else 0
	if result.get("ok", false) and int(merged["chart"].get("duration_us", 0)) > runtime_audio_duration_us:
		result = _failure("chart_exceeds_audio_duration", score_location, "The score extends beyond the selected audio file.", "Choose matching audio or shorten the score.")
	if result.get("ok", false) and _cancelled(cancelled): result = _failure("import_cancelled", score_location, "Import was cancelled after conversion.", "No song was published.")
	var package := {"schema_version":PACKAGE_VERSION, "song_id":chart_id, "import_version":import_version, "title":str(request.get("title", chart_id)), "artist":str(request.get("artist", "")), "duration_us":runtime_audio_duration_us, "chart_schema_version":str(merged["chart"].get("schema_version", "1.0.0")), "artwork_path":"", "status":"valid", "importer_version":IMPORTER_VERSION, "profile_id":profile.get("profile_id", ""), "cache_key":cache_key, "source":{"original_name":str(request["score_path"]).get_file(), "archive_rootfile":score_location.get_slice("#", 1) if "#" in score_location else "", "extension":score_file["extension"], "sha256":source_sha, "bytes":score_bytes.size(), "archive_entries":archive_manifest}, "overlay_sha256":overlay_sha, "audio":{"source_sha256":audio_file["sha256"], "runtime_path":"runtime.ogg"}, "chart_path":"chart.json"}
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
			completed = true; result = {"ok":true, "duplicate":false, "song":entry, "package":package, "published_path":final_path, "diagnostics":[]}
	if not completed and _files.directory_exists(staging): _files.remove_tree(staging)
	return result

func _cancelled(callback: Callable) -> bool:
	return callback.is_valid() and bool(callback.call())

func _valid_id(value: String) -> bool:
	if value.is_empty(): return false
	for index: int in value.length():
		var character := value.substr(index, 1)
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-": return false
	return true

func _repository_failure(result: Dictionary) -> Dictionary:
	return _failure(str(result.get("code", "repository_error")), str(result.get("path", "song-index")), str(result.get("error", "Song index operation failed.")), "Check storage permissions, free space, and index version.")

func _failure(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"ok":false, "diagnostics":[{"severity":"error", "code":code, "file":file, "part":"", "measure":"", "element":"import", "message":message, "remediation":remediation}]}
