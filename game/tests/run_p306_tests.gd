extends SceneTree

const View := preload("res://presentation/radial_view.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const Scheduler := preload("res://application/gameplay_note_scheduler.gd")
const RichBackground := preload("res://presentation/rich_ui_background.gd")
const NoteScrollSpeeds := preload("res://application/note_scroll_speed_catalog.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var perfect := View.feedback_style("perfect")
	var great := View.feedback_style("great")
	var good := View.feedback_style("good")
	var miss := View.feedback_style("miss")
	_check(perfect["rings"] == 1 and perfect["pattern"] == "single_impact" and perfect["label"] == "PERFECT" and perfect["color"] == "success", "Perfect is one strong impact ring", failures)
	_check(View.feedback_label_width("PERFECT") > 68.0 and View.feedback_label_width("PERFECT") >= ThemeDB.fallback_font.get_string_size("PERFECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 16.0, "Perfect label width includes safe horizontal padding", failures)
	_check(great["rings"] == 1 and great["pattern"] == "single_impact" and great["width"] < perfect["width"], "Great is one weaker impact ring", failures)
	_check(good["rings"] == 1 and good["pattern"] == "thin", "Good thin feedback", failures)
	_check(miss["rings"] == 0 and miss["pattern"] == "text_only" and miss["width"] == 0.0 and miss["label"] == "MISS", "Miss uses text only with no cross or ring", failures)
	_check(View.feedback_origin_for("tone", Vector2.ZERO, Vector2(1,2)) == Vector2(1,2), "Tone feedback local", failures)
	_check(View.feedback_origin_for("ding", Vector2.ZERO, Vector2(1,2)) == Vector2.ZERO, "Ding feedback central", failures)
	_check(View.feedback_origin_for("slap", Vector2.ZERO, Vector2(1,2)) == Vector2.ZERO, "Slap feedback central full radius", failures)
	_check(View.combo_stage(4) == 0 and View.combo_stage(5) == 1 and View.combo_stage(10) == 2 and View.combo_stage(25) == 3, "Combo thresholds", failures)
	var profile := {"layout":{"tones":[{"target_id":"tone-1","angle_degrees":0.0}]},"mappings":[{"technique":"tone","target_id":"tone-1"},{"technique":"ding","target_id":"ding"},{"technique":"slap","target_id":"outer-hit-radius"}]}
	var notes: Array[Dictionary] = []
	for index: int in 64:
		notes.append({"note_id":"note-%d" % index,"timestamp_us":2_000_000,"technique":["tone","ding","slap"][index % 3],"target_id":["tone-1","ding","outer-hit-radius"][index % 3]})
	var chart := {"schema_version":"1.0.0","chart_id":"p306-max","duration_us":4_000_000,"notes":notes}
	var built := ChartFactory.build(chart, profile, 4_000_000)
	_check(built.get("ok",false), "maximum fixture builds", failures)
	if built.get("ok",false):
		var scheduler := Scheduler.new(built["chart"], profile, 64)
		scheduler.update(0)
		_check(scheduler.active_count() == 64 and scheduler.overflow_count == 0, "maximum active fixture fits fixed pool", failures)
		var very_fast := Scheduler.new(built["chart"], profile, 64, NoteScrollSpeeds.preset("very_fast")["lookahead_us"])
		very_fast.update(0)
		_check(very_fast.active_count() == 0, "very fast speed keeps notes outside its shorter initial lookahead", failures)
		very_fast.update(1_000_000)
		_check(very_fast.active_count() == 64 and very_fast.lookahead_us() == 1_000_000, "very fast speed activates the same notes one second before judgement", failures)
		notes.append({"note_id":"overflow","timestamp_us":2_000_000,"technique":"ding","target_id":"ding"})
		var overflow_built := ChartFactory.build({"schema_version":"1.0.0","chart_id":"p306-overflow","duration_us":4_000_000,"notes":notes}, profile, 4_000_000)
		var overflow_scheduler := Scheduler.new(overflow_built["chart"], profile, 64); overflow_scheduler.update(0)
		_check(overflow_scheduler.overflow_count == 1, "pool overflow is observable", failures)
	var quality := View.visual_quality_contract()
	_check(quality["procedural_field_shader"] and quality["audio_time_driven_shader"] and quality["deterministic_shader"] and quality["note_bloom_shader"] == "integrated_sdf_gaussian" and quality["tone_note_shape"] == "foreground_emissive_orb" and quality["orb_shading"] == "saturated_cyan_center_hot_gradient" and quality["orb_draw_order"] == "above_handpan_and_targets" and quality["orb_bloom_strength"] == "strong_atmospheric_spill" and quality["bloom_profile"] == "luminous_core_diffused_mist_atmospheric_spill" and quality["bloom_shader_capacity"] == 16 and quality["normal_glow_layers"] == 1 and quality["smooth_bloom_falloff"] == "continuous_gaussian" and not quality["single_note_ring"] and not quality["hollow_note_core"] and not quality["black_note_core"] and not quality["white_impact_fill"] and not quality["impact_rays"] and quality["bloom_strength"] == "pronounced" and quality["hit_bloom_strength"] == "bright_surge" and quality["dense_load_threshold"] == 16 and quality["dense_load_halo_layers"] == 1, "foreground tone notes use saturated cyan center-hot gradients and strong atmospheric spill above the handpan", failures)
	_check(quality["handpan_material"] == "translucent_forged_copper" and is_equal_approx(quality["background_transmission"], 0.76) and quality["copper_patina"], "handpan uses recognizable translucent forged copper with patina", failures)
	_check(not quality["note_trails"] and quality["technique_palette"].size() == 3 and quality["reference_window"] == [1600,900] and quality["launch_mode"] == "maximized", "trail-free luminous orb palette and maximized window contract", failures)
	var background_quality := RichBackground.visual_contract()
	_check(background_quality["procedural_shader"] and background_quality["meditative_fog"] and background_quality["breathing_halo"] and background_quality["resonance_ripples"] and not background_quality["perspective_grid"] and not background_quality["particle_field"], "meditative shared UI shader background contract", failures)
	_check(quality["background_presets"].size() == 3 and quality["background_motion"] == "visible_audio_time" and quality["background_motion_strength"] == "dramatic" and quality["deep_resonance_identity"] == "jade_mist_caustics" and not quality["cyber_grid"] and not quality["static_outer_gold_ring"] and not quality["legacy_highlight_arc"] and quality["stretch_aspect"] == "expand", "three dramatically animated meditative backgrounds retain Deep Resonance identity and omit misleading decoration", failures)
	var main_source := FileAccess.get_file_as_string("res://presentation/main.gd")
	_check(main_source.contains("func _ready() -> void:\n\tsuper._ready()"), "application startup initializes the inherited gameplay field shader", failures)
	var speed_presets := NoteScrollSpeeds.all()
	_check(speed_presets.size() == 4 and speed_presets.map(func(value: Dictionary) -> String: return value["id"]) == ["slow", "normal", "fast", "very_fast"], "four stable scroll speed presets are exposed", failures)
	_check(NoteScrollSpeeds.preset("slow")["lookahead_us"] > NoteScrollSpeeds.preset("normal")["lookahead_us"] and NoteScrollSpeeds.preset("very_fast")["lookahead_us"] < NoteScrollSpeeds.preset("fast")["lookahead_us"], "faster presets use shorter visual lookahead", failures)
	var speed_settings := {"note_scroll_speed_id":"slow", "song_note_scroll_speeds":{"dense-song":"very_fast"}}
	_check(NoteScrollSpeeds.resolve({"song_id":"dense-song"}, speed_settings) == "very_fast" and NoteScrollSpeeds.resolve({"song_id":"other"}, speed_settings) == "slow", "per-song speed overrides the global preference", failures)
	_check(NoteScrollSpeeds.resolve({"song_id":"dense-song"}, speed_settings, "fast") == "fast" and NoteScrollSpeeds.resolve({}, {}) == "normal", "CLI override and safe default resolve", failures)
	var assigned_speed := NoteScrollSpeeds.assign_to_song(speed_settings, "new-song", "fast")
	_check(assigned_speed["song_note_scroll_speeds"]["new-song"] == "fast" and not speed_settings["song_note_scroll_speeds"].has("new-song"), "per-song speed assignment preserves the input settings", failures)
	var library_source := FileAccess.get_file_as_string("res://presentation/song_library_view.gd")
	_check(library_source.contains("NOTE SPEED") and library_source.contains("_on_note_scroll_speed_selected"), "Song Library exposes and persists note speed", failures)
	_finish(failures, 26)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P306_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
