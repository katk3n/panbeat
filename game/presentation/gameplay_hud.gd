class_name GameplayHud
extends Node2D

signal pause_retry_requested
signal pause_song_library_requested

const Tokens := preload("res://presentation/ui_tokens.gd")
const AppTheme := preload("res://presentation/panbeat_theme.gd")
const FIELD_DISC_RADIUS_FACTOR := 0.47

var song_title: String = ""
var duration_us: int = 0
var practice_tempo_label: String = "100% · Original"
var score_hud: Dictionary = {"current_score":0, "current_combo":0, "current_accuracy":0.0, "latest_grade":"", "latest_direction":"none"}
var song_time_us: int = 0
var transport_state: String = "idle"
var input_label: String = ""
var technical_failure: String = ""
var results_pending: bool = false
var monochrome: bool = false
var high_contrast: bool = false
var _pause_actions: HBoxContainer

func _ready() -> void:
	_ensure_pause_actions()
	_sync_pause_actions()

func _ensure_pause_actions() -> void:
	if _pause_actions != null:
		return
	_pause_actions = HBoxContainer.new()
	_pause_actions.name = "PauseActions"
	_pause_actions.theme = AppTheme.shared()
	_pause_actions.add_theme_constant_override("separation", 12)
	_pause_actions.z_index = 50
	var retry := Button.new()
	retry.name = "RetryButton"
	retry.text = "↻  RETRY · R"
	retry.tooltip_text = "Restart this song from the beginning (R)"
	retry.custom_minimum_size = Vector2(150, 44)
	retry.pressed.connect(func() -> void: pause_retry_requested.emit())
	_pause_actions.add_child(retry)
	var song_library := Button.new()
	song_library.name = "SongLibraryButton"
	song_library.text = "SONG LIBRARY · ESC"
	song_library.tooltip_text = "Stop this session and choose another song (Esc)"
	song_library.custom_minimum_size = Vector2(180, 44)
	song_library.pressed.connect(func() -> void: pause_song_library_requested.emit())
	_pause_actions.add_child(song_library)
	add_child(_pause_actions)

func configure(title: String, song_duration_us: int, tempo_label: String = "100% · Original") -> void:
	song_title = title
	duration_us = maxi(song_duration_us, 0)
	practice_tempo_label = tempo_label
	queue_redraw()

func present(hud: Dictionary, now_us: int, state: String, input_name: String, failure_detail: String = "", complete: bool = false) -> void:
	_ensure_pause_actions()
	score_hud = hud
	song_time_us = now_us
	transport_state = state
	input_label = input_name
	technical_failure = failure_detail
	results_pending = complete
	_sync_pause_actions()
	queue_redraw()

func _sync_pause_actions() -> void:
	if _pause_actions == null:
		return
	_pause_actions.visible = transport_state == "paused" and technical_failure.is_empty() and not results_pending
	if not _pause_actions.visible or not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	_pause_actions.position = Vector2((viewport_size.x - 342.0) * 0.5, viewport_size.y * 0.5 + 48.0)

