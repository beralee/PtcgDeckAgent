class_name DeckStrategyV18Stage2Core
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const ProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const CardCatalogIndexScript = preload("res://scripts/card_catalog/CardCatalogIndex.gd")
const MAMOSWINE_BLAZIKEN_DECK_ID := 800017047
const MAMOSWINE_EX_UID := "CSV10C_104"
const BLAZIKEN_EX_UID := "CSV7C_038"
const FIGHTING_ENERGY_TYPE := "F"
const FIRE_ENERGY_TYPE := "R"
const TM_EVOLUTION_HARD_REJECT_SCORE := -10000.0
const MAMOSWINE_RETREAT_BRIDGE_SCORE := 5200.0

var _deck_id := 0
var _profile_data: Dictionary = {}
var _deck_cards: Array[CardData] = []
var _stage1_cards: Array[CardData] = []
var _stage2_cards: Array[CardData] = []
var _chain_seeds: Array[CardData] = []


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else 0
	_profile_data = ProfileCatalogScript.get_profile_for_deck(_deck_id)
	_deck_cards.clear()
	_stage1_cards.clear()
	_stage2_cards.clear()
	_chain_seeds.clear()
	if deck == null:
		return
	var catalog: RefCounted = CardCatalogIndexScript.new()
	for entry: Dictionary in deck.cards:
		var card := _load_deck_card(entry, catalog)
		if card == null:
			continue
		_deck_cards.append(card)
		match str(card.stage).to_lower():
			"stage 1":
				_stage1_cards.append(card)
			"stage 2":
				_stage2_cards.append(card)
	for card: CardData in _deck_cards:
		if not card.is_basic_pokemon():
			continue
		for middle: CardData in _stage1_cards:
			if middle.evolves_from_matches(card) and _has_stage2_child(middle):
				_chain_seeds.append(card)
				break


func _load_deck_card(entry: Dictionary, catalog: RefCounted) -> CardData:
	var set_code := str(entry.get("set_code", ""))
	var card_index := str(entry.get("card_index", ""))
	var bundled_path := "res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]
	if FileAccess.file_exists(bundled_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(bundled_path))
		if parsed is Dictionary:
			var card := CardData.from_dict(parsed)
			if card.set_code == "":
				card.set_code = set_code
			if card.card_index == "":
				card.card_index = card_index
			return card
	if catalog != null and catalog.has_method("get_card_data"):
		return catalog.call("get_card_data", set_code, card_index) as CardData
	return null


func _profile() -> Dictionary:
	return _profile_data


