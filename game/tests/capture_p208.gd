extends SceneTree

const View := preload("res://presentation/song_library_view.gd")
const Files := preload("res://infrastructure/native_song_package_backend.gd")
const Library := preload("res://application/song_library_service.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args(); var index := arguments.find("--output"); if index < 0: quit(64); return
	var test_root := "/tmp/panbeat-p208-capture"; var files := Files.new(); files.remove_tree(test_root); DirAccess.make_dir_recursive_absolute(test_root)
	var repositories := Repositories.new(test_root.path_join("documents")); repositories.songs.save({"schema_version":"1.0.0", "songs":[{"song_id":"broken-demo", "import_version":1, "status":"invalid", "title":"Broken Import", "package_path":"packages/broken-demo/v1"}]})
	root.size = Vector2i(1280, 720); RenderingServer.set_default_clear_color(Color("101620"))
	var view := View.new(); view.repository_root = test_root.path_join("songs"); view.repositories = repositories; view.library = Library.new(files); root.add_child(view)
	for _frame: int in 5: await process_frame
	view._select_song_row(0); await process_frame
	var error := root.get_texture().get_image().save_png(arguments[index + 1]); files.remove_tree(test_root); quit(0 if error == OK else 1)
