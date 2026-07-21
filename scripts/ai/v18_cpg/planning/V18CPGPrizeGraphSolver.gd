class_name V18CPGPrizeGraphSolver
extends RefCounted


func solve(observation: Dictionary, facts: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) if opponent.get("active", {}) is Dictionary else {}
	var prize_swing := int(opponent_active.get("prize_count", 1)) if bool(facts.get("attack", {}).get("ko_available", false)) else 0
	var own_remaining := int(own.get("prizes_remaining", 0))
	var opponent_remaining := int(opponent.get("prizes_remaining", 0))
	var max_damage := int(facts.get("attack", {}).get("max_damage", 0))
	var target_lanes := _target_lanes(opponent, max_damage)
	var maximum_visible_prize := 1
	for lane: Dictionary in target_lanes:
		maximum_visible_prize = maxi(maximum_visible_prize, int(lane.get("prize_count", 1)))
	var own_active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var opponent_energy := _board_energy_count(opponent)
	var credible_counter_ko := not own_active.is_empty() and opponent_energy >= 2
	return {
		"schema_version": 2,
		"own_prizes_remaining": own_remaining,
		"opponent_prizes_remaining": opponent_remaining,
		"current_prize_swing": prize_swing,
		"win_now": prize_swing >= own_remaining and prize_swing > 0,
		"shortest_path_turns": ceili(float(own_remaining) / float(maxi(maximum_visible_prize, 1))),
		"opponent_shortest_path_turns": ceili(float(opponent_remaining) / float(maxi(int(own_active.get("prize_count", 1)), 1))),
		"two_turn_prize_swing": prize_swing + maximum_visible_prize,
		"credible_counter_ko": credible_counter_ko,
		"target_lanes": target_lanes,
	}


