extends SceneTree

const Accessibility := preload("res://presentation/accessibility_presenter.gd")
const Tokens := preload("res://presentation/ui_tokens.gd")
const View := preload("res://presentation/radial_view.gd")
const Hud := preload("res://presentation/gameplay_hud.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var defaults := {"glow_enabled":true,"monochrome":false,"high_contrast":false}
	var standard := Accessibility.resolve(defaults, PackedStringArray())
	_check(standard["glow_enabled"] and not standard["monochrome"], "default accessibility settings preserve luminous effects", failures)
	var glow_off := Accessibility.resolve(defaults, PackedStringArray(["--disable-glow"]))
	_check(not glow_off["glow_enabled"], "glow-off CLI fallback resolves", failures)
	var alternate := Accessibility.resolve(defaults, PackedStringArray(["--monochrome","--high-contrast"]))
	_check(alternate["monochrome"] and alternate["high_contrast"], "monochrome and high contrast resolve independently", failures)
	_check(is_equal_approx(Accessibility.contrast_ratio(Color.WHITE, Color.BLACK), 21.0), "black white contrast is 21 to 1", failures)
	_check(is_equal_approx(Accessibility.contrast_ratio(Color.BLACK, Color.WHITE), 21.0), "contrast calculation is order independent", failures)
	var matrix := Accessibility.contrast_matrix(Tokens.COLOR)
	_check(matrix["body_text_on_background"] >= 4.5, "body text contrast meets WCAG AA", failures)
	_check(matrix["muted_text_on_background"] >= 4.5, "muted text contrast meets WCAG AA", failures)
	_check(matrix["focus_on_background"] >= 3.0, "focus indicator contrast meets non-text threshold", failures)
	_check(matrix["error_on_surface"] >= 4.5 and matrix["success_on_surface"] >= 4.5, "important statuses meet text threshold", failures)
	var keyboard := Accessibility.keyboard_contract()
	_check(keyboard["required_actions"] == ["primary","back","retry","cancel"] and keyboard["failure_retry"] == "R", "keyboard contract covers required operations", failures)
	var geometry_720 := View.geometry_for_size(Vector2(1280,720)); var geometry_1610 := View.geometry_for_size(Vector2(1280,800)); var geometry_ultra := View.geometry_for_size(Vector2(1920,720))
	_check(geometry_720["short_side"] == 720.0 and geometry_1610["short_side"] == 800.0 and geometry_ultra["short_side"] == 720.0, "three aspect ratios use short side", failures)
	_check(geometry_720["outer_radius"] == geometry_ultra["outer_radius"], "ultrawide field remains circular", failures)
	for size: Vector2 in [Vector2(1280,720),Vector2(1280,800),Vector2(1920,720)]:
		var layout := Hud.layout_for_size(size)
		_check(not layout["left"].intersects(layout["field_safe_rect"]) and not layout["right"].intersects(layout["field_safe_rect"]), "HUD clears field at %s" % size, failures)
	var contract := View.accessibility_contract()
	_check(not contract["full_screen_flash"] and not contract["constant_camera_shake"], "prohibited global effects absent", failures)
	_check(contract["technique_uses_shape_and_direction"] and contract["grade_uses_shape_strength_and_text"], "technique and grade do not rely on color", failures)
	_check(View.layer_contract()["per_frame_node_creation"] == 0 and View.layer_contract()["per_frame_resource_creation"] == 0, "draw contract allocates no nodes or resources per frame", failures)
	_finish(failures, 18)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P309_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
