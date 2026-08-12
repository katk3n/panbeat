extends SceneTree

const RadialView := preload("res://presentation/radial_view.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")
const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var output_index: int = arguments.find("--output")
	if output_index < 0 or output_index + 1 >= arguments.size():
		push_error("capture_p112 requires --output PATH"); quit(64); return
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("0d121c"))
	var profile: Dictionary = Normalizer.load_profile(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))
	var loaded: Dictionary = ChartSource.load_chart(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/chart.json"))
	var built: Dictionary = ChartFactory.build(loaded["chart"], profile, 36_000_000)
	if not built.get("ok", false):
		push_error(JSON.stringify(built)); quit(1); return
	var view := RadialView.new()
	view.configure(built["chart"], profile)
	view.set_preview_song_time_us(10_000_000)
	root.add_child(view)
	_add_label("SCORE 12000    COMBO 12", Vector2(28, 17), 24, Color("f0f2f8"))
	_add_label("PERFECT  ON_TIME", Vector2(28, 50), 18, Color("f0f2f8"))
	_add_label("INPUT: REPLAY    SPACE: PAUSE / RESUME", Vector2(28, 680), 16, Color("b6bbc7"))
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(arguments[output_index + 1])
	quit(0 if error == OK else 1)

func _add_label(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	root.add_child(label)
