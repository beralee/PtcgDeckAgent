class_name DeckStrategyV18BlazikenDragapult
extends "res://scripts/ai/DeckStrategyV18DragapultFamily.gd"


const DECK_MUNKIDORI_BLAZIKEN := 18000625
const DECK_DUSKNOIR_DRAGAPULT := 800015734
const DECK_BLAZIKEN_DRAGAPULT := 800019125
const SINGLE_PRIZE_BLAZIKEN_EFFECT_ID := "d66a01f98e15b770b2c4bd1372382d4c"
const ULTRA_BALL_EFFECT_ID := "a337ed34a45e63c6d21d98c3d8e0cb6e"
const BLAZIKEN_ENERGY_DISCARD_STEP := "discard_two_energy_for_bench_damage"
const BLAZIKEN_BENCH_TARGET_STEP := "bench_damage_target"

const SUPPORTED_DECK_IDS: Array[int] = [
	DECK_MUNKIDORI_BLAZIKEN,
	DECK_DUSKNOIR_DRAGAPULT,
	DECK_BLAZIKEN_DRAGAPULT,
]

const TORCHIC_MB: Array[String] = ["火稚鸡", "Torchic", "e6962cb473824c61448412bbb29b0313"]
const COMBUSKEN_MB: Array[String] = ["力壮鸡", "Combusken", "aa3e6e7b35d94f4cfc99d9bb7ba5ddc3"]
const BLAZIKEN_EX_MB: Array[String] = ["火焰鸡ex", "Blaziken ex", "15eb5f310fd523c4c468e4519e30ae70"]
const BLAZIKEN_MB: Array[String] = ["火焰鸡", "Blaziken", "d66a01f98e15b770b2c4bd1372382d4c"]
const MUNKIDORI_MB: Array[String] = ["愿增猿", "Munkidori", "66fee12502043db7d92b97b0d62b0f59"]
const PECHARUNT_MB: Array[String] = ["桃歹郎", "Pecharunt", "277e3fdeae03359715f5b1432e00619c"]
const MIMIKYU_MB: Array[String] = ["谜拟丘", "Mimikyu", "4ba364fe554ffe8577561515bc8b5979"]
const SHAYMIN_MB: Array[String] = ["谢米", "Shaymin", "fd1e9b0379f79156fbb304162cbe21ba"]
const FEZANDIPITI_MB: Array[String] = ["吉雉鸡ex", "Fezandipiti ex", "ab6c3357e2b8a8385a68da738f41e0c1"]

const IONO_MB: Array[String] = ["奇树", "Iono"]
const RESEARCH_MB: Array[String] = ["博士的研究", "Professor's Research"]
const BOSS_MB: Array[String] = ["老大的指令", "Boss's Orders"]
const NEST_BALL_MB: Array[String] = ["巢穴球", "Nest Ball"]
const SECRET_BOX_MB: Array[String] = ["秘密箱", "Secret Box"]
const ART_AZON_MB: Array[String] = ["深钵镇", "Artazon"]

const MAXIMUM_BELT_MB: Array[String] = ["Maximum Belt", "CSV7C_189"]

const LOW_DECK_CHURN_FLOOR := 8
const CRITICAL_DECK_FLOOR := 4
const MB_TM_ROUTE_ATTACH_TM := "attach_tm"
const MB_TM_ROUTE_ATTACH_ACTIVE_FIRE := "attach_active_fire"
const MB_TM_ROUTE_USE_EVOLUTION := "use_tm_evolution"
const MB_TM_ROUTE_INACTIVE := "inactive"
const MB_TM_ROUTE_HARD_REJECT_SCORE := -100000.0
const PECHARUNT_TM_CARRIER: Array[String] = ["CSV9C_127"]

var _munkidori_blaziken := false


func configure_from_deck(deck: DeckData) -> void:
	super.configure_from_deck(deck)
	_munkidori_blaziken = _deck_id == DECK_MUNKIDORI_BLAZIKEN


func get_strategy_id() -> String:
	return "v18_blaziken_dragapult_%d" % _deck_id


