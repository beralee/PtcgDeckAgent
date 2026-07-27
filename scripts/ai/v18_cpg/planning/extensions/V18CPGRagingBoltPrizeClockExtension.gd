class_name V18CPGRagingBoltPrizeClockExtension
extends RefCounted

## Deck-specific constraint layer for 800018509.  It only derives typed public
## facts for the shared prize-clock Base graph; it neither executes actions nor
## grants an upgrade by itself.

const EnergySymbolsScript = preload(
	"res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd"
)

const KIND := "raging_bolt"
const RAGING_BOLT_EX_UID := "CSV7C_154"
const TEAL_MASK_OGERPON_EX_UID := "CSV8C_028"
const LATIAS_EX_UID := "CSV9C_078"
const BLOODMOON_EX_UID := "CSV8C_172"
const AREA_ZERO_UID := "CSV9C_207"


func supports(profile: Dictionary) -> bool:
	var config: Dictionary = profile.get("prize_clock_extension", {}) \
		if profile.get("prize_clock_extension", {}) is Dictionary else {}
	return int(profile.get("deck_id", 0)) == 800018509 \
		and str(config.get("kind", "")) == KIND


func annotate_candidate(
	candidate: Dictionary,
	observation: Dictionary,
	_facts: Dictionary,
	profile: Dictionary,
	baseline: Dictionary
) -> Dictionary:
	var config: Dictionary = profile.get("prize_clock_extension", {}) \
		if profile.get("prize_clock_extension", {}) is Dictionary else {}
	var action: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var action_kind := str(candidate.get("action_kind", action.get("kind", "")))
	var card_uid := _action_card_uid(action)
	var source_uid := _action_source_uid(action, observation)
	var target_slot := _own_slot(str(action.get("target", "")), observation)
	var target_uid := _slot_uid(target_slot)
	var operators: Array[String] = []
	var noctowl_uids := _upper_strings(config.get("noctowl_uids", []))
	if card_uid in noctowl_uids or source_uid in noctowl_uids:
		operators.append("RB_BUILD_NOCTOWL_ENGINE")
	if card_uid == str(config.get("area_zero_uid", AREA_ZERO_UID)).to_upper():
		operators.append("RB_EXPAND_AREA_ZERO_CAPACITY")
	if action_kind == "use_ability" \
			and source_uid == TEAL_MASK_OGERPON_EX_UID:
		operators.append("RB_BANK_TEAL_DANCE_ENERGY")
	if action_kind in ["attack", "granted_attack"] \
			and source_uid == RAGING_BOLT_EX_UID:
		operators.append("RB_MINIMUM_LETHAL_DISCARD")
	var latias_visible := _has_visible_uid(
		observation,
		config.get("free_retreat_enabler_uids", [LATIAS_EX_UID])
	)
	if action_kind == "retreat" and latias_visible:
		operators.append("RB_FREE_RETREAT_VIA_LATIAS")
	var attacker_config := _one_prize_attacker_config(target_uid, config)
	if not attacker_config.is_empty():
		var operator := str(attacker_config.get("operator", ""))
		if operator != "" and operator not in operators:
			operators.append(operator)
	if target_uid == BLOODMOON_EX_UID \
			or source_uid == BLOODMOON_EX_UID:
		operators.append("RB_BLOODMOON_DYNAMIC_CLOSEOUT")
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var own_active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var active_damaged_two_prizer := int(
		own_active.get("prize_count", 1)
	) >= 2 and int(own_active.get("damage", 0)) > 0
	if action_kind == "retreat" and active_damaged_two_prizer:
		operators.append("RB_PRESERVE_DAMAGED_TWO_PRIZE_BENCH")

	var dynamic_cost := _module_annotation(candidate, "dynamic_attack_cost")
	var same_window := _same_attack_window(
		action_kind,
		target_slot,
		target_uid,
		attacker_config,
		observation,
		dynamic_cost,
		config
	)
	var public_gust_exhausted := bool(baseline.get(
		"public_gust_exhausted",
		false
	))
	var denial_level := "none"
	var exposed_prizes := int(target_slot.get("prize_count", 0))
	if action_kind == "retreat" \
			and active_damaged_two_prizer \
			and exposed_prizes == 1 \
			and bool(same_window.get("ko_ready", false)):
		denial_level = "forced" if public_gust_exhausted else "credible"
	var continuity_effect: Dictionary = candidate.get(
		"post_attack_continuity",
		{}
	) if candidate.get("post_attack_continuity", {}) is Dictionary else {}
	var route_warning := ""
	if "RB_EXPAND_AREA_ZERO_CAPACITY" in operators \
			and not bool(continuity_effect.get("reduces_debt", false)):
		route_warning = "capacity_without_immediate_engine_chain"
	var conditional_suffix := _conditional_suffix(
		candidate,
		operators,
		continuity_effect
	)
	return {
		"extension_kind": KIND,
		"extension_operators": operators,
		"same_attack_window": same_window,
		"prize_denial": {
			"level": denial_level,
			"exposed_prize_count": exposed_prizes,
			"active_damaged_two_prizer": active_damaged_two_prizer,
			"public_gust_exhausted": public_gust_exhausted,
			"retreated_liability_remains_gust_exposed": denial_level == "credible",
			"target_slot_id": str(target_slot.get("slot_id", "")),
			"target_uid": target_uid,
		},
		"latias_free_retreat_visible": latias_visible,
		"target_uid": target_uid,
		"route_warning": route_warning,
		"conditional_suffix": conditional_suffix,
		"opponent_wins_next_window": bool(baseline.get(
			"opponent_wins_next_window",
			false
		)),
	}


