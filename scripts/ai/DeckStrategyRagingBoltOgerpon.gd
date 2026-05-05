class_name DeckStrategyRagingBoltOgerpon
extends "res://scripts/ai/LLMDeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const RAGING_BOLT_EX: Array[String] = ["Raging Bolt ex", "猛雷鼓ex"]
const TEAL_MASK_OGERPON_EX: Array[String] = ["Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex"]
const SLITHER_WING: Array[String] = ["Slither Wing", "爬地翅"]
const IRON_BUNDLE: Array[String] = ["Iron Bundle", "铁包袱"]
const SQUAWKABILLY_EX: Array[String] = ["Squawkabilly ex", "怒鹦哥ex"]

const SADA: Array[String] = ["Professor Sada's Vitality", "奥琳博士的气魄"]
const EARTHEN_VESSEL: Array[String] = ["Earthen Vessel", "大地容器"]
const ENERGY_RETRIEVAL: Array[String] = ["Energy Retrieval", "能量回收"]
const NEST_BALL: Array[String] = ["Nest Ball", "巢穴球"]
const BRAVERY_CHARM: Array[String] = ["Bravery Charm", "勇气护符"]
const SWITCH_CART: Array[String] = ["Switch Cart", "交替推车"]
const PROFESSORS_RESEARCH: Array[String] = ["Professor's Research", "博士的研究"]
const MAGMA_BASIN: Array[String] = ["Magma Basin", "熔岩瀑布之渊"]
const PHASE_LAUNCH := "launch"
const PHASE_PRESSURE := "pressure"
const PHASE_CONVERT := "convert"
const POKEGEAR_30: Array[String] = ["Pok\u00e9gear 3.0", "Pokegear 3.0", "宝可装置3.0"]
const RADIANT_GRENINJA: Array[String] = ["Radiant Greninja", "光辉甲贺忍蛙"]
const NIGHT_STRETCHER: Array[String] = ["Night Stretcher", "夜间担架", "夜晚担架"]
const TREKKING_SHOES: Array[String] = ["Trekking Shoes", "健行鞋"]
const HISUIAN_HEAVY_BALL: Array[String] = ["Hisuian Heavy Ball", "洗翠的沉重球"]
const POKEMON_CATCHER: Array[String] = ["Pok\u00e9mon Catcher", "Pokemon Catcher", "宝可梦捕捉器"]
const LOST_VACUUM: Array[String] = ["Lost Vacuum", "放逐吸尘器"]
const PAL_PAD: Array[String] = ["Pal Pad", "朋友手册"]
const IONO: Array[String] = ["Iono", "奇树"]
const BOSS_ORDERS: Array[String] = ["Boss's Orders", "Boss's Orders (Ghetsis)", "老大的指令"]
const PRIME_CATCHER: Array[String] = ["Prime Catcher", "顶尖捕捉器", "高级捕获器"]
const TEMPLE_OF_SINNOH: Array[String] = ["Temple of Sinnoh", "神奥神殿"]
const CONTINUITY_ENERGY_NAMES: Array[String] = ["Lightning Energy", "Fighting Energy", "Grass Energy"]
const CONTINUITY_ENERGY_TYPES: Array[String] = ["L", "F", "G"]

var _deck_strategy_text: String = ""


func get_strategy_id() -> String:
	return "raging_bolt_ogerpon"


func set_deck_strategy_text(strategy_text: String) -> void:
	_deck_strategy_text = strategy_text.strip_edges()


func get_deck_strategy_text() -> String:
	return _deck_strategy_text


func get_signature_names() -> Array[String]:
	return ["Raging Bolt ex", "Teal Mask Ogerpon ex", "Professor Sada's Vitality"]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"max_actions_per_turn": 8,
		"rollouts_per_sequence": 0,
		"time_budget_ms": 2400,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if not _is_basic_pokemon(card):
			continue
		basics.append({"index": i, "priority": _setup_priority(str(card.card_data.name))})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	for entry: Dictionary in basics:
		var index: int = int(entry.get("index", -1))
		if index == active_index:
			continue
		bench_indices.append(index)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var kind: String = str(action.get("kind", ""))
	var base_score: float = 0.0
	match kind:
		"play_basic_to_bench":
			base_score = _score_bench_basic(action.get("card"), game_state, player_index)
		"attach_energy":
			base_score = _score_attach_energy(action.get("card"), action.get("target_slot"), game_state, player_index)
		"attach_tool":
			base_score = _score_attach_tool(action.get("card"), action.get("target_slot"))
		"use_ability":
			base_score = _score_ability(action.get("source_slot"), game_state, player_index)
		"play_trainer":
			base_score = _score_trainer_action(action, game_state, player_index)
		"play_stadium":
			base_score = _score_trainer_action(action, game_state, player_index)
		"attack", "granted_attack":
			base_score = _score_attack(action, game_state, player_index)
		"retreat":
			base_score = _score_retreat(action.get("bench_target"), game_state, player_index)
	return base_score + _apply_turn_plan_bonus(kind, action, game_state, player_index, base_score)


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	return score_action_absolute(action, game_state, player_index) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.get_card_data() == null:
			continue
		if _slot_matches(slot, RAGING_BOLT_EX):
			score += 240.0
			score += float(slot.attached_energy.size()) * 85.0
			if _preferred_attack_energy_gap(slot) <= 1:
				score += 100.0
		elif _slot_matches(slot, TEAL_MASK_OGERPON_EX):
			score += 150.0
			score += float(slot.attached_energy.size()) * 35.0
		elif slot.get_card_data().is_ancient_pokemon():
			score += 60.0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			score += 12.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached: int = slot.attached_energy.size() + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		var attack_damage: int = _parse_damage_value(str(attack.get("damage", "0")))
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, attack_damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = str(card.card_data.name)
	if _matches_name(name, RAGING_BOLT_EX):
		return 5
	if card.card_data.card_type == "Basic Energy":
		return 220
	if _matches_name(name, SADA):
		return 10
	if _matches_name(name, EARTHEN_VESSEL) or _matches_name(name, ENERGY_RETRIEVAL):
		return 30
	return 90


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player: PlayerState = _get_player(game_state, player_index)
	if player == null or card == null or card.card_data == null:
		return get_discard_priority(card)
	if _find_energy_holder(player, card) != null:
		return int(_score_field_discard_candidate(card, player))
	return int(_score_hand_discard_candidate(card, player))


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _card_matches(card, RAGING_BOLT_EX):
		return 100
	if _card_matches(card, TEAL_MASK_OGERPON_EX):
		return 95
	if _card_matches(card, SLITHER_WING):
		return 70
	return 20


func estimate_bellowing_thunder_damage(discard_count: int) -> int:
	return maxi(0, discard_count) * 70


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id: String = str(step.get("id", ""))
	if step_id == "sada_assignments":
		return _pick_sada_energy_sources(items, context, int(step.get("max_select", 2)))
	if step_id not in ["discard_energy", "discard_card", "discard_cards", "discard_basic_energy"]:
		return []
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	if player == null or items.is_empty():
		return []
	var card_items: Array[CardInstance] = []
	for item: Variant in items:
		if item is CardInstance:
			card_items.append(item as CardInstance)
	if card_items.is_empty():
		return []
	for card: CardInstance in card_items:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			return []
	if _all_cards_attached_to_field(card_items, player):
		return _pick_field_discard_items(card_items, player, context, int(step.get("max_select", card_items.size())))
	return _pick_hand_discard_items(card_items, player, int(step.get("min_select", 0)), int(step.get("max_select", card_items.size())))


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "search_cards", "search_future_pokemon"]:
			return float(get_search_priority(card))
		if step_id == "look_top_cards":
			return _score_supporter_candidate(card, context)
		if step_id in ["discard_cards", "discard_card", "discard_energy", "discard_basic_energy"]:
			return float(get_discard_priority_contextual(card, context.get("game_state"), int(context.get("player_index", -1))))
		if step_id == "search_energy":
			return _score_energy_search_candidate(card, context)
		if step_id == "recover_energy":
			return _score_energy_recovery_candidate(card, context)
		return 40.0
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		return _score_assignment_target(slot, context)
	return 0.0


