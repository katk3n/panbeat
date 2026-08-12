extends SceneTree

const View := preload("res://presentation/radial_view.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var geometry_720 := View.geometry_for_size(Vector2(1280, 720))
	var geometry_wide := View.geometry_for_size(Vector2(1728, 720))
	_check(geometry_720["short_side"] == 720.0 and geometry_wide["short_side"] == 720.0, "short-side geometry", failures)
	_check(geometry_720["outer_radius"] == geometry_wide["outer_radius"], "outer radius is circular", failures)
	_check(geometry_720["spawn_radius"] == 162.0 and geometry_wide["spawn_radius"] == 162.0, "spawn radius contract", failures)
	_check(is_equal_approx(720.0 * View.DING_RADIUS_FACTOR, 61.2), "Ding radius contract", failures)
	var top_720 := View.tone_center_for(geometry_720["center"], geometry_720["outer_radius"], 0.0)
	var top_wide := View.tone_center_for(geometry_wide["center"], geometry_wide["outer_radius"], 0.0)
	_check(is_equal_approx(top_720.y, top_wide.y), "Tone angle/radius stable across aspect", failures)
	_check(is_equal_approx(top_720.x, 640.0) and is_equal_approx(top_wide.x, 864.0), "Tone remains centered", failures)
	var right := View.tone_center_for(geometry_720["center"], geometry_720["outer_radius"], 90.0)
	_check(is_equal_approx(right.x, 946.0) and is_equal_approx(right.y, 360.0), "polar angle convention unchanged", failures)
	var layers := View.layer_contract()
	_check(layers["decoration_independent"] and layers["judgement_independent"], "layers independently switchable", failures)
	_check(layers["notes_always_visible"], "notes independent from optional layers", failures)
	_check(layers["material"] == "translucent_forged_copper" and is_equal_approx(layers["background_transmission"], 0.76) and layers["opaque_accessibility_fallback"], "recognizable translucent copper preserves background with an accessibility fallback", failures)
	_check(layers["per_frame_node_creation"] == 0 and layers["per_frame_resource_creation"] == 0, "no per-frame Node/resource creation", failures)
	var view := View.new(); view.decoration_enabled = false; view.judgement_layer_enabled = true; view.glow_enabled = false; view.monochrome = true
	_check(not view.decoration_enabled and view.judgement_layer_enabled and not view.glow_enabled and view.monochrome, "fallback switches compose", failures)
	view.free()
	_finish(failures, 12)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P305_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
