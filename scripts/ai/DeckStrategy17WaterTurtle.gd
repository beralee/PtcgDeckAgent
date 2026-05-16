class_name DeckStrategy17WaterTurtle
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"

const TERAPAGOS_ID := "CSV9C_175"
const TERAPAGOS_NAME := "太乐巴戈斯ex"
const HOOTHOOT_ID := "CSV9C_154"
const HOOTHOOT_NAME := "咕咕"
const NOCTOWL_ID := "CSV9C_155"
const NOCTOWL_NAME := "猫头夜鹰"
const FAN_ROTOM_ID := "CSV9C_161"
const FAN_ROTOM_NAME := "旋转洛托姆"
const AREA_ZERO_ID := "CSV9C_207"
const AREA_ZERO_NAME := "零之大空洞"
const GLASS_TRUMPET_ID := "CSV9C_178"
const GLASS_TRUMPET_NAME := "玻璃喇叭"
const PALKIA_V := "Origin Forme Palkia V"
const PALKIA_VSTAR := "Origin Forme Palkia VSTAR"
const RADIANT_GRENINJA := "Radiant Greninja"
const BIDOOF := "Bidoof"
const BIBAREL := "Bibarel"
const FEZANDIPITI := "Fezandipiti ex"
const NEST_BALL := "Nest Ball"
const ULTRA_BALL := "Ultra Ball"
const BUDDY_POFFIN := "Buddy-Buddy Poffin"
const EARTHEN_VESSEL := "Earthen Vessel"
const HISUIAN_HEAVY_BALL := "Hisuian Heavy Ball"
const IRIDA := "Irida"
const BOSS_ORDERS := "Boss's Orders"
const PRIME_CATCHER := "Prime Catcher"
const KIERAN := "Kieran"
const LOST_VACUUM := "Lost Vacuum"
const NEST_BALL_ID := "CSVH1C_043"
const ULTRA_BALL_ID := "CSV1C_112"
const BUDDY_POFFIN_ID := "CSV7C_177"
const EARTHEN_VESSEL_ID := "CSV6C_115"
const HISUIAN_HEAVY_BALL_ID := "CS5.5C_060"
const IRIDA_ID := "CS5DC_138"
const BOSS_ORDERS_ID := "CSVH1aC_023"
const PRIME_CATCHER_ID := "CSV7C_180"
const KIERAN_ID := "CSV8C_198"
const LOST_VACUUM_ID := "CS6bC_123"


func _profile() -> Dictionary:
	return {
		"strategy_id": "v17_water_turtle",
		"signatures": [HOOTHOOT_ID, NOCTOWL_ID, FAN_ROTOM_ID, TERAPAGOS_ID, PALKIA_VSTAR],
		"active_priority": [FAN_ROTOM_ID, TERAPAGOS_ID, HOOTHOOT_ID, PALKIA_V, RADIANT_GRENINJA, BIDOOF],
		"bench_priority": [TERAPAGOS_ID, HOOTHOOT_ID, FAN_ROTOM_ID, PALKIA_V, BIDOOF, RADIANT_GRENINJA, FEZANDIPITI],
		"search_priority": [TERAPAGOS_ID, HOOTHOOT_ID, NOCTOWL_ID, FAN_ROTOM_ID, PALKIA_VSTAR, PALKIA_V, BIDOOF, BIBAREL, RADIANT_GRENINJA],
		"evolution_priority": [NOCTOWL_ID, PALKIA_VSTAR, BIBAREL],
		"energy_priority": [TERAPAGOS_ID, PALKIA_VSTAR, PALKIA_V, RADIANT_GRENINJA],
		"ability_priority": [NOCTOWL_ID, FAN_ROTOM_ID, RADIANT_GRENINJA, BIBAREL, FEZANDIPITI],
	}


