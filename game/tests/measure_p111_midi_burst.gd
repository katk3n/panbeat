extends SceneTree

const Adapter := preload("res://infrastructure/godot_midi_adapter.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const RecordedReplay := preload("res://infrastructure/recorded_midi_replay.gd")

var _observed: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var output_path: String = _read(arguments, "--output")
	var profile: Dictionary = Normalizer.load_profile(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))
	var trace_path: String = ProjectSettings.globalize_path("res://../artifacts/raw/m02-mood-pan-20260810/gamelan-minor-simultaneous-pad2-pad3-then-pad1-rapid10.jsonl")
	var loaded: Dictionary = RecordedReplay.load_jsonl(trace_path)
	if not loaded.get("ok", false):
		push_error(loaded.get("error", "trace load failed")); quit(1); return
	var adapter := Adapter.new()
	adapter.profile = profile
	adapter.diagnostic_mode = true
	adapter.record_received.connect(_on_record)
	for repetition: int in 50:
		for raw_value: Variant in loaded["events"]:
			var raw: Dictionary = raw_value as Dictionary
			adapter.diagnostic_enqueue_raw(raw, Time.get_ticks_usec(), Engine.get_process_frames())
		await process_frame
		adapter.process_queued_events(Time.get_ticks_usec(), Engine.get_process_frames())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot open MIDI measurement output"); quit(1); return
	file.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"session","source_fixture":"artifacts/raw/m02-mood-pan-20260810/gamelan-minor-simultaneous-pad2-pad3-then-pad1-rapid10.jsonl","repetitions":50,"os_receive_timestamp_available":false,"latency_scope":"Godot _input acceptance-equivalent enqueue to Gameplay queue processing"}))
	for index: int in _observed.size():
		var record: Dictionary = _observed[index]
		file.store_line(JSON.stringify({"schema_version":"1.0.0","record_type":"dispatch","sequence":index,"accepted_frame":record["accepted_frame"],"processed_frame":record["queue_processed_frame"],"accepted_to_processed_us":int(record["queue_processed_timestamp_us"])-int(record["queue_enqueued_timestamp_us"]),"kind":record["normalized_kind"],"code":record["normalized_code"]}))
	file.close()
	print("PANBEAT_P111_MIDI_BURST_OK %d" % _observed.size())
	quit(0)

func _on_record(raw: Dictionary, normalized: Dictionary) -> void:
	_observed.append({"accepted_frame":raw["accepted_frame"],"queue_processed_frame":raw["queue_processed_frame"],"queue_enqueued_timestamp_us":raw["queue_enqueued_timestamp_us"],"queue_processed_timestamp_us":raw["queue_processed_timestamp_us"],"normalized_kind":normalized.get("kind"),"normalized_code":normalized.get("code")})

func _read(arguments: PackedStringArray, option: String) -> String:
	var index: int = arguments.find(option)
	return arguments[index + 1] if index >= 0 and index + 1 < arguments.size() else ""
