class_name DeckStrategyLugiaArcheops
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const LUGIA_V := "Lugia V"
const LUGIA_VSTAR := "Lugia VSTAR"
const ARCHEOPS := "Archeops"
const MINCCINO := "Minccino"
const CINCCINO := "Cinccino"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const IRON_HANDS_EX := "Iron Hands ex"
const BLOODMOON_URSALUNA_EX := "Bloodmoon Ursaluna ex"
const WELLSPRING_OGERPON_EX := "Wellspring Mask Ogerpon ex"
const CORNERSTONE_OGERPON_EX := "Cornerstone Mask Ogerpon ex"
const JAMMING_TOWER := "Jamming Tower"
const COLLAPSED_STADIUM := "Collapsed Stadium"
const FOREST_SEAL_STONE := "Forest Seal Stone"
const MAXIMUM_BELT := "Maximum Belt"
const DEFIANCE_BAND := "Defiance Band"
const SPARKLING_CRYSTAL := "Sparkling Crystal"

const ULTRA_BALL := "Ultra Ball"
const CAPTURING_AROMA := "Capturing Aroma"
const GREAT_BALL := "Great Ball"
const PROFESSORS_RESEARCH := "Professor's Research"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const THORTON := "Thorton"
const JACQ := "Jacq"
const CARMINE := "Carmine"

const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GIFT_ENERGY := "Gift Energy"
const JET_ENERGY := "Jet Energy"
const MIST_ENERGY := "Mist Energy"
const V_GUARD_ENERGY := "V Guard Energy"
const LEGACY_ENERGY := "Legacy Energy"


func get_strategy_id() -> String:
	return "lugia_archeops"


func get_signature_names() -> Array[String]:
	return [LUGIA_V, LUGIA_VSTAR, ARCHEOPS]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"time_budget_ms": 2100,
		"rollouts_per_sequence": 0,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or not card.is_basic_pokemon():
			continue
		basics.append({"index": i, "score": _setup_priority(_card_name(card), player)})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	var bench_names: Array[String] = []
	var active_name := _card_name(player.hand[active_index]) if active_index >= 0 and active_index < player.hand.size() else ""
	for entry: Dictionary in basics:
		var idx: int = int(entry.get("index", -1))
		if idx == active_index:
			continue
		var bench_name := _card_name(player.hand[idx]) if idx >= 0 and idx < player.hand.size() else ""
		if not _should_bench_opening_basic(bench_name, active_name, bench_names):
			continue
		bench_indices.append(idx)
		bench_names.append(bench_name)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var lugia_field := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR)
	var lugia_vstar_field := _count_named_on_field(player, LUGIA_VSTAR)
	var lugia_hand := _count_named_in_hand(player, LUGIA_V)
	var lugia_vstar_hand := _count_named_in_hand(player, LUGIA_VSTAR)
	var minccino_field := _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO)
	var minccino_hand := _count_named_in_hand(player, MINCCINO) + _count_named_in_hand(player, CINCCINO)
	var archeops_field := _count_named_on_field(player, ARCHEOPS)
	var archeops_discard := _count_named_in_discard(player, ARCHEOPS)
	var archeops_hand := _count_named_in_hand(player, ARCHEOPS)
	var shell_missing_owner := lugia_field + lugia_hand == 0
	var shell_missing_minccino := minccino_field + minccino_hand == 0
	var engine_online := archeops_field >= 1
	var owner_name := ""
	if lugia_vstar_field > 0:
		owner_name = LUGIA_VSTAR
	elif lugia_field > 0:
		owner_name = LUGIA_V
	elif minccino_field > 0:
		owner_name = CINCCINO if _count_named_on_field(player, CINCCINO) > 0 else MINCCINO
	var bridge_target_name := ""
	var search_priority: Array[String] = []
	if shell_missing_owner:
		bridge_target_name = LUGIA_V
		search_priority.append(LUGIA_V)
	elif lugia_field == 0 and lugia_hand > 0:
		bridge_target_name = LUGIA_V
	if lugia_field > 0 and lugia_vstar_field == 0 and lugia_vstar_hand == 0:
		if bridge_target_name == "":
			bridge_target_name = LUGIA_VSTAR
		search_priority.append(LUGIA_VSTAR)
	if not engine_online and archeops_discard + archeops_hand < 2:
		search_priority.append(ARCHEOPS)
	if shell_missing_minccino:
		search_priority.append(MINCCINO)
	if bridge_target_name == "" and not search_priority.is_empty():
		bridge_target_name = search_priority[0]
	if owner_name == "" and bridge_target_name in [LUGIA_V, LUGIA_VSTAR, MINCCINO, CINCCINO]:
		owner_name = bridge_target_name
	var attach_priority: Array[String] = []
	if lugia_vstar_field > 0:
		attach_priority.append(LUGIA_VSTAR)
	elif lugia_field > 0:
		attach_priority.append(LUGIA_V)
	if _count_named_on_field(player, CINCCINO) > 0:
		attach_priority.append(CINCCINO)
	elif _count_named_on_field(player, MINCCINO) > 0:
		attach_priority.append(MINCCINO)
	if engine_online:
		var special_target := _best_special_energy_target(player)
		var special_target_name := _slot_name(special_target)
		if special_target_name != "" and not attach_priority.has(special_target_name):
			attach_priority.append(special_target_name)
	var handoff_priority: Array[String] = []
	var ready_bench := _best_ready_bench(player)
	if ready_bench != null:
		handoff_priority.append(_slot_name(ready_bench))
	elif owner_name != "":
		handoff_priority.append(owner_name)
	for name: String in [bridge_target_name, owner_name]:
		if name != "" and not search_priority.has(name):
			search_priority.append(name)
	return {
		"id": "lugia_%s" % phase,
		"intent": "launch_shell" if not engine_online else "convert_attack",
		"phase": phase,
		"flags": {
			"shell_missing_owner": shell_missing_owner,
			"shell_missing_minccino": shell_missing_minccino,
			"engine_online": engine_online,
			"archeops_short": not engine_online and archeops_discard + archeops_hand < 2,
		},
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_target_name,
			"pivot_target_name": handoff_priority[0] if not handoff_priority.is_empty() else owner_name,
		},
		"priorities": {
			"attach": attach_priority,
			"handoff": handoff_priority,
			"search": search_priority,
		},
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
	var resolved_contract: Dictionary = turn_contract.duplicate(true)
	if resolved_contract.is_empty():
		resolved_contract = build_turn_contract(game_state, player_index, {"prompt_kind": "continuity_contract"})
	var setup_debt := _build_continuity_setup_debt(game_state, player_index, player)
	if not _has_immediate_attack_window(player):
		disabled["setup_debt"] = setup_debt
		return disabled
	if _lugia_continuity_terminal_attack_locked(game_state, player_index, resolved_contract):
		disabled["setup_debt"] = setup_debt
		disabled["terminal_attack_locked"] = true
		return disabled
	var action_bonuses := _build_continuity_action_bonuses(player, setup_debt)
	var enabled := _continuity_setup_debt_is_active(setup_debt) and not action_bonuses.is_empty()
	return {
		"enabled": enabled,
		"safe_setup_before_attack": enabled,
		"setup_debt": setup_debt,
		"action_bonuses": action_bonuses,
		"attack_penalty": 0.0,
		"turn_intent": str(resolved_contract.get("intent", "")),
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_play_basic(action.get("card", null), game_state, player_index, player, phase)
		"evolve":
			return _score_evolve(action.get("card", null), player, phase)
		"play_stadium":
			return _score_stadium(action.get("card", null), game_state, player, player_index, phase)
		"play_trainer":
			return _score_trainer(action.get("card", null), player, phase, game_state, player_index)
		"attach_energy":
			return _score_attach(action.get("card", null), action.get("target_slot", null), player, phase, game_state)
		"use_ability":
			return _score_use_ability(action.get("source_slot", null), game_state, player, phase)
		"retreat":
			return _score_retreat(game_state, player, phase, action.get("bench_target", null))
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index, phase)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1)))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		var name := _slot_name(slot)
		if name == LUGIA_VSTAR:
			score += 820.0
		elif name == LUGIA_V:
			score += 340.0
		elif name == ARCHEOPS:
			score += 390.0
		elif name == CINCCINO:
			score += 240.0
		elif name == MINCCINO:
			score += 140.0
		elif name == IRON_HANDS_EX:
			score += 230.0
		elif name == BLOODMOON_URSALUNA_EX:
			score += 210.0
		score += float(slot.attached_energy.size()) * 54.0
		score += float(slot.get_remaining_hp()) * 0.06
	score += float(_count_named_on_field(player, ARCHEOPS)) * 150.0
	score += float(_count_named_in_discard(player, ARCHEOPS)) * 70.0
	if _best_lugia_slot(player) != null and _attack_energy_gap(_best_lugia_slot(player)) <= 0:
		score += 220.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := slot.attached_energy.size() + extra_context
	var best_damage := _best_attack_damage(slot)
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		if attached >= cost.length():
			can_attack = true
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if name == ARCHEOPS:
		return 260
	if name == MINCCINO:
		return 90
	if name == THORTON or name == JACQ:
		return 170
	if card.card_data.card_type == "Special Energy":
		return 135
	if card.card_data.is_energy():
		return 80
	return 120


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if name == ARCHEOPS and not _needs_archeops_discard_setup(player):
		return 90
	if name == LUGIA_VSTAR and _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 10
	if card.card_data.card_type == "Special Energy" and _count_total_special_energy(player) <= 3:
		return 70
	return priority


