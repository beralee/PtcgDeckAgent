class_name DeckStrategyDragapultDusknoir
extends "res://scripts/ai/DeckStrategyBase.gd"


const STRATEGY_ID := "dragapult_dusknoir"
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const DragapultDusknoirStateEncoderScript = preload("res://scripts/ai/DragapultDusknoirStateEncoder.gd")

var _value_net: RefCounted = null
var _encoder_class: GDScript = DragapultDusknoirStateEncoderScript

const DREEPY := "Dreepy"
const DRAKLOAK := "Drakloak"
const DRAGAPULT_EX := "Dragapult ex"
const DUSKULL := "Duskull"
const DUSCLOPS := "Dusclops"
const DUSKNOIR := "Dusknoir"
const TATSUGIRI := "Tatsugiri"
const ROTOM_V := "Rotom V"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const RADIANT_ALAKAZAM := "Radiant Alakazam"
const MIRAIDON_EX := "Miraidon ex"
const IRON_HANDS_EX := "Iron Hands ex"
const RAIKOU_V := "Raikou V"
const RAICHU_V := "Raichu V"
const SQUAWKABILLY_EX := "Squawkabilly ex"

const ARVEN := "Arven"
const IONO := "Iono"
const ROXANNE := "Roxanne"
const BOSSS_ORDERS := "Boss's Orders"
const MELA := "Mela"
const RARE_CANDY := "Rare Candy"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const SWITCH := "Switch"
const EARTHEN_VESSEL := "Earthen Vessel"
const COUNTER_CATCHER := "Counter Catcher"
const NIGHT_STRETCHER := "Night Stretcher"
const RESCUE_BOARD := "Rescue Board"
const SPARKLING_CRYSTAL := "Sparkling Crystal"
const FOREST_SEAL_STONE := "Forest Seal Stone"
const FOREST_SEAL_STONE_EFFECT_ID := "9fa9943ccda36f417ac3cb675177c216"
const TM_DEVOLUTION := "Technical Machine: Devolution"
const TEMPLE_OF_SINNOH := "Temple of Sinnoh"

const SEARCH_PRIORITY := {
	DRAGAPULT_EX: 100,
	DRAKLOAK: 94,
	DREEPY: 88,
	DUSKNOIR: 78,
	DUSCLOPS: 70,
	DUSKULL: 64,
	TATSUGIRI: 42,
	ROTOM_V: 38,
	LUMINEON_V: 30,
	FEZANDIPITI_EX: 26,
	RADIANT_ALAKAZAM: 18,
}


func get_strategy_id() -> String:
	return STRATEGY_ID


func get_signature_names() -> Array[String]:
	return [DRAGAPULT_EX, DRAKLOAK, DREEPY, DUSKNOIR, DUSKULL]


func get_state_encoder_class() -> GDScript:
	return _encoder_class


func load_value_net(path: String) -> bool:
	var net := NeuralNetInferenceScript.new()
	if net.load_weights(path):
		_value_net = net
		return true
	_value_net = null
	return false


func get_value_net() -> RefCounted:
	return _value_net


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 4,
		"time_budget_ms": 1200,
		"rollouts_per_sequence": 0,
	}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var has_dragapult: bool = _count_name(player, DRAGAPULT_EX) > 0
	var ready_dragapult := _best_ready_dragapult_slot(player)
	var ready_dragapult_live: bool = ready_dragapult != null
	var dragapult_shell_ready: bool = _count_name(player, DREEPY) > 0 or _count_name(player, DRAKLOAK) > 0
	var support_shell_ready: bool = _count_name(player, DUSKULL) > 0
	var shell_ready: bool = has_dragapult or dragapult_shell_ready
	var candy_dragapult_live: bool = _rare_candy_dragapult_live(player)
	var first_dragapult_window: bool = not has_dragapult and candy_dragapult_live
	var immediate_attack_window: bool = _has_immediate_attack_window(player)
	var devolution_window: bool = _has_real_devolution_window(game_state, player_index)
	var miraidon_pressure: bool = _is_miraidon_pressure_matchup(opponent)
	var launch_pivot_name: String = _launch_pivot_name(player)
	var intent := "launch_shell"
	if ready_dragapult_live:
		intent = "convert_attack" if immediate_attack_window else "bridge_to_attack"
	elif has_dragapult:
		intent = "rebuild_dragapult" if _count_name(player, DREEPY) == 0 and _count_name(player, DRAKLOAK) == 0 else "bridge_to_attack"
	elif dragapult_shell_ready:
		intent = "force_first_dragapult"
	elif first_dragapult_window:
		intent = "force_first_dragapult"
	else:
		intent = "launch_shell"
	var flags := {
		"launch_shell": intent == "launch_shell",
		"force_first_dragapult": intent == "force_first_dragapult",
		"bridge_to_attack": intent == "bridge_to_attack",
		"convert_attack": intent == "convert_attack",
		"rebuild_dragapult": intent == "rebuild_dragapult",
		"miraidon_pressure": miraidon_pressure,
		"devolution_window": devolution_window,
		"immediate_attack_window": immediate_attack_window,
		"shell_ready": shell_ready,
		"support_shell_ready": support_shell_ready,
		"launch_pivot_active": launch_pivot_name != "" and _slot_name(player.active_pokemon) == launch_pivot_name,
	}
	var primary_attacker_name := DRAGAPULT_EX if ready_dragapult_live or has_dragapult or first_dragapult_window else DREEPY
	var bridge_target_name := DRAGAPULT_EX if intent in ["force_first_dragapult", "bridge_to_attack", "rebuild_dragapult"] else DREEPY
	var priorities := {
		"attach": [DRAGAPULT_EX, DRAKLOAK, DREEPY],
		"handoff": [DRAGAPULT_EX, DUSKNOIR, DRAKLOAK],
		"search": [DREEPY, DUSKULL, DRAGAPULT_EX, DRAKLOAK, DUSKNOIR],
	}
	if intent == "convert_attack":
		priorities["handoff"] = [DRAGAPULT_EX, DUSKNOIR, DRAKLOAK, DREEPY]
	return {
		"intent": intent,
		"phase": "launch" if not has_dragapult else ("convert" if ready_dragapult_live else "bridge"),
		"flags": flags,
		"targets": {
			"primary_attacker_name": primary_attacker_name,
			"bridge_target_name": bridge_target_name,
			"pivot_target_name": launch_pivot_name,
		},
		"owner": {
			"turn_owner_name": primary_attacker_name if intent != "launch_shell" else launch_pivot_name,
			"bridge_target_name": bridge_target_name,
			"pivot_target_name": launch_pivot_name,
		},
		"constraints": {
			"must_attack_if_available": intent == "convert_attack" and immediate_attack_window,
			"forbid_engine_churn": intent in ["force_first_dragapult", "bridge_to_attack", "convert_attack"],
			"forbid_extra_bench_padding": intent in ["bridge_to_attack", "convert_attack"] and shell_ready,
		},
		"priorities": priorities,
		"context": context.duplicate(true),
	}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var contract := _normalize_turn_contract(build_turn_plan(game_state, player_index, context))
	var priorities: Dictionary = contract.get("priorities", {}) if contract.get("priorities", {}) is Dictionary else {}
	var attach_priority: Array[String] = []
	var raw_attach: Variant = priorities.get("attach", [])
	if raw_attach is Array:
		for name_variant: Variant in raw_attach:
			attach_priority.append(str(name_variant))
	if attach_priority.is_empty():
		attach_priority = [DRAGAPULT_EX, DRAKLOAK, DREEPY]
	priorities["attach"] = attach_priority
	contract["priorities"] = priorities
	return contract


