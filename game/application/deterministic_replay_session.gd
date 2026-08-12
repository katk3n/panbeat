class_name DeterministicReplaySession
extends RefCounted

const Pipeline := preload("res://application/judgement_pipeline.gd")
const ScoreEngine := preload("res://domain/score_engine.gd")

static func run(chart: RefCounted, expected_inputs: Array, judgement_rules: Dictionary, score_rules: Dictionary, offsets: Dictionary = {}) -> Dictionary:
	var pipeline := Pipeline.new(chart, judgement_rules, offsets)
	for value: Variant in expected_inputs:
		var event: Dictionary = value as Dictionary
		pipeline.process_input({
			"kind":"normalized_input", "input_event_id":event["event_id"],
			"technique":event["technique"], "target_id":event["target_id"], "velocity":event.get("velocity", 96)
		}, int(event["timestamp_us"]))
	pipeline.sweep_misses(9_007_199_254_740_991)
	var records: Array[Dictionary] = pipeline.records()
	return {"records":records, "summary":ScoreEngine.summarize(records, score_rules)}