func get_search_priority(card: CardInstance) -> int:
	return _search_score(card, null, -1)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id in ["search_pokemon", "search_cards", "search_item"]:
		return _pick_search_items_by_score(items, int(step.get("max_select", 1)), step, context)
	return []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id == "supporter_card":
			return _score_supporter_card(card, context)
		if step_id in ["search_pokemon", "search_cards", "search_item"]:
			return float(_search_score(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id in ["discard_card", "discard_cards"]:
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id == "summon_targets":
			return _summon_target_score(card)
	if item is PokemonSlot and step_id in ["assignment_target", "energy_assignment"]:
		return _assignment_target_score(item as PokemonSlot, context)
	if item is PokemonSlot and step_id in ["opponent_switch_target", "opponent_bench_target"]:
		return _score_opponent_switch_target(item as PokemonSlot, context)
	if item is PokemonSlot and step_id in ["send_out", "switch_target", "self_switch_target", "pivot_target", "heavy_baton_target"]:
		return _score_handoff_target(item as PokemonSlot, step_id, context)
	return 0.0


func _pick_search_items_by_score(items: Array, max_select: int, step: Dictionary, context: Dictionary) -> Array:
	var limit := maxi(1, max_select)
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if item is CardInstance:
			ranked.append({
				"item": item,
				"score": score_interaction_target(item, step, context),
			})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var picked: Array = []
	for entry: Dictionary in ranked:
		if picked.size() >= limit:
			break
		picked.append(entry.get("item"))
	return picked


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is PokemonSlot and step_id in ["opponent_switch_target", "opponent_bench_target"]:
		return _score_opponent_switch_target(item as PokemonSlot, context)
	if item is PokemonSlot and step_id in ["send_out", "switch_target", "self_switch_target", "pivot_target", "heavy_baton_target"]:
		return _score_handoff_target(item as PokemonSlot, step_id, context)
	return score_interaction_target(item, step, context)


func _setup_priority(name: String, player: PlayerState) -> float:
	if name == LUGIA_V:
		return 380.0
	if name == MINCCINO:
		return 270.0
	if name == LUMINEON_V:
		return 190.0 if _count_named_in_hand(player, LUGIA_V) == 0 else 150.0
	if name == FEZANDIPITI_EX:
		return 140.0
	if name == IRON_HANDS_EX:
		return 110.0 if _count_named_in_hand(player, LUGIA_V) > 0 else 80.0
	if name == WELLSPRING_OGERPON_EX or name == CORNERSTONE_OGERPON_EX:
		return 60.0
	if name == BLOODMOON_URSALUNA_EX:
		return 50.0
	return 100.0


func _should_bench_opening_basic(name: String, active_name: String, bench_names: Array[String]) -> bool:
	if name == LUGIA_V or name == MINCCINO:
		return true
	var owner_present := active_name == LUGIA_V or bench_names.has(LUGIA_V)
	var minccino_present := active_name == MINCCINO or bench_names.has(MINCCINO)
	if owner_present and minccino_present:
		return false
	if bench_names.is_empty() and active_name != LUGIA_V:
		return true
	return false


func _score_play_basic(card: CardInstance, game_state: GameState, player_index: int, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null or player.is_bench_full():
		return 0.0
	var name := _card_name(card)
	var owner_missing := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) == 0
	var owner_in_hand := _count_named_in_hand(player, LUGIA_V) > 0
	var cool_off_padding := _should_cool_off_post_launch_padding(player, phase)
	var core_shell_pressure := _lugia_core_shell_pressure(player)
	if name == LUGIA_V:
		if owner_missing:
			return 640.0 if phase == "early" else 520.0
		if _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) >= 2:
			return 140.0
		return 360.0
	if name == MINCCINO:
		if cool_off_padding:
			return 30.0
		return 250.0 if _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO) == 0 else 130.0
	if cool_off_padding and name in [LUMINEON_V, FEZANDIPITI_EX, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]:
		return 10.0
	if owner_missing and not owner_in_hand and phase == "early":
		if name == LUMINEON_V:
			return 120.0
		if name in [IRON_HANDS_EX, FEZANDIPITI_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]:
			return 20.0
	if core_shell_pressure and name in [LUMINEON_V, FEZANDIPITI_EX, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]:
		if name == FEZANDIPITI_EX and player.prizes.size() > 0 and player.prizes.size() < 6:
			return 65.0
		return 0.0
	if name == IRON_HANDS_EX:
		return 180.0 if _count_named_on_field(player, ARCHEOPS) > 0 and phase != "early" else 40.0
	if name == BLOODMOON_URSALUNA_EX:
		return 170.0 if phase == "late" else 20.0
	if name == LUMINEON_V:
		return 90.0 if phase == "early" and _count_named_on_field(player, LUGIA_VSTAR) == 0 else 20.0
	if name == FEZANDIPITI_EX:
		return 95.0 if player.prizes.size() > 0 and player.prizes.size() < 6 else 25.0
	if name == WELLSPRING_OGERPON_EX or name == CORNERSTONE_OGERPON_EX:
		return 120.0 if phase == "late" and _count_named_on_field(player, ARCHEOPS) > 0 else 15.0
	return 80.0


