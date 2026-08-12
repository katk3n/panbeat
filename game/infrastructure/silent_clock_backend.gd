class_name SilentClockBackend
extends RefCounted

var _duration_seconds: float
var _playback_speed: float
var _clock: RefCounted
var _playing := false
var _paused := false
var _started_at := 0.0
var _paused_at := 0.0
var _paused_total := 0.0

func _init(duration_us: int, clock: RefCounted = null, playback_speed: float = 1.0) -> void:
	_duration_seconds = float(duration_us) / 1_000_000.0
	_clock = clock
	_playback_speed = playback_speed

func ready() -> bool:
	return _duration_seconds > 0.0 and _playback_speed > 0.0

func monotonic_seconds() -> float:
	return _clock.monotonic_seconds() if _clock != null else Time.get_ticks_usec() / 1_000_000.0

func play() -> bool:
	if not ready(): return false
	_started_at = monotonic_seconds(); _paused_total = 0.0; _playing = true; _paused = false
	return true

func is_playing() -> bool:
	return _playing and audio_position_seconds() < _duration_seconds

func set_paused(paused: bool) -> void:
	if not _playing or paused == _paused: return
	if paused:
		_paused_at = monotonic_seconds()
	else:
		_paused_total += monotonic_seconds() - _paused_at
	_paused = paused

func audio_position_seconds() -> float:
	if not _playing: return 0.0
	var now := _paused_at if _paused else monotonic_seconds()
	return clampf((now - _started_at - _paused_total) * _playback_speed, 0.0, _duration_seconds)

func sample_rate_hz() -> int: return 0
func output_latency_seconds() -> float: return 0.0
func buffer_frames_estimate() -> int: return 0
