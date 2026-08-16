class_name RichUiBackground
extends ColorRect

const BackgroundShader := preload("res://presentation/rich_ui_background.gdshader")

var intensity: float = 1.0
var _shader_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = BackgroundShader
	material = _shader_material
	_sync_shader()

func _process(_delta: float) -> void:
	_sync_shader()

func _sync_shader() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("viewport_size", get_viewport_rect().size)
	_shader_material.set_shader_parameter("intensity", intensity)

static func visual_contract() -> Dictionary:
	return {"procedural_shader":true, "meditative_fog":true, "breathing_halo":true, "resonance_ripples":true, "visible_slow_motion":true, "motion_speed":0.38, "motion_strength":"dramatic", "palette":"icon_cyan_blue_magenta", "dark_negative_space":true, "perspective_grid":false, "particle_field":false, "cyber_aesthetic":false}
