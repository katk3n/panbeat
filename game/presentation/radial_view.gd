class_name RadialView
extends Node2D

const Scheduler := preload("res://application/gameplay_note_scheduler.gd")
const Tokens := preload("res://presentation/ui_tokens.gd")
const FieldShader := preload("res://presentation/radial_field.gdshader")
const BackgroundPresets := preload("res://application/background_preset_catalog.gd")
const OUTER_RADIUS_FACTOR: float = 0.425
const SPAWN_RADIUS_FACTOR: float = 0.225
const DING_RADIUS_FACTOR: float = 0.085

var monochrome: bool = false
var glow_enabled: bool = true
var high_contrast: bool = false
var decoration_enabled: bool = true
var judgement_layer_enabled: bool = true
var combo_visual_enabled: bool = true
var combo_value: int = 0
var scheduler: GameplayNoteScheduler
var transport: RefCounted
var preview_song_time_us: int = 10_000_000
var background_preset_id: String = BackgroundPresets.DEFAULT_ID
var _profile: Dictionary = {}
var _field_shader_rect: ColorRect
var _field_shader_material: ShaderMaterial
var _dense_visual_load: bool = false
var _orb_mesh: ArrayMesh

func _ready() -> void:
	_orb_mesh = _build_orb_mesh()
	_field_shader_rect = ColorRect.new()
	_field_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_shader_rect.z_index = -100
	_field_shader_material = ShaderMaterial.new()
	_field_shader_material.shader = FieldShader
	_field_shader_rect.material = _field_shader_material
	add_child(_field_shader_rect)
	_sync_field_shader()

func configure(chart: RefCounted, profile: Dictionary, note_capacity: int = 64) -> void:
	_profile = profile.duplicate(true)
	scheduler = Scheduler.new(chart, _profile, note_capacity)
	queue_redraw()

func set_preview_song_time_us(value: int) -> void:
	preview_song_time_us = value
	queue_redraw()

func set_background_preset(preset_id: String) -> void:
	background_preset_id = preset_id if BackgroundPresets.is_valid(preset_id) else BackgroundPresets.DEFAULT_ID
	_sync_field_shader()
	queue_redraw()

func show_feedback(note_id: String, grade: String) -> bool:
	if scheduler == null:
		return false
	var changed: bool = scheduler.mark_feedback(note_id, grade, _song_time_us())
	if changed:
		queue_redraw()
	return changed

func _process(_delta: float) -> void:
	_sync_field_shader()
	if scheduler == null:
		return
	scheduler.update(_song_time_us())
	_sync_note_bloom()
	queue_redraw()

func _draw() -> void:
	var geometry: Dictionary = geometry_for_size(get_viewport_rect().size)
	var center: Vector2 = geometry["center"]
	var short_side: float = geometry["short_side"]
	var ink := Color.WHITE if monochrome or high_contrast else Tokens.color("primary")
	var guide := Color.WHITE if high_contrast else (Color(0.68, 0.68, 0.68) if monochrome else Tokens.color("line"))
	_draw_background(geometry)
	if decoration_enabled:
		_draw_instrument_decoration(geometry, guide)
	if judgement_layer_enabled:
		_draw_judgement_guides(geometry, guide)
	_draw_notes(geometry, ink)
	if combo_visual_enabled:
		_draw_combo(geometry, ink)

func _draw_background(geometry: Dictionary) -> void:
	var size: Vector2 = get_viewport_rect().size
	var base := Color.BLACK if high_contrast else (Color("090b11") if monochrome else Tokens.color("background"))
	if _field_shader_rect == null:
		draw_rect(Rect2(Vector2.ZERO, size), base)
	if not decoration_enabled:
		return
	if _field_shader_rect != null:
		return
	var center: Vector2 = geometry["center"]
	var short_side: float = geometry["short_side"]
	for index: int in 7:
		var alpha := 0.055 - index * 0.006
		draw_circle(center, short_side * (0.51 - index * 0.025), Color(Tokens.color("background_depth"), alpha))

func _draw_instrument_decoration(geometry: Dictionary, guide: Color) -> void:
	var center: Vector2 = geometry["center"]
	var short_side: float = geometry["short_side"]
	var disc_radius: float = short_side * 0.47
	var metal_outer := Color("303238") if monochrome else Color("34383f")
	var metal_inner := Color("14161b") if monochrome else Color("171b22")
	if _field_shader_rect == null:
		for index: int in 10:
			var amount := float(index) / 9.0
			draw_circle(center, disc_radius - index * short_side * 0.018, metal_outer.lerp(metal_inner, amount))
	for factor: float in [0.46, 0.34, 0.22, 0.11]:
		draw_arc(center, short_side * factor, 0.0, TAU, 144, Color(guide, 0.20), 1.0)

