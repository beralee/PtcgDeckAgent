extends RefCounted

## Isolated grass-spread capability.  The generic strategic-shape module is
## retained as a read-only delegate for the established grass annotations and
## certificates; deck-800018500-specific monotonic proofs live here.

const StrategicShapeScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd")
const EnergySymbolsScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd")

var _delegate = StrategicShapeScript.new()


func configure(module_id: String) -> void:
	_delegate.configure(module_id)


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Array[Dictionary]:
	return annotate_frontier_v2(frontier, observation, facts, profile, {})


func annotate_frontier_v2(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	semantic_manifest: Dictionary
) -> Array[Dictionary]:
	var delegated: Variant = _delegate.annotate_frontier_v2(
		frontier, observation, facts, profile, semantic_manifest
	)
	var result: Array[Dictionary] = []
	if delegated is Array:
		for raw_candidate: Variant in delegated:
			if raw_candidate is Dictionary:
				result.append((raw_candidate as Dictionary).duplicate(true))
	else:
		result = frontier.duplicate(true)
	var pair := _teal_dance_productive_prefix_pair(result, observation, facts, profile)
	if pair.is_empty():
		pair = _energy_switch_productive_prefix_pair(result, observation, facts, profile)
	if pair.is_empty():
		return result
	var prefix_id := str(pair.get("prefix_candidate_id", ""))
	var attack_id := str(pair.get("attack_candidate_id", ""))
	for candidate: Dictionary in result:
		var candidate_id := str(candidate.get("candidate_id", ""))
		if candidate_id not in [prefix_id, attack_id]:
			continue
		var annotations: Dictionary = candidate.get("module_annotations", {}) \
			if candidate.get("module_annotations", {}) is Dictionary else {}
		var grass: Dictionary = annotations.get("grass_spread", {}) \
			if annotations.get("grass_spread", {}) is Dictionary else {}
		var proof := pair.duplicate(true)
		proof["pair_role"] = "productive_prefix" if candidate_id == prefix_id else "secured_terminal"
		grass["productive_prefix"] = proof
		annotations["grass_spread"] = grass
		candidate["module_annotations"] = annotations
	return result


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	return _delegate.validate_route_switch(selected, local_top, facts, profile)


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var prefix := _productive_prefix_annotation(selected)
	var terminal := _productive_prefix_annotation(local_top)
	if _verified_energy_switch_productive_prefix(prefix, terminal, selected):
		return {
			"verified": true,
			"reason": "exact_energy_switch_spreads_public_grass_before_same_secured_ko",
			"certificate_kind": str(prefix.get("certificate_kind", "")),
			"evidence_kind": "public_same_turn_productive_prefix",
			"interaction_owner": "rules_fallback",
			"prizes_floor": int(prefix.get("prizes_floor", 0)),
			"win_now": bool(prefix.get("win_now", false)),
			"target_slot_id": str(prefix.get("target_slot_id", "")),
			"energy_source_slot_id": str(prefix.get("energy_source_slot_id", "")),
			"energy_target_slot_id": str(prefix.get("energy_target_slot_id", "")),
			"projected_damage_after": int(prefix.get("projected_damage_after", 0)),
		}
	if str(prefix.get("pair_role", "")) == "productive_prefix" \
			and str(terminal.get("pair_role", "")) == "secured_terminal" \
			and bool(selected.get("engine_rule_floor_exact", false)) \
			and str(prefix.get("pair_key", "")) != "" \
			and str(prefix.get("pair_key", "")) == str(terminal.get("pair_key", "")) \
			and str(prefix.get("source_slot_id", "")) == str(terminal.get("source_slot_id", "")) \
			and str(prefix.get("target_slot_id", "")) == str(terminal.get("target_slot_id", "")) \
			and bool(prefix.get("ability_unused", false)) \
			and bool(prefix.get("visible_grass_payment", false)) \
			and bool(prefix.get("attack_legal_before", false)) \
			and bool(prefix.get("attack_legal_after", false)) \
			and bool(prefix.get("same_target", false)) \
			and bool(prefix.get("hidden_result_route_invariant", false)) \
			and not bool(prefix.get("hidden_choice_controls_suffix", true)) \
			and int(prefix.get("prizes_floor", 0)) > 0:
		return {
			"verified": true,
			"reason": "exact_teal_dance_adds_public_grass_and_draw_before_same_secured_ko",
			"certificate_kind": str(prefix.get("certificate_kind", "")),
			"evidence_kind": "public_same_turn_productive_prefix",
			"interaction_owner": "rules_fallback",
			"prizes_floor": int(prefix.get("prizes_floor", 0)),
			"win_now": bool(prefix.get("win_now", false)),
			"target_slot_id": str(prefix.get("target_slot_id", "")),
		}
	return _delegate.verify_route_advantage(selected, local_top, facts, profile)


