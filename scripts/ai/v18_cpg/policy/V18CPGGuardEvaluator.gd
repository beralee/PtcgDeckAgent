class_name V18CPGGuardEvaluator
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")


func evaluate_all(clauses: Array, facts: Dictionary) -> bool:
	for raw_clause: Variant in clauses:
		if not (raw_clause is Dictionary) or not evaluate(raw_clause as Dictionary, facts):
			return false
	return true


func evaluate(clause: Dictionary, facts: Dictionary) -> bool:
	var path := ContractsScript.canonical_fact_path(
		str(clause.get("fact", ""))
	)
	var op := str(clause.get("op", ""))
	if path not in ContractsScript.branchable_fact_paths(facts) \
			or op not in ContractsScript.GUARD_OPERATORS:
		return false
	var lookup := _lookup(facts, path)
	var exists := bool(lookup.get("exists", false))
	var actual: Variant = lookup.get("value", null)
	var expected: Variant = clause.get("value", null)
	match op:
		"exists":
			return exists == bool(expected if clause.has("value") else true)
		"==":
			return exists and actual == expected
		"!=":
			return exists and actual != expected
		">":
			return exists and _number(actual) > _number(expected)
		">=":
			return exists and _number(actual) >= _number(expected)
		"<":
			return exists and _number(actual) < _number(expected)
		"<=":
			return exists and _number(actual) <= _number(expected)
		"in":
			return exists and expected is Array and actual in (expected as Array)
		"not_in":
			return exists and expected is Array and actual not in (expected as Array)
	return false


func _lookup(facts: Dictionary, path: String) -> Dictionary:
	var current: Variant = facts
	for segment: String in path.split("."):
		if not (current is Dictionary) or not (current as Dictionary).has(segment):
			return {"exists": false, "value": null}
		current = (current as Dictionary).get(segment)
	return {"exists": true, "value": current}


func _number(value: Variant) -> float:
	if value is int or value is float:
		return float(value)
	return 0.0
