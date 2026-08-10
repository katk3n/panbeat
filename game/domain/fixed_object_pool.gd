class_name FixedObjectPool
extends RefCounted

var _items: Array[RefCounted] = []
var overflow_count: int = 0
var created_count: int = 0

func _init(capacity: int) -> void:
	assert(capacity > 0)
	_items.resize(capacity)
	for index: int in capacity:
		_items[index] = RefCounted.new()
		created_count += 1

func rent() -> RefCounted:
	if _items.is_empty():
		overflow_count += 1
		return null
	return _items.pop_back()

func give_back(item: RefCounted) -> void:
	assert(item != null)
	_items.push_back(item)

func available() -> int:
	return _items.size()
