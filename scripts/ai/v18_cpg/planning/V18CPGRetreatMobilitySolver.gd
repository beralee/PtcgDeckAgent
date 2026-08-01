class_name V18CPGRetreatMobilitySolver
extends RefCounted

## Shared, deck-independent interpretation of retreat mobility.
##
## Provider visibility explains *why* a Basic Pokemon can have free retreat, but
## never grants execution authority.  The only current-window proof is an exact
## legal retreat action whose engine-computed payment list is empty.

const LATIAS_EX_UIDS: Array[String] = ["CSV9C_078", "LEN_SSP_76"]
const LATIAS_EX_EFFECT_IDS: Array[String] = [
	"f8c2715403e3f4ea9783c46be2de832b",
	"0ae80b64c46fbf648bf3d0fd49be4c04",
]


func solve(observation: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var provider_refs := _visible_latias_providers(own)
	var zero_action_ids: Array[String] = []
	var target_slot_ids: Array[String] = []
	var retreat_action_ids: Array[String] = []
	var exact_payment_action_ids: Array[String] = []
	var legal_actions: Array = observation.get("legal_actions", []) \
		if observation.get("legal_actions", []) is Array else []
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		if str(action.get("kind", "")) != "retreat":
			continue
		var action_id := str(action.get("id", ""))
		if action_id != "":
			retreat_action_ids.append(action_id)
		var target_slot_id := str(action.get("target", ""))
		if target_slot_id != "" and not target_slot_ids.has(target_slot_id):
			target_slot_ids.append(target_slot_id)
		if not bool(action.get("engine_legal_retreat_proof", false)) \
				or not action.has("retreat_payment_energy_count"):
			continue
		if action_id != "":
			exact_payment_action_ids.append(action_id)
		if int(action.get("retreat_payment_energy_count", -1)) == 0 \
				and bool(action.get("zero_energy_retreat", false)) \
				and action_id != "":
			zero_action_ids.append(action_id)
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) \
		if turn.get("quotas", {}) is Dictionary else {}
	var provider_uids: Array[String] = []
	var provider_effect_ids: Array[String] = []
	var provider_slot_ids: Array[String] = []
	for provider: Dictionary in provider_refs:
		var uid := str(provider.get("uid", ""))
		var effect_id := str(provider.get("effect_id", ""))
		var slot_id := str(provider.get("slot_id", ""))
		if uid != "" and not provider_uids.has(uid):
			provider_uids.append(uid)
		if effect_id != "" and not provider_effect_ids.has(effect_id):
			provider_effect_ids.append(effect_id)
		if slot_id != "" and not provider_slot_ids.has(slot_id):
			provider_slot_ids.append(slot_id)
	return {
		"schema_version": 1,
		"active_slot_id": str(active.get("slot_id", "")),
		"active_stage": _slot_stage(active),
		"active_is_basic": _is_basic_slot(active),
		"printed_retreat_cost": int(
			active.get(
				"printed_retreat_cost",
				active.get("retreat_cost", 0)
			)
		),
		"provider_visible": not provider_refs.is_empty(),
		"provider_uids": provider_uids,
		"provider_effect_ids": provider_effect_ids,
		"provider_slot_ids": provider_slot_ids,
		"provider_scope": "own_basic_pokemon" if not provider_refs.is_empty() else "",
		"retreat_quota_available": bool(quotas.get("retreat_available", false)),
		"legal_retreat_action_ids": retreat_action_ids,
		"exact_payment_action_ids": exact_payment_action_ids,
		"zero_retreat_available_now": not zero_action_ids.is_empty(),
		"zero_retreat_action_ids": zero_action_ids,
		"target_slot_ids": target_slot_ids,
		"engine_legal_proof": not zero_action_ids.is_empty(),
		"preserves_attached_energy": not zero_action_ids.is_empty(),
	}


func _visible_latias_providers(own: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active: Variant = own.get("active", {})
	if active is Dictionary:
		_append_provider(result, active as Dictionary)
	var bench: Variant = own.get("bench", [])
	if bench is Array:
		for raw_slot: Variant in bench as Array:
			if raw_slot is Dictionary:
				_append_provider(result, raw_slot as Dictionary)
	return result


func _append_provider(result: Array[Dictionary], slot: Dictionary) -> void:
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	var uid := str(pokemon.get("uid", "")).strip_edges().to_upper()
	var effect_id := str(pokemon.get("effect_id", "")).strip_edges().to_lower()
	if uid not in LATIAS_EX_UIDS and effect_id not in LATIAS_EX_EFFECT_IDS:
		return
	result.append({
		"slot_id": str(slot.get("slot_id", "")),
		"uid": uid,
		"effect_id": effect_id,
	})


func _is_basic_slot(slot: Dictionary) -> bool:
	return _slot_stage(slot).strip_edges().to_lower() == "basic"


func _slot_stage(slot: Dictionary) -> String:
	var pokemon: Dictionary = slot.get("pokemon", {}) \
		if slot.get("pokemon", {}) is Dictionary else {}
	return str(slot.get("stage", pokemon.get("stage", "")))
