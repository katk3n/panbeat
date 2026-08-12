class_name AudioTransportService
extends RefCounted

const IDLE: String = "idle"
const SCHEDULED: String = "scheduled"
const PLAYING: String = "playing"
const PAUSED: String = "paused"
const COMPLETED: String = "completed"
const FAILED: String = "failed"

var _backend: RefCounted
var _session: RefCounted
var _duration_us: int
var _state: String = IDLE
var _scheduled_monotonic_seconds: float = 0.0
var _actual_start_monotonic_seconds: float = 0.0
var _last_song_time_us: int = 0
var _paused_song_time_us: int = 0
var _failure_reason: String = ""
var _start_lead_seconds: float = 0.0

func _init(backend: RefCounted, duration_us: int, session: RefCounted = null) -> void:
	assert(backend != null)
	assert(duration_us > 0)
	_backend = backend
	_duration_us = duration_us
	_session = session

func schedule_start(start_lead_seconds: float) -> Dictionary:
	if _state != IDLE:
		return _reject("transport has already been scheduled")
	if start_lead_seconds < 0.0:
		return _reject("start lead must not be negative")
	if not _backend.ready():
		return _fail("audio stream is not ready")
	_start_lead_seconds = start_lead_seconds
	_scheduled_monotonic_seconds = _backend.monotonic_seconds() + start_lead_seconds
	_state = SCHEDULED
	return {"ok": true, "scheduled_monotonic_seconds": _scheduled_monotonic_seconds}

func update() -> Dictionary:
	if _state == SCHEDULED and _backend.monotonic_seconds() >= _scheduled_monotonic_seconds:
		if not _backend.play():
			return _fail("audio playback failed to start")
		_actual_start_monotonic_seconds = _backend.monotonic_seconds()
		_state = PLAYING
		if _session != null:
			var transition: Dictionary = _session.transition("playing")
			if not transition.get("ok", false):
				return _fail("session rejected audio start: %s" % transition.get("error", "unknown"))
	if _state == PLAYING:
		var current_us: int = _audio_song_time_us()
		if current_us >= _duration_us or (not _backend.is_playing() and current_us > 0):
			_last_song_time_us = _duration_us
			_state = COMPLETED
			if _session != null:
				_session.transition("completed")
	return {"ok": _state != FAILED, "state": _state}

func now_us() -> int:
	match _state:
		SCHEDULED:
			return mini(0, roundi((_backend.monotonic_seconds() - _scheduled_monotonic_seconds) * 1_000_000.0))
		PLAYING:
			return _audio_song_time_us()
		PAUSED:
			return _paused_song_time_us
		COMPLETED:
			return _duration_us
		_:
			return 0

func pause() -> Dictionary:
	if _state != PLAYING:
		return _reject("transport is not playing")
	_paused_song_time_us = _audio_song_time_us()
	_backend.set_paused(true)
	_state = PAUSED
	if _session != null:
		_session.transition("paused")
	return {"ok": true, "state": _state}

func resume() -> Dictionary:
	if _state != PAUSED:
		return _reject("transport is not paused")
	_backend.set_paused(false)
	_state = PLAYING
	if _session != null:
		_session.transition("playing")
	return {"ok": true, "state": _state}

func state() -> String:
	return _state

func accepts_input() -> bool:
	return _state == PLAYING

func diagnostics() -> Dictionary:
	return {
		"state": _state,
		"start_lead_seconds": _start_lead_seconds,
		"scheduled_monotonic_seconds": _scheduled_monotonic_seconds,
		"actual_start_monotonic_seconds": _actual_start_monotonic_seconds,
		"start_lateness_us": maxi(0, roundi((_actual_start_monotonic_seconds - _scheduled_monotonic_seconds) * 1_000_000.0)) if _actual_start_monotonic_seconds > 0.0 else 0,
		"sample_rate_hz": _backend.sample_rate_hz(),
		"output_latency_seconds": _backend.output_latency_seconds(),
		"buffer_frames_estimate": _backend.buffer_frames_estimate(),
		"audio_duration_us": _duration_us,
		"failure_reason": _failure_reason,
	}

func _audio_song_time_us() -> int:
	var candidate: int = clampi(roundi(_backend.audio_position_seconds() * 1_000_000.0), 0, _duration_us)
	_last_song_time_us = maxi(_last_song_time_us, candidate)
	return _last_song_time_us

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

func _fail(reason: String) -> Dictionary:
	_failure_reason = reason
	_state = FAILED
	if _session != null and _session.state() != "failed":
		_session.transition("failed", reason)
	return {"ok": false, "error": reason, "state": _state}
