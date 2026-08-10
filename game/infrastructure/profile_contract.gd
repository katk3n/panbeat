class_name ProfileContract
extends RefCounted

const InputTechnique := preload("res://domain/input_technique.gd")
const SCHEMA_VERSION: String = "1.0.0"

static func supported_technique_count() -> int:
	return InputTechnique.count()
