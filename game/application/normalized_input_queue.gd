class_name NormalizedInputQueue
extends RefCounted

var _events: Array[Dictionary] = []

func submit(event: Dictionary) -> bool:
	if event.get("kind") != "normalized_input":
		return false
	_events.append(event.duplicate(true))
	return true

func drain() -> Array[Dictionary]:
	var drained: Array[Dictionary] = _events
	_events = []
	return drained

func size() -> int:
	return _events.size()