func _conditional_suffix(
	candidate: Dictionary,
	operators: Array[String],
	continuity_effect: Dictionary
) -> Dictionary:
	if operators.is_empty():
		return {}
	var planned_debts: Array = continuity_effect.get(
		"planned_debt_types",
		continuity_effect.get("debt_types", [])
	) if continuity_effect.get(
		"planned_debt_types",
		continuity_effect.get("debt_types", [])
	) is Array else []
	var guarded_followups: Array[Dictionary] = []
	for raw_debt: Variant in planned_debts:
		var debt := str(raw_debt)
		var routes := _followup_routes_for_debt(debt)
		if routes.is_empty():
			continue
		guarded_followups.append({
			"debt_type": debt,
			"prefer_routes": routes,
			"checkpoint_required": true,
		})
	if guarded_followups.is_empty():
		for operator: String in operators:
			var routes := _followup_routes_for_operator(operator)
			if routes.is_empty():
				continue
			guarded_followups.append({
				"operator": operator,
				"prefer_routes": routes,
				"checkpoint_required": true,
			})
	if guarded_followups.is_empty():
		return {}
	return {
		"schema_version": 1,
		"kind": "raging_bolt_continuity_route",
		"root_route_id": str(candidate.get("route_id", "")),
		"checkpoint_after": str(candidate.get(
			"checkpoint_after",
			"action_resolved"
		)),
		"requires_reobservation": true,
		"guarded_followups": guarded_followups,
		"terminal_routes": [
			"route:attack_ko",
			"route:attack_pressure",
		],
		"preserve_invariants": [
			"minimum_lethal_payment",
			"current_attack_window",
			"future_search_lane",
			"next_attacker_continuity",
		],
	}


func _followup_routes_for_debt(debt: String) -> Array[String]:
	match debt:
		"bench_capacity_for_engines":
			return ["route:stadium", "route:develop"]
		"search_engine_root":
			return [
				"route:opening_search",
				"route:tutor",
				"route:develop",
			]
		"search_engine_activation", "tera_enabler_for_search_activation":
			return ["route:develop", "route:evolve", "route:noctowl_search"]
		"banked_damage_units", "live_energy_engine", \
		"energized_energy_engine", "energy_engine_width", \
		"energized_engine_width":
			return [
				"route:develop",
				"route:information",
				"route:accelerate",
			]
		"next_attacker_root", "next_attacker_attack_cost":
			return [
				"route:develop",
				"route:energy_commit",
				"route:accelerate",
			]
	return []


func _followup_routes_for_operator(operator: String) -> Array[String]:
	match operator:
		"RB_BUILD_NOCTOWL_ENGINE":
			return [
				"route:stadium",
				"route:develop",
				"route:accelerate",
			]
		"RB_EXPAND_AREA_ZERO_CAPACITY":
			return ["route:develop", "route:evolve"]
		"RB_BANK_TEAL_DANCE_ENERGY":
			return [
				"route:develop",
				"route:energy_commit",
				"route:attack_ko",
			]
	return []


func _same_attack_window(
	action_kind: String,
	target_slot: Dictionary,
	target_uid: String,
	attacker_config: Dictionary,
	observation: Dictionary,
	dynamic_cost: Dictionary,
	config: Dictionary
) -> Dictionary:
	if action_kind != "retreat" or target_slot.is_empty():
		return {
			"attack_ready": false,
			"ko_ready": false,
		}
	if target_uid == BLOODMOON_EX_UID:
		return _dynamic_bloodmoon_attack_window(
			target_slot,
			observation,
			dynamic_cost,
			config
		)
	if attacker_config.is_empty():
		return {
			"attack_ready": false,
			"ko_ready": false,
		}
	var required: Array = attacker_config.get("required_energy", []) \
		if attacker_config.get("required_energy", []) is Array else []
	var attack_ready := _cost_paid(target_slot, required)
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var damage := maxi(0, int(attacker_config.get("damage", 0)))
	var target_hp := maxi(0, int(opponent_active.get("remaining_hp", 0)))
	return {
		"attack_ready": attack_ready,
		"ko_ready": attack_ready and damage > 0 \
			and target_hp > 0 and damage >= target_hp,
		"projected_damage": damage,
		"target_remaining_hp": target_hp,
		"required_energy": required.duplicate(),
		"self_damage": maxi(0, int(attacker_config.get("self_damage", 0))),
		"proof_kind": "public_profile_attack_cost_after_pivot",
		"target_slot_id": str(target_slot.get("slot_id", "")),
		"target_uid": target_uid,
		"projected_prizes": maxi(
			1,
			int(opponent_active.get("prize_count", 1))
		),
		"requires_reobservation": true,
	}


