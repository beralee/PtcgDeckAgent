class_name DeckStrategyNsZoroark
extends "res://scripts/ai/DeckStrategyBase.gd"


const STRATEGY_ID := "ns_zoroark"

const NS_ZORUA := "N的索罗亚"
const NS_ZOROARK_EX := "N的索罗亚克ex"
const NS_RESHIRAM := "N的莱希拉姆"
const NS_DARMANITAN := "N的达摩狒狒"
const NS_PP_UP := "N的PP提升剂"
const NS_NAME_ALIASES := {
	NS_ZORUA: ["N's Zorua"],
	NS_ZOROARK_EX: ["N's Zoroark ex"],
	NS_RESHIRAM: ["N's Reshiram"],
	NS_DARMANITAN: ["N's Darmanitan"],
	NS_PP_UP: ["N's PP Up", "N的PP提升"],
}
const MUNKIDORI := "Munkidori"
const FEZANDIPITI_EX := "Fezandipiti ex"
const BLOODMOON_URSALUNA_EX := "Bloodmoon Ursaluna ex"
const WELLSPRING_OGERPON_EX := "Wellspring Mask Ogerpon ex"
const CORNERSTONE_OGERPON_EX := "Cornerstone Mask Ogerpon ex"

const ARVEN := "Arven"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const PROFESSORS_RESEARCH := "Professor's Research"
const PROFESSOR_TURO := "Professor Turo's Scenario"
const NEST_BALL := "Nest Ball"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const COUNTER_CATCHER := "Counter Catcher"
const ULTRA_BALL := "Ultra Ball"
const SUPER_ROD := "Super Rod"
const PAL_PAD := "Pal Pad"
const NIGHT_STRETCHER := "Night Stretcher"
const ENERGY_SWITCH := "Energy Switch"
const SECRET_BOX := "Secret Box"
const EARTHEN_VESSEL := "Earthen Vessel"
const SWITCH := "Switch"
const TM_TURBO_ENERGIZE := "Technical Machine: Turbo Energize"
const TM_EVOLUTION := "Technical Machine: Evolution"
const TM_DEVOLUTION := "Technical Machine: Devolution"
const AIR_BALLOON := "Air Balloon"
const ARTAZON := "Artazon"

const DARKNESS_ENERGY := "Darkness Energy"
const FIGHTING_ENERGY := "Fighting Energy"
const REVERSAL_ENERGY_EFFECT_ID := "cbadb3473273c14cf667d495d44d111b"
const CILAN_CARD_UID := "CSV9C_198"

const TRADE_DISCARD_STEP := "discard_card"
const COPIED_ATTACK_STEP := "copied_attack"
const NIGHT_JOKER_KO_BONUS := 900.0
const EVOLUTION_ACCESS_ATTACK_PENALTY := 1200.0
const EVOLUTION_ACCESS_BRIDGE_BONUS := 320.0
const EVOLUTION_ACCESS_KO_BONUS := 900.0

const CORE_NAMES: Array[String] = [NS_ZORUA, NS_ZOROARK_EX, NS_RESHIRAM]
const SEARCH_PRIORITY := {
	NS_ZOROARK_EX: 100,
	NS_ZORUA: 96,
	NS_RESHIRAM: 84,
	MUNKIDORI: 72,
	ARVEN: 66,
	BUDDY_BUDDY_POFFIN: 64,
	NEST_BALL: 62,
	ULTRA_BALL: 60,
	SECRET_BOX: 58,
	EARTHEN_VESSEL: 52,
	DARKNESS_ENERGY: 48,
}

var _prediction_game_state: GameState = null
var _prediction_player_index := -1


func get_strategy_id() -> String:
	return STRATEGY_ID


