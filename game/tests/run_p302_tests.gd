extends SceneTree

const Technique := preload("res://domain/input_technique.gd")
const Kinematics := preload("res://domain/note_visual_kinematics.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const Scheduler := preload("res://application/gameplay_note_scheduler.gd")
const RadialView := preload("res://presentation/radial_view.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var spawn := Kinematics.evaluate(Technique.Value.DING, 123.0, 1_000_000, 3_000_000, 1_000_000)
	var middle := Kinematics.evaluate(Technique.Value.DING, 123.0, 1_000_000, 3_000_000, 2_000_000)
	var hit := Kinematics.evaluate(Technique.Value.DING, 123.0, 1_000_000, 3_000_000, 3_000_000)
	var before_spawn := Kinematics.evaluate(Technique.Value.DING, 123.0, 1_000_000, 3_000_000, 0)
	var after_hit := Kinematics.evaluate(Technique.Value.DING, 123.0, 1_000_000, 3_000_000, 3_120_000)
	_check(is_equal_approx(spawn.x, Kinematics.SPAWN_RADIUS), "Ding starts on Spawn Ring", failures)
	_check(is_equal_approx(middle.x, 0.31), "Ding midpoint contracts linearly", failures)
	_check(is_equal_approx(hit.x, Kinematics.DING_HIT_RADIUS), "Ding hits central judgement ring", failures)
	_check(is_equal_approx(before_spawn.x, Kinematics.SPAWN_RADIUS), "Ding clamps before spawn", failures)
	_check(is_equal_approx(after_hit.x, Kinematics.DING_HIT_RADIUS), "Ding clamps after hit until retirement", failures)
	var tone_hit := Kinematics.evaluate(Technique.Value.TONE, 45.0, 1_000_000, 3_000_000, 3_000_000)
	var slap_hit := Kinematics.evaluate(Technique.Value.SLAP, 0.0, 1_000_000, 3_000_000, 3_000_000)
	_check(is_equal_approx(tone_hit.x, Kinematics.OUTER_HIT_RADIUS), "Tone remains local and outward", failures)
	_check(is_equal_approx(slap_hit.x, Kinematics.OUTER_HIT_RADIUS), "Slap remains full-ring and outward", failures)
	var center := Vector2(640, 360)
	_check(RadialView.feedback_origin_for("ding", center, Vector2(640, 100)) == center, "Ding feedback originates at center", failures)
	_check(RadialView.feedback_origin_for("tone", center, Vector2(640, 100)) == Vector2(640, 100), "Tone feedback remains local", failures)
	var profile := {"layout":{"tones":[{"target_id":"tone-1","angle_degrees":0.0}]}, "mappings":[{"technique":"ding","target_id":"ding"},{"technique":"tone","target_id":"tone-1"},{"technique":"slap","target_id":"outer-hit-radius"}]}
	var chart := {"schema_version":"1.0.0", "chart_id":"p302", "duration_us":4_000_000, "notes":[{"note_id":"ding","timestamp_us":2_000_000,"technique":"ding","target_id":"ding"},{"note_id":"tone","timestamp_us":2_000_000,"technique":"tone","target_id":"tone-1"},{"note_id":"slap","timestamp_us":2_000_000,"technique":"slap","target_id":"outer-hit-radius"}]}
	var built: Dictionary = ChartFactory.build(chart, profile, 4_000_000)
	_check(built.get("ok", false), "simultaneous chart builds", failures)
	if built.get("ok", false):
		var scheduler := Scheduler.new(built["chart"], profile, 3, 2_000_000, 120_000)
		scheduler.update(0)
		_check(scheduler.active_count() == 3 and scheduler.overflow_count == 0, "Ding Tone Slap coexist without overflow", failures)
		scheduler.update(2_120_000)
		_check(scheduler.active_count() == 3, "notes remain at retire boundary", failures)
		scheduler.update(2_120_001)
		_check(scheduler.active_count() == 0 and scheduler.retired_count == 3, "notes retire immediately after boundary", failures)
	_finish(failures, 13)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty():
		print("PANBEAT_P302_TESTS_OK %d/%d" % [count, count])
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
