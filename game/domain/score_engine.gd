class_name ScoreEngine
extends RefCounted

static func summarize(records: Array[Dictionary], rules: Dictionary) -> Dictionary:
	var score: int = 0
	var combo: int = 0
	var max_combo: int = 0
	var accuracy_points: float = 0.0
	var accuracy_count: int = 0
	var breakdown: Dictionary = {"perfect":0, "great":0, "good":0, "miss":0, "extra_hit":0}
	var latest_grade: String = ""
	var latest_direction: String = "none"
	for record: Dictionary in records:
		var grade: String = record.get("grade", "")
		if not breakdown.has(grade):
			continue
		breakdown[grade] = int(breakdown[grade]) + 1
		score += int(rules["weights"].get(grade, 0))
		if grade in rules["combo_increments"]:
			combo += 1
			max_combo = maxi(max_combo, combo)
		elif grade in rules["combo_breaks"]:
			combo = 0
		if grade != "extra_hit" or bool(rules.get("extra_hit_counts_toward_accuracy", false)):
			accuracy_points += float(rules["accuracy_weights"].get(grade, 0.0))
			accuracy_count += 1
		latest_grade = grade
		var delta: Variant = record.get("delta_us")
		latest_direction = "none" if delta == null else ("early" if int(delta) < 0 else ("late" if int(delta) > 0 else "on_time"))
	return {
		"score":score, "combo":combo, "max_combo":max_combo,
		"accuracy":accuracy_points / accuracy_count if accuracy_count > 0 else 0.0,
		"breakdown":breakdown, "latest_grade":latest_grade, "latest_direction":latest_direction
	}

static func hud_model(records: Array[Dictionary], rules: Dictionary) -> Dictionary:
	var summary: Dictionary = summarize(records, rules)
	return {
		"current_score":summary["score"], "current_combo":summary["combo"],
		"current_accuracy":summary["accuracy"],
		"latest_grade":summary["latest_grade"], "latest_direction":summary["latest_direction"]
	}
