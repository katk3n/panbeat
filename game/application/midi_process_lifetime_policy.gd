class_name MidiProcessLifetimePolicy
extends RefCounted

var _open_claimed := false

func claim_driver_open() -> bool:
	if _open_claimed:
		return false
	_open_claimed = true
	return true

func close_driver_on_view_exit() -> bool:
	return false

func is_open_claimed() -> bool:
	return _open_claimed