func get_strategy_id() -> String:
	return "v18_stage2_core_%d" % _deck_id


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var owner := _first_profile_name("energy_priority")
	var phase := "seed"
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
		var best := _best_chain_slot(player)
		if best != null:
			owner = _primary_name(best)
			var stage := str(best.get_card_data().stage).to_lower()
			phase = "attack" if stage == "stage 2" and _stage2_route_online(best) else "evolve"
	var flags := {
		"stage2_chain_core": true,
		"stage2_online": phase == "attack",
	}
	if _deck_id == MAMOSWINE_BLAZIKEN_DECK_ID:
		flags["setup_debt"] = _stage2_setup_debt(player)
	return {
		"id": "v18_stage2_chain_%d" % _deck_id,
		"intent": "complete_stage2_route" if phase != "attack" else "convert_stage2_attack",
		"phase": phase,
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": owner,
			"pivot_target_name": owner,
		},
		"priorities": {
			"attach": _profile_list("energy_priority"),
			"handoff": _profile_list("energy_priority"),
			"search": _profile_list("search_priority"),
		},
		"flags": flags,
		"constraints": {},
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	if _deck_id != MAMOSWINE_BLAZIKEN_DECK_ID:
		return super.build_continuity_contract(game_state, player_index, turn_contract)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var setup_debt := _stage2_setup_debt(player)
	var ready_attacker := false
	for slot: PokemonSlot in _all_slots(player):
		if bool(predict_attacker_damage(slot).get("can_attack", false)):
			ready_attacker = true
			break
	return {
		"enabled": true,
		"safe_setup_before_attack": setup_debt > 0 and ready_attacker,
		"setup_debt": {
			"missing_mamoswine_route": setup_debt,
			"turn_contract_id": str(turn_contract.get("id", "")),
		},
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	var kind := str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			if _is_chain_seed(_card_data_from_item(action.get("card", null))):
				return maxf(score, 2800.0)
		"evolve":
			var evolution := _card_data_from_item(action.get("card", null))
			if _is_chain_stage2(evolution):
				return maxf(score, 4300.0)
			if _is_chain_stage1(evolution):
				return maxf(score, 3300.0)
		"attach_energy":
			if _mamoswine_retreat_bridge_is_live(action, player):
				return maxf(score, MAMOSWINE_RETREAT_BRIDGE_SCORE)
			var target: PokemonSlot = action.get("target_slot", null)
			var source: Variant = action.get("card", null)
			if _deck_id == MAMOSWINE_BLAZIKEN_DECK_ID \
					and _provides_energy_type(source, FIGHTING_ENERGY_TYPE) \
					and _stage2_setup_debt(player) > 0:
				var route_rank := _route_chain_rank(_card_data_from_item(target))
				if route_rank > 0:
					if _count_attached_energy_type(target, FIGHTING_ENERGY_TYPE) < 2:
						return maxf(score, 3600.0 + float(route_rank) * 400.0)
					return minf(score, 300.0)
				return minf(score, -1200.0)
			var rank := _chain_rank(_card_data_from_item(target))
			if rank >= 2:
				return maxf(score, 2600.0 + float(rank) * 350.0)
			if rank == 0 and _best_chain_slot(player) != null:
				return minf(score, 300.0)
		"use_ability":
			if _is_chain_stage2(_card_data_from_item(action.get("source_slot", null))):
				return maxf(score, 3000.0)
		"play_trainer":
			var trainer: Variant = action.get("card", null)
			if _matches_key(trainer, "Rare Candy") or _matches_key(trainer, "神奇糖果"):
				return maxf(score, 3900.0) if _has_live_rare_candy_route(player) else -1400.0
			if _deck_id == MAMOSWINE_BLAZIKEN_DECK_ID \
					and (_matches_key(trainer, "Arven") or _matches_key(trainer, "派帕")) \
					and _stage2_setup_debt(player) > 0 \
					and _has_complete_stage2_route_search_target(action, player):
				return maxf(score, 3900.0)
		"attach_tool":
			var tool: Variant = action.get("card", null)
			if _matches_key(tool, "Technical Machine: Evolution") or _matches_key(tool, "招式学习器 进化"):
				var target: PokemonSlot = action.get("target_slot", null)
				if _deck_id == MAMOSWINE_BLAZIKEN_DECK_ID:
					if _tm_evolution_attach_executable(target, player, game_state):
						return maxf(score, 3200.0)
					return minf(score, TM_EVOLUTION_HARD_REJECT_SCORE)
				if target == player.active_pokemon and _has_live_tm_route(player):
					return maxf(score, 3200.0)
				return minf(score, -700.0)
		"granted_attack":
			if _is_tm_evolution_attack(action):
				if _deck_id == MAMOSWINE_BLAZIKEN_DECK_ID:
					if _tm_evolution_attack_executable(action, player, game_state):
						return maxf(score, 4200.0)
					return minf(score, TM_EVOLUTION_HARD_REJECT_SCORE)
				if _has_live_tm_route(player):
					return maxf(score, 4200.0)
		"end_turn":
			if _stage2_setup_debt(player) > 0:
				return minf(score, -1800.0)
	return score


func _mamoswine_retreat_bridge_is_live(action: Dictionary, player: PlayerState) -> bool:
	if _deck_id != MAMOSWINE_BLAZIKEN_DECK_ID or player == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	var target: PokemonSlot = action.get("target_slot", null)
	var source: Variant = action.get("card", null)
	if active == null or target == null or target != active:
		return false
	if _same_identity(active.get_card_data(), _mamoswine_stage2_card()):
		return false
	var source_data := _card_data_from_item(source)
	if source_data == null or not source_data.is_energy():
		return false
	var retreat_cost := active.get_retreat_cost()
	if retreat_cost <= 0 or active.attached_energy.size() >= retreat_cost:
		return false
	if active.attached_energy.size() + 1 < retreat_cost:
		return false
	for bench_slot: PokemonSlot in player.bench:
		if not _same_identity(bench_slot.get_card_data(), _mamoswine_stage2_card()):
			continue
		var fighting_count := 0
		for energy: CardInstance in bench_slot.attached_energy:
			if _provides_energy_type(energy, FIGHTING_ENERGY_TYPE):
				fighting_count += 1
		if fighting_count >= 2 and bool(predict_attacker_damage(bench_slot).get("can_attack", false)):
			return true
	return false


func get_discard_priority(card: CardInstance) -> int:
	var data := _card_data_from_item(card)
	if _is_chain_stage2(data):
		return 5
	if _is_chain_stage1(data):
		return 8
	if _is_chain_seed(data):
		return 12
	if _matches_key(card, "Rare Candy") or _matches_key(card, "神奇糖果"):
		return 10
	if _matches_key(card, "Technical Machine: Evolution") or _matches_key(card, "招式学习器 进化"):
		return 18
	return super.get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	var data := _card_data_from_item(card)
	if _is_chain_stage2(data):
		return 820
	if _is_chain_stage1(data):
		return 880
	if _is_chain_seed(data):
		return 760
	return super.get_search_priority(card)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if _deck_id != MAMOSWINE_BLAZIKEN_DECK_ID:
		return []
	var step_id := str(step.get("id", "")).to_lower()
	if step_id in ["buddy_poffin_pokemon", "csv9c186_basic_pokemon"]:
		return _pick_stage2_seed_coverage(items, step, context)
	if step_id == "search_energy":
		var player := _player_from_context(context)
		if _has_live_blaziken_route(player) and not _has_secured_energy_type(player, FIRE_ENERGY_TYPE):
			return _pick_fighting_then_fire(items, step)
		return _pick_stable_items(items, step)
	return []


func _pick_fighting_then_fire(items: Array, step: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 1)))
	if max_select <= 0:
		return []
	var selected: Array = []
	for energy_type: String in [FIGHTING_ENERGY_TYPE, FIRE_ENERGY_TYPE]:
		for item: Variant in items:
			if item in selected or not _provides_energy_type(item, energy_type):
				continue
			selected.append(item)
			break
		if selected.size() >= max_select:
			return selected
	for item: Variant in items:
		if item in selected:
			continue
		selected.append(item)
		if selected.size() >= max_select:
			break
	return selected