func _verified_energy_switch_productive_prefix(
	prefix: Dictionary,
	terminal: Dictionary,
	selected: Dictionary
) -> bool:
	return str(prefix.get("pair_role", "")) == "productive_prefix" \
		and str(terminal.get("pair_role", "")) == "secured_terminal" \
		and bool(selected.get("engine_rule_floor_exact", false)) \
		and str(prefix.get("pair_key", "")) != "" \
		and str(prefix.get("pair_key", "")) == str(terminal.get("pair_key", "")) \
		and str(prefix.get("interaction_step_id", "")) == "energy_assignment" \
		and bool(prefix.get("exact_public_energy_topology", false)) \
		and bool(prefix.get("unique_rule_interaction_pair", false)) \
		and bool(prefix.get("source_reserve_preserved", false)) \
		and bool(prefix.get("backup_lane_energized", false)) \
		and bool(prefix.get("attack_legal_before", false)) \
		and bool(prefix.get("attack_legal_after", false)) \
		and bool(prefix.get("same_attack_source", false)) \
		and bool(prefix.get("same_target", false)) \
		and bool(prefix.get("ko_preserved", false)) \
		and int(prefix.get("energized_bench_after", 0)) \
			== int(prefix.get("energized_bench_before", 0)) + 1 \
		and int(prefix.get("projected_damage_after", 0)) \
			> int(prefix.get("projected_damage_before", 0)) \
		and int(prefix.get("prizes_floor", 0)) > 0