func _draw() -> void:
	var size := get_viewport_rect().size
	var layout := layout_for_size(size)
	var font := ThemeDB.fallback_font
	var primary := Color.WHITE if monochrome or high_contrast else Tokens.color("primary")
	var muted := Color("d0d0d0") if high_contrast else (Color("b8b8b8") if monochrome else Tokens.color("muted"))
	var accent := Color.WHITE if monochrome or high_contrast else Tokens.color("accent")
	_draw_panel(layout["left"])
	_draw_panel(layout["right"])
	var left: Rect2 = layout["left"]
	var right: Rect2 = layout["right"]
	draw_string(font, left.position + Vector2(18, 27), "NOW PLAYING", HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36, Tokens.FONT_SIZE["caption"], accent)
	var title_rows := title_lines(song_title, 24)
	for index: int in title_rows.size():
		draw_string(font, left.position + Vector2(18, 55 + index * 23), title_rows[index], HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36, Tokens.FONT_SIZE["label"], primary)
	draw_string(font, left.position + Vector2(18, 120), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36, Tokens.FONT_SIZE["caption"], muted)
	draw_string(font, left.position + Vector2(18, 159), str(int(score_hud.get("current_score", 0))), HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36, 34, primary)
	draw_string(font, left.position + Vector2(18, 198), "ACCURACY", HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36, Tokens.FONT_SIZE["caption"], muted)
	draw_string(font, left.position + Vector2(18, 232), "%.2f%%" % (float(score_hud.get("current_accuracy", 0.0)) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36, 28, primary)
	var progress := progress_ratio(song_time_us, duration_us)
	var track := Rect2(left.position + Vector2(18, 258), Vector2(left.size.x - 36, 5))
	draw_rect(track, Color(Tokens.color("line"), 0.35))
	draw_rect(Rect2(track.position, Vector2(track.size.x * progress, track.size.y)), accent)
	draw_string(font, left.position + Vector2(18, 289), "%s  /  %s" % [format_time(song_time_us), format_time(duration_us)], HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36, Tokens.FONT_SIZE["caption"], muted)

	draw_string(font, right.position + Vector2(18, 27), "COMBO", HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, Tokens.FONT_SIZE["caption"], muted)
	draw_string(font, right.position + Vector2(18, 73), str(int(score_hud.get("current_combo", 0))), HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, 42, accent)
	var grade := String(score_hud.get("latest_grade", "")).to_upper()
	if grade.is_empty(): grade = "—"
	draw_string(font, right.position + Vector2(18, 122), "LATEST", HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, Tokens.FONT_SIZE["caption"], muted)
	draw_string(font, right.position + Vector2(18, 158), grade, HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, 26, primary)
	draw_string(font, right.position + Vector2(18, 184), String(score_hud.get("latest_direction", "none")).replace("_", " ").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, Tokens.FONT_SIZE["caption"], muted)
	var input_status := input_status_model(input_label)
	var input_color: Color = primary if monochrome or high_contrast else Tokens.color(input_status["color"])
	var input_font_size := 12 if not str(input_status["detail"]).is_empty() else int(Tokens.FONT_SIZE["caption"])
	draw_string(font, right.position + Vector2(18, 233), input_status["label"], HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, input_font_size, input_color)
	var tempo_y := 263.0
	if not str(input_status["detail"]).is_empty():
		draw_string(font, right.position + Vector2(18, 254), input_status["detail"], HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, input_font_size, input_color)
		tempo_y = 284.0
	draw_string(font, right.position + Vector2(18, tempo_y), "TEMPO  %s" % practice_tempo_label, HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 36, Tokens.FONT_SIZE["caption"], accent)
	draw_string(font, Vector2(24, size.y - 22), "SPACE  PAUSE / RESUME", HORIZONTAL_ALIGNMENT_LEFT, 260, Tokens.FONT_SIZE["caption"], muted)

	var overlay := overlay_model(transport_state, song_time_us, technical_failure, results_pending)
	if overlay["visible"]:
		_draw_overlay(size, overlay)

func _draw_panel(rect: Rect2) -> void:
	var accent := Color.WHITE if monochrome or high_contrast else Tokens.color("accent")
	if not monochrome and not high_contrast:
		for spread: int in [18, 10, 4]:
			var expanded := rect.grow(float(spread))
			draw_rect(expanded, Color(accent, 0.012 + (18 - spread) * 0.002), false, 2.0)
	draw_rect(rect, Color("080808") if high_contrast else Color(Tokens.color("surface"), 0.94))
	draw_rect(rect, Color(accent, 0.34), false, 1.0)
	draw_line(rect.position, rect.position + Vector2(0, rect.size.y), accent, 3.0)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(accent, 0.72), 1.0)

