extends SceneTree

const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const View := preload("res://presentation/radial_view.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output"); var mode_index := args.find("--mode")
	if output_index < 0 or mode_index < 0: quit(64); return
	root.size = Vector2i(1600,900); root.content_scale_size = Vector2i(1600,900); RenderingServer.set_default_clear_color(Color("0b0e16"))
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/package.json")))
	var loaded := ChartSource.load_chart(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/%s" % package["chart_file"])); var built := ChartFactory.build(loaded["chart"],profile,int(package["duration_us"]))
	var view := View.new(); view.configure(built["chart"],profile); view.set_preview_song_time_us(8_750_000); view.glow_enabled = true; view.combo_value = 27; root.add_child(view)
	for _frame: int in 5: await process_frame
	view.show_feedback("orbit-011","perfect"); view.show_feedback("orbit-012","great"); view.show_feedback("orbit-013","good"); view.show_feedback("orbit-014","miss")
	_add_label("P306 · TECHNIQUE / FEEDBACK / COMBO",Vector2(28,34),24); _add_label("LUMINOUS SHADER FIELD",Vector2(28,64),16)
	for _frame: int in 2: await process_frame
	var error := root.get_texture().get_image().save_png(args[output_index+1]); quit(0 if error == OK else 1)

func _add_label(value:String, position:Vector2, size:int) -> void:
	var label:=Label.new(); label.text=value; label.position=position; label.add_theme_font_size_override("font_size",size); root.add_child(label)
