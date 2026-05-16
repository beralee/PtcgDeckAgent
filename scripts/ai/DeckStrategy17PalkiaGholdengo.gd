class_name DeckStrategy17PalkiaGholdengo
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"

const CSV9C_GIMMIGHOUL := "CSV9C_096"
const ENERGY_SEARCH_PRO := "Energy Search Pro"
const CSV9C_ENERGY_SEARCH_PRO := "CSV9C_176"
const GHOLDENGO_EX := "Gholdengo ex"
const GIMMIGHOUL := "Gimmighoul"
const PALKIA_V := "Origin Forme Palkia V"
const PALKIA_VSTAR := "Origin Forme Palkia VSTAR"
const MANAPHY := "Manaphy"
const RADIANT_GRENINJA := "Radiant Greninja"
const FEZANDIPITI_EX := "Fezandipiti ex"
const IRON_BUNDLE := "Iron Bundle"

const SUPERIOR_ENERGY_RETRIEVAL := "Superior Energy Retrieval"
const ENERGY_RETRIEVAL := "Energy Retrieval"
const EARTHEN_VESSEL := "Earthen Vessel"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const NEST_BALL := "Nest Ball"
const ULTRA_BALL := "Ultra Ball"
const IRIDA := "Irida"
const CIPHERMANIACS_CODEBREAKING := "Ciphermaniac's Codebreaking"
const BOSS_ORDERS := "Boss's Orders"
const COUNTER_CATCHER := "Counter Catcher"
const SWITCH := "Switch"
const FULL_METAL_LAB := "Full Metal Lab"
const CANCELING_COLOGNE := "Canceling Cologne"

const WATER_ENERGY := "W"
const METAL_ENERGY := "M"


func _profile() -> Dictionary:
	return {
		"strategy_id": "v17_palkia_gholdengo",
		"signatures": [GHOLDENGO_EX, CSV9C_GIMMIGHOUL, GIMMIGHOUL, PALKIA_VSTAR, PALKIA_V, CSV9C_ENERGY_SEARCH_PRO],
		"active_priority": [GIMMIGHOUL, CSV9C_GIMMIGHOUL, PALKIA_V, RADIANT_GRENINJA, MANAPHY, FEZANDIPITI_EX, IRON_BUNDLE],
		"bench_priority": [CSV9C_GIMMIGHOUL, GIMMIGHOUL, PALKIA_V, RADIANT_GRENINJA, FEZANDIPITI_EX, MANAPHY, IRON_BUNDLE],
		"search_priority": [GHOLDENGO_EX, CSV9C_GIMMIGHOUL, GIMMIGHOUL, PALKIA_VSTAR, PALKIA_V, CSV9C_ENERGY_SEARCH_PRO, ENERGY_SEARCH_PRO, SUPERIOR_ENERGY_RETRIEVAL, EARTHEN_VESSEL],
		"evolution_priority": [GHOLDENGO_EX, PALKIA_VSTAR],
		"energy_priority": [GHOLDENGO_EX, PALKIA_VSTAR, PALKIA_V, CSV9C_GIMMIGHOUL, GIMMIGHOUL, RADIANT_GRENINJA],
		"ability_priority": [GHOLDENGO_EX, CSV9C_GIMMIGHOUL, GIMMIGHOUL, RADIANT_GRENINJA, FEZANDIPITI_EX, IRON_BUNDLE],
	}


func get_strategy_id() -> String:
	return "v17_palkia_gholdengo"


