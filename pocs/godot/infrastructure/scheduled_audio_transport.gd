class_name ScheduledAudioTransport
extends RefCounted

const GameTransportContract := preload("res://domain/game_transport.gd")
const AudioClock := preload("res://infrastructure/godot_audio_clock.gd")
const DEFAULT_START_LEAD_SECONDS: float = 0.1

var player: AudioStreamPlayer
var clock: GodotAudioClock
var transport: GameTransport

func _init(audio_player: AudioStreamPlayer) -> void:
	player = audio_player
	clock = AudioClock.new(player)
	transport = GameTransportContract.new(clock)

func start(start_lead_seconds: float = DEFAULT_START_LEAD_SECONDS) -> void:
	if start_lead_seconds < 0.0:
		push_error("start lead must not be negative")
		return
	var scheduled_clock_seconds: float = clock.time_seconds() + start_lead_seconds
	transport.start(scheduled_clock_seconds)
	await player.get_tree().create_timer(start_lead_seconds).timeout
	player.play()

func pause() -> void:
	transport.pause()
	player.stream_paused = true

func resume() -> void:
	player.stream_paused = false
	transport.resume()
