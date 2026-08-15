class_name PerformanceLayoutService
extends RefCounted

const Canonical := preload("res://application/canonical_json.gd")
const LAYOUT_VERSION := "1.0.0"
const STRATEGY := "lowest-ding-ascending-zigzag-v1"
const TONE_TARGETS: Array[String] = ["tone-1", "tone-2", "tone-3", "tone-4", "tone-5", "tone-6", "tone-7", "tone-8"]

static func provisional_profile(timed_chart: RefCounted, base_profile: Dictionary, notation_octave_shift: int = 0, preferred_ding_midi: int = -1) -> Dictionary:
	var profile := base_profile.duplicate(true)
	var mappings: Array[Dictionary] = []
	for value: Variant in base_profile.get("mappings", []):
		if value is Dictionary and value.get("technique") == "slap": mappings.append((value as Dictionary).duplicate(true))
	var pitches := _timed_pitches(timed_chart, notation_octave_shift)
	var ding_midi := preferred_ding_midi if pitches.has(preferred_ding_midi) else (int(pitches[0]) if not pitches.is_empty() else preferred_ding_midi)
	var tone_index := 0
	for midi_value: Variant in pitches:
		var midi := int(midi_value)
		if midi == ding_midi: mappings.append(_mapping(midi, "ding", "ding"))
		else:
			mappings.append(_mapping(midi, "tone", TONE_TARGETS[tone_index % TONE_TARGETS.size()]))
			tone_index += 1
	# Overlay annotations and NotePan techniques validate pairs before the final layout exists.
	for target: String in TONE_TARGETS: mappings.append(_mapping(-1, "tone", target))
	mappings.append(_mapping(-1, "ding", "ding"))
	for value: Variant in base_profile.get("mappings", []):
		if value is Dictionary and value.get("technique") in ["tone", "ding"]:
			var pair_mapping := _mapping(-1, str(value.get("technique", "")), str(value.get("target_id", "")))
			if not _has_pair(mappings, str(pair_mapping["technique"]), str(pair_mapping["target_id"])): mappings.append(pair_mapping)
	profile["mappings"] = mappings
	return profile

static func build(chart: Dictionary, base_profile: Dictionary, notation_octave_shift: int = 0, preferred_ding_midi: int = -1) -> Dictionary:
	var by_midi: Dictionary = {}
	var by_pair: Dictionary = {}
	var source_labels: Dictionary = {}
	var needs_ding := false
	var needs_slap := false
	for note: Dictionary in chart.get("notes", []):
		var technique := str(note.get("technique", ""))
		if technique == "slap": needs_slap = true; continue
		if technique == "ding": needs_ding = true
		var midi := pitch_to_midi(note.get("pitch", {}))
		if midi < 0: continue
		midi += notation_octave_shift * 12
		var target := str(note.get("target_id", ""))
		var pair := "%s:%s" % [technique, target]
		if not by_midi.has(midi) and by_midi.size() >= 9:
			return _failure("performance_layout_capacity_exceeded", "The song requires more than nine distinct pitched sounds; Mood Pan supports Ding plus eight Tone fields.")
		if by_midi.has(midi) and str(by_midi[midi]) != pair:
			return _failure("performance_layout_pitch_conflict", "MIDI note %d is assigned to more than one gameplay target." % midi)
		if by_pair.has(pair) and int(by_pair[pair]) != midi:
			return _failure("performance_layout_target_conflict", "%s is assigned to more than one sounding pitch." % pair)
		by_midi[midi] = pair; by_pair[pair] = midi
		var label := pitch_label(note.get("pitch", {}))
		if not source_labels.has(midi): source_labels[midi] = []
		if not (source_labels[midi] as Array).has(label): (source_labels[midi] as Array).append(label)
	if needs_ding and not by_pair.has("ding:ding"):
		var ding_midi := preferred_ding_midi
		if ding_midi < 0: ding_midi = _base_ding_midi(base_profile)
		if ding_midi < 0: return _failure("performance_layout_ding_unknown", "The score uses Ding but no sounding Ding pitch is available.")
		if by_midi.has(ding_midi): return _failure("performance_layout_pitch_conflict", "The Ding pitch is already assigned to another target.")
		by_midi[ding_midi] = "ding:ding"; by_pair["ding:ding"] = ding_midi; source_labels[ding_midi] = [midi_label(ding_midi)]
	if needs_slap:
		for value: Variant in base_profile.get("mappings", []):
			if value is Dictionary and value.get("technique") == "slap" and by_midi.has(int(value.get("note", -1))):
				return _failure("performance_layout_slap_pitch_collision", "A required pitched sound uses MIDI note %d, which is reserved for Slap in the selected device profile." % int(value.get("note", -1)))
	var slots: Array[Dictionary] = []
	for pair_value: Variant in by_pair:
		var pair := str(pair_value); var parts := pair.split(":"); var midi := int(by_pair[pair])
		var labels: Array = source_labels.get(midi, [midi_label(midi)]); labels.sort()
		slots.append({"technique":parts[0], "target_id":parts[1], "midi_note":midi, "display_names":labels})
	slots.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _target_order(str(left["target_id"])) < _target_order(str(right["target_id"])))
	var identity := {"layout_version":LAYOUT_VERSION, "strategy":STRATEGY, "slots":slots}
	var layout_id := (Canonical.encode(identity) + "\n").sha256_text()
	identity["layout_id"] = layout_id
	return {"ok":true, "layout":identity, "profile":effective_profile(base_profile, identity)}

