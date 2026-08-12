class_name GodotMidiAdapter
extends Node

signal record_received(raw: Dictionary, normalized: Dictionary)

const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const PortBackend := preload("res://infrastructure/godot_midi_port_backend.gd")
const PortService := preload("res://application/midi_port_service.gd")
var profile: Dictionary = {}
var lifecycle_diagnostics: Array[Dictionary] = []
var diagnostic_mode: bool = false
var preferred_port: String = ""
var _raw_queue: Array[Dictionary] = []
var _port_service: RefCounted

func _ready() -> void:
	_port_service = PortService.new(PortBackend.new(), preferred_port)
	_record_lifecycle(_port_service.open())

func _exit_tree() -> void:
	if _port_service != null:
		_record_lifecycle(_port_service.close())

func _process(_delta: float) -> void:
	var lifecycle: Dictionary = _port_service.refresh()
	if lifecycle.get("changed", false):
		_record_lifecycle(lifecycle)
	process_queued_events(Time.get_ticks_usec(), Engine.get_process_frames())

func _input(event: InputEvent) -> void:
	if event is not InputEventMIDI:
		return
	var accepted_us: int = Time.get_ticks_usec()
	var raw: Dictionary = event_to_record(event as InputEventMIDI, accepted_us, Engine.get_process_frames())
	raw["queue_enqueued_timestamp_us"] = Time.get_ticks_usec()
	_raw_queue.append(raw)

func process_queued_events(processed_us: int, processed_frame: int) -> void:
	var queued: Array[Dictionary] = _raw_queue
	_raw_queue = []
	for raw: Dictionary in queued:
		raw["queue_processed_timestamp_us"] = processed_us
		raw["queue_processed_frame"] = processed_frame
		record_received.emit(raw, Normalizer.normalize(raw, profile))

func queued_event_count() -> int:
	return _raw_queue.size()

func diagnostic_enqueue_raw(raw: Dictionary, enqueued_us: int, frame: int) -> bool:
	if not diagnostic_mode:
		return false
	var queued: Dictionary = raw.duplicate(true)
	queued["accepted_frame"] = frame
	queued["queue_enqueued_timestamp_us"] = enqueued_us
	_raw_queue.append(queued)
	return true

static func event_to_record(event: InputEventMIDI, arrival_us: int, frame: int) -> Dictionary:
	var message_type: String = _message_type(event.message)
	if message_type == "note_on" and event.velocity == 0:
		message_type = "note_off"
	return {
		"schema_version":"1.0.0", "arrival_timestamp_us":arrival_us,
		"arrival_clock_domain":"godot_time_ticks", "os_receive_timestamp_available":false,
		"accepted_frame":frame, "message_type":message_type, "channel_wire":event.channel,
		"source_kind":"physical_midi",
		"data1":_data1(event), "data2":_data2(event),
		"godot_message":event.message, "pitch":event.pitch, "velocity":event.velocity,
		"pressure":event.pressure, "controller_number":event.controller_number,
		"controller_value":event.controller_value
	}

static func _message_type(message: int) -> String:
	match message:
		MIDI_MESSAGE_NOTE_ON: return "note_on"
		MIDI_MESSAGE_NOTE_OFF: return "note_off"
		MIDI_MESSAGE_AFTERTOUCH: return "poly_pressure"
		MIDI_MESSAGE_CONTROL_CHANGE: return "control_change"
		MIDI_MESSAGE_CHANNEL_PRESSURE: return "channel_pressure"
		_: return "unknown"

static func _data1(event: InputEventMIDI) -> int:
	if event.message == MIDI_MESSAGE_CONTROL_CHANGE:
		return event.controller_number
	return event.pitch

static func _data2(event: InputEventMIDI) -> int:
	if event.message == MIDI_MESSAGE_CONTROL_CHANGE:
		return event.controller_value
	if event.message == MIDI_MESSAGE_AFTERTOUCH or event.message == MIDI_MESSAGE_CHANNEL_PRESSURE:
		return event.pressure
	return event.velocity

func _record_lifecycle(record: Dictionary) -> void:
	lifecycle_diagnostics.append(record.duplicate(true))
