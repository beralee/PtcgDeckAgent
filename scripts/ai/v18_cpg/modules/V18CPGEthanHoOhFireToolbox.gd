extends RefCounted

## Deck-local public suffix certificates for Ethan's Ho-Oh.  The generic
## strategic-shape module remains the base fire_toolbox implementation; this
## wrapper adds only generalized same-quota retreat -> Ho-Oh attack branches
## proven from typed public invariants in the filtered observation.

const StrategicShapeScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd")

const CERTIFICATE_KIND := "public_fire_same_turn_retreat_attack_suffix"
const EVIDENCE_KIND := "public_same_turn_bound_attack_suffix"
const REACTIVE_EFFECT_IDS: Array[String] = [
	"0c65d1d9705ccf735d3780b072e3924d",
	"08e4abe39ce058b6724cf68c1e9828e4",
	"76ed73e869ac742e97ea521f200a360e",
	"1bc2bed91258ca0ecfb69e5ee8dc0c79",
	"f9db949f369ecead569fb8e3adc4eaee",
]
const PROTECTION_EFFECT_IDS: Array[String] = [
	"896c85e6588f5e35909fd0969201be21",
	"fd252ce877c709e9e3161c56ef98aff8",
]

var _module_id: String = ""
var _shape: RefCounted


func configure(module_id: String) -> void:
	_module_id = module_id if module_id == "fire_toolbox" else ""
	_shape = StrategicShapeScript.new()
	_shape.configure(_module_id)


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
	var base: Array[Dictionary] = []
	var raw_base: Variant = _shape.annotate_frontier_v2(
		frontier, observation, facts, profile, semantic_manifest
	)
	if raw_base is Array:
		for raw_candidate: Variant in raw_base as Array:
			if raw_candidate is Dictionary:
				base.append(raw_candidate as Dictionary)
	for index: int in base.size():
		var candidate := base[index].duplicate(true)
		var annotations: Dictionary = candidate.get("module_annotations", {}) \
			if candidate.get("module_annotations", {}) is Dictionary else {}
		var annotation: Dictionary = annotations.get("fire_toolbox", {}) \
			if annotations.get("fire_toolbox", {}) is Dictionary else {}
		var certificate := _same_turn_retreat_attack_suffix(
			candidate, observation, facts, profile
		)
		if not certificate.is_empty():
			annotation["same_turn_retreat_attack_suffix"] = certificate
		if bool(certificate.get("verified", false)):
			annotation["verified_advantage"] = true
			annotation["verified_advantage_kind"] = CERTIFICATE_KIND
			annotation["verified_evidence_kind"] = EVIDENCE_KIND
			var hints: Array = annotation.get("decision_hints", []) \
				if annotation.get("decision_hints", []) is Array else []
			if "pivot_to_publicly_ready_ho_oh_then_attack" not in hints:
				hints.append("pivot_to_publicly_ready_ho_oh_then_attack")
			annotation["decision_hints"] = hints
		annotations["fire_toolbox"] = annotation
		candidate["module_annotations"] = annotations
		base[index] = candidate
	return base


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	return _shape.validate_route_switch(selected, local_top, facts, profile)


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var certificate := _certificate(selected)
	if bool(certificate.get("verified", false)):
		var selected_ref: Dictionary = selected.get("action_ref", {}) \
			if selected.get("action_ref", {}) is Dictionary else {}
		var top_ref: Dictionary = local_top.get("action_ref", {}) \
			if local_top.get("action_ref", {}) is Dictionary else {}
		var target_slot_id := str(selected_ref.get("target", ""))
		var top_target_slot_id := str(top_ref.get("target", ""))
		var selected_quota := _retreat_quota_contract(selected, profile)
		var top_quota := _retreat_quota_contract(local_top, profile)
		if str(selected.get("action_kind", "")) == "retreat" \
				and str(selected.get("route_id", "")) == "route:pivot" \
				and str(local_top.get("action_kind", "")) == "retreat" \
				and str(local_top.get("route_id", "")) == "route:pivot" \
				and bool(local_top.get("engine_rule_floor_exact", false)) \
				and target_slot_id != "" and top_target_slot_id != "" \
				and target_slot_id != top_target_slot_id \
				and str(certificate.get("target_slot_id", "")) == target_slot_id \
				and str(selected.get("checkpoint_after", "")) == "action_resolved" \
				and str(local_top.get("checkpoint_after", "")) == "action_resolved" \
				and not selected_quota.is_empty() and selected_quota == top_quota \
				and _rule_target_suffix_unavailable(local_top, profile) \
				and not bool(_certificate(local_top).get("verified", false)) \
				and not bool(facts.get("attack", {}).get("ready", false)) \
				and not bool(facts.get("attack", {}).get("ko_available", false)):
			return {
				"verified": true,
				"reason": "public_ready_ho_oh_completes_same_turn_retreat_attack_suffix",
				"certificate_kind": CERTIFICATE_KIND,
				"evidence_kind": EVIDENCE_KIND,
				"interaction_owner": "not_required",
				"invariant_id": str(certificate.get("invariant_id", "")),
				"damage_floor": int(certificate.get("projected_damage", 0)),
				"prizes_now": int(certificate.get("prizes_now", 0)),
				"win_now": bool(certificate.get("win_now", false)),
				"suffix_preserved": bool(certificate.get("suffix_preserved", false)),
				"retreat_quota": selected_quota.duplicate(true),
			}
	return _shape.verify_route_advantage(selected, local_top, facts, profile)


