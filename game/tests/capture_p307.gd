extends SceneTree

const ChartSource := preload("res://infrastructure/json_chart_source.gd")
const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const View := preload("res://presentation/radial_view.gd")
const Hud := preload("res://presentation/gameplay_hud.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output"); var state_index := args.find("--state"); var size_index := args.find("--size")
	if output_index < 0 or state_index < 0 or size_index < 0: quit(64); return
	var state: String = args[state_index + 1]
	var dimensions := args[size_index + 1].split("x")
	var viewport_size := Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.size = viewport_size; root.content_scale_size = viewport_size; RenderingServer.set_default_clear_color(Color("0b0e16"))
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json")))
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/package.json")))
	var loaded := ChartSource.load_chart(ProjectSettings.globalize_path("res://content/phase1-fixed-song-v1/%s" % package["chart_file"])); var built := ChartFactory.build(loaded["chart"], profile, int(package["duration_us"]))
	var view := View.new(); view.configure(built["chart"], profile); view.set_preview_song_time_us(8_750_000); view.combo_visual_enabled = false; root.add_child(view)
	var hud := Hud.new(); hud.configure("A Very Long Handpan Song Title — Quiet Forge Session" if viewport_size.x > 1280 else package["title"], int(package["duration_us"])); root.add_child(hud)
	var hud_values := {"current_score":999999999, "current_combo":999999, "current_accuracy":0.9987, "latest_grade":"perfect", "latest_direction":"early"}
	var detail := "audio backend unavailable · code AUDIO-07" if state == "failed" else ""
	var complete := state == "completed"
	var now := -2_100_000 if state == "scheduled" else 8_750_000
	var input_name := "midi_unavailable" if state == "midi-unavailable" else "midi"
	hud.present(hud_values, now, state, input_name, detail, complete)
	for _frame: int in 6: await process_frame
	var error := root.get_texture().get_image().save_png(args[output_index + 1]); quit(0 if error == OK else 1)
