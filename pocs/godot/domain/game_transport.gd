class_name GameTransport
extends RefCounted

var _clock: RefCounted
var _start_seconds: float = 0.0
var _paused_at_seconds: float = 0.0
var _paused_song_time_us: int = 0
var is_running: bool = false
var is_paused: bool = false

func _init(clock: RefCounted) -> void:
	_clock = clock

func start(scheduled_clock_seconds: float) -> void:
	_start_seconds = scheduled_clock_seconds
	_paused_at_seconds = 0.0
	_paused_song_time_us = 0
	is_running = true
	is_paused = false

func song_time_us() -> int:
	if not is_running:
		return 0
	if is_paused:
		return _paused_song_time_us
	return maxi(0, roundi((_clock.time_seconds() - _start_seconds) * 1_000_000.0))

func pause() -> void:
	if not is_running or is_paused:
		return
	_paused_song_time_us = song_time_us()
	_paused_at_seconds = _clock.time_seconds()
	is_paused = true

func resume() -> void:
	if not is_running or not is_paused:
		return
	_start_seconds += _clock.time_seconds() - _paused_at_seconds
	is_paused = false
