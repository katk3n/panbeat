extends SceneTree

const View := preload("res://presentation/calibration_view.gd")
const Repositories := preload("res://infrastructure/user_data_repositories.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args(); var index := arguments.find("--output"); if index < 0: quit(64); return
	root.size = Vector2i(1280, 720); RenderingServer.set_default_clear_color(Color("101620")); var view := View.new(); view.repositories = Repositories.new("/tmp/panbeat-p210-capture", NativeBackend.new()); root.add_child(view)
	for _frame: int in 5: await process_frame
	view._samples = [
		CalibrationService.sample(1000000, 1040000, "hit", "roland-mn10-handpan-minor-v1", "Default Output"),
		CalibrationService.sample(2000000, 2042000, "hit", "roland-mn10-handpan-minor-v1", "Default Output"),
		CalibrationService.sample(3000000, -1, "miss", "roland-mn10-handpan-minor-v1", "Default Output")]
	view._refresh_samples(); view._status.text = "RETRY — Need at least 5 valid hits; Miss is excluded."; await process_frame
	var error := root.get_texture().get_image().save_png(arguments[index + 1]); quit(0 if error == OK else 1)
