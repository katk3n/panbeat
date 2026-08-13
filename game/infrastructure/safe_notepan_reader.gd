class_name SafeNotePanReader
extends RefCounted

const SymbolicScoreModel := preload("res://domain/symbolic_score.gd")

const MAX_SOURCE_BYTES := 16 * 1024 * 1024
const MAX_STRING_BYTES := 1024 * 1024
const MAX_RECORDS := 250_000
const MAX_FOOTER_BYTES := 1024
const TICKS_PER_QUARTER := 96
const SPECIAL_LABELS := {31:"D", 35:"g", 36:"d", 37:"T", 38:"P", 39:"S", 41:"F"}
const NEW_TO_LEGACY_NOTE := {51:31, 54:36, 150:35, 151:39, 153:41, 161:38, 171:37}
const SCHEMA8_PITCHES := {0:"C", 1:"C#", 2:"Db", 3:"D", 4:"D#", 5:"Eb", 6:"E", 7:"F", 8:"F#", 9:"Gb", 10:"G", 11:"G#", 12:"Ab", 13:"A", 14:"A#", 15:"Bb", 16:"B"}

class ByteReader extends RefCounted:
	var data: PackedByteArray
	var position := 0
	var record_count := 0
	var error_code := ""
	var error_message := ""

	func _init(value: PackedByteArray) -> void:
		data = value

	func remaining() -> int:
		return data.size() - position

	func failed() -> bool:
		return not error_code.is_empty()

	func fail(code: String, message: String) -> void:
		if error_code.is_empty():
			error_code = code
			error_message = message

	func bytes(count: int) -> PackedByteArray:
		if count < 0 or remaining() < count:
			fail("truncated_notepan", "NotePan data ends unexpectedly at byte %d." % position)
			return PackedByteArray()
		var result := data.slice(position, position + count)
		position += count
		return result

	func u8() -> int:
		var value := bytes(1)
		return int(value[0]) if not failed() else 0

	func boolean() -> bool:
		var offset := position
		var value := u8()
		if not failed() and value not in [0, 1]: fail("invalid_notepan_boolean", "Expected a boolean at byte %d." % offset)
		return value == 1

	func i16() -> int:
		var offset := position
		bytes(2)
		return data.decode_s16(offset) if not failed() else 0

	func i32() -> int:
		var offset := position
		bytes(4)
		return data.decode_s32(offset) if not failed() else 0

	func f32() -> float:
		var offset := position
		bytes(4)
		return data.decode_float(offset) if not failed() else 0.0

	func f64() -> float:
		var offset := position
		bytes(8)
		return data.decode_double(offset) if not failed() else 0.0

	func count(label: String) -> int:
		var value := i32()
		if failed(): return 0
		if value < 0:
			fail("invalid_notepan_count", "%s count must not be negative." % label)
			return 0
		if value > MAX_RECORDS or record_count + value > MAX_RECORDS:
			fail("notepan_record_limit", "NotePan exceeds the %d-record safety limit at %s." % [MAX_RECORDS, label])
			return 0
		record_count += value
		return value

	func string() -> String:
		var length := 0
		var shift := 0
		while true:
			if shift > 28:
				fail("invalid_notepan_string_length", "Invalid .NET string length at byte %d." % position)
				return ""
			var value := u8()
			if failed(): return ""
			length |= (value & 0x7f) << shift
			if (value & 0x80) == 0: break
			shift += 7
		if length > MAX_STRING_BYTES:
			fail("notepan_string_limit", "NotePan string exceeds %d bytes." % MAX_STRING_BYTES)
			return ""
		var raw := bytes(length)
		if failed(): return ""
		var result := raw.get_string_from_utf8()
		if result.to_utf8_buffer() != raw:
			fail("invalid_notepan_utf8", "NotePan contains invalid UTF-8 at byte %d." % (position - length))
			return ""
		return result

