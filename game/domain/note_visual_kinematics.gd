class_name NoteVisualKinematics
extends RefCounted

const InputTechnique := preload("res://domain/input_technique.gd")
const SPAWN_RADIUS: float = 0.45
const DING_HIT_RADIUS: float = 0.17
const OUTER_HIT_RADIUS: float = 0.85

static func evaluate(technique: int, angle_degrees: float, spawn_us: int, hit_us: int, song_us: int) -> Vector3:
	assert(hit_us > spawn_us)
	var progress: float = clampf(float(song_us - spawn_us) / float(hit_us - spawn_us), 0.0, 1.0)
	var radius: float
	if technique == InputTechnique.Value.DING:
		radius = lerpf(SPAWN_RADIUS, DING_HIT_RADIUS, progress)
	else:
		radius = lerpf(SPAWN_RADIUS, OUTER_HIT_RADIUS, progress)
	return Vector3(radius, angle_degrees, progress)
