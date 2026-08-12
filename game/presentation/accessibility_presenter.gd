class_name AccessibilityPresenter
extends RefCounted

static func resolve(defaults: Dictionary, arguments: PackedStringArray) -> Dictionary:
	var result := {
		"glow_enabled":bool(defaults.get("glow_enabled", true)),
		"monochrome":bool(defaults.get("monochrome", false)),
		"high_contrast":bool(defaults.get("high_contrast", false))
	}
	if arguments.has("--disable-glow"): result["glow_enabled"] = false
	if arguments.has("--monochrome"): result["monochrome"] = true
	if arguments.has("--high-contrast"): result["high_contrast"] = true
	return result

static func contrast_ratio(foreground: Color, background: Color) -> float:
	var light := _luminance(foreground)
	var dark := _luminance(background)
	if dark > light:
		var swap := light; light = dark; dark = swap
	return (light + 0.05) / (dark + 0.05)

static func contrast_matrix(colors: Dictionary) -> Dictionary:
	return {
		"body_text_on_background":contrast_ratio(colors["primary"], colors["background"]),
		"muted_text_on_background":contrast_ratio(colors["muted"], colors["background"]),
		"focus_on_background":contrast_ratio(colors["focus"], colors["background"]),
		"error_on_surface":contrast_ratio(colors["error"], colors["surface"]),
		"success_on_surface":contrast_ratio(colors["success"], colors["surface"])
	}

static func keyboard_contract() -> Dictionary:
	return {"navigation":"Tab / Shift+Tab", "activate":"Enter / Space", "gameplay_pause":"Space", "failure_retry":"R", "failure_exit":"Escape", "required_actions":["primary","back","retry","cancel"]}

static func _luminance(color: Color) -> float:
	var channels: Array[float] = []
	for value: float in [color.r, color.g, color.b]:
		channels.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