func get_signature_names() -> Array[String]:
	return [
		GHOLDENGO_EX,
		GIMMIGHOUL,
		CSV9C_GIMMIGHOUL,
		PALKIA_VSTAR,
		PALKIA_V,
		CSV9C_ENERGY_SEARCH_PRO,
	]


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"time_budget_ms": 140,
		"rollouts_per_sequence": 0,
	}


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var owner_name := GHOLDENGO_EX
	var bridge_name := GHOLDENGO_EX
	var pivot_name := GHOLDENGO_EX
	var thin_churn := false
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		var best_attacker := _best_palkia_gholdengo_attacker(player, game_state, player_index)
		if best_attacker != null:
			owner_name = _slot_name(best_attacker)
			bridge_name = owner_name
			pivot_name = owner_name
		elif _count_name_on_field(player, GIMMIGHOUL) > 0:
			owner_name = GIMMIGHOUL
			bridge_name = GHOLDENGO_EX
			pivot_name = GIMMIGHOUL
		elif _count_name_on_field(player, PALKIA_V) > 0:
			owner_name = PALKIA_V
			bridge_name = PALKIA_VSTAR
			pivot_name = PALKIA_V
		thin_churn = _deck_is_thin(player) and _has_live_attack_route(player, game_state, player_index)
	return {
		"id": "v17_palkia_gholdengo_rules",
		"intent": "build_gold_burst" if not thin_churn else "convert_without_churn",
		"phase": "convert" if thin_churn else "setup",
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": pivot_name,
		},
		"priorities": {
			"attach": [GHOLDENGO_EX, PALKIA_VSTAR, PALKIA_V, CSV9C_GIMMIGHOUL, GIMMIGHOUL],
			"handoff": [GHOLDENGO_EX, PALKIA_VSTAR, PALKIA_V, CSV9C_GIMMIGHOUL, GIMMIGHOUL],
			"search": [GHOLDENGO_EX, CSV9C_GIMMIGHOUL, GIMMIGHOUL, PALKIA_VSTAR, PALKIA_V, CSV9C_ENERGY_SEARCH_PRO],
		},
		"flags": {
			"thin_deck_churn_guard": thin_churn,
			"live_attack_route": thin_churn,
		},
		"constraints": {
			"forbid_engine_churn": thin_churn,
		},
	}


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var name := _slot_name(slot)
	if name == GHOLDENGO_EX:
		var can_attack := _has_attached_energy_type(slot, METAL_ENERGY)
		return {
			"damage": 50 * maxi(0, extra_context) if can_attack else 0,
			"can_attack": can_attack,
			"description": "Make It Rain",
		}
	if name == PALKIA_VSTAR:
		return {
			"damage": 220,
			"can_attack": slot.attached_energy.size() + extra_context >= 2,
			"description": "Subspace Swell",
		}
	return super.predict_attacker_damage(slot, extra_context)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	if _action_targets_knocked_out_slot(action):
		return -100000.0
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			var card: CardInstance = action.get("card", null)
			if _card_name(card) == GIMMIGHOUL and _count_name_on_field(player, GIMMIGHOUL) == 0:
				score = maxf(score, 620.0)
			elif _card_name(card) == GIMMIGHOUL:
				score = maxf(score, 360.0)
			elif _card_name(card) == PALKIA_V and _count_name_on_field(player, PALKIA_V) == 0:
				score = maxf(score, 520.0)
		"play_trainer":
			score = _score_palkia_gholdengo_trainer(action, game_state, player, player_index, score)
		"attach_energy":
			score = _score_palkia_gholdengo_attach(action, player, score)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _is_thin_deck_draw_ability(source, player):
				return -280.0
			if _slot_name(source) == GHOLDENGO_EX:
				score = maxf(score, 380.0 if player.hand.size() <= 5 else 260.0)
				if source == player.active_pokemon and _has_attached_energy_type(source, METAL_ENERGY) and not _deck_is_thin(player):
					score = maxf(score, 3200.0)
			elif _slot_name(source) == RADIANT_GRENINJA:
				score = maxf(score, 330.0 if _basic_energy_in_hand(player) > 0 else 80.0)
			elif _slot_name(source) == FEZANDIPITI_EX:
				score = maxf(score, 240.0)
		"attack", "granted_attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			if source == null:
				source = player.active_pokemon
			if _slot_name(source) == GHOLDENGO_EX:
				if not _has_attached_energy_type(source, METAL_ENERGY):
					return -1000.0
				score = _score_gholdengo_make_it_rain(action, player, game_state, player_index, score)
			elif _slot_name(source) == PALKIA_VSTAR:
				var damage := _predict_attack_with_board(source, game_state)
				score = maxf(score, 420.0 + float(damage) * 1.9)
				if damage >= _opponent_active_remaining_hp(game_state, player_index):
					score += 720.0
			elif _slot_name(source) == GIMMIGHOUL and _should_delay_gimmighoul_setup_attack(action, player):
				score = minf(score, 220.0)
		"retreat":
			score = _score_palkia_gholdengo_retreat(player, game_state, player_index, score)
	return score


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		max_select = 1
	if step_id.contains("discard_basic_energy"):
		return _pick_make_it_rain_energy(items, max_select, context)
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard_basic_energy"):
			if _is_basic_energy(card):
				return 940.0 + _energy_type_diversity_bonus(card)
			return 5.0
		if step_id == "discard_energy" or step_id.contains("discard_energy"):
			if _is_basic_energy(card):
				return 860.0 + _energy_type_diversity_bonus(card)
			return 5.0
		if step_id.contains("csv9c176") or step_id.contains("energy_search") or step_id.contains("search_energy"):
			if _is_basic_energy(card):
				return _score_energy_search_target(card, context)
			return 0.0
		if step_id.contains("discard"):
			if _is_basic_energy(card):
				return 45.0
			if _card_name(card) in [GHOLDENGO_EX, GIMMIGHOUL, PALKIA_V, PALKIA_VSTAR]:
				return 8.0
		if step_id.contains("search") or step_id.contains("item") or step_id.contains("basic_pokemon") or step_id.contains("buddy_poffin_pokemon"):
			var name := _card_name(card)
			var player := _player_from_context(context)
			if name == ENERGY_SEARCH_PRO:
				return 380.0
			if name == GHOLDENGO_EX:
				return 430.0 if _count_name_on_field(player, GIMMIGHOUL) > 0 and _count_name_on_field(player, GHOLDENGO_EX) == 0 else 360.0
			if name == GIMMIGHOUL:
				if _count_name_on_field(player, GIMMIGHOUL) == 0:
					return 410.0
				if _count_name_on_field(player, PALKIA_V) == 0:
					return 210.0
				return 330.0
			if name == PALKIA_VSTAR:
				return 360.0 if _count_name_on_field(player, PALKIA_V) > 0 and _count_name_on_field(player, PALKIA_VSTAR) == 0 else 240.0
			if name == PALKIA_V:
				return 330.0 if _count_name_on_field(player, GIMMIGHOUL) > 0 and _count_name_on_field(player, PALKIA_V) == 0 else 300.0
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if not _slot_is_live(slot):
			return -100000.0
		if step_id.contains("attach") or step_id.contains("assign") or step_id.contains("energy"):
			var name := _slot_name(slot)
			if name == GHOLDENGO_EX:
				return 980.0
			if name == GIMMIGHOUL:
				return 760.0
			if name == PALKIA_VSTAR or name == PALKIA_V:
				return 520.0
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		if not _slot_is_live(item as PokemonSlot):
			return -100000.0
		return _palkia_gholdengo_handoff_score(item as PokemonSlot, _player_from_context(context), context.get("game_state", null), int(context.get("player_index", -1)))
	return score_interaction_target(item, step, context)


