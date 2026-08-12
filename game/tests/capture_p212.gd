extends SceneTree

const View := preload("res://presentation/product_flow_view.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args(); var index := arguments.find("--output"); var error_index := arguments.find("--error-output"); if index < 0: quit(64); return
	var repository_root := "/tmp/panbeat-p212-capture"; _remove_tree(repository_root); var repositories := Repositories.new(repository_root, NativeBackend.new())
	repositories.settings.save({"schema_version":"1.0.0", "selected_midi_port":"", "profile_id":"roland-mn10-handpan-minor-v1", "offsets":[]}); repositories.songs.save({"schema_version":"1.0.0", "songs":[]})
	root.size = Vector2i(1280, 720); RenderingServer.set_default_clear_color(Color("101620")); var view := View.new(); view.repositories = repositories; root.add_child(view)
	for _frame: int in 8: await process_frame
	var error := root.get_texture().get_image().save_png(arguments[index + 1]); if error != OK: quit(1); return
	if error_index >= 0:
		view._show_error(view.flow.failure("audio", "Audio output became unavailable. Reconnect it and retry.", "AudioServer output device 'External DAC' disappeared during preload.", true)); await process_frame
		error = root.get_texture().get_image().save_png(arguments[error_index + 1])
	quit(0 if error == OK else 1)

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var directory := DirAccess.open(path); directory.include_hidden = true; directory.list_dir_begin()
	while true:
		var name := directory.get_next(); if name.is_empty(): break
		var child := path.path_join(name); if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
	directory.list_dir_end(); directory = null; DirAccess.remove_absolute(path)
