class_name V18CPGEventBridge
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")

var _resolution_sequence: int = 0


func reset() -> void:
	_resolution_sequence = 0


func observe_transition(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_resolution_sequence += 1
	var before_hash := str(before_snapshot.get("public_state_hash", ""))
	var after_hash := str(after_snapshot.get("public_state_hash", ""))
	var public_changed := before_hash != after_hash
	var before_own: Dictionary = before_snapshot.get("own", {}) \
		if before_snapshot.get("own", {}) is Dictionary else {}
	var after_own: Dictionary = after_snapshot.get("own", {}) \
		if after_snapshot.get("own", {}) is Dictionary else {}
	var acquired_cards := _card_ref_difference(
		after_own.get("hand", []) if after_own.get("hand", []) is Array else [],
		before_own.get("hand", []) if before_own.get("hand", []) is Array else []
	)
	var released_cards := _card_ref_difference(
		before_own.get("hand", []) if before_own.get("hand", []) is Array else [],
		after_own.get("hand", []) if after_own.get("hand", []) is Array else []
	)
	var before_deck_count := int(before_own.get("deck_count", -1))
	var after_deck_count := int(after_own.get("deck_count", -1))
	var deck_count_changed := before_deck_count >= 0 \
		and after_deck_count >= 0 \
		and before_deck_count != after_deck_count
	var interaction_complete := bool(context.get(
		"interaction_complete",
		str(context.get("pending_choice_after", "")) != "effect_interaction"
	))
	var visible_scope := str(context.get("visible_scope", ""))
	var explicit_information_checkpoint := bool(context.get("information_checkpoint", false)) \
		or visible_scope in [
			"own_full_deck",
			"opponent_hand_revealed",
		]
	var success := bool(context.get("success", false))
	var information_material := success \
		and interaction_complete \
		and (
			explicit_information_checkpoint
			or public_changed and (
				not acquired_cards.is_empty()
				or deck_count_changed
			)
		)
	var public_delta := {
		"public_state_changed": public_changed,
		"own_hand_count_before": int(before_own.get("hand_count", 0)),
		"own_hand_count_after": int(after_own.get("hand_count", 0)),
		"own_deck_count_before": before_deck_count,
		"own_deck_count_after": after_deck_count,
		"own_deck_count_changed": deck_count_changed,
		"turn_changed": before_snapshot.get("turn", {}) != after_snapshot.get("turn", {}),
		"stadium_changed": before_snapshot.get("stadium", {}) != after_snapshot.get("stadium", {}),
		"own_board_changed": _board_projection(before_own) != _board_projection(after_own),
		"opponent_public_changed": before_snapshot.get("opponent", {}) != after_snapshot.get("opponent", {}),
	}
	var event_type := "INTERACTION_STEP_RESOLVED" \
		if str(context.get("step_kind", "")) == "effect_interaction" \
		else "MAIN_ACTION_RESOLVED"
	var identity_payload := {
		"sequence": _resolution_sequence,
		"before_hash": before_hash,
		"after_hash": after_hash,
		"event_type": event_type,
		"step_id": str(context.get("step_id", "")),
	}
	return {
		"resolution_id": "resolution:%d:%s" % [
			_resolution_sequence,
			ContractsScript.stable_hash(identity_payload).substr(0, 12),
		],
		"sequence": _resolution_sequence,
		"event_type": event_type,
		"step_kind": str(context.get("step_kind", "")),
		"step_id": str(context.get("step_id", "")),
		"success": success,
		"interaction_complete": interaction_complete,
		"information_material": information_material,
		"before_hash": before_hash,
		"after_hash": after_hash,
		"visible_scope": visible_scope,
		"acquired_own_hand_cards": acquired_cards,
		"released_own_hand_cards": released_cards,
		"public_delta": public_delta,
	}


func _card_ref_difference(left: Array, right: Array) -> Array[Dictionary]:
	var remaining: Dictionary = {}
	for raw_ref: Variant in right:
		if not (raw_ref is Dictionary):
			continue
		var key := _card_ref_identity(raw_ref as Dictionary)
		remaining[key] = int(remaining.get(key, 0)) + 1
	var difference: Array[Dictionary] = []
	for raw_ref: Variant in left:
		if not (raw_ref is Dictionary):
			continue
		var ref := raw_ref as Dictionary
		var key := _card_ref_identity(ref)
		var count := int(remaining.get(key, 0))
		if count > 0:
			remaining[key] = count - 1
		else:
			difference.append(ref.duplicate(true))
	return difference


func _card_ref_identity(ref: Dictionary) -> String:
	var instance_id := int(ref.get("instance_id", -1))
	if instance_id >= 0:
		return "instance:%d" % instance_id
	return "card:%s:%s:%s" % [
		str(ref.get("uid", "")),
		str(ref.get("name", "")),
		str(ref.get("type", "")),
	]


func _board_projection(player: Dictionary) -> Dictionary:
	return {
		"active": player.get("active", {}),
		"bench": player.get("bench", []),
		"discard": player.get("discard", []),
		"lost_zone": player.get("lost_zone", []),
		"prizes_remaining": int(player.get("prizes_remaining", 0)),
	}
