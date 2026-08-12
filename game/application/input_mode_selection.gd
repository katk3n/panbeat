class_name InputModeSelection
extends RefCounted

const MIDI: String = "midi"
const REPLAY: String = "replay"

static func from_arguments(arguments: PackedStringArray, default_mode: String = MIDI) -> Dictionary:
	var mode: String = default_mode
	var index: int = arguments.find("--input-mode")
	if index >= 0:
		if index + 1 >= arguments.size():
			return {"ok":false, "error":"--input-mode requires midi or replay"}
		mode = arguments[index + 1]
	for argument: String in arguments:
		if argument.begins_with("--input-mode="):
			mode = argument.trim_prefix("--input-mode=")
	if mode != MIDI and mode != REPLAY:
		return {"ok":false, "error":"unsupported input mode: %s" % mode}
	return {"ok":true, "mode":mode}
