extends SceneTree

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")
const TimedChart := preload("res://domain/timed_score_chart.gd")

const SOURCE_SHA := "d039856c26d8a8428c214f37f06d1839f69b4d1fc61b92ec947286c540c996fc"

func _initialize() -> void:
	var failures: Array[String] = []
	var profile := JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))) as Dictionary
	var parsed := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/musescore-minimal.musicxml"))
	var compiled := Compiler.compile(parsed["score"], "p205")
	var overlay := JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p205-slap-overlay.json"))) as Dictionary
	var slap := Merger.merge(compiled["chart"], overlay, SOURCE_SHA, profile)
	_check(slap.get("ok") == true and slap["chart"]["notes"][0]["technique"] == "slap" and slap["chart"]["notes"][0]["target_id"] == "outer-hit-radius", "explicit Slap annotation", failures)
	_check(slap.get("song_metadata", {}).get("handpan_scale_name") == "D Kurd 9", "overlay handpan scale metadata is returned outside Runtime Chart", failures)
	var legacy := overlay.duplicate(true); legacy["schema_version"] = "1.0.0"; legacy.erase("handpan_scale_name")
	_check(Merger.merge(compiled["chart"], legacy, SOURCE_SHA, profile).get("song_metadata", {}).is_empty(), "legacy overlay without scale remains supported", failures)
	var maximum_scale := overlay.duplicate(true); maximum_scale["handpan_scale_name"] = "x".repeat(80)
	_check(Merger.merge(compiled["chart"], maximum_scale, SOURCE_SHA, profile).get("song_metadata", {}).get("handpan_scale_name", "").length() == 80, "maximum-length handpan scale name accepted", failures)
	var invalid_scale := overlay.duplicate(true); invalid_scale["handpan_scale_name"] = " D Kurd 9 "
	_check(_code(Merger.merge(compiled["chart"], invalid_scale, SOURCE_SHA, profile)) == "invalid_handpan_scale_name", "untrimmed handpan scale name rejected", failures)
	var invalid_scale_forms_ok := true
	for invalid_name: String in ["", "D Kurd\n9", "x".repeat(81)]:
		var invalid_form := overlay.duplicate(true); invalid_form["handpan_scale_name"] = invalid_name
		invalid_scale_forms_ok = invalid_scale_forms_ok and _code(Merger.merge(compiled["chart"], invalid_form, SOURCE_SHA, profile)) == "invalid_handpan_scale_name"
	_check(invalid_scale_forms_ok, "empty multiline and overlong handpan scale names rejected", failures)
	var tone := Merger.merge(compiled["chart"], {}, SOURCE_SHA, profile)
	_check(tone.get("ok") == true and tone["chart"]["notes"][0]["technique"] == "tone" and tone["chart"]["notes"][0]["target_id"] == "tone-4", "overlay-free Tone resolved by profile MIDI pitch", failures)
	var ding_chart := _chart_with_notes([_timed_note("ding-note", "D", 3, 0)])
	var ding := Merger.merge(ding_chart, {}, SOURCE_SHA, profile)
	_check(ding.get("ok") == true and ding["chart"]["notes"][0]["technique"] == "ding" and ding["chart"]["notes"][0]["target_id"] == "ding", "overlay-free Ding resolved by profile", failures)
	var written_high_chart := _chart_with_notes([_timed_note("written-a4", "A", 4, 0)])
	var as_written := Merger.merge(written_high_chart, {}, SOURCE_SHA, profile)
	var octave_down := Merger.merge(written_high_chart, {}, SOURCE_SHA, profile, {}, -1)
	_check(as_written.get("ok") and as_written["chart"]["notes"][0]["target_id"] == "tone-8" and octave_down.get("ok") and octave_down["chart"]["notes"][0]["target_id"] == "tone-1" and octave_down["chart"]["notes"][0]["pitch"]["octave"] == 4, "written-one-octave-high option maps sounding pitch down while preserving source pitch", failures)
	var notepan_parsed := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/notepan-unpitched.musicxml"))
	var notepan_compiled := Compiler.compile(notepan_parsed["score"], "notepan-unpitched")
	var notepan_merged := Merger.merge(notepan_compiled["chart"], {}, FileAccess.get_sha256(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/notepan-unpitched.musicxml")), profile, {}, -1)
	var notepan_notes: Array = notepan_merged.get("chart", {}).get("notes", [])
	var notepan_pairs: Array[String] = []
	for note: Dictionary in notepan_notes: notepan_pairs.append("%s:%s" % [note["technique"], note["target_id"]])
	_check(notepan_merged.get("ok") and notepan_notes.size() == 4 and notepan_pairs.count("slap:outer-hit-radius") == 2 and "tone:tone-1" in notepan_pairs and "tone:tone-6" in notepan_pairs and not "ding:ding" in notepan_pairs, "NotePan standalone S/T map to Slap while S/T members of Tone chords are absent", failures)
	var mismatch := overlay.duplicate(true); mismatch["source_musicxml_sha256"] = "0".repeat(64)
	_check(_code(Merger.merge(compiled["chart"], mismatch, SOURCE_SHA, profile)) == "overlay_source_checksum_mismatch", "source checksum mismatch rejected", failures)
	var missing := overlay.duplicate(true); missing["annotations"][0]["selector"] = {"note_id":"missing"}
	_check(_code(Merger.merge(compiled["chart"], missing, SOURCE_SHA, profile)) == "unused_annotation", "unused selector rejected", failures)
	var duplicate := overlay.duplicate(true); duplicate["annotations"].append(duplicate["annotations"][0].duplicate(true))
	_check(_code(Merger.merge(compiled["chart"], duplicate, SOURCE_SHA, profile)) == "duplicate_selector", "duplicate selector rejected", failures)
	var source_selector := overlay.duplicate(true); source_selector["annotations"][0]["selector"] = {"part":"P1", "measure":"1", "tick":0, "voice":"1"}
	var duplicate_source_chart := _chart_with_notes([_timed_note("a", "D", 4, 0), _timed_note("b", "D", 4, 0)])
	_check(_code(Merger.merge(duplicate_source_chart, source_selector, SOURCE_SHA, profile)) == "selector_multiple_matches", "multiple-match source selector rejected", failures)
	var unknown_target := overlay.duplicate(true); unknown_target["annotations"][0]["target_id"] = "tone-99"
	_check(_code(Merger.merge(compiled["chart"], unknown_target, SOURCE_SHA, profile)) == "unknown_target", "unknown target rejected", failures)
	var c_chart := _chart_with_notes([_timed_note("c-sharp", "C", 4, 0, 1)])
	var explicit := Merger.merge(c_chart, {}, SOURCE_SHA, profile, {"C#4":{"technique":"tone", "target_id":"tone-1"}})
	_check(explicit.get("ok") == true and explicit["chart"]["notes"][0]["target_id"] == "tone-1", "explicit pitch mapping", failures)
	_check(_code(Merger.merge(c_chart, {}, SOURCE_SHA, profile)) == "unsupported_pitch", "unsupported pitch diagnosed", failures)
	var future := overlay.duplicate(true); future["schema_version"] = "2.0.0"
	_check(_code(Merger.merge(compiled["chart"], future, SOURCE_SHA, profile)) == "unsupported_overlay_version", "unknown overlay major rejected", failures)
	var slap_pitch_chart := _chart_with_notes([_timed_note("a6", "A", 6, 0)])
	_check(_code(Merger.merge(slap_pitch_chart, {}, SOURCE_SHA, profile)) == "unsupported_pitch", "Slap is not inferred from MusicXML pitch", failures)
	_check(slap.get("ok") and slap["canonical_json"] == Merger.merge(compiled["chart"], overlay, SOURCE_SHA, profile)["canonical_json"], "overlay merge canonical output deterministic", failures)
	_finish(failures, 20)

func _chart_with_notes(notes: Array[Dictionary]) -> RefCounted:
	return TimedChart.new("test", "panbeat-musicxml-importer-v1", 4, 4, 500000, [{"tick":0,"bpm_milli":120000,"start_us":0}], [], notes)

func _timed_note(note_id: String, step: String, octave: int, tick: int, alter: int = 0) -> Dictionary:
	return {"note_id":note_id, "tick":tick, "duration_ticks":4, "timestamp_us":0, "duration_us":500000, "pitch":{"step":step,"alter":alter,"octave":octave}, "source":{"part":"P1","measure":"1","tick":tick,"voice":"1","line":1}}

func _code(result: Dictionary) -> String:
	var diagnostics: Array = result.get("diagnostics", [])
	return str(diagnostics[0].get("code", "")) if not diagnostics.is_empty() else ""

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P205_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