func get_supported_deck_ids() -> Array[int]:
	return SUPPORTED_DECK_IDS.duplicate()


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if not _munkidori_blaziken:
		return super.plan_opening_setup(player)
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var candidates: Array[Dictionary] = []
	for index: int in player.hand.size():
		var card: CardInstance = player.hand[index]
		if card == null or not card.is_basic_pokemon():
			continue
		candidates.append({
			"index": index,
			"active": _mb_opening_active_score(card),
			"bench": _mb_opening_bench_score(card),
		})
	if candidates.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("active", 0.0)) > float(b.get("active", 0.0))
	)
	var active_index := int(candidates[0].get("index", -1))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("bench", 0.0)) > float(b.get("bench", 0.0))
	)
	var bench_indices: Array[int] = []
	for entry: Dictionary in candidates:
		var index := int(entry.get("index", -1))
		if index == active_index or float(entry.get("bench", 0.0)) <= 0.0:
			continue
		bench_indices.append(index)
		if bench_indices.size() >= 5:
			break
	return {
		"active_hand_index": active_index,
		"bench_hand_indices": bench_indices,
	}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if not _munkidori_blaziken:
		var inherited := super.build_turn_plan(game_state, player_index, context)
		var inherited_flags: Dictionary = inherited.get("flags", {})
		inherited_flags["blaziken_dragapult_delegate"] = true
		inherited_flags["supported_deck_id"] = _deck_id in SUPPORTED_DECK_IDS
		inherited["flags"] = inherited_flags
		return inherited
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var tm_route := _mb_first_turn_tm_evolution_route_state(game_state, player_index)
	var tm_route_live := str(tm_route.get("stage", MB_TM_ROUTE_INACTIVE)) != MB_TM_ROUTE_INACTIVE
	var owner: PokemonSlot = tm_route.get("owner", null)
	if owner == null:
		owner = _mb_best_route_owner(player, int(game_state.turn_number))
	var owner_name := _display_name(owner) if owner != null else "火焰鸡ex"
	var bridge_name := str(tm_route.get("bridge_name", ""))
	if bridge_name == "":
		bridge_name = _mb_bridge_name(player, int(game_state.turn_number))
	var engine_online := _mb_has_slot(player, BLAZIKEN_EX_MB)
	var ready_attack := owner != null and bool(predict_attacker_damage(owner).get("can_attack", false))
	var phase := "setup"
	if engine_online:
		phase = "convert" if ready_attack else "launch"
	if ready_attack and player.prizes.size() <= 2:
		phase = "close"
	elif not engine_online and int(game_state.turn_number) > 3:
		phase = "rebuild"
	var debt := _mb_setup_debt(player, int(game_state.turn_number), tm_route)
	var attach_priorities: Array[String] = ["愿增猿", "火焰鸡ex", "火焰鸡", "力壮鸡", "火稚鸡", "谜拟丘", "桃歹郎"]
	if tm_route_live:
		attach_priorities.erase(owner_name)
		attach_priorities.push_front(owner_name)
	return {
		"id": "v18_blaziken_dragapult_%d:%s" % [_deck_id, phase],
		"intent": "complete_first_turn_tm_evolution" if tm_route_live else _mb_turn_intent(phase),
		"phase": phase,
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": owner_name,
		},
		"targets": {
			"primary_attacker_name": "火焰鸡ex",
			"energy_engine_name": "火焰鸡ex",
			"damage_mover_name": "愿增猿",
			"bridge_target_name": bridge_name,
		},
		"priorities": {
			"attach": attach_priorities,
			"handoff": ["火焰鸡ex", "火焰鸡", "谜拟丘", "愿增猿", "桃歹郎"],
			"search": ["火焰鸡ex", "力壮鸡", "火稚鸡", "愿增猿", "基本恶能量", "大地容器"],
			"evolve": ["火焰鸡ex", "火焰鸡", "力壮鸡"],
			"ability": ["火焰鸡ex", "愿增猿", "吉雉鸡ex"],
			"trainer": _profile_list("trainer_priority"),
		},
		"flags": {
			"blaziken_dragapult_delegate": true,
			"munkidori_blaziken": true,
			"boiling_spirit_online": engine_online,
			"dark_munkidori_online": _mb_has_powered_munkidori(player),
			"ready_attack": ready_attack,
			"setup_debt": debt,
			"tm_evolution_first_turn_route": str(tm_route.get("stage", MB_TM_ROUTE_INACTIVE)),
			"allow_resource_paid_owner_retreat": false,
		},
		"constraints": {
			"forbid_engine_churn": player.deck.size() <= LOW_DECK_CHURN_FLOOR and ready_attack,
			"forbid_extra_bench_padding": player.bench.size() >= 4 and int(debt.get("total", 0)) <= 0,
		},
		"context": context.duplicate(true),
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	if not _munkidori_blaziken:
		return super.build_continuity_contract(game_state, player_index, turn_contract)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var tm_route := _mb_first_turn_tm_evolution_route_state(game_state, player_index)
	var tm_route_stage := str(tm_route.get("stage", MB_TM_ROUTE_INACTIVE))
	var owner: PokemonSlot = tm_route.get("owner", null)
	if owner == null:
		owner = _mb_best_route_owner(player, int(game_state.turn_number))
	var owner_name := _display_name(owner) if owner != null else "火焰鸡ex"
	var bridge_name := str(tm_route.get("bridge_name", ""))
	if bridge_name == "":
		bridge_name = _mb_bridge_name(player, int(game_state.turn_number))
	var debt := _mb_setup_debt(player, int(game_state.turn_number), tm_route)
	var ready := owner != null and bool(predict_attacker_damage(owner).get("can_attack", false))
	var tm_setup_before_attack := tm_route_stage in [MB_TM_ROUTE_ATTACH_TM, MB_TM_ROUTE_ATTACH_ACTIVE_FIRE]
	return {
		"enabled": true,
		"safe_setup_before_attack": tm_setup_before_attack \
			or (ready and int(debt.get("total", 0)) > 0 and player.deck.size() > CRITICAL_DECK_FLOOR),
		"setup_debt": debt,
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": owner_name,
		},
		"tm_evolution_first_turn_route": tm_route_stage,
		"action_bonuses": [
			{
				"kind": "play_basic_to_bench",
				"card_names": ["火稚鸡", "Torchic"],
				"bonus": 620.0 if int(debt.get("missing_torchic_lane", 0)) > 0 else 100.0,
			},
			{
				"kind": "evolve",
				"card_names": ["力壮鸡", "Combusken", "火焰鸡ex", "Blaziken ex", "火焰鸡", "Blaziken"],
				"bonus": 760.0 if int(debt.get("missing_blaziken_engine", 0)) > 0 else 180.0,
			},
			{
				"kind": "attach_energy",
				"target_names": ["愿增猿", "Munkidori"],
				"bonus": 680.0 if int(debt.get("missing_dark_munkidori", 0)) > 0 else 80.0,
			},
			{
				"kind": "use_ability",
				"target_names": ["火焰鸡ex", "Blaziken ex", "愿增猿", "Munkidori"],
				"bonus": 420.0,
			},
		],
		"attack_penalty": 1150.0,
		"turn_contract_id": str(turn_contract.get("id", "")),
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if not _munkidori_blaziken:
		return super.score_action_absolute(action, game_state, player_index)
	var inherited := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return inherited
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var kind := str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			return _mb_score_basic_to_bench(action.get("card", null), player)
		"evolve":
			return _mb_score_evolution(action, player)
		"attach_energy":
			return _mb_score_manual_attachment(action, player, game_state, player_index)
		"attach_tool":
			return _mb_score_tool(action, player, game_state, player_index)
		"play_trainer":
			return _mb_score_trainer(action, player, game_state, player_index, inherited)
		"use_ability":
			return _mb_score_ability(action, player, opponent, inherited)
		"retreat":
			var target: PokemonSlot = action.get(
				"target_slot",
				action.get("bench_slot", action.get("bench_target", null))
			)
			if _mb_recycles_dark_munkidori_without_progress(
				player.active_pokemon,
				target,
				player,
				int(game_state.turn_number)
			):
				return -3600.0
			return score_handoff_target(target, {"id": "retreat"}, {
				"game_state": game_state,
				"player_index": player_index,
			})
		"attack", "granted_attack":
			return _mb_score_attack(action, player, opponent, game_state, player_index, inherited)
		"end_turn":
			if _mb_has_productive_setup_action(player, game_state, player_index):
				return -2800.0
			return 350.0 if player.deck.size() <= CRITICAL_DECK_FLOOR else inherited
	return inherited


func score_action_absolute_with_plan(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	_turn_plan: Dictionary = {}
) -> float:
	# V18Rules merges and applies this delegate's continuity contract once.
	return score_action_absolute(action, game_state, player_index)


