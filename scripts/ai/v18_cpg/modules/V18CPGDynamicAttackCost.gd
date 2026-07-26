class_name V18CPGDynamicAttackCost
extends RefCounted

## Public-state dynamic attack-cost certificates shared by every V18CPG deck.
##
## The engine remains the authority for whether an attack is currently legal.
## This module gives the planner the missing arithmetic needed before and after
## a pivot: Blood Moon's printed 5 Colorless cost is reduced by the number of
## Prize cards the opponent has taken.  The certificate is rebuilt from every
## filtered observation, so no stale turn-plan estimate can survive a Prize
## change.

const MODULE_ID := "dynamic_attack_cost"
const BLOODMOON_UID := "CSV8C_172"
const BLOODMOON_EFFECT_ID := "f2afef80b13b8f6a071facbcade0251c"
const STARTING_PRIZES := 6
const PRINTED_COLORLESS_COST := 5


func public_snapshot(observation: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_prizes_remaining := clampi(
		int(opponent.get("prizes_remaining", STARTING_PRIZES)),
		0,
		STARTING_PRIZES
	)
	var active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var active_slot_id := str(active.get("slot_id", ""))
	var cards: Array[Dictionary] = []
	var active_certificate: Dictionary = {}
	var slots: Array = []
	if not active.is_empty():
		slots.append(active)
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		if not _is_bloodmoon_slot(slot):
			continue
		var certificate := _certificate(
			slot,
			opponent_prizes_remaining,
			str(slot.get("slot_id", "")) == active_slot_id,
			observation
		)
		cards.append(certificate)
		if bool(certificate.get("is_active", false)):
			active_certificate = certificate
	return {
		"active": active_certificate,
		"cards": cards,
		"opponent_prizes_remaining": opponent_prizes_remaining,
		"opponent_prizes_taken": STARTING_PRIZES - opponent_prizes_remaining,
	}


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	_facts: Dictionary,
	_profile: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var snapshot := public_snapshot(observation)
	var active: Dictionary = snapshot.get("active", {}) \
		if snapshot.get("active", {}) is Dictionary else {}
	for candidate: Dictionary in frontier:
		var annotated := candidate.duplicate(true)
		var action: Dictionary = candidate.get("action_ref", {}) \
			if candidate.get("action_ref", {}) is Dictionary else {}
		var target_before: Dictionary = {}
		var target_after: Dictionary = {}
		var target_is_active := false
		var redundant_active_attachment := false
		var completes_dynamic_cost := false
		var attack_paid_after_pivot := false
		if str(action.get("kind", "")) in ["attach_energy", "retreat"]:
			var target_slot := _own_slot(str(action.get("target", "")), observation)
			if _is_bloodmoon_slot(target_slot):
				target_before = _certificate(
					target_slot,
					int(snapshot.get("opponent_prizes_remaining", STARTING_PRIZES)),
					str(target_slot.get("slot_id", "")) \
						== str(active.get("slot_id", "")),
					observation
				)
				target_after = target_before.duplicate(true)
				if str(action.get("kind", "")) == "attach_energy":
					var paid_after := int(target_before.get(
						"attached_energy_units_lower_bound",
						0
					)) + _attachment_energy_lower_bound(action)
					var required := int(target_before.get(
						"effective_energy_required",
						0
					))
					target_after["attached_energy_units_lower_bound"] = paid_after
					target_after["energy_deficit"] = maxi(0, required - paid_after)
					target_after["cost_ready"] = paid_after >= required \
						or bool(target_before.get("engine_confirms_cost_paid", false))
				else:
					# A legal retreat binds the exact destination. The attack itself
					# becomes engine-authoritative only after reobservation, but its
					# public energy payment can already be proved now.
					target_after["is_active"] = true
					target_after["engine_confirms_cost_paid"] = false
					target_after["legal_attack_action_id"] = ""
					target_after["executable_now"] = false
					attack_paid_after_pivot = bool(
						target_before.get("cost_ready", false)
					)
				target_is_active = bool(target_before.get("is_active", false))
				redundant_active_attachment = str(action.get("kind", "")) \
					== "attach_energy" \
					and target_is_active \
					and bool(target_before.get("cost_ready", false)) \
					and bool(target_before.get("engine_confirms_cost_paid", false))
				completes_dynamic_cost = str(action.get("kind", "")) \
					== "attach_energy" \
					and not bool(target_before.get("cost_ready", false)) \
					and bool(target_after.get("cost_ready", false))
		var is_bound_attack := str(action.get("kind", "")) in ["attack", "granted_attack"] \
			and not active.is_empty() \
			and _action_source_matches(action, active)
		var module_annotation := {
			"module": MODULE_ID,
			"active": active.duplicate(true),
			"target_before": target_before,
			"target_after": target_after,
			"target_is_active": target_is_active,
			"completes_dynamic_cost": completes_dynamic_cost,
			"attack_paid_after_pivot": attack_paid_after_pivot,
			"redundant_active_cost_attachment": redundant_active_attachment,
			"verified_advantage": is_bound_attack \
				and bool(active.get("executable_now", false)),
			"verified_advantage_kind": "dynamic_cost_ready_attack" \
				if is_bound_attack and bool(active.get("executable_now", false)) else "",
		}
		var annotations: Dictionary = annotated.get("module_annotations", {}) \
			if annotated.get("module_annotations", {}) is Dictionary else {}
		annotations[MODULE_ID] = module_annotation
		annotated["module_annotations"] = annotations
		result.append(annotated)
	return result


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	_facts: Dictionary,
	_profile: Dictionary
) -> Dictionary:
	var selected_annotation := _annotation(selected)
	var top_annotation := _annotation(local_top)
	if bool(selected_annotation.get("redundant_active_cost_attachment", false)) \
			and str(local_top.get("action_kind", "")) in ["attack", "granted_attack"] \
			and bool((top_annotation.get("active", {}) as Dictionary).get(
				"executable_now",
				false
			)):
		return {
			"valid": false,
			"reason": "dynamic_attack_cost_already_paid",
		}
	return {"valid": true}


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	_facts: Dictionary,
	_profile: Dictionary
) -> Dictionary:
	var selected_annotation := _annotation(selected)
	var top_annotation := _annotation(local_top)
	var active: Dictionary = selected_annotation.get("active", {}) \
		if selected_annotation.get("active", {}) is Dictionary else {}
	if str(selected.get("action_kind", "")) in ["attack", "granted_attack"] \
			and bool(active.get("executable_now", false)) \
			and bool(top_annotation.get("redundant_active_cost_attachment", false)):
		return {
			"verified": true,
			"reason": "public_dynamic_cost_ready_attack_over_redundant_attachment",
			"certificate_kind": \
				"public_dynamic_cost_ready_attack_over_redundant_attachment",
			"interaction_owner": "not_required",
			"source_uid": str(active.get("source_uid", "")),
			"effective_energy_required": int(
				active.get("effective_energy_required", 0)
			),
			"opponent_prizes_remaining": int(
				active.get("opponent_prizes_remaining", STARTING_PRIZES)
			),
		}
	return {"verified": false}


