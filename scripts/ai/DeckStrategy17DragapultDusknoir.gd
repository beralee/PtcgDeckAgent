class_name DeckStrategy17DragapultDusknoir
extends "res://scripts/ai/DeckStrategyDragapultDusknoir.gd"

const V17_CRISPIN := "Crispin"
const V17_CRISPIN_EFFECT_ID := "136fdb6578daa3b81aef369495de4c3d"
const V17_CRISPIN_HAND_STEP := "csv9c196_energy_to_hand"
const V17_CRISPIN_ATTACH_STEP := "csv9c196_energy_attachment"


func get_strategy_id() -> String:
	return "v17_dragapult_dusknoir"


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	var max_select := int(step.get("max_select", items.size()))
	if max_select <= 0 or items.is_empty():
		return []
	if step_id == "buddy_poffin_pokemon":
		return _v17_pick_opening_poffin_targets(items, max_select, context)
	if step_id == V17_CRISPIN_HAND_STEP:
		return _v17_pick_crispin_hand_energy(items, max_select, context)
	if step_id == V17_CRISPIN_ATTACH_STEP:
		return _v17_pick_ranked_items(items, max_select, step, context, -INF)
	var parent_pick: Array = super.pick_interaction_items(items, step, context)
	if not parent_pick.is_empty():
		return parent_pick
	if step_id in ["search_pokemon", "bench_pokemon", "basic_pokemon", "search_cards", "search_item", "search_tool", "stage2_card", "look_top_pick"]:
		return _v17_pick_ranked_items(items, max_select, step, context, -INF)
	return parent_pick


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance and step_id == "buddy_poffin_pokemon":
		var player := _v17_context_player(context)
		return _v17_score_poffin_target_with_counts(
			item as CardInstance,
			_v17_dreepy_line_count(player),
			_v17_dusk_line_count(player)
		)
	if item is CardInstance and step_id in [V17_CRISPIN_HAND_STEP, V17_CRISPIN_ATTACH_STEP]:
		return _v17_score_crispin_energy(item as CardInstance, step_id, context)
	if item is CardInstance and step_id == "look_top_pick":
		return _v17_score_look_top_pick(item as CardInstance, context)
	if item is PokemonSlot and step_id in [V17_CRISPIN_ATTACH_STEP, "attach_energy_target", "energy_target", "energy_assignments", "assignment_target"]:
		return _v17_score_crispin_or_energy_target(item as PokemonSlot, step_id, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not (item is PokemonSlot):
		return score_interaction_target(item, step, context)
	var slot := item as PokemonSlot
	var step_id := str(step.get("id", ""))
	if step_id in ["opponent_switch_target", "opponent_bench_target", "gust_target"]:
		return _v17_score_gust_target(slot, context)
	return _score_send_out(slot)


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return super._score_trainer(action, game_state, player_index)
	var player: PlayerState = game_state.players[player_index]
	var name := _v17_card_name(card)
	if name == V17_CRISPIN:
		return _v17_score_crispin_trainer(player, game_state)
	if name == "Buddy-Buddy Poffin":
		var missing_dreepy := _v17_dreepy_line_count(player) == 0 and _v17_deck_has(player, "Dreepy")
		var missing_duskull := _v17_dusk_line_count(player) == 0 and _v17_deck_has(player, "Duskull")
		if missing_dreepy and missing_duskull:
			return 700.0
		if missing_dreepy:
			return 640.0
		if missing_duskull and _v17_dreepy_line_count(player) > 0:
			return 580.0
	return super._score_trainer(action, game_state, player_index)


func _score_attach_energy(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return super._score_attach_energy(action, game_state, player_index)
	var player: PlayerState = game_state.players[player_index]
	var energy_type := _v17_energy_type(card)
	if _v17_slot_name(target_slot) in ["Dreepy", "Drakloak", "Dragapult ex"]:
		return _v17_dragapult_exact_energy_score(target_slot, player, energy_type)
	return super._score_attach_energy(action, game_state, player_index)


func _v17_pick_opening_poffin_targets(items: Array, max_select: int, context: Dictionary) -> Array:
	var player := _v17_context_player(context)
	var virtual_dreepy := _v17_dreepy_line_count(player)
	var virtual_duskull := _v17_dusk_line_count(player)
	var remaining := items.duplicate()
	var picked: Array = []
	while picked.size() < max_select and not remaining.is_empty():
		var best_index := -1
		var best_score := -INF
		for i: int in remaining.size():
			var item: Variant = remaining[i]
			if not (item is CardInstance):
				continue
			var score := _v17_score_poffin_target_with_counts(item as CardInstance, virtual_dreepy, virtual_duskull)
			if score > best_score:
				best_score = score
				best_index = i
		if best_index < 0 or best_score <= 0.0:
			break
		var chosen: Variant = remaining[best_index]
		picked.append(chosen)
		remaining.remove_at(best_index)
		if chosen is CardInstance:
			match _v17_card_name(chosen as CardInstance):
				"Dreepy":
					virtual_dreepy += 1
				"Duskull":
					virtual_duskull += 1
	return picked


func _v17_pick_crispin_hand_energy(items: Array, max_select: int, context: Dictionary) -> Array:
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		var item: Variant = items[i]
		if not (item is CardInstance):
			continue
		var score := _v17_score_crispin_energy(item as CardInstance, V17_CRISPIN_HAND_STEP, context)
		if score <= 0.0:
			continue
		scored.append({"index": i, "item": item, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", 0)) < int(b.get("index", 0))
		return score_a > score_b
	)
	var picked: Array = []
	for i: int in mini(max_select, scored.size()):
		picked.append(scored[i].get("item"))
	return picked


func _v17_score_poffin_target_with_counts(card: CardInstance, dreepy_lines: int, duskull_lines: int) -> float:
	match _v17_card_name(card):
		"Dreepy":
			if dreepy_lines <= 0:
				return 900.0
			if dreepy_lines < 2 and duskull_lines > 0:
				return 720.0
			return 300.0
		"Duskull":
			if duskull_lines <= 0 and dreepy_lines > 0:
				return 860.0
			if duskull_lines <= 0:
				return 620.0
			return 100.0
	return 0.0


func _v17_score_crispin_trainer(player: PlayerState, game_state: GameState) -> float:
	if player == null:
		return 0.0
	if _v17_under_deck_out_pressure(player, game_state):
		return 260.0 if _v17_needs_dragapult_energy(player) else -10.0
	var best_target := _v17_best_dragapult_energy_target(player)
	if best_target == null:
		return 120.0
	var gap := _attack_gap(best_target)
	var score := 520.0
	if gap >= 2:
		score = 760.0
	elif gap == 1:
		score = 680.0
	if _v17_has_energy_type_in_deck(player, "R") and _v17_has_energy_type_in_deck(player, "P"):
		score += 80.0
	if game_state != null and int(game_state.turn_number) <= 5:
		score += 80.0
	return score


func _v17_score_crispin_energy(card: CardInstance, step_id: String, context: Dictionary) -> float:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return 0.0
	var energy_type := _v17_energy_type(card)
	var player := _v17_context_player(context)
	var target := _v17_best_dragapult_energy_target(player)
	if target == null:
		return 80.0
	var target_score := _v17_dragapult_exact_energy_score(target, player, energy_type)
	if step_id == V17_CRISPIN_ATTACH_STEP:
		return target_score
	var opposite_type := "P" if energy_type == "R" else ("R" if energy_type == "P" else "")
	if opposite_type != "":
		var opposite_score := _v17_dragapult_exact_energy_score(target, player, opposite_type)
		if opposite_score > target_score + 120.0:
			return 420.0
	return 180.0 if energy_type in ["R", "P"] else 30.0


func _v17_score_crispin_or_energy_target(slot: PokemonSlot, step_id: String, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var source: Variant = context.get("source_card", null)
	if source is CardInstance:
		var energy_type := _v17_energy_type(source as CardInstance)
		if _v17_slot_name(slot) in ["Dreepy", "Drakloak", "Dragapult ex"]:
			return _v17_dragapult_exact_energy_score(slot, _v17_context_player(context), energy_type)
	if step_id == V17_CRISPIN_ATTACH_STEP and _v17_slot_name(slot) in ["Dreepy", "Drakloak", "Dragapult ex"]:
		return 520.0
	return super.score_interaction_target(slot, {"id": step_id}, context)


func _v17_score_look_top_pick(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var base := super.score_interaction_target(card, {"id": "search_cards"}, context)
	var player := _v17_context_player(context)
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var name := _v17_card_name(card)
	if player == null:
		return base
	match name:
		DRAGAPULT_EX:
			if _v17_dreepy_line_count(player) > 0 and _v17_count_name(player, DRAGAPULT_EX) == 0:
				return base + 260.0
		DRAKLOAK:
			if _v17_count_name(player, DREEPY) > 0 and _v17_count_name(player, DRAGAPULT_EX) == 0:
				return base + 180.0
		DUSKNOIR:
			if _v17_dusk_line_count(player) > 0 and _has_live_dusk_blast_conversion_target(game_state, player_index):
				return base + 180.0
		RARE_CANDY:
			if _v17_dreepy_line_count(player) > 0 and (_v17_deck_has(player, DRAGAPULT_EX) or _has_hand_card(player, DRAGAPULT_EX)):
				return base + 240.0
		SPARKLING_CRYSTAL:
			if _v17_best_dragapult_energy_target(player) != null:
				return base + 180.0
		EARTHEN_VESSEL, V17_CRISPIN:
			if _v17_best_dragapult_energy_target(player) != null:
				return base + 140.0
		COUNTER_CATCHER, BOSSS_ORDERS:
			if game_state != null and player_index >= 0 and _can_take_bench_prize(game_state, player_index):
				return base + 180.0
			if _v17_count_name(player, DRAGAPULT_EX) == 0:
				return 35.0
	if card.card_data.is_energy():
		var target := _v17_best_dragapult_energy_target(player)
		if target != null:
			return maxf(base, _v17_dragapult_exact_energy_score(target, player, _v17_energy_type(card)) + 60.0)
	return base


func _v17_dragapult_exact_energy_score(target_slot: PokemonSlot, player: PlayerState, energy_type: String) -> float:
	if target_slot == null or target_slot.get_top_card() == null:
		return 0.0
	var name := _v17_slot_name(target_slot)
	if name not in ["Dreepy", "Drakloak", "Dragapult ex"]:
		return super._score_attach_target(target_slot, {"game_state": null, "player_index": -1})
	var has_fire := _v17_slot_has_energy_type(target_slot, "R")
	var has_psychic := _v17_slot_has_energy_type(target_slot, "P")
	var has_crystal := _slot_has_tool(target_slot, "Sparkling Crystal")
	var duplicate := (energy_type == "R" and has_fire) or (energy_type == "P" and has_psychic)
	if duplicate:
		return 70.0 if _attack_gap(target_slot) > 0 else 15.0
	if energy_type == "R" and not has_fire:
		if has_psychic or has_crystal:
			return 640.0
		return 530.0
	if energy_type == "P" and not has_psychic:
		if has_fire or has_crystal:
			return 620.0
		return 540.0
	if energy_type in ["R", "P"]:
		return 160.0
	if player != null and target_slot == player.active_pokemon and _retreat_gap(target_slot) > 0:
		return 90.0
	return 20.0


func _v17_best_dragapult_energy_target(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _v17_all_slots(player):
		var name := _v17_slot_name(slot)
		if name not in ["Dragapult ex", "Drakloak", "Dreepy"]:
			continue
		var missing_fire := not _v17_slot_has_energy_type(slot, "R")
		var missing_psychic := not _v17_slot_has_energy_type(slot, "P")
		if not missing_fire and not missing_psychic:
			continue
		var missing_score := 0.0
		if missing_fire:
			missing_score += 120.0
		if missing_psychic:
			missing_score += 120.0
		if _attack_gap(slot) <= 1:
			missing_score += 180.0
		match name:
			"Dragapult ex":
				missing_score += 260.0
			"Drakloak":
				missing_score += 180.0
			"Dreepy":
				missing_score += 140.0
		if missing_score > best_score:
			best_score = missing_score
			best_slot = slot
	return best_slot


func _v17_score_gust_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var damage := 0
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if player.active_pokemon != null:
			damage = int(predict_attacker_damage(player.active_pokemon).get("damage", 0))
	var remaining := slot.get_remaining_hp()
	var prize_count := slot.get_prize_count()
	var score := float(prize_count) * 180.0 - float(_retreat_gap(slot)) * 15.0
	if damage > 0 and remaining <= damage:
		score += 900.0 + float(prize_count) * 220.0
	elif remaining <= 130 and game_state != null and player_index >= 0 and _has_live_dusk_blast_conversion_target(game_state, player_index):
		score += 520.0 + float(prize_count) * 120.0
	elif remaining <= 200:
		score += 180.0
	if _is_rule_box(slot):
		score += 160.0
	return score


func _v17_pick_ranked_items(items: Array, max_select: int, step: Dictionary, context: Dictionary, min_score: float) -> Array:
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		var score := score_interaction_target(items[i], step, context)
		if score <= min_score:
			continue
		scored.append({"index": i, "item": items[i], "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", 0)) < int(b.get("index", 0))
		return score_a > score_b
	)
	var picked: Array = []
	for i: int in mini(max_select, scored.size()):
		picked.append(scored[i].get("item"))
	return picked


func _v17_context_player(context: Dictionary) -> PlayerState:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _v17_dreepy_line_count(player: PlayerState) -> int:
	return _v17_count_name(player, "Dreepy") + _v17_count_name(player, "Drakloak") + _v17_count_name(player, "Dragapult ex")


func _v17_dusk_line_count(player: PlayerState) -> int:
	return _v17_count_name(player, "Duskull") + _v17_count_name(player, "Dusclops") + _v17_count_name(player, "Dusknoir")


func _v17_count_name(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _v17_all_slots(player):
		if _v17_slot_name(slot) == target_name:
			count += 1
	return count


func _v17_deck_has(player: PlayerState, target_name: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _v17_card_name(card) == target_name:
			return true
	return false


func _v17_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _v17_needs_dragapult_energy(player: PlayerState) -> bool:
	return _v17_best_dragapult_energy_target(player) != null


func _v17_has_energy_type_in_deck(player: PlayerState, energy_type: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _v17_energy_type(card) == energy_type:
			return true
	return false


func _v17_slot_has_energy_type(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null:
		return false
	for card: CardInstance in slot.attached_energy:
		if _v17_energy_type(card) == energy_type:
			return true
	return false


func _v17_under_deck_out_pressure(player: PlayerState, game_state: GameState) -> bool:
	if player == null:
		return false
	if player.deck.size() > 12:
		return false
	if game_state != null and int(game_state.turn_number) <= 6:
		return false
	return _best_ready_dragapult_slot(player) != null


func _v17_slot_name(slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	return _v17_card_name(slot.get_top_card())


func _v17_energy_type(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			var provides := str(instance.card_data.energy_provides)
			return provides if provides != "" else str(instance.card_data.energy_type)
	return ""


func _v17_card_name(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			if str(instance.card_data.effect_id) == V17_CRISPIN_EFFECT_ID:
				return V17_CRISPIN
			return str(instance.card_data.name_en) if str(instance.card_data.name_en) != "" else str(instance.card_data.name)
	return ""