func _score_evolve(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == LUGIA_VSTAR:
		if _count_named_in_discard(player, ARCHEOPS) >= 1:
			return 950.0
		return 820.0
	if name == CINCCINO:
		var minccino_online := _count_named_on_field(player, MINCCINO) > 0
		var archeops_online := _count_named_on_field(player, ARCHEOPS)
		if minccino_online and archeops_online >= 1:
			return 620.0
		if minccino_online:
			return 420.0 if phase != "early" else 300.0
		return 340.0 if phase != "early" else 220.0
	return 100.0


func _score_stadium(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var name := _card_name(card)
	if game_state != null and game_state.stadium_card != null and _card_name(game_state.stadium_card) == name:
		return 0.0
	if name == JAMMING_TOWER:
		var opponent: PlayerState = null
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			opponent = game_state.players[1 - player_index]
		var opponent_tool_pressure := _tool_pressure(opponent)
		var own_tool_pressure := _tool_pressure(player)
		if opponent_tool_pressure <= own_tool_pressure:
			return 20.0 if game_state != null and game_state.stadium_card != null else 0.0
		var score := 120.0 + (opponent_tool_pressure - own_tool_pressure)
		if game_state != null and game_state.stadium_card != null:
			score += 30.0
		return score
	if name == COLLAPSED_STADIUM:
		var opponent: PlayerState = null
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			opponent = game_state.players[1 - player_index]
		var opponent_bench_pressure := 0.0
		if opponent != null and opponent.bench.size() > 4:
			opponent_bench_pressure += 100.0 + float(opponent.bench.size() - 4) * 25.0
		var cleanup_value := _collapsed_cleanup_value(player)
		if cleanup_value <= 0.0 and opponent_bench_pressure <= 0.0:
			return 0.0
		if phase == "early" and cleanup_value <= 0.0 and opponent_bench_pressure < 120.0:
			return 0.0
		return cleanup_value + opponent_bench_pressure
	return 0.0


func _score_trainer(
	card: CardInstance,
	player: PlayerState,
	phase: String,
	game_state: GameState = null,
	player_index: int = -1
) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	var owner_missing := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) == 0
	var owner_in_hand := _count_named_in_hand(player, LUGIA_V) > 0
	var cool_off_churn := _should_cool_off_post_launch_padding(player, phase)
	var cool_off_draw_churn := _should_cool_off_draw_churn(player, phase)
	if cool_off_draw_churn:
		if name in [PROFESSORS_RESEARCH, IONO, GREAT_BALL, CARMINE, ULTRA_BALL, CAPTURING_AROMA]:
			return 0.0
	if cool_off_churn:
		if name == PROFESSORS_RESEARCH:
			return 80.0
		if name == IONO:
			return 70.0
		if name == GREAT_BALL:
			return 30.0
		if name == CAPTURING_AROMA:
			return 70.0
		if name == JACQ:
			return 50.0
		if name == CARMINE:
			return 20.0
	if name == ULTRA_BALL:
		if owner_missing and owner_in_hand:
			if _needs_archeops_discard_setup(player):
				return 250.0
			return 120.0
		if _needs_archeops_discard_setup(player):
			return 560.0
		if _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
			return 440.0
		return 240.0
	if name == CAPTURING_AROMA:
		if owner_missing and owner_in_hand:
			if _needs_archeops_discard_setup(player):
				return 230.0
			return 110.0
		if _count_named_on_field(player, LUGIA_V) == 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
			return 360.0
		if _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
			return 380.0
		if _needs_archeops_discard_setup(player):
			return 320.0
		return 160.0
	if name == GREAT_BALL:
		return 210.0 if phase == "early" else 110.0
	if name == PROFESSORS_RESEARCH:
		return 220.0 if player.hand.size() <= 4 or _needs_archeops_discard_setup(player) else 130.0
	if name == IONO:
		return 170.0
	if name == CARMINE:
		return 190.0 if phase == "early" else 80.0
	if name == JACQ:
		return 230.0 if _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0 else 110.0
	if name == BOSSS_ORDERS:
		var gust_target := _best_gust_ko_target(game_state, player_index)
		if gust_target != null:
			return 760.0 + float(gust_target.get_prize_count()) * 120.0
		if _has_ready_attacker(player) and phase == "late":
			return 160.0
		return 0.0
	return 90.0


func _score_supporter_card(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return float(get_search_priority(card))
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var score := _score_trainer(card, player, phase, game_state, player_index)
	var name := _card_name(card)
	if name == JACQ and _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
		score += 40.0
	if name == THORTON and phase == "early":
		score -= 50.0
	if name == BOSSS_ORDERS and phase != "late":
		score -= 40.0
	return score


func _score_attach(
	card: CardInstance,
	target_slot: PokemonSlot,
	player: PlayerState,
	phase: String,
	game_state: GameState = null
) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var source_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	var archeops_online := _count_named_on_field(player, ARCHEOPS) > 0
	var owner_missing := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) == 0
	var initial_launch_window := game_state == null or game_state.turn_number <= 2
	if owner_missing and phase == "early" and initial_launch_window and target_name not in [LUGIA_V, LUGIA_VSTAR]:
		return 0.0
	if source_name == DOUBLE_TURBO_ENERGY:
		if target_name == LUGIA_V or target_name == LUGIA_VSTAR:
			return 420.0 if _attack_energy_gap(target_slot) > 0 else 90.0
		if target_name == CINCCINO or target_name == BLOODMOON_URSALUNA_EX:
			if target_name == CINCCINO and archeops_online:
				return 420.0
			return 320.0 if phase != "early" else 180.0
	if source_name == JET_ENERGY:
		if target_name == LUGIA_V or target_name == LUGIA_VSTAR:
			return 360.0 if phase == "early" else 170.0
		if target_name == IRON_HANDS_EX or target_name == WELLSPRING_OGERPON_EX:
			return 300.0 if phase != "early" else 170.0
	if source_name == GIFT_ENERGY:
		if target_name == LUGIA_VSTAR or target_name == LUGIA_V:
			return 340.0
		if target_name == CINCCINO:
			return 380.0 if archeops_online else 260.0
	if source_name == MIST_ENERGY or source_name == V_GUARD_ENERGY:
		if target_name == LUGIA_VSTAR or target_name == LUGIA_V:
			return 320.0
		if target_name == IRON_HANDS_EX:
			return 200.0
	if source_name == LEGACY_ENERGY:
		if target_name in [IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, LUGIA_VSTAR]:
			return 360.0
	if card.card_data.is_energy():
		if target_name == LUGIA_V or target_name == LUGIA_VSTAR:
			return 320.0
		if target_name == CINCCINO and str(card.card_data.card_type) == "Special Energy":
			return 360.0 if archeops_online else 280.0
		if target_name == IRON_HANDS_EX or target_name == CINCCINO:
			return 260.0
	return 90.0


func _score_use_ability(source_slot: PokemonSlot, game_state: GameState, player: PlayerState, phase: String) -> float:
	if source_slot == null:
		return 0.0
	var name := _slot_name(source_slot)
	if name == LUGIA_VSTAR:
		var archeops_in_discard := _count_named_in_discard(player, ARCHEOPS)
		if archeops_in_discard >= 2:
			return 760.0
		if archeops_in_discard == 1:
			return 620.0
		return 0.0
	if name == ARCHEOPS:
		var best_target := _best_special_energy_target(player)
		if best_target == null:
			return 140.0
		var gap := _attack_energy_gap(best_target)
		if gap > 0:
			return 640.0 - float(gap) * 40.0
		return 220.0
	if name == FEZANDIPITI_EX:
		if _should_cool_off_draw_churn(player, phase):
			return 0.0
		return 130.0
	return 0.0


func _score_retreat(game_state: GameState, player: PlayerState, phase: String, bench_target: PokemonSlot = null) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	var target := bench_target if bench_target != null else _best_ready_bench(player)
	if target == null:
		return 0.0
	var target_damage := 0
	if _attack_energy_gap(target) <= 0:
		target_damage = _best_attack_damage(target)
	if target_damage <= 0:
		return 0.0
	var active_damage := 0
	if _attack_energy_gap(player.active_pokemon) <= 0:
		active_damage = _best_attack_damage(player.active_pokemon)
	var opponent_hp := 0
	if game_state != null and player.player_index >= 0 and player.player_index < game_state.players.size():
		var opponent: PlayerState = game_state.players[1 - player.player_index]
		if opponent != null and opponent.active_pokemon != null:
			opponent_hp = opponent.active_pokemon.get_remaining_hp()
	var score := 90.0
	var active_name := _slot_name(player.active_pokemon)
	var target_name := _slot_name(target)
	if active_name == MINCCINO:
		score = 260.0
	if active_name == LUMINEON_V:
		score = maxf(score, 220.0)
	if active_name == LUGIA_V and phase == "late":
		score = maxf(score, 180.0)
	if target_name == CINCCINO:
		score += 120.0
	elif target_name == IRON_HANDS_EX:
		score += 80.0
	elif target_name == BLOODMOON_URSALUNA_EX:
		score += 60.0
	elif target_name in [LUMINEON_V, FEZANDIPITI_EX]:
		score -= 60.0
	if opponent_hp > 0:
		var active_misses := active_damage < opponent_hp
		var target_converts := target_damage >= opponent_hp
		if active_misses and target_converts:
			score += 640.0
		elif active_misses and target_damage > active_damage:
			score += 180.0
	elif target_damage > active_damage:
		score += 120.0
	return score


func _score_attack(action: Dictionary, game_state: GameState, player_index: int, phase: String) -> float:
	var player: PlayerState = game_state.players[player_index]
	var projected_damage := int(action.get("projected_damage", 0))
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	var projected_ko := defender != null and projected_damage >= defender.get_remaining_hp()
	var score := 500.0 + float(projected_damage)
	score += _launch_shell_attack_adjustment(player, projected_damage, projected_ko)
	if projected_ko:
		score += 300.0
	if phase == "late":
		score += 40.0
	return score


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		if name == ARCHEOPS:
			return 115
		if name == LUGIA_VSTAR:
			return 110
		if name == LUGIA_V:
			return 100
		if name == CINCCINO:
			return 80
		return 20
	var player: PlayerState = game_state.players[player_index]
	var turn_contract := get_turn_contract_context()
	var lugia_on_field := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR)
	var lugia_in_hand := _count_named_in_hand(player, LUGIA_V)
	var lugia_vstar_on_field := _count_named_on_field(player, LUGIA_VSTAR)
	var lugia_vstar_in_hand := _count_named_in_hand(player, LUGIA_VSTAR)
	var minccino_total := _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO) + _count_named_in_hand(player, MINCCINO) + _count_named_in_hand(player, CINCCINO)
	var engine_online := _count_named_on_field(player, ARCHEOPS) > 0
	var phase := _detect_phase(game_state, player)
	if lugia_on_field + lugia_in_hand == 0:
		if name == LUGIA_V:
			return 220 + _turn_contract_search_bonus(turn_contract, LUGIA_V)
		if name == ARCHEOPS:
			return 120
		if name == MINCCINO:
			return 150
	if lugia_on_field == 0 and lugia_in_hand > 0:
		if _archeops_search_candidate_is_needed(player, name):
			return 215
		if name == MINCCINO and minccino_total == 0:
			return 185
		if name == LUGIA_VSTAR and lugia_vstar_on_field + lugia_vstar_in_hand == 0:
			return 70
	if name == LUGIA_V and _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 150 + _turn_contract_search_bonus(turn_contract, LUGIA_V)
	if name == LUGIA_VSTAR and _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 260 + _turn_contract_search_bonus(turn_contract, LUGIA_VSTAR)
	if _archeops_search_candidate_is_needed(player, name):
		return 160 + _turn_contract_search_bonus(turn_contract, ARCHEOPS)
	if name == CINCCINO and _count_named_on_field(player, MINCCINO) > 0 and _count_named_on_field(player, CINCCINO) == 0:
		return 185
	if name == MINCCINO and _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO) == 0:
		return 110 + _turn_contract_search_bonus(turn_contract, MINCCINO)
	if name == BLOODMOON_URSALUNA_EX and engine_online and phase == "late":
		return 210
	if name == IRON_HANDS_EX and engine_online:
		return 160 if phase != "early" else 120
	if name in [FEZANDIPITI_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX, BLOODMOON_URSALUNA_EX] and (lugia_on_field + lugia_in_hand == 0 or (minccino_total == 0 and not engine_online)):
		return 10
	if name == BLOODMOON_URSALUNA_EX and phase == "late":
		return 130
	return 20


