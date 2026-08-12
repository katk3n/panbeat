class_name GodotMidiPortBackend
extends RefCounted

const LifetimePolicy := preload("res://application/midi_process_lifetime_policy.gd")
static var _lifetime: RefCounted = LifetimePolicy.new()

func connected_ports() -> PackedStringArray:
	return OS.get_connected_midi_inputs()

func open_inputs() -> bool:
	# Godot 4.6 CoreMIDI cannot reopen after OS.close_midi_inputs() in the same
	# process. Keep the process driver alive while views exchange ownership.
	if _lifetime.claim_driver_open():
		OS.open_midi_inputs()
	return not OS.get_connected_midi_inputs().is_empty()

func close_inputs() -> void:
	if _lifetime.close_driver_on_view_exit():
		OS.close_midi_inputs()

func monotonic_us() -> int:
	return Time.get_ticks_usec()
