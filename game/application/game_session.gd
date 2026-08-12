class_name GameSession
extends RefCounted

const LOADING: String = "loading"
const READY: String = "ready"
const PLAYING: String = "playing"
const PAUSED: String = "paused"
const COMPLETED: String = "completed"
const FAILED: String = "failed"

const ALLOWED: Dictionary = {
	LOADING: [READY, FAILED],
	READY: [PLAYING, FAILED],
	PLAYING: [PAUSED, COMPLETED, FAILED],
	PAUSED: [PLAYING, FAILED],
	COMPLETED: [],
	FAILED: [],
}

var _state: String = LOADING
var _failure_reason: String = ""

func state() -> String:
	return _state

func failure_reason() -> String:
	return _failure_reason

func transition(next_state: String, reason: String = "") -> Dictionary:
	if not ALLOWED.has(next_state):
		return {"ok": false, "error": "unknown session state: %s" % next_state}
	if not (ALLOWED[_state] as Array).has(next_state):
		return {"ok": false, "error": "invalid session transition: %s -> %s" % [_state, next_state]}
	if next_state == FAILED and reason.is_empty():
		return {"ok": false, "error": "failed state requires a reason"}
	_state = next_state
	_failure_reason = reason if next_state == FAILED else ""
	return {"ok": true, "state": _state}
