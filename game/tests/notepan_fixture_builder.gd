class_name NotePanFixtureBuilder
extends RefCounted

static func valid(options: Dictionary = {}) -> PackedByteArray:
	var writer := Writer.new()
	writer.raw("PAN".to_ascii_buffer())
	writer.string("1.2.3")
	writer.i32(int(options.get("schema", 6)))
	if int(options.get("schema", 6)) >= 7: writer.boolean(bool(options.get("compressed", true)))
	writer.u8(int(options.get("content_type", 0)))
	if int(options.get("schema", 6)) not in [6, 8] or bool(options.get("compressed", true)) and int(options.get("schema", 6)) >= 7 or int(options.get("content_type", 0)) != 0: return writer.data
	writer.string(str(options.get("title", "Schema Six Song")))
	writer.string(str(options.get("artist", "NotePan Artist")))
	writer.string("Fixture info")
	var track_count := int(options.get("track_count", 1)); writer.i32(track_count)
	if options.get("stop_after_track_count", false): return writer.data
	for track_index: int in track_count:
		if int(options.get("schema", 6)) == 8: _track_v8(writer, track_index, options)
		else: _track(writer, track_index, options)
	writer.i32(1)
	writer.u8(4); writer.boolean(false); writer.boolean(true); writer.boolean(false); writer.boolean(false)
	var tempo_variations: Array = options.get("tempo_variations", [])
	if tempo_variations.is_empty(): tempo_variations = [{"tempo":float(options.get("tempo", 120.0)), "bar":0, "beat":0, "final_tempo":float(options.get("final_tempo", 140.0 if options.get("tempo_ramp", false) else 0.0)), "duration":int(options.get("tempo_duration", 4 if options.get("tempo_ramp", false) else 0))}]
	writer.i32(tempo_variations.size())
	for tempo: Dictionary in tempo_variations:
		writer.f32(float(tempo.get("tempo", 120.0))); writer.i16(int(tempo.get("bar", 0))); writer.u8(int(tempo.get("beat", 0)))
		writer.f32(float(tempo.get("final_tempo", 0.0))); writer.u8(int(tempo.get("duration", 0)))
	if int(options.get("schema", 6)) == 8:
		writer.i32(32)
		for _index: int in 32: writer.u8(0)
	if options.get("trailing", false): writer.u8(0xaa)
	return writer.data

static func _track(writer: Writer, track_index: int, options: Dictionary) -> void:
	writer.string("Handpan %d" % (track_index + 1)); writer.u8(100); writer.f64(0.0)
	writer.string("D Kurd"); writer.string("Fixture handpan"); writer.string(str(options.get("scale", "D Kurd 9")))
	writer.u8(2); writer.u8(0); writer.u8(1); writer.u8(0); writer.u8(0)
	writer.i32(3)
	_handpan_note(writer, "D", "D3", true)
	_handpan_note(writer, "1", "A3", false)
	_handpan_note(writer, "2", "Bb3", false)
	writer.i32(4)
	for beat: int in 4:
		writer.i16(0); writer.u8(beat); writer.u8(5 if options.get("unsupported_grid", false) and beat == 0 else 2)
	writer.i32(1)
	writer.i16(0); writer.u8(0); writer.u8(1)
	var notes: Array[Dictionary] = [
		{"column":0, "lane":0, "note":31},
		{"column":1, "lane":1, "note":35},
		{"column":2, "lane":2, "note":39},
		{"column":3, "lane":3, "note":37},
		{"column":4, "lane":0, "note":36},
		{"column":5, "lane":1, "note":38},
		{"column":6, "lane":2, "note":41},
		{"column":7, "lane":3, "note":1, "nuance":1, "effect":2, "grace":true, "finger_roll":true},
		{"column":8, "lane":0, "note":2},
		{"column":8, "lane":1, "note":39},
		{"column":1, "lane":0, "note":40},
		{"column":8, "lane":2, "note":40},
	]
	if options.get("bad_column", false): notes[0]["column"] = 999
	if options.get("bad_lane", false): notes[0]["lane"] = 4
	writer.i32(notes.size() + 1)
	for note: Dictionary in notes:
		writer.i16(int(note["column"])); writer.u8(int(note["lane"])); writer.u8(0); writer.boolean(false)
		writer.u8(int(note["note"])); writer.u8(int(note.get("nuance", 0))); writer.u8(int(note.get("effect", 0))); writer.boolean(bool(note.get("grace", false))); writer.boolean(bool(note.get("finger_roll", false)))
	writer.i16(0); writer.u8(0); writer.u8(1); writer.boolean(true)
	writer.i32(1); writer.i16(0); writer.string("Display annotation")

