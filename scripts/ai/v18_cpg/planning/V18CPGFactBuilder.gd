class_name V18CPGFactBuilder
extends RefCounted

const DynamicAttackCostScript = preload(
	"res://scripts/ai/v18_cpg/modules/V18CPGDynamicAttackCost.gd"
)
const EnergyBurstScript = preload(
	"res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd"
)
const RetreatMobilitySolverScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGRetreatMobilitySolver.gd"
)


func build(observation: Dictionary, current_route_id: String = "", profile: Dictionary = {}) -> Dictionary:
	var actions: Array = observation.get("legal_actions", []) if observation.get("legal_actions", []) is Array else []
	var attack_ready := false
	var ko_available := false
	var max_damage := 0
	var fan_call_available := false
	var material_information_action := false
	var route_valid := current_route_id == ""
	for raw_action: Variant in actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var kind := str(action.get("kind", ""))
		if kind in ["attack", "granted_attack"]:
			attack_ready = true
			ko_available = ko_available or bool(action.get("projected_knockout", false))
			max_damage = maxi(max_damage, int(action.get("projected_damage", 0)))
		if _is_noctowl_search_action(action):
			fan_call_available = true
		if kind in ["use_ability", "play_trainer", "use_stadium_effect"] and bool(action.get("requires_interaction", false)):
			material_information_action = true
		if current_route_id != "" and _route_accepts_action(current_route_id, action):
			route_valid = true
	var variable_projection := _variable_attack_projection(
		observation,
		actions,
		profile
	)
	if attack_ready and bool(variable_projection.get("enabled", false)):
		max_damage = maxi(
			max_damage,
			int(variable_projection.get("projected_damage", 0))
		)
		ko_available = ko_available or bool(
			variable_projection.get("projected_knockout", false)
		)
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var bench_count := int(own.get("bench_count", bench.size()))
	var bench_capacity := int(own.get("bench_capacity", 5))
	var bench_slots_free := int(
		own.get("bench_slots_free", maxi(0, bench_capacity - bench_count))
	)
	var has_tera := _slot_is_tera(own.get("active", {}))
	var energy_on_board := _slot_energy_count(own.get("active", {}))
	var energy_symbols: Dictionary = {}
	_collect_energy_symbols(own.get("active", {}), energy_symbols)
	for raw_slot: Variant in bench:
		if not (raw_slot is Dictionary):
			continue
		if _slot_is_tera(raw_slot as Dictionary):
			has_tera = true
		energy_on_board += _slot_energy_count(raw_slot)
		_collect_energy_symbols(raw_slot, energy_symbols)
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) if turn.get("quotas", {}) is Dictionary else {}
	var safety: Dictionary = profile.get("safety", {}) if profile.get("safety", {}) is Dictionary else {}
	var low_deck_threshold := int(safety.get("low_deck_threshold", 8))
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var opponent_bench: Array = opponent.get("bench", []) \
		if opponent.get("bench", []) is Array else []
	var opponent_bench_count := int(
		opponent.get("bench_count", opponent_bench.size())
	)
	var opponent_bench_capacity := int(
		opponent.get("bench_capacity", 5)
	)
	var opponent_bench_slots_free := int(
		opponent.get(
			"bench_slots_free",
			maxi(0, opponent_bench_capacity - opponent_bench_count)
		)
	)
	var own_active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) if opponent.get("active", {}) is Dictionary else {}
	var prize_swing := int(opponent_active.get("prize_count", 1)) if ko_available else 0
	var prizes_remaining := int(own.get("prizes_remaining", 0))
	var dynamic_cost_snapshot := DynamicAttackCostScript.new().public_snapshot(observation)
	var mobility_snapshot := RetreatMobilitySolverScript.new().solve(observation)
	var dynamic_active: Dictionary = dynamic_cost_snapshot.get("active", {}) \
		if dynamic_cost_snapshot.get("active", {}) is Dictionary else {}
	return {
		"attack": {
			"ready": attack_ready,
			"ko_available": ko_available,
			"max_damage": max_damage,
			"dynamic_cost_applied": not dynamic_active.is_empty(),
			"effective_energy_required": int(
				dynamic_active.get("effective_energy_required", 0)
			),
			"energy_deficit": int(dynamic_active.get("energy_deficit", 0)),
			"cost_ready": bool(dynamic_active.get("cost_ready", attack_ready)),
			"engine_confirms_cost_paid": bool(
				dynamic_active.get("engine_confirms_cost_paid", attack_ready)
			),
			"dynamic_cost": dynamic_active,
			"variable_damage_projection": variable_projection,
		},
		"board": {
			"bench_count": bench_count,
			"bench_capacity": bench_capacity,
			"bench_full": bool(
				own.get("bench_full", bench_count >= bench_capacity)
			),
			"bench_overflow_count": int(
				own.get(
					"bench_overflow_count",
					maxi(0, bench_count - bench_capacity)
				)
			),
			"bench_overflow_if_default": int(
				own.get(
					"overflow_if_default_capacity",
					maxi(0, bench_count - 5)
				)
			),
			"bench_capacity_above_default": bool(
				own.get("capacity_above_default", bench_capacity > 5)
			),
			"bench_capacity_below_default": bool(
				own.get("capacity_below_default", bench_capacity < 5)
			),
			"opponent_bench_count": opponent_bench_count,
			"opponent_bench_capacity": opponent_bench_capacity,
			"opponent_bench_slots_free": opponent_bench_slots_free,
			"opponent_bench_full": bool(
				opponent.get(
					"bench_full",
					opponent_bench_count >= opponent_bench_capacity
				)
			),
			"opponent_bench_overflow_if_default": int(
				opponent.get(
					"overflow_if_default_capacity",
					maxi(0, opponent_bench_count - 5)
				)
			),
			"has_tera": has_tera,
			"own_active_remaining_hp": int(own_active.get("remaining_hp", 0)),
			"opponent_active_remaining_hp": int(opponent_active.get("remaining_hp", 0)),
			"dynamic_attack_cost_cards": dynamic_cost_snapshot.get("cards", []),
		},
		"fan_call": {"available": fan_call_available},
		"information": {"material_action_available": material_information_action},
		"mobility": mobility_snapshot,
		"resources": {
			"deck_low": int(own.get("deck_count", 0)) <= low_deck_threshold,
			"bench_slots_free": bench_slots_free,
			"energy_on_board": energy_on_board,
			"distinct_energy_symbols": energy_symbols.size(),
			"hand_size": int(own.get("hand_count", 0)),
			"prizes_remaining": prizes_remaining,
		},
		"prize": {
			"current_swing": prize_swing,
			"win_now": prize_swing > 0 and prize_swing >= prizes_remaining,
		},
		"route": {"current_valid": route_valid},
		"turn": {
			"energy_available": bool(quotas.get("energy_available", false)),
			"supporter_available": bool(quotas.get("supporter_available", false)),
		},
	}


