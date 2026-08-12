class_name GodotMidiPortBackend
extends RefCounted

func connected_ports() -> PackedStringArray:
	return OS.get_connected_midi_inputs()

func open_inputs() -> bool:
	OS.open_midi_inputs()
	return not OS.get_connected_midi_inputs().is_empty()

func close_inputs() -> void:
	OS.close_midi_inputs()

func monotonic_us() -> int:
	return Time.get_ticks_usec()
