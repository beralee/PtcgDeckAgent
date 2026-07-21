class_name V18CPGCopyAttackToolbox
extends RefCounted

## Exact public-state support for copied attacks.  This module deliberately
## owns only copy_attack_toolbox; broader strategic-shape behavior stays in the
## generic module.  A copied attack is certified only when the complete current
## turn suffix (copy source, copied attack and secondary target) is bound from
## public state and the configured engine effect identities.

const MODULE_ID := "copy_attack_toolbox"
const CERTIFICATE_KIND := "public_partner_same_turn_prize_breakpoint"
const EVIDENCE_KIND := "engine_registered_copy_attack_same_turn_suffix"
const PROOF_KIND := "public_copy_double_knockout_three_prize_closeout"
const SOURCE_DEVELOPMENT_CERTIFICATE_KIND := "public_copy_source_development_preserved_attack"
const SOURCE_DEVELOPMENT_EVIDENCE_KIND := "public_hand_evolution_and_same_turn_attack_suffix"
const SOURCE_DEVELOPMENT_PROOF_KIND := "darumaka_for_idle_munkidori_with_attack_suffix_preserved"
const GUST_HOLD_CERTIFICATE_KIND := "public_attackless_unbound_gust_hold"
const GUST_HOLD_EVIDENCE_KIND := "public_rule_target_and_zero_quota_development_suffix"
const GUST_HOLD_PROOF_KIND := "preserve_opponent_pivot_tax_after_attackless_development"
const ATTACK_EPOCH_CERTIFICATE_KIND := "public_attackless_gust_to_attack_epoch"
const ATTACK_EPOCH_EVIDENCE_KIND := "public_unbound_gust_threat_and_iono_information_checkpoint"
const ATTACK_EPOCH_PROOF_KIND := "reopen_public_energy_attack_suffix_before_harmful_gust"
const RECOVERY_EPOCH_CERTIFICATE_KIND := "public_copy_source_recovery_attack_epoch"
const RECOVERY_EPOCH_EVIDENCE_KIND := "public_discard_recovery_and_copy_attack_checkpoints"
const RECOVERY_EPOCH_PROOF_KIND := "night_stretcher_recovers_reshiram_before_low_value_copy_attack"

var _module_id: String = ""


func configure(module_id: String) -> void:
	_module_id = module_id if module_id == MODULE_ID else ""


func module_id() -> String:
	return _module_id


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
	if _module_id == "":
		return frontier.duplicate(true)
	var result: Array[Dictionary] = []
	var copy_source_count := _visible_role_count(observation, semantic_manifest, "copy_source")
	# This exact-state context is computed once per frontier.  Its first guards
	# are intentionally cheap so the deck-local proof does not tax normal turns.
	var gust_hold_context := _attackless_gust_hold_context(
		frontier, observation, facts, profile
	)
	var attack_epoch_context := _attackless_gust_attack_epoch_context(
		frontier, observation, facts, profile
	)
	var recovery_epoch_context := _copy_source_recovery_attack_epoch_context(
		frontier, observation, facts, profile
	)
	for candidate: Dictionary in frontier:
		var annotated := candidate.duplicate(true)
		var annotations: Dictionary = annotated.get("module_annotations", {}) \
			if annotated.get("module_annotations", {}) is Dictionary else {}
		var suffix := _strict_suffix_for_candidate(candidate, observation, facts, profile)
		var source_development := _source_development_for_candidate(
			candidate, frontier, observation, facts, profile
		)
		var gust_hold := _attackless_gust_hold_for_candidate(
			candidate, observation, gust_hold_context
		)
		var attack_epoch := _attackless_gust_attack_epoch_for_candidate(
			candidate, attack_epoch_context
		)
		var recovery_epoch := _copy_source_recovery_attack_epoch_for_candidate(
			candidate, recovery_epoch_context
		)
		var annotation := {
			"module": MODULE_ID,
			"route_id": str(candidate.get("route_id", "")),
			"action_kind": str(candidate.get("action_kind", "")),
			"copy_source_count": copy_source_count,
			"decision_hints": ["bind_copy_source", "verify_copied_cost_and_effect", "bind_complete_copy_attack_suffix"],
			"typed_attachment": _typed_attachment_for_candidate(candidate, observation, profile),
			"strict_copy_suffix": suffix,
		}
		# Local source-development parameters and their certificate vocabulary must
		# add zero wire bytes until an exact Darumaka action is actually present.
		# Otherwise common-context factoring repeats dead metadata on every request.
		if bool(source_development.get("profiled_candidate", false)):
			annotation["source_development"] = source_development
		# As with source development, this adds no model wire outside the exact
		# profiled public-state branch and its one currently eligible action.
		if not gust_hold.is_empty():
			annotation["attackless_unbound_gust_hold"] = gust_hold
		if not attack_epoch.is_empty():
			annotation["attackless_gust_to_attack_epoch"] = attack_epoch
		if not recovery_epoch.is_empty():
			annotation["copy_source_recovery_attack_epoch"] = recovery_epoch
		if bool(suffix.get("verified", false)):
			annotation["verified_advantage"] = true
			annotation["verified_advantage_kind"] = CERTIFICATE_KIND
			annotation["verified_evidence_kind"] = EVIDENCE_KIND
		elif bool(source_development.get("verified", false)):
			annotation["verified_advantage"] = true
			annotation["verified_advantage_kind"] = SOURCE_DEVELOPMENT_CERTIFICATE_KIND
			annotation["verified_evidence_kind"] = SOURCE_DEVELOPMENT_EVIDENCE_KIND
		elif bool(gust_hold.get("verified", false)):
			annotation["verified_advantage"] = true
			annotation["verified_advantage_kind"] = GUST_HOLD_CERTIFICATE_KIND
			annotation["verified_evidence_kind"] = GUST_HOLD_EVIDENCE_KIND
		elif bool(attack_epoch.get("verified", false)):
			annotation["verified_advantage"] = true
			annotation["verified_advantage_kind"] = ATTACK_EPOCH_CERTIFICATE_KIND
			annotation["verified_evidence_kind"] = ATTACK_EPOCH_EVIDENCE_KIND
		elif bool(recovery_epoch.get("verified", false)):
			annotation["verified_advantage"] = true
			annotation["verified_advantage_kind"] = RECOVERY_EPOCH_CERTIFICATE_KIND
			annotation["verified_evidence_kind"] = RECOVERY_EPOCH_EVIDENCE_KIND
		annotations[MODULE_ID] = annotation
		annotated["module_annotations"] = annotations
		result.append(annotated)
	return result


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var typed_completion := _verify_typed_attachment_completion(selected, local_top, facts)
	if bool(typed_completion.get("verified", false)):
		return {"valid": true, "reason": "copy_attack_typed_cost_completion_verified"}
	var recovery_epoch_annotation := _copy_source_recovery_attack_epoch_annotation(selected)
	if not recovery_epoch_annotation.is_empty():
		var recovery_epoch := _verify_copy_source_recovery_attack_epoch_annotation(
			selected, local_top, facts, profile
		)
		if not bool(recovery_epoch.get("verified", false)):
			return {
				"valid": false,
				"reason": "copy_source_recovery_attack_epoch_unproven",
				"module": MODULE_ID,
			}
		return {"valid": true, "reason": "copy_source_recovery_attack_epoch_verified"}
	var attack_epoch_annotation := _attackless_gust_attack_epoch_annotation(selected)
	if not attack_epoch_annotation.is_empty():
		var attack_epoch := _verify_attackless_gust_attack_epoch_annotation(
			selected, local_top, facts, profile
		)
		if not bool(attack_epoch.get("verified", false)):
			return {
				"valid": false,
				"reason": "attackless_gust_to_attack_epoch_unproven",
				"module": MODULE_ID,
			}
		return {"valid": true, "reason": "attackless_gust_to_attack_epoch_verified"}
	var gust_hold_annotation := _attackless_gust_hold_annotation(selected)
	if not gust_hold_annotation.is_empty():
		var gust_hold := _verify_attackless_gust_hold_annotation(
			selected, local_top, facts, profile
		)
		if not bool(gust_hold.get("verified", false)):
			return {
				"valid": false,
				"reason": "attackless_unbound_gust_hold_unproven",
				"module": MODULE_ID,
			}
		return {"valid": true, "reason": "attackless_unbound_gust_hold_verified"}
	if _is_profiled_source_development_candidate(selected, profile):
		var source_development := _verify_source_development_annotation(
			selected, local_top, facts, profile
		)
		if not bool(source_development.get("verified", false)):
			return {
				"valid": false,
				"reason": "copy_source_development_suffix_unproven",
				"module": MODULE_ID,
			}
		return {"valid": true, "reason": "copy_source_development_suffix_verified"}
	if not _is_profiled_copy_attack_candidate(selected, profile):
		return {"valid": true, "reason": "copy_attack_public_shape_valid"}
	if str(selected.get("candidate_id", "")) == str(local_top.get("candidate_id", "")):
		return {"valid": true, "reason": "copy_attack_exact_rule_floor"}
	var selected_outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	# A terminal outcome already proven by RouteSearch does not depend on this
	# module's copy-interaction certificate.  Keep that independent authority
	# intact; only an otherwise-unproven Night Joker deviation is fail-closed.
	if bool(selected_outcome.get("win_now", false)):
		return {"valid": true, "reason": "copy_attack_independent_terminal_outcome"}
	var proof := _verify_strict_suffix_annotation(selected, local_top, profile)
	if not bool(proof.get("verified", false)):
		return {
			"valid": false,
			"reason": "copy_attack_complete_suffix_unproven",
			"module": MODULE_ID,
		}
	return {"valid": true, "reason": "copy_attack_complete_suffix_verified"}


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var typed_completion := _verify_typed_attachment_completion(selected, local_top, facts)
	if bool(typed_completion.get("verified", false)):
		return typed_completion
	var recovery_epoch := _verify_copy_source_recovery_attack_epoch_annotation(
		selected, local_top, facts, profile
	)
	if bool(recovery_epoch.get("verified", false)):
		return recovery_epoch
	var attack_epoch := _verify_attackless_gust_attack_epoch_annotation(
		selected, local_top, facts, profile
	)
	if bool(attack_epoch.get("verified", false)):
		return attack_epoch
	var gust_hold := _verify_attackless_gust_hold_annotation(
		selected, local_top, facts, profile
	)
	if bool(gust_hold.get("verified", false)):
		return gust_hold
	var source_development := _verify_source_development_annotation(
		selected, local_top, facts, profile
	)
	if bool(source_development.get("verified", false)):
		return source_development
	return _verify_strict_suffix_annotation(selected, local_top, profile)


func _verify_typed_attachment_completion(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary
) -> Dictionary:
	var selected_attachment := _typed_attachment_annotation(selected)
	var top_attachment := _typed_attachment_annotation(local_top)
	var selected_outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	var top_outcome: Dictionary = local_top.get("outcome", {}) \
		if local_top.get("outcome", {}) is Dictionary else {}
	if str(selected.get("route_id", "")) == "route:energy_commit" \
			and bool(selected_attachment.get("target_is_profiled_attacker", false)) \
			and bool(selected_attachment.get("target_is_active", false)) \
			and bool(selected_attachment.get("adds_missing_required_type", false)) \
			and bool(selected_attachment.get("deterministic_attack_window_open", false)) \
			and bool(selected_attachment.get("completes_required_types", false)) \
			and not bool(top_attachment.get("completes_required_types", false)) \
			and not bool((facts.get("attack", {}) as Dictionary).get("ready", false)) \
			and not bool((facts.get("attack", {}) as Dictionary).get("ko_available", false)) \
			and str(local_top.get("route_id", "")) not in ["route:attack_ko", "route:attack_pressure"] \
			and not bool(top_outcome.get("win_now", false)) \
			and int(top_outcome.get("prizes_now", 0)) <= int(selected_outcome.get("prizes_now", 0)):
		return {
			"verified": true,
			"reason": "profiled_typed_attachment_closes_public_attack_cost_gap",
			"certificate_kind": "public_typed_attack_cost_completion",
			"interaction_owner": "not_required",
		}
	return {"verified": false}