func get_discard_priority(card: CardInstance) -> int:
	if not _munkidori_blaziken:
		return super.get_discard_priority(card)
	if _matches_any(card, BLAZIKEN_EX_MB) or _matches_any(card, BLAZIKEN_MB):
		return 3
	if _matches_any(card, COMBUSKEN_MB):
		return 5
	if _matches_any(card, TORCHIC_MB):
		return 9
	if _matches_any(card, MUNKIDORI_MB):
		return 7
	if _matches_any(card, RARE_CANDY) or _matches_any(card, TM_EVOLUTION):
		return 8
	if _matches_any(card, NIGHT_STRETCHER) or _matches_any(card, SUPER_ROD):
		return 10
	if _is_basic_energy(card):
		return 12
	return super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if not _munkidori_blaziken:
		return super.get_discard_priority_contextual(card, game_state, player_index)
	var base_priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return base_priority
	var player: PlayerState = game_state.players[player_index]
	if _is_basic_energy(card):
		var energy_type := _energy_type(card)
		if energy_type == "D" and not _mb_has_powered_munkidori(player):
			return 2
		if _mb_has_slot(player, BLAZIKEN_EX_MB) and _mb_count_basic_energy(player, energy_type) >= 2:
			return 145
	if (_matches_any(card, ULTRA_BALL) or _matches_any(card, BUDDY_BUDDY_POFFIN) or _matches_any(card, NEST_BALL_MB)) \
			and player.is_bench_full():
		return 180
	return base_priority


func get_search_priority(card: CardInstance) -> int:
	if not _munkidori_blaziken:
		return super.get_search_priority(card)
	if _matches_any(card, BLAZIKEN_EX_MB):
		return 1220
	if _matches_any(card, COMBUSKEN_MB):
		return 1180
	if _matches_any(card, TORCHIC_MB):
		return 1100
	if _matches_any(card, MUNKIDORI_MB):
		return 980
	if _matches_any(card, BLAZIKEN_MB):
		return 900
	if _is_basic_energy(card):
		return 820
	return super.get_search_priority(card)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if not _munkidori_blaziken:
		return super.pick_interaction_items(items, step, context)
	var max_select := maxi(1, int(step.get("max_select", 1)))
	var step_id := str(step.get("id", "")).to_lower()
	if step_id == "discard_cards" and max_select == 2 \
			and _mb_should_preserve_ultra_ball_startup_fire(items, step, context):
		return _mb_pick_discards_preserving_one_fire(items, step, context, max_select)
	if _interaction_uses_effect(context, SINGLE_PRIZE_BLAZIKEN_EFFECT_ID):
		if step_id == BLAZIKEN_ENERGY_DISCARD_STEP:
			return _pick_ranked_interaction_items(items, step, context, max_select)
		if step_id == BLAZIKEN_BENCH_TARGET_STEP:
			return _pick_ranked_interaction_items(items, step, context, 1)
	if max_select <= 1 or step_id not in ["buddy_poffin_pokemon", "basic_pokemon", "bench_pokemon"]:
		return super.pick_interaction_items(items, step, context)
	var ranked := items.duplicate()
	ranked.sort_custom(func(a: Variant, b: Variant) -> bool:
		return score_interaction_target(a, step, context) > score_interaction_target(b, step, context)
	)
	var result: Array = []
	var roles := {}
	for item: Variant in ranked:
		var role := _mb_basic_role(item)
		if role != "" and roles.has(role):
			continue
		result.append(item)
		if role != "":
			roles[role] = true
		if result.size() >= max_select:
			return result
	for item: Variant in ranked:
		if item in result:
			continue
		result.append(item)
		if result.size() >= max_select:
			break
	return result


func _mb_should_preserve_ultra_ball_startup_fire(
	items: Array,
	step: Dictionary,
	context: Dictionary
) -> bool:
	if not _interaction_uses_effect(context, ULTRA_BALL_EFFECT_ID) and not context.has("owner_index"):
		return false
	var state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if state == null or player_index < 0 or player_index >= state.players.size():
		return false
	if str(_mb_first_turn_tm_evolution_route_state(state, player_index).get("stage", MB_TM_ROUTE_INACTIVE)) != MB_TM_ROUTE_INACTIVE:
		return false
	var player: PlayerState = state.players[player_index]
	if _mb_has_slot(player, BLAZIKEN_EX_MB) or not _mb_unpowered_fire_seed_line(player):
		return false
	var fire_count := 0
	for item: Variant in items:
		if item is CardInstance and _is_basic_energy(item) and _energy_type(item) == "R":
			fire_count += 1
	return fire_count > 0 and items.size() > int(step.get("max_select", 2))


