class_name JsonChartSource
extends RefCounted

static func load_chart(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "chart file could not be opened", "path": path}
	return parse_chart(file.get_as_text(), path)

static func parse_chart(text: String, source: String = "memory") -> Dictionary:
	var json := JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		return {
			"ok": false,
			"error": "invalid chart JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()],
			"path": source,
		}
	if json.data is not Dictionary:
		return {"ok": false, "error": "chart root must be an object", "path": source}
	var chart: Dictionary = json.data as Dictionary
	if chart.get("schema_version") != "1.0.0":
		return {"ok": false, "error": "unsupported chart schema version", "path": source}
	return {"ok": true, "chart": chart, "path": source}
