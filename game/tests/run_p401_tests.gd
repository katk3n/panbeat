extends SceneTree

const Builder := preload("res://tests/notepan_fixture_builder.gd")
const Reader := preload("res://infrastructure/safe_notepan_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Audio := preload("res://infrastructure/ffmpeg_audio_converter.gd")
const Importer := preload("res://application/song_import_service.gd")
const Library := preload("res://application/song_library_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var bytes := Builder.valid()
	var parsed := Reader.read_bytes(bytes, "fixture.pan")
	_check(parsed.get("ok") and parsed.get("metadata", {}).get("title") == "Schema Six Song" and parsed.get("metadata", {}).get("handpan_scale_name") == "D Kurd 9", "schema 6 metadata parsed", failures)
	_check(parsed.get("score") != null and parsed["score"].ticks_per_quarter == 96 and parsed["score"].notes.size() == 10 and parsed["score"].time_signatures.size() == 1, "rhythmic grid and attacks parsed", failures)
	_check(_codes(parsed).has("notepan_nuance_simplified") and _codes(parsed).has("notepan_effect_simplified") and _codes(parsed).has("notepan_grace_simplified") and _codes(parsed).has("notepan_finger_roll_simplified") and _codes(parsed).has("notepan_background_ignored") and _codes(parsed).has("notepan_annotations_ignored"), "lossy notation produces explicit warnings", failures)
	var bad_header := bytes.duplicate(); bad_header[0] = 0
	_check(_code(Reader.read_bytes(bad_header, "header.pan")) == "invalid_notepan_header", "invalid header rejected", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"schema":7}), "schema7.pan")) == "unsupported_notepan_compression", "compressed schema 7 rejected", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"schema":7, "compressed":false}), "schema7-uncompressed.pan")) == "unsupported_notepan_schema", "uncompressed schema 7 rejected", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"schema":8}), "schema8-compressed.pan")) == "unsupported_notepan_compression", "compressed schema 8 rejected", failures)
	var schema8 := Reader.read_bytes(Builder.valid({"schema":8, "compressed":false}), "schema8.pan")
	var schema8_chart := Compiler.compile(schema8.get("score"), "schema8-chart") if schema8.get("ok", false) else {}
	_check(schema8.get("ok", false) and schema8.get("metadata", {}).get("handpan_scale_name") == "D Kurd 9" and schema8.get("score").version == "notepan-schema-8" and schema8.get("score").notes.size() == 10 and schema8_chart.get("ok", false), "uncompressed schema 8 handpan, notes, and chart parsed", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"content_type":1}), "bundle.pan")) == "unsupported_notepan_content", "bundle rejected", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"track_count":2}), "tracks.pan")) == "unsupported_notepan_track_count", "multiple tracks rejected", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"track_count":250001, "stop_after_track_count":true}), "count.pan")) == "notepan_record_limit", "declared record limit enforced before allocation", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"bad_column":true}), "column.pan")) == "notepan_note_column_out_of_range", "out-of-range note rejected", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"unsupported_grid":true}), "grid.pan")) == "unsupported_notepan_grid", "non-integral grid rejected", failures)
	var ramp := Reader.read_bytes(Builder.valid({"tempo_ramp":true}), "ramp.pan")
	var ramp_chart := Compiler.compile(ramp.get("score"), "ramp-chart") if ramp.get("ok", false) else {}
	var ramp_map: Array = ramp_chart.get("chart").tempo_map if ramp_chart.get("ok", false) else []
	_check(ramp.get("ok", false) and ramp.get("score").tempo_events.size() == 385 and ramp_chart.get("ok", false) and ramp_map.size() == 385 and int(ramp_map[0]["bpm_milli"]) == 120000 and int(ramp_map[-1]["tick"]) == 384 and int(ramp_map[-1]["bpm_milli"]) == 140000, "tempo ramp expands deterministically from start through final BPM", failures)
	var falling_ramp := Reader.read_bytes(Builder.valid({"tempo_ramp":true, "tempo":140.0, "final_tempo":120.0}), "falling-ramp.pan")
	_check(falling_ramp.get("ok", false) and float(falling_ramp.get("score").tempo_events[0]["bpm"]) == 140.0 and float(falling_ramp.get("score").tempo_events[-1]["bpm"]) == 120.0, "decelerating tempo ramp supported", failures)
	var endpoint_override := Reader.read_bytes(Builder.valid({"tempo_variations":[{"tempo":120.0, "bar":0, "beat":0, "final_tempo":140.0, "duration":2}, {"tempo":150.0, "bar":0, "beat":2}]}), "endpoint-override.pan")
	var endpoint_chart := Compiler.compile(endpoint_override.get("score"), "endpoint-chart") if endpoint_override.get("ok", false) else {}
	_check(endpoint_override.get("ok", false) and endpoint_chart.get("ok", false) and endpoint_override.get("score").tempo_events.size() == 193 and int(endpoint_override.get("score").tempo_events[-1]["tick"]) == 192 and float(endpoint_override.get("score").tempo_events[-1]["bpm"]) == 150.0 and _codes(endpoint_override).has("notepan_tempo_collision_resolved"), "explicit tempo at a ramp endpoint overrides the generated endpoint", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"final_tempo":140.0}), "incomplete-ramp.pan")) == "invalid_notepan_tempo_ramp", "incomplete tempo ramp rejected", failures)
	_check(_code(Reader.read_bytes(Builder.valid({"tempo_ramp":true, "tempo_duration":5}), "long-ramp.pan")) == "notepan_tempo_ramp_out_of_range", "tempo ramp beyond score rejected", failures)
	_check(_code(Reader.read_bytes(bytes.slice(0, bytes.size() - 3), "truncated.pan")) == "truncated_notepan", "truncated source rejected", failures)
	_check(_codes(Reader.read_bytes(Builder.valid({"trailing":true}), "trailing.pan")).has("notepan_trailing_data_ignored"), "trailing schema data warned", failures)

	var files := Files.new(); var root := "/tmp/panbeat-p401-tests"
	files.remove_tree(root); DirAccess.make_dir_recursive_absolute(root)
	var source := root.path_join("fixture.pan"); files.write_bytes(source, bytes)
	var profile := JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))) as Dictionary
	var repositories := Repositories.new(root.path_join("documents")); var importer := Importer.new(files, Audio.new())
	var request := {"score_path":source, "profile":profile, "song_id":"notepan-song", "title":""}
	var imported := importer.import_song(request, root.path_join("library"), repositories.songs)
	var package: Dictionary = imported.get("package", {})
	_check(imported.get("ok", false) and package.get("schema_version") == "1.2.0" and package.get("importer_version") == "panbeat-score-importer-v2" and package.get("title") == "Schema Six Song" and package.get("artist") == "NotePan Artist" and package.get("handpan_scale_name") == "D Kurd 9", "NotePan metadata imported to package 1.2: %s" % str(imported), failures)
	_check(FileAccess.file_exists(str(imported.get("published_path", "")).path_join("source.pan")) and FileAccess.get_sha256(source) == files.hash_bytes(bytes), "raw NotePan source preserved unchanged", failures)
	var chart_result := files.read_json(str(imported.get("published_path", "")).path_join("chart.json"), 1024 * 1024)
	var chart_notes: Array = chart_result.get("document", {}).get("notes", [])
	_check(chart_notes.size() == 8 and _technique_count(chart_notes, "slap") == 2 and _technique_count(chart_notes, "ding") == 4 and _technique_count(chart_notes, "tone") == 2, "S/T map to Slap, d/P/F and Ding map to Ding, ghost and technique chord are omitted", failures)
	var queried := Library.new(files).query(root.path_join("library"), repositories.songs, str(profile["profile_id"]))
	var song: Dictionary = queried.get("songs", [])[0] if not queried.get("songs", []).is_empty() else {}
	_check(song.get("display_status") == "warning" and song.get("playable", false) and song.get("handpan_scale_name") == "D Kurd 9", "persisted import warnings remain playable in Song Library: %s" % str(song), failures)
	var duplicate := importer.import_song(request, root.path_join("library"), repositories.songs)
	_check(duplicate.get("duplicate", false), "identical NotePan source deduplicates: %s" % str(duplicate), failures)
	var ramp_source := root.path_join("ramp.pan"); files.write_bytes(ramp_source, Builder.valid({"tempo_ramp":true}))
	var ramp_request := request.duplicate(true); ramp_request["score_path"] = ramp_source; ramp_request["song_id"] = "notepan-ramp"
	var ramp_imported := importer.import_song(ramp_request, root.path_join("library"), repositories.songs)
	var imported_ramp_chart := files.read_json(str(ramp_imported.get("published_path", "")).path_join("chart.json"), 4 * 1024 * 1024)
	_check(ramp_imported.get("ok", false) and imported_ramp_chart.get("document", {}).get("tempo_map", []).size() == 385, "tempo ramp imports through the complete song-package pipeline: %s" % str(ramp_imported), failures)
	var overlay_request := request.duplicate(true); overlay_request["overlay_path"] = source
	_check(_code(importer.import_song(overlay_request, root.path_join("overlay"), repositories.songs)) == "notepan_overlay_unsupported", "NotePan overlay rejected", failures)
	var octave_request := request.duplicate(true); octave_request["notation_octave_shift"] = -1
	_check(_code(importer.import_song(octave_request, root.path_join("octave"), repositories.songs)) == "notepan_octave_shift_unsupported", "NotePan octave shift rejected", failures)
	var ambiguous_profile := profile.duplicate(true); (ambiguous_profile["mappings"] as Array).append({"channel_wire":0, "note":51, "velocity_min":1, "velocity_max":127, "technique":"ding", "target_id":"second-ding"})
	var ambiguous_request := request.duplicate(true); ambiguous_request["profile"] = ambiguous_profile; ambiguous_request["song_id"] = "ambiguous"
	_check(_code(importer.import_song(ambiguous_request, root.path_join("ambiguous"), repositories.songs)) == "ambiguous_technique_target", "special technique requires a unique profile target", failures)
	var expected_count := 30
	var arguments := OS.get_cmdline_user_args()
	var real_index := arguments.find("--real-pan")
	if real_index >= 0 and real_index + 1 < arguments.size():
		expected_count += 1
		var real_schema8 := Reader.read_file(arguments[real_index + 1])
		var real_compiled := Compiler.compile(real_schema8.get("score"), "real-schema8-chart") if real_schema8.get("ok", false) else {}
		var real_request := request.duplicate(true); real_request["score_path"] = arguments[real_index + 1]; real_request["song_id"] = "real-schema8"; real_request["title"] = ""
		var real_imported := importer.import_song(real_request, root.path_join("library"), repositories.songs)
		_check(real_schema8.get("ok", false) and real_schema8.get("metadata", {}).get("title") == "La Valse d'Amélie" and real_schema8.get("score").measures.size() == 136 and real_schema8.get("score").notes.size() == 550 and real_compiled.get("ok", false) and real_imported.get("ok", false) and real_imported.get("package", {}).get("title") == "La Valse d'Amélie", "attached schema 8 score parses, compiles, and imports end to end: %s" % str(real_imported), failures)
	files.remove_tree(root)
	_finish(failures, expected_count)

func _technique_count(notes: Array, technique: String) -> int:
	var count := 0
	for note: Dictionary in notes:
		if note.get("technique") == technique: count += 1
	return count

func _codes(result: Dictionary) -> Array[String]:
	var result_codes: Array[String] = []
	for diagnostic: Dictionary in result.get("diagnostics", []): result_codes.append(str(diagnostic.get("code", "")))
	return result_codes

func _code(result: Dictionary) -> String:
	var values := _codes(result)
	return values[0] if not values.is_empty() else ""

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P401_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
