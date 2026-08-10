class_name RadialView
extends Node2D

func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5
	var scale_size: float = minf(get_viewport_rect().size.x, get_viewport_rect().size.y)
	var ink := Color(0.9, 0.92, 0.95)
	draw_arc(center, scale_size * 0.425, 0.0, TAU, 128, Color(0.6, 0.65, 0.72), 3.0)
	draw_arc(center, scale_size * 0.225, 0.0, TAU, 128, Color(0.3, 0.34, 0.42), 2.0)
	draw_arc(center, scale_size * 0.34, 0.0, TAU, 128, ink, 8.0)
	var tone_center := center + Vector2(scale_size * 0.25, -scale_size * 0.20)
	draw_arc(tone_center, 28.0, 0.0, TAU, 48, ink, 7.0)
	draw_arc(tone_center, 47.0, 0.0, TAU, 48, Color(0.6, 0.65, 0.72), 3.0)
	var ding_center := center + Vector2(0.0, scale_size * 0.10)
	draw_colored_polygon(PackedVector2Array([ding_center + Vector2(0,-34), ding_center + Vector2(34,0), ding_center + Vector2(0,34), ding_center + Vector2(-34,0)]), ink)
