extends SceneTree

const Tokens := preload("res://presentation/ui_tokens.gd")
const AppTheme := preload("res://presentation/panbeat_theme.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var theme := AppTheme.shared()
	_check(Tokens.VERSION == "phase3-quiet-forge-v3", "approved visual-quality token version", failures)
	_check(Tokens.color("accent") == Color("e4b45f") and Tokens.color("focus") == Color("ffe29b"), "Quiet Forge accent and focus", failures)
	_check(Tokens.spacing("page") == 48 and Tokens.FONT_SIZE["body"] == 19, "spacing and typography tokens", failures)
	_check(Tokens.color("tone_luminous") == Color("2fd4ff") and Tokens.color("ding_luminous") == Color("ffc45f") and Tokens.color("slap_luminous") == Color("ff806f") and Tokens.MOTION_MS["hit"] == 180, "saturated cyan technique and motion tokens", failures)
	for type: String in ["Button", "OptionButton"]:
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			_check(theme.has_stylebox(state, type), "%s %s style" % [type, state], failures)
	for state: String in ["normal", "focus", "read_only"]:
		_check(theme.has_stylebox(state, "LineEdit"), "LineEdit %s style" % state, failures)
	for state: String in ["panel", "focus", "cursor", "cursor_unfocused"]:
		_check(theme.has_stylebox(state, "ItemList"), "ItemList %s style" % state, failures)
	for kind: String in ["Success", "Warning", "Error", "Info"]:
		_check(theme.has_stylebox("panel", "%sPanel" % kind), "%s status shape" % kind, failures)
	_check(AppTheme.status_text("success", "Ready").begins_with("✓") and AppTheme.status_text("error", "Failed").begins_with("!"), "status text is not color-only", failures)
	_check(theme.default_font != null and theme.default_font_size == 19, "fallback font is explicit", failures)
	_check(theme.has_stylebox("panel", "Panel") and theme.has_stylebox("panel", "PanelContainer"), "panel and dialog foundation", failures)
	_finish(failures, 28)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P303_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