static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failed("source_open_failed", path, "NotePan file could not be opened.", "Check file permissions and path.")
	if file.get_length() > MAX_SOURCE_BYTES: return _failed("source_too_large", path, "NotePan exceeds %d bytes." % MAX_SOURCE_BYTES, "Choose a smaller score.")
	return read_bytes(file.get_buffer(file.get_length()), path)

static func read_bytes(bytes: PackedByteArray, source: String = "memory") -> Dictionary:
	if bytes.size() > MAX_SOURCE_BYTES: return _failed("source_too_large", source, "NotePan exceeds %d bytes." % MAX_SOURCE_BYTES, "Choose a smaller score.")
	var reader := ByteReader.new(bytes)
	if reader.bytes(3).get_string_from_ascii() != "PAN": return _failed("invalid_notepan_header", source, "NotePan header must be PAN.", "Choose an uncompressed NotePan tablature file.")
	var app_version := reader.string()
	var schema := reader.i32()
	if reader.failed(): return _reader_failure(reader, source)
	if schema >= 7:
		var compressed := reader.boolean()
		if reader.failed(): return _reader_failure(reader, source)
		if compressed: return _failed("unsupported_notepan_compression", source, "Compressed NotePan schema %d streams are not supported." % schema, "Save or export an uncompressed .pan file.")
	if schema not in [6, 8]: return _failed("unsupported_notepan_schema", source, "NotePan schema must be 6 or 8; found %d." % schema, "Save the tablature using a supported NotePan version.")
	var content_type := reader.u8()
	if reader.failed(): return _reader_failure(reader, source)
	if content_type != 0: return _failed("unsupported_notepan_content", source, "NotePan bundles are not supported.", "Choose a schema 6 or 8 tablature instead of a bundle.")
	var title := reader.string()
	var artist := reader.string()
	var info := reader.string()
	var track_count := reader.count("tracks")
	if reader.failed(): return _reader_failure(reader, source)
	if track_count != 1: return _failed("unsupported_notepan_track_count", source, "NotePan import requires exactly one track; found %d." % track_count, "Export a single-track tablature.")
	var track := _read_track_v8(reader) if schema == 8 else _read_track_v6(reader)
	if reader.failed(): return _reader_failure(reader, source)
	var bars: Array[Dictionary] = []
	for index: int in reader.count("bars"):
		var beats := reader.u8()
		var line_break := reader.boolean()
		var completed := reader.boolean()
		var has_section := reader.boolean()
		var has_subsection := reader.boolean()
		var section := reader.string() if has_section else ""
		var subsection := reader.string() if has_subsection else ""
		bars.append({"beats":beats, "line_break":line_break, "completed":completed, "section":section, "subsection":subsection})
		if beats <= 0: reader.fail("invalid_notepan_bar", "Bar %d must contain at least one beat." % (index + 1))
	var tempos: Array[Dictionary] = []
	for _index: int in reader.count("tempo variations"):
		var tempo := reader.f32()
		var bar := reader.i16()
		var beat := reader.u8()
		var final_tempo := reader.f32()
		var duration := reader.u8()
		tempos.append({"tempo":tempo, "bar":bar, "beat":beat, "final_tempo":final_tempo, "duration":duration})
	if reader.failed(): return _reader_failure(reader, source)
	if schema == 8 and reader.remaining() > 0:
		var footer_size := reader.i32()
		if reader.failed(): return _reader_failure(reader, source)
		if footer_size < 0 or footer_size > MAX_FOOTER_BYTES or footer_size != reader.remaining(): return _failed("invalid_notepan_footer", source, "Schema 8 footer length does not match the remaining data.", "Repair or re-save the NotePan tablature.")
		reader.bytes(footer_size)
		if reader.failed(): return _reader_failure(reader, source)
	if bars.is_empty(): return _failed("empty_notepan_bars", source, "NotePan tablature contains no bars.", "Export a score containing at least one bar.")
	var warnings: Array[Dictionary] = []
	if reader.remaining() > 0: warnings.append(_diagnostic("warning", "notepan_trailing_data_ignored", source, "document", "Ignored %d trailing schema %d byte(s)." % [reader.remaining(), schema], "Re-export if the score does not play as expected."))
	var built := _build_score(source, app_version, schema, title, artist, info, track, bars, tempos, warnings)
	return built