func get_intent_planner_profile() -> Dictionary:
	return {
		"primary_attackers": [TERAPAGOS_NAME, PALKIA_VSTAR, PALKIA_V],
		"secondary_attackers": [RADIANT_GRENINJA],
		"scaling_attackers": [TERAPAGOS_NAME, PALKIA_VSTAR],
		"bench_priorities": [TERAPAGOS_NAME, HOOTHOOT_NAME, FAN_ROTOM_NAME, PALKIA_V, BIDOOF, RADIANT_GRENINJA, FEZANDIPITI],
		"search_priorities": [TERAPAGOS_NAME, HOOTHOOT_NAME, NOCTOWL_NAME, FAN_ROTOM_NAME, AREA_ZERO_NAME, GLASS_TRUMPET_NAME, PALKIA_VSTAR, PALKIA_V, BIDOOF, BIBAREL, RADIANT_GRENINJA],
		"evolution_priorities": [NOCTOWL_NAME, PALKIA_VSTAR, BIBAREL],
		"support_only": [HOOTHOOT_NAME, NOCTOWL_NAME, FAN_ROTOM_NAME, BIDOOF, BIBAREL, FEZANDIPITI],
		"evolution_lines": [
			{"basic": HOOTHOOT_NAME, "stages": [NOCTOWL_NAME], "role": "support"},
			{"basic": PALKIA_V, "stages": [PALKIA_VSTAR], "role": "secondary_attacker"},
			{"basic": BIDOOF, "stages": [BIBAREL], "role": "support"},
		],
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var has_core_candidate := _hand_has_opening_core(player)
	var basics: Array[Dictionary] = []
	for hand_index: int in player.hand.size():
		var card: CardInstance = player.hand[hand_index]
		if card == null or not card.is_basic_pokemon():
			continue
		basics.append({
			"index": hand_index,
			"active": _opening_active_score_water(card, has_core_candidate),
			"bench": _opening_bench_score_water(card),
		})
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


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var owner_name := TERAPAGOS_NAME
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		var ready := _best_ready_water_turtle_attacker(player)
		if ready != null:
			owner_name = _primary_name(ready)
		else:
			var setup_target := _best_setup_water_turtle_attacker(player)
			if setup_target != null:
				owner_name = _primary_name(setup_target)
	return {
		"id": "v17_water_turtle_rules",
		"intent": "build_area_zero_terapagos",
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": owner_name,
			"pivot_target_name": owner_name,
		},
		"priorities": {
			"attach": [TERAPAGOS_NAME, PALKIA_VSTAR, PALKIA_V, RADIANT_GRENINJA],
			"handoff": [TERAPAGOS_NAME, PALKIA_VSTAR, PALKIA_V, RADIANT_GRENINJA],
			"search": [TERAPAGOS_NAME, HOOTHOOT_NAME, NOCTOWL_NAME, FAN_ROTOM_NAME, AREA_ZERO_NAME, GLASS_TRUMPET_NAME, PALKIA_VSTAR, PALKIA_V, BIDOOF, BIBAREL],
		},
		"constraints": {
			"avoid_support_manual_attach": true,
			"fill_area_zero_bench": true,
		},
	}


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	if _matches_key(slot, TERAPAGOS_ID):
		var attached := slot.attached_energy.size() + extra_context
		var best_damage := 0
		var can_attack := false
		for attack: Dictionary in slot.get_card_data().attacks:
			var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
			if attached < cost.length():
				continue
			can_attack = true
			var raw_damage := str(attack.get("damage", "0"))
			if _is_terapagos_scaling_damage(raw_damage):
				var estimated_bench := 6 if extra_context <= 1 else clampi(extra_context, 1, 8)
				best_damage = maxi(best_damage, 30 * estimated_bench)
			else:
				best_damage = maxi(best_damage, _parse_damage(raw_damage))
		return {"damage": best_damage, "can_attack": can_attack, "description": "terapagos_bench_scaling"}
	if _matches_key(slot, PALKIA_VSTAR):
		var attached := slot.attached_energy.size() + extra_context
		var best_damage := 0
		var can_attack := false
		for attack: Dictionary in slot.get_card_data().attacks:
			var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
			if attached < cost.length():
				continue
			can_attack = true
			var raw_damage := str(attack.get("damage", "0"))
			best_damage = maxi(best_damage, 220 if raw_damage.begins_with("60+") else _parse_damage(raw_damage))
		return {"damage": best_damage, "can_attack": can_attack, "description": "palkia_bench_scaling"}
	return super.predict_attacker_damage(slot, extra_context)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	var kind := str(action.get("kind", ""))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if _action_targets_knocked_out_slot(action):
		return -100000.0
	if kind == "attack" or kind == "granted_attack":
		score = _score_water_turtle_attack(action, game_state, player_index, player, score)
	if kind == "play_trainer" or kind == "play_stadium":
		var card: CardInstance = action.get("card", null)
		if _matches_key(card, AREA_ZERO_ID) or _primary_name(card).to_lower().contains("area zero"):
			score += 360.0
		elif _matches_key(card, GLASS_TRUMPET_ID) or _primary_name(card).to_lower().contains("glass trumpet"):
			score += 330.0
		elif _primary_name(card).to_lower().contains("ultra ball") or _primary_name(card).to_lower().contains("nest ball"):
			score += 120.0
		elif _is_gust_card(card):
			var is_prime := _matches_any_key(card, [PRIME_CATCHER, PRIME_CATCHER_ID])
			var gust_bonus := _gust_action_bonus(game_state, player_index, is_prime)
			if gust_bonus > 0.0:
				score += gust_bonus
		elif _matches_any_key(card, [KIERAN, KIERAN_ID]):
			var kieran_bonus := _kieran_exact_ko_bonus(game_state, player_index)
			if kieran_bonus > 0.0:
				score += kieran_bonus
		score += _setup_trainer_bonus(card, player, game_state)
	if kind == "play_basic_to_bench":
		var basic_card: CardInstance = action.get("card", null)
		if _matches_key(basic_card, TERAPAGOS_ID):
			score += 620.0 if player != null and not _has_terapagos_on_field(player) else 220.0
		elif player != null:
			score += _bench_fill_bonus(basic_card, player)
		score += _terapagos_bench_pressure_bonus(player, game_state, player_index)
	if kind == "attach_energy":
		score += _manual_attach_adjustment(action, player)
	if kind == "use_ability":
		var source: PokemonSlot = action.get("source_slot", null)
		if _matches_key(source, NOCTOWL_ID) or _matches_key(source, FAN_ROTOM_ID):
			score += 260.0
	if kind == "retreat" and player != null:
		var target: PokemonSlot = action.get("bench_target", null)
		if target != null:
			score = maxf(score, _water_turtle_handoff_score(target) - 120.0)
			if player.active_pokemon != null and _is_core_attacker(player.active_pokemon) and _best_attack_gap(player.active_pokemon) == 0:
				score -= 260.0
	return score


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if not _slot_is_live(slot):
			return -100000.0
		if step_id == "opponent_bench_target":
			return _opponent_gust_target_score(slot, context)
		if step_id == "own_bench_target":
			return _water_turtle_handoff_score(slot)
		if step_id.contains("csv9c178") or step_id.contains("glass") or (step_id.contains("energy") and step_id.contains("assign")):
			if _matches_key(slot, TERAPAGOS_ID):
				return _glass_trumpet_assignment_score(slot, context)
			if _matches_key(slot, PALKIA_VSTAR) or _matches_key(slot, PALKIA_V):
				return 610.0
			if _matches_key(slot, FAN_ROTOM_ID):
				return 280.0
		if step_id.contains("switch") or step_id.contains("send") or step_id.contains("active") or step_id.contains("handoff"):
			return _water_turtle_handoff_score(slot)
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard"):
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id.contains("search_energy"):
			if _is_water_energy(card):
				return 260.0
		if step_id == "water_pokemon":
			return _irida_water_target_score(card, context)
		if step_id == "item_card":
			return _irida_item_target_score(card, context)
		if step_id.contains("fan_call"):
			return _fan_call_target_score(card, context)
		if step_id.contains("poffin") or step_id.contains("basic"):
			var basic_score := _basic_search_target_score(card, context)
			if basic_score > -99999.0:
				return basic_score
		if step_id.contains("noctowl") or step_id.contains("csv9c_noctowl"):
			return _trainer_search_score(card, context)
		if step_id.contains("trainer") or step_id.contains("search"):
			if _matches_key(card, AREA_ZERO_ID):
				return 980.0
			if _matches_key(card, GLASS_TRUMPET_ID):
				return _glass_trumpet_search_score(_context_player(context))
	if step_id == "kieran_mode":
		return _kieran_mode_score(str(item), context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		if not _slot_is_live(item as PokemonSlot):
			return -100000.0
		return _water_turtle_handoff_score(item as PokemonSlot)
	return score_interaction_target(item, step, context)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	if step_id.contains("fan_call"):
		return _pick_diverse_fan_call_targets(items, step, context)
	if step_id.contains("noctowl") or step_id.contains("csv9c_noctowl"):
		return _pick_diverse_noctowl_trainers(items, step, context)
	return super.pick_interaction_items(items, step, context)


func get_search_priority(card: CardInstance) -> int:
	if card == null:
		return 0
	if _matches_key(card, TERAPAGOS_ID):
		return 270
	if _matches_key(card, NOCTOWL_ID):
		return 258
	if _matches_key(card, HOOTHOOT_ID):
		return 250
	if _matches_key(card, AREA_ZERO_ID):
		return 245
	if _matches_key(card, GLASS_TRUMPET_ID):
		return 240
	return super.get_search_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var priority := super.get_discard_priority_contextual(card, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	var player: PlayerState = game_state.players[player_index]
	if _active_terapagos_needs_vessel_before_attach(player, game_state):
		if _matches_any_key(card, [EARTHEN_VESSEL, EARTHEN_VESSEL_ID]):
			return mini(priority, 5)
		if _matches_any_key(card, [GLASS_TRUMPET_ID, GLASS_TRUMPET_NAME]):
			return maxi(priority, 145)
	return priority


func _setup_trainer_bonus(card: CardInstance, player: PlayerState, game_state: GameState) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var turn := int(game_state.turn_number) if game_state != null else 0
	var opening := turn <= 3
	var bench_thin := player.bench.size() < 2
	var missing_terapagos := not _has_terapagos_on_field(player)
	if _matches_any_key(card, [EARTHEN_VESSEL, EARTHEN_VESSEL_ID]):
		if _active_terapagos_needs_vessel_before_attach(player, game_state):
			return 1040.0
		if opening and bench_thin and missing_terapagos:
			return -140.0
	if _matches_any_key(card, [LOST_VACUUM, LOST_VACUUM_ID]):
		if _lost_vacuum_breaks_own_area_zero_shell(player, game_state):
			return -620.0
	if _matches_any_key(card, [BUDDY_POFFIN, BUDDY_POFFIN_ID]):
		if not _can_poffin_find_setup_basics(player):
			return 0.0
		if bench_thin:
			return 680.0 if opening else 430.0
		return 420.0 if _has_terapagos_on_field(player) else 260.0
	if _matches_any_key(card, [NEST_BALL, NEST_BALL_ID]):
		if missing_terapagos and _deck_has_key(player, TERAPAGOS_ID):
			return 620.0
		if bench_thin and _deck_has_setup_basic(player):
			return 380.0
		return 180.0
	if _matches_any_key(card, [ULTRA_BALL, ULTRA_BALL_ID]):
		if missing_terapagos:
			return 500.0
		if _has_on_field_key(player, HOOTHOOT_ID) and not _has_on_field_key(player, NOCTOWL_ID):
			return 340.0
		return 180.0
	if _matches_any_key(card, [HISUIAN_HEAVY_BALL, HISUIAN_HEAVY_BALL_ID]):
		return 320.0 if missing_terapagos or bench_thin else 120.0
	if _matches_any_key(card, [IRIDA, IRIDA_ID]):
		if _deck_has_key(player, PALKIA_VSTAR) and _has_on_field_key(player, PALKIA_V) and not _has_on_field_key(player, PALKIA_VSTAR):
			return 760.0
		if not _has_on_field_key(player, PALKIA_V) and _deck_has_key(player, PALKIA_V):
			return 660.0
		if not _area_zero_in_play(game_state) or missing_terapagos:
			return 560.0
		return 330.0
	return 0.0


func _gust_action_bonus(game_state: GameState, player_index: int, is_prime_catcher: bool = false) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0.0
	var damage := _active_pressure_damage(game_state, player_index)
	if damage <= 0:
		return 0.0
	var active_remaining := _opponent_active_remaining_hp(game_state, player_index)
	var best_target := 0.0
	for slot: PokemonSlot in game_state.players[opponent_index].bench:
		if not _slot_is_live(slot):
			continue
		if damage >= slot.get_remaining_hp():
			best_target = maxf(best_target, 720.0 + float(_slot_prize_value(slot)) * 180.0)
		elif damage < active_remaining:
			var gap := slot.get_remaining_hp() - damage
			best_target = maxf(best_target, 180.0 - float(maxi(0, gap)) * 0.4)
	if best_target <= 0.0:
		return 0.0
	if damage >= active_remaining:
		best_target *= 0.45
	if is_prime_catcher:
		best_target += 90.0
	return best_target


func _kieran_exact_ko_bonus(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var damage := _active_pressure_damage(game_state, player_index)
	if damage <= 0:
		return 0.0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0.0
	var defender := game_state.players[opponent_index].active_pokemon
	if not _slot_is_live(defender) or not _is_rule_box_slot(defender):
		return 0.0
	var remaining := defender.get_remaining_hp()
	if damage < remaining and damage + 30 >= remaining:
		return 1180.0
	return 0.0


func _kieran_mode_score(mode: String, context: Dictionary) -> float:
	var bonus := _kieran_exact_ko_bonus(context.get("game_state", null), int(context.get("player_index", -1)))
	if mode == "boost_vs_active_rule_box":
		return 1280.0 if bonus > 0.0 else 80.0
	if mode == "switch_active":
		return 180.0
	return 0.0


func _manual_attach_adjustment(action: Dictionary, player: PlayerState) -> float:
	var target: PokemonSlot = action.get("target_slot", null)
	var energy: CardInstance = action.get("card", null)
	if target == null or energy == null:
		return 0.0
	if not _slot_is_live(target):
		return -100000.0
	if not _is_water_energy(energy):
		return 0.0
	if _matches_key(target, TERAPAGOS_ID):
		var after_units := _energy_units(target) + 1
		if after_units <= 2:
			return 780.0
		if after_units == 3:
			return 540.0
		return -220.0
	if _matches_key(target, PALKIA_VSTAR) or _matches_key(target, PALKIA_V):
		var gap_after := _best_attack_gap(target, 1)
		if gap_after == 0:
			return 430.0
		if gap_after == 1:
			return 260.0
		return 120.0
	if _matches_key(target, RADIANT_GRENINJA):
		return 130.0 if player != null and not _has_better_water_attach_target(player, target) else -120.0
	if _is_support_slot(target):
		return -920.0 if player != null and _has_better_water_attach_target(player, target) else -780.0
	return 0.0


func _bench_fill_bonus(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or not card.is_basic_pokemon():
		return 0.0
	if player != null and player.bench.size() >= 8:
		return -120.0
	if _matches_key(card, HOOTHOOT_ID):
		return 360.0 if not _has_on_field_key(player, HOOTHOOT_ID) else 120.0
	if _matches_key(card, FAN_ROTOM_ID):
		return 340.0 if not _has_on_field_key(player, FAN_ROTOM_ID) else 100.0
	if _matches_key(card, PALKIA_V):
		return 300.0 if not _has_on_field_key(player, PALKIA_V) else 110.0
	if _matches_key(card, BIDOOF):
		return 220.0 if not _has_on_field_key(player, BIDOOF) else 70.0
	if _matches_key(card, RADIANT_GRENINJA):
		return 180.0
	if _matches_key(card, FEZANDIPITI):
		return 90.0
	return 0.0


func _terapagos_bench_pressure_bonus(player: PlayerState, game_state: GameState, player_index: int) -> float:
	if player == null or game_state == null or player.bench.size() >= 8:
		return 0.0
	var active := player.active_pokemon
	if not _slot_is_live(active) or not _matches_key(active, TERAPAGOS_ID):
		return 0.0
	if _best_attack_gap(active) > 0:
		return 0.0
	var current_damage := _predict_attack_with_board(active, game_state)
	var remaining_hp := _opponent_active_remaining_hp(game_state, player_index)
	if current_damage <= 0 or current_damage >= remaining_hp:
		return 0.0
	var after_damage := current_damage + 30
	if after_damage >= remaining_hp:
		return 820.0
	if current_damage < 210 and after_damage >= 210:
		return 520.0
	if current_damage < 180 and after_damage >= 180:
		return 460.0
	if current_damage < 240 and after_damage >= 240:
		return 420.0
	return 260.0


func _water_turtle_handoff_score(slot: PokemonSlot) -> float:
	if not _slot_is_live(slot):
		return -100000.0
	var gap := _best_attack_gap(slot)
	var pred := predict_attacker_damage(slot)
	var damage := float(int(pred.get("damage", 0)))
	if _matches_key(slot, TERAPAGOS_ID):
		if gap == 0:
			return 980.0 + damage * 0.45
		if gap == 1:
			return 620.0
		return 360.0
	if _matches_key(slot, PALKIA_VSTAR):
		if gap == 0:
			return 780.0 + damage * 0.35
		if gap == 1:
			return 450.0
		return 260.0
	if _matches_key(slot, PALKIA_V):
		if _palkia_v_hydro_break_ready(slot):
			return 700.0 + damage * 0.25
		if gap == 0:
			return 260.0 + damage * 0.15
		if gap == 1:
			return 190.0
		return 100.0
	if _matches_key(slot, RADIANT_GRENINJA):
		return 520.0 + damage * 0.25 if gap == 0 else 120.0
	if _is_support_slot(slot):
		return 45.0
	return super.score_handoff_target(slot, {"id": "handoff"})


func _score_water_turtle_attack(action: Dictionary, game_state: GameState, player_index: int, player: PlayerState, base_score: float) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	if not _slot_is_live(source):
		return -100000.0
	if _matches_key(source, TERAPAGOS_ID):
		var damage := _predict_attack_with_board(source, game_state)
		var score := 720.0 + float(damage) * 2.0
		if damage >= _opponent_active_remaining_hp(game_state, player_index):
			score += 780.0
		elif damage < 150 and player != null and player.bench.size() < 5:
			score = minf(score, 520.0 + float(damage))
		elif damage < 180 and player != null and player.bench.size() < 6:
			score = minf(score, 650.0 + float(damage))
		return score
	if _matches_key(source, PALKIA_VSTAR):
		var damage := _predict_attack_with_board(source, game_state)
		var score := 640.0 + float(damage) * 2.0
		if damage >= _opponent_active_remaining_hp(game_state, player_index):
			score += 760.0
		return score
	if _matches_key(source, PALKIA_V):
		var damage := _action_or_predicted_damage(action, source, game_state)
		if damage >= _opponent_active_remaining_hp(game_state, player_index) and damage > 0:
			return maxf(base_score, 760.0 + float(damage) * 1.6)
		if damage >= 180:
			return maxf(base_score, 560.0 + float(damage))
		return minf(base_score, 520.0 if not _area_zero_in_play(game_state) else 280.0)
	if _is_support_slot(source):
		var damage := _action_or_predicted_damage(action, source, game_state)
		if damage >= _opponent_active_remaining_hp(game_state, player_index) and damage > 0:
			return maxf(base_score, 520.0 + float(damage) * 1.4)
		return minf(base_score, 180.0 + float(damage) * 0.8)
	return base_score


func _predict_attack_with_board(slot: PokemonSlot, game_state: GameState) -> int:
	if slot == null:
		return 0
	if _matches_key(slot, TERAPAGOS_ID):
		var owner_index := _find_owner_index(game_state, slot)
		if owner_index >= 0:
			return game_state.players[owner_index].bench.size() * 30
		var prediction := predict_attacker_damage(slot)
		return int(prediction.get("damage", 0))
	if _matches_key(slot, PALKIA_VSTAR):
		return 60 + _count_total_bench(game_state) * 20
	var prediction := predict_attacker_damage(slot)
	return int(prediction.get("damage", 0))


func _best_ready_water_turtle_attacker(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -1.0
	for slot: PokemonSlot in _all_slots(player):
		if not _slot_is_live(slot) or not _is_pressure_attacker(slot) or _best_attack_gap(slot) > 0:
			continue
		var score := _water_turtle_handoff_score(slot)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_setup_water_turtle_attacker(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and _matches_key(slot, TERAPAGOS_ID):
			return slot
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and (_matches_key(slot, PALKIA_VSTAR) or _matches_key(slot, PALKIA_V)):
			return slot
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and _matches_key(slot, RADIANT_GRENINJA):
			return slot
	return null


func _has_better_water_attach_target(player: PlayerState, excluded: PokemonSlot) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if slot == excluded or slot == null:
			continue
		if not _slot_is_live(slot):
			continue
		if _matches_key(slot, TERAPAGOS_ID) and _energy_units(slot) < 3:
			return true
		if (_matches_key(slot, PALKIA_VSTAR) or _matches_key(slot, PALKIA_V)) and _best_attack_gap(slot) > 0:
			return true
	return false


func _has_terapagos_on_field(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and _matches_key(slot, TERAPAGOS_ID):
			return true
	return false


func _is_core_attacker(slot: PokemonSlot) -> bool:
	return _matches_key(slot, TERAPAGOS_ID) or _matches_key(slot, PALKIA_VSTAR) or _matches_key(slot, PALKIA_V) or _matches_key(slot, RADIANT_GRENINJA)


func _is_pressure_attacker(slot: PokemonSlot) -> bool:
	if _matches_key(slot, TERAPAGOS_ID) or _matches_key(slot, PALKIA_VSTAR) or _matches_key(slot, RADIANT_GRENINJA):
		return true
	if _matches_key(slot, PALKIA_V):
		return _palkia_v_hydro_break_ready(slot)
	return false


func _is_support_slot(slot: PokemonSlot) -> bool:
	return _matches_key(slot, HOOTHOOT_ID) or _matches_key(slot, NOCTOWL_ID) or _matches_key(slot, FAN_ROTOM_ID) or _matches_key(slot, BIDOOF) or _matches_key(slot, BIBAREL) or _matches_key(slot, FEZANDIPITI)


func _slot_prize_value(slot: PokemonSlot) -> int:
	var cd := slot.get_card_data() if slot != null else null
	if cd == null:
		return 1
	if str(cd.mechanic) in ["VMAX"]:
		return 3
	if str(cd.mechanic) == "ex" or str(cd.mechanic) in ["V", "VSTAR"]:
		return 2
	return 1


func _is_rule_box_slot(slot: PokemonSlot) -> bool:
	var cd := slot.get_card_data() if slot != null else null
	if cd == null:
		return false
	return str(cd.mechanic) == "ex" or str(cd.mechanic) in ["V", "VSTAR", "VMAX"]


func _is_gust_card(card: CardInstance) -> bool:
	if card == null:
		return false
	if _matches_any_key(card, [BOSS_ORDERS, BOSS_ORDERS_ID, PRIME_CATCHER, PRIME_CATCHER_ID]):
		return true
	var lowered := _primary_name(card).to_lower()
	return lowered.contains("boss") or lowered.contains("prime catcher")


func _is_water_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return false
	return str(card.card_data.energy_provides) == "W" or _primary_name(card).to_lower().contains("water energy")


func _best_attack_gap(slot: PokemonSlot, extra_water: int = 0) -> int:
	var cd := slot.get_card_data() if slot != null else null
	if cd == null or cd.attacks.is_empty():
		return 999
	var best := 999
	for raw_attack: Variant in cd.attacks:
		if not (raw_attack is Dictionary):
			continue
		var attack := raw_attack as Dictionary
		best = mini(best, _attack_gap_for_cost(slot, str(attack.get("cost", "")), extra_water))
	return best


func _palkia_v_hydro_break_ready(slot: PokemonSlot) -> bool:
	if slot == null or not _matches_key(slot, PALKIA_V):
		return false
	return _attack_gap_for_cost(slot, "WWC") <= 0


func _action_or_predicted_damage(action: Dictionary, slot: PokemonSlot, game_state: GameState) -> int:
	var projected := int(action.get("projected_damage", 0))
	if projected > 0:
		return projected
	return _predict_attack_with_board(slot, game_state)


func _active_pressure_damage(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var active := game_state.players[player_index].active_pokemon
	if not _slot_is_live(active) or _best_attack_gap(active) > 0:
		return 0
	if not (_matches_key(active, TERAPAGOS_ID) or _matches_key(active, PALKIA_VSTAR) or _palkia_v_hydro_break_ready(active)):
		return 0
	return _predict_attack_with_board(active, game_state)


func _attack_gap_for_cost(slot: PokemonSlot, raw_cost: String, extra_water: int = 0) -> int:
	var cost := CardData.normalize_attack_cost(raw_cost)
	var required_total := cost.length()
	var required_by_type := {}
	for i: int in cost.length():
		var symbol := cost.substr(i, 1)
		if symbol == "" or symbol == "C":
			continue
		required_by_type[symbol] = int(required_by_type.get(symbol, 0)) + 1
	var total_units := _energy_units(slot) + extra_water
	var missing_specific := 0
	for raw_symbol: Variant in required_by_type.keys():
		var symbol := str(raw_symbol)
		var attached := _attached_type_units(slot, symbol)
		if symbol == "W":
			attached += extra_water
		missing_specific += maxi(0, int(required_by_type.get(symbol, 0)) - attached)
	return maxi(missing_specific, maxi(0, required_total - total_units))


func _energy_units(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func _attached_type_units(slot: PokemonSlot, energy_type: String) -> int:
	if slot == null:
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == energy_type:
			total += 1
	return total


func _opening_active_score_water(card: CardInstance, has_core_candidate: bool) -> float:
	if _matches_key(card, TERAPAGOS_ID):
		return 1240.0
	if _matches_key(card, PALKIA_V):
		return 1080.0
	if _matches_key(card, FAN_ROTOM_ID):
		return 760.0 if has_core_candidate else 940.0
	if _matches_key(card, HOOTHOOT_ID):
		return 720.0 if has_core_candidate else 880.0
	if _matches_key(card, BIDOOF):
		return 680.0 if has_core_candidate else 820.0
	if _matches_key(card, RADIANT_GRENINJA):
		return 660.0 if has_core_candidate else 780.0
	if _matches_key(card, FEZANDIPITI):
		return 520.0
	return 80.0


func _opening_bench_score_water(card: CardInstance) -> float:
	if _matches_key(card, TERAPAGOS_ID):
		return 1220.0
	if _matches_key(card, PALKIA_V):
		return 850.0
	if _matches_key(card, HOOTHOOT_ID):
		return 790.0
	if _matches_key(card, FAN_ROTOM_ID):
		return 770.0
	if _matches_key(card, BIDOOF):
		return 560.0
	if _matches_key(card, RADIANT_GRENINJA):
		return 540.0
	if _matches_key(card, FEZANDIPITI):
		return 360.0
	return 80.0


func _hand_has_opening_core(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _matches_key(card, TERAPAGOS_ID) or _matches_key(card, PALKIA_V):
			return true
	return false


func _basic_search_target_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null or not card.is_basic_pokemon():
		return -100000.0
	var player := _context_player(context)
	if _matches_key(card, TERAPAGOS_ID):
		return 1280.0 if player == null or not _has_terapagos_on_field(player) else 620.0
	if _matches_key(card, HOOTHOOT_ID):
		return 940.0 if player == null or not _has_on_field_key(player, HOOTHOOT_ID) else 420.0
	if _matches_key(card, FAN_ROTOM_ID):
		return 920.0 if player == null or not _has_on_field_key(player, FAN_ROTOM_ID) else 380.0
	if _matches_key(card, PALKIA_V):
		return 760.0 if player == null or not _has_on_field_key(player, PALKIA_V) else 330.0
	if _matches_key(card, BIDOOF):
		return 640.0 if player == null or not _has_on_field_key(player, BIDOOF) else 260.0
	if _matches_key(card, RADIANT_GRENINJA):
		return 560.0
	if _matches_key(card, FEZANDIPITI):
		return 330.0
	return 120.0


func _fan_call_target_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null or not card.card_data.is_pokemon():
		return -100000.0
	var player := _context_player(context)
	var hoothoot_count := _field_key_count(player, HOOTHOOT_ID)
	if _matches_key(card, NOCTOWL_ID):
		return 1180.0 if player != null and hoothoot_count > 0 and not _has_on_field_key(player, NOCTOWL_ID) else 960.0
	if _matches_key(card, HOOTHOOT_ID):
		return 1240.0 if player == null or hoothoot_count < 2 else 80.0
	if _matches_key(card, BIBAREL):
		return 1130.0 if player != null and _has_on_field_key(player, BIDOOF) and not _has_on_field_key(player, BIBAREL) else -100000.0
	if str(card.card_data.energy_type) != "C" or int(card.card_data.hp) > 100:
		return -100000.0
	if _matches_key(card, FAN_ROTOM_ID):
		return 780.0 if player == null or not _has_on_field_key(player, FAN_ROTOM_ID) else 260.0
	if _matches_key(card, BIDOOF):
		return 640.0 if player == null or not _has_on_field_key(player, BIDOOF) else 260.0
	return 160.0


func _irida_water_target_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null or not card.card_data.is_pokemon() or str(card.card_data.energy_type) != "W":
		return -100000.0
	var player := _context_player(context)
	if _matches_key(card, PALKIA_VSTAR):
		if player != null and _has_on_field_key(player, PALKIA_V) and not _has_on_field_key(player, PALKIA_VSTAR):
			return 1180.0
		return 760.0
	if _matches_key(card, PALKIA_V):
		return 1020.0 if player == null or not _has_on_field_key(player, PALKIA_V) else 260.0
	if _matches_key(card, RADIANT_GRENINJA):
		return 520.0 if player == null or not _has_on_field_key(player, RADIANT_GRENINJA) else 180.0
	return 140.0


func _irida_item_target_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null or str(card.card_data.card_type) != "Item":
		return -100000.0
	var player := _context_player(context)
	var missing_terapagos := player == null or not _has_terapagos_on_field(player)
	var bench_thin := player == null or player.bench.size() < 5
	if _matches_any_key(card, [NEST_BALL, NEST_BALL_ID]):
		if missing_terapagos:
			return 1120.0
		return 900.0 if bench_thin else 320.0
	if _matches_any_key(card, [ULTRA_BALL, ULTRA_BALL_ID]):
		if missing_terapagos:
			return 1040.0
		if player != null and _has_on_field_key(player, HOOTHOOT_ID) and not _has_on_field_key(player, NOCTOWL_ID):
			return 880.0
		return 360.0
	if _matches_any_key(card, [BUDDY_POFFIN, BUDDY_POFFIN_ID]):
		return 980.0 if bench_thin and (player == null or _can_poffin_find_setup_basics(player)) else 260.0
	if _matches_key(card, GLASS_TRUMPET_ID):
		return _glass_trumpet_search_score(player)
	if _matches_any_key(card, [EARTHEN_VESSEL, EARTHEN_VESSEL_ID]):
		return 760.0 if player != null and _basic_energy_in_discard_count(player) <= 0 else 420.0
	if _matches_any_key(card, [HISUIAN_HEAVY_BALL, HISUIAN_HEAVY_BALL_ID]):
		return 620.0 if missing_terapagos else 220.0
	return float(get_search_priority(card))


func _opponent_gust_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if not _slot_is_live(slot):
		return -100000.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var damage := _active_pressure_damage(game_state, player_index)
	var remaining := slot.get_remaining_hp()
	var prize_value := _slot_prize_value(slot)
	if damage > 0 and damage >= remaining:
		return 960.0 + float(prize_value) * 180.0 + float(maxi(0, 260 - remaining)) * 0.25
	if damage > 0:
		return 280.0 + float(prize_value) * 80.0 - float(maxi(0, remaining - damage)) * 0.6
	return 80.0 + float(prize_value) * 50.0


func _trainer_search_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var player := _context_player(context)
	if _matches_key(card, AREA_ZERO_ID):
		return 1120.0 if not _area_zero_is_active(context) else 420.0
	if _matches_key(card, GLASS_TRUMPET_ID):
		return _glass_trumpet_search_score(player)
	if _matches_any_key(card, [BUDDY_POFFIN, BUDDY_POFFIN_ID]):
		return 1020.0 if player == null or player.bench.size() < 5 else 240.0
	if _matches_any_key(card, [NEST_BALL, NEST_BALL_ID]):
		return 990.0 if player == null or not _has_terapagos_on_field(player) or player.bench.size() < 5 else 260.0
	if _matches_any_key(card, [ULTRA_BALL, ULTRA_BALL_ID]):
		return 960.0
	if _matches_any_key(card, [EARTHEN_VESSEL, EARTHEN_VESSEL_ID]):
		return 1110.0 if _terapagos_t2_energy_access_needed(player) else 780.0
	return float(get_search_priority(card))


func _pick_diverse_noctowl_trainers(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		max_select = 1
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		ranked.append({
			"item": item,
			"score": score_interaction_target(item, step, context),
			"role": _trainer_role_key(item),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var selected: Array = []
	var roles := {}
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		var role := str(entry.get("role", ""))
		if role != "" and roles.has(role) and _has_unselected_distinct_role(ranked, roles):
			continue
		selected.append(entry.get("item"))
		if role != "":
			roles[role] = true
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		var item: Variant = entry.get("item")
		if selected.has(item):
			continue
		selected.append(item)
	return selected


func _pick_diverse_fan_call_targets(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		max_select = 1
	var player := _context_player(context)
	var selected: Array = []
	_append_first_matching_fan_call_target(selected, items, HOOTHOOT_ID, player == null or _field_key_count(player, HOOTHOOT_ID) < 2, max_select)
	_append_first_matching_fan_call_target(selected, items, NOCTOWL_ID, true, max_select)
	_append_first_matching_fan_call_target(selected, items, BIBAREL, player != null and _has_on_field_key(player, BIDOOF), max_select)
	if selected.size() >= max_select:
		return selected
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		ranked.append({
			"item": item,
			"score": score_interaction_target(item, step, context),
			"role": _fan_call_role_key(item),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var roles := {}
	for item: Variant in selected:
		var role := _fan_call_role_key(item)
		if role != "":
			roles[role] = true
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		if float(entry.get("score", 0.0)) <= -99999.0:
			continue
		var item: Variant = entry.get("item")
		if selected.has(item):
			continue
		var role := str(entry.get("role", ""))
		if role != "" and roles.has(role) and _has_unselected_distinct_role(ranked, roles):
			continue
		selected.append(item)
		if role != "":
			roles[role] = true
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		if float(entry.get("score", 0.0)) <= -99999.0:
			continue
		var item: Variant = entry.get("item")
		if selected.has(item):
			continue
		selected.append(item)
	return selected


func _append_first_matching_fan_call_target(selected: Array, items: Array, key: String, enabled: bool, max_select: int) -> void:
	if not enabled or selected.size() >= max_select:
		return
	for item: Variant in items:
		if selected.has(item):
			continue
		if item is CardInstance and _matches_key(item as CardInstance, key):
			selected.append(item)
			return


func _has_unselected_distinct_role(ranked: Array[Dictionary], selected_roles: Dictionary) -> bool:
	for entry: Dictionary in ranked:
		var role := str(entry.get("role", ""))
		if role != "" and not selected_roles.has(role):
			return true
	return false


func _trainer_role_key(item: Variant) -> String:
	if not (item is CardInstance):
		return ""
	var card := item as CardInstance
	if _matches_key(card, AREA_ZERO_ID):
		return "area_zero"
	if _matches_key(card, GLASS_TRUMPET_ID):
		return "glass_trumpet"
	if _matches_any_key(card, [BUDDY_POFFIN, BUDDY_POFFIN_ID, NEST_BALL, NEST_BALL_ID, ULTRA_BALL, ULTRA_BALL_ID]):
		return "setup_search"
	if _matches_any_key(card, [EARTHEN_VESSEL, EARTHEN_VESSEL_ID]):
		return "energy_access"
	return _primary_name(card).to_lower()


func _fan_call_role_key(item: Variant) -> String:
	if not (item is CardInstance):
		return ""
	var card := item as CardInstance
	if _matches_key(card, HOOTHOOT_ID) or _matches_key(card, NOCTOWL_ID):
		return "noctowl_line"
	if _matches_key(card, BIDOOF) or _matches_key(card, BIBAREL):
		return "bibarel_line"
	if _matches_key(card, FAN_ROTOM_ID):
		return "fan_rotom"
	return _primary_name(card).to_lower()


func _glass_trumpet_search_score(player: PlayerState) -> float:
	if player == null:
		return 620.0
	var has_tera := _has_terapagos_on_field(player)
	var discard_energy_count := _basic_energy_in_discard_count(player)
	var target_count := _glass_trumpet_target_count(player)
	if discard_energy_count <= 0:
		return 520.0 if has_tera else 360.0
	if target_count <= 0:
		return 500.0 if has_tera else 320.0
	if has_tera:
		return 1080.0 if target_count >= 2 else 960.0
	return 720.0


func _glass_trumpet_assignment_score(slot: PokemonSlot, context: Dictionary) -> float:
	var attached := _energy_units(slot)
	if attached <= 0:
		return 1080.0
	if attached == 1:
		return 1160.0
	var player := _context_player(context)
	if _has_underbuilt_backup_terapagos(player, slot):
		return 640.0
	if attached == 2:
		return 820.0
	return 420.0


func _has_underbuilt_backup_terapagos(player: PlayerState, excluded: PokemonSlot) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if slot == excluded or not _slot_is_live(slot):
			continue
		if _matches_key(slot, TERAPAGOS_ID) and _energy_units(slot) < 2:
			return true
	return false


func _is_terapagos_scaling_damage(raw_damage: String) -> bool:
	var lowered := raw_damage.to_lower()
	return lowered.contains("30x") or (raw_damage.begins_with("30") and raw_damage.length() > 2 and _parse_damage(raw_damage) == 30)


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


func _basic_energy_in_discard_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy():
			total += 1
	return total


func _glass_trumpet_target_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for slot: PokemonSlot in player.bench:
		if _is_glass_trumpet_target(slot):
			total += 1
	return total


func _is_glass_trumpet_target(slot: PokemonSlot) -> bool:
	if not _slot_is_live(slot):
		return false
	var cd := slot.get_card_data()
	return cd != null and str(cd.energy_type) == "C"


func _context_player(context: Dictionary) -> PlayerState:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _area_zero_is_active(context: Dictionary) -> bool:
	var game_state: GameState = context.get("game_state", null)
	return game_state != null and game_state.stadium_card != null and _matches_key(game_state.stadium_card, AREA_ZERO_ID)


func _area_zero_in_play(game_state: GameState) -> bool:
	return game_state != null and game_state.stadium_card != null and _matches_key(game_state.stadium_card, AREA_ZERO_ID)


func _can_poffin_find_setup_basics(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _is_poffin_setup_basic(card):
			return true
	return false


func _deck_has_setup_basic(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if card != null and card.is_basic_pokemon() and (_is_core_basic(card) or _is_poffin_setup_basic(card)):
			return true
	return false


func _deck_has_key(player: PlayerState, key: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _matches_key(card, key):
			return true
	return false


func _has_on_field_key(player: PlayerState, key: String) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and _matches_key(slot, key):
			return true
	return false


func _field_key_count(player: PlayerState, key: String) -> int:
	var total := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and _matches_key(slot, key):
			total += 1
	return total


func _terapagos_t2_energy_access_needed(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is_live(slot) and _matches_key(slot, TERAPAGOS_ID) and _energy_units(slot) < 2:
			return true
	return false


func _active_terapagos_needs_vessel_before_attach(player: PlayerState, game_state: GameState) -> bool:
	if player == null or game_state == null:
		return false
	if game_state.energy_attached_this_turn:
		return false
	var active := player.active_pokemon
	if not _slot_is_live(active) or not _matches_key(active, TERAPAGOS_ID):
		return false
	if _energy_units(active) != 1:
		return false
	if _hand_has_water_energy(player):
		return false
	return _deck_has_water_energy(player)


func _lost_vacuum_breaks_own_area_zero_shell(player: PlayerState, game_state: GameState) -> bool:
	if player == null or not _area_zero_in_play(game_state):
		return false
	if player.bench.size() <= 5:
		return false
	if _slot_is_live(player.active_pokemon) and _matches_key(player.active_pokemon, TERAPAGOS_ID):
		return true
	return _has_on_field_key(player, TERAPAGOS_ID)


func _hand_has_water_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _is_water_energy(card):
			return true
	return false


func _deck_has_water_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _is_water_energy(card):
			return true
	return false


func _action_targets_knocked_out_slot(action: Dictionary) -> bool:
	for key: String in ["target_slot", "bench_target", "source_slot"]:
		var value: Variant = action.get(key, null)
		if value is PokemonSlot and not _slot_is_live(value as PokemonSlot):
			return true
	return false


func _slot_is_live(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_top_card() != null and slot.get_remaining_hp() > 0


func _is_core_basic(card: CardInstance) -> bool:
	return _matches_key(card, TERAPAGOS_ID) or _matches_key(card, PALKIA_V)


func _is_poffin_setup_basic(card: CardInstance) -> bool:
	if card == null or card.card_data == null or not card.is_basic_pokemon():
		return false
	if int(card.card_data.hp) > 70:
		return false
	return _matches_key(card, HOOTHOOT_ID) or _matches_key(card, FAN_ROTOM_ID) or _matches_key(card, BIDOOF)


func _matches_any_key(item: Variant, keys: Array) -> bool:
	for key: Variant in keys:
		if _matches_key(item, str(key)):
			return true
	return false
