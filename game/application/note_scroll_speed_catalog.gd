class_name NoteScrollSpeedCatalog
extends RefCounted

const DEFAULT_ID := "normal"
const PRESETS: Array[Dictionary] = [
	{"id":"slow", "label":"Slow · 0.75×", "multiplier":0.75, "lookahead_us":2_666_667},
	{"id":"normal", "label":"Normal · 1.0×", "multiplier":1.0, "lookahead_us":2_000_000},
	{"id":"fast", "label":"Fast · 1.5×", "multiplier":1.5, "lookahead_us":1_333_333},
	{"id":"very_fast", "label":"Very Fast · 2.0×", "multiplier":2.0, "lookahead_us":1_000_000}
]

static func all() -> Array[Dictionary]:
	return PRESETS.duplicate(true)

static func is_valid(preset_id: String) -> bool:
	return PRESETS.any(func(preset: Dictionary) -> bool: return preset["id"] == preset_id)

static func preset(preset_id: String) -> Dictionary:
	for value: Dictionary in PRESETS:
		if value["id"] == preset_id:
			return value.duplicate(true)
	return preset(DEFAULT_ID)

static func resolve(package: Dictionary, settings: Dictionary, override_id: String = "") -> String:
	if is_valid(override_id):
		return override_id
	var song_id := str(package.get("song_id", package.get("package_id", "")))
	var per_song: Variant = settings.get("song_note_scroll_speeds", {})
	if per_song is Dictionary and not song_id.is_empty():
		var selected := str((per_song as Dictionary).get(song_id, ""))
		if is_valid(selected):
			return selected
	var global_id := str(settings.get("note_scroll_speed_id", ""))
	return global_id if is_valid(global_id) else DEFAULT_ID

static func assign_to_song(settings: Dictionary, song_id: String, preset_id: String) -> Dictionary:
	var updated := settings.duplicate(true)
	if not is_valid(preset_id) or song_id.is_empty():
		return updated
	var per_song: Dictionary = updated.get("song_note_scroll_speeds", {}).duplicate(true)
	per_song[song_id] = preset_id
	updated["song_note_scroll_speeds"] = per_song
	return updated