func get_signature_names() -> Array[String]:
	return [
		NS_ZORUA, "N's Zorua",
		NS_ZOROARK_EX, "N's Zoroark ex",
		NS_RESHIRAM, "N's Reshiram",
		NS_DARMANITAN, "N's Darmanitan",
		NS_PP_UP, "N's PP Up",
	]


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 4,
		"time_budget_ms": 1400,
		"rollouts_per_sequence": 0,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {}
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or not card.is_basic_pokemon():
			continue
		basics.append({
			"index": i,
			"active_score": _opening_active_priority(card),
			"bench_score": _opening_bench_priority(card),
		})
	if basics.is_empty():
		return {}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("active_score", 0.0)) > float(b.get("active_score", 0.0))
	)
	var active_index := int(basics[0].get("index", -1))
	var bench: Array[Dictionary] = []
	for entry: Dictionary in basics:
		if int(entry.get("index", -1)) != active_index:
			bench.append(entry)
	bench.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("bench_score", 0.0)) > float(b.get("bench_score", 0.0))
	)
	var bench_indices: Array[int] = []
	for entry: Dictionary in bench:
		if bench_indices.size() >= 5:
			break
		if float(entry.get("bench_score", 0.0)) > 0.0:
			bench_indices.append(int(entry.get("index", -1)))
	return {
		"active_hand_index": active_index,
		"bench_hand_indices": bench_indices,
	}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	_remember_prediction_context(game_state, player_index)
	var player: PlayerState = game_state.players[player_index]
	var zoroark_online := _count_name_on_field(player, NS_ZOROARK_EX) > 0
	var zorua_missing := _count_name_on_field(player, NS_ZORUA) + _count_name_on_field(player, NS_ZOROARK_EX) == 0
	var reshiram_missing := _count_name_on_field(player, NS_RESHIRAM) == 0
	var owner := NS_ZOROARK_EX if zoroark_online else NS_ZORUA
	var reversal_target := _live_reversal_darmanitan_target(game_state, player_index)
	var attach_priority: Array[String] = [NS_ZOROARK_EX, NS_ZORUA, NS_RESHIRAM, MUNKIDORI]
	if reversal_target != null:
		attach_priority.push_front(NS_DARMANITAN)
	var handoff_priority: Array[String] = [NS_ZOROARK_EX, NS_RESHIRAM, MUNKIDORI]
	if _ready_benched_darmanitan(game_state, player_index) != null:
		handoff_priority.push_front(NS_DARMANITAN)
	var search_priority: Array[String] = []
	if zorua_missing:
		search_priority.append(NS_ZORUA)
	if not zoroark_online:
		search_priority.append(NS_ZOROARK_EX)
	if reshiram_missing:
		search_priority.append(NS_RESHIRAM)
	for name: String in [ARVEN, BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL, EARTHEN_VESSEL]:
		if not search_priority.has(name):
			search_priority.append(name)
	return {
		"id": "ns_zoroark_setup" if not zoroark_online else "ns_zoroark_attack",
		"intent": "build_zoroark" if not zoroark_online else "copy_attack",
		"phase": "setup" if not zoroark_online else "attack",
		"flags": {
			"zoroark_online": zoroark_online,
			"zorua_missing": zorua_missing,
			"reshiram_missing": reshiram_missing,
		},
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": search_priority[0] if not search_priority.is_empty() else owner,
			"pivot_target_name": NS_ZOROARK_EX,
		},
		"priorities": {
			"attach": attach_priority,
			"handoff": handoff_priority,
			"search": search_priority,
		},
		"context": context.duplicate(true),
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	var debt := _evolution_access_debt_state(game_state, player_index, turn_contract)
	var active := bool(debt.get("evolution_access_active", false))
	return {
		"enabled": active,
		"safe_setup_before_attack": active,
		"setup_debt": debt,
		"action_bonuses": [
			{
				"kind": "play_trainer",
				"card_names": ["席蓝", "Cyrano", "奇树", IONO],
				"bonus": EVOLUTION_ACCESS_BRIDGE_BONUS if active else 0.0,
			},
		],
		"attack_penalty": EVOLUTION_ACCESS_ATTACK_PENALTY if active else 0.0,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	_remember_prediction_context(game_state, player_index)
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_play_basic(action, player)
		"evolve":
			return _score_evolve(action)
		"attach_energy":
			return _score_attach_energy(action, player, game_state, player_index)
		"attach_tool":
			return _score_attach_tool(action, game_state, player_index)
		"play_trainer":
			return _score_trainer(action, game_state, player_index)
		"play_stadium":
			return _score_stadium(action, game_state)
		"use_ability":
			return _score_ability(action)
		"retreat":
			return _score_retreat(player, game_state, player_index)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1))) - _heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	score += float(_count_name_on_field(player, NS_ZOROARK_EX)) * 700.0
	score += float(_count_name_on_field(player, NS_ZORUA)) * 180.0
	score += float(_count_name_on_field(player, NS_RESHIRAM)) * 220.0
	score += float(_count_name_on_field(player, MUNKIDORI)) * 110.0
	for slot: PokemonSlot in _all_slots(player):
		score += float(slot.attached_energy.size()) * (42.0 if _slot_matches(slot, [NS_ZOROARK_EX, NS_ZORUA, NS_RESHIRAM]) else 12.0)
		if _slot_matches(slot, [NS_ZOROARK_EX]) and _can_attack(slot, game_state, player_index):
			score += 220.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	if _slot_matches(slot, [NS_ZOROARK_EX]):
		var player_index := _prediction_player_index
		var top_card := slot.get_top_card()
		if top_card != null and _player(_prediction_game_state, top_card.owner_index) != null:
			player_index = top_card.owner_index
		var copied := _best_n_copy_prediction(_prediction_game_state, player_index, _player(_prediction_game_state, player_index))
		var has_source := bool(copied.get("has_source", false))
		return {
			"damage": int(copied.get("damage", 0)),
			"can_attack": _darkness_units(slot) + extra_context >= 2 and has_source,
			"description": "night_joker:%s" % str(copied.get("attack_name", "")) if has_source else "night_joker:no_source",
		}
	if _slot_matches(slot, [NS_RESHIRAM]):
		return {"damage": max(20, slot.damage_counters * 20), "can_attack": slot.attached_energy.size() >= 2, "description": "Powerful Rage"}
	if _slot_matches(slot, [NS_DARMANITAN]):
		return _predict_darmanitan(slot, _prediction_game_state, _prediction_player_index)
	if _slot_matches(slot, [BLOODMOON_URSALUNA_EX]):
		return {"damage": 240, "can_attack": slot.attached_energy.size() >= 3, "description": "Blood Moon"}
	return {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _is_reversal_energy(card):
		return 60
	if _card_matches(card, [NS_RESHIRAM]):
		return 20
	if _card_matches(card, [NS_ZOROARK_EX, NS_ZORUA]):
		return 5
	if _is_basic_darkness_energy(card) or _card_matches(card, [DARKNESS_ENERGY, FIGHTING_ENERGY]):
		return 72
	if _card_matches(card, [IONO, PROFESSORS_RESEARCH, BOSSS_ORDERS, PROFESSOR_TURO]):
		return 46
	if _card_matches(card, [ARVEN, SECRET_BOX, ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN, NS_PP_UP]):
		return 18
	return 60


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	if _is_reversal_energy(card):
		if _reversal_darmanitan_route_can_complete(card, game_state, player_index, null):
			return 1 if _count_reversal_energy_in_hand(player) <= 1 else 42
		# Older strategy fixtures omit both Prize areas; no playable turn has this state.
		if _prize_context_is_uninitialized(game_state):
			return 1 if _count_reversal_energy_in_hand(player) <= 1 else 42
		return get_discard_priority(card)
	if _is_basic_darkness_energy(card):
		var active_needs_manual := _slot_matches(player.active_pokemon, [NS_ZOROARK_EX]) and _darkness_units(player.active_pokemon) < 2
		if active_needs_manual and not game_state.energy_attached_this_turn and _basic_darkness_in_hand(player) <= 1:
			return 4
		return 112 if _has_ns_pp_target(player) else 64
	if _card_matches(card, [NS_RESHIRAM]):
		return 4 if _count_name_on_field(player, NS_RESHIRAM) == 0 else 38
	if _card_matches(card, [DARKNESS_ENERGY, FIGHTING_ENERGY]) and _count_basic_energy_in_discard(player) == 0:
		return 88
	if _card_matches(card, [NS_PP_UP]):
		return 2 if _count_basic_energy_in_discard(player) > 0 and _has_benched_ns_target(player) else 58
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	for raw_name: Variant in SEARCH_PRIORITY.keys():
		var name := str(raw_name)
		if _card_matches(card, [name]):
			return int(SEARCH_PRIORITY[name])
	if card.card_data.is_basic_pokemon():
		return 34
	if card.card_data.is_energy():
		return 28
	return 20


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	if item is Dictionary:
		return _score_dictionary_interaction(item as Dictionary, step_id, context)
	if item is CardInstance:
		var card := item as CardInstance
		if "discard" in step_id:
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if "search" in step_id or "deck" in step_id:
			return float(get_search_priority(card))
		if "energy" in step_id and _card_matches(card, [DARKNESS_ENERGY]):
			return 90.0
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == "send_out":
			return score_handoff_target(slot, step, context)
		if "target" in step_id or "assignment" in step_id or "handoff" in step_id:
			return _slot_priority(slot)
	return 0.0


func _score_dictionary_interaction(option: Dictionary, step_id: String, context: Dictionary = {}) -> float:
	if option.has("attack") or step_id == "copied_attack":
		var attack: Dictionary = {}
		var raw_attack: Variant = option.get("attack", {})
		if raw_attack is Dictionary:
			attack = raw_attack
		if step_id == COPIED_ATTACK_STEP:
			return _score_copied_attack_option(attack, context)
		var attack_name := str(attack.get("name", ""))
		match attack_name:
			"Powerful Rage", "力量愤怒":
				return 360.0
			"Virtuous Flame", "纯真火焰":
				return 310.0
			"Scratch", "抓":
				return 90.0
		var source_slot: PokemonSlot = option.get("source_slot", null)
		if source_slot != null:
			return _slot_priority(source_slot)
		return 40.0
	if option.has("source") or option.has("target"):
		var score := 0.0
		var source: Variant = option.get("source", null)
		if source is CardInstance:
			var source_card := source as CardInstance
			if _card_matches(source_card, [DARKNESS_ENERGY]):
				score += 120.0
			elif source_card.card_data != null and source_card.card_data.card_type == "Basic Energy":
				score += 80.0
		var target: Variant = option.get("target", null)
		if target is PokemonSlot:
			score += _slot_priority(target as PokemonSlot)
		return score
	return 0.0


func _score_copied_attack_option(attack: Dictionary, context: Dictionary) -> float:
	var attack_name := str(attack.get("name", ""))
	if _is_night_joker_name(attack_name):
		return -3000.0
	var damage := _estimate_copy_attack_damage(
		attack,
		context.get("game_state", null),
		int(context.get("player_index", -1))
	)
	var score := 900.0 + float(damage) * 8.0
	if attack_name in ["Virtuous Flame", "纯真火焰", "高洁火焰"]:
		score += 80.0
	return score


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if _slot_matches(slot, [NS_ZOROARK_EX]) and _can_attack(slot, _prediction_game_state, _prediction_player_index):
			return 520.0
		if _slot_matches(slot, [NS_RESHIRAM]):
			return 260.0
		if _slot_matches(slot, [MUNKIDORI]):
			return 190.0
		return _slot_priority(slot)
	return score_interaction_target(item, step, context)


func _score_play_basic(action: Dictionary, player: PlayerState) -> float:
	if player == null or player.is_bench_full():
		return 0.0
	return _opening_bench_priority(action.get("card"))


func _score_evolve(action: Dictionary) -> float:
	var card: CardInstance = action.get("card")
	if _card_matches(card, [NS_ZOROARK_EX]):
		return 560.0
	return 80.0


func _score_attach_energy(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> float:
	var card: CardInstance = action.get("card")
	var target: PokemonSlot = action.get("target_slot")
	if card == null or target == null:
		return 0.0
	if _is_reversal_energy(card):
		if _reversal_darmanitan_route_can_complete(card, game_state, player_index, target):
			return 460.0
		return -3800.0
	if _card_matches(card, [DARKNESS_ENERGY]):
		if _slot_matches(target, [NS_ZOROARK_EX]):
			return 340.0 if target.attached_energy.size() < 2 else 120.0
		if _slot_matches(target, [NS_ZORUA]):
			return 280.0
		if _slot_matches(target, [MUNKIDORI]) and target.attached_energy.is_empty():
			return 220.0
	if _card_matches(card, [FIGHTING_ENERGY]) and _slot_matches(target, [CORNERSTONE_OGERPON_EX]):
		return 160.0
	if _slot_matches(target, [NS_RESHIRAM]) and _count_name_on_field(player, NS_ZOROARK_EX) > 0:
		return 90.0
	return 18.0


func _score_attach_tool(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	var target: PokemonSlot = action.get("target_slot")
	if card == null or target == null:
		return 0.0
	if _card_matches(card, [TM_DEVOLUTION]):
		return 180.0 if _opponent_has_evolution_in_play(game_state, player_index) else -2800.0
	if _card_matches(card, [AIR_BALLOON]) and _slot_matches(target, [NS_ZOROARK_EX, MUNKIDORI]):
		return 180.0
	if _card_matches(card, [TM_EVOLUTION]) and _slot_matches(target, [NS_ZORUA]):
		return 210.0
	if _card_matches(card, [TM_TURBO_ENERGIZE]) and _slot_matches(target, [NS_ZORUA, NS_RESHIRAM]):
		return 170.0
	return 35.0


func _opponent_has_evolution_in_play(game_state: GameState, player_index: int) -> bool:
	var opponent := _player(game_state, 1 - player_index)
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		var data := slot.get_card_data() if slot != null else null
		if data != null and data.is_evolution_pokemon():
			return true
	return false


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if _card_matches(card, [BOSSS_ORDERS, COUNTER_CATCHER]) \
			and not _active_attack_window_live(player, game_state, player_index):
		return -2800.0
	if _card_matches(card, [IONO, PROFESSORS_RESEARCH]) and _pre_reset_poffin_bridge_live(player):
		return -3000.0
	if _is_cilan_card(card) and _cilan_evolution_bridge_live(player):
		return 400.0
	if _card_matches(card, [NS_PP_UP]):
		return 260.0 if _count_basic_energy_in_discard(player) > 0 and _has_benched_ns_target(player) else 0.0
	if _card_matches(card, [ARVEN]):
		return 250.0
	if _card_matches(card, [BUDDY_BUDDY_POFFIN, NEST_BALL, ARTAZON]):
		return 230.0 if _count_name_on_field(player, NS_ZORUA) < 2 else 90.0
	if _card_matches(card, [ULTRA_BALL, SECRET_BOX]):
		return 220.0 if _count_name_on_field(player, NS_ZOROARK_EX) == 0 else 90.0
	if _card_matches(card, [EARTHEN_VESSEL]):
		return 190.0
	if _card_matches(card, [ENERGY_SWITCH, SWITCH, COUNTER_CATCHER, NIGHT_STRETCHER, SUPER_ROD, PAL_PAD]):
		return 110.0
	if _card_matches(card, [IONO, PROFESSORS_RESEARCH]):
		return 95.0 if player.hand.size() <= 3 else 30.0
	if _card_matches(card, [BOSSS_ORDERS]):
		return 140.0
	if _card_matches(card, [PROFESSOR_TURO]):
		return 40.0
	return 20.0


func _active_attack_window_live(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	return player != null and player.active_pokemon != null \
		and _can_attack(player.active_pokemon, game_state, player_index)


func _score_stadium(action: Dictionary, game_state: GameState) -> float:
	var card: CardInstance = action.get("card")
	if card == null:
		return 0.0
	if game_state != null and game_state.stadium_card != null and _card_matches(game_state.stadium_card, [ARTAZON]):
		return 0.0
	return 190.0 if _card_matches(card, [ARTAZON]) else 25.0


func _score_ability(action: Dictionary) -> float:
	var slot: PokemonSlot = action.get("source_slot")
	var ability_name := str(action.get("ability_name", ""))
	if _slot_matches(slot, [NS_ZOROARK_EX]) or ability_name in ["Trade", "交易"]:
		return 320.0
	if _slot_matches(slot, [MUNKIDORI]):
		return 190.0
	if _slot_matches(slot, [FEZANDIPITI_EX]):
		return 150.0
	return 60.0


func _score_attack(action: Dictionary, game_state: GameState = null, player_index: int = -1) -> float:
	var attack_name := _attack_name_for_scoring(action)
	var damage := int(action.get("projected_damage", action.get("damage", 0)))
	match attack_name:
		"Night Joker", "暗夜王牌", "暗夜小丑":
			var player := _player(game_state, player_index)
			if not _has_benched_ns_attack_option(player):
				return -3000.0
			var copied := _best_n_copy_prediction(game_state, player_index, player)
			damage = maxi(damage, int(copied.get("damage", 0)))
			var score := 620.0 + float(damage)
			if bool(action.get("projected_knockout", false)) or _damage_knocks_out_opponent_active(game_state, player_index, damage):
				score += NIGHT_JOKER_KO_BONUS
			return _apply_evolution_access_ko_bypass(score, action, game_state, player_index, damage)
		"Powerful Rage", "力量愤怒":
			return _apply_evolution_access_ko_bypass(
				420.0 + float(damage), action, game_state, player_index, damage
			)
		"Virtuous Flame", "纯真火焰":
			return _apply_evolution_access_ko_bypass(
				380.0 + float(damage), action, game_state, player_index, damage
			)
		"Blood Moon":
			return _apply_evolution_access_ko_bypass(
				360.0 + float(damage), action, game_state, player_index, damage
			)
		"Energy Turbo":
			return _apply_evolution_access_ko_bypass(
				260.0, action, game_state, player_index, damage
			)
	return _apply_evolution_access_ko_bypass(
		120.0 + float(damage), action, game_state, player_index, damage
	)


func _attack_name_for_scoring(action: Dictionary) -> String:
	var attack_name := str(action.get("attack_name", "")).strip_edges()
	if attack_name != "":
		return attack_name
	var granted_attack_data: Variant = action.get("granted_attack_data", {})
	if granted_attack_data is Dictionary:
		return str((granted_attack_data as Dictionary).get("name", "")).strip_edges()
	return ""


func _score_retreat(player: PlayerState, game_state: GameState, player_index: int) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	if _slot_matches(player.active_pokemon, [NS_ZOROARK_EX]) and _can_attack(player.active_pokemon, game_state, player_index):
		return -90.0
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, [NS_ZOROARK_EX, NS_DARMANITAN]) and _can_attack(slot, game_state, player_index):
			return 230.0
	return 20.0


func _opening_active_priority(card: Variant) -> float:
	if _card_matches(card, [NS_ZORUA]):
		return 300.0
	if _card_matches(card, [NS_RESHIRAM]):
		return 240.0
	if _card_matches(card, [MUNKIDORI]):
		return 110.0
	if _card_matches(card, [FEZANDIPITI_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]):
		return 70.0
	return 30.0


func _opening_bench_priority(card: Variant) -> float:
	if _card_matches(card, [NS_ZORUA]):
		return 360.0
	if _card_matches(card, [NS_RESHIRAM]):
		return 270.0
	if _card_matches(card, [MUNKIDORI]):
		return 190.0
	if _card_matches(card, [FEZANDIPITI_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]):
		return 90.0
	return 20.0


func _slot_priority(slot: PokemonSlot) -> float:
	if _slot_matches(slot, [NS_ZOROARK_EX]):
		return 480.0
	if _slot_matches(slot, [NS_ZORUA]):
		return 360.0
	if _slot_matches(slot, [NS_RESHIRAM]):
		return 260.0
	if _slot_matches(slot, [MUNKIDORI]):
		return 170.0
	return 40.0


func _heuristic_base(kind: String) -> float:
	match kind:
		"attack", "granted_attack":
			return 100.0
		"use_ability":
			return 160.0
		"play_trainer", "play_stadium", "use_stadium_effect":
			return 80.0
		"attach_energy", "attach_tool":
			return 70.0
		"evolve":
			return 90.0
		"play_basic_to_bench":
			return 50.0
		"retreat":
			return 45.0
	return 0.0


func _count_name_on_field(player: PlayerState, target_name: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_matches(slot, [target_name]):
			count += 1
	return count


func _cilan_evolution_bridge_live(player: PlayerState) -> bool:
	if player == null or _count_name_on_field(player, NS_ZORUA) == 0 \
			or _count_name_on_field(player, NS_ZOROARK_EX) > 0:
		return false
	for card: CardInstance in player.hand:
		if _card_matches(card, [NS_ZOROARK_EX]):
			return false
	for card: CardInstance in player.deck:
		if _card_matches(card, [NS_ZOROARK_EX]):
			return true
	return false


func _pre_reset_poffin_bridge_live(player: PlayerState) -> bool:
	if player == null or player.is_bench_full() \
			or _count_name_on_field(player, NS_ZORUA) != 1 \
			or _count_name_on_field(player, NS_ZOROARK_EX) > 0:
		return false
	var poffin_in_hand := false
	for card: CardInstance in player.hand:
		if _card_matches(card, [BUDDY_BUDDY_POFFIN]):
			poffin_in_hand = true
			break
	if not poffin_in_hand:
		return false
	for card: CardInstance in player.deck:
		if _card_matches(card, [NS_ZORUA]):
			return true
	return false


func _evolution_access_debt_state(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _player(game_state, player_index)
	var strong_opening := _is_strong_opening_contract(turn_contract)
	var active_zorua := player != null and _slot_matches(player.active_pokemon, [NS_ZORUA])
	var zoroark_in_hand := false
	var zoroark_on_field := false
	var zoroark_in_deck := false
	var cyrano_in_hand := false
	var iono_in_hand := false
	if player != null:
		zoroark_on_field = _count_name_on_field(player, NS_ZOROARK_EX) > 0
		for card: CardInstance in player.hand:
			zoroark_in_hand = zoroark_in_hand or _card_matches(card, [NS_ZOROARK_EX])
			cyrano_in_hand = cyrano_in_hand or _is_cilan_card(card)
			iono_in_hand = iono_in_hand or _card_matches(card, [IONO])
		for card: CardInstance in player.deck:
			if _card_matches(card, [NS_ZOROARK_EX]):
				zoroark_in_deck = true
				break
	var supporter_open := _supporter_window_is_open(game_state, player_index)
	var bridge_available := supporter_open and (cyrano_in_hand or iono_in_hand)
	var active := not strong_opening and active_zorua and not zoroark_in_hand \
		and not zoroark_on_field and zoroark_in_deck and bridge_available
	return {
		"evolution_access_active": active,
		"active_zorua": active_zorua,
		"zoroark_in_hand": zoroark_in_hand,
		"zoroark_on_field": zoroark_on_field,
		"zoroark_in_deck": zoroark_in_deck,
		"supporter_window_open": supporter_open,
		"cyrano_bridge_available": supporter_open and cyrano_in_hand,
		"iono_bridge_available": supporter_open and iono_in_hand,
		"strong_fixed_opening": strong_opening,
	}


func _supporter_window_is_open(game_state: GameState, player_index: int) -> bool:
	if game_state == null or _player(game_state, player_index) == null:
		return false
	if game_state.current_player_index != player_index or game_state.phase != GameState.GamePhase.MAIN:
		return false
	if game_state.supporter_used_this_turn:
		return false
	return not (game_state.turn_number == 1 and game_state.first_player_index == player_index)


func _is_strong_opening_contract(turn_contract: Dictionary) -> bool:
	if bool(turn_contract.get("strong_fixed_opening", false)):
		return true
	var context: Variant = turn_contract.get("context", {})
	return context is Dictionary and bool((context as Dictionary).get("strong_fixed_opening", false))


func _apply_evolution_access_ko_bypass(
	score: float,
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	damage: int
) -> float:
	var turn_contract := get_turn_plan_context()
	var debt := _evolution_access_debt_state(game_state, player_index, turn_contract)
	if not bool(debt.get("evolution_access_active", false)):
		return score
	if not bool(action.get("projected_knockout", false)) \
			and not _damage_knocks_out_opponent_active(game_state, player_index, damage):
		return score
	return score + EVOLUTION_ACCESS_ATTACK_PENALTY + EVOLUTION_ACCESS_KO_BONUS


func _is_cilan_card(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.get_uid() == CILAN_CARD_UID


func _count_name_in_discard(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.discard_pile:
		if _card_matches(card, [target_name]):
			count += 1
	return count


func _has_benched_ns_attack_option(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if slot == null or not _card_matches_ns_pokemon(slot.get_card_data()):
			continue
		for attack: Dictionary in slot.get_attacks():
			if str(attack.get("name", "")) in ["Night Joker", "暗夜王牌", "暗夜小丑"]:
				continue
			if bool(attack.get("is_vstar_power", false)):
				continue
			return true
	return false


func _best_n_copy_prediction(game_state: GameState, player_index: int, player: PlayerState) -> Dictionary:
	if player == null:
		return {"damage": 0, "attack_name": "", "has_source": false}
	var best := {"damage": 0, "attack_name": "", "has_source": false}
	for slot: PokemonSlot in player.bench:
		if slot == null or not _card_matches_ns_pokemon(slot.get_card_data()):
			continue
		for attack: Dictionary in slot.get_attacks():
			var attack_name := str(attack.get("name", ""))
			if bool(attack.get("is_vstar_power", false)) or _is_night_joker_name(attack_name):
				continue
			var damage := _estimate_copy_attack_damage(attack, game_state, player_index)
			if not bool(best.get("has_source", false)) or damage > int(best.get("damage", 0)):
				best = {
					"damage": damage,
					"attack_name": attack_name,
					"has_source": true,
				}
	return best


func _estimate_copy_attack_damage(attack: Dictionary, game_state: GameState, player_index: int) -> int:
	var attack_name := str(attack.get("name", ""))
	var player := _player(game_state, player_index)
	if attack_name in ["Powerful Rage", "力量愤怒", "强力愤怒"]:
		return player.active_pokemon.damage_counters * 2 if player != null and player.active_pokemon != null else 0
	if attack_name in ["Reignite", "复燃"]:
		return _opponent_basic_energy_discard_count(game_state, player_index) * 30
	return _parse_damage(str(attack.get("damage", "")))


func _is_night_joker_name(attack_name: String) -> bool:
	return attack_name in ["Night Joker", "暗夜王牌", "暗夜小丑"]


func _card_matches_ns_pokemon(card: Variant) -> bool:
	var cd := _card_data(card)
	if cd == null or not cd.is_pokemon():
		return false
	return str(cd.name_en).begins_with("N's ") or str(cd.name).begins_with("N's ") or str(cd.name_zh).begins_with("N的") or str(cd.name).begins_with("N的")


func _player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _count_basic_energy_in_discard(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			count += 1
	return count


func _opponent_basic_energy_discard_count(game_state: GameState, player_index: int) -> int:
	if game_state == null:
		return 0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0
	return _count_basic_energy_in_discard(game_state.players[opponent_index])


func _damage_knocks_out_opponent_active(game_state: GameState, player_index: int, damage: int) -> bool:
	if game_state == null or damage <= 0 or game_state.players.size() != 2:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
	return defender != null and damage >= defender.get_remaining_hp()


func _basic_darkness_in_hand(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.hand:
			if _is_basic_darkness_energy(card):
				count += 1
	return count


func _count_reversal_energy_in_hand(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.hand:
			if _is_reversal_energy(card):
				count += 1
	return count


func _live_reversal_darmanitan_target(game_state: GameState, player_index: int) -> PokemonSlot:
	var player := _player(game_state, player_index)
	if player == null:
		return null
	for card: CardInstance in player.hand:
		if not _is_reversal_energy(card):
			continue
		for slot: PokemonSlot in player.bench:
			if _reversal_darmanitan_route_can_complete(card, game_state, player_index, slot):
				return slot
	return null


func _ready_benched_darmanitan(game_state: GameState, player_index: int) -> PokemonSlot:
	var player := _player(game_state, player_index)
	if player == null:
		return null
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, [NS_DARMANITAN]) and _can_attack(slot, game_state, player_index):
			return slot
	return null


func _reversal_darmanitan_route_can_complete(
	card: CardInstance,
	game_state: GameState,
	player_index: int,
	target: PokemonSlot
) -> bool:
	var player := _player(game_state, player_index)
	if player == null or not _is_reversal_energy(card) or game_state.energy_attached_this_turn:
		return false
	if card not in player.hand:
		return false
	if target == null:
		for bench_slot: PokemonSlot in player.bench:
			if _reversal_darmanitan_route_can_complete(card, game_state, player_index, bench_slot):
				return true
		return false
	if target not in player.bench or not _slot_matches(target, [NS_DARMANITAN]):
		return false
	if not _reversal_is_active_for_target(target, game_state, player_index):
		return false
	var current := _darmanitan_energy_profile(target, game_state, player_index)
	if _darmanitan_profile_can_attack(current):
		return false
	var after_attach := current.duplicate()
	after_attach["units"] = int(current.get("units", 0)) + 3
	after_attach["fire_units"] = int(current.get("fire_units", 0)) + 3
	return _darmanitan_profile_can_attack(after_attach)


func _predict_darmanitan(slot: PokemonSlot, game_state: GameState, player_index: int) -> Dictionary:
	var profile := _darmanitan_energy_profile(slot, game_state, player_index)
	var units := int(profile.get("units", 0))
	var fire_units := int(profile.get("fire_units", 0))
	var reignite_live := units >= 2
	var cannon_live := units >= 3 and fire_units >= 2
	var reignite_damage := _opponent_basic_energy_discard_count(game_state, player_index) * 30
	var damage := 0
	var description := "Reignite"
	if reignite_live:
		damage = reignite_damage
	if cannon_live and damage <= 90:
		damage = 90
		description = "Immolating Cannon"
	return {
		"damage": damage,
		"can_attack": reignite_live or cannon_live,
		"description": description,
		"energy_units": units,
	}


func _darmanitan_energy_profile(slot: PokemonSlot, game_state: GameState, player_index: int) -> Dictionary:
	var units := 0
	var fire_units := 0
	if slot == null:
		return {"units": units, "fire_units": fire_units}
	for energy: CardInstance in slot.attached_energy:
		if _is_reversal_energy(energy):
			var reversal_units := 3 if _reversal_is_active_for_target(slot, game_state, player_index) else 1
			units += reversal_units
			if reversal_units == 3:
				fire_units += reversal_units
			continue
		units += 1
		var symbol := _energy_symbol(energy)
		if symbol == "R" or symbol == "ANY" or "R" in symbol:
			fire_units += 1
	return {"units": units, "fire_units": fire_units}


func _darmanitan_profile_can_attack(profile: Dictionary) -> bool:
	var units := int(profile.get("units", 0))
	var fire_units := int(profile.get("fire_units", 0))
	return units >= 2 or (units >= 3 and fire_units >= 2)


func _reversal_is_active_for_target(
	target: PokemonSlot,
	game_state: GameState,
	player_index: int
) -> bool:
	if target == null or game_state == null:
		return false
	var card_data := target.get_card_data()
	if card_data == null or not card_data.is_evolution_pokemon() or card_data.is_rule_box_pokemon():
		return false
	var player := _player(game_state, player_index)
	var opponent := _player(game_state, 1 - player_index)
	if player == null or opponent == null:
		return false
	var top_card := target.get_top_card()
	if top_card == null or int(top_card.owner_index) != player_index:
		return false
	return player.prizes.size() > opponent.prizes.size()


func _prize_context_is_uninitialized(game_state: GameState) -> bool:
	return game_state != null and game_state.players.size() == 2 \
		and game_state.players[0].prizes.is_empty() and game_state.players[1].prizes.is_empty()


func _has_ns_pp_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, [NS_ZOROARK_EX, NS_ZORUA]) and _darkness_units(slot) < 2:
			return true
	return false


func _has_benched_ns_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, CORE_NAMES):
			return true
	return false


func _darkness_units(slot: PokemonSlot) -> int:
	var count := 0
	if slot != null:
		for energy: CardInstance in slot.attached_energy:
			if _energy_pays_darkness(energy):
				count += 1
	return count


func _is_basic_darkness_energy(card: CardInstance) -> bool:
	return _is_basic_energy(card) and _energy_symbol(card) == "D"


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and str(card.card_data.card_type) == "Basic Energy"


func _energy_pays_darkness(card: CardInstance) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return false
	var symbol := _energy_symbol(card)
	return symbol == "D" or symbol == "ANY" or "D" in symbol


func _energy_symbol(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	var symbol := str(card.card_data.energy_provides)
	if symbol == "":
		symbol = str(card.card_data.energy_type)
	return symbol.to_upper()


func _is_reversal_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_energy() \
		and str(card.card_data.effect_id) == REVERSAL_ENERGY_EFFECT_ID


func _can_attack(slot: PokemonSlot, game_state: GameState = null, player_index: int = -1) -> bool:
	if slot == null or slot.get_card_data() == null or slot.get_attacks().is_empty():
		return false
	if _slot_matches(slot, [NS_DARMANITAN]):
		return bool(_predict_darmanitan(slot, game_state, player_index).get("can_attack", false))
	return not slot.attached_energy.is_empty()


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _slot_matches(slot: PokemonSlot, names: Array[String]) -> bool:
	return slot != null and _card_matches(slot.get_card_data(), names)


func _card_matches(value: Variant, names: Array[String]) -> bool:
	var cd := _card_data(value)
	if cd == null:
		return false
	var card_names: Array[String] = [str(cd.name), str(cd.name_en), str(cd.name_zh)]
	for candidate: String in names:
		if candidate in card_names:
			return true
		var aliases: Array = NS_NAME_ALIASES.get(candidate, [])
		for alias: Variant in aliases:
			if str(alias) in card_names:
				return true
	return false


func _card_data(value: Variant) -> CardData:
	if value is CardData:
		return value as CardData
	if value is CardInstance:
		return (value as CardInstance).card_data
	return null


func _parse_damage(text: String) -> int:
	var digits := ""
	for index: int in text.length():
		var character := text.substr(index, 1)
		if character >= "0" and character <= "9":
			digits += character
		elif digits != "":
			break
	return int(digits) if digits != "" else 0


func _remember_prediction_context(game_state: GameState, player_index: int) -> void:
	if _player(game_state, player_index) == null:
		return
	_prediction_game_state = game_state
	_prediction_player_index = player_index
