class_name SafeMusicXmlReader
extends RefCounted

const SymbolicScoreModel := preload("res://domain/symbolic_score.gd")
const MAX_SOURCE_BYTES := 16 * 1024 * 1024
const MAX_DEPTH := 64
const MAX_ELEMENTS := 250_000
const UNSUPPORTED_ELEMENTS: Dictionary = {
	"time-modification":"tuplet", "tuplet":"tuplet", "grace":"grace_note",
	"repeat":"repeat", "ending":"volta", "backup":"backup_forward", "forward":"backup_forward"
}

static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failed([_diagnostic("error", "file_open_failed", path, "", "", "document", 0, "MusicXML file could not be opened", "Check file permissions and path.")])
	if file.get_length() > MAX_SOURCE_BYTES:
		return _failed([_diagnostic("error", "source_too_large", path, "", "", "document", 0, "MusicXML exceeds %d bytes" % MAX_SOURCE_BYTES, "Choose a smaller score.")])
	return read_bytes(file.get_buffer(file.get_length()), path)

static func read_text(text: String, source: String = "memory") -> Dictionary:
	return read_bytes(text.to_utf8_buffer(), source)

static func read_bytes(bytes: PackedByteArray, source: String = "memory") -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if bytes.size() > MAX_SOURCE_BYTES:
		return _failed([_diagnostic("error", "source_too_large", source, "", "", "document", 0, "MusicXML exceeds %d bytes" % MAX_SOURCE_BYTES, "Choose a smaller score.")])
	var lowered := bytes.get_string_from_utf8().to_lower()
	if "<!doctype" in lowered or "<!entity" in lowered:
		return _failed([_diagnostic("error", "xml_dtd_forbidden", source, "", "", "document", 0, "DOCTYPE and entity declarations are forbidden", "Export MusicXML without DTD or entities.")])
	var parser := XMLParser.new()
	var open_error := parser.open_buffer(bytes)
	if open_error != OK:
		return _failed([_diagnostic("error", "malformed_xml", source, "", "", "document", 0, "MusicXML parser could not open input: %s" % error_string(open_error), "Export a well-formed MusicXML document.")])
	var stack: Array[String] = []
	var root_seen := false
	var version := ""
	var part_ids: Array[String] = []
	var part_id := ""
	var measure_number := ""
	var measure_index := -1
	var current_divisions := 0
	var divisions_values: Array[int] = []
	var divisions_raw: Array[Dictionary] = []
	var notes_raw: Array[Dictionary] = []
	var tempo_raw: Array[Dictionary] = []
	var time_raw: Array[Dictionary] = []
	var measures_raw: Array[Dictionary] = []
	var measure_position := {"n":0, "d":1}
	var score_position := {"n":0, "d":1}
	var previous_note_start: Dictionary = {}
	var previous_note_was_pitched := false
	var current_note: Dictionary = {}
	var current_time: Dictionary = {}
	var current_metronome: Dictionary = {}
	var voices: Dictionary = {}
	var element_count := 0
	while true:
		var read_error := parser.read()
		if read_error == ERR_FILE_EOF: break
		if read_error != OK:
			diagnostics.append(_diagnostic("error", "malformed_xml", source, part_id, measure_number, stack.back() if not stack.is_empty() else "document", parser.get_current_line(), "Malformed XML: %s" % error_string(read_error), "Export a well-formed MusicXML document."))
			break
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var name := parser.get_node_name()
			element_count += 1
			if element_count > MAX_ELEMENTS:
				diagnostics.append(_diagnostic("error", "xml_element_limit", source, part_id, measure_number, name, parser.get_current_line(), "MusicXML exceeds %d elements" % MAX_ELEMENTS, "Split or simplify the score."))
				break
			stack.append(name)
			if stack.size() > MAX_DEPTH:
				diagnostics.append(_diagnostic("error", "xml_depth_limit", source, part_id, measure_number, name, parser.get_current_line(), "MusicXML nesting exceeds %d" % MAX_DEPTH, "Remove excessive nesting."))
				break
			if not root_seen:
				root_seen = true
				if name != "score-partwise":
					diagnostics.append(_diagnostic("error", "unsupported_root", source, "", "", name, parser.get_current_line(), "Root must be score-partwise", "Export a score-partwise MusicXML 4.0 file."))
				version = parser.get_named_attribute_value_safe("version")
				if version != "4.0":
					diagnostics.append(_diagnostic("error", "unsupported_musicxml_version", source, "", "", name, parser.get_current_line(), "MusicXML version must be 4.0", "Export MusicXML 4.0."))
			if UNSUPPORTED_ELEMENTS.has(name):
				diagnostics.append(_diagnostic("error", "unsupported_%s" % UNSUPPORTED_ELEMENTS[name], source, part_id, measure_number, name, parser.get_current_line(), "%s is outside the Phase 2 MVP subset" % name, "Remove or flatten this notation before import."))
			if name == "part" and stack.size() == 2:
				part_id = parser.get_named_attribute_value_safe("id")
				part_ids.append(part_id)
				if part_ids.size() > 1:
					diagnostics.append(_diagnostic("error", "unsupported_multiple_parts", source, part_id, "", name, parser.get_current_line(), "Only one score part is supported", "Export a single-part score."))
			elif name == "measure":
				measure_index += 1
				measure_number = parser.get_named_attribute_value_safe("number")
				measure_position = {"n":0, "d":1}
				previous_note_start = {}
				previous_note_was_pitched = false
				measures_raw.append({"number":measure_number, "index":measure_index, "start":score_position.duplicate(), "line":parser.get_current_line()})
			elif name == "note":
				current_note = {"part":part_id, "measure":measure_number, "measure_index":measure_index, "start":_fraction_add(score_position, measure_position), "line":parser.get_current_line(), "is_rest":false, "tie_types":[]}
			elif name == "rest" and not current_note.is_empty():
				current_note["is_rest"] = true
			elif name == "unpitched" and not current_note.is_empty():
				current_note["is_unpitched"] = true
			elif name == "lyric" and not current_note.is_empty():
				current_note["_active_lyric_name"] = parser.get_named_attribute_value_safe("name")
			elif name == "chord" and not current_note.is_empty():
				current_note["is_chord"] = true
				if previous_note_start.is_empty() or not previous_note_was_pitched:
					diagnostics.append(_diagnostic("error", "chord_without_preceding_note", source, part_id, measure_number, name, parser.get_current_line(), "A chord member must follow a pitched note in the same measure", "Place the chord base note immediately before its <chord/> members."))
				else:
					current_note["start"] = previous_note_start.duplicate()
			elif name == "time":
				current_time = {"part":part_id, "measure":measure_number, "position":_fraction_add(score_position, measure_position), "line":parser.get_current_line()}
			elif name == "metronome":
				current_metronome = {"part":part_id, "measure":measure_number, "position":_fraction_add(score_position, measure_position), "line":parser.get_current_line()}
			elif name == "sound" and parser.has_attribute("tempo"):
				var tempo_text := parser.get_named_attribute_value_safe("tempo")
				if tempo_text.is_valid_float() and float(tempo_text) > 0.0:
					tempo_raw.append({"part":part_id, "measure":measure_number, "position":_fraction_add(score_position, measure_position), "bpm":float(tempo_text), "source":"sound", "line":parser.get_current_line()})
				else:
					diagnostics.append(_diagnostic("error", "invalid_tempo", source, part_id, measure_number, name, parser.get_current_line(), "tempo must be positive", "Set a positive BPM."))
			if name == "sound":
				for navigation_attribute: String in ["dacapo", "dalsegno", "segno", "coda", "tocoda", "fine"]:
					if parser.has_attribute(navigation_attribute): diagnostics.append(_diagnostic("error", "unsupported_navigation", source, part_id, measure_number, name, parser.get_current_line(), "Music navigation is outside the Phase 2 MVP subset", "Expand navigation into linear measures."))
			if name == "tie" and not current_note.is_empty():
				var tie_type := parser.get_named_attribute_value_safe("type")
				if not ["start", "stop"].has(tie_type): diagnostics.append(_diagnostic("error", "invalid_tie", source, part_id, measure_number, name, parser.get_current_line(), "tie type must be start or stop", "Correct the tie type."))
				else: (current_note["tie_types"] as Array).append(tie_type)
			if parser.is_empty():
				_handle_end(name, current_note, current_time, current_metronome, notes_raw, time_raw, tempo_raw, diagnostics, source, current_divisions)
				stack.pop_back()
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			var value := parser.get_node_data().strip_edges()
			if not value.is_empty():
				_assign_text(stack, value, current_note, current_time, current_metronome, diagnostics, source, part_id, measure_number, parser.get_current_line())
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var name := parser.get_node_name()
			if name == "divisions":
				var divisions_text: String = str(current_time.get("_divisions_text", ""))
				if divisions_text.is_valid_int() and int(divisions_text) > 0:
					current_divisions = int(divisions_text); divisions_values.append(current_divisions)
					divisions_raw.append({"part":part_id, "measure":measure_number, "position":_fraction_add(score_position, measure_position), "divisions":current_divisions, "line":parser.get_current_line()})
				else: diagnostics.append(_diagnostic("error", "invalid_divisions", source, part_id, measure_number, name, parser.get_current_line(), "divisions must be a positive integer", "Set a positive divisions value."))
				current_time.erase("_divisions_text")
			elif name == "note":
				if current_divisions <= 0: diagnostics.append(_diagnostic("error", "missing_divisions", source, part_id, measure_number, name, parser.get_current_line(), "A positive divisions value is required before notes", "Add attributes/divisions."))
				var duration_text: String = str(current_note.get("duration_text", ""))
				if not duration_text.is_valid_int() or int(duration_text) <= 0:
					diagnostics.append(_diagnostic("error", "invalid_duration", source, part_id, measure_number, name, parser.get_current_line(), "note duration must be a positive integer", "Set a positive duration."))
				else:
					var voice: String = str(current_note.get("voice", "1")); voices[voice] = true
					if voices.size() > 1: diagnostics.append(_diagnostic("error", "unsupported_multiple_voices", source, part_id, measure_number, "voice", parser.get_current_line(), "Only one voice is supported", "Export a single-voice score."))
					if current_note.get("is_unpitched", false):
						var notepan_label := str(current_note.get("notepan_label", "")).strip_edges()
						var primary_label := notepan_label.get_slice("+", 0).strip_edges()
						var is_technique_chord := notepan_label.contains("+") and primary_label in ["S", "T"]
						match primary_label:
							"g": current_note["is_ignored"] = true
							"S", "T":
								if is_technique_chord:
									current_note["is_ignored"] = true
									current_note["anchors_pitched_chord"] = true
								else:
									current_note["authoring_technique"] = "slap"
									current_note["authoring_target_id"] = "outer-hit-radius"
							_: diagnostics.append(_diagnostic("error", "unsupported_unpitched_notepan_label", source, part_id, measure_number, "unpitched", parser.get_current_line(), "Unpitched NotePan label is unsupported: %s" % notepan_label, "Use g, S, or T as the primary NotePan label."))
					if not current_note.get("is_rest", false) and not current_note.get("is_unpitched", false) and (not current_note.has("step") or not current_note.has("octave") or str(current_note.get("step", "")) not in ["A", "B", "C", "D", "E", "F", "G"]):
						diagnostics.append(_diagnostic("error", "invalid_pitch", source, part_id, measure_number, "pitch", parser.get_current_line(), "Pitched notes require step A-G and octave", "Provide a complete pitch or rest."))
					var duration_fraction := _fraction(int(duration_text), maxi(current_divisions, 1))
					current_note["duration"] = duration_fraction
					current_note["divisions"] = current_divisions
					notes_raw.append(current_note.duplicate(true))
					if not current_note.get("is_chord", false):
						previous_note_start = current_note["start"].duplicate()
						previous_note_was_pitched = not current_note.get("is_rest", false) and (not current_note.get("is_ignored", false) or current_note.get("anchors_pitched_chord", false))
						measure_position = _fraction_add(measure_position, duration_fraction)
				current_note = {}
			elif name == "lyric" and not current_note.is_empty():
				current_note.erase("_active_lyric_name")
			elif name == "time":
				if current_time.has("beats") and current_time.has("beat_type"): time_raw.append(current_time.duplicate(true))
				else: diagnostics.append(_diagnostic("error", "invalid_time_signature", source, part_id, measure_number, name, parser.get_current_line(), "time requires beats and beat-type", "Add a complete time signature."))
				current_time = {}
			elif name == "metronome":
				var bpm_text: String = str(current_metronome.get("per_minute", ""))
				if bpm_text.is_valid_float() and float(bpm_text) > 0.0: tempo_raw.append({"part":part_id, "measure":measure_number, "position":current_metronome.get("position", score_position), "bpm":float(bpm_text), "source":"metronome", "beat_unit":current_metronome.get("beat_unit", "quarter"), "line":current_metronome.get("line", 0)})
				else: diagnostics.append(_diagnostic("error", "invalid_tempo", source, part_id, measure_number, name, parser.get_current_line(), "per-minute must be positive", "Set a positive BPM."))
				current_metronome = {}
			elif name == "measure":
				score_position = _fraction_add(score_position, measure_position)
			elif name == "part" and stack.size() == 2:
				measure_number = ""
			if not stack.is_empty(): stack.pop_back()
	if not root_seen: diagnostics.append(_diagnostic("error", "empty_xml", source, "", "", "document", 0, "MusicXML document is empty", "Export a MusicXML 4.0 score."))
	elif not stack.is_empty() and not _has_code(diagnostics, "xml_depth_limit") and not _has_code(diagnostics, "xml_element_limit"):
		diagnostics.append(_diagnostic("error", "malformed_xml", source, part_id, measure_number, stack.back(), parser.get_current_line(), "MusicXML ended before all elements were closed", "Export a well-formed MusicXML document."))
	if part_ids.size() != 1: diagnostics.append(_diagnostic("error", "part_count", source, part_id, "", "part", 0, "Exactly one part is required", "Export one score part."))
	if notes_raw.is_empty(): diagnostics.append(_diagnostic("error", "no_notes", source, part_id, "", "note", 0, "Score contains no supported notes or rests", "Add at least one note or rest."))
	if not diagnostics.is_empty(): return _failed(diagnostics)
	var ticks_per_quarter := 1
	for divisions: int in divisions_values: ticks_per_quarter = _lcm(ticks_per_quarter, divisions)
	var notes: Array[Dictionary] = []
	for raw: Dictionary in notes_raw:
		var note := raw.duplicate(true)
		note["tick"] = _to_tick(note["start"], ticks_per_quarter)
		note["duration_ticks"] = _to_tick(note["duration"], ticks_per_quarter)
		note.erase("start"); note.erase("duration"); note.erase("duration_text")
		notes.append(note)
	var measures := _convert_positions(measures_raw, ticks_per_quarter, "start", "start_tick")
	var tempos := _convert_positions(tempo_raw, ticks_per_quarter, "position", "tick")
	var times := _convert_positions(time_raw, ticks_per_quarter, "position", "tick")
	var divisions_events := _convert_positions(divisions_raw, ticks_per_quarter, "position", "tick")
	return {"ok": true, "score": SymbolicScoreModel.new(source, version, part_id, ticks_per_quarter, measures, notes, tempos, times, divisions_events), "diagnostics": []}