func build_continuity_contract(game_state: GameState, player_index: int, turn_contract: Dictionary = {}) -> Dictionary:
	var continuity := {
		"enabled": false,
		"safe_setup_before_attack": false,
		"setup_debt": {},
		"action_bonuses": [],
		"attack_penalty": 0.0,
	}
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return continuity
	var player: PlayerState = game_state.players[player_index]
	var resolved_contract: Dictionary = turn_contract.duplicate(true)
	if resolved_contract.is_empty():
		resolved_contract = build_turn_contract(game_state, player_index, {"prompt_kind": "continuity_contract"})
	var setup_debt := _dragapult_continuity_setup_debt(player, game_state)
	var action_bonuses: Array[Dictionary] = []
	if bool(setup_debt.get("needs_backup_dragapult_line", false)):
		action_bonuses.append({
			"kind": "play_trainer",
			"card_names": [BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL],
			"target_card_names": [DREEPY],
			"bonus": 760.0,
			"reason": "seed_backup_dragapult_line_before_noncritical_attack",
		})
	if bool(setup_debt.get("needs_duskull_line", false)):
		action_bonuses.append({
			"kind": "play_trainer",
			"card_names": [BUDDY_BUDDY_POFFIN],
			"target_card_names": [DUSKULL],
			"bonus": 700.0,
			"reason": "seed_duskull_support_line_before_noncritical_attack",
		})
	continuity["enabled"] = true
	continuity["safe_setup_before_attack"] = not action_bonuses.is_empty() and not _has_closing_active_attack(game_state, player_index)
	continuity["setup_debt"] = setup_debt
	continuity["action_bonuses"] = action_bonuses
	continuity["turn_intent"] = str(resolved_contract.get("intent", ""))
	return continuity


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[int] = []
	for i: int in range(player.hand.size()):
		var card: CardInstance = player.hand[i]
		if card != null and card.is_basic_pokemon():
			basics.append(i)
	if basics.is_empty():
		return {}

	var active_index := basics[0]
	var best_score := -INF
	for hand_index: int in basics:
		var score: float = _opening_priority(_hand_name(player, hand_index), player)
		if score > best_score:
			best_score = score
			active_index = hand_index

	var bench_entries: Array[Dictionary] = []
	for hand_index: int in basics:
		if hand_index == active_index:
			continue
		var bench_score: float = _bench_priority(_hand_name(player, hand_index), player)
		if bench_score <= 0.0:
			continue
		bench_entries.append({
			"index": hand_index,
			"score": bench_score,
		})
	bench_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var bench_indices: Array[int] = []
	for entry: Dictionary in bench_entries:
		if bench_indices.size() >= 5:
			break
		bench_indices.append(int(entry.get("index", -1)))

	return {
		"active_hand_index": active_index,
		"bench_hand_indices": bench_indices,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_basic_to_bench(action, game_state, player_index)
		"evolve":
			return _score_evolve(action, game_state, player_index)
		"play_trainer":
			return _score_trainer(action, game_state, player_index)
		"attach_energy":
			return _score_attach_energy(action, game_state, player_index)
		"attach_tool":
			return _score_attach_tool(action, game_state, player_index)
		"use_ability":
			return _score_use_ability(action, game_state, player_index)
		"retreat":
			return _score_retreat(player, game_state, player_index)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1))) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or slot.get_top_card() == null:
			continue
		match _slot_name(slot):
			DRAGAPULT_EX:
				score += 980.0
				if _can_slot_attack(slot):
					score += 170.0
			DRAKLOAK:
				score += 320.0
			DREEPY:
				score += 150.0
			DUSKNOIR:
				score += 520.0
			DUSCLOPS:
				score += 260.0
			DUSKULL:
				score += 130.0
			TATSUGIRI:
				score += 90.0
			ROTOM_V:
				score += 90.0 if _count_name(player, DRAGAPULT_EX) == 0 else 35.0
			LUMINEON_V:
				score += 75.0
			FEZANDIPITI_EX:
				score += 120.0
			RADIANT_ALAKAZAM:
				score += 95.0
		score += float(slot.attached_energy.size()) * 22.0
	if _count_name(player, DRAGAPULT_EX) > 0 and _count_name(player, DUSKNOIR) > 0:
		score += 170.0
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.get_top_card() != null:
			score += float(slot.damage_counters) * 1.8
			if slot.get_remaining_hp() <= 130:
				score += 80.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var card_data := slot.get_card_data()
	if card_data == null or card_data.attacks.is_empty():
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := slot.attached_energy.size() + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in card_data.attacks:
		var cost := str(attack.get("cost", ""))
		var damage := _parse_damage_text(str(attack.get("damage", "0")))
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if name in [DRAGAPULT_EX, DRAKLOAK, DUSKNOIR]:
		return 5
	if name in [DREEPY, DUSKULL, DUSCLOPS]:
		return 12
	if name in [SPARKLING_CRYSTAL, RARE_CANDY]:
		return 18
	if card.card_data.is_energy():
		return 100
	if name in [ROTOM_V, LUMINEON_V]:
		return 150
	return 60


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if player.bench.size() >= 5 and name in [NEST_BALL, BUDDY_BUDDY_POFFIN]:
		return 220
	if name == TATSUGIRI and _count_name(player, TATSUGIRI) >= 1:
		return 170
	if name == TEMPLE_OF_SINNOH:
		return 140
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	return int(SEARCH_PRIORITY.get(_card_name(card), 20))


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	var max_select := int(step.get("max_select", items.size()))
	if max_select <= 0 or items.is_empty():
		return []
	if step_id in ["bench_damage_counters", "bench_target"]:
		return _pick_bench_counter_targets(items, max_select)
	if step_id == "self_ko_target":
		return _pick_self_ko_targets(items, max_select, context)
	return []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if card.card_data == null:
			return 0.0
		if step_id == "stage2_card":
			return _score_search_pokemon(card, context, step_id)
		if step_id == "search_cards":
			return _score_search_card(card, context)
		if step_id == "search_item":
			return _score_search_item(card, context)
		if step_id == "search_tool":
			return _score_search_tool(card, context)
		if step_id in ["search_pokemon", "bench_pokemon", "basic_pokemon", "buddy_poffin_pokemon"]:
			return _score_search_pokemon(card, context, step_id)
		if step_id in ["discard_card", "discard_cards", "discard_energy"]:
			var game_state: GameState = context.get("game_state", null)
			var player_index := int(context.get("player_index", -1))
			return float(get_discard_priority_contextual(card, game_state, player_index))
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id in ["attach_energy_target", "energy_target"]:
			return _score_attach_target(slot, context)
		if step_id in ["send_out", "pivot_target", "self_switch_target", "switch_target"]:
			return _score_send_out(slot)
		if step_id in ["bench_damage_counters", "bench_target"]:
			return _score_bench_counter_target(slot)
		if step_id == "self_ko_target":
			return _score_dusk_blast_target(slot, context)
	return 0.0