func _pick_stable_items(items: Array, step: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 1)))
	var selected: Array = []
	for item: Variant in items:
		if selected.size() >= max_select:
			break
		selected.append(item)
	return selected


func _pick_stage2_seed_coverage(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 1)))
	if max_select <= 0:
		return []
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		if item is CardInstance and (item as CardInstance).card_data != null:
			ranked.append({
				"item": item,
				"score": score_interaction_target(item, step, context),
				"order": index,
			})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", 0.0))
		var right_score := float(right.get("score", 0.0))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)

	var player := _player_from_context(context)
	var selected: Array = []
	for entry: Dictionary in ranked:
		var candidate := entry.get("item") as CardInstance
		var data := candidate.card_data
		if not _is_chain_seed(data) \
				or _has_same_identity_on_field(player, data) \
				or _selection_has_identity(selected, data):
			continue
		selected.append(candidate)
		if selected.size() >= max_select:
			return selected

	for entry: Dictionary in ranked:
		var candidate := entry.get("item") as CardInstance
		if candidate in selected:
			continue
		selected.append(candidate)
		if selected.size() >= max_select:
			break
	return selected


func _selection_has_identity(selected: Array, data: CardData) -> bool:
	for item: Variant in selected:
		if item is CardInstance and _same_identity((item as CardInstance).card_data, data):
			return true
	return false


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if item is CardInstance:
		var card := item as CardInstance
		var data := card.card_data
		if step_id.contains("discard"):
			return float(get_discard_priority(card))
		if _is_chain_stage2(data):
			if _has_matching_stage1_on_field(player, data):
				return 4700.0
			if _has_rare_candy_in_hand(player) and _has_matching_seed_on_field(player, data):
				return 4400.0
			return 650.0
		if _is_chain_stage1(data):
			return 4500.0 if _has_matching_parent_on_field(player, data) else 900.0
		if _is_chain_seed(data):
			return 3100.0 if not _has_same_identity_on_field(player, data) else 700.0
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		var boiling_spirit_score: Variant = _boiling_spirit_target_score(slot, step_id, player, context)
		if boiling_spirit_score != null:
			return float(boiling_spirit_score)
		var rank := _chain_rank(slot.get_card_data())
		if step_id.contains("attach") or step_id.contains("energy") or step_id.contains("assign"):
			if rank >= 3:
				return 4600.0
			if rank == 2:
				return 3200.0
			if rank == 1:
				return 2100.0
			return 250.0
		if step_id.contains("evolution_bench"):
			return 3600.0 if rank == 1 else 400.0
		if step_id.contains("target_pokemon"):
			return 3900.0 if _seed_has_stage2_path(slot.get_card_data()) else 300.0
	return super.score_interaction_target(item, step, context)