static func _track_v8(writer: Writer, track_index: int, options: Dictionary) -> void:
	writer.string("Handpan %d" % (track_index + 1)); writer.u8(100); writer.f64(0.0)
	writer.string("D Kurd 9"); writer.u8(1); writer.u8(0); writer.u8(0)
	writer.i32(3)
	_handpan_note_v8(writer, 1, 13, 3, false, "1")
	_handpan_note_v8(writer, 2, 15, 3, false, "2")
	_handpan_note_v8(writer, 51, 3, 3, true, "D")
	writer.i32(4)
	for beat: int in 4:
		writer.i16(0); writer.u8(beat); writer.u8(5 if options.get("unsupported_grid", false) and beat == 0 else 2)
	writer.i32(1); writer.i16(0); writer.u8(0); writer.u8(1)
	var notes: Array[Dictionary] = [
		{"column":0, "lane":0, "note":51}, {"column":1, "lane":2, "note":150},
		{"column":2, "lane":1, "note":151}, {"column":3, "lane":2, "note":171},
		{"column":4, "lane":1, "note":54}, {"column":5, "lane":2, "note":161},
		{"column":6, "lane":1, "note":153}, {"column":7, "lane":2, "note":1},
		{"column":8, "lane":1, "note":2}, {"column":8, "lane":3, "note":151},
		{"column":1, "lane":0, "note":152}, {"column":8, "lane":2, "note":152},
	]
	if options.get("bad_column", false): notes[0]["column"] = 999
	if options.get("bad_lane", false): notes[0]["lane"] = 4
	writer.i32(notes.size() + 1)
	for note: Dictionary in notes:
		writer.i16(int(note["column"])); writer.u8(int(note["lane"])); writer.i32(0); writer.u8(int(note["note"])); writer.u8(2); writer.u8(0); writer.boolean(false); writer.boolean(false)
	writer.i16(0); writer.u8(1); writer.i32(1); writer.u8(0); writer.u8(2); writer.u8(0); writer.boolean(false); writer.boolean(false)
	writer.i32(1); writer.i16(0); writer.string("Display annotation")

static func _handpan_note_v8(writer: Writer, code: int, pitch: int, octave: int, ding: bool, number: String) -> void:
	writer.u8(code); writer.u8(pitch); writer.i32(octave); writer.boolean(ding)
	for _index: int in 5: writer.f64(0.0)
	writer.string(number)

static func _handpan_note(writer: Writer, number: String, pitch: String, ding: bool) -> void:
	writer.boolean(true); writer.boolean(ding); writer.string(number); writer.string(pitch)

class Writer extends RefCounted:
	var data := PackedByteArray()

	func raw(value: PackedByteArray) -> void: data.append_array(value)
	func u8(value: int) -> void: data.append(value & 0xff)
	func boolean(value: bool) -> void: u8(1 if value else 0)
	func i16(value: int) -> void:
		var offset := data.size(); data.resize(offset + 2); data.encode_s16(offset, value)
	func i32(value: int) -> void:
		var offset := data.size(); data.resize(offset + 4); data.encode_s32(offset, value)
	func f32(value: float) -> void:
		var offset := data.size(); data.resize(offset + 4); data.encode_float(offset, value)
	func f64(value: float) -> void:
		var offset := data.size(); data.resize(offset + 8); data.encode_double(offset, value)
	func string(value: String) -> void:
		var encoded := value.to_utf8_buffer(); var length := encoded.size()
		while length >= 0x80: u8((length & 0x7f) | 0x80); length >>= 7
		u8(length); raw(encoded)
