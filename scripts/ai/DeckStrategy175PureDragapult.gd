class_name DeckStrategy175PureDragapult
extends "res://scripts/ai/DeckStrategy17DragapultDusknoir.gd"


const V175_STRATEGY_ID := "v175_pure_dragapult"
const BUDEW := "Budew"
const BUDEW_EFFECT_ID := "28505a8ad6e07e74382c1b5e09737932"
const DRAKLOAK_RECON_EFFECT_ID := "4e13cd08de3b6d141ce8e2f09d17a3a4"
const DRAKLOAK_RECON_USED_FLAG := "ability_look_top_to_hand_used"
const LANCE := "Lance"
const LANCE_EFFECT_ID := "2df65fcd5de0d9d9e24486b059981cdf"
const LANCE_DRAGON_STEP := "dragon_pokemon"


func get_strategy_id() -> String:
	return V175_STRATEGY_ID


func get_signature_names() -> Array[String]:
	return [BUDEW, DRAGAPULT_EX, DRAKLOAK, DREEPY, DUSKNOIR, DUSKULL]


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	var max_select := int(step.get("max_select", items.size()))
	if max_select <= 0 or items.is_empty():
		return []
	if step_id == "buddy_poffin_pokemon":
		return _v175_pick_opening_poffin_targets(items, max_select, context)
	if step_id == LANCE_DRAGON_STEP:
		return _v175_pick_lance_dragon_targets(items, max_select, context)
	if step_id == "search_energy":
		return _v175_pick_energy_search_targets(items, max_select, context)
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		var name := _card_name(card)
		if step_id == LANCE_DRAGON_STEP:
			return _v175_score_lance_target(card, _v17_context_player(context))
		if step_id == "search_energy":
			return _v175_score_energy_search_target(card, _v17_context_player(context))
		if name == BUDEW and step_id in ["search_pokemon", "bench_pokemon", "basic_pokemon", "buddy_poffin_pokemon", "search_cards"]:
			return _v175_score_budew_search(_v17_context_player(context), context, step_id)
	if item is PokemonSlot and step_id in ["send_out", "pivot_target", "self_switch_target", "switch_target"]:
		return _v175_score_self_handoff(item as PokemonSlot, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not (item is PokemonSlot):
		return score_interaction_target(item, step, context)
	var step_id := str(step.get("id", ""))
	if step_id in ["opponent_switch_target", "opponent_bench_target", "gust_target"]:
		return super.score_handoff_target(item, step, context)
	return _v175_score_self_handoff(item as PokemonSlot, context)


func _best_ready_dragapult_slot(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if _v175_dragapult_phantom_dive_ready(slot):
			return slot
	return null


func _has_immediate_attack_window(player: PlayerState) -> bool:
	if player == null:
		return false
	if _v175_dragapult_phantom_dive_ready(player.active_pokemon):
		return true
	if player.active_pokemon == null or _retreat_gap(player.active_pokemon) > 0:
		return false
	return _best_ready_dragapult_slot(player) != null


func _dragapult_phantom_dive_ready(slot: PokemonSlot) -> bool:
	return _v175_dragapult_phantom_dive_ready(slot)


func build_continuity_contract(game_state: GameState, player_index: int, turn_contract: Dictionary = {}) -> Dictionary:
	var continuity: Dictionary = super.build_continuity_contract(game_state, player_index, turn_contract)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return continuity
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return continuity

	var action_bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var active_name := _v175_slot_name(player.active_pokemon)
	var local_bonuses: Array[Dictionary] = []
	var local_attack_penalty := 0.0
	if active_name == BUDEW:
		if _best_ready_dragapult_slot(player) != null:
			return continuity
		var budew_debt := _v175_budew_continuity_setup_debt(player, game_state)
		for key: String in budew_debt.keys():
			setup_debt[key] = budew_debt[key]
		local_bonuses.append_array(_v175_budew_continuity_action_bonuses(setup_debt))
		local_attack_penalty = 520.0
	elif active_name == DRAGAPULT_EX and not _v175_dragapult_phantom_dive_ready(player.active_pokemon):
		if _has_closing_active_attack(game_state, player_index):
			return continuity
		var bridge_debt := _v175_active_dragapult_phantom_bridge_debt(player, game_state)
		for key: String in bridge_debt.keys():
			setup_debt[key] = bridge_debt[key]
		local_bonuses.append_array(_v175_active_dragapult_phantom_action_bonuses(bridge_debt))
		local_attack_penalty = 420.0
	if local_bonuses.is_empty():
		return continuity
	action_bonuses.append_array(local_bonuses)
	continuity["enabled"] = true
	continuity["safe_setup_before_attack"] = true
	continuity["setup_debt"] = setup_debt
	continuity["action_bonuses"] = action_bonuses
	continuity["attack_penalty"] = maxf(float(continuity.get("attack_penalty", 0.0)), local_attack_penalty)
	return continuity


func _score_basic_to_bench(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if _card_name(card) == BUDEW:
		if _v175_budew_count(player) > 0:
			return 20.0
		if _best_ready_dragapult_slot(player) != null:
			return 40.0
		return 620.0 if int(game_state.turn_number) <= 3 else 360.0
	return super._score_basic_to_bench(action, game_state, player_index)


func _score_evolve(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var base_score := super._score_evolve(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return base_score
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return base_score
	var player: PlayerState = game_state.players[player_index]
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var name := _card_name(card)
	if name == DRAKLOAK:
		if target_slot != null and _v175_slot_name(target_slot) == DREEPY:
			var score := maxf(base_score, 900.0)
			if _v175_slot_name(player.active_pokemon) == BUDEW:
				score = maxf(score, 980.0)
			if _v17_count_name(player, DRAGAPULT_EX) == 0:
				score += 80.0
			if _v175_hand_count(player, DRAKLOAK) >= 2:
				score += 40.0
			return score
		return maxf(base_score, 680.0)
	if name == DRAGAPULT_EX:
		if target_slot != null and _v175_slot_name(target_slot) == DRAKLOAK and _v175_slot_name(player.active_pokemon) == BUDEW:
			return maxf(base_score, 980.0)
	return base_score


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return super._score_trainer(action, game_state, player_index)
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	match name:
		IONO:
			var opponent: PlayerState = game_state.players[1 - player_index]
			var opponent_prizes := opponent.prizes.size()
			var own_prizes := player.prizes.size()
			if _best_ready_dragapult_slot(player) != null:
				if opponent_prizes <= 2:
					return 1500.0
				if opponent_prizes <= 3 and own_prizes >= opponent_prizes:
					return 1360.0
				if opponent_prizes <= 4 and own_prizes > opponent_prizes:
					return 860.0
		BUDDY_BUDDY_POFFIN:
			if player.bench.size() >= 5:
				return 0.0
			var missing_budew := _v175_budew_count(player) == 0 and _v175_deck_has(player, BUDEW)
			var missing_dreepy := _v17_dreepy_line_count(player) == 0 and _v175_deck_has(player, DREEPY)
			if missing_budew and missing_dreepy:
				return 820.0
			if missing_budew and _best_ready_dragapult_slot(player) == null:
				return 700.0
			if missing_dreepy:
				return 660.0
		NEST_BALL:
			if player.bench.size() >= 5:
				return 0.0
			if _v175_budew_count(player) == 0 and _v175_deck_has(player, BUDEW) and _best_ready_dragapult_slot(player) == null:
				return 560.0
			if _v17_dreepy_line_count(player) == 0 and _v175_deck_has(player, DREEPY):
				return 460.0
		SWITCH:
			if _v175_should_promote_budew(player):
				return 360.0
		LANCE:
			if _v17_dreepy_line_count(player) == 0:
				return 520.0
			if _v175_missing_dragapult_evolution(player):
				return 460.0
	return super._score_trainer(action, game_state, player_index)


func _score_retreat(player: PlayerState, game_state: GameState, player_index: int) -> float:
	if player != null and _v175_slot_name(player.active_pokemon) == BUDEW:
		if _has_ready_dragapult_promotion(player):
			return 560.0
		if _v17_dreepy_line_count(player) > 0 and int(game_state.turn_number) <= 5:
			return -260.0
	return super._score_retreat(player, game_state, player_index)


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot", null)
	var player: PlayerState = game_state.players[player_index]
	if source_slot != null and _v175_slot_name(source_slot) == BUDEW:
		if _has_ready_dragapult_promotion(player):
			return 180.0
		var score := 640.0
		if int(game_state.turn_number) <= 4:
			score += 90.0
		if _v17_dreepy_line_count(player) > 0:
			score += 80.0
		return score
	return super._score_attack(action, game_state, player_index)


func _score_search_pokemon(card: CardInstance, context: Dictionary, step_id: String = "") -> float:
	if card != null and _card_name(card) == BUDEW:
		return _v175_score_budew_search(_v17_context_player(context), context, step_id)
	return super._score_search_pokemon(card, context, step_id)


func _opening_priority(name: String, player: PlayerState) -> float:
	if name == BUDEW:
		return 520.0
	return super._opening_priority(name, player)


func _bench_priority(name: String, player: PlayerState) -> float:
	if name == BUDEW:
		return 420.0 if _v175_budew_count(player) == 0 else 20.0
	if name == DREEPY:
		return 560.0
	return super._bench_priority(name, player)


func _launch_pivot_name(player: PlayerState) -> String:
	if _v175_budew_count(player) > 0 and _best_ready_dragapult_slot(player) == null:
		return BUDEW
	return super._launch_pivot_name(player)


func evaluate_board(game_state: GameState, player_index: int) -> float:
	var score := super.evaluate_board(game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	if _v175_budew_count(player) > 0 and _best_ready_dragapult_slot(player) == null:
		score += 110.0
	return score


func get_discard_priority(card: CardInstance) -> int:
	if _card_name(card) == BUDEW:
		return 14
	return super.get_discard_priority(card)


func _card_name(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			var effect_id := str(instance.card_data.effect_id)
			if effect_id == BUDEW_EFFECT_ID:
				return BUDEW
			if effect_id == LANCE_EFFECT_ID:
				return LANCE
	return super._card_name(card)


func _v17_card_name(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			var effect_id := str(instance.card_data.effect_id)
			if effect_id == BUDEW_EFFECT_ID:
				return BUDEW
			if effect_id == LANCE_EFFECT_ID:
				return LANCE
	return super._v17_card_name(card)


func _v175_pick_opening_poffin_targets(items: Array, max_select: int, context: Dictionary) -> Array:
	var player := _v17_context_player(context)
	var prefer_opening_dragapult_backups := _v175_prefers_opening_dragapult_backups_before_duskull(player, context)
	var virtual_budew := _v175_budew_count(player)
	var virtual_dreepy := _v17_dreepy_line_count(player)
	var virtual_dusk := _v17_dusk_line_count(player)
	var remaining := items.duplicate()
	var picked: Array = []
	while picked.size() < max_select and not remaining.is_empty():
		var best_index := -1
		var best_score := -INF
		for i: int in remaining.size():
			var item: Variant = remaining[i]
			if not (item is CardInstance):
				continue
			var score := _v175_score_poffin_target_with_counts(item as CardInstance, virtual_budew, virtual_dreepy, virtual_dusk, prefer_opening_dragapult_backups)
			if score > best_score:
				best_score = score
				best_index = i
		if best_index < 0 or best_score <= 0.0:
			break
		var chosen: Variant = remaining[best_index]
		picked.append(chosen)
		remaining.remove_at(best_index)
		if chosen is CardInstance:
			match _card_name(chosen as CardInstance):
				BUDEW:
					virtual_budew += 1
				DREEPY:
					virtual_dreepy += 1
				DUSKULL:
					virtual_dusk += 1
	return picked


func _v175_pick_lance_dragon_targets(items: Array, max_select: int, context: Dictionary) -> Array:
	var player := _v17_context_player(context)
	var virtual_dreepy := _v17_count_name(player, DREEPY) + _v175_hand_count(player, DREEPY)
	var virtual_drakloak := _v17_count_name(player, DRAKLOAK) + _v175_hand_count(player, DRAKLOAK)
	var virtual_dragapult := _v17_count_name(player, DRAGAPULT_EX) + _v175_hand_count(player, DRAGAPULT_EX)
	var remaining := items.duplicate()
	var picked: Array = []
	while picked.size() < max_select and not remaining.is_empty():
		var best_index := -1
		var best_score := -INF
		for i: int in remaining.size():
			var item: Variant = remaining[i]
			if not (item is CardInstance):
				continue
			var score := _v175_score_lance_target_with_counts(item as CardInstance, virtual_dreepy, virtual_drakloak, virtual_dragapult)
			if score > best_score:
				best_score = score
				best_index = i
		if best_index < 0 or best_score <= 0.0:
			break
		var chosen: Variant = remaining[best_index]
		picked.append(chosen)
		remaining.remove_at(best_index)
		if chosen is CardInstance:
			match _card_name(chosen as CardInstance):
				DREEPY:
					virtual_dreepy += 1
				DRAKLOAK:
					virtual_drakloak += 1
				DRAGAPULT_EX:
					virtual_dragapult += 1
	return picked


func _v175_pick_energy_search_targets(items: Array, max_select: int, context: Dictionary) -> Array:
	var scored: Array[Dictionary] = []
	var player := _v17_context_player(context)
	for i: int in items.size():
		var item: Variant = items[i]
		if not (item is CardInstance):
			continue
		var score := _v175_score_energy_search_target(item as CardInstance, player)
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


func _v175_score_lance_target(card: CardInstance, player: PlayerState) -> float:
	return _v175_score_lance_target_with_counts(
		card,
		_v17_count_name(player, DREEPY) + _v175_hand_count(player, DREEPY),
		_v17_count_name(player, DRAKLOAK) + _v175_hand_count(player, DRAKLOAK),
		_v17_count_name(player, DRAGAPULT_EX) + _v175_hand_count(player, DRAGAPULT_EX)
	)


func _v175_score_lance_target_with_counts(card: CardInstance, dreepy_lines: int, drakloak_lines: int, dragapult_lines: int) -> float:
	match _card_name(card):
		DRAKLOAK:
			if dreepy_lines > drakloak_lines:
				return 990.0
			if dreepy_lines > 0 and dragapult_lines <= 0:
				return 760.0
			return 520.0
		DRAGAPULT_EX:
			if drakloak_lines > dragapult_lines:
				return 940.0
			if dreepy_lines > 0 and dragapult_lines <= 0:
				return 780.0
			return 500.0
		DREEPY:
			if dreepy_lines <= 0:
				return 700.0
			if dreepy_lines < 2:
				return 540.0
			return 180.0
	return 0.0


func _v175_score_energy_search_target(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return 0.0
	var energy_type := _v17_energy_type(card)
	var target := _v17_best_dragapult_energy_target(player)
	if target == null:
		return 180.0 if energy_type in ["R", "P"] else 20.0
	var missing_fire := not _v17_slot_has_energy_type(target, "R")
	var missing_psychic := not _v17_slot_has_energy_type(target, "P")
	if energy_type == "R" and missing_fire:
		return 980.0
	if energy_type == "P" and missing_psychic:
		return 940.0
	if energy_type in ["R", "P"]:
		return 260.0
	return 20.0


func _v175_prefers_opening_dragapult_backups_before_duskull(player: PlayerState, context: Dictionary) -> bool:
	if player == null or _v175_slot_name(player.active_pokemon) != BUDEW:
		return false
	if _v17_dusk_line_count(player) > 0 or _v17_dreepy_line_count(player) <= 0:
		return false
	var game_state: GameState = context.get("game_state", null)
	return game_state != null and int(game_state.turn_number) <= 2


func _v175_score_poffin_target_with_counts(
	card: CardInstance,
	budew_lines: int,
	dreepy_lines: int,
	dusk_lines: int,
	prefer_opening_dragapult_backups: bool = false
) -> float:
	match _card_name(card):
		BUDEW:
			if budew_lines <= 0:
				return 980.0
			return 40.0
		DREEPY:
			if dreepy_lines <= 0:
				return 940.0
			if prefer_opening_dragapult_backups and dusk_lines <= 0 and dreepy_lines < 3:
				return 560.0
			if dreepy_lines < 2:
				return 700.0
			return 260.0
		DUSKULL:
			if dusk_lines <= 0 and budew_lines > 0 and dreepy_lines > 0:
				return 520.0
			if dusk_lines <= 0:
				return 180.0
			return 60.0
	return 0.0


func _v175_score_budew_search(player: PlayerState, context: Dictionary, step_id: String) -> float:
	if player == null:
		return 120.0
	if _v175_budew_count(player) > 0:
		return 30.0
	if _best_ready_dragapult_slot(player) != null:
		return 80.0
	if player.bench.size() >= 5 and step_id in ["bench_pokemon", "basic_pokemon", "buddy_poffin_pokemon"]:
		return 0.0
	var score := 620.0
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and int(game_state.turn_number) <= 3:
		score += 140.0
	if _v17_dreepy_line_count(player) > 0:
		score += 80.0
	return score


func _v175_score_self_handoff(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var player := _v17_context_player(context)
	var base := super._score_send_out(slot)
	var name := _v175_slot_name(slot)
	if name == DRAGAPULT_EX and _can_slot_attack(slot):
		return base + 240.0
	if name == BUDEW:
		if player != null and _has_ready_dragapult_promotion(player):
			return 90.0
		if player != null and _v17_dreepy_line_count(player) > 0:
			return base + 520.0
		return base + 440.0
	if name == DREEPY and player != null and _v175_budew_count(player) > 0 and _best_ready_dragapult_slot(player) == null:
		return base - 120.0
	return base


func _v175_budew_continuity_setup_debt(player: PlayerState, game_state: GameState) -> Dictionary:
	var dreepy_lines := _v17_dreepy_line_count(player)
	var dusk_lines := _v17_dusk_line_count(player)
	var has_bench_space := player != null and player.bench.size() < 5
	var search_safe := not _v17_under_deck_out_pressure(player, game_state)
	return {
		"budew_active": player != null and _v175_slot_name(player.active_pokemon) == BUDEW,
		"dreepy_family_lines": dreepy_lines,
		"dusk_family_lines": dusk_lines,
		"needs_backup_dragapult_basic": (
			player != null
			and has_bench_space
			and search_safe
			and dreepy_lines < 2
			and _v175_deck_has(player, DREEPY)
		),
		"needs_duskull_basic": (
			player != null
			and has_bench_space
			and search_safe
			and dusk_lines == 0
			and _v175_deck_has(player, DUSKULL)
		),
		"needs_lance_evolution_search": (
			player != null
			and search_safe
			and _v175_missing_dragapult_evolution(player)
			and _v175_deck_has_useful_lance_target(player)
		),
		"needs_dragapult_energy": player != null and _v17_best_dragapult_energy_target(player) != null,
		"needs_dragapult_crystal": player != null and _v175_can_still_route_sparkling_crystal(player),
		"pending_drakloak_recon": _v175_has_pending_recon_drakloak(player, game_state),
	}


func _v175_budew_continuity_action_bonuses(setup_debt: Dictionary) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if bool(setup_debt.get("needs_backup_dragapult_basic", false)) or bool(setup_debt.get("needs_duskull_basic", false)):
		bonuses.append({
			"kind": "play_trainer",
			"card_names": [BUDDY_BUDDY_POFFIN, NEST_BALL],
			"target_names": [DREEPY, DUSKULL],
			"bonus": 420.0,
			"reason": "seed_dragapult_or_duskull_before_budew_terminal_attack",
		})
	if bool(setup_debt.get("needs_lance_evolution_search", false)):
		bonuses.append({
			"kind": "play_trainer",
			"card_names": [LANCE],
			"target_names": [DREEPY, DRAKLOAK, DRAGAPULT_EX],
			"bonus": 460.0,
			"reason": "find_dragapult_evolution_before_budew_terminal_attack",
		})
	if bool(setup_debt.get("needs_dragapult_energy", false)):
		bonuses.append({
			"kind": "attach_energy",
			"target_names": [DREEPY, DRAKLOAK, DRAGAPULT_EX],
			"bonus": 360.0,
			"reason": "power_dragapult_line_before_budew_terminal_attack",
		})
	if bool(setup_debt.get("needs_dragapult_crystal", false)):
		bonuses.append({
			"kind": "attach_tool",
			"card_names": [SPARKLING_CRYSTAL],
			"target_names": [DREEPY, DRAKLOAK, DRAGAPULT_EX],
			"bonus": 300.0,
			"reason": "attach_sparkling_crystal_before_budew_terminal_attack",
		})
	if bool(setup_debt.get("pending_drakloak_recon", false)):
		bonuses.append({
			"kind": "use_ability",
			"target_names": [DRAKLOAK],
			"bonus": 680.0,
			"reason": "use_drakloak_recon_before_budew_terminal_attack",
		})
	return bonuses


func _v175_active_dragapult_phantom_bridge_debt(player: PlayerState, game_state: GameState) -> Dictionary:
	if player == null or game_state == null:
		return {}
	var active := player.active_pokemon
	if active == null or _v175_slot_name(active) != DRAGAPULT_EX or _v175_dragapult_phantom_dive_ready(active):
		return {}
	var missing_types := _v175_dragapult_missing_phantom_energy_types(active)
	var search_safe := not _v17_under_deck_out_pressure(player, game_state)
	var deck_energy_available := false
	var hand_energy_available := false
	for missing_type: String in missing_types:
		deck_energy_available = deck_energy_available or _v175_deck_has_energy_type(player, missing_type)
		hand_energy_available = hand_energy_available or _v175_hand_has_energy_type(player, missing_type)
	var crystal_would_bridge := _v175_active_dragapult_crystal_would_bridge(active)
	var deck_crystal_available := crystal_would_bridge and _v175_deck_has(player, SPARKLING_CRYSTAL)
	var hand_crystal_available := crystal_would_bridge and _has_hand_card(player, SPARKLING_CRYSTAL)
	var can_search_bridge_piece := (
		search_safe
		and (
			(_has_hand_card(player, EARTHEN_VESSEL) and deck_energy_available)
			or (
				_has_hand_card(player, ARVEN)
				and (deck_energy_available or deck_crystal_available or _v175_deck_has(player, EARTHEN_VESSEL))
			)
		)
	)
	return {
		"active_dragapult_needs_phantom_energy": not missing_types.is_empty(),
		"active_dragapult_missing_phantom_energy_types": missing_types,
		"active_dragapult_manual_energy_available": hand_energy_available,
		"active_dragapult_energy_search_available": can_search_bridge_piece,
		"active_dragapult_crystal_available": hand_crystal_available,
		"pending_drakloak_recon": (
			_v175_has_pending_recon_drakloak(player, game_state)
			and search_safe
			and (deck_energy_available or deck_crystal_available or _v175_deck_has(player, EARTHEN_VESSEL))
		),
	}


func _v175_active_dragapult_phantom_action_bonuses(setup_debt: Dictionary) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if bool(setup_debt.get("active_dragapult_manual_energy_available", false)):
		bonuses.append({
			"kind": "attach_energy",
			"target_names": [DRAGAPULT_EX],
			"bonus": 520.0,
			"reason": "attach_phantom_energy_before_jet_head",
		})
	if bool(setup_debt.get("active_dragapult_crystal_available", false)):
		bonuses.append({
			"kind": "attach_tool",
			"card_names": [SPARKLING_CRYSTAL],
			"target_names": [DRAGAPULT_EX],
			"bonus": 520.0,
			"reason": "attach_sparkling_crystal_before_jet_head",
		})
	if bool(setup_debt.get("active_dragapult_energy_search_available", false)):
		bonuses.append({
			"kind": "play_trainer",
			"card_names": [EARTHEN_VESSEL, ARVEN],
			"bonus": 430.0,
			"reason": "find_phantom_energy_before_jet_head",
		})
	if bool(setup_debt.get("pending_drakloak_recon", false)):
		bonuses.append({
			"kind": "use_ability",
			"target_names": [DRAKLOAK],
			"bonus": 560.0,
			"reason": "use_drakloak_recon_to_find_phantom_energy_before_jet_head",
		})
	return bonuses


func _v175_dragapult_missing_phantom_energy_types(slot: PokemonSlot) -> Array[String]:
	var missing: Array[String] = []
	if slot == null or _v175_slot_name(slot) != DRAGAPULT_EX:
		return missing
	if _slot_has_tool(slot, SPARKLING_CRYSTAL) and slot.get_card_data() != null and str(slot.get_card_data().ancient_trait) == "Tera":
		if not _v175_slot_has_any_phantom_energy(slot):
			missing.append("R")
			missing.append("P")
		return missing
	if not _v17_slot_has_energy_type(slot, "R"):
		missing.append("R")
	if not _v17_slot_has_energy_type(slot, "P"):
		missing.append("P")
	return missing


func _v175_active_dragapult_crystal_would_bridge(slot: PokemonSlot) -> bool:
	if slot == null or _v175_slot_name(slot) != DRAGAPULT_EX or _slot_has_tool(slot, SPARKLING_CRYSTAL):
		return false
	if slot.get_card_data() != null and str(slot.get_card_data().ancient_trait) != "Tera":
		return false
	return _v175_slot_has_any_phantom_energy(slot)


func _v175_slot_has_any_phantom_energy(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _v17_energy_type(energy) in ["R", "P", "ANY"]:
			return true
	return false


func _v175_deck_has_energy_type(player: PlayerState, target_type: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _v17_energy_type(card) in [target_type, "ANY"]:
			return true
	return false


func _v175_hand_has_energy_type(player: PlayerState, target_type: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _v17_energy_type(card) in [target_type, "ANY"]:
			return true
	return false


func _v175_deck_has_useful_lance_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _card_name(card) in [DREEPY, DRAKLOAK, DRAGAPULT_EX]:
			return true
	return false


func _v175_can_still_route_sparkling_crystal(player: PlayerState) -> bool:
	if player == null or not (_has_hand_card(player, SPARKLING_CRYSTAL) or _v175_deck_has(player, SPARKLING_CRYSTAL)):
		return false
	for slot: PokemonSlot in _all_slots(player):
		var name := _v175_slot_name(slot)
		if name in [DREEPY, DRAKLOAK, DRAGAPULT_EX] and not _slot_has_tool(slot, SPARKLING_CRYSTAL):
			return true
	return false


func _v175_should_promote_budew(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _v175_slot_name(player.active_pokemon) == BUDEW:
		return false
	if _best_ready_dragapult_slot(player) != null:
		return false
	return _v175_budew_count(player) > 0 and _v17_dreepy_line_count(player) > 0


func _v175_missing_dragapult_evolution(player: PlayerState) -> bool:
	if player == null:
		return false
	if _v17_dreepy_line_count(player) <= 0:
		return true
	if _v17_count_name(player, DRAGAPULT_EX) == 0 and (_v175_deck_has(player, DRAGAPULT_EX) or _has_hand_card(player, DRAGAPULT_EX)):
		return true
	if _v17_count_name(player, DRAKLOAK) == 0 and (_v175_deck_has(player, DRAKLOAK) or _has_hand_card(player, DRAKLOAK)):
		return true
	return false


func _v175_budew_count(player: PlayerState) -> int:
	return _v17_count_name(player, BUDEW)


func _v175_deck_has(player: PlayerState, target_name: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _card_name(card) == target_name:
			return true
	return false


func _v175_hand_count(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if _card_name(card) == target_name:
			count += 1
	return count


func _v175_slot_name(slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	return _card_name(slot.get_top_card())


func _v175_is_recon_drakloak(slot: PokemonSlot) -> bool:
	if slot == null or _v175_slot_name(slot) != DRAKLOAK:
		return false
	var card_data := slot.get_card_data()
	return card_data != null and str(card_data.effect_id) == DRAKLOAK_RECON_EFFECT_ID


func _v175_has_pending_recon_drakloak(player: PlayerState, game_state: GameState) -> bool:
	if player == null or game_state == null or player.deck.is_empty():
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _v175_recon_drakloak_pending(slot, game_state):
			return true
	return false


func _v175_recon_drakloak_pending(slot: PokemonSlot, game_state: GameState) -> bool:
	if not _v175_is_recon_drakloak(slot):
		return false
	for effect_data: Dictionary in slot.effects:
		if str(effect_data.get("type", "")) == DRAKLOAK_RECON_USED_FLAG and int(effect_data.get("turn", -1)) == int(game_state.turn_number):
			return false
	return true


func _v175_dragapult_phantom_dive_ready(slot: PokemonSlot) -> bool:
	if slot == null or _v175_slot_name(slot) != DRAGAPULT_EX:
		return false
	var fire_count := 0
	var psychic_count := 0
	var any_count := 0
	for energy: CardInstance in slot.attached_energy:
		var energy_type := _v17_energy_type(energy)
		match energy_type:
			"R":
				fire_count += 1
			"P":
				psychic_count += 1
			"ANY":
				any_count += 1
	if _slot_has_tool(slot, SPARKLING_CRYSTAL) and slot.get_card_data() != null and str(slot.get_card_data().ancient_trait) == "Tera":
		return fire_count + psychic_count + any_count > 0
	if fire_count > 0:
		return psychic_count > 0 or any_count > 0
	if any_count > 0:
		any_count -= 1
		return psychic_count > 0 or any_count > 0
	return false