## Produces a narrow public-state certificate for an attack whose registered
## card text awards one extra Prize on a knockout.  The caller supplies the two
## already-legal route candidates, so this solver never guesses attack legality
## or reaches into engine state.  Every semantic identity and every energy card
## is bound by the deck profile; incomplete public data fails closed.
func public_extra_prize_attack_terminal_certificate(
	selected: Dictionary,
	rule_floor: Dictionary,
	observation: Dictionary,
	config: Dictionary
) -> Dictionary:
	var rejected := {"verified": false, "certificate_kind": "public_extra_prize_attack_terminal"}
	if config.is_empty():
		return _certificate_rejection(rejected, "missing_profile_config")
	if int(config.get("deck_id", 0)) <= 0:
		return _certificate_rejection(rejected, "unbound_deck_id")
	if selected.is_empty() or rule_floor.is_empty() or selected == rule_floor:
		return _certificate_rejection(rejected, "missing_distinct_attack_pair")
	if not bool(rule_floor.get("engine_rule_floor_exact", false)) \
			or bool(selected.get("engine_rule_floor_exact", false)):
		return _certificate_rejection(rejected, "rule_floor_not_exact")
	if str(selected.get("route_id", "")) != "route:attack_ko" \
			or str(rule_floor.get("route_id", "")) != "route:attack_ko" \
			or str(selected.get("action_kind", "")) != "attack" \
			or str(rule_floor.get("action_kind", "")) != "attack":
		return _certificate_rejection(rejected, "attack_route_not_exact")

	var selected_ref: Dictionary = selected.get("action_ref", {}) \
		if selected.get("action_ref", {}) is Dictionary else {}
	var rule_ref: Dictionary = rule_floor.get("action_ref", {}) \
		if rule_floor.get("action_ref", {}) is Dictionary else {}
	var selected_card: Dictionary = selected_ref.get("source_card", {}) \
		if selected_ref.get("source_card", {}) is Dictionary else {}
	var rule_card: Dictionary = rule_ref.get("source_card", {}) \
		if rule_ref.get("source_card", {}) is Dictionary else {}
	var attacker_uid := str(config.get("attacker_uid", "")).strip_edges().to_upper()
	var attacker_effect_id := str(config.get("attacker_effect_id", "")).strip_edges()
	if attacker_uid == "" or attacker_effect_id == "":
		return _certificate_rejection(rejected, "unbound_attacker_identity")
	for source_card: Dictionary in [selected_card, rule_card]:
		if str(source_card.get("uid", "")).strip_edges().to_upper() != attacker_uid \
				or str(source_card.get("effect_id", "")) != attacker_effect_id:
			return _certificate_rejection(rejected, "attacker_identity_mismatch")

	var selected_source := str(selected_ref.get("source", ""))
	var rule_source := str(rule_ref.get("source", ""))
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var own_active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var own_active_card: Dictionary = own_active.get("pokemon", {}) \
		if own_active.get("pokemon", {}) is Dictionary else {}
	var own_active_slot_id := str(own_active.get("slot_id", ""))
	if selected_source == "" or selected_source != rule_source or selected_source != own_active_slot_id:
		return _certificate_rejection(rejected, "same_active_source_not_bound")
	if str(own_active_card.get("uid", "")).strip_edges().to_upper() != attacker_uid \
			or str(own_active_card.get("effect_id", "")) != attacker_effect_id:
		return _certificate_rejection(rejected, "public_active_attacker_mismatch")

	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var opponent_active_slot_id := str(opponent_active.get("slot_id", ""))
	var selected_target := str(selected_ref.get("target", ""))
	var rule_target := str(rule_ref.get("target", ""))
	var same_public_target := selected_target == rule_target \
		and (selected_target == "" or selected_target == opponent_active_slot_id)
	if opponent_active_slot_id == "" or not same_public_target:
		return _certificate_rejection(rejected, "same_opponent_active_target_not_bound")

	var bonus_attack_index := int(config.get("bonus_attack_index", -1))
	var comparison_attack_index := int(config.get("comparison_attack_index", -1))
	var bonus_damage := int(config.get("bonus_damage", 0))
	var comparison_damage := int(config.get("comparison_damage", 0))
	if int(selected_ref.get("attack_index", -1)) != bonus_attack_index \
			or int(rule_ref.get("attack_index", -1)) != comparison_attack_index \
			or bonus_attack_index < 0 or comparison_attack_index < 0 \
			or bonus_attack_index == comparison_attack_index:
		return _certificate_rejection(rejected, "attack_index_binding_mismatch")
	if int(selected_ref.get("projected_damage", -1)) != bonus_damage \
			or int(rule_ref.get("projected_damage", -1)) != comparison_damage \
			or bonus_damage <= 0 or comparison_damage <= 0:
		return _certificate_rejection(rejected, "attack_damage_binding_mismatch")
	if not bool(selected_ref.get("projected_knockout", false)) \
			or not bool(rule_ref.get("projected_knockout", false)):
		return _certificate_rejection(rejected, "both_attacks_must_project_knockout")

	var required_own_prizes := int(config.get("required_own_prizes_remaining", 0))
	var required_target_prizes := int(config.get("required_active_prize_count", 0))
	var maximum_target_hp := int(config.get("max_active_remaining_hp", 0))
	var target_hp := int(opponent_active.get("remaining_hp", 0))
	if required_own_prizes != 2 or int(own.get("prizes_remaining", 0)) != required_own_prizes:
		return _certificate_rejection(rejected, "not_exact_two_prize_closeout")
	if required_target_prizes != 1 \
			or int(opponent_active.get("prize_count", 0)) != required_target_prizes:
		return _certificate_rejection(rejected, "target_not_exact_single_prize")
	if maximum_target_hp <= 0 or target_hp <= 0 or target_hp > maximum_target_hp \
			or target_hp > bonus_damage:
		return _certificate_rejection(rejected, "target_hp_outside_bonus_attack_ko_range")
	if bool(config.get("require_live_opponent_bench", true)) and not _has_live_bench(opponent):
		return _certificate_rejection(rejected, "opponent_has_no_live_bench")

	var public_blocker := _public_blocker(opponent_active, config)
	if not public_blocker.is_empty():
		var blocked := _certificate_rejection(rejected, str(public_blocker.get("reason", "public_blocker")))
		blocked["blocker_effect_id"] = str(public_blocker.get("effect_id", ""))
		return blocked
	var energy_proof := _exact_active_energy_proof(own_active, config)
	if not bool(energy_proof.get("verified", false)):
		var energy_rejected := _certificate_rejection(rejected, str(energy_proof.get("reason", "energy_not_exact")))
		energy_rejected["energy_proof"] = energy_proof
		return energy_rejected

	var selected_outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	var rule_outcome: Dictionary = rule_floor.get("outcome", {}) \
		if rule_floor.get("outcome", {}) is Dictionary else {}
	if int(selected_outcome.get("prizes_now", 0)) != required_target_prizes \
			or int(rule_outcome.get("prizes_now", 0)) != required_target_prizes \
			or bool(selected_outcome.get("win_now", false)) \
			or bool(rule_outcome.get("win_now", false)):
		return _certificate_rejection(rejected, "base_outcome_not_exact_nonterminal_single_prize")
	var extra_prizes := int(config.get("extra_prizes", 0))
	var prizes_now := required_target_prizes + extra_prizes
	if extra_prizes != 1 or prizes_now != required_own_prizes:
		return _certificate_rejection(rejected, "extra_prize_count_not_exact_terminal")

	return {
		"verified": true,
		"certificate_kind": "public_extra_prize_attack_terminal",
		"reason": "exact_public_bonus_attack_takes_final_two_prizes",
		"deck_id": int(config.get("deck_id", 0)),
		"source_slot_id": selected_source,
		"target_slot_id": opponent_active_slot_id,
		"implicit_active_target": selected_target == "",
		"same_source": true,
		"same_target": true,
		"attacker_uid": attacker_uid,
		"attacker_effect_id": attacker_effect_id,
		"selected_attack_index": bonus_attack_index,
		"rule_attack_index": comparison_attack_index,
		"selected_damage": bonus_damage,
		"rule_damage": comparison_damage,
		"target_remaining_hp": target_hp,
		"target_prize_count": required_target_prizes,
		"extra_prizes": extra_prizes,
		"prizes_now": prizes_now,
		"own_prizes_remaining": required_own_prizes,
		"win_now": true,
		"opponent_live_bench": true,
		"public_blockers_absent": true,
		"energy_proof": energy_proof,
	}