func _summon_target_score(card: CardInstance) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == ARCHEOPS:
		return 520.0
	if name == MINCCINO or name == CINCCINO:
		return 160.0
	return 60.0


func _assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source_card: CardInstance = context.get("source_card", null)
	var source_name := _card_name(source_card)
	var slot_name := _slot_name(slot)
	if source_name == DOUBLE_TURBO_ENERGY:
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 430.0
		if slot_name == CINCCINO or slot_name == BLOODMOON_URSALUNA_EX:
			return 360.0
	if source_name == JET_ENERGY:
		if slot_name == IRON_HANDS_EX or slot_name == WELLSPRING_OGERPON_EX:
			return 380.0
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 320.0
	if source_name == LEGACY_ENERGY:
		if slot_name == IRON_HANDS_EX or slot_name == BLOODMOON_URSALUNA_EX:
			return 420.0
		if slot_name == LUGIA_VSTAR:
			return 360.0
	if source_name == GIFT_ENERGY:
		if slot_name == CINCCINO:
			return 340.0
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 320.0
	if source_name == MIST_ENERGY or source_name == V_GUARD_ENERGY:
		if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			return 350.0
		if slot_name == IRON_HANDS_EX:
			return 220.0
	if slot_name == IRON_HANDS_EX:
		return 330.0
	if slot_name == CINCCINO:
		return 300.0
	if slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
		return 280.0
	if slot_name == BLOODMOON_URSALUNA_EX:
		return 260.0
	return 90.0