func _pick_bench_counter_targets(items: Array, max_select: int) -> Array:
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		var item: Variant = items[i]
		if not (item is PokemonSlot):
			continue
		var score := _score_bench_counter_target(item as PokemonSlot)
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


func _pick_self_ko_targets(items: Array, max_select: int, context: Dictionary) -> Array:
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		var item: Variant = items[i]
		if not (item is PokemonSlot):
			continue
		var score := _score_dusk_blast_target(item as PokemonSlot, context)
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


func _resolved_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var turn_contract := get_turn_contract_context()
	if not turn_contract.is_empty():
		return turn_contract
	return build_turn_contract(game_state, player_index, context)


func _score_basic_to_bench(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if _should_shutdown_extra_setup(player, game_state):
		match _card_name(card):
			DREEPY:
				return 80.0 if _count_name(player, DREEPY) == 0 else -10.0
			DUSKULL:
				return 60.0 if _count_name(player, DUSKULL) == 0 else -10.0
			TATSUGIRI, ROTOM_V, FEZANDIPITI_EX, LUMINEON_V, RADIANT_ALAKAZAM:
				return -20.0
	var turn_contract := _resolved_turn_contract(game_state, player_index, {"prompt_kind": "action_selection", "kind": "play_basic_to_bench"})
	var flags: Dictionary = turn_contract.get("flags", {}) if turn_contract.get("flags", {}) is Dictionary else {}
	var shell_ready: bool = bool(flags.get("shell_ready", false))
	match _card_name(card):
		DREEPY:
			return 420.0 if _count_name(player, DREEPY) == 0 else 250.0
		DUSKULL:
			return 380.0 if _count_name(player, DUSKULL) == 0 else 210.0
		TATSUGIRI:
			if shell_ready and bool(turn_contract.get("constraints", {}).get("forbid_extra_bench_padding", false)):
				return 20.0
			return 240.0 if _count_name(player, TATSUGIRI) == 0 else 90.0
		ROTOM_V:
			if shell_ready and bool(turn_contract.get("constraints", {}).get("forbid_extra_bench_padding", false)):
				return 25.0
			return 220.0 if _count_name(player, DRAGAPULT_EX) == 0 and _count_name(player, ROTOM_V) == 0 else 70.0
		FEZANDIPITI_EX:
			if shell_ready and bool(turn_contract.get("constraints", {}).get("forbid_extra_bench_padding", false)):
				return 10.0
			return 170.0 if _count_name(player, FEZANDIPITI_EX) == 0 else 80.0
	return 50.0


func _score_evolve(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match _card_name(card):
		DRAGAPULT_EX:
			return 900.0 if _count_name(player, DRAGAPULT_EX) == 0 else 760.0
		DRAKLOAK:
			return 560.0
		DUSKNOIR:
			return 640.0 if _count_name(player, DUSKNOIR) == 0 else 520.0
		DUSCLOPS:
			return 470.0
	return 120.0


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var name := _card_name(action.get("card"))
	var turn_contract := _resolved_turn_contract(game_state, player_index, {"prompt_kind": "action_selection", "kind": "play_trainer", "trainer_name": name})
	var flags: Dictionary = turn_contract.get("flags", {}) if turn_contract.get("flags", {}) is Dictionary else {}
	var intent := str(turn_contract.get("intent", ""))
	var immediate_attack_window: bool = bool(flags.get("immediate_attack_window", false))
	if _under_deck_out_pressure(player, game_state):
		match name:
			BUDDY_BUDDY_POFFIN, NEST_BALL:
				return -10.0
			ULTRA_BALL:
				return 40.0 if _count_name(player, DRAGAPULT_EX) == 0 else -10.0
			ARVEN:
				return 180.0 if _has_live_dusk_blast_conversion_target(game_state, player_index) else 30.0
			IONO, ROXANNE:
				return 40.0 if opponent.prizes.size() <= 2 else -10.0
			MELA:
				return 80.0 if _fire_energy_in_discard(player) and _needs_dragapult_energy(player) else -10.0
			EARTHEN_VESSEL:
				return 120.0 if _needs_dragapult_energy(player) else -10.0
			NIGHT_STRETCHER:
				return 120.0 if _has_core_piece_in_discard(player) else -10.0
	if _should_shutdown_extra_setup(player, game_state):
		match name:
			BUDDY_BUDDY_POFFIN:
				if _should_use_poffin_for_duskull_followup(player, game_state):
					return 1180.0
				return 1220.0 if _should_use_poffin_for_dreepy_backups(player, game_state) else 20.0
			NEST_BALL:
				return 20.0
			ULTRA_BALL:
				return 80.0 if _count_name(player, DREEPY) == 0 or _count_name(player, DUSKULL) == 0 else 30.0
			ARVEN:
				if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index) and immediate_attack_window:
					return 140.0
				if _deck_has(player, NIGHT_STRETCHER) and _has_core_piece_in_discard(player):
					return 120.0
				return 30.0
			EARTHEN_VESSEL:
				return 40.0 if _needs_dragapult_energy(player) else -10.0
			NIGHT_STRETCHER:
				return 300.0 if _has_core_piece_in_discard(player) else 40.0
	match name:
		RARE_CANDY:
			return _rare_candy_value(player) + (140.0 if intent == "force_first_dragapult" else 0.0)
		ARVEN:
			return _score_arven(player, game_state, player_index)
		BUDDY_BUDDY_POFFIN:
			if _should_use_poffin_for_dreepy_backups(player, game_state):
				return 1220.0 if immediate_attack_window else 560.0
			if _should_use_poffin_for_duskull_followup(player, game_state):
				return 1180.0 if immediate_attack_window else 520.0
			if _count_name(player, DRAGAPULT_EX) > 0 and intent in ["bridge_to_attack", "convert_attack", "rebuild_dragapult"]:
				return 30.0
			if player.bench.size() >= 5:
				return 0.0
			var missing := 0
			if _count_name(player, DREEPY) == 0:
				missing += 1
			if _count_name(player, DUSKULL) == 0:
				missing += 1
			return 420.0 if missing >= 2 else 260.0
		NEST_BALL:
			if _count_name(player, DRAGAPULT_EX) > 0 and intent in ["bridge_to_attack", "convert_attack", "rebuild_dragapult"]:
				return 60.0
			if _should_prioritize_rotom_v_for_opening_nest(player, game_state):
				return 410.0
			return 340.0 if player.bench.size() < 5 and (_count_name(player, DREEPY) == 0 or _count_name(player, DUSKULL) == 0) else 150.0
		SWITCH:
			if _has_ready_dragapult_promotion(player):
				return 520.0
			if player.active_pokemon != null and _slot_name(player.active_pokemon) in [TATSUGIRI, ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM]:
				return 260.0 if _best_ready_dragapult_slot(player) != null else 120.0
			return 70.0
		ULTRA_BALL:
			return 360.0 if intent in ["force_first_dragapult", "bridge_to_attack"] else (320.0 if _count_name(player, DRAGAPULT_EX) == 0 or _count_name(player, DUSKNOIR) == 0 else 180.0)
		EARTHEN_VESSEL:
			return 300.0 if _needs_dragapult_energy(player) else 160.0
		COUNTER_CATCHER:
			if not immediate_attack_window:
				return 30.0
			return 430.0 if _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player) else 120.0
		BOSSS_ORDERS:
			if not immediate_attack_window:
				return 20.0
			return 420.0 if _can_take_bench_prize(game_state, player_index) else 90.0
		ROXANNE:
			return 320.0 if opponent.prizes.size() <= 3 else 90.0
		MELA:
			return 260.0 if _fire_energy_in_discard(player) and player.hand.size() <= 4 else 120.0
		NIGHT_STRETCHER:
			return 280.0 if _has_core_piece_in_discard(player) else 90.0
		TEMPLE_OF_SINNOH:
			return 20.0 if bool(flags.get("miraidon_pressure", false)) else 80.0
	return 70.0


