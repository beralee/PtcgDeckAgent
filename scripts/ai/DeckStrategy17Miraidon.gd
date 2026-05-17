class_name DeckStrategy17Miraidon
extends "res://scripts/ai/DeckStrategyMiraidon.gd"

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")

const V17_UNHANDLED := -987654321.0

const MIRAIDON := "Miraidon ex"
const IRON_HANDS := "Iron Hands ex"
const RAIKOU := "Raikou V"
const RAICHU := "Raichu V"
const MEW := "Mew ex"
const LATIAS := "Latias ex"
const LUMINEON := "Lumineon V"
const SQUAWK := "Squawkabilly ex"
const FEZANDIPITI := "Fezandipiti ex"
const IRON_BUNDLE := "Iron Bundle"
const MAGNEMITE := "Magnemite"
const MAGNETON_ID := "CBB5C_0301"
const PIKACHU_ID := "CSV9C_054"
const LATIAS_ID := "CSV9C_078"
const AREA_ZERO_ID := "CSV9C_207"

const V17_DOUBLE_TURBO := "Double Turbo Energy"
const V17_NEST_BALL := "Nest Ball"
const V17_ULTRA_BALL := "Ultra Ball"
const V17_ELECTRIC_GENERATOR := "Electric Generator"
const V17_ARVEN := "Arven"
const V17_SECRET_BOX := "Secret Box"
const V17_BOSS := "Boss's Orders"
const V17_COUNTER_CATCHER := "Counter Catcher"
const V17_HEAVY_BALL := "Hisuian Heavy Ball"
const V17_RESCUE_BOARD := "Rescue Board"
const V17_BRAVERY_CHARM := "Bravery Charm"
const V17_FOREST_SEAL := "Forest Seal Stone"
const V17_NIGHT_STRETCHER := "Night Stretcher"


func get_strategy_id() -> String:
	return "v17_miraidon"


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_signature_names() -> Array[String]:
	var signatures := super.get_signature_names()
	for name: String in [MIRAIDON, IRON_HANDS, RAIKOU, RAICHU, V17_ELECTRIC_GENERATOR, PIKACHU_ID, LATIAS_ID]:
		if not signatures.has(name):
			signatures.append(name)
	return signatures


