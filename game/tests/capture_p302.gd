extends SceneTree

const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const View := preload("res://presentation/radial_view.gd")

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args()
	var output_index := arguments.find("--output")
	if output_index < 0 or output_index + 1 >= arguments.size():
		quit(64)
		return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/package.json")))
	var loaded := ChartSource.load_chart(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/%s" % package["chart_file"]))
	var built := ChartFactory.build(loaded["chart"], profile, int(package["duration_us"]))
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("0b0e16"))
	var view := View.new()
	view.glow_enabled = false
	view.configure(built["chart"], profile)
	view.set_preview_song_time_us(8_750_000)
	root.add_child(view)
	_add_label("P302 · DING FULL-RING CONVERGENCE", Vector2(28, 32), 24)
	_add_label("8.750 s · Ding + Slap + Tone simultaneous lookahead", Vector2(28, 62), 17)
	for _frame: int in 4:
		await process_frame
	var error := root.get_texture().get_image().save_png(arguments[output_index + 1])
	quit(0 if error == OK else 1)

func _add_label(text: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	root.add_child(label)
