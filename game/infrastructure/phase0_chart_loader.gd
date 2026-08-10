class_name Phase0ChartLoader
extends RefCounted

static func load_chart(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var chart: Variant = JSON.parse_string(file.get_as_text())
	if chart is not Dictionary or chart.get("schema_version") != "1.0.0":
		return {}
	return chart as Dictionary