func _dynamic_bloodmoon_attack_window(
	target_slot: Dictionary,
	observation: Dictionary,
	dynamic_cost: Dictionary,
	config: Dictionary
) -> Dictionary:
	var target_after: Dictionary = dynamic_cost.get("target_after", {}) \
		if dynamic_cost.get("target_after", {}) is Dictionary else {}
	var target_slot_id := str(target_slot.get("slot_id", ""))
	var cost_proof_matches := bool(dynamic_cost.get(
		"attack_paid_after_pivot",
		false
	)) \
		and str(target_after.get("slot_id", "")) == target_slot_id \
		and str(target_after.get("source_uid", "")).strip_edges().to_upper() \
			== BLOODMOON_EX_UID \
		and bool(target_after.get("cost_ready", false)) \
		and int(target_after.get("energy_deficit", 1)) == 0
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var damage := maxi(0, int(config.get("bloodmoon_damage", 240)))
	var target_hp := maxi(0, int(opponent_active.get("remaining_hp", 0)))
	return {
		"attack_ready": cost_proof_matches,
		"ko_ready": cost_proof_matches and damage > 0 \
			and target_hp > 0 and damage >= target_hp,
		"projected_damage": damage,
		"target_remaining_hp": target_hp,
		"projected_prizes": maxi(
			1,
			int(opponent_active.get("prize_count", 1))
		),
		"proof_kind": "public_dynamic_attack_cost_after_pivot",
		"target_slot_id": target_slot_id,
		"target_uid": BLOODMOON_EX_UID,
		"effective_energy_required": int(target_after.get(
			"effective_energy_required",
			0
		)),
		"attached_energy_units_lower_bound": int(target_after.get(
			"attached_energy_units_lower_bound",
			0
		)),
		"opponent_prizes_remaining": int(target_after.get(
			"opponent_prizes_remaining",
			6
		)),
		"requires_reobservation": true,
	}


func _cost_paid(slot: Dictionary, required: Array) -> bool:
	var attached: Array[String] = []
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary:
			var symbol := EnergySymbolsScript.from_card(raw_energy as Dictionary)
			if symbol != "":
				attached.append(symbol)
	if attached.size() < required.size():
		return false
	var remaining := attached.duplicate()
	var wildcards := 0
	for raw_required: Variant in required:
		var required_symbol := str(raw_required).strip_edges().to_upper()
		if required_symbol in ["", "C"]:
			wildcards += 1
			continue
		var index := remaining.find(required_symbol)
		if index < 0:
			return false
		remaining.remove_at(index)
	return remaining.size() >= wildcards


func _one_prize_attacker_config(uid: String, config: Dictionary) -> Dictionary:
	var attackers: Dictionary = config.get("one_prize_attackers", {}) \
		if config.get("one_prize_attackers", {}) is Dictionary else {}
	for raw_uid: Variant in attackers.keys():
		if str(raw_uid).strip_edges().to_upper() != uid:
			continue
		var value: Variant = attackers.get(raw_uid, {})
		return (value as Dictionary).duplicate(true) \
			if value is Dictionary else {}
	return {}


func _action_card_uid(action: Dictionary) -> String:
	var card: Dictionary = action.get("card", {}) \
		if action.get("card", {}) is Dictionary else {}
	return str(card.get("uid", "")).strip_edges().to_upper()


func _action_source_uid(action: Dictionary, observation: Dictionary) -> String:
	var source_card: Dictionary = action.get("source_card", {}) \
		if action.get("source_card", {}) is Dictionary else {}
	var uid := str(source_card.get("uid", "")).strip_edges().to_upper()
	if uid != "":
		return uid
	return _slot_uid(_own_slot(str(action.get("source", "")), observation))


func _own_slot(slot_id: String, observation: Dictionary) -> Dictionary:
	if slot_id == "":
		return {}
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	if str(active.get("slot_id", "")) == slot_id:
		return active
	for raw_slot: Variant in own.get("bench", []):
		if raw_slot is Dictionary \
				and str((raw_slot as Dictionary).get("slot_id", "")) == slot_id:
			return raw_slot as Dictionary
	return {}


func _slot_uid(slot: Dictionary) -> String:
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	return str(pokemon.get("uid", "")).strip_edges().to_upper()


func _has_visible_uid(observation: Dictionary, value: Variant) -> bool:
	var wanted := _upper_strings(value)
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if raw_slot is Dictionary and _slot_uid(raw_slot as Dictionary) in wanted:
			return true
	return false


func _upper_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var item := str(raw).strip_edges().to_upper()
			if item != "" and item not in result:
				result.append(item)
	return result


func _module_annotation(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) \
		if annotations.get(module_id, {}) is Dictionary else {}
