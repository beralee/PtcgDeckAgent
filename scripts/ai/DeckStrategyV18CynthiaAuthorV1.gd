class_name DeckStrategyV18CynthiaAuthorV1
extends "res://scripts/ai/DeckStrategyV18MarnieCynthia.gd"


const AUTHOR_STRATEGY_ID := "v18_cynthia_garchomp_author_v1"
const BUDEW_POFFIN_BONUS := 1500.0
const BUDEW_CHIP_ATTACK_PENALTY := 1650.0
const ROSERADE_EVOLUTION_BONUS := 4600.0
const ROSERADE_ATTACK_PENALTY := 3600.0
const POWER_WEIGHT_ATTACH_BONUS := 6400.0
const POWER_WEIGHT_ATTACK_PENALTY := 4400.0
const POFFIN_BACKUP_BONUS := 7000.0
const ARVEN_BACKUP_BONUS := 7600.0
const GARCHOMP_BACKUP_ATTACK_PENALTY := 7000.0
const ARVEN_NAME_EN := "Arven"
const ARVEN_UID := "CSV1C_123"


func get_strategy_id() -> String:
	return AUTHOR_STRATEGY_ID


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if _should_build_distinct_tm_roots(step, context):
		var distinct_roots: Array = []
		for root_key: String in [GIBLE, ROSELIA]:
			for item: Variant in items:
				if _matches_key(item, root_key):
					distinct_roots.append(item)
					break
		if distinct_roots.size() == 2:
			return distinct_roots
	return super.pick_interaction_items(items, step, context)


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	var contract: Dictionary = super.build_continuity_contract(game_state, player_index, turn_contract)
	var player := _valid_player(game_state, player_index)
	var needs_poffin := _needs_budew_poffin_before_chip(player, game_state)
	var needs_arven := _needs_budew_arven_poffin_before_chip(player, game_state)
	var needs_roserade := _needs_roserade_evolution_before_attack(player, game_state)
	var needs_power_weight := _needs_power_weight_before_attack(player)
	var needs_backup_poffin := _needs_garchomp_poffin_backup_before_attack(player)
	var needs_backup_arven := _needs_garchomp_arven_poffin_backup_before_attack(player, game_state)
	if not needs_poffin and not needs_arven and not needs_roserade and not needs_power_weight \
			and not needs_backup_poffin and not needs_backup_arven:
		return contract
	var debt: Dictionary = (contract.get("setup_debt", {}) as Dictionary).duplicate(true)
	var added_debt := 0
	if needs_poffin:
		debt["needs_budew_poffin_before_chip"] = 1
		added_debt += 1
	if needs_arven:
		debt["needs_arven_poffin_before_chip"] = 1
		added_debt += 1
	if needs_roserade:
		debt["needs_roserade_evolution_before_attack"] = 1
		added_debt += 1
	if needs_power_weight:
		debt["needs_power_weight_before_attack"] = 1
		added_debt += 1
	if needs_backup_poffin:
		debt["needs_poffin_backup_before_attack"] = 1
		added_debt += 1
	if needs_backup_arven:
		debt["needs_arven_poffin_backup_before_attack"] = 1
		added_debt += 1
	debt["total"] = int(debt.get("total", 0)) + added_debt
	var bonuses: Array = (contract.get("action_bonuses", []) as Array).duplicate(true)
	if needs_poffin:
		bonuses.append({
			"kind": "play_trainer",
			"card_names": IDENTITY_ALIASES.get(BUDDY_BUDDY_POFFIN, []),
			"bonus": BUDEW_POFFIN_BONUS,
		})
	if needs_arven:
		bonuses.append({
			"kind": "play_trainer",
			"card_names": [ARVEN_NAME_EN],
			"bonus": 1800.0,
		})
	if needs_roserade:
		bonuses.append({
			"kind": "evolve",
			"card_names": IDENTITY_ALIASES.get(ROSERADE, []),
			"bonus": ROSERADE_EVOLUTION_BONUS,
		})
	if needs_power_weight:
		bonuses.append({
			"kind": "attach_tool",
			"card_names": IDENTITY_ALIASES.get(POWER_WEIGHT, []),
			"target_names": IDENTITY_ALIASES.get(GARCHOMP, []),
			"bonus": POWER_WEIGHT_ATTACH_BONUS,
		})
	if needs_backup_poffin:
		bonuses.append({
			"kind": "play_trainer",
			"card_names": IDENTITY_ALIASES.get(BUDDY_BUDDY_POFFIN, []),
			"bonus": POFFIN_BACKUP_BONUS,
		})
	if needs_backup_arven:
		bonuses.append({
			"kind": "play_trainer",
			"card_names": [ARVEN_NAME_EN],
			"bonus": ARVEN_BACKUP_BONUS,
		})
	contract["enabled"] = true
	contract["safe_setup_before_attack"] = true
	contract["setup_debt"] = debt
	contract["action_bonuses"] = bonuses
	var required_attack_penalty := 0.0
	if needs_poffin or needs_arven:
		required_attack_penalty = maxf(required_attack_penalty, BUDEW_CHIP_ATTACK_PENALTY)
	if needs_roserade:
		required_attack_penalty = maxf(required_attack_penalty, ROSERADE_ATTACK_PENALTY)
	if needs_power_weight:
		required_attack_penalty = maxf(required_attack_penalty, POWER_WEIGHT_ATTACK_PENALTY)
	if needs_backup_poffin or needs_backup_arven:
		required_attack_penalty = maxf(required_attack_penalty, GARCHOMP_BACKUP_ATTACK_PENALTY)
	contract["attack_penalty"] = maxf(float(contract.get("attack_penalty", 0.0)), required_attack_penalty)
	return contract


