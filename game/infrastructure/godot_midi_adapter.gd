class_name GodotMidiAdapter
extends Node

signal record_received(raw: Dictionary, normalized: Dictionary)

const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
var profile: Dictionary = {}
var lifecycle_diagnostics: Array[Dictionary] = []
var _last_ports: PackedStringArray = []

func _ready() -> void:
	OS.open_midi_inputs()
	_last_ports = OS.get_connected_midi_inputs()
	_record_lifecycle("startup")

func _exit_tree() -> void:
	OS.close_midi_inputs()

func _process(_delta: float) -> void:
	var ports: PackedStringArray = OS.get_connected_midi_inputs()
	if ports != _last_ports:
		OS.close_midi_inputs()
		OS.open_midi_inputs()
		ports = OS.get_connected_midi_inputs()
		_last_ports = ports
		_record_lifecycle("ports_changed")

func _input(event: InputEvent) -> void:
	if event is not InputEventMIDI:
		return
	var raw: Dictionary = event_to_record(event as InputEventMIDI, Time.get_ticks_usec(), Engine.get_process_frames())
	record_received.emit(raw, Normalizer.normalize(raw, profile))

static func event_to_record(event: InputEventMIDI, arrival_us: int, frame: int) -> Dictionary:
	var message_type: String = _message_type(event.message)
	if message_type == "note_on" and event.velocity == 0:
		message_type = "note_off"
	return {
		"schema_version":"1.0.0", "arrival_timestamp_us":arrival_us,
		"arrival_clock_domain":"godot_time_ticks", "os_receive_timestamp_available":false,
		"process_frame":frame, "message_type":message_type, "channel_wire":event.channel,
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

func _record_lifecycle(reason: String) -> void:
	lifecycle_diagnostics.append({"arrival_timestamp_us":Time.get_ticks_usec(), "reason":reason, "ports":Array(_last_ports)})
