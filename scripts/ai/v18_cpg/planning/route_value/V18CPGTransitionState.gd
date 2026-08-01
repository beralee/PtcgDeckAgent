class_name V18CPGTransitionState
extends RefCounted

const ContractsScript = preload(
	"res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd"
)


func build(
	observation: Dictionary,
	resource_ledger: Dictionary,
	facts: Dictionary,
	prize_clock: Dictionary
) -> Dictionary:
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) \
		if turn.get("quotas", {}) is Dictionary else {}
	var state := {
		"schema_version": ContractsScript.TRANSITION_SCHEMA_VERSION,
		"observation_hash": str(observation.get("observation_hash", "")),
		"turn": {
			"number": int(turn.get("number", 0)),
			"current_player": int(turn.get("current_player", -1)),
			"viewer": int(turn.get("viewer", -1)),
			"phase": int(turn.get("phase", -1)),
		},
		"quotas": {
			"energy_attachment": bool(quotas.get("energy_available", false)),
			"supporter": bool(quotas.get("supporter_available", false)),
			"stadium": bool(quotas.get("stadium_available", false)),
			"retreat": bool(quotas.get("retreat_available", false)),
			"vstar": bool(quotas.get("vstar_available", false)),
		},
		"own": _public_side(observation.get("own", {}), true),
		"opponent": _public_side(observation.get("opponent", {}), false),
		"stadium": _public_card(observation.get("stadium", {})),
		"ledger": _public_ledger(resource_ledger),
		"facts": _public_fact_snapshot(facts),
		"prize_clock": _public_clock_snapshot(prize_clock),
	}
	state["state_hash"] = ContractsScript.stable_hash(state)
	return state


func _public_side(value: Variant, include_hand: bool) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var side: Dictionary = value
	var bench: Array = side.get("bench", []) \
		if side.get("bench", []) is Array else []
	var bench_count := int(side.get("bench_count", bench.size()))
	var bench_capacity := int(side.get("bench_capacity", 5))
	var result := {
		"hand_count": int(side.get("hand_count", 0)),
		"deck_count": int(side.get("deck_count", 0)),
		"prizes_remaining": int(side.get("prizes_remaining", 0)),
		"bench_count": bench_count,
		"bench_capacity": bench_capacity,
		"bench_slots_free": int(
			side.get(
				"bench_slots_free",
				maxi(0, bench_capacity - bench_count)
			)
		),
		"bench_full": bool(
			side.get("bench_full", bench_count >= bench_capacity)
		),
		"bench_overflow_count": int(
			side.get("bench_overflow_count", 0)
		),
		"default_bench_capacity": int(
			side.get("default_bench_capacity", 5)
		),
		"overflow_if_default_capacity": int(
			side.get("overflow_if_default_capacity", 0)
		),
		"capacity_above_default": bool(
			side.get("capacity_above_default", false)
		),
		"capacity_below_default": bool(
			side.get("capacity_below_default", false)
		),
		"active": _public_slot(side.get("active", {})),
		"bench": _public_slots(bench),
		"discard": _public_cards(side.get("discard", [])),
		"lost_zone": _public_cards(side.get("lost_zone", [])),
	}
	if include_hand:
		result["hand"] = _public_cards(side.get("hand", []))
	return result


func _public_slots(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for raw_slot: Variant in value:
		if raw_slot is Dictionary:
			result.append(_public_slot(raw_slot))
	return result


func _public_slot(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var slot: Dictionary = value
	return {
		"slot_id": str(slot.get("slot_id", "")),
		"pokemon": _public_card(slot.get("pokemon", {})),
		"energy": _public_cards(slot.get("energy", [])),
		"energy_count": int(
			slot.get(
				"energy_count",
				(slot.get("energy", []) as Array).size()
					if slot.get("energy", []) is Array else 0
			)
		),
		"tool": _public_card(slot.get("tool", {})),
		"damage": int(slot.get("damage", 0)),
		"remaining_hp": int(slot.get("remaining_hp", 0)),
		"max_hp": int(slot.get("max_hp", 0)),
		"prize_count": int(slot.get("prize_count", 1)),
		"retreat_cost": int(slot.get("retreat_cost", 0)),
		"ability_used": bool(slot.get("ability_used", false)),
		"tera": bool(slot.get("tera", false)),
	}


func _public_cards(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for raw_card: Variant in value:
		if raw_card is Dictionary:
			result.append(_public_card(raw_card))
	return result


func _public_card(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var card: Dictionary = value
	var result: Dictionary = {}
	for key: String in [
		"instance_id", "uid", "effect_id", "name", "type", "mechanic", "stage",
		"energy_type", "energy_provides", "hp",
	]:
		if card.has(key):
			result[key] = card.get(key)
	return result


func _public_ledger(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var ledger: Dictionary = value
	var result: Dictionary = {
		"schema_version": int(ledger.get("schema_version", 0)),
	}
	for key: String in [
		"available_now", "reserved_current_route", "reserved_next_turn",
		"reserved_by_window", "recoverable", "possibly_prized", "safe_to_discard",
		"exclusive_quota", "semantic_role_counts",
	]:
		var raw: Variant = ledger.get(key)
		if raw is Dictionary:
			result[key] = (raw as Dictionary).duplicate(true)
		elif raw is Array:
			result[key] = (raw as Array).duplicate(true)
	return result


func _public_fact_snapshot(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var facts: Dictionary = value
	var result: Dictionary = {}
	for key: String in [
		"attack", "board", "continuity", "information", "prize", "prize_clock",
		"resources", "route", "turn",
	]:
		if facts.get(key) is Dictionary:
			result[key] = (facts.get(key) as Dictionary).duplicate(true)
	return result


func _public_clock_snapshot(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var clock: Dictionary = value
	var result: Dictionary = {}
	for key: String in [
		"schema_version", "own", "opponent", "race_margin",
		"current_attack_window_open", "opponent_wins_next_window",
	]:
		if clock.has(key):
			var raw: Variant = clock.get(key)
			result[key] = raw.duplicate(true) if raw is Dictionary or raw is Array else raw
	return result
