class_name GodotAudioClock
extends RefCounted

var _player: AudioStreamPlayer
var _last_seconds: float = 0.0
var correction_count: int = 0
var backward_count: int = 0
var max_backward_us: int = 0

func _init(player: AudioStreamPlayer) -> void:
	_player = player

func raw_time_seconds() -> float:
	return _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

func time_seconds() -> float:
	var raw: float = raw_time_seconds()
	if raw < _last_seconds:
		backward_count += 1
		max_backward_us = maxi(max_backward_us, roundi((_last_seconds - raw) * 1_000_000.0))
		correction_count += 1
		return _last_seconds
	_last_seconds = raw
	return raw