func pick_verified_interaction_override(
	items: Array,
	step: Dictionary,
	rule_selection: Array,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	var iron_config := _iron_leaves_interaction_config(profile)
	var expected_step := str(iron_config.get("interaction_step_id", "")).strip_edges().to_lower()
	if expected_step != "" and str(step.get("id", "")).strip_edges().to_lower() == expected_step:
		var binding: Dictionary = context.get("v18cpg_action_binding", {}) \
			if context.get("v18cpg_action_binding", {}) is Dictionary else {}
		if not _verified_iron_leaves_action_binding(binding, iron_config):
			return {"handled": false, "items": []}
	var result := _delegate.pick_verified_interaction_override(
		items, step, rule_selection, context, profile, certificate_kind
	)
	if bool(result.get("handled", false)) and expected_step != "":
		var evidence: Dictionary = result.get("evidence", {}) \
			if result.get("evidence", {}) is Dictionary else {}
		var binding: Dictionary = context.get("v18cpg_action_binding", {}) \
			if context.get("v18cpg_action_binding", {}) is Dictionary else {}
		evidence["action_binding_kind"] = str(binding.get("evidence_kind", ""))
		evidence["action_id"] = str(binding.get("action_id", ""))
		evidence["candidate_id"] = str(binding.get("candidate_id", ""))
		evidence["observation_hash"] = str(binding.get("observation_hash", ""))
		result["evidence"] = evidence
	return result


func _energy_switch_productive_prefix_pair(
	candidates: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var config := _energy_switch_productive_prefix_config(profile)
	if not bool(config.get("enabled", false)) \
			or int(profile.get("deck_id", 0)) != int(config.get("owner_deck_id", 0)):
		return {}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var own_active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var active_uid := str(config.get("active_pokemon_uid", "")).strip_edges().to_upper()
	var source_uid := str(config.get("energy_source_pokemon_uid", "")).strip_edges().to_upper()
	var backup_uid := str(config.get("energy_target_pokemon_uid", "")).strip_edges().to_upper()
	var energy_symbol := str(config.get("energy_symbol", "G"))
	var active_slot_id := str(own_active.get("slot_id", ""))
	var target_slot_id := str(opponent_active.get("slot_id", ""))
	if active_uid == "" \
			or source_uid == "" \
			or backup_uid == "" \
			or active_slot_id == "" \
			or target_slot_id == "" \
			or _slot_uid(own_active) != active_uid \
			or not bool(turn.get("deterministic_attack_window_open", false)) \
			or not bool(attack_facts.get("ready", false)) \
			or not bool(attack_facts.get("ko_available", false)) \
			or int(own_active.get("energy_count", 0)) != int(config.get("active_energy_count", 2)) \
			or _visible_basic_energy_count(own_active.get("energy", []), energy_symbol) \
				!= int(config.get("active_energy_count", 2)):
		return {}

	var sources: Array[Dictionary] = []
	var backups: Array[Dictionary] = []
	var energized_bench_before := 0
	var expected_source_energy := int(config.get("source_energy_before", 4))
	var expected_target_energy := int(config.get("target_energy_before", 0))
	var raw_bench: Variant = own.get("bench", [])
	if not (raw_bench is Array):
		return {}
	for raw_slot: Variant in raw_bench as Array:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		var grass_count := _visible_basic_energy_count(slot.get("energy", []), energy_symbol)
		if grass_count > 0:
			energized_bench_before += 1
		if _slot_uid(slot) == source_uid \
				and int(slot.get("energy_count", 0)) == expected_source_energy \
				and grass_count == expected_source_energy:
			sources.append(slot)
		elif _slot_uid(slot) == backup_uid \
				and int(slot.get("energy_count", 0)) == expected_target_energy \
				and grass_count == expected_target_energy:
			backups.append(slot)
	if sources.size() != 1 or backups.size() != 1:
		return {}
	var source: Dictionary = sources[0]
	var backup: Dictionary = backups[0]
	var source_slot_id := str(source.get("slot_id", ""))
	var backup_slot_id := str(backup.get("slot_id", ""))
	var reserve_after := expected_source_energy - 1
	if source_slot_id == "" \
			or backup_slot_id == "" \
			or source_slot_id == backup_slot_id \
			or reserve_after < int(config.get("source_energy_reserve_after", 3)):
		return {}

	var prefix: Dictionary = {}
	var attack: Dictionary = {}
	var expected_card_uid := str(config.get("trainer_card_uid", "")).strip_edges().to_upper()
	for candidate: Dictionary in candidates:
		var action_ref: Dictionary = candidate.get("action_ref", {}) \
			if candidate.get("action_ref", {}) is Dictionary else {}
		if str(candidate.get("action_kind", "")) == "play_trainer":
			var card_ref: Dictionary = action_ref.get("card", {}) \
				if action_ref.get("card", {}) is Dictionary else {}
			if str(card_ref.get("uid", "")).strip_edges().to_upper() == expected_card_uid \
					and bool(candidate.get("engine_rule_floor_exact", false)) \
					and str(candidate.get("checkpoint_after", "")) == "action_resolved":
				prefix = candidate
		elif str(candidate.get("action_kind", "")) in ["attack", "granted_attack"]:
			var source_card: Dictionary = action_ref.get("source_card", {}) \
				if action_ref.get("source_card", {}) is Dictionary else {}
			if str(action_ref.get("source", "")) == active_slot_id \
					and str(source_card.get("uid", "")).strip_edges().to_upper() == active_uid \
					and int(action_ref.get("attack_index", -1)) == int(config.get("attack_index", 0)) \
					and bool(action_ref.get("projected_knockout", false)) \
					and not bool(action_ref.get("requires_interaction", true)):
				var action_target := str(action_ref.get("target", target_slot_id))
				if action_target in ["", target_slot_id]:
					attack = candidate
	if prefix.is_empty() or attack.is_empty():
		return {}
	var attack_ref: Dictionary = attack.get("action_ref", {}) \
		if attack.get("action_ref", {}) is Dictionary else {}
	var damage_before := int(attack_ref.get("projected_damage", 0))
	var opponent_remaining_hp := int(opponent_active.get("remaining_hp", 0))
	var damage_gain := int(config.get("damage_per_new_energized_bench", 40))
	if opponent_remaining_hp <= 0 or damage_before < opponent_remaining_hp or damage_gain <= 0:
		return {}
	var attack_outcome: Dictionary = attack.get("outcome", {}) \
		if attack.get("outcome", {}) is Dictionary else {}
	var prizes_floor := int(attack_outcome.get("prizes_now", 0))
	if prizes_floor <= 0:
		return {}
	var pair_key := "%s|%s|%s|%s|%d" % [
		source_slot_id,
		backup_slot_id,
		active_slot_id,
		target_slot_id,
		int(attack_ref.get("attack_index", -1)),
	]
	return {
		"certificate_kind": str(config.get("certificate_kind", "")),
		"pair_key": pair_key,
		"prefix_candidate_id": str(prefix.get("candidate_id", "")),
		"attack_candidate_id": str(attack.get("candidate_id", "")),
		"interaction_step_id": str(config.get("interaction_step_id", "energy_assignment")),
		"energy_source_slot_id": source_slot_id,
		"energy_source_pokemon_uid": source_uid,
		"energy_target_slot_id": backup_slot_id,
		"energy_target_pokemon_uid": backup_uid,
		"attack_source_slot_id": active_slot_id,
		"target_slot_id": target_slot_id,
		"exact_public_energy_topology": true,
		# The strict 4G Ogerpon -> 0G backup Toedscruel ex topology is the
		# unique positive Rule interaction pair: the donor keeps its GGG attack
		# reserve while the receiver creates a new energized-bench damage unit.
		"unique_rule_interaction_pair": true,
		"source_energy_before": expected_source_energy,
		"source_energy_after": reserve_after,
		"source_reserve_preserved": true,
		"backup_energy_before": expected_target_energy,
		"backup_energy_after": expected_target_energy + 1,
		"backup_lane_energized": true,
		"energized_bench_before": energized_bench_before,
		"energized_bench_after": energized_bench_before + 1,
		"projected_damage_before": damage_before,
		"projected_damage_after": damage_before + damage_gain,
		"attack_legal_before": true,
		"attack_legal_after": true,
		"same_attack_source": true,
		"same_target": true,
		"ko_preserved": true,
		"hidden_choice_controls_suffix": false,
		"prizes_floor": prizes_floor,
		"win_now": bool(attack_outcome.get("win_now", false)),
	}


func _teal_dance_productive_prefix_pair(
	candidates: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var config := _productive_prefix_config(profile)
	if not bool(config.get("enabled", false)) \
			or int(profile.get("deck_id", 0)) != int(config.get("owner_deck_id", 0)):
		return {}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var own_active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var active_card: Dictionary = own_active.get("pokemon", {}) \
		if own_active.get("pokemon", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var source_uid := str(config.get("source_pokemon_uid", "")).strip_edges().to_upper()
	var effect_id := str(config.get("ability_effect_id", "")).strip_edges()
	var source_slot_id := str(own_active.get("slot_id", ""))
	var target_slot_id := str(opponent_active.get("slot_id", ""))
	if source_uid == "" \
			or effect_id == "" \
			or str(active_card.get("uid", "")).strip_edges().to_upper() != source_uid \
			or source_slot_id == "" \
			or target_slot_id == "" \
			or bool(own_active.get("ability_used", true)) \
			or not bool(turn.get("deterministic_attack_window_open", false)) \
			or not bool(attack_facts.get("ready", false)) \
			or not bool(attack_facts.get("ko_available", false)) \
			or int(own.get("deck_count", 0)) < int(config.get("minimum_deck_count", 1)) \
			or _visible_energy_count(own.get("hand", []), str(config.get("energy_symbol", "G"))) != int(config.get("visible_energy_count", 1)):
		return {}
	var prefix: Dictionary = {}
	var attack: Dictionary = {}
	for candidate: Dictionary in candidates:
		var action_ref: Dictionary = candidate.get("action_ref", {}) \
			if candidate.get("action_ref", {}) is Dictionary else {}
		var source_card: Dictionary = action_ref.get("source_card", {}) \
			if action_ref.get("source_card", {}) is Dictionary else {}
		if str(source_card.get("uid", "")).strip_edges().to_upper() != source_uid \
				or str(action_ref.get("source", "")) != source_slot_id:
			continue
		if str(candidate.get("action_kind", "")) == "use_ability" \
				and bool(candidate.get("engine_rule_floor_exact", false)) \
				and int(action_ref.get("ability_index", -1)) == int(config.get("ability_index", 0)) \
				and str(source_card.get("effect_id", "")) == effect_id \
				and str(candidate.get("checkpoint_after", "")) == "information_result":
			prefix = candidate
		elif str(candidate.get("action_kind", "")) in ["attack", "granted_attack"] \
				and int(action_ref.get("attack_index", -1)) == int(config.get("attack_index", 0)) \
				and bool(action_ref.get("projected_knockout", false)) \
				and int(action_ref.get("projected_damage", 0)) >= int(opponent_active.get("remaining_hp", 1)) \
				and not bool(action_ref.get("requires_interaction", true)):
			var action_target := str(action_ref.get("target", target_slot_id))
			if action_target in ["", target_slot_id]:
				attack = candidate
	if prefix.is_empty() or attack.is_empty():
		return {}
	var attack_outcome: Dictionary = attack.get("outcome", {}) \
		if attack.get("outcome", {}) is Dictionary else {}
	var prizes_floor := int(attack_outcome.get("prizes_now", 0))
	if prizes_floor <= 0:
		return {}
	var pair_key := "%s|%s|%d|%s" % [
		source_slot_id,
		target_slot_id,
		int((attack.get("action_ref", {}) as Dictionary).get("attack_index", -1)),
		str(prefix.get("safe_prefix_action_id", "")),
	]
	return {
		"certificate_kind": str(config.get("certificate_kind", "")),
		"pair_key": pair_key,
		"prefix_candidate_id": str(prefix.get("candidate_id", "")),
		"attack_candidate_id": str(attack.get("candidate_id", "")),
		"source_slot_id": source_slot_id,
		"source_pokemon_uid": source_uid,
		"ability_effect_id": effect_id,
		"target_slot_id": target_slot_id,
		"ability_unused": true,
		"visible_grass_payment": true,
		"attack_legal_before": true,
		"attack_legal_after": true,
		"same_target": true,
		# The exact registered effect has one public payment and a top-deck draw.
		# The drawn identity may alter later choices but cannot revoke the already
		# legal attack, change its source/target, or consume the attack window.
		"hidden_result_route_invariant": bool(config.get("hidden_result_route_invariant", false)),
		"hidden_choice_controls_suffix": false,
		"prizes_floor": prizes_floor,
		"win_now": bool(attack_outcome.get("win_now", false)),
	}


func _productive_prefix_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var grass: Dictionary = annotations.get("grass_spread", {}) \
		if annotations.get("grass_spread", {}) is Dictionary else {}
	return grass.get("productive_prefix", {}) as Dictionary \
		if grass.get("productive_prefix", {}) is Dictionary else {}


func _productive_prefix_config(profile: Dictionary) -> Dictionary:
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var grass: Dictionary = module_parameters.get("grass_spread", {}) \
		if module_parameters.get("grass_spread", {}) is Dictionary else {}
	return grass.get("profiled_teal_dance_before_secured_ko", {}) as Dictionary \
		if grass.get("profiled_teal_dance_before_secured_ko", {}) is Dictionary else {}


func _energy_switch_productive_prefix_config(profile: Dictionary) -> Dictionary:
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var grass: Dictionary = module_parameters.get("grass_spread", {}) \
		if module_parameters.get("grass_spread", {}) is Dictionary else {}
	return grass.get("profiled_energy_switch_before_secured_ko", {}) as Dictionary \
		if grass.get("profiled_energy_switch_before_secured_ko", {}) is Dictionary else {}


func _iron_leaves_interaction_config(profile: Dictionary) -> Dictionary:
	var module_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var grass: Dictionary = module_parameters.get("grass_spread", {}) \
		if module_parameters.get("grass_spread", {}) is Dictionary else {}
	return grass.get("profiled_iron_leaves_same_turn_prize_suffix", {}) as Dictionary \
		if grass.get("profiled_iron_leaves_same_turn_prize_suffix", {}) is Dictionary else {}


func _verified_iron_leaves_action_binding(binding: Dictionary, config: Dictionary) -> bool:
	var expected_uid := str(config.get("source_pokemon_uid", "")).strip_edges().to_upper()
	return str(binding.get("evidence_kind", "")) == "selected_action_filtered_snapshot" \
		and str(binding.get("action_kind", "")) == str(config.get("source_action_kind", "")) \
		and str(binding.get("action_card_uid", "")).strip_edges().to_upper() == expected_uid \
		and str(binding.get("owner", "")) in [
			"local_gate",
			"model_selected_local_route",
			"model_synthesized_route",
			"policy_graph_branch",
			"module_verified_upgrade",
		] \
		and str(binding.get("action_id", "")) != "" \
		and str(binding.get("candidate_id", "")) != "" \
		and str(binding.get("observation_hash", "")) != ""


func _visible_energy_count(raw_hand: Variant, expected_symbol: String) -> int:
	if not (raw_hand is Array):
		return 0
	var canonical := EnergySymbolsScript.canonical(expected_symbol)
	var count := 0
	for raw_card: Variant in raw_hand as Array:
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		var symbol := EnergySymbolsScript.canonical(card.get("energy_provides", card.get("energy_type", "")))
		if symbol == canonical and str(card.get("type", "")).contains("Energy"):
			count += 1
	return count


func _visible_basic_energy_count(raw_energy: Variant, expected_symbol: String) -> int:
	if not (raw_energy is Array):
		return 0
	var canonical := EnergySymbolsScript.canonical(expected_symbol)
	var count := 0
	for raw_card: Variant in raw_energy as Array:
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		var symbol := EnergySymbolsScript.canonical(card.get("energy_provides", card.get("energy_type", "")))
		if symbol == canonical and str(card.get("type", "")) == "Basic Energy":
			count += 1
	return count


func _slot_uid(slot: Dictionary) -> String:
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	return str(pokemon.get("uid", "")).strip_edges().to_upper()
