class_name AIHeuristics
extends RefCounted


func score_action(action: Dictionary, context: Dictionary) -> float:
	var features: Dictionary = context.get("features", {})
	action["reason_tags"] = []
	var score: float = _base_score(action, features)
	score += _apply_shared_adjustments(action, context, features)
	return score


func _base_score(action: Dictionary, features: Dictionary) -> float:
	match str(action.get("kind", "")):
		"attack":
			if bool(action.get("projected_knockout", false)):
				return 1000.0
			return 500.0
		"attach_energy":
			return 240.0 if bool(action.get("is_active_target", false)) else 200.0
		"play_basic_to_bench":
			return 180.0
		"evolve":
			return 170.0
		"use_ability":
			return 160.0
		"play_stadium":
			return 120.0
		"play_trainer":
			return 110.0 if _is_productive_trainer(action, features) else 20.0
		"retreat":
			return 90.0
		"end_turn":
			return 0.0
		_:
			return 10.0


func _apply_shared_adjustments(action: Dictionary, context: Dictionary, features: Dictionary) -> float:
	var score_delta := 0.0
	var kind := str(action.get("kind", ""))

	if _supports_bench_development(kind, features):
		score_delta += 70.0
		_add_reason_tag(action, "bench_development")

	if kind == "evolve" and _advances_stage2_line(action, context):
		score_delta += 140.0
		_add_reason_tag(action, "stage2_progress")

	if kind == "attach_energy" and bool(features.get("improves_attack_readiness", false)):
		score_delta += 80.0
		_add_reason_tag(action, "attack_readiness")

	if kind == "play_trainer" and not _is_productive_trainer(action, features):
		score_delta -= 30.0
		_add_reason_tag(action, "dead_trainer_penalty")

	return score_delta


func _supports_bench_development(kind: String, features: Dictionary) -> bool:
	if bool(features.get("improves_bench_development", false)):
		return true
	return kind == "play_trainer" and int(features.get("remaining_basic_targets", 0)) > 0


func _is_productive_trainer(action: Dictionary, features: Dictionary) -> bool:
	if features.has("productive"):
		return bool(features.get("productive", true))
	return bool(action.get("productive", true))


func _advances_stage2_line(action: Dictionary, context: Dictionary) -> bool:
	var evolution_card: CardInstance = action.get("card")
	if evolution_card == null or evolution_card.card_data == null:
		return false
	if str(evolution_card.card_data.stage) != "Stage 1":
		return false
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for hand_card: CardInstance in game_state.players[player_index].hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		if str(hand_card.card_data.stage) != "Stage 2":
			continue
		if str(hand_card.card_data.evolves_from) == str(evolution_card.card_data.name):
			return true
	return false


func _add_reason_tag(action: Dictionary, tag: String) -> void:
	var reason_tags: Array = action.get("reason_tags", [])
	if not reason_tags.has(tag):
		reason_tags.append(tag)
	action["reason_tags"] = reason_tags
