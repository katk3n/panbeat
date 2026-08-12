class_name NativeFileBackend
extends RefCounted

func ensure_directory(path: String) -> Dictionary:
	var error := DirAccess.make_dir_recursive_absolute(path)
	return _result(error, "create directory", path)

func exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func read_text(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(FileAccess.get_open_error(), "read", path)
	return {"ok": true, "text": file.get_as_text()}

func write_text(path: String, text: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _result(FileAccess.get_open_error(), "write", path)
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	if error != OK:
		return _result(error, "flush", path)
	return {"ok": true}

func rename(from_path: String, to_path: String) -> Dictionary:
	return _result(DirAccess.rename_absolute(from_path, to_path), "rename", "%s -> %s" % [from_path, to_path])

func remove(path: String) -> Dictionary:
	if not exists(path): return {"ok": true}
	return _result(DirAccess.remove_absolute(path), "remove", path)

func _result(error: Error, operation: String, path: String) -> Dictionary:
	if error == OK: return {"ok": true}
	var code := "permission_denied" if error == ERR_FILE_NO_PERMISSION else "io_error"
	return {"ok": false, "code": code, "error": "%s failed for %s: %s" % [operation, path, error_string(error)], "error_code": error}
