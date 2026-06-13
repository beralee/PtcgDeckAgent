class_name DeckStrategy175LugiaArcheops
extends "res://scripts/ai/DeckStrategyLugiaArcheops.gd"

const NEST_BALL := "Nest Ball"
const MESAGOZA := "Mesagoza"
const WYRDEER_V := "Wyrdeer V"
const REGIGIGAS := "Regigigas"
const REGIGIGAS_ATTACK := "Jewel Break"


func get_strategy_id() -> String:
	return "v175_lugia_archeops"


func get_signature_names() -> Array[String]:
	var names := super.get_signature_names()
	for name: String in [NEST_BALL, MESAGOZA, WYRDEER_V, REGIGIGAS]:
		if not names.has(name):
			names.append(name)
	return names


func get_mcts_config() -> Dictionary:
	var config := super.get_mcts_config()
	config["time_budget_ms"] = maxi(int(config.get("time_budget_ms", 0)), 2200)
	return config


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var plan := super.build_turn_plan(game_state, player_index, context)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return plan
	var player: PlayerState = game_state.players[player_index]
	var chargeable_handoff := _v175_best_chargeable_handoff(player)
	if chargeable_handoff == null:
		return plan
	var handoff_name := _slot_name(chargeable_handoff)
	if handoff_name == "":
		return plan
	var owner: Dictionary = plan.get("owner", {}) if plan.get("owner", {}) is Dictionary else {}
	owner["pivot_target_name"] = handoff_name
	plan["owner"] = owner
	var priorities: Dictionary = plan.get("priorities", {}) if plan.get("priorities", {}) is Dictionary else {}
	var handoff: Array = priorities.get("handoff", []) if priorities.get("handoff", []) is Array else []
	handoff.erase(handoff_name)
	handoff.push_front(handoff_name)
	priorities["handoff"] = handoff
	plan["priorities"] = priorities
	return plan


func _setup_priority(name: String, player: PlayerState) -> float:
	if name == WYRDEER_V:
		return 125.0
	if _v175_name_is_regigigas(name):
		return 105.0
	return super._setup_priority(name, player)


func _should_bench_opening_basic(name: String, active_name: String, bench_names: Array[String]) -> bool:
	if name == WYRDEER_V or _v175_name_is_regigigas(name):
		var owner_present := active_name == LUGIA_V or bench_names.has(LUGIA_V)
		var minccino_present := active_name == MINCCINO or bench_names.has(MINCCINO)
		return owner_present and minccino_present and bench_names.size() <= 2
	return super._should_bench_opening_basic(name, active_name, bench_names)


func _score_play_basic(card: CardInstance, game_state: GameState, player_index: int, player: PlayerState, phase: String) -> float:
	var base_score := super._score_play_basic(card, game_state, player_index, player, phase)
	var name := _card_name(card)
	if name == WYRDEER_V:
		if _lugia_core_shell_pressure(player):
			return minf(base_score, 25.0)
		var energy_score := float(_v175_total_attached_energy(player)) * 18.0
		return maxf(base_score, 145.0 + energy_score)
	if _v175_card_is_regigigas(card):
		if _lugia_core_shell_pressure(player):
			return minf(base_score, 20.0)
		var tera_bonus := 90.0 if _v175_opponent_active_is_tera(game_state, player_index) else 0.0
		return maxf(base_score, 135.0 + tera_bonus)
	return base_score


func _score_stadium(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var base_score := super._score_stadium(card, game_state, player, player_index, phase)
	if _card_name(card) != MESAGOZA:
		return base_score
	if game_state != null and game_state.stadium_card != null and _card_name(game_state.stadium_card) == MESAGOZA:
		return 0.0
	if _should_cool_off_draw_churn(player, phase):
		return -60.0
	if _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 230.0 if phase == "early" else 140.0
	if _count_named_on_field(player, LUGIA_V) > 0 and _count_named_on_field(player, LUGIA_VSTAR) == 0:
		return 180.0
	if _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO) == 0:
		return 155.0
	if _count_named_on_field(player, ARCHEOPS) > 0 and phase == "late":
		return 80.0
	return 60.0


