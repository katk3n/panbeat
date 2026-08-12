class_name BackgroundPresetCatalog
extends RefCounted

const DEFAULT_ID := "deep_resonance"
const PRESETS: Array[Dictionary] = [
	{"id":"silent_resonance", "label":"Silent Resonance", "shader_index":0, "description":"Indigo mist, warm mineral light, and gentle acoustic ripples."},
	{"id":"breath_of_dawn", "label":"Breath of Dawn", "shader_index":1, "description":"Pearlescent halo, lavender fog, and softly drifting motes."},
	{"id":"deep_resonance", "label":"Deep Resonance", "shader_index":2, "description":"Dark teal veils, liquid light, and slow organic resonance."}
]

static func all() -> Array[Dictionary]:
	return PRESETS.duplicate(true)

static func is_valid(preset_id: String) -> bool:
	return PRESETS.any(func(preset: Dictionary) -> bool: return preset["id"] == preset_id)

static func preset(preset_id: String) -> Dictionary:
	for value: Dictionary in PRESETS:
		if value["id"] == preset_id:
			return value.duplicate(true)
	return preset(DEFAULT_ID) if preset_id != DEFAULT_ID else {}

static func shader_index(preset_id: String) -> int:
	return int(preset(preset_id).get("shader_index", 2))

static func resolve(package: Dictionary, settings: Dictionary, override_id: String = "") -> String:
	if is_valid(override_id):
		return override_id
	var song_id := str(package.get("song_id", package.get("package_id", "")))
	var per_song: Variant = settings.get("song_background_presets", {})
	if per_song is Dictionary:
		var selected := str((per_song as Dictionary).get(song_id, ""))
		if is_valid(selected):
			return selected
	var package_id := str(package.get("background_preset_id", ""))
	if is_valid(package_id):
		return package_id
	var global_id := str(settings.get("background_preset_id", ""))
	return global_id if is_valid(global_id) else DEFAULT_ID

static func assign_to_song(settings: Dictionary, song_id: String, preset_id: String) -> Dictionary:
	var updated := settings.duplicate(true)
	if not is_valid(preset_id) or song_id.is_empty():
		return updated
	var per_song: Dictionary = updated.get("song_background_presets", {}).duplicate(true)
	per_song[song_id] = preset_id
	updated["song_background_presets"] = per_song
	return updated
