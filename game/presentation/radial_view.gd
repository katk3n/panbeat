class_name RadialView
extends Node2D

const Scheduler := preload("res://application/gameplay_note_scheduler.gd")
const OUTER_RADIUS_FACTOR: float = 0.425
const SPAWN_RADIUS_FACTOR: float = 0.225
const DING_RADIUS_FACTOR: float = 0.085

var monochrome: bool = false
var scheduler: GameplayNoteScheduler
var transport: RefCounted
var preview_song_time_us: int = 10_000_000
var _profile: Dictionary = {}

func configure(chart: RefCounted, profile: Dictionary, note_capacity: int = 64) -> void:
	_profile = profile.duplicate(true)
	scheduler = Scheduler.new(chart, _profile, note_capacity)
	queue_redraw()

func set_preview_song_time_us(value: int) -> void:
	preview_song_time_us = value
	queue_redraw()

func show_feedback(note_id: String, grade: String) -> bool:
	if scheduler == null:
		return false
	var changed: bool = scheduler.mark_feedback(note_id, grade, _song_time_us())
	if changed:
		queue_redraw()
	return changed

func _process(_delta: float) -> void:
	if scheduler == null:
		return
	scheduler.update(_song_time_us())
	queue_redraw()

func _draw() -> void:
	var geometry: Dictionary = geometry_for_size(get_viewport_rect().size)
	var center: Vector2 = geometry["center"]
	var short_side: float = geometry["short_side"]
	var ink := Color(0.94, 0.95, 0.98)
	var guide := Color(0.46, 0.52, 0.62)
	if monochrome:
		ink = Color.WHITE
		guide = Color(0.55, 0.55, 0.55)
	var outer_radius: float = geometry["outer_radius"]
	var spawn_radius: float = geometry["spawn_radius"]
	draw_arc(center, outer_radius, 0.0, TAU, 160, guide, 3.0)
	draw_arc(center, spawn_radius, 0.0, TAU, 128, Color(guide, 0.35), 2.0)
	draw_arc(center, short_side * DING_RADIUS_FACTOR, 0.0, TAU, 64, guide, 3.0)
	for tone_value: Variant in _profile.get("layout", {}).get("tones", []):
		var tone: Dictionary = tone_value as Dictionary
		var tone_center: Vector2 = center + _polar_offset(float(tone["angle_degrees"]), outer_radius)
		draw_arc(tone_center, short_side * 0.035, 0.0, TAU, 36, guide, 3.0)
		var label: String = (tone["target_id"] as String).trim_prefix("tone-")
		var font: Font = ThemeDB.fallback_font
		var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(short_side * 0.027))
		draw_string(font, tone_center + Vector2(-label_size.x * 0.5, label_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(short_side * 0.027), guide)
	if scheduler == null:
		return
	var song_time_us: int = _song_time_us()
	for slot: Dictionary in scheduler.active_slots():
		if not slot["active"]:
			continue
		var note: Dictionary = slot["note"]
		var visual: Vector3 = scheduler.visual_state(slot, song_time_us)
		var radius: float = visual.x * short_side * 0.5
		var position: Vector2 = center + _polar_offset(visual.y, radius)
		match note["technique"]:
			"ding":
				var size: float = short_side * 0.026
				draw_colored_polygon(PackedVector2Array([position + Vector2(0,-size), position + Vector2(size,0), position + Vector2(0,size), position + Vector2(-size,0)]), ink)
			"slap":
				draw_arc(center, radius, 0.0, TAU, 128, ink, 7.0)
				draw_arc(center, radius + short_side * 0.012, 0.0, TAU, 128, ink, 2.0)
			_:
				draw_arc(position, short_side * 0.025, 0.0, TAU, 36, ink, 7.0)
		if not (slot["feedback"] as String).is_empty() and song_time_us <= int(slot["feedback_expires_us"]):
			var feedback_radius: float = short_side * 0.045
			if slot["feedback"] == "miss":
				draw_line(position + Vector2(-feedback_radius,-feedback_radius), position + Vector2(feedback_radius,feedback_radius), ink, 5.0)
				draw_line(position + Vector2(feedback_radius,-feedback_radius), position + Vector2(-feedback_radius,feedback_radius), ink, 5.0)
			else:
				draw_arc(position, feedback_radius, 0.0, TAU, 40, ink, 4.0)

func _song_time_us() -> int:
	if transport != null and transport.has_method("now_us"):
		return int(transport.now_us())
	return preview_song_time_us

func _polar_offset(angle_degrees: float, radius: float) -> Vector2:
	var radians: float = deg_to_rad(angle_degrees)
	return Vector2(sin(radians), -cos(radians)) * radius

static func geometry_for_size(size: Vector2) -> Dictionary:
	var short_side: float = minf(size.x, size.y)
	return {
		"center": size * 0.5,
		"short_side": short_side,
		"outer_radius": short_side * OUTER_RADIUS_FACTOR,
		"spawn_radius": short_side * SPAWN_RADIUS_FACTOR
	}