func _score_opponent_switch_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or _attack_energy_gap(player.active_pokemon) > 0:
		return 0.0
	var projected_damage := _best_attack_damage(player.active_pokemon)
	if projected_damage <= 0:
		return 0.0
	var score := 0.0
	var can_ko := projected_damage >= slot.get_remaining_hp()
	if can_ko:
		score += 520.0
		score += float(slot.get_prize_count()) * 180.0
	else:
		score -= 120.0
	score += float(slot.damage_counters) * 1.5
	score -= float(slot.get_remaining_hp()) * 0.35
	return score


func _tool_pressure(player: PlayerState) -> float:
	if player == null:
		return 0.0
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or slot.attached_tool == null:
			continue
		match _card_name(slot.attached_tool):
			FOREST_SEAL_STONE:
				score += 120.0
			MAXIMUM_BELT:
				score += 120.0
			DEFIANCE_BAND, SPARKLING_CRYSTAL:
				score += 90.0
			_:
				score += 45.0
	return score


func _collapsed_cleanup_value(player: PlayerState) -> float:
	if player == null or player.bench.size() <= 4:
		return 0.0
	var value := 60.0
	for slot: PokemonSlot in player.bench:
		var slot_name := _slot_name(slot)
		if slot_name == LUMINEON_V or slot_name == FEZANDIPITI_EX:
			value += 55.0
		elif slot_name == MINCCINO and _count_named_on_field(player, CINCCINO) > 0:
			value += 35.0
		elif slot_name in [WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX] and _attack_energy_gap(slot) > 0:
			value += 25.0
	return value