func _score_attach_energy(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot")
	var card: CardInstance = action.get("card")
	if target_slot == null or card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	return _dragapult_energy_score(target_slot, player)


func _score_attach_tool(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var tool_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	var player: PlayerState = game_state.players[player_index]
	var turn_contract := _resolved_turn_contract(game_state, player_index, {"prompt_kind": "action_selection", "kind": "attach_tool", "tool_name": tool_name})
	match tool_name:
		SPARKLING_CRYSTAL:
			if target_name == DRAGAPULT_EX:
				return 540.0
			if target_name == DRAKLOAK:
				return 460.0 if _has_live_dragapult_stage2_route(player) else 260.0
			if target_name == DREEPY:
				return 420.0 if _has_live_dragapult_stage2_route(player) else 220.0
			if target_name in [TATSUGIRI, ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM, DUSKULL, DUSCLOPS, DUSKNOIR]:
				return -20.0
			return 40.0
		RESCUE_BOARD:
			if target_name in [DUSKULL, TATSUGIRI, ROTOM_V] or target_slot == game_state.players[player_index].active_pokemon:
				return 340.0 if target_slot == game_state.players[player_index].active_pokemon else 280.0
			return 120.0
		FOREST_SEAL_STONE:
			if target_name not in [ROTOM_V, LUMINEON_V]:
				return -20.0
			if target_name == ROTOM_V:
				return 520.0 if _should_route_forest_seal_stone_to_rotom(player, game_state) else (360.0 if _count_name(player, DRAGAPULT_EX) == 0 else 120.0)
			if target_name == LUMINEON_V:
				if _count_name(player, DRAGAPULT_EX) == 0 and not _has_supporter_in_hand(player):
					return 420.0
				return 220.0 if _count_name(player, DRAGAPULT_EX) == 0 else 80.0
			return 40.0
		TM_DEVOLUTION:
			if str(turn_contract.get("intent", "")) in ["bridge_to_attack", "convert_attack"] and not _has_real_devolution_window(game_state, player_index):
				return 0.0
			return 280.0 if _has_real_devolution_window(game_state, player_index) else 0.0
	return 50.0


func _score_use_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	var ability_index := int(action.get("ability_index", 0))
	if source_slot == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if _is_forest_seal_stone_ability(source_slot, ability_index):
		return _score_forest_seal_stone_ability(player, game_state, player_index)
	if _under_deck_out_pressure(player, game_state):
		match _slot_name(source_slot):
			DRAKLOAK:
				return 30.0
			ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, TATSUGIRI:
				return -20.0
	if _should_shutdown_extra_setup(player, game_state):
		match _slot_name(source_slot):
			ROTOM_V:
				return -20.0
			LUMINEON_V:
				return 20.0 if not _has_supporter_in_hand(player) else -10.0
			FEZANDIPITI_EX:
				return -10.0 if player.hand.size() >= 4 else 60.0
			TATSUGIRI:
				return 20.0 if source_slot == player.active_pokemon and not _has_supporter_in_hand(player) else -10.0
	match _slot_name(source_slot):
		DRAKLOAK:
			return 430.0
		DUSKNOIR:
			return _score_dusk_blast_ability(source_slot, opponent, game_state, player_index)
		DUSCLOPS:
			return _score_dusk_blast_ability(source_slot, opponent, game_state, player_index)
		ROTOM_V:
			if _has_hand_card(player, BUDDY_BUDDY_POFFIN) and _should_use_poffin_for_dreepy_backups(player, game_state):
				return 70.0
			return 340.0 if _count_name(player, DRAGAPULT_EX) == 0 and player.hand.size() <= 5 else 90.0
		LUMINEON_V:
			return 300.0 if not _has_supporter_in_hand(player) else 110.0
		FEZANDIPITI_EX:
			return 240.0 if player.hand.size() <= 3 else 110.0
		RADIANT_ALAKAZAM:
			return 180.0 if _opponent_has_damage_counters(opponent) else 60.0
		TATSUGIRI:
			return 220.0 if source_slot == player.active_pokemon and not _has_supporter_in_hand(player) else 70.0
	return 0.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var active := player.active_pokemon
	if active == null:
		return 0.0
	var attack_index := int(action.get("attack_index", -1))
	var attack_data: Dictionary = {}
	if active.get_card_data() != null and attack_index >= 0 and attack_index < active.get_card_data().attacks.size():
		attack_data = active.get_card_data().attacks[attack_index]
	var projected_damage := int(action.get("projected_damage", 0))
	if projected_damage <= 0:
		if not attack_data.is_empty():
			projected_damage = _parse_damage_text(str(attack_data.get("damage", "0")))
		else:
			projected_damage = int(predict_attacker_damage(active).get("damage", 0))
	var attack_name := str(action.get("attack_name", ""))
	if attack_name == "" and not attack_data.is_empty():
		attack_name = str(attack_data.get("name", ""))
	var is_phantom_dive := attack_index == 1 or attack_name in ["Phantom Dive", "幻影潜袭"] or projected_damage >= 200
	var is_jet_head := attack_index == 0 or attack_name in ["Jet Head", "喷射头击"] or projected_damage == 70
	var active_is_dragapult := _slot_name(active) == DRAGAPULT_EX
	var phantom_dive_online := active_is_dragapult and _dragapult_phantom_dive_ready(active)
	if active_is_dragapult and phantom_dive_online and is_jet_head:
		return -1000.0
	var score := 180.0 + float(projected_damage)
	if opponent.active_pokemon != null and projected_damage >= opponent.active_pokemon.get_remaining_hp():
		score += 420.0
		if _is_two_prize_target(opponent.active_pokemon):
			score += 120.0
	elif projected_damage > 0:
		score += 80.0

	if active_is_dragapult:
		if is_phantom_dive:
			score += 520.0
			if _phantom_dive_has_pickoff(opponent):
				score += 220.0
			if phantom_dive_online:
				score += 180.0
		else:
			score -= 120.0
	if _slot_name(active) == DUSKNOIR and projected_damage >= 150:
		score += 90.0
	if projected_damage > 0 and _under_deck_out_pressure(player, game_state):
		score += 180.0
	return score


func _score_search_card(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var card_type := str(card.card_data.card_type)
	if card_type == "Pokemon":
		return _score_search_pokemon(card, context)
	if card_type == "Tool":
		return _score_search_tool(card, context)
	if card_type in ["Item", "Stadium", "Supporter"]:
		var game_state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			return _score_trainer({"card": card}, game_state, player_index)
	if card.card_data.is_energy():
		var game_state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
		if player != null and _needs_dragapult_energy(player):
			return 320.0
		return 80.0
	return float(get_search_priority(card))


func _score_search_item(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	if _should_shutdown_extra_setup(player, game_state):
		match name:
			BUDDY_BUDDY_POFFIN, NEST_BALL:
				return 20.0
			ULTRA_BALL:
				return 80.0 if _count_name(player, DREEPY) == 0 or _count_name(player, DUSKULL) == 0 else 20.0
			EARTHEN_VESSEL:
				return 40.0 if _needs_dragapult_energy(player) else -10.0
			NIGHT_STRETCHER:
				return 340.0 if _has_core_piece_in_discard(player) else 40.0
	match name:
		RARE_CANDY:
			return _rare_candy_value(player) + 320.0
		BUDDY_BUDDY_POFFIN:
			return 520.0 if _count_name(player, DREEPY) == 0 or _count_name(player, DUSKULL) == 0 else 220.0
		ULTRA_BALL:
			return 420.0 if _count_name(player, DRAGAPULT_EX) == 0 else 200.0
		NEST_BALL:
			return 360.0 if _count_name(player, DREEPY) == 0 or _count_name(player, DUSKULL) == 0 else 160.0
		EARTHEN_VESSEL:
			return 380.0 if _needs_dragapult_energy(player) else 180.0
		COUNTER_CATCHER:
			return 420.0 if game_state != null and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player) else 120.0
		NIGHT_STRETCHER:
			return 340.0 if _has_core_piece_in_discard(player) else 90.0
	return 80.0


func _score_search_tool(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return 0.0
	if _should_shutdown_extra_setup(player, game_state) and name == FOREST_SEAL_STONE:
		return 40.0
	match name:
		SPARKLING_CRYSTAL:
			if _count_name(player, DRAGAPULT_EX) > 0 or ((_count_name(player, DREEPY) + _count_name(player, DRAKLOAK) > 0) and (_has_hand_card(player, DRAGAPULT_EX) or _deck_has(player, DRAGAPULT_EX))):
				return 540.0
			return 120.0
		RESCUE_BOARD:
			return 340.0 if player.active_pokemon != null and _slot_name(player.active_pokemon) in [DUSKULL, TATSUGIRI, ROTOM_V] else 180.0
		FOREST_SEAL_STONE:
			if not _has_live_forest_seal_target(player):
				return 20.0
			if _count_name(player, DRAGAPULT_EX) == 0:
				return 420.0 if _needs_first_dragapult_push(player) else 320.0
			return 120.0
		TM_DEVOLUTION:
			return 320.0 if game_state != null and _has_real_devolution_window(game_state, player_index) else 0.0
	return 90.0


func _score_search_pokemon(card: CardInstance, context: Dictionary, step_id: String = "") -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _card_name(card)
	if player == null:
		return float(get_search_priority(card))
	if step_id == "buddy_poffin_pokemon" and _should_use_poffin_for_dreepy_backups(player, game_state):
		if name == DREEPY:
			return 780.0
		if name == DUSKULL:
			return 360.0 if _count_name(player, DUSKULL) == 0 else 80.0
	if step_id == "buddy_poffin_pokemon" and _should_use_poffin_for_duskull_followup(player, game_state):
		if name == DUSKULL:
			return 780.0
		if name == DREEPY:
			return 180.0
	if step_id == "basic_pokemon" and _should_prioritize_rotom_v_for_opening_nest(player, game_state) and name == ROTOM_V:
		return 760.0
	if _should_shutdown_extra_setup(player, game_state):
		match name:
			DREEPY:
				return 80.0 if _count_name(player, DREEPY) == 0 else 10.0
			DUSKULL:
				return 60.0 if _count_name(player, DUSKULL) == 0 else 10.0
			TATSUGIRI, ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM:
				return -20.0
	if name == DRAGAPULT_EX and _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) > 0:
		return 860.0
	if name == DRAKLOAK and _count_name(player, DREEPY) > 0:
		return 760.0
	if name == DREEPY and _count_name(player, DREEPY) == 0:
		return 700.0
	if name == DUSKNOIR and _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) > 0:
		return 620.0
	if name == DUSCLOPS and _count_name(player, DUSKULL) > 0:
		return 520.0
	if name == DUSKULL and _count_name(player, DUSKULL) == 0:
		return 500.0
	if name == TATSUGIRI and _count_name(player, TATSUGIRI) == 0:
		return 220.0
	return float(get_search_priority(card))


func _should_prioritize_rotom_v_for_opening_nest(player: PlayerState, game_state: GameState) -> bool:
	if player == null:
		return false
	if player.bench.size() >= 5 or _count_name(player, ROTOM_V) > 0:
		return false
	if _count_name(player, DRAGAPULT_EX) > 0 or not _deck_has(player, ROTOM_V):
		return false
	if game_state != null and int(game_state.turn_number) > 2:
		return false
	if _dreepy_family_line_count(player) >= 2:
		return true
	if _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) <= 0:
		return false
	if _has_hand_card(player, BUDDY_BUDDY_POFFIN):
		return true
	return _count_name(player, DUSKULL) > 0


func _should_use_poffin_for_dreepy_backups(player: PlayerState, game_state: GameState) -> bool:
	if player == null:
		return false
	if player.bench.size() >= 5 or not _deck_has(player, DREEPY):
		return false
	if _under_deck_out_pressure(player, game_state):
		return false
	if _dreepy_family_line_count(player) >= 2:
		return false
	if game_state != null and int(game_state.turn_number) > 6:
		return false
	return _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) + _count_name(player, DRAGAPULT_EX) > 0


