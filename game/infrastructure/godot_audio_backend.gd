class_name GodotAudioBackend
extends RefCounted

var _player: AudioStreamPlayer
var _last_position_seconds: float = 0.0

func _init(player: AudioStreamPlayer) -> void:
	_player = player

func ready() -> bool:
	return is_instance_valid(_player) and _player.stream != null

func monotonic_seconds() -> float:
	return Time.get_ticks_usec() / 1_000_000.0

func play() -> bool:
	if not ready():
		return false
	_last_position_seconds = 0.0
	_player.play()
	return _player.playing

func is_playing() -> bool:
	return ready() and _player.playing

func set_paused(paused: bool) -> void:
	if ready():
		_player.stream_paused = paused

func audio_position_seconds() -> float:
	if not ready():
		return 0.0
	var candidate: float = _player.get_playback_position()
	if _player.playing and not _player.stream_paused:
		candidate += AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	_last_position_seconds = maxf(_last_position_seconds, maxf(0.0, candidate))
	return _last_position_seconds

func sample_rate_hz() -> int:
	return roundi(AudioServer.get_mix_rate())

func output_latency_seconds() -> float:
	return AudioServer.get_output_latency()

func buffer_frames_estimate() -> int:
	return roundi(output_latency_seconds() * sample_rate_hz())