static func _read_track_v6(reader: ByteReader) -> Dictionary:
	var track := {"name":reader.string(), "volume":reader.u8(), "rotation":reader.f64()}
	var handpan := {"name":reader.string(), "description":reader.string(), "scale":reader.string(), "ring_notes":reader.u8(), "mutant_notes":reader.u8(), "ding_notes":reader.u8(), "bottom_layout":reader.u8(), "ring_position":reader.u8(), "notes":[]}
	var handpan_notes: Array[Dictionary] = []
	for _index: int in reader.count("handpan notes"):
		handpan_notes.append({"regular":reader.boolean(), "ding_pitch":reader.boolean(), "number":reader.string(), "pitch":reader.string()})
	handpan["notes"] = handpan_notes
	track["handpan"] = handpan
	var beats: Array[Dictionary] = []
	for _index: int in reader.count("beats"): beats.append({"bar":reader.i16(), "beat":reader.u8(), "subdivisions":reader.u8()})
	track["beats"] = beats
	var splits: Array[Dictionary] = []
	for _index: int in reader.count("splits"): splits.append({"bar":reader.i16(), "beat":reader.u8(), "subdivision":reader.u8()})
	track["splits"] = splits
	var notes: Array[Dictionary] = []
	for _index: int in reader.count("notes"):
		var note := {"column":reader.i16(), "lane":reader.u8(), "background":reader.u8(), "background_only":reader.boolean()}
		if not note["background_only"]:
			note.merge({"note":reader.u8(), "nuance":reader.u8(), "effect":reader.u8(), "grace":reader.boolean(), "finger_roll":reader.boolean()})
		notes.append(note)
	track["notes"] = notes
	var annotations: Array[Dictionary] = []
	for _index: int in reader.count("annotations"): annotations.append({"column":reader.i16(), "text":reader.string()})
	track["annotations"] = annotations
	return track

static func _read_track_v8(reader: ByteReader) -> Dictionary:
	var track := {"name":reader.string(), "volume":reader.u8(), "rotation":reader.f64()}
	var handpan := {"name":reader.string(), "description":"", "scale":"", "notes":[]}
	reader.u8(); reader.u8(); reader.u8()
	var handpan_notes: Array[Dictionary] = []
	for _index: int in reader.count("handpan notes"):
		var code := reader.u8()
		var pitch_code := reader.u8()
		var octave := reader.i32()
		var ding_pitch := reader.boolean()
		for _geometry_index: int in 5: reader.f64()
		var number := reader.string()
		var pitch := _schema8_pitch(pitch_code, octave)
		if not pitch.is_empty(): handpan_notes.append({"regular":true, "ding_pitch":ding_pitch, "number":number, "pitch":pitch, "code":_legacy_note_code(code)})
	handpan["notes"] = handpan_notes
	handpan["scale"] = str(handpan["name"])
	track["handpan"] = handpan
	var beats: Array[Dictionary] = []
	for _index: int in reader.count("beats"): beats.append({"bar":reader.i16(), "beat":reader.u8(), "subdivisions":reader.u8()})
	track["beats"] = beats
	var splits: Array[Dictionary] = []
	for _index: int in reader.count("splits"): splits.append({"bar":reader.i16(), "beat":reader.u8(), "subdivision":reader.u8()})
	track["splits"] = splits
	var notes: Array[Dictionary] = []
	for _index: int in reader.count("notes"):
		var column := reader.i16()
		var lane := reader.u8()
		var background := reader.i32()
		var code := reader.u8()
		var nuance := reader.u8()
		var effect := reader.u8()
		var grace := reader.boolean()
		var finger_roll := reader.boolean()
		notes.append({"column":column, "lane":maxi(0, lane - 1), "background":background, "background_only":code == 0, "note":_legacy_note_code(code), "nuance":0 if nuance == 2 else nuance, "effect":effect, "grace":grace, "finger_roll":finger_roll})
	track["notes"] = notes
	var annotations: Array[Dictionary] = []
	for _index: int in reader.count("annotations"): annotations.append({"column":reader.i16(), "text":reader.string()})
	track["annotations"] = annotations
	return track

