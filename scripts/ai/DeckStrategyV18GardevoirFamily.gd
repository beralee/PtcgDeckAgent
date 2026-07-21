class_name DeckStrategyV18GardevoirFamily
extends "res://scripts/ai/DeckStrategyGardevoir.gd"


const DECK_NO_TM := 800017097
const DECK_RABSCA := 800018105
const DECK_STANDARD := 800018497
const DECK_ACADEMY := 800018498

const VARIANT_NO_TM := "no_tm_gardevoir"
const VARIANT_RABSCA := "rabsca_gardevoir"
const VARIANT_STANDARD := "gardevoir"
const VARIANT_ACADEMY := "academy_gardevoir"
const VARIANT_UNKNOWN := "gardevoir_family"

const RELLOR_NAMES: Array[String] = ["虫滚泥", "Rellor"]
const RABSCA_NAMES: Array[String] = ["虫甲圣", "Rabsca"]
const SHAYMIN_NAMES: Array[String] = ["谢米", "Shaymin"]
const BUDEW_NAMES: Array[String] = ["含羞苞", "Budew"]
const CLEFFA_NAMES: Array[String] = ["皮宝宝", "Cleffa"]
const MEW_EX_NAMES: Array[String] = ["梦幻ex", "Mew ex"]
const FEZANDIPITI_EX_NAMES: Array[String] = ["吉雉鸡ex", "Fezandipiti ex"]
const CLEFAIRY_EX_NAMES: Array[String] = ["莉莉艾的皮皮ex", "Lillie's Clefairy ex"]
const TM_EVOLUTION_NAMES: Array[String] = ["招式学习器 进化", "Technical Machine: Evolution"]

const FAMILY_ATTACKER_NAMES: Array[String] = [
	"飘飘球", "Drifloon",
	"吼叫尾", "Scream Tail",
	"莉莉艾的皮皮ex", "Lillie's Clefairy ex",
]

var _family_deck_id: int = 0
var _family_variant: String = VARIANT_UNKNOWN
var _family_has_tm_evolution: bool = false
var _family_has_rabsca: bool = false
var _family_has_shaymin: bool = false


func get_strategy_id() -> String:
	return "v18_gardevoir_family"


func get_family_variant_id() -> String:
	return _family_variant


func configure_from_deck(deck: DeckData) -> void:
	super.configure_from_deck(deck)
	_family_deck_id = int(deck.id) if deck != null else 0
	_family_variant = _variant_for_deck_id(_family_deck_id)
	_family_has_tm_evolution = false
	_family_has_rabsca = false
	_family_has_shaymin = false
	if deck == null:
		return
	for entry_variant: Variant in deck.cards:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		_family_has_tm_evolution = _family_has_tm_evolution or _deck_entry_matches_any(entry, TM_EVOLUTION_NAMES)
		_family_has_rabsca = _family_has_rabsca or _deck_entry_matches_any(entry, RABSCA_NAMES)
		_family_has_shaymin = _family_has_shaymin or _deck_entry_matches_any(entry, SHAYMIN_NAMES)


