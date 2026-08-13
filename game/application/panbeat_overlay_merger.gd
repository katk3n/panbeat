class_name PanBeatOverlayMerger
extends RefCounted

const Canonical := preload("res://application/canonical_json.gd")
const OVERLAY_VERSIONS: Array[String] = ["1.0.0", "1.1.0"]

static func merge(timed_chart: RefCounted, overlay: Dictionary, source_sha256: String, profile: Dictionary, explicit_pitch_mapping: Dictionary = {}, notation_octave_shift: int = 0) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var annotations: Array = []
	var song_metadata: Dictionary = {}
	if not overlay.is_empty():
		var overlay_version := str(overlay.get("schema_version", ""))
		if not OVERLAY_VERSIONS.has(overlay_version): diagnostics.append(_metadata_diagnostic("unsupported_overlay_version", "overlay schema_version must be 1.0.0 or 1.1.0"))
		if overlay.get("source_musicxml_sha256") != source_sha256: diagnostics.append(_diagnostic("overlay_source_checksum_mismatch", "overlay does not match source MusicXML SHA-256", -1))
		if overlay.get("annotations") is not Array: diagnostics.append(_diagnostic("invalid_annotations", "overlay annotations must be an array", -1))
		else: annotations = overlay["annotations"]
		if overlay.has("handpan_scale_name"):
			if overlay_version != "1.1.0":
				diagnostics.append(_metadata_diagnostic("unsupported_overlay_metadata_version", "handpan_scale_name requires overlay schema_version 1.1.0"))
			else:
				var scale_name: Variant = overlay["handpan_scale_name"]
				if scale_name is not String:
					diagnostics.append(_metadata_diagnostic("invalid_handpan_scale_name", "handpan_scale_name must be a string"))
				else:
					var text := scale_name as String
					if text.is_empty() or text.length() > 80 or text != text.strip_edges() or "\n" in text or "\r" in text or "\t" in text:
						diagnostics.append(_metadata_diagnostic("invalid_handpan_scale_name", "handpan_scale_name must be a trimmed single-line string of 1 to 80 characters"))
					else:
						song_metadata["handpan_scale_name"] = text
	if not diagnostics.is_empty(): return {"ok":false, "diagnostics":diagnostics}
	var selected: Dictionary = {}
	for index: int in annotations.size():
		var annotation_value: Variant = annotations[index]
		if annotation_value is not Dictionary:
			diagnostics.append(_diagnostic("invalid_annotation", "annotation must be an object", index)); continue
		var annotation := annotation_value as Dictionary
		var selector: Variant = annotation.get("selector")
		if selector is not Dictionary:
			diagnostics.append(_diagnostic("invalid_selector", "selector must be an object", index)); continue
		var selector_dictionary := selector as Dictionary
		var has_id := selector_dictionary.has("note_id")
		var has_source := selector_dictionary.has_all(["part", "measure", "tick", "voice"])
		if has_id == has_source:
			diagnostics.append(_diagnostic("invalid_selector", "selector must use exactly one note_id or complete source coordinate", index)); continue
		var matches: Array[Dictionary] = []
		for note: Dictionary in timed_chart.notes:
			if has_id and note.get("note_id") == selector_dictionary.get("note_id"): matches.append(note)
			elif has_source and _source_matches(note.get("source", {}), selector_dictionary): matches.append(note)
		if matches.is_empty():
			diagnostics.append(_diagnostic("unused_annotation", "selector matches no runtime note", index)); continue
		if matches.size() > 1:
			diagnostics.append(_diagnostic("selector_multiple_matches", "selector matches more than one runtime note", index)); continue
		var note_id: String = matches[0]["note_id"]
		if selected.has(note_id):
			diagnostics.append(_diagnostic("duplicate_selector", "more than one annotation selects %s" % note_id, index)); continue
		var technique := str(annotation.get("technique", ""))
		var target_id := str(annotation.get("target_id", ""))
		if not ["tone", "ding", "slap"].has(technique): diagnostics.append(_diagnostic("invalid_technique", "unknown technique: %s" % technique, index)); continue
		if not _profile_has_pair(profile, technique, target_id): diagnostics.append(_diagnostic("unknown_target", "profile has no %s:%s target" % [technique, target_id], index)); continue
		selected[note_id] = {"technique":technique, "target_id":target_id, "annotation_index":index}
	if not diagnostics.is_empty(): return {"ok":false, "diagnostics":diagnostics}
	var gameplay_notes: Array[Dictionary] = []
	for note: Dictionary in timed_chart.notes:
		var mapping: Dictionary = selected.get(note["note_id"], {})
		if mapping.is_empty() and not str(note.get("authoring_technique", "")).is_empty():
			var authoring_technique := str(note["authoring_technique"])
			var authoring_target := str(note.get("authoring_target_id", ""))
			if authoring_target.is_empty():
				var resolved_target := _unique_profile_target(profile, authoring_technique)
				if not resolved_target.get("ok", false):
					diagnostics.append(_diagnostic(str(resolved_target.get("code", "unknown_target")), str(resolved_target.get("error", "Technique target is unavailable.")), -1, note.get("source", {}))); continue
				authoring_target = str(resolved_target["target_id"])
			mapping = {"technique":authoring_technique, "target_id":authoring_target}
			if not _profile_has_pair(profile, mapping["technique"], mapping["target_id"]):
				diagnostics.append(_diagnostic("unknown_target", "profile has no %s:%s target" % [mapping["technique"], mapping["target_id"]], -1, note.get("source", {}))); continue
		if mapping.is_empty():
			mapping = _resolve_pitch(note["pitch"], profile, explicit_pitch_mapping, notation_octave_shift)
			if not mapping.get("ok", false):
				diagnostics.append(_diagnostic(mapping.get("code", "unsupported_pitch"), mapping.get("error", "pitch is not mapped"), -1, note.get("source", {}))); continue
			mapping.erase("ok")
		if mapping.get("technique") == "slap" and not selected.has(note["note_id"]) and note.get("authoring_technique") != "slap":
			diagnostics.append(_diagnostic("slap_requires_overlay", "Slap must be explicitly annotated in the PanBeat overlay", -1, note.get("source", {}))); continue
		gameplay_notes.append({"note_id":note["note_id"], "timestamp_us":note["timestamp_us"], "duration_us":note["duration_us"], "technique":mapping["technique"], "target_id":mapping["target_id"], "source":note["source"], "pitch":note["pitch"]})
	if not diagnostics.is_empty(): return {"ok":false, "diagnostics":diagnostics}
	var chart := {"schema_version":"1.0.0", "chart_id":timed_chart.chart_id, "importer_version":timed_chart.importer_version, "overlay_id":overlay.get("overlay_id", "none"), "profile_id":profile.get("profile_id", ""), "duration_us":timed_chart.duration_us, "tempo_map":timed_chart.tempo_map.duplicate(true), "notes":gameplay_notes}
	return {"ok":true, "chart":chart, "canonical_json":Canonical.encode(chart) + "\n", "song_metadata":song_metadata, "diagnostics":[]}