static func effective_profile(base_profile: Dictionary, layout: Dictionary) -> Dictionary:
	var profile := base_profile.duplicate(true)
	var mappings: Array[Dictionary] = []
	var channels: Dictionary = {}
	for value: Variant in base_profile.get("mappings", []):
		if value is not Dictionary: continue
		var mapping := value as Dictionary
		if mapping.get("technique") == "slap": mappings.append(mapping.duplicate(true))
		elif mapping.get("technique") in ["tone", "ding"]: channels[int(mapping.get("channel_wire", 0))] = true
	if channels.is_empty(): channels[0] = true
	for slot: Dictionary in layout.get("slots", []):
		for channel_value: Variant in channels:
			var mapping := _mapping(int(slot["midi_note"]), str(slot["technique"]), str(slot["target_id"])); mapping["channel_wire"] = int(channel_value); mappings.append(mapping)
	profile["mappings"] = mappings
	profile["performance_layout_id"] = layout.get("layout_id", "")
	return profile

static func validate(layout: Dictionary) -> bool:
	if layout.get("layout_version") != LAYOUT_VERSION or layout.get("strategy") != STRATEGY or str(layout.get("layout_id", "")).length() != 64 or layout.get("slots") is not Array: return false
	var slots: Array = layout["slots"]
	if slots.is_empty() or slots.size() > 9: return false
	var targets: Dictionary = {}; var notes: Dictionary = {}; var canonical_slots: Array[Dictionary] = []
	for slot_value: Variant in slots:
		if slot_value is not Dictionary: return false
		var slot := slot_value as Dictionary; var technique := str(slot.get("technique", "")); var target := str(slot.get("target_id", "")); var midi := int(slot.get("midi_note", -1))
		if technique == "ding" and target != "ding" or technique == "tone" and target not in TONE_TARGETS or technique not in ["ding", "tone"]: return false
		if midi < 0 or midi > 127 or targets.has(target) or notes.has(midi) or slot.get("display_names") is not Array or (slot["display_names"] as Array).is_empty(): return false
		for name: Variant in slot["display_names"]:
			if name is not String or str(name).is_empty(): return false
		var names: Array[String] = []
		for name: Variant in slot["display_names"]: names.append(str(name))
		canonical_slots.append({"technique":technique, "target_id":target, "midi_note":midi, "display_names":names})
		targets[target] = true; notes[midi] = true
	var identity := {"layout_version":str(layout["layout_version"]), "strategy":str(layout["strategy"]), "slots":canonical_slots}
	return str(layout["layout_id"]) == (Canonical.encode(identity) + "\n").sha256_text()

static func preferred_ding_midi(metadata: Dictionary, notation_octave_shift: int = 0) -> int:
	var values: Array = metadata.get("handpan_ding_pitches", [])
	if values.size() != 1: return -1
	var parsed := parse_pitch_name(str(values[0]))
	return pitch_to_midi(parsed) + notation_octave_shift * 12 if not parsed.is_empty() else -1

static func pitch_to_midi(pitch: Dictionary) -> int:
	var semitones := {"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11}
	var step := str(pitch.get("step", ""))
	if not semitones.has(step): return -1
	var midi := (int(pitch.get("octave", -20)) + 1) * 12 + int(semitones[step]) + int(pitch.get("alter", 0))
	return midi if midi >= 0 and midi <= 127 else -1

static func parse_pitch_name(value: String) -> Dictionary:
	var regex := RegEx.new()
	if regex.compile("^([A-G])([#b]?)(-?[0-9]+)$") != OK: return {}
	var found := regex.search(value)
	if found == null: return {}
	return {"step":found.get_string(1), "alter":1 if found.get_string(2) == "#" else -1 if found.get_string(2) == "b" else 0, "octave":int(found.get_string(3))}

static func pitch_label(pitch: Dictionary) -> String:
	return "%s%s%d" % [pitch.get("step", ""), "♯" if int(pitch.get("alter", 0)) == 1 else "♭" if int(pitch.get("alter", 0)) == -1 else "", int(pitch.get("octave", 0))]

static func midi_label(midi: int) -> String:
	var names: Array[String] = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
	return "%s%d" % [names[midi % 12], midi / 12 - 1]

static func _timed_pitches(timed_chart: RefCounted, shift: int) -> Array:
	var found: Dictionary = {}
	for note: Dictionary in timed_chart.notes:
		var midi := pitch_to_midi(note.get("pitch", {}))
		if midi >= 0: found[midi + shift * 12] = true
	var values: Array = found.keys(); values.sort(); return values

static func _base_ding_midi(profile: Dictionary) -> int:
	for value: Variant in profile.get("mappings", []):
		if value is Dictionary and value.get("technique") == "ding": return int(value.get("note", -1))
	return -1

static func _mapping(note: int, technique: String, target: String) -> Dictionary:
	return {"channel_wire":0, "note":note, "velocity_min":1, "velocity_max":127, "technique":technique, "target_id":target}

static func _has_pair(mappings: Array[Dictionary], technique: String, target: String) -> bool:
	for mapping: Dictionary in mappings:
		if mapping.get("technique") == technique and mapping.get("target_id") == target: return true
	return false

static func _target_order(target: String) -> int:
	if target == "ding": return 0
	return int(target.trim_prefix("tone-")) if target.begins_with("tone-") else 99

static func _failure(code: String, message: String) -> Dictionary:
	return {"ok":false, "diagnostics":[{"severity":"error", "code":code, "file":"score", "part":"", "measure":"", "element":"performance-layout", "message":message, "remediation":"Use at most one Ding and eight distinct Tone pitches, then import again."}]}
