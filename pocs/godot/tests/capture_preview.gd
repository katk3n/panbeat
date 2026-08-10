extends SceneTree

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = arguments.find("--output")
	if index < 0:
		quit(1)
		return
	var image := Image.create(768, 768, false, Image.FORMAT_RGBA8)
	image.fill(Color("0d121c"))
	_circle(image, Vector2i(384,384), 326, 3, Color("b4becd"))
	_circle(image, Vector2i(384,384), 173, 2, Color("505a69"))
	_circle(image, Vector2i(384,384), 261, 8, Color("f0f0f0"))
	_circle(image, Vector2i(576,230), 28, 7, Color("f0f0f0"))
	_circle(image, Vector2i(576,230), 47, 3, Color("969eaf"))
	_diamond(image, Vector2i(384,461), 34, Color("f0f0f0"))
	var error: Error = image.save_png(arguments[index + 1])
	quit(0 if error == OK else 1)

func _circle(image: Image, center: Vector2i, radius: int, thickness: int, color: Color) -> void:
	var inner: int = (radius - thickness) * (radius - thickness)
	var outer: int = (radius + thickness) * (radius + thickness)
	for y: int in range(center.y-radius-thickness, center.y+radius+thickness+1):
		for x: int in range(center.x-radius-thickness, center.x+radius+thickness+1):
			var distance: int = (x-center.x)*(x-center.x)+(y-center.y)*(y-center.y)
			if distance >= inner and distance <= outer:
				image.set_pixel(x, y, color)

func _diamond(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y: int in range(center.y-radius, center.y+radius+1):
		for x: int in range(center.x-radius, center.x+radius+1):
			if absi(x-center.x)+absi(y-center.y) <= radius:
				image.set_pixel(x, y, color)
