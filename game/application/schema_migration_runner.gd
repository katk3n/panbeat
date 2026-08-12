class_name SchemaMigrationRunner
extends RefCounted

const CURRENT_VERSION := "1.0.0"
const DOCUMENT_TYPES: Array[String] = ["settings", "song_index", "result_history"]

static func migrate(document_type: String, source: Dictionary) -> Dictionary:
	if not DOCUMENT_TYPES.has(document_type):
		return _failure("unknown_document_type", "unknown persistence document type: %s" % document_type)
	var version_value: Variant = source.get("schema_version")
	if version_value is not String or (version_value as String).is_empty():
		return _failure("missing_schema_version", "%s requires schema_version" % document_type)
	var version := version_value as String
	var parts := version.split(".")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return _failure("invalid_schema_version", "invalid %s schema_version: %s" % [document_type, version])
	if int(parts[0]) != 0 and int(parts[0]) != 1:
		return _failure("unknown_schema_major", "unsupported %s schema major version: %s" % [document_type, parts[0]])
	var migrated := source.duplicate(true)
	if version == "0.1.0":
		migrated = _migrate_0_1_to_1_0(document_type, migrated)
	elif version != CURRENT_VERSION:
		return _failure("unknown_schema_version", "no migration from %s %s" % [document_type, version])
	var validation := validate(document_type, migrated)
	if not validation.get("ok", false):
		return validation
	return {"ok": true, "document": migrated, "from_version": version, "to_version": CURRENT_VERSION, "migrated": version != CURRENT_VERSION}

static func validate(document_type: String, document: Dictionary) -> Dictionary:
	if document.get("schema_version") != CURRENT_VERSION:
		return _failure("schema_version_mismatch", "%s schema_version must be %s" % [document_type, CURRENT_VERSION])
	match document_type:
		"settings":
			if document.get("profile_id") is not String or document.get("offsets") is not Array:
				return _failure("invalid_settings", "settings require profile_id and offsets")
		"song_index":
			if document.get("songs") is not Array:
				return _failure("invalid_song_index", "song index requires songs")
		"result_history":
			if document.get("records") is not Array or not _is_positive_integer(document.get("max_records")):
				return _failure("invalid_result_history", "result history requires records and a positive max_records")
		_:
			return _failure("unknown_document_type", "unknown persistence document type: %s" % document_type)
	return {"ok": true}

static func empty_document(document_type: String) -> Dictionary:
	match document_type:
		"settings":
			return {"schema_version": CURRENT_VERSION, "selected_midi_port": "", "profile_id": "roland-mn10-handpan-minor-v1", "offsets": []}
		"song_index":
			return {"schema_version": CURRENT_VERSION, "songs": []}
		"result_history":
			return {"schema_version": CURRENT_VERSION, "max_records": 100, "records": []}
	return {}

static func _migrate_0_1_to_1_0(document_type: String, source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	migrated["schema_version"] = CURRENT_VERSION
	match document_type:
		"settings":
			migrated["selected_midi_port"] = migrated.get("selected_port", "")
			migrated.erase("selected_port")
			if not migrated.has("offsets"): migrated["offsets"] = []
		"song_index":
			if not migrated.has("songs"): migrated["songs"] = []
		"result_history":
			if not migrated.has("records"): migrated["records"] = []
			if not migrated.has("max_records"): migrated["max_records"] = 100
	return migrated

static func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "error": message}

static func _is_positive_integer(value: Variant) -> bool:
	if value is int: return int(value) > 0
	if value is float: return is_finite(value as float) and floorf(value as float) == value as float and value as float > 0.0
	return false