func _score_bench_basic(card: CardInstance, game_state: GameState = null, player_index: int = -1) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	if _matches_name(name, SQUAWKABILLY_EX):
		if game_state != null and game_state.turn_number > 2:
			return -50.0
		return float(_setup_priority(name) * 3)
	var base: float = float(_setup_priority(name) * 3)
	var player: PlayerState = _get_player(game_state, player_index)
	if player != null and _has_attack_ready_raging_bolt(player) and player.deck.size() > 8 and _current_phase(player) == PHASE_PRESSURE:
		if _matches_name(name, RAGING_BOLT_EX) and _count_pokemon_on_field(player, RAGING_BOLT_EX) < 2:
			return 900.0
		if _matches_name(name, TEAL_MASK_OGERPON_EX) and _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) < 2:
			return 870.0
	if player != null and _current_phase(player) != PHASE_LAUNCH:
		if _matches_name(name, RAGING_BOLT_EX) and _count_pokemon_on_field(player, RAGING_BOLT_EX) < 2:
			base += 120.0
		if _matches_name(name, TEAL_MASK_OGERPON_EX) and _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) < 2:
			base += 100.0
	return base


func _score_attach_energy(card: CardInstance, target_slot: PokemonSlot, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var player: PlayerState = _get_player(game_state, player_index)
	var phase: String = _current_phase(player)
	var energy_type: String = str(card.card_data.energy_provides)
	if _slot_matches(target_slot, RAGING_BOLT_EX):
		var core_ready: bool = _raging_bolt_core_cost_ready(target_slot)
		var gap: int = _preferred_attack_energy_gap(target_slot)
		if energy_type not in ["L", "F"]:
			if core_ready and gap == 1:
				return 520.0 if phase != PHASE_LAUNCH else 430.0
			return 110.0 if gap <= 0 else 10.0
		var type_needed: bool = _energy_type_is_needed_for_attack(target_slot, energy_type)
		if not core_ready and not type_needed:
			return 60.0
		if phase != PHASE_LAUNCH:
			if gap == 1:
				return 540.0
			if gap == 2:
				return 390.0
			if gap <= 0:
				return 170.0 if _has_follow_up_bolt(player) else 250.0
		if gap == 1:
			return 470.0
		if gap == 2:
			return 360.0
		return 260.0
	if _slot_matches(target_slot, TEAL_MASK_OGERPON_EX) and energy_type == "G":
		var gap: int = _attack_energy_gap(target_slot)
		if phase == PHASE_CONVERT:
			return 90.0 if gap > 0 else 40.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			return 150.0 if gap > 0 else 70.0
		return 310.0 if gap > 0 else 160.0
	if player != null and target_slot == player.active_pokemon and _active_is_non_attacker(player):
		var retreat_cost: int = target_slot.get_card_data().retreat_cost if target_slot.get_card_data() != null else 0
		if target_slot.attached_energy.size() < retreat_cost:
			return 500.0
	return -20.0


func _score_attach_tool(card: CardInstance, target_slot: PokemonSlot) -> float:
	if card == null or target_slot == null:
		return 0.0
	if _card_matches(card, BRAVERY_CHARM):
		if _slot_matches(target_slot, RAGING_BOLT_EX):
			return 880.0
		if _slot_matches(target_slot, TEAL_MASK_OGERPON_EX):
			return 220.0
	return -20.0


func _score_trainer(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var player: PlayerState = game_state.players[player_index]
	var phase: String = _current_phase(player)
	var churn_cooldown: bool = _should_cool_off_churn_trainers(player)
	if _matches_name(name, SADA):
		if player.deck.size() <= 3 and _has_attack_ready_raging_bolt(player):
			return 20.0
		if _recovery_restores_missing_bolt_cost(player):
			return 520.0 if phase != PHASE_CONVERT else 340.0
		if _count_basic_energy_in_discard(player) >= 2 and _count_ancient_targets(player) >= 1:
			if phase == PHASE_CONVERT:
				return 170.0 if player.deck.size() <= 8 else 240.0
			if phase == PHASE_PRESSURE:
				return 420.0
			return 500.0
		return 220.0 if phase != PHASE_LAUNCH else 260.0
	if _matches_name(name, EARTHEN_VESSEL):
		if _earthen_vessel_restores_missing_bolt_cost(player):
			return 470.0 if phase != PHASE_CONVERT else 300.0
		if _has_attack_ready_raging_bolt(player):
			if player.deck.size() <= 10:
				return -10.0
			return 160.0 if _count_basic_energy_in_discard(player) < 2 else 40.0
		if phase == PHASE_CONVERT:
			return 90.0 if player.deck.size() <= 8 else 110.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			return 180.0
		if _count_basic_energy_in_discard(player) >= 3 and player.hand.size() >= 4:
			return 170.0
		return 390.0
	if _matches_name(name, ENERGY_RETRIEVAL):
		if _recovery_restores_missing_bolt_cost(player):
			return 380.0 if phase != PHASE_CONVERT else 260.0
		if phase == PHASE_CONVERT:
			return 110.0 if player.deck.size() <= 8 else 120.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			return 210.0
		return 330.0 if _count_basic_energy_in_discard(player) >= 2 else 180.0
	if _matches_name(name, NIGHT_STRETCHER):
		return 260.0 if _night_stretcher_has_real_need(player) else -20.0
	if _matches_name(name, NEST_BALL):
		if phase != PHASE_LAUNCH and _bench_needs_backup(player):
			return 320.0
		if churn_cooldown:
			return 20.0
		return 260.0
	if _matches_name(name, BOSS_ORDERS) or _matches_name(name, PRIME_CATCHER):
		if not _has_immediate_raging_bolt_attack_window(game_state, player_index):
			return -30.0
		if _opponent_has_low_hp_support(game_state, player_index):
			return 520.0 if phase != PHASE_LAUNCH else 420.0
		return 80.0 if phase != PHASE_LAUNCH else 20.0
	if _matches_name(name, IONO):
		if phase == PHASE_CONVERT and player.hand.size() > 3:
			return 20.0 if player.deck.size() <= 8 else 90.0
		return 260.0 if player.hand.size() <= 3 else 170.0
	if _matches_name(name, POKEGEAR_30):
		if churn_cooldown:
			return 30.0
		return 220.0 if not _hand_has_supporter(player) else 120.0
	if _matches_name(name, TREKKING_SHOES):
		if churn_cooldown or player.deck.size() <= 8:
			return -10.0
		return 80.0 if phase == PHASE_LAUNCH else 35.0
	if _matches_name(name, HISUIAN_HEAVY_BALL):
		if churn_cooldown or phase != PHASE_LAUNCH:
			return -10.0
		return 90.0 if _count_pokemon_on_field(player, RAGING_BOLT_EX) <= 0 else 30.0
	if _matches_name(name, POKEMON_CATCHER):
		if churn_cooldown or not _has_immediate_raging_bolt_attack_window(game_state, player_index):
			return -10.0
		return 140.0 if _opponent_has_low_hp_support(game_state, player_index) else 30.0
	if _matches_name(name, LOST_VACUUM):
		if not _has_immediate_raging_bolt_attack_window(game_state, player_index):
			return -30.0
		return 130.0 if _has_lost_vacuum_target(game_state, player_index) else -30.0
	if _matches_name(name, PAL_PAD):
		return 120.0 if _pal_pad_has_real_need(player) else -20.0
	if _matches_name(name, TEMPLE_OF_SINNOH):
		return 240.0 if _opponent_has_special_energy_attached(game_state, player_index) else 120.0
	if _matches_name(name, BRAVERY_CHARM):
		return 240.0
	if _matches_name(name, SWITCH_CART):
		if _has_ready_benched_raging_bolt(player):
			return 620.0 if _active_is_non_attacker(player) else 360.0
		if _active_is_non_attacker(player):
			return 260.0
		return 180.0 if phase == PHASE_CONVERT and _has_attack_ready_raging_bolt(player) else 230.0
	if _matches_name(name, MAGMA_BASIN):
		return 150.0
	if _matches_name(name, PROFESSORS_RESEARCH):
		return 70.0 if churn_cooldown else 150.0
	return -10.0 if churn_cooldown else 20.0


func _score_trainer_action(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	var score: float = _score_trainer(card, game_state, player_index)
	if card == null or card.card_data == null:
		return score
	var player: PlayerState = _get_player(game_state, player_index)
	var name: String = str(card.card_data.name)
	if _matches_name(name, POKEGEAR_30) and _pokegear_hits_only_low_value_supporter(action, player):
		return -10.0
	return score


func _score_ability(source_slot: PokemonSlot, game_state: GameState, player_index: int) -> float:
	if source_slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase: String = _current_phase(player)
	if _slot_matches(source_slot, TEAL_MASK_OGERPON_EX):
		if not _hand_has_basic_energy(player, "G"):
			return 30.0
		if player.deck.size() <= 3:
			return -10.0
		if _has_attack_ready_raging_bolt(player) and player.deck.size() <= 8:
			return -10.0
		if _has_attack_ready_raging_bolt(player) and game_state.turn_number <= 4 and source_slot.count_energy_of_type("G") <= 0:
			return 900.0
		if _has_attack_ready_raging_bolt(player) and phase == PHASE_PRESSURE and player.deck.size() > 12 and source_slot.count_energy_of_type("G") <= 0:
			return 900.0
		if phase == PHASE_CONVERT:
			if player.hand.size() >= 4:
				return 20.0
			return 50.0 if source_slot.count_energy_of_type("G") <= 0 else 25.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			if player.hand.size() >= 4:
				return 40.0
			if source_slot.count_energy_of_type("G") >= 1:
				return 70.0
			return 120.0
		if _has_attack_ready_raging_bolt(player):
			if player.hand.size() >= 5:
				return 60.0
			if source_slot.count_energy_of_type("G") >= 1:
				return 120.0
		var attached_grass: int = source_slot.count_energy_of_type("G")
		if attached_grass == 0:
			return 420.0
		if attached_grass == 1:
			return 360.0
		return 260.0
	if _slot_matches(source_slot, SQUAWKABILLY_EX):
		if game_state.turn_number <= 2 and player.hand.size() >= 3:
			return 280.0
		return 80.0
	if _slot_matches(source_slot, RADIANT_GRENINJA):
		var has_any_energy: bool = _hand_has_basic_energy(player, "G") \
			or _hand_has_basic_energy(player, "L") \
			or _hand_has_basic_energy(player, "F")
		if not has_any_energy:
			return 5.0
		if player.deck.size() <= 4:
			return -10.0
		if _has_attack_ready_raging_bolt(player) and (player.deck.size() <= 8 or phase == PHASE_CONVERT):
			return -10.0
		if phase == PHASE_LAUNCH and _count_ancient_targets(player) >= 1:
			if _hand_has_supporter(player):
				return 350.0
			return 260.0
		if phase == PHASE_PRESSURE:
			return 220.0
		if phase == PHASE_CONVERT:
			return 80.0
		return 200.0
	return 0.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = _get_player(game_state, player_index)
	var phase: String = _current_phase(player)
	var projected_damage: int = int(action.get("projected_damage", 0))
	if projected_damage <= 0 and player != null and _slot_matches(player.active_pokemon, RAGING_BOLT_EX):
		var attack_index: int = int(action.get("attack_index", -1))
		var attack_name: String = str(action.get("attack_name", ""))
		if _is_raging_bolt_redraw_attack(attack_index, attack_name):
			if player.deck.size() <= 12:
				return -100.0
			if _has_attack_ready_raging_bolt(player) or _has_productive_setup_resource(player):
				return -30.0
			if phase != PHASE_LAUNCH:
				return -20.0
			if player.hand.size() <= 2 and player.deck.size() >= 20:
				return 120.0
			return 5.0
		if attack_index == 1 or attack_name == "Bellowing Thunder":
			projected_damage = _estimate_best_bellowing_thunder_damage(player, game_state, player_index)
	if projected_damage <= 0:
		if player != null and _slot_matches(player.active_pokemon, RAGING_BOLT_EX):
			if phase != PHASE_LAUNCH:
				return 5.0
			if player.hand.size() >= 5:
				return 20.0
			if _has_attack_ready_raging_bolt(player):
				return 10.0
		return 80.0
	if bool(action.get("projected_knockout", false)):
		if _knockout_wins_game(game_state, player_index):
			return 980.0
		if player != null and player.deck.size() <= 8:
			return 930.0
		return 850.0
	if phase == PHASE_CONVERT:
		if projected_damage >= 200:
			return 860.0
		if projected_damage >= 140:
			return 760.0
		return 620.0
	if phase == PHASE_PRESSURE:
		if projected_damage >= 200:
			return 840.0
		if projected_damage >= 140:
			return 740.0
		return 600.0
	if projected_damage >= 240:
		return 820.0
	if projected_damage >= 140:
		return 700.0
	return 520.0


func _score_retreat(target_slot: PokemonSlot, game_state: GameState = null, player_index: int = -1) -> float:
	if target_slot == null:
		return 0.0
	var player: PlayerState = _get_player(game_state, player_index)
	var stuck_bonus: float = 0.0
	if player != null and _active_is_non_attacker(player):
		stuck_bonus = 200.0
	if _slot_matches(target_slot, RAGING_BOLT_EX):
		var gap: int = _preferred_attack_energy_gap(target_slot)
		if gap <= 0:
			return 320.0 + stuck_bonus
		if gap == 1:
			return 220.0 + stuck_bonus
		return 120.0 + stuck_bonus * 0.5
	if _slot_matches(target_slot, TEAL_MASK_OGERPON_EX):
		var score: float = 150.0 if target_slot.count_energy_of_type("G") >= 1 else 90.0
		return score + stuck_bonus * 0.5
	if _slot_matches(target_slot, IRON_BUNDLE):
		return -20.0
	if _slot_matches(target_slot, SQUAWKABILLY_EX):
		return -10.0
	return 40.0


func _setup_priority(name: String) -> int:
	if _matches_name(name, RAGING_BOLT_EX):
		return 100
	if _matches_name(name, TEAL_MASK_OGERPON_EX):
		return 94
	if _matches_name(name, SQUAWKABILLY_EX):
		return 76
	if _matches_name(name, SLITHER_WING):
		return 70
	if _matches_name(name, IRON_BUNDLE):
		return 64
	return 30


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack", "granted_attack":
			return 500.0
		"attach_energy":
			return 220.0
		"attach_tool":
			return 160.0
		"play_basic_to_bench":
			return 180.0
		"play_trainer":
			return 110.0
		"play_stadium":
			return 90.0
		"retreat":
			return 90.0
	return 10.0


func _count_basic_energy_in_discard(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			count += 1
	return count


func _count_basic_energy_in_hand(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			count += 1
	return count


func _discard_has_basic_energy_type(player: PlayerState, energy_type: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type == "Basic Energy" and str(card.card_data.energy_provides) == energy_type:
			return true
	return false


func _discard_has_pokemon(player: PlayerState, aliases: Array[String]) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Pokemon" and _matches_name(str(card.card_data.name), aliases):
			return true
	return false


func _night_stretcher_has_real_need(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_pokemon_on_field(player, RAGING_BOLT_EX) <= 0 and _discard_has_pokemon(player, RAGING_BOLT_EX):
		return true
	if _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) <= 0 and _discard_has_pokemon(player, TEAL_MASK_OGERPON_EX):
		return true
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		for energy_type: String in ["L", "F"]:
			if _energy_type_is_needed_for_attack(slot, energy_type) and not _hand_has_basic_energy(player, energy_type) and _discard_has_basic_energy_type(player, energy_type):
				return true
	if not _has_attack_ready_raging_bolt(player) and _count_basic_energy_in_hand(player) <= 0 and _count_basic_energy_in_discard(player) > 0 and player.hand.size() <= 2:
		return true
	return false


func _recovery_restores_missing_bolt_cost(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		for energy_type: String in ["L", "F"]:
			if _energy_type_is_needed_for_attack(slot, energy_type) and _discard_has_basic_energy_type(player, energy_type):
				return true
	return false


func _earthen_vessel_restores_missing_bolt_cost(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		for energy_type: String in ["L", "F"]:
			if _energy_type_is_needed_for_attack(slot, energy_type) and not _hand_has_basic_energy(player, energy_type):
				return true
	return false


func _pal_pad_has_real_need(player: PlayerState) -> bool:
	if player == null or _hand_has_supporter(player):
		return false
	var attack_window: bool = _has_attack_ready_raging_bolt(player)
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		var name: String = str(card.card_data.name)
		if _matches_name(name, SADA):
			return true
		if attack_window and (_matches_name(name, BOSS_ORDERS) or _matches_name(name, PROFESSORS_RESEARCH)):
			return true
	return false


func _count_ancient_targets(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_card_data() != null and slot.get_card_data().is_ancient_pokemon():
			count += 1
	return count


func _score_assignment_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	var phase: String = _current_phase(player)
	var source_card: CardInstance = context.get("source_card", null)
	if source_card != null and source_card.card_data != null:
		var energy_type: String = str(source_card.card_data.energy_provides)
		if energy_type == "G":
			if _slot_matches(slot, RAGING_BOLT_EX):
				return 80.0
			if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
				if phase == PHASE_CONVERT:
					return 90.0 if _attack_energy_gap(slot) > 0 else 50.0
				if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
					return 160.0 if _attack_energy_gap(slot) > 0 else 110.0
				return 380.0 if _attack_energy_gap(slot) > 0 else 320.0
		elif energy_type in ["L", "F"]:
			if _slot_matches(slot, RAGING_BOLT_EX):
				if _energy_type_is_needed_for_attack(slot, energy_type):
					return 560.0 if slot == player.active_pokemon else 500.0
				return 420.0 if _preferred_attack_energy_gap(slot) <= 1 else 360.0
			if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
				return 180.0
	if _slot_matches(slot, RAGING_BOLT_EX):
		return 320.0
	if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
		return 260.0
	return 60.0


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 999
	var attached: int = slot.attached_energy.size()
	var min_gap := 999
	for attack: Dictionary in slot.get_card_data().attacks:
		var gap: int = maxi(0, str(attack.get("cost", "")).length() - attached)
		min_gap = mini(min_gap, gap)
	return min_gap


func _preferred_attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 999
	if _slot_matches(slot, RAGING_BOLT_EX):
		return _raging_bolt_pressure_gap(slot)
	return _attack_energy_gap(slot)


func _raging_bolt_pressure_gap(slot: PokemonSlot) -> int:
	if slot == null:
		return 999
	var missing := 0
	if slot.count_energy_of_type("L") <= 0:
		missing += 1
	if slot.count_energy_of_type("F") <= 0:
		missing += 1
	var total_after_core: int = slot.attached_energy.size() + missing
	if total_after_core < 3:
		missing += 3 - total_after_core
	return missing


func _active_is_non_attacker(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if _slot_matches(active, RAGING_BOLT_EX) and _preferred_attack_energy_gap(active) <= 1:
		return false
	if _slot_matches(active, TEAL_MASK_OGERPON_EX) and _attack_energy_gap(active) <= 0:
		return false
	if _slot_matches(active, SLITHER_WING) and _attack_energy_gap(active) <= 0:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 1:
			return true
	return false


func _count_pokemon_on_field(player: PlayerState, aliases: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, aliases):
			count += 1
	return count


func _has_attack_ready_raging_bolt(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 0:
			return true
	return false


func _has_ready_benched_raging_bolt(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 0:
			return true
	return false


func _has_immediate_raging_bolt_attack_window(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = _get_player(game_state, player_index)
	if player == null:
		return false
	if _slot_matches(player.active_pokemon, RAGING_BOLT_EX) and _preferred_attack_energy_gap(player.active_pokemon) <= 0:
		return true
	if not _has_ready_benched_raging_bolt(player):
		return false
	if _hand_has_card(player, SWITCH_CART):
		return true
	if game_state != null and not game_state.retreat_used_this_turn and _active_can_pay_retreat(player):
		return true
	return false


func _active_can_pay_retreat(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return false
	var retreat_cost: int = int(player.active_pokemon.get_card_data().retreat_cost)
	if retreat_cost <= 0:
		return true
	return player.active_pokemon.attached_energy.size() >= retreat_cost


func _should_cool_off_churn_trainers(player: PlayerState) -> bool:
	if player == null:
		return false
	if _board_is_fully_developed(player):
		return true
	if _has_attack_ready_raging_bolt(player) and player.hand.size() >= 4:
		return true
	return player.deck.size() <= 8 and _count_near_ready_raging_bolts(player) >= 1


func _board_is_fully_developed(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_near_ready_raging_bolts(player) >= 2 \
		and _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) >= 1


func _bench_needs_backup(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_pokemon_on_field(player, RAGING_BOLT_EX) < 2


func _current_phase(player: PlayerState) -> String:
	if player == null:
		return PHASE_LAUNCH
	var ready_count: int = _count_ready_raging_bolts(player)
	if ready_count <= 0:
		return PHASE_LAUNCH
	if _has_follow_up_bolt(player) or player.deck.size() <= 8:
		return PHASE_CONVERT
	return PHASE_PRESSURE


func _has_follow_up_bolt(player: PlayerState) -> bool:
	return _count_near_ready_raging_bolts(player) >= 2


func _count_ready_raging_bolts(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 0:
			count += 1
	return count


func _count_near_ready_raging_bolts(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 1:
			count += 1
	return count


func _get_player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _estimate_best_bellowing_thunder_damage(player: PlayerState, game_state: GameState, player_index: int) -> int:
	if player == null:
		return 0
	var available: Array[CardInstance] = _collect_bellowing_thunder_energy_candidates(player)
	if available.is_empty():
		return 0
	var desired_count: int = _desired_bellowing_thunder_discard_count(
		player,
		_opponent_active_remaining_hp(game_state, player_index),
		available.size(),
		int(game_state.turn_number) if game_state != null else -1
	)
	return estimate_bellowing_thunder_damage(desired_count)


func _pick_field_discard_items(cards: Array[CardInstance], player: PlayerState, context: Dictionary, max_select: int) -> Array:
	if cards.is_empty():
		return []
	var desired_count: int = _desired_bellowing_thunder_discard_count(
		player,
		_opponent_active_remaining_hp(context.get("game_state"), int(context.get("player_index", -1))),
		cards.size(),
		int(context.get("game_state").turn_number) if context.get("game_state") != null else -1
	)
	if desired_count <= 0:
		return []
	var sorted_cards: Array = _ordered_field_discard_candidates(cards, player)
	return sorted_cards.slice(0, mini(mini(max_select, desired_count), sorted_cards.size()))


func _pick_hand_discard_items(cards: Array[CardInstance], player: PlayerState, min_select: int, max_select: int) -> Array:
	if cards.is_empty() or max_select <= 0:
		return []
	var desired_count: int = maxi(min_select, 1)
	var sorted_cards: Array = cards.duplicate()
	sorted_cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var score_a: float = _score_hand_discard_candidate(a, player)
		var score_b: float = _score_hand_discard_candidate(b, player)
		if is_equal_approx(score_a, score_b):
			return str(a.card_data.name) < str(b.card_data.name)
		return score_a > score_b
	)
	return sorted_cards.slice(0, mini(mini(max_select, desired_count), sorted_cards.size()))


func _desired_bellowing_thunder_discard_count(player: PlayerState, target_hp: int, available_count: int, turn_number: int = -1) -> int:
	if player == null or available_count <= 0:
		return 0
	if target_hp <= 0:
		return 0
	var lethal_count: int = int(ceili(float(target_hp) / 70.0))
	if turn_number > 0 and turn_number <= 4:
		lethal_count = maxi(lethal_count, 3)
	return mini(available_count, maxi(1, lethal_count))


func _collect_bellowing_thunder_energy_candidates(player: PlayerState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	if player == null:
		return cards
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Basic Energy":
				cards.append(energy)
	return cards


func _score_field_discard_candidate(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var holder: PokemonSlot = _find_energy_holder(player, card)
	if holder == null:
		return 0.0
	var energy_type: String = str(card.card_data.energy_provides)
	var protected_core_ids := _raging_bolt_core_energy_ids_to_preserve(player)
	if energy_type == "G":
		if _slot_matches(holder, TEAL_MASK_OGERPON_EX):
			return 1040.0
		if _slot_matches(holder, RAGING_BOLT_EX):
			return 1020.0
		return 1000.0
	if holder == player.active_pokemon and _slot_matches(holder, RAGING_BOLT_EX):
		if bool(protected_core_ids.get(card.instance_id, false)):
			return 20.0
		return 760.0
	if _slot_matches(holder, TEAL_MASK_OGERPON_EX):
		return 700.0
	if _slot_matches(holder, RAGING_BOLT_EX):
		if bool(protected_core_ids.get(card.instance_id, false)):
			return 180.0
		return 900.0
	return 500.0


func _ordered_field_discard_candidates(cards: Array[CardInstance], player: PlayerState) -> Array:
	var buckets: Array = [[], [], [], [], [], [], []]
	var protected_core_ids := _raging_bolt_core_energy_ids_to_preserve(player)
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			continue
		var holder: PokemonSlot = _find_energy_holder(player, card)
		if holder == null:
			continue
		var energy_type: String = str(card.card_data.energy_provides)
		var bucket_index := 4
		if energy_type == "G":
			bucket_index = 0
		elif _slot_matches(holder, RAGING_BOLT_EX) and holder != player.active_pokemon and not bool(protected_core_ids.get(card.instance_id, false)):
			bucket_index = 1
		elif holder == player.active_pokemon and _slot_matches(holder, RAGING_BOLT_EX) and not bool(protected_core_ids.get(card.instance_id, false)):
			bucket_index = 2
		elif _slot_matches(holder, TEAL_MASK_OGERPON_EX):
			bucket_index = 3
		elif holder == player.active_pokemon and _slot_matches(holder, RAGING_BOLT_EX):
			bucket_index = 5
		elif _slot_matches(holder, RAGING_BOLT_EX):
			bucket_index = 6
		(buckets[bucket_index] as Array).append(card)
	var ordered: Array = []
	for bucket: Array in buckets:
		bucket.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var name_a := str(a.card_data.name) if a != null and a.card_data != null else ""
			var name_b := str(b.card_data.name) if b != null and b.card_data != null else ""
			if name_a == name_b:
				return int(a.instance_id) < int(b.instance_id)
			return name_a < name_b
		)
		ordered.append_array(bucket)
	return ordered


func _raging_bolt_core_energy_ids_to_preserve(player: PlayerState) -> Dictionary:
	var protected := {}
	if player == null:
		return protected
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		var preserved_lightning: CardInstance = null
		var preserved_fighting: CardInstance = null
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			var energy_type := str(energy.card_data.energy_provides)
			if energy_type == "L" and preserved_lightning == null:
				preserved_lightning = energy
			elif energy_type == "F" and preserved_fighting == null:
				preserved_fighting = energy
		if preserved_lightning != null:
			protected[preserved_lightning.instance_id] = true
		if preserved_fighting != null:
			protected[preserved_fighting.instance_id] = true
	return protected


func _score_hand_discard_candidate(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var energy_type: String = str(card.card_data.energy_provides)
	var best_target: PokemonSlot = _best_sada_target_for_energy_type(player, energy_type)
	if best_target != null and _energy_type_is_needed_for_attack(best_target, energy_type):
		return 900.0
	if energy_type == "G":
		return 620.0
	if energy_type in ["L", "F"]:
		return 420.0
	return 120.0


func _pick_sada_energy_sources(items: Array, context: Dictionary, max_count: int) -> Array:
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	if player == null:
		return items.slice(0, mini(max_count, items.size()))
	var scored: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance):
			continue
		var card := item as CardInstance
		if card.card_data == null:
			continue
		var energy_type: String = str(card.card_data.energy_provides)
		var score: float = 100.0
		for slot: PokemonSlot in player.get_all_pokemon():
			if _slot_matches(slot, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(slot, energy_type):
				score = 900.0
				break
		if score < 900.0:
			if energy_type in ["L", "F"]:
				score = 500.0
			elif energy_type == "G":
				score = 300.0
		scored.append({"item": item, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	var result: Array = []
	for entry: Dictionary in scored.slice(0, mini(max_count, scored.size())):
		result.append(entry.item)
	return result


func _best_sada_target_for_energy_type(player: PlayerState, energy_type: String) -> PokemonSlot:
	if player == null:
		return null
	if _slot_matches(player.active_pokemon, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(player.active_pokemon, energy_type):
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(slot, energy_type):
			return slot
	if _slot_matches(player.active_pokemon, RAGING_BOLT_EX):
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, RAGING_BOLT_EX):
			return slot
	return null


func _all_cards_attached_to_field(cards: Array[CardInstance], player: PlayerState) -> bool:
	if player == null or cards.is_empty():
		return false
	for card: CardInstance in cards:
		if _find_energy_holder(player, card) == null:
			return false
	return true


func _find_energy_holder(player: PlayerState, card: CardInstance) -> PokemonSlot:
	if player == null or card == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and card in slot.attached_energy:
			return slot
	return null


func _energy_type_is_needed_for_attack(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null or energy_type == "":
		return false
	return int(_preferred_attack_requirements(slot).get(energy_type, 0)) > slot.count_energy_of_type(energy_type)


func _energy_card_is_essential_for_attack(slot: PokemonSlot, card: CardInstance) -> bool:
	if slot == null or card == null or card.card_data == null:
		return false
	var energy_type: String = str(card.card_data.energy_provides)
	var required: int = int(_preferred_attack_requirements(slot).get(energy_type, 0))
	if required <= 0:
		return false
	return slot.count_energy_of_type(energy_type) <= required


func _raging_bolt_core_cost_ready(slot: PokemonSlot) -> bool:
	if slot == null or not _slot_matches(slot, RAGING_BOLT_EX):
		return false
	return slot.count_energy_of_type("L") >= 1 and slot.count_energy_of_type("F") >= 1


func _preferred_attack_requirements(slot: PokemonSlot) -> Dictionary:
	var requirements := {}
	if slot == null or slot.get_card_data() == null:
		return requirements
	var attacks: Array = slot.get_card_data().attacks
	var best_attack: Dictionary = {}
	var best_damage := -1
	for attack: Dictionary in attacks:
		var damage: int = _parse_damage_value(str(attack.get("damage", "0")))
		if damage > best_damage:
			best_damage = damage
			best_attack = attack
	var cost: String = str(best_attack.get("cost", ""))
	for i: int in cost.length():
		var symbol: String = cost.substr(i, 1)
		requirements[symbol] = int(requirements.get(symbol, 0)) + 1
	return requirements


func _opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return 0
	return opponent.active_pokemon.get_remaining_hp()


func _knockout_wins_game(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = _get_player(game_state, player_index)
	if player == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	if player.prizes.is_empty():
		return false
	return player.prizes.size() <= opponent.active_pokemon.get_prize_count()


func _is_basic_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Pokemon" and str(card.card_data.stage) == "Basic"


func _slot_matches(slot: PokemonSlot, aliases: Array[String]) -> bool:
	return slot != null and _matches_name(str(slot.get_pokemon_name()), aliases)


func _card_matches(card: CardInstance, aliases: Array[String]) -> bool:
	return card != null and card.card_data != null and _matches_name(str(card.card_data.name), aliases)


func _matches_name(name: String, aliases: Array[String]) -> bool:
	for alias: String in aliases:
		if name == alias:
			return true
	return false


func _is_raging_bolt_redraw_attack(attack_index: int, attack_name: String) -> bool:
	if attack_index == 0:
		return true
	return attack_name in ["Burst Roar", "飞溅咆哮"]


func _has_productive_setup_resource(player: PlayerState) -> bool:
	if player == null:
		return false
	if _hand_has_card(player, SADA) and _count_basic_energy_in_discard(player) >= 1 and _count_ancient_targets(player) >= 1:
		return true
	if _hand_has_card(player, EARTHEN_VESSEL):
		return true
	if _hand_has_card(player, ENERGY_RETRIEVAL) and _count_basic_energy_in_discard(player) >= 2:
		return true
	if _hand_has_card(player, NEST_BALL) and _bench_needs_backup(player):
		return true
	if _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) >= 1 and _hand_has_basic_energy(player, "G"):
		return true
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		for energy_type: String in ["L", "F"]:
			if _energy_type_is_needed_for_attack(slot, energy_type) and _hand_has_basic_energy(player, energy_type):
				return true
	return false


func _parse_damage_value(damage_text: String) -> int:
	var digits := ""
	for i: int in damage_text.length():
		var ch := damage_text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0


func _score_energy_search_candidate(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 40.0
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	var energy_type: String = str(card.card_data.energy_provides)
	if player == null:
		return 40.0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(slot, energy_type):
			return 500.0
	if energy_type == "G":
		for slot: PokemonSlot in player.get_all_pokemon():
			if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
				return 300.0
	return 100.0


func _score_energy_recovery_candidate(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 40.0
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	var energy_type: String = str(card.card_data.energy_provides)
	if player == null:
		return 40.0
	var missing_bolt_cost: bool = false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(slot, energy_type):
			return 780.0 if energy_type in ["L", "F"] else 240.0
		if _slot_matches(slot, RAGING_BOLT_EX):
			for required_type: String in ["L", "F"]:
				if _energy_type_is_needed_for_attack(slot, required_type):
					missing_bolt_cost = true
	if not missing_bolt_cost and energy_type == "G" and _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) > 0:
		return 620.0
	if energy_type in ["L", "F"]:
		return 420.0
	if energy_type == "G" and _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) > 0:
		return 320.0
	return 120.0


func _score_supporter_candidate(card: CardInstance, context: Dictionary) -> float:
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	return _score_supporter_candidate_for_player(card, player)


func _score_supporter_candidate_for_player(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null:
		return 0.0
	if card.card_data.card_type != "Supporter":
		return 0.0
	var name: String = str(card.card_data.name)
	if _matches_name(name, SADA):
		return 900.0
	if _matches_name(name, PROFESSORS_RESEARCH):
		if player != null and player.hand.size() <= 3 and player.deck.size() > 8:
			return 420.0
		return 120.0
	if _matches_name(name, IONO):
		if player != null and player.hand.size() <= 3 and player.deck.size() > 8:
			return 360.0
		return 100.0
	if _matches_name(name, BOSS_ORDERS):
		return 260.0 if player != null and _has_attack_ready_raging_bolt(player) else -80.0
	return 60.0


func _pokegear_hits_only_low_value_supporter(action: Dictionary, player: PlayerState) -> bool:
	var saw_supporter := false
	var saw_good_supporter := false
	var targets: Array = action.get("targets", [])
	for target_group: Variant in targets:
		if not (target_group is Dictionary):
			continue
		var cards: Array = (target_group as Dictionary).get("look_top_cards", [])
		for item: Variant in cards:
			if not (item is CardInstance):
				continue
			var card := item as CardInstance
			if card.card_data == null or card.card_data.card_type != "Supporter":
				continue
			saw_supporter = true
			var score: float = _score_supporter_candidate_for_player(card, player)
			if score >= 300.0:
				saw_good_supporter = true
	return saw_supporter and not saw_good_supporter


func _hand_has_basic_energy(player: PlayerState, energy_type: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type == "Basic Energy" and str(card.card_data.energy_provides) == energy_type:
			return true
	return false


func _hand_has_supporter(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.card_type == "Supporter":
			return true
	return false


func _opponent_has_special_energy_attached(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Special Energy":
				return true
	return false


func _has_lost_vacuum_target(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if game_state.stadium_card != null and game_state.stadium_owner_index >= 0 and game_state.stadium_owner_index != player_index:
		return true
	var opponent: PlayerState = game_state.players[1 - player_index]
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot != null and slot.attached_tool != null:
			return true
	return false


func _opponent_has_low_hp_support(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= 180:
			return true
	return false


# ============================================================
#  Turn Plan / Turn Contract
# ============================================================


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var phase: String = _current_phase(player)
	var discard_fuel: int = _count_basic_energy_in_discard(player)
	var hand_has_sada: bool = _hand_has_card(player, SADA)
	var hand_has_ev: bool = _hand_has_card(player, EARTHEN_VESSEL)
	var hand_has_er: bool = _hand_has_card(player, ENERGY_RETRIEVAL)
	var active_stuck: bool = _active_is_non_attacker(player)
	var ready_bolts: int = _count_ready_raging_bolts(player)
	var near_ready_bolts: int = _count_near_ready_raging_bolts(player)
	var bolts_on_field: int = _count_pokemon_on_field(player, RAGING_BOLT_EX)
	var ogerpon_on_field: int = _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX)

	var intent: String = "setup_board"
	if active_stuck:
		intent = "emergency_retreat"
	elif ready_bolts >= 1 and near_ready_bolts >= 2:
		intent = "convert_attack"
	elif ready_bolts >= 1 and near_ready_bolts < 2:
		intent = "pressure_expand"
	elif discard_fuel >= 2 and hand_has_sada and bolts_on_field >= 1:
		intent = "charge_bolt"
	elif discard_fuel < 2 and bolts_on_field >= 1:
		intent = "fuel_discard"

	var primary_attacker_name: String = _find_best_charge_bolt_name(player)
	var bridge_target_name: String = primary_attacker_name if intent in ["charge_bolt", "fuel_discard"] else ""
	var pivot_target_name: String = ""
	if intent == "pressure_expand":
		pivot_target_name = _find_backup_target_name(player, primary_attacker_name)

	var flags: Dictionary = {
		"hand_has_sada": hand_has_sada,
		"hand_has_earthen_vessel": hand_has_ev,
		"hand_has_energy_retrieval": hand_has_er,
		"discard_has_fuel": discard_fuel >= 2,
		"active_is_stuck": active_stuck,
		"opponent_has_value_target": _opponent_has_low_hp_support(game_state, player_index),
		"bolts_on_field": bolts_on_field,
		"ogerpon_on_field": ogerpon_on_field,
	}

	var constraints: Dictionary = {}
	if intent == "charge_bolt" and hand_has_sada:
		constraints["forbid_draw_supporter_waste"] = true
	if intent == "convert_attack":
		constraints["forbid_engine_churn"] = true

	return {
		"intent": intent,
		"phase": phase,
		"flags": flags,
		"targets": {
			"primary_attacker_name": primary_attacker_name,
			"bridge_target_name": bridge_target_name,
			"pivot_target_name": pivot_target_name,
		},
		"constraints": constraints,
		"context": context.duplicate(true),
	}


func build_continuity_contract(game_state: GameState, player_index: int, turn_contract: Dictionary = {}) -> Dictionary:
	var disabled := {
		"enabled": false,
		"safe_setup_before_attack": false,
		"setup_debt": {},
		"action_bonuses": [],
		"attack_penalty": 0.0,
	}
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return disabled
	var player: PlayerState = game_state.players[player_index]
	if not _has_immediate_raging_bolt_attack_window(game_state, player_index):
		return disabled
	var setup_debt: Dictionary = _build_continuity_setup_debt(player)
	if _continuity_terminal_attack_locked(game_state, player_index, turn_contract):
		disabled["setup_debt"] = setup_debt
		disabled["terminal_attack_locked"] = true
		return disabled
	var action_bonuses: Array[Dictionary] = _build_continuity_action_bonuses(player, setup_debt)
	var enabled: bool = _continuity_setup_debt_is_active(setup_debt) and not action_bonuses.is_empty()
	return {
		"enabled": enabled,
		"safe_setup_before_attack": enabled,
		"setup_debt": setup_debt,
		"action_bonuses": action_bonuses,
		"attack_penalty": 0.0,
	}


func _build_continuity_setup_debt(player: PlayerState) -> Dictionary:
	var bolts_on_field: int = _count_pokemon_on_field(player, RAGING_BOLT_EX)
	var ogerpon_on_field: int = _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX)
	var backup_bolt: PokemonSlot = _best_continuity_backup_bolt(player)
	var backup_gap: int = _preferred_attack_energy_gap(backup_bolt) if backup_bolt != null else 999
	var field_basic_energy: int = _count_basic_energy_attached_to_field(player)
	var ogerpon_with_grass: int = _count_ogerpon_with_grass_energy(player)
	var bench_open: bool = player != null and not player.is_bench_full()
	var needs_second_bolt: bool = bolts_on_field < 2 and bench_open
	var needs_ogerpon: bool = ogerpon_on_field < 1 and bench_open
	var needs_ogerpon_charge: bool = ogerpon_on_field > 0 and ogerpon_with_grass < ogerpon_on_field and _hand_has_basic_energy(player, "G")
	var needs_follow_up_energy: bool = backup_bolt != null and backup_gap > 0
	var needs_field_energy: bool = field_basic_energy < 5 or needs_follow_up_energy or needs_ogerpon_charge
	var needs_discard_fuel: bool = _count_basic_energy_in_discard(player) < 2
	return {
		"ready_raging_bolt_count": _count_ready_raging_bolts(player),
		"raging_bolt_count": bolts_on_field,
		"ogerpon_count": ogerpon_on_field,
		"ogerpon_with_grass_energy_count": ogerpon_with_grass,
		"field_basic_energy_count": field_basic_energy,
		"discard_basic_energy_count": _count_basic_energy_in_discard(player),
		"backup_raging_bolt_gap": backup_gap,
		"needs_second_raging_bolt": needs_second_bolt,
		"needs_ogerpon": needs_ogerpon,
		"needs_ogerpon_charge": needs_ogerpon_charge,
		"needs_follow_up_energy": needs_follow_up_energy,
		"needs_field_energy": needs_field_energy,
		"needs_discard_fuel": needs_discard_fuel,
	}


func _build_continuity_action_bonuses(player: PlayerState, setup_debt: Dictionary) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	var needs_second_bolt: bool = bool(setup_debt.get("needs_second_raging_bolt", false))
	var needs_ogerpon: bool = bool(setup_debt.get("needs_ogerpon", false))
	var needs_follow_up_energy: bool = bool(setup_debt.get("needs_follow_up_energy", false))
	var needs_field_energy: bool = bool(setup_debt.get("needs_field_energy", false))
	var needs_discard_fuel: bool = bool(setup_debt.get("needs_discard_fuel", false))
	if player != null and not player.is_bench_full():
		if needs_second_bolt:
			bonuses.append(_continuity_bonus(
				"play_basic_to_bench",
				RAGING_BOLT_EX,
				240.0,
				"Bench a second Raging Bolt before a non-terminal attack.",
				{"target_names": RAGING_BOLT_EX}
			))
		if needs_ogerpon:
			bonuses.append(_continuity_bonus(
				"play_basic_to_bench",
				TEAL_MASK_OGERPON_EX,
				210.0,
				"Bench Teal Mask Ogerpon so future Grass attachments become field Energy.",
				{"target_names": TEAL_MASK_OGERPON_EX}
			))
		if needs_second_bolt or needs_ogerpon:
			bonuses.append(_continuity_bonus(
				"play_trainer",
				NEST_BALL,
				170.0,
				"Use search to fill missing Raging Bolt/Ogerpon continuity pieces.",
				{"search_names": RAGING_BOLT_EX + TEAL_MASK_OGERPON_EX}
			))
	if bool(setup_debt.get("needs_ogerpon_charge", false)):
		bonuses.append(_continuity_bonus(
			"use_ability",
			TEAL_MASK_OGERPON_EX,
			220.0,
			"Use Teal Mask Ogerpon to put Grass Energy on board before Bellowing Thunder.",
			{"pokemon_names": TEAL_MASK_OGERPON_EX, "energy_types": ["G"]}
		))
	if needs_follow_up_energy or needs_field_energy:
		bonuses.append(_continuity_bonus(
			"attach_energy",
			CONTINUITY_ENERGY_NAMES,
			160.0,
			"Attach a basic Energy to keep a follow-up Raging Bolt or Bellowing Thunder fuel online.",
			{"target_names": RAGING_BOLT_EX, "energy_types": CONTINUITY_ENERGY_TYPES, "prefer_non_active": true}
		))
	if (needs_follow_up_energy or needs_field_energy) and _count_basic_energy_in_discard(player) >= 1 and _count_ancient_targets(player) >= 1:
		bonuses.append(_continuity_bonus(
			"play_trainer",
			SADA,
			190.0,
			"Use Professor Sada's Vitality to charge Ancient follow-up attackers before attacking.",
			{"target_names": RAGING_BOLT_EX}
		))
	if needs_follow_up_energy or needs_field_energy or needs_discard_fuel:
		bonuses.append(_continuity_bonus(
			"play_trainer",
			EARTHEN_VESSEL,
			150.0,
			"Use Earthen Vessel to find basic Energy for the next attacker or discard fuel.",
			{"energy_types": CONTINUITY_ENERGY_TYPES}
		))
	if (needs_follow_up_energy or needs_field_energy) and _count_basic_energy_in_discard(player) >= 2:
		bonuses.append(_continuity_bonus(
			"play_trainer",
			ENERGY_RETRIEVAL,
			130.0,
			"Recover basic Energy to preserve the follow-up attack chain.",
			{"energy_types": CONTINUITY_ENERGY_TYPES}
		))
	return bonuses


func _continuity_bonus(kind: String, card_names: Array[String], bonus: float, reason: String, extra: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {
		"kind": kind,
		"card_names": card_names.duplicate(),
		"bonus": bonus,
		"reason": reason,
	}
	for key: Variant in extra.keys():
		entry[key] = extra[key]
	return entry


func _continuity_setup_debt_is_active(setup_debt: Dictionary) -> bool:
	return bool(setup_debt.get("needs_second_raging_bolt", false)) \
		or bool(setup_debt.get("needs_ogerpon", false)) \
		or bool(setup_debt.get("needs_ogerpon_charge", false)) \
		or bool(setup_debt.get("needs_follow_up_energy", false)) \
		or bool(setup_debt.get("needs_field_energy", false)) \
		or bool(setup_debt.get("needs_discard_fuel", false))


func _continuity_terminal_attack_locked(game_state: GameState, player_index: int, turn_contract: Dictionary) -> bool:
	var flags: Dictionary = turn_contract.get("flags", {}) if turn_contract.get("flags", {}) is Dictionary else {}
	var constraints: Dictionary = turn_contract.get("constraints", {}) if turn_contract.get("constraints", {}) is Dictionary else {}
	if bool(constraints.get("must_attack_if_available", false)):
		return true
	for key: String in ["final_prize_ko", "final_prize_ko_available", "critical_ko", "critical_ko_available", "key_ko", "key_ko_available", "force_terminal_attack"]:
		if bool(turn_contract.get(key, false)) or bool(flags.get(key, false)):
			return true
	return _raging_bolt_final_prize_ko_is_available(game_state, player_index)


func _raging_bolt_final_prize_ko_is_available(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = _get_player(game_state, player_index)
	if player == null or not _has_immediate_raging_bolt_attack_window(game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	if player.prizes.is_empty() or player.prizes.size() > opponent.active_pokemon.get_prize_count():
		return false
	return _estimate_best_bellowing_thunder_damage(player, game_state, player_index) >= opponent.active_pokemon.get_remaining_hp()


func _best_continuity_backup_bolt(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_gap := 999
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot == player.active_pokemon or not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		var gap: int = _preferred_attack_energy_gap(slot)
		if gap < best_gap:
			best_slot = slot
			best_gap = gap
	return best_slot


func _count_basic_energy_attached_to_field(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Basic Energy":
				count += 1
	return count


func _count_ogerpon_with_grass_energy(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, TEAL_MASK_OGERPON_EX) and slot.count_energy_of_type("G") > 0:
			count += 1
	return count


func _find_best_charge_bolt_name(player: PlayerState) -> String:
	if player == null:
		return ""
	var best_name: String = ""
	var best_gap: int = 999
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		var gap: int = _preferred_attack_energy_gap(slot)
		if gap < best_gap:
			best_gap = gap
			best_name = str(slot.get_pokemon_name())
	return best_name


func _find_backup_target_name(player: PlayerState, exclude_name: String) -> String:
	if player == null:
		return ""
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		if _slot_matches(slot, RAGING_BOLT_EX):
			var n: String = str(slot.get_pokemon_name())
			if n != exclude_name or _count_pokemon_on_field(player, RAGING_BOLT_EX) >= 2:
				return n
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
			return str(slot.get_pokemon_name())
	return ""


func _hand_has_card(player: PlayerState, aliases: Array[String]) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _matches_name(str(card.card_data.name), aliases):
			return true
	return false


func _is_draw_supporter(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var name: String = str(card.card_data.name)
	return name == "Iono" or _matches_name(name, PROFESSORS_RESEARCH) or name == "Judge"


# ============================================================
#  Turn Plan Bonus — intent-driven score adjustments
# ============================================================


func _apply_turn_plan_bonus(kind: String, action: Dictionary, game_state: GameState, player_index: int, base_score: float) -> float:
	var contract: Dictionary = _turn_contract_context
	if contract.is_empty():
		return 0.0
	var intent: String = str(contract.get("intent", ""))
	if intent == "":
		return 0.0
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var targets: Dictionary = contract.get("targets", {}) if contract.get("targets", {}) is Dictionary else {}
	var player: PlayerState = _get_player(game_state, player_index)

	match intent:
		"fuel_discard":
			return _bonus_fuel_discard(kind, action, player, flags)
		"charge_bolt":
			return _bonus_charge_bolt(kind, action, player, flags, targets)
		"emergency_retreat":
			return _bonus_emergency_retreat(kind, action, player, flags)
		"pressure_expand":
			return _bonus_pressure_expand(kind, action, player, flags, targets)
		"convert_attack":
			return _bonus_convert_attack(kind, action, game_state, player_index, flags)
	return 0.0


func _bonus_fuel_discard(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, EARTHEN_VESSEL):
			return 100.0
		if _is_draw_supporter(card) and (bool(flags.get("hand_has_earthen_vessel", false)) or bool(flags.get("hand_has_energy_retrieval", false))):
			return -80.0
	if kind == "use_ability":
		var slot: PokemonSlot = action.get("source_slot")
		if _slot_matches(slot, RADIANT_GRENINJA):
			return 80.0
	return 0.0


func _bonus_charge_bolt(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary, targets: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, SADA):
			return 80.0
		if _is_draw_supporter(card) and bool(flags.get("hand_has_sada", false)):
			return -150.0
	if kind == "attach_energy":
		var target_slot: PokemonSlot = action.get("target_slot")
		if target_slot != null and _slot_matches(target_slot, RAGING_BOLT_EX):
			var primary_name: String = str(targets.get("primary_attacker_name", ""))
			if primary_name != "" and str(target_slot.get_pokemon_name()) == primary_name:
				return 60.0
	return 0.0


func _bonus_emergency_retreat(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, SWITCH_CART):
			return 100.0
	if kind == "retreat":
		var target: PokemonSlot = action.get("bench_target")
		if target != null and _slot_matches(target, RAGING_BOLT_EX) and _preferred_attack_energy_gap(target) <= 0:
			return 100.0
	if kind == "attach_energy" and player != null:
		var target_slot: PokemonSlot = action.get("target_slot")
		if target_slot != null and target_slot == player.active_pokemon:
			return 80.0
	return 0.0


func _bonus_pressure_expand(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary, targets: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, NEST_BALL):
			return 60.0
	if kind == "play_basic_to_bench":
		var card: CardInstance = action.get("card")
		if card != null and card.card_data != null:
			var name: String = str(card.card_data.name)
			if _matches_name(name, RAGING_BOLT_EX) or _matches_name(name, TEAL_MASK_OGERPON_EX):
				return 60.0
	if kind == "attach_energy":
		var target_slot: PokemonSlot = action.get("target_slot")
		if target_slot != null and _slot_matches(target_slot, RAGING_BOLT_EX):
			var pivot_name: String = str(targets.get("pivot_target_name", ""))
			if pivot_name != "" and str(target_slot.get_pokemon_name()) == pivot_name:
				return 40.0
	return 0.0


func _bonus_convert_attack(kind: String, action: Dictionary, game_state: GameState, player_index: int, flags: Dictionary) -> float:
	if kind in ["attack", "granted_attack"]:
		return 80.0
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if card != null and card.card_data != null:
			var name: String = str(card.card_data.name)
			if (_matches_name(name, BOSS_ORDERS) or _matches_name(name, PRIME_CATCHER)) and bool(flags.get("opponent_has_value_target", false)):
				return 60.0
	return 0.0


# ============================================================
#  Handoff Scoring — 被击倒后选谁上场
# ============================================================


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not (item is PokemonSlot):
		return score_interaction_target(item, step, context)
	var slot: PokemonSlot = item as PokemonSlot
	if slot == null or slot.get_card_data() == null:
		return 0.0
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	var has_other_bolt := false
	if player != null:
		for bench_slot: PokemonSlot in player.bench:
			if bench_slot != null and bench_slot != slot and _slot_matches(bench_slot, RAGING_BOLT_EX):
				has_other_bolt = true
				break
	if _slot_matches(slot, RAGING_BOLT_EX):
		var gap: int = _preferred_attack_energy_gap(slot)
		if gap <= 0:
			return 850.0
		if gap == 1:
			return 650.0
		if gap == 2:
			return 460.0
		return 330.0
	if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
		var ogerpon_score := 300.0 if slot.count_energy_of_type("G") >= 1 else 180.0
		return mini(ogerpon_score, 240.0) if has_other_bolt else ogerpon_score
	if _slot_matches(slot, SLITHER_WING):
		return 120.0 if has_other_bolt else 200.0
	if _slot_matches(slot, SQUAWKABILLY_EX) or _slot_matches(slot, RADIANT_GRENINJA) or _slot_matches(slot, IRON_BUNDLE):
		return -50.0
	return 40.0