func _certificate(
	slot: Dictionary,
	opponent_prizes_remaining: int,
	is_active: bool,
	observation: Dictionary
) -> Dictionary:
	var prizes_remaining := clampi(
		opponent_prizes_remaining,
		0,
		STARTING_PRIZES
	)
	var prizes_taken := STARTING_PRIZES - prizes_remaining
	var discount := mini(PRINTED_COLORLESS_COST, prizes_taken)
	var required := maxi(0, PRINTED_COLORLESS_COST - discount)
	var attached_lower_bound := _attached_energy_lower_bound(slot)
	var legal_attack_id := _legal_attack_id(slot, observation) if is_active else ""
	var engine_confirms := legal_attack_id != ""
	var cost_ready := attached_lower_bound >= required or engine_confirms
	return {
		"rule": "opponent_prizes_taken_colorless_reduction",
		"source_uid": BLOODMOON_UID,
		"source_effect_id": BLOODMOON_EFFECT_ID,
		"slot_id": str(slot.get("slot_id", "")),
		"is_active": is_active,
		"printed_colorless_cost": PRINTED_COLORLESS_COST,
		"opponent_prizes_remaining": prizes_remaining,
		"opponent_prizes_taken": prizes_taken,
		"colorless_discount": discount,
		"effective_energy_required": required,
		"attached_energy_units_lower_bound": attached_lower_bound,
		"energy_deficit": 0 if engine_confirms else maxi(
			0,
			required - attached_lower_bound
		),
		"cost_ready": cost_ready,
		"engine_confirms_cost_paid": engine_confirms,
		"legal_attack_action_id": legal_attack_id,
		"executable_now": is_active and engine_confirms,
	}


func _legal_attack_id(slot: Dictionary, observation: Dictionary) -> String:
	for raw_action: Variant in observation.get("legal_actions", []):
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		if str(action.get("kind", "")) not in ["attack", "granted_attack"]:
			continue
		if _action_source_matches(action, {
			"slot_id": str(slot.get("slot_id", "")),
			"pokemon": slot.get("pokemon", {}),
		}):
			return str(action.get("id", ""))
	return ""


func _action_source_matches(action: Dictionary, certificate_or_slot: Dictionary) -> bool:
	var wanted_slot_id := str(certificate_or_slot.get("slot_id", ""))
	var wanted_uid := str(certificate_or_slot.get(
		"source_uid",
		(certificate_or_slot.get("pokemon", {}) as Dictionary).get("uid", "") \
			if certificate_or_slot.get("pokemon", {}) is Dictionary else ""
	)).strip_edges().to_upper()
	var source_slot_id := str(action.get("source", ""))
	var source_card: Dictionary = action.get("source_card", {}) \
		if action.get("source_card", {}) is Dictionary else {}
	var source_uid := str(source_card.get("uid", "")).strip_edges().to_upper()
	if source_slot_id != "" and wanted_slot_id != "":
		return source_slot_id == wanted_slot_id
	return source_uid != "" and source_uid == wanted_uid


func _is_bloodmoon_slot(slot: Dictionary) -> bool:
	if slot.is_empty():
		return false
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	return str(pokemon.get("uid", "")).strip_edges().to_upper() == BLOODMOON_UID \
		or str(pokemon.get("effect_id", "")).strip_edges().to_lower() \
			== BLOODMOON_EFFECT_ID


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


func _attached_energy_lower_bound(slot: Dictionary) -> int:
	var visible_energy_count := 0
	if slot.get("energy", []) is Array:
		visible_energy_count = (slot.get("energy", []) as Array).size()
	return maxi(visible_energy_count, int(slot.get("energy_count", 0)))


func _attachment_energy_lower_bound(action: Dictionary) -> int:
	# One attached Energy card always provides at least one unit unless the engine
	# has already rejected the action. Multi-unit Special Energy is deliberately
	# under-counted here; the next legal-action observation remains authoritative.
	return 1 if str(action.get("kind", "")) == "attach_energy" else 0


func _annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}
