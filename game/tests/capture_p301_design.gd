extends SceneTree

class DesignPreview:
	extends Node2D

	var option_id := "quiet_forge"
	var palette: Dictionary = {}
	var viewport_size := Vector2(1280, 720)

	func configure(value: String, size: Vector2) -> void:
		option_id = value
		viewport_size = size
		palette = _palette_for(value)
		queue_redraw()

	func _draw() -> void:
		var background: Color = palette["background"]
		draw_rect(Rect2(Vector2.ZERO, viewport_size), background)
		for index: int in 12:
			var band := Rect2(0, index * viewport_size.y / 12.0, viewport_size.x, viewport_size.y / 12.0 + 1.0)
			draw_rect(band, background.lerp(palette["depth"], float(index) / 38.0))
		_draw_shell()
		_draw_field()
		_draw_hud()
		_draw_footer()

	func _draw_shell() -> void:
		var surface: Color = palette["surface"]
		var line: Color = palette["line"]
		draw_rect(Rect2(20, 18, viewport_size.x - 40, 68), surface, true)
		draw_line(Vector2(20, 86), Vector2(viewport_size.x - 20, 86), line, 2.0)
		_text("PANBEAT", Vector2(44, 61), 27, palette["text"])
		_text("PLAY", Vector2(234, 59), 17, palette["accent"])
		_text("DEVICE", Vector2(322, 59), 16, palette["muted"])
		_text("SONGS", Vector2(420, 59), 16, palette["muted"])
		_text("CALIBRATION", Vector2(506, 59), 16, palette["muted"])
		_text("RESULTS", Vector2(654, 59), 16, palette["muted"])
		draw_rect(Rect2(viewport_size.x - 252, 36, 204, 34), palette["status_bg"], true)
		draw_circle(Vector2(viewport_size.x - 228, 53), 6.0, palette["success"])
		_text("MIDI READY · MN-10", Vector2(viewport_size.x - 212, 59), 14, palette["text"])
		draw_line(Vector2(226, 75), Vector2(284, 75), palette["accent"], 3.0)

	func _draw_field() -> void:
		var center := Vector2(viewport_size.x * 0.52, 390)
		var outer := 236.0
		for index: int in 9:
			var radius := outer - index * 12.0
			var amount := float(index) / 8.0
			draw_circle(center, radius, palette["metal_outer"].lerp(palette["metal_inner"], amount))
		draw_arc(center, outer, 0.0, TAU, 180, palette["line"], 2.0)
		draw_arc(center, 128.0, 0.0, TAU, 128, Color(palette["accent"], 0.26), 2.0)
		draw_circle(center, 56.0, palette["metal_inner"])
		draw_arc(center, 56.0, 0.0, TAU, 72, palette["line"], 3.0)
		for index: int in 8:
			var angle := -PI * 0.5 + TAU * index / 8.0
			var tone_center := center + Vector2(cos(angle), sin(angle)) * 176.0
			draw_circle(tone_center, 30.0, palette["metal_inner"])
			draw_arc(tone_center, 30.0, 0.0, TAU, 40, palette["line"], 2.0)
			_text(str(index + 1), tone_center + Vector2(-5, 6), 14, palette["muted"])
		# Identical technique fixture in both options: local Tone, converging Ding, expanding Slap.
		var tone_target := center + Vector2(0, -176)
		draw_arc(tone_target, 21.0, 0.0, TAU, 48, palette["tone"], 6.0)
		draw_arc(center, 102.0, 0.0, TAU, 128, palette["ding"], 5.0)
		draw_arc(center, 210.0, 0.0, TAU, 160, palette["slap"], 4.0)
		draw_arc(center, 218.0, 0.0, TAU, 160, Color(palette["slap"], 0.46), 2.0)
		_text("DING · CONVERGE", center + Vector2(-74, 8), 12, palette["ding"])
		_text("TONE", tone_target + Vector2(-20, -31), 12, palette["tone"])
		_text("SLAP · EXPAND", center + Vector2(-59, 230), 12, palette["slap"])

	func _draw_hud() -> void:
		var x := viewport_size.x - 294.0
		draw_rect(Rect2(x, 112, 266, 416), palette["surface"], true)
		draw_line(Vector2(x, 112), Vector2(x, 528), palette["line"], 2.0)
		_text("ORBIT PRACTICE", Vector2(x + 24, 148), 15, palette["muted"])
		_text("45,000", Vector2(x + 22, 214), 42, palette["text"])
		_text("SCORE", Vector2(x + 24, 238), 13, palette["muted"])
		_text("27", Vector2(x + 22, 306), 52, palette["accent"])
		_text("COMBO", Vector2(x + 96, 298), 14, palette["muted"])
		draw_rect(Rect2(x + 22, 336, 220, 7), palette["depth"], true)
		draw_rect(Rect2(x + 22, 336, 154, 7), palette["accent"], true)
		_text("PERFECT", Vector2(x + 22, 396), 24, palette["success"])
		_text("−12 ms · EARLY", Vector2(x + 22, 423), 14, palette["muted"])
		draw_rect(Rect2(x + 22, 456, 220, 44), palette["focus_bg"], true)
		draw_rect(Rect2(x + 22, 456, 220, 44), palette["focus"], false, 3.0)
		_text("PAUSE  [SPACE]", Vector2(x + 47, 485), 15, palette["text"])

	func _draw_footer() -> void:
		var panel_y := viewport_size.y - 148.0
		draw_rect(Rect2(20, panel_y, viewport_size.x - 40, 112), palette["surface"], true)
		_text("TECHNIQUE", Vector2(44, panel_y + 31), 13, palette["muted"])
		_text("○ TONE  ·  ◎ DING INWARD  ·  ◉ SLAP OUTWARD", Vector2(44, panel_y + 62), 16, palette["text"])
		_text("COUNT-IN −1.000 s  ·  SONG 10.000 s  ·  SAME CHART / PROFILE / HUD DATA", Vector2(44, panel_y + 90), 13, palette["muted"])
		var name := "OPTION A · QUIET FORGE" if option_id == "quiet_forge" else "OPTION B · POLAR RESONANCE"
		_text(name, Vector2(viewport_size.x - 310, panel_y + 90), 13, palette["accent"])

	func _text(value: String, position: Vector2, size: int, color: Color) -> void:
		draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func _palette_for(value: String) -> Dictionary:
		if value == "polar_resonance":
			return {"background":Color("080d18"), "depth":Color("151d35"), "surface":Color("111a2b"), "status_bg":Color("132d33"), "focus_bg":Color("192540"), "metal_outer":Color("263445"), "metal_inner":Color("101a28"), "line":Color("66778f"), "text":Color("f3f7ff"), "muted":Color("9eabc0"), "accent":Color("6de7f2"), "focus":Color("b49cff"), "success":Color("79efbd"), "tone":Color("f4f8ff"), "ding":Color("6de7f2"), "slap":Color("b49cff")}
		return {"background":Color("0b0e16"), "depth":Color("211a1b"), "surface":Color("171b24"), "status_bg":Color("1a2c27"), "focus_bg":Color("28231d"), "metal_outer":Color("34383f"), "metal_inner":Color("171b22"), "line":Color("777a82"), "text":Color("f4f1e8"), "muted":Color("aaa79f"), "accent":Color("e4b45f"), "focus":Color("ffe29b"), "success":Color("8ed3a7"), "tone":Color("f4f1e8"), "ding":Color("e4b45f"), "slap":Color("d68c6c")}

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args()
	var output_index := arguments.find("--output")
	var option_index := arguments.find("--option")
	if output_index < 0 or output_index + 1 >= arguments.size() or option_index < 0 or option_index + 1 >= arguments.size():
		push_error("capture_p301_design requires --option quiet_forge|polar_resonance --output PATH")
		quit(64)
		return
	var option: String = arguments[option_index + 1]
	if option not in ["quiet_forge", "polar_resonance"]:
		quit(64)
		return
	root.size = Vector2i(1280, 720)
	var preview := DesignPreview.new()
	preview.configure(option, Vector2(root.size))
	root.add_child(preview)
	for _frame: int in 3:
		await process_frame
	var error := root.get_texture().get_image().save_png(arguments[output_index + 1])
	quit(0 if error == OK else 1)
