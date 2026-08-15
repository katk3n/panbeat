extends SceneTree

const Layouts := preload("res://application/performance_layout_service.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")
const TimedChart := preload("res://domain/timed_score_chart.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const HandpanLayoutView := preload("res://presentation/handpan_layout_view.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var base := JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))) as Dictionary
	var timed := _timed([_note("d3", "D", 3, 0), _note("fs3", "F", 3, 1), _note("a3", "A", 3, 0)])
	var provisional := Layouts.provisional_profile(timed, base)
	var merged := Merger.merge(timed, {}, "none", provisional)
	var built := Layouts.build(merged.get("chart", {}), base)
	var slots: Array = built.get("layout", {}).get("slots", [])
	_check(merged.get("ok") and built.get("ok") and _slot(slots, "ding").get("midi_note") == 50 and _slot(slots, "tone-1").get("midi_note") == 54 and _slot(slots, "tone-2").get("midi_note") == 57, "lowest pitch becomes Ding and remaining pitches ascend", failures)
	_check(str(built.get("layout", {}).get("layout_id", "")).length() == 64 and built["layout"] == Layouts.build(merged["chart"], base)["layout"], "layout identity is canonical and deterministic", failures)
	var persisted_layout := JSON.parse_string(JSON.stringify(built["layout"])) as Dictionary
	_check(Layouts.validate(persisted_layout), "layout identity survives JSON numeric round-trip", failures)
	var tampered: Dictionary = built["layout"].duplicate(true); tampered["slots"][0]["midi_note"] = 51
	_check(Layouts.validate(built["layout"]) and not Layouts.validate(tampered), "layout validation detects identity-changing tampering", failures)
	var effective: Dictionary = built.get("profile", {})
	var normalized := Normalizer.normalize({"message_type":"note_on", "data1":54, "data2":80, "channel_wire":0, "arrival_timestamp_us":1, "arrival_clock_domain":"godot_time_ticks"}, effective)
	_check(normalized.get("technique") == "tone" and normalized.get("target_id") == "tone-1", "effective profile maps configured pitch to generated target", failures)
	var enharmonic := _timed([_note("cs4", "C", 4, 1), _note("db4", "D", 4, -1)])
	var enharmonic_merged := Merger.merge(enharmonic, {}, "none", Layouts.provisional_profile(enharmonic, base))
	var enharmonic_layout := Layouts.build(enharmonic_merged["chart"], base)
	_check(enharmonic_layout.get("ok") and enharmonic_layout["layout"]["slots"].size() == 1 and enharmonic_layout["layout"]["slots"][0]["display_names"].size() == 2, "enharmonic spellings share one MIDI sound and retain source labels", failures)
	var too_many_notes: Array[Dictionary] = []
	for index: int in 10: too_many_notes.append({"technique":"ding" if index == 0 else "tone", "target_id":"ding" if index == 0 else "tone-%d" % (((index - 1) % 8) + 1), "pitch":{"step":"C", "alter":0, "octave":index}, "note_id":"n%d" % index})
	_check(_code(Layouts.build({"notes":too_many_notes}, base)) == "performance_layout_capacity_exceeded", "ten distinct sounds are rejected instead of omitted", failures)
	var conflict := {"notes":[{"note_id":"a", "technique":"tone", "target_id":"tone-1", "pitch":{"step":"C", "alter":0, "octave":4}}, {"note_id":"b", "technique":"tone", "target_id":"tone-1", "pitch":{"step":"D", "alter":0, "octave":4}}]}
	_check(_code(Layouts.build(conflict, base)) == "performance_layout_target_conflict", "one target cannot hide two required pitches", failures)
	_check(Layouts.preferred_ding_midi({"handpan_ding_pitches":["F#3"]}) == 54, "NotePan authored Ding pitch is retained", failures)
	var labels := HandpanLayoutView.slot_labels(built["layout"])
	_check(labels.get("ding") == "D3" and labels.get("tone-1") == "F♯3", "Song Library presents pitch labels in the handpan map", failures)
	_check(HandpanLayoutView.target_direction("ding") == Vector2.ZERO and HandpanLayoutView.target_direction("tone-7").x > 0.0 and HandpanLayoutView.target_direction("tone-8").x < 0.0, "handpan diagram keeps Ding centered and upper pads mirrored", failures)
	_finish(failures, 11)

func _timed(notes: Array[Dictionary]) -> RefCounted:
	return TimedChart.new("p402", "test", 4, 4, 500000, [{"tick":0,"bpm_milli":120000,"start_us":0}], [], notes)

func _note(note_id: String, step: String, octave: int, alter: int) -> Dictionary:
	return {"note_id":note_id, "tick":0, "duration_ticks":4, "timestamp_us":0, "duration_us":500000, "pitch":{"step":step,"alter":alter,"octave":octave}, "source":{"part":"P1","measure":"1","tick":0,"voice":"1","line":1}}

func _slot(slots: Array, target: String) -> Dictionary:
	for slot: Dictionary in slots:
		if slot.get("target_id") == target: return slot
	return {}

func _code(result: Dictionary) -> String:
	var diagnostics: Array = result.get("diagnostics", [])
	return str(diagnostics[0].get("code", "")) if not diagnostics.is_empty() else ""

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P402_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
