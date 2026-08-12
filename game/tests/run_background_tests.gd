extends SceneTree

const Presets := preload("res://application/background_preset_catalog.gd")
const View := preload("res://presentation/radial_view.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var presets := Presets.all()
	_check(presets.size() == 3, "three presets are exposed", failures)
	_check(presets.map(func(value: Dictionary) -> String: return value["id"]) == ["silent_resonance", "breath_of_dawn", "deep_resonance"], "preset IDs are stable", failures)
	_check(Presets.DEFAULT_ID == "deep_resonance" and Presets.shader_index("deep_resonance") == 2, "Deep Resonance is the safe default", failures)
	_check(Presets.resolve({}, {}) == "deep_resonance", "missing settings use the default", failures)
	_check(Presets.resolve({}, {"background_preset_id":"silent_resonance"}) == "silent_resonance", "global selection resolves", failures)
	var settings := {"background_preset_id":"silent_resonance", "song_background_presets":{"song-a":"breath_of_dawn"}}
	_check(Presets.resolve({"song_id":"song-a"}, settings) == "breath_of_dawn", "per-song selection overrides global selection", failures)
	_check(Presets.resolve({"song_id":"song-a", "background_preset_id":"deep_resonance"}, settings) == "breath_of_dawn", "saved per-song selection overrides package default", failures)
	_check(Presets.resolve({"song_id":"song-a", "background_preset_id":"deep_resonance"}, settings, "silent_resonance") == "silent_resonance", "CLI preview override has highest precedence", failures)
	var assigned := Presets.assign_to_song(settings, "song-b", "deep_resonance")
	_check(assigned["song_background_presets"]["song-b"] == "deep_resonance" and not settings["song_background_presets"].has("song-b"), "per-song assignment is immutable", failures)
	var shader_source := FileAccess.get_file_as_string("res://presentation/radial_field.gdshader")
	_check(shader_source.contains("silent_resonance") and shader_source.contains("breath_of_dawn") and shader_source.contains("deep_resonance"), "shader implements all three patterns", failures)
	_check(not shader_source.contains("grid_uv") and shader_source.contains("pulse_phase") and not shader_source.contains("TIME"), "background has no cyber grid and uses audio time", failures)
	_check(not shader_source.contains("amber * rim") and not shader_source.contains("amber * halo"), "static outer gold ring is absent from the shader", failures)
	var view := View.new(); view.set_background_preset("breath_of_dawn")
	_check(view.background_preset_id == "breath_of_dawn", "view accepts a valid selection", failures)
	view.set_background_preset("unknown")
	_check(view.background_preset_id == Presets.DEFAULT_ID, "view rejects an unknown selection", failures)
	view.free()
	_finish(failures, 14)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_BACKGROUND_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
