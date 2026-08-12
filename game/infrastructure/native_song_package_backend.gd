class_name NativeSongPackageBackend
extends RefCounted

func inspect_file(path: String, extensions: Array, max_bytes: int) -> Dictionary:
	if not FileAccess.file_exists(path): return _failed("source_not_found", path, "Source file does not exist.", "Choose an existing readable file.")
	var extension := "." + path.get_extension().to_lower()
	if not extensions.has(extension): return _failed("unsupported_extension", path, "Unsupported extension: %s" % extension, "Choose one of: %s" % str(extensions))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failed("source_open_failed", path, "Source file could not be opened.", "Check file permissions.")
	var size := file.get_length()
	if size > max_bytes: return _failed("source_size_limit", path, "Source exceeds %d bytes." % max_bytes, "Choose a smaller file.")
	var bytes := file.get_buffer(size)
	return {"ok":true, "path":path, "extension":extension, "bytes":bytes, "size":size, "sha256":hash_bytes(bytes)}

func read_json(path: String, max_bytes: int) -> Dictionary:
	var inspected := inspect_file(path, [".json"], max_bytes)
	if not inspected.get("ok", false): return inspected
	var parser := JSON.new()
	var error := parser.parse((inspected["bytes"] as PackedByteArray).get_string_from_utf8())
	if error != OK or parser.data is not Dictionary: return _failed("invalid_json", path, "JSON object expected at line %d: %s" % [parser.get_error_line(), parser.get_error_message()], "Correct the JSON document.")
	inspected["document"] = parser.data
	return inspected

func create_staging(root: String, token: String) -> Dictionary:
	var staging_root := root.path_join(".staging")
	var prepared := DirAccess.make_dir_recursive_absolute(staging_root)
	if prepared != OK: return _io_failed("staging_create_failed", staging_root, prepared)
	var path := staging_root.path_join(token)
	if DirAccess.dir_exists_absolute(path):
		var removed := remove_tree(path)
		if not removed.get("ok", false): return removed
	var made := DirAccess.make_dir_recursive_absolute(path)
	if made != OK: return _io_failed("staging_create_failed", path, made)
	return {"ok":true, "path":path}

func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
	var parent_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if parent_error != OK: return _io_failed("package_write_failed", path.get_base_dir(), parent_error)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _failed("package_write_failed", path, "Could not create package file.", "Check storage permissions and free space.")
	file.store_buffer(bytes); file.flush()
	if file.get_error() != OK: return _io_failed("package_write_failed", path, file.get_error())
	return {"ok":true, "path":path}

func write_text(path: String, text: String) -> Dictionary:
	return write_bytes(path, text.to_utf8_buffer())

func publish(staging: String, destination: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(destination): return _failed("package_already_exists", destination, "The immutable package version already exists.", "Re-import identical content as a duplicate or use a new import version.")
	var prepared := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if prepared != OK: return _io_failed("package_publish_failed", destination.get_base_dir(), prepared)
	var renamed := DirAccess.rename_absolute(staging, destination)
	if renamed != OK: return _io_failed("package_publish_failed", destination, renamed)
	return {"ok":true, "path":destination}

func directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)

func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func resolve_relative(root: String, relative_path: String) -> Dictionary:
	if relative_path.is_empty() or relative_path.begins_with("/") or relative_path.begins_with("\\") or "\\" in relative_path:
		return _failed("unsafe_repository_path", relative_path, "Repository path must be relative POSIX path.", "Repair or remove the corrupt song index entry.")
	for segment: String in relative_path.split("/", false):
		if segment in [".", ".."]: return _failed("unsafe_repository_path", relative_path, "Repository path traversal is forbidden.", "Repair or remove the corrupt song index entry.")
	return {"ok":true, "path":root.path_join(relative_path)}

func remove_tree(path: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(path): return {"ok":true}
	var directory := DirAccess.open(path)
	if directory == null: return _failed("cleanup_failed", path, "Could not open directory for cleanup.", "Check storage permissions.")
	directory.include_hidden = true
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty(): break
		if name in [".", ".."]: continue
		var child := path.path_join(name)
		if directory.current_is_dir():
			var nested := remove_tree(child)
			if not nested.get("ok", false): directory.list_dir_end(); return nested
		else:
			var removed_file := DirAccess.remove_absolute(child)
			if removed_file != OK: directory.list_dir_end(); return _io_failed("cleanup_failed", child, removed_file)
	directory.list_dir_end()
	directory = null
	var removed := DirAccess.remove_absolute(path)
	return {"ok":true} if removed == OK else _io_failed("cleanup_failed", path, removed)

func hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()

func _io_failed(code: String, path: String, error: Error) -> Dictionary:
	return _failed(code, path, "%s: %s" % [code, error_string(error)], "Check storage permissions and free space.")

func _failed(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"ok":false, "diagnostics":[{"severity":"error", "code":code, "file":file, "part":"", "measure":"", "element":"file", "message":message, "remediation":remediation}]}
