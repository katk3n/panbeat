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
	func loading_state() -> Dictionary: return {"label":"LOADING — Reading local songs…"}
	func query(_root: String, _store: RefCounted, _profile: String) -> Dictionary:
		return {"label":"1 SONG READY", "songs":[{"song_id":"notepan-song", "title":"Schema Six Song", "artist":"NotePan Artist", "handpan_scale_name":"D Kurd 9", "duration_us":2_000_000, "chart_schema_version":"1.0.0", "profile_id":"roland-mn10-handpan-minor-v1", "profile_compatibility":"compatible", "artwork_label":"No artwork", "display_status":"warning", "playable":true, "import_version":1, "package_path":"notepan-song", "diagnostics":[{"severity":"warning", "code":"notepan_grace_simplified", "message":"Imported one grace-marked attack as a base gameplay attack.", "remediation":"Use MusicXML plus overlay if this distinction must affect gameplay."}]}]}

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output")
	if output_index < 0: quit(64); return
	var viewport_size := DisplayServer.window_get_size(); root.size = viewport_size; root.content_scale_size = viewport_size
	RenderingServer.set_default_clear_color(Color("0b0e16"))
	var view := SongView.new(); view.repositories = FakeRepositories.new(); view.library = FakeLibrary.new(); view.repository_root = "/tmp/panbeat-p401-capture"; root.add_child(view)
	for _frame: int in 3: await process_frame
	view._score_path = "/tmp/schema-six.pan"; view._score_button.text = "schema-six.pan"; view._update_score_options()
	view._list.select(0); view._on_selected(0)
	for _frame: int in 20: await process_frame
	await create_timer(1.0).timeout
	for _frame: int in 4: await process_frame
	var error := root.get_texture().get_image().save_png(args[output_index + 1]); quit(0 if error == OK else 1)