static func _assign_text(stack: Array[String], value: String, note: Dictionary, time: Dictionary, metronome: Dictionary, diagnostics: Array[Dictionary], source: String, part: String, measure: String, line: int) -> void:
	if stack.is_empty(): return
	var name: String = stack.back()
	if not note.is_empty():
		match name:
			"duration": note["duration_text"] = value
			"voice": note["voice"] = value
			"step": note["step"] = value
			"alter": note["alter"] = value.to_int() if value.is_valid_int() else value
			"octave": note["octave"] = value.to_int() if value.is_valid_int() else value
			"rest": note["is_rest"] = true
			"text":
				if note.get("_active_lyric_name", "") == "NotePan": note["notepan_label"] = value
	if name == "divisions": time["_divisions_text"] = value
	elif name == "beats": time["beats"] = value.to_int() if value.is_valid_int() else value
	elif name == "beat-type": time["beat_type"] = value.to_int() if value.is_valid_int() else value
	elif name == "beat-unit": metronome["beat_unit"] = value
	elif name == "per-minute": metronome["per_minute"] = value
	if not note.is_empty() and name in ["step", "octave"] and value.is_empty(): diagnostics.append(_diagnostic("error", "invalid_pitch", source, part, measure, name, line, "pitch field is empty", "Provide a complete pitch."))