func pick_verified_interaction_override(
	items: Array,
	step: Dictionary,
	rule_selection: Array,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	return _shape.pick_verified_interaction_override(
		items, step, rule_selection, context, profile, certificate_kind
	)


func module_id() -> String:
	return _module_id


func _same_turn_retreat_attack_suffix(
	candidate: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if _module_id != "fire_toolbox" \
			or int(profile.get("deck_id", 0)) != 800018539 \
			or str(candidate.get("action_kind", "")) != "retreat" \
			or str(candidate.get("route_id", "")) != "route:pivot":
		return {}
	var parameters := _parameters(profile)
	var raw_config: Variant = parameters.get("same_turn_retreat_attack_invariant", {})
	if not (raw_config is Dictionary):
		return {}
	return _evaluate_suffix(candidate, observation, facts, raw_config as Dictionary, profile)


func _evaluate_suffix(
	candidate: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	config: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var target_slot_id := str(action_ref.get("target", ""))
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var target := _find_bench_slot(own, target_slot_id)
	if target.is_empty():
		return {}
	var target_pokemon: Dictionary = target.get("pokemon", {}) \
		if target.get("pokemon", {}) is Dictionary else {}
	var attacker_uid := str(config.get("attacker_uid", "")).strip_edges().to_upper()
	if str(target_pokemon.get("uid", "")).strip_edges().to_upper() != attacker_uid:
		return {}
	var failure := func(reason: String) -> Dictionary:
		return {
			"schema_version": 1,
			"verified": false,
			"reason": reason,
			"invariant_id": "ethan_ho_oh_public_retreat_attack_v1",
			"certificate_kind": CERTIFICATE_KIND,
		}
	if int(config.get("schema_version", 0)) != 1 or attacker_uid == "":
		return failure.call("invalid_profile_config")
	if not bool(config.get("require_target_on_bench", false)) \
			or int(config.get("attack_index", -1)) < 0:
		return failure.call("invalid_profile_config")
	if str(candidate.get("candidate_id", "")) == "" \
			or not str(candidate.get("safe_prefix_action_id", "")).begins_with("action:retreat:") \
			or str(action_ref.get("kind", "")) != "retreat" \
			or str(candidate.get("checkpoint_after", "")) != "action_resolved":
		return failure.call("unbound_retreat_candidate")
	if str(target_pokemon.get("effect_id", "")) != str(config.get("attacker_effect_id", "")):
		return failure.call("attacker_effect_identity_mismatch")
	if int(target.get("remaining_hp", 0)) <= 0 \
			or int(target.get("max_hp", 0)) <= 0 \
			or int(target.get("damage", -1)) < 0 \
			or int(target.get("remaining_hp", 0)) + int(target.get("damage", 0)) \
				!= int(target.get("max_hp", 0)):
		return failure.call("target_not_live_or_damage_inconsistent")
	var active_pokemon: Dictionary = active.get("pokemon", {}) \
		if active.get("pokemon", {}) is Dictionary else {}
	if str(active.get("slot_id", "")) == "" \
			or str(active_pokemon.get("uid", "")).strip_edges() == "" \
			or int(active.get("remaining_hp", 0)) <= 0:
		return failure.call("current_active_not_live")
	if str((target.get("tool", {}) as Dictionary).get("uid", "")) != "" \
			if target.get("tool", {}) is Dictionary else false:
		return failure.call("target_tool_present")
	var required_fire_units := int(config.get("required_fire_units", 0))
	var fire_units := _effective_fire_units(target, config)
	if required_fire_units <= 0 or fire_units < required_fire_units:
		return failure.call("target_printed_cost_not_proven")
	var retreat_quota := _retreat_quota_contract(candidate, profile)
	if retreat_quota.is_empty():
		return failure.call("retreat_quota_not_exact")
	var retreat_cost := int(active.get("retreat_cost", -1))
	var active_energy_count := (active.get("energy", []) as Array).size() \
		if active.get("energy", []) is Array else -1
	var retreat_payment_proof := "public_attached_energy_count"
	if retreat_cost < 0 or active_energy_count < 0:
		return failure.call("retreat_cost_not_publicly_payable")
	if active_energy_count < retreat_cost:
		if not _public_free_retreat_applies(own, active, config):
			return failure.call("retreat_cost_not_publicly_payable")
		retreat_payment_proof = "public_basic_plus_live_latias_skyline"
	if bool(facts.get("attack", {}).get("ready", false)) \
			or bool(facts.get("attack", {}).get("ko_available", false)):
		return failure.call("current_active_already_attacks")
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) \
		if turn.get("quotas", {}) is Dictionary else {}
	if not bool(turn.get("deterministic_attack_window_open", false)) \
			or not bool(quotas.get("retreat_available", false)):
		return failure.call("attack_window_closed")
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var opponent_pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	if str(opponent_pokemon.get("uid", "")).strip_edges() == "" \
			or int(opponent_active.get("remaining_hp", 0)) <= 0 \
			or int(opponent_active.get("prize_count", 0)) <= 0 \
			or int(own.get("prizes_remaining", 0)) <= 0:
		return failure.call("opponent_active_state_mismatch")
	var stadium: Dictionary = observation.get("stadium", {}) \
		if observation.get("stadium", {}) is Dictionary else {}
	if not _public_opponent_semantics_supported(opponent_active, stadium, config) \
			or _has_public_blocker(opponent_active, stadium):
		return failure.call("public_protection_or_reaction_present")
	var damage := int(config.get("attack_damage", 0))
	var minimum_damage := int(config.get("minimum_projected_damage", 1))
	var projected_knockout := damage >= int(opponent_active.get("remaining_hp", 0))
	var projected_damage := mini(damage, int(opponent_active.get("remaining_hp", 0)))
	if damage <= 0 or minimum_damage <= 0 or projected_damage < minimum_damage:
		return failure.call("no_public_damage_gain")
	var prizes_now := int(opponent_active.get("prize_count", 0)) if projected_knockout else 0
	return {
		"schema_version": 1,
		"verified": true,
		"reason": "public_typed_retreat_opens_bound_ho_oh_attack",
		"invariant_id": "ethan_ho_oh_public_retreat_attack_v1",
		"certificate_kind": CERTIFICATE_KIND,
		"evidence_kind": EVIDENCE_KIND,
		"prefix": {
			"action_kind": "retreat",
			"source_slot_id": str(active.get("slot_id", "")),
			"target_slot_id": target_slot_id,
		},
		"suffix": {
			"action_kind": "attack",
			"attacker_uid": attacker_uid,
			"attack_index": int(config.get("attack_index", -1)),
		},
		"target_slot_id": target_slot_id,
		"target_remaining_hp": int(target.get("remaining_hp", 0)),
		"target_damage": int(target.get("damage", 0)),
		"fire_units": fire_units,
		"required_fire_units": required_fire_units,
		"retreat_cost": retreat_cost,
		"retreat_energy_count": active_energy_count,
		"retreat_payment_proof": retreat_payment_proof,
		"retreat_quota": retreat_quota.duplicate(true),
		"projected_damage": projected_damage,
		"projected_knockout": projected_knockout,
		"prizes_now": prizes_now,
		"win_now": prizes_now > 0 and int(own.get("prizes_remaining", 0)) <= prizes_now,
		"suffix_preserved": true,
		"attack_quota_untouched": true,
	}


func _parameters(profile: Dictionary) -> Dictionary:
	var all_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	return all_parameters.get("fire_toolbox", {}) \
		if all_parameters.get("fire_toolbox", {}) is Dictionary else {}


func _find_bench_slot(side: Dictionary, slot_id: String) -> Dictionary:
	for raw_slot: Variant in side.get("bench", []):
		if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == slot_id:
			return raw_slot as Dictionary
	return {}


func _public_free_retreat_applies(
	own: Dictionary,
	active: Dictionary,
	config: Dictionary
) -> bool:
	var active_pokemon: Dictionary = active.get("pokemon", {}) \
		if active.get("pokemon", {}) is Dictionary else {}
	if str(active_pokemon.get("stage", "")).strip_edges().to_lower() \
			!= str(config.get("free_retreat_active_stage", "")).strip_edges().to_lower():
		return false
	var provider_uid := str(config.get("free_retreat_provider_uid", "")).strip_edges().to_upper()
	var provider_effect := str(config.get("free_retreat_provider_effect_id", "")).strip_edges()
	if provider_uid == "" or provider_effect == "":
		return false
	var visible_slots: Array = []
	visible_slots.append(active)
	if own.get("bench", []) is Array:
		visible_slots.append_array(own.get("bench", []) as Array)
	for raw_slot: Variant in visible_slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot as Dictionary
		var pokemon: Dictionary = slot.get("pokemon", {}) \
			if slot.get("pokemon", {}) is Dictionary else {}
		if int(slot.get("remaining_hp", 0)) > 0 \
				and str(pokemon.get("uid", "")).strip_edges().to_upper() == provider_uid \
				and str(pokemon.get("effect_id", "")) == provider_effect:
			return true
	return false


func _retreat_quota_contract(candidate: Dictionary, profile: Dictionary) -> Dictionary:
	var config: Dictionary = _parameters(profile).get("same_turn_retreat_attack_invariant", {}) \
		if _parameters(profile).get("same_turn_retreat_attack_invariant", {}) is Dictionary else {}
	if not bool(config.get("require_exact_retreat_quota", false)):
		return {}
	var reservations: Array = candidate.get("reservations", []) \
		if candidate.get("reservations", []) is Array else []
	if reservations.size() != 1:
		return {}
	var reservation: Dictionary = reservations[0] if reservations[0] is Dictionary else {}
	if str(reservation.get("resource", "")) != "quota:retreat_or_switch" \
			or int(reservation.get("count", 0)) != 1 \
			or int(reservation.get("available", 0)) < 1 \
			or str(reservation.get("until", "")) != "action_resolved":
		return {}
	return {
		"resource": "quota:retreat_or_switch",
		"count": 1,
		"until": "action_resolved",
	}


func _rule_target_suffix_unavailable(candidate: Dictionary, profile: Dictionary) -> bool:
	var config: Dictionary = _parameters(profile).get("same_turn_retreat_attack_invariant", {}) \
		if _parameters(profile).get("same_turn_retreat_attack_invariant", {}) is Dictionary else {}
	if not bool(config.get("require_rule_suffix_unavailable", false)):
		return false
	var minimum_by_uid: Dictionary = config.get("rule_target_min_attack_energy_count_by_uid", {}) \
		if config.get("rule_target_min_attack_energy_count_by_uid", {}) is Dictionary else {}
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var annotation: Dictionary = annotations.get("fire_toolbox", {}) \
		if annotations.get("fire_toolbox", {}) is Dictionary else {}
	var snapshot: Dictionary = annotation.get("public_snapshot", {}) \
		if annotation.get("public_snapshot", {}) is Dictionary else {}
	var states: Dictionary = snapshot.get("slot_state", {}) \
		if snapshot.get("slot_state", {}) is Dictionary else {}
	var energies: Dictionary = snapshot.get("slot_energy", {}) \
		if snapshot.get("slot_energy", {}) is Dictionary else {}
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var target_slot_id := str(action_ref.get("target", ""))
	var state: Dictionary = states.get(target_slot_id, {}) \
		if states.get(target_slot_id, {}) is Dictionary else {}
	var energy: Dictionary = energies.get(target_slot_id, {}) \
		if energies.get(target_slot_id, {}) is Dictionary else {}
	var uid := str(state.get("pokemon_uid", "")).strip_edges().to_upper()
	var minimum_energy_count := int(minimum_by_uid.get(uid, 0))
	var attached_symbols: Array = energy.get("attached_symbols", []) \
		if energy.get("attached_symbols", []) is Array else []
	return target_slot_id != "" \
		and int(state.get("remaining_hp", 0)) > 0 \
		and str(state.get("tool_uid", "")) == "" \
		and minimum_energy_count > 0 \
		and attached_symbols.size() < minimum_energy_count


func _effective_fire_units(slot: Dictionary, config: Dictionary) -> int:
	var basic_uid := str(config.get("basic_fire_energy_uid", "")).strip_edges().to_upper()
	var any_uids := _canonical_uid_array(config.get("any_type_energy_uids", []))
	var conditional_uids := _canonical_uid_array(
		config.get("conditional_any_type_energy_uids", [])
	)
	var special_uids := _canonical_uid_array(config.get("special_energy_uids", []))
	var raw_effects: Variant = config.get("target_energy_effect_id_by_uid", {})
	if not (raw_effects is Dictionary):
		return -1
	var effect_by_uid: Dictionary = {}
	for raw_uid: Variant in (raw_effects as Dictionary).keys():
		var configured_uid := str(raw_uid).strip_edges().to_upper()
		var configured_effect := str(
			(raw_effects as Dictionary).get(raw_uid, "")
		).strip_edges().to_lower()
		if configured_uid == "" or configured_effect == "":
			return -1
		effect_by_uid[configured_uid] = configured_effect
	var energy_uids: Array[String] = []
	var special_count := 0
	for raw_energy: Variant in slot.get("energy", []):
		if not (raw_energy is Dictionary):
			return -1
		var uid := str((raw_energy as Dictionary).get("uid", "")).strip_edges().to_upper()
		var effect_id := str(
			(raw_energy as Dictionary).get("effect_id", "")
		).strip_edges().to_lower()
		if not effect_by_uid.has(uid) or effect_id != str(effect_by_uid.get(uid, "")):
			return -1
		energy_uids.append(uid)
		var type_name := str((raw_energy as Dictionary).get("type", "")).strip_edges().to_lower()
		if uid in special_uids or type_name == "special energy":
			special_count += 1
	var result := 0
	for uid: String in energy_uids:
		if uid == basic_uid or uid in any_uids:
			result += 1
		elif uid in conditional_uids and special_count == 1:
			result += 1
	return result


func _canonical_uid_array(raw_values: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_values is Array:
		for raw_value: Variant in raw_values as Array:
			var uid := str(raw_value).strip_edges().to_upper()
			if uid != "" and uid not in result:
				result.append(uid)
	return result


func _public_opponent_semantics_supported(
	opponent_active: Dictionary,
	stadium: Dictionary,
	config: Dictionary
) -> bool:
	var pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	if str(pokemon.get("uid", "")).strip_edges().to_upper() \
			!= str(config.get("opponent_active_uid", "")).strip_edges().to_upper() \
			or str(pokemon.get("effect_id", "")) \
			!= str(config.get("opponent_active_effect_id", "")):
		return false
	var allowed_tool_effects := _canonical_string_array(
		config.get("allowed_opponent_tool_effect_ids", [])
	)
	var tool: Dictionary = opponent_active.get("tool", {}) \
		if opponent_active.get("tool", {}) is Dictionary else {}
	if not _optional_public_effect_supported(tool, allowed_tool_effects):
		return false
	var allowed_energy_effects := _canonical_string_array(
		config.get("allowed_opponent_energy_effect_ids", [])
	)
	for raw_energy: Variant in opponent_active.get("energy", []):
		if not (raw_energy is Dictionary) \
				or not _required_public_effect_supported(
				raw_energy as Dictionary, allowed_energy_effects
			):
			return false
	var allowed_stadium_effects := _canonical_string_array(
		config.get("allowed_stadium_effect_ids", [])
	)
	return _optional_public_effect_supported(stadium, allowed_stadium_effects)


func _optional_public_effect_supported(item: Dictionary, allowed_effects: Array[String]) -> bool:
	var uid := str(item.get("uid", "")).strip_edges().to_upper()
	if uid == "":
		return item.is_empty() or str(item.get("effect_id", "")).strip_edges() == ""
	return _required_public_effect_supported(item, allowed_effects)


func _required_public_effect_supported(item: Dictionary, allowed_effects: Array[String]) -> bool:
	var uid := str(item.get("uid", "")).strip_edges().to_upper()
	var effect_id := str(item.get("effect_id", "")).strip_edges().to_lower()
	return uid != "" and effect_id != "" and effect_id in allowed_effects


func _canonical_string_array(raw_values: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_values is Array:
		for raw_value: Variant in raw_values as Array:
			var value := str(raw_value).strip_edges().to_lower()
			if value != "" and value not in result:
				result.append(value)
	return result


func _has_public_blocker(opponent_active: Dictionary, stadium: Dictionary) -> bool:
	var effect_ids: Array[String] = []
	var pokemon: Dictionary = opponent_active.get("pokemon", {}) \
		if opponent_active.get("pokemon", {}) is Dictionary else {}
	var tool: Dictionary = opponent_active.get("tool", {}) \
		if opponent_active.get("tool", {}) is Dictionary else {}
	for item: Dictionary in [pokemon, tool, stadium]:
		var effect_id := str(item.get("effect_id", ""))
		if effect_id != "":
			effect_ids.append(effect_id)
	for raw_energy: Variant in opponent_active.get("energy", []):
		if raw_energy is Dictionary:
			var effect_id := str((raw_energy as Dictionary).get("effect_id", ""))
			if effect_id != "":
				effect_ids.append(effect_id)
	for effect_id: String in effect_ids:
		if effect_id in PROTECTION_EFFECT_IDS or effect_id in REACTIVE_EFFECT_IDS:
			return true
	return false


func _certificate(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var annotation: Dictionary = annotations.get("fire_toolbox", {}) \
		if annotations.get("fire_toolbox", {}) is Dictionary else {}
	return annotation.get("same_turn_retreat_attack_suffix", {}) \
		if annotation.get("same_turn_retreat_attack_suffix", {}) is Dictionary else {}