func _draw_overlay(size: Vector2, overlay: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var width := minf(440.0, size.x - 48.0)
	var height := 220.0 if overlay.get("pause_actions", false) else (190.0 if not String(overlay["detail"]).is_empty() else 154.0)
	var rect := Rect2(Vector2((size.x - width) * 0.5, (size.y - height) * 0.5), Vector2(width, height))
	draw_rect(rect, Color(Tokens.color("surface_raised"), 0.97))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Tokens.color(overlay["color"]), 4.0)
	draw_string(font, rect.position + Vector2(24, 43), overlay["title"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 48, Tokens.FONT_SIZE["title"], Tokens.color("primary"))
	draw_string(font, rect.position + Vector2(24, 76), overlay["message"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 48, Tokens.FONT_SIZE["body"], Tokens.color("muted"))
	draw_string(font, rect.position + Vector2(24, 111), overlay["action"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 48, Tokens.FONT_SIZE["label"], Tokens.color(overlay["color"]))
	if not String(overlay["detail"]).is_empty():
		draw_string(font, rect.position + Vector2(24, 151), "DETAILS", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, Tokens.FONT_SIZE["caption"], Tokens.color("muted"))
		draw_string(font, rect.position + Vector2(24, 174), overlay["detail"], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, Tokens.FONT_SIZE["caption"], Tokens.color("muted"))

static func layout_for_size(size: Vector2) -> Dictionary:
	var short_side := minf(size.x, size.y)
	var disc_edge_left := size.x * 0.5 - short_side * FIELD_DISC_RADIUS_FACTOR
	var available := maxf(180.0, disc_edge_left - 64.0)
	var panel_width := minf(300.0, available)
	var panel_height := minf(350.0, size.y - 128.0)
	return {
		"left": Rect2(Vector2(24, 54), Vector2(panel_width, panel_height)),
		"right": Rect2(Vector2(size.x - 24 - panel_width, 54), Vector2(panel_width, panel_height)),
		"field_safe_rect": Rect2(Vector2(disc_edge_left, size.y * 0.5 - short_side * FIELD_DISC_RADIUS_FACTOR), Vector2(short_side * FIELD_DISC_RADIUS_FACTOR * 2.0, short_side * FIELD_DISC_RADIUS_FACTOR * 2.0))
	}

static func progress_ratio(now_us: int, song_duration_us: int) -> float:
	if song_duration_us <= 0: return 0.0
	return clampf(float(maxi(now_us, 0)) / float(song_duration_us), 0.0, 1.0)

static func input_status_model(input_name: String) -> Dictionary:
	match input_name:
		"midi": return {"label":"◆  MIDI READY", "detail":"", "color":"success"}
		"midi_unavailable": return {"label":"!  MOOD PAN NOT CONNECTED", "detail":"MIDI ERROR · VIEW ONLY", "color":"error"}
		_: return {"label":"◆  REPLAY INPUT", "detail":"", "color":"success"}

static func format_time(value_us: int) -> String:
	var seconds := maxi(value_us, 0) / 1_000_000
	return "%d:%02d" % [seconds / 60, seconds % 60]

static func title_lines(value: String, max_characters: int = 24) -> Array[String]:
	var rows: Array[String] = []
	var current := ""
	for word: String in value.split(" ", false):
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		if candidate.length() <= max_characters:
			current = candidate
		elif rows.is_empty():
			rows.append(current if not current.is_empty() else word.left(max_characters))
			current = word if not current.is_empty() else word.substr(max_characters)
		else:
			current = candidate
	if not current.is_empty(): rows.append(current)
	if rows.size() > 2:
		var second := rows[1]
		for index: int in range(2, rows.size()): second += " " + rows[index]
		rows.resize(2)
		rows[1] = second.left(maxi(1, max_characters - 1)).strip_edges() + "…"
	elif rows.size() == 2 and rows[1].length() > max_characters:
		rows[1] = rows[1].left(maxi(1, max_characters - 1)).strip_edges() + "…"
	return rows

static func overlay_model(state: String, now_us: int, failure_detail: String = "", complete: bool = false) -> Dictionary:
	if not failure_detail.is_empty():
		return {"visible":true, "title":"PLAYBACK STOPPED", "message":"Your session was stopped safely.", "action":"R  RETRY     ESC  EXIT", "detail":failure_detail, "color":"error"}
	if complete:
		return {"visible":true, "title":"SONG COMPLETE", "message":"Your performance has been saved.", "action":"OPENING RESULTS…", "detail":"", "color":"success"}
	if state == "scheduled":
		var beats := maxi(1, ceili(float(-now_us) / 1_000_000.0))
		return {"visible":true, "title":str(beats), "message":"GET READY", "action":"Audio starts at zero", "detail":"", "color":"accent"}
	if state == "paused":
		return {"visible":true, "title":"PAUSED", "message":"Playback and judgement are stopped.", "action":"SPACE  RESUME", "detail":"", "color":"accent", "pause_actions":true}
	return {"visible":false, "title":"", "message":"", "action":"", "detail":"", "color":"accent"}

static func pause_action_contract() -> Dictionary:
	return {"resume":"space", "retry":"r", "song_library":"escape", "abandons_result":true, "process_restart_required":false}
