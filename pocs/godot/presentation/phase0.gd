class_name Phase0View
extends "res://presentation/radial_view.gd"

const InputTechnique := preload("res://domain/input_technique.gd")
const MidiAdapter := preload("res://infrastructure/godot_midi_adapter.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")

var _capture_output: FileAccess
var _capture_adapter: Node
var _capture_started_us: int
var _capture_duration_us: int
var _lifecycle_index: int = 0
var _event_count: int = 0
var _drift_output: FileAccess
var _drift_player: AudioStreamPlayer
var _drift_started_us: int
var _drift_duration_us: int
var _drift_next_sample_us: int
var _drift_previous_position: float = 0.0
var _drift_loop_count: int = 0
var _drift_baseline_delta: float = 0.0
var _drift_sequence: int = 0

func _ready() -> void:
	assert(InputTechnique.count() == 3)
	queue_redraw()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var drift_index: int = arguments.find("--drift-output")
	if drift_index >= 0 and drift_index + 1 < arguments.size():
		_start_drift(arguments, drift_index)
		return
	var output_index: int = arguments.find("--e02-output")
	if output_index >= 0 and output_index + 1 < arguments.size():
		_start_capture(arguments, output_index)

func _start_capture(arguments: PackedStringArray, output_index: int) -> void:
	var duration_index: int = arguments.find("--duration-seconds")
	_capture_duration_us = roundi(float(arguments[duration_index + 1]) * 1_000_000.0)
	_capture_output = FileAccess.open(arguments[output_index + 1], FileAccess.WRITE)
	_capture_started_us = Time.get_ticks_usec()
	_capture_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"session","duration_seconds":float(_capture_duration_us)/1_000_000.0,"build_type":"release","arrival_clock_domain":"godot_time_ticks","os_receive_timestamp_available":false}))
	_capture_adapter = MidiAdapter.new()
	_capture_adapter.profile = Normalizer.load_profile(_profile_path(arguments))
	_capture_adapter.record_received.connect(_on_capture_record)
	add_child(_capture_adapter)

func _process(_delta: float) -> void:
	if _drift_output != null:
		_sample_drift()
		return
	if _capture_output == null:
		return
	_flush_capture_lifecycle()
	if Time.get_ticks_usec() - _capture_started_us >= _capture_duration_us:
		_capture_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"summary","event_count":_event_count}))
		_capture_output.close()
		_capture_output = null
		get_tree().quit(0)

func _on_capture_record(raw: Dictionary, normalized: Dictionary) -> void:
	_event_count += 1
	_capture_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"event","elapsed_us":Time.get_ticks_usec()-_capture_started_us,"raw":raw,"normalized":normalized}))
	_capture_output.flush()

func _flush_capture_lifecycle() -> void:
	while _lifecycle_index < _capture_adapter.lifecycle_diagnostics.size():
		var diagnostic: Dictionary = _capture_adapter.lifecycle_diagnostics[_lifecycle_index]
		_capture_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"lifecycle","elapsed_us":Time.get_ticks_usec()-_capture_started_us,"diagnostic":diagnostic}))
		_lifecycle_index += 1
		_capture_output.flush()

func _profile_path(arguments: PackedStringArray) -> String:
	var index: int = arguments.find("--profile")
	return arguments[index + 1]

func _start_drift(arguments: PackedStringArray, output_index: int) -> void:
	var duration_index: int = arguments.find("--duration-seconds")
	var audio_index: int = arguments.find("--audio")
	_drift_duration_us = roundi(float(arguments[duration_index + 1]) * 1_000_000.0)
	_drift_output = FileAccess.open(arguments[output_index + 1], FileAccess.WRITE)
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(arguments[audio_index + 1])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	_drift_player = AudioStreamPlayer.new()
	_drift_player.stream = stream
	add_child(_drift_player)
	_drift_player.play()
	_drift_started_us = Time.get_ticks_usec()
	_drift_next_sample_us = _drift_started_us + 200_000
	_drift_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"session","engine":"godot","build_type":"release","duration_seconds":float(_drift_duration_us)/1_000_000.0,"clip_sample_rate_hz":stream.mix_rate,"audio_driver":AudioServer.get_driver_name(),"mix_rate_hz":AudioServer.get_mix_rate(),"output_latency_us":roundi(AudioServer.get_output_latency()*1_000_000.0),"clock_domain":"godot_audio_playhead_and_monotonic"}))

func _sample_drift() -> void:
	var now_us: int = Time.get_ticks_usec()
	if now_us < _drift_next_sample_us:
		return
	var raw_position: float = _drift_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	var clip_length: float = _drift_player.stream.get_length()
	if raw_position < _drift_previous_position - clip_length * 0.5:
		_drift_loop_count += 1
	_drift_previous_position = raw_position
	var actual_seconds: float = _drift_loop_count * clip_length + raw_position
	var expected_seconds: float = float(now_us - _drift_started_us) / 1_000_000.0
	var delta: float = actual_seconds - expected_seconds
	if _drift_sequence == 0:
		_drift_baseline_delta = delta
	var drift_us: int = roundi((delta - _drift_baseline_delta) * 1_000_000.0)
	_drift_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"sample","sequence":_drift_sequence,"monotonic_elapsed_us":now_us-_drift_started_us,"audio_unwrapped_us":roundi(actual_seconds*1_000_000.0),"drift_us":drift_us}))
	_drift_sequence += 1
	_drift_next_sample_us += 100_000
	if now_us - _drift_started_us >= _drift_duration_us:
		_drift_player.stop()
		_drift_player.free()
		_drift_output.close()
		_drift_output = null
		get_tree().quit(0)
