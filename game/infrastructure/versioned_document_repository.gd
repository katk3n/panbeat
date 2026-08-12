class_name VersionedDocumentRepository
extends RefCounted

const MigrationRunner := preload("res://application/schema_migration_runner.gd")

var _document_type: String
var _path: String
var _store: RefCounted

func _init(document_type: String, path: String, store: RefCounted) -> void:
	_document_type = document_type
	_path = path
	_store = store

func load() -> Dictionary:
	var loaded: Dictionary = _store.load_document(_path)
	if not loaded.get("ok", false):
		if loaded.get("code") == "not_found": return {"ok": true, "document": MigrationRunner.empty_document(_document_type), "created_default": true}
		return loaded
	var migrated: Dictionary = MigrationRunner.migrate(_document_type, loaded["document"])
	if not migrated.get("ok", false): return migrated
	if loaded.get("recovered_from_backup", false): migrated["recovered_from_backup"] = true
	return migrated

func save(document: Dictionary) -> Dictionary:
	var migrated := MigrationRunner.migrate(_document_type, document)
	if not migrated.get("ok", false): return migrated
	return _store.save_document(_path, migrated["document"])

func delete() -> Dictionary:
	return _store.delete_document(_path)

func path() -> String:
	return _path
