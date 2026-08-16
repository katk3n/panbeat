class_name PanBeatTheme
extends RefCounted

const Tokens := preload("res://presentation/ui_tokens.gd")

static var _shared: Theme

static func shared() -> Theme:
	if _shared == null:
		_shared = _build()
	return _shared

static func status_text(kind: String, message: String) -> String:
	match kind:
		"success": return "✓ %s" % message
		"warning": return "△ %s" % message
		"error": return "! %s" % message
		_: return "• %s" % message

static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = Tokens.FONT_SIZE["body"]
	_set_text_colors(theme, "Label")
	_set_text_colors(theme, "RichTextLabel")
	_build_button(theme, "Button")
	_build_button(theme, "OptionButton")
	_build_line_edit(theme)
	_build_item_list(theme)
	_build_tree(theme)
	_build_window(theme)
	_build_panels(theme)
	_build_controls(theme)
	_build_preview_variations(theme)
	_build_product_variations(theme)
	return theme

static func _set_text_colors(theme: Theme, type: String) -> void:
	theme.set_color("font_color", type, Tokens.color("primary"))
	theme.set_color("font_shadow_color", type, Color(0, 0, 0, 0.35))
	theme.set_constant("shadow_offset_x", type, 1)
	theme.set_constant("shadow_offset_y", type, 1)

static func _build_button(theme: Theme, type: String) -> void:
	var normal := _box(Tokens.color("surface_raised"), Color(Tokens.color("accent_blue"), 0.58), Tokens.CORNER["control"], 1, 16, 11)
	var hover := _box(Tokens.color("surface_raised").lightened(0.08), Tokens.color("accent"), Tokens.CORNER["control"], 2, 12, 8)
	var pressed := _box(Color(Tokens.color("accent_magenta"), 0.22), Tokens.color("focus"), Tokens.CORNER["control"], 2, 12, 8)
	var disabled := _box(Tokens.color("surface"), Tokens.color("disabled"), Tokens.CORNER["control"], 1, 12, 8)
	var focus := _box(Color(0, 0, 0, 0), Tokens.color("focus"), Tokens.CORNER["control"], Tokens.STROKE["focus"], 10, 6)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, type, {"normal":normal,"hover":hover,"pressed":pressed,"disabled":disabled,"focus":focus}[state])
	theme.set_color("font_color", type, Tokens.color("primary"))
	theme.set_color("font_hover_color", type, Tokens.color("primary"))
	theme.set_color("font_pressed_color", type, Tokens.color("primary"))
	theme.set_color("font_focus_color", type, Tokens.color("primary"))
	theme.set_color("font_disabled_color", type, Tokens.color("disabled"))
	theme.set_font_size("font_size", type, Tokens.FONT_SIZE["body"])

static func _build_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", _box(Tokens.color("surface"), Tokens.color("line"), Tokens.CORNER["control"], 1, 10, 8))
	theme.set_stylebox("focus", "LineEdit", _box(Tokens.color("surface"), Tokens.color("focus"), Tokens.CORNER["control"], Tokens.STROKE["focus"], 10, 8))
	theme.set_stylebox("read_only", "LineEdit", _box(Tokens.color("surface").darkened(0.08), Tokens.color("disabled"), Tokens.CORNER["control"], 1, 10, 8))
	theme.set_color("font_color", "LineEdit", Tokens.color("primary"))
	theme.set_color("font_uneditable_color", "LineEdit", Tokens.color("muted"))
	theme.set_color("caret_color", "LineEdit", Tokens.color("accent"))
	theme.set_color("selection_color", "LineEdit", Color(Tokens.color("accent"), 0.35))

static func _build_item_list(theme: Theme) -> void:
	theme.set_stylebox("panel", "ItemList", _box(Color(Tokens.color("surface"), 0.88), Color(Tokens.color("accent"), 0.36), Tokens.CORNER["panel"], 1, 12, 12))
	theme.set_stylebox("focus", "ItemList", _box(Color(0,0,0,0), Tokens.color("focus"), Tokens.CORNER["panel"], Tokens.STROKE["focus"], 6, 6))
	theme.set_stylebox("cursor", "ItemList", _box(Color(Tokens.color("accent"), 0.24), Tokens.color("accent"), Tokens.CORNER["control"], 2, 6, 4))
	theme.set_stylebox("cursor_unfocused", "ItemList", _box(Color(Tokens.color("muted"), 0.12), Tokens.color("muted"), Tokens.CORNER["control"], 1, 6, 4))
	theme.set_color("font_color", "ItemList", Tokens.color("primary"))
	theme.set_color("font_selected_color", "ItemList", Tokens.color("primary"))
	theme.set_color("font_hovered_color", "ItemList", Tokens.color("primary"))