func _certificate_rejection(base: Dictionary, reason: String) -> Dictionary:
	var result := base.duplicate(true)
	result["reason"] = reason
	return result


func _has_live_bench(side: Dictionary) -> bool:
	var bench: Array = side.get("bench", []) if side.get("bench", []) is Array else []
	for raw_slot: Variant in bench:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		if str(slot.get("slot_id", "")) != "" and int(slot.get("remaining_hp", 0)) > 0:
			return true
	return false


func _public_blocker(active: Dictionary, config: Dictionary) -> Dictionary:
	var protection_ids := _string_set(config.get("public_protection_effect_ids", []))
	var reaction_ids := _string_set(config.get("public_reaction_effect_ids", []))
	var public_cards: Array = []
	if active.get("pokemon", {}) is Dictionary:
		public_cards.append(active.get("pokemon", {}))
	if active.get("tool", {}) is Dictionary:
		public_cards.append(active.get("tool", {}))
	if active.get("energy", []) is Array:
		public_cards.append_array(active.get("energy", []))
	for raw_card: Variant in public_cards:
		if not (raw_card is Dictionary):
			continue
		var effect_id := str((raw_card as Dictionary).get("effect_id", ""))
		if effect_id in protection_ids:
			return {"reason": "public_damage_protection_present", "effect_id": effect_id}
		if effect_id in reaction_ids:
			return {"reason": "public_knockout_reaction_present", "effect_id": effect_id}
	return {}


