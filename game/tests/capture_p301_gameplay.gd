extends SceneTree

const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const View := preload("res://presentation/radial_view.gd")

const CAPTURE_TIME_US := 10_000_000

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args()
	var output_index := arguments.find("--output")
	if output_index < 0 or output_index + 1 >= arguments.size():
		push_error("capture_p301_gameplay requires --output PATH")
		quit(64)
		return
	var width := _integer_argument(arguments, "--width", 1280)
	var height := _integer_argument(arguments, "--height", 720)
	if width < 1280 or height < 720:
		push_error("capture_p301_gameplay requires at least 1280x720")
		quit(64)
		return
	var profile: Dictionary = _load_json("res://config/default-instrument-profile.json")
	var package: Dictionary = _load_json("res://content/phase1-fixed-song-v1/package.json")
	var chart_result: Dictionary = ChartSource.load_chart(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/%s" % package["chart_file"]))
	if not chart_result.get("ok", false):
		push_error("P301 chart load failed")
		quit(1)
		return
	var built: Dictionary = ChartFactory.build(chart_result["chart"], profile, int(package["duration_us"]))
	if not built.get("ok", false):
		push_error("P301 runtime chart build failed")
		quit(1)
		return
	root.size = Vector2i(width, height)
	root.content_scale_size = Vector2i(width, height)
	DisplayServer.window_set_size(Vector2i(width, height))
	RenderingServer.set_default_clear_color(Color("101620"))
	var view := View.new()
	view.monochrome = arguments.has("--monochrome")
	view.configure(built["chart"], profile)
	view.set_preview_song_time_us(CAPTURE_TIME_US)
	root.add_child(view)
	_add_label("PHASE 2 VISUAL BASELINE", Vector2(28, 20), 24)
	_add_label("FIXTURE orbit-practice · SONG TIME 10.000 s · AUDIO-BACKED RECORD", Vector2(28, 54), 16)
	_add_label("TONE / DING / SLAP · simultaneous lookahead · current rendering", Vector2(28, 80), 16)
	_add_label("COUNT-IN −1.000 s · PAUSE at 12.000 s · grades P/G/GOOD/MISS fixed in manifest", Vector2(28, height - 42), 15)
	for _frame: int in 4:
		await process_frame
	view.show_feedback("orbit-013", "perfect")
	view.show_feedback("orbit-014", "great")
	view.show_feedback("orbit-015", "good")
	view.show_feedback("orbit-016", "miss")
	await process_frame
	var error := root.get_texture().get_image().save_png(arguments[output_index + 1])
	quit(0 if error == OK else 1)

func _integer_argument(arguments: PackedStringArray, name: String, fallback: int) -> int:
	var index := arguments.find(name)
	return int(arguments[index + 1]) if index >= 0 and index + 1 < arguments.size() else fallback

func _load_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path)))
	return value as Dictionary if value is Dictionary else {}

func _add_label(text: String, position: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	root.add_child(label)
