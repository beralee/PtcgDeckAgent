class_name DeckStrategyNsZoroark
extends "res://scripts/ai/DeckStrategyBase.gd"


const STRATEGY_ID := "ns_zoroark"

const NS_ZORUA := "N's Zorua"
const NS_ZOROARK_EX := "N's Zoroark ex"
const NS_RESHIRAM := "N's Reshiram"
const NS_PP_UP := "N's PP Up"
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
const AIR_BALLOON := "Air Balloon"
const ARTAZON := "Artazon"

const DARKNESS_ENERGY := "Darkness Energy"
const FIGHTING_ENERGY := "Fighting Energy"

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


func get_strategy_id() -> String:
	return STRATEGY_ID


func get_signature_names() -> Array[String]:
	return [NS_ZORUA, NS_ZOROARK_EX, NS_RESHIRAM, NS_PP_UP]


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
	var player: PlayerState = game_state.players[player_index]
	var zoroark_online := _count_name_on_field(player, NS_ZOROARK_EX) > 0
	var zorua_missing := _count_name_on_field(player, NS_ZORUA) + _count_name_on_field(player, NS_ZOROARK_EX) == 0
	var reshiram_missing := _count_name_on_field(player, NS_RESHIRAM) == 0
	var owner := NS_ZOROARK_EX if zoroark_online else NS_ZORUA
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
			"attach": [NS_ZOROARK_EX, NS_ZORUA, NS_RESHIRAM, MUNKIDORI],
			"handoff": [NS_ZOROARK_EX, NS_RESHIRAM, MUNKIDORI],
			"search": search_priority,
		},
		"context": context.duplicate(true),
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_play_basic(action, player)
		"evolve":
			return _score_evolve(action)
		"attach_energy":
			return _score_attach_energy(action, player)
		"attach_tool":
			return _score_attach_tool(action)
		"play_trainer":
			return _score_trainer(action, game_state, player_index)
		"play_stadium":
			return _score_stadium(action, game_state)
		"use_ability":
			return _score_ability(action)
		"retreat":
			return _score_retreat(player)
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
		if _slot_matches(slot, [NS_ZOROARK_EX]) and _can_attack(slot):
			score += 220.0
	return score


func predict_attacker_damage(slot: PokemonSlot, _extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	if _slot_matches(slot, [NS_ZOROARK_EX]):
		return {"damage": 170, "can_attack": slot.attached_energy.size() >= 2, "description": "Night Joker"}
	if _slot_matches(slot, [NS_RESHIRAM]):
		return {"damage": max(20, slot.damage_counters * 20), "can_attack": slot.attached_energy.size() >= 2, "description": "Powerful Rage"}
	if _slot_matches(slot, [BLOODMOON_URSALUNA_EX]):
		return {"damage": 240, "can_attack": slot.attached_energy.size() >= 3, "description": "Blood Moon"}
	return {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _card_matches(card, [NS_RESHIRAM]):
		return 20
	if _card_matches(card, [NS_ZOROARK_EX, NS_ZORUA]):
		return 5
	if _card_matches(card, [DARKNESS_ENERGY, FIGHTING_ENERGY]):
		return 72
	if _card_matches(card, [IONO, PROFESSORS_RESEARCH, BOSSS_ORDERS, PROFESSOR_TURO]):
		return 46
	if _card_matches(card, [ARVEN, SECRET_BOX, ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN]):
		return 18
	return 60


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	if _card_matches(card, [NS_RESHIRAM]):
		return 4 if _count_name_on_field(player, NS_RESHIRAM) == 0 else 38
	if _card_matches(card, [DARKNESS_ENERGY, FIGHTING_ENERGY]) and _count_basic_energy_in_discard(player) == 0:
		return 88
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
	if item is Dictionary:
		return _score_dictionary_interaction(item as Dictionary, step_id)
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


func _score_dictionary_interaction(option: Dictionary, step_id: String) -> float:
	if option.has("attack") or step_id == "copied_attack":
		var attack: Dictionary = {}
		var raw_attack: Variant = option.get("attack", {})
		if raw_attack is Dictionary:
			attack = raw_attack
		var attack_name := str(attack.get("name", ""))
		match attack_name:
			"Powerful Rage":
				return 360.0
			"Virtuous Flame":
				return 310.0
			"Scratch":
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


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if _slot_matches(slot, [NS_ZOROARK_EX]) and _can_attack(slot):
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
	var target: PokemonSlot = action.get("target_slot")
	if _card_matches(card, [NS_ZOROARK_EX]) and _slot_matches(target, [NS_ZORUA]):
		return 560.0
	return 80.0


func _score_attach_energy(action: Dictionary, player: PlayerState) -> float:
	var card: CardInstance = action.get("card")
	var target: PokemonSlot = action.get("target_slot")
	if card == null or target == null:
		return 0.0
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


func _score_attach_tool(action: Dictionary) -> float:
	var card: CardInstance = action.get("card")
	var target: PokemonSlot = action.get("target_slot")
	if card == null or target == null:
		return 0.0
	if _card_matches(card, [AIR_BALLOON]) and _slot_matches(target, [NS_ZOROARK_EX, MUNKIDORI]):
		return 180.0
	if _card_matches(card, [TM_EVOLUTION]) and _slot_matches(target, [NS_ZORUA]):
		return 210.0
	if _card_matches(card, [TM_TURBO_ENERGIZE]) and _slot_matches(target, [NS_ZORUA, NS_RESHIRAM]):
		return 170.0
	return 35.0


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
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
	if _slot_matches(slot, [NS_ZOROARK_EX]) or ability_name == "Trade":
		return 320.0
	if _slot_matches(slot, [MUNKIDORI]):
		return 190.0
	if _slot_matches(slot, [FEZANDIPITI_EX]):
		return 150.0
	return 60.0


func _score_attack(action: Dictionary, game_state: GameState = null, player_index: int = -1) -> float:
	var attack_name := str(action.get("attack_name", ""))
	var damage := int(action.get("projected_damage", action.get("damage", 0)))
	match attack_name:
		"Night Joker":
			var player := _player(game_state, player_index)
			if not _has_benched_ns_attack_option(player):
				return 80.0 + float(damage)
			return 620.0 + float(damage)
		"Powerful Rage":
			return 420.0 + float(damage)
		"Virtuous Flame":
			return 380.0 + float(damage)
		"Blood Moon":
			return 360.0 + float(damage)
		"Energy Turbo":
			return 260.0
	return 120.0 + float(damage)


func _score_retreat(player: PlayerState) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	if _slot_matches(player.active_pokemon, [NS_ZOROARK_EX]) and _can_attack(player.active_pokemon):
		return -90.0
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, [NS_ZOROARK_EX]) and _can_attack(slot):
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
			if str(attack.get("name", "")) == "Night Joker":
				continue
			if bool(attack.get("is_vstar_power", false)):
				continue
			return true
	return false


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


func _has_benched_ns_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, CORE_NAMES):
			return true
	return false


func _can_attack(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null and not slot.get_attacks().is_empty() and slot.attached_energy.size() > 0


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
	var localized := str(cd.name)
	var english := str(cd.name_en)
	for candidate: String in names:
		if candidate == localized or candidate == english:
			return true
	return false


func _card_data(value: Variant) -> CardData:
	if value is CardData:
		return value as CardData
	if value is CardInstance:
		return (value as CardInstance).card_data
	return null