func _exact_active_energy_proof(active: Dictionary, config: Dictionary) -> Dictionary:
	var energies: Array = active.get("energy", []) if active.get("energy", []) is Array else []
	var required_total := int(config.get("required_active_energy_count", 0))
	var wildcard_uid := str(config.get("wildcard_energy_uid", "")).strip_edges().to_upper()
	var wildcard_effect_id := str(config.get("wildcard_energy_effect_id", ""))
	var basic_uid := str(config.get("required_basic_energy_uid", "")).strip_edges().to_upper()
	var basic_effect_id := str(config.get("required_basic_energy_effect_id", ""))
	var required_wildcards := int(config.get("required_wildcard_energy_count", 0))
	var required_basics := int(config.get("required_basic_energy_count", 0))
	if required_total <= 0 or required_wildcards <= 0 or required_basics <= 0 \
			or required_wildcards + required_basics != required_total:
		return {"verified": false, "reason": "invalid_profile_energy_contract"}
	if energies.size() != required_total:
		return {"verified": false, "reason": "active_energy_count_not_exact", "count": energies.size()}
	var wildcard_count := 0
	var basic_count := 0
	for raw_energy: Variant in energies:
		if not (raw_energy is Dictionary):
			return {"verified": false, "reason": "non_public_energy_reference"}
		var energy: Dictionary = raw_energy
		var uid := str(energy.get("uid", "")).strip_edges().to_upper()
		var effect_id := str(energy.get("effect_id", ""))
		if uid == wildcard_uid and effect_id == wildcard_effect_id:
			wildcard_count += 1
			continue
		if uid == basic_uid and effect_id == basic_effect_id \
				and str(energy.get("type", "")).strip_edges().to_lower() == "basic energy":
			basic_count += 1
			continue
		return {
			"verified": false,
			"reason": "active_energy_identity_not_exact",
			"unexpected_uid": uid,
			"unexpected_effect_id": effect_id,
		}
	if wildcard_count != required_wildcards or basic_count != required_basics:
		return {
			"verified": false,
			"reason": "active_energy_mix_not_exact",
			"wildcard_count": wildcard_count,
			"basic_count": basic_count,
		}
	return {
		"verified": true,
		"legal_actions_double_bound": true,
		"required_cost": "LCCC",
		"active_energy_count": energies.size(),
		"wildcard_energy_uid": wildcard_uid,
		"wildcard_energy_count": wildcard_count,
		"basic_energy_uid": basic_uid,
		"basic_energy_count": basic_count,
		"no_additional_special_energy": true,
	}


func _string_set(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var item := str(raw).strip_edges()
			if item != "" and item not in result:
				result.append(item)
	return result


func _target_lanes(opponent: Dictionary, max_damage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var candidates: Array = []
	if opponent.get("active", {}) is Dictionary:
		candidates.append({"position": "active", "slot": opponent.get("active", {})})
	if opponent.get("bench", []) is Array:
		for raw_slot: Variant in opponent.get("bench", []):
			candidates.append({"position": "bench", "slot": raw_slot})
	for raw_candidate: Variant in candidates:
		if not (raw_candidate is Dictionary):
			continue
		var candidate: Dictionary = raw_candidate
		var slot: Dictionary = candidate.get("slot", {}) if candidate.get("slot", {}) is Dictionary else {}
		if slot.is_empty():
			continue
		var remaining_hp := int(slot.get("remaining_hp", 0))
		result.append({
			"slot_id": str(slot.get("slot_id", "")),
			"position": str(candidate.get("position", "")),
			"remaining_hp": remaining_hp,
			"prize_count": int(slot.get("prize_count", 1)),
			"ko_with_current_damage": max_damage > 0 and remaining_hp > 0 and max_damage >= remaining_hp,
			"requires_gust": str(candidate.get("position", "")) == "bench",
		})
	return result


func _board_energy_count(side: Dictionary) -> int:
	var result := 0
	if side.get("active", {}) is Dictionary:
		result += int((side.get("active", {}) as Dictionary).get("energy_count", 0))
	for raw_slot: Variant in side.get("bench", []):
		if raw_slot is Dictionary:
			result += int((raw_slot as Dictionary).get("energy_count", 0))
	return result
