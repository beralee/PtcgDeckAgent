class_name DeckStrategy17Regidrago
extends "res://scripts/ai/DeckStrategyRegidrago.gd"

const ALOLAN_EXEGGUTOR_EX := "CSV9C_144"
const KYUREM := "CSV9C_147"
const SUPERIOR_ENERGY_RETRIEVAL := "Superior Energy Retrieval"
const SWITCH := "Switch"

const V17_DRAGON_FUEL_NAMES: Array[String] = [
	GIRATINA_VSTAR,
	DRAGAPULT_EX,
	HISUIAN_GOODRA_VSTAR,
	HAXORUS,
	ALOLAN_EXEGGUTOR_EX,
	KYUREM,
	"Alolan Exeggutor ex",
	"Kyurem",
]


func get_strategy_id() -> String:
	return "v17_regidrago"


func get_signature_names() -> Array[String]:
	return [REGIDRAGO_V, REGIDRAGO_VSTAR, GIRATINA_VSTAR, DRAGAPULT_EX, TEAL_MASK_OGERPON_EX]


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var has_regidrago_basic := false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.is_basic_pokemon():
			continue
		if _card_name(card) == REGIDRAGO_V:
			has_regidrago_basic = true
			break
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or card.card_data == null or not card.is_basic_pokemon():
			continue
		var name := _card_name(card)
		var active_score := 100.0
		var bench_score := 80.0
		match name:
			TEAL_MASK_OGERPON_EX:
				active_score = 455.0 if has_regidrago_basic else 320.0
				bench_score = 330.0
			REGIDRAGO_V:
				active_score = 430.0
				bench_score = 430.0
			MEW_EX:
				active_score = 220.0
				bench_score = 190.0
			CLEFFA:
				active_score = 180.0
				bench_score = 120.0
			SQUAWKABILLY_EX, FEZANDIPITI_EX:
				active_score = 120.0
				bench_score = 170.0
		basics.append({"index": i, "active": active_score, "bench": bench_score})
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
	var player := _player(game_state, player_index)
	var phase := "launch_shell"
	if player != null and _best_ready_regidrago(player) != null and _dragon_fuel_count(player) > 0:
		phase = "conversion"
	elif player != null and _count_named_on_field(player, REGIDRAGO_VSTAR) > 0:
		phase = "fuel_gate"
	return {
		"id": "v17_regidrago_%s" % phase,
		"intent": phase,
		"phase": phase,
		"owner": {
			"turn_owner_name": REGIDRAGO_VSTAR,
			"bridge_target_name": REGIDRAGO_VSTAR,
			"pivot_target_name": REGIDRAGO_VSTAR if player != null and _best_ready_regidrago(player) != null else REGIDRAGO_V,
		},
		"targets": {
			"primary_attacker_name": REGIDRAGO_VSTAR,
			"dragon_fuel_count": _dragon_fuel_count(player),
		},
		"priorities": {
			"attach": [REGIDRAGO_VSTAR, REGIDRAGO_V, TEAL_MASK_OGERPON_EX],
			"handoff": [REGIDRAGO_VSTAR, REGIDRAGO_V, TEAL_MASK_OGERPON_EX],
			"search": [REGIDRAGO_V, REGIDRAGO_VSTAR, TEAL_MASK_OGERPON_EX, GIRATINA_VSTAR, DRAGAPULT_EX, KYUREM, ALOLAN_EXEGGUTOR_EX],
			"discard": V17_DRAGON_FUEL_NAMES.duplicate(),
		},
		"constraints": {},
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _player(game_state, player_index)
	if player == null:
		return _v17_continuity_disabled()
	var setup_debt := _build_v17_continuity_setup_debt(player, game_state, player_index, turn_contract)
	if bool(setup_debt.get("terminal_attack_locked", false)):
		return _v17_continuity_disabled(setup_debt)
	var action_bonuses := _build_v17_continuity_action_bonuses(setup_debt)
	var enabled := _v17_continuity_setup_debt_is_active(setup_debt) and not action_bonuses.is_empty()
	return {
		"enabled": enabled,
		"safe_setup_before_attack": enabled,
		"setup_debt": setup_debt,
		"action_bonuses": action_bonuses,
		"attack_penalty": 260.0 if enabled else 0.0,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var kind := str(action.get("kind", ""))
	var player := _player(game_state, player_index)
	if player != null and _is_thin_deck_churn(action, player):
		return -240.0
	if kind == "end_turn" and _ready_active_apex_exists(player):
		return -12000.0
	if kind == "play_basic_to_bench" and _is_v17_dragon_fuel(action.get("card", null)):
		return -80.0
	if kind == "play_basic_to_bench" and _card_name(action.get("card", null)) == RADIANT_CHARIZARD and player != null and _has_live_or_rebuildable_regidrago(player):
		return -140.0
	if kind == "play_basic_to_bench" and player != null and _card_name(action.get("card", null)) == REGIDRAGO_V:
		if _opponent_has_charizard_pressure(game_state, player_index) and _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) < 2:
			return 680.0
	if kind == "play_basic_to_bench" and player != null and _card_name(action.get("card", null)) == MEW_EX:
		if _needs_mew_draw_for_backup_vstar(player):
			return 680.0
	if kind == "play_basic_to_bench" and _card_name(action.get("card", null)) == HAWLUCHA:
		return -60.0
	if kind == "attach_energy":
		var energy: CardInstance = action.get("card", null)
		var target: PokemonSlot = action.get("target_slot", null)
		if target != null and _slot_name(target) == RADIANT_CHARIZARD and player != null and _has_live_or_rebuildable_regidrago(player):
			return -260.0
		if player != null and energy != null and target != null and _slot_name(target) in [REGIDRAGO_V, REGIDRAGO_VSTAR]:
			var energy_type := _energy_type(energy)
			if _regidrago_needs_type(target, energy_type):
				if _manual_attach_sets_up_ogerpon_switch_apex(target, energy_type, player):
					return 820.0
				var attach_score := super.score_action_absolute(action, game_state, player_index) + (80.0 if energy_type == "R" else 20.0)
				if game_state != null and game_state.turn_number <= 3:
					attach_score = maxf(attach_score, 720.0 if energy_type == "R" else 660.0)
				return attach_score
			return maxf(30.0, super.score_action_absolute(action, game_state, player_index) - 160.0)
	if kind == "play_trainer":
		var trainer_name := _card_name(action.get("card", null))
		var pivot_target := _own_bench_target_from_action(action)
		if _late_support_pivot_liability(player.active_pokemon if player != null else null, pivot_target, player, game_state):
			return -12000.0
		if _is_live_slot(pivot_target) and player != null and player.active_pokemon != null and _opponent_has_charizard_pressure(game_state, player_index) and _charizard_pressure_retreat_is_liability(player.active_pokemon, pivot_target, player, game_state, player_index):
			return -320.0
		if trainer_name == ENERGY_SWITCH:
			if _energy_switch_strands_active_ogerpon_buffer(action, player):
				return -260.0
			if _energy_switch_completes_primary_regidrago_attack(action, player):
				return 1120.0
			if _energy_switch_advances_primary_regidrago(action, player):
				return 700.0
			if _energy_switch_drains_primary_regidrago(action, player):
				return -260.0
		if trainer_name == SWITCH:
			if _switch_promotes_ready_regidrago(action, player):
				return 900.0
			if _has_trapped_ready_benched_regidrago(player):
				return 760.0
		if trainer_name == BOSSS_ORDERS and _boss_creates_dragapult_prize_window(action, game_state, player_index):
			return 1040.0
		if trainer_name == ULTRA_BALL:
			var ultra_score := super.score_action_absolute(action, game_state, player_index)
			if _ultra_ball_discards_launch_energy_resource(action, player):
				return minf(ultra_score, 180.0)
			if _launch_energy_bridge_is_open(player):
				return minf(ultra_score, 520.0)
			if _ultra_ball_discards_v17_fuel_and_searches_vstar(action, player):
				return maxf(ultra_score, 660.0)
			return ultra_score
		if trainer_name == EARTHEN_VESSEL and _action_discards_protected_mew_draw(action, player):
			return -260.0
		if trainer_name == NEST_BALL and _action_targets_only_v17_dragon_fuel(action):
			return -160.0
		if trainer_name in [SUPER_ROD, NIGHT_STRETCHER] and _action_recovers_only_v17_dragon_fuel(action):
			return -220.0
		if trainer_name == SUPERIOR_ENERGY_RETRIEVAL:
			return _score_superior_energy_retrieval(player)
	if kind == "use_ability":
		var source: PokemonSlot = action.get("source_slot", null)
		if source != null and _slot_name(source) == SQUAWKABILLY_EX:
			if player != null and _launch_route_should_preserve_hand(player):
				return -120.0
			if game_state != null and game_state.turn_number <= 2 and player != null and _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) > 0:
				return 540.0
			return 80.0
		if source != null and _slot_name(source) == REGIDRAGO_VSTAR:
			if game_state != null and player_index >= 0 and player_index < game_state.vstar_power_used.size() and bool(game_state.vstar_power_used[player_index]):
				return -80.0
			if player != null and _has_trapped_ready_benched_regidrago(player):
				return 640.0
			if player != null and _best_ready_regidrago(player) != null and _dragon_fuel_count(player) > 0:
				return -40.0
			if player != null and _dragon_fuel_count(player) >= 2 and player.deck.size() <= 18:
				return -180.0
			if player != null and player.deck.size() <= 14:
				return -260.0
			if player != null and _dragon_fuel_count(player) > 0 and _can_finish_regidrago_attack_without_star_legacy(player, game_state):
				return -40.0
			if player != null and _dragon_fuel_count(player) < 2:
				return 720.0
			return 420.0
		if source != null and _slot_name(source) == MEW_EX:
			if player != null and _needs_mew_draw_for_backup_vstar(player):
				return 720.0
	if kind == "retreat" and player != null and player.active_pokemon != null:
		var target: PokemonSlot = action.get("bench_target", null)
		var active_name := _slot_name(player.active_pokemon)
		if _retreat_dumps_ready_active_apex_into_unready_target(action, player, target):
			return -13000.0
		if _late_support_pivot_liability(player.active_pokemon, target, player, game_state):
			return -12000.0
		if _is_live_slot(target) and _opponent_has_charizard_pressure(game_state, player_index) and _charizard_pressure_retreat_is_liability(player.active_pokemon, target, player, game_state, player_index):
			return -320.0
		if _is_live_slot(target) and _slot_name(target) == REGIDRAGO_VSTAR and not (active_name in [REGIDRAGO_V, REGIDRAGO_VSTAR]) and _attack_energy_gap(target) <= 0 and _dragon_fuel_count(player) > 0:
			return 585.0
		if _is_live_slot(target) and _slot_name(player.active_pokemon) == REGIDRAGO_V and _slot_name(target) == TEAL_MASK_OGERPON_EX and _attack_energy_gap(target) <= 0:
			return 620.0
	if kind == "attack" or kind == "granted_attack":
		if _should_defer_basic_dragon_laser_for_vstar(action, player, game_state, player_index):
			return -360.0
		if _is_apex_dragon_action(action, player) and player != null and _dragon_fuel_count(player) > 0:
			var score := 760.0 + float(mini(3, _dragon_fuel_count(player))) * 90.0
			score += float(int(action.get("projected_damage", 0))) * 0.8
			if bool(action.get("projected_knockout", false)):
				score += 260.0
			return score
		if _is_celestial_roar_action(action, player):
			if player != null and (_count_named_on_field(player, REGIDRAGO_VSTAR) > 0 or _dragon_fuel_count(player) > 0 or player.deck.size() <= 22):
				return -220.0
			return 460.0
	return super.score_action_absolute(action, game_state, player_index)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var max_select := int(step.get("max_select", step.get("count", 1)))
	if max_select <= 0:
		max_select = 1
	var step_id := str(step.get("id", "")).to_lower()
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		ranked.append({
			"item": item,
			"score": score_interaction_target(item, step, context),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var selected: Array = []
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		selected.append(entry.get("item"))
	return selected


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard"):
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id.contains("search_energy") or step_id.contains("basic_energy"):
			return _energy_search_score(card, context.get("game_state", null), int(context.get("player_index", -1)))
		if step_id == "energy_assignment":
			return _energy_switch_source_score(card, context)
		if step_id == "basic_pokemon" or step_id.contains("bench"):
			return float(_bench_candidate_score(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id.contains("recover") or step_id.contains("return") or step_id.contains("rod") or step_id.contains("stretcher"):
			return _recover_score(card, context.get("game_state", null), int(context.get("player_index", -1)))
		if step_id.contains("search"):
			return float(_search_score(card, context.get("game_state", null), int(context.get("player_index", -1))))
	if item is PokemonSlot:
		if step_id.contains("bench_damage_counters") or step_id.contains("damage_counter"):
			return _bench_damage_counter_target_score(item as PokemonSlot)
		if step_id in ["opponent_switch_target", "opponent_bench_target", "gust_target"]:
			return _regidrago_gust_target_score(item as PokemonSlot, context)
		if _is_energy_assignment_step(step_id):
			return _energy_assignment_target_score(item as PokemonSlot, context)
		if step_id.contains("switch") or step_id.contains("send") or step_id.contains("active") or step_id.contains("handoff"):
			return _handoff_target_score(item as PokemonSlot, context, step_id)
	if item is Dictionary and step_id == "copied_attack":
		return _copied_attack_score(item as Dictionary, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		return _handoff_target_score(item as PokemonSlot, context, str(step.get("id", "")).to_lower())
	return score_interaction_target(item, step, context)


func get_discard_priority(card: CardInstance) -> int:
	if _is_v17_dragon_fuel(card):
		return 260
	return super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var priority := get_discard_priority(card)
	if card == null or card.card_data == null:
		return priority
	var player := _player(game_state, player_index)
	if player == null:
		return priority
	var name := _card_name(card)
	if name == REGIDRAGO_V and _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) == 0:
		return 0
	if name == REGIDRAGO_VSTAR and _count_named_on_field(player, REGIDRAGO_VSTAR) == 0 and _count_named_on_field(player, REGIDRAGO_V) > 0:
		return 15
	if name == ENERGY_SWITCH and _energy_switch_reloads_primary_regidrago(player):
		return 10
	if name == HISUIAN_GOODRA_VSTAR and _opponent_has_charizard_pressure(game_state, player_index) and _count_named_in_discard(player, name) == 0:
		return maxi(priority + 180, 460)
	if _is_v17_dragon_fuel(card) and _count_named_in_discard(player, name) == 0:
		return priority + 40
	if name == MEW_EX and _needs_mew_draw_for_backup_vstar(player):
		return 12
	if card.card_data.is_energy() and _energy_type(card) == "R" and _regidrago_needs_type(_best_regidrago_slot(player), "R"):
		return mini(priority, 45)
	if card.card_data.is_energy() and _energy_type(card) == "G" and _regidrago_needs_type(_best_regidrago_slot(player), "G"):
		return mini(priority, 70)
	return priority


func get_search_priority(card: CardInstance) -> int:
	return _search_score(card, null, -1)


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	var player := _player(game_state, player_index)
	if player != null and name == REGIDRAGO_V:
		var regidrago_v_count := _count_named_on_field(player, REGIDRAGO_V)
		var regidrago_vstar_count := _count_named_on_field(player, REGIDRAGO_VSTAR)
		var regidrago_total := regidrago_v_count + regidrago_vstar_count
		if regidrago_total <= 0:
			return 340
		if regidrago_total < 2:
			return 242 if regidrago_vstar_count > 0 and _dragon_fuel_count(player) > 0 else 205
	if player != null and name == REGIDRAGO_VSTAR and _count_named_on_field(player, REGIDRAGO_VSTAR) == 0 and _count_named_on_field(player, REGIDRAGO_V) > 0:
		return 230
	if (
		player != null
		and name == REGIDRAGO_VSTAR
		and _count_named_on_field(player, REGIDRAGO_VSTAR) > 0
		and _count_named_on_field(player, REGIDRAGO_V) > 0
	):
		return 236 if _dragon_fuel_count(player) > 0 else 186
	if player != null and _is_v17_dragon_fuel(card) and _count_named_in_discard(player, name) == 0:
		if name == GIRATINA_VSTAR:
			return 190
		if name == DRAGAPULT_EX:
			return 198
		if name == ALOLAN_EXEGGUTOR_EX:
			return 220
		if name == KYUREM:
			return 150
		return 144
	if player == null and _is_v17_dragon_fuel(card):
		if name == GIRATINA_VSTAR:
			return 120
		if name == DRAGAPULT_EX:
			return 114
		if name == ALOLAN_EXEGGUTOR_EX:
			return 112
		if name == KYUREM:
			return 92
	return super._search_score(card, game_state, player_index)


func _dragon_fuel_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for card: CardInstance in player.discard_pile:
		if _is_v17_dragon_fuel(card):
			total += 1
	return total


func _dragon_fuel_remaining(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for card: CardInstance in player.deck:
		if _is_v17_dragon_fuel(card):
			total += 1
	for card: CardInstance in player.hand:
		if _is_v17_dragon_fuel(card):
			total += 1
	return total


func _v17_continuity_disabled(setup_debt: Dictionary = {}) -> Dictionary:
	return {
		"enabled": false,
		"safe_setup_before_attack": false,
		"setup_debt": setup_debt,
		"action_bonuses": [],
		"attack_penalty": 0.0,
	}


func _build_v17_continuity_setup_debt(
	player: PlayerState,
	_game_state: GameState,
	_player_index: int,
	_turn_contract: Dictionary
) -> Dictionary:
	var debt := {
		"ready_primary_online": false,
		"need_backup_regidrago_seed": false,
		"need_backup_regidrago_vstar": false,
		"need_second_ogerpon": false,
		"need_backup_regidrago_energy": false,
		"need_ogerpon_charge": false,
		"terminal_attack_locked": false,
	}
	if player == null:
		return debt
	var active := player.active_pokemon
	var primary_ready := (
		_is_live_slot(active)
		and _slot_name(active) == REGIDRAGO_VSTAR
		and _attack_energy_gap(active) <= 0
		and _dragon_fuel_count(player) > 0
	)
	debt["ready_primary_online"] = primary_ready
	if not primary_ready:
		return debt
	if player.prizes.size() <= 1:
		debt["terminal_attack_locked"] = true
		return debt
	var open_bench_slots := _open_bench_slots(player)
	var live_regidrago_count := (
		_count_live_named_on_field(player, REGIDRAGO_V)
		+ _count_live_named_on_field(player, REGIDRAGO_VSTAR)
	)
	var live_ogerpon_count := _count_live_named_on_field(player, TEAL_MASK_OGERPON_EX)
	var needs_backup_seed := live_regidrago_count < 2 and open_bench_slots > 0
	debt["live_regidrago_count"] = live_regidrago_count
	debt["live_ogerpon_count"] = live_ogerpon_count
	debt["open_bench_slots"] = open_bench_slots
	debt["need_backup_regidrago_seed"] = needs_backup_seed
	debt["need_second_ogerpon"] = live_ogerpon_count < 2 and open_bench_slots > (1 if needs_backup_seed else 0)
	var backup := _best_v17_backup_regidrago(player, active)
	debt["need_backup_regidrago_vstar"] = backup != null and _slot_name(backup) == REGIDRAGO_V
	debt["need_backup_regidrago_energy"] = (
		backup != null
		and _attack_energy_gap(backup) > 0
		and _can_advance_backup_regidrago_energy(player, backup)
	)
	debt["need_ogerpon_charge"] = _has_uncharged_live_ogerpon(player) and _count_energy_in_hand(player, "G") > 0
	return debt


func _build_v17_continuity_action_bonuses(setup_debt: Dictionary) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if bool(setup_debt.get("need_backup_regidrago_seed", false)):
		bonuses.append({"kind": "play_basic_to_bench", "card_names": [REGIDRAGO_V], "bonus": 820.0})
		bonuses.append({"kind": "play_trainer", "card_names": [NEST_BALL], "target_names": [REGIDRAGO_V], "bonus": 780.0})
		bonuses.append({"kind": "play_trainer", "card_names": [ULTRA_BALL], "target_names": [REGIDRAGO_V], "bonus": 560.0})
	if bool(setup_debt.get("need_backup_regidrago_vstar", false)):
		bonuses.append({"kind": "evolve", "card_names": [REGIDRAGO_VSTAR], "target_names": [REGIDRAGO_V], "bonus": 780.0})
		bonuses.append({"kind": "play_trainer", "card_names": [ULTRA_BALL], "target_names": [REGIDRAGO_VSTAR], "bonus": 620.0})
	if bool(setup_debt.get("need_second_ogerpon", false)):
		bonuses.append({"kind": "play_basic_to_bench", "card_names": [TEAL_MASK_OGERPON_EX], "bonus": 560.0})
		bonuses.append({"kind": "play_trainer", "card_names": [NEST_BALL], "target_names": [TEAL_MASK_OGERPON_EX], "bonus": 560.0})
		bonuses.append({"kind": "play_trainer", "card_names": [ULTRA_BALL], "target_names": [TEAL_MASK_OGERPON_EX], "bonus": 420.0})
	if bool(setup_debt.get("need_backup_regidrago_energy", false)):
		bonuses.append({"kind": "attach_energy", "target_names": [REGIDRAGO_V, REGIDRAGO_VSTAR], "bonus": 620.0})
		bonuses.append({"kind": "play_trainer", "card_names": [ENERGY_SWITCH], "target_names": [REGIDRAGO_V, REGIDRAGO_VSTAR], "bonus": 500.0})
	if bool(setup_debt.get("need_ogerpon_charge", false)):
		bonuses.append({"kind": "use_ability", "target_names": [TEAL_MASK_OGERPON_EX], "bonus": 650.0})
		bonuses.append({"kind": "attach_energy", "target_names": [TEAL_MASK_OGERPON_EX], "bonus": 320.0})
	return bonuses


func _v17_continuity_setup_debt_is_active(setup_debt: Dictionary) -> bool:
	return (
		bool(setup_debt.get("ready_primary_online", false))
		and (
			bool(setup_debt.get("need_backup_regidrago_seed", false))
			or bool(setup_debt.get("need_backup_regidrago_vstar", false))
			or bool(setup_debt.get("need_second_ogerpon", false))
			or bool(setup_debt.get("need_backup_regidrago_energy", false))
			or bool(setup_debt.get("need_ogerpon_charge", false))
		)
	)


func _count_live_named_on_field(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _is_live_slot(slot) and _slot_name(slot) == target_name:
			count += 1
	return count


func _open_bench_slots(player: PlayerState) -> int:
	if player == null:
		return 0
	return maxi(0, 5 - player.bench.size())


func _best_v17_backup_regidrago(player: PlayerState, primary: PokemonSlot) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_score := -1000000.0
	for slot: PokemonSlot in _all_slots(player):
		if slot == primary or not _is_live_slot(slot):
			continue
		var name := _slot_name(slot)
		if not (name in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
			continue
		var score := float(slot.attached_energy.size()) * 80.0
		if name == REGIDRAGO_VSTAR:
			score += 180.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _can_advance_backup_regidrago_energy(player: PlayerState, backup: PokemonSlot) -> bool:
	if player == null or backup == null:
		return false
	for missing_type: String in _regidrago_missing_types(backup):
		if _count_energy_in_hand(player, missing_type) > 0:
			return true
		if _has_movable_ogerpon_energy_for_slot(player, backup, missing_type):
			return true
	return false


func _has_movable_ogerpon_energy_for_slot(player: PlayerState, target: PokemonSlot, required_type: String = "") -> bool:
	if player == null or target == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == target or _slot_name(slot) != TEAL_MASK_OGERPON_EX:
			continue
		for energy: CardInstance in slot.attached_energy:
			var provides := _energy_type(energy)
			if required_type == "" or provides == required_type:
				return true
	return false


func _has_uncharged_live_ogerpon(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if not _is_live_slot(slot) or _slot_name(slot) != TEAL_MASK_OGERPON_EX:
			continue
		var grass_count := 0
		for energy: CardInstance in slot.attached_energy:
			if _energy_type(energy) == "G":
				grass_count += 1
		if grass_count == 0:
			return true
	return false


func _copied_attack_score(option: Dictionary, context: Dictionary) -> float:
	var source_card: Variant = option.get("source_card", null)
	if source_card is CardInstance:
		var source_name := _card_name(source_card as CardInstance)
		var attack: Dictionary = option.get("attack", {})
		var attack_name := str(attack.get("name", ""))
		var game_state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		var opp_bench_count := 0
		var defender: PokemonSlot = null
		var own_active: PokemonSlot = null
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			var player: PlayerState = game_state.players[player_index]
			var opponent: PlayerState = game_state.players[1 - player_index]
			own_active = player.active_pokemon
			opp_bench_count = opponent.bench.size()
			defender = opponent.active_pokemon
		if source_name == KYUREM or attack_name == "Trifrost":
			return 500.0 + float(mini(3, opp_bench_count + 1)) * 110.0
		if source_name == ALOLAN_EXEGGUTOR_EX:
			var attack_index := int(option.get("attack_index", -1))
			if attack_index == 1 or attack_name in ["Swinging Sphene", "嗡嗡榍石"]:
				var score := 620.0
				if defender != null and defender.get_card_data() != null and defender.get_card_data().stage == "Basic":
					score += 560.0
				return score
			var score := 360.0
			if defender != null and defender.get_card_data() != null and defender.get_remaining_hp() <= 150:
				score += 260.0
			return score
		if source_name == DRAGAPULT_EX or attack_name == "Phantom Dive":
			var score := super._copied_attack_score(option, context)
			if defender != null and defender.get_remaining_hp() <= 200:
				score += 140.0
			return score
		if source_name == GIRATINA_VSTAR or attack_name in ["Lost Impact", "放逐冲击", "迷失冲击"]:
			var score := super._copied_attack_score(option, context)
			if defender != null:
				var attack_damage := _parse_damage(str(attack.get("damage", "")))
				var defender_name := _slot_name(defender)
				if _slot_is_charizard_attacker(defender):
					if attack_damage >= defender.get_remaining_hp():
						score += 520.0
						if own_active != null and _slot_name(own_active) == REGIDRAGO_VSTAR and own_active.get_remaining_hp() <= 140:
							score += 180.0
					elif attack_damage > 200:
						score += 360.0
						if defender_name == "Charizard ex" or _is_charizard_attacker_name(defender_name):
							score += 80.0
			return score
		if source_name == HISUIAN_GOODRA_VSTAR or attack_name == "Rolling Iron":
			var score := 760.0
			if defender != null:
				var attack_damage := _parse_damage(str(attack.get("damage", "")))
				var defender_name := _slot_name(defender)
				var goodra_survives_return := _goodra_reduction_survives_charizard_return(own_active, game_state, player_index)
				var survival_check_applies := own_active != null and _slot_name(own_active) == REGIDRAGO_VSTAR
				if attack_damage > 0 and attack_damage < defender.get_remaining_hp():
					if _slot_is_charizard_attacker(defender):
						score += 420.0 if not survival_check_applies or goodra_survives_return else -180.0
					elif defender.get_remaining_hp() >= 260:
						score += 260.0
				if defender.get_remaining_hp() > 200 and defender.get_remaining_hp() <= 230:
					score += 280.0
				elif defender.get_remaining_hp() <= 200:
					score += 40.0
					if goodra_survives_return and own_active != null and _slot_name(own_active) == REGIDRAGO_VSTAR and own_active.get_remaining_hp() <= 180:
						score += 360.0
					score += _charizard_pressure_goodra_bonus(defender, own_active, game_state, player_index)
			return score
	return super._copied_attack_score(option, context)


func _charizard_pressure_goodra_bonus(
	defender: PokemonSlot,
	own_active: PokemonSlot,
	game_state: GameState,
	player_index: int
) -> float:
	if defender == null or not _opponent_has_charizard_pressure(game_state, player_index):
		return 0.0
	if defender.get_remaining_hp() > 200:
		return 0.0
	var bonus := 520.0
	if own_active != null and _slot_name(own_active) == REGIDRAGO_VSTAR and not _goodra_reduction_survives_charizard_return(own_active, game_state, player_index):
		bonus = 220.0
	var data := defender.get_card_data()
	if data != null and str(data.mechanic).to_lower() in ["ex", "v", "vstar", "vmax"]:
		bonus += 100.0
	if defender.has_method("get_prize_count") and int(defender.get_prize_count()) >= 2:
		bonus += 80.0
	if own_active != null and _slot_name(own_active) == REGIDRAGO_VSTAR and own_active.get_remaining_hp() <= 260:
		bonus += 120.0
	return bonus


func _goodra_reduction_survives_charizard_return(own_active: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if own_active == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var prizes_taken := 0 if player.prizes.is_empty() else maxi(0, 6 - player.prizes.size())
	var expected_reduced_damage := maxi(0, 180 + prizes_taken * 30 - 80)
	return own_active.get_remaining_hp() > expected_reduced_damage


func _bench_candidate_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var player := _player(game_state, player_index)
	var name := _card_name(card)
	if _is_v17_dragon_fuel(card):
		return -240
	if player != null and name == REGIDRAGO_V:
		return 290 if _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) < 2 else 100
	if player != null and name == TEAL_MASK_OGERPON_EX:
		return 260 if _count_named_on_field(player, TEAL_MASK_OGERPON_EX) == 0 else 130
	return _search_score(card, game_state, player_index)


func _bench_damage_counter_target_score(slot: PokemonSlot) -> float:
	if not _is_live_slot(slot):
		return -900.0
	var name := _slot_name(slot)
	var score := 80.0
	var remaining_hp := slot.get_remaining_hp()
	if remaining_hp <= 60:
		score += 420.0
	elif remaining_hp <= 120:
		score += 150.0
	var data := slot.get_card_data()
	if data != null:
		if str(data.mechanic).to_lower() in ["ex", "v", "vstar", "vmax"]:
			score += 90.0
		if data.hp >= 200:
			score += 35.0
	match name:
		"Iron Hands ex", "铁臂膀ex", "鐵臂膀ex":
			score += 240.0
		"Miraidon ex", "密勒顿ex", "密勒頓ex":
			score += 180.0
		"Raikou V", "雷公V":
			score += 150.0
		"Pikachu ex", "皮卡丘ex":
			score += 140.0
		"Latias ex", "拉帝亚斯ex", "拉帝亞斯ex":
			score += 90.0
	return score


func _boss_creates_dragapult_prize_window(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var player := _player(game_state, player_index)
	if player == null or _best_ready_regidrago(player) == null or _count_named_in_discard(player, DRAGAPULT_EX) <= 0:
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent := game_state.players[1 - player_index]
	if opponent == null:
		return false
	if opponent.active_pokemon != null and opponent.active_pokemon.get_remaining_hp() <= 200:
		return false
	var chosen := _opponent_bench_target_from_action(action)
	if chosen != null:
		return _regidrago_gust_target_score(chosen) >= 520.0
	return _best_dragapult_gust_target(opponent) != null


func _opponent_bench_target_from_action(action: Dictionary) -> PokemonSlot:
	var targets: Variant = action.get("targets", [])
	if not (targets is Array):
		return null
	for entry: Variant in targets:
		if not (entry is Dictionary):
			continue
		for key: String in ["opponent_bench_target", "gust_target", "opponent_switch_target"]:
			var raw: Variant = (entry as Dictionary).get(key, null)
			if raw is Array and not (raw as Array).is_empty() and (raw as Array)[0] is PokemonSlot:
				return (raw as Array)[0] as PokemonSlot
			if raw is PokemonSlot:
				return raw as PokemonSlot
	return null


func _best_dragapult_gust_target(opponent: PlayerState) -> PokemonSlot:
	if opponent == null:
		return null
	var best_slot: PokemonSlot = null
	var best_score := 0.0
	for slot: PokemonSlot in opponent.bench:
		var score := _regidrago_gust_target_score(slot)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot if best_score >= 520.0 else null


func _regidrago_gust_target_score(slot: PokemonSlot, context: Dictionary = {}) -> float:
	if not _is_live_slot(slot):
		return -900.0
	var remaining_hp := slot.get_remaining_hp()
	if remaining_hp > 200:
		return 70.0
	var name := _slot_name(slot)
	var score := 360.0 + float(200 - remaining_hp) * 0.5
	var data := slot.get_card_data()
	if data != null and str(data.mechanic).to_lower() in ["ex", "v", "vstar", "vmax"]:
		score += 120.0
	if slot.has_method("get_prize_count"):
		score += float(slot.get_prize_count()) * 80.0
	if _charizard_active_punishes_low_value_gust(slot, context):
		score -= 620.0
	match name:
		"Raikou V", "雷公V":
			score += 110.0
		"Mew ex", "梦幻ex", "夢幻ex":
			score += 80.0
		"Squawkabilly ex", "怒鹦哥ex", "怒鸚哥ex":
			score += 70.0
	return score


func _charizard_active_punishes_low_value_gust(slot: PokemonSlot, context: Dictionary) -> bool:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if player == null or opponent == null or opponent.active_pokemon == null:
		return false
	if not _slot_is_charizard_attacker(opponent.active_pokemon):
		return false
	if not player.prizes.is_empty() and player.prizes.size() <= 1:
		return false
	var prize_count := 1
	if slot.has_method("get_prize_count"):
		prize_count = int(slot.get_prize_count())
	var data := slot.get_card_data()
	var is_rule_box := data != null and str(data.mechanic).to_lower() in ["ex", "v", "vstar", "vmax"]
	return prize_count <= 1 and not is_rule_box


func _recover_score(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var player := _player(game_state, player_index)
	var name := _card_name(card)
	if player != null and _has_trapped_ready_benched_regidrago(player):
		if name == SWITCH:
			return 720.0
		if name == PRIME_CATCHER:
			return 620.0
	if player != null and name == REGIDRAGO_VSTAR and _has_backup_basic_regidrago_needing_vstar(player):
		return 660.0
	if _is_v17_dragon_fuel(card):
		return -360.0
	if player != null and card.card_data.is_energy() and _regidrago_needs_type(_best_regidrago_slot(player), _energy_type(card)):
		var drago := _best_regidrago_slot(player)
		if drago != null and _slot_name(drago) == REGIDRAGO_VSTAR and _regidrago_primary_missing_count(drago) > 0:
			return 520.0
		return 220.0
	if player != null and name == ENERGY_SWITCH and _energy_switch_reloads_primary_regidrago(player):
		return 560.0
	return float(_search_score(card, game_state, player_index))


func _score_superior_energy_retrieval(player: PlayerState) -> float:
	if player == null:
		return 0.0
	var drago := _best_regidrago_slot(player)
	if drago == null:
		return 80.0
	var missing_types: Array[String] = []
	if _regidrago_needs_type(drago, "G"):
		missing_types.append("G")
	if _regidrago_needs_type(drago, "R"):
		missing_types.append("R")
	var useful_energy := 0
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		var energy_type := _energy_type(card)
		if energy_type in ["G", "R"]:
			useful_energy += 1
	if useful_energy <= 0:
		return 60.0
	if missing_types.size() >= 2:
		return 610.0
	if missing_types.size() == 1:
		return 510.0
	return 170.0 if useful_energy >= 3 else 90.0


func _energy_switch_advances_primary_regidrago(action: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null or _regidrago_primary_missing_count(drago) <= 0:
		return false
	var targets: Variant = action.get("targets", [])
	if targets is Array:
		for entry: Variant in targets:
			if not (entry is Dictionary):
				continue
			for value: Variant in (entry as Dictionary).values():
				if not (value is Array):
					continue
				for assignment: Variant in value:
					if not (assignment is Dictionary):
						continue
					var source_card: CardInstance = (assignment as Dictionary).get("source", null)
					var target_slot: PokemonSlot = (assignment as Dictionary).get("target", null)
					if target_slot == drago and source_card != null and _regidrago_needs_type(drago, _energy_type(source_card)):
						return true
	return _has_movable_ogerpon_energy_for_regidrago(player)


func _energy_switch_reloads_primary_regidrago(player: PlayerState) -> bool:
	if player == null:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null or not (_slot_name(drago) in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
		return false
	if _regidrago_primary_missing_count(drago) <= 0:
		return false
	return _has_movable_ogerpon_energy_for_regidrago(player)


func _energy_switch_completes_primary_regidrago_attack(action: Dictionary, player: PlayerState) -> bool:
	if player == null or _dragon_fuel_count(player) <= 0:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null or _slot_name(drago) != REGIDRAGO_VSTAR:
		return false
	var missing := _regidrago_missing_types(drago)
	if missing.size() != 1:
		return false
	var targets: Variant = action.get("targets", [])
	if targets is Array:
		for entry: Variant in targets:
			if not (entry is Dictionary):
				continue
			for value: Variant in (entry as Dictionary).values():
				if not (value is Array):
					continue
				for assignment: Variant in value:
					if not (assignment is Dictionary):
						continue
					var source_card: CardInstance = (assignment as Dictionary).get("source", null)
					var target_slot: PokemonSlot = (assignment as Dictionary).get("target", null)
					if target_slot == drago and source_card != null and _energy_type(source_card) == missing[0]:
						return true
	return missing[0] == "G" and _has_movable_ogerpon_energy_for_regidrago(player)


func _energy_switch_drains_primary_regidrago(action: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	var targets: Variant = action.get("targets", [])
	if not (targets is Array):
		return false
	for entry: Variant in targets:
		if not (entry is Dictionary):
			continue
		for value: Variant in (entry as Dictionary).values():
			if not (value is Array):
				continue
			for assignment: Variant in value:
				if not (assignment is Dictionary):
					continue
				var source_card: CardInstance = (assignment as Dictionary).get("source", null)
				var target_slot: PokemonSlot = (assignment as Dictionary).get("target", null)
				var source_slot := _find_slot_with_attached_card(player, source_card)
				if source_slot == null or source_card == null:
					continue
				if not (_slot_name(source_slot) in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
					continue
				if target_slot == source_slot or _slot_name(target_slot) in [REGIDRAGO_V, REGIDRAGO_VSTAR]:
					continue
				if _regidrago_would_miss_type_after_removal(source_slot, source_card):
					return true
	return false


func _switch_promotes_ready_regidrago(action: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	var chosen := _own_bench_target_from_action(action)
	if chosen != null:
		return _slot_name(chosen) == REGIDRAGO_VSTAR and _attack_energy_gap(chosen) <= 0 and _dragon_fuel_count(player) > 0
	return _has_trapped_ready_benched_regidrago(player)


func _has_trapped_ready_benched_regidrago(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name(player.active_pokemon) in [REGIDRAGO_V, REGIDRAGO_VSTAR]:
		return false
	if _dragon_fuel_count(player) <= 0:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_name(slot) == REGIDRAGO_VSTAR and _attack_energy_gap(slot) <= 0:
			return true
	return false


func _has_live_or_rebuildable_regidrago(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) > 0:
		return true
	for card: CardInstance in player.hand:
		var name := _card_name(card)
		if name == REGIDRAGO_V or name == REGIDRAGO_VSTAR:
			return true
	return false


func _ready_active_apex_exists(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name(player.active_pokemon) != REGIDRAGO_VSTAR:
		return false
	return _attack_energy_gap(player.active_pokemon) <= 0 and _dragon_fuel_count(player) > 0


func _retreat_dumps_ready_active_apex_into_unready_target(
	action: Dictionary,
	player: PlayerState,
	target: PokemonSlot
) -> bool:
	if not _ready_active_apex_exists(player):
		return false
	if not _is_live_slot(target):
		return false
	var discards: Variant = action.get("energy_to_discard", [])
	if not (discards is Array) or (discards as Array).is_empty():
		return false
	if _slot_name(target) == REGIDRAGO_VSTAR and _attack_energy_gap(target) <= 0 and _dragon_fuel_count(player) > 0:
		return false
	return true


func _has_backup_basic_regidrago_needing_vstar(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_name(slot) == REGIDRAGO_V:
			return true
	return false


func _needs_mew_draw_for_backup_vstar(player: PlayerState) -> bool:
	if player == null or player.is_bench_full():
		return false
	if _count_named_on_field(player, REGIDRAGO_VSTAR) > 0:
		return false
	if not _has_backup_basic_regidrago_needing_vstar(player):
		return false
	if _count_named_in_hand(player, REGIDRAGO_VSTAR) > 0:
		return false
	return _count_named_in_deck(player, REGIDRAGO_VSTAR) > 0


func _action_discards_protected_mew_draw(action: Dictionary, player: PlayerState) -> bool:
	if not _needs_mew_draw_for_backup_vstar(player):
		return false
	for card: CardInstance in _discard_cards_from_action(action):
		if _card_name(card) == MEW_EX:
			return true
	return false


func _count_named_in_deck(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.deck:
		if _card_name(card) == target_name:
			count += 1
	return count


func _own_bench_target_from_action(action: Dictionary) -> PokemonSlot:
	var targets: Variant = action.get("targets", [])
	if not (targets is Array):
		return null
	for entry: Variant in targets:
		if not (entry is Dictionary):
			continue
		for key: String in ["self_switch_target", "own_bench_target", "switch_target", "bench_target"]:
			var raw: Variant = (entry as Dictionary).get(key, null)
			if raw is Array and not (raw as Array).is_empty() and (raw as Array)[0] is PokemonSlot:
				return (raw as Array)[0] as PokemonSlot
			if raw is PokemonSlot:
				return raw as PokemonSlot
	return null


func _ultra_ball_discards_launch_energy_resource(action: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null or _regidrago_primary_missing_count(drago) <= 1:
		return false
	for card: CardInstance in _discard_cards_from_action(action):
		var name := _card_name(card)
		if name == ENERGY_SWITCH and _has_movable_ogerpon_energy_for_regidrago(player):
			return true
		if card != null and card.card_data != null and card.card_data.is_energy() and _regidrago_needs_type(drago, _energy_type(card)):
			return true
	return false


func _ultra_ball_discards_v17_fuel_and_searches_vstar(action: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	var discarded_fuel := false
	for card: CardInstance in _discard_cards_from_action(action):
		if _is_v17_dragon_fuel(card):
			discarded_fuel = true
			break
	if not discarded_fuel:
		return false
	for card: CardInstance in _search_cards_from_action(action):
		if _card_name(card) == REGIDRAGO_VSTAR:
			return true
	return false


func _launch_energy_bridge_is_open(player: PlayerState) -> bool:
	if player == null:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null:
		return false
	if _regidrago_primary_missing_count(drago) <= 1:
		return false
	for missing_type: String in _regidrago_missing_types(drago):
		if _count_energy_in_hand(player, missing_type) > 0:
			return true
	return _has_movable_ogerpon_energy_for_regidrago(player)


func _launch_route_should_preserve_hand(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) <= 0:
		return false
	if _count_named_in_hand(player, REGIDRAGO_VSTAR) > 0:
		return true
	if _count_named_in_hand(player, ULTRA_BALL) > 0 and _has_v17_dragon_fuel_in_hand(player):
		return true
	if _count_named_in_hand(player, ENERGY_SWITCH) > 0 and _has_movable_ogerpon_energy_for_regidrago(player):
		return true
	return false


func _can_finish_regidrago_attack_without_star_legacy(player: PlayerState, game_state: GameState) -> bool:
	if player == null:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null or _slot_name(drago) != REGIDRAGO_VSTAR:
		return false
	var missing := _regidrago_missing_types(drago)
	if missing.is_empty():
		return true
	if missing.size() == 1:
		if game_state == null or not game_state.energy_attached_this_turn:
			if _count_energy_in_hand(player, missing[0]) > 0:
				return true
		if missing[0] == "G" and _has_movable_ogerpon_energy_for_regidrago(player):
			return true
	return false


func _has_v17_dragon_fuel_in_hand(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _is_v17_dragon_fuel(card):
			return true
	return false


func _has_movable_ogerpon_energy_for_regidrago(player: PlayerState) -> bool:
	if player == null:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == drago or _slot_name(slot) != TEAL_MASK_OGERPON_EX:
			continue
		for energy: CardInstance in slot.attached_energy:
			if _regidrago_needs_type(drago, _energy_type(energy)) and _can_spare_ogerpon_energy_for_regidrago(player, slot, energy):
				return true
	return false


func _energy_switch_strands_active_ogerpon_buffer(action: Dictionary, player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name(player.active_pokemon) != TEAL_MASK_OGERPON_EX:
		return false
	var drago := _best_regidrago_slot(player)
	if drago == null or _regidrago_primary_missing_count(drago) <= 0:
		return false
	var explicit_source_seen := false
	var targets: Variant = action.get("targets", [])
	if targets is Array:
		for entry: Variant in targets:
			if not (entry is Dictionary):
				continue
			for value: Variant in (entry as Dictionary).values():
				if not (value is Array):
					continue
				for assignment: Variant in value:
					if not (assignment is Dictionary):
						continue
					var source_card: CardInstance = (assignment as Dictionary).get("source", null)
					var target_slot: PokemonSlot = (assignment as Dictionary).get("target", null)
					if source_card == null:
						continue
					var source_slot := _find_slot_with_attached_card(player, source_card)
					if source_slot != player.active_pokemon:
						continue
					explicit_source_seen = true
					if target_slot == drago and _regidrago_needs_type(drago, _energy_type(source_card)):
						return not _can_spare_ogerpon_energy_for_regidrago(player, source_slot, source_card)
	if explicit_source_seen:
		return false
	return not _has_movable_ogerpon_energy_for_regidrago(player)


func _can_spare_ogerpon_energy_for_regidrago(player: PlayerState, source_slot: PokemonSlot, source_energy: CardInstance) -> bool:
	if player == null or source_slot == null or source_energy == null:
		return false
	if _slot_name(source_slot) != TEAL_MASK_OGERPON_EX:
		return false
	if source_slot != player.active_pokemon:
		return true
	var cd := source_slot.get_card_data()
	var retreat_cost := maxi(0, int(cd.retreat_cost) if cd != null else 1)
	return source_slot.attached_energy.size() - 1 >= retreat_cost


func _regidrago_missing_types(slot: PokemonSlot) -> Array[String]:
	var missing: Array[String] = []
	if slot == null or not (_slot_name(slot) in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
		return missing
	var need_g := 2
	var need_r := 1
	for energy: CardInstance in slot.attached_energy:
		var provides := _energy_type(energy)
		if provides == "G" and need_g > 0:
			need_g -= 1
		elif provides == "R" and need_r > 0:
			need_r -= 1
	for i: int in need_g:
		missing.append("G")
	for i: int in need_r:
		missing.append("R")
	return missing


func _regidrago_would_miss_type_after_removal(slot: PokemonSlot, removed_energy: CardInstance) -> bool:
	if slot == null or removed_energy == null or not (_slot_name(slot) in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
		return false
	var need_g := 2
	var need_r := 1
	for energy: CardInstance in slot.attached_energy:
		if energy == removed_energy:
			continue
		var provides := _energy_type(energy)
		if provides == "G" and need_g > 0:
			need_g -= 1
		elif provides == "R" and need_r > 0:
			need_r -= 1
	var removed_type := _energy_type(removed_energy)
	return (removed_type == "G" and need_g > 0) or (removed_type == "R" and need_r > 0)


func _regidrago_primary_missing_count(slot: PokemonSlot) -> int:
	return _regidrago_missing_types(slot).size()


func _manual_attach_sets_up_ogerpon_switch_apex(target: PokemonSlot, energy_type: String, player: PlayerState) -> bool:
	if target == null or player == null or not (_slot_name(target) in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
		return false
	var missing := _regidrago_missing_types(target)
	if energy_type not in missing:
		return false
	missing.erase(energy_type)
	if missing.is_empty():
		return true
	return missing.size() == 1 and missing[0] == "G" and _has_movable_ogerpon_energy_for_regidrago(player)


func _discard_cards_from_action(action: Dictionary) -> Array[CardInstance]:
	return _cards_from_action_targets(action, ["discard"])


func _search_cards_from_action(action: Dictionary) -> Array[CardInstance]:
	return _cards_from_action_targets(action, ["search"])


func _cards_from_action_targets(action: Dictionary, key_fragments: Array[String]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var targets: Variant = action.get("targets", [])
	if not (targets is Array):
		return result
	for entry: Variant in targets:
		if not (entry is Dictionary):
			continue
		for key: Variant in (entry as Dictionary).keys():
			var key_text := str(key).to_lower()
			var matches := false
			for fragment: String in key_fragments:
				if key_text.contains(fragment):
					matches = true
					break
			if not matches:
				continue
			var value: Variant = (entry as Dictionary).get(key)
			if value is Array:
				for nested: Variant in value:
					if nested is CardInstance:
						result.append(nested as CardInstance)
			elif value is CardInstance:
				result.append(value as CardInstance)
	return result


func _energy_search_score(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return 0.0
	var player := _player(game_state, player_index)
	var drago := _best_regidrago_slot(player)
	var energy_type := _energy_type(card)
	if drago != null and _regidrago_needs_type(drago, energy_type):
		return 420.0 if energy_type == "R" else 360.0 if energy_type == "G" else 120.0
	if energy_type == "R":
		return 180.0
	if energy_type == "G":
		return 150.0
	return 40.0


func _energy_switch_source_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return 0.0
	var player := _player(context.get("game_state", null), int(context.get("player_index", -1)))
	var source_slot := _find_slot_with_attached_card(player, card)
	if source_slot == null:
		return 80.0
	var drago := _best_regidrago_slot(player)
	var energy_type := _energy_type(card)
	if source_slot == player.active_pokemon and _slot_name(source_slot) == TEAL_MASK_OGERPON_EX and not _can_spare_ogerpon_energy_for_regidrago(player, source_slot, card):
		return -360.0
	if source_slot == drago or _slot_name(source_slot) in [REGIDRAGO_V, REGIDRAGO_VSTAR]:
		return -420.0 if _regidrago_needs_type(source_slot, energy_type) else -120.0
	if drago != null and _regidrago_needs_type(drago, energy_type):
		return 620.0 if _slot_name(source_slot) == TEAL_MASK_OGERPON_EX else 420.0
	return 20.0


func _energy_assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if not _is_live_slot(slot):
		return -900.0
	var source_card: CardInstance = context.get("source_card", null)
	var source_type := _energy_type(source_card)
	var slot_name := _slot_name(slot)
	var player := _player(context.get("game_state", null), int(context.get("player_index", -1)))
	if slot_name in [REGIDRAGO_V, REGIDRAGO_VSTAR]:
		if _regidrago_needs_type_after_pending(slot, source_type, context):
			return 760.0 if source_type == "R" else 700.0 if source_type == "G" else 360.0
		if _attack_energy_gap_with_pending(slot, context) > 0:
			return 420.0
		return 70.0
	if slot_name == TEAL_MASK_OGERPON_EX:
		if source_type == "G":
			var drago := _best_regidrago_slot(player)
			if drago != null and _attack_energy_gap_with_pending(drago, context) > 0:
				return 180.0
			return 320.0
		return 80.0
	if slot_name == RADIANT_CHARIZARD and source_type == "R":
		return 160.0
	return 40.0


func _handoff_target_score(slot: PokemonSlot, context: Dictionary = {}, step_id: String = "") -> float:
	if slot == null:
		return 0.0
	var name := _slot_name(slot)
	if _is_charizard_send_out_context(context, step_id):
		return _charizard_pressure_handoff_score(slot, context)
	if name == REGIDRAGO_VSTAR:
		return 620.0 if _attack_energy_gap(slot) <= 0 else 360.0
	if name == REGIDRAGO_V:
		return 180.0
	if name == TEAL_MASK_OGERPON_EX:
		return 140.0
	return 40.0


func _is_charizard_send_out_context(context: Dictionary, step_id: String) -> bool:
	if step_id != "send_out":
		return false
	return _opponent_has_charizard_pressure(context.get("game_state", null), int(context.get("player_index", -1)))


func _charizard_pressure_handoff_score(slot: PokemonSlot, context: Dictionary) -> float:
	if not _is_live_slot(slot):
		return -900.0
	var player := _player(context.get("game_state", null), int(context.get("player_index", -1)))
	var name := _slot_name(slot)
	var energy_gap := _attack_energy_gap(slot)
	var attached_count := slot.attached_energy.size()
	if name == REGIDRAGO_VSTAR:
		if energy_gap <= 0 and _dragon_fuel_count(player) > 0:
			return 880.0
		return 70.0 if _charizard_context_has_buffer_candidate(context, slot) else 260.0
	if name == REGIDRAGO_V:
		if energy_gap <= 0 and _best_attack_damage(slot) > 0:
			return 430.0
		return 35.0 if _charizard_context_has_buffer_candidate(context, slot) else 160.0
	if name == TEAL_MASK_OGERPON_EX:
		if energy_gap <= 0 and _best_attack_damage(slot) > 0:
			return 760.0
		if attached_count > 0:
			return 540.0
		return 260.0
	if name == RADIANT_CHARIZARD:
		if energy_gap <= 0 and _best_attack_damage(slot) > 0:
			return 680.0
		if attached_count > 0:
			return 520.0
		return 360.0
	if name in [CLEFFA, MEW_EX, FEZANDIPITI_EX]:
		return 180.0
	return 90.0


func _charizard_pressure_retreat_is_liability(
	active: PokemonSlot,
	target: PokemonSlot,
	player: PlayerState,
	game_state: GameState = null,
	player_index: int = -1
) -> bool:
	if not _is_live_slot(active) or not _is_live_slot(target):
		return false
	if _charizard_pressure_retreat_target_is_ready_attacker(target, player):
		return not _charizard_pressure_ready_attacker_handoff_is_safe(target, player, game_state, player_index)
	var target_name := _slot_name(target)
	if target_name in [MEW_EX, FEZANDIPITI_EX, SQUAWKABILLY_EX]:
		return true
	if target_name in [REGIDRAGO_V, REGIDRAGO_VSTAR]:
		return true
	var active_name := _slot_name(active)
	if active_name in [REGIDRAGO_V, REGIDRAGO_VSTAR] and active.attached_energy.size() > 0:
		return true
	if active_name == TEAL_MASK_OGERPON_EX and active.attached_energy.size() > 0:
		return true
	return false


func _late_support_pivot_liability(
	active: PokemonSlot,
	target: PokemonSlot,
	player: PlayerState,
	game_state: GameState
) -> bool:
	if not _is_live_slot(active) or not _is_live_slot(target) or player == null or game_state == null:
		return false
	if game_state.turn_number <= 2:
		return false
	if _count_named_on_field(player, REGIDRAGO_V) + _count_named_on_field(player, REGIDRAGO_VSTAR) <= 0:
		return false
	if _slot_name(target) not in [MEW_EX, FEZANDIPITI_EX, SQUAWKABILLY_EX]:
		return false
	var active_name := _slot_name(active)
	if active_name in [REGIDRAGO_V, REGIDRAGO_VSTAR, TEAL_MASK_OGERPON_EX] and active.attached_energy.size() > 0:
		return true
	return false


func _charizard_pressure_ready_attacker_handoff_is_safe(
	target: PokemonSlot,
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> bool:
	if not _is_live_slot(target):
		return false
	if player != null and not player.prizes.is_empty() and player.prizes.size() <= 2:
		return true
	if _slot_name(target) != REGIDRAGO_VSTAR:
		return true
	if _charizard_pressure_slot_survives_return(target, game_state, player_index, 0):
		return true
	return _discard_has_hisuian_goodra(player) and _charizard_pressure_slot_survives_return(target, game_state, player_index, 80)


func _charizard_pressure_slot_survives_return(
	slot: PokemonSlot,
	game_state: GameState,
	player_index: int,
	damage_reduction: int
) -> bool:
	if not _is_live_slot(slot) or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var prizes_taken := 0 if player.prizes.is_empty() else maxi(0, 6 - player.prizes.size())
	var expected_damage := maxi(0, 180 + prizes_taken * 30 - damage_reduction)
	return slot.get_remaining_hp() > expected_damage


func _discard_has_hisuian_goodra(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if _card_name(card) == HISUIAN_GOODRA_VSTAR:
			return true
	return false


func _charizard_pressure_retreat_target_is_ready_attacker(target: PokemonSlot, player: PlayerState) -> bool:
	if not _is_live_slot(target):
		return false
	var name := _slot_name(target)
	if name == REGIDRAGO_VSTAR:
		return _attack_energy_gap(target) <= 0 and _dragon_fuel_count(player) > 0
	if name == REGIDRAGO_V:
		return _attack_energy_gap(target) <= 0 and _best_attack_damage(target) > 0
	if name in [TEAL_MASK_OGERPON_EX, RADIANT_CHARIZARD]:
		return _attack_energy_gap(target) <= 0 and _best_attack_damage(target) > 0
	return false


func _charizard_context_has_buffer_candidate(context: Dictionary, excluded_slot: PokemonSlot) -> bool:
	var items: Variant = context.get("all_items", [])
	if not (items is Array):
		return false
	for item: Variant in items:
		if not (item is PokemonSlot):
			continue
		var slot := item as PokemonSlot
		if slot == excluded_slot or not _is_live_slot(slot):
			continue
		var name := _slot_name(slot)
		if name == TEAL_MASK_OGERPON_EX and slot.attached_energy.size() > 0:
			return true
		if name == RADIANT_CHARIZARD:
			return true
		if name == REGIDRAGO_VSTAR and _attack_energy_gap(slot) <= 0:
			return true
	return false


func _best_ready_regidrago(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name(slot) == REGIDRAGO_VSTAR and _attack_energy_gap(slot) <= 0:
			return slot
	return null


func _regidrago_needs_type(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null or not (_slot_name(slot) in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
		return false
	var need_g := 2
	var need_r := 1
	for energy: CardInstance in slot.attached_energy:
		var provides := _energy_type(energy)
		if provides == "G" and need_g > 0:
			need_g -= 1
		elif provides == "R" and need_r > 0:
			need_r -= 1
	return (energy_type == "G" and need_g > 0) or (energy_type == "R" and need_r > 0)


func _regidrago_needs_type_after_pending(slot: PokemonSlot, energy_type: String, context: Dictionary) -> bool:
	if slot == null or not (_slot_name(slot) in [REGIDRAGO_V, REGIDRAGO_VSTAR]):
		return false
	var need_g := 2
	var need_r := 1
	for energy: CardInstance in slot.attached_energy:
		var provides := _energy_type(energy)
		if provides == "G" and need_g > 0:
			need_g -= 1
		elif provides == "R" and need_r > 0:
			need_r -= 1
	var pending: Variant = context.get("pending_assignments", [])
	if pending is Array:
		for entry: Variant in pending:
			if not (entry is Dictionary):
				continue
			var pending_target: Variant = (entry as Dictionary).get("target", null)
			if pending_target != slot:
				continue
			var pending_type := _energy_type((entry as Dictionary).get("source", null))
			if pending_type == "G" and need_g > 0:
				need_g -= 1
			elif pending_type == "R" and need_r > 0:
				need_r -= 1
	return (energy_type == "G" and need_g > 0) or (energy_type == "R" and need_r > 0)


func _attack_energy_gap_with_pending(slot: PokemonSlot, context: Dictionary) -> int:
	return maxi(0, _attack_energy_gap(slot) - _pending_assignment_count_for_slot(slot, context))


func _pending_assignment_count_for_slot(slot: PokemonSlot, context: Dictionary) -> int:
	if slot == null:
		return 0
	var counts: Variant = context.get("pending_assignment_counts", {})
	if not (counts is Dictionary):
		return 0
	var slot_id := str(slot.get_instance_id())
	for key: Variant in (counts as Dictionary).keys():
		if str(key) == slot_id:
			return int((counts as Dictionary).get(key, 0))
	return 0


func _is_energy_assignment_step(step_id: String) -> bool:
	return step_id == "energy_assignment" or step_id.contains("energy_assignment") or step_id == "csv9c_hand_energy_assignments" or step_id.contains("hand_energy") or step_id.contains("hand_basic_energy")


func _is_live_slot(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_top_card() != null and slot.get_remaining_hp() > 0


func _find_slot_with_attached_card(player: PlayerState, card: CardInstance) -> PokemonSlot:
	if player == null or card == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if card in slot.attached_energy:
			return slot
	return null


func _energy_type(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if str(card.card_data.energy_provides) != "":
		return str(card.card_data.energy_provides)
	return str(card.card_data.energy_type)


func _player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _opponent_has_charizard_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		if _slot_is_charizard_pressure(slot):
			return true
	return false


func _slot_is_charizard_pressure(slot: PokemonSlot) -> bool:
	return _slot_matches_name_predicate(slot, Callable(self, "_is_charizard_pressure_name"))


func _slot_is_charizard_attacker(slot: PokemonSlot) -> bool:
	return _slot_matches_name_predicate(slot, Callable(self, "_is_charizard_attacker_name"))


func _slot_matches_name_predicate(slot: PokemonSlot, predicate: Callable) -> bool:
	if not _is_live_slot(slot):
		return false
	var names: Array[String] = [_slot_name(slot)]
	var data := slot.get_card_data()
	if data != null:
		names.append(str(data.name))
		names.append(str(data.name_en))
	for raw_name: String in names:
		if predicate.call(raw_name):
			return true
	return false


func _is_charizard_pressure_name(name: String) -> bool:
	if _is_charizard_attacker_name(name):
		return true
	var compact := name.to_lower().replace(" ", "")
	return compact.contains("charmander") \
		or compact.contains("charmeleon") \
		or name.contains("小火龙") \
		or name.contains("火恐龙")


func _is_charizard_attacker_name(name: String) -> bool:
	var compact := name.to_lower().replace(" ", "")
	return compact.contains("charizard") \
		or name.contains("喷火龙")


func _is_v17_dragon_fuel(card: Variant) -> bool:
	return _card_name(card) in V17_DRAGON_FUEL_NAMES


func _is_celestial_roar_action(action: Dictionary, player: PlayerState = null) -> bool:
	var attack_name := str(action.get("attack_name", action.get("attack", "")))
	if attack_name in ["Celestial Roar", "天之呐喊"]:
		return true
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	return int(action.get("attack_index", -1)) == 0 and source != null and _slot_name(source) == REGIDRAGO_V


func _is_basic_dragon_laser_action(action: Dictionary, player: PlayerState = null) -> bool:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	if source == null or _slot_name(source) != REGIDRAGO_V:
		return false
	if int(action.get("attack_index", -1)) == 1:
		return true
	var attack_name := str(action.get("attack_name", action.get("attack", "")))
	return attack_name in ["Dragon Laser", "巨龙镭射", "宸ㄩ緳闀皠"]


func _should_defer_basic_dragon_laser_for_vstar(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState = null,
	player_index: int = -1
) -> bool:
	if player == null:
		return false
	if bool(action.get("projected_knockout", false)) and not player.prizes.is_empty() and player.prizes.size() <= 1:
		return false
	if not _is_basic_dragon_laser_action(action, player):
		return false
	if _count_named_in_hand(player, REGIDRAGO_VSTAR) <= 0:
		return false
	if _dragon_fuel_count(player) > 0:
		return true
	return _opponent_has_charizard_pressure(game_state, player_index)


func _is_apex_dragon_action(action: Dictionary, player: PlayerState = null) -> bool:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	return int(action.get("attack_index", -1)) == 0 and source != null and _slot_name(source) == REGIDRAGO_VSTAR


func _is_thin_deck_churn(action: Dictionary, player: PlayerState) -> bool:
	if player == null:
		return false
	var kind := str(action.get("kind", ""))
	if kind == "use_ability":
		var source: PokemonSlot = action.get("source_slot", null)
		var source_name := _slot_name(source)
		if source_name in [TEAL_MASK_OGERPON_EX, MEW_EX, CLEFFA, SQUAWKABILLY_EX, FEZANDIPITI_EX]:
			return player.deck.size() <= 12
	if kind == "play_trainer":
		var trainer_name := _card_name(action.get("card", null))
		if trainer_name in [PROFESSORS_RESEARCH, IONO]:
			return player.deck.size() <= 18
	return false


func _action_targets_only_v17_dragon_fuel(action: Dictionary) -> bool:
	var targets: Variant = action.get("targets", [])
	if not (targets is Array) or (targets as Array).is_empty():
		return false
	var saw_card := false
	for entry: Variant in targets:
		if entry is Dictionary:
			for value: Variant in (entry as Dictionary).values():
				if value is Array:
					for nested: Variant in value:
						if nested is CardInstance:
							saw_card = true
							if not _is_v17_dragon_fuel(nested):
								return false
				elif value is CardInstance:
					saw_card = true
					if not _is_v17_dragon_fuel(value):
						return false
		elif entry is CardInstance:
			saw_card = true
			if not _is_v17_dragon_fuel(entry):
				return false
	return saw_card


func _action_recovers_only_v17_dragon_fuel(action: Dictionary) -> bool:
	var targets: Variant = action.get("targets", [])
	if not (targets is Array) or (targets as Array).is_empty():
		return false
	var saw_card := false
	for entry: Variant in targets:
		if entry is Dictionary:
			for value: Variant in (entry as Dictionary).values():
				if value is Array:
					for nested: Variant in value:
						if nested is CardInstance:
							saw_card = true
							if not _is_v17_dragon_fuel(nested):
								return false
				elif value is CardInstance:
					saw_card = true
					if not _is_v17_dragon_fuel(value):
						return false
		elif entry is CardInstance:
			saw_card = true
			if not _is_v17_dragon_fuel(entry):
				return false
	return saw_card


func _card_name(card: Variant) -> String:
	if card is CardInstance:
		var inst := card as CardInstance
		if inst.card_data != null:
			if str(inst.card_data.set_code) == "CSV9C" and str(inst.card_data.card_index) == "144":
				return ALOLAN_EXEGGUTOR_EX
			if str(inst.card_data.set_code) == "CSV9C" and str(inst.card_data.card_index) == "147":
				return KYUREM
	var name := super._card_name(card)
	if name == "Alolan Exeggutor ex":
		return ALOLAN_EXEGGUTOR_EX
	if name == "Kyurem":
		return KYUREM
	return name
