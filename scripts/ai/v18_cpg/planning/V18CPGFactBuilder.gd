class_name V18CPGFactBuilder
extends RefCounted

const DynamicAttackCostScript = preload(
	"res://scripts/ai/v18_cpg/modules/V18CPGDynamicAttackCost.gd"
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
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var has_tera := _slot_is_tera(own.get("active", {}))
	var energy_on_board := _slot_energy_count(own.get("active", {}))
	var energy_symbols: Dictionary = {}
	_collect_energy_symbols(own.get("active", {}), energy_symbols)
	for raw_slot: Variant in bench:
		if raw_slot is Dictionary and _slot_is_tera(raw_slot as Dictionary):
			has_tera = true
		energy_on_board += _slot_energy_count(raw_slot)
		_collect_energy_symbols(raw_slot, energy_symbols)
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) if turn.get("quotas", {}) is Dictionary else {}
	var safety: Dictionary = profile.get("safety", {}) if profile.get("safety", {}) is Dictionary else {}
	var low_deck_threshold := int(safety.get("low_deck_threshold", 8))
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var own_active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) if opponent.get("active", {}) is Dictionary else {}
	var prize_swing := int(opponent_active.get("prize_count", 1)) if ko_available else 0
	var prizes_remaining := int(own.get("prizes_remaining", 0))
	var dynamic_cost_snapshot := DynamicAttackCostScript.new().public_snapshot(observation)
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
		},
		"board": {
			"bench_full": bench.size() >= 5,
			"has_tera": has_tera,
			"own_active_remaining_hp": int(own_active.get("remaining_hp", 0)),
			"opponent_active_remaining_hp": int(opponent_active.get("remaining_hp", 0)),
			"dynamic_attack_cost_cards": dynamic_cost_snapshot.get("cards", []),
		},
		"fan_call": {"available": fan_call_available},
		"information": {"material_action_available": material_information_action},
		"resources": {
			"deck_low": int(own.get("deck_count", 0)) <= low_deck_threshold,
			"bench_slots_free": maxi(0, 5 - bench.size()),
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
