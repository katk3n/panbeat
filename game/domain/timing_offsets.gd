class_name TimingOffsets
extends RefCounted

static func from_seconds(input_offset_sec: float, audio_offset_sec: float) -> Dictionary:
	return {
		"input_offset_us": roundi(input_offset_sec * 1_000_000.0),
		"audio_offset_us": roundi(audio_offset_sec * 1_000_000.0)
	}

static func adjusted_delta_us(expected_us: int, actual_us: int, offsets: Dictionary) -> int:
	var logical_actual_us: int = actual_us + int(offsets.get("input_offset_us", 0))
	var logical_expected_us: int = expected_us + int(offsets.get("audio_offset_us", 0))
	return logical_actual_us - logical_expected_us
