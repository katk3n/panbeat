class_name UserDataRepositories
extends RefCounted

const AtomicStore := preload("res://infrastructure/atomic_json_store.gd")
const NativeBackend := preload("res://infrastructure/native_file_backend.gd")
const Repository := preload("res://infrastructure/versioned_document_repository.gd")

var root_path: String
var settings: RefCounted
var songs: RefCounted
var results: RefCounted

func _init(override_root: String = "", backend: RefCounted = null) -> void:
	root_path = override_root if not override_root.is_empty() else OS.get_user_data_dir().path_join("v1")
	var file_backend: RefCounted = backend if backend != null else NativeBackend.new()
	var store := AtomicStore.new(file_backend)
	settings = Repository.new("settings", root_path.path_join("settings/settings.json"), store)
	songs = Repository.new("song_index", root_path.path_join("songs/index.json"), store)
	results = Repository.new("result_history", root_path.path_join("results/history.json"), store)
