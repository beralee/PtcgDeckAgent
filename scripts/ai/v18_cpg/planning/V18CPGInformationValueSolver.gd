class_name V18CPGInformationValueSolver
extends RefCounted


func evaluate_action(
	action: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	semantic_manifest: Dictionary
) -> Dictionary:
	var kind := str(action.get("kind", ""))
	var terminal := kind in ["attack", "granted_attack", "end_turn"]
	var information_action := kind in ["use_ability", "play_trainer", "use_stadium_effect"] \
		and bool(action.get("requires_interaction", false))
	var resource_commitment := 0.0
	if kind in ["attach_energy", "retreat", "play_stadium"]:
		resource_commitment = 0.7
	elif kind == "play_trainer":
		resource_commitment = 0.8 if _is_supporter(action) else 0.35
	elif terminal:
		resource_commitment = 1.0
	var board_commitment := 0.0
	if kind in ["play_basic_to_bench", "evolve", "attach_tool"]:
		board_commitment = 0.55
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var deck_count := int(own.get("deck_count", 0))
	var information_gain := 0.0
	if information_action:
		information_gain = 0.8 if deck_count > 8 else 0.35
		if bool(facts.get("attack", {}).get("ko_available", false)):
			information_gain *= 0.25
	var reversible_setup := kind in ["use_ability", "play_basic_to_bench"] and resource_commitment < 0.6
	var expected_route_improvement := maxf(0.0, information_gain - resource_commitment * 0.45 - board_commitment * 0.2)
	return {
		"information_gain": information_gain,
		"reversible_setup": reversible_setup,
		"resource_commitment": resource_commitment,
		"board_commitment": board_commitment,
		"terminal": terminal,
		"expected_route_improvement": expected_route_improvement,
		"semantic_role_count": int(semantic_manifest.get("role_counts", {}).size()) if semantic_manifest.get("role_counts", {}) is Dictionary else 0,
	}


func _is_supporter(action: Dictionary) -> bool:
	var card: Variant = action.get("card", {})
	return card is Dictionary and str((card as Dictionary).get("type", "")).to_lower() == "supporter"
