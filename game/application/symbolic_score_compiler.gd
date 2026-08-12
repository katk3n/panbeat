class_name SymbolicScoreCompiler
extends RefCounted

const TimedChart := preload("res://domain/timed_score_chart.gd")
const Canonical := preload("res://application/canonical_json.gd")
const IMPORTER_VERSION := "panbeat-musicxml-importer-v1"
const DEFAULT_BPM_MILLI := 120_000

static func compile(score: RefCounted, chart_id: String) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if score.ticks_per_quarter <= 0: return _failed("invalid_ticks_per_quarter", "ticks_per_quarter must be positive")
	var tempo_result := _build_tempo_map(score.tempo_events, score.ticks_per_quarter)
	if not tempo_result.get("ok", false): return tempo_result
	var tempo_map: Array[Dictionary] = tempo_result["tempo_map"]
	var tie_result := _build_sustain_notes(score.notes)
	if not tie_result.get("ok", false): return tie_result
	var duration_ticks := 0
	for note: Dictionary in score.notes: duration_ticks = maxi(duration_ticks, int(note["tick"]) + int(note["duration_ticks"]))
	var timed_notes: Array[Dictionary] = []
	for note: Dictionary in tie_result["notes"]:
		var timestamp_us := tick_to_us(int(note["tick"]), tempo_map, score.ticks_per_quarter)
		var end_us := tick_to_us(int(note["tick"]) + int(note["duration_ticks"]), tempo_map, score.ticks_per_quarter)
		var timed := note.duplicate(true)
		timed["timestamp_us"] = timestamp_us
		timed["duration_us"] = end_us - timestamp_us
		timed_notes.append(timed)
	var time_map: Array[Dictionary] = []
	for event: Dictionary in score.time_signatures:
		time_map.append({"tick":int(event["tick"]), "timestamp_us":tick_to_us(int(event["tick"]), tempo_map, score.ticks_per_quarter), "beats":int(event["beats"]), "beat_type":int(event["beat_type"]), "source":{"part":event.get("part", ""), "measure":event.get("measure", ""), "line":event.get("line", 0)}})
	var duration_us := tick_to_us(duration_ticks, tempo_map, score.ticks_per_quarter)
	var chart := TimedChart.new(chart_id, IMPORTER_VERSION, score.ticks_per_quarter, duration_ticks, duration_us, tempo_map, time_map, timed_notes)
	var dictionary := chart.to_dictionary()
	return {"ok": true, "chart": chart, "canonical_json": Canonical.encode(dictionary) + "\n", "diagnostics": diagnostics}

static func tick_to_us(tick: int, tempo_map: Array[Dictionary], ticks_per_quarter: int) -> int:
	var segment: Dictionary = tempo_map[0]
	for candidate: Dictionary in tempo_map:
		if int(candidate["tick"]) > tick: break
		segment = candidate
	var delta_ticks := tick - int(segment["tick"])
	return int(segment["start_us"]) + _round_div(delta_ticks * 60_000_000_000, ticks_per_quarter * int(segment["bpm_milli"]))

static func _build_tempo_map(events: Array[Dictionary], ticks_per_quarter: int) -> Dictionary:
	var normalized: Array[Dictionary] = []
	for event: Dictionary in events:
		var bpm_milli := roundi(float(event.get("bpm", 0.0)) * 1000.0)
		var beat_unit := str(event.get("beat_unit", "quarter"))
		match beat_unit:
			"whole": bpm_milli *= 4
			"half": bpm_milli *= 2
			"quarter": pass
			"eighth": bpm_milli = _round_div(bpm_milli, 2)
			_: return _failed("unsupported_beat_unit", "unsupported metronome beat-unit: %s" % beat_unit)
		if bpm_milli <= 0: return _failed("invalid_tempo", "tempo must be positive")
		normalized.append({"tick":int(event["tick"]), "bpm_milli":bpm_milli, "source":event.get("source", "unknown"), "part":event.get("part", ""), "measure":event.get("measure", ""), "line":event.get("line", 0)})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["tick"]) < int(right["tick"]))
	var unique: Array[Dictionary] = []
	for event: Dictionary in normalized:
		if not unique.is_empty() and int(unique.back()["tick"]) == int(event["tick"]):
			if int(unique.back()["bpm_milli"]) != int(event["bpm_milli"]): return _failed("conflicting_tempo", "conflicting tempo events at tick %d" % int(event["tick"]))
			continue
		unique.append(event)
	if unique.is_empty() or int(unique[0]["tick"]) > 0: unique.push_front({"tick":0, "bpm_milli":DEFAULT_BPM_MILLI, "source":"implicit-default", "part":"", "measure":"", "line":0})
	elif int(unique[0]["tick"]) < 0: return _failed("negative_tempo_tick", "tempo tick must be non-negative")
	var start_us := 0
	for index: int in unique.size():
		if index > 0:
			var previous: Dictionary = unique[index - 1]
			start_us += _round_div((int(unique[index]["tick"]) - int(previous["tick"])) * 60_000_000_000, ticks_per_quarter * int(previous["bpm_milli"]))
		unique[index]["start_us"] = start_us
	return {"ok":true, "tempo_map":unique}

