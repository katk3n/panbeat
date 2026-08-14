extends SceneTree

const View := preload("res://presentation/radial_view.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var geometry_720 := View.geometry_for_size(Vector2(1280, 720))
	var geometry_wide := View.geometry_for_size(Vector2(1728, 720))
	_check(geometry_720["short_side"] == 720.0 and geometry_wide["short_side"] == 720.0, "short-side geometry", failures)
	_check(geometry_720["outer_radius"] == geometry_wide["outer_radius"], "outer radius is circular", failures)
	_check(geometry_720["spawn_radius"] == 162.0 and geometry_wide["spawn_radius"] == 162.0, "spawn radius contract", failures)
	_check(not View.INSTRUMENT_DECORATION_RING_FACTORS.has(0.22) and View.INSTRUMENT_DECORATION_RING_FACTORS.all(func(factor: float) -> bool: return absf(factor - View.SPAWN_RADIUS_FACTOR) > 0.01), "Spawn Ring has no overlapping decoration ring", failures)
	_check(not View.INSTRUMENT_DECORATION_RING_FACTORS.has(0.11) and View.INSTRUMENT_DECORATION_RING_FACTORS.all(func(factor: float) -> bool: return absf(factor - View.DING_RADIUS_FACTOR) > 0.02), "Ding has no confusing nearby fixed decoration ring", failures)
	_check(is_equal_approx(720.0 * View.DING_RADIUS_FACTOR, 61.2), "Ding radius contract", failures)
	var top_720 := View.tone_center_for(geometry_720["center"], geometry_720["outer_radius"], 0.0)
	var top_wide := View.tone_center_for(geometry_wide["center"], geometry_wide["outer_radius"], 0.0)
	_check(is_equal_approx(top_720.y, top_wide.y), "Tone angle/radius stable across aspect", failures)
	_check(is_equal_approx(top_720.x, 640.0) and is_equal_approx(top_wide.x, 864.0), "Tone remains centered", failures)
	var right := View.tone_center_for(geometry_720["center"], geometry_720["outer_radius"], 90.0)
	_check(is_equal_approx(right.x, 946.0) and is_equal_approx(right.y, 360.0), "polar angle convention unchanged", failures)
	var layers := View.layer_contract()
	_check(layers["decoration_independent"] and layers["judgement_independent"], "layers independently switchable", failures)
	_check(layers["beat_pulse_independent"], "tempo pulse is independently switchable", failures)
	_check(layers["notes_always_visible"], "notes independent from optional layers", failures)
	_check(layers["material"] == "translucent_forged_copper" and is_equal_approx(layers["background_transmission"], 0.76) and layers["opaque_accessibility_fallback"], "recognizable translucent copper preserves background with an accessibility fallback", failures)
	_check(layers["per_frame_node_creation"] == 0 and layers["per_frame_resource_creation"] == 0, "no per-frame Node/resource creation", failures)
	var view := View.new(); view.decoration_enabled = false; view.judgement_layer_enabled = true; view.glow_enabled = false; view.monochrome = true
	_check(not view.decoration_enabled and view.judgement_layer_enabled and not view.glow_enabled and view.monochrome, "fallback switches compose", failures)
	var steady_beats := View.build_beat_times([{"start_us":0,"bpm_milli":120_000}], 2_000_000)
	_check(steady_beats == PackedInt64Array([0,500_000,1_000_000,1_500_000,2_000_000]), "120 BPM guide produces exact quarter-note hit times", failures)
	var changed_beats := View.build_beat_times([{"start_us":0,"bpm_milli":120_000},{"start_us":1_000_000,"bpm_milli":60_000}], 3_000_000)
	_check(changed_beats == PackedInt64Array([0,500_000,1_000_000,2_000_000,3_000_000]), "tempo change updates subsequent guide hit times", failures)
	_check(is_equal_approx(View.beat_pulse_progress(8_500_000, 9_000_000, 1_000_000), 0.5) and is_equal_approx(View.beat_pulse_progress(8_500_000, 9_000_000, 500_000), 0.0), "guide progress follows the selected note lookahead speed", failures)
	var split_radii := View.beat_pulse_radii(0.5, geometry_720["spawn_radius"], 720.0 * View.DING_RADIUS_FACTOR, geometry_720["outer_radius"])
	_check(is_equal_approx(split_radii.x, (geometry_720["spawn_radius"] + 720.0 * View.DING_RADIUS_FACTOR) * 0.5) and is_equal_approx(split_radii.y, (geometry_720["spawn_radius"] + geometry_720["outer_radius"]) * 0.5), "guide uses the same linear radial interpolation as Ding and Slap notes", failures)
	_check(View.build_beat_times([], 2_000_000).is_empty(), "chart without tempo does not show a beat pulse", failures)
	var no_tempo_chart := {"schema_version":"1.0.0","chart_id":"no-tempo-pulse","duration_us":2_000_000,"notes":[{"note_id":"ding","timestamp_us":1_000_000,"technique":"ding","target_id":"ding"}]}
	var no_tempo_runtime := ChartFactory.build(no_tempo_chart, {"mappings":[{"technique":"ding","target_id":"ding"}]}, 2_000_000)
	_check(no_tempo_runtime.get("ok", false) and no_tempo_runtime["chart"].tempo_map().is_empty(), "runtime chart preserves missing tempo instead of inventing a default", failures)
	var tempo_chart := {"schema_version":"1.0.0","chart_id":"tempo-pulse","duration_us":2_000_000,"tempo_map":[{"start_us":0,"bpm_milli":120_000},{"start_us":1_000_000,"bpm_milli":60_000}],"notes":[{"note_id":"ding","timestamp_us":1_000_000,"technique":"ding","target_id":"ding"}]}
	var tempo_runtime := ChartFactory.build(tempo_chart, {"mappings":[{"technique":"ding","target_id":"ding"}]}, 2_000_000)
	_check(tempo_runtime.get("ok", false) and tempo_runtime["chart"].tempo_map().size() == 2 and tempo_runtime["chart"].tempo_map()[1]["bpm_milli"] == 60_000, "runtime chart preserves validated tempo segments for the pulse", failures)
	view.free()
	_finish(failures, 22)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P305_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
