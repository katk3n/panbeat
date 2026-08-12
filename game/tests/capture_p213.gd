extends SceneTree

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")
const Factory := preload("res://application/runtime_chart_factory.gd")
const View := preload("res://presentation/radial_view.gd")

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args(); var index := arguments.find("--output"); if index < 0: quit(64); return
	var score_path := ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance.musicxml"); var bytes := FileAccess.get_file_as_bytes(score_path); var parsed := Reader.read_bytes(bytes, score_path); var compiled := Compiler.compile(parsed["score"], "p213-acceptance")
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))); var overlay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance-overlay.json"))); var merged := Merger.merge(compiled["chart"], overlay, FileAccess.get_sha256(score_path), profile); var built := Factory.build(merged["chart"], profile, merged["chart"]["duration_us"])
	root.size = Vector2i(1280, 720); RenderingServer.set_default_clear_color(Color("0d121c")); var view := View.new(); view.configure(built["chart"], profile); view.set_preview_song_time_us(900000); root.add_child(view)
	_add_label("IMPORTED: P213 ACCEPTANCE", Vector2(28, 17), 24); _add_label("TONE · DING · SLAP    TEMPO 120 → 90    TIE MERGED", Vector2(28, 50), 18)
	for _frame: int in 3: await process_frame
	var error := root.get_texture().get_image().save_png(arguments[index + 1]); quit(0 if error == OK else 1)

func _add_label(text: String, position: Vector2, size: int) -> void:
	var label := Label.new(); label.text = text; label.position = position; label.add_theme_font_size_override("font_size", size); root.add_child(label)
