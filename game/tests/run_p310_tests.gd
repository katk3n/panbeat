extends SceneTree

const Reader := preload("res://infrastructure/safe_musicxml_reader.gd")
const Compiler := preload("res://application/symbolic_score_compiler.gd")
const Merger := preload("res://application/panbeat_overlay_merger.gd")

const SUCCESS_RUNS := [
	"phase3-p302-ding-20260812t1530", "phase3-p303-rich-ui-v3-20260812",
	"phase3-p304-shell-20260812t1615", "phase3-p305-field-20260812t1640", "phase3-p306-runtime-background-v6-20260812",
	"phase3-p307-hud-20260812t1810", "phase3-p308-product-ux-20260812t1910", "phase3-p309-runtime-background-v9-20260812"
]

func _initialize() -> void:
	var failures: Array[String] = []
	var repository_root := ProjectSettings.globalize_path("res://..").simplify_path()
	for run_id: String in SUCCESS_RUNS:
		var path := repository_root.path_join("artifacts/raw/%s/run-manifest.json" % run_id)
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(value is Dictionary and value.get("status") in ["complete","approved"] and value.get("result","pass") == "pass", "%s successful manifest" % run_id, failures)
	var baseline_path := repository_root.path_join("artifacts/raw/phase3-p301-baseline-20260812t1455/run-manifest.json")
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	_check(baseline is Dictionary and baseline.get("status") == "awaiting-user-design-approval" and baseline.get("result") == "prepared-awaiting-user", "P301 baseline preserved before approval", failures)
	var approval_path := repository_root.path_join("artifacts/raw/phase3-p301-approval-20260812/run-manifest.json")
	var approval: Variant = JSON.parse_string(FileAccess.get_file_as_string(approval_path))
	_check(approval is Dictionary and approval.get("decision", {}).get("selected_option") == "quiet_forge" and approval.get("result") == "pass", "P301 Quiet Forge approval traceable", failures)
	var protocol := FileAccess.get_file_as_string(repository_root.path_join("docs/phase3-p310-real-device-protocol.md"))
	_check(protocol.contains("Real-device session") and not protocol.contains("Reduced Effects") and protocol.contains("visual-v6"), "real-device protocol covers the single high-quality visual session", failures)
	var report := FileAccess.get_file_as_string(repository_root.path_join("docs/phase3-completion-report.md"))
	_check(report.contains("PHASE 3 COMPLETE") and report.contains("R-P1-001") and report.contains("R-P1-003") and report.contains("does not authorize"), "completion report distinguishes Phase 3 acceptance and Final release blockers", failures)
	var device_observations := _json_file(repository_root.path_join("artifacts/raw/phase3-p310-device-visual-v6-20260812/session-observations.json"))
	_check(device_observations.get("status") == "complete" and device_observations.get("checks", {}).get("session_completed") == true and device_observations.get("checks", {}).get("background_shader_visible") == true, "real-device visual session is complete and traceable", failures)
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
	_finish(failures, 17)

func _json_file(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value as Dictionary if value is Dictionary else {}

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P310_TESTS_OK %d/%d" % [count, count]); quit(0); return
	for failure: String in failures: push_error(failure)
	quit(1)