static func _build_tree(theme: Theme) -> void:
	# Keep Godot's established Tree geometry; only recolor its text and guides.
	theme.set_color("font_color", "Tree", Tokens.color("primary"))
	theme.set_color("font_selected_color", "Tree", Tokens.color("primary"))
	theme.set_color("title_button_color", "Tree", Tokens.color("accent"))
	theme.set_color("relationship_line_color", "Tree", Color(Tokens.color("accent_blue"), 0.42))

static func _build_window(theme: Theme) -> void:
	var defaults := ThemeDB.get_default_theme()
	var focused := defaults.get_stylebox("embedded_border", "Window").duplicate()
	var unfocused := defaults.get_stylebox("embedded_unfocused_border", "Window").duplicate()
	_recolor_window_box(focused, Tokens.color("surface_raised"), Tokens.color("accent_blue"))
	_recolor_window_box(unfocused, Tokens.color("surface"), Tokens.color("line"))
	theme.set_stylebox("embedded_border", "Window", focused)
	theme.set_stylebox("embedded_unfocused_border", "Window", unfocused)
	theme.set_color("title_color", "Window", Tokens.color("primary"))
	theme.set_color("title_outline_modulate", "Window", Color(Tokens.color("background"), 0.84))

static func _recolor_window_box(box: StyleBox, background: Color, border: Color) -> void:
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		flat.bg_color = background
		flat.border_color = border
		flat.shadow_color = Color(0, 0, 0, 0.58)

static func _build_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", _box(Color(Tokens.color("surface"), 0.86), Color(Tokens.color("accent"), 0.34), Tokens.CORNER["panel"], 1, 20, 20))
	theme.set_stylebox("panel", "PanelContainer", _box(Color(Tokens.color("surface"), 0.88), Color(Tokens.color("accent"), 0.40), Tokens.CORNER["panel"], 1, 20, 15))
	for kind: String in ["Success", "Warning", "Error", "Info"]:
		var lower := kind.to_lower()
		var color_name := lower if lower in ["success", "warning", "error"] else "accent"
		theme.set_type_variation("%sPanel" % kind, "PanelContainer")
		theme.set_stylebox("panel", "%sPanel" % kind, _box(Color(Tokens.color(color_name), 0.11), Tokens.color(color_name), Tokens.CORNER["status"], 2, 14, 9))

static func _build_controls(theme: Theme) -> void:
	theme.set_stylebox("background", "SpinBox", _box(Tokens.color("surface"), Tokens.color("line"), Tokens.CORNER["control"], 1, 8, 6))
	theme.set_stylebox("background", "ProgressBar", _box(Tokens.color("background_depth"), Tokens.color("line"), Tokens.CORNER["control"], 1, 4, 4))
	theme.set_stylebox("fill", "ProgressBar", _box(Tokens.color("accent"), Tokens.color("accent"), Tokens.CORNER["control"], 0, 4, 4))
	theme.set_color("font_color", "ProgressBar", Tokens.color("primary"))
	theme.set_color("font_outline_color", "ProgressBar", Tokens.color("background"))

static func _build_preview_variations(theme: Theme) -> void:
	for entry: Dictionary in [{"name":"PreviewHoverButton","state":"hover"},{"name":"PreviewPressedButton","state":"pressed"},{"name":"PreviewDisabledButton","state":"disabled"}]:
		theme.set_type_variation(entry["name"], "Button")
		theme.set_stylebox("normal", entry["name"], theme.get_stylebox(entry["state"], "Button"))

static func _build_product_variations(theme: Theme) -> void:
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _box(Tokens.color("accent").darkened(0.38), Tokens.color("accent"), Tokens.CORNER["control"], 2, 18, 11))
	theme.set_stylebox("hover", "PrimaryButton", _box(Tokens.color("accent").darkened(0.26), Tokens.color("focus"), Tokens.CORNER["control"], 2, 18, 11))
	theme.set_stylebox("pressed", "PrimaryButton", _box(Tokens.color("accent").darkened(0.52), Tokens.color("focus"), Tokens.CORNER["control"], 3, 18, 11))
	theme.set_stylebox("disabled", "PrimaryButton", theme.get_stylebox("disabled", "Button"))
	theme.set_stylebox("focus", "PrimaryButton", theme.get_stylebox("focus", "Button"))
	theme.set_font_size("font_size", "PrimaryButton", Tokens.FONT_SIZE["label"])

static func _box(background: Color, border: Color, radius: int, border_width: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	box.anti_aliasing = true
	if background.a > 0.2:
		box.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0, 4)
	return box