static func _schema8_pitch(pitch_code: int, octave: int) -> String:
	if not SCHEMA8_PITCHES.has(pitch_code) or octave < -1 or octave > 9: return ""
	return "%s%d" % [SCHEMA8_PITCHES[pitch_code], octave]

static func _legacy_note_code(code: int) -> int:
	return int(NEW_TO_LEGACY_NOTE.get(code, code))

static func _build_score(source: String, app_version: String, schema: int, title: String, artist: String, info: String, track: Dictionary, bars: Array[Dictionary], tempos: Array[Dictionary], warnings: Array[Dictionary]) -> Dictionary:
	var beat_map: Dictionary = {}
	for beat: Dictionary in track["beats"]:
		var bar_index := int(beat["bar"]); var beat_index := int(beat["beat"]); var subdivisions := int(beat["subdivisions"])
		if bar_index < 0 or bar_index >= bars.size() or beat_index < 0 or beat_index >= int(bars[bar_index]["beats"]): return _failed("invalid_notepan_beat", source, "Beat points outside the bar grid.", "Repair or re-export the NotePan score.")
		if subdivisions <= 0: return _failed("invalid_notepan_subdivision", source, "Beat subdivisions must be positive.", "Repair or re-export the NotePan score.")
		var key := "%d:%d" % [bar_index, beat_index]
		if beat_map.has(key): return _failed("duplicate_notepan_beat", source, "Beat %s is defined more than once." % key, "Repair or re-export the NotePan score.")
		beat_map[key] = subdivisions
	var split_map: Dictionary = {}
	for split: Dictionary in track["splits"]:
		var bar_index := int(split["bar"]); var beat_index := int(split["beat"]); var subdivision := int(split["subdivision"])
		var key := "%d:%d" % [bar_index, beat_index]
		if not beat_map.has(key) or subdivision < 0 or subdivision >= int(beat_map[key]): return _failed("invalid_notepan_split", source, "Split points outside the beat grid.", "Repair or re-export the NotePan score.")
		var split_key := "%s:%d" % [key, subdivision]
		if split_map.has(split_key): return _failed("duplicate_notepan_split", source, "Split %s is defined more than once." % split_key, "Repair or re-export the NotePan score.")
		split_map[split_key] = true
	var columns: Array[Dictionary] = []
	var measures: Array[Dictionary] = []
	var time_signatures: Array[Dictionary] = []
	var tick := 0
	var previous_beats := -1
	for bar_index: int in bars.size():
		measures.append({"number":str(bar_index + 1), "index":bar_index, "start_tick":tick, "line":0})
		var bar_beats := int(bars[bar_index]["beats"])
		if bar_beats != previous_beats:
			time_signatures.append({"part":str(track["name"]), "measure":str(bar_index + 1), "tick":tick, "beats":bar_beats, "beat_type":4, "line":0})
			previous_beats = bar_beats
		for beat_index: int in bar_beats:
			var beat_key := "%d:%d" % [bar_index, beat_index]
			if not beat_map.has(beat_key): return _failed("missing_notepan_beat", source, "Bar %d beat %d has no subdivision record." % [bar_index + 1, beat_index + 1], "Repair or re-export the NotePan score.")
			var subdivisions := int(beat_map[beat_key])
			for subdivision: int in subdivisions:
				var pieces := 2 if split_map.has("%s:%d" % [beat_key, subdivision]) else 1
				var divisor := subdivisions * pieces
				if TICKS_PER_QUARTER % divisor != 0: return _failed("unsupported_notepan_grid", source, "Subdivision %d cannot be represented at %d ticks per quarter." % [divisor, TICKS_PER_QUARTER], "Use subdivisions that divide 96 evenly.")
				var duration := TICKS_PER_QUARTER / divisor
				for split_part: int in pieces:
					columns.append({"tick":tick, "duration_ticks":duration, "bar":bar_index, "beat":beat_index, "subdivision":subdivision, "split_part":split_part})
					tick += duration
	var score_duration_ticks := tick
	var pitch_by_code: Dictionary = {}
	for value: Dictionary in track["handpan"]["notes"]:
		if value.has("code"): pitch_by_code[int(value["code"])] = str(value["pitch"]); continue
		var number := str(value["number"])
		if number.is_valid_int(): pitch_by_code[int(number)] = str(value["pitch"])
		elif number == "D": pitch_by_code[31] = str(value["pitch"])
	var by_column: Dictionary = {}
	var modifier_counts: Dictionary = {}
	var background_count := 0
	for note: Dictionary in track["notes"]:
		if note.get("background_only", false): background_count += 1; continue
		var column := int(note["column"])
		if column < 0 or column >= columns.size(): return _failed("notepan_note_column_out_of_range", source, "Note column %d is outside the rhythmic grid." % column, "Repair or re-export the NotePan score.")
		if not by_column.has(column): by_column[column] = []
		(by_column[column] as Array).append(note)
		for modifier: String in ["nuance", "effect"]:
			if int(note.get(modifier, 0)) != 0: modifier_counts[modifier] = int(modifier_counts.get(modifier, 0)) + 1
		for modifier: String in ["grace", "finger_roll"]:
			if bool(note.get(modifier, false)): modifier_counts[modifier] = int(modifier_counts.get(modifier, 0)) + 1
	if by_column.is_empty(): return _failed("empty_notepan_score", source, "The NotePan track contains no playable attacks.", "Export a score containing at least one attack.")
	var attack_columns: Array = by_column.keys(); attack_columns.sort()
	var notes: Array[Dictionary] = []
	for attack_index: int in attack_columns.size():
		var column := int(attack_columns[attack_index])
		var column_data: Dictionary = columns[column]
		var next_tick := int(columns[int(attack_columns[attack_index + 1])]["tick"]) if attack_index + 1 < attack_columns.size() else score_duration_ticks
		var attack_notes: Array = by_column[column]
		var has_pitched := false
		for raw: Dictionary in attack_notes:
			var code := int(raw["note"])
			if code not in [35, 36, 37, 38, 39, 41]: has_pitched = true
		for raw: Dictionary in attack_notes:
			var converted := _convert_note(source, raw, column_data, next_tick - int(column_data["tick"]), pitch_by_code, has_pitched)
			if not converted.get("ok", false): return converted
			notes.append(converted["note"])
	if background_count > 0: warnings.append(_diagnostic("warning", "notepan_background_ignored", source, "notes", "Ignored %d background-only NotePan item(s)." % background_count, "No action is required for gameplay."))
	for modifier: String in modifier_counts:
		warnings.append(_diagnostic("warning", "notepan_%s_simplified" % modifier, source, "notes", "Imported %d %s-marked attack(s) as base gameplay attacks." % [modifier_counts[modifier], modifier.replace("_", " ")], "Use MusicXML plus overlay if this distinction must affect gameplay."))
	if not (track["annotations"] as Array).is_empty(): warnings.append(_diagnostic("warning", "notepan_annotations_ignored", source, "annotations", "Ignored %d display annotation(s)." % (track["annotations"] as Array).size(), "Annotations do not affect PanBeat gameplay."))
	var tempo_specs: Array[Dictionary] = []
	for tempo: Dictionary in tempos:
		if not is_finite(float(tempo["tempo"])) or float(tempo["tempo"]) <= 0.0: return _failed("invalid_notepan_tempo", source, "Tempo must be finite and positive.", "Repair or re-export the NotePan score.")
		if not is_finite(float(tempo["final_tempo"])): return _failed("invalid_notepan_tempo", source, "Final tempo must be finite.", "Repair or re-export the NotePan score.")
		var bar_index := int(tempo["bar"]); var beat_index := int(tempo["beat"])
		if bar_index < 0 or bar_index >= bars.size() or beat_index < 0 or beat_index >= int(bars[bar_index]["beats"]): return _failed("invalid_notepan_tempo_position", source, "Tempo points outside the bar grid.", "Repair or re-export the NotePan score.")
		var measure: Dictionary = measures[bar_index]
		var start_tick := int(measure["start_tick"]) + beat_index * TICKS_PER_QUARTER
		var final_tempo := float(tempo["final_tempo"])
		var duration_beats := int(tempo["duration"])
		var has_final_tempo := final_tempo > 0.0
		var has_duration := duration_beats > 0
		if has_final_tempo != has_duration: return _failed("invalid_notepan_tempo_ramp", source, "A NotePan tempo ramp requires both a positive final tempo and duration.", "Repair or re-export the tempo variation.")
		if final_tempo < 0.0: return _failed("invalid_notepan_tempo", source, "Final tempo must be positive when present.", "Repair or re-export the NotePan score.")
		var duration_ticks := duration_beats * TICKS_PER_QUARTER
		if start_tick + duration_ticks > score_duration_ticks: return _failed("notepan_tempo_ramp_out_of_range", source, "Tempo ramp at bar %d beat %d extends beyond the score." % [bar_index + 1, beat_index + 1], "Shorten the ramp or extend the NotePan score.")
		tempo_specs.append({"tick":start_tick, "end_tick":start_tick + duration_ticks, "bpm":float(tempo["tempo"]), "final_bpm":final_tempo, "duration_ticks":duration_ticks, "part":str(track["name"]), "measure":str(bar_index + 1), "source_order":tempo_specs.size()})
	var spec_by_tick: Dictionary = {}
	var collision_count := 0
	for spec: Dictionary in tempo_specs:
		var spec_tick := int(spec["tick"])
		if spec_by_tick.has(spec_tick):
			var previous: Dictionary = spec_by_tick[spec_tick]
			if roundi(float(previous["bpm"]) * 1000.0) != roundi(float(spec["bpm"]) * 1000.0) or roundi(float(previous["final_bpm"]) * 1000.0) != roundi(float(spec["final_bpm"]) * 1000.0) or int(previous["duration_ticks"]) != int(spec["duration_ticks"]): collision_count += 1
		spec_by_tick[spec_tick] = spec
	tempo_specs.clear()
	for spec_tick: Variant in spec_by_tick: tempo_specs.append(spec_by_tick[spec_tick])
	tempo_specs.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["tick"]) < int(right["tick"]))
	var tempo_by_tick: Dictionary = {}
	var expanded_count := 0
	var occupied_until := -1
	for spec: Dictionary in tempo_specs:
		var start_tick := int(spec["tick"])
		var duration_ticks := int(spec["duration_ticks"])
		if start_tick < occupied_until: return _failed("overlapping_notepan_tempo_ramp", source, "A tempo variation starts before the preceding ramp finishes.", "Move or shorten the overlapping NotePan tempo variation.")
		if duration_ticks > 0: occupied_until = int(spec["end_tick"])
		var generated_count := duration_ticks + 1 if duration_ticks > 0 else 1
		expanded_count += generated_count
		if expanded_count > MAX_RECORDS: return _failed("notepan_tempo_event_limit", source, "Expanded tempo ramps exceed the %d-event safety limit." % MAX_RECORDS, "Shorten or simplify the NotePan tempo ramps.")
		for offset: int in generated_count:
			var ratio := float(offset) / float(duration_ticks) if duration_ticks > 0 else 0.0
			var bpm := lerpf(float(spec["bpm"]), float(spec["final_bpm"]), ratio) if duration_ticks > 0 else float(spec["bpm"])
			var event_tick := start_tick + offset
			if tempo_by_tick.has(event_tick) and roundi(float(tempo_by_tick[event_tick]["bpm"]) * 1000.0) != roundi(bpm * 1000.0): collision_count += 1
			tempo_by_tick[event_tick] = {"tick":event_tick, "bpm":bpm, "part":spec["part"], "measure":spec["measure"], "source":"notepan-ramp" if duration_ticks > 0 else "notepan", "line":0}
	var tempo_ticks: Array = tempo_by_tick.keys(); tempo_ticks.sort()
	var tempo_events: Array[Dictionary] = []
	for tempo_tick: Variant in tempo_ticks: tempo_events.append(tempo_by_tick[tempo_tick])
	if collision_count > 0: warnings.append(_diagnostic("warning", "notepan_tempo_collision_resolved", source, "tempo", "Resolved %d same-tick tempo collision(s) using the later NotePan variation." % collision_count, "No action is required unless playback timing differs from NotePan."))
	var score := SymbolicScoreModel.new(source, "notepan-schema-%d" % schema, str(track["name"]), TICKS_PER_QUARTER, measures, notes, tempo_events, time_signatures, [])
	var metadata := {"title":title, "artist":artist, "handpan_scale_name":str(track["handpan"]["scale"]), "notepan_info":info, "notepan_app_version":app_version}
	return {"ok":true, "score":score, "metadata":metadata, "diagnostics":warnings}