func _score_trainer(
	card: CardInstance,
	player: PlayerState,
	phase: String,
	game_state: GameState = null,
	player_index: int = -1
) -> float:
	var base_score := super._score_trainer(card, player, phase, game_state, player_index)
	var name := _card_name(card)
	if name != NEST_BALL:
		return base_score
	if player == null or player.is_bench_full():
		return 0.0
	if _should_cool_off_draw_churn(player, phase):
		return -60.0
	var owner_missing := _count_named_on_field(player, LUGIA_V) + _count_named_on_field(player, LUGIA_VSTAR) == 0
	var minccino_missing := _count_named_on_field(player, MINCCINO) + _count_named_on_field(player, CINCCINO) == 0
	if owner_missing:
		return 470.0 if phase == "early" else 320.0
	if minccino_missing:
		return 300.0
	if _lugia_core_shell_pressure(player):
		return 180.0
	if _count_named_on_field(player, ARCHEOPS) > 0 and phase == "late":
		return 160.0
	return 95.0


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var base_score := super._search_score(card, game_state, player_index)
	var name := _card_name(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		if name == WYRDEER_V or _v175_name_is_regigigas(name):
			return maxi(base_score, 45)
		return base_score
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var engine_online := _count_named_on_field(player, ARCHEOPS) > 0
	if name == WYRDEER_V:
		if _lugia_core_shell_pressure(player):
			return mini(base_score, 25)
		var energy_bonus := mini(80, _v175_total_attached_energy(player) * 12)
		return maxi(base_score, 175 + energy_bonus)
	if _v175_card_is_regigigas(card):
		if _lugia_core_shell_pressure(player):
			return mini(base_score, 20)
		var tera_bonus := 70 if _v175_opponent_active_is_tera(game_state, player_index) else 0
		return maxi(base_score, 150 + tera_bonus if engine_online or phase == "late" else 70)
	return base_score


func _assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	var base_score := super._assignment_target_score(slot, context)
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	if slot == null or player == null or _count_named_on_field(player, ARCHEOPS) == 0:
		return base_score
	var source_card: CardInstance = context.get("source_card", null)
	if _v175_slot_is_energy_capped(slot, context):
		return minf(base_score, 40.0)
	var active_conversion_target := _v175_active_conversion_target(player)
	if active_conversion_target != null and slot == active_conversion_target:
		if _slot_name(slot) == CINCCINO:
			return maxf(base_score, 520.0)
		if _slot_name(slot) == WYRDEER_V:
			return maxf(base_score, 430.0)
		if _v175_slot_is_regigigas(slot):
			return maxf(base_score, 390.0)
	if (
		active_conversion_target != null
		and slot != active_conversion_target
		and _v175_slot_is_lugia_owner(slot)
		and slot != player.active_pokemon
	):
		return minf(base_score, 120.0)
	if _slot_name(slot) == CINCCINO and _v175_primary_lugia_needs_charge(player):
		return minf(base_score, 95.0)
	if _slot_name(slot) == CINCCINO:
		if _v175_card_is_legacy_energy(source_card):
			return maxf(base_score, 560.0)
		return maxf(base_score, 430.0 if _v175_effective_energy_count(slot, context) < 5 else 360.0)
	if _slot_name(slot) == WELLSPRING_OGERPON_EX:
		if _v175_card_is_legacy_energy(source_card) or _v175_slot_has_legacy_energy(slot):
			return maxf(base_score, 260.0)
		return minf(base_score, 70.0)
	if _slot_name(slot) == WYRDEER_V:
		if _v175_primary_lugia_needs_charge(player):
			return minf(base_score, 90.0)
		return maxf(base_score, 390.0 if _attack_energy_gap(slot) > 0 else 250.0)
	if _v175_slot_is_regigigas(slot):
		if _v175_primary_lugia_needs_charge(player):
			return minf(base_score, 85.0)
		return maxf(base_score, 340.0 if _attack_energy_gap(slot) > 0 else 210.0)
	return base_score


func _score_attach(
	card: CardInstance,
	target_slot: PokemonSlot,
	player: PlayerState,
	phase: String,
	game_state: GameState = null
) -> float:
	var base_score := super._score_attach(card, target_slot, player, phase, game_state)
	if target_slot == null or player == null:
		return base_score
	if _v175_slot_is_energy_capped(target_slot):
		return minf(base_score, 30.0)
	var engine_online := _count_named_on_field(player, ARCHEOPS) > 0
	var active_conversion_target := _v175_active_conversion_target(player)
	if active_conversion_target != null and target_slot == active_conversion_target:
		if _slot_name(target_slot) == CINCCINO:
			return maxf(base_score, 430.0)
		if _slot_name(target_slot) == WYRDEER_V:
			return maxf(base_score, 360.0)
		if _v175_slot_is_regigigas(target_slot):
			return maxf(base_score, 330.0)
	if (
		active_conversion_target != null
		and target_slot != active_conversion_target
		and _v175_slot_is_lugia_owner(target_slot)
		and target_slot != player.active_pokemon
	):
		return minf(base_score, 100.0)
	if not engine_online and _lugia_core_shell_pressure(player):
		if _slot_name(target_slot) == WYRDEER_V or _v175_slot_is_regigigas(target_slot):
			return minf(base_score, 35.0)
	if _slot_name(target_slot) == CINCCINO and _count_named_on_field(player, ARCHEOPS) > 0 and _v175_primary_lugia_needs_charge(player):
		return minf(base_score, 85.0)
	if _slot_name(target_slot) == CINCCINO and engine_online:
		if _v175_card_is_legacy_energy(card):
			return maxf(base_score, 540.0)
		return maxf(base_score, 410.0 if _v175_effective_energy_count(target_slot) < 5 else 340.0)
	if _slot_name(target_slot) == WELLSPRING_OGERPON_EX and engine_online:
		if _v175_card_is_legacy_energy(card) or _v175_slot_has_legacy_energy(target_slot):
			return maxf(base_score, 220.0 if _attack_energy_gap(target_slot) > 0 else 90.0)
		return minf(base_score, 80.0)
	if _slot_name(target_slot) == WYRDEER_V and engine_online:
		if _v175_primary_lugia_needs_charge(player):
			return minf(base_score, 80.0)
		return maxf(base_score, 320.0 if _attack_energy_gap(target_slot) > 0 else 120.0)
	if _v175_slot_is_regigigas(target_slot) and engine_online:
		if _v175_primary_lugia_needs_charge(player):
			return minf(base_score, 75.0)
		return maxf(base_score, 300.0 if _attack_energy_gap(target_slot) > 0 else 110.0)
	return base_score


func _score_attack(action: Dictionary, game_state: GameState, player_index: int, phase: String) -> float:
	var base_score: float = super._score_attack(action, game_state, player_index, phase)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return base_score
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_named_on_field(player, ARCHEOPS) == 0:
		return base_score
	var source_slot: PokemonSlot = action.get("source_slot", null)
	if source_slot == null:
		source_slot = player.active_pokemon
	if not _v175_slot_is_lugia_owner(source_slot):
		return base_score
	var projected_damage := int(action.get("projected_damage", 0))
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	var projected_ko := bool(action.get("projected_knockout", false))
	if not projected_ko and defender != null:
		projected_ko = projected_damage >= defender.get_remaining_hp()
	if projected_damage <= 30 and not projected_ko:
		return minf(base_score, 40.0)
	return base_score


func _v175_slot_is_lugia_owner(slot: PokemonSlot) -> bool:
	return _slot_is(slot, [LUGIA_V, LUGIA_VSTAR, "娲涘浜歏", "娲涘浜歏STAR"])


func _v175_primary_lugia_needs_charge(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot != null and slot.get_remaining_hp() > 0 and _slot_name(slot) == LUGIA_VSTAR and _attack_energy_gap(slot) > 0:
			return true
	return false


func _v175_slot_energy_cap(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	if _v175_slot_is_lugia_owner(slot) or _v175_slot_is_regigigas(slot):
		return 4
	return 0


func _v175_effective_energy_count(slot: PokemonSlot, context: Dictionary = {}) -> int:
	if slot == null:
		return 0
	var total := slot.attached_energy.size()
	var pending_counts: Variant = context.get("pending_assignment_counts", {})
	if pending_counts is Dictionary:
		total += int((pending_counts as Dictionary).get(slot.get_instance_id(), 0))
	return total


func _v175_slot_is_energy_capped(slot: PokemonSlot, context: Dictionary = {}) -> bool:
	var cap := _v175_slot_energy_cap(slot)
	return cap > 0 and _v175_effective_energy_count(slot, context) >= cap


func _best_special_energy_target(player: PlayerState) -> PokemonSlot:
	if _v175_primary_lugia_needs_charge(player):
		for slot: PokemonSlot in _all_slots(player):
			if _slot_name(slot) == LUGIA_VSTAR and _attack_energy_gap(slot) > 0:
				return slot
	var preferred: Array[String] = [CINCCINO, LUGIA_VSTAR, WYRDEER_V, REGIGIGAS, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, LUGIA_V]
	for target_name: String in preferred:
		for slot: PokemonSlot in _all_slots(player):
			if _v175_slot_is_energy_capped(slot):
				continue
			if target_name == REGIGIGAS:
				if not _v175_slot_is_regigigas(slot):
					continue
			elif _slot_name(slot) != target_name:
				continue
			if _attack_energy_gap(slot) > 0 or _slot_name(slot) == CINCCINO:
				return slot
	return null


func _send_out_target_score(slot: PokemonSlot, context: Dictionary = {}) -> float:
	var score := super._send_out_target_score(slot, context)
	if slot == null:
		return score
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	if _v175_can_charge_handoff_this_turn(slot, player):
		if _slot_name(slot) == WYRDEER_V:
			score += 220.0
		elif _v175_slot_is_regigigas(slot):
			score += 185.0
	if _slot_name(slot) == WYRDEER_V and _attack_energy_gap(slot) <= 0:
		score += 120.0 + float(_v175_wyrdeer_damage(slot)) * 0.4
	if _v175_slot_is_regigigas(slot) and _attack_energy_gap(slot) <= 0:
		score += 95.0
	return score


func _best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	if _slot_name(slot) == WYRDEER_V:
		return _v175_wyrdeer_damage(slot)
	if _v175_slot_is_regigigas(slot):
		return 100
	if _slot_name(slot) == WELLSPRING_OGERPON_EX:
		return _v175_wellspring_damage(slot)
	return super._best_attack_damage(slot)


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot != null and _slot_name(slot) == WELLSPRING_OGERPON_EX:
		if _v175_slot_has_legacy_energy(slot):
			return maxi(0, 3 - slot.attached_energy.size())
		return maxi(0, 1 - slot.attached_energy.size())
	return super._attack_energy_gap(slot)


func _build_continuity_action_bonuses(player: PlayerState, setup_debt: Dictionary) -> Array[Dictionary]:
	var bonuses := super._build_continuity_action_bonuses(player, setup_debt)
	for bonus: Dictionary in bonuses:
		var card_names: Variant = bonus.get("card_names", [])
		if not (card_names is Array):
			continue
		if GREAT_BALL in (card_names as Array) or ULTRA_BALL in (card_names as Array):
			if not (card_names as Array).has(NEST_BALL):
				(card_names as Array).append(NEST_BALL)
		if GREAT_BALL in (card_names as Array) and not (card_names as Array).has(MESAGOZA):
			(card_names as Array).append(MESAGOZA)
	return bonuses


func _is_continuity_backup_seed(slot: PokemonSlot) -> bool:
	if _slot_name(slot) == WELLSPRING_OGERPON_EX:
		return _v175_slot_has_legacy_energy(slot)
	return super._is_continuity_backup_seed(slot) or _slot_name(slot) == WYRDEER_V or _v175_slot_is_regigigas(slot)


func _is_continuity_energy_target(slot: PokemonSlot) -> bool:
	if _slot_name(slot) == WELLSPRING_OGERPON_EX:
		return _v175_slot_has_legacy_energy(slot)
	return super._is_continuity_energy_target(slot) or _slot_name(slot) == WYRDEER_V or _v175_slot_is_regigigas(slot)


func _v175_name_is_regigigas(name: String) -> bool:
	var normalized := name.strip_edges().to_lower()
	return normalized == REGIGIGAS.to_lower()


func _v175_slot_is_regigigas(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	return _v175_card_data_is_regigigas(slot.get_card_data())


func _v175_card_is_regigigas(card: Variant) -> bool:
	if not (card is CardInstance):
		return false
	return _v175_card_data_is_regigigas((card as CardInstance).card_data)


func _v175_card_data_is_regigigas(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if _v175_name_is_regigigas(str(card_data.name_en)) or _v175_name_is_regigigas(str(card_data.name)):
		return true
	if str(card_data.stage) != "Basic" or int(card_data.hp) != 160:
		return false
	for attack: Dictionary in card_data.attacks:
		if str(attack.get("name", "")) == REGIGIGAS_ATTACK and str(attack.get("cost", "")) == "CCCC":
			return true
	return false


func _v175_total_attached_energy(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for slot: PokemonSlot in _all_slots(player):
		if slot != null:
			total += slot.attached_energy.size()
	return total


func _v175_wyrdeer_damage(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	var energy_units := _attached_energy_units(slot)
	if energy_units < 3:
		return 0
	return maxi(0, energy_units * 40 + _attached_damage_modifier(slot))


func _v175_wellspring_damage(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	if _v175_slot_has_legacy_energy(slot) and slot.attached_energy.size() >= 3:
		return 100
	return 20 if slot.attached_energy.size() >= 1 else 0


func _v175_slot_has_legacy_energy(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _v175_card_is_legacy_energy(energy):
			return true
	return false


func _v175_card_is_legacy_energy(card: Variant) -> bool:
	if not (card is CardInstance):
		return false
	return _card_name(card) == LEGACY_ENERGY


func _v175_opponent_active_is_tera(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	var cd := opponent.active_pokemon.get_card_data()
	return cd != null and cd.is_tera_pokemon()


func _v175_best_chargeable_handoff(player: PlayerState) -> PokemonSlot:
	if player == null or _v175_primary_lugia_needs_charge(player):
		return null
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in player.bench:
		if not _v175_can_charge_handoff_this_turn(slot, player):
			continue
		var score := 0.0
		if _slot_name(slot) == WYRDEER_V:
			score = 260.0 + float(_v175_projected_wyrdeer_damage_after_charge(slot, player))
		elif _v175_slot_is_regigigas(slot):
			score = 210.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _v175_can_charge_handoff_this_turn(slot: PokemonSlot, player: PlayerState) -> bool:
	if slot == null or player == null:
		return false
	if slot.get_remaining_hp() <= 0:
		return false
	if _slot_name(slot) != WYRDEER_V and not _v175_slot_is_regigigas(slot):
		return false
	if _attack_energy_gap(slot) <= 0:
		return false
	if _v175_count_live_named_on_field(player, ARCHEOPS) <= 0:
		return false
	var needed_units := _attack_energy_gap(slot)
	return _v175_available_archeops_energy_units(player) >= needed_units


func _v175_available_archeops_energy_units(player: PlayerState) -> int:
	if player == null:
		return 0
	var max_cards := _count_named_on_field(player, ARCHEOPS) * 2
	if max_cards <= 0:
		return 0
	var units: Array[int] = []
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) != "Special Energy":
			continue
		units.append(_v175_energy_card_units(card))
	units.sort()
	units.reverse()
	var total := 0
	for idx: int in mini(max_cards, units.size()):
		total += units[idx]
	return total


func _v175_energy_card_units(card: CardInstance) -> int:
	if _card_name(card) == DOUBLE_TURBO_ENERGY:
		return 2
	return 1


func _v175_projected_wyrdeer_damage_after_charge(slot: PokemonSlot, player: PlayerState) -> int:
	if slot == null:
		return 0
	var units := _attached_energy_units(slot)
	var damage_modifier := _attached_damage_modifier(slot)
	var max_cards := _count_named_on_field(player, ARCHEOPS) * 2
	var added_cards := 0
	var sorted_units: Array[Dictionary] = []
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) != "Special Energy":
			continue
		sorted_units.append({
			"units": _v175_energy_card_units(card),
			"modifier": -20 if _card_name(card) == DOUBLE_TURBO_ENERGY else 0,
		})
	sorted_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("units", 0)) > int(b.get("units", 0))
	)
	for entry: Dictionary in sorted_units:
		if added_cards >= max_cards:
			break
		if units >= 3:
			break
		units += int(entry.get("units", 0))
		damage_modifier += int(entry.get("modifier", 0))
		added_cards += 1
	if units < 3:
		return 0
	return maxi(0, units * 40 + damage_modifier)


func _v175_active_conversion_target(player: PlayerState) -> PokemonSlot:
	if player == null or player.active_pokemon == null:
		return null
	var active := player.active_pokemon
	if _v175_slot_is_lugia_owner(active):
		return null
	var active_name := _slot_name(active)
	if active_name != CINCCINO and active_name != WYRDEER_V and not _v175_slot_is_regigigas(active):
		return null
	var gap := _attack_energy_gap(active)
	if gap <= 0:
		return null
	if _count_named_on_field(player, ARCHEOPS) <= 0:
		return null
	if _v175_available_archeops_energy_units(player) < gap:
		return null
	return active


func _v175_count_live_named_on_field(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or slot.get_remaining_hp() <= 0:
			continue
		if _slot_is(slot, [target_name]):
			count += 1
	return count