func get_intent_planner_profile() -> Dictionary:
	return {
		"primary_attackers": [IRON_HANDS, RAIKOU, RAICHU, MIRAIDON, PIKACHU_ID],
		"bench_priorities": [MIRAIDON, IRON_HANDS, RAIKOU, LATIAS, RAICHU, PIKACHU_ID],
		"search_priorities": [MIRAIDON, IRON_HANDS, RAIKOU, LATIAS, RAICHU, PIKACHU_ID],
		"evolution_priorities": [MAGNETON_ID],
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or card.card_data == null or not card.is_basic_pokemon():
			continue
		basics.append({"index": i, "active": _opening_active_score_v17(card), "bench": _opening_bench_score_v17(card)})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("active", 0.0)) > float(b.get("active", 0.0))
	)
	var active_index := int(basics[0].get("index", -1))
	var bench_entries := basics.duplicate(true)
	bench_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("bench", 0.0)) > float(b.get("bench", 0.0))
	)
	var bench_indices: Array[int] = []
	for entry: Dictionary in bench_entries:
		var idx := int(entry.get("index", -1))
		if idx == active_index:
			continue
		if float(entry.get("bench", 0.0)) <= 0.0:
			continue
		bench_indices.append(idx)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := V17_UNHANDLED
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			score = _score_play_basic_v17(action, game_state, player)
		"attach_energy":
			score = _score_attach_energy_v17(action, player)
		"attach_tool":
			score = _score_attach_tool_v17(action, player)
		"use_ability":
			score = _score_ability_v17(action, game_state, player)
		"play_trainer", "play_stadium":
			score = _score_trainer_v17(action, game_state, player, player_index)
		"retreat":
			score = _score_retreat_v17(action, game_state, player, player_index)
		"attack", "granted_attack":
			score = _score_attack_v17(action, game_state, player, player_index)
		"end_turn":
			return -120.0
	return score if score != V17_UNHANDLED else super.score_action_absolute(action, game_state, player_index)


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var owner_name := IRON_HANDS
	var bridge_name := IRON_HANDS
	var pivot_name := MEW
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		var ready := _best_ready_attacker(player)
		if ready != null:
			owner_name = _primary_name_v17(ready)
			pivot_name = owner_name
		else:
			var bridge := _best_generator_target_slot(player)
			if bridge != null:
				bridge_name = _primary_name_v17(bridge)
				owner_name = bridge_name
	return {
		"id": "v17_miraidon_rules",
		"intent": "lightning_prize_race",
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": pivot_name,
		},
		"priorities": {
			"attach": [IRON_HANDS, RAIKOU, RAICHU, PIKACHU_ID, MIRAIDON],
			"handoff": [MEW, RAIKOU, IRON_HANDS, RAICHU, LATIAS],
			"search": [MIRAIDON, IRON_HANDS, RAIKOU, LATIAS, RAICHU, PIKACHU_ID],
		},
		"constraints": {"avoid_engine_churn": true},
	}


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard_energy"):
			return 300.0 if _is_lightning_energy(card) else 20.0
		if step_id.contains("discard"):
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		var card_score := _search_card_score(card, step, context)
		if card_score != V17_UNHANDLED:
			return card_score
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id.contains("assign") or step_id.contains("attach") or step_id.contains("energy"):
			return _generator_target_score(slot, context)
		if _is_opponent_target_step_v17(step_id):
			return _opponent_target_score_v17(slot, context)
		if step_id.contains("switch") or step_id.contains("send") or step_id.contains("active") or step_id.contains("handoff") or step_id.contains("target"):
			return _handoff_target_score_v17(slot, step_id, context)
		return _slot_score(slot)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		return _handoff_target_score_v17(item as PokemonSlot, str(step.get("id", "")), context)
	return score_interaction_target(item, step, context)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		max_select = 1
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		ranked.append({"item": item, "score": score_interaction_target(item, step, context)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var selected: Array = []
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		selected.append(entry.get("item"))
	return selected


func get_search_priority(card: CardInstance) -> int:
	var score := _search_card_score(card, {"id": "generic_search"}, {})
	return int(round(score)) if score != V17_UNHANDLED else super.get_search_priority(card)


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _is_core_pokemon(card):
		return 5
	if _is_lightning_energy(card):
		return 70
	if _is_support_pokemon(card):
		return 145
	if _matches(card, [V17_NEST_BALL, V17_ULTRA_BALL, V17_ELECTRIC_GENERATOR, V17_ARVEN]):
		return 35
	return super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if _is_miraidon(card) and _count_on_field(player, [MIRAIDON, "CSV1C_050"]) > 0:
			return 120
		if _is_support_pokemon(card) and _count_on_field(player, _labels(card)) > 0:
			return 170
	return get_discard_priority(card)


func predict_attacker_damage(slot: PokemonSlot, extra_energy: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	if _is_raichu(slot):
		var lightning := _attached_type_units(slot, "L") + extra_energy
		return {"damage": lightning * 60, "can_attack": _attack_gap(slot, extra_energy) == 0, "description": "Dynamic Spark"}
	return {"damage": _best_attack_damage_v17(slot, extra_energy), "can_attack": _attack_gap(slot, extra_energy) == 0, "description": ""}


func _opening_active_score_v17(card: CardInstance) -> float:
	if _is_mew(card): return 1000.0
	if _is_latias(card): return 930.0
	if _is_raikou(card): return 880.0
	if _is_squawk(card): return 760.0
	if _is_iron_bundle(card): return 730.0
	if _is_iron_hands(card): return 620.0
	if _is_raichu(card): return 520.0
	if _is_pikachu(card): return 500.0
	if _is_miraidon(card): return 160.0
	if _is_lumineon(card) or _is_fezandipiti(card): return 240.0
	return 100.0


func _opening_bench_score_v17(card: CardInstance) -> float:
	if _is_miraidon(card): return 1050.0
	if _is_iron_hands(card): return 980.0
	if _is_raikou(card): return 940.0
	if _is_latias(card): return 820.0
	if _is_pikachu(card): return 500.0
	if _is_raichu(card): return 690.0
	if _is_magnemite(card) or _is_magneton(card): return 520.0
	if _is_fezandipiti(card): return 500.0
	if _is_mew(card): return 440.0
	if _is_squawk(card): return 420.0
	if _is_iron_bundle(card): return 360.0
	if _is_lumineon(card): return 180.0
	return 80.0


func _score_play_basic_v17(action: Dictionary, game_state: GameState, player: PlayerState) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null or not _is_known_pokemon(card):
		return V17_UNHANDLED
	if player == null or _bench_is_full_v17(game_state, player):
		return 0.0
	var turn := int(game_state.turn_number) if game_state != null else 0
	if _is_miraidon(card): return 720.0 if _count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0 else 220.0
	if _is_iron_hands(card): return 640.0 if _count_on_field(player, [IRON_HANDS, "CSV6C_051"]) == 0 else 230.0
	if _is_raikou(card): return 610.0 if _count_on_field(player, [RAIKOU, "CS4DaC_137"]) == 0 else 220.0
	if _is_latias(card): return 500.0 if _count_on_field(player, [LATIAS, LATIAS_ID]) == 0 else 120.0
	if _is_pikachu(card):
		if _count_on_field(player, [PIKACHU_ID]) == 0:
			return 320.0 if _has_area_zero_access_v17(player, game_state) else 260.0
		return 180.0
	if _is_raichu(card): return 360.0 if turn >= 4 else 130.0
	if _is_squawk(card): return 430.0 if turn <= 2 else 80.0
	if _is_fezandipiti(card): return 300.0
	if _is_lumineon(card): return 260.0 if player.bench.size() <= 3 else 70.0
	return 120.0


func _score_attach_energy_v17(action: Dictionary, player: PlayerState) -> float:
	var target: PokemonSlot = action.get("target_slot", null)
	var energy: CardInstance = action.get("card", null)
	if target == null or energy == null or energy.card_data == null:
		return 0.0
	if not _is_known_pokemon(target) and not _is_lightning_energy(energy) and not _is_double_turbo(energy):
		return V17_UNHANDLED
	if _is_double_turbo(energy):
		if not _is_iron_hands(target):
			return -160.0
		var dte_gap := _attack_gap(target, 0, 2)
		return 590.0 if dte_gap == 0 else (430.0 if dte_gap == 1 else 120.0)
	if not _is_lightning_energy(energy):
		return V17_UNHANDLED
	if _is_support_pokemon(target):
		if player != null and target == player.active_pokemon and not _has_better_attach_target(player, target):
			return 65.0
		return -80.0
	if _energy_full_after(target, 0) and not _is_raichu(target):
		return 12.0
	var gap_after := _attack_gap(target, 1)
	if player != null and _count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0 and target == player.active_pokemon and not _is_main_attacker(target):
		return 35.0
	if _is_iron_hands(target): return 700.0 if gap_after == 0 else (500.0 if gap_after == 1 else 390.0)
	if _is_raikou(target): return 680.0 if gap_after == 0 else (420.0 if gap_after == 1 else 260.0)
	if _is_raichu(target): return 560.0 if _total_lightning_energy(player) >= 3 else (260.0 if gap_after <= 1 else 140.0)
	if _is_pikachu(target): return 330.0 if gap_after <= 1 else 210.0
	if _is_miraidon(target): return 310.0 if player != null and target == player.active_pokemon and gap_after == 0 else 90.0
	if _is_magneton(target) or _is_magnemite(target): return 150.0
	return 60.0


func _score_attach_tool_v17(action: Dictionary, player: PlayerState) -> float:
	var target: PokemonSlot = action.get("target_slot", null)
	var tool: CardInstance = action.get("card", null)
	if target == null or tool == null or tool.card_data == null:
		return 0.0
	if not _is_known_pokemon(target):
		return V17_UNHANDLED
	if _matches(tool, [V17_RESCUE_BOARD, "CSV7C_185"]):
		return 350.0 if _is_mew(target) or _is_latias(target) or (player != null and target == player.active_pokemon) else 120.0
	if _matches(tool, [V17_BRAVERY_CHARM, "CSV1C_115"]):
		return 330.0 if _is_iron_hands(target) or _is_raichu(target) or _is_pikachu(target) else 90.0
	if _matches(tool, [V17_FOREST_SEAL, "CS5aC_093"]):
		return 310.0 if _has_v_mechanic(target) else 50.0
	return 90.0


func _score_ability_v17(action: Dictionary, game_state: GameState, player: PlayerState) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null or not _is_known_pokemon(source):
		return V17_UNHANDLED
	if _is_miraidon(source):
		if _action_has_empty_bench_selection(action):
			return 10.0
		if player == null or _bench_is_full_v17(game_state, player):
			return 25.0
		if _count_lightning_basics_in_deck(player) <= 0:
			return 20.0
		if _count_on_field(player, [IRON_HANDS, "CSV6C_051"]) == 0:
			return 680.0
		if _count_on_field(player, [RAIKOU, "CS4DaC_137"]) == 0:
			return 640.0
		if _count_on_field(player, [LATIAS, LATIAS_ID]) == 0 and player.bench.size() <= 3:
			return 520.0
		return 430.0
	if _is_raikou(source):
		return 330.0 if player != null and source == player.active_pokemon else 0.0
	if _is_mew(source):
		return 285.0 if player != null and player.hand.size() <= 3 else 95.0
	if _is_squawk(source):
		var turn := int(game_state.turn_number) if game_state != null else 0
		return 430.0 if turn <= 2 else 65.0
	if _is_fezandipiti(source): return 260.0
	if _is_lumineon(source): return 300.0
	return V17_UNHANDLED


func _score_trainer_v17(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return 0.0
	var turn := int(game_state.turn_number) if game_state != null else 0
	var bench_full := player != null and _bench_is_full_v17(game_state, player)
	if _matches(card, [V17_NEST_BALL]):
		if bench_full: return 0.0
		if player != null and _count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0: return 720.0
		if player != null and _area_zero_in_play_v17(game_state) and _bench_space_v17(game_state, player) > 0: return 560.0
		if player != null and not _has_generator_attacker_target(player): return 620.0
		return 420.0 if turn <= 2 else 240.0
	if _matches(card, [V17_ULTRA_BALL, V17_HEAVY_BALL]):
		if player != null and _count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0: return 720.0
		if player != null and not _has_generator_attacker_target(player): return 620.0
		return 420.0 if turn <= 2 else 240.0
	if _matches(card, [V17_ELECTRIC_GENERATOR, "CSV1C_107"]):
		if player == null or not _has_useful_generator_target(player): return 25.0
		if _count_lightning_in_deck(player) <= 0: return 0.0
		if _count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0: return 290.0
		return 590.0 if _best_generator_target_score(player) >= 450.0 else 360.0
	if _matches(card, [V17_ARVEN, "CSV1C_123"]):
		if player != null and (_count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0 or _has_useful_generator_target(player)):
			return 520.0
		return 250.0
	if _matches(card, [V17_SECRET_BOX, "CSV8C_176"]):
		if player != null and turn <= 3 and (_count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0 or _has_useful_generator_target(player)):
			return 500.0
		return 120.0
	if _matches(card, [V17_BOSS, V17_COUNTER_CATCHER]):
		var gust_score := _best_opponent_bench_target_score_v17(game_state, player_index)
		if player != null and _is_iron_hands(player.active_pokemon) and _iron_hands_amp_ready_v17(player.active_pokemon) and gust_score >= 780.0:
			return 780.0
		if _gust_can_close_game_v17(game_state, player, player_index):
			return 720.0
		return 690.0 if _can_current_attacker_take_prize(game_state, player, player_index) else 130.0
	if _matches(card, [V17_NIGHT_STRETCHER]): return 210.0
	if _matches(card, [AREA_ZERO_ID]):
		if player != null and _area_zero_in_play_v17(game_state):
			return 30.0
		if player != null and _area_zero_expansion_ready_v17(player, game_state):
			return 760.0 if player.bench.size() >= 5 else 650.0
		if player != null and _count_on_field(player, [PIKACHU_ID]) > 0:
			return 320.0 if player.bench.size() >= 5 else 250.0
		if player != null and _has_tera_on_field_v17(player):
			return 300.0 if player.bench.size() >= 5 else 210.0
		return 80.0
	return V17_UNHANDLED


func _score_retreat_v17(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	var target: PokemonSlot = action.get("bench_target", null)
	if target == null:
		return 0.0
	if not _is_known_pokemon(player.active_pokemon) and not _is_known_pokemon(target):
		return V17_UNHANDLED
	var active := player.active_pokemon
	var target_ready := _can_attack_v17(target)
	var target_attacker := _is_attacker(target)
	var target_gap := _attack_gap(target)
	if _is_mew(active) or _is_latias(active):
		if target_ready and target_attacker:
			return 780.0 + float(_best_attack_damage_v17(target)) * 0.3
		if target_gap == 1 and target_attacker:
			return 300.0
		return -70.0
	if _can_attack_v17(active) and not _retreat_target_is_better_prize_line(target, game_state, player_index):
		return -180.0
	if target_ready and target_attacker:
		return 640.0 + float(_best_attack_damage_v17(target)) * 0.25
	if target_gap == 1 and target_attacker:
		return 230.0
	if _is_mew(target) or _is_latias(target):
		return 140.0
	return -120.0


func _score_attack_v17(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var active: PokemonSlot = action.get("source_slot", null)
	if active == null and player != null:
		active = player.active_pokemon
	if active == null or not _is_known_pokemon(active):
		return V17_UNHANDLED
	var defender := _opponent_active(game_state, player_index)
	var defender_hp := defender.get_remaining_hp() if defender != null else 999
	var attack_index := int(action.get("attack_index", 0))
	var attack_name := str(action.get("attack_name", ""))
	var damage := int(action.get("projected_damage", 0))
	if damage <= 0:
		if _is_raikou(active) and (attack_index == 0 or attack_name == "Lightning Rondo" or attack_name == "雷电回旋曲" or attack_name == "闪电回旋"):
			damage = _visible_board_damage_v17(active, game_state, player_index)
		else:
			damage = _damage_for_attack_action(active, attack_index, attack_name, player)
	if _is_raichu(active):
		var burst := _total_lightning_energy(player) * 60
		if attack_index == 1 or attack_name == "Dynamic Spark":
			if burst >= defender_hp: return 1120.0 if _is_rulebox(defender) else 900.0
			if burst >= 240: return 560.0 + float(burst)
			if burst >= 180: return 390.0 + float(burst)
			return 90.0
		if attack_index == 0 or attack_name == "Fast Charge":
			return 30.0 if burst >= 180 else 250.0
	if _is_iron_hands(active) and attack_index == 1:
		if damage >= defender_hp: return 1260.0 if _is_rulebox(defender) else 1060.0
		return 260.0 + float(damage)
	if damage >= defender_hp:
		return (1080.0 if _is_rulebox(defender) else 860.0) + float(damage) * 0.25
	if damage > 0:
		return 180.0 + float(damage) * 1.8
	return 40.0


func _search_card_score(card: CardInstance, step: Dictionary, context: Dictionary = {}) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var player := _context_player(context)
	var game_state: GameState = context.get("game_state", null)
	var step_id := str(step.get("id", "")).to_lower()
	var is_basic_search := step_id.contains("basic")
	var is_bench_search := step_id.contains("bench")
	if _is_miraidon(card):
		if player != null and _count_on_field(player, [MIRAIDON, "CSV1C_050"]) == 0:
			return 1120.0 if is_basic_search else 930.0
		return 360.0
	if _is_iron_hands(card):
		if player != null and _count_on_field(player, [IRON_HANDS, "CSV6C_051"]) == 0:
			return 980.0 if is_bench_search else 690.0
		return 360.0
	if _is_raikou(card):
		if player != null and _count_on_field(player, [RAIKOU, "CS4DaC_137"]) == 0:
			return 940.0 if is_bench_search else 640.0
		return 300.0
	if _is_latias(card): return 680.0 if player != null and _count_on_field(player, [LATIAS, LATIAS_ID]) == 0 else 180.0
	if _is_pikachu(card):
		if player != null and _count_on_field(player, [PIKACHU_ID]) == 0:
			if _needs_pikachu_area_zero_shell_v17(player, game_state):
				return 880.0 if is_bench_search else 820.0
			return 380.0
		return 260.0
	if _is_raichu(card): return 440.0
	if _is_squawk(card): return 520.0 if player != null and player.bench.size() <= 3 else 120.0
	if _is_lumineon(card): return -80.0
	if _is_fezandipiti(card): return 260.0
	if _is_magnemite(card) or _is_magneton(card): return 220.0
	if _matches(card, [V17_ELECTRIC_GENERATOR, "CSV1C_107"]): return 620.0 if player != null and _has_useful_generator_target(player) else 80.0
	if _matches(card, [V17_NEST_BALL, V17_ULTRA_BALL, V17_ARVEN, V17_SECRET_BOX]): return 500.0
	if _matches(card, [V17_RESCUE_BOARD, V17_BRAVERY_CHARM, V17_FOREST_SEAL]): return 320.0
	if _is_lightning_energy(card): return 210.0
	return V17_UNHANDLED


func _generator_target_score(slot: PokemonSlot, context: Dictionary = {}) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	if not _is_generator_eligible(slot):
		return -120.0
	var player := _context_player(context)
	var pending := _pending_assignments_for_slot(slot, context)
	if _energy_full_after(slot, pending) and not _is_raichu(slot):
		return 5.0
	if _is_support_pokemon(slot):
		return 8.0
	var gap_after := _attack_gap(slot, pending + 1)
	var revenge_bonus := _revenge_bonus(slot, context)
	if _is_raikou(slot):
		if gap_after == 0: return 760.0 + revenge_bonus
		if gap_after == 1: return 560.0 + revenge_bonus
		return 360.0 + revenge_bonus
	if _is_iron_hands(slot):
		if gap_after == 0: return 740.0 + revenge_bonus
		if gap_after == 1: return 650.0 + revenge_bonus
		if gap_after == 2: return 520.0 + revenge_bonus
		return 430.0 + revenge_bonus
	if _is_raichu(slot): return 520.0 if _total_lightning_energy(player) >= 3 else 280.0
	if _is_pikachu(slot): return 260.0
	if _is_miraidon(slot): return 70.0 if player != null and _has_non_miraidon_generator_target(player) else 220.0
	if _is_magneton(slot) or _is_magnemite(slot): return 150.0
	return 80.0


func _handoff_target_score_v17(slot: PokemonSlot, step_id: String, context: Dictionary = {}) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var ready := _can_attack_v17(slot)
	var attacker := _is_attacker(slot)
	var gap := _attack_gap(slot)
	var damage := _best_attack_damage_v17(slot)
	if step_id.to_lower().contains("send"):
		if _is_mew(slot): return 1200.0
		if ready and attacker: return 820.0 + float(damage) * 0.5
		if _is_latias(slot): return 650.0
		if gap == 1 and attacker: return 480.0
		if _is_support_pokemon(slot): return 60.0
	var score := float(slot.get_remaining_hp()) * 0.25
	if ready and attacker:
		score += 520.0 + float(damage) * 0.8
	elif gap == 1 and attacker:
		score += 220.0
	if _is_raikou(slot): score += 170.0
	elif _is_iron_hands(slot): score += 150.0
	elif _is_raichu(slot): score += 130.0
	elif _is_mew(slot) or _is_latias(slot): score += 90.0
	elif _is_support_pokemon(slot): score -= 260.0
	if _is_miraidon(slot) and not ready:
		score -= 140.0
	return score


func _is_opponent_target_step_v17(step_id: String) -> bool:
	var lowered := step_id.to_lower()
	return lowered.contains("opponent") or lowered.contains("enemy") or lowered.contains("gust")


func _opponent_target_score_v17(slot: PokemonSlot, context: Dictionary = {}) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return _opponent_target_role_score_v17(slot)
	var player: PlayerState = game_state.players[player_index]
	var damage := _current_attacker_damage_for_targeting_v17(game_state, player, player_index)
	var remaining_hp := slot.get_remaining_hp()
	var prize_count := slot.get_prize_count()
	var role_score := _opponent_target_role_score_v17(slot)
	if damage > 0 and remaining_hp <= damage:
		var score := 880.0 + float(prize_count) * 180.0 + role_score
		if player != null and _is_iron_hands(player.active_pokemon) and _iron_hands_amp_ready_v17(player.active_pokemon):
			score += 260.0
		score -= float(remaining_hp) * 0.08
		return score
	var pressure := 140.0 + role_score * 0.6 + float(prize_count) * 80.0
	pressure -= float(remaining_hp) * 0.18
	return pressure


func _best_opponent_bench_target_score_v17(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0.0
	var best := 0.0
	var context := {"game_state": game_state, "player_index": player_index}
	for slot: PokemonSlot in game_state.players[opponent_index].bench:
		best = maxf(best, _opponent_target_score_v17(slot, context))
	return best


func _gust_can_close_game_v17(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.prizes.is_empty() or player_index < 0 or player_index >= game_state.players.size():
		return false
	if player.active_pokemon == null or not _can_attack_v17(player.active_pokemon):
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var damage := _current_attacker_damage_for_targeting_v17(game_state, player, player_index)
	if damage <= 0:
		return false
	for slot: PokemonSlot in game_state.players[opponent_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= damage and slot.get_prize_count() >= player.prizes.size():
			return true
	return false


func _opponent_target_role_score_v17(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	if _matches(slot, ["Charmander", "Pidgey", "Duskull", "Cleffa"]):
		return 260.0
	if _matches(slot, ["Pidgeot ex", "Dusknoir", "Dusclops", "Rotom V", LUMINEON]):
		return 220.0
	if _matches(slot, ["Charizard ex"]):
		return 120.0
	return 40.0


func _slot_score(slot: PokemonSlot) -> float:
	if _is_iron_hands(slot): return 500.0
	if _is_raikou(slot): return 470.0
	if _is_miraidon(slot): return 430.0
	if _is_latias(slot): return 360.0
	if _is_raichu(slot): return 340.0
	if _is_pikachu(slot): return 300.0
	if _is_support_pokemon(slot): return 130.0
	return 80.0


func _context_player(context: Dictionary) -> PlayerState:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _bench_limit_v17(game_state: GameState, player: PlayerState) -> int:
	if game_state == null or player == null:
		return 5
	return BenchLimit.get_bench_limit_for_player(game_state, player)


func _bench_space_v17(game_state: GameState, player: PlayerState) -> int:
	if player == null:
		return 0
	return maxi(0, _bench_limit_v17(game_state, player) - player.bench.size())


func _bench_is_full_v17(game_state: GameState, player: PlayerState) -> bool:
	return player == null or _bench_space_v17(game_state, player) <= 0


func _area_zero_in_play_v17(game_state: GameState) -> bool:
	return game_state != null and game_state.stadium_card != null and _matches(game_state.stadium_card, [AREA_ZERO_ID])


func _has_area_zero_in_hand_v17(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _matches(card, [AREA_ZERO_ID]):
			return true
	return false


func _has_area_zero_access_v17(player: PlayerState, game_state: GameState) -> bool:
	return _area_zero_in_play_v17(game_state) or _has_area_zero_in_hand_v17(player)


func _has_tera_on_field_v17(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots_v17(player):
		var cd := _card_data(slot)
		if cd != null and cd.is_tera_pokemon():
			return true
	return false


func _needs_pikachu_area_zero_shell_v17(player: PlayerState, game_state: GameState) -> bool:
	if player == null or _count_on_field(player, [PIKACHU_ID]) > 0:
		return false
	if not _has_area_zero_access_v17(player, game_state):
		return false
	return player.bench.size() >= 3 or _count_on_field(player, [MIRAIDON, "CSV1C_050"]) > 0


func _area_zero_expansion_ready_v17(player: PlayerState, game_state: GameState) -> bool:
	if player == null or _area_zero_in_play_v17(game_state):
		return false
	if _count_on_field(player, [PIKACHU_ID]) <= 0 and not _has_tera_on_field_v17(player):
		return false
	return player.bench.size() >= 4


func _card_data(item: Variant) -> CardData:
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	if item is CardData:
		return item as CardData
	return null


func _labels(item: Variant) -> Array[String]:
	var labels: Array[String] = []
	var cd := _card_data(item)
	if cd == null:
		_append_label_v17(labels, str(item))
		return labels
	_append_label_v17(labels, str(cd.name))
	_append_label_v17(labels, str(cd.name_en))
	_append_label_v17(labels, str(cd.get_uid()))
	if str(cd.set_code) != "" and str(cd.card_index) != "":
		_append_label_v17(labels, "%s_%s" % [str(cd.set_code), str(cd.card_index)])
	_append_label_v17(labels, str(cd.effect_id))
	return labels


func _append_label_v17(labels: Array[String], label: String) -> void:
	var normalized := label.strip_edges()
	if normalized != "" and not labels.has(normalized):
		labels.append(normalized)


func _matches(item: Variant, keys: Array) -> bool:
	var lowered_keys: Array[String] = []
	for key: Variant in keys:
		lowered_keys.append(str(key).strip_edges().to_lower())
	for label: String in _labels(item):
		if label.to_lower() in lowered_keys:
			return true
	return false


func _primary_name_v17(item: Variant) -> String:
	var cd := _card_data(item)
	if cd == null:
		return str(item)
	if str(cd.name_en) != "":
		return str(cd.name_en)
	if str(cd.set_code) != "" and str(cd.card_index) != "":
		return "%s_%s" % [str(cd.set_code), str(cd.card_index)]
	return str(cd.name)


func _is_miraidon(item: Variant) -> bool: return _matches(item, [MIRAIDON, "CSV1C_050"])
func _is_iron_hands(item: Variant) -> bool: return _matches(item, [IRON_HANDS, "CSV6C_051"])
func _is_raikou(item: Variant) -> bool: return _matches(item, [RAIKOU, "CS4DaC_137"])
func _is_raichu(item: Variant) -> bool: return _matches(item, [RAICHU, "CS5aC_019"])
func _is_mew(item: Variant) -> bool: return _matches(item, [MEW])
func _is_latias(item: Variant) -> bool: return _matches(item, [LATIAS, LATIAS_ID])
func _is_lumineon(item: Variant) -> bool: return _matches(item, [LUMINEON, "CS5aC_043"])
func _is_squawk(item: Variant) -> bool: return _matches(item, [SQUAWK])
func _is_fezandipiti(item: Variant) -> bool: return _matches(item, [FEZANDIPITI])
func _is_iron_bundle(item: Variant) -> bool: return _matches(item, [IRON_BUNDLE])
func _is_magnemite(item: Variant) -> bool: return _matches(item, [MAGNEMITE])
func _is_magneton(item: Variant) -> bool: return _matches(item, [MAGNETON_ID])
func _is_pikachu(item: Variant) -> bool: return _matches(item, ["Pikachu ex", PIKACHU_ID])


func _is_known_pokemon(item: Variant) -> bool:
	return _is_miraidon(item) or _is_iron_hands(item) or _is_raikou(item) or _is_raichu(item) or _is_mew(item) or _is_latias(item) or _is_lumineon(item) or _is_squawk(item) or _is_fezandipiti(item) or _is_iron_bundle(item) or _is_magnemite(item) or _is_magneton(item) or _is_pikachu(item)


func _is_core_pokemon(item: Variant) -> bool:
	return _is_miraidon(item) or _is_iron_hands(item) or _is_raikou(item) or _is_raichu(item) or _is_pikachu(item)


func _is_support_pokemon(item: Variant) -> bool:
	return _is_mew(item) or _is_latias(item) or _is_lumineon(item) or _is_squawk(item) or _is_fezandipiti(item) or _is_iron_bundle(item)


func _is_attacker(item: Variant) -> bool:
	return _is_iron_hands(item) or _is_raikou(item) or _is_raichu(item) or _is_miraidon(item) or _is_pikachu(item)


func _is_main_attacker(item: Variant) -> bool:
	return _is_iron_hands(item) or _is_raikou(item) or _is_raichu(item)


func _is_generator_eligible(item: Variant) -> bool:
	var cd := _card_data(item)
	if cd == null:
		return false
	if str(cd.energy_type) == "L":
		return true
	return _is_miraidon(item) or _is_iron_hands(item) or _is_raikou(item) or _is_raichu(item) or _is_pikachu(item) or _is_magnemite(item) or _is_magneton(item)


func _is_lightning_energy(item: Variant) -> bool:
	var cd := _card_data(item)
	return cd != null and cd.is_energy() and str(cd.energy_provides) == "L"


func _is_double_turbo(item: Variant) -> bool:
	return _matches(item, [V17_DOUBLE_TURBO, "CSNC_024"])


func _has_v_mechanic(slot: PokemonSlot) -> bool:
	var cd := _card_data(slot)
	if cd == null:
		return false
	var mechanic := str(cd.mechanic)
	return mechanic == "V" or mechanic == "VSTAR"


func _is_rulebox(slot: PokemonSlot) -> bool:
	var cd := _card_data(slot)
	if cd == null:
		return false
	var mechanic := str(cd.mechanic)
	return mechanic == "ex" or mechanic == "V" or mechanic == "VSTAR"


func _count_on_field(player: PlayerState, keys: Array) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null and _matches(player.active_pokemon, keys):
		count += 1
	for slot: PokemonSlot in player.bench:
		if slot != null and _matches(slot, keys):
			count += 1
	return count


func _all_slots_v17(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _count_lightning_in_deck(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.deck:
		if _is_lightning_energy(card):
			count += 1
	return count


func _count_lightning_basics_in_deck(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.deck:
		var cd := _card_data(card)
		if cd != null and str(cd.card_type) == "Pokemon" and str(cd.stage) == "Basic" and _is_generator_eligible(card):
			count += 1
	return count


func _energy_units(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		total += 2 if _is_double_turbo(energy) else 1
	return total


func _attached_type_units(slot: PokemonSlot, energy_type: String) -> int:
	if slot == null:
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		var cd := _card_data(energy)
		if cd != null and str(cd.energy_provides) == energy_type:
			total += 1
	return total


func _total_lightning_energy(player: PlayerState) -> int:
	var total := 0
	for slot: PokemonSlot in _all_slots_v17(player):
		total += _attached_type_units(slot, "L")
	return total


func _attack_gap(slot: PokemonSlot, extra_lightning: int = 0, extra_colorless: int = 0) -> int:
	var cd := _card_data(slot)
	if cd == null or cd.attacks.is_empty():
		return 999
	var best := 999
	for attack: Dictionary in cd.attacks:
		best = mini(best, _attack_gap_for_cost(slot, str(attack.get("cost", "")), extra_lightning, extra_colorless))
	return best


func _attack_gap_for_cost(slot: PokemonSlot, cost: String, extra_lightning: int = 0, extra_colorless: int = 0) -> int:
	var total_units := _energy_units(slot) + extra_lightning + extra_colorless
	var required_total := cost.length()
	var required_by_type: Dictionary = {}
	for i: int in cost.length():
		var symbol := cost.substr(i, 1)
		if symbol == "" or symbol == "C":
			continue
		required_by_type[symbol] = int(required_by_type.get(symbol, 0)) + 1
	var missing_specific := 0
	for symbol: Variant in required_by_type.keys():
		var provided := _attached_type_units(slot, str(symbol))
		if str(symbol) == "L":
			provided += extra_lightning
		missing_specific += maxi(0, int(required_by_type[symbol]) - provided)
	return maxi(missing_specific, maxi(0, required_total - total_units))


func _can_attack_v17(slot: PokemonSlot) -> bool:
	return _attack_gap(slot) == 0


func _best_attack_damage_v17(slot: PokemonSlot, extra_lightning: int = 0) -> int:
	var cd := _card_data(slot)
	if cd == null:
		return 0
	var best := 0
	for attack: Dictionary in cd.attacks:
		if _attack_gap_for_cost(slot, str(attack.get("cost", "")), extra_lightning) == 0:
			best = maxi(best, _parse_damage_v17(str(attack.get("damage", "0"))))
	if _is_raichu(slot):
		best = maxi(best, (_attached_type_units(slot, "L") + extra_lightning) * 60)
	return best


func _current_attacker_damage_for_targeting_v17(game_state: GameState, player: PlayerState, player_index: int) -> int:
	if player == null or player.active_pokemon == null or not _can_attack_v17(player.active_pokemon):
		return 0
	return _visible_board_damage_v17(player.active_pokemon, game_state, player_index)


func _visible_board_damage_v17(slot: PokemonSlot, game_state: GameState, player_index: int, extra_lightning: int = 0) -> int:
	if slot == null or not _can_attack_with_extra_v17(slot, extra_lightning):
		return 0
	if _is_raikou(slot):
		return 20 + 20 * _total_bench_count_v17(game_state)
	return _best_attack_damage_v17(slot, extra_lightning)


func _can_attack_with_extra_v17(slot: PokemonSlot, extra_lightning: int) -> bool:
	return _attack_gap(slot, extra_lightning) == 0


func _total_bench_count_v17(game_state: GameState) -> int:
	if game_state == null:
		return 0
	var total := 0
	for player: PlayerState in game_state.players:
		total += player.bench.size()
	return total


func _iron_hands_amp_ready_v17(slot: PokemonSlot) -> bool:
	if slot == null or not _is_iron_hands(slot):
		return false
	return _attack_gap_for_cost(slot, "LCCC") == 0


func _parse_damage_v17(raw_damage: String) -> int:
	var digits := ""
	for i: int in raw_damage.length():
		var ch := raw_damage.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits != "" else 0


func _max_useful_energy(slot: PokemonSlot) -> int:
	if _is_raikou(slot): return 2
	if _is_iron_hands(slot): return 4
	if _is_miraidon(slot): return 3
	if _is_raichu(slot): return 8
	if _is_pikachu(slot) or _is_latias(slot): return 3
	var cd := _card_data(slot)
	if cd == null:
		return 1
	var max_cost := 0
	for attack: Dictionary in cd.attacks:
		max_cost = maxi(max_cost, str(attack.get("cost", "")).length())
	return maxi(max_cost, 1)


func _energy_full_after(slot: PokemonSlot, pending_lightning: int) -> bool:
	return _energy_units(slot) + pending_lightning >= _max_useful_energy(slot)


func _pending_assignments_for_slot(slot: PokemonSlot, context: Dictionary) -> int:
	var counts: Variant = context.get("pending_assignment_counts", {})
	if slot == null or not (counts is Dictionary):
		return 0
	var dict := counts as Dictionary
	var slot_id := int(slot.get_instance_id())
	if dict.has(slot_id):
		return int(dict[slot_id])
	if dict.has(str(slot_id)):
		return int(dict[str(slot_id)])
	return 0


func _has_better_attach_target(player: PlayerState, excluded: PokemonSlot) -> bool:
	for slot: PokemonSlot in _all_slots_v17(player):
		if slot != excluded and _is_main_attacker(slot) and not _energy_full_after(slot, 0):
			return true
	return false


func _has_non_miraidon_generator_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if slot != null and not _is_miraidon(slot) and _is_attacker(slot) and not _energy_full_after(slot, 0):
			return true
	return false


func _has_generator_attacker_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if slot != null and _is_attacker(slot) and not _energy_full_after(slot, 0):
			return true
	return false


func _has_useful_generator_target(player: PlayerState) -> bool:
	return _best_generator_target_score(player) >= 200.0


func _best_generator_target_score(player: PlayerState) -> float:
	var best := 0.0
	if player == null:
		return best
	for slot: PokemonSlot in player.bench:
		best = maxf(best, _generator_target_score(slot, {}))
	return best


func _best_generator_target_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -1.0
	if player == null:
		return null
	for slot: PokemonSlot in player.bench:
		var score := _generator_target_score(slot, {})
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_ready_attacker(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -1.0
	for slot: PokemonSlot in _all_slots_v17(player):
		if not _is_attacker(slot) or not _can_attack_v17(slot):
			continue
		var score := float(_best_attack_damage_v17(slot))
		if _is_iron_hands(slot): score += 120.0
		if _is_raikou(slot): score += 100.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _can_current_attacker_take_prize(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if player == null or player.active_pokemon == null or game_state == null or not _can_attack_v17(player.active_pokemon):
		return false
	var defender := _opponent_active(game_state, player_index)
	return defender != null and _current_attacker_damage_for_targeting_v17(game_state, player, player_index) >= defender.get_remaining_hp()


func _opponent_active(game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null:
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	return game_state.players[opponent_index].active_pokemon


func _revenge_bonus(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var defender := _opponent_active(game_state, player_index)
	if defender == null:
		return 0.0
	var gap := _attack_gap(slot)
	if gap > 2:
		return 0.0
	return 180.0 if _best_attack_damage_v17(slot, gap) >= defender.get_remaining_hp() else 0.0


func _retreat_target_is_better_prize_line(target: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	var defender := _opponent_active(game_state, player_index)
	return defender != null and _can_attack_v17(target) and _visible_board_damage_v17(target, game_state, player_index) >= defender.get_remaining_hp()


func _damage_for_attack_action(active: PokemonSlot, attack_index: int, attack_name: String, player: PlayerState) -> int:
	if _is_raichu(active) and (attack_index == 1 or attack_name == "Dynamic Spark"):
		return _total_lightning_energy(player) * 60
	var cd := _card_data(active)
	if cd == null or cd.attacks.is_empty():
		return 0
	var index := clampi(attack_index, 0, cd.attacks.size() - 1)
	return _parse_damage_v17(str((cd.attacks[index] as Dictionary).get("damage", "0")))


func _action_has_empty_bench_selection(action: Dictionary) -> bool:
	var targets: Variant = action.get("targets", [])
	if not (targets is Array):
		return false
	for target_variant: Variant in targets:
		if not (target_variant is Dictionary):
			continue
		var target: Dictionary = target_variant
		var bench_items: Variant = target.get("bench_pokemon", null)
		if bench_items is Array and (bench_items as Array).is_empty():
			return true
	return false
