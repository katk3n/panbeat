extends SceneTree

const SongView := preload("res://presentation/song_library_view.gd")
const DeviceView := preload("res://presentation/device_setup_view.gd")
const CalibrationView := preload("res://presentation/calibration_view.gd")
const ResultsView := preload("res://presentation/results_view.gd")
const Presenter := preload("res://presentation/product_screen_presenter.gd")
const AppTheme := preload("res://presentation/panbeat_theme.gd")

class MemoryStore extends RefCounted:
	var document: Dictionary
	func _init(value: Dictionary) -> void: document = value
	func load() -> Dictionary: return {"ok":true,"document":document.duplicate(true)}
	func save(value: Dictionary) -> Dictionary: document = value.duplicate(true); return {"ok":true}

class FakeRepositories extends RefCounted:
	var settings: RefCounted
	var results: RefCounted
	var songs: RefCounted
	func _init(result_records: Array = []) -> void:
		settings = MemoryStore.new({"schema_version":"1.0.0","selected_midi_port":"","profile_id":"roland-mn10-handpan-minor-v1","offsets":[]})
		results = MemoryStore.new({"schema_version":"1.0.0","max_records":100,"records":result_records})
		songs = MemoryStore.new({"schema_version":"1.0.0","songs":[]})

class FakeLibrary extends RefCounted:
	func loading_state() -> Dictionary: return {"label":"LOADING — Reading local songs…"}
	func query(_root: String, _store: RefCounted, _profile: String) -> Dictionary:
		return {"label":"1 SONG READY","songs":[{"song_id":"quiet-forge","title":"Quiet Forge Etude","artist":"PanBeat Studio","handpan_scale_name":"D Kurd 9","duration_us":96_000_000,"chart_schema_version":"1.0.0","profile_id":"roland-mn10-handpan-minor-v1","profile_compatibility":"compatible","artwork_label":"No artwork","display_status":"valid","playable":true,"import_version":1,"package_path":"quiet-forge","diagnostics":[]}]}

class FakeAdapter extends Node:
	signal record_received(raw: Dictionary, normalized: Dictionary)
	var profile: Dictionary = {}
	var preferred_port := ""
	var lifecycle_diagnostics: Array[Dictionary] = [{"ok":false,"code":"no_ports","ports":[]}]
	func ports() -> PackedStringArray: return PackedStringArray()
	func reopen() -> Dictionary: return {"ok":false,"code":"no_ports"}
	func select_port(_name: String) -> Dictionary: return {"ok":false}

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output"); var mode_index := args.find("--mode")
	if output_index < 0 or mode_index < 0: quit(64); return
	var viewport_size := DisplayServer.window_get_size()
	root.size = viewport_size; root.content_scale_size = viewport_size; RenderingServer.set_default_clear_color(Color("0b0e16"))
	var mode: String = args[mode_index + 1]
	match mode:
		"songs":
			var view := SongView.new(); view.repositories = FakeRepositories.new(); view.library = FakeLibrary.new(); view.repository_root = "/tmp/panbeat-p308-fixture"; root.add_child(view)
			for _frame: int in 3: await process_frame
			view._list.select(0); view._on_selected(0)
		"device":
			var view := DeviceView.new(); view.repositories = FakeRepositories.new(); view._adapter = FakeAdapter.new(); root.add_child(view)
		"calibration":
			var view := CalibrationView.new(); view.repositories = FakeRepositories.new(); view._adapter = FakeAdapter.new(); root.add_child(view)
			for _frame: int in 2: await process_frame
			view._analyze()
		"results", "results-confirm":
			var view := ResultsView.new(); view.repositories = FakeRepositories.new([_result_record()]); view.completion_actions_enabled = true; root.add_child(view)
			for _frame: int in 2: await process_frame
			if mode == "results-confirm": view._delete_selected()
		_:
			_build_states()
	for _frame: int in 6: await process_frame
	var error := root.get_texture().get_image().save_png(args[output_index + 1]); quit(0 if error == OK else 1)

func _build_states() -> void:
	var background := ColorRect.new(); background.color = Color("0b0e16"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(background)
	var layout := VBoxContainer.new(); layout.position = Vector2(40,36); layout.size = Vector2(1200,640); layout.theme = AppTheme.shared(); root.add_child(layout)
	var title := Label.new(); title.text = "PRODUCT STATE FIXTURES"; title.add_theme_font_size_override("font_size",30); layout.add_child(title)
	for kind: String in ["loading","empty","disabled","warning","error"]:
		var fixture := Presenter.state_fixture(kind); var panel := PanelContainer.new(); panel.custom_minimum_size.y = 88; panel.theme_type_variation = "%sPanel" % String(fixture["tone"]).capitalize(); var row := HBoxContainer.new(); panel.add_child(row)
		var copy := Label.new(); copy.text = "%s\n%s" % [fixture["label"],fixture["message"]]; copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(copy)
		var action := Button.new(); action.text = "Retry" if fixture["action_enabled"] else "Unavailable"; action.disabled = not fixture["action_enabled"]; action.custom_minimum_size.x = 150; row.add_child(action); layout.add_child(panel)

func _result_record() -> Dictionary:
	return {"schema_version":"1.0.0","result_id":"quiet-forge-20260812","completed_at":"2026-08-12T09:10:00Z","metadata":{"song_id":"quiet-forge","importer_version":"1.0.0","chart_version":"1.0.0","profile_id":"roland-mn10-handpan-minor-v1","judgement_rule_id":"standard-v1","score_rule_id":"standard-v1"},"summary":{"score":45000,"accuracy":0.985,"combo":0,"max_combo":41,"latest_grade":"perfect","latest_direction":"on_time","breakdown":{"perfect":40,"great":3,"good":1,"miss":1,"extra_hit":0}},"timing_distribution":{"sample_count":45,"median_delta_us":4000,"early_count":8,"on_time_count":26,"late_count":11},"error_breakdown":{"wrong_target":1,"wrong_technique":0,"no_candidate":0},"judgements":[]}