func score_action_absolute(
	action: Dictionary,
	game_state: GameState,
	player_index: int
) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	var player := _valid_player(game_state, player_index)
	if _deck_id != CYNTHIA_DECK_ID or player == null:
		return score
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"retreat":
			var ready_bench_garchomp := _ready_bench_garchomp(player)
			if ready_bench_garchomp != null \
					and not _should_hold_protected_cynthia_pivot(player) \
					and _garchomp_retreat_converts_now(ready_bench_garchomp, player, game_state, player_index):
				var retreat_target: PokemonSlot = action.get("bench_target", null)
				if retreat_target == ready_bench_garchomp:
					return maxf(score, 7600.0)
				return minf(score, -2500.0)
		"play_trainer":
			if _matches_key(card, BUDDY_BUDDY_POFFIN) and _needs_budew_poffin_before_chip(player, game_state):
				return maxf(score, 6100.0)
			if _is_arven(card) and _needs_budew_arven_poffin_before_chip(player, game_state):
				return maxf(score, 6900.0)
		"play_basic_to_bench":
			if _matches_key(card, GIBLE) and not _has_slot(player, GIBLE):
				return maxf(score, 6500.0)
			if _matches_key(card, ROSELIA) and not _has_slot(player, ROSELIA):
				return maxf(score, 5600.0)
		"attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			if _matches_key(source, BUDEW) and _needs_budew_setup_before_chip(player, game_state) \
					and not bool(action.get("projected_knockout", false)):
				return minf(score, -2400.0)
			if _matches_key(source, GARCHOMP):
				return _score_garchomp_minimum_lethal(action, game_state, player_index, player, score)
	return score


func _score_garchomp_minimum_lethal(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	current_score: float
) -> float:
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := _attack_name(action, action.get("source_slot", player.active_pokemon))
	var is_spiral := attack_index == 0 or attack_name in ["螺旋俯冲", "Spiral Dive"]
	var is_blast := attack_index == 1 or attack_name in ["龙之爆破", "Dragon Blast"]
	if not is_spiral and not is_blast:
		return current_score
	var defender_hp := _opponent_active_remaining_hp(game_state, player_index)
	if defender_hp <= 0:
		return current_score
	var roserade_bonus := 30 * _count_slots(player, ROSERADE)
	var spiral_damage := 100 + roserade_bonus
	var blast_damage := 260 + roserade_bonus
	var projected_damage := maxi(int(action.get("projected_damage", 0)), 0)
	if is_spiral and projected_damage > 0:
		spiral_damage = projected_damage
	elif is_blast and projected_damage > 0:
		# Both attacks share the same type and attacker-side modifiers.  Derive the
		# cheaper attack's effective damage from the engine projection so weakness
		# (notably Miraidon's Fighting weakness) is not mistaken for a Blast-only KO.
		var printed_blast_damage := 260 + roserade_bonus
		blast_damage = projected_damage
		spiral_damage = roundi(float(100 + roserade_bonus) * float(projected_damage) / float(printed_blast_damage))
	var spiral_ko := defender_hp <= spiral_damage
	var blast_ko := defender_hp <= blast_damage
	if is_spiral and spiral_ko:
		return maxf(current_score, 7200.0)
	if is_blast and spiral_ko:
		return minf(current_score, 6500.0)
	if is_blast and blast_ko:
		return maxf(current_score, 8200.0)
	return current_score


func _needs_budew_poffin_before_chip(player: PlayerState, game_state: GameState) -> bool:
	return _budew_core_setup_is_missing(player, game_state) and _hand_has(player, BUDDY_BUDDY_POFFIN)


func _needs_budew_arven_poffin_before_chip(player: PlayerState, game_state: GameState) -> bool:
	return _budew_core_setup_is_missing(player, game_state) \
		and not _hand_has(player, BUDDY_BUDDY_POFFIN) \
		and not bool(game_state.supporter_used_this_turn) \
		and (_hand_has(player, ARVEN_UID) or _hand_has(player, ARVEN_NAME_EN)) \
		and _deck_has_key(player, BUDDY_BUDDY_POFFIN)


func _needs_budew_setup_before_chip(player: PlayerState, game_state: GameState) -> bool:
	return _needs_budew_poffin_before_chip(player, game_state) \
		or _needs_budew_arven_poffin_before_chip(player, game_state)