func _build_continuity_setup_debt(game_state: GameState, player_index: int, player: PlayerState) -> Dictionary:
	var archeops_field := _count_named_on_field(player, ARCHEOPS)
	var archeops_discard := _count_named_in_discard(player, ARCHEOPS)
	var archeops_hand := _count_named_in_hand(player, ARCHEOPS)
	var lugia_vstar_field := _count_named_on_field(player, LUGIA_VSTAR)
	var backup_seed_count := _continuity_backup_seed_count(player)
	var ready_backup_count := _continuity_ready_backup_count(player)
	var minccino_field := _count_named_on_field(player, MINCCINO)
	var cinccino_field := _count_named_on_field(player, CINCCINO)
	var best_backup := _best_continuity_backup_attacker(player)
	var backup_gap := _attack_energy_gap(best_backup) if best_backup != null else 999
	var vstar_unused := player_index >= 0 \
		and player_index < game_state.vstar_power_used.size() \
		and not bool(game_state.vstar_power_used[player_index])
	var bench_open := player != null and not player.is_bench_full()
	var has_archeops_route := vstar_unused \
		and (archeops_discard > 0 or archeops_hand > 0 or _has_card_named(player.deck, ARCHEOPS))
	var needs_second_archeops := archeops_field < 2 and has_archeops_route
	var needs_archeops_discard := needs_second_archeops and archeops_discard < mini(2, 2 - archeops_field)
	var needs_summoning_star := lugia_vstar_field > 0 and vstar_unused and archeops_field < 2 and archeops_discard > 0
	var needs_backup_seed := backup_seed_count == 0 and bench_open
	var needs_cinccino_evolution := minccino_field > 0 \
		and cinccino_field == 0 \
		and (_count_named_in_hand(player, CINCCINO) > 0 or _has_card_named(player.deck, CINCCINO))
	var needs_backup_energy := best_backup != null \
		and backup_gap > 0 \
		and (archeops_field > 0 or _hand_has_special_energy(player) or _count_special_energy_in_deck(player) > 0)
	return {
		"archeops_on_field_count": archeops_field,
		"archeops_in_discard_count": archeops_discard,
		"archeops_in_hand_count": archeops_hand,
		"backup_attacker_seed_count": backup_seed_count,
		"ready_backup_attacker_count": ready_backup_count,
		"backup_attacker_energy_gap": backup_gap,
		"needs_second_archeops": needs_second_archeops,
		"needs_archeops_discard_or_search": needs_archeops_discard,
		"needs_summoning_star": needs_summoning_star,
		"needs_backup_attacker_seed": needs_backup_seed,
		"needs_cinccino_evolution": needs_cinccino_evolution,
		"needs_second_attacker_energy": needs_backup_energy,
		"continuity_complete": archeops_field >= 2 and ready_backup_count > 0,
	}


func _build_continuity_action_bonuses(player: PlayerState, setup_debt: Dictionary) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if bool(setup_debt.get("needs_summoning_star", false)):
		bonuses.append(_continuity_bonus(
			"use_ability",
			[],
			620.0,
			"summon_second_archeops_before_nonterminal_attack",
			{"target_names": [LUGIA_VSTAR]}
		))
	if bool(setup_debt.get("needs_second_archeops", false)) or bool(setup_debt.get("needs_archeops_discard_or_search", false)):
		bonuses.append(_continuity_bonus(
			"play_trainer",
			[ULTRA_BALL, CAPTURING_AROMA, GREAT_BALL],
			560.0,
			"complete_dual_archeops_engine_before_nonterminal_attack"
		))
		bonuses.append(_continuity_bonus(
			"play_trainer",
			[PROFESSORS_RESEARCH, CARMINE, JACQ],
			260.0,
			"advance_archeops_discard_search_line_before_nonterminal_attack"
		))
	if bool(setup_debt.get("needs_backup_attacker_seed", false)):
		bonuses.append(_continuity_bonus(
			"play_basic_to_bench",
			[LUGIA_V, MINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX],
			480.0,
			"seed_backup_lugia_or_main_attacker_before_nonterminal_attack"
		))
		bonuses.append(_continuity_bonus(
			"play_trainer",
			[ULTRA_BALL, CAPTURING_AROMA, GREAT_BALL],
			360.0,
			"search_backup_lugia_or_main_attacker_before_nonterminal_attack"
		))
	if bool(setup_debt.get("needs_cinccino_evolution", false)):
		bonuses.append(_continuity_bonus(
			"evolve",
			[CINCCINO],
			430.0,
			"evolve_backup_cinccino_before_nonterminal_attack"
		))
		bonuses.append(_continuity_bonus(
			"play_trainer",
			[ULTRA_BALL, CAPTURING_AROMA, GREAT_BALL, JACQ],
			330.0,
			"search_cinccino_backup_attacker_before_nonterminal_attack"
		))
	if bool(setup_debt.get("needs_second_attacker_energy", false)):
		bonuses.append(_continuity_bonus(
			"use_ability",
			[],
			330.0,
			"archeops_relay_energy_to_followup_attacker_before_nonterminal_attack",
			{"target_names": [ARCHEOPS]}
		))
		bonuses.append(_continuity_bonus(
			"attach_energy",
			[DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY, V_GUARD_ENERGY, LEGACY_ENERGY],
			440.0,
			"manual_relay_special_energy_to_followup_attacker_before_nonterminal_attack",
			{"target_names": [LUGIA_V, LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]}
		))
	return bonuses


func _continuity_bonus(kind: String, card_names: Array[String], bonus: float, reason: String, extra: Dictionary = {}) -> Dictionary:
	var entry := {
		"kind": kind,
		"card_names": card_names.duplicate(),
		"bonus": bonus,
		"reason": reason,
	}
	for key: Variant in extra.keys():
		entry[key] = extra[key]
	return entry


func _continuity_setup_debt_is_active(setup_debt: Dictionary) -> bool:
	return bool(setup_debt.get("needs_second_archeops", false)) \
		or bool(setup_debt.get("needs_archeops_discard_or_search", false)) \
		or bool(setup_debt.get("needs_summoning_star", false)) \
		or bool(setup_debt.get("needs_backup_attacker_seed", false)) \
		or bool(setup_debt.get("needs_cinccino_evolution", false)) \
		or bool(setup_debt.get("needs_second_attacker_energy", false))


func _lugia_continuity_terminal_attack_locked(game_state: GameState, player_index: int, turn_contract: Dictionary) -> bool:
	var flags: Dictionary = turn_contract.get("flags", {}) if turn_contract.get("flags", {}) is Dictionary else {}
	var constraints: Dictionary = turn_contract.get("constraints", {}) if turn_contract.get("constraints", {}) is Dictionary else {}
	if bool(constraints.get("must_attack_if_available", false)):
		return true
	for key: String in ["final_prize_ko", "final_prize_ko_available", "critical_ko", "critical_ko_available", "key_ko", "key_ko_available", "force_terminal_attack"]:
		if bool(turn_contract.get(key, false)) or bool(flags.get(key, false)):
			return true
	return _lugia_final_prize_ko_is_available(game_state, player_index)


