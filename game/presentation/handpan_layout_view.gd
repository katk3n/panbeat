class_name HandpanLayoutView
extends Control

const Tokens := preload("res://presentation/ui_tokens.gd")

const TARGET_ANGLES := {
	"tone-7": 22.5,
	"tone-5": 67.5,
	"tone-3": 112.5,
	"tone-1": 157.5,
	"tone-2": 202.5,
	"tone-4": 247.5,
	"tone-6": 292.5,
	"tone-8": 337.5,
}

var performance_layout: Dictionary = {}
var scale_name := ""
var highlighted_target := ""
var verified_targets: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(250, 250)
	resized.connect(queue_redraw)

func show_layout(value: Dictionary, song_scale_name: String = "") -> void:
	performance_layout = value.duplicate(true)
	scale_name = song_scale_name
	highlighted_target = ""
	verified_targets.clear()
	visible = not performance_layout.is_empty()
	queue_redraw()

func show_midi_target(target_id: String) -> void:
	highlighted_target = target_id
	if not target_id.is_empty(): verified_targets[target_id] = true
	queue_redraw()

static func slot_labels(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot: Dictionary in value.get("slots", []):
		var names := PackedStringArray(slot.get("display_names", []))
		result[str(slot.get("target_id", ""))] = "/".join(names) if not names.is_empty() else "—"
	return result

static func target_direction(target_id: String) -> Vector2:
	if target_id == "ding": return Vector2.ZERO
	var radians := deg_to_rad(float(TARGET_ANGLES.get(target_id, 0.0)))
	return Vector2(sin(radians), -cos(radians))

func _draw() -> void:
	if performance_layout.is_empty(): return
	var font := ThemeDB.fallback_font
	var radius := maxf(1.0, minf(size.x * 0.43, (size.y - 32.0) * 0.48))
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 14.0)
	var title := "HANDPAN MAP"
	if not scale_name.is_empty(): title += "  ·  %s" % scale_name
	draw_string(font, Vector2(0, 18), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Tokens.color("accent"))

	# Echo the app icon with a restrained, nearly monochrome luminous outline.
	draw_circle(center + Vector2(0, 5), radius + 7.0, Color(0, 0, 0, 0.42))
	draw_circle(center, radius, Color("060a1b"))
	draw_circle(center, radius * 0.91, Color("091026"))
	draw_arc(center, radius - 1.0, 0.0, TAU, 96, Tokens.color("accent_blue"), 3.0, true)
	draw_arc(center, radius + 2.0, 0.0, TAU, 96, Color(Tokens.color("accent"), 0.08), 8.0, true)

	var labels := slot_labels(performance_layout)
	var pad_radius := radius * 0.168
	var orbit := radius * 0.77
	for target_id: String in TARGET_ANGLES:
		var pad_center := center + target_direction(target_id) * orbit
		_draw_pad(pad_center, pad_radius, target_id, str(labels.get(target_id, "—")), font)

	var ding_radius := radius * 0.275
	var ding_active := highlighted_target == "ding"
	draw_circle(center, ding_radius, Color("050817"))
	draw_circle(center, ding_radius * 0.57, Color("080d25"))
	draw_arc(center, ding_radius, 0.0, TAU, 64, Tokens.color("accent_blue"), 3.0 if not ding_active else 5.0, true)
	if ding_active: draw_arc(center, ding_radius + 2.0, 0.0, TAU, 64, Color(Tokens.color("accent_blue"), 0.18), 10.0, true)
	if verified_targets.has("ding") and not ding_active:
		draw_arc(center, ding_radius - 5.0, 0.0, TAU, 64, Tokens.color("focus"), 2.0, true)
	_draw_centered_pair(center, str(labels.get("ding", "—")), "D", font, Color.WHITE if ding_active else Color("dbe7ff"), radius)

func _draw_pad(center: Vector2, radius: float, target_id: String, pitch: String, font: Font) -> void:
	var active := highlighted_target == target_id
	var rim := Tokens.color("accent_blue")
	draw_circle(center, radius, Color("060a1b"))
	draw_arc(center, radius - 1.0, 0.0, TAU, 48, rim, 2.5 if not active else 4.5, true)
	if active:
		draw_arc(center, radius + 2.0, 0.0, TAU, 48, Color(rim, 0.20), 10.0, true)
	if verified_targets.has(target_id) and not active:
		draw_arc(center, radius - 5.0, 0.0, TAU, 40, Tokens.color("focus"), 2.0, true)
	var number := target_id.trim_prefix("tone-")
	var ink := Color.WHITE if active else Color("dbe7ff")
	if pitch == "—": ink = Color("7381a8")
	_draw_centered_pair(center, pitch, number, font, ink, radius / 0.168)

static func visual_contract() -> Dictionary:
	return {"icon_palette":true, "dark_body":true, "restrained_color":true, "uniform_rim":true, "luminous_pad_outlines":true, "solid_light_pads":false}

func _draw_centered_pair(center: Vector2, first: String, second: String, font: Font, color: Color, body_radius: float) -> void:
	var pitch_size := maxi(12, int(body_radius * 0.073))
	var index_size := maxi(11, int(body_radius * 0.060))
	var pitch_width := font.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, pitch_size).x
	var index_width := font.get_string_size(second, HORIZONTAL_ALIGNMENT_LEFT, -1, index_size).x
	draw_string(font, center + Vector2(-pitch_width * 0.5, -1), first, HORIZONTAL_ALIGNMENT_LEFT, -1, pitch_size, color)
	draw_string(font, center + Vector2(-index_width * 0.5, index_size + 2), second, HORIZONTAL_ALIGNMENT_LEFT, -1, index_size, Color(color, color.a * 0.82))
