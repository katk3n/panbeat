class_name PanBeatMain
extends "res://presentation/radial_view.gd"

const MidiAdapter := preload("res://infrastructure/godot_midi_adapter.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")

var midi_adapter: Node

func _ready() -> void:
	var profile_path: String = ProjectSettings.globalize_path("res://config/default-instrument-profile.json")
	midi_adapter = MidiAdapter.new()
	midi_adapter.profile = Normalizer.load_profile(profile_path)
	add_child(midi_adapter)
	queue_redraw()