func pick_verified_interaction_override(
	items: Array,
	step: Dictionary,
	_rule_selection: Array,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	if _module_id != MODULE_ID:
		return {"handled": false, "items": []}
	if certificate_kind == RECOVERY_EPOCH_CERTIFICATE_KIND:
		return _pick_copy_source_recovery_item(items, step, context, profile)
	if certificate_kind != CERTIFICATE_KIND:
		return {"handled": false, "items": []}
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var board := _strict_board_snapshot(observation, profile)
	if not bool(board.get("verified", false)):
		return {"handled": false, "items": []}
	var config := _strict_suffix_config(profile)
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	if step_id == str(config.get("copy_step_id", "")).strip_edges().to_lower():
		var copy_matches: Array = []
		for item: Variant in items:
			if _copy_option_matches(item, board, config):
				copy_matches.append(item)
		if copy_matches.size() != 1:
			return {"handled": false, "items": []}
		return {
			"handled": true,
			"items": [copy_matches[0]],
			"reason": "bind_profiled_darmanitan_copied_attack",
			"certificate_kind": CERTIFICATE_KIND,
			"proof_kind": PROOF_KIND,
		}
	if step_id == str(config.get("bench_step_id", "")).strip_edges().to_lower():
		var target_matches: Array = []
		for item: Variant in items:
			if _bench_target_matches(item, board, config):
				target_matches.append(item)
		if target_matches.size() != 1:
			return {"handled": false, "items": []}
		return {
			"handled": true,
			"items": [target_matches[0]],
			"reason": "bind_public_two_prize_bench_knockout_target",
			"certificate_kind": CERTIFICATE_KIND,
			"proof_kind": PROOF_KIND,
		}
	return {"handled": false, "items": []}


func _copy_source_recovery_attack_epoch_context(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var config := _copy_source_recovery_attack_epoch_config(profile)
	var public_state := _copy_source_recovery_public_state(observation, facts, config)
	if public_state.is_empty():
		return {}
	var rule_floor := _exact_rule_floor(frontier)
	if not _rule_floor_is_profiled_low_value_copy_attack(rule_floor, config):
		return {}
	public_state.merge({
		"rule_floor_candidate_id": str(rule_floor.get("candidate_id", "")),
		"rule_floor_action_id": str(rule_floor.get("safe_prefix_action_id", "")),
		"rule_floor_route_id": str(rule_floor.get("route_id", "")),
	}, true)
	return public_state


func _copy_source_recovery_public_state(
	observation: Dictionary,
	facts: Dictionary,
	config: Dictionary
) -> Dictionary:
	if config.is_empty() or not bool(config.get("enabled", false)):
		return {}
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	if not bool(turn.get("deterministic_attack_window_open", false)):
		return {}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	if not bool(attack_facts.get("ready", false)) \
			or bool(attack_facts.get("ko_available", false)):
		return {}
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	if int(own.get("prizes_remaining", -1)) \
			!= int(config.get("required_own_prizes", -2)) \
			or int(opponent.get("prizes_remaining", -1)) \
			!= int(config.get("required_opponent_prizes", -2)) \
			or int(opponent.get("hand_count", -1)) \
			!= int(config.get("required_opponent_hand_count", -2)) \
			or int(own.get("deck_count", -1)) \
			!= int(config.get("expected_own_deck_count", -2)):
		return {}
	var active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	if _slot_uid(active) != _upper(str(config.get("attacker_uid", ""))) \
			or int(active.get("energy_count", -1)) \
			!= int(config.get("attacker_energy_count", -2)) \
			or int(active.get("remaining_hp", -1)) \
			!= int(config.get("attacker_remaining_hp", -2)):
		return {}
	if not _public_bench_uids_match(own, config.get("expected_own_bench_uids", [])):
		return {}
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var visible_free_slots := maxi(0, 5 - bench.size())
	var resources: Dictionary = facts.get("resources", {}) \
		if facts.get("resources", {}) is Dictionary else {}
	if visible_free_slots != int(resources.get("bench_slots_free", visible_free_slots)) \
			or visible_free_slots < int(config.get("minimum_free_bench_slots", 1)):
		return {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var remaining_hp := int(opponent_active.get("remaining_hp", 0))
	if _slot_uid(opponent_active) != _upper(str(config.get("opponent_active_uid", ""))) \
			or remaining_hp != int(config.get("opponent_active_remaining_hp", -1)) \
			or remaining_hp <= int(config.get("rule_copy_damage_before", 0)) \
			or remaining_hp > int(config.get("copy_damage_after", 0)) \
			or int(opponent_active.get("energy_count", -1)) \
			!= int(config.get("opponent_active_energy_count", -2)) \
			or int(opponent_active.get("prize_count", -1)) \
			!= int(config.get("opponent_active_prize_count", -2)) \
			or _slot_has_public_damage_protection(opponent_active, config):
		return {}
	var copy_source_uid := str(config.get("copy_source_uid", ""))
	var recovery_card_uid := str(config.get("recovery_card_uid", ""))
	if _field_uid_count(own, copy_source_uid) != 0:
		return {}
	var source_in_discard := _discard_identity_count(own, copy_source_uid)
	var source_in_hand := _public_hand_uid_count(own, copy_source_uid)
	var recovery_in_hand := _public_hand_uid_count(own, recovery_card_uid)
	var stage := ""
	if source_in_discard == 1 and source_in_hand == 0 and recovery_in_hand == 1:
		stage = "recover_copy_source"
	elif source_in_discard == 0 and source_in_hand == 1 and recovery_in_hand == 0:
		stage = "bench_recovered_copy_source"
	else:
		return {}
	return {
		"stage": stage,
		"attacker_slot_id": str(active.get("slot_id", "")),
		"attacker_uid": _slot_uid(active),
		"attacker_energy_count": int(active.get("energy_count", 0)),
		"attacker_remaining_hp": int(active.get("remaining_hp", 0)),
		"own_prizes_remaining": int(own.get("prizes_remaining", 0)),
		"opponent_prizes_remaining": int(opponent.get("prizes_remaining", 0)),
		"opponent_hand_count": int(opponent.get("hand_count", 0)),
		"own_deck_count": int(own.get("deck_count", 0)),
		"own_bench_uids": _public_bench_uids(own),
		"bench_slots_before": visible_free_slots,
		"opponent_active_slot_id": str(opponent_active.get("slot_id", "")),
		"opponent_active_uid": _slot_uid(opponent_active),
		"opponent_active_remaining_hp": remaining_hp,
		"opponent_active_energy_count": int(opponent_active.get("energy_count", 0)),
		"opponent_active_prize_count": int(opponent_active.get("prize_count", 0)),
		"copy_source_uid": _upper(copy_source_uid),
		"copy_source_effect_id": str(config.get("copy_source_effect_id", "")),
		"copy_source_in_discard": source_in_discard,
		"copy_source_in_hand": source_in_hand,
		"recovery_card_uid": _upper(recovery_card_uid),
		"recovery_card_effect_id": str(config.get("recovery_card_effect_id", "")),
		"recovery_card_in_hand": recovery_in_hand,
		"rule_copy_source_uid": _upper(str(config.get("rule_copy_source_uid", ""))),
		"rule_copy_damage_before": int(config.get("rule_copy_damage_before", 0)),
		"copy_damage_after": int(config.get("copy_damage_after", 0)),
		"prizes_floor": int(opponent_active.get("prize_count", 0)),
	}


func _copy_source_recovery_attack_epoch_for_candidate(
	candidate: Dictionary,
	context: Dictionary
) -> Dictionary:
	if context.is_empty():
		return {}
	var stage := str(context.get("stage", ""))
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var action_uid := _action_ref_card_uid(action_ref)
	var eligible := false
	if stage == "recover_copy_source":
		eligible = str(candidate.get("action_kind", "")) == "play_trainer" \
			and str(candidate.get("route_id", "")) == "route:recover" \
			and str(candidate.get("checkpoint_after", "")) == "action_resolved" \
			and action_uid == str(context.get("recovery_card_uid", ""))
	elif stage == "bench_recovered_copy_source":
		eligible = str(candidate.get("action_kind", "")) == "play_basic_to_bench" \
			and str(candidate.get("route_id", "")) == "route:develop" \
			and str(candidate.get("checkpoint_after", "")) == "action_resolved" \
			and action_uid == str(context.get("copy_source_uid", ""))
	if not eligible:
		return {}
	var result := context.duplicate(true)
	result.merge({
		"schema_version": 1,
		"verified": true,
		"certificate_kind": RECOVERY_EPOCH_CERTIFICATE_KIND,
		"evidence_kind": RECOVERY_EPOCH_EVIDENCE_KIND,
		"proof_kind": RECOVERY_EPOCH_PROOF_KIND,
		"candidate_id": str(candidate.get("candidate_id", "")),
		"candidate_action_id": str(candidate.get("safe_prefix_action_id", "")),
		"candidate_action_kind": str(candidate.get("action_kind", "")),
		"candidate_route_id": str(candidate.get("route_id", "")),
		"candidate_card_uid": action_uid,
		"checkpoint_after": str(candidate.get("checkpoint_after", "")),
		"information_checkpoint_crossed": true,
		"requires_public_replan": true,
		"interaction_owner": "module_verified_interaction_override" \
			if stage == "recover_copy_source" else "not_required",
		"terminal_status": "replan_after_public_recovery" \
			if stage == "recover_copy_source" else "replan_after_public_bench",
	}, true)
	result["binding_hash"] = _copy_source_recovery_attack_epoch_binding_hash(result)
	return result


func _verify_copy_source_recovery_attack_epoch_annotation(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var annotation := _copy_source_recovery_attack_epoch_annotation(selected)
	if annotation.is_empty() or not bool(local_top.get("engine_rule_floor_exact", false)):
		return {"verified": false}
	var config := _copy_source_recovery_attack_epoch_config(profile)
	if config.is_empty() \
			or not _rule_floor_is_profiled_low_value_copy_attack(local_top, config):
		return {"verified": false}
	var stage := str(annotation.get("stage", ""))
	var action_ref: Dictionary = selected.get("action_ref", {}) \
		if selected.get("action_ref", {}) is Dictionary else {}
	var expected_action_kind := "play_trainer" if stage == "recover_copy_source" \
		else "play_basic_to_bench"
	var expected_route_id := "route:recover" if stage == "recover_copy_source" \
		else "route:develop"
	var expected_card_uid := _upper(str(config.get("recovery_card_uid", ""))) \
		if stage == "recover_copy_source" else _upper(str(config.get("copy_source_uid", "")))
	if stage not in ["recover_copy_source", "bench_recovered_copy_source"] \
			or int(annotation.get("schema_version", 0)) != 1 \
			or not bool(annotation.get("verified", false)) \
			or str(annotation.get("certificate_kind", "")) != RECOVERY_EPOCH_CERTIFICATE_KIND \
			or str(annotation.get("evidence_kind", "")) != RECOVERY_EPOCH_EVIDENCE_KIND \
			or str(annotation.get("proof_kind", "")) != RECOVERY_EPOCH_PROOF_KIND \
			or str(annotation.get("candidate_id", "")) != str(selected.get("candidate_id", "")) \
			or str(annotation.get("candidate_action_id", "")) \
			!= str(selected.get("safe_prefix_action_id", "")) \
			or str(annotation.get("candidate_action_kind", "")) != expected_action_kind \
			or str(annotation.get("candidate_route_id", "")) != expected_route_id \
			or str(annotation.get("candidate_card_uid", "")) != expected_card_uid \
			or _action_ref_card_uid(action_ref) != expected_card_uid \
			or str(annotation.get("checkpoint_after", "")) != "action_resolved" \
			or str(annotation.get("rule_floor_candidate_id", "")) \
			!= str(local_top.get("candidate_id", "")) \
			or str(annotation.get("rule_floor_action_id", "")) \
			!= str(local_top.get("safe_prefix_action_id", "")) \
			or int(annotation.get("rule_copy_damage_before", 0)) \
			!= int(config.get("rule_copy_damage_before", 0)) \
			or int(annotation.get("copy_damage_after", 0)) \
			!= int(config.get("copy_damage_after", 0)) \
			or int(annotation.get("opponent_active_remaining_hp", 0)) \
			<= int(annotation.get("rule_copy_damage_before", 0)) \
			or int(annotation.get("opponent_active_remaining_hp", 0)) \
			> int(annotation.get("copy_damage_after", 0)) \
			or int(annotation.get("prizes_floor", 0)) \
			!= int(config.get("opponent_active_prize_count", 0)) \
			or not bool(annotation.get("information_checkpoint_crossed", false)) \
			or not bool(annotation.get("requires_public_replan", false)) \
			or str(annotation.get("binding_hash", "")) == "" \
			or str(annotation.get("binding_hash", "")) \
			!= _copy_source_recovery_attack_epoch_binding_hash(annotation):
		return {"verified": false}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	if not bool(attack_facts.get("ready", false)) \
			or bool(attack_facts.get("ko_available", false)):
		return {"verified": false}
	return {
		"verified": true,
		"reason": "public_reshiram_recovery_replaces_non_ko_zorua_copy_attack",
		"certificate_kind": RECOVERY_EPOCH_CERTIFICATE_KIND,
		"evidence_kind": RECOVERY_EPOCH_EVIDENCE_KIND,
		"proof_kind": RECOVERY_EPOCH_PROOF_KIND,
		"stage": stage,
		"interaction_owner": str(annotation.get("interaction_owner", "not_required")),
		"terminal_status": str(annotation.get("terminal_status", "")),
		"prizes_floor": int(annotation.get("prizes_floor", 0)),
		"win_now": false,
	}


func _copy_source_recovery_attack_epoch_binding_hash(annotation: Dictionary) -> String:
	var bound := annotation.duplicate(true)
	bound.erase("binding_hash")
	return JSON.stringify(bound).sha256_text()


func _pick_copy_source_recovery_item(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var config := _copy_source_recovery_attack_epoch_config(profile)
	var observation: Dictionary = context.get("v18cpg_observation", {}) \
		if context.get("v18cpg_observation", {}) is Dictionary else {}
	var facts: Dictionary = context.get("v18cpg_facts", {}) \
		if context.get("v18cpg_facts", {}) is Dictionary else {}
	var public_state := _copy_source_recovery_public_state(observation, facts, config)
	if str(public_state.get("stage", "")) != "recover_copy_source" \
			or str(step.get("id", "")).strip_edges().to_lower() \
			!= str(config.get("recovery_step_id", "")).strip_edges().to_lower() \
			or int(step.get("min_select", 1)) != 1 \
			or int(step.get("max_select", 1)) != 1:
		return {"handled": false, "items": []}
	var matches: Array = []
	for item: Variant in items:
		if _recoverable_copy_source_item_matches(item, config):
			matches.append(item)
	if matches.size() != 1:
		return {"handled": false, "items": []}
	return {
		"handled": true,
		"items": [matches[0]],
		"reason": "bind_unique_public_reshiram_recovery",
		"certificate_kind": RECOVERY_EPOCH_CERTIFICATE_KIND,
		"proof_kind": RECOVERY_EPOCH_PROOF_KIND,
		"stage": "recover_copy_source",
	}


func _source_development_for_candidate(
	candidate: Dictionary,
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var result := {
		"schema_version": 1,
		"profiled_candidate": _is_profiled_source_development_candidate(candidate, profile),
		"verified": false,
		"certificate_kind": SOURCE_DEVELOPMENT_CERTIFICATE_KIND,
		"evidence_kind": SOURCE_DEVELOPMENT_EVIDENCE_KIND,
		"proof_kind": SOURCE_DEVELOPMENT_PROOF_KIND,
	}
	if not bool(result.get("profiled_candidate", false)):
		return result
	var config := _source_development_config(profile)
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	if not bool(turn.get("deterministic_attack_window_open", false)):
		result["failed_guard"] = "attack_window_closed"
		return result
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	if int(own.get("prizes_remaining", 0)) != int(config.get("required_prizes", 3)):
		result["failed_guard"] = "wrong_prize_window"
		return result
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var visible_free_slots := maxi(0, 5 - bench.size())
	var fact_resources: Dictionary = facts.get("resources", {}) \
		if facts.get("resources", {}) is Dictionary else {}
	var fact_free_slots := int(fact_resources.get("bench_slots_free", visible_free_slots))
	if visible_free_slots != fact_free_slots \
			or visible_free_slots < int(config.get("minimum_free_bench_slots", 2)):
		result["failed_guard"] = "bench_reserve_unproven"
		return result
	if _field_identity_count(own, config, "candidate") > 0 \
			or _field_identity_count(own, config, "evolution") > 0:
		result["failed_guard"] = "copy_source_already_on_field"
		return result
	if bool(config.get("require_evolution_in_public_hand", true)):
		var evolution_in_hand := _public_hand_identity_count(own, config, "evolution")
		if evolution_in_hand != 1:
			result["failed_guard"] = "evolution_not_uniquely_public_in_hand"
			return result
	if _discard_identity_count(own, str(config.get("evolution_uid", ""))) > 0:
		result["failed_guard"] = "evolution_publicly_discarded"
		return result
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	if not _slot_identity_matches(active, config, "attacker") \
			or not _attached_symbols_pay_cost(
				_slot_energy_symbols(active), _string_array(config.get("attacker_cost", []))
			):
		result["failed_guard"] = "attacker_or_cost_unproven"
		return result
	var attack_facts: Dictionary = facts.get("attack", {}) if facts.get("attack", {}) is Dictionary else {}
	if not bool(attack_facts.get("ready", false)):
		result["failed_guard"] = "rule_attack_not_ready"
		return result
	if bool(config.get("require_no_own_damage", true)) and _own_has_damage(own):
		result["failed_guard"] = "munkidori_public_damage_transfer_urgent"
		return result
	var rule_floor := _exact_rule_floor(frontier)
	if not _rule_floor_is_profiled_idle_munkidori(rule_floor, config):
		result["failed_guard"] = "idle_munkidori_rule_floor_missing"
		return result
	var preserved_attack := _preserved_attack_candidate(frontier, active, config)
	if bool(config.get("require_preserved_attack_candidate", true)) and preserved_attack.is_empty():
		result["failed_guard"] = "complete_rule_attack_suffix_missing"
		return result
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var attack_ref: Dictionary = preserved_attack.get("action_ref", {}) \
		if preserved_attack.get("action_ref", {}) is Dictionary else {}
	result.merge({
		"candidate_id": str(candidate.get("candidate_id", "")),
		"candidate_action_id": str(candidate.get("safe_prefix_action_id", "")),
		"candidate_uid": _action_ref_card_uid(action_ref),
		"rule_floor_candidate_id": str(rule_floor.get("candidate_id", "")),
		"rule_floor_action_id": str(rule_floor.get("safe_prefix_action_id", "")),
		"rule_floor_uid": _action_ref_card_uid(
			rule_floor.get("action_ref", {}) if rule_floor.get("action_ref", {}) is Dictionary else {}
		),
		"attacker_slot_id": str(active.get("slot_id", "")),
		"attacker_uid": _slot_uid(active),
		"preserved_attack_candidate_id": str(preserved_attack.get("candidate_id", "")),
		"preserved_attack_action_id": str(preserved_attack.get("safe_prefix_action_id", "")),
		"preserved_attack_index": int(attack_ref.get("attack_index", -1)),
		"preserved_attack_route_id": str(preserved_attack.get("route_id", "")),
		"preserved_attack_prizes_now": int(
			(preserved_attack.get("outcome", {}) as Dictionary).get("prizes_now", 0)
			if preserved_attack.get("outcome", {}) is Dictionary else 0
		),
		"same_quota_replacement": true,
		"attack_quota_preserved": true,
		"energy_quota_preserved": true,
		"supporter_quota_preserved": true,
		"information_checkpoint_crossed": false,
		"evolution_public_in_hand": true,
		"munkidori_urgent": false,
		"bench_slots_after": visible_free_slots - 1,
		"verified": true,
	}, true)
	result["binding_hash"] = _source_development_binding_hash(result)
	return result


func _verify_source_development_annotation(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if not _is_profiled_source_development_candidate(selected, profile) \
			or not bool(local_top.get("engine_rule_floor_exact", false)):
		return {"verified": false}
	var config := _source_development_config(profile)
	if not _rule_floor_is_profiled_idle_munkidori(local_top, config):
		return {"verified": false}
	var annotation := _source_development_annotation(selected)
	if not bool(annotation.get("verified", false)) \
			or int(annotation.get("schema_version", 0)) != 1 \
			or str(annotation.get("certificate_kind", "")) != SOURCE_DEVELOPMENT_CERTIFICATE_KIND \
			or str(annotation.get("evidence_kind", "")) != SOURCE_DEVELOPMENT_EVIDENCE_KIND \
			or str(annotation.get("proof_kind", "")) != SOURCE_DEVELOPMENT_PROOF_KIND \
			or not bool(annotation.get("same_quota_replacement", false)) \
			or not bool(annotation.get("attack_quota_preserved", false)) \
			or not bool(annotation.get("energy_quota_preserved", false)) \
			or not bool(annotation.get("supporter_quota_preserved", false)) \
			or bool(annotation.get("information_checkpoint_crossed", true)) \
			or not bool(annotation.get("evolution_public_in_hand", false)) \
			or bool(annotation.get("munkidori_urgent", true)) \
			or int(annotation.get("bench_slots_after", 0)) < 1 \
			or str(annotation.get("binding_hash", "")) == "" \
			or str(annotation.get("binding_hash", "")) != _source_development_binding_hash(annotation):
		return {"verified": false}
	var attack_facts: Dictionary = facts.get("attack", {}) if facts.get("attack", {}) is Dictionary else {}
	if not bool(attack_facts.get("ready", false)) \
			or str(annotation.get("candidate_id", "")) != str(selected.get("candidate_id", "")) \
			or str(annotation.get("rule_floor_candidate_id", "")) != str(local_top.get("candidate_id", "")) \
			or str(annotation.get("preserved_attack_candidate_id", "")) == "" \
			or str(annotation.get("preserved_attack_action_id", "")) == "":
		return {"verified": false}
	return {
		"verified": true,
		"reason": "public_darumaka_replaces_idle_munkidori_and_preserves_ready_attack",
		"certificate_kind": SOURCE_DEVELOPMENT_CERTIFICATE_KIND,
		"evidence_kind": SOURCE_DEVELOPMENT_EVIDENCE_KIND,
		"proof_kind": SOURCE_DEVELOPMENT_PROOF_KIND,
		"interaction_owner": "not_required",
		"rule_floor_candidate_id": str(annotation.get("rule_floor_candidate_id", "")),
		"preserved_attack_candidate_id": str(annotation.get("preserved_attack_candidate_id", "")),
		"preserved_attack_action_id": str(annotation.get("preserved_attack_action_id", "")),
		"prizes_floor": int(annotation.get("preserved_attack_prizes_now", 0)),
		"win_now": false,
	}


func _source_development_binding_hash(annotation: Dictionary) -> String:
	return JSON.stringify([
		int(annotation.get("schema_version", 0)),
		str(annotation.get("certificate_kind", "")),
		str(annotation.get("evidence_kind", "")),
		str(annotation.get("proof_kind", "")),
		str(annotation.get("candidate_id", "")),
		str(annotation.get("candidate_action_id", "")),
		str(annotation.get("candidate_uid", "")),
		str(annotation.get("rule_floor_candidate_id", "")),
		str(annotation.get("rule_floor_action_id", "")),
		str(annotation.get("rule_floor_uid", "")),
		str(annotation.get("attacker_slot_id", "")),
		str(annotation.get("attacker_uid", "")),
		str(annotation.get("preserved_attack_candidate_id", "")),
		str(annotation.get("preserved_attack_action_id", "")),
		int(annotation.get("preserved_attack_index", -1)),
		str(annotation.get("preserved_attack_route_id", "")),
		int(annotation.get("preserved_attack_prizes_now", 0)),
		bool(annotation.get("same_quota_replacement", false)),
		bool(annotation.get("attack_quota_preserved", false)),
		bool(annotation.get("energy_quota_preserved", false)),
		bool(annotation.get("supporter_quota_preserved", false)),
		bool(annotation.get("information_checkpoint_crossed", true)),
		bool(annotation.get("evolution_public_in_hand", false)),
		bool(annotation.get("munkidori_urgent", true)),
		int(annotation.get("bench_slots_after", 0)),
	]).sha256_text()


func _attackless_gust_attack_epoch_context(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var config := _attackless_gust_attack_epoch_config(profile)
	if config.is_empty() or not bool(config.get("enabled", false)):
		return {}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var fact_turn: Dictionary = facts.get("turn", {}) if facts.get("turn", {}) is Dictionary else {}
	if bool(attack_facts.get("ready", false)) \
			or bool(attack_facts.get("ko_available", false)) \
			or int(attack_facts.get("max_damage", 0)) > 0 \
			or not bool(fact_turn.get("supporter_available", false)) \
			or not bool(fact_turn.get("energy_available", false)):
		return {}
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) if turn.get("quotas", {}) is Dictionary else {}
	if not bool(turn.get("deterministic_attack_window_open", false)) \
			or not bool(quotas.get("supporter_available", false)) \
			or not bool(quotas.get("energy_available", false)):
		return {}
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	if _slot_uid(active) != _upper(str(config.get("attacker_uid", ""))) \
			or int(active.get("energy_count", -1)) != int(config.get("attacker_energy_count", -2)) \
			or int(active.get("remaining_hp", -1)) != int(config.get("attacker_remaining_hp", -2)) \
			or int(own.get("prizes_remaining", -1)) != int(config.get("required_own_prizes", -2)) \
			or int(own.get("deck_count", -1)) != int(config.get("expected_own_deck_count", -2)) \
			or not _public_hand_uids_match(own, config.get("expected_hand_uids", [])) \
			or not _public_bench_uids_match(own, config.get("expected_own_bench_uids", [])):
		return {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	if _slot_uid(opponent_active) != _upper(str(config.get("opponent_active_uid", ""))) \
			or int(opponent_active.get("energy_count", -1)) \
				!= int(config.get("opponent_active_energy_count", -2)) \
			or int(opponent.get("prizes_remaining", -1)) \
				!= int(config.get("required_opponent_prizes", -2)) \
			or int(opponent.get("hand_count", -1)) \
				!= int(config.get("required_opponent_hand_count", -2)):
		return {}
	var rule_floor := _exact_rule_floor(frontier)
	if not _rule_floor_is_profiled_unbound_gust(rule_floor, config):
		return {}
	var target_proof := _recompute_public_rule_gust_target(opponent, config)
	if not bool(target_proof.get("verified", false)):
		return {}
	var active_retreat_cost := int(config.get("opponent_active_retreat_cost", 0))
	var active_energy_count := int(opponent_active.get("energy_count", 0))
	var pivot_energy_deficit := maxi(0, active_retreat_cost - active_energy_count)
	var target_energy_count := int(target_proof.get("energy_count", 0))
	var target_attack_cost := int(config.get("expected_rule_target_immediate_attack_cost", 0))
	if pivot_energy_deficit <= 0 \
			or target_attack_cost <= 0 \
			or target_energy_count < target_attack_cost:
		return {}
	return {
		"config": config,
		"rule_floor_candidate_id": str(rule_floor.get("candidate_id", "")),
		"rule_floor_action_id": str(rule_floor.get("safe_prefix_action_id", "")),
		"rule_floor_uid": _action_ref_card_uid(
			rule_floor.get("action_ref", {}) if rule_floor.get("action_ref", {}) is Dictionary else {}
		),
		"rule_floor_effect_id": _action_ref_card_effect_id(
			rule_floor.get("action_ref", {}) if rule_floor.get("action_ref", {}) is Dictionary else {}
		),
		"attacker_slot_id": str(active.get("slot_id", "")),
		"attacker_uid": _slot_uid(active),
		"rule_target_slot_id": str(target_proof.get("slot_id", "")),
		"rule_target_uid": str(target_proof.get("uid", "")),
		"rule_target_energy_count": target_energy_count,
		"rule_target_immediate_attack_cost": target_attack_cost,
		"rule_sort_input_hash": str(target_proof.get("sort_input_hash", "")),
		"opponent_active_uid": _slot_uid(opponent_active),
		"opponent_pivot_energy_deficit": pivot_energy_deficit,
	}


func _attackless_gust_attack_epoch_for_candidate(
	candidate: Dictionary,
	context: Dictionary
) -> Dictionary:
	if context.is_empty():
		return {}
	var config: Dictionary = context.get("config", {}) \
		if context.get("config", {}) is Dictionary else {}
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	if str(candidate.get("action_kind", "")) != str(config.get("candidate_action_kind", "")) \
			or str(candidate.get("route_id", "")) != str(config.get("candidate_route_id", "")) \
			or str(candidate.get("checkpoint_after", "")) \
				!= str(config.get("candidate_checkpoint_after", "")) \
			or _action_ref_card_uid(action_ref) != _upper(str(config.get("candidate_card_uid", ""))) \
			or _action_ref_card_effect_id(action_ref) \
				!= str(config.get("candidate_card_effect_id", "")):
		return {}
	var result := {
		"schema_version": 1,
		"verified": true,
		"certificate_kind": ATTACK_EPOCH_CERTIFICATE_KIND,
		"evidence_kind": ATTACK_EPOCH_EVIDENCE_KIND,
		"proof_kind": ATTACK_EPOCH_PROOF_KIND,
		"stage": "reset_for_energy_before_gust",
		"candidate_id": str(candidate.get("candidate_id", "")),
		"candidate_action_id": str(candidate.get("safe_prefix_action_id", "")),
		"candidate_action_kind": str(candidate.get("action_kind", "")),
		"candidate_card_uid": _action_ref_card_uid(action_ref),
		"candidate_card_effect_id": _action_ref_card_effect_id(action_ref),
		"rule_floor_candidate_id": str(context.get("rule_floor_candidate_id", "")),
		"rule_floor_action_id": str(context.get("rule_floor_action_id", "")),
		"rule_floor_uid": str(context.get("rule_floor_uid", "")),
		"rule_floor_effect_id": str(context.get("rule_floor_effect_id", "")),
		"rule_floor_target_unbound": true,
		"attacker_slot_id": str(context.get("attacker_slot_id", "")),
		"attacker_uid": str(context.get("attacker_uid", "")),
		"opponent_active_uid": str(context.get("opponent_active_uid", "")),
		"opponent_pivot_energy_deficit": int(context.get("opponent_pivot_energy_deficit", 0)),
		"rule_target_slot_id": str(context.get("rule_target_slot_id", "")),
		"rule_target_uid": str(context.get("rule_target_uid", "")),
		"rule_target_energy_count": int(context.get("rule_target_energy_count", 0)),
		"rule_target_immediate_attack_cost": int(context.get("rule_target_immediate_attack_cost", 0)),
		"rule_sort_input_hash": str(context.get("rule_sort_input_hash", "")),
		"attack_ready_before_information": false,
		"energy_quota_available": true,
		"information_checkpoint_crossed": true,
		"attack_suffix_requires_public_replan": true,
		"interaction_owner": "rules_fallback",
		"terminal_status": "replan_after_public_information",
	}
	result["binding_hash"] = _attackless_gust_attack_epoch_binding_hash(result)
	return result


func _verify_attackless_gust_attack_epoch_annotation(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var annotation := _attackless_gust_attack_epoch_annotation(selected)
	if annotation.is_empty() or not bool(local_top.get("engine_rule_floor_exact", false)):
		return {"verified": false}
	var config := _attackless_gust_attack_epoch_config(profile)
	if config.is_empty() or not _rule_floor_is_profiled_unbound_gust(local_top, config):
		return {"verified": false}
	var action_ref: Dictionary = selected.get("action_ref", {}) \
		if selected.get("action_ref", {}) is Dictionary else {}
	if int(annotation.get("schema_version", 0)) != 1 \
			or not bool(annotation.get("verified", false)) \
			or str(annotation.get("certificate_kind", "")) != ATTACK_EPOCH_CERTIFICATE_KIND \
			or str(annotation.get("evidence_kind", "")) != ATTACK_EPOCH_EVIDENCE_KIND \
			or str(annotation.get("proof_kind", "")) != ATTACK_EPOCH_PROOF_KIND \
			or str(annotation.get("stage", "")) != "reset_for_energy_before_gust" \
			or str(annotation.get("candidate_id", "")) != str(selected.get("candidate_id", "")) \
			or str(annotation.get("candidate_action_id", "")) \
				!= str(selected.get("safe_prefix_action_id", "")) \
			or str(annotation.get("candidate_action_kind", "")) \
				!= str(config.get("candidate_action_kind", "")) \
			or str(annotation.get("candidate_card_uid", "")) \
				!= _upper(str(config.get("candidate_card_uid", ""))) \
			or str(annotation.get("candidate_card_effect_id", "")) \
				!= str(config.get("candidate_card_effect_id", "")) \
			or _action_ref_card_uid(action_ref) != str(annotation.get("candidate_card_uid", "")) \
			or _action_ref_card_effect_id(action_ref) \
				!= str(annotation.get("candidate_card_effect_id", "")) \
			or str(annotation.get("rule_floor_candidate_id", "")) \
				!= str(local_top.get("candidate_id", "")) \
			or str(annotation.get("rule_floor_action_id", "")) \
				!= str(local_top.get("safe_prefix_action_id", "")) \
			or not bool(annotation.get("rule_floor_target_unbound", false)) \
			or int(annotation.get("opponent_pivot_energy_deficit", 0)) <= 0 \
			or int(annotation.get("rule_target_energy_count", 0)) \
				< int(annotation.get("rule_target_immediate_attack_cost", 1)) \
			or not bool(annotation.get("energy_quota_available", false)) \
			or not bool(annotation.get("information_checkpoint_crossed", false)) \
			or not bool(annotation.get("attack_suffix_requires_public_replan", false)) \
			or str(annotation.get("binding_hash", "")) == "" \
			or str(annotation.get("binding_hash", "")) \
				!= _attackless_gust_attack_epoch_binding_hash(annotation):
		return {"verified": false}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var fact_turn: Dictionary = facts.get("turn", {}) if facts.get("turn", {}) is Dictionary else {}
	if bool(attack_facts.get("ready", false)) \
			or bool(attack_facts.get("ko_available", false)) \
			or int(attack_facts.get("max_damage", 0)) > 0 \
			or not bool(fact_turn.get("supporter_available", false)) \
			or not bool(fact_turn.get("energy_available", false)):
		return {"verified": false}
	return {
		"verified": true,
		"reason": "public_iono_reopens_energy_attack_epoch_before_harmful_unbound_gust",
		"certificate_kind": ATTACK_EPOCH_CERTIFICATE_KIND,
		"evidence_kind": ATTACK_EPOCH_EVIDENCE_KIND,
		"proof_kind": ATTACK_EPOCH_PROOF_KIND,
		"stage": str(annotation.get("stage", "")),
		"interaction_owner": str(annotation.get("interaction_owner", "rules_fallback")),
		"terminal_status": str(annotation.get("terminal_status", "")),
		"rule_floor_candidate_id": str(annotation.get("rule_floor_candidate_id", "")),
		"rule_target_uid": str(annotation.get("rule_target_uid", "")),
		"rule_target_slot_id": str(annotation.get("rule_target_slot_id", "")),
		"prizes_floor": 0,
		"win_now": false,
	}


func _attackless_gust_attack_epoch_binding_hash(annotation: Dictionary) -> String:
	var bound := annotation.duplicate(true)
	bound.erase("binding_hash")
	return JSON.stringify(bound).sha256_text()


func _attackless_gust_hold_context(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var config := _attackless_gust_hold_config(profile)
	if config.is_empty() or not bool(config.get("enabled", false)):
		return {}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	if bool(attack_facts.get("ready", false)) \
			or bool(attack_facts.get("ko_available", false)) \
			or int(attack_facts.get("max_damage", 0)) > 0:
		return {}
	var fact_turn: Dictionary = facts.get("turn", {}) if facts.get("turn", {}) is Dictionary else {}
	if not bool(fact_turn.get("supporter_available", false)):
		return {}
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	if not bool(turn.get("deterministic_attack_window_open", false)):
		return {}
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	if int(own.get("prizes_remaining", -1)) != int(config.get("required_own_prizes", -2)) \
			or int(opponent.get("prizes_remaining", -1)) != int(config.get("required_opponent_prizes", -2)) \
			or int(opponent.get("hand_count", -1)) != int(config.get("required_opponent_hand_count", -2)):
		return {}
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	if _slot_uid(active) != _upper(str(config.get("attacker_uid", ""))) \
			or int(active.get("energy_count", -1)) != int(config.get("attacker_energy_count", -2)) \
			or int(active.get("remaining_hp", -1)) != int(config.get("attacker_remaining_hp", -2)):
		return {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	if _slot_uid(opponent_active) != _upper(str(config.get("opponent_active_uid", ""))) \
			or int(opponent_active.get("energy_count", -1)) \
				!= int(config.get("opponent_active_energy_count", -2)):
		return {}
	var rule_floor := _exact_rule_floor(frontier)
	if not _rule_floor_is_profiled_unbound_gust(rule_floor, config):
		return {}
	var target_proof := _recompute_public_rule_gust_target(opponent, config)
	if not bool(target_proof.get("verified", false)):
		return {}
	var active_retreat_cost := int(config.get("opponent_active_retreat_cost", 0))
	var active_energy_count := int(opponent_active.get("energy_count", 0))
	var pivot_energy_deficit := maxi(0, active_retreat_cost - active_energy_count)
	if pivot_energy_deficit <= 0:
		return {}
	var target_energy_count := int(target_proof.get("energy_count", 0))
	var target_attack_cost := int(config.get("expected_rule_target_immediate_attack_cost", 0))
	if target_attack_cost <= 0 or target_energy_count < target_attack_cost:
		return {}
	return {
		"config": config,
		"rule_floor_candidate_id": str(rule_floor.get("candidate_id", "")),
		"rule_floor_action_id": str(rule_floor.get("safe_prefix_action_id", "")),
		"rule_floor_uid": _action_ref_card_uid(
			rule_floor.get("action_ref", {}) if rule_floor.get("action_ref", {}) is Dictionary else {}
		),
		"rule_floor_effect_id": _action_ref_card_effect_id(
			rule_floor.get("action_ref", {}) if rule_floor.get("action_ref", {}) is Dictionary else {}
		),
		"attacker_slot_id": str(active.get("slot_id", "")),
		"attacker_uid": _slot_uid(active),
		"opponent_active_slot_id": str(opponent_active.get("slot_id", "")),
		"opponent_active_uid": _slot_uid(opponent_active),
		"opponent_active_energy_count": active_energy_count,
		"opponent_active_retreat_cost": active_retreat_cost,
		"opponent_pivot_energy_deficit": pivot_energy_deficit,
		"rule_target_slot_id": str(target_proof.get("slot_id", "")),
		"rule_target_uid": str(target_proof.get("uid", "")),
		"rule_target_energy_count": target_energy_count,
		"rule_target_score": float(target_proof.get("score", 0.0)),
		"rule_target_index": int(target_proof.get("index", -1)),
		"rule_target_immediate_attack_cost": target_attack_cost,
		"rule_target_immediate_attack_ready": true,
		"rule_sort_input_hash": str(target_proof.get("sort_input_hash", "")),
		"own": own,
		"turn": turn,
	}


func _attackless_gust_hold_for_candidate(
	candidate: Dictionary,
	observation: Dictionary,
	context: Dictionary
) -> Dictionary:
	if context.is_empty():
		return {}
	var config: Dictionary = context.get("config", {}) \
		if context.get("config", {}) is Dictionary else {}
	var own: Dictionary = context.get("own", {}) if context.get("own", {}) is Dictionary else {}
	var turn: Dictionary = context.get("turn", {}) if context.get("turn", {}) is Dictionary else {}
	var stage := _matching_attackless_gust_stage(candidate, observation, own, turn, config)
	if stage.is_empty():
		return {}
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var target_slot := _own_slot(str(action_ref.get("target", "")), observation)
	var stage_id := str(stage.get("id", ""))
	var result := {
		"schema_version": 1,
		"verified": true,
		"certificate_kind": GUST_HOLD_CERTIFICATE_KIND,
		"evidence_kind": GUST_HOLD_EVIDENCE_KIND,
		"proof_kind": GUST_HOLD_PROOF_KIND,
		"stage": stage_id,
		"candidate_id": str(candidate.get("candidate_id", "")),
		"candidate_action_id": str(candidate.get("safe_prefix_action_id", "")),
		"candidate_action_kind": str(candidate.get("action_kind", "")),
		"candidate_card_uid": _action_ref_card_uid(action_ref),
		"candidate_card_effect_id": _action_ref_card_effect_id(action_ref),
		"candidate_target_slot_id": str(action_ref.get("target", "")),
		"candidate_target_uid": _slot_uid(target_slot),
		"rule_floor_candidate_id": str(context.get("rule_floor_candidate_id", "")),
		"rule_floor_action_id": str(context.get("rule_floor_action_id", "")),
		"rule_floor_uid": str(context.get("rule_floor_uid", "")),
		"rule_floor_effect_id": str(context.get("rule_floor_effect_id", "")),
		"rule_floor_target_unbound": true,
		"rule_floor_available_before_selection": true,
		"rule_floor_preserved_after_prefix": true,
		"attacker_slot_id": str(context.get("attacker_slot_id", "")),
		"attacker_uid": str(context.get("attacker_uid", "")),
		"opponent_active_slot_id": str(context.get("opponent_active_slot_id", "")),
		"opponent_active_uid": str(context.get("opponent_active_uid", "")),
		"opponent_active_energy_count": int(context.get("opponent_active_energy_count", 0)),
		"opponent_active_retreat_cost": int(context.get("opponent_active_retreat_cost", 0)),
		"opponent_pivot_energy_deficit": int(context.get("opponent_pivot_energy_deficit", 0)),
		"rule_target_slot_id": str(context.get("rule_target_slot_id", "")),
		"rule_target_uid": str(context.get("rule_target_uid", "")),
		"rule_target_energy_count": int(context.get("rule_target_energy_count", 0)),
		"rule_target_score": float(context.get("rule_target_score", 0.0)),
		"rule_target_index": int(context.get("rule_target_index", -1)),
		"rule_target_immediate_attack_cost": int(context.get("rule_target_immediate_attack_cost", 0)),
		"rule_target_immediate_attack_ready": bool(context.get("rule_target_immediate_attack_ready", false)),
		"rule_sort_input_hash": str(context.get("rule_sort_input_hash", "")),
		"attack_ready": false,
		"ko_available": false,
		"supporter_quota_preserved": true,
		"energy_quota_preserved": true,
		"information_checkpoint_crossed": str(candidate.get("checkpoint_after", "")) == "information_result",
		"interaction_owner": str(stage.get("interaction_owner", "not_required")),
		"terminal_status": str(stage.get("terminal_status", "")),
		"opponent_pivot_tax_preserved": stage_id == "hold_unbound_gust_after_development",
	}
	result["binding_hash"] = _attackless_gust_hold_binding_hash(result)
	return result


func _verify_attackless_gust_hold_annotation(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var annotation := _attackless_gust_hold_annotation(selected)
	if annotation.is_empty() or not bool(local_top.get("engine_rule_floor_exact", false)):
		return {"verified": false}
	var config := _attackless_gust_hold_config(profile)
	if config.is_empty() or not _rule_floor_is_profiled_unbound_gust(local_top, config):
		return {"verified": false}
	var stage := _gust_stage_config(config, str(annotation.get("stage", "")))
	if stage.is_empty() \
			or int(annotation.get("schema_version", 0)) != 1 \
			or not bool(annotation.get("verified", false)) \
			or str(annotation.get("certificate_kind", "")) != GUST_HOLD_CERTIFICATE_KIND \
			or str(annotation.get("evidence_kind", "")) != GUST_HOLD_EVIDENCE_KIND \
			or str(annotation.get("proof_kind", "")) != GUST_HOLD_PROOF_KIND \
			or str(annotation.get("candidate_id", "")) != str(selected.get("candidate_id", "")) \
			or str(annotation.get("candidate_action_id", "")) != str(selected.get("safe_prefix_action_id", "")) \
			or str(annotation.get("candidate_action_kind", "")) != str(selected.get("action_kind", "")) \
			or str(annotation.get("rule_floor_candidate_id", "")) != str(local_top.get("candidate_id", "")) \
			or str(annotation.get("rule_floor_action_id", "")) != str(local_top.get("safe_prefix_action_id", "")) \
			or not bool(annotation.get("rule_floor_target_unbound", false)) \
			or not bool(annotation.get("rule_floor_available_before_selection", false)) \
			or not bool(annotation.get("rule_floor_preserved_after_prefix", false)) \
			or int(annotation.get("opponent_pivot_energy_deficit", 0)) <= 0 \
			or not bool(annotation.get("rule_target_immediate_attack_ready", false)) \
			or int(annotation.get("rule_target_energy_count", 0)) \
				< int(annotation.get("rule_target_immediate_attack_cost", 1)) \
			or str(annotation.get("rule_sort_input_hash", "")) == "" \
			or str(annotation.get("binding_hash", "")) == "" \
			or str(annotation.get("binding_hash", "")) != _attackless_gust_hold_binding_hash(annotation):
		return {"verified": false}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var fact_turn: Dictionary = facts.get("turn", {}) if facts.get("turn", {}) is Dictionary else {}
	if bool(attack_facts.get("ready", false)) \
			or bool(attack_facts.get("ko_available", false)) \
			or int(attack_facts.get("max_damage", 0)) > 0 \
			or not bool(fact_turn.get("supporter_available", false)):
		return {"verified": false}
	var is_terminal_stage := str(annotation.get("stage", "")) == "hold_unbound_gust_after_development"
	if is_terminal_stage != bool(annotation.get("opponent_pivot_tax_preserved", false)):
		return {"verified": false}
	return {
		"verified": true,
		"reason": "public_development_then_hold_gust_preserves_opponent_pivot_tax",
		"certificate_kind": GUST_HOLD_CERTIFICATE_KIND,
		"evidence_kind": GUST_HOLD_EVIDENCE_KIND,
		"proof_kind": GUST_HOLD_PROOF_KIND,
		"stage": str(annotation.get("stage", "")),
		"interaction_owner": str(annotation.get("interaction_owner", "not_required")),
		"terminal_status": str(annotation.get("terminal_status", "")),
		"rule_floor_candidate_id": str(annotation.get("rule_floor_candidate_id", "")),
		"rule_target_uid": str(annotation.get("rule_target_uid", "")),
		"rule_target_slot_id": str(annotation.get("rule_target_slot_id", "")),
		"prizes_floor": 0,
		"win_now": false,
	}


func _matching_attackless_gust_stage(
	candidate: Dictionary,
	observation: Dictionary,
	own: Dictionary,
	turn: Dictionary,
	config: Dictionary
) -> Dictionary:
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	for raw_stage: Variant in config.get("stages", []):
		if not (raw_stage is Dictionary):
			continue
		var stage: Dictionary = raw_stage
		if str(candidate.get("action_kind", "")) != str(stage.get("action_kind", "")) \
				or str(candidate.get("checkpoint_after", "")) != str(stage.get("checkpoint_after", "")):
			continue
		var expected_card_uid := _upper(str(stage.get("card_uid", "")))
		if expected_card_uid != "" and (
			_action_ref_card_uid(action_ref) != expected_card_uid \
			or _action_ref_card_effect_id(action_ref) != str(stage.get("card_effect_id", ""))
		):
			continue
		var expected_target_uid := _upper(str(stage.get("target_uid", "")))
		if expected_target_uid != "":
			var target := _own_slot(str(action_ref.get("target", "")), observation)
			if _slot_uid(target) != expected_target_uid:
				continue
		if not _public_hand_uids_match(own, stage.get("expected_hand_uids", [])) \
				or not _public_bench_uids_match(own, stage.get("expected_own_bench_uids", [])) \
				or int(own.get("deck_count", -1)) != int(stage.get("expected_own_deck_count", -2)):
			continue
		var quotas: Dictionary = turn.get("quotas", {}) if turn.get("quotas", {}) is Dictionary else {}
		if bool(quotas.get("stadium_available", false)) \
				!= bool(stage.get("expected_stadium_available", false)):
			continue
		return stage
	return {}


func _recompute_public_rule_gust_target(opponent: Dictionary, config: Dictionary) -> Dictionary:
	var bench: Array = opponent.get("bench", []) if opponent.get("bench", []) is Array else []
	var expected: Array = config.get("opponent_bench_rule_order", []) \
		if config.get("opponent_bench_rule_order", []) is Array else []
	if bench.size() != expected.size() or bench.is_empty():
		return {"verified": false}
	var ranked: Array[Dictionary] = []
	var sort_input: Array = []
	for index: int in bench.size():
		if not (bench[index] is Dictionary) or not (expected[index] is Dictionary):
			return {"verified": false}
		var slot: Dictionary = bench[index]
		var expected_slot: Dictionary = expected[index]
		var energy_count := int(slot.get("energy_count", -1))
		if _slot_uid(slot) != _upper(str(expected_slot.get("uid", ""))) \
				or energy_count != int(expected_slot.get("energy_count", -2)) \
				or int(slot.get("prize_count", -1)) != int(expected_slot.get("prize_count", -2)):
			return {"verified": false}
		# DeckStrategy17InitialRulesBase._slot_general_score gives these exact
		# Basic multi-prize identities +55 and each attached Energy +20.  Feeding
		# the same order and comparator to the same Godot runtime reproduces its
		# deterministic (even when tied) sort without reading the later interaction.
		var score := float(expected_slot.get("rule_identity_bonus", 0.0)) + float(energy_count) * 20.0
		ranked.append({"index": index, "score": score})
		sort_input.append([index, _slot_uid(slot), energy_count, score])
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	if ranked.is_empty():
		return {"verified": false}
	var selected_index := int(ranked[0].get("index", -1))
	if selected_index < 0 or selected_index >= bench.size():
		return {"verified": false}
	var selected: Dictionary = bench[selected_index]
	if _slot_uid(selected) != _upper(str(config.get("expected_rule_target_uid", ""))) \
			or int(selected.get("energy_count", 0)) \
				!= int(config.get("expected_rule_target_energy_count", -1)):
		return {"verified": false}
	return {
		"verified": true,
		"index": selected_index,
		"slot_id": str(selected.get("slot_id", "")),
		"uid": _slot_uid(selected),
		"energy_count": int(selected.get("energy_count", 0)),
		"score": float(ranked[0].get("score", 0.0)),
		"sort_input_hash": JSON.stringify(sort_input).sha256_text(),
	}


func _rule_floor_is_profiled_unbound_gust(candidate: Dictionary, config: Dictionary) -> bool:
	if candidate.is_empty() or not bool(candidate.get("engine_rule_floor_exact", false)):
		return false
	var rule: Dictionary = config.get("rule_floor", {}) \
		if config.get("rule_floor", {}) is Dictionary else {}
	if str(candidate.get("action_kind", "")) != str(rule.get("action_kind", "")) \
			or str(candidate.get("route_id", "")) != str(rule.get("route_id", "")):
		return false
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	if _action_ref_card_uid(action_ref) != _upper(str(rule.get("card_uid", ""))) \
			or _action_ref_card_effect_id(action_ref) != str(rule.get("card_effect_id", "")):
		return false
	if bool(rule.get("require_unbound_target", true)):
		if str(action_ref.get("target", "")).strip_edges() != "":
			return false
		var raw_targets: Variant = action_ref.get("targets", [])
		if not (raw_targets is Array) or not (raw_targets as Array).is_empty():
			return false
	return true


func _public_hand_uids_match(own: Dictionary, expected_variant: Variant) -> bool:
	if not (expected_variant is Array):
		return false
	var actual: Array[String] = []
	for raw_card: Variant in own.get("hand", []):
		if not (raw_card is Dictionary):
			return false
		actual.append(_upper(str((raw_card as Dictionary).get("uid", ""))))
	var expected: Array[String] = []
	for raw_uid: Variant in expected_variant:
		expected.append(_upper(str(raw_uid)))
	actual.sort()
	expected.sort()
	return actual == expected


func _public_bench_uids_match(own: Dictionary, expected_variant: Variant) -> bool:
	if not (expected_variant is Array):
		return false
	var bench: Array = own.get("bench", []) if own.get("bench", []) is Array else []
	var expected: Array = expected_variant
	if bench.size() != expected.size():
		return false
	for index: int in bench.size():
		if not (bench[index] is Dictionary) \
				or _slot_uid(bench[index] as Dictionary) != _upper(str(expected[index])):
			return false
	return true


func _gust_stage_config(config: Dictionary, stage_id: String) -> Dictionary:
	for raw_stage: Variant in config.get("stages", []):
		if raw_stage is Dictionary and str((raw_stage as Dictionary).get("id", "")) == stage_id:
			return raw_stage as Dictionary
	return {}


func _attackless_gust_hold_binding_hash(annotation: Dictionary) -> String:
	var bound := annotation.duplicate(true)
	bound.erase("binding_hash")
	return JSON.stringify(bound).sha256_text()


func _verify_strict_suffix_annotation(
	selected: Dictionary,
	local_top: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if not _is_profiled_copy_attack_candidate(selected, profile) \
			or not bool(local_top.get("engine_rule_floor_exact", false)):
		return {"verified": false}
	var config := _strict_suffix_config(profile)
	var rule_floor: Dictionary = config.get("rule_floor", {}) \
		if config.get("rule_floor", {}) is Dictionary else {}
	var top_ref: Dictionary = local_top.get("action_ref", {}) \
		if local_top.get("action_ref", {}) is Dictionary else {}
	var top_source: Dictionary = top_ref.get("source_card", {}) \
		if top_ref.get("source_card", {}) is Dictionary else {}
	if str(local_top.get("action_kind", "")) != str(rule_floor.get("action_kind", "")) \
			or _upper(str(top_source.get("uid", ""))) != _upper(str(rule_floor.get("source_uid", ""))) \
			or int(top_ref.get("ability_index", -1)) != int(rule_floor.get("ability_index", -2)):
		return {"verified": false}
	var top_outcome: Dictionary = local_top.get("outcome", {}) \
		if local_top.get("outcome", {}) is Dictionary else {}
	if bool(top_outcome.get("win_now", false)) or int(top_outcome.get("prizes_now", 0)) > 0:
		return {"verified": false}
	var suffix := _strict_suffix_annotation(selected)
	if not bool(suffix.get("verified", false)) \
			or int(suffix.get("schema_version", 0)) != 1 \
			or str(suffix.get("certificate_kind", "")) != CERTIFICATE_KIND \
			or str(suffix.get("evidence_kind", "")) != EVIDENCE_KIND \
			or str(suffix.get("proof_kind", "")) != PROOF_KIND \
			or not bool(suffix.get("interaction_suffix_bound", false)) \
			or int(suffix.get("prizes_floor", 0)) != int(config.get("required_prizes", 3)) \
			or not bool(suffix.get("win_now", false)) \
			or str(suffix.get("binding_hash", "")) == "" \
			or str(suffix.get("binding_hash", "")) != _suffix_binding_hash(suffix):
		return {"verified": false}
	var selected_ref: Dictionary = selected.get("action_ref", {}) \
		if selected.get("action_ref", {}) is Dictionary else {}
	var selected_source: Dictionary = selected_ref.get("source_card", {}) \
		if selected_ref.get("source_card", {}) is Dictionary else {}
	if str(suffix.get("attacker_slot_id", "")) != str(selected_ref.get("source", "")) \
			or _upper(str(suffix.get("attacker_uid", ""))) != _upper(str(selected_source.get("uid", ""))) \
			or int(suffix.get("attack_index", -1)) != int(selected_ref.get("attack_index", -2)):
		return {"verified": false}
	return {
		"verified": true,
		"reason": "engine_registered_copy_suffix_wins_three_public_prizes_now",
		"certificate_kind": CERTIFICATE_KIND,
		"evidence_kind": EVIDENCE_KIND,
		"proof_kind": PROOF_KIND,
		"terminal_status": "win_now",
		"interaction_owner": "copy_attack_toolbox_complete_suffix",
		"prizes_floor": int(suffix.get("prizes_floor", 0)),
		"win_now": true,
		"attacker_slot_id": str(suffix.get("attacker_slot_id", "")),
		"copy_source_slot_id": str(suffix.get("copy_source_slot_id", "")),
		"bench_target_slot_id": str(suffix.get("bench_target_slot_id", "")),
		"active_damage": int(suffix.get("active_damage", 0)),
		"bench_damage": int(suffix.get("bench_damage", 0)),
	}


func _strict_suffix_for_candidate(
	candidate: Dictionary,
	observation: Dictionary,
	_facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var result := {
		"schema_version": 1,
		"profiled_candidate": _is_profiled_copy_attack_candidate(candidate, profile),
		"verified": false,
		"certificate_kind": CERTIFICATE_KIND,
		"evidence_kind": EVIDENCE_KIND,
		"proof_kind": PROOF_KIND,
	}
	if not bool(result.get("profiled_candidate", false)):
		return result
	var board := _strict_board_snapshot(observation, profile)
	for key: String in board.keys():
		result[key] = board.get(key)
	if not bool(board.get("verified", false)):
		return result
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	result["attacker_slot_id"] = str(action_ref.get("source", ""))
	result["attack_index"] = int(action_ref.get("attack_index", -1))
	result["interaction_suffix_bound"] = str(result.get("copy_source_slot_id", "")) != "" \
		and str(result.get("bench_target_slot_id", "")) != ""
	result["verified"] = bool(result.get("interaction_suffix_bound", false))
	if bool(result.get("verified", false)):
		result["binding_hash"] = _suffix_binding_hash(result)
	return result


func _suffix_binding_hash(suffix: Dictionary) -> String:
	# The certificate is produced before the model call and candidate annotations
	# are not model-owned.  Bind every dynamic suffix identity/value so a stale or
	# partially mutated annotation cannot be promoted by the verifier.
	return JSON.stringify([
		int(suffix.get("schema_version", 0)),
		str(suffix.get("certificate_kind", "")),
		str(suffix.get("evidence_kind", "")),
		str(suffix.get("proof_kind", "")),
		str(suffix.get("attacker_slot_id", "")),
		str(suffix.get("attacker_uid", "")),
		str(suffix.get("attacker_effect_id", "")),
		int(suffix.get("attack_index", -1)),
		str(suffix.get("copy_source_slot_id", "")),
		str(suffix.get("copy_source_uid", "")),
		str(suffix.get("copy_source_effect_id", "")),
		str(suffix.get("opponent_active_slot_id", "")),
		str(suffix.get("opponent_active_uid", "")),
		int(suffix.get("active_remaining_hp", 0)),
		int(suffix.get("active_damage", 0)),
		str(suffix.get("bench_target_slot_id", "")),
		str(suffix.get("bench_target_uid", "")),
		str(suffix.get("bench_target_effect_id", "")),
		int(suffix.get("bench_remaining_hp", 0)),
		int(suffix.get("bench_damage", 0)),
		int(suffix.get("prizes_floor", 0)),
		bool(suffix.get("win_now", false)),
		bool(suffix.get("interaction_suffix_bound", false)),
	]).sha256_text()


func _strict_board_snapshot(observation: Dictionary, profile: Dictionary) -> Dictionary:
	var config := _strict_suffix_config(profile)
	var result := {
		"verified": false,
		"certificate_kind": CERTIFICATE_KIND,
		"evidence_kind": EVIDENCE_KIND,
		"proof_kind": PROOF_KIND,
	}
	if config.is_empty() or not bool(config.get("enabled", false)):
		return result
	var turn: Dictionary = observation.get("turn", {}) if observation.get("turn", {}) is Dictionary else {}
	if not bool(turn.get("deterministic_attack_window_open", false)):
		return result
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	if int(own.get("prizes_remaining", 0)) != int(config.get("required_prizes", 3)):
		return result
	var active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	if not _slot_identity_matches(active, config, "attacker"):
		return result
	var required_cost := _string_array(config.get("attacker_cost", []))
	if not _attached_symbols_pay_cost(_slot_energy_symbols(active), required_cost):
		return result
	var source_matches: Array[Dictionary] = []
	for raw_slot: Variant in own.get("bench", []):
		if raw_slot is Dictionary and _slot_identity_matches(raw_slot as Dictionary, config, "copy_source"):
			source_matches.append(raw_slot as Dictionary)
	if source_matches.size() != 1:
		return result
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	if not _slot_identity_matches(opponent_active, config, "opponent_active") \
			or int(opponent_active.get("remaining_hp", 0)) <= 0 \
			or int(opponent_active.get("remaining_hp", 0)) > int(config.get("active_damage", 0)) \
			or int(opponent_active.get("prize_count", 0)) != int(config.get("active_prizes", 1)) \
			or _slot_has_unbound_public_protection(opponent_active, config):
		return result
	var opponent_bench: Array = opponent.get("bench", []) if opponent.get("bench", []) is Array else []
	if bool(config.get("require_only_one_opponent_bench", true)) and opponent_bench.size() != 1:
		return result
	var target_matches: Array[Dictionary] = []
	for raw_slot: Variant in opponent_bench:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		if _slot_identity_matches(slot, config, "bench_target") \
				and int(slot.get("remaining_hp", 0)) > 0 \
				and int(slot.get("remaining_hp", 0)) <= int(config.get("bench_damage", 0)) \
				and int(slot.get("prize_count", 0)) == int(config.get("bench_prizes", 2)) \
				and not _slot_has_unbound_public_protection(slot, config):
			target_matches.append(slot)
	if target_matches.size() != 1:
		return result
	var prizes_floor := int(opponent_active.get("prize_count", 0)) \
		+ int(target_matches[0].get("prize_count", 0))
	if prizes_floor != int(config.get("required_prizes", 3)):
		return result
	return {
		"verified": true,
		"certificate_kind": CERTIFICATE_KIND,
		"evidence_kind": EVIDENCE_KIND,
		"proof_kind": PROOF_KIND,
		"attacker_uid": _slot_uid(active),
		"attacker_effect_id": _slot_effect_id(active),
		"copy_source_uid": _slot_uid(source_matches[0]),
		"copy_source_effect_id": _slot_effect_id(source_matches[0]),
		"copy_source_slot_id": str(source_matches[0].get("slot_id", "")),
		"opponent_active_uid": _slot_uid(opponent_active),
		"opponent_active_slot_id": str(opponent_active.get("slot_id", "")),
		"bench_target_uid": _slot_uid(target_matches[0]),
		"bench_target_effect_id": _slot_effect_id(target_matches[0]),
		"bench_target_slot_id": str(target_matches[0].get("slot_id", "")),
		"active_remaining_hp": int(opponent_active.get("remaining_hp", 0)),
		"bench_remaining_hp": int(target_matches[0].get("remaining_hp", 0)),
		"active_damage": int(config.get("active_damage", 0)),
		"bench_damage": int(config.get("bench_damage", 0)),
		"prizes_floor": prizes_floor,
		"win_now": prizes_floor >= int(own.get("prizes_remaining", 0)),
	}


func _is_profiled_copy_attack_candidate(candidate: Dictionary, profile: Dictionary) -> bool:
	var config := _strict_suffix_config(profile)
	if config.is_empty() or not bool(config.get("enabled", false)):
		return false
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	return str(candidate.get("action_kind", "")) in ["attack", "granted_attack"] \
		and _upper(str(source_card.get("uid", ""))) == _upper(str(config.get("attacker_uid", ""))) \
		and str(source_card.get("effect_id", "")) == str(config.get("attacker_effect_id", "")) \
		and int(action_ref.get("attack_index", -1)) == int(config.get("attacker_attack_index", -2)) \
		and bool(action_ref.get("requires_interaction", false))


func _strict_suffix_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
	return module_annotation.get("strict_copy_suffix", {}) \
		if module_annotation.get("strict_copy_suffix", {}) is Dictionary else {}


func _typed_attachment_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
	return module_annotation.get("typed_attachment", {}) \
		if module_annotation.get("typed_attachment", {}) is Dictionary else {}


func _strict_suffix_config(profile: Dictionary) -> Dictionary:
	var modules: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = modules.get(MODULE_ID, {}) \
		if modules.get(MODULE_ID, {}) is Dictionary else {}
	return parameters.get("strict_double_ko_suffix", {}) \
		if parameters.get("strict_double_ko_suffix", {}) is Dictionary else {}


func _source_development_config(profile: Dictionary) -> Dictionary:
	var local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = local_parameters.get(MODULE_ID, {}) \
		if local_parameters.get(MODULE_ID, {}) is Dictionary else {}
	return parameters.get("source_development_suffix", {}) \
		if parameters.get("source_development_suffix", {}) is Dictionary else {}


func _attackless_gust_hold_config(profile: Dictionary) -> Dictionary:
	var local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = local_parameters.get(MODULE_ID, {}) \
		if local_parameters.get(MODULE_ID, {}) is Dictionary else {}
	return parameters.get("attackless_unbound_gust_hold_suffix", {}) \
		if parameters.get("attackless_unbound_gust_hold_suffix", {}) is Dictionary else {}


func _attackless_gust_attack_epoch_config(profile: Dictionary) -> Dictionary:
	var local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = local_parameters.get(MODULE_ID, {}) \
		if local_parameters.get(MODULE_ID, {}) is Dictionary else {}
	return parameters.get("attackless_gust_to_attack_epoch_suffix", {}) \
		if parameters.get("attackless_gust_to_attack_epoch_suffix", {}) is Dictionary else {}


func _copy_source_recovery_attack_epoch_config(profile: Dictionary) -> Dictionary:
	var local_parameters: Dictionary = profile.get("local_action_certificate_parameters", {}) \
		if profile.get("local_action_certificate_parameters", {}) is Dictionary else {}
	var parameters: Dictionary = local_parameters.get(MODULE_ID, {}) \
		if local_parameters.get(MODULE_ID, {}) is Dictionary else {}
	return parameters.get("copy_source_recovery_attack_epoch_suffix", {}) \
		if parameters.get("copy_source_recovery_attack_epoch_suffix", {}) is Dictionary else {}


func _is_profiled_source_development_candidate(candidate: Dictionary, profile: Dictionary) -> bool:
	var config := _source_development_config(profile)
	if config.is_empty() or not bool(config.get("enabled", false)):
		return false
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	return str(candidate.get("action_kind", "")) == "play_basic_to_bench" \
		and _upper(str(card.get("uid", ""))) == _upper(str(config.get("candidate_uid", ""))) \
		and str(card.get("effect_id", "")) == str(config.get("candidate_effect_id", "")) \
		and str(candidate.get("checkpoint_after", "")) == "action_resolved"


func _source_development_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
	return module_annotation.get("source_development", {}) \
		if module_annotation.get("source_development", {}) is Dictionary else {}


func _attackless_gust_hold_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
	return module_annotation.get("attackless_unbound_gust_hold", {}) \
		if module_annotation.get("attackless_unbound_gust_hold", {}) is Dictionary else {}


func _attackless_gust_attack_epoch_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
	return module_annotation.get("attackless_gust_to_attack_epoch", {}) \
		if module_annotation.get("attackless_gust_to_attack_epoch", {}) is Dictionary else {}


func _copy_source_recovery_attack_epoch_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
	return module_annotation.get("copy_source_recovery_attack_epoch", {}) \
		if module_annotation.get("copy_source_recovery_attack_epoch", {}) is Dictionary else {}


func _exact_rule_floor(frontier: Array[Dictionary]) -> Dictionary:
	var matches: Array[Dictionary] = []
	for candidate: Dictionary in frontier:
		if bool(candidate.get("engine_rule_floor_exact", false)):
			matches.append(candidate)
	return matches[0] if matches.size() == 1 else {}


func _rule_floor_is_profiled_low_value_copy_attack(
	candidate: Dictionary,
	config: Dictionary
) -> bool:
	if candidate.is_empty() \
			or not bool(candidate.get("engine_rule_floor_exact", false)) \
			or str(candidate.get("action_kind", "")) != "attack" \
			or str(candidate.get("route_id", "")) != str(config.get("rule_floor_route_id", "")) \
			or str(candidate.get("checkpoint_after", "")) != "terminal":
		return false
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var source_card: Dictionary = action_ref.get("source_card", {}) \
		if action_ref.get("source_card", {}) is Dictionary else {}
	return _upper(str(source_card.get("uid", ""))) \
			== _upper(str(config.get("attacker_uid", ""))) \
		and int(action_ref.get("attack_index", -1)) \
			== int(config.get("rule_floor_attack_index", -2)) \
		and bool(action_ref.get("requires_interaction", false)) \
		and not bool(action_ref.get("projected_knockout", false))


func _rule_floor_is_profiled_idle_munkidori(candidate: Dictionary, config: Dictionary) -> bool:
	if candidate.is_empty() \
			or not bool(candidate.get("engine_rule_floor_exact", false)) \
			or str(candidate.get("action_kind", "")) != "play_basic_to_bench" \
			or str(candidate.get("checkpoint_after", "")) != "action_resolved":
		return false
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	return _upper(str(card.get("uid", ""))) == _upper(str(config.get("rule_floor_uid", ""))) \
		and str(card.get("effect_id", "")) == str(config.get("rule_floor_effect_id", ""))


func _preserved_attack_candidate(
	frontier: Array[Dictionary],
	active: Dictionary,
	config: Dictionary
) -> Dictionary:
	var matches: Array[Dictionary] = []
	for candidate: Dictionary in frontier:
		if str(candidate.get("action_kind", "")) not in ["attack", "granted_attack"]:
			continue
		var action_ref: Dictionary = candidate.get("action_ref", {}) \
			if candidate.get("action_ref", {}) is Dictionary else {}
		var source_card: Dictionary = action_ref.get("source_card", {}) \
			if action_ref.get("source_card", {}) is Dictionary else {}
		if str(action_ref.get("source", "")) != str(active.get("slot_id", "")) \
				or _upper(str(source_card.get("uid", ""))) != _upper(str(config.get("attacker_uid", ""))) \
				or str(source_card.get("effect_id", "")) != str(config.get("attacker_effect_id", "")) \
				or int(action_ref.get("attack_index", -1)) != int(config.get("attacker_attack_index", -2)):
			continue
		matches.append(candidate)
	return matches[0] if matches.size() == 1 else {}


func _public_hand_identity_count(side: Dictionary, config: Dictionary, prefix: String) -> int:
	var count := 0
	for raw_card: Variant in side.get("hand", []):
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		if _upper(str(card.get("uid", ""))) == _upper(str(config.get("%s_uid" % prefix, ""))) \
				and str(card.get("effect_id", "")) == str(config.get("%s_effect_id" % prefix, "")):
			count += 1
	return count


func _public_hand_uid_count(side: Dictionary, uid: String) -> int:
	var count := 0
	for raw_card: Variant in side.get("hand", []):
		if raw_card is Dictionary \
				and _upper(str((raw_card as Dictionary).get("uid", ""))) == _upper(uid):
			count += 1
	return count


func _public_bench_uids(side: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var bench: Array = side.get("bench", []) if side.get("bench", []) is Array else []
	for raw_slot: Variant in bench:
		if raw_slot is Dictionary:
			result.append(_slot_uid(raw_slot as Dictionary))
	return result


func _field_uid_count(side: Dictionary, uid: String) -> int:
	var count := 0
	for slot: Dictionary in _visible_slots(side):
		if _slot_uid(slot) == _upper(uid):
			count += 1
	return count


func _field_identity_count(side: Dictionary, config: Dictionary, prefix: String) -> int:
	var count := 0
	for slot: Dictionary in _visible_slots(side):
		if _slot_identity_matches(slot, config, prefix):
			count += 1
	return count


func _discard_identity_count(side: Dictionary, uid: String) -> int:
	var counts: Dictionary = side.get("discard_counts", {}) \
		if side.get("discard_counts", {}) is Dictionary else {}
	for raw_uid: Variant in counts.keys():
		if _upper(str(raw_uid)) == _upper(uid):
			return int(counts.get(raw_uid, 0))
	for raw_card: Variant in side.get("discard", []):
		if raw_card is Dictionary and _upper(str((raw_card as Dictionary).get("uid", ""))) == _upper(uid):
			return 1
	return 0


func _own_has_damage(side: Dictionary) -> bool:
	for slot: Dictionary in _visible_slots(side):
		if int(slot.get("damage", 0)) > 0:
			return true
		var max_hp := int(slot.get("max_hp", 0))
		var remaining_hp := int(slot.get("remaining_hp", max_hp))
		if max_hp > 0 and remaining_hp > 0 and remaining_hp < max_hp:
			return true
	return false


func _action_ref_card_uid(action_ref: Dictionary) -> String:
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	return _upper(str(card.get("uid", "")))


func _action_ref_card_effect_id(action_ref: Dictionary) -> String:
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	return str(card.get("effect_id", ""))


func _slot_identity_matches(slot: Dictionary, config: Dictionary, prefix: String) -> bool:
	return not slot.is_empty() \
		and _slot_uid(slot) == _upper(str(config.get("%s_uid" % prefix, ""))) \
		and _slot_effect_id(slot) == str(config.get("%s_effect_id" % prefix, ""))


func _slot_has_unbound_public_protection(slot: Dictionary, config: Dictionary) -> bool:
	if slot.is_empty() or bool(slot.get("tera", false)) \
			or bool(slot.get("attack_damage_blocked", false)) \
			or bool(slot.get("bench_damage_blocked", false)) \
			or bool(slot.get("damage_prevention_active", false)):
		return true
	if bool(config.get("require_no_target_tool", true)):
		var tool: Variant = slot.get("tool", {})
		if tool is Dictionary and not (tool as Dictionary).is_empty():
			return true
	if bool(config.get("require_no_target_energy", true)):
		var energy: Variant = slot.get("energy", [])
		if energy is Array and not (energy as Array).is_empty():
			return true
	return false


func _slot_has_public_damage_protection(slot: Dictionary, config: Dictionary) -> bool:
	if slot.is_empty() or bool(slot.get("tera", false)) \
			or bool(slot.get("attack_damage_blocked", false)) \
			or bool(slot.get("damage_prevention_active", false)):
		return true
	if bool(config.get("require_no_target_tool", true)):
		var tool: Variant = slot.get("tool", {})
		if tool is Dictionary and not (tool as Dictionary).is_empty():
			return true
	return false


func _recoverable_copy_source_item_matches(item: Variant, config: Dictionary) -> bool:
	var data: CardData = null
	if item is CardInstance:
		data = (item as CardInstance).card_data
	elif item is Dictionary:
		var card_variant: Variant = (item as Dictionary).get("card", item)
		if card_variant is CardInstance:
			data = (card_variant as CardInstance).card_data
		elif card_variant is Dictionary:
			var card: Dictionary = card_variant
			return _upper(str(card.get("uid", ""))) \
					== _upper(str(config.get("copy_source_uid", ""))) \
				and str(card.get("effect_id", "")) \
					== str(config.get("copy_source_effect_id", ""))
	if data == null:
		return false
	return _upper(data.get_uid()) == _upper(str(config.get("copy_source_uid", ""))) \
		and str(data.effect_id) == str(config.get("copy_source_effect_id", ""))


func _copy_option_matches(item: Variant, board: Dictionary, config: Dictionary) -> bool:
	if not (item is Dictionary):
		return false
	var option: Dictionary = item
	if str(option.get("source_effect_id", "")) != str(config.get("copy_source_effect_id", "")) \
			or int(option.get("attack_index", -1)) != int(config.get("copy_attack_index", -2)):
		return false
	var source_card: Variant = option.get("source_card", null)
	if source_card is CardInstance:
		var source_data: CardData = (source_card as CardInstance).card_data
		if source_data == null \
				or _upper(source_data.get_uid()) != _upper(str(config.get("copy_source_uid", ""))) \
				or str(source_data.effect_id) != str(config.get("copy_source_effect_id", "")):
			return false
	else:
		return false
	var source_slot: Variant = option.get("source_slot", null)
	if not (source_slot is PokemonSlot) \
			or _pokemon_slot_id(source_slot as PokemonSlot) != str(board.get("copy_source_slot_id", "")):
		return false
	var attack: Dictionary = option.get("attack", {}) if option.get("attack", {}) is Dictionary else {}
	return int(str(attack.get("damage", "0"))) == int(config.get("active_damage", 0))


func _bench_target_matches(item: Variant, board: Dictionary, config: Dictionary) -> bool:
	if not (item is PokemonSlot):
		return false
	var slot := item as PokemonSlot
	var data := slot.get_card_data()
	if data == null \
			or _pokemon_slot_id(slot) != str(board.get("bench_target_slot_id", "")) \
			or _upper(data.get_uid()) != _upper(str(config.get("bench_target_uid", ""))) \
			or str(data.effect_id) != str(config.get("bench_target_effect_id", "")) \
			or slot.get_remaining_hp() <= 0 \
			or slot.get_remaining_hp() > int(config.get("bench_damage", 0)) \
			or slot.get_prize_count() != int(config.get("bench_prizes", 2)) \
			or data.is_tera_pokemon():
		return false
	if bool(config.get("require_no_target_tool", true)) and slot.attached_tool != null:
		return false
	if bool(config.get("require_no_target_energy", true)) and not slot.attached_energy.is_empty():
		return false
	for effect_data: Dictionary in slot.effects:
		var effect_type := str(effect_data.get("type", "")).to_lower()
		if effect_type.contains("prevent") or effect_type.contains("immune"):
			return false
	return true


func _typed_attachment_for_candidate(
	candidate: Dictionary,
	observation: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var action_ref: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	if str(candidate.get("action_kind", "")) != "attach_energy":
		return {}
	var target_slot_id := str(action_ref.get("target", ""))
	var target := _own_slot(target_slot_id, observation)
	if target.is_empty():
		return {}
	var parameters: Dictionary = _module_parameters(profile)
	var costs: Dictionary = parameters.get("attack_cost_by_uid", {}) \
		if parameters.get("attack_cost_by_uid", {}) is Dictionary else {}
	var target_uid := _slot_uid(target)
	var required := _string_array(costs.get(target_uid, []))
	var attached := _slot_energy_symbols(target)
	var card: Dictionary = action_ref.get("card", {}) if action_ref.get("card", {}) is Dictionary else {}
	var added_symbol := _energy_symbol(card)
	var missing_before := _missing_required_symbols(required, attached)
	var after := attached.duplicate()
	if added_symbol != "":
		after.append(added_symbol)
	var missing_after := _missing_required_symbols(required, after)
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var own_active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	return {
		"target_slot_id": target_slot_id,
		"target_uid": target_uid,
		"target_is_active": target_slot_id != "" and target_slot_id == str(own_active.get("slot_id", "")),
		"required_symbols": required,
		"attached_symbols_before": attached,
		"attached_symbols_after": after,
		"missing_before": missing_before,
		"missing_after": missing_after,
		"adds_missing_required_type": added_symbol in missing_before,
		"completes_required_types": not required.is_empty() and missing_before.size() == 1 and missing_after.is_empty(),
		"target_is_profiled_attacker": not required.is_empty(),
		"deterministic_attack_window_open": bool((observation.get("turn", {}) as Dictionary).get("deterministic_attack_window_open", false)) \
			if observation.get("turn", {}) is Dictionary else false,
	}


func _visible_role_count(observation: Dictionary, manifest: Dictionary, role: String) -> int:
	var count := 0
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	for slot: Dictionary in _visible_slots(own):
		var uid := _slot_uid(slot)
		if role in _roles_for_uid(uid, manifest):
			count += 1
	return count


func _roles_for_uid(uid: String, manifest: Dictionary) -> Array[String]:
	for raw_card: Variant in manifest.get("cards", []):
		if not (raw_card is Dictionary) or _upper(str((raw_card as Dictionary).get("uid", ""))) != uid:
			continue
		var result: Array[String] = []
		for raw_role: Variant in (raw_card as Dictionary).get("roles", []):
			var value := str(raw_role)
			if value != "":
				result.append(value)
		return result
	return []


func _visible_slots(side: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active: Variant = side.get("active", {})
	if active is Dictionary and not (active as Dictionary).is_empty():
		result.append(active as Dictionary)
	for raw_slot: Variant in side.get("bench", []):
		if raw_slot is Dictionary:
			result.append(raw_slot as Dictionary)
	return result


func _own_slot(slot_id: String, observation: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	for slot: Dictionary in _visible_slots(own):
		if str(slot.get("slot_id", "")) == slot_id:
			return slot
	return {}


func _slot_uid(slot: Dictionary) -> String:
	var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
	return _upper(str(pokemon.get("uid", "")))


func _slot_effect_id(slot: Dictionary) -> String:
	var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
	return str(pokemon.get("effect_id", ""))


func _slot_energy_symbols(slot: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary:
			var symbol := _energy_symbol(raw_energy as Dictionary)
			if symbol != "":
				result.append(symbol)
	return result


func _energy_symbol(card: Dictionary) -> String:
	var value := str(card.get("energy_provides", card.get("energy_type", ""))).strip_edges().to_upper()
	match value:
		"D", "DARKNESS": return "D"
		"C", "COLORLESS": return "C"
		"R", "FIRE": return "R"
		"L", "LIGHTNING": return "L"
		"G", "GRASS": return "G"
		"W", "WATER": return "W"
		"P", "PSYCHIC": return "P"
		"F", "FIGHTING": return "F"
		"M", "METAL": return "M"
		_: return value


func _attached_symbols_pay_cost(attached: Array[String], required: Array[String]) -> bool:
	return _missing_required_symbols(required, attached).is_empty()


func _missing_required_symbols(required: Array[String], attached: Array[String]) -> Array[String]:
	var pool := attached.duplicate()
	var missing: Array[String] = []
	for symbol: String in required:
		if symbol == "C":
			if pool.is_empty():
				missing.append(symbol)
			else:
				pool.remove_at(0)
			continue
		var index := pool.find(symbol)
		if index < 0:
			missing.append(symbol)
		else:
			pool.remove_at(index)
	return missing


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw_value: Variant in value as Array:
			var text := str(raw_value).strip_edges().to_upper()
			if text != "":
				result.append(text)
	return result


func _module_parameters(profile: Dictionary) -> Dictionary:
	var all_parameters: Dictionary = profile.get("module_parameters", {}) \
		if profile.get("module_parameters", {}) is Dictionary else {}
	return all_parameters.get(MODULE_ID, {}) \
		if all_parameters.get(MODULE_ID, {}) is Dictionary else {}


func _pokemon_slot_id(slot: PokemonSlot) -> String:
	if slot == null or slot.get_top_card() == null:
		return ""
	return "slot:%d" % int(slot.get_top_card().instance_id)


func _upper(value: String) -> String:
	return value.strip_edges().to_upper()
