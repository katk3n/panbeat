extends SceneTree

const View := preload("res://presentation/product_flow_view.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output"); var mode_index := args.find("--mode")
	if output_index < 0 or mode_index < 0: quit(64); return
	var repository_root := "/tmp/panbeat-p304-capture-%s" % args[mode_index + 1]
	_remove_tree(repository_root)
	var repositories := Repositories.new(repository_root, NativeBackend.new())
	repositories.settings.save({"schema_version":"1.0.0", "selected_midi_port":"", "profile_id":"roland-mn10-handpan-minor-v1", "offsets":[]})
	repositories.songs.save({"schema_version":"1.0.0", "songs":[]})
	var viewport_size := DisplayServer.window_get_size()
	root.size = viewport_size; root.content_scale_size = viewport_size; RenderingServer.set_default_clear_color(Color("0b0e16"))
	var view := View.new(); view.repositories = repositories; root.add_child(view)
	for _frame: int in 12: await process_frame
	if args[mode_index + 1] == "error":
		view._show_error(view.flow.failure("audio", "Audio output became unavailable. Reconnect it and retry.", "AudioServer output device 'External DAC' disappeared during preload.", true))
		for _frame: int in 4: await process_frame
	var error := root.get_texture().get_image().save_png(args[output_index + 1])
	_remove_tree(repository_root)
	quit(0 if error == OK else 1)

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var directory := DirAccess.open(path); directory.include_hidden = true; directory.list_dir_begin()
	while true:
		var name := directory.get_next(); if name.is_empty(): break
		var child := directory.get_current_dir().path_join(name)
		if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
	directory.list_dir_end(); directory = null; DirAccess.remove_absolute(path)