static func _resolve_pitch(pitch: Dictionary, profile: Dictionary, explicit: Dictionary, notation_octave_shift: int) -> Dictionary:
	var key := "%s%s%s" % [pitch.get("step", ""), "#" if int(pitch.get("alter", 0)) == 1 else "b" if int(pitch.get("alter", 0)) == -1 else "", pitch.get("octave", "")]
	if explicit.has(key):
		var mapping: Variant = explicit[key]
		if mapping is Dictionary and _profile_has_pair(profile, str(mapping.get("technique", "")), str(mapping.get("target_id", ""))): return {"ok":true, "technique":mapping["technique"], "target_id":mapping["target_id"]}
		return {"ok":false, "code":"invalid_explicit_mapping", "error":"explicit pitch mapping is not available in profile: %s" % key}
	var midi := _pitch_to_midi(pitch)
	if midi < 0: return {"ok":false, "code":"invalid_pitch", "error":"invalid pitch: %s" % key}
	midi += notation_octave_shift * 12
	var matches: Array[Dictionary] = []
	for value: Variant in profile.get("mappings", []):
		if value is Dictionary:
			var mapping := value as Dictionary
			if int(mapping.get("note", -1)) == midi and ["tone", "ding"].has(str(mapping.get("technique", ""))): matches.append(mapping)
	if matches.is_empty(): return {"ok":false, "code":"unsupported_pitch", "error":"pitch %s resolves to MIDI %d after notation octave shift %d and is not mapped by profile" % [key, midi, notation_octave_shift]}
	var first: Dictionary = matches[0]
	for mapping: Dictionary in matches:
		if mapping.get("technique") != first.get("technique") or mapping.get("target_id") != first.get("target_id"): return {"ok":false, "code":"ambiguous_pitch", "error":"pitch %s has multiple profile targets" % key}
	return {"ok":true, "technique":first["technique"], "target_id":first["target_id"]}

static func _pitch_to_midi(pitch: Dictionary) -> int:
	var semitones := {"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11}
	var step := str(pitch.get("step", ""))
	if not semitones.has(step): return -1
	return (int(pitch.get("octave", -2)) + 1) * 12 + int(semitones[step]) + int(pitch.get("alter", 0))

static func _profile_has_pair(profile: Dictionary, technique: String, target_id: String) -> bool:
	for value: Variant in profile.get("mappings", []):
		if value is Dictionary and value.get("technique") == technique and value.get("target_id") == target_id: return true
	return false

static func _unique_profile_target(profile: Dictionary, technique: String) -> Dictionary:
	var targets: Dictionary = {}
	for value: Variant in profile.get("mappings", []):
		if value is Dictionary and value.get("technique") == technique:
			targets[str(value.get("target_id", ""))] = true
	if targets.is_empty(): return {"ok":false, "code":"unknown_target", "error":"profile has no %s target" % technique}
	if targets.size() > 1: return {"ok":false, "code":"ambiguous_technique_target", "error":"profile has more than one %s target" % technique}
	return {"ok":true, "target_id":str(targets.keys()[0])}

static func _source_matches(source: Dictionary, selector: Dictionary) -> bool:
	return str(source.get("part", "")) == str(selector.get("part", "")) and str(source.get("measure", "")) == str(selector.get("measure", "")) and int(source.get("tick", -1)) == int(selector.get("tick", -2)) and str(source.get("voice", "")) == str(selector.get("voice", ""))

static func _diagnostic(code: String, message: String, annotation_index: int, source: Dictionary = {}) -> Dictionary:
	return {"severity":"error", "code":code, "file":"overlay" if annotation_index >= 0 else "MusicXML", "annotation_index":annotation_index, "part":source.get("part", ""), "measure":source.get("measure", ""), "element":"annotation" if annotation_index >= 0 else "note", "message":message, "remediation":"Correct the overlay selector, target, source checksum, or explicit pitch mapping."}

static func _metadata_diagnostic(code: String, message: String) -> Dictionary:
	return {"severity":"error", "code":code, "file":"overlay", "annotation_index":-1, "part":"", "measure":"", "element":"handpan_scale_name", "message":message, "remediation":"Use overlay schema_version 1.1.0 and a trimmed single-line handpan scale name of at most 80 characters."}
