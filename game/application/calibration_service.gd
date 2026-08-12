class_name CalibrationService
extends RefCounted

const MIN_SAMPLES := 5
const MAX_RANGE_US := 120_000
const MAX_ABS_SAMPLE_US := 400_000
const OUTLIER_DISTANCE_US := 60_000

static func assign_input(input_us: int, pending_stimulus_us: int, next_cue_us: int, hit_window_us: int, early_input_buffered: bool = false) -> String:
	if pending_stimulus_us >= 0 and input_us >= pending_stimulus_us and input_us - pending_stimulus_us <= hit_window_us: return "current_cue"
	if not early_input_buffered and next_cue_us >= 0 and input_us < next_cue_us and next_cue_us - input_us <= hit_window_us: return "next_cue"
	return "extra_hit"

static func sample(stimulus_us: int, input_us: int, status: String, profile_id: String, audio_output_id: String, technique: String = "tone") -> Dictionary:
	var valid := status == "hit" and input_us >= 0 and absi(input_us - stimulus_us) <= MAX_ABS_SAMPLE_US
	return {"stimulus_timestamp_us":stimulus_us, "input_timestamp_us":input_us if input_us >= 0 else null, "delta_us":input_us - stimulus_us if input_us >= 0 else null, "status":status, "included":valid, "profile_id":profile_id, "audio_output_id":audio_output_id, "technique":technique}

static func analyze(samples: Array[Dictionary], current_input_offset_us: int = 0, current_audio_offset_us: int = 0) -> Dictionary:
	var candidates: Array[Dictionary] = []; var excluded: Array[Dictionary] = []
	for value: Dictionary in samples:
		if value.get("included", false) and value.get("delta_us") != null: candidates.append(value)
		else: excluded.append(value)
	if candidates.size() < MIN_SAMPLES: return {"ok":false, "code":"sample_shortage", "valid_count":candidates.size(), "required_count":MIN_SAMPLES, "excluded":excluded, "message":"Need at least %d valid hits; Extra Hit, Miss, and out-of-range samples are excluded." % MIN_SAMPLES}
	var candidate_deltas: Array[int] = []
	for value: Dictionary in candidates: candidate_deltas.append(int(value["delta_us"]))
	candidate_deltas.sort(); var candidate_median := _median(candidate_deltas); var deltas: Array[int] = []
	for value: Dictionary in candidates:
		if absi(int(value["delta_us"]) - candidate_median) > OUTLIER_DISTANCE_US:
			var outlier := value.duplicate(true); outlier["included"] = false; outlier["exclusion_reason"] = "timing_outlier"; excluded.append(outlier)
		else: deltas.append(int(value["delta_us"]))
	if deltas.size() < MIN_SAMPLES: return {"ok":false, "code":"variance_too_high", "valid_count":deltas.size(), "required_count":MIN_SAMPLES, "excluded":excluded, "message":"Too many timing outliers remain; retry with steady single hits on the repeating beat."}
	deltas.sort(); var median: int = _median(deltas); var deviations: Array[int] = []
	for delta: int in deltas: deviations.append(absi(delta - median))
	deviations.sort(); var mad: int = _median(deviations); var sample_range: int = int(deltas.back()) - int(deltas.front())
	if sample_range > MAX_RANGE_US: return {"ok":false, "code":"variance_too_high", "valid_count":deltas.size(), "median_delta_us":median, "mad_us":mad, "range_us":sample_range, "excluded":excluded, "message":"Hit timing varies too much (%d ms range). Retry with clear single hits." % roundi(sample_range / 1000.0)}
	return {"ok":true, "valid_count":deltas.size(), "outlier_count":excluded.filter(func(value: Dictionary) -> bool: return value.get("exclusion_reason") == "timing_outlier").size(), "median_delta_us":median, "mad_us":mad, "range_us":sample_range, "excluded":excluded, "before":{"input_offset_us":current_input_offset_us, "audio_offset_us":current_audio_offset_us}, "proposed":{"input_offset_us":current_audio_offset_us - median, "audio_offset_us":current_audio_offset_us}, "explanation":"Positive Input Offset moves input logically later; negative moves it earlier. Positive Audio Offset moves the judged note later."}

static func upsert_offset(settings: Dictionary, profile_id: String, audio_output_id: String, input_offset_us: int, audio_offset_us: int, samples: Array[Dictionary] = []) -> Dictionary:
	var updated := settings.duplicate(true); var offsets: Array = []
	for value: Variant in updated.get("offsets", []):
		if value is Dictionary and not (value.get("profile_id") == profile_id and value.get("audio_output_id") == audio_output_id): offsets.append(value)
	offsets.append({"profile_id":profile_id, "audio_output_id":audio_output_id, "input_offset_us":input_offset_us, "audio_offset_us":audio_offset_us, "calibration_samples":samples.duplicate(true)})
	offsets.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return "%s|%s" % [left["profile_id"], left["audio_output_id"]] < "%s|%s" % [right["profile_id"], right["audio_output_id"]])
	updated["offsets"] = offsets; return updated

static func find_offset(settings: Dictionary, profile_id: String, audio_output_id: String) -> Dictionary:
	for value: Variant in settings.get("offsets", []):
		if value is Dictionary and value.get("profile_id") == profile_id and value.get("audio_output_id") == audio_output_id: return (value as Dictionary).duplicate(true)
	return {"profile_id":profile_id, "audio_output_id":audio_output_id, "input_offset_us":0, "audio_offset_us":0, "calibration_samples":[]}

static func reset_offset(settings: Dictionary, profile_id: String, audio_output_id: String) -> Dictionary:
	return upsert_offset(settings, profile_id, audio_output_id, 0, 0, [])

static func _median(sorted: Array[int]) -> int:
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 == 1 else roundi((sorted[middle - 1] + sorted[middle]) / 2.0)
