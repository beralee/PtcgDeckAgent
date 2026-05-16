class_name DeckStrategy17BombCharizard
extends "res://scripts/ai/DeckStrategyCharizardEx.gd"


func get_strategy_id() -> String:
	return "v17_bomb_charizard"


func get_signature_names() -> Array[String]:
	return ["Charizard ex", "Charmander", "Pidgeot ex", "Pidgey", "Dusknoir"]


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 4,
		"time_budget_ms": 260,
		"rollouts_per_sequence": 0,
	}


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	var predicted: Dictionary = super.predict_attacker_damage(slot, extra_context)
	if slot == null or slot.get_card_data() == null:
		return predicted
	if _slot_name(slot) == CHARIZARD_EX and bool(predicted.get("can_attack", false)):
		predicted["damage"] = maxi(int(predicted.get("damage", 0)), 180 + 30 * maxi(0, extra_context))
		predicted["description"] = "v17_charizard_prize_scaling"
	return predicted


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id == "self_ko_target":
		return _pick_v17_self_ko_targets(items, int(step.get("max_select", items.size())), context)
	if step_id == "buddy_buddy_poffin":
		var normalized_step := step.duplicate(true)
		normalized_step["id"] = "buddy_poffin_pokemon"
		if context.has("game_state"):
			return super.pick_interaction_items(items, normalized_step, context)
		return _pick_poffin_shell_without_context(items, int(step.get("max_select", 2)))
	if step_id == "buddy_poffin_pokemon" and not context.has("game_state"):
		return _pick_poffin_shell_without_context(items, int(step.get("max_select", 2)))
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot and str(step.get("id", "")) == "self_ko_target":
		return _score_dusknoir_target(item as PokemonSlot, context)
	return super.score_interaction_target(item, step, context)


func _score_use_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot") as PokemonSlot
	if source_slot == null:
		return super._score_use_ability(action, game_state, player_index)
	var source_name := _slot_name(source_slot)
	if source_name not in [DUSKNOIR, DUSCLOPS]:
		return super._score_use_ability(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = _opponent(game_state, player_index)
	var context := {
		"game_state": game_state,
		"player_index": player_index,
		"source_slot": source_slot,
	}
	var best_score := _best_v17_self_ko_target_score(opponent, context)
	var suppressed := _should_suppress_dusk_lane_actions(player, game_state, player_index)
	match source_name:
		DUSKNOIR:
			if best_score >= 650.0:
				return 540.0
			if best_score >= 350.0:
				return 380.0
			return -50.0 if suppressed else -30.0
		DUSCLOPS:
			if best_score >= 650.0:
				return 420.0
			if best_score >= 350.0:
				return 260.0
			return -60.0 if suppressed else -20.0
	return 0.0


func _pick_poffin_shell_without_context(items: Array, max_select: int) -> Array:
	var selected: Array = []
	for desired_name: String in [CHARMANDER, PIDGEY, ROTOM_V, DUSKULL]:
		if selected.size() >= max_select:
			break
		for item: Variant in items:
			if not (item is CardInstance):
				continue
			var card := item as CardInstance
			if selected.has(card):
				continue
			if _card_name(card) == desired_name:
				selected.append(card)
				break
	return selected


func _pick_v17_self_ko_targets(items: Array, max_select: int, context: Dictionary) -> Array:
	if max_select <= 0 or items.is_empty():
		return []
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		var item: Variant = items[i]
		if not (item is PokemonSlot):
			continue
		var score := _score_dusknoir_target(item as PokemonSlot, context)
		if score <= 0.0:
			continue
		scored.append({
			"index": i,
			"item": item,
			"score": score,
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", -1)) < int(b.get("index", -1))
		return score_a > score_b
	)
	var picked: Array = []
	for i: int in mini(max_select, scored.size()):
		picked.append(scored[i].get("item"))
	return picked


func _has_dusknoir_conversion_target(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = _opponent(game_state, player_index)
	var source_slot := _best_v17_self_ko_source(player)
	if source_slot == null or opponent == null:
		return false
	var context := {
		"game_state": game_state,
		"player_index": player_index,
		"source_slot": source_slot,
	}
	return _best_v17_self_ko_target_score(opponent, context) >= 350.0


func _score_dusknoir_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var remaining_hp := slot.get_remaining_hp()
	var blast_damage := _v17_self_ko_damage(context)
	var prize_count := slot.get_prize_count()
	var score := float(prize_count) * 100.0
	if remaining_hp <= blast_damage:
		if _v17_self_ko_would_hand_final_prize_without_win(prize_count, context):
			return -260.0
		if _is_v17_closing_self_ko_prize(prize_count, context):
			score += 760.0
			return score
		if prize_count >= 2:
			score += 770.0
			return score
		score += 180.0
		return score
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		var opponent: PlayerState = _opponent(game_state, player_index)
		var active := player.active_pokemon
		var source_slot := _v17_self_ko_source_from_context(context)
		if active != null and active != source_slot and opponent != null and slot == opponent.active_pokemon:
			var attack_info: Dictionary = predict_attacker_damage(active)
			if bool(attack_info.get("can_attack", false)):
				var follow_up_damage := int(attack_info.get("damage", 0))
				if remaining_hp <= blast_damage + follow_up_damage:
					if _v17_self_ko_would_hand_final_prize_without_win(prize_count, context):
						return -220.0
					score += 440.0
					if prize_count >= 2:
						score += 90.0
					return score
	score -= 180.0
	score -= float(remaining_hp) * 0.25
	return score


func _best_v17_self_ko_target_score(opponent: PlayerState, context: Dictionary) -> float:
	if opponent == null:
		return -99999.0
	var best_score := -99999.0
	for slot: PokemonSlot in _all_slots(opponent):
		best_score = maxf(best_score, _score_dusknoir_target(slot, context))
	return best_score


func _v17_self_ko_damage(context: Dictionary) -> int:
	var source_slot := _v17_self_ko_source_from_context(context)
	if source_slot != null:
		match _slot_name(source_slot):
			DUSCLOPS:
				return 50
			DUSKNOIR:
				return 130
	return 130


func _v17_self_ko_source_from_context(context: Dictionary) -> PokemonSlot:
	var source_variant: Variant = context.get("source_slot", null)
	if source_variant is PokemonSlot:
		return source_variant as PokemonSlot
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return _best_v17_self_ko_source(game_state.players[player_index])


func _best_v17_self_ko_source(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var fallback: PokemonSlot = null
	for slot: PokemonSlot in _all_slots(player):
		var name := _slot_name(slot)
		if name == DUSKNOIR:
			return slot
		if name == DUSCLOPS and fallback == null:
			fallback = slot
	return fallback


func _is_v17_closing_self_ko_prize(prize_count: int, context: Dictionary) -> bool:
	if prize_count <= 0:
		return false
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and player.prizes.size() > 0 and prize_count >= player.prizes.size()


func _v17_self_ko_would_hand_final_prize_without_win(prize_count: int, context: Dictionary) -> bool:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = _opponent(game_state, player_index)
	if player == null or opponent == null:
		return false
	if opponent.prizes.size() > 1:
		return false
	return prize_count < player.prizes.size()