func get_search_priority(card: CardInstance) -> int:
	var name := _card_name(card)
	if name == GHOLDENGO_EX:
		return 340
	if name == GIMMIGHOUL:
		return 330
	if name == PALKIA_VSTAR:
		return 315
	if name == PALKIA_V:
		return 300
	if name == ENERGY_SEARCH_PRO:
		return 290
	return super.get_search_priority(card)


func get_discard_priority(card: CardInstance) -> int:
	if _is_basic_energy(card):
		return 45
	if _card_name(card) in [GHOLDENGO_EX, GIMMIGHOUL, PALKIA_V, PALKIA_VSTAR]:
		return 8
	if _card_name(card) == ENERGY_SEARCH_PRO:
		return 20
	return super.get_discard_priority(card)


func _score_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	return _score_palkia_gholdengo_trainer(action, game_state, player, player_index, super._score_trainer_action(action))


func _score_item_search_target(card: CardInstance, context: Dictionary) -> float:
	if _card_name(card) == ENERGY_SEARCH_PRO:
		return 390.0
	if _card_name(card) == BUDDY_BUDDY_POFFIN:
		var player := _player_from_context(context)
		return 410.0 if _needs_poffin_basics(player) else 230.0
	if _card_name(card) == NEST_BALL:
		var player := _player_from_context(context)
		return 390.0 if _needs_opening_basics(player) else 220.0
	return float(super.get_search_priority(card))


