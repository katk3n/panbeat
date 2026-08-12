extends SceneTree

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")
const Factory := preload("res://application/runtime_chart_factory.gd")
const Scheduler := preload("res://application/gameplay_note_scheduler.gd")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args(); var output_index := arguments.find("--output"); if output_index < 0: quit(64); return
	var note_count := 2000; var xml := _large_musicxml(note_count); var profile: Dictionary = _json("res://config/default-instrument-profile.json"); var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC)); var started := Time.get_ticks_usec()
	var parsed := Reader.read_bytes(xml.to_utf8_buffer(), "generated-p214.musicxml"); var compiled := Compiler.compile(parsed["score"], "p214-density"); var merged := Merger.merge(compiled["chart"], {}, FileAccess.get_sha256(ProjectSettings.globalize_path("res://../shared/fixtures/musicxml/p213-acceptance.musicxml")), profile, {}); var import_us := Time.get_ticks_usec() - started
	var runtime := Factory.build(merged["chart"], profile, int(merged["chart"]["duration_us"])); var scheduler := Scheduler.new(runtime["chart"], profile, 64, 2000000, 120000); var samples: Array[int] = []
	for frame: int in 5000:
		var frame_start := Time.get_ticks_usec(); scheduler.update(frame * 16667); samples.append(Time.get_ticks_usec() - frame_start)
	samples.sort(); var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC)); var file := FileAccess.open(arguments[output_index + 1], FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":"1.0.0", "fixture":{"kind":"generated MusicXML", "source_bytes":xml.to_utf8_buffer().size(), "notes":note_count, "tempo_bpm":120, "duration_us":merged["chart"]["duration_us"]}, "import":{"elapsed_us":import_us, "memory_static_before_bytes":memory_before, "memory_static_after_bytes":memory_after, "memory_static_delta_bytes":memory_after-memory_before}, "scheduler":{"frames":samples.size(), "frame_cost_p95_us":samples[_percentile_index(samples.size(), 0.95)], "frame_cost_p99_us":samples[_percentile_index(samples.size(), 0.99)], "frame_cost_max_us":samples.back(), "pool_capacity":64, "pool_overflow":scheduler.overflow_count, "activated":scheduler.activated_count}}, "  ") + "\n"); quit(0)

func _large_musicxml(note_count: int) -> String:
	var lines: Array[String] = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<score-partwise version=\"4.0\"><part-list><score-part id=\"P1\"><part-name>P214</part-name></score-part></part-list><part id=\"P1\">"]
	for measure: int in ceili(note_count / 4.0):
		lines.append("<measure number=\"%d\">" % (measure + 1)); if measure == 0: lines.append("<attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes><sound tempo=\"120\"/>")
		for beat: int in 4:
			if measure * 4 + beat >= note_count: break
			lines.append("<note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice></note>")
		lines.append("</measure>")
	lines.append("</part></score-partwise>"); return "".join(lines)

func _percentile_index(size: int, percentile: float) -> int: return mini(size - 1, maxi(0, ceili(size * percentile) - 1))
func _json(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))) as Dictionary
