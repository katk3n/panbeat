extends SceneTree

const SongView := preload("res://presentation/song_library_view.gd")

class MemoryStore extends RefCounted:
	var document: Dictionary
	func _init(value: Dictionary) -> void: document = value
	func load() -> Dictionary: return {"ok":true, "document":document.duplicate(true)}
	func save(value: Dictionary) -> Dictionary: document = value.duplicate(true); return {"ok":true}

class FakeRepositories extends RefCounted:
	var settings := MemoryStore.new({"schema_version":"1.0.0", "selected_midi_port":"", "profile_id":"roland-mn10-handpan-minor-v1", "offsets":[]})
	var results := MemoryStore.new({"schema_version":"1.0.0", "max_records":100, "records":[]})
	var songs := MemoryStore.new({"schema_version":"1.0.0", "songs":[]})

class FakeLibrary extends RefCounted:
	var legacy := false
	var warnings := false
	func loading_state() -> Dictionary: return {"label":"LOADING — Reading local songs…"}
	func query(_root: String, _store: RefCounted, _profile: String) -> Dictionary:
		var layout := {"layout_version":"1.0.0", "strategy":"lowest-ding-ascending-zigzag-v1", "layout_id":"0".repeat(64), "slots":[
			{"technique":"ding", "target_id":"ding", "midi_note":52, "display_names":["E3"]},
			{"technique":"tone", "target_id":"tone-1", "midi_note":59, "display_names":["B3"]},
			{"technique":"tone", "target_id":"tone-2", "midi_note":60, "display_names":["C4"]},
			{"technique":"tone", "target_id":"tone-3", "midi_note":64, "display_names":["E4"]},
			{"technique":"tone", "target_id":"tone-4", "midi_note":66, "display_names":["F♯4"]},
			{"technique":"tone", "target_id":"tone-5", "midi_note":67, "display_names":["G4"]},
			{"technique":"tone", "target_id":"tone-6", "midi_note":71, "display_names":["B4"]}
		]}
		var diagnostics := [
			{"severity":"warning", "code":"notepan_nuance_simplified", "message":"Imported 127 nuance-marked attacks as base gameplay attacks.", "remediation":"Use MusicXML plus overlay if this distinction must affect gameplay."},
			{"severity":"warning", "code":"notepan_tempo_collision_resolved", "message":"Resolved 1 same-tick tempo collision using the later variation.", "remediation":"No action is required unless playback timing differs from NotePan."},
		] if warnings else []
		return {"label":"1 SONG READY", "songs":[{"song_id":"e-amara", "title":"Northern Light", "artist":"PanBeat Studio", "handpan_scale_name":"E Amara 9", "performance_layout":{} if legacy else layout, "duration_us":96_000_000, "chart_schema_version":"1.0.0", "profile_id":"roland-mn10-handpan-minor-v1", "profile_compatibility":"compatible", "artwork_label":"No artwork", "display_status":"warning" if warnings else "valid", "playable":true, "import_version":1, "package_path":"e-amara", "diagnostics":diagnostics}]}

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output")
	if output_index < 0: quit(64); return
	var viewport_size := DisplayServer.window_get_size(); root.size = viewport_size; root.content_scale_size = viewport_size; RenderingServer.set_default_clear_color(Color("0b0e16"))
	var fake_library := FakeLibrary.new(); fake_library.legacy = args.has("--legacy"); fake_library.warnings = args.has("--warnings")
	var view := SongView.new(); view.repositories = FakeRepositories.new(); view.library = fake_library; view.repository_root = "/tmp/panbeat-p402-capture"; root.add_child(view)
	for _frame: int in 5: await process_frame
	if args.has("--long-files"):
		view._apply_chosen_file("score", "/scores/New York - Sam Maher - D kurd with a very long filename.pan")
		view._apply_chosen_file("audio", "/audio/New York - Sam Maher - D kurd with a very long filename.wav")
	view._select_song_row(0)
	if not fake_library.legacy: view._on_layout_midi_record({"message_type":"note_on", "data1":60, "data2":96}, {})
	if args.has("--modal"):
		view._open_import_dialog(false)
		if args.has("--import-error"):
			view._show_import_error("IMPORT FAILED\nperformance_layout_capacity_exceeded: The song requires more than nine distinct pitched sounds; Mood Pan supports Ding plus eight Tone fields.\nFix: Use a score with at most one Ding and eight distinct Tone pitches, then import again.")
			for _frame: int in 3: await process_frame
			view._import_scroll.scroll_vertical = int(view._import_scroll.get_v_scroll_bar().max_value)
	for _frame: int in 20: await process_frame
	await create_timer(1.0).timeout
	for _frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(args[output_index + 1]); quit(0 if error == OK else 1)
