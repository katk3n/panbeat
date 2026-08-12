extends SceneTree

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var fixture_path := ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/musescore-minimal.musicxml")
	var valid := Reader.read_file(fixture_path)
	_check(valid.get("ok") == true, "MuseScore-style minimal fixture parses: %s" % [valid.get("diagnostics", [])], failures)
	if valid.get("ok") == true:
		var score: RefCounted = valid["score"]
		_check(score.ticks_per_quarter == 4 and score.notes.size() == 4, "divisions changes normalize to integer ticks", failures)
		_check(score.notes[0]["tick"] == 0 and score.notes[1]["tick"] == 4 and score.notes[2]["tick"] == 8 and score.notes[3]["tick"] == 12 and score.notes[3]["is_rest"], "rests and measure positions preserved", failures)
		_check(score.notes[0]["tie_types"] == ["start"] and score.notes[1]["tie_types"] == ["stop", "start"] and score.notes[2]["tie_types"] == ["stop"], "tie information preserved", failures)
		_check(score.tempo_events.size() == 2 and score.tempo_events[0]["tick"] == 0 and score.tempo_events[1]["tick"] == 8, "metronome and sound tempo changes preserved", failures)
		_check(score.time_signatures.size() == 1 and score.time_signatures[0]["beats"] == 4, "time signature preserved", failures)
	var chord := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/chord.musicxml"))
	_check(chord.get("ok") and chord["score"].notes.size() == 4 and chord["score"].notes[0]["tick"] == 0 and chord["score"].notes[1]["tick"] == 0 and chord["score"].notes[2]["tick"] == 4, "MusicXML chord members share the base-note onset without advancing the cursor", failures)
	var notepan := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/notepan-unpitched.musicxml"))
	_check(notepan.get("ok") and notepan["score"].notes.size() == 7 and notepan["score"].notes[0]["is_ignored"] and notepan["score"].notes[1]["authoring_technique"] == "slap" and notepan["score"].notes[2]["authoring_technique"] == "slap" and notepan["score"].notes[3]["is_ignored"] and notepan["score"].notes[3]["tick"] == notepan["score"].notes[4]["tick"] and notepan["score"].notes[5]["is_ignored"] and notepan["score"].notes[5]["tick"] == notepan["score"].notes[6]["tick"], "NotePan g is ignored, standalone S/T become Slap, and S/T chord technique members are ignored", failures)
	var unsupported := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/unsupported.musicxml"))
	var unsupported_codes := _codes(unsupported)
	_check("chord_without_preceding_note" in unsupported_codes and "unsupported_tuplet" in unsupported_codes and "unsupported_grace_note" in unsupported_codes and "unsupported_backup_forward" in unsupported_codes and "unsupported_repeat" in unsupported_codes, "unsupported notation and malformed chord placement are explicit", failures)
	_check(_first_diagnostic_has_location(unsupported), "unsupported diagnostics include source location", failures)
	var doctype := Reader.read_file(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/security-doctype.musicxml"))
	_check(_codes(doctype) == ["xml_dtd_forbidden"], "DTD and external entity rejected before parsing", failures)
	_check("malformed_xml" in _codes(Reader.read_text("<score-partwise version=\"4.0\"><broken>")), "malformed XML rejected", failures)
	_check("unsupported_root" in _codes(Reader.read_text("<score-timewise version=\"4.0\"/>")), "unknown root rejected", failures)
	_check("unsupported_musicxml_version" in _codes(Reader.read_text(_single_note_xml("3.1"))), "unknown MusicXML version rejected", failures)
	var two_parts := _single_note_xml().replace("</score-partwise>", "<part id=\"P2\"><measure number=\"1\"><attributes><divisions>1</divisions></attributes><note><rest/><duration>1</duration><voice>1</voice></note></measure></part></score-partwise>")
	_check("unsupported_multiple_parts" in _codes(Reader.read_text(two_parts)), "multiple parts rejected", failures)
	var two_voices := _single_note_xml().replace("</measure>", "<note><rest/><duration>1</duration><voice>2</voice></note></measure>")
	_check("unsupported_multiple_voices" in _codes(Reader.read_text(two_voices)), "multiple voices rejected", failures)
	var navigation := _single_note_xml().replace("<note>", "<sound dacapo=\"yes\"/><note>")
	_check("unsupported_navigation" in _codes(Reader.read_text(navigation)), "D.C. navigation rejected", failures)
	var deep := _single_note_xml().replace("<note>", "<x>".repeat(70) + "<note>").replace("</note>", "</note>" + "</x>".repeat(70))
	_check("xml_depth_limit" in _codes(Reader.read_text(deep)), "excessive depth rejected", failures)
	var many_elements := "<score-partwise version=\"4.0\">" + "<x/>".repeat(Reader.MAX_ELEMENTS + 1) + "</score-partwise>"
	_check("xml_element_limit" in _codes(Reader.read_text(many_elements)), "excessive element count rejected", failures)
	var oversized := PackedByteArray(); oversized.resize(Reader.MAX_SOURCE_BYTES + 1)
	_check("source_too_large" in _codes(Reader.read_bytes(oversized)), "oversized source rejected before decoding", failures)
	_finish(failures, 19)

func _single_note_xml(version: String = "4.0") -> String:
	return "<score-partwise version=\"%s\"><part-list><score-part id=\"P1\"><part-name>Test</part-name></score-part></part-list><part id=\"P1\"><measure number=\"1\"><attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes><note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note></measure></part></score-partwise>" % version

func _codes(result: Dictionary) -> Array[String]:
	var codes: Array[String] = []
	for diagnostic: Dictionary in result.get("diagnostics", []): codes.append(diagnostic.get("code", ""))
	return codes

func _first_diagnostic_has_location(result: Dictionary) -> bool:
	for diagnostic: Dictionary in result.get("diagnostics", []):
		if not str(diagnostic.get("part", "")).is_empty() and not str(diagnostic.get("measure", "")).is_empty() and not str(diagnostic.get("element", "")).is_empty() and int(diagnostic.get("line", 0)) > 0: return true
	return false

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty():
		print("PANBEAT_P203_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
