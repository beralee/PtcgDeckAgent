class_name DeckStrategy17ArchaludonDialga
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const DURALUDON := "CSV9C_136"
const ARCHALUDON_EX := "CSV9C_138"
const DIALGA_V := "Origin Forme Dialga V"
const DIALGA_VSTAR := "Origin Forme Dialga VSTAR"
const MEW_EX := "Mew ex"
const RADIANT_GRENINJA := "Radiant Greninja"
const FEZANDIPITI_EX := "Fezandipiti ex"
const METAL := "M"


func _profile() -> Dictionary:
	return {
		"strategy_id": "v17_archaludon_dialga",
		"signatures": [DIALGA_V, DIALGA_VSTAR, DURALUDON, ARCHALUDON_EX],
		"active_priority": [DURALUDON, MEW_EX, RADIANT_GRENINJA, DIALGA_V],
		"bench_priority": [DURALUDON, DIALGA_V, RADIANT_GRENINJA, MEW_EX, FEZANDIPITI_EX],
		"search_priority": [DURALUDON, ARCHALUDON_EX, DIALGA_V, DIALGA_VSTAR, RADIANT_GRENINJA, MEW_EX],
		"evolution_priority": [ARCHALUDON_EX, DIALGA_VSTAR],
		"energy_priority": [DIALGA_VSTAR, DIALGA_V, ARCHALUDON_EX, DURALUDON],
		"ability_priority": [ARCHALUDON_EX, RADIANT_GRENINJA, MEW_EX, FEZANDIPITI_EX],
	}


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	if _matches_key(slot, DIALGA_VSTAR):
		var attached := slot.attached_energy.size() + extra_context
		var metal_attached := _attached_energy_count(slot, METAL) + extra_context
		var best_damage := 0
		var can_attack := false
		for attack: Dictionary in slot.get_card_data().attacks:
			var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
			if attached < cost.length():
				continue
			can_attack = true
			var attack_name := str(attack.get("name", "")).to_lower()
			var raw_damage := str(attack.get("damage", "0"))
			if attack_name.contains("metal blast") or raw_damage.begins_with("40+"):
				best_damage = maxi(best_damage, 40 + 40 * metal_attached)
			elif attack_name.contains("star chronos"):
				best_damage = maxi(best_damage, 220)
			else:
				best_damage = maxi(best_damage, _parse_damage(raw_damage))
		return {"damage": best_damage, "can_attack": can_attack, "description": "dialga_metal_scaling"}
	return super.predict_attacker_damage(slot, extra_context)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var base_score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return base_score
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"attack", "granted_attack":
			return _score_archaludon_attack_action(action, player, game_state, player_index, base_score)
		"attach_energy":
			return _score_archaludon_attach_action(action, player, game_state, player_index, base_score)
		"evolve":
			return _score_archaludon_evolve_action(action, player, base_score)
		"play_basic_to_bench":
			return _score_archaludon_basic_action(action, player, base_score)
		"play_trainer", "play_stadium":
			return _score_archaludon_trainer_action(action, player, base_score)
		"use_ability", "use_stadium_effect":
			return _score_archaludon_ability_action(action, player, base_score)
		"retreat":
			return _score_archaludon_retreat_action(player, base_score)
	return base_score


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if _is_energy_assignment_step(step_id):
			var player := _player_from_context(context)
			var pending := _pending_energy_for_slot(slot, context)
			return _metal_energy_target_score(slot, player, pending + 1)
		if _is_handoff_step(step_id):
			return _metal_handoff_score(slot, context)
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard"):
			var player := _player_from_context(context)
			return float(_discard_priority_for_route(card, player))
		if step_id.contains("search") or step_id.contains("choose") or step_id.contains("select"):
			var player := _player_from_context(context)
			return float(_search_priority_for_route(card, player))
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		return _metal_handoff_score(item as PokemonSlot, context)
	return score_interaction_target(item, step, context)


func get_discard_priority(card: CardInstance) -> int:
	return _discard_priority_for_route(card, null)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	return _discard_priority_for_route(card, player)


func get_search_priority(card: CardInstance) -> int:
	return _search_priority_for_route(card, null)