func _variable_attack_projection(
	observation: Dictionary,
	actions: Array,
	profile: Dictionary
) -> Dictionary:
	var modules: Array = profile.get("modules", []) \
		if profile.get("modules", []) is Array else []
	if "energy_burst" not in modules:
		return {}
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = module_parameters.get("energy_burst", {}) \
		if module_parameters.get("energy_burst", {}) is Dictionary else {}
	var primary_uids: Array[String] = []
	for raw_uid: Variant in parameters.get("primary_attacker_uids", []):
		primary_uids.append(str(raw_uid).strip_edges().to_upper())
	var primary_indexes: Array[int] = []
	for raw_index: Variant in parameters.get(
		"minimum_lethal_attack_indexes",
		[]
	):
		primary_indexes.append(int(raw_index))
	var bound_primary_attack := false
	for raw_action: Variant in actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		if str(action.get("kind", "")) not in ["attack", "granted_attack"]:
			continue
		var source_card: Dictionary = action.get("source_card", {}) \
			if action.get("source_card", {}) is Dictionary else {}
		var source_uid := str(
			source_card.get("uid", "")
		).strip_edges().to_upper()
		if not primary_uids.is_empty() and source_uid not in primary_uids:
			continue
		if not primary_indexes.is_empty() \
				and int(action.get("attack_index", -1)) not in primary_indexes:
			continue
		bound_primary_attack = true
		break
	if not bound_primary_attack:
		return {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var target_hp := int(opponent_active.get("remaining_hp", 0))
	var resource := EnergyBurstScript.new().damage_resource_snapshot(
		observation,
		profile,
		{},
		target_hp
	)
	if not bool(resource.get("enabled", false)):
		return {}
	var projected_damage := int(
		resource.get("projected_public_damage", 0)
	)
	return {
		"enabled": projected_damage > 0,
		"source": "energy_burst_public_resource",
		"mode": str(resource.get("mode", "none")),
		"projected_damage": projected_damage,
		"projected_knockout": target_hp > 0 \
			and projected_damage >= target_hp,
		"resource": resource,
	}


func _is_noctowl_search_action(action: Dictionary) -> bool:
	if str(action.get("kind", "")) != "use_ability":
		return false
	var source: Dictionary = action.get("source_card", {}) if action.get("source_card", {}) is Dictionary else {}
	return str(source.get("uid", "")).to_upper() in ["CSV9C_155", "LEN_SCR_115"]


func _route_accepts_action(route_id: String, action: Dictionary) -> bool:
	var category := route_id.trim_prefix("route:")
	var kind := str(action.get("kind", ""))
	match category:
		"attack_ko":
			return kind in ["attack", "granted_attack"] and bool(action.get("projected_knockout", false))
		"attack_pressure":
			return kind in ["attack", "granted_attack"]
		"noctowl_search":
			return _is_noctowl_search_action(action)
		"pivot":
			return kind == "retreat"
		"energy_commit":
			return kind == "attach_energy"
		"develop":
			return kind in ["play_basic_to_bench", "evolve", "attach_tool", "play_stadium"]
		"information":
			return kind in ["play_trainer", "use_ability", "use_stadium_effect"]
		"tutor":
			return kind == "play_trainer" and _action_card_uid(action) == "CSV1C_123"
		"recover":
			return kind == "play_trainer" and _action_card_uid(action) in ["CSV8C_183", "CSV1C_109"]
		"end_turn":
			return kind == "end_turn"
	return true


func _action_card_uid(action: Dictionary) -> String:
	var card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	return str(card.get("uid", "")).strip_edges().to_upper()


func _slot_is_tera(value: Variant) -> bool:
	return value is Dictionary and bool((value as Dictionary).get("tera", false))


func _slot_energy_count(value: Variant) -> int:
	if not (value is Dictionary):
		return 0
	var slot: Dictionary = value
	return int(slot.get("energy_count", (slot.get("energy", []) as Array).size() if slot.get("energy", []) is Array else 0))


func _collect_energy_symbols(value: Variant, output: Dictionary) -> void:
	if not (value is Dictionary):
		return
	for raw_energy: Variant in (value as Dictionary).get("energy", []):
		if not (raw_energy is Dictionary):
			continue
		var energy: Dictionary = raw_energy
		var symbol := str(energy.get("energy_provides", energy.get("energy_type", ""))).to_upper()
		if symbol != "":
			output[symbol] = true