static func _build_sustain_notes(notes: Array[Dictionary]) -> Dictionary:
	var result: Array[Dictionary] = []
	var active: Dictionary = {}
	for note: Dictionary in notes:
		if note.get("is_rest", false) or note.get("is_ignored", false): continue
		var key := _pitch_key(note)
		var ties: Array = note.get("tie_types", [])
		var has_start := "start" in ties
		var has_stop := "stop" in ties
		if has_stop:
			if not active.has(key): return _failed("tie_stop_without_start", "tie stop has no matching start at %s" % _source_label(note))
			var chain: Dictionary = active[key]
			if int(note["tick"]) != int(chain["next_tick"]): return _failed("tie_gap_or_overlap", "tie chain is not contiguous at %s" % _source_label(note))
			chain["duration_ticks"] = int(note["tick"]) + int(note["duration_ticks"]) - int(chain["tick"])
			chain["next_tick"] = int(note["tick"]) + int(note["duration_ticks"])
			if has_start: active[key] = chain
			else:
				chain.erase("next_tick"); result.append(chain); active.erase(key)
		elif has_start:
			if active.has(key): return _failed("tie_start_while_active", "duplicate tie start at %s" % _source_label(note))
			var chain := _runtime_note(note)
			chain["next_tick"] = int(note["tick"]) + int(note["duration_ticks"])
			active[key] = chain
		else: result.append(_runtime_note(note))
	if not active.is_empty(): return _failed("unclosed_tie", "tie start has no matching stop")
	_assign_unique_note_ids(result)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["tick"]) < int(right["tick"]) if int(left["tick"]) != int(right["tick"]) else str(left["note_id"]) < str(right["note_id"]))
	return {"ok":true, "notes":result}

static func _assign_unique_note_ids(notes: Array[Dictionary]) -> void:
	var counts: Dictionary = {}
	for note: Dictionary in notes:
		var base := str(note["note_id"])
		counts[base] = int(counts.get(base, 0)) + 1
		if int(counts[base]) > 1: note["note_id"] = "%s:#%d" % [base, counts[base]]

static func _runtime_note(note: Dictionary) -> Dictionary:
	var voice := str(note.get("voice", "1"))
	var source := {"part":str(note.get("part", "")), "measure":str(note.get("measure", "")), "tick":int(note["tick"]), "voice":voice, "line":int(note.get("line", 0))}
	if note.get("is_unpitched", false):
		return {"note_id":"%s:m%s:t%d:v%s:unpitched:%s" % [source.part, source.measure, source.tick, voice, note.get("authoring_technique", "unknown")], "tick":int(note["tick"]), "duration_ticks":int(note["duration_ticks"]), "pitch":{}, "source":source, "authoring_technique":str(note.get("authoring_technique", "")), "authoring_target_id":str(note.get("authoring_target_id", "")), "notepan_label":str(note.get("notepan_label", ""))}
	var pitch := {"step":str(note.get("step", "")), "alter":int(note.get("alter", 0)), "octave":int(note.get("octave", 0))}
	return {"note_id":"%s:m%s:t%d:v%s:%s%d:%d" % [source.part, source.measure, source.tick, voice, pitch.step, pitch.octave, pitch.alter], "tick":int(note["tick"]), "duration_ticks":int(note["duration_ticks"]), "pitch":pitch, "source":source}

static func _pitch_key(note: Dictionary) -> String:
	return "%s:%s:%s:%s" % [note.get("voice", "1"), note.get("step", ""), note.get("alter", 0), note.get("octave", 0)]

static func _source_label(note: Dictionary) -> String:
	return "%s measure %s tick %s voice %s" % [note.get("part", ""), note.get("measure", ""), note.get("tick", ""), note.get("voice", "1")]

static func _round_div(numerator: int, denominator: int) -> int:
	return (numerator + denominator / 2) / denominator

static func _failed(code: String, message: String) -> Dictionary:
	return {"ok":false, "diagnostics":[{"severity":"error", "code":code, "message":message, "remediation":"Correct the MusicXML timing or tie data."}]}