func _boiling_spirit_target_score(
	slot: PokemonSlot,
	step_id: String,
	player: PlayerState,
	context: Dictionary
) -> Variant:
	if _deck_id != MAMOSWINE_BLAZIKEN_DECK_ID \
			or step_id != "attach_basic_energy_from_discard" \
			or player == null \
			or _stage2_setup_debt(player) <= 0:
		return null
	var source: Variant = context.get("source_card", null)
	if not source is CardInstance or (source as CardInstance).card_data == null:
		return null
	var target_data := slot.get_card_data() if slot != null else null
	var mamoswine := _mamoswine_stage2_card()
	var blaziken := _blaziken_stage2_card()
	if _provides_energy_type(source, FIGHTING_ENERGY_TYPE):
		if _same_identity(target_data, mamoswine) and not _stage2_route_online(slot):
			return 6200.0
		return null
	if _provides_energy_type(source, FIRE_ENERGY_TYPE):
		if _same_identity(target_data, mamoswine):
			return -INF
		if _same_identity(target_data, blaziken):
			return 6200.0
	return null


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		var rank := _chain_rank(slot.get_card_data())
		if rank >= 3:
			var prediction := predict_attacker_damage(slot)
			return 4400.0 if bool(prediction.get("can_attack", false)) else 2400.0
	return super.score_handoff_target(item, step, context)


func _has_stage2_child(middle: CardData) -> bool:
	for stage2: CardData in _stage2_cards:
		if stage2.evolves_from_matches(middle):
			return true
	return false


func _is_chain_seed(data: CardData) -> bool:
	return _array_has_identity(_chain_seeds, data)


func _is_chain_stage1(data: CardData) -> bool:
	return _array_has_identity(_stage1_cards, data) and _has_stage2_child(data)


func _is_chain_stage2(data: CardData) -> bool:
	return _array_has_identity(_stage2_cards, data)


func _array_has_identity(cards: Array[CardData], target: CardData) -> bool:
	if target == null:
		return false
	for card: CardData in cards:
		if card == target or card.get_uid() == target.get_uid():
			return true
		for name: String in target.rule_identity_names():
			if card.matches_rule_identity_name(name):
				return true
	return false


func _chain_rank(data: CardData) -> int:
	if _is_chain_stage2(data):
		return 3
	if _is_chain_stage1(data):
		return 2
	if _is_chain_seed(data):
		return 1
	return 0


func _best_chain_slot(player: PlayerState) -> PokemonSlot:
	var best: PokemonSlot = null
	var best_rank := 0
	for slot: PokemonSlot in _all_slots(player):
		var rank := _route_chain_rank(slot.get_card_data())
		if rank > best_rank:
			best = slot
			best_rank = rank
	return best


func _route_chain_rank(data: CardData) -> int:
	if _deck_id != MAMOSWINE_BLAZIKEN_DECK_ID:
		return _chain_rank(data)
	var mamoswine := _mamoswine_stage2_card()
	if mamoswine == null or data == null:
		return 0
	if _same_identity(mamoswine, data):
		return 3
	if str(data.stage).to_lower() == "stage 1" and mamoswine.evolves_from_matches(data):
		return 2
	if data.is_basic_pokemon() and _stage2_matches_seed(mamoswine, data):
		return 1
	return 0


func _mamoswine_stage2_card() -> CardData:
	for card: CardData in _stage2_cards:
		if card.get_uid() == MAMOSWINE_EX_UID:
			return card
	return null


