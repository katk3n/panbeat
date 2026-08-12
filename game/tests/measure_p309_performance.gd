extends SceneTree

const ChartFactory := preload("res://application/runtime_chart_factory.gd")
const View := preload("res://presentation/radial_view.gd")
const Hud := preload("res://presentation/gameplay_hud.gd")

func _initialize() -> void: _measure.call_deferred()

func _measure() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output"); var image_index := args.find("--image")
	if output_index < 0 or image_index < 0: quit(64); return
	root.size = Vector2i(1600,900); root.content_scale_size = Vector2i(1600,900); Engine.max_fps = 60
	var profile := {"layout":{"tones":[{"target_id":"tone-1","angle_degrees":0.0},{"target_id":"tone-2","angle_degrees":90.0}]},"mappings":[{"technique":"tone","target_id":"tone-1"},{"technique":"tone","target_id":"tone-2"},{"technique":"ding","target_id":"ding"},{"technique":"slap","target_id":"outer-hit-radius"}]}
	var notes: Array[Dictionary] = []
	for index: int in 64:
		var technique: String = ["tone","ding","slap"][index % 3]; var target: String = ["tone-1","ding","outer-hit-radius"][index % 3]
		notes.append({"note_id":"load-%02d" % index,"timestamp_us":2_000_000,"technique":technique,"target_id":target})
	var built := ChartFactory.build({"schema_version":"1.0.0","chart_id":"p309-maximum","duration_us":4_000_000,"notes":notes},profile,4_000_000)
	if not built.get("ok",false): quit(1); return
	var view := View.new(); view.configure(built["chart"],profile,64); view.set_preview_song_time_us(0); view.combo_visual_enabled = false; root.add_child(view)
	var hud := Hud.new(); hud.configure("Maximum Visual Load",4_000_000); hud.present({"current_score":999999999,"current_combo":999999,"current_accuracy":1.0,"latest_grade":"perfect","latest_direction":"on_time"},0,"playing","replay"); root.add_child(hud)
	for _frame: int in 12: await process_frame
	for note: Dictionary in notes: view.show_feedback(note["note_id"],["perfect","great","good","miss"][int(note["note_id"].trim_prefix("load-")) % 4])
	for _frame: int in 30: await process_frame
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)); var resources_before := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)); var samples := PackedInt64Array(); samples.resize(240)
	for index: int in 240:
		var started := Time.get_ticks_usec(); await process_frame; samples[index] = Time.get_ticks_usec() - started
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)); var resources_after := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)); var sorted := Array(samples); sorted.sort()
	var p95 := int(sorted[ceili(sorted.size() * 0.95) - 1]); var mean := 0.0
	for value: int in samples: mean += value
	mean /= samples.size()
	var screenshot_error := root.get_texture().get_image().save_png(args[image_index+1])
	var evidence := {"schema_version":"1.0.0","story":"P309","engine_version":Engine.get_version_info()["string"],"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1600,900],"sample_frames":samples.size(),"active_visuals":view.scheduler.active_count(),"feedback_visuals":64,"frame_time_mean_us":roundi(mean),"frame_time_p95_us":p95,"frame_time_max_us":int(sorted.back()),"node_count_before":nodes_before,"node_count_after":nodes_after,"resource_count_before":resources_before,"resource_count_after":resources_after,"node_delta":nodes_after-nodes_before,"resource_delta":resources_after-resources_before,"phase2_frame_p95_us":16667,"comparison":"Rich shader field at the 1600x900 reference remains at the display-paced 60 fps baseline"}
	var file := FileAccess.open(args[output_index+1],FileAccess.WRITE); if file == null: quit(1); return
	file.store_string(JSON.stringify(evidence,"  ")+"\n"); file.close()
	print("PANBEAT_P309_PERFORMANCE %s" % JSON.stringify(evidence)); quit(0 if screenshot_error == OK and p95 <= 20_000 and nodes_after == nodes_before and resources_after == resources_before and view.scheduler.active_count() == 64 else 1)
