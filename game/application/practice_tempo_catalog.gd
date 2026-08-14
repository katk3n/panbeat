class_name PracticeTempoCatalog
extends RefCounted

const DEFAULT_ID := "tempo_100"
const PRESETS: Array[Dictionary] = [
	{"id":"tempo_50", "label":"50%", "multiplier":0.5},
	{"id":"tempo_60", "label":"60%", "multiplier":0.6},
	{"id":"tempo_70", "label":"70%", "multiplier":0.7},
	{"id":"tempo_80", "label":"80%", "multiplier":0.8},
	{"id":"tempo_90", "label":"90%", "multiplier":0.9},
	{"id":"tempo_100", "label":"100% · Original", "multiplier":1.0}
]

static func all() -> Array[Dictionary]:
	return PRESETS.duplicate(true)

static func is_valid(preset_id: String) -> bool:
	return PRESETS.any(func(value: Dictionary) -> bool: return value["id"] == preset_id)

static func preset(preset_id: String) -> Dictionary:
	for value: Dictionary in PRESETS:
		if value["id"] == preset_id: return value.duplicate(true)
	return preset(DEFAULT_ID) if preset_id != DEFAULT_ID else {}

static func resolve(package: Dictionary, settings: Dictionary, override_id: String = "") -> String:
	if is_valid(override_id): return override_id
	var song_id := str(package.get("song_id", package.get("package_id", "")))
	var per_song: Variant = settings.get("song_practice_tempos", {})
	if per_song is Dictionary and not song_id.is_empty():
		var selected := str((per_song as Dictionary).get(song_id, ""))
		if is_valid(selected): return selected
	var global_id := str(settings.get("practice_tempo_id", ""))
	return global_id if is_valid(global_id) else DEFAULT_ID

static func assign_to_song(settings: Dictionary, song_id: String, preset_id: String) -> Dictionary:
	var updated := settings.duplicate(true)
	if not is_valid(preset_id) or song_id.is_empty(): return updated
	var per_song: Dictionary = updated.get("song_practice_tempos", {}).duplicate(true)
	per_song[song_id] = preset_id
	updated["song_practice_tempos"] = per_song
	return updated