func _draw_judgement_guides(geometry: Dictionary, guide: Color) -> void:
	var center: Vector2 = geometry["center"]
	var short_side: float = geometry["short_side"]
	var outer_radius: float = geometry["outer_radius"]
	var spawn_radius: float = geometry["spawn_radius"]
	draw_arc(center, outer_radius, 0.0, TAU, 160, guide, 3.0)
	draw_arc(center, spawn_radius, 0.0, TAU, 128, Color(guide, 0.24), 1.5)
	draw_arc(center, short_side * DING_RADIUS_FACTOR, 0.0, TAU, 64, guide, 3.0)
	for tone_value: Variant in _profile.get("layout", {}).get("tones", []):
		var tone: Dictionary = tone_value as Dictionary
		var tone_center: Vector2 = tone_center_for(center, outer_radius, float(tone["angle_degrees"]))
		draw_circle(tone_center, short_side * 0.037, Color(Tokens.color("surface"), 0.78) if not monochrome else Color("202020"))
		draw_arc(tone_center, short_side * 0.035, 0.0, TAU, 36, guide, 3.0)
		var label: String = (tone["target_id"] as String).trim_prefix("tone-")
		var font: Font = ThemeDB.fallback_font
		var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(short_side * 0.027))
		draw_string(font, tone_center + Vector2(-label_size.x * 0.5, label_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(short_side * 0.027), guide)

func _draw_notes(geometry: Dictionary, ink: Color) -> void:
	if scheduler == null: return
	_dense_visual_load = scheduler.active_count() > 16
	var center: Vector2 = geometry["center"]
	var short_side: float = geometry["short_side"]
	var song_time_us: int = _song_time_us()
	for slot: Dictionary in scheduler.active_slots():
		if not slot["active"]:
			continue
		var note: Dictionary = slot["note"]
		var visual: Vector3 = scheduler.visual_state(slot, song_time_us)
		var radius: float = visual.x * short_side * 0.5
		var position: Vector2 = tone_center_for(center, radius, visual.y)
		var progress: float = visual.z
		if progress < 0.12:
			var spawn_alpha := (0.12 - progress) / 0.12
			_draw_luminous_arc(center, geometry["spawn_radius"] + short_side * progress * 0.035, Tokens.color("spawn_luminous"), 2.0, 128, spawn_alpha * 0.72)
		match note["technique"]:
			"ding":
				var ding_color := _technique_color("ding", ink)
				_draw_luminous_arc(center, radius, ding_color, 5.0, 128, 1.0)
				_draw_direction_ticks(center, radius, true, ding_color)
			"slap":
				var slap_color := _technique_color("slap", ink)
				_draw_luminous_arc(center, radius, slap_color, 6.0, 128, 1.0)
				_draw_direction_ticks(center, radius, false, slap_color)
			_:
				var tone_color := _technique_color("tone", ink)
				_draw_luminous_orb(position, short_side * 0.025, tone_color)
		if not (slot["feedback"] as String).is_empty() and song_time_us <= int(slot["feedback_expires_us"]):
			var feedback_duration_us := maxi(1, int(slot["feedback_expires_us"]) - int(slot["feedback_started_us"]))
			var feedback_age := clampf(float(song_time_us - int(slot["feedback_started_us"])) / float(feedback_duration_us), 0.0, 1.0)
			_draw_feedback(note["technique"], slot["feedback"], center, position, geometry, ink, feedback_age)

func _draw_direction_ticks(center: Vector2, radius: float, inward: bool, ink: Color) -> void:
	for angle: float in [0.0, 90.0, 180.0, 270.0]:
		var outer := tone_center_for(center, radius + (9.0 if not inward else -3.0), angle)
		var inner := tone_center_for(center, radius + (-9.0 if inward else 15.0), angle)
		draw_line(outer, inner, ink, 3.0)

func _draw_feedback(technique: String, grade: String, center: Vector2, note_position: Vector2, geometry: Dictionary, ink: Color, age: float) -> void:
	var style := feedback_style(grade)
	var position := feedback_origin_for(technique, center, note_position)
	var radius: float = geometry["short_side"] * (0.075 if technique == "ding" else 0.045)
	if technique == "slap":
		position = center
		radius = geometry["outer_radius"]
	var color: Color = ink if monochrome else Tokens.color(style["color"])
	if grade != "miss":
		var impact := pow(1.0 - age, 2.4)
		_draw_luminous_arc(position, radius, color, float(style["width"]) + impact * 6.0, 80 if technique != "slap" else 160, 1.4 + impact * 3.4)
	var font_size := 18
	var label_width := feedback_label_width(style["label"], font_size)
	draw_string(ThemeDB.fallback_font, position + Vector2(-label_width * 0.5, -radius - 12), style["label"], HORIZONTAL_ALIGNMENT_CENTER, label_width, font_size, color)

func _draw_luminous_arc(center: Vector2, radius: float, color: Color, core_width: float, segments: int, energy: float) -> void:
	draw_arc(center, radius, 0.0, TAU, segments, Color(color, clampf(0.78 + energy * 0.18, 0.0, 1.0)), core_width)

func _draw_luminous_orb(position: Vector2, radius: float, color: Color) -> void:
	if _orb_mesh == null:
		draw_circle(position, radius, color.lightened(0.45))
		return
	var transform := Transform2D(Vector2(radius, 0.0), Vector2(0.0, radius), position)
	var modulate := Color.WHITE if high_contrast else color.lightened(0.42)
	draw_mesh(_orb_mesh, null, transform, modulate)

func _build_orb_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var colors := PackedColorArray([Color.WHITE])
	var indices := PackedInt32Array()
	for index: int in 49:
		var angle := TAU * float(index) / 48.0
		vertices.append(Vector3(cos(angle), sin(angle), 0.0))
		colors.append(Color(0.80, 0.80, 0.80, 0.96))
	for index: int in 48:
		indices.append_array(PackedInt32Array([0, index + 1, index + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _technique_color(technique: String, fallback: Color) -> Color:
	if monochrome or high_contrast:
		return fallback
	match technique:
		"ding": return Tokens.color("ding_luminous")
		"slap": return Tokens.color("slap_luminous")
		_: return Tokens.color("tone_luminous")

func _sync_field_shader() -> void:
	if _field_shader_rect == null or _field_shader_material == null:
		return
	var size := get_viewport_rect().size
	_field_shader_rect.position = Vector2.ZERO
	_field_shader_rect.size = size
	_field_shader_material.set_shader_parameter("viewport_size", size)
	_field_shader_material.set_shader_parameter("glow_energy", 1.18 if glow_enabled else 0.0)
	_field_shader_material.set_shader_parameter("monochrome", monochrome)
	_field_shader_material.set_shader_parameter("high_contrast", high_contrast)
	_field_shader_material.set_shader_parameter("decoration_enabled", decoration_enabled)
	_field_shader_material.set_shader_parameter("pulse_phase", float(_song_time_us()) / 1_000_000.0)
	_field_shader_material.set_shader_parameter("background_preset", BackgroundPresets.shader_index(background_preset_id))

func _sync_note_bloom() -> void:
	if _field_shader_material == null:
		return
	if not glow_enabled or monochrome or high_contrast or scheduler == null:
		_field_shader_material.set_shader_parameter("note_bloom_count", 0)
		return
	var viewport_size := get_viewport_rect().size
	var geometry := geometry_for_size(viewport_size)
	var center: Vector2 = geometry["center"]
	var short_side: float = geometry["short_side"]
	var song_time_us := _song_time_us()
	var ring_count := 0
	for slot: Dictionary in scheduler.active_slots():
		if not slot["active"] or ring_count >= 16:
			continue
		var note: Dictionary = slot["note"]
		var visual := scheduler.visual_state(slot, song_time_us)
		var note_radius := visual.x * short_side * 0.5
		var note_center := center
		var ring_radius := note_radius
		if note["technique"] == "tone":
			note_center = tone_center_for(center, note_radius, visual.y)
			ring_radius = -short_side * 0.025
		var color := _technique_color(note["technique"], Color.WHITE)
		var bloom_energy := 0.38
		var bloom_sigma := short_side * 0.013
		if note["technique"] == "tone":
			bloom_energy = 0.60
			bloom_sigma = short_side * 0.016
		if not (slot["feedback"] as String).is_empty() and song_time_us <= int(slot["feedback_expires_us"]) and slot["feedback"] != "miss":
			var style := feedback_style(slot["feedback"])
			color = Tokens.color(style["color"])
			var duration_us := maxi(1, int(slot["feedback_expires_us"]) - int(slot["feedback_started_us"]))
			var age := clampf(float(song_time_us - int(slot["feedback_started_us"])) / float(duration_us), 0.0, 1.0)
			var impact := pow(1.0 - age, 2.4)
			if note["technique"] == "tone":
				bloom_energy = 0.62 + impact * 0.52
				bloom_sigma = short_side * (0.017 + impact * 0.010)
			else:
				bloom_energy = 0.35 + impact * 0.50
				bloom_sigma = short_side * (0.014 + impact * 0.009)
		_field_shader_material.set_shader_parameter("note_bloom_geometry_%d" % ring_count, Vector4(note_center.x, note_center.y, ring_radius, bloom_sigma))
		_field_shader_material.set_shader_parameter("note_bloom_color_%d" % ring_count, Vector4(color.r, color.g, color.b, bloom_energy))
		ring_count += 1
	_field_shader_material.set_shader_parameter("note_bloom_count", ring_count)

func _draw_combo(geometry: Dictionary, ink: Color) -> void:
	var stage := combo_stage(combo_value)
	if stage == 0: return
	var position := Vector2(get_viewport_rect().size.x - 214, 118)
	var color := ink if monochrome else Tokens.color("accent")
	var size := 17 + stage * 3
	draw_string(ThemeDB.fallback_font, position, "COMBO %d · %s" % [combo_value, "I".repeat(stage)], HORIZONTAL_ALIGNMENT_LEFT, 190, size, color)
	for index: int in stage:
		draw_line(position + Vector2(index * 18, 12), position + Vector2(index * 18 + 12, 12), color, 3.0)

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

static func tone_center_for(center: Vector2, radius: float, angle_degrees: float) -> Vector2:
	var radians: float = deg_to_rad(angle_degrees)
	return center + Vector2(sin(radians), -cos(radians)) * radius

static func layer_contract() -> Dictionary:
	return {"decoration_independent":true, "judgement_independent":true, "notes_always_visible":true, "material":"translucent_forged_copper", "background_transmission":0.76, "opaque_accessibility_fallback":true, "per_frame_node_creation":0, "per_frame_resource_creation":0}

static func accessibility_contract() -> Dictionary:
	return {"full_screen_flash":false, "constant_camera_shake":false, "technique_uses_shape_and_direction":true, "grade_uses_shape_strength_and_text":true, "lightweight_fallback":["glow_disabled","monochrome"]}

static func feedback_style(grade: String) -> Dictionary:
	match grade:
		"perfect": return {"label":"PERFECT", "color":"success", "width":6.0, "rings":1, "pattern":"single_impact"}
		"great": return {"label":"GREAT", "color":"accent", "width":4.0, "rings":1, "pattern":"single_impact"}
		"good": return {"label":"GOOD", "color":"warning", "width":2.0, "rings":1, "pattern":"thin"}
		_: return {"label":"MISS", "color":"error", "width":0.0, "rings":0, "pattern":"text_only"}

static func feedback_label_width(label: String, font_size: int = 18) -> float:
	return ceilf(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20.0)

static func combo_stage(combo: int) -> int:
	if combo < 5: return 0
	if combo < 10: return 1
	if combo < 25: return 2
	return 3

static func feedback_origin_for(technique: String, center: Vector2, note_position: Vector2) -> Vector2:
	return center if technique in ["ding", "slap"] else note_position

static func visual_quality_contract() -> Dictionary:
	return {"procedural_field_shader":true, "audio_time_driven_shader":true, "deterministic_shader":true, "handpan_material":"translucent_forged_copper", "background_transmission":0.76, "copper_patina":true, "note_bloom_shader":"integrated_sdf_gaussian", "tone_note_shape":"foreground_emissive_orb", "orb_shading":"saturated_cyan_center_hot_gradient", "orb_draw_order":"above_handpan_and_targets", "orb_bloom_strength":"strong_atmospheric_spill", "bloom_profile":"luminous_core_diffused_mist_atmospheric_spill", "bloom_shader_capacity":16, "normal_glow_layers":1, "smooth_bloom_falloff":"continuous_gaussian", "single_note_ring":false, "hollow_note_core":false, "black_note_core":false, "white_impact_fill":false, "impact_rays":false, "bloom_strength":"pronounced", "hit_bloom_strength":"bright_surge", "background_presets":["silent_resonance","breath_of_dawn","deep_resonance"], "background_motion":"visible_audio_time", "background_motion_strength":"dramatic", "deep_resonance_identity":"jade_mist_caustics", "cyber_grid":false, "static_outer_gold_ring":false, "legacy_highlight_arc":false, "dense_load_threshold":16, "dense_load_halo_layers":1, "note_trails":false, "technique_palette":["tone_luminous","ding_luminous","slap_luminous"], "reference_window":[1600,900], "launch_mode":"maximized", "stretch_aspect":"expand"}
