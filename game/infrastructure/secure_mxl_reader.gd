class_name SecureMxlReader
extends RefCounted

const MAX_ARCHIVE_BYTES := 32 * 1024 * 1024
const MAX_ENTRIES := 256
const MAX_EXPANDED_BYTES := 64 * 1024 * 1024
const MAX_COMPRESSION_RATIO := 100
const MAX_SCORE_BYTES := 16 * 1024 * 1024
const CENTRAL_SIGNATURE := 0x02014b50
const EOCD_SIGNATURE := 0x06054b50

static func read_file(path: String) -> Dictionary:
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null: return _failed("archive_open_failed", path, "The MXL archive could not be opened.", "Check the path and file permissions.")
	if source.get_length() > MAX_ARCHIVE_BYTES: return _failed("archive_size_limit", path, "The MXL archive exceeds %d bytes." % MAX_ARCHIVE_BYTES, "Choose a smaller archive.")
	var bytes := source.get_buffer(source.get_length())
	var inspected := inspect_archive_bytes(bytes, path)
	if not inspected.get("ok", false): return inspected
	var archive := ZIPReader.new()
	var open_error := archive.open(path)
	if open_error != OK: return _failed("invalid_mxl_archive", path, "The MXL ZIP structure could not be opened: %s" % error_string(open_error), "Export a valid compressed MusicXML file.")
	var files := Array(archive.get_files())
	if not files.has("META-INF/container.xml"):
		archive.close(); return _failed("mxl_container_missing", path, "META-INF/container.xml is missing.", "Export a standard MusicXML MXL archive.")
	var container_bytes := archive.read_file("META-INF/container.xml")
	var root_result := _rootfile(container_bytes, path)
	if not root_result.get("ok", false): archive.close(); return root_result
	var rootfile: String = root_result["rootfile"]
	if not files.has(rootfile): archive.close(); return _failed("mxl_rootfile_missing", path, "The container rootfile does not exist: %s" % rootfile, "Correct META-INF/container.xml.")
	if rootfile.get_extension().to_lower() not in ["xml", "musicxml"]: archive.close(); return _failed("mxl_rootfile_extension", path, "The rootfile must be .xml or .musicxml.", "Point the container to MusicXML.")
	var score_bytes := archive.read_file(rootfile)
	archive.close()
	if score_bytes.size() > MAX_SCORE_BYTES: return _failed("source_too_large", rootfile, "The expanded MusicXML exceeds %d bytes." % MAX_SCORE_BYTES, "Choose a smaller score.")
	return {"ok":true, "bytes":score_bytes, "rootfile":rootfile, "entries":inspected["entries"], "expanded_bytes":inspected["expanded_bytes"]}

static func inspect_archive_bytes(bytes: PackedByteArray, source: String = "archive") -> Dictionary:
	if bytes.size() > MAX_ARCHIVE_BYTES: return _failed("archive_size_limit", source, "The MXL archive is too large.", "Choose a smaller archive.")
	var eocd := -1
	for offset: int in range(bytes.size() - 22, maxi(-1, bytes.size() - 65558), -1):
		if offset >= 0 and bytes.decode_u32(offset) == EOCD_SIGNATURE: eocd = offset; break
	if eocd < 0: return _failed("invalid_mxl_archive", source, "ZIP end-of-central-directory was not found.", "Export a valid MXL archive.")
	var entry_count := bytes.decode_u16(eocd + 10)
	var central_size := bytes.decode_u32(eocd + 12)
	var cursor := bytes.decode_u32(eocd + 16)
	if entry_count > MAX_ENTRIES: return _failed("archive_entry_limit", source, "The archive contains more than %d entries." % MAX_ENTRIES, "Remove unnecessary files.")
	if cursor + central_size > bytes.size(): return _failed("invalid_mxl_archive", source, "ZIP central directory is outside the archive.", "Export a valid MXL archive.")
	var entries: Array[Dictionary] = []
	for _index: int in entry_count:
		if cursor + 46 > bytes.size() or bytes.decode_u32(cursor) != CENTRAL_SIGNATURE: return _failed("invalid_mxl_archive", source, "Invalid ZIP central-directory entry.", "Export a valid MXL archive.")
		var made_by := bytes.decode_u16(cursor + 4)
		var flags := bytes.decode_u16(cursor + 8)
		var compressed_size := bytes.decode_u32(cursor + 20)
		var expanded_size := bytes.decode_u32(cursor + 24)
		var name_length := bytes.decode_u16(cursor + 28)
		var extra_length := bytes.decode_u16(cursor + 30)
		var comment_length := bytes.decode_u16(cursor + 32)
		var external_attributes := bytes.decode_u32(cursor + 38)
		var end := cursor + 46 + name_length + extra_length + comment_length
		if end > bytes.size(): return _failed("invalid_mxl_archive", source, "Truncated ZIP central-directory entry.", "Export a valid MXL archive.")
		var name := bytes.slice(cursor + 46, cursor + 46 + name_length).get_string_from_utf8()
		var host_os := made_by >> 8
		var unix_mode := external_attributes >> 16
		var file_type := unix_mode & 0xF000
		entries.append({"path":name, "compressed_bytes":compressed_size, "expanded_bytes":expanded_size, "encrypted":bool(flags & 1), "file_type":file_type if host_os == 3 else 0})
		cursor = end
	return validate_declared_entries(entries, source)

