extends SceneTree

const Flow := preload("res://application/product_flow_service.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var settings_empty := {"ok":true, "document":{"schema_version":"1.0.0", "selected_midi_port":"", "profile_id":"p", "offsets":[]}}
	var settings_ready := {"ok":true, "document":{"schema_version":"1.0.0", "selected_midi_port":"MN-10", "profile_id":"p", "offsets":[]}}
	var songs_empty := {"ok":true, "document":{"schema_version":"1.0.0", "songs":[]}}
	var songs_ready := {"ok":true, "document":{"schema_version":"1.0.0", "songs":[{"song_id":"song"}]}}
	var fresh := Flow.new(); _check(fresh.initial_route(settings_empty, songs_empty).get("state") == Flow.DEVICE_SETUP, "first launch starts at Device Setup", failures)
	var no_device := Flow.new(); _check(no_device.initial_route(settings_ready, songs_ready, PackedStringArray()).get("state") == Flow.DEVICE_SETUP, "configured startup without device starts at Device Setup", failures)
	var no_song := Flow.new(); var no_song_route := no_song.initial_route(settings_ready, songs_empty, PackedStringArray(["MN-10"])); _check(no_song_route.get("state") == Flow.SONG_LIBRARY and no_song_route.get("reason") == "song_import_required", "configured startup with no songs starts at Song Library", failures)
	var configured := Flow.new(); _check(configured.initial_route(settings_ready, songs_ready, PackedStringArray(["MN-10"])).get("state") == Flow.SONG_LIBRARY, "configured startup starts at Song Library", failures)
	_check(configured.transition(Flow.SONG_LIBRARY).get("code") == "invalid_transition", "same-screen transition rejected", failures)
	var top_navigation := Flow.new(); top_navigation.initial_route(settings_empty, songs_empty)
	_check(top_navigation.transition(Flow.CALIBRATION).get("ok") and top_navigation.transition(Flow.RESULTS).get("ok") and top_navigation.transition(Flow.DEVICE_SETUP).get("ok") and top_navigation.transition(Flow.SONG_LIBRARY).get("ok"), "visible top navigation works between Device Calibration Results and Songs", failures)
	_check(configured.begin_session().get("code") == "invalid_session_start", "session cannot start outside Gameplay", failures)
	_check(configured.transition(Flow.GAMEPLAY).get("ok") and configured.begin_session().get("ok"), "valid Gameplay session starts", failures)
	_check(configured.begin_session().get("code") == "duplicate_session", "double session start rejected", failures)
	_check(configured.transition(Flow.SONG_LIBRARY).get("code") == "session_active", "active session blocks navigation", failures)
	_check(configured.finish_session().get("state") == Flow.RESULTS and not configured.session_active(), "completed session transitions once to Results", failures)
	_check(configured.transition(Flow.GAMEPLAY).get("ok") and configured.begin_session().get("ok") and configured.finish_session().get("state") == Flow.RESULTS, "completed session can start the same song again without restarting the process", failures)
	var automation := Flow.new(); _check(automation.begin_session(true).get("ok") and automation.state() == Flow.GAMEPLAY, "CLI/replay automation uses product flow service", failures)
	var cleaned: Array[String] = []; var cleanup_flow := Flow.new(); cleanup_flow.register_resource("midi", func() -> void: cleaned.append("midi")); cleanup_flow.transition(Flow.DEVICE_SETUP)
	_check(cleaned == ["midi"], "transition cleans registered resources", failures)
	_check(cleanup_flow.register_resource("temporary-import", func() -> void: pass).get("ok") and cleanup_flow.register_resource("temporary-import", func() -> void: pass).get("code") == "duplicate_resource", "resource double registration rejected", failures)
	var recoverable := cleanup_flow.failure("import", "Import failed.", "zip traversal", true); _check(recoverable["severity"] == "recoverable" and recoverable["actions"] == ["retry", "cancel", "back"] and recoverable["technical_detail"] == "zip traversal", "recoverable error has explanation details and recovery actions", failures)
	var fatal := cleanup_flow.failure("settings", "Settings unavailable.", "permission denied", false); _check(fatal["severity"] == "fatal" and fatal["actions"].has("diagnostics") and not fatal["actions"].has("retry"), "fatal error stops with diagnostics", failures)
	var bad_settings := Flow.new().initial_route({"ok":false, "error":"permission"}, songs_empty); _check(bad_settings["severity"] == "fatal" and bad_settings["category"] == "settings", "settings startup error classified fatal", failures)
	_finish(failures, 18)

func _check(condition: bool, label: String, failures: Array[String]) -> void: if not condition: failures.append(label)
func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P212_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