func _lugia_final_prize_ko_is_available(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.prizes.is_empty() or player.active_pokemon == null:
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	if player.prizes.size() > opponent.active_pokemon.get_prize_count():
		return false
	if _attack_energy_gap(player.active_pokemon) > 0:
		return false
	return _best_attack_damage(player.active_pokemon) >= opponent.active_pokemon.get_remaining_hp()


func _has_immediate_attack_window(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	return _attack_energy_gap(player.active_pokemon) <= 0 and _best_attack_damage(player.active_pokemon) > 0


func _continuity_backup_seed_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if _is_continuity_backup_seed(slot):
			count += 1
	return count


func _continuity_ready_backup_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if slot == null or _attack_energy_gap(slot) > 0:
			continue
		if _best_attack_damage(slot) > 0 and _is_continuity_energy_target(slot):
			count += 1
	return count


func _best_continuity_backup_attacker(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in player.bench:
		if not _is_continuity_energy_target(slot):
			continue
		var gap := _attack_energy_gap(slot)
		if gap >= 99:
			continue
		var score := -float(gap) * 120.0 + float(_best_attack_damage(slot))
		var slot_name := _slot_name(slot)
		if slot_name == CINCCINO:
			score += 90.0
		elif slot_name == LUGIA_VSTAR or slot_name == LUGIA_V:
			score += 70.0
		elif slot_name == IRON_HANDS_EX:
			score += 60.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _is_continuity_backup_seed(slot: PokemonSlot) -> bool:
	var slot_name := _slot_name(slot)
	return slot_name in [LUGIA_V, LUGIA_VSTAR, MINCCINO, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]


func _is_continuity_energy_target(slot: PokemonSlot) -> bool:
	var slot_name := _slot_name(slot)
	return slot_name in [LUGIA_V, LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]


func _hand_has_special_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			return true
	return false


func _count_special_energy_in_deck(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			count += 1
	return count


func _detect_phase(game_state: GameState, player: PlayerState) -> String:
	var archeops_count := _count_named_on_field(player, ARCHEOPS)
	var ready_bench := _best_ready_bench(player)
	var active_ready := player != null and player.active_pokemon != null and _attack_energy_gap(player.active_pokemon) <= 0 and _best_attack_damage(player.active_pokemon) > 0
	var prizes_left := player.prizes.size() if player != null else 0
	if prizes_left > 0 and prizes_left <= 2 and archeops_count >= 1:
		return "late"
	if game_state.turn_number <= 2 and archeops_count == 0 and not active_ready and ready_bench == null:
		return "early"
	if archeops_count >= 1:
		if active_ready or ready_bench != null:
			return "late"
		return "mid"
	if active_ready or ready_bench != null:
		return "mid"
	return "early"


func _best_lugia_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != LUGIA_V and slot_name != LUGIA_VSTAR:
			continue
		var score := float(slot.attached_energy.size()) * 44.0
		if slot_name == LUGIA_VSTAR:
			score += 220.0
		if slot == player.active_pokemon:
			score += 40.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_special_energy_target(player: PlayerState) -> PokemonSlot:
	var preferred: Array[String] = [CINCCINO, LUGIA_VSTAR, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, LUGIA_V]
	for target_name: String in preferred:
		for slot: PokemonSlot in _all_slots(player):
			if _slot_name(slot) != target_name:
				continue
			if _attack_energy_gap(slot) > 0:
				return slot
	return null


func _best_ready_bench(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in player.bench:
		if slot == null or _attack_energy_gap(slot) > 0:
			continue
		var damage := _best_attack_damage(slot)
		if damage <= 0:
			continue
		var score := float(damage)
		var slot_name := _slot_name(slot)
		if slot_name == CINCCINO:
			score += 120.0
		elif slot_name == IRON_HANDS_EX:
			score += 60.0
		elif slot_name == BLOODMOON_URSALUNA_EX:
			score += 40.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _score_handoff_target(slot: PokemonSlot, step_id: String, context: Dictionary = {}) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	if step_id == "send_out":
		return _send_out_target_score(slot, context)
	if step_id in ["self_switch_target", "switch_target", "pivot_target", "heavy_baton_target"]:
		var score := _send_out_target_score(slot, context)
		var turn_plan := _context_turn_plan(context)
		var pivot_target_name := _turn_contract_owner_name(turn_plan, "pivot_target_name")
		var turn_owner_name := _turn_contract_owner_name(turn_plan, "turn_owner_name")
		var slot_name := _slot_name(slot)
		if slot_name != "" and slot_name == pivot_target_name:
			score += 320.0
		elif slot_name != "" and slot_name == turn_owner_name:
			score += 220.0
		return score
	return 0.0


func _send_out_target_score(slot: PokemonSlot, context: Dictionary = {}) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var score := float(slot.get_remaining_hp()) * 0.45 - float(_attack_energy_gap(slot)) * 18.0
	var damage := _best_attack_damage(slot)
	if _attack_energy_gap(slot) <= 0 and damage > 0:
		score += 260.0 + float(damage)
	var slot_name := _slot_name(slot)
	match slot_name:
		CINCCINO:
			score += 180.0
		LUGIA_VSTAR:
			score += 140.0
		IRON_HANDS_EX:
			score += 110.0
		BLOODMOON_URSALUNA_EX:
			score += 90.0
		ARCHEOPS:
			score -= 160.0
		LUMINEON_V, FEZANDIPITI_EX:
			score -= 130.0
		MINCCINO:
			score -= 100.0
	return score


func _launch_shell_attack_adjustment(player: PlayerState, projected_damage: int, projected_ko: bool) -> float:
	if player == null or projected_ko:
		return 0.0
	var turn_contract := get_turn_contract_context()
	if not _is_launch_shell_state(player, turn_contract):
		return 0.0
	var active := player.active_pokemon
	var active_name := _slot_name(active)
	var owner_online := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) > 0
	var vstar_online := _count_named_on_field(player, LUGIA_VSTAR) > 0
	var engine_online := _count_named_on_field(player, ARCHEOPS) > 0
	if engine_online:
		return 0.0
	if not owner_online:
		return -380.0 if active_name not in [LUGIA_V, LUGIA_VSTAR] else -260.0
	if not vstar_online:
		return -340.0 if active_name not in [LUGIA_V, LUGIA_VSTAR] else -220.0
	if projected_damage < 100:
		return -120.0
	return 0.0


func _is_launch_shell_state(player: PlayerState, turn_contract: Dictionary = {}) -> bool:
	if player == null:
		return false
	if str(turn_contract.get("intent", "")) == "launch_shell":
		return true
	var engine_online := _count_named_on_field(player, ARCHEOPS) > 0
	if engine_online:
		return false
	var owner_online := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) > 0
	var vstar_online := _count_named_on_field(player, LUGIA_VSTAR) > 0
	return not owner_online or not vstar_online


func _should_cool_off_post_launch_padding(player: PlayerState, phase: String) -> bool:
	if player == null or phase == "early":
		return false
	if _count_named_on_field(player, ARCHEOPS) == 0:
		return false
	if player.active_pokemon != null and _attack_energy_gap(player.active_pokemon) <= 0 and _best_attack_damage(player.active_pokemon) > 0:
		return true
	return _best_ready_bench(player) != null


func _has_deck_out_pressure(player: PlayerState) -> bool:
	return player != null and player.deck.size() > 0 and player.deck.size() <= 14


func _has_ready_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	if player.active_pokemon != null and _attack_energy_gap(player.active_pokemon) <= 0 and _best_attack_damage(player.active_pokemon) > 0:
		return true
	return _best_ready_bench(player) != null


func _should_cool_off_draw_churn(player: PlayerState, phase: String) -> bool:
	return _has_deck_out_pressure(player) and _should_cool_off_post_launch_padding(player, phase) and _has_ready_attacker(player)


func _needs_archeops_discard_setup(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_named_on_field(player, ARCHEOPS) > 0:
		return false
	var staged_count := _count_named_in_discard(player, ARCHEOPS) + _count_named_in_hand(player, ARCHEOPS)
	if staged_count >= 2:
		return false
	return _has_card_named(player.deck, ARCHEOPS) or _count_named_in_hand(player, ARCHEOPS) > 0


func _archeops_search_candidate_is_needed(player: PlayerState, candidate_name: String) -> bool:
	if player == null or candidate_name != ARCHEOPS:
		return false
	if _count_named_on_field(player, ARCHEOPS) > 0:
		return false
	return _count_named_in_discard(player, ARCHEOPS) + _count_named_in_hand(player, ARCHEOPS) < 2


func _lugia_core_shell_pressure(player: PlayerState) -> bool:
	if player == null:
		return false
	var lugia_line := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR)
	var minccino_line := _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO)
	if lugia_line == 0 or minccino_line == 0:
		return true
	if _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return true
	if _count_named_on_field(player, ARCHEOPS) == 0 and _count_named_in_discard(player, ARCHEOPS) < 2:
		return true
	return false


func _best_gust_ko_target(game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if player == null or opponent == null or player.active_pokemon == null:
		return null
	if _attack_energy_gap(player.active_pokemon) > 0:
		return null
	var projected_damage := _best_attack_damage(player.active_pokemon)
	if projected_damage <= 0:
		return null
	var best: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in opponent.bench:
		if slot == null or slot.get_remaining_hp() <= 0:
			continue
		if projected_damage < slot.get_remaining_hp():
			continue
		var score := float(slot.get_prize_count()) * 300.0 + float(slot.damage_counters) * 1.5 - float(slot.get_remaining_hp()) * 0.25
		if score > best_score:
			best_score = score
			best = slot
	return best


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var min_gap := 99
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		min_gap = mini(min_gap, maxi(0, cost.length() - slot.attached_energy.size()))
	return min_gap


func _best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var slot_name := _slot_name(slot)
	if slot_name == CINCCINO:
		var special_count := 0
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and str(energy.card_data.card_type) == "Special Energy":
				special_count += 1
		var scaled_damage := special_count * 70 if slot.attached_energy.size() >= 2 else 0
		var fallback_damage := 30 if slot.attached_energy.size() >= 1 else 0
		return maxi(scaled_damage, fallback_damage)
	var best := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		best = maxi(best, _parse_damage(str(attack.get("damage", "0"))))
	return best


func _context_turn_plan(context: Dictionary) -> Dictionary:
	if context.get("turn_contract", {}) is Dictionary:
		return context.get("turn_contract", {})
	if context.get("turn_plan", {}) is Dictionary:
		return context.get("turn_plan", {})
	return get_turn_contract_context()


func _turn_contract_owner_name(turn_plan: Dictionary, key: String) -> String:
	if not (turn_plan.get("owner", {}) is Dictionary):
		return ""
	var owner: Dictionary = turn_plan.get("owner", {})
	return str(owner.get(key, ""))


func _count_total_special_energy(player: PlayerState) -> int:
	var total := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			total += 1
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			total += 1
	return total


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _count_named_on_field(player: PlayerState, target_name: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is(slot, [target_name]):
			count += 1
	return count


func _count_named_in_hand(player: PlayerState, target_name: String) -> int:
	var count := 0
	for card: CardInstance in player.hand:
		if _card_name(card) == target_name:
			count += 1
	return count


func _count_named_in_discard(player: PlayerState, target_name: String) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if _card_name(card) == target_name:
			count += 1
	return count


func _has_card_named(cards: Array, target_name: String) -> bool:
	for item: Variant in cards:
		if item is CardInstance and _card_name(item as CardInstance) == target_name:
			return true
	return false


func _turn_contract_search_bonus(turn_contract: Dictionary, value: String) -> int:
	var priorities: Variant = turn_contract.get("priorities", {})
	if not (priorities is Dictionary):
		return 0
	var values: Variant = (priorities as Dictionary).get("search", [])
	if not (values is Array):
		return 0
	var idx := (values as Array).find(value)
	if idx < 0:
		return 0
	return 35 if idx == 0 else 15


func _card_name(card: Variant) -> String:
	if not (card is CardInstance):
		return ""
	var inst := card as CardInstance
	if inst.card_data == null:
		return ""
	if str(inst.card_data.name_en) != "":
		return str(inst.card_data.name_en)
	return str(inst.card_data.name)


func _parse_damage(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0