func predict_attacker_damage(slot: PokemonSlot, extra_embrace_count: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return super.predict_attacker_damage(slot, extra_embrace_count)
	if _matches_family(slot, CLEFAIRY_EX_NAMES):
		return {
			"damage": 20,
			"can_attack": _family_attack_cost_is_met(slot, "PC", extra_embrace_count),
			"description": "full_moon_rondo_minimum",
		}
	if _matches_family(slot, [GARDEVOIR_EX, "Gardevoir ex"]):
		return {
			"damage": 190,
			"can_attack": _family_attack_cost_is_met(slot, "PPC", extra_embrace_count),
			"description": "gardevoir_emergency_route",
		}
	return super.predict_attacker_damage(slot, extra_embrace_count)


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var basics: Array[Dictionary] = []
	for index: int in player.hand.size():
		var card: CardInstance = player.hand[index]
		var data := _family_card_data(card)
		if data == null or not data.is_pokemon() or str(data.stage) != "Basic":
			continue
		basics.append({"index": index, "card": card})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}

	var active_index := _first_opening_index(basics, [
		BUDEW_NAMES,
		CLEFFA_NAMES,
		MEW_EX_NAMES,
		[MUNKIDORI, "Munkidori"],
		CLEFAIRY_EX_NAMES,
		SHAYMIN_NAMES,
		RELLOR_NAMES,
		[SCREAM_TAIL, "Scream Tail"],
		[DRIFLOON, "Drifloon"],
		FEZANDIPITI_EX_NAMES,
	])
	if active_index < 0:
		active_index = int(basics[0].get("index", -1))

	var bench_indices: Array[int] = []
	_append_opening_bench_matches(bench_indices, basics, active_index, [[RALTS, "Ralts"]], 2)
	if _family_variant == VARIANT_RABSCA or _family_has_rabsca:
		_append_opening_bench_matches(bench_indices, basics, active_index, [RELLOR_NAMES], 1)
	var attacker_order: Array[Array] = []
	if _family_variant in [VARIANT_NO_TM, VARIANT_RABSCA, VARIANT_ACADEMY]:
		attacker_order.append([DRIFLOON, "Drifloon"])
	attacker_order.append([SCREAM_TAIL, "Scream Tail"])
	attacker_order.append(CLEFAIRY_EX_NAMES)
	_append_opening_bench_matches(bench_indices, basics, active_index, attacker_order, 1)
	if _family_variant == VARIANT_ACADEMY or _family_has_shaymin:
		_append_opening_bench_matches(bench_indices, basics, active_index, [SHAYMIN_NAMES], 1)
	_append_opening_bench_matches(bench_indices, basics, active_index, [[MUNKIDORI, "Munkidori"]], 1)

	var bench_limit := 3
	if bench_indices.size() < bench_limit:
		for entry: Dictionary in basics:
			var index := int(entry.get("index", -1))
			if index == active_index or index in bench_indices:
				continue
			bench_indices.append(index)
			if bench_indices.size() >= bench_limit:
				break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var plan := super.build_turn_plan(game_state, player_index, context)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return plan
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return plan

	var gardevoir_count := _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"])
	var kirlia_count := _family_count_on_field(player, [KIRLIA, "Kirlia"])
	var discard_psychic := _count_psychic_energy_in_discard(game_state, player_index)
	var best_attacker := _best_family_attacker(player)
	var fallback_gardevoir: PokemonSlot = null
	if best_attacker == null:
		fallback_gardevoir = _best_gardevoir_fallback(player)
	var fallback_route_live := best_attacker == null \
		and _gardevoir_emergency_route_live(game_state, player, player_index, fallback_gardevoir)
	var route_attacker: PokemonSlot = best_attacker
	if route_attacker == null and fallback_route_live:
		route_attacker = fallback_gardevoir
	var attack_route_live := _family_attacker_ready(best_attacker) \
		or (fallback_route_live and _gardevoir_fallback_ready(fallback_gardevoir))
	var thin_deck_guard := player.deck.size() <= 8 and gardevoir_count > 0 and attack_route_live
	var rabsca_debt := (_family_variant == VARIANT_RABSCA or _family_has_rabsca) \
		and _family_count_on_field(player, RABSCA_NAMES) == 0 \
		and _family_count_on_field(player, RELLOR_NAMES) > 0
	var shaymin_debt := (_family_variant == VARIANT_ACADEMY or _family_has_shaymin) \
		and _opponent_has_bench_damage_pressure(game_state, player_index) \
		and _family_count_on_field(player, SHAYMIN_NAMES) == 0

	var phase := "setup"
	if gardevoir_count > 0 and best_attacker == null and not fallback_route_live:
		phase = "rebuild"
	elif gardevoir_count > 0 and not attack_route_live:
		phase = "launch"
	elif gardevoir_count > 0 and player.prizes.size() <= 2:
		phase = "close"
	elif gardevoir_count > 0:
		phase = "convert"

	var intent := "establish_refinement_shell"
	if gardevoir_count == 0 and _family_has_tm_evolution and _tm_evolution_debt_count(player) >= 2:
		intent = "establish_dual_evolution_lane"
	elif gardevoir_count == 0 and kirlia_count > 0:
		intent = "refine_into_first_gardevoir"
	elif gardevoir_count > 0 and best_attacker == null and fallback_route_live:
		intent = "convert_gardevoir_fallback" if _gardevoir_fallback_ready(fallback_gardevoir) else "embrace_gardevoir_fallback"
	elif gardevoir_count > 0 and best_attacker == null:
		intent = "rebuild_one_prize_attacker"
	elif gardevoir_count > 0 and not attack_route_live:
		intent = "embrace_attack_route" if discard_psychic > 0 else "refine_psychic_fuel"
	elif thin_deck_guard:
		intent = "close_without_churn"
	elif attack_route_live:
		intent = "convert_psychic_damage"

	var attacker_name := _family_slot_name(route_attacker)
	var bridge_name := attacker_name
	if gardevoir_count == 0:
		bridge_name = GARDEVOIR_EX if kirlia_count > 0 else KIRLIA if _family_count_on_field(player, [RALTS, "Ralts"]) > 0 else RALTS
	elif best_attacker == null:
		bridge_name = _preferred_family_attacker_name()
	var owner_name := attacker_name if attacker_name != "" else bridge_name
	var pivot_name := attacker_name if attacker_name != "" else _family_slot_name(player.active_pokemon)

	plan["id"] = "v18_gardevoir_family:%s:%s" % [_family_variant, intent]
	plan["intent"] = intent
	plan["phase"] = phase
	plan["owner"] = {
		"turn_owner_name": owner_name,
		"bridge_target_name": bridge_name,
		"pivot_target_name": pivot_name,
	}
	plan["targets"] = {
		"primary_attacker_name": attacker_name,
		"bridge_target_name": bridge_name,
		"pivot_target_name": pivot_name,
	}
	plan["priorities"] = {
		"attach": _family_attach_priorities(attacker_name),
		"handoff": _family_handoff_priorities(attacker_name),
		"search": _family_search_priorities(),
		"evolve": _family_evolution_priorities(),
		"ability": [KIRLIA, GARDEVOIR_EX, MUNKIDORI],
		"trainer": [ULTRA_BALL, EARTHEN_VESSEL, RARE_CANDY, TM_EVOLUTION, NIGHT_STRETCHER],
	}
	var flags: Dictionary = plan.get("flags", {}) if plan.get("flags", {}) is Dictionary else {}
	flags.merge({
		"family_variant": _family_variant,
		"kirlia_filter_live": kirlia_count > 0 and discard_psychic < _psychic_fuel_target(player),
		"psychic_discard_fuel": discard_psychic,
		"attack_route_live": attack_route_live,
		"rabsca_lane_debt": rabsca_debt,
		"academy_guard_debt": shaymin_debt,
		"thin_deck_churn_guard": thin_deck_guard,
	}, true)
	plan["flags"] = flags
	var constraints: Dictionary = plan.get("constraints", {}) if plan.get("constraints", {}) is Dictionary else {}
	constraints["forbid_engine_churn"] = bool(constraints.get("forbid_engine_churn", false)) or thin_deck_guard
	constraints["forbid_extra_bench_padding"] = bool(constraints.get("forbid_extra_bench_padding", false)) \
		or (attack_route_live and not rabsca_debt and not shaymin_debt)
	plan["constraints"] = constraints
	return plan


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	var continuity := super.build_continuity_contract(game_state, player_index, turn_contract)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return continuity
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return continuity
	var gardevoir_count := _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"])
	var kirlia_count := _family_count_on_field(player, [KIRLIA, "Kirlia"])
	var discard_psychic := _count_psychic_energy_in_discard(game_state, player_index)
	var ready_attacker := _has_ready_family_attacker(player)
	var fallback_gardevoir: PokemonSlot = null
	if not ready_attacker:
		fallback_gardevoir = _best_gardevoir_fallback(player)
	var fallback_gardevoir_ready := _gardevoir_emergency_route_live(
		game_state,
		player,
		player_index,
		fallback_gardevoir
	) and _gardevoir_fallback_ready(fallback_gardevoir)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	setup_debt.merge({
		"need_first_gardevoir": gardevoir_count == 0,
		"need_refinement_lane": kirlia_count == 0 and gardevoir_count == 0,
		"need_psychic_fuel": discard_psychic < _psychic_fuel_target(player),
		"need_rabsca_guard": (_family_variant == VARIANT_RABSCA or _family_has_rabsca) and _family_count_on_field(player, RABSCA_NAMES) == 0,
		"need_academy_guard": (_family_variant == VARIANT_ACADEMY or _family_has_shaymin) and _opponent_has_bench_damage_pressure(game_state, player_index) and _family_count_on_field(player, SHAYMIN_NAMES) == 0,
	}, true)
	continuity["setup_debt"] = setup_debt
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	if gardevoir_count == 0:
		bonuses.append({"kind": "evolve", "card_names": [GARDEVOIR_EX, "Gardevoir ex"], "bonus": 1500.0, "reason": "first_psychic_embrace_engine"})
		bonuses.append({"kind": "evolve", "card_names": [KIRLIA, "Kirlia"], "bonus": 900.0, "reason": "refinement_bridge"})
	if kirlia_count > 0 and discard_psychic < _psychic_fuel_target(player) and player.deck.size() > 8:
		bonuses.append({"kind": "use_ability", "target_names": [KIRLIA, "Kirlia"], "bonus": 650.0, "reason": "refinement_psychic_fuel"})
	if _family_variant == VARIANT_RABSCA or _family_has_rabsca:
		bonuses.append({"kind": "evolve", "card_names": RABSCA_NAMES, "bonus": 650.0, "reason": "rabsca_bench_guard"})
	if _family_variant == VARIANT_ACADEMY or _family_has_shaymin:
		bonuses.append({"kind": "play_basic_to_bench", "card_names": SHAYMIN_NAMES, "bonus": 420.0, "reason": "academy_bench_guard"})
	continuity["action_bonuses"] = bonuses
	continuity["enabled"] = bool(continuity.get("enabled", false)) or not bonuses.is_empty()
	if not ready_attacker and (gardevoir_count == 0 or discard_psychic < 2):
		continuity["safe_setup_before_attack"] = true
		continuity["attack_penalty"] = maxf(float(continuity.get("attack_penalty", 0.0)), 420.0)
	if fallback_gardevoir_ready:
		continuity["safe_setup_before_attack"] = false
		continuity["attack_penalty"] = 0.0
	return continuity


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return score
	var kind := str(action.get("kind", ""))
	match kind:
		"use_ability":
			return _score_family_ability(action, score, game_state, player, player_index)
		"attach_energy":
			return _score_family_attachment(action, score, game_state, player, player_index)
		"attach_tool":
			return _score_family_tool(action, score, game_state, player, player_index)
		"evolve":
			return _score_family_evolution(action, score, player)
		"play_basic_to_bench":
			return _score_family_bench(action, score, game_state, player, player_index)
		"granted_attack":
			if _is_tm_evolution_attack_action(action):
				var target_count := _tm_evolution_debt_count(player)
				return 1900.0 + float(target_count) * 700.0 if target_count > 0 else -1800.0
		"attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			if _is_family_attacker(source):
				score += 800.0 + float(int(action.get("projected_damage", 0))) * 1.5
				if bool(action.get("projected_knockout", false)):
					score += 900.0
				if player.deck.size() <= 8:
					score += 1000.0
			elif _matches_family(source, [GARDEVOIR_EX, "Gardevoir ex"]) \
					and _gardevoir_emergency_route_live(game_state, player, player_index, source):
				score = maxf(score + 650.0 + float(int(action.get("projected_damage", 0))), 1700.0)
				if bool(action.get("projected_knockout", false)):
					score += 900.0
			elif player.deck.size() <= 8 and _has_ready_family_attacker(player):
				score -= 900.0
	return score


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if items.is_empty():
		return []
	var step_id := str(step.get("id", "")).to_lower()
	if step_id == "embrace_target":
		var embrace_target: Variant = pick_embrace_target(
			items,
			context.get("game_state", null),
			int(context.get("player_index", -1))
		)
		return [embrace_target] if embrace_target != null and embrace_target in items else []
	var max_select := maxi(1, int(step.get("max_select", 1)))
	var min_select := maxi(0, int(step.get("min_select", 0)))
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		ranked.append({
			"item": item,
			"score": score_interaction_target(item, step, context),
			"index": index,
			"role": _interaction_role(item, step_id),
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", 0.0))
		var right_score := float(right.get("score", 0.0))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var picked: Array = []
	var role_limits := _interaction_role_limits(items, step_id, max_select)
	var used_roles := {}
	for entry: Dictionary in ranked:
		if picked.size() >= max_select:
			break
		var role := str(entry.get("role", ""))
		if role != "" and int(used_roles.get(role, 0)) >= int(role_limits.get(role, 1)):
			continue
		if float(entry.get("score", 0.0)) <= -1000.0 and picked.size() >= min_select:
			continue
		picked.append(entry.get("item"))
		if role != "":
			used_roles[role] = int(used_roles.get(role, 0)) + 1
	return picked


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = null
	if state != null and player_index >= 0 and player_index < state.players.size():
		player = state.players[player_index]
	if step_id in ["discard_card", "discard_cards", "discard_energy"] and item is CardInstance:
		return _family_discard_score(item as CardInstance, state, player, player_index)
	if step_id == "evolution_bench" and item is PokemonSlot:
		return _tm_evolution_slot_score(item as PokemonSlot, player)
	if step_id == "evolution_cards" and item is CardInstance:
		return _tm_evolution_card_score(item as CardInstance, player)
	var score := super.score_interaction_target(item, step, context)
	if step_id == "embrace_target" and item is PokemonSlot and player != null:
		var slot := item as PokemonSlot
		if slot == player.active_pokemon and _is_family_attacker(slot) and _family_attack_gap(slot) > 0:
			return maxf(score, 3200.0 - float(_family_attack_gap(slot)) * 150.0)
		if _is_family_attacker(slot) and _family_attack_gap(slot) > 0:
			return maxf(score, 2200.0 - float(_family_attack_gap(slot)) * 120.0)
		if _matches_family(slot, [GARDEVOIR_EX, "Gardevoir ex"]) and slot == player.active_pokemon and _get_retreat_energy_gap(slot) > 0 and _has_ready_family_attacker(player):
			return maxf(score, 2600.0)
		if _matches_family(slot, [GARDEVOIR_EX, "Gardevoir ex"]) \
				and slot == player.active_pokemon \
				and _gardevoir_emergency_route_live(state, player, player_index, slot) \
				and _minimum_attack_gap(slot) > 0:
			return maxf(score, 2100.0 - float(_minimum_attack_gap(slot)) * 100.0)
	if item is CardInstance:
		if _matches_family(item, RABSCA_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca):
			return maxf(score, 1500.0)
		if _matches_family(item, SHAYMIN_NAMES) and (_family_variant == VARIANT_ACADEMY or _family_has_shaymin):
			return maxf(score, 850.0)
		if _matches_family(item, CLEFAIRY_EX_NAMES):
			return maxf(score, 760.0)
	return score


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if _is_family_attacker(slot):
			var score := 1200.0 + float(slot.attached_energy.size()) * 180.0
			if _family_attacker_ready(slot):
				score += 1200.0
			return score
		if _matches_family(slot, [RALTS, "Ralts", KIRLIA, "Kirlia"]):
			return -900.0
	return super.score_handoff_target(item, step, context)


func pick_embrace_target(target_slots: Array, game_state: GameState = null, player_index: int = -1) -> Variant:
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		var active := player.active_pokemon
		if active in target_slots and _is_family_attacker(active) and _family_attack_gap(active) > 0 and _can_take_more_psychic_embrace_damage(active, game_state):
			return active
		if active in target_slots \
				and _matches_family(active, [GARDEVOIR_EX, "Gardevoir ex"]) \
				and _gardevoir_emergency_route_live(game_state, player, player_index, active) \
				and _minimum_attack_gap(active) > 0 \
				and _can_take_more_psychic_embrace_damage(active, game_state):
			return active
	return super.pick_embrace_target(target_slots, game_state, player_index)


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _is_basic_energy_symbol(card, "P"):
		return 320
	if _matches_family(card, [GARDEVOIR_EX, "Gardevoir ex", KIRLIA, "Kirlia"]):
		return 2
	if _matches_family(card, RABSCA_NAMES) or _matches_family(card, RELLOR_NAMES):
		return 4
	if _matches_family(card, SHAYMIN_NAMES):
		return 12
	return super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	return int(round(_family_discard_score(card, game_state, game_state.players[player_index], player_index)))


func get_search_priority(card: CardInstance) -> int:
	if _matches_family(card, [GARDEVOIR_EX, "Gardevoir ex"]):
		return 1500
	if _matches_family(card, [KIRLIA, "Kirlia"]):
		return 1380
	if _matches_family(card, [RALTS, "Ralts"]):
		return 1260
	if _matches_family(card, RABSCA_NAMES):
		return 1120 if _family_variant == VARIANT_RABSCA or _family_has_rabsca else 100
	if _matches_family(card, RELLOR_NAMES):
		return 1040 if _family_variant == VARIANT_RABSCA or _family_has_rabsca else 100
	if _matches_family(card, [SCREAM_TAIL, "Scream Tail"]):
		return 1020
	if _matches_family(card, [DRIFLOON, "Drifloon"]):
		return 1000
	if _matches_family(card, CLEFAIRY_EX_NAMES):
		return 820
	if _matches_family(card, SHAYMIN_NAMES):
		return 720
	return super.get_search_priority(card)


func _score_family_ability(
	action: Dictionary,
	score: float,
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if _matches_family(source, [KIRLIA, "Kirlia"]):
		if player.deck.size() <= 8 and _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"]) > 0 and _has_ready_family_attacker(player):
			return minf(score, -1800.0)
		var discard_psychic := _count_psychic_energy_in_discard(game_state, player_index)
		if discard_psychic < _psychic_fuel_target(player):
			score += 900.0
		if _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"]) == 0:
			score += 500.0
	elif _matches_family(source, MEW_EX_NAMES) or _matches_family(source, FEZANDIPITI_EX_NAMES):
		if player.deck.size() <= 8 and _has_ready_family_attacker(player):
			return minf(score, -1500.0)
	elif _matches_family(source, [GARDEVOIR_EX, "Gardevoir ex"]) \
			and _gardevoir_emergency_route_live(game_state, player, player_index, source) \
			and _minimum_attack_gap(source) > 0:
		return maxf(score, 1800.0)
	return score


func _score_family_attachment(
	action: Dictionary,
	score: float,
	game_state: GameState,
	player: PlayerState,
	_player_index: int
) -> float:
	var energy: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null:
		return score
	if _is_basic_energy_symbol(energy, "D"):
		if _matches_family(target, [MUNKIDORI, "Munkidori"]):
			return maxf(score + 1800.0, 1700.0) if not _slot_has_energy_symbol(target, "D") else score - 900.0
		var active_escape := target == player.active_pokemon \
			and _get_retreat_energy_gap(target) > 0 \
			and _has_productive_handoff_on_bench(player) \
			and not _hand_has_energy_symbol(player, "P")
		return score + 250.0 if active_escape else minf(score, -1900.0)
	if _is_basic_energy_symbol(energy, "P"):
		if target == player.active_pokemon and _get_retreat_energy_gap(target) > 0 and _has_family_attacker_on_bench(player):
			score += 1400.0
		elif _is_family_attacker(target):
			score += 850.0 - float(target.attached_energy.size()) * 100.0
		elif _matches_family(target, [RALTS, "Ralts", KIRLIA, "Kirlia", RABSCA_NAMES[0], RABSCA_NAMES[1], SHAYMIN_NAMES[0], SHAYMIN_NAMES[1]]):
			score -= 600.0
	if player.deck.size() <= 8 and _has_ready_family_attacker(player) and target != player.active_pokemon:
		score -= 350.0
	return score


func _score_family_tool(
	action: Dictionary,
	score: float,
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> float:
	if not _matches_family(action.get("card", null), TM_EVOLUTION_NAMES):
		return score
	var target: PokemonSlot = action.get("target_slot", null)
	if _first_player_attack_locked(game_state, player_index):
		return minf(score, -2800.0)
	if target == null or target != player.active_pokemon:
		return minf(score, -2400.0)
	var target_count := _tm_evolution_debt_count(player)
	if target_count <= 0 or not _can_pay_tm_evolution(game_state, player):
		return minf(score, -1800.0)
	return maxf(score + 1000.0 + float(target_count) * 650.0, 1800.0)


func _score_family_evolution(action: Dictionary, score: float, player: PlayerState) -> float:
	var evolution: Variant = action.get("card", null)
	if _matches_family(evolution, [GARDEVOIR_EX, "Gardevoir ex"]):
		var gardevoir_count := _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"])
		if gardevoir_count == 0:
			var target: PokemonSlot = action.get("target_slot", null)
			if target == player.active_pokemon and _family_count_on_bench(player, [KIRLIA, "Kirlia"]) > 0:
				return score
			return maxf(score + 900.0, 2400.0)
		if _family_count_on_field(player, [KIRLIA, "Kirlia"]) <= 1:
			return minf(score, -1500.0)
		score += 180.0
	elif _matches_family(evolution, [KIRLIA, "Kirlia"]):
		var kirlia_count := _family_count_on_field(player, [KIRLIA, "Kirlia"])
		return maxf(score + 600.0, 1500.0 if kirlia_count == 0 else 980.0)
	elif _matches_family(evolution, RABSCA_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca):
		return maxf(score + 700.0, 1350.0)
	return score


func _score_family_bench(
	action: Dictionary,
	score: float,
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> float:
	var card: Variant = action.get("card", null)
	if _matches_family(card, [RALTS, "Ralts"]):
		var ralts_count := _family_count_on_field(player, [RALTS, "Ralts"])
		score += 1000.0 if ralts_count == 0 else 420.0 if ralts_count == 1 else -250.0
	elif _matches_family(card, RELLOR_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca):
		score += 850.0 if _family_count_on_field(player, RABSCA_NAMES) == 0 else -300.0
	elif _matches_family(card, SHAYMIN_NAMES) and (_family_variant == VARIANT_ACADEMY or _family_has_shaymin):
		score += 900.0 if _opponent_has_bench_damage_pressure(game_state, player_index) else 180.0
	elif _is_family_attacker(card) and _family_count_attackers_on_field(player) == 0:
		score += 750.0
	if player.bench.size() >= 4 and _has_ready_family_attacker(player):
		score -= 600.0
	return score


func _family_discard_score(
	card: CardInstance,
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> float:
	if card == null or card.card_data == null:
		return -1000.0
	if _is_basic_energy_symbol(card, "P"):
		var current_fuel := _count_psychic_energy_in_discard(game_state, player_index) if game_state != null else 0
		if current_fuel < _psychic_fuel_target(player):
			return 3400.0 - float(current_fuel) * 180.0
		return 180.0
	if _is_basic_energy_symbol(card, "D"):
		if player != null and _has_unpowered_munkidori(player):
			return -900.0
		return 220.0
	if _matches_family(card, [GARDEVOIR_EX, "Gardevoir ex"]):
		return -1200.0 if player == null or _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"]) == 0 else 20.0
	if _matches_family(card, [KIRLIA, "Kirlia"]):
		return -1100.0 if player == null or _family_count_on_field(player, [KIRLIA, "Kirlia"]) < 2 else 35.0
	if _matches_family(card, [RALTS, "Ralts"]):
		return -950.0 if player == null or _family_count_on_field(player, [RALTS, "Ralts", KIRLIA, "Kirlia", GARDEVOIR_EX, "Gardevoir ex"]) < 2 else 70.0
	if _matches_family(card, RABSCA_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca):
		return -850.0 if player == null or _family_count_on_field(player, RABSCA_NAMES) == 0 else 40.0
	if _matches_family(card, RELLOR_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca):
		return -700.0 if player == null or _family_count_on_field(player, RELLOR_NAMES) == 0 else 55.0
	if _is_family_attacker(card) and player != null and _family_count_attackers_on_field(player) == 0:
		return -720.0
	return float(super.get_discard_priority_contextual(card, game_state, player_index)) \
		if game_state != null and player_index >= 0 else float(super.get_discard_priority(card))


func _tm_evolution_slot_score(slot: PokemonSlot, player: PlayerState) -> float:
	if slot == null:
		return -2000.0
	if _matches_family(slot, [KIRLIA, "Kirlia"]):
		return 3900.0 if player == null or _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"]) == 0 else 1300.0
	if _matches_family(slot, [RALTS, "Ralts"]):
		return 3500.0 if player == null or _family_count_on_field(player, [KIRLIA, "Kirlia"]) < 2 else 1500.0
	if _matches_family(slot, RELLOR_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca):
		return 3300.0 if player == null or _family_count_on_field(player, RABSCA_NAMES) == 0 else 300.0
	return -1400.0


func _tm_evolution_card_score(card: CardInstance, player: PlayerState) -> float:
	if _matches_family(card, [GARDEVOIR_EX, "Gardevoir ex"]):
		return 3900.0 if player == null or _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"]) == 0 else 900.0
	if _matches_family(card, [KIRLIA, "Kirlia"]):
		return 3600.0
	if _matches_family(card, RABSCA_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca):
		return 3400.0
	return -1300.0


func _variant_for_deck_id(deck_id: int) -> String:
	match deck_id:
		DECK_NO_TM: return VARIANT_NO_TM
		DECK_RABSCA: return VARIANT_RABSCA
		DECK_STANDARD: return VARIANT_STANDARD
		DECK_ACADEMY: return VARIANT_ACADEMY
	return VARIANT_UNKNOWN


func _deck_entry_matches_any(entry: Dictionary, names: Array[String]) -> bool:
	var local_name := str(entry.get("name", "")).strip_edges().to_lower()
	var english_name := str(entry.get("name_en", entry.get("source_name", ""))).strip_edges().to_lower()
	for wanted: String in names:
		var normalized := wanted.strip_edges().to_lower()
		if local_name == normalized or english_name == normalized:
			return true
	return false


func _first_opening_index(basics: Array[Dictionary], preference_groups: Array) -> int:
	for names_variant: Variant in preference_groups:
		if not names_variant is Array:
			continue
		var names: Array[String] = []
		for raw_name: Variant in names_variant as Array:
			names.append(str(raw_name))
		for entry: Dictionary in basics:
			if _matches_family(entry.get("card", null), names):
				return int(entry.get("index", -1))
	return -1


func _append_opening_bench_matches(
	bench_indices: Array[int],
	basics: Array[Dictionary],
	active_index: int,
	preference_groups: Array,
	max_to_add: int
) -> void:
	var added := 0
	for names_variant: Variant in preference_groups:
		if added >= max_to_add or not names_variant is Array:
			break
		var names: Array[String] = []
		for raw_name: Variant in names_variant as Array:
			names.append(str(raw_name))
		for entry: Dictionary in basics:
			if added >= max_to_add:
				break
			var index := int(entry.get("index", -1))
			if index == active_index or index in bench_indices:
				continue
			if _matches_family(entry.get("card", null), names):
				bench_indices.append(index)
				added += 1


func _family_card_data(item: Variant) -> CardData:
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is CardData:
		return item as CardData
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	return null


func _matches_family(item: Variant, names: Array[String]) -> bool:
	var data := _family_card_data(item)
	if data == null:
		return false
	var local_name := str(data.name).strip_edges().to_lower()
	var english_name := str(data.name_en).strip_edges().to_lower()
	for wanted: String in names:
		var normalized := wanted.strip_edges().to_lower()
		if local_name == normalized or english_name == normalized:
			return true
	return false


func _family_count_on_field(player: PlayerState, names: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_is_live(slot) and _matches_family(slot, names):
			count += 1
	return count


func _family_count_on_bench(player: PlayerState, names: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if _slot_is_live(slot) and _matches_family(slot, names):
			count += 1
	return count


func _family_count_attackers_on_field(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_is_live(slot) and _is_family_attacker(slot):
			count += 1
	return count


func _is_family_attacker(item: Variant) -> bool:
	return _matches_family(item, FAMILY_ATTACKER_NAMES)


func _best_family_attacker(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _slot_is_live(slot) or not _is_family_attacker(slot):
			continue
		var score := 200.0
		if slot == player.active_pokemon:
			score += 300.0
		if _family_attacker_ready(slot):
			score += 1200.0
		var prediction := predict_attacker_damage(slot)
		score += float(int(prediction.get("damage", 0)))
		if score > best_score:
			best_score = score
			best = slot
	return best


func _best_gardevoir_fallback(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	if _matches_family(player.active_pokemon, [GARDEVOIR_EX, "Gardevoir ex"]):
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if _slot_is_live(slot) and _matches_family(slot, [GARDEVOIR_EX, "Gardevoir ex"]):
			return slot
	return null


func _gardevoir_fallback_ready(slot: PokemonSlot) -> bool:
	return slot != null \
		and _matches_family(slot, [GARDEVOIR_EX, "Gardevoir ex"]) \
		and _minimum_attack_gap(slot) <= 0


func _gardevoir_emergency_route_live(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	slot: PokemonSlot
) -> bool:
	if player == null \
			or slot == null \
			or slot != player.active_pokemon \
			or not _matches_family(slot, [GARDEVOIR_EX, "Gardevoir ex"]) \
			or _family_count_attackers_on_field(player) > 0:
		return false
	if player.deck.size() <= 8:
		return true
	if game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	return opponent != null \
		and opponent.active_pokemon != null \
		and opponent.active_pokemon.get_remaining_hp() <= 190


func _family_attacker_ready(slot: PokemonSlot) -> bool:
	if slot == null or not _is_family_attacker(slot) or _family_attack_gap(slot) > 0:
		return false
	if _matches_family(slot, [SCREAM_TAIL, "Scream Tail", DRIFLOON, "Drifloon"]):
		return slot.damage_counters > 0
	return true


func _family_attack_gap(slot: PokemonSlot) -> int:
	if _matches_family(slot, [SCREAM_TAIL, "Scream Tail", DRIFLOON, "Drifloon"]):
		return _self_damage_attack_energy_gap(slot, 2)
	return _minimum_attack_gap(slot)


func _has_ready_family_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _family_attacker_ready(slot):
			return true
	return false


func _has_family_attacker_on_bench(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_is_live(slot) and _is_family_attacker(slot):
			return true
	return false


func _has_productive_handoff_on_bench(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if not _slot_is_live(slot):
			continue
		if _is_family_attacker(slot) \
				or _matches_family(slot, [GARDEVOIR_EX, "Gardevoir ex", KIRLIA, "Kirlia", RALTS, "Ralts"]):
			return true
	return false


func _minimum_attack_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 999
	var minimum := 999
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
		minimum = mini(minimum, maxi(0, cost.length() - slot.attached_energy.size()))
	return minimum


func _family_slot_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	return str(slot.get_card_data().name) if str(slot.get_card_data().name) != "" else str(slot.get_card_data().name_en)


func _preferred_family_attacker_name() -> String:
	if _family_variant == VARIANT_STANDARD:
		return SCREAM_TAIL
	return DRIFLOON


func _family_attach_priorities(attacker_name: String) -> Array[String]:
	var result: Array[String] = []
	if attacker_name != "":
		result.append(attacker_name)
	for name: String in [_preferred_family_attacker_name(), SCREAM_TAIL, GARDEVOIR_EX, MUNKIDORI]:
		if name != "" and name not in result:
			result.append(name)
	return result


func _family_handoff_priorities(attacker_name: String) -> Array[String]:
	var result: Array[String] = []
	if attacker_name != "":
		result.append(attacker_name)
	for name: String in [_preferred_family_attacker_name(), SCREAM_TAIL, GARDEVOIR_EX]:
		if name != "" and name not in result:
			result.append(name)
	return result


func _family_search_priorities() -> Array[String]:
	var result: Array[String] = [GARDEVOIR_EX, KIRLIA, RALTS]
	if _family_variant == VARIANT_RABSCA or _family_has_rabsca:
		result.append_array([RABSCA_NAMES[0], RELLOR_NAMES[0]])
	result.append_array([_preferred_family_attacker_name(), SCREAM_TAIL, MUNKIDORI, EARTHEN_VESSEL, ULTRA_BALL])
	return result


func _family_evolution_priorities() -> Array[String]:
	var result: Array[String] = [GARDEVOIR_EX, KIRLIA]
	if _family_variant == VARIANT_RABSCA or _family_has_rabsca:
		result.append(RABSCA_NAMES[0])
	return result


func _psychic_fuel_target(player: PlayerState) -> int:
	if player == null:
		return 2
	if _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"]) == 0:
		return 2
	if _family_count_on_field(player, [DRIFLOON, "Drifloon", SCREAM_TAIL, "Scream Tail"]) > 0:
		return 3
	return 2


func _tm_evolution_debt_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var debt := 0
	for slot: PokemonSlot in player.bench:
		if _matches_family(slot, [KIRLIA, "Kirlia"]) and _family_count_on_field(player, [GARDEVOIR_EX, "Gardevoir ex"]) == 0:
			debt += 1
		elif _matches_family(slot, [RALTS, "Ralts"]) and _family_count_on_field(player, [KIRLIA, "Kirlia"]) < 2:
			debt += 1
		elif _matches_family(slot, RELLOR_NAMES) and (_family_variant == VARIANT_RABSCA or _family_has_rabsca) and _family_count_on_field(player, RABSCA_NAMES) == 0:
			debt += 1
	return mini(2, debt)


func _can_pay_tm_evolution(game_state: GameState, player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not player.active_pokemon.attached_energy.is_empty():
		return true
	if game_state != null and game_state.energy_attached_this_turn:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _first_player_attack_locked(game_state: GameState, player_index: int) -> bool:
	return game_state != null \
		and int(game_state.turn_number) == 1 \
		and int(game_state.first_player_index) == player_index


func _is_tm_evolution_attack_action(action: Dictionary) -> bool:
	var granted: Variant = action.get("granted_attack_data", {})
	if granted is Dictionary:
		var granted_data := granted as Dictionary
		if str(granted_data.get("id", "")) == "tm_evolution" or str(granted_data.get("name", "")) in ["进化", "Evolution", "TM Evolution"]:
			return true
	return str(action.get("attack_name", "")) in ["进化", "Evolution", "TM Evolution"]


func _interaction_role(item: Variant, step_id: String) -> String:
	if step_id != "evolution_cards":
		return ""
	if _matches_family(item, [GARDEVOIR_EX, "Gardevoir ex"]):
		return "gardevoir"
	if _matches_family(item, [KIRLIA, "Kirlia"]):
		return "kirlia"
	if _matches_family(item, RABSCA_NAMES):
		return "rabsca"
	return ""


func _interaction_role_limits(items: Array, step_id: String, max_select: int) -> Dictionary:
	var limits := {}
	if step_id != "evolution_cards":
		return limits
	for item: Variant in items:
		var role := _interaction_role(item, step_id)
		if role != "":
			limits[role] = 1
	# A real TM follow-up only exposes evolutions for the selected slots. When
	# every candidate is from one line, multiple same-name cards represent
	# distinct selected Pokemon and must not be deduplicated.
	if limits.size() == 1:
		var only_role: Variant = limits.keys()[0]
		limits[only_role] = max_select
	return limits


func _family_attack_cost_is_met(slot: PokemonSlot, cost: String, extra_psychic: int = 0) -> bool:
	if slot == null:
		return false
	var normalized_cost := CardData.normalize_attack_cost(cost)
	var required_psychic := 0
	for symbol: String in normalized_cost:
		if symbol == "P":
			required_psychic += 1
	var psychic_units := maxi(0, extra_psychic)
	for energy: CardInstance in slot.attached_energy:
		var data := _family_card_data(energy)
		if data == null or not data.is_energy():
			continue
		var provides := str(data.energy_provides)
		if provides == "":
			provides = str(data.energy_type)
		if provides == "ANY" or provides.contains("P"):
			psychic_units += 1
	return slot.attached_energy.size() + maxi(0, extra_psychic) >= normalized_cost.length() \
		and psychic_units >= required_psychic


func _is_basic_energy_symbol(item: Variant, symbol: String) -> bool:
	var data := _family_card_data(item)
	return data != null and str(data.card_type) == "Basic Energy" and str(data.energy_provides) == symbol


func _slot_has_energy_symbol(slot: PokemonSlot, symbol: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _is_basic_energy_symbol(energy, symbol):
			return true
	return false


func _hand_has_energy_symbol(player: PlayerState, symbol: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _is_basic_energy_symbol(card, symbol):
			return true
	return false


func _has_unpowered_munkidori(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches_family(slot, [MUNKIDORI, "Munkidori"]) and not _slot_has_energy_symbol(slot, "D"):
			return true
	return false


func _opponent_has_bench_damage_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot == null or slot.get_card_data() == null:
			continue
		for attack: Dictionary in slot.get_card_data().attacks:
			var text := (str(attack.get("name", "")) + " " + str(attack.get("text", ""))).to_lower()
			if text.contains("bench") or text.contains("备战") or text.contains("后备"):
				return true
	return false
