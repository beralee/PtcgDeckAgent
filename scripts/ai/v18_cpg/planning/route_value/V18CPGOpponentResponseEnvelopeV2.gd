class_name V18CPGOpponentResponseEnvelopeV2
extends RefCounted

const ContractsScript = preload(
	"res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd"
)


func solve(observation: Dictionary, _profile: Dictionary = {}) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var attacker: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var target: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var responses: Array[Dictionary] = []
	if not attacker.is_empty() and not target.is_empty():
		responses.append(_active_attack_response(attacker, target))
	var credible_gust := _credible_gust_response(opponent, own)
	if not credible_gust.is_empty():
		responses.append(credible_gust)
	var envelope := {
		"schema_version": ContractsScript.RESPONSE_ENVELOPE_SCHEMA_VERSION,
		"responses": responses,
		"credible_response_count": _count_evidence(responses, "credible"),
		"verified_response_count": _count_evidence(responses, "verified"),
		"speculative_response_count": _count_evidence(responses, "speculative"),
		"verified_certificate_eligible": _count_evidence(responses, "verified") > 0,
	}
	envelope["response_envelope_hash"] = ContractsScript.stable_hash(envelope)
	return envelope


func _active_attack_response(attacker: Dictionary, target: Dictionary) -> Dictionary:
	var damage := int(attacker.get("public_attack_damage", 0))
	var paid := bool(attacker.get("public_attack_cost_paid", false))
	var attack_id := str(attacker.get("public_attack_id", ""))
	var evidence := "verified" if damage > 0 and paid and attack_id != "" \
		else "credible" if int(attacker.get("energy_count", 0)) > 0 \
		else "speculative"
	var target_hp := int(target.get("remaining_hp", 0))
	var prizes := int(target.get("prize_count", 1)) \
		if damage > 0 and target_hp > 0 and damage >= target_hp else 0
	return {
		"response_id": _response_id("active_attack", attacker, target),
		"kind": "active_attack",
		"attacker_slot_id": str(attacker.get("slot_id", "")),
		"attack_id": attack_id if attack_id != "" else "unknown_public_attack",
		"target_slot_id": str(target.get("slot_id", "")),
		"payment": {
			"paid": paid,
			"visible_energy_count": int(attacker.get("energy_count", 0)),
		},
		"damage": damage,
		"prizes": prizes,
		"evidence_level": evidence,
		"certainty": 1.0 if evidence == "verified" else 0.65 if evidence == "credible" else 0.25,
	}


func _credible_gust_response(opponent: Dictionary, own: Dictionary) -> Dictionary:
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	if bench.is_empty():
		return {}
	var target: Dictionary = _highest_liability_target(bench)
	var attacker: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	if target.is_empty() or attacker.is_empty():
		return {}
	return {
		"response_id": _response_id("gust_pressure", attacker, target),
		"kind": "gust_pressure",
		"attacker_slot_id": str(attacker.get("slot_id", "")),
		"attack_id": "unknown_after_gust",
		"target_slot_id": str(target.get("slot_id", "")),
		"payment": {
			"paid": false,
			"visible_energy_count": int(attacker.get("energy_count", 0)),
			"gust_resource_publicly_bound": false,
		},
		"damage": 0,
		"prizes": 0,
		"evidence_level": "speculative",
		"certainty": 0.2,
	}


func _highest_liability_target(bench: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for raw_slot: Variant in bench:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		var score := int(slot.get("prize_count", 1)) * 1000 \
			+ int(slot.get("energy_count", 0)) * 100 \
			- int(slot.get("remaining_hp", 0))
		if score > best_score:
			best = slot
			best_score = score
	return best


func _count_evidence(responses: Array[Dictionary], level: String) -> int:
	var result := 0
	for response: Dictionary in responses:
		if str(response.get("evidence_level", "")) == level:
			result += 1
	return result


func _response_id(kind: String, attacker: Dictionary, target: Dictionary) -> String:
	return "response:%s" % ContractsScript.stable_hash({
		"kind": kind,
		"attacker": str(attacker.get("slot_id", "")),
		"target": str(target.get("slot_id", "")),
	}).substr(0, 16)