static func _convert_note(source: String, raw: Dictionary, column: Dictionary, duration_ticks: int, pitch_by_code: Dictionary, has_pitched: bool) -> Dictionary:
	var code := int(raw["note"])
	var note := {"part":"NotePan", "measure":str(int(column["bar"]) + 1), "measure_index":int(column["bar"]), "tick":int(column["tick"]), "duration_ticks":duration_ticks, "voice":str(int(raw["lane"]) + 1), "line":0, "tie_types":[], "notepan_label":str(SPECIAL_LABELS.get(code, code))}
	match code:
		35: note["is_unpitched"] = true; note["is_ignored"] = true
		37, 39:
			note["is_unpitched"] = true
			if has_pitched: note["is_ignored"] = true
			else: note["authoring_technique"] = "slap"
		36, 38, 41: note["is_unpitched"] = true; note["authoring_technique"] = "ding"
		_:
			if not pitch_by_code.has(code): return _failed("undefined_notepan_pitch", source, "NotePan slot %d has no embedded pitch." % code, "Correct the source handpan definition.")
			var pitch := _parse_pitch(str(pitch_by_code[code]))
			if pitch.is_empty(): return _failed("invalid_notepan_pitch", source, "Unsupported NotePan pitch: %s." % pitch_by_code[code], "Use a pitch such as D3, F#4, or Bb3.")
			note.merge(pitch)
	return {"ok":true, "note":note}

static func _parse_pitch(value: String) -> Dictionary:
	var expression := RegEx.new()
	if expression.compile("^([A-G])([#b]?)(-?[0-9]+)$") != OK: return {}
	var matched := expression.search(value)
	if matched == null: return {}
	var accidental := matched.get_string(2)
	var octave_text := matched.get_string(3)
	if not octave_text.is_valid_int(): return {}
	var octave := int(octave_text)
	var alter := 1 if accidental == "#" else -1 if accidental == "b" else 0
	var midi := (octave + 1) * 12 + int({"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11}[matched.get_string(1)]) + alter
	if midi < 0 or midi > 127: return {}
	return {"step":matched.get_string(1), "alter":alter, "octave":octave}

static func _reader_failure(reader: ByteReader, source: String) -> Dictionary:
	return _failed(reader.error_code, source, reader.error_message, "Repair or re-export the NotePan schema 6 or 8 tablature.")

static func _diagnostic(severity: String, code: String, file: String, element: String, message: String, remediation: String) -> Dictionary:
	return {"severity":severity, "code":code, "file":file, "part":"", "measure":"", "element":element, "message":message, "remediation":remediation}

static func _failed(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"ok":false, "diagnostics":[_diagnostic("error", code, file, "notepan", message, remediation)]}
