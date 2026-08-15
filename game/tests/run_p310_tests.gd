extends SceneTree

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var repository_root := ProjectSettings.globalize_path("res://..").simplify_path()
	var decision := FileAccess.get_file_as_string(repository_root.path_join("docs/phase3-p301-design-decision.md"))
	_check(decision.contains("Quiet Forge") and decision.contains("Status: approved"), "P301 Quiet Forge approval remains documented", failures)
	var protocol := FileAccess.get_file_as_string(repository_root.path_join("docs/phase3-p310-real-device-protocol.md"))
	_check(protocol.contains("Real-device session — High-quality visual mode") and not protocol.contains("Reduced Effects") and protocol.contains("実機受入れは2026-08-12に完了"), "real-device protocol covers the completed high-quality visual session", failures)
	var report := FileAccess.get_file_as_string(repository_root.path_join("docs/phase3-completion-report.md"))
	var all_stories_traceable := true
	for story_index: int in range(301, 311): all_stories_traceable = all_stories_traceable and report.contains("| P%d |" % story_index)
	_check(report.contains("PHASE 3 COMPLETE") and all_stories_traceable and report.contains("scripts/check-phase3-p310"), "completion report preserves committed P301-P310 traceability", failures)
	_check(report.contains("R-P1-001") and report.contains("R-P1-003") and report.contains("正式release"), "completion report does not turn Phase 3 acceptance into formal release approval", failures)
	var final_plan := FileAccess.get_file_as_string(repository_root.path_join("docs/final-phase-stories.md"))
	_check(final_plan.contains("NOT PLANNED") and final_plan.contains("R-P1-001") and final_plan.contains("R-P1-003"), "current closeout decision retains unresolved performance constraints without scheduling Final Phase", failures)
	var score_path := repository_root.path_join("shared/fixtures/musicxml/p310-real-device.musicxml")
	var overlay_path := repository_root.path_join("shared/fixtures/musicxml/p310-real-device-overlay.json")
	var parsed := Reader.read_bytes(FileAccess.get_file_as_bytes(score_path), score_path)
	var compiled := Compiler.compile(parsed.get("score"), "p310-real-device") if parsed.get("ok", false) else {"ok":false}
	var merged := Merger.merge(compiled.get("chart"), _json_file(overlay_path), FileAccess.get_sha256(score_path), _json_file(repository_root.path_join("game/config/default-instrument-profile.json"))) if compiled.get("ok", false) else {"ok":false}
	var notes: Array = merged.get("chart", {}).get("notes", [])
	_check(merged.get("ok", false) and notes.size() == 32, "real-device score imports as 32 playable notes", failures)
	var acceptance_audio := load("res://content/phase1-fixed-song-v1/orbit-practice.wav") as AudioStream
	var audio_duration_us := roundi(acceptance_audio.get_length() * 1_000_000.0) if acceptance_audio != null else 0
	_check(not notes.is_empty() and notes.front()["timestamp_us"] == 2_000_000 and notes.back()["timestamp_us"] == 33_000_000 and merged["chart"]["duration_us"] == 34_000_000 and audio_duration_us == 36_000_000, "score spans count-in through the matching audio ending margin", failures)
	var techniques: Array[String] = []; var maximum_gap_us := 0
	for index: int in notes.size():
		techniques.append(notes[index]["technique"])
		if index > 0: maximum_gap_us = maxi(maximum_gap_us, int(notes[index]["timestamp_us"]) - int(notes[index - 1]["timestamp_us"]))
	_check(techniques.has("tone") and techniques.has("ding") and techniques.has("slap") and maximum_gap_us <= 1_000_000, "Tone Ding and Slap remain playable without a long empty section", failures)
	_check(protocol.contains("p310-real-device.musicxml") and protocol.contains("Re-import"), "protocol selects the extended score and replaces the short import", failures)
	_finish(failures, 9)

func _json_file(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value as Dictionary if value is Dictionary else {}

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P310_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
