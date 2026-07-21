class_name V18CPGResourceLedger
extends RefCounted

const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")

var _semantic_compiler = SemanticCompilerScript.new()


func build(
	observation: Dictionary,
	semantic_manifest: Dictionary,
	profile: Dictionary,
	belief: Dictionary = {},
	current_reservations: Array = []
) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var quotas: Dictionary = observation.get("turn", {}).get("quotas", {}) if observation.get("turn", {}) is Dictionary else {}
	var hand: Array = own.get("hand", []) if own.get("hand", []) is Array else []
	var discard: Array = own.get("discard", []) if own.get("discard", []) is Array else []
	var hand_counts := _card_counts(hand)
	var discard_counts := _card_counts(discard)
	var protected_roles: Array = profile.get("protected_roles", []) if profile.get("protected_roles", []) is Array else []
	var board_energy := _board_energy_counts(own)
	var own_belief: Dictionary = belief.get("own", {}) if belief.get("own", {}) is Dictionary else {}
	return {
		"schema_version": 2,
		"available_now": {
			"hand_cards": int(own.get("hand_count", 0)),
			"bench_slots": maxi(0, 5 - int((own.get("bench", []) as Array).size() if own.get("bench", []) is Array else 0)),
			"deck_cards": int(own.get("deck_count", 0)),
			"hand_by_uid": hand_counts,
			"board_energy_by_symbol": board_energy,
		},
		"reserved_current_route": current_reservations.duplicate(true),
		"reserved_next_turn": _typed_role_reservations(protected_roles),
		"recoverable": _recoverable_public_resources(discard_counts, semantic_manifest),
		"possibly_prized": (own_belief.get("possible_prized", {}) as Dictionary).duplicate(true) if own_belief.get("possible_prized", {}) is Dictionary else {},
		"safe_to_discard": _safe_to_discard(hand, hand_counts, protected_roles, semantic_manifest),
		"exclusive_quota": {
			"energy_attachment": bool(quotas.get("energy_available", false)),
			"supporter": bool(quotas.get("supporter_available", false)),
			"retreat": bool(quotas.get("retreat_available", false)),
			"stadium": bool(quotas.get("stadium_available", false)),
		},
		"semantic_role_counts": (semantic_manifest.get("role_counts", {}) as Dictionary).duplicate(true) if semantic_manifest.get("role_counts", {}) is Dictionary else {},
	}


func _card_counts(cards: Array) -> Dictionary:
	var counts: Dictionary = {}
	for raw_card: Variant in cards:
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		var uid := str(card.get("uid", ""))
		if uid != "":
			counts[uid] = int(counts.get(uid, 0)) + 1
	return counts


func _typed_role_reservations(roles: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_role: Variant in roles:
		var role := str(raw_role)
		if role != "":
			result.append({"resource": "role:%s" % role, "count": 1, "until": "next_turn_attack_window"})
	return result


func _recoverable_public_resources(discard_counts: Dictionary, semantic_manifest: Dictionary) -> Array[Dictionary]:
	var recovery_available := int((semantic_manifest.get("role_counts", {}) as Dictionary).get("recovery", 0)) > 0 if semantic_manifest.get("role_counts", {}) is Dictionary else false
	var result: Array[Dictionary] = []
	for raw_uid: Variant in discard_counts.keys():
		result.append({
			"uid": str(raw_uid),
			"count": int(discard_counts.get(raw_uid, 0)),
			"recovery_route_known": recovery_available,
		})
	return result


func _safe_to_discard(
	hand: Array,
	hand_counts: Dictionary,
	protected_roles: Array,
	semantic_manifest: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_card: Variant in hand:
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		var uid := str(card.get("uid", ""))
		if uid == "" or seen.has(uid):
			continue
		seen[uid] = true
		var roles := _semantic_compiler.roles_for_card_ref(card, semantic_manifest)
		var protected := false
		for raw_role: Variant in protected_roles:
			if str(raw_role) in roles:
				protected = true
				break
		var count := int(hand_counts.get(uid, 0))
		if not protected and count > 1:
			result.append({"uid": uid, "safe_count": count - 1, "reason": "visible_duplicate"})
	return result


func _board_energy_counts(own: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		for raw_energy: Variant in (raw_slot as Dictionary).get("energy", []):
			if not (raw_energy is Dictionary):
				continue
			var energy: Dictionary = raw_energy
			var symbol := str(energy.get("energy_provides", energy.get("energy_type", ""))).to_upper()
			if symbol != "":
				result[symbol] = int(result.get(symbol, 0)) + 1
	return result


func reservations_do_not_overlap(reservations: Array) -> bool:
	var seen: Dictionary = {}
	for raw: Variant in reservations:
		if not (raw is Dictionary):
			return false
		var reservation: Dictionary = raw
		var key := str(reservation.get("resource", ""))
		if key == "":
			return false
		seen[key] = int(seen.get(key, 0)) + int(reservation.get("count", 1))
		if int(seen[key]) > int(reservation.get("available", 1)):
			return false
	return true
