extends SceneTree

const DeviceSetup := preload("res://presentation/device_setup_view.gd")

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find("--output")
	if index < 0 or index + 1 >= arguments.size(): push_error("capture_p209 requires --output"); quit(64); return
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("101620"))
	root.add_child(DeviceSetup.new())
	for _frame: int in 4: await process_frame
	var error := root.get_texture().get_image().save_png(arguments[index + 1])
	quit(0 if error == OK else 1)
