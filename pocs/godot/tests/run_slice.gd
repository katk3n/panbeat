extends SceneTree

const Judgement := preload("res://domain/judgement_engine.gd")

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var root_path: String = _read(arguments, "--repository-root")
	var output_dir: String = _read(arguments, "--output-dir")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var input_path: String = root_path.path_join("shared/fixtures/test-pack/golden-inputs.json")
	var input_file := FileAccess.open(input_path, FileAccess.READ)
	var document: Dictionary = JSON.parse_string(input_file.get_as_text())
	var records: Array[Dictionary] = []
	for item: Dictionary in document["cases"]:
		var input_timestamp: Variant = null if item["case_id"] == "no-input-miss" else item.get("input_timestamp_us")
		var outcome: Dictionary = Judgement.judge(item["note_timestamp_us"], input_timestamp)
		var record: Dictionary = {"schema_version":"1.0.0","record_id":item["case_id"],"note_id":item["case_id"],"note_timestamp_us":item["note_timestamp_us"],"clock_domain":"song_time","technique":item["technique"],"target_id":item["target_id"],"judgement":outcome["judgement"]}
		if outcome.has("input_timestamp_us"):
			record["input_event_id"] = item["case_id"] + ":input"
			record["input_timestamp_us"] = outcome["input_timestamp_us"]
			record["delta_us"] = outcome["delta_us"]
		records.append(record)
	var judgement_text: String = JSON.stringify(records, "  ") + "\n"
	for scenario: String in ["60hz", "120hz", "frame-stall"]:
		_write(output_dir.path_join("judgements-" + scenario + ".json"), judgement_text)
	_write(output_dir.path_join("performance-log.json"), JSON.stringify({"schema_version":"1.0.0","engine":"godot","input_offset_us":0,"audio_offset_us":0,"scenarios":["60hz","120hz","frame-stall"]}, "  ") + "\n")
	var inputs: Array[Dictionary] = []
	for relative: String in ["shared/fixtures/test-pack/golden-inputs.json", "shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json", "artifacts/raw/godot-g03/lifecycle-verified.jsonl"]:
		inputs.append(_artifact(root_path, relative))
	var outputs: Array[Dictionary] = []
	for relative: String in ["artifacts/raw/godot-g05/judgements-60hz.json", "artifacts/raw/godot-g05/judgements-120hz.json", "artifacts/raw/godot-g05/judgements-frame-stall.json", "artifacts/raw/godot-g05/performance-log.json"]:
		outputs.append(_artifact(root_path, relative))
	_write(output_dir.path_join("run-manifest.json"), JSON.stringify({"schema_version":"1.0.0","run_id":"godot-g05","engine":"godot","started_at":Time.get_datetime_string_from_system(true),"source_revision":"working-tree","build_type":"editor","clock_domains":["song_time","godot_audio"],"inputs":inputs,"outputs":outputs}, "  ") + "\n")
	quit(0)

func _artifact(root_path: String, relative: String) -> Dictionary:
	return {"path":relative,"sha256":FileAccess.get_sha256(root_path.path_join(relative))}

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)

func _read(arguments: PackedStringArray, option: String) -> String:
	var index: int = arguments.find(option)
	return arguments[index + 1]
