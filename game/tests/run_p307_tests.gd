extends SceneTree

const Hud := preload("res://presentation/gameplay_hud.gd")
const ScoreEngine := preload("res://domain/score_engine.gd")
const Main := preload("res://presentation/main.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var layout_720 := Hud.layout_for_size(Vector2(1280, 720))
	var layout_wide := Hud.layout_for_size(Vector2(1600, 720))
	_check(not layout_720["left"].intersects(layout_720["field_safe_rect"]), "720p left HUD clears field safe area", failures)
	_check(not layout_720["right"].intersects(layout_720["field_safe_rect"]), "720p right HUD clears field safe area", failures)
	_check(not layout_wide["left"].intersects(layout_wide["field_safe_rect"]) and not layout_wide["right"].intersects(layout_wide["field_safe_rect"]), "wide HUD clears field safe area", failures)
	_check(layout_720["left"].size.x >= 180.0 and layout_720["right"].end.x <= 1280.0, "720p panels retain usable width", failures)
	var rules := {"weights":{"perfect":1000,"great":750,"good":500,"miss":0,"extra_hit":0},"accuracy_weights":{"perfect":1.0,"great":0.75,"good":0.5,"miss":0.0,"extra_hit":0.0},"combo_increments":["perfect","great","good"],"combo_breaks":["miss","extra_hit"],"extra_hit_counts_toward_accuracy":false}
	var records: Array[Dictionary] = [{"grade":"perfect","delta_us":0},{"grade":"great","delta_us":-40_000}]
	var engine_hud := ScoreEngine.hud_model(records, rules)
	_check(engine_hud["current_score"] == 1750 and is_equal_approx(engine_hud["current_accuracy"], 0.875), "score and accuracy come from Score Engine HUD model", failures)
	_check(Hud.progress_ratio(-500_000, 10_000_000) == 0.0 and Hud.progress_ratio(5_000_000, 10_000_000) == 0.5 and Hud.progress_ratio(20_000_000, 10_000_000) == 1.0, "transport progress clamps at boundaries", failures)
	_check(Hud.format_time(0) == "0:00" and Hud.format_time(125_000_000) == "2:05", "time formatting boundaries", failures)
	var count_in := Hud.overlay_model("scheduled", -2_100_000)
	_check(count_in["visible"] and count_in["title"] == "3" and count_in["action"] == "Audio starts at zero", "count-in derives from negative transport time", failures)
	var paused := Hud.overlay_model("paused", 4_000_000)
	_check(paused["title"] == "PAUSED" and String(paused["action"]).contains("RESUME") and paused["pause_actions"], "pause exposes resume and interactive secondary actions", failures)
	var pause_contract := Hud.pause_action_contract()
	_check(pause_contract == {"resume":"space", "retry":"r", "song_library":"escape", "abandons_result":true, "process_restart_required":false}, "pause action contract uses in-process retry and safely abandons the current result", failures)
	var hud_view := Hud.new(); root.add_child(hud_view); hud_view.present({}, 4_000_000, "paused", "midi")
	_check(hud_view.get_node("PauseActions").visible and hud_view.get_node("PauseActions/RetryButton") is Button and hud_view.get_node("PauseActions/SongLibraryButton") is Button and hud_view.get_node("PauseActions/RetryButton").text.contains("R") and hud_view.get_node("PauseActions/SongLibraryButton").text.contains("ESC"), "paused HUD presents clickable retry and Song Library buttons with keyboard hints", failures)
	hud_view.present({}, 4_000_000, "playing", "midi"); _check(not hud_view.get_node("PauseActions").visible, "pause actions hide after resume", failures); hud_view.free()
	var failed := Hud.overlay_model("failed", 0, "audio backend unavailable")
	_check(failed["title"] == "PLAYBACK STOPPED" and String(failed["action"]).contains("RETRY") and failed["detail"] == "audio backend unavailable", "failure separates summary actions and detail", failures)
	var complete := Hud.overlay_model("completed", 10_000_000, "", true)
	_check(complete["title"] == "SONG COMPLETE" and String(complete["action"]).contains("RESULTS"), "complete announces Results transition", failures)
	_check(not Hud.overlay_model("playing", 1_000_000)["visible"], "playing has no obstructive state overlay", failures)
	_check(layout_wide["left"].size.x >= layout_720["left"].size.x, "wide layout never narrows title and maximum digit panels", failures)
	var title_rows := Hud.title_lines("A Very Long Handpan Song Title — Quiet Forge Session", 24)
	_check(title_rows.size() == 2 and title_rows[1].ends_with("…") and title_rows[0].length() <= 24 and title_rows[1].length() <= 24, "long title wraps to two bounded rows with explicit ellipsis", failures)
	var contract_complete := true
	for key: String in ["current_score","current_combo","current_accuracy","latest_grade","latest_direction"]:
		contract_complete = contract_complete and engine_hud.has(key)
	_check(contract_complete, "HUD contract contains all engine-derived performance fields", failures)
	hud_view = Hud.new(); hud_view.configure("Practice", 10_000_000, "70%"); _check(hud_view.practice_tempo_label == "70%", "HUD retains the active practice tempo label", failures); hud_view.free()
	var unavailable_input := Hud.input_status_model("midi_unavailable")
	_check(unavailable_input["label"].contains("MOOD PAN NOT CONNECTED") and unavailable_input["detail"].contains("MIDI ERROR") and unavailable_input["color"] == "error", "HUD keeps a persistent non-obstructive MIDI error in view-only Gameplay", failures)
	var no_midi_policy := Main.midi_startup_policy({"ok":false, "code":"no_ports"}); var ready_midi_policy := Main.midi_startup_policy({"ok":true, "code":"opened"})
	_check(no_midi_policy["allow_gameplay"] and not no_midi_policy["available"] and no_midi_policy["input_label"] == "midi_unavailable" and no_midi_policy["diagnostic"].contains("no_ports") and ready_midi_policy["available"], "MIDI startup errors permit view-only Gameplay while ready MIDI retains normal input", failures)
	_finish(failures, 21)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P307_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