func _predict_attack_with_board(slot: PokemonSlot, game_state: GameState) -> int:
	if slot == null:
		return 0
	if _slot_name(slot) == GHOLDENGO_EX:
		if not _has_attached_energy_type(slot, METAL_ENERGY):
			return 0
		var player_index := _find_owner_index(game_state, slot)
		if player_index >= 0:
			return _basic_energy_in_hand(game_state.players[player_index]) * 50
	if _slot_name(slot) == PALKIA_VSTAR:
		return 60 + _count_total_bench(game_state) * 20
	var prediction := super.predict_attacker_damage(slot)
	return int(prediction.get("damage", 0))


func _card_name(card: Variant) -> String:
	var cd := _card_data_from_variant(card)
	if cd == null:
		return ""
	return _canonical_v17_name(cd)


func _slot_name(slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	var cd := slot.get_card_data()
	if cd == null:
		return ""
	return _canonical_v17_name(cd)


func _canonical_v17_name(cd: CardData) -> String:
	var uid := _card_uid(cd)
	if uid == CSV9C_GIMMIGHOUL:
		return GIMMIGHOUL
	if uid == CSV9C_ENERGY_SEARCH_PRO:
		return ENERGY_SEARCH_PRO
	if str(cd.name_en) != "":
		return _canonical_known_name(str(cd.name_en))
	return _canonical_known_name(str(cd.name))


func _card_data_from_variant(item: Variant) -> CardData:
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	if item is CardData:
		return item as CardData
	return null


func _card_uid(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.set_code) != "" and str(cd.card_index) != "":
		return "%s_%s" % [str(cd.set_code), str(cd.card_index)]
	return str(cd.get_uid())


func _basic_energy_in_hand(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.hand:
		if _is_basic_energy(card):
			count += 1
	return count


func _count_energy_in_hand(player: PlayerState, energy_type: String) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.hand:
		if _is_basic_energy(card) and _energy_type(card) == energy_type:
			count += 1
	return count


func _score_energy_search_target(card: CardInstance, context: Dictionary) -> float:
	if not _is_basic_energy(card):
		return 0.0
	var energy_type := _energy_type(card)
	var player := _player_from_context(context)
	var fuel_score := 760.0 + _energy_type_diversity_bonus(card)
	if energy_type == METAL_ENERGY:
		if _needs_metal_energy_for_gholdengo_line(player):
			return 1160.0
		if _count_name_on_field(player, GHOLDENGO_EX) > 0 or _count_name_on_field(player, GIMMIGHOUL) > 0:
			return 1040.0
		return 940.0
	if energy_type == WATER_ENERGY:
		if _needs_water_energy_for_palkia_line(player):
			return 1080.0
		if _count_name_on_field(player, PALKIA_VSTAR) > 0 or _count_name_on_field(player, PALKIA_V) > 0:
			return 940.0
		return 880.0
	if _active_gholdengo_can_attack(player) or _count_name_on_field(player, GHOLDENGO_EX) > 0:
		return maxf(fuel_score, 830.0 + _energy_type_diversity_bonus(card))
	return fuel_score


func _needs_metal_energy_for_gholdengo_line(player: PlayerState) -> bool:
	if player == null or _count_energy_in_hand(player, METAL_ENERGY) > 0:
		return false
	for slot: PokemonSlot in _all_slots(player):
		var name := _slot_name(slot)
		if name in [GHOLDENGO_EX, GIMMIGHOUL] and not _has_attached_energy_type(slot, METAL_ENERGY):
			return true
	return false


func _needs_water_energy_for_palkia_line(player: PlayerState) -> bool:
	if player == null or _count_energy_in_hand(player, WATER_ENERGY) > 0:
		return false
	for slot: PokemonSlot in _all_slots(player):
		var name := _slot_name(slot)
		if name in [PALKIA_VSTAR, PALKIA_V] and slot.attached_energy.size() < 2:
			return true
	return false


func _score_palkia_gholdengo_trainer(
	action: Dictionary,
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	base_score: float
) -> float:
	var card: CardInstance = action.get("card", null)
	var name := _card_name(card)
	var score := base_score
	if name == ENERGY_SEARCH_PRO:
		score = maxf(score, 470.0 if _basic_energy_in_hand(player) < 5 else 250.0)
	if name == BUDDY_BUDDY_POFFIN:
		if _needs_poffin_basics(player):
			score = maxf(score, 560.0)
		else:
			score = minf(maxf(score, 260.0), 300.0)
	if name == NEST_BALL:
		score = maxf(score, 540.0 if _needs_opening_basics(player) else 250.0)
	if name == ULTRA_BALL:
		score = maxf(score, 510.0 if _needs_evolution_piece(player) else 260.0)
	if name == IRIDA:
		score = maxf(score, 480.0 if _engine_setup_gap(player) > 0 else 240.0)
	if name == EARTHEN_VESSEL:
		if _needs_opening_basics(player):
			score = minf(score, 300.0)
		elif _basic_energy_in_hand(player) < 3:
			score = maxf(score, 360.0)
	if name == SUPERIOR_ENERGY_RETRIEVAL:
		score = maxf(score, 430.0 if _discard_basic_energy_count(player) >= 2 else 180.0)
		score = _score_make_it_rain_recovery_trainer(name, player, game_state, player_index, score)
	if name == ENERGY_RETRIEVAL:
		score = maxf(score, 320.0 if _discard_basic_energy_count(player) >= 1 else 120.0)
		score = _score_make_it_rain_recovery_trainer(name, player, game_state, player_index, score)
	if name == BOSS_ORDERS or name == COUNTER_CATCHER:
		score = maxf(score, 560.0 if _can_current_attacker_take_ko(game_state, player_index) else 120.0)
	if name == SWITCH:
		score = maxf(score, 300.0 if _has_ready_bench_attacker(player, game_state, player_index) else 80.0)
	if name == FULL_METAL_LAB:
		score = maxf(score, 260.0 if _count_name_on_field(player, GHOLDENGO_EX) > 0 else 80.0)
	if name == CANCELING_COLOGNE:
		score = minf(score, 120.0)
	if _deck_is_thin(player) and _has_live_attack_route(player, game_state, player_index):
		if name in [CIPHERMANIACS_CODEBREAKING]:
			score = minf(score, 40.0)
		if name in [BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL, EARTHEN_VESSEL] and not _needs_evolution_piece(player):
			score = minf(score, 90.0)
	if _deck_is_critical(player):
		if name == CIPHERMANIACS_CODEBREAKING:
			score = minf(score, 40.0)
		if name in [BOSS_ORDERS, COUNTER_CATCHER] and not _can_current_attacker_take_ko(game_state, player_index):
			score = minf(score, 70.0)
	return score


func _score_palkia_gholdengo_attach(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var target: PokemonSlot = action.get("target_slot", null)
	var energy: CardInstance = action.get("card", null)
	if player == null or target == null or energy == null or not _is_basic_energy(energy):
		return base_score
	if not _slot_is_live(target):
		return -100000.0
	var score := base_score
	var target_name := _slot_name(target)
	var energy_type := _energy_type(energy)
	if target_name in [GHOLDENGO_EX, GIMMIGHOUL]:
		if energy_type == METAL_ENERGY and not _has_attached_energy_type(target, METAL_ENERGY):
			score = maxf(score, 980.0 if target_name == GHOLDENGO_EX else 760.0)
		elif energy_type != METAL_ENERGY and not _has_attached_energy_type(target, METAL_ENERGY):
			score = minf(score, 180.0 if target_name == GIMMIGHOUL and target.attached_energy.is_empty() else 90.0)
		elif _has_attached_energy_type(target, METAL_ENERGY):
			score = minf(score, 140.0)
	if target_name in [PALKIA_VSTAR, PALKIA_V]:
		if energy_type == WATER_ENERGY and target.attached_energy.size() < 2:
			score = maxf(score, 820.0 if target_name == PALKIA_VSTAR else 760.0)
		elif energy_type != WATER_ENERGY:
			score = minf(score, 90.0)
	if target_name in [MANAPHY, RADIANT_GRENINJA, FEZANDIPITI_EX, IRON_BUNDLE] and target != player.active_pokemon:
		score = minf(score, 80.0)
	if target == player.active_pokemon and _active_support_is_blocking(player):
		if _active_needs_retreat_energy(player) and _has_bench_pivot_ready_after_retreat(player):
			score = maxf(score, 930.0)
		elif _needs_opening_basics(player):
			score = minf(score, 220.0)
	if target != player.active_pokemon and _active_support_is_blocking(player) and _active_needs_retreat_energy(player) and _has_bench_pivot_ready_after_retreat(player):
		score = minf(score, 760.0)
	return score


func _score_gholdengo_make_it_rain(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var hand_energy := _basic_energy_in_hand(player)
	var burst_damage := hand_energy * 50
	var score := maxf(base_score, 520.0 + float(burst_damage) * 2.8)
	var remaining_hp := _opponent_active_remaining_hp(game_state, player_index)
	if burst_damage >= remaining_hp:
		return score + 820.0
	if _best_energy_recovery_gain_from_hand(player) > 0:
		var projected_after_recovery := (hand_energy + _best_energy_recovery_gain_from_hand(player)) * 50
		if projected_after_recovery > burst_damage:
			if burst_damage < 150:
				score = minf(score, 250.0 + float(burst_damage) * 1.2)
			else:
				score = minf(score, 380.0 + float(burst_damage))
	var projected_damage := int(action.get("projected_damage", 0))
	if hand_energy <= 1 and projected_damage <= 50 and _best_energy_recovery_gain_from_hand(player) > 0:
		score = minf(score, 300.0)
	return score


func _score_make_it_rain_recovery_trainer(
	name: String,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	if not _active_gholdengo_can_attack(player):
		return base_score
	var recover_count := mini(_recovery_limit_for_trainer(name), _discard_basic_energy_count(player))
	if recover_count <= 0:
		return base_score
	var total_damage_after_recovery := (_basic_energy_in_hand(player) + recover_count) * 50
	var score := base_score
	if total_damage_after_recovery >= _opponent_active_remaining_hp(game_state, player_index):
		score = maxf(score, 1120.0 if name == SUPERIOR_ENERGY_RETRIEVAL else 980.0)
	elif total_damage_after_recovery >= 150:
		score = maxf(score, 900.0 if name == SUPERIOR_ENERGY_RETRIEVAL else 760.0)
	else:
		score = maxf(score, 560.0)
	return score


func _score_palkia_gholdengo_retreat(player: PlayerState, game_state: GameState, player_index: int, base_score: float) -> float:
	if player == null or player.active_pokemon == null:
		return base_score
	if _active_support_is_blocking(player) and _best_palkia_gholdengo_attacker(player, game_state, player_index) != null:
		return maxf(base_score, 980.0)
	if _slot_name(player.active_pokemon) in [GHOLDENGO_EX, PALKIA_VSTAR] and _has_live_attack_route(player, game_state, player_index):
		return minf(base_score, 30.0)
	return base_score


func _pick_make_it_rain_energy(items: Array, max_select: int, context: Dictionary) -> Array:
	var energies: Array = []
	for item: Variant in items:
		if item is CardInstance and _is_basic_energy(item as CardInstance):
			energies.append(item)
	if energies.is_empty():
		return []
	energies.sort_custom(func(a: Variant, b: Variant) -> bool:
		return score_interaction_target(a, {"id": "discard_basic_energy"}, context) > score_interaction_target(b, {"id": "discard_basic_energy"}, context)
	)
	var need_count := mini(max_select, energies.size())
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var remaining_hp := _opponent_active_remaining_hp(game_state, player_index)
	if remaining_hp > 0 and remaining_hp < 999:
		need_count = mini(need_count, maxi(1, int(ceil(float(remaining_hp) / 50.0))))
	return energies.slice(0, need_count)


func _needs_opening_basics(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_name_on_field(player, GIMMIGHOUL) == 0 or _count_name_on_field(player, PALKIA_V) == 0


func _needs_poffin_basics(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_name_on_field(player, GIMMIGHOUL) < 2


func _needs_evolution_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	return (_count_name_on_field(player, GIMMIGHOUL) > 0 and _count_name_on_field(player, GHOLDENGO_EX) == 0) or (_count_name_on_field(player, PALKIA_V) > 0 and _count_name_on_field(player, PALKIA_VSTAR) == 0)


func _engine_setup_gap(player: PlayerState) -> int:
	if player == null:
		return 0
	var gap := 0
	if _count_name_on_field(player, GHOLDENGO_EX) == 0:
		gap += 1
	if _count_name_on_field(player, PALKIA_VSTAR) == 0:
		gap += 1
	if _count_name_on_field(player, GIMMIGHOUL) == 0:
		gap += 1
	return gap


func _discard_basic_energy_count(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.discard_pile:
		if _is_basic_energy(card):
			count += 1
	return count


func _active_gholdengo_can_attack(player: PlayerState) -> bool:
	return player != null and _slot_name(player.active_pokemon) == GHOLDENGO_EX and _has_attached_energy_type(player.active_pokemon, METAL_ENERGY)


func _recovery_limit_for_trainer(name: String) -> int:
	if name == SUPERIOR_ENERGY_RETRIEVAL:
		return 4
	if name == ENERGY_RETRIEVAL:
		return 2
	return 0


func _best_energy_recovery_gain_from_hand(player: PlayerState) -> int:
	if player == null:
		return 0
	var recoverable := _discard_basic_energy_count(player)
	var best := 0
	for card: CardInstance in player.hand:
		best = maxi(best, mini(_recovery_limit_for_trainer(_card_name(card)), recoverable))
	return best


func _is_thin_deck_draw_ability(source: PokemonSlot, player: PlayerState) -> bool:
	if player == null or source == null:
		return false
	if not _deck_is_thin(player):
		return false
	var name := _slot_name(source)
	return name == GHOLDENGO_EX or name == RADIANT_GRENINJA or name == FEZANDIPITI_EX


func _active_support_is_blocking(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active_name := _slot_name(player.active_pokemon)
	return active_name in [MANAPHY, RADIANT_GRENINJA, FEZANDIPITI_EX, IRON_BUNDLE, GIMMIGHOUL]


func _active_needs_retreat_energy(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	return player.active_pokemon.attached_energy.size() < player.active_pokemon.get_retreat_cost()


func _has_bench_pivot_ready_after_retreat(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if not _slot_is_live(slot):
			continue
		var name := _slot_name(slot)
		if name == GHOLDENGO_EX and _has_attached_energy_type(slot, METAL_ENERGY):
			return true
		if name == PALKIA_VSTAR and slot.attached_energy.size() >= 2:
			return true
	return false


func _deck_is_thin(player: PlayerState) -> bool:
	return player != null and player.deck.size() <= 8


func _deck_is_critical(player: PlayerState) -> bool:
	return player != null and player.deck.size() <= 3


func _should_delay_gimmighoul_setup_attack(action: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	if int(action.get("projected_damage", 0)) > 0 or bool(action.get("projected_knockout", false)):
		return false
	var attack_index := int(action.get("attack_index", 0))
	if attack_index > 0 and not bool(action.get("requires_interaction", false)):
		return false
	return player.bench.size() <= 1 or _needs_opening_basics(player)


func _has_live_attack_route(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if not _slot_is_live(slot):
			continue
		if _slot_name(slot) == GHOLDENGO_EX and _has_attached_energy_type(slot, METAL_ENERGY) and _basic_energy_in_hand(player) >= 2:
			return true
		var prediction := predict_attacker_damage(slot)
		if bool(prediction.get("can_attack", false)) and int(prediction.get("damage", 0)) >= _opponent_active_remaining_hp(game_state, player_index):
			return true
	return false


func _has_ready_bench_attacker(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if not _slot_is_live(slot):
			continue
		if _slot_name(slot) == GHOLDENGO_EX and _has_attached_energy_type(slot, METAL_ENERGY) and _basic_energy_in_hand(player) >= 2:
			return true
		var prediction := predict_attacker_damage(slot)
		if bool(prediction.get("can_attack", false)) and int(prediction.get("damage", 0)) >= _opponent_active_remaining_hp(game_state, player_index):
			return true
	return false


func _best_palkia_gholdengo_attacker(player: PlayerState, game_state: GameState, player_index: int) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := 0.0
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if not _slot_is_live(slot):
			continue
		var score := 0.0
		if _slot_name(slot) == GHOLDENGO_EX and _has_attached_energy_type(slot, METAL_ENERGY):
			score = 420.0 + float(_basic_energy_in_hand(player) * 50)
		else:
			var prediction := predict_attacker_damage(slot)
			if bool(prediction.get("can_attack", false)):
				score = float(int(prediction.get("damage", 0)))
		if score >= float(_opponent_active_remaining_hp(game_state, player_index)):
			score += 300.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _palkia_gholdengo_handoff_score(slot: PokemonSlot, player: PlayerState, game_state: GameState, player_index: int) -> float:
	if not _slot_is_live(slot):
		return -100000.0
	var name := _slot_name(slot)
	if name == GHOLDENGO_EX:
		var score := 760.0 + float(slot.attached_energy.size()) * 90.0 + float(_basic_energy_in_hand(player)) * 35.0
		if _has_attached_energy_type(slot, METAL_ENERGY):
			score += 260.0
		if _basic_energy_in_hand(player) * 50 >= _opponent_active_remaining_hp(game_state, player_index):
			score += 520.0
		return score
	if name == PALKIA_VSTAR:
		var damage := _predict_attack_with_board(slot, game_state)
		var score := 620.0 + float(damage) * 0.9
		if slot.attached_energy.size() >= 2:
			score += 240.0
		if damage >= _opponent_active_remaining_hp(game_state, player_index):
			score += 420.0
		return score
	if name == PALKIA_V:
		return 360.0 + float(slot.attached_energy.size()) * 60.0
	if name == GIMMIGHOUL:
		return 220.0 + float(slot.attached_energy.size()) * 40.0
	if name in [MANAPHY, RADIANT_GRENINJA, FEZANDIPITI_EX, IRON_BUNDLE]:
		return 55.0
	return super.score_handoff_target(slot, {"id": "handoff"}, {"game_state": game_state, "player_index": player_index})


func _can_current_attacker_take_ko(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player.active_pokemon == null:
		return false
	return _predict_attack_with_board(player.active_pokemon, game_state) >= _opponent_active_remaining_hp(game_state, player_index)


func _count_name_on_field(player: PlayerState, target_name: String) -> int:
	var count := 0
	if player == null:
		return count
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and _slot_name(slot) == target_name:
			count += 1
	return count


func _count_total_bench(game_state: GameState) -> int:
	var total := 0
	if game_state == null:
		return total
	for player: PlayerState in game_state.players:
		total += player.bench.size()
	return total


func _find_owner_index(game_state: GameState, target_slot: PokemonSlot) -> int:
	if game_state == null or target_slot == null:
		return -1
	for i: int in game_state.players.size():
		var player: PlayerState = game_state.players[i]
		if player.active_pokemon == target_slot:
			return i
		for slot: PokemonSlot in player.bench:
			if slot == target_slot:
				return i
	return -1


func _action_targets_knocked_out_slot(action: Dictionary) -> bool:
	for key: String in ["target_slot", "bench_target", "source_slot"]:
		var value: Variant = action.get(key, null)
		if value is PokemonSlot and not _slot_is_live(value as PokemonSlot):
			return true
	return false


func _slot_is_live(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_top_card() != null and slot.get_remaining_hp() > 0


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy"


func _energy_type(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if str(card.card_data.energy_provides) != "":
		return str(card.card_data.energy_provides)
	return str(card.card_data.energy_type)


func _has_attached_energy_type(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _energy_type(energy) == energy_type:
			return true
	return false


func _energy_type_diversity_bonus(card: CardInstance) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var energy_type := str(card.card_data.energy_provides if card.card_data.energy_provides != "" else card.card_data.energy_type)
	return float(abs(energy_type.hash() % 37))


func _opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	if game_state == null:
		return 999
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 999
	var active := game_state.players[opponent_index].active_pokemon
	if active == null:
		return 999
	return active.get_remaining_hp()


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.has("player") and context["player"] is PlayerState:
		return context["player"] as PlayerState
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		return game_state.players[player_index]
	return null


func _canonical_known_name(name: String) -> String:
	match name:
		GHOLDENGO_EX:
			return GHOLDENGO_EX
		GIMMIGHOUL:
			return GIMMIGHOUL
		PALKIA_V:
			return PALKIA_V
		PALKIA_VSTAR:
			return PALKIA_VSTAR
		MANAPHY:
			return MANAPHY
		RADIANT_GRENINJA:
			return RADIANT_GRENINJA
		FEZANDIPITI_EX:
			return FEZANDIPITI_EX
		IRON_BUNDLE:
			return IRON_BUNDLE
		ENERGY_SEARCH_PRO:
			return ENERGY_SEARCH_PRO
		_:
			return name
