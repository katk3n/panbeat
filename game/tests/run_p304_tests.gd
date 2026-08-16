extends SceneTree

const View := preload("res://presentation/product_flow_view.gd")
const RichBackground := preload("res://presentation/rich_ui_background.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_check(View.navigation_label("song library", false) == "SONG LIBRARY", "unselected navigation text", failures)
	_check(View.navigation_label("song library", true) == "● SONG LIBRARY", "current navigation has persistent marker", failures)
	_check(View.midi_status_text(PackedStringArray(["MN-10"])) == "✓ MIDI READY · MN-10", "MIDI ready status", failures)
	_check(View.midi_status_text(PackedStringArray()).begins_with("△ MIDI NO PORTS"), "no-port status", failures)
	_check(View.midi_status_text(PackedStringArray(), true).contains("REOPEN REQUIRED"), "reopen-required status", failures)
	_check(not View.midi_status_text(PackedStringArray()).contains("DISCONNECTED"), "silence is not called disconnect", failures)
	_check(View.midi_status_detail(PackedStringArray()).contains("relaunch PanBeat"), "no-port recovery detail", failures)
	var error := View.error_presentation({"severity":"error","user_message":"Audio output unavailable.","technical_detail":"External DAC disappeared.","actions":["retry","cancel"]})
	_check(error["summary"].begins_with("!") and error["summary"].contains("retry"), "recoverable summary and action", failures)
	_check(error["technical"].contains("External DAC") and error["actions"] == ["retry","cancel"], "technical detail remains available", failures)
	var fallback := View.error_presentation({})
	_check(fallback["summary"].contains("Operation failed") and fallback["technical"].contains("Unavailable"), "error fallback", failures)
	var background := RichBackground.visual_contract()
	_check(background["procedural_shader"] and background["meditative_fog"] and background["breathing_halo"] and background["resonance_ripples"] and background["visible_slow_motion"] and is_equal_approx(background["motion_speed"], 0.38) and background["motion_strength"] == "dramatic", "shared menu background uses clearly animated meditative visual language", failures)
	_check(background["palette"] == "icon_cyan_blue_magenta" and background["dark_negative_space"], "shared menu background follows the app icon palette", failures)
	_check(not background["perspective_grid"] and not background["particle_field"] and not background["cyber_aesthetic"], "shared menu background omits cyber grid and particles", failures)
	_finish(failures, 12)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P304_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