func _mb_pick_discards_preserving_one_fire(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	select_count: int
) -> Array:
	var selectable := items.duplicate()
	for item: Variant in items:
		if item is CardInstance and _is_basic_energy(item) and _energy_type(item) == "R":
			selectable.erase(item)
			break
	return _pick_ranked_interaction_items(selectable, step, context, select_count)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not _munkidori_blaziken:
		return super.score_interaction_target(item, step, context)
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if item is CardInstance:
		var card := item as CardInstance
		if _interaction_uses_effect(context, SINGLE_PRIZE_BLAZIKEN_EFFECT_ID) \
				and step_id == BLAZIKEN_ENERGY_DISCARD_STEP:
			return float(get_discard_priority_contextual(
				card,
				context.get("game_state", null),
				int(context.get("player_index", -1))
			))
		if step_id.contains("discard") and step_id != "attach_basic_energy_from_discard":
			return float(get_discard_priority_contextual(
				card,
				context.get("game_state", null),
				int(context.get("player_index", -1))
			))
		if step_id in ["attach_basic_energy_from_discard", "energy_assignments"] and _is_basic_energy(card):
			return _mb_score_discard_energy(card, player)
		if step_id in ["search_pokemon", "search_cards", "search_item", "search_tool", "stage2_card", "evolution_cards", "basic_pokemon", "bench_pokemon", "buddy_poffin_pokemon", "recover_target", "recover_card"]:
			return _mb_score_search_card(card, player, step_id)
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if _interaction_uses_effect(context, SINGLE_PRIZE_BLAZIKEN_EFFECT_ID) \
				and step_id == BLAZIKEN_BENCH_TARGET_STEP:
			return _mb_score_counter_target(slot, 120)
		if step_id == "source_pokemon":
			return _mb_score_damage_source(slot)
		if step_id in ["target_damage_counters", "opponent_pokemon_damage_counter_target", "bench_target"]:
			return _mb_score_counter_target(slot, 30)
		if step_id in ["attach_basic_energy_from_discard", "energy_assignments", "assignment_target", "attach_energy_target", "energy_target"]:
			return _mb_score_acceleration_target(slot, context, player)
		if step_id == "evolution_bench":
			return 4800.0 if _matches_any(slot, TORCHIC_MB) else 200.0
		if step_id.contains("switch") or step_id.contains("send") or step_id.contains("handoff") or step_id.contains("active"):
			return score_handoff_target(slot, step, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not _munkidori_blaziken:
		return super.score_handoff_target(item, step, context)
	if not item is PokemonSlot:
		return super.score_handoff_target(item, step, context)
	var slot := item as PokemonSlot
	var prediction := predict_attacker_damage(slot)
	var ready := bool(prediction.get("can_attack", false))
	if _matches_any(slot, BLAZIKEN_EX_MB):
		var state: GameState = context.get("game_state", null)
		var current_turn := int(state.turn_number) if state != null else -999
		return 5400.0 if ready and not _mb_attack_locked(slot, current_turn) else 1050.0
	if _matches_any(slot, BLAZIKEN_MB):
		return 4300.0 if ready else 1350.0
	if _matches_any(slot, MIMIKYU_MB):
		var state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		return 3600.0 if _mb_opponent_active_is_rule_box(state, player_index) else 1500.0
	if _matches_any(slot, MUNKIDORI_MB):
		return 2300.0 if ready else 650.0
	if _matches_any(slot, PECHARUNT_MB):
		return 1700.0 if ready else 500.0
	return super.score_handoff_target(item, step, context)


func _mb_recycles_dark_munkidori_without_progress(
	active: PokemonSlot,
	target: PokemonSlot,
	player: PlayerState,
	current_turn: int
) -> bool:
	if active == null or target == null or player == null:
		return false
	if not _matches_any(active, MUNKIDORI_MB) \
			or not _matches_any(target, MUNKIDORI_MB + FEZANDIPITI_MB):
		return false
	if not _mb_slot_has_energy_type(active, "D"):
		return false
	if bool(predict_attacker_damage(target).get("can_attack", false)):
		return false
	return not _mb_has_ready_backup(player, active, current_turn)


func _mb_score_basic_to_bench(card: Variant, player: PlayerState) -> float:
	if _matches_any(card, TORCHIC_MB):
		var lane_count := _mb_count_slots(player, TORCHIC_MB + COMBUSKEN_MB + BLAZIKEN_EX_MB + BLAZIKEN_MB)
		return 4800.0 if lane_count == 0 else (3300.0 if lane_count == 1 else 350.0)
	if _matches_any(card, MUNKIDORI_MB):
		var count := _mb_count_slots(player, MUNKIDORI_MB)
		return 4100.0 if count == 0 else (2200.0 if count == 1 and _mb_has_damage_to_move(player) else 250.0)
	if _matches_any(card, SHAYMIN_MB):
		return 2500.0 if not _mb_has_slot(player, SHAYMIN_MB) else 150.0
	if _matches_any(card, FEZANDIPITI_MB):
		return 1900.0 if not _mb_has_slot(player, FEZANDIPITI_MB) else -300.0
	if _matches_any(card, MIMIKYU_MB):
		return 2100.0 if not _mb_has_slot(player, MIMIKYU_MB) else 100.0
	if _matches_any(card, PECHARUNT_MB):
		return 1300.0 if not _mb_has_slot(player, PECHARUNT_MB) else 100.0
	return 100.0


func _mb_score_evolution(action: Dictionary, player: PlayerState) -> float:
	var card: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if _matches_any(card, BLAZIKEN_EX_MB):
		return 6100.0 if target != null and (_matches_any(target, COMBUSKEN_MB) or _matches_any(target, TORCHIC_MB)) else -2400.0
	if _matches_any(card, BLAZIKEN_MB):
		return 3500.0
	if _matches_any(card, COMBUSKEN_MB):
		return 4700.0 if target != null and _matches_any(target, TORCHIC_MB) else -1800.0
	return 0.0


func _mb_score_manual_attachment(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> float:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if card == null or target == null:
		return -1800.0
	var energy_type := _energy_type(card)
	var tm_route := _mb_first_turn_tm_evolution_route_state(game_state, player_index)
	if str(tm_route.get("stage", MB_TM_ROUTE_INACTIVE)) == MB_TM_ROUTE_ATTACH_ACTIVE_FIRE \
			and target == tm_route.get("owner", null) \
			and _is_basic_energy(card) \
			and energy_type == "R":
		return 6200.0
	if target == player.active_pokemon and _matches_any(target, MIMIKYU_MB) \
			and target.attached_energy.size() < target.get_retreat_cost() \
			and target.attached_energy.size() + 1 >= target.get_retreat_cost() \
			and _mb_has_ready_backup(
				player,
				target,
				int(game_state.turn_number) if game_state != null else -999
			):
		return 6100.0
	if _matches_any(target, MUNKIDORI_MB):
		if energy_type == "D" and not _mb_slot_has_energy_type(target, "D"):
			return 5600.0 if _mb_has_damage_to_move(player) else 4300.0
		if not _mb_slot_has_energy_type(target, "D"):
			return -1600.0
		return 2100.0 if bool(predict_attacker_damage(target).get("can_attack", false)) == false else 200.0
	if _matches_any(target, BLAZIKEN_EX_MB):
		var current_turn := int(game_state.turn_number) if game_state != null else -999
		if _mb_attack_locked(target, current_turn) and _mb_has_ready_backup(player, target, current_turn):
			return 300.0
		return _mb_attack_completion_score(card, target, "RC")
	if _matches_any(target, BLAZIKEN_MB):
		return _mb_attack_completion_score(card, target, "RRC")
	if _matches_any(target, COMBUSKEN_MB) or _matches_any(target, TORCHIC_MB):
		return 3400.0 if energy_type == "R" else 1350.0
	if _matches_any(target, MIMIKYU_MB):
		return 3100.0 if energy_type == "P" else 400.0
	if _matches_any(target, PECHARUNT_MB):
		return 2500.0 if energy_type == "D" and _mb_has_powered_munkidori(player) else 450.0
	return 100.0


func _mb_score_tool(action: Dictionary, player: PlayerState, game_state: GameState, player_index: int) -> float:
	var card: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if _matches_any(card, TM_EVOLUTION):
		var tm_route := _mb_first_turn_tm_evolution_route_state(game_state, player_index)
		var tm_route_stage := str(tm_route.get("stage", MB_TM_ROUTE_INACTIVE))
		if tm_route_stage == MB_TM_ROUTE_ATTACH_TM \
				and target == tm_route.get("owner", null):
			return 5200.0
		if tm_route_stage == MB_TM_ROUTE_INACTIVE:
			return MB_TM_ROUTE_HARD_REJECT_SCORE
		return -2100.0
	if _matches_any(card, MAXIMUM_BELT_MB):
		if _matches_any(target, BLAZIKEN_EX_MB):
			return 3200.0
		if _matches_any(target, TORCHIC_MB + COMBUSKEN_MB) and _mb_has_blaziken_ex_access(player):
			return 2800.0
		if _matches_any(target, BLAZIKEN_MB) and bool(predict_attacker_damage(target).get("can_attack", false)):
			return 2600.0
		return -4800.0
	return 250.0


func _mb_score_trainer(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	inherited: float
) -> float:
	var card: Variant = action.get("card", null)
	var current_turn := int(game_state.turn_number) if game_state != null else -999
	var opponent: PlayerState = game_state.players[1 - player_index] if game_state != null else null
	if (_matches_any(card, IONO_MB) or _matches_any(card, RESEARCH_MB)) \
			and player.deck.size() <= LOW_DECK_CHURN_FLOOR and _mb_has_ready_attack(player, current_turn):
		return -3600.0
	if _matches_any(card, RARE_CANDY):
		return 5700.0 if _has_live_rare_candy_route(player) else -1800.0
	if _matches_any(card, ULTRA_BALL):
		return 4400.0 if _mb_has_playable_evolution_search(player) else (250.0 if player.deck.size() > LOW_DECK_CHURN_FLOOR else -1800.0)
	if _matches_any(card, BUDDY_BUDDY_POFFIN) or _matches_any(card, NEST_BALL_MB) or _matches_any(card, ART_AZON_MB):
		return 3800.0 if not player.is_bench_full() and _mb_missing_basic_route(player) else -1300.0
	if _matches_any(card, EARTHEN_VESSEL):
		if _mb_should_bank_attack_energy_before_ultra(player, current_turn):
			return 5400.0
		return 3900.0 if _mb_missing_route_energy(player) else 300.0
	if _matches_any(card, NIGHT_STRETCHER):
		return 3700.0 if _mb_discard_has_route_piece(player) else -1000.0
	if _matches_any(card, SUPER_ROD):
		if player.deck.size() <= LOW_DECK_CHURN_FLOOR:
			return 3700.0 if _mb_discard_has_route_piece(player) else -1000.0
		return 3500.0 if _mb_discard_has_missing_route_piece(player) else -1800.0
	if _matches_any(card, BOSS_MB):
		return 4800.0 if _mb_has_ready_attack(player, current_turn) and _mb_opponent_has_bench_ko(opponent, 200) else 100.0
	if _matches_any(card, SECRET_BOX_MB):
		return 4300.0 if player.deck.size() > CRITICAL_DECK_FLOOR and not _mb_has_ready_attack(player, current_turn) else 450.0
	return inherited


func _mb_score_ability(
	action: Dictionary,
	player: PlayerState,
	opponent: PlayerState,
	inherited: float
) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null:
		return inherited
	if _matches_any(source, BLAZIKEN_EX_MB):
		return 5600.0 if _mb_discard_has_basic_energy(player) and _mb_has_acceleration_target(player) else -900.0
	if _matches_any(source, MUNKIDORI_MB):
		if not _mb_slot_has_energy_type(source, "D"):
			return -1800.0
		return 5100.0 if _mb_has_damage_to_move(player) and _mb_opponent_has_counter_target(opponent, 30) else -300.0
	if _matches_any(source, FEZANDIPITI_MB):
		if player.deck.size() <= CRITICAL_DECK_FLOOR:
			return -3600.0
		return maxf(inherited, 2600.0)
	return inherited


func _mb_score_attack(
	action: Dictionary,
	player: PlayerState,
	opponent: PlayerState,
	game_state: GameState,
	player_index: int,
	inherited: float
) -> float:
	if str(action.get("kind", "")) == "granted_attack" and _is_tm_evolution_attack(action):
		var tm_route := _mb_first_turn_tm_evolution_route_state(game_state, player_index)
		var tm_route_stage := str(tm_route.get("stage", MB_TM_ROUTE_INACTIVE))
		if tm_route_stage == MB_TM_ROUTE_USE_EVOLUTION \
				and action.get("source_slot", player.active_pokemon) == tm_route.get("owner", null):
			return 6500.0
		if tm_route_stage == MB_TM_ROUTE_INACTIVE:
			return MB_TM_ROUTE_HARD_REJECT_SCORE
		return -1600.0
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	if source == null:
		return inherited
	var projected_ko := bool(action.get("projected_knockout", false))
	var defender := opponent.active_pokemon if opponent != null else null
	var defender_remaining := _mb_remaining_hp(defender)
	if _matches_any(source, BLAZIKEN_EX_MB):
		if projected_ko or (defender_remaining > 0 and defender_remaining <= 200):
			return 7600.0 + float(_mb_prize_value(defender)) * 500.0
		return 4800.0 if _mb_has_ready_backup(player, source, int(game_state.turn_number)) else 4000.0
	if _matches_any(source, BLAZIKEN_MB):
		if projected_ko or (defender_remaining > 0 and defender_remaining <= 120) or _mb_opponent_has_bench_ko(opponent, 120):
			return 7000.0
		return 3900.0
	if _matches_any(source, MIMIKYU_MB):
		return 4300.0 if _mb_opponent_active_is_rule_box(game_state, player_index) else 1900.0
	if _matches_any(source, MUNKIDORI_MB):
		return 3300.0 if projected_ko or (defender_remaining > 0 and defender_remaining <= 60) else 1700.0
	if _matches_any(source, PECHARUNT_MB):
		return 2600.0
	return inherited


func _mb_score_search_card(card: CardInstance, player: PlayerState, step_id: String) -> float:
	if player == null:
		return float(get_search_priority(card))
	if _matches_any(card, RARE_CANDY) and step_id.contains("item") \
			and _has_live_rare_candy_route(player) and _mb_hand_has_any(player, BLAZIKEN_EX_MB):
		return 7000.0
	if _matches_any(card, COMBUSKEN_MB):
		return 6100.0 if _mb_has_slot(player, TORCHIC_MB) else 900.0
	if _matches_any(card, BLAZIKEN_EX_MB):
		if _mb_has_slot(player, COMBUSKEN_MB) or (_has_rare_candy_in_hand(player) and _mb_has_slot(player, TORCHIC_MB)):
			return 6400.0
		return 1000.0
	if _matches_any(card, BLAZIKEN_MB):
		return 5200.0 if _mb_has_slot(player, COMBUSKEN_MB) else 650.0
	if _matches_any(card, TORCHIC_MB):
		return 5000.0 if not _mb_has_slot(player, TORCHIC_MB + COMBUSKEN_MB + BLAZIKEN_EX_MB + BLAZIKEN_MB) else 650.0
	if _matches_any(card, MUNKIDORI_MB):
		return 4700.0 if not _mb_has_slot(player, MUNKIDORI_MB) else 900.0
	if step_id.begins_with("recover") and (_matches_any(card, BLAZIKEN_EX_MB) or _matches_any(card, MUNKIDORI_MB)):
		return 5500.0
	return float(get_search_priority(card))


func _mb_score_discard_energy(card: CardInstance, player: PlayerState) -> float:
	if player == null or not _is_basic_energy(card):
		return -1000.0
	var energy_type := _energy_type(card)
	if energy_type == "D" and not _mb_has_powered_munkidori(player):
		return 6200.0
	if energy_type == "R" and _mb_any_slot_missing_cost(player, BLAZIKEN_EX_MB, "RC"):
		return 5400.0
	if energy_type == "P" and (_mb_has_slot(player, MIMIKYU_MB) or _mb_has_slot(player, MUNKIDORI_MB)):
		return 3900.0
	return 1800.0


func _mb_score_acceleration_target(slot: PokemonSlot, context: Dictionary, player: PlayerState) -> float:
	if slot == null:
		return -2000.0
	var source: CardInstance = context.get("assignment_source", context.get("source_card", null))
	var energy_type := _energy_type(source) if source != null else ""
	if energy_type == "D" and _matches_any(slot, MUNKIDORI_MB) and not _mb_slot_has_energy_type(slot, "D"):
		return 6900.0
	if _matches_any(slot, BLAZIKEN_EX_MB):
		return _mb_attack_completion_score(source, slot, "RC") + 900.0
	if _matches_any(slot, BLAZIKEN_MB):
		return _mb_attack_completion_score(source, slot, "RRC") + 600.0
	if _matches_any(slot, COMBUSKEN_MB) or _matches_any(slot, TORCHIC_MB):
		return 3200.0 if energy_type == "R" else 900.0
	if _matches_any(slot, MIMIKYU_MB):
		return 2800.0 if energy_type == "P" else 350.0
	if _matches_any(slot, MUNKIDORI_MB):
		return 2200.0
	return 100.0 if player != null else 0.0


func _mb_score_damage_source(slot: PokemonSlot) -> float:
	if slot == null or slot.damage_counters <= 0:
		return -1200.0
	var score := float(mini(slot.damage_counters, 30)) * 50.0
	if _matches_any(slot, BLAZIKEN_EX_MB):
		score += 1500.0
	elif _matches_any(slot, MUNKIDORI_MB):
		score += 500.0
	else:
		score += 100.0
	return score


func _mb_score_counter_target(slot: PokemonSlot, damage: int) -> float:
	if slot == null:
		return -1200.0
	var remaining := _mb_remaining_hp(slot)
	var score := float(_mb_prize_value(slot)) * 500.0
	if remaining > 0 and remaining <= damage:
		return 6200.0 + score - float(damage - remaining) * 4.0
	return score + float(slot.damage_counters) * 3.0


func _mb_attack_completion_score(energy: CardInstance, slot: PokemonSlot, cost: String) -> float:
	if energy == null or slot == null:
		return -1200.0
	if bool(predict_attacker_damage(slot).get("can_attack", false)):
		return 250.0
	var required_type := "R" if cost.contains("R") and not _mb_slot_has_energy_type(slot, "R") else ""
	var energy_type := _energy_type(energy)
	if required_type != "" and energy_type == required_type:
		return 5000.0
	var current_count := slot.attached_energy.size()
	var needed_count := 2 if cost == "RC" else 3
	if current_count < needed_count:
		return 3900.0
	return 200.0


func _mb_opening_active_score(card: CardInstance) -> float:
	if _matches_any(card, BUDEW):
		return 10000.0
	if _matches_any(card, MIMIKYU_MB):
		return 9000.0
	if _matches_any(card, PECHARUNT_MB):
		return 8200.0
	if _matches_any(card, SHAYMIN_MB):
		return 7200.0
	if _matches_any(card, MUNKIDORI_MB):
		return 5200.0
	if _matches_any(card, FEZANDIPITI_MB):
		return 3800.0
	if _matches_any(card, TORCHIC_MB):
		return 800.0
	return 1000.0


func _mb_opening_bench_score(card: CardInstance) -> float:
	if _matches_any(card, TORCHIC_MB):
		return 10000.0
	if _matches_any(card, MUNKIDORI_MB):
		return 9000.0
	if _matches_any(card, SHAYMIN_MB):
		return 7200.0
	if _matches_any(card, FEZANDIPITI_MB):
		return 6200.0
	if _matches_any(card, MIMIKYU_MB):
		return 5200.0
	if _matches_any(card, PECHARUNT_MB):
		return 3200.0
	return 500.0


func _mb_setup_debt(
	player: PlayerState,
	current_turn: int = -999,
	tm_route: Dictionary = {}
) -> Dictionary:
	var missing_torchic := 0 if _mb_has_slot(player, TORCHIC_MB + COMBUSKEN_MB + BLAZIKEN_EX_MB + BLAZIKEN_MB) else 1
	var missing_engine := 0 if _mb_has_slot(player, BLAZIKEN_EX_MB) else 1
	var missing_munkidori := 0 if _mb_has_slot(player, MUNKIDORI_MB) else 1
	var missing_dark := 0 if _mb_has_powered_munkidori(player) else 1
	var missing_backup := 0 if _mb_ready_attacker_count(player, current_turn) >= 2 else 1
	var tm_first_turn := int(tm_route.get("debt", 0))
	return {
		"missing_torchic_lane": missing_torchic,
		"missing_blaziken_engine": missing_engine,
		"missing_munkidori": missing_munkidori,
		"missing_dark_munkidori": missing_dark,
		"missing_ready_backup": missing_backup,
		"tm_evolution_first_turn": tm_first_turn,
		"total": missing_torchic + missing_engine + missing_munkidori + missing_dark + missing_backup + tm_first_turn,
	}


func _mb_best_route_owner(player: PlayerState, current_turn: int = -999) -> PokemonSlot:
	var best: PokemonSlot = null
	var best_score := -100000.0
	for slot: PokemonSlot in _all_slots(player):
		var score := 0.0
		var ready := bool(predict_attacker_damage(slot).get("can_attack", false))
		if _matches_any(slot, BLAZIKEN_EX_MB):
			score = 5000.0 if ready and not _mb_attack_locked(slot, current_turn) else 2500.0
		elif _matches_any(slot, BLAZIKEN_MB):
			score = 4300.0 if ready else 2100.0
		elif _matches_any(slot, MIMIKYU_MB):
			score = 3000.0 if ready else 1200.0
		elif _matches_any(slot, COMBUSKEN_MB):
			score = 1500.0
		elif _matches_any(slot, TORCHIC_MB):
			score = 900.0
		elif _matches_any(slot, MUNKIDORI_MB):
			score = 1800.0 if ready else 700.0
		if slot == player.active_pokemon:
			score += 150.0
		if score > best_score:
			best_score = score
			best = slot
	return best


func _mb_bridge_name(player: PlayerState, current_turn: int = -999) -> String:
	if not _mb_has_slot(player, BLAZIKEN_EX_MB):
		return "火焰鸡ex"
	if not _mb_has_powered_munkidori(player):
		return "愿增猿"
	if _mb_ready_attacker_count(player, current_turn) < 2:
		return "火焰鸡"
	return "火焰鸡ex"


func _mb_turn_intent(phase: String) -> String:
	match phase:
		"setup":
			return "seed_blaziken_and_munkidori_routes"
		"launch":
			return "launch_boiling_spirit_energy_cycle"
		"convert":
			return "convert_damage_and_rotate_attackers"
		"rebuild":
			return "rebuild_blaziken_energy_engine"
		"close":
			return "close_prizes_with_exact_damage_transfer"
	return "advance_blaziken_route"


func _mb_tm_route_live(player: PlayerState) -> bool:
	return _mb_tm_evolution_bridge(player) != null


func _mb_first_turn_tm_evolution_route_state(game_state: GameState, player_index: int) -> Dictionary:
	var inactive := {
		"stage": MB_TM_ROUTE_INACTIVE,
		"debt": 0,
		"owner": null,
		"bridge": null,
		"owner_name": "",
		"bridge_name": "",
	}
	if not _is_second_player_first_turn(game_state, player_index):
		return inactive
	var player: PlayerState = game_state.players[player_index]
	var owner: PokemonSlot = player.active_pokemon
	if owner == null or not _matches_any(owner, PECHARUNT_TM_CARRIER):
		return inactive
	var bridge := _mb_tm_evolution_bridge(player)
	if bridge == null:
		return inactive
	if owner.attached_tool != null and not _slot_has_tm_evolution(owner):
		return inactive
	var stage := MB_TM_ROUTE_ATTACH_TM
	if _slot_has_tm_evolution(owner):
		stage = MB_TM_ROUTE_USE_EVOLUTION if _mb_slot_has_energy_type(owner, "R") else MB_TM_ROUTE_ATTACH_ACTIVE_FIRE
	return {
		"stage": stage,
		"debt": 1,
		"owner": owner,
		"bridge": bridge,
		"owner_name": _display_name(owner),
		"bridge_name": _display_name(bridge),
	}


func _mb_tm_evolution_bridge(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var has_combusken := false
	for card: CardInstance in player.deck:
		if _matches_any(card, COMBUSKEN_MB):
			has_combusken = true
			break
	if not has_combusken:
		return null
	for slot: PokemonSlot in player.bench:
		if _matches_any(slot, TORCHIC_MB):
			return slot
	return null


func _mb_has_productive_setup_action(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null:
		return false
	if str(_mb_first_turn_tm_evolution_route_state(game_state, player_index).get("stage", MB_TM_ROUTE_INACTIVE)) != MB_TM_ROUTE_INACTIVE:
		return true
	for card: CardInstance in player.hand:
		if card == null:
			continue
		if card.is_basic_pokemon() and not player.is_bench_full() and _mb_score_basic_to_bench(card, player) >= 2000.0:
			return true
		if (_matches_any(card, COMBUSKEN_MB) or _matches_any(card, BLAZIKEN_EX_MB) or _matches_any(card, BLAZIKEN_MB)) \
				and _mb_has_playable_evolution_search(player):
			return true
	return false


func _mb_has_playable_evolution_search(player: PlayerState) -> bool:
	if player == null:
		return false
	if _mb_has_slot(player, TORCHIC_MB):
		return true
	return _mb_has_slot(player, COMBUSKEN_MB)


func _mb_missing_basic_route(player: PlayerState) -> bool:
	return not _mb_has_slot(player, TORCHIC_MB + COMBUSKEN_MB + BLAZIKEN_EX_MB + BLAZIKEN_MB) \
		or not _mb_has_slot(player, MUNKIDORI_MB)


func _mb_missing_route_energy(player: PlayerState) -> bool:
	return not _mb_has_powered_munkidori(player) or _mb_any_slot_missing_cost(player, BLAZIKEN_EX_MB, "RC")


func _mb_should_bank_attack_energy_before_ultra(player: PlayerState, current_turn: int) -> bool:
	if player == null or _mb_has_ready_attack(player, current_turn):
		return false
	if not _mb_has_slot(player, COMBUSKEN_MB):
		return false
	if not _mb_hand_has_any(player, ULTRA_BALL) or not _mb_hand_has_any(player, EARTHEN_VESSEL):
		return false
	if _mb_hand_has_basic_energy(player) or not _mb_discard_has_basic_energy(player):
		return false
	if not _mb_deck_has_any(player, BLAZIKEN_EX_MB) or not _mb_deck_has_basic_energy(player):
		return false
	return _mb_count_basic_energy(player, "R") > 0


func _mb_discard_has_route_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if _matches_any(card, TORCHIC_MB + COMBUSKEN_MB + BLAZIKEN_EX_MB + BLAZIKEN_MB + MUNKIDORI_MB) or _is_basic_energy(card):
			return true
	return false


func _mb_discard_has_missing_route_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	var has_torchic := _mb_has_slot(player, TORCHIC_MB)
	var has_combusken := _mb_has_slot(player, COMBUSKEN_MB)
	var has_blaziken := _mb_has_slot(player, BLAZIKEN_EX_MB + BLAZIKEN_MB)
	var has_munkidori := _mb_has_slot(player, MUNKIDORI_MB)
	for card: CardInstance in player.discard_pile:
		if _matches_any(card, TORCHIC_MB) and not (has_torchic or has_combusken or has_blaziken):
			return true
		if _matches_any(card, COMBUSKEN_MB) and has_torchic and not (has_combusken or has_blaziken):
			return true
		if _matches_any(card, BLAZIKEN_EX_MB + BLAZIKEN_MB) and (has_torchic or has_combusken) and not has_blaziken:
			return true
		if _matches_any(card, MUNKIDORI_MB) and not has_munkidori:
			return true
	return false


func _mb_discard_has_basic_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if _is_basic_energy(card):
			return true
	return false


func _mb_has_acceleration_target(player: PlayerState) -> bool:
	if player == null:
		return false
	if not _mb_has_powered_munkidori(player) and _mb_has_slot(player, MUNKIDORI_MB):
		return true
	for slot: PokemonSlot in _all_slots(player):
		if (_matches_any(slot, BLAZIKEN_EX_MB) or _matches_any(slot, BLAZIKEN_MB)) \
				and not bool(predict_attacker_damage(slot).get("can_attack", false)):
			return true
	return false


func _mb_has_ready_attack(player: PlayerState, current_turn: int = -999) -> bool:
	return _mb_ready_attacker_count(player, current_turn) > 0


func _mb_ready_attacker_count(player: PlayerState, current_turn: int = -999) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _mb_attack_locked(slot, current_turn):
			continue
		if bool(predict_attacker_damage(slot).get("can_attack", false)):
			count += 1
	return count


func _mb_has_ready_backup(player: PlayerState, excluded: PokemonSlot, current_turn: int = -999) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == excluded or _mb_attack_locked(slot, current_turn):
			continue
		if bool(predict_attacker_damage(slot).get("can_attack", false)):
			return true
	return false


func _mb_attack_locked(slot: PokemonSlot, current_turn: int = -999) -> bool:
	if slot == null:
		return false
	for effect_data: Dictionary in slot.effects:
		if str(effect_data.get("type", "")) not in ["attack_lock", "attack_lock_all"]:
			continue
		if current_turn == -999 or int(effect_data.get("turn", -999)) == current_turn - 2:
			return true
	return false


func _mb_any_slot_missing_cost(player: PlayerState, names: Array[String], cost: String) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, names) and not bool(predict_attacker_damage(slot).get("can_attack", false)):
			if cost == "" or slot.attached_energy.size() < cost.length():
				return true
	return false


func _mb_slot_has_energy_type(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _energy_can_pay(energy, energy_type, slot):
			return true
	return false


func _mb_has_powered_munkidori(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, MUNKIDORI_MB) and _mb_slot_has_energy_type(slot, "D"):
			return true
	return false


func _mb_unpowered_fire_seed_line(player: PlayerState) -> bool:
	if player == null:
		return false
	var has_seed_line := false
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_any(slot, TORCHIC_MB + COMBUSKEN_MB):
			continue
		has_seed_line = true
		if _mb_slot_has_energy_type(slot, "R"):
			return false
	return has_seed_line


func _mb_has_damage_to_move(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot.damage_counters > 0:
			return true
	return false


func _mb_opponent_has_counter_target(opponent: PlayerState, damage: int) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		if _mb_remaining_hp(slot) > 0:
			return true
	return false


func _mb_opponent_has_bench_ko(opponent: PlayerState, damage: int) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.bench:
		var remaining := _mb_remaining_hp(slot)
		if remaining > 0 and remaining <= damage:
			return true
	return false


func _mb_opponent_active_is_rule_box(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	var data := opponent.active_pokemon.get_card_data()
	return data != null and str(data.mechanic).to_lower() in ["ex", "v", "vstar", "vmax"]


func _mb_remaining_hp(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	return maxi(0, int(slot.get_card_data().hp) - int(slot.damage_counters))


func _mb_prize_value(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 1
	var mechanic := str(slot.get_card_data().mechanic).to_lower()
	if mechanic == "vmax":
		return 3
	if mechanic in ["ex", "v", "vstar"]:
		return 2
	return 1


func _mb_has_slot(player: PlayerState, names: Array[String]) -> bool:
	return _mb_count_slots(player, names) > 0


func _mb_hand_has_any(player: PlayerState, names: Array[String]) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _matches_any(card, names):
			return true
	return false


func _mb_hand_has_basic_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _is_basic_energy(card):
			return true
	return false


func _mb_deck_has_any(player: PlayerState, names: Array[String]) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _matches_any(card, names):
			return true
	return false


func _mb_deck_has_basic_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _is_basic_energy(card):
			return true
	return false


func _mb_has_blaziken_ex_access(player: PlayerState) -> bool:
	if player == null:
		return false
	for pile: Array in [player.hand, player.deck]:
		for card: CardInstance in pile:
			if _matches_any(card, BLAZIKEN_EX_MB):
				return true
	return false


func _mb_count_slots(player: PlayerState, names: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, names):
			count += 1
	return count


func _mb_count_basic_energy(player: PlayerState, energy_type: String) -> int:
	if player == null:
		return 0
	var count := 0
	for pile: Array in [player.hand, player.deck, player.discard_pile]:
		for card: CardInstance in pile:
			if _is_basic_energy(card) and _energy_type(card) == energy_type:
				count += 1
	return count


func _mb_basic_role(item: Variant) -> String:
	if _matches_any(item, TORCHIC_MB):
		return "blaziken_seed"
	if _matches_any(item, MUNKIDORI_MB):
		return "damage_mover"
	if _matches_any(item, MIMIKYU_MB) or _matches_any(item, PECHARUNT_MB):
		return "pivot"
	if _matches_any(item, SHAYMIN_MB) or _matches_any(item, FEZANDIPITI_MB):
		return "support"
	return ""