func _should_use_poffin_for_duskull_followup(player: PlayerState, game_state: GameState) -> bool:
	if player == null:
		return false
	if player.bench.size() >= 5 or not _deck_has(player, DUSKULL):
		return false
	if _under_deck_out_pressure(player, game_state):
		return false
	if _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) + _count_name(player, DUSKNOIR) > 0:
		return false
	if _dreepy_family_line_count(player) < 2:
		return false
	if game_state != null and int(game_state.turn_number) > 6:
		return false
	return true


func _dreepy_family_line_count(player: PlayerState) -> int:
	if player == null:
		return 0
	return _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) + _count_name(player, DRAGAPULT_EX)


func _dragapult_continuity_setup_debt(player: PlayerState, game_state: GameState) -> Dictionary:
	var dreepy_lines := _dreepy_family_line_count(player)
	var duskull_lines := 0
	if player != null:
		duskull_lines = _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) + _count_name(player, DUSKNOIR)
	var has_bench_space := player != null and player.bench.size() < 5
	var search_safe := not _under_deck_out_pressure(player, game_state)
	var needs_backup_dragapult_line := (
		player != null
		and has_bench_space
		and search_safe
		and _count_name(player, DRAGAPULT_EX) > 0
		and dreepy_lines < 2
		and _deck_has(player, DREEPY)
	)
	var needs_duskull_line := (
		player != null
		and has_bench_space
		and search_safe
		and dreepy_lines >= 2
		and duskull_lines == 0
		and _deck_has(player, DUSKULL)
	)
	return {
		"ready_dragapult": player != null and _best_ready_dragapult_slot(player) != null,
		"dreepy_family_lines": dreepy_lines,
		"duskull_family_lines": duskull_lines,
		"needs_backup_dragapult_line": needs_backup_dragapult_line,
		"needs_duskull_line": needs_duskull_line,
		"deck_has_dreepy": player != null and _deck_has(player, DREEPY),
		"deck_has_duskull": player != null and _deck_has(player, DUSKULL),
	}