func _needs_roserade_evolution_before_attack(player: PlayerState, game_state: GameState) -> bool:
	if player == null or game_state == null or _ready_garchomp(player) == null:
		return false
	if _has_slot(player, ROSERADE) or not _hand_has(player, ROSERADE):
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, ROSELIA) \
				and int(slot.turn_played) < int(game_state.turn_number) \
				and int(slot.turn_evolved) != int(game_state.turn_number):
			return true
	return false


func _needs_power_weight_before_attack(player: PlayerState) -> bool:
	return player != null \
		and _matches_key(player.active_pokemon, GARCHOMP) \
		and player.active_pokemon.attached_tool == null \
		and _hand_has(player, POWER_WEIGHT)


func _needs_garchomp_poffin_backup_before_attack(player: PlayerState) -> bool:
	return _garchomp_backup_is_missing(player) \
		and _hand_has(player, BUDDY_BUDDY_POFFIN)


func _needs_garchomp_arven_poffin_backup_before_attack(player: PlayerState, game_state: GameState) -> bool:
	return _garchomp_backup_is_missing(player) \
		and game_state != null \
		and not bool(game_state.supporter_used_this_turn) \
		and not _hand_has(player, BUDDY_BUDDY_POFFIN) \
		and (_hand_has(player, ARVEN_UID) or _hand_has(player, ARVEN_NAME_EN)) \
		and _deck_has_key(player, BUDDY_BUDDY_POFFIN)


func _garchomp_backup_is_missing(player: PlayerState) -> bool:
	if player == null:
		return false
	var ready_owner := _ready_garchomp(player)
	if ready_owner == null or player.is_bench_full() or not _deck_has_key(player, GIBLE):
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == ready_owner:
			continue
		if _matches_key(slot, GIBLE) or _matches_key(slot, GABITE) or _matches_key(slot, GARCHOMP):
			return false
	return true


func _should_build_distinct_tm_roots(step: Dictionary, context: Dictionary) -> bool:
	if _deck_id != CYNTHIA_DECK_ID \
			or str(step.get("id", "")).to_lower() != "buddy_poffin_pokemon" \
			or int(step.get("max_select", 1)) < 2:
		return false
	var game_state: GameState = context.get("game_state", null)
	var player := _player_from_context(context)
	if player == null or game_state == null or player.active_pokemon == null:
		return false
	if _first_player_attack_locked(game_state, player) \
			or player.active_pokemon.attached_tool != null \
			or not _hand_has(player, TM_EVOLUTION) \
			or not _can_fund_tm_evolution_attack(player.active_pokemon, player, game_state):
		return false
	if _has_slot(player, GIBLE) or _has_slot(player, GABITE) or _has_slot(player, GARCHOMP) \
			or _has_slot(player, ROSELIA) or _has_slot(player, ROSERADE):
		return false
	return _deck_has_key(player, GABITE) and _deck_has_key(player, ROSERADE)


func _budew_core_setup_is_missing(player: PlayerState, game_state: GameState) -> bool:
	if player == null or game_state == null or not _matches_key(player.active_pokemon, BUDEW):
		return false
	if player.is_bench_full() or _ready_garchomp(player) != null:
		return false
	if _slot_has_tm_evolution(player.active_pokemon) or _has_live_cynthia_tm_carrier(player, game_state):
		return false
	return _deck_has_key(player, GIBLE) or _deck_has_key(player, ROSELIA)


func _deck_has_key(player: PlayerState, key: String) -> bool:
	if player != null:
		for card: CardInstance in player.deck:
			if _matches_key(card, key):
				return true
	return false


func _ready_bench_garchomp(player: PlayerState) -> PokemonSlot:
	if player != null:
		for slot: PokemonSlot in player.bench:
			if _matches_key(slot, GARCHOMP) and _fighting_units(slot) >= 1:
				return slot
	return null


func _should_hold_protected_cynthia_pivot(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active := player.active_pokemon
	var protected_roselia := _matches_key(active, ROSELIA) \
		and _matches_key(active.attached_tool, POWER_WEIGHT) \
		and int(active.damage_counters) <= 0 \
		and not active.attached_energy.is_empty()
	var live_spiritomb := _matches_key(active, SPIRITOMB) \
		and not active.attached_energy.is_empty() \
		and _cynthia_benched_damage(player) + 30 * _count_slots(player, ROSERADE) >= 50
	return protected_roselia or live_spiritomb


func _garchomp_retreat_converts_now(
	garchomp: PokemonSlot,
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> bool:
	if garchomp == null or player == null or game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	var printed_damage := 260 if _fighting_units(garchomp) >= 2 else 100
	var roserade_bonus := 30 * _count_slots(player, ROSERADE)
	var projected_damage := DamageCalculator.new().calculate_damage(
		garchomp,
		opponent.active_pokemon,
		{"damage": str(printed_damage)},
		game_state,
		0,
		roserade_bonus
	)
	return opponent.active_pokemon.get_remaining_hp() <= projected_damage


func _is_arven(card: Variant) -> bool:
	return _matches_key(card, ARVEN_UID) or _matches_key(card, ARVEN_NAME_EN)


func _opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	var opponent_index := 1 - player_index
	if game_state == null or opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.active_pokemon == null:
		return 0
	return opponent.active_pokemon.get_remaining_hp()