static func validate_declared_entries(entries: Array[Dictionary], source: String = "archive") -> Dictionary:
	if entries.size() > MAX_ENTRIES: return _failed("archive_entry_limit", source, "The archive contains more than %d entries." % MAX_ENTRIES, "Remove unnecessary files.")
	var names: Dictionary = {}
	var expanded := 0
	var compressed := 0
	for entry: Dictionary in entries:
		var name := str(entry.get("path", ""))
		var path_error := validate_entry_path(name)
		if not path_error.is_empty(): return _failed(path_error, name, "Unsafe archive entry path: %s" % name, "Remove absolute, traversal, or backslash paths.")
		if names.has(name): return _failed("archive_duplicate_entry", name, "Duplicate archive entry: %s" % name, "Keep one entry per path.")
		names[name] = true
		if entry.get("encrypted", false): return _failed("archive_encrypted_entry", name, "Encrypted archive entries are unsupported.", "Export an unencrypted MXL archive.")
		if int(entry.get("file_type", 0)) not in [0, 0x4000, 0x8000]: return _failed("archive_special_entry", name, "Symlinks and special files are forbidden.", "Store regular files and directories only.")
		var compressed_size := int(entry.get("compressed_bytes", 0)); var expanded_size := int(entry.get("expanded_bytes", 0))
		if expanded_size > 0 and compressed_size == 0: return _failed("archive_compression_ratio", name, "Archive entry has an invalid compression ratio.", "Re-export the archive normally.")
		if compressed_size > 0 and expanded_size > compressed_size * MAX_COMPRESSION_RATIO: return _failed("archive_compression_ratio", name, "Archive entry exceeds the %d:1 compression ratio limit." % MAX_COMPRESSION_RATIO, "Reduce compression ratio or input size.")
		expanded += expanded_size; compressed += compressed_size
		if expanded > MAX_EXPANDED_BYTES: return _failed("archive_expanded_size_limit", source, "Expanded archive exceeds %d bytes." % MAX_EXPANDED_BYTES, "Choose a smaller archive.")
	if compressed > 0 and expanded > compressed * MAX_COMPRESSION_RATIO: return _failed("archive_compression_ratio", source, "Archive exceeds the total compression ratio limit.", "Reduce compression ratio or input size.")
	return {"ok":true, "entries":entries, "expanded_bytes":expanded}

static func validate_entry_path(path: String) -> String:
	if path.is_empty() or path.begins_with("/") or path.begins_with("\\") or "\\" in path: return "archive_absolute_or_backslash_path"
	if path.length() >= 2 and path[1] == ":": return "archive_absolute_or_backslash_path"
	for segment: String in path.split("/", false):
		if segment == ".." or segment == ".": return "archive_path_traversal"
	return ""

static func _rootfile(bytes: PackedByteArray, source: String) -> Dictionary:
	if bytes.size() > 1024 * 1024: return _failed("mxl_container_too_large", source, "container.xml exceeds 1 MiB.", "Use a minimal standard container file.")
	var lowered := bytes.get_string_from_utf8().to_lower()
	if "<!doctype" in lowered or "<!entity" in lowered: return _failed("xml_dtd_forbidden", "META-INF/container.xml", "DOCTYPE and entities are forbidden.", "Remove the DTD or entity declaration.")
	var parser := XMLParser.new()
	if parser.open_buffer(bytes) != OK: return _failed("mxl_container_malformed", source, "container.xml is malformed.", "Export a valid MXL archive.")
	var roots: Array[String] = []
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "rootfile":
			var candidate := parser.get_named_attribute_value_safe("full-path")
			if validate_entry_path(candidate).is_empty(): roots.append(candidate)
			else: return _failed("archive_path_traversal", candidate, "Unsafe rootfile path.", "Correct container.xml.")
	if roots.size() != 1: return _failed("mxl_rootfile_count", source, "container.xml must declare exactly one rootfile.", "Keep one score rootfile.")
	return {"ok":true, "rootfile":roots[0]}

static func _failed(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"ok":false, "diagnostics":[{"severity":"error", "code":code, "file":file, "part":"", "measure":"", "element":"archive", "message":message, "remediation":remediation}]}