func _has_closing_active_attack(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if player.active_pokemon == null or opponent.active_pokemon == null:
		return false
	var attack_info := predict_attacker_damage(player.active_pokemon)
	if not bool(attack_info.get("can_attack", false)):
		return false
	if int(attack_info.get("damage", 0)) < opponent.active_pokemon.get_remaining_hp():
		return false
	var prizes_remaining := player.prizes.size()
	return prizes_remaining > 0 and opponent.active_pokemon.get_prize_count() >= prizes_remaining


func _score_attach_target(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player == null:
		return 0.0
	return _dragapult_energy_score(slot, player)


func _score_send_out(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var score := float(slot.get_remaining_hp()) * 0.6 - float(_retreat_gap(slot)) * 25.0
	if _can_slot_attack(slot):
		score += 280.0
	match _slot_name(slot):
		DRAGAPULT_EX:
			score += 220.0
		DUSKNOIR:
			score += 140.0
		DRAKLOAK:
			score += 90.0
		ROTOM_V, LUMINEON_V, TATSUGIRI:
			score -= 80.0
	return score


func _score_bench_counter_target(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var remaining_hp := slot.get_remaining_hp()
	var prize_count := slot.get_prize_count()
	var score := float(prize_count) * 180.0
	if remaining_hp <= 60:
		score += 900.0 + float(prize_count) * 220.0
	elif remaining_hp <= 120:
		score += 300.0 + float(prize_count) * 90.0
	elif remaining_hp <= 180:
		score += 140.0
	if _is_rule_box(slot):
		score += 120.0
	score += float(slot.damage_counters) * 3.0
	score -= float(remaining_hp) * 0.75
	return score


func _opening_priority(name: String, player: PlayerState) -> float:
	match name:
		DREEPY:
			return 250.0
		TATSUGIRI:
			return 360.0 if not _hand_has_name(player, ARVEN) else 300.0
		ROTOM_V:
			return 330.0
		DUSKULL:
			return 220.0
		FEZANDIPITI_EX:
			return 140.0
	return 80.0


func _bench_priority(name: String, _player: PlayerState) -> float:
	match name:
		DUSKULL:
			return 540.0
		DREEPY:
			return 500.0
		ROTOM_V:
			return 280.0
		TATSUGIRI:
			return 240.0
		FEZANDIPITI_EX:
			return 160.0
		RADIANT_ALAKAZAM:
			return 100.0
	return 0.0


func _rare_candy_value(player: PlayerState) -> float:
	if (_has_hand_card(player, DRAGAPULT_EX) or _deck_has(player, DRAGAPULT_EX)) and _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) > 0:
		return 560.0
	if (_has_hand_card(player, DUSKNOIR) or _deck_has(player, DUSKNOIR)) and _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) > 0:
		return 420.0
	return 170.0


func _score_arven(player: PlayerState, game_state: GameState, player_index: int) -> float:
	var turn_contract := get_turn_contract_context()
	var intent := str(turn_contract.get("intent", ""))
	if _should_shutdown_extra_setup(player, game_state):
		var shutdown_item_value := 80.0
		if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player):
			shutdown_item_value = maxf(shutdown_item_value, 180.0)
		if _deck_has(player, NIGHT_STRETCHER) and _has_core_piece_in_discard(player):
			shutdown_item_value = maxf(shutdown_item_value, 160.0)
		if _deck_has(player, EARTHEN_VESSEL) and _needs_dragapult_energy(player):
			shutdown_item_value = maxf(shutdown_item_value, 100.0)
		var shutdown_tool_value := 40.0
		if _deck_has(player, SPARKLING_CRYSTAL) and _count_name(player, DRAGAPULT_EX) > 0:
			shutdown_tool_value = maxf(shutdown_tool_value, 180.0)
		return maxf(shutdown_item_value + shutdown_tool_value, 120.0)
	var item_value := 120.0
	if _deck_has(player, RARE_CANDY):
		item_value = maxf(item_value, _rare_candy_value(player) - 80.0)
	if _deck_has(player, BUDDY_BUDDY_POFFIN) and (_count_name(player, DREEPY) == 0 or _count_name(player, DUSKULL) == 0):
		item_value = maxf(item_value, 300.0)
	if _deck_has(player, EARTHEN_VESSEL) and _needs_dragapult_energy(player):
		item_value = maxf(item_value, 260.0)
	if _deck_has(player, COUNTER_CATCHER) and _player_is_behind_in_prizes(game_state, player_index) and _can_attack_soon(player):
		item_value = maxf(item_value, 280.0)
	if intent == "force_first_dragapult":
		item_value = maxf(item_value, 420.0)

	var tool_value := 60.0
	if _deck_has(player, SPARKLING_CRYSTAL) and (_count_name(player, DRAGAPULT_EX) > 0 or _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) > 0):
		tool_value = maxf(tool_value, 320.0)
	if _deck_has(player, RESCUE_BOARD):
		tool_value = maxf(tool_value, 260.0 if intent == "launch_shell" else 180.0)
	if _deck_has(player, FOREST_SEAL_STONE) and _has_live_forest_seal_target(player):
		tool_value = maxf(tool_value, 300.0 if _count_name(player, DRAGAPULT_EX) == 0 else 180.0)
	return maxf(item_value + tool_value, 190.0)


func _dragapult_energy_score(target_slot: PokemonSlot, player: PlayerState) -> float:
	if target_slot == null or target_slot.get_top_card() == null:
		return 0.0
	var name := _slot_name(target_slot)
	if not _is_dragapult_energy_lane(target_slot):
		return _active_retreat_attach_score(target_slot, player)
	var has_crystal := _slot_has_tool(target_slot, SPARKLING_CRYSTAL)
	match name:
		DRAGAPULT_EX:
			if has_crystal and target_slot.attached_energy.size() == 0:
				return 520.0
			if _attack_gap(target_slot) == 1:
				return 500.0
			return 360.0
		DRAKLOAK:
			return 420.0 if _count_name(player, DRAGAPULT_EX) == 0 else 260.0
		DREEPY:
			if target_slot == player.active_pokemon and target_slot.attached_energy.is_empty() and _count_name(player, DRAGAPULT_EX) == 0:
				return 520.0
			return 360.0 if _count_name(player, DRAGAPULT_EX) == 0 else 220.0
	return -80.0


func _is_dragapult_energy_lane(slot: PokemonSlot) -> bool:
	return _slot_name(slot) in [DREEPY, DRAKLOAK, DRAGAPULT_EX]


func _active_retreat_attach_score(slot: PokemonSlot, player: PlayerState) -> float:
	if player == null or slot == null or slot != player.active_pokemon:
		return -10000.0
	if player.bench.is_empty() or _retreat_gap(slot) <= 0:
		return -10000.0
	if _has_ready_dragapult_promotion(player):
		return 280.0 if _retreat_gap(slot) <= 1 else 160.0
	return 180.0 if _retreat_gap(slot) <= 1 else 90.0


