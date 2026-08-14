class_name PracticePitchPreserver
extends RefCounted

const FFT_SIZE_SAMPLES := 1024
const OVERSAMPLING := 4
const BUS_PREFIX := "PanBeatPractice"

var _bus_name: StringName = &""
var _active := false

func configure(player: AudioStreamPlayer, practice_multiplier: float) -> Dictionary:
	release(player)
	if not is_instance_valid(player): return {"ok":false, "error":"audio player is unavailable"}
	if not is_finite(practice_multiplier) or practice_multiplier <= 0.0: return {"ok":false, "error":"practice tempo multiplier must be positive"}
	if is_equal_approx(practice_multiplier, 1.0):
		player.bus = &"Master"
		return {"ok":true, "active":false, "pitch_scale":1.0, "estimated_latency_seconds":0.0}
	_bus_name = StringName("%s-%d" % [BUS_PREFIX, get_instance_id()])
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, _bus_name)
	AudioServer.set_bus_send(bus_index, &"Master")
	var effect := AudioEffectPitchShift.new()
	effect.pitch_scale = compensation_scale(practice_multiplier)
	effect.fft_size = AudioEffectPitchShift.FFT_SIZE_1024
	effect.oversampling = OVERSAMPLING
	AudioServer.add_bus_effect(bus_index, effect)
	player.bus = _bus_name
	_active = true
	return {"ok":true, "active":true, "bus_name":str(_bus_name), "pitch_scale":effect.pitch_scale, "estimated_latency_seconds":estimated_latency_seconds()}

func release(player: AudioStreamPlayer = null) -> void:
	if is_instance_valid(player) and player.bus == _bus_name: player.bus = &"Master"
	if not _bus_name.is_empty():
		var bus_index := AudioServer.get_bus_index(_bus_name)
		if bus_index >= 0: AudioServer.remove_bus(bus_index)
	_bus_name = &""
	_active = false

func estimated_latency_seconds() -> float:
	var mix_rate := AudioServer.get_mix_rate()
	return float(FFT_SIZE_SAMPLES) / mix_rate if _active and mix_rate > 0.0 else 0.0

static func compensation_scale(practice_multiplier: float) -> float:
	return 1.0 / practice_multiplier
