class_name V18CPGParetoFrontier
extends RefCounted


func prune(
	bundles: Array[Dictionary],
	max_size: int = 8,
	rule_root_candidate_id: String = ""
) -> Array[Dictionary]:
	if bundles.is_empty() or max_size <= 0:
		return []
	var survivors: Array[Dictionary] = []
	for candidate: Dictionary in bundles:
		var dominated := false
		for other: Dictionary in bundles:
			if other == candidate:
				continue
			if _dominates(other, candidate):
				dominated = true
				break
		if not dominated \
				or str(candidate.get("root_candidate_id", "")) == rule_root_candidate_id \
				or bool(candidate.get("verified_rescue", false)):
			survivors.append(candidate)
	survivors.sort_custom(_sort_bundle)
	var preserved: Array[Dictionary] = []
	_append_by_id(preserved, survivors, rule_root_candidate_id)
	for bundle: Dictionary in survivors:
		if bool(bundle.get("verified_rescue", false)):
			_append_unique(preserved, bundle)
	for bundle: Dictionary in survivors:
		if preserved.size() >= max_size:
			break
		_append_unique(preserved, bundle)
	if preserved.size() > max_size:
		preserved.resize(max_size)
	return preserved


func _dominates(a: Dictionary, b: Dictionary) -> bool:
	var av: Dictionary = a.get("outcome_vector", {}) \
		if a.get("outcome_vector", {}) is Dictionary else {}
	var bv: Dictionary = b.get("outcome_vector", {}) \
		if b.get("outcome_vector", {}) is Dictionary else {}
	var maximize_keys: Array[String] = [
		"win_now", "prevents_next_window_loss", "prizes_now", "race_margin",
		"current_attack_window_preserved", "next_attack_window_uptime",
		"information_value",
	]
	var minimize_keys: Array[String] = [
		"continuity_debt", "ledger_debt", "liability", "uncertainty",
	]
	var all_no_worse := true
	var any_better := false
	for key: String in maximize_keys:
		var a_value := float(av.get(key, 0.0))
		var b_value := float(bv.get(key, 0.0))
		if a_value < b_value:
			all_no_worse = false
		if a_value > b_value:
			any_better = true
	for key: String in minimize_keys:
		var a_value := float(av.get(key, 0.0))
		var b_value := float(bv.get(key, 0.0))
		if a_value > b_value:
			all_no_worse = false
		if a_value < b_value:
			any_better = true
	return all_no_worse and any_better


func _sort_bundle(a: Dictionary, b: Dictionary) -> bool:
	var av: Dictionary = a.get("outcome_vector", {}) \
		if a.get("outcome_vector", {}) is Dictionary else {}
	var bv: Dictionary = b.get("outcome_vector", {}) \
		if b.get("outcome_vector", {}) is Dictionary else {}
	var a_key := [
		-int(bool(av.get("win_now", false))),
		-int(bool(av.get("prevents_next_window_loss", false))),
		-int(av.get("prizes_now", 0)),
		-int(av.get("race_margin", 0)),
		int(av.get("continuity_debt", 0)),
		int(av.get("ledger_debt", 0)),
		float(av.get("liability", 0.0)),
		float(av.get("uncertainty", 0.0)),
		-float(a.get("rule_score", 0.0)),
		str(a.get("bundle_id", "")),
	]
	var b_key := [
		-int(bool(bv.get("win_now", false))),
		-int(bool(bv.get("prevents_next_window_loss", false))),
		-int(bv.get("prizes_now", 0)),
		-int(bv.get("race_margin", 0)),
		int(bv.get("continuity_debt", 0)),
		int(bv.get("ledger_debt", 0)),
		float(bv.get("liability", 0.0)),
		float(bv.get("uncertainty", 0.0)),
		-float(b.get("rule_score", 0.0)),
		str(b.get("bundle_id", "")),
	]
	for index: int in a_key.size():
		if a_key[index] == b_key[index]:
			continue
		return a_key[index] < b_key[index]
	return false


func _append_by_id(
	output: Array[Dictionary],
	bundles: Array[Dictionary],
	candidate_id: String
) -> void:
	if candidate_id == "":
		return
	for bundle: Dictionary in bundles:
		if str(bundle.get("root_candidate_id", "")) == candidate_id:
			_append_unique(output, bundle)
			return


func _append_unique(output: Array[Dictionary], bundle: Dictionary) -> void:
	var bundle_id := str(bundle.get("bundle_id", ""))
	for existing: Dictionary in output:
		if str(existing.get("bundle_id", "")) == bundle_id:
			return
	output.append(bundle)