func _score_retreat(player: PlayerState, game_state: GameState, player_index: int) -> float:
	if player.active_pokemon == null:
		return 0.0
	var turn_contract := get_turn_contract_context()
	if turn_contract.is_empty() and game_state != null:
		turn_contract = build_turn_contract(game_state, player_index, {"prompt_kind": "action_selection", "kind": "retreat"})
	var flags: Dictionary = turn_contract.get("flags", {}) if turn_contract.get("flags", {}) is Dictionary else {}
	var active_name := _slot_name(player.active_pokemon)
	var ready_promotion := _has_ready_dragapult_promotion(player)
	if active_name in [DREEPY, DRAKLOAK]:
		if ready_promotion:
			return 260.0
		return -700.0 if player.active_pokemon.attached_energy.size() > 0 else -160.0
	if active_name == DRAGAPULT_EX:
		return 80.0 if ready_promotion else -120.0
	if active_name in [TATSUGIRI, ROTOM_V, DUSKULL, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM]:
		if ready_promotion or bool(flags.get("convert_attack", false)):
			return 260.0
		return -180.0
	return -80.0


func _best_ready_dragapult_slot(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) == DRAGAPULT_EX and _can_slot_attack(slot):
			return slot
	return null


func _has_ready_dragapult_promotion(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name(player.active_pokemon) == DRAGAPULT_EX and _can_slot_attack(player.active_pokemon):
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_name(slot) == DRAGAPULT_EX and _can_slot_attack(slot):
			return true
	return false


func _rare_candy_dragapult_live(player: PlayerState) -> bool:
	if _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) <= 0:
		return false
	if not (_has_hand_card(player, RARE_CANDY) or _deck_has(player, RARE_CANDY)):
		return false
	return _has_hand_card(player, DRAGAPULT_EX) or _deck_has(player, DRAGAPULT_EX)


func _has_live_dragapult_stage2_route(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_name(player, DRAGAPULT_EX) > 0:
		return true
	if _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) <= 0:
		return false
	return _has_hand_card(player, DRAGAPULT_EX) or _deck_has(player, DRAGAPULT_EX)


func _has_immediate_attack_window(player: PlayerState) -> bool:
	if player.active_pokemon != null and _can_slot_attack(player.active_pokemon):
		return true
	if player.active_pokemon == null or _retreat_gap(player.active_pokemon) > 0:
		return false
	return _best_ready_dragapult_slot(player) != null


func _can_use_named_attack(slot: PokemonSlot, attack_name: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		var candidate_name := str(attack.get("name", ""))
		if candidate_name != attack_name and not (attack_name == "Phantom Dive" and candidate_name == "幻影潜袭"):
			continue
		return slot.attached_energy.size() >= str(attack.get("cost", "")).length()
	return false


func _launch_pivot_name(player: PlayerState) -> String:
	if _count_name(player, TATSUGIRI) > 0:
		return TATSUGIRI
	if _count_name(player, ROTOM_V) > 0:
		return ROTOM_V
	if _count_name(player, DUSKULL) > 0:
		return DUSKULL
	if _count_name(player, DREEPY) > 0:
		return DREEPY
	return ""


func _has_live_forest_seal_target(player: PlayerState) -> bool:
	return _count_name(player, ROTOM_V) + _count_name(player, LUMINEON_V) > 0


func _needs_first_dragapult_push(player: PlayerState) -> bool:
	if _count_name(player, DRAGAPULT_EX) > 0:
		return false
	if _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) <= 0:
		return false
	if _has_hand_card(player, DRAGAPULT_EX):
		return not _has_hand_card(player, RARE_CANDY)
	return _deck_has(player, DRAGAPULT_EX)


