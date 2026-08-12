class_name MidiPortService
extends RefCounted

var _backend: RefCounted
var _preferred_port: String
var _ports: PackedStringArray = []
var _is_open: bool = false
var diagnostics: Array[Dictionary] = []

func _init(backend: RefCounted, preferred_port: String = "") -> void:
	_backend = backend
	_preferred_port = preferred_port

func open() -> Dictionary:
	var backend_opened: bool = _backend.open_inputs()
	_ports = _backend.connected_ports()
	if _ports.is_empty():
		_backend.close_inputs()
		_is_open = false
		return _record("no_ports", false)
	if not _preferred_port.is_empty() and not _ports.has(_preferred_port):
		_backend.close_inputs()
		_is_open = false
		return _record("preferred_port_not_found", false)
	_is_open = backend_opened
	return _record("opened" if _is_open else "open_failed", _is_open)

func close() -> Dictionary:
	_backend.close_inputs()
	_is_open = false
	return _record("closed", true)

func refresh() -> Dictionary:
	var current: PackedStringArray = _backend.connected_ports()
	if current == _ports:
		return {"ok": true, "changed": false, "ports": Array(current)}
	close()
	_ports = current
	var opened: Dictionary = open()
	opened["changed"] = true
	return opened

func is_open() -> bool:
	return _is_open

func ports() -> PackedStringArray:
	return _ports.duplicate()

func _record(code: String, ok: bool) -> Dictionary:
	var record: Dictionary = {"timestamp_us": _backend.monotonic_us(), "code": code, "ok": ok, "ports": Array(_ports), "preferred_port": _preferred_port}
	diagnostics.append(record)
	return record
