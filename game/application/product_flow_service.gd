class_name ProductFlowService
extends RefCounted

const BOOT := "boot"
const DEVICE_SETUP := "device_setup"
const SONG_LIBRARY := "song_library"
const CALIBRATION := "calibration"
const GAMEPLAY := "gameplay"
const RESULTS := "results"

const ALLOWED := {
	BOOT:[DEVICE_SETUP, SONG_LIBRARY, GAMEPLAY],
	DEVICE_SETUP:[SONG_LIBRARY, CALIBRATION, RESULTS, BOOT],
	SONG_LIBRARY:[DEVICE_SETUP, CALIBRATION, GAMEPLAY, RESULTS, BOOT],
	CALIBRATION:[DEVICE_SETUP, SONG_LIBRARY, GAMEPLAY, RESULTS],
	GAMEPLAY:[RESULTS, SONG_LIBRARY],
	RESULTS:[DEVICE_SETUP, SONG_LIBRARY, CALIBRATION, GAMEPLAY]
}

var _state := BOOT
var _session_active := false
var _resources: Dictionary = {}

func state() -> String: return _state
func session_active() -> bool: return _session_active

func initial_route(settings_result: Dictionary, songs_result: Dictionary, midi_ports: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not settings_result.get("ok", false): return failure("settings", "Settings could not be loaded.", str(settings_result.get("error", "unknown settings error")), false)
	if not songs_result.get("ok", false): return failure("songs", "Song Library could not be loaded.", str(songs_result.get("error", "unknown song-index error")), true)
	var configured: bool = not str(settings_result["document"].get("selected_midi_port", "")).is_empty()
	var song_values: Array = songs_result["document"].get("songs", [])
	var has_songs: bool = not song_values.is_empty()
	var target: String = DEVICE_SETUP if not configured or midi_ports.is_empty() else SONG_LIBRARY
	var reason: String = "device_required" if target == DEVICE_SETUP else ("songs_ready" if has_songs else "song_import_required")
	var moved: Dictionary = transition(target); moved["reason"] = reason; return moved

func transition(next_state: String) -> Dictionary:
	if not ALLOWED.has(next_state): return {"ok":false, "code":"unknown_screen", "error":"Unknown screen: %s" % next_state}
	if not (ALLOWED[_state] as Array).has(next_state): return {"ok":false, "code":"invalid_transition", "error":"Invalid product transition: %s -> %s" % [_state, next_state]}
	if _session_active and next_state != RESULTS: return {"ok":false, "code":"session_active", "error":"Finish or cancel the active session before leaving Gameplay."}
	_cleanup_resources(); _state = next_state; return {"ok":true, "state":_state}

func begin_session(automation: bool = false) -> Dictionary:
	if _session_active: return {"ok":false, "code":"duplicate_session", "error":"A Gameplay session is already active."}
	if _state != GAMEPLAY:
		if not automation: return {"ok":false, "code":"invalid_session_start", "error":"Gameplay can start only from the Gameplay screen."}
		if _state != BOOT: return {"ok":false, "code":"invalid_session_start", "error":"Automation session can start only during Boot."}
		var moved: Dictionary = transition(GAMEPLAY); if not moved.get("ok", false): return moved
	_session_active = true; return {"ok":true, "state":_state}

func finish_session() -> Dictionary:
	if not _session_active or _state != GAMEPLAY: return {"ok":false, "code":"no_active_session", "error":"No Gameplay session is active."}
	_session_active = false; return transition(RESULTS)

func cancel_session() -> Dictionary:
	if not _session_active: return {"ok":false, "code":"no_active_session", "error":"No Gameplay session is active."}
	_session_active = false; return transition(SONG_LIBRARY)

func register_resource(resource_id: String, cleanup: Callable) -> Dictionary:
	if resource_id.is_empty() or not cleanup.is_valid(): return {"ok":false, "code":"invalid_resource", "error":"Resource cleanup registration is invalid."}
	if _resources.has(resource_id): return {"ok":false, "code":"duplicate_resource", "error":"Resource is already registered: %s" % resource_id}
	_resources[resource_id] = cleanup; return {"ok":true}

func failure(category: String, user_message: String, technical_detail: String, recoverable: bool) -> Dictionary:
	var actions: Array[String] = []
	if recoverable: actions.assign(["retry", "cancel", "back"])
	else: actions.assign(["back", "diagnostics"])
	return {"ok":false, "category":category, "severity":"recoverable" if recoverable else "fatal", "user_message":user_message, "technical_detail":technical_detail, "actions":actions}

func _cleanup_resources() -> void:
	for cleanup: Callable in _resources.values(): if cleanup.is_valid(): cleanup.call()
	_resources.clear()