func _should_route_forest_seal_stone_to_rotom(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _count_name(player, ROTOM_V) == 0:
		return false
	if _count_name(player, DRAGAPULT_EX) > 0:
		return false
	if game_state != null and int(game_state.turn_number) <= 2:
		return true
	return _needs_first_dragapult_push(player)


func _is_miraidon_pressure_matchup(opponent: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(opponent):
		var name := _slot_name(slot)
		if name in [MIRAIDON_EX, IRON_HANDS_EX, RAIKOU_V, RAICHU_V, SQUAWKABILLY_EX]:
			return true
	return false


func _is_forest_seal_stone_ability(slot: PokemonSlot, ability_index: int) -> bool:
	if slot == null or slot.get_card_data() == null or slot.attached_tool == null or slot.attached_tool.card_data == null:
		return false
	var native_count := slot.get_card_data().abilities.size()
	if ability_index < native_count:
		return false
	return str(slot.attached_tool.card_data.effect_id) == FOREST_SEAL_STONE_EFFECT_ID


func _score_forest_seal_stone_ability(player: PlayerState, game_state: GameState, _player_index: int) -> float:
	if player == null:
		return 0.0
	if _count_name(player, DRAGAPULT_EX) > 0 and _can_attack_soon(player):
		return 120.0
	if _needs_first_dragapult_push(player):
		return 620.0
	if _count_name(player, DREEPY) == 0 or _count_name(player, DUSKULL) == 0:
		return 220.0
	if game_state != null and int(game_state.turn_number) <= 2:
		return 460.0
	if _count_name(player, DUSKNOIR) == 0 and (_count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) > 0):
		return 320.0
	return 180.0


func _has_real_devolution_window(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_card_data() == null:
			continue
		if str(slot.get_card_data().stage) == "Basic":
			continue
		if slot.damage_counters > 0 or slot.get_remaining_hp() <= 160:
			return true
	return false


func _should_shutdown_extra_setup(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if _best_ready_dragapult_slot(player) == null:
		return false
	var support_shell_online: bool = _count_name(player, DUSKULL) + _count_name(player, DUSCLOPS) + _count_name(player, DUSKNOIR) > 0
	var backup_dragapult_online: bool = _count_name(player, DREEPY) + _count_name(player, DRAKLOAK) + _count_name(player, DRAGAPULT_EX) > 1
	if not support_shell_online and not backup_dragapult_online:
		return false
	if game_state != null and int(game_state.turn_number) <= 3 and player.hand.size() <= 4 and not support_shell_online:
		return false
	return true


func _under_deck_out_pressure(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return false
	if player.deck.size() > 12:
		return false
	if game_state != null and int(game_state.turn_number) <= 6:
		return false
	return _best_ready_dragapult_slot(player) != null


func _has_live_dusk_blast_conversion_target(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	return _best_dusk_blast_target_score(opponent, {"game_state": game_state, "player_index": player_index}) >= 650.0


func _needs_dragapult_energy(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) in [DREEPY, DRAKLOAK, DRAGAPULT_EX] and _attack_gap(slot) > 0:
			return true
	return false


func _fire_energy_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "R":
			return true
	return false


func _has_core_piece_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		var name := _card_name(card)
		if name in [DRAGAPULT_EX, DRAKLOAK, DREEPY, DUSKNOIR, DUSKULL, DUSCLOPS]:
			return true
	return false


func _has_supporter_in_hand(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Supporter":
			return true
	return false


func _player_is_behind_in_prizes(game_state: GameState, player_index: int) -> bool:
	return game_state.players[player_index].prizes.size() > game_state.players[1 - player_index].prizes.size()


func _can_attack_soon(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _can_slot_attack(slot) or _attack_gap(slot) <= 1:
			return true
	return false


func _can_take_bench_prize(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var active := player.active_pokemon
	if active == null:
		return false
	var predicted_damage := int(predict_attacker_damage(active).get("damage", 0))
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.get_top_card() != null and predicted_damage >= slot.get_remaining_hp():
			return true
	return false


func _phantom_dive_has_pickoff(opponent: PlayerState) -> bool:
	for slot: PokemonSlot in opponent.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= 60:
			return true
		if slot.damage_counters >= 40 and _is_two_prize_target(slot):
			return true
	return false


func _score_dusk_blast_ability(source_slot: PokemonSlot, opponent: PlayerState, game_state: GameState, player_index: int) -> float:
	var context := {
		"game_state": game_state,
		"player_index": player_index,
		"source_slot": source_slot,
	}
	var best_score := _best_dusk_blast_target_score(opponent, context)
	if _slot_name(source_slot) == DUSKNOIR:
		if best_score >= 650.0:
			return 520.0
		if best_score >= 350.0:
			return 360.0
		return -40.0
	if _slot_name(source_slot) == DUSCLOPS:
		if best_score >= 650.0:
			return 430.0
		if best_score >= 350.0:
			return 260.0
		return -60.0
	return 0.0


func _best_dusk_blast_target_score(opponent: PlayerState, context: Dictionary) -> float:
	if opponent == null:
		return -INF
	var best_score := -INF
	if opponent.active_pokemon != null:
		best_score = maxf(best_score, _score_dusk_blast_target(opponent.active_pokemon, context))
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.get_top_card() != null:
			best_score = maxf(best_score, _score_dusk_blast_target(slot, context))
	return best_score


func _score_dusk_blast_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var remaining_hp := slot.get_remaining_hp()
	var blast_damage := _dusk_blast_damage(context.get("source_slot", null))
	var prize_count := slot.get_prize_count()
	var score := float(prize_count) * 100.0
	if remaining_hp <= blast_damage:
		if _is_closing_dusk_blast_prize(prize_count, context):
			score += 700.0
			return score
		if prize_count >= 2:
			score += 650.0
			score += 120.0
			return score
		score += 180.0
		return score
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		var opponent: PlayerState = game_state.players[1 - player_index]
		var active := player.active_pokemon
		var source_slot: PokemonSlot = context.get("source_slot", null)
		if active != null and active != source_slot and slot == opponent.active_pokemon:
			var attack_info: Dictionary = predict_attacker_damage(active)
			if bool(attack_info.get("can_attack", false)):
				var follow_up_damage := int(attack_info.get("damage", 0))
				if remaining_hp <= blast_damage + follow_up_damage:
					score += 420.0
					if slot.get_prize_count() >= 2:
						score += 80.0
					return score
	score -= 180.0
	score -= float(remaining_hp) * 0.25
	return score


func _is_closing_dusk_blast_prize(prize_count: int, context: Dictionary) -> bool:
	if prize_count <= 0:
		return false
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var prizes_remaining := game_state.players[player_index].prizes.size()
	if prizes_remaining <= 0:
		return false
	return prize_count >= prizes_remaining


func _dusk_blast_damage(source_slot: Variant) -> int:
	if source_slot is PokemonSlot:
		match _slot_name(source_slot as PokemonSlot):
			DUSCLOPS:
				return 50
			DUSKNOIR:
				return 130
	return 130


func _has_dusk_blast_target(opponent: PlayerState, source_slot: PokemonSlot = null, context: Dictionary = {}) -> bool:
	var target_context := context.duplicate()
	target_context["source_slot"] = source_slot
	return _best_dusk_blast_target_score(opponent, target_context) >= 350.0


func _opponent_has_damage_counters(opponent: PlayerState) -> bool:
	if opponent.active_pokemon != null and opponent.active_pokemon.damage_counters > 0:
		return true
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.damage_counters > 0:
			return true
	return false


func _opponent_has_evolution(game_state: GameState, player_index: int) -> bool:
	var opponent: PlayerState = game_state.players[1 - player_index]
	for slot: PokemonSlot in _all_slots(opponent):
		if slot != null and slot.get_card_data() != null and str(slot.get_card_data().stage) != "Basic":
			return true
	return false


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _count_name(player: PlayerState, target_name: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is(slot, [target_name]):
			count += 1
	return count


func _hand_name(player: PlayerState, hand_index: int) -> String:
	if hand_index < 0 or hand_index >= player.hand.size():
		return ""
	var card: CardInstance = player.hand[hand_index]
	return _card_name(card)


func _hand_has_name(player: PlayerState, target_name: String) -> bool:
	for card: CardInstance in player.hand:
		if _card_name(card) == target_name:
			return true
	return false


func _has_hand_card(player: PlayerState, target_name: String) -> bool:
	return _hand_has_name(player, target_name)


func _deck_has(player: PlayerState, target_name: String) -> bool:
	for card: CardInstance in player.deck:
		if _card_name(card) == target_name:
			return true
	return false


func _can_slot_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if slot.attached_energy.size() >= str(attack.get("cost", "")).length():
			return true
	return false


func _dragapult_phantom_dive_ready(slot: PokemonSlot) -> bool:
	return _slot_name(slot) == DRAGAPULT_EX and _attack_gap_for_index(slot, 1) <= 0


func _attack_gap_for_index(slot: PokemonSlot, attack_index: int) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	if attack_index < 0 or attack_index >= slot.get_card_data().attacks.size():
		return 99
	var attack: Dictionary = slot.get_card_data().attacks[attack_index]
	return maxi(0, str(attack.get("cost", "")).length() - slot.attached_energy.size())


func _attack_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var best := 99
	for attack: Dictionary in slot.get_card_data().attacks:
		best = mini(best, maxi(0, str(attack.get("cost", "")).length() - slot.attached_energy.size()))
	return best


func _retreat_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	return maxi(0, int(slot.get_card_data().retreat_cost) - slot.attached_energy.size())


func _slot_has_tool(slot: PokemonSlot, tool_name: String) -> bool:
	if slot == null or slot.attached_tool == null:
		return false
	return _card_name(slot.attached_tool) == tool_name


func _is_two_prize_target(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_prize_count() >= 2


func _is_rule_box(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null and str(slot.get_card_data().mechanic) != ""


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack", "granted_attack":
			return 500.0
		"attach_energy":
			return 220.0
		"play_trainer":
			return 110.0
		"play_basic_to_bench":
			return 180.0
		"use_ability":
			return 160.0
		"retreat":
			return 90.0
		"attach_tool":
			return 90.0
	return 10.0


func _parse_damage_text(text: String) -> int:
	var cleaned := text.replace("+", "").replace("x", "").replace("×", "").replace("脳", "").strip_edges()
	return int(cleaned) if cleaned.is_valid_int() else 0


func _card_name(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			return str(instance.card_data.name_en) if str(instance.card_data.name_en) != "" else str(instance.card_data.name)
	return ""