static func _handle_end(_name: String, _note: Dictionary, _time: Dictionary, _metronome: Dictionary, _notes: Array[Dictionary], _times: Array[Dictionary], _tempos: Array[Dictionary], _diagnostics: Array[Dictionary], _source: String, _divisions: int) -> void:
	pass

static func _convert_positions(values: Array[Dictionary], ticks: int, source_key: String, target_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		var converted := value.duplicate(true)
		converted[target_key] = _to_tick(converted[source_key], ticks)
		converted.erase(source_key)
		result.append(converted)
	return result

static func _fraction(numerator: int, denominator: int) -> Dictionary:
	var divisor := _gcd(absi(numerator), absi(denominator))
	return {"n": numerator / divisor, "d": denominator / divisor}

static func _fraction_add(left: Dictionary, right: Dictionary) -> Dictionary:
	return _fraction(int(left["n"]) * int(right["d"]) + int(right["n"]) * int(left["d"]), int(left["d"]) * int(right["d"]))

static func _to_tick(value: Dictionary, ticks: int) -> int:
	return int(value["n"]) * ticks / int(value["d"])

static func _gcd(left: int, right: int) -> int:
	var a := maxi(left, 1) if right == 0 else left
	var b := right
	while b != 0:
		var remainder := a % b; a = b; b = remainder
	return maxi(a, 1)

static func _lcm(left: int, right: int) -> int:
	return left / _gcd(left, right) * right

static func _diagnostic(severity: String, code: String, file: String, part: String, measure: String, element: String, line: int, message: String, remediation: String) -> Dictionary:
	return {"severity":severity, "code":code, "file":file, "part":part, "measure":measure, "element":element, "line":line, "message":message, "remediation":remediation}

static func _failed(diagnostics: Array[Dictionary]) -> Dictionary:
	return {"ok": false, "diagnostics": diagnostics}

static func _has_code(diagnostics: Array[Dictionary], code: String) -> bool:
	for diagnostic: Dictionary in diagnostics:
		if diagnostic.get("code") == code: return true
	return false
