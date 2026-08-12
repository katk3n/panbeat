extends SceneTree

const LifetimePolicy := preload("res://application/midi_process_lifetime_policy.gd")

const MidiPorts := preload("res://application/midi_port_service.gd")
const DeviceModel := preload("res://application/device_setup_model.gd")
const Normalizer := preload("res://infrastructure/midi_normalizer.gd")

class LifecycleBackend extends RefCounted:
	var ports := PackedStringArray()
	var opened := false
	var allow_open := true
	var open_count := 0
	var close_count := 0
	var active_registrations := 0
	var max_registrations := 0
	var requires_open := true
	var now := 0
	func connected_ports() -> PackedStringArray: return ports.duplicate() if opened or not requires_open else PackedStringArray()
	func open_inputs() -> bool:
		open_count += 1
		if allow_open:
			opened = true; active_registrations = 1; max_registrations = maxi(max_registrations, active_registrations)
		return opened
	func close_inputs() -> void: close_count += 1; opened = false; active_registrations = 0
	func monotonic_us() -> int: now += 1; return now

func _initialize() -> void:
	var failures: Array[String] = []
	var profile := JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://config/default-instrument-profile.json"))) as Dictionary
	var backend := LifecycleBackend.new(); backend.ports = PackedStringArray(["MN-10"])
	var service := MidiPorts.new(backend, "MN-10")
	var opened := service.open()
	_check(opened.get("ok") and backend.open_count == 1 and service.ports() == PackedStringArray(["MN-10"]), "open before cold-start enumeration", failures)
	var reopened := service.reopen()
	_check(reopened.get("ok") and reopened.get("reopened") and backend.open_count == 2 and backend.max_registrations == 1 and backend.active_registrations == 1, "reopen has one registration and no duplicate", failures)
	_check(service.diagnostics.size() >= 3 and service.diagnostics.back().get("physical_disconnect_observable") == false, "lifecycle history records Godot disconnect limitation", failures)
	var no_ports_backend := LifecycleBackend.new()
	var no_ports := MidiPorts.new(no_ports_backend).open()
	_check(no_ports.get("code") == "no_ports" and DeviceModel.lifecycle_status(no_ports)["code"] == "no_ports", "no ports distinct status", failures)
	var failed_backend := LifecycleBackend.new(); failed_backend.ports = PackedStringArray(["MN-10"]); failed_backend.allow_open = false; failed_backend.requires_open = false
	var failed_open := MidiPorts.new(failed_backend).open()
	_check(failed_open.get("code") == "open_failed" and DeviceModel.lifecycle_status(failed_open)["code"] == "open_failed", "open failure distinct status", failures)
	var preferred_backend := LifecycleBackend.new(); preferred_backend.ports = PackedStringArray(["Other Device"])
	var preferred := MidiPorts.new(preferred_backend, "MN-10").open()
	_check(preferred.get("code") == "preferred_port_not_found", "saved port missing status", failures)
	var compatibility := DeviceModel.compatibility("Other Device", profile)
	_check(not compatibility.get("ok") and compatibility.get("code") == "unsupported_device" and compatibility.get("profile_code") == "profile_mismatch", "unsupported device and profile mismatch distinguished", failures)
	_check(DeviceModel.compatibility("Roland MN-10", profile).get("ok") == true, "canonical Mood Pan profile compatibility", failures)
	var expected := [{"note":57,"technique":"TONE","target":"tone-1"},{"note":50,"technique":"DING","target":"ding"},{"note":93,"technique":"SLAP","target":"outer-hit-radius"}]
	var mapped_all := true
	for item: Dictionary in expected:
		var raw := {"message_type":"note_on","arrival_timestamp_us":1,"channel_wire":0,"data1":item["note"],"data2":90}
		var monitor := DeviceModel.monitor_entry(raw, Normalizer.normalize(raw, profile))
		mapped_all = mapped_all and monitor["status"] == "MAPPED" and monitor["technique"] == item["technique"] and monitor["target"] == item["target"]
	_check(mapped_all, "input monitor displays normalized Tone Ding Slap and target", failures)
	var unknown_raw := {"message_type":"note_on","arrival_timestamp_us":1,"channel_wire":0,"data1":1,"data2":90}
	_check(DeviceModel.monitor_entry(unknown_raw, Normalizer.normalize(unknown_raw, profile))["status"] == "DIAGNOSTIC", "unmapped input remains diagnostic", failures)
	var lifetime := LifetimePolicy.new()
	_check(lifetime.claim_driver_open() and lifetime.is_open_claimed(), "process MIDI driver is opened on first ownership claim", failures)
	_check(not lifetime.claim_driver_open() and not lifetime.close_driver_on_view_exit(), "view transitions neither reopen nor close process MIDI driver", failures)
	_finish(failures, 12)

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)

func _finish(failures: Array[String], count: int) -> void:
	if failures.is_empty(): print("PANBEAT_P209_TESTS_OK %d/%d" % [count, count]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