func _blaziken_stage2_card() -> CardData:
	for card: CardData in _stage2_cards:
		if card.get_uid() == BLAZIKEN_EX_UID:
			return card
	return null


func _has_live_blaziken_route(player: PlayerState) -> bool:
	if player == null:
		return false
	var blaziken := _blaziken_stage2_card()
	if blaziken == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		var data := slot.get_card_data()
		if _same_identity(blaziken, data) \
				or blaziken.evolves_from_matches(data) \
				or (data != null and data.is_basic_pokemon() and _stage2_matches_seed(blaziken, data)):
			return true
	return false


func _has_secured_energy_type(player: PlayerState, energy_type: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _provides_energy_type(card, energy_type):
			return true
	for slot: PokemonSlot in _all_slots(player):
		for energy: CardInstance in slot.attached_energy:
			if _provides_energy_type(energy, energy_type):
				return true
	return false


func _provides_energy_type(item: Variant, energy_type: String) -> bool:
	var data := _card_data_from_item(item)
	return data != null and data.is_energy() and str(data.energy_provides).contains(energy_type)


func _count_attached_energy_type(slot: PokemonSlot, energy_type: String) -> int:
	if slot == null:
		return 0
	var count := 0
	for energy: CardInstance in slot.attached_energy:
		if _provides_energy_type(energy, energy_type):
			count += 1
	return count


func _stage2_route_online(slot: PokemonSlot) -> bool:
	if _deck_id != MAMOSWINE_BLAZIKEN_DECK_ID:
		return true
	if slot == null or _route_chain_rank(slot.get_card_data()) != 3:
		return false
	var fighting_energy := 0
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == "F":
			fighting_energy += 1
	return fighting_energy >= 2


func _has_matching_parent_on_field(player: PlayerState, evolution: CardData) -> bool:
	if player == null or evolution == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if evolution.evolves_from_matches(slot.get_card_data()):
			return true
	return false


func _has_matching_stage1_on_field(player: PlayerState, stage2: CardData) -> bool:
	return _has_matching_parent_on_field(player, stage2)


func _has_matching_seed_on_field(player: PlayerState, stage2: CardData) -> bool:
	if player == null or stage2 == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _stage2_matches_seed(stage2, slot.get_card_data()):
			return true
	return false


func _stage2_matches_seed(stage2: CardData, seed: CardData) -> bool:
	for middle: CardData in _stage1_cards:
		if stage2.evolves_from_matches(middle) and middle.evolves_from_matches(seed):
			return true
	return false


func _seed_has_stage2_path(seed: CardData) -> bool:
	for stage2: CardData in _stage2_cards:
		if _stage2_matches_seed(stage2, seed):
			return true
	return false


func _has_same_identity_on_field(player: PlayerState, data: CardData) -> bool:
	if player == null or data == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _same_identity(slot.get_card_data(), data):
			return true
	return false


func _same_identity(left: CardData, right: CardData) -> bool:
	if left == null or right == null:
		return false
	if left.get_uid() == right.get_uid():
		return true
	for name: String in right.rule_identity_names():
		if left.matches_rule_identity_name(name):
			return true
	return false


func _has_rare_candy_in_hand(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _matches_key(card, "Rare Candy") or _matches_key(card, "神奇糖果"):
			return true
	return false


func _has_live_rare_candy_route(player: PlayerState) -> bool:
	if player == null:
		return false
	for stage2: CardData in _stage2_cards:
		if _has_matching_seed_on_field(player, stage2):
			return true
	return false


func _has_stage2_route_search_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _matches_key(card, "Rare Candy") or _matches_key(card, "神奇糖果") \
				or _matches_key(card, "Technical Machine: Evolution") \
				or _matches_key(card, "招式学习器 进化") \
				or _matches_key(card, "Earthen Vessel") \
				or _matches_key(card, "大地容器"):
			return true
	return false


func _action_has_stage2_route_search_target(action: Dictionary) -> bool:
	var targets: Variant = action.get("targets", [])
	return _variant_has_stage2_route_item(targets) and _variant_has_stage2_route_tool(targets)


func _has_complete_stage2_route_search_target(action: Dictionary, player: PlayerState) -> bool:
	var targets: Variant = action.get("targets", [])
	if (targets is Array and not (targets as Array).is_empty()) \
			or (targets is Dictionary and not (targets as Dictionary).is_empty()):
		return _action_has_stage2_route_search_target(action)
	return _has_stage2_route_search_target(player)


func _variant_has_stage2_route_item(value: Variant) -> bool:
	if value is CardInstance or value is CardData:
		return _matches_key(value, "Rare Candy") or _matches_key(value, "神奇糖果") \
			or _matches_key(value, "Earthen Vessel") \
			or _matches_key(value, "大地容器")
	if value is Array:
		for item: Variant in value:
			if _variant_has_stage2_route_item(item):
				return true
		return false
	if value is Dictionary:
		for item: Variant in (value as Dictionary).values():
			if _variant_has_stage2_route_item(item):
				return true
	return false


func _variant_has_stage2_route_tool(value: Variant) -> bool:
	if value is CardInstance or value is CardData:
		return _matches_key(value, "Technical Machine: Evolution") \
			or _matches_key(value, "招式学习器 进化")
	if value is Array:
		for item: Variant in value:
			if _variant_has_stage2_route_tool(item):
				return true
		return false
	if value is Dictionary:
		for item: Variant in (value as Dictionary).values():
			if _variant_has_stage2_route_tool(item):
				return true
	return false


func _has_live_tm_route(player: PlayerState) -> bool:
	if player == null:
		return false
	for middle: CardData in _stage1_cards:
		if not _has_stage2_child(middle):
			continue
		if _has_matching_parent_on_field(player, middle):
			return true
	return false


func _has_live_tm_bench_route(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		for middle: CardData in _stage1_cards:
			if _has_stage2_child(middle) and middle.evolves_from_matches(slot.get_card_data()):
				return true
	return false


func _tm_evolution_attach_executable(
	target: PokemonSlot,
	player: PlayerState,
	game_state: GameState
) -> bool:
	return player != null \
		and target == player.active_pokemon \
		and not _stage2_tm_first_player_attack_locked(game_state, player) \
		and _has_live_tm_bench_route(player) \
		and _active_can_pay_tm_evolution_this_turn(player, game_state)


func _tm_evolution_attack_executable(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState
) -> bool:
	if player == null or _stage2_tm_first_player_attack_locked(game_state, player) or not _has_live_tm_bench_route(player):
		return false
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	return source == player.active_pokemon \
		and _slot_has_tm_evolution(source) \
		and not source.attached_energy.is_empty()


func _active_can_pay_tm_evolution_this_turn(player: PlayerState, game_state: GameState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not player.active_pokemon.attached_energy.is_empty():
		return true
	if game_state == null or game_state.energy_attached_this_turn:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _stage2_tm_first_player_attack_locked(game_state: GameState, player: PlayerState) -> bool:
	return game_state != null \
		and player != null \
		and int(game_state.turn_number) == 1 \
		and int(game_state.first_player_index) == int(player.player_index)


func _slot_has_tm_evolution(slot: PokemonSlot) -> bool:
	return slot != null and (
		_matches_key(slot.attached_tool, "Technical Machine: Evolution") \
		or _matches_key(slot.attached_tool, "招式学习器 进化")
	)


func _is_tm_evolution_attack(action: Dictionary) -> bool:
	var attack: Dictionary = action.get("granted_attack_data", {}) if action.get("granted_attack_data", {}) is Dictionary else {}
	var identity := "%s %s" % [str(attack.get("id", "")), str(attack.get("name", ""))]
	return identity.to_lower().contains("evolution") or identity.contains("进化")


func _stage2_setup_debt(player: PlayerState) -> int:
	if player == null:
		return 0
	var has_seed := false
	var has_stage2 := false
	for slot: PokemonSlot in _all_slots(player):
		var rank := _route_chain_rank(slot.get_card_data())
		has_seed = has_seed or rank >= 1
		if rank >= 3:
			has_stage2 = has_stage2 or (
				_stage2_route_online(slot)
				if _deck_id == MAMOSWINE_BLAZIKEN_DECK_ID
				else true
			)
	if has_stage2:
		return 0
	return 1 if has_seed else 2


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	var state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if state != null and player_index >= 0 and player_index < state.players.size():
		return state.players[player_index]
	return null


func _first_profile_name(key: String) -> String:
	var values := _profile_list(key)
	return values[0] if not values.is_empty() else ""