func _score_archaludon_attack_action(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	if source == null:
		return base_score
	var attack_name := str(action.get("attack_name", "")).to_lower()
	var attack_index := int(action.get("attack_index", -1))
	if _matches_key(source, DIALGA_V):
		if attack_index == 0 or attack_name.contains("metal coating"):
			return _score_metal_coating(source, player)
		return base_score
	if _matches_key(source, DIALGA_VSTAR):
		if attack_index == 0 or attack_name.contains("metal blast"):
			var damage := 40 + 40 * _attached_energy_count(source, METAL)
			return _score_damage_attack(damage, game_state, player_index, 500.0, 1120.0)
		if attack_index == 1 or attack_name.contains("star chronos"):
			return _score_damage_attack(220, game_state, player_index, 780.0, 1320.0)
	if _matches_key(source, ARCHALUDON_EX):
		var damage := maxi(220, int(action.get("projected_damage", 0)))
		if damage > 0:
			return maxf(base_score, _score_damage_attack(damage, game_state, player_index, 690.0, 1160.0))
	return base_score


func _score_archaludon_attach_action(
	action: Dictionary,
	player: PlayerState,
	_game_state: GameState,
	_player_index: int,
	base_score: float
) -> float:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null:
		return base_score
	if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type(card) != METAL:
		return maxf(20.0, base_score * 0.35)
	return 210.0 + _metal_energy_target_score(target, player, 1)


func _score_archaludon_evolve_action(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if card == null or target == null:
		return base_score
	if _matches_key(card, ARCHALUDON_EX):
		var score := maxf(base_score, 780.0)
		if _metal_energy_in_discard(player) > 0:
			score += 150.0
		if _attached_energy_count(target, METAL) >= 1:
			score += 70.0
		if player != null and target == player.active_pokemon:
			score += 80.0
		return score
	if _matches_key(card, DIALGA_VSTAR):
		var score := maxf(base_score, 720.0)
		var attached := _attached_energy_count(target, METAL)
		if attached >= 3:
			score += 160.0
		elif attached >= 1:
			score += 70.0
		return score
	return base_score


func _score_archaludon_basic_action(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null:
		return base_score
	if _matches_key(card, DURALUDON):
		var existing := _count_slots_matching(player, DURALUDON)
		return maxf(base_score, 520.0 if existing == 0 else 330.0)
	if _matches_key(card, DIALGA_V):
		var existing := _count_slots_matching(player, DIALGA_V)
		return maxf(base_score, 500.0 if existing == 0 else 250.0)
	if _matches_key(card, RADIANT_GRENINJA) or _matches_key(card, MEW_EX):
		return maxf(base_score, 255.0)
	return base_score


func _score_archaludon_trainer_action(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var card: CardInstance = action.get("card", null)
	var name := _primary_name(card).to_lower()
	var score := base_score
	if name.contains("earthen vessel"):
		if _metal_energy_in_discard(player) < 2:
			score += 95.0
		if _count_energy_in_hand(player, METAL) <= 1:
			score += 60.0
	if name.contains("ultra ball"):
		if _count_slots_matching(player, ARCHALUDON_EX) == 0 and _count_slots_matching(player, DURALUDON) > 0:
			score += 90.0
		if _count_slots_matching(player, DIALGA_VSTAR) == 0 and _count_slots_matching(player, DIALGA_V) > 0:
			score += 65.0
	if name.contains("nest ball"):
		if _count_slots_matching(player, DURALUDON) == 0:
			score += 100.0
		elif _count_slots_matching(player, DIALGA_V) == 0:
			score += 70.0
	if _is_draw_churn_name(name) and _deck_is_thin(player) and _has_ready_metal_attacker(player):
		score = minf(score, 70.0)
	return score


func _score_archaludon_ability_action(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	if source == null:
		return base_score
	if _matches_key(source, ARCHALUDON_EX):
		var score := maxf(base_score, 620.0)
		var discard_metal := _metal_energy_in_discard(player)
		if discard_metal >= 2:
			score += 230.0
		elif discard_metal == 1:
			score += 120.0
		if _best_energy_target_needs(player, 1):
			score += 90.0
		return score
	if (_matches_key(source, RADIANT_GRENINJA) or _matches_key(source, MEW_EX) or _matches_key(source, FEZANDIPITI_EX)) and _deck_is_thin(player) and _has_ready_metal_attacker(player):
		return minf(base_score, 55.0)
	return base_score


func _score_archaludon_retreat_action(player: PlayerState, base_score: float) -> float:
	if player == null:
		return base_score
	var active_score := _metal_handoff_score(player.active_pokemon, {"player": player})
	var best_bench := -9999.0
	for slot: PokemonSlot in player.bench:
		best_bench = maxf(best_bench, _metal_handoff_score(slot, {"player": player}))
	return maxf(base_score, 220.0) if best_bench > active_score + 90.0 else minf(base_score, 45.0)


func _score_metal_coating(source: PokemonSlot, player: PlayerState) -> float:
	var discard_metal := _metal_energy_in_discard(player)
	var need := maxi(0, 5 - _attached_energy_count(source, METAL))
	if discard_metal <= 0 or need <= 0:
		return 45.0
	var useful_accel := mini(2, mini(discard_metal, need))
	var score := 390.0 + float(useful_accel) * 185.0
	if not _has_ready_metal_attacker(player):
		score += 80.0
	if _count_slots_matching(player, DIALGA_VSTAR) > 0:
		score += 65.0
	return score


func _score_damage_attack(
	damage: int,
	game_state: GameState,
	player_index: int,
	normal_base: float,
	ko_base: float
) -> float:
	var remaining := _opponent_active_remaining_hp(game_state, player_index)
	if remaining > 0 and damage >= remaining:
		return ko_base + float(damage) * 0.45
	if damage >= 220:
		return normal_base + float(damage) * 1.15
	if damage >= 160:
		return normal_base + float(damage) * 0.95
	return 260.0 + float(damage) * 0.85


func _metal_energy_target_score(slot: PokemonSlot, player: PlayerState, incoming_metal: int = 1) -> float:
	if slot == null:
		return 0.0
	var current := _attached_energy_count(slot, METAL)
	var after := current + maxi(0, incoming_metal)
	var ready_archaludon := _has_ready_archaludon(player)
	var has_dialga_route := _has_dialga_route(player)
	if _matches_key(slot, ARCHALUDON_EX):
		if ready_archaludon and has_dialga_route and current >= 3:
			return 210.0 if player != null and slot == player.active_pokemon else 150.0
		var score := 470.0
		if current < 3:
			score += 150.0 * float(3 - current)
		if after >= 3 and current < 3:
			score += 320.0
		if player != null and slot == player.active_pokemon:
			score += 110.0
		return score
	if _matches_key(slot, DIALGA_VSTAR):
		var score := 390.0 + float(after) * 35.0
		if ready_archaludon:
			score += 260.0 + float(maxi(0, 5 - current)) * 45.0
		if after >= 5 and current < 5:
			score += 330.0
		elif after >= 4:
			score += 130.0
		if 40 + 40 * after >= 220:
			score += 105.0
		return score
	if _matches_key(slot, DIALGA_V):
		var score := 315.0
		if ready_archaludon:
			score += 190.0
		if current == 0:
			score += 170.0
		elif current < 3 and not _has_ready_metal_attacker(player):
			score += 85.0
		if _count_slots_matching(player, DIALGA_VSTAR) > 0:
			score += 45.0
		return score
	if _matches_key(slot, DURALUDON):
		if ready_archaludon and has_dialga_route:
			return 130.0 + float(current) * 20.0
		var score := 260.0
		if _count_slots_matching(player, ARCHALUDON_EX) == 0 and current < 2:
			score += 155.0
		if player != null and slot == player.active_pokemon and current < 3:
			score += 105.0
		return score
	if _is_support_slot(slot):
		return -80.0 if _has_other_metal_target(player, slot) else 35.0
	return 80.0 + float(after) * 10.0


func _metal_handoff_score(slot: PokemonSlot, context: Dictionary = {}) -> float:
	if slot == null:
		return 0.0
	var player := _player_from_context(context)
	var prediction := predict_attacker_damage(slot)
	var can_attack := bool(prediction.get("can_attack", false))
	var damage := int(prediction.get("damage", 0))
	if can_attack and damage > 0:
		var score := 500.0 + float(damage) * 1.35
		if _matches_key(slot, ARCHALUDON_EX):
			score += 120.0
		elif _matches_key(slot, DIALGA_VSTAR):
			score += 90.0
		return score
	if _matches_key(slot, ARCHALUDON_EX):
		return 290.0 + float(_attached_energy_count(slot, METAL)) * 55.0
	if _matches_key(slot, DURALUDON):
		return 180.0 + float(_attached_energy_count(slot, METAL)) * 45.0
	if _matches_key(slot, DIALGA_VSTAR) or _matches_key(slot, DIALGA_V):
		return 150.0 + float(_attached_energy_count(slot, METAL)) * 42.0
	if _is_support_slot(slot):
		return 25.0 if _has_other_metal_target(player, slot) else 75.0
	return 70.0


func _search_priority_for_route(card: CardInstance, player: PlayerState) -> int:
	var base_priority := super.get_search_priority(card)
	if card == null:
		return base_priority
	if _matches_key(card, DURALUDON):
		return 330 if _count_slots_matching(player, DURALUDON) == 0 else max(base_priority, 230)
	if _matches_key(card, ARCHALUDON_EX):
		return 325 if _count_slots_matching(player, ARCHALUDON_EX) == 0 else max(base_priority, 220)
	if _matches_key(card, DIALGA_V):
		return 300 if _count_slots_matching(player, DIALGA_V) == 0 else max(base_priority, 205)
	if _matches_key(card, DIALGA_VSTAR):
		return 285 if _count_slots_matching(player, DIALGA_V) > 0 else max(base_priority, 220)
	if card.card_data != null and card.card_data.is_energy() and _energy_type(card) == METAL:
		if _count_energy_in_hand(player, METAL) <= 1:
			return 170
		return max(base_priority, 95)
	return base_priority


func _discard_priority_for_route(card: CardInstance, player: PlayerState) -> int:
	var base_priority := super.get_discard_priority(card)
	if card == null or card.card_data == null:
		return base_priority
	if card.card_data.is_energy() and _energy_type(card) == METAL:
		return 135 if _metal_energy_in_discard(player) < 2 else 105
	if _matches_key(card, ARCHALUDON_EX) or _matches_key(card, DIALGA_VSTAR):
		return 12
	if _matches_key(card, DURALUDON) and _count_slots_matching(player, DURALUDON) == 0:
		return 8
	if _matches_key(card, DIALGA_V) and _count_slots_matching(player, DIALGA_V) == 0:
		return 10
	if _matches_key(card, RADIANT_GRENINJA) or _matches_key(card, MEW_EX) or _matches_key(card, FEZANDIPITI_EX):
		return 75
	return base_priority


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.has("player") and context["player"] is PlayerState:
		return context["player"] as PlayerState
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		return game_state.players[player_index]
	return null


func _is_energy_assignment_step(step_id: String) -> bool:
	return step_id.contains("assign") or step_id.contains("attach") or step_id.contains("energy")


func _is_handoff_step(step_id: String) -> bool:
	return step_id.contains("switch") or step_id.contains("send") or step_id.contains("active") or step_id.contains("handoff")


func _pending_energy_for_slot(slot: PokemonSlot, context: Dictionary) -> int:
	var pending_counts: Variant = context.get("pending_assignment_counts", {})
	if pending_counts is Dictionary:
		for key: Variant in (pending_counts as Dictionary).keys():
			if key is PokemonSlot and key == slot:
				return int((pending_counts as Dictionary).get(key, 0))
			if str(key) == str(slot):
				return int((pending_counts as Dictionary).get(key, 0))
	return 0


func _best_energy_target_needs(player: PlayerState, incoming_metal: int) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _metal_energy_target_score(slot, player, incoming_metal) >= 550.0:
			return true
	return false


func _has_ready_metal_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		var prediction := predict_attacker_damage(slot)
		if bool(prediction.get("can_attack", false)) and int(prediction.get("damage", 0)) >= 160:
			return true
	return false


func _has_ready_archaludon(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_key(slot, ARCHALUDON_EX):
			continue
		var prediction := predict_attacker_damage(slot)
		if bool(prediction.get("can_attack", false)) and int(prediction.get("damage", 0)) >= 220:
			return true
	return false


func _has_dialga_route(player: PlayerState) -> bool:
	return _count_slots_matching(player, DIALGA_V) > 0 or _count_slots_matching(player, DIALGA_VSTAR) > 0


func _has_other_metal_target(player: PlayerState, excluded: PokemonSlot) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or slot == excluded:
			continue
		if _matches_key(slot, ARCHALUDON_EX) or _matches_key(slot, DIALGA_VSTAR) or _matches_key(slot, DIALGA_V) or _matches_key(slot, DURALUDON):
			return true
	return false


func _count_slots_matching(player: PlayerState, key: String) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, key):
			count += 1
	return count


func _count_energy_in_hand(player: PlayerState, energy_type: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type(card) == energy_type:
			count += 1
	return count


func _metal_energy_in_discard(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type(card) == METAL:
			count += 1
	return count


func _attached_energy_count(slot: PokemonSlot, energy_type: String) -> int:
	if slot == null:
		return 0
	var count := 0
	for card: CardInstance in slot.attached_energy:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type(card) == energy_type:
			count += 1
	return count


func _energy_type(card: Variant) -> String:
	var cd := _card_data_from_item(card)
	if cd == null:
		return ""
	if str(cd.energy_provides) != "":
		return str(cd.energy_provides)
	return str(cd.energy_type)


func _is_support_slot(slot: PokemonSlot) -> bool:
	return _matches_key(slot, MEW_EX) or _matches_key(slot, RADIANT_GRENINJA) or _matches_key(slot, FEZANDIPITI_EX)


func _is_draw_churn_name(name: String) -> bool:
	return name.contains("professor") or name.contains("iono") or name.contains("greninja") or name.contains("restart") or name.contains("draw")


func _deck_is_thin(player: PlayerState) -> bool:
	return player != null and player.deck.size() <= 14


func _opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	if game_state == null:
		return 0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0
	var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
	if defender == null or defender.get_card_data() == null:
		return 0
	return maxi(0, int(defender.get_card_data().hp) - int(defender.damage_counters))
