extends SceneTree

const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const View := preload("res://presentation/radial_view.gd")
const Hud := preload("res://presentation/gameplay_hud.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output"); var mode_index := args.find("--mode"); var size_index := args.find("--size")
	if output_index < 0 or mode_index < 0 or size_index < 0: quit(64); return
	var mode: String = args[mode_index + 1]; var values := args[size_index + 1].split("x"); var viewport_size := Vector2i(int(values[0]),int(values[1]))
	var preset_index := args.find("--background-preset"); var preset_id := args[preset_index + 1] if preset_index >= 0 else "deep_resonance"
	var song_time_index := args.find("--song-time-us"); var song_time_us := int(args[song_time_index + 1]) if song_time_index >= 0 else 8_750_000
	root.content_scale_size = viewport_size; DisplayServer.window_set_size(viewport_size); root.size = viewport_size; RenderingServer.set_default_clear_color(Color("0b0e16"))
	await create_timer(0.35).timeout
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/package.json")))
	var loaded := ChartSource.load_chart(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/%s" % package["chart_file"])); var built := ChartFactory.build(loaded["chart"],profile,int(package["duration_us"]))
	var view := View.new(); view.configure(built["chart"],profile); view.set_preview_song_time_us(song_time_us); view.set_background_preset(preset_id); view.combo_visual_enabled = false
	view.glow_enabled = mode != "glow-off"; view.monochrome = mode == "monochrome"; view.high_contrast = mode == "high-contrast"; root.add_child(view)
	var hud := Hud.new(); hud.configure(package["title"],int(package["duration_us"])); hud.monochrome = view.monochrome; hud.high_contrast = view.high_contrast; root.add_child(hud)
	hud.present({"current_score":45000,"current_combo":41,"current_accuracy":0.985,"latest_grade":"perfect","latest_direction":"on_time"},song_time_us,"playing","midi")
	# A fresh macOS GL process may compile the canvas shader asynchronously.
	# Warm the renderer long enough that the first 1600x900 fixture cannot capture its clear frame.
	for _frame: int in 12: await process_frame
	if song_time_index < 0:
		for note_id: String in ["orbit-011","orbit-012","orbit-013","orbit-014"]: view.show_feedback(note_id,["perfect","great","good","miss"][["orbit-011","orbit-012","orbit-013","orbit-014"].find(note_id)])
	for _frame: int in 5: await process_frame
	view.queue_redraw(); await process_frame; RenderingServer.force_sync()
	var error := root.get_texture().get_image().save_png(args[output_index+1]); quit(0 if error == OK else 1)
