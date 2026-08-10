class_name JudgementEngine
extends RefCounted

const PERFECT_US: int = 30_000
const GREAT_US: int = 60_000
const GOOD_US: int = 100_000

static func judge(note_timestamp_us: int, input_timestamp: Variant) -> Dictionary:
	if input_timestamp == null:
		return {"judgement":"miss"}
	var delta_us: int = int(input_timestamp) - note_timestamp_us
	var absolute_us: int = absi(delta_us)
	if absolute_us > GOOD_US:
		return {"judgement":"miss"}
	var judgement: String = "perfect" if absolute_us <= PERFECT_US else ("great" if absolute_us <= GREAT_US else "good")
	return {"judgement":judgement, "input_timestamp_us":int(input_timestamp), "delta_us":delta_us}
