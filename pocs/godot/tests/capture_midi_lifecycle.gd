extends SceneTree

const MidiAdapter := preload("res://infrastructure/godot_midi_adapter.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")

var _output: FileAccess
var _adapter: Node
var _lifecycle_index: int = 0
var _started_us: int = 0
var _event_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var duration_seconds: float = float(_read(arguments, "--duration-seconds"))
	var output_path: String = _read(arguments, "--output")
	var profile_path: String = _read(arguments, "--profile")
	_output = FileAccess.open(output_path, FileAccess.WRITE)
	if _output == null:
		quit(1)
		return
	_started_us = Time.get_ticks_usec()
	_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"session","duration_seconds":duration_seconds,"arrival_clock_domain":"godot_time_ticks","os_receive_timestamp_available":false}))
	_adapter = MidiAdapter.new()
	_adapter.profile = Normalizer.load_profile(profile_path)
	_adapter.record_received.connect(_on_record)
	root.add_child(_adapter)
	while Time.get_ticks_usec() - _started_us <= roundi(duration_seconds * 1_000_000.0):
		_flush_lifecycle()
		await create_timer(0.05).timeout
	_flush_lifecycle()
	_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"summary","event_count":_event_count}))
	_output.close()
	_adapter.queue_free()
	quit(0)

func _on_record(raw: Dictionary, normalized: Dictionary) -> void:
	_event_count += 1
	_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"event","elapsed_us":Time.get_ticks_usec()-_started_us,"raw":raw,"normalized":normalized}))
	_output.flush()

func _flush_lifecycle() -> void:
	while _lifecycle_index < _adapter.lifecycle_diagnostics.size():
		var diagnostic: Dictionary = _adapter.lifecycle_diagnostics[_lifecycle_index]
		_output.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"lifecycle","elapsed_us":Time.get_ticks_usec()-_started_us,"diagnostic":diagnostic}))
		_lifecycle_index += 1
		_output.flush()

func _read(arguments: PackedStringArray, option: String) -> String:
	var index: int = arguments.find(option)
	if index < 0 or index + 1 >= arguments.size():
		return ""
	return arguments[index + 1]
