class_name AtomicJsonStore
extends RefCounted

var _backend: RefCounted

func _init(backend: RefCounted) -> void:
	_backend = backend

func load_document(path: String) -> Dictionary:
	var primary := _load_one(path)
	if primary.get("ok", false): return primary
	var backup_path := path + ".bak"
	var backup := _load_one(backup_path)
	if backup.get("ok", false):
		backup["recovered_from_backup"] = true
		backup["primary_error"] = primary
		return backup
	return {"ok": false, "code": primary.get("code", "read_failed"), "error": primary.get("error", "document unavailable"), "path": path, "backup_error": backup}

func save_document(path: String, document: Dictionary) -> Dictionary:
	var parent := path.get_base_dir()
	var prepared: Dictionary = _backend.ensure_directory(parent)
	if not prepared.get("ok", false): return prepared
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	var cleanup: Dictionary = _backend.remove(temporary_path)
	if not cleanup.get("ok", false): return cleanup
	var text := JSON.stringify(document, "  ", false) + "\n"
	var written: Dictionary = _backend.write_text(temporary_path, text)
	if not written.get("ok", false): return written
	var staged := _load_one(temporary_path)
	if not staged.get("ok", false):
		_backend.remove(temporary_path)
		return {"ok": false, "code": "staging_validation_failed", "error": "staged JSON could not be read back", "detail": staged}
	var had_primary: bool = _backend.exists(path)
	if had_primary:
		var removed_backup: Dictionary = _backend.remove(backup_path)
		if not removed_backup.get("ok", false): return removed_backup
		var backed_up: Dictionary = _backend.rename(path, backup_path)
		if not backed_up.get("ok", false): return backed_up
	var published: Dictionary = _backend.rename(temporary_path, path)
	if not published.get("ok", false):
		if had_primary and _backend.exists(backup_path): _backend.rename(backup_path, path)
		return {"ok": false, "code": published.get("code", "atomic_replace_failed"), "error": published.get("error", "atomic replace failed"), "previous_restored": had_primary}
	return {"ok": true, "path": path, "backup_path": backup_path if had_primary else ""}

func delete_document(path: String) -> Dictionary:
	for suffix: String in ["", ".tmp", ".bak"]:
		var result: Dictionary = _backend.remove(path + suffix)
		if not result.get("ok", false): return result
	return {"ok": true, "path": path}

func _load_one(path: String) -> Dictionary:
	if not _backend.exists(path): return {"ok": false, "code": "not_found", "error": "document not found: %s" % path}
	var read: Dictionary = _backend.read_text(path)
	if not read.get("ok", false): return read
	var parser := JSON.new()
	var error := parser.parse(read.get("text", ""))
	if error != OK:
		return {"ok": false, "code": "corrupt_json", "error": "invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()], "path": path}
	if parser.data is not Dictionary:
		return {"ok": false, "code": "invalid_root", "error": "JSON root must be an object", "path": path}
	return {"ok": true, "document": parser.data as Dictionary, "path": path}
