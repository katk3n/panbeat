class_name DeviceSetupModel
extends RefCounted

static func lifecycle_status(lifecycle: Dictionary) -> Dictionary:
	match str(lifecycle.get("code", "")):
		"opened": return {"code":"ready", "label":"READY", "message":"MIDI input is open."}
		"no_ports": return {"code":"no_ports", "label":"NO MIDI PORTS", "message":"No MIDI ports were visible after opening CoreMIDI."}
		"open_failed": return {"code":"open_failed", "label":"OPEN FAILED", "message":"CoreMIDI reported ports but input opening failed."}
		"preferred_port_not_found": return {"code":"selected_port_missing", "label":"SELECTED PORT MISSING", "message":"The saved MIDI port is not currently listed."}
		_: return {"code":"not_ready", "label":"NOT READY", "message":"MIDI input is not ready."}

static func compatibility(selected_port: String, profile: Dictionary) -> Dictionary:
	if selected_port.is_empty(): return {"ok":false, "code":"device_not_selected", "message":"Select a MIDI port."}
	var model := str(profile.get("device", {}).get("model", ""))
	var token := model.split(" ")[-1] if not model.is_empty() else ""
	if token.is_empty(): return {"ok":false, "code":"profile_mismatch", "message":"Profile has no device model contract."}
	if token.to_lower() not in selected_port.to_lower(): return {"ok":false, "code":"unsupported_device", "profile_code":"profile_mismatch", "message":"Selected port does not match profile device %s." % model}
	return {"ok":true, "code":"compatible", "message":"Port matches %s." % model}

static func monitor_entry(raw: Dictionary, normalized: Dictionary) -> Dictionary:
	if normalized.get("kind") == "normalized_input":
		return {"status":"MAPPED", "technique":str(normalized.get("technique", "")).to_upper(), "target":str(normalized.get("target_id", "")), "velocity":int(normalized.get("velocity", 0)), "note":int(raw.get("data1", -1)), "message":"%s → %s" % [str(normalized.get("technique", "")).to_upper(), normalized.get("target_id", "")]}
	return {"status":"DIAGNOSTIC", "technique":"", "target":"", "velocity":int(raw.get("data2", 0)), "note":int(raw.get("data1", -1)), "message":"Unmapped MIDI note %s (%s)" % [raw.get("data1", "?"), normalized.get("code", "unknown")]}
