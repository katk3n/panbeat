class_name CanonicalJson
extends RefCounted

static func encode(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys(); keys.sort()
		var members: Array[String] = []
		for key: Variant in keys: members.append("%s:%s" % [JSON.stringify(str(key)), encode((value as Dictionary)[key])])
		return "{%s}" % ",".join(members)
	if value is Array:
		var items: Array[String] = []
		for item: Variant in value: items.append(encode(item))
		return "[%s]" % ",".join(items)
	if value is String or value is StringName: return JSON.stringify(str(value))
	if value is bool: return "true" if value else "false"
	if value == null: return "null"
	if value is int: return str(value)
	if value is float:
		if not is_finite(value as float): return "null"
		return str(value)
	return JSON.stringify(value)
