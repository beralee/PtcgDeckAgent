class_name DeckStrategyV18DragapultFamily
extends "res://scripts/ai/DeckStrategyV18Stage2Core.gd"


const VARIANT_CHARIZARD := "charizard"
const VARIANT_DUSKNOIR := "dusknoir"
const VARIANT_PURE := "pure"
const VARIANT_BLAZIKEN := "blaziken"

const BLAZIKEN_DRAGAPULT_DECK_ID := 800019125
const CURSE_BLAST_DRAGAPULT_DECK_ID := 800015734
const ROUTE_CORE_DISCARD_PRIORITY := -1200
const TM_ENERGY_SEARCH_SCORE := 6400.0
const BROKEN_ROUTE_ULTRA_BALL_SCORE := -5200.0
const NO_LANE_ENERGY_RESERVE_SCORE := -5200.0
const BLAZIKEN_LOW_DECK_DRAKLOAK_ABILITY_SCORE := -4000.0
const CURSE_BLAST_DEFERRED_ATTACK_SCORE := 2400.0
const ACTIVE_PHANTOM_DIVE_ATTACHMENT_URGENCY_SCORE := 2400.0
const PHANTOM_DIVE_ACTIVE_DAMAGE := 200
const PHANTOM_DIVE_BENCH_DAMAGE := 60

const RADIANT_ALAKAZAM_EFFECT_ID := "68244d82147e13bb7d77116ffedf6162"
const CHI_YU_EFFECT_ID := "4e1e775eaafb11028f5378ede92cb964"
const ROTOM_FAST_CHARGE_EFFECT_ID := "8ef5ff61fd97838af568f00fe3b0e3ea"
const CHI_YU: Array[String] = [CHI_YU_EFFECT_ID, "Chi-Yu"]
const ROTOM_V: Array[String] = ["Rotom V", "洛托姆V"]

const ALAKAZAM_SOURCE_STEP := "source_pokemon"
const ALAKAZAM_TARGET_STEP := "target_pokemon"
const ALAKAZAM_COUNTER_STEP := "counter_count"
const CHI_YU_ENERGY_STEP := "discard_energy"
const CHI_YU_TARGET_STEP := "attach_target"

const DREEPY: Array[String] = ["Dreepy", "多龙梅西亚"]
const DRAKLOAK: Array[String] = ["Drakloak", "多龙奇"]
const DRAGAPULT_EX: Array[String] = ["Dragapult ex", "多龙巴鲁托ex"]
const BUDEW: Array[String] = ["Budew", "含羞苞"]
const MUNKIDORI: Array[String] = ["Munkidori", "愿增猿"]
const HAWLUCHA: Array[String] = ["Hawlucha", "摔角鹰人"]
const CACTURNE_PIVOT: Array[String] = ["Cacnea", "沙铃仙人掌"]
const BLOODMOON_URSALUNA: Array[String] = ["Bloodmoon Ursaluna ex", "月月熊 赫月ex"]

const CHARMANDER: Array[String] = ["Charmander", "小火龙"]
const CHARMELEON: Array[String] = ["Charmeleon", "火恐龙"]
const CHARIZARD_EX: Array[String] = ["Charizard ex", "喷火龙ex"]

const DUSKULL: Array[String] = ["Duskull", "夜巡灵"]
const DUSCLOPS: Array[String] = ["Dusclops", "彷徨夜灵"]
const DUSKNOIR: Array[String] = ["Dusknoir", "黑夜魔灵"]

const TORCHIC: Array[String] = ["Torchic", "火稚鸡"]
const COMBUSKEN: Array[String] = ["Combusken", "力壮鸡"]
const BLAZIKEN_EX: Array[String] = ["Blaziken ex", "火焰鸡ex"]

const RARE_CANDY: Array[String] = ["Rare Candy", "神奇糖果"]
const TM_EVOLUTION: Array[String] = ["Technical Machine: Evolution", "招式学习器 进化"]
const BUDDY_BUDDY_POFFIN: Array[String] = ["Buddy-Buddy Poffin", "友好宝芬"]
const ULTRA_BALL: Array[String] = ["Ultra Ball", "高级球"]
const EARTHEN_VESSEL: Array[String] = ["Earthen Vessel", "大地容器"]
const NIGHT_STRETCHER: Array[String] = ["Night Stretcher", "夜间担架"]
const SUPER_ROD: Array[String] = ["Super Rod", "厉害钓竿"]
const BOSSS_ORDERS: Array[String] = ["Boss's Orders", "老大的指令"]
const ARTAZON: Array[String] = ["Artazon", "深钵镇"]
const AIR_BALLOON: Array[String] = ["Air Balloon", "气球"]
const SPARKLING_CRYSTAL: Array[String] = ["Sparkling Crystal", "璀璨结晶"]
const FOREST_SEAL_STONE: Array[String] = ["Forest Seal Stone", "森林封印石"]

const LUMINOUS_ENERGY_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"
const NEO_UPPER_ENERGY_EFFECT_ID := "83aba7d0c92c81e8c03b3785af695c2f"

const DRAGAPULT_COLORS: Array[String] = ["R", "P"]

var _family_variant := VARIANT_PURE
var _family_has_tm_evolution := false


func configure_from_deck(deck: DeckData) -> void:
	super.configure_from_deck(deck)
	_family_has_tm_evolution = false
	match _deck_id:
		18000230:
			_family_variant = VARIANT_CHARIZARD
		800015734:
			_family_variant = VARIANT_DUSKNOIR
		800019125:
			_family_variant = VARIANT_BLAZIKEN
		_:
			_family_variant = VARIANT_PURE
	for card: CardData in _deck_cards:
		if _matches_any(card, TM_EVOLUTION):
			_family_has_tm_evolution = true
			break


func get_strategy_id() -> String:
	return "v18_dragapult_family_%d" % _deck_id


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var candidates: Array[Dictionary] = []
	for index: int in player.hand.size():
		var card: CardInstance = player.hand[index]
		if card == null or not card.is_basic_pokemon():
			continue
		candidates.append({
			"index": index,
			"active": _opening_active_score_for(card),
			"bench": _opening_bench_score_for(card),
		})
	if candidates.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("active", 0.0)) > float(b.get("active", 0.0))
	)
	var active_index := int(candidates[0].get("index", -1))
	var bench_candidates := candidates.duplicate(true)
	bench_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("bench", 0.0)) > float(b.get("bench", 0.0))
	)
	var bench_indices: Array[int] = []
	for entry: Dictionary in bench_candidates:
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
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var owner := _best_dragapult_route_slot(player)
	var owner_name := _display_name(owner) if owner != null else "Dragapult ex"
	var bridge_name := _bridge_name(player)
	var ready := owner != null and _dragapult_phantom_ready(owner)
	var debt := _dragapult_setup_debt(player)
	var phase := "setup"
	if owner != null:
		phase = "convert" if ready else "launch"
	if ready and player.prizes.size() <= 2:
		phase = "close"
	elif owner == null and int(game_state.turn_number) > 2:
		phase = "rebuild"
	var opening_route := _opening_route(game_state, player_index)
	var plan := {
		"id": "v18_dragapult_family_%d:%s" % [_deck_id, phase],
		"intent": _turn_intent(phase, opening_route),
		"phase": phase,
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": owner_name,
		},
		"targets": {
			"primary_attacker_name": "Dragapult ex",
			"bridge_target_name": bridge_name,
			"damage_counter_route": _damage_counter_route_name(),
		},
		"priorities": {
			"attach": _attach_priorities(player),
			"handoff": ["Dragapult ex", "多龙巴鲁托ex", bridge_name],
			"search": _search_priorities(player),
			"evolve": _evolution_priorities(),
			"ability": _ability_priorities(),
			"trainer": _profile_list("trainer_priority"),
		},
		"flags": {
			"dragapult_family": true,
			"family_variant": _family_variant,
			"opening_route": opening_route,
			"phantom_dive_ready": ready,
			"missing_dragapult_colors": _missing_dragapult_colors(owner),
			"setup_debt": debt,
			"allow_resource_paid_owner_retreat": false,
		},
		"constraints": {
			"forbid_engine_churn": player.deck.size() <= 8 and ready,
			"forbid_extra_bench_padding": player.bench.size() >= 4 and int(debt.get("total", 0)) <= 0,
		},
		"context": context.duplicate(true),
	}
	return plan


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var debt := _dragapult_setup_debt(player)
	var ready := _has_ready_dragapult(player)
	var setup_live := int(debt.get("total", 0)) > 0
	var safe_setup_before_attack := ready and setup_live
	if _deck_id == CURSE_BLAST_DRAGAPULT_DECK_ID:
		safe_setup_before_attack = setup_live and not ready
	var bonuses: Array[Dictionary] = [
		{
			"kind": "play_basic_to_bench",
			"card_names": ["Dreepy", "多龙梅西亚"],
			"bonus": 520.0 if int(debt.get("missing_dragapult_seed", 0)) > 0 else 160.0,
		},
		{
			"kind": "evolve",
			"card_names": ["Drakloak", "多龙奇", "Dragapult ex", "多龙巴鲁托ex"],
			"bonus": 720.0 if int(debt.get("backup_dragapult_gap", 0)) > 0 else 220.0,
		},
		{
			"kind": "attach_energy",
			"target_names": ["Dreepy", "多龙梅西亚", "Drakloak", "多龙奇", "Dragapult ex", "多龙巴鲁托ex"],
			"bonus": 520.0 if int(debt.get("missing_attack_colors", 0)) > 0 else 100.0,
		},
		{
			"kind": "use_ability",
			"target_names": ["Drakloak", "多龙奇", "Blaziken ex", "火焰鸡ex"],
			"bonus": 260.0,
		},
	]
	if _family_variant != VARIANT_PURE:
		bonuses.append({
			"kind": "play_basic_to_bench",
			"card_names": _partner_seed_names(),
			"bonus": 420.0 if int(debt.get("missing_partner_seed", 0)) > 0 else 80.0,
		})
		bonuses.append({
			"kind": "evolve",
			"card_names": _partner_stage1_names() + _partner_stage2_names(),
			"bonus": 360.0 if int(debt.get("partner_chain_gap", 0)) > 0 else 60.0,
		})
	return {
		"enabled": true,
		"safe_setup_before_attack": safe_setup_before_attack,
		"setup_debt": debt,
		"action_bonuses": bonuses,
		"attack_penalty": 1050.0,
		"turn_contract_id": str(turn_contract.get("id", "")),
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var kind := str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			return _score_basic_to_bench(action.get("card", null), player, game_state)
		"evolve":
			return _score_evolution_action(action, player, opponent)
		"attach_energy":
			return _score_energy_attachment(action, player, game_state)
		"attach_tool":
			return _score_tool_attachment(action, player, game_state, player_index)
		"play_stadium":
			return _score_stadium_action_family(action, player, game_state, score)
		"play_trainer":
			return _score_trainer_action_family(action, player, game_state, player_index, score)
		"use_ability":
			return _score_ability_action_family(action, player, opponent, game_state, player_index, score)
		"retreat":
			return _score_retreat_action_family(action, player, score)
		"attack", "granted_attack":
			return _score_attack_action_family(action, player, opponent, game_state, player_index, score)
		"end_turn":
			if _productive_setup_debt(player) or _second_player_tm_route_live(player, game_state, player_index):
				return -2600.0
	return score


func _score_stadium_action_family(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	base_score: float
) -> float:
	var stadium: Variant = action.get("card", null)
	if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
			and _matches_any(stadium, ARTAZON) \
			and game_state.stadium_card == null \
			and player != null and player.bench.size() >= 5:
		return -3000.0
	return base_score


func score_action_absolute_with_plan(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	_turn_plan: Dictionary = {}
) -> float:
	# V18Rules owns continuity application after it merges this delegate's contract.
	return score_action_absolute(action, game_state, player_index)


func get_discard_priority(card: CardInstance) -> int:
	if _matches_any(card, DRAGAPULT_EX):
		return 3
	if _matches_any(card, DRAKLOAK):
		return 5
	if _matches_any(card, DREEPY):
		return 8
	if _matches_any(card, _partner_stage2_names()):
		return 7
	if _matches_any(card, _partner_stage1_names()):
		return 10
	if _matches_any(card, _partner_seed_names()):
		return 12
	if _matches_any(card, RARE_CANDY) or _matches_any(card, TM_EVOLUTION):
		return 9
	if _matches_any(card, NIGHT_STRETCHER) or _matches_any(card, SUPER_ROD):
		return 11
	if _is_dragapult_energy(card):
		return 8
	if _matches_any(card, ["Luminous Energy", "夜光能量", "Neo Upper Energy", "新冲天能量"]):
		return 5
	return super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var base_priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return base_priority
	var player: PlayerState = game_state.players[player_index]
	if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID and _is_basic_energy(card):
		var energy_type := _energy_type(card)
		if energy_type in DRAGAPULT_COLORS \
				and not _has_ready_dragapult(player) \
				and _count_accessible_basic_energy(player, energy_type) <= 1:
			return ROUTE_CORE_DISCARD_PRIORITY
		if _count_accessible_basic_energy(player, energy_type) >= 2 and _has_slot(player, BLAZIKEN_EX):
			return 135
	if (_matches_any(card, BUDDY_BUDDY_POFFIN) or _matches_any(card, ULTRA_BALL)) \
			and player.is_bench_full():
		return 180
	return base_priority


func get_search_priority(card: CardInstance) -> int:
	if _matches_any(card, DRAGAPULT_EX):
		return 1200
	if _matches_any(card, DRAKLOAK):
		return 1160
	if _matches_any(card, DREEPY):
		return 1080
	if _matches_any(card, _partner_stage2_names()):
		return 930
	if _matches_any(card, _partner_stage1_names()):
		return 980
	if _matches_any(card, _partner_seed_names()):
		return 850
	if _matches_any(card, MUNKIDORI):
		return 720
	if _is_dragapult_energy(card):
		return 780
	return super.get_search_priority(card)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if items.is_empty():
		return []
	var step_id := str(step.get("id", "")).to_lower()
	var max_select := maxi(1, int(step.get("max_select", 1)))
	if _deck_id == CURSE_BLAST_DRAGAPULT_DECK_ID and step_id == "self_ko_target":
		return _pick_ranked_interaction_items(items, step, context, 1)
	if _interaction_uses_effect(context, RADIANT_ALAKAZAM_EFFECT_ID):
		if step_id == ALAKAZAM_COUNTER_STEP:
			for item: Variant in items:
				if int(item) == 2:
					return [item]
		if step_id in [ALAKAZAM_SOURCE_STEP, ALAKAZAM_TARGET_STEP]:
			return _pick_ranked_interaction_items(items, step, context, 1)
	if _interaction_uses_effect(context, CHI_YU_EFFECT_ID):
		if step_id == CHI_YU_ENERGY_STEP:
			return _pick_ranked_interaction_items(items, step, context, max_select, true)
		if step_id == CHI_YU_TARGET_STEP:
			return _pick_ranked_interaction_items(items, step, context, 1)
	if max_select > 1 and step_id in ["buddy_poffin_pokemon", "basic_pokemon", "bench_pokemon"]:
		return _pick_diverse_basic_routes(items, max_select, step, context)
	return super.pick_interaction_items(items, step, context)


func _pick_ranked_interaction_items(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	select_count: int,
	require_positive_score: bool = false
) -> Array:
	if items.is_empty() or select_count <= 0:
		return []
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		ranked.append({
			"item": items[index],
			"score": score_interaction_target(items[index], step, context),
			"order": index,
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", 0.0))
		var right_score := float(right.get("score", 0.0))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)
	var selected: Array = []
	for entry: Dictionary in ranked:
		if require_positive_score and float(entry.get("score", 0.0)) <= 0.0:
			continue
		selected.append(entry.get("item"))
		if selected.size() >= mini(select_count, items.size()):
			break
	return selected


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	var alakazam_interaction := _interaction_uses_effect(context, RADIANT_ALAKAZAM_EFFECT_ID)
	var chi_yu_interaction := _interaction_uses_effect(context, CHI_YU_EFFECT_ID)
	if alakazam_interaction and step_id == ALAKAZAM_COUNTER_STEP:
		return float(int(item)) * 1000.0
	if item is CardInstance:
		var card := item as CardInstance
		if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
				and step_id == "search_item" \
				and _second_player_tm_energy_search_live(player, context) \
				and _matches_any(card, EARTHEN_VESSEL):
			return TM_ENERGY_SEARCH_SCORE
		if chi_yu_interaction and step_id == CHI_YU_ENERGY_STEP:
			return _score_chi_yu_discard_energy(card)
		if step_id.contains("discard") and step_id != "attach_basic_energy_from_discard":
			return float(get_discard_priority_contextual(
				card,
				context.get("game_state", null),
				int(context.get("player_index", -1))
			))
		if step_id in ["attach_basic_energy_from_discard", "energy_assignments"] and card.card_data != null and card.card_data.is_energy():
			return _score_acceleration_energy(card, player, step_id)
		if step_id in ["look_top_pick", "search_pokemon", "search_cards", "stage2_card", "evolution_cards", "basic_pokemon", "bench_pokemon", "buddy_poffin_pokemon", "recover_target", "recover_card"]:
			return _score_search_card_family(card, player, step_id)
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if alakazam_interaction and step_id == ALAKAZAM_SOURCE_STEP:
			return _score_radiant_alakazam_source(slot)
		if alakazam_interaction and step_id == ALAKAZAM_TARGET_STEP:
			return _score_damage_counter_target(slot, 20, false, context)
		if chi_yu_interaction and step_id == CHI_YU_TARGET_STEP:
			return _score_chi_yu_attach_target(slot)
		if step_id == "target_pokemon" and _selected_stage2_from_context(context) != null:
			return _score_rare_candy_target(slot, context)
		if step_id == "self_ko_target":
			return _score_damage_counter_target(
				slot,
				_curse_blast_damage_from_context(context),
				false,
				context
			)
		if step_id == "bench_damage_counters":
			return _score_damage_counter_target(slot, 60, true, context)
		if step_id in ["target_damage_counters", "opponent_pokemon_damage_counter_target", "bench_target"]:
			return _score_damage_counter_target(slot, 30, false, context)
		if step_id == "source_pokemon":
			return _score_munkidori_source(slot)
		if step_id in ["attach_basic_energy_from_discard", "energy_assignments", "assignment_target", "attach_energy_target", "energy_target"]:
			return _score_acceleration_target(slot, context, player, step_id)
		if step_id == "evolution_bench":
			return _score_tm_evolution_seed(slot, player)
		if step_id.contains("switch") or step_id.contains("send") or step_id.contains("handoff") or step_id.contains("active"):
			return score_handoff_target(slot, step, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not item is PokemonSlot:
		return super.score_handoff_target(item, step, context)
	var slot := item as PokemonSlot
	if _matches_any(slot, DRAGAPULT_EX):
		return 5200.0 if _dragapult_phantom_ready(slot) else 3100.0 - float(_missing_dragapult_colors(slot).size()) * 250.0
	if _matches_any(slot, DRAKLOAK):
		return 1900.0
	if _matches_any(slot, BLOODMOON_URSALUNA):
		return 2600.0 if bool(predict_attacker_damage(slot).get("can_attack", false)) else 500.0
	if _matches_any(slot, BLAZIKEN_EX) or _matches_any(slot, CHARIZARD_EX):
		return 1800.0 if bool(predict_attacker_damage(slot).get("can_attack", false)) else 700.0
	if _matches_any(slot, BUDEW) or _matches_any(slot, CACTURNE_PIVOT):
		return 250.0
	return super.score_handoff_target(item, step, context)


func _score_basic_to_bench(card: Variant, player: PlayerState, game_state: GameState) -> float:
	if _matches_any(card, DREEPY):
		var lanes := _dragapult_lane_count(player)
		return 4700.0 if lanes == 0 else (3600.0 if lanes == 1 else 500.0)
	if _matches_any(card, _partner_seed_names()):
		return 4100.0 if not _has_partner_lane(player) else 550.0
	if _matches_any(card, MUNKIDORI):
		if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
				and player.deck.size() <= 4 \
				and player.bench.size() >= 4 \
				and _has_ready_dragapult(player) \
				and not _munkidori_energy_accessible(player):
			return -3000.0
		return 2400.0 if _has_damage_to_move(player) or _family_variant == VARIANT_BLAZIKEN else 950.0
	if _matches_any(card, HAWLUCHA):
		return 2300.0 if _opponent_bench_has_counter_conversion(game_state, player.player_index, 10) else 300.0
	if _matches_any(card, CACTURNE_PIVOT):
		return 900.0 if player.active_pokemon == null else 250.0
	if _matches_any(card, BLOODMOON_URSALUNA):
		return 1500.0 if player.prizes.size() <= 2 else 150.0
	return 120.0


func _munkidori_energy_accessible(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null \
				and (_energy_type(card) in ["D", "ANY"] \
					or card.card_data.effect_id == LUMINOUS_ENERGY_EFFECT_ID):
			return true
	for card: CardInstance in player.discard_pile:
		if _is_basic_energy(card) and _energy_type(card) == "D":
			return true
	return false


func _score_evolution_action(action: Dictionary, player: PlayerState, opponent: PlayerState) -> float:
	var card: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if _matches_any(card, DRAKLOAK):
		return 5000.0 if target != null and _matches_any(target, DREEPY) else -1600.0
	if _matches_any(card, DRAGAPULT_EX):
		if target == null or not (_matches_any(target, DRAKLOAK) or _matches_any(target, DREEPY)):
			return -1800.0
		var score := 5600.0 if _matches_any(target, DRAKLOAK) else 5200.0
		if _matches_any(target, DREEPY) and not _has_rare_candy_in_hand(player):
			return -1800.0
		if _dragapult_lane_count(player) >= 2 and _has_ready_dragapult(player):
			score -= 900.0
		return score
	if _matches_any(card, DUSCLOPS):
		return 3400.0 if target != null and _matches_any(target, DUSKULL) else -1400.0
	if _matches_any(card, DUSKNOIR):
		if target == null or not (_matches_any(target, DUSCLOPS) or _matches_any(target, DUSKULL)):
			return -1400.0
		var best := _best_damage_counter_target_score(opponent, 130, false, {})
		return 4300.0 if best >= 3000.0 else 2500.0
	if _matches_any(card, CHARMELEON) or _matches_any(card, COMBUSKEN):
		return 3300.0 if target != null and _matches_any(target, _partner_seed_names()) else -1200.0
	if _matches_any(card, CHARIZARD_EX):
		if target == null or not (_matches_any(target, CHARMELEON) or (_matches_any(target, CHARMANDER) and _has_rare_candy_in_hand(player))):
			return -1400.0
		return 4300.0 + (700.0 if _any_dragapult_missing_color(player, "R") else 0.0)
	if _matches_any(card, BLAZIKEN_EX):
		if target == null or not (_matches_any(target, COMBUSKEN) or (_matches_any(target, TORCHIC) and _has_rare_candy_in_hand(player))):
			return -1400.0
		return 4500.0 if _discard_has_useful_basic_energy(player) else 3600.0
	return 0.0


func _score_energy_attachment(action: Dictionary, player: PlayerState, game_state: GameState) -> float:
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if energy == null or target == null:
		return -2000.0
	if _blaziken_active_retreat_payment_bridges_handoff(energy, target, player):
		return 7600.0
	if _second_player_tm_route_live(player, game_state, player.player_index) \
			and target == player.active_pokemon \
			and _slot_has_tm_evolution(target) \
			and target.attached_energy.is_empty():
		return 5600.0
	if _matches_any(target, DRAGAPULT_EX) or _matches_any(target, DRAKLOAK) or _matches_any(target, DREEPY):
		var completion_score := _dragapult_energy_completion_score(energy, target)
		if _active_phantom_dive_attachment_is_urgent(energy, target, player):
			completion_score += ACTIVE_PHANTOM_DIVE_ATTACHMENT_URGENCY_SCORE
		return completion_score
	if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
			and _dragapult_lane_count(player) == 0 \
			and _is_basic_energy(energy) \
			and _energy_type(energy) in DRAGAPULT_COLORS:
		if _energy_type(energy) == "R":
			if _matches_any(target, TORCHIC) or _matches_any(target, COMBUSKEN) or _matches_any(target, BLAZIKEN_EX):
				return 1400.0
			if _matches_any(target, CHI_YU) and _chi_yu_manual_acceleration_route_live(player, target):
				return 3000.0
		return NO_LANE_ENERGY_RESERVE_SCORE
	if _matches_any(target, MUNKIDORI):
		if _energy_can_pay(energy, "D", target) and _has_damage_to_move(player):
			return 3000.0
		return -900.0
	if _matches_any(target, CHARIZARD_EX) or _matches_any(target, CHARMELEON) or _matches_any(target, CHARMANDER):
		return 1600.0 if _energy_can_pay(energy, "R", target) and not _has_ready_dragapult(player) else 200.0
	if _matches_any(target, BLAZIKEN_EX):
		return 1400.0 if _energy_can_pay(energy, "R", target) else -500.0
	return -700.0 if _dragapult_lane_count(player) > 0 else 250.0


func _blaziken_active_retreat_payment_bridges_handoff(
	energy: CardInstance,
	target: PokemonSlot,
	player: PlayerState
) -> bool:
	if _deck_id != BLAZIKEN_DRAGAPULT_DECK_ID or player == null \
			or target == null or target != player.active_pokemon \
			or not _matches_any(target, BLAZIKEN_EX) or not _energy_can_pay(energy, "R", target):
		return false
	var retreat_cost := target.get_retreat_cost()
	if retreat_cost <= 0 or target.attached_energy.size() >= retreat_cost \
			or target.attached_energy.size() + 1 < retreat_cost:
		return false
	for slot: PokemonSlot in player.bench:
		if not _matches_any(slot, DRAGAPULT_EX):
			continue
		var missing_before := _missing_dragapult_colors(slot)
		if missing_before.size() == 1 and _missing_dragapult_colors(slot, [energy]).is_empty():
			return true
	return false


func _score_tool_attachment(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> float:
	var tool: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", action.get("target", null))
	if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
			and _matches_any(tool, AIR_BALLOON) \
			and target != null and target == player.active_pokemon \
			and _matches_any(target, BLAZIKEN_EX) \
			and target.get_retreat_cost() > 0 and target.get_retreat_cost() <= 2 \
			and target.attached_energy.size() < target.get_retreat_cost() \
			and _has_ready_dragapult(player):
		return 5200.0
	if _matches_any(tool, TM_EVOLUTION):
		if _first_player_attack_locked(game_state, player_index):
			return -3000.0
		if target != player.active_pokemon or _tm_evolution_target_count(player) <= 0:
			return -2200.0
		return 5000.0
	if _matches_any(tool, SPARKLING_CRYSTAL):
		if target == null or not _is_dragapult_line_slot(target):
			return -1800.0
		if _matches_any(target, DRAGAPULT_EX):
			return 4400.0 if not _dragapult_phantom_ready(target) else -1000.0
		var preattach_score := 3900.0 if _matches_any(target, DRAKLOAK) else 3500.0
		return preattach_score + float(target.attached_energy.size()) * 350.0
	if _matches_any(tool, FOREST_SEAL_STONE):
		return 4300.0 if _forest_seal_target_is_live(target, game_state, player_index) else -2400.0
	return 100.0


func _score_trainer_action_family(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var trainer: Variant = action.get("card", null)
	if not bool(action.get("productive", true)):
		return -1600.0
	if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
			and _matches_any(trainer, BOSSS_ORDERS) \
			and not _active_attack_window_live(player):
		return -3000.0
	if _matches_any(trainer, BUDDY_BUDDY_POFFIN):
		if _second_player_tm_route_live(player, game_state, player_index) and _tm_evolution_target_count(player) < 2:
			return 7600.0
		return 4600.0 if _dragapult_lane_count(player) < 2 or not _has_partner_lane(player) else 350.0
	if _matches_any(trainer, ULTRA_BALL):
		if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
				and _resolved_ultra_ball_replaces_same_identity(action):
			return -5200.0
		if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
				and _resolved_ultra_ball_breaks_route_core(action, player):
			return BROKEN_ROUTE_ULTRA_BALL_SCORE
		return 4300.0 if _missing_playable_evolution(player) else 450.0
	if _matches_any(trainer, RARE_CANDY):
		return 4700.0 if _has_live_family_candy_route(player) else -1800.0
	if _matches_any(trainer, EARTHEN_VESSEL):
		return 3900.0 if _field_missing_dragapult_color(player) else 350.0
	if _matches_any(trainer, NIGHT_STRETCHER) or _matches_any(trainer, SUPER_ROD):
		if _boiling_spirit_discard_reserve_live(player):
			return -3400.0
		return 3600.0 if _discard_has_missing_route_piece(player) else -500.0
	return base_score


func _active_attack_window_live(player: PlayerState) -> bool:
	return player != null and player.active_pokemon != null \
		and bool(predict_attacker_damage(player.active_pokemon).get("can_attack", false))


func _score_ability_action_family(
	action: Dictionary,
	player: PlayerState,
	opponent: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null:
		return base_score
	if _deck_id == CURSE_BLAST_DRAGAPULT_DECK_ID \
			and _is_rotom_fast_charge_action(action, source) \
			and player.deck.size() <= 3:
		return -5000.0
	if _matches_any(source, DRAKLOAK):
		if _deck_id == BLAZIKEN_DRAGAPULT_DECK_ID \
				and player.deck.size() <= 8 \
				and _has_ready_dragapult(player):
			return BLAZIKEN_LOW_DECK_DRAKLOAK_ABILITY_SCORE
		return 4700.0 if player.deck.size() > 8 else 200.0
	if _matches_any(source, CHARIZARD_EX):
		if _count_basic_energy_in_deck(player, "R") <= 0:
			return -1200.0
		return 5600.0 if _any_dragapult_missing_color(player, "R") else 5100.0
	if _matches_any(source, DUSCLOPS) or _matches_any(source, DUSKNOIR):
		var damage := _dusk_counter_damage(source)
		if opponent.prizes.size() <= 1 \
				and not opponent.prizes.is_empty() \
				and not _has_direct_curse_blast_close(player, opponent, damage):
			return -INF
		var best := _best_damage_counter_target_score(opponent, damage, false, {
			"game_state": game_state,
			"player_index": player_index,
			"source_slot": source,
		})
		if best >= 5000.0:
			return 5200.0
		if best >= 2800.0:
			return 3400.0
		return -INF
	if _matches_any(source, MUNKIDORI):
		if not _has_damage_to_move(player):
			return -1400.0
		var best := _best_damage_counter_target_score(opponent, 30, false, {})
		return 3900.0 if best >= 4000.0 else 2300.0
	if _matches_any(source, BLAZIKEN_EX):
		if not _discard_has_useful_basic_energy(player):
			return -1200.0
		return 4900.0 if _field_missing_dragapult_color(player) else 2600.0
	return base_score


func _is_rotom_fast_charge_action(action: Dictionary, source: PokemonSlot) -> bool:
	if source == null or source.get_card_data() == null:
		return false
	return source.get_card_data().effect_id == ROTOM_FAST_CHARGE_EFFECT_ID \
			and int(action.get("ability_index", -1)) == 0


func _score_retreat_action_family(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var target: PokemonSlot = action.get("bench_target", null)
	if target == null:
		return -1800.0
	if player.active_pokemon != null and _dragapult_phantom_ready(player.active_pokemon):
		return -2200.0 if not _dragapult_phantom_ready(target) else 250.0
	if _matches_any(target, DRAGAPULT_EX):
		return 4200.0 if _dragapult_phantom_ready(target) else 1700.0
	if _slot_has_tm_evolution(player.active_pokemon) and _tm_evolution_target_count(player) > 0:
		return -2600.0
	return base_score


func _score_attack_action_family(
	action: Dictionary,
	player: PlayerState,
	opponent: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var kind := str(action.get("kind", ""))
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	if kind == "granted_attack" and _is_tm_evolution_attack(action):
		if _first_player_attack_locked(game_state, player_index):
			return -3000.0
		var targets := _tm_evolution_target_count(player)
		return 7600.0 + float(targets) * 500.0 if targets > 0 else -2200.0
	if _matches_any(source, DRAGAPULT_EX):
		if _is_phantom_dive_action(action):
			if not _dragapult_phantom_ready(source):
				return -2200.0
			var score := 5600.0
			var spread_score := _best_damage_counter_target_score(opponent, 60, true, {})
			if not is_inf(spread_score):
				score += spread_score * 0.12
			if bool(action.get("projected_knockout", false)):
				score += 1700.0
			if not bool(action.get("projected_knockout", false)) \
					and _curse_blast_should_precede_phantom_dive(player, opponent, game_state):
				return minf(score, CURSE_BLAST_DEFERRED_ATTACK_SCORE)
			return score
		if _dragapult_phantom_ready(source):
			return -1900.0
	if _deck_id == 800019125 and _matches_any(source, CHI_YU):
		var attack_index := int(action.get("attack_index", -1))
		if attack_index == 0:
			return _score_chi_yu_acceleration_attack(player)
		if bool(action.get("projected_knockout", false)):
			return 5600.0
	if _matches_any(source, BLAZIKEN_EX) and _has_ready_dragapult(player):
		return 1800.0 if bool(action.get("projected_knockout", false)) else 300.0
	return base_score


func _score_search_card_family(card: CardInstance, player: PlayerState, _step_id: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	if _matches_any(card, DREEPY):
		return 4700.0 if _dragapult_lane_count(player) == 0 else (3500.0 if _dragapult_lane_count(player) == 1 else 400.0)
	if _matches_any(card, DRAKLOAK):
		return 5300.0 if _has_slot(player, DREEPY) else 950.0
	if _matches_any(card, DRAGAPULT_EX):
		if _has_slot(player, DRAKLOAK):
			return 5600.0
		if _has_rare_candy_in_hand(player) and _has_slot(player, DREEPY):
			return 5400.0
		return 700.0
	if _matches_any(card, _partner_seed_names()):
		return 3900.0 if not _has_partner_lane(player) else 450.0
	if _matches_any(card, _partner_stage1_names()):
		return 4400.0 if _has_slot(player, _partner_seed_names()) else 800.0
	if _matches_any(card, _partner_stage2_names()):
		if _has_slot(player, _partner_stage1_names()):
			return 4700.0
		if _has_rare_candy_in_hand(player) and _has_slot(player, _partner_seed_names()):
			return 4300.0
		return 650.0
	if _is_dragapult_energy(card):
		return 3600.0 if _field_missing_dragapult_color(player) else 500.0
	return float(get_search_priority(card))


func _score_rare_candy_target(slot: PokemonSlot, context: Dictionary) -> float:
	var selected_stage2 := _selected_stage2_from_context(context)
	if selected_stage2 == null or not _rare_candy_target_matches_stage2(slot, selected_stage2):
		return -3200.0
	var score := 4400.0
	if _matches_any(selected_stage2, DRAGAPULT_EX):
		score = 5200.0 + float(slot.attached_energy.size()) * 260.0
		if _slot_has_sparkling_crystal(slot):
			score += 700.0
	elif _matches_any(selected_stage2, CHARIZARD_EX):
		score = 5000.0
	elif _matches_any(selected_stage2, BLAZIKEN_EX):
		score = 4700.0
	elif _matches_any(selected_stage2, DUSKNOIR):
		score = 4500.0
	return score


func _selected_stage2_from_context(context: Dictionary) -> CardInstance:
	var selected: Variant = context.get("stage2_card", null)
	if selected is Array:
		if (selected as Array).is_empty():
			return null
		selected = (selected as Array)[0]
	return selected as CardInstance if selected is CardInstance else null


func _rare_candy_target_matches_stage2(slot: PokemonSlot, stage2_card: CardInstance) -> bool:
	if slot == null or stage2_card == null or stage2_card.card_data == null:
		return false
	var target_data := slot.get_card_data()
	var stage2_data := stage2_card.card_data
	if target_data == null or not target_data.is_basic_pokemon() or str(stage2_data.stage).to_lower() != "stage 2":
		return false
	for stage1: CardData in _stage1_cards:
		if stage2_data.evolves_from_matches(stage1) and stage1.evolves_from_matches(target_data):
			return true
	return false


func _score_acceleration_energy(card: CardInstance, player: PlayerState, step_id: String) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var best := -1000.0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, DRAGAPULT_EX) or _matches_any(slot, DRAKLOAK) or _matches_any(slot, DREEPY):
			best = maxf(best, _dragapult_energy_completion_score(card, slot))
	if step_id == "energy_assignments" and _energy_type(card) == "R":
		best = maxf(best, 1800.0)
	return best


func _score_acceleration_target(
	target: PokemonSlot,
	context: Dictionary,
	player: PlayerState,
	step_id: String
) -> float:
	if target == null:
		return -1500.0
	var energy := _assignment_source_from_context(context)
	if _matches_any(target, DRAGAPULT_EX) or _matches_any(target, DRAKLOAK) or _matches_any(target, DREEPY):
		if energy != null:
			return _dragapult_acceleration_score(energy, target, context)
		return 4600.0 if not _missing_dragapult_colors(target).is_empty() else 800.0
	if step_id == "energy_assignments" and _matches_any(target, CHARIZARD_EX):
		return 1800.0
	if _matches_any(target, BLAZIKEN_EX):
		return 1400.0
	if player != null and _field_missing_dragapult_color(player):
		return -1200.0
	return 200.0


func _score_tm_evolution_seed(slot: PokemonSlot, player: PlayerState) -> float:
	if _matches_any(slot, DREEPY):
		return 5200.0
	if _matches_any(slot, _partner_seed_names()) and not _has_partner_stage2(player):
		return 3900.0
	return 200.0


func _score_damage_counter_target(
	slot: PokemonSlot,
	available_damage: int,
	spread_only: bool,
	context: Dictionary
) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var remaining := slot.get_remaining_hp()
	var prizes := maxi(1, slot.get_prize_count())
	var score := float(prizes) * 320.0
	if remaining <= available_damage:
		score += 5200.0 + float(prizes) * 1000.0
		score -= float(available_damage - remaining) * 5.0
		return score
	if not spread_only:
		var game_state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			var active := game_state.players[player_index].active_pokemon
			var follow_up_damage := PHANTOM_DIVE_ACTIVE_DAMAGE
			if _deck_id == CURSE_BLAST_DRAGAPULT_DECK_ID:
				follow_up_damage = _curse_blast_follow_up_damage(slot, game_state, player_index)
			if active != null \
					and _dragapult_phantom_ready(active) \
					and follow_up_damage > 0 \
					and remaining <= available_damage + follow_up_damage:
				score += 3300.0 + float(prizes) * 500.0
	if spread_only and remaining > 200 and remaining <= 200 + available_damage:
		score += 3000.0 + float(prizes) * 450.0
	elif remaining <= 120:
		score += 1100.0
	elif remaining <= 260:
		score += 700.0
	if slot.get_card_data() != null and str(slot.get_card_data().mechanic) != "":
		score += 500.0
	score += float(slot.damage_counters) * 2.0
	score -= float(remaining) * 1.5
	return score


func _score_munkidori_source(slot: PokemonSlot) -> float:
	if slot == null or slot.damage_counters <= 0:
		return -1200.0
	var score := float(mini(30, slot.damage_counters)) * 20.0
	if _matches_any(slot, DRAGAPULT_EX):
		score += 2300.0
	elif _matches_any(slot, DRAKLOAK) or _matches_any(slot, BLAZIKEN_EX) or _matches_any(slot, CHARIZARD_EX):
		score += 1200.0
	else:
		score += 250.0
	if slot.get_remaining_hp() <= 60:
		score += 800.0
	return score


func _score_radiant_alakazam_source(slot: PokemonSlot) -> float:
	if slot == null or slot.damage_counters < 10:
		return -1200.0
	var movable_damage := mini(20, slot.damage_counters)
	var remaining := slot.get_remaining_hp()
	var score := float(movable_damage) * 25.0 + float(slot.damage_counters) * 2.0
	if remaining <= 20:
		score -= 6000.0 + float(maxi(1, slot.get_prize_count())) * 1000.0
	elif remaining <= 60:
		score -= 1200.0
	if slot.get_card_data() != null and str(slot.get_card_data().mechanic) != "":
		score -= 400.0
	return score


func _score_chi_yu_discard_energy(card: CardInstance) -> float:
	if card == null or card.card_data == null or not _is_basic_energy(card):
		return -1800.0
	return 6200.0 if _energy_type(card) == "R" else -1200.0


func _score_chi_yu_attach_target(slot: PokemonSlot) -> float:
	if slot == null:
		return -1800.0
	if _matches_any(slot, DRAGAPULT_EX) or _matches_any(slot, DRAKLOAK) or _matches_any(slot, DREEPY):
		return 6500.0 if "R" in _missing_dragapult_colors(slot) else 1200.0
	if _matches_any(slot, BLAZIKEN_EX):
		return 5000.0 if slot.attached_energy.size() < 2 else 900.0
	if _matches_any(slot, CHI_YU):
		return 4200.0 if slot.attached_energy.size() < 2 else 700.0
	return 100.0


func _score_chi_yu_acceleration_attack(player: PlayerState) -> float:
	if player == null:
		return -1800.0
	var fire_count := 0
	for card: CardInstance in player.discard_pile:
		if _is_basic_energy(card) and _energy_type(card) == "R":
			fire_count += 1
			if fire_count >= 2:
				break
	if fire_count <= 0:
		return -1800.0
	var best_target_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		best_target_score = maxf(best_target_score, _score_chi_yu_attach_target(slot))
	if best_target_score < 3000.0:
		return 2200.0
	return 5900.0 + float(fire_count) * 300.0


func _chi_yu_manual_acceleration_route_live(player: PlayerState, target: PokemonSlot) -> bool:
	return player != null \
		and target != null \
		and target == player.active_pokemon \
		and _score_chi_yu_acceleration_attack(player) >= 5000.0


func _interaction_uses_effect(context: Dictionary, expected_effect_id: String) -> bool:
	for key: String in ["pending_effect_card", "effect_card", "pending_card"]:
		var card_data := _card_data_from_item(context.get(key, null))
		if card_data != null:
			return str(card_data.effect_id) == expected_effect_id
	return false


func _dragapult_energy_completion_score(energy: CardInstance, target: PokemonSlot) -> float:
	if energy == null or target == null:
		return -1800.0
	var missing_before := _missing_dragapult_colors(target)
	if missing_before.is_empty():
		return -2600.0
	var missing_after := _missing_dragapult_colors(target, [energy])
	if missing_after.size() >= missing_before.size():
		return -1700.0
	return 5000.0 if missing_after.is_empty() else 3300.0


func _active_phantom_dive_attachment_is_urgent(
	energy: CardInstance,
	target: PokemonSlot,
	player: PlayerState
) -> bool:
	if _deck_id != CURSE_BLAST_DRAGAPULT_DECK_ID \
			or player == null \
			or target == null \
			or target != player.active_pokemon \
			or not _matches_any(target, DRAGAPULT_EX) \
			or not _is_dragapult_energy(energy):
		return false
	var missing_before := _missing_dragapult_colors(target)
	if missing_before.is_empty():
		return false
	return _missing_dragapult_colors(target, [energy]).is_empty()


func _dragapult_acceleration_score(
	energy: CardInstance,
	target: PokemonSlot,
	context: Dictionary
) -> float:
	if energy == null or target == null:
		return -1800.0
	var pending_energies: Array = []
	var pending: Variant = context.get("pending_assignments", [])
	if pending is Array:
		for raw_assignment: Variant in pending:
			if not raw_assignment is Dictionary:
				continue
			var assignment := raw_assignment as Dictionary
			if assignment.get("target", null) != target:
				continue
			var pending_energy: CardInstance = assignment.get("source", null)
			if pending_energy != null:
				pending_energies.append(pending_energy)
	var missing_before := _missing_dragapult_colors(target, pending_energies)
	if missing_before.is_empty():
		return -2800.0
	var all_extra_energies := pending_energies.duplicate()
	all_extra_energies.append(energy)
	var missing_after := _missing_dragapult_colors(target, all_extra_energies)
	if missing_after.size() >= missing_before.size():
		return -1900.0
	return 5200.0 if missing_after.is_empty() else 3400.0


func _missing_dragapult_colors(slot: PokemonSlot, extra_energies: Array = []) -> Array[String]:
	var missing: Array[String] = DRAGAPULT_COLORS.duplicate()
	if slot == null:
		return missing
	var energies: Array = slot.attached_energy.duplicate()
	for extra_energy: Variant in extra_energies:
		if extra_energy is CardInstance:
			energies.append(extra_energy as CardInstance)
	var wildcard_units := 0
	var special_count := 0
	for energy: CardInstance in energies:
		if energy != null and energy.card_data != null and energy.card_data.card_type == "Special Energy":
			special_count += 1
	for energy: CardInstance in energies:
		if energy == null or energy.card_data == null:
			continue
		var energy_type := _energy_type(energy)
		if energy_type in missing:
			missing.erase(energy_type)
			continue
		if energy.card_data.effect_id == LUMINOUS_ENERGY_EFFECT_ID and special_count <= 1:
			wildcard_units += 1
		elif energy.card_data.effect_id == NEO_UPPER_ENERGY_EFFECT_ID and _is_stage2(slot.get_card_data()):
			wildcard_units += 2
		elif energy_type == "ANY":
			wildcard_units += 1
	while wildcard_units > 0 and not missing.is_empty():
		missing.pop_back()
		wildcard_units -= 1
	if _slot_has_sparkling_crystal(slot) and not missing.is_empty():
		missing.pop_back()
	return missing


func _energy_can_pay(energy: CardInstance, color: String, target: PokemonSlot) -> bool:
	if energy == null or energy.card_data == null:
		return false
	var energy_type := _energy_type(energy)
	if energy_type == color or energy_type == "ANY":
		return true
	if energy.card_data.effect_id == LUMINOUS_ENERGY_EFFECT_ID:
		for attached: CardInstance in target.attached_energy:
			if attached != null and attached.card_data != null and attached.card_data.card_type == "Special Energy":
				return false
		return true
	return energy.card_data.effect_id == NEO_UPPER_ENERGY_EFFECT_ID and _is_stage2(target.get_card_data())


func _dragapult_setup_debt(player: PlayerState) -> Dictionary:
	if player == null:
		return {"total": 0}
	var lanes := _dragapult_lane_count(player)
	var best := _best_dragapult_route_slot(player)
	var missing_seed := maxi(0, 2 - lanes)
	var backup_gap := 0
	if lanes >= 2:
		var advanced := 0
		for slot: PokemonSlot in _all_slots(player):
			if _matches_any(slot, DRAKLOAK) or _matches_any(slot, DRAGAPULT_EX):
				advanced += 1
		backup_gap = 1 if advanced < 2 else 0
	elif lanes == 1 and best != null and _matches_any(best, DRAGAPULT_EX):
		backup_gap = 1
	var missing_colors := _missing_dragapult_colors(best).size() if best != null else 2
	var missing_partner := 0
	var partner_gap := 0
	if _family_variant != VARIANT_PURE:
		missing_partner = 0 if _has_partner_lane(player) else 1
		partner_gap = 0 if _has_partner_stage2(player) else (1 if _has_partner_lane(player) else 0)
	var total := missing_seed + backup_gap + mini(1, missing_colors) + missing_partner + partner_gap
	return {
		"total": total,
		"missing_dragapult_seed": missing_seed,
		"backup_dragapult_gap": backup_gap,
		"missing_attack_colors": missing_colors,
		"missing_partner_seed": missing_partner,
		"partner_chain_gap": partner_gap,
	}


func _best_dragapult_route_slot(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var score := 0.0
		if _matches_any(slot, DRAGAPULT_EX):
			score = 5000.0 - float(_missing_dragapult_colors(slot).size()) * 450.0
		elif _matches_any(slot, DRAKLOAK):
			score = 3200.0 + float(slot.attached_energy.size()) * 180.0
		elif _matches_any(slot, DREEPY):
			score = 1800.0 + float(slot.attached_energy.size()) * 160.0
		else:
			continue
		if score > best_score:
			best = slot
			best_score = score
	return best


func _bridge_name(player: PlayerState) -> String:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, DRAGAPULT_EX):
			continue
		if _matches_any(slot, DRAKLOAK):
			return _display_name(slot)
		if _matches_any(slot, DREEPY):
			return _display_name(slot)
	return "Dreepy"


func _opening_route(game_state: GameState, player_index: int) -> String:
	if _first_player_attack_locked(game_state, player_index):
		return "first_player_manual_chain"
	if _is_second_player_first_turn(game_state, player_index):
		return "second_player_tm_evolution" if _family_has_tm_evolution else "second_player_manual_pressure"
	return "established_chain"


func _turn_intent(phase: String, opening_route: String) -> String:
	if opening_route == "second_player_tm_evolution":
		return "seed_both_lines_then_tm_evolution"
	if opening_route == "second_player_manual_pressure":
		return "seed_dragapult_then_apply_opening_pressure"
	match phase:
		"setup":
			return "establish_dragapult_and_partner_seeds"
		"launch":
			return "complete_rp_phantom_dive_route"
		"convert":
			return "convert_damage_counters_and_build_backup"
		"rebuild":
			return "rebuild_dragapult_chain"
		"close":
			return "take_exact_final_prizes"
	return "preserve_dragapult_pressure"


func _attach_priorities(player: PlayerState) -> Array[String]:
	var priorities: Array[String] = ["Dragapult ex", "多龙巴鲁托ex", "Drakloak", "多龙奇", "Dreepy", "多龙梅西亚"]
	if _family_variant == VARIANT_BLAZIKEN:
		priorities.append_array(["Blaziken ex", "火焰鸡ex", "Munkidori", "愿增猿"])
	elif _family_variant == VARIANT_CHARIZARD:
		priorities.append_array(["Charizard ex", "喷火龙ex"])
	elif _has_damage_to_move(player):
		priorities.append_array(["Munkidori", "愿增猿"])
	return priorities


func _search_priorities(player: PlayerState) -> Array[String]:
	var priorities: Array[String] = []
	if not _has_slot(player, DREEPY):
		priorities.append_array(["Dreepy", "多龙梅西亚"])
	elif _has_slot(player, DREEPY) and not _has_slot(player, DRAKLOAK) and not _has_rare_candy_in_hand(player):
		priorities.append_array(["Drakloak", "多龙奇"])
	else:
		priorities.append_array(["Dragapult ex", "多龙巴鲁托ex", "Drakloak", "多龙奇"])
	priorities.append_array(_partner_stage1_names())
	priorities.append_array(_partner_stage2_names())
	priorities.append_array(_partner_seed_names())
	return priorities


func _evolution_priorities() -> Array[String]:
	var priorities: Array[String] = ["Dragapult ex", "多龙巴鲁托ex", "Drakloak", "多龙奇"]
	priorities.append_array(_partner_stage2_names())
	priorities.append_array(_partner_stage1_names())
	return priorities


func _ability_priorities() -> Array[String]:
	var priorities: Array[String] = ["Drakloak", "多龙奇", "Munkidori", "愿增猿"]
	if _family_variant == VARIANT_DUSKNOIR:
		priorities.append_array(["Dusknoir", "黑夜魔灵", "Dusclops", "彷徨夜灵"])
	elif _family_variant == VARIANT_BLAZIKEN:
		priorities.push_front("火焰鸡ex")
		priorities.push_front("Blaziken ex")
	return priorities


func _partner_seed_names() -> Array[String]:
	match _family_variant:
		VARIANT_CHARIZARD:
			return CHARMANDER.duplicate()
		VARIANT_DUSKNOIR:
			return DUSKULL.duplicate()
		VARIANT_BLAZIKEN:
			return TORCHIC.duplicate()
	return []


func _partner_stage1_names() -> Array[String]:
	match _family_variant:
		VARIANT_CHARIZARD:
			return CHARMELEON.duplicate()
		VARIANT_DUSKNOIR:
			return DUSCLOPS.duplicate()
		VARIANT_BLAZIKEN:
			return COMBUSKEN.duplicate()
	return []


func _partner_stage2_names() -> Array[String]:
	match _family_variant:
		VARIANT_CHARIZARD:
			return CHARIZARD_EX.duplicate()
		VARIANT_DUSKNOIR:
			return DUSKNOIR.duplicate()
		VARIANT_BLAZIKEN:
			return BLAZIKEN_EX.duplicate()
	return []


func _opening_active_score_for(card: CardInstance) -> float:
	if _matches_any(card, BUDEW):
		return 6000.0
	if _matches_any(card, CACTURNE_PIVOT):
		return 5200.0
	if _matches_any(card, DREEPY):
		return 1100.0
	if _matches_any(card, _partner_seed_names()):
		return 850.0
	if _matches_any(card, MUNKIDORI) or _matches_any(card, HAWLUCHA):
		return 500.0
	return 350.0


func _opening_bench_score_for(card: CardInstance) -> float:
	if _matches_any(card, DREEPY):
		return 6000.0
	if _matches_any(card, _partner_seed_names()):
		return 5200.0
	if _family_variant == VARIANT_PURE and _matches_any(card, MUNKIDORI):
		return 4700.0
	if _matches_any(card, MUNKIDORI):
		return 2500.0
	if _matches_any(card, HAWLUCHA):
		return 1800.0
	if _matches_any(card, BLOODMOON_URSALUNA):
		return 500.0
	if _matches_any(card, BUDEW) or _matches_any(card, CACTURNE_PIVOT):
		return 250.0
	return 150.0


func _pick_diverse_basic_routes(
	items: Array,
	max_select: int,
	step: Dictionary,
	context: Dictionary
) -> Array:
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		ranked.append({
			"item": item,
			"role": _basic_route_role(item),
			"score": score_interaction_target(item, step, context),
			"index": index,
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a.get("score", 0.0))
		var b_score := float(b.get("score", 0.0))
		return a_score > b_score if not is_equal_approx(a_score, b_score) else int(a.get("index", 0)) < int(b.get("index", 0))
	)
	var selected: Array = []
	var used_roles: Dictionary = {}
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		var role := str(entry.get("role", ""))
		if role != "" and used_roles.has(role):
			continue
		selected.append(entry.get("item"))
		if role != "":
			used_roles[role] = true
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		if entry.get("item") not in selected:
			selected.append(entry.get("item"))
	return selected


func _basic_route_role(item: Variant) -> String:
	if _matches_any(item, DREEPY):
		return "dragapult_seed"
	if _matches_any(item, _partner_seed_names()):
		return "partner_seed"
	if _matches_any(item, MUNKIDORI):
		return "damage_engine"
	return _display_name(item)


func _partner_route_name() -> String:
	match _family_variant:
		VARIANT_CHARIZARD:
			return "Charizard ex"
		VARIANT_DUSKNOIR:
			return "Dusknoir"
		VARIANT_BLAZIKEN:
			return "Blaziken ex"
	return "Munkidori"


func _damage_counter_route_name() -> String:
	return "Dusknoir" if _family_variant == VARIANT_DUSKNOIR else "Munkidori"


func _first_player_attack_locked(game_state: GameState, player_index: int) -> bool:
	return game_state != null \
		and int(game_state.current_player_index) == player_index \
		and int(game_state.first_player_index) == player_index \
		and game_state.is_first_turn_for_player(player_index)


func _is_second_player_first_turn(game_state: GameState, player_index: int) -> bool:
	return game_state != null \
		and int(game_state.current_player_index) == player_index \
		and int(game_state.first_player_index) != player_index \
		and game_state.is_first_turn_for_player(player_index)


func _second_player_tm_route_live(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	return _family_has_tm_evolution \
		and _is_second_player_first_turn(game_state, player_index) \
		and _tm_evolution_target_count(player) > 0


func _second_player_tm_energy_search_live(player: PlayerState, context: Dictionary) -> bool:
	if _deck_id != BLAZIKEN_DRAGAPULT_DECK_ID or player == null:
		return false
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if not _second_player_tm_route_live(player, game_state, player_index):
		return false
	if player.active_pokemon != null and not player.active_pokemon.attached_energy.is_empty():
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return false
	return true


func _tm_evolution_target_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if _matches_any(slot, DREEPY) and _deck_has_any(player, DRAKLOAK):
			count += 1
		elif _matches_any(slot, _partner_seed_names()) and _deck_has_any(player, _partner_stage1_names()):
			count += 1
	return mini(2, count)


func _has_live_family_candy_route(player: PlayerState) -> bool:
	return (_has_slot(player, DREEPY) and _hand_or_deck_has(player, DRAGAPULT_EX)) \
		or (_has_slot(player, _partner_seed_names()) and _hand_or_deck_has(player, _partner_stage2_names()))


func _missing_playable_evolution(player: PlayerState) -> bool:
	return (_has_slot(player, DREEPY) and not _has_slot(player, DRAKLOAK) and not _has_slot(player, DRAGAPULT_EX)) \
		or (_has_slot(player, DRAKLOAK) and not _has_slot(player, DRAGAPULT_EX)) \
		or (_family_variant != VARIANT_PURE and _has_partner_lane(player) and not _has_partner_stage2(player))


func _productive_setup_debt(player: PlayerState) -> bool:
	return int(_dragapult_setup_debt(player).get("total", 0)) > 0


func _dragapult_lane_count(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, DREEPY) or _matches_any(slot, DRAKLOAK) or _matches_any(slot, DRAGAPULT_EX):
			count += 1
	return count


func _has_ready_dragapult(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, DRAGAPULT_EX) and _dragapult_phantom_ready(slot):
			return true
	return false


func _dragapult_phantom_ready(slot: PokemonSlot) -> bool:
	return slot != null and _matches_any(slot, DRAGAPULT_EX) and _missing_dragapult_colors(slot).is_empty()


func _has_partner_lane(player: PlayerState) -> bool:
	return _has_slot(player, _partner_seed_names()) \
		or _has_slot(player, _partner_stage1_names()) \
		or _has_slot(player, _partner_stage2_names())


func _has_partner_stage2(player: PlayerState) -> bool:
	return _has_slot(player, _partner_stage2_names())


func _has_slot(player: PlayerState, names: Array[String]) -> bool:
	if player == null or names.is_empty():
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, names):
			return true
	return false


func _deck_has_any(player: PlayerState, names: Array[String]) -> bool:
	if player == null or names.is_empty():
		return false
	for card: CardInstance in player.deck:
		if _matches_any(card, names):
			return true
	return false


func _hand_or_deck_has(player: PlayerState, names: Array[String]) -> bool:
	if player == null or names.is_empty():
		return false
	for card: CardInstance in player.hand:
		if _matches_any(card, names):
			return true
	return _deck_has_any(player, names)


func _has_damage_to_move(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot.damage_counters > 0:
			return true
	return false


func _opponent_bench_has_counter_conversion(game_state: GameState, player_index: int, damage: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].bench:
		if slot != null and slot.get_remaining_hp() <= damage:
			return true
	return false


func _best_damage_counter_target_score(
	opponent: PlayerState,
	damage: int,
	spread_only: bool,
	context: Dictionary
) -> float:
	if opponent == null:
		return -INF
	var best := -INF
	var slots: Array[PokemonSlot] = []
	if spread_only:
		slots.assign(opponent.bench)
	else:
		slots.assign(opponent.get_all_pokemon())
	for slot: PokemonSlot in slots:
		best = maxf(best, _score_damage_counter_target(slot, damage, spread_only, context))
	return best


func _dusk_counter_damage(source: PokemonSlot) -> int:
	return 50 if source != null and _matches_any(source, DUSCLOPS) else 130


func _curse_blast_damage_from_context(context: Dictionary) -> int:
	var source: Variant = context.get("source_slot", null)
	if source is PokemonSlot:
		return _dusk_counter_damage(source as PokemonSlot)
	for key: String in ["pending_effect_card", "effect_card", "pending_card"]:
		var card: Variant = context.get(key, null)
		if _matches_any(card, DUSCLOPS):
			return 50
		if _matches_any(card, DUSKNOIR):
			return 130
	return 130


func _curse_blast_should_precede_phantom_dive(
	player: PlayerState,
	opponent: PlayerState,
	game_state: GameState
) -> bool:
	if _deck_id != CURSE_BLAST_DRAGAPULT_DECK_ID \
			or player == null \
			or opponent == null \
			or not _dragapult_phantom_ready(player.active_pokemon) \
			or opponent.active_pokemon == null:
		return false
	var remaining := opponent.active_pokemon.get_remaining_hp()
	for source: PokemonSlot in _all_slots(player):
		if not (_matches_any(source, DUSCLOPS) or _matches_any(source, DUSKNOIR)):
			continue
		if game_state != null and source.has_ability_used(game_state.turn_number):
			continue
		var blast_damage := _dusk_counter_damage(source)
		if opponent.prizes.size() <= 1 \
				and not opponent.prizes.is_empty() \
				and not _has_direct_curse_blast_close(player, opponent, blast_damage):
			continue
		if remaining > PHANTOM_DIVE_ACTIVE_DAMAGE \
				and remaining <= PHANTOM_DIVE_ACTIVE_DAMAGE + blast_damage:
			return true
	return false


func _curse_blast_follow_up_damage(
	target: PokemonSlot,
	game_state: GameState,
	player_index: int
) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var opponent: PlayerState = game_state.players[1 - player_index]
	if target == opponent.active_pokemon:
		return PHANTOM_DIVE_ACTIVE_DAMAGE
	if target in opponent.bench:
		return PHANTOM_DIVE_BENCH_DAMAGE
	return 0


func _has_direct_curse_blast_close(player: PlayerState, opponent: PlayerState, damage: int) -> bool:
	if player == null or opponent == null or player.prizes.is_empty():
		return false
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= damage and slot.get_prize_count() >= player.prizes.size():
			return true
	return false


func _discard_has_useful_basic_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if _is_basic_energy(card):
			return true
	return false


func _discard_has_missing_route_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if _matches_any(card, DREEPY) or _matches_any(card, DRAKLOAK) or _matches_any(card, DRAGAPULT_EX):
			return true
		if _matches_any(card, _partner_seed_names()) or _matches_any(card, _partner_stage1_names()) or _matches_any(card, _partner_stage2_names()):
			return true
		if _is_dragapult_energy(card):
			return true
	return false


func _boiling_spirit_discard_reserve_live(player: PlayerState) -> bool:
	if _deck_id != BLAZIKEN_DRAGAPULT_DECK_ID or player == null \
			or not _has_slot(player, BLAZIKEN_EX):
		return false
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_any(slot, DRAGAPULT_EX):
			continue
		var missing_colors := _missing_dragapult_colors(slot)
		if missing_colors.is_empty():
			continue
		for card: CardInstance in player.discard_pile:
			if _is_basic_energy(card) and _energy_type(card) in missing_colors:
				return true
	return false


func _field_missing_dragapult_color(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if (_matches_any(slot, DREEPY) or _matches_any(slot, DRAKLOAK) or _matches_any(slot, DRAGAPULT_EX)) \
				and not _missing_dragapult_colors(slot).is_empty():
			return true
	return false


func _any_dragapult_missing_color(player: PlayerState, color: String) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if color in _missing_dragapult_colors(slot):
			return true
	return false


func _count_accessible_basic_energy(player: PlayerState, energy_type: String) -> int:
	var count := 0
	for card: CardInstance in player.hand:
		if _is_basic_energy(card) and _energy_type(card) == energy_type:
			count += 1
	for card: CardInstance in player.discard_pile:
		if _is_basic_energy(card) and _energy_type(card) == energy_type:
			count += 1
	return count


func _resolved_ultra_ball_breaks_route_core(action: Dictionary, player: PlayerState) -> bool:
	if _deck_id != BLAZIKEN_DRAGAPULT_DECK_ID \
			or player == null \
			or _has_ready_dragapult(player):
		return false
	var discarded := _resolved_discard_cards(action)
	if discarded.is_empty():
		return false
	for energy_type: String in DRAGAPULT_COLORS:
		var discarded_count := 0
		for card: CardInstance in discarded:
			if _is_basic_energy(card) and _energy_type(card) == energy_type:
				discarded_count += 1
		if discarded_count > 0 \
				and _count_accessible_basic_energy(player, energy_type) <= discarded_count:
			return true
	return false


func _resolved_discard_cards(action: Dictionary) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var raw_targets: Variant = action.get("targets", [])
	if not raw_targets is Array:
		return result
	for raw_group: Variant in raw_targets:
		if not raw_group is Dictionary:
			continue
		for raw_card: Variant in (raw_group as Dictionary).get("discard_cards", []):
			if raw_card is CardInstance:
				result.append(raw_card as CardInstance)
	return result


func _resolved_ultra_ball_replaces_same_identity(action: Dictionary) -> bool:
	var discarded := _resolved_discard_cards(action)
	if discarded.is_empty():
		return false
	var raw_targets: Variant = action.get("targets", [])
	if not raw_targets is Array:
		return false
	for raw_group: Variant in raw_targets:
		if not raw_group is Dictionary:
			continue
		for raw_card: Variant in (raw_group as Dictionary).get("search_pokemon", []):
			if not raw_card is CardInstance or (raw_card as CardInstance).card_data == null:
				continue
			var searched_data: CardData = (raw_card as CardInstance).card_data
			for discarded_card: CardInstance in discarded:
				if discarded_card.card_data != null \
						and _same_rule_identity_local(searched_data, discarded_card.card_data):
					return true
	return false


func _same_rule_identity_local(left: CardData, right: CardData) -> bool:
	if left == null or right == null:
		return false
	var left_uid := left.get_uid()
	var right_uid := right.get_uid()
	return (left_uid != "" and left_uid != "_" and left_uid == right_uid) \
		or left.matches_rule_identity_name(right.name) \
		or (str(right.name_en) != "" and left.matches_rule_identity_name(right.name_en))


func _count_basic_energy_in_deck(player: PlayerState, energy_type: String) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.deck:
		if _is_basic_energy(card) and _energy_type(card) == energy_type:
			count += 1
	return count


func _assignment_source_from_context(context: Dictionary) -> CardInstance:
	for key: String in ["assignment_source", "source_card", "selected_card", "card", "source"]:
		var value: Variant = context.get(key, null)
		if value is CardInstance:
			return value as CardInstance
	return null


func _slot_has_tm_evolution(slot: PokemonSlot) -> bool:
	return slot != null and _matches_any(slot.attached_tool, TM_EVOLUTION)


func _slot_has_sparkling_crystal(slot: PokemonSlot) -> bool:
	return slot != null and _matches_any(slot.attached_tool, SPARKLING_CRYSTAL)


func _is_dragapult_line_slot(slot: PokemonSlot) -> bool:
	return slot != null \
		and (_matches_any(slot, DREEPY) or _matches_any(slot, DRAKLOAK) or _matches_any(slot, DRAGAPULT_EX))


func _forest_seal_target_is_live(
	target: PokemonSlot,
	game_state: GameState,
	player_index: int
) -> bool:
	if target == null or target.get_card_data() == null or str(target.get_card_data().mechanic) != "V":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	return not bool(game_state.vstar_power_used[player_index]) \
		and not game_state.players[player_index].deck.is_empty()


func _is_tm_evolution_attack(action: Dictionary) -> bool:
	var granted: Dictionary = action.get("granted_attack_data", {}) if action.get("granted_attack_data", {}) is Dictionary else {}
	var identity := "%s %s" % [str(granted.get("id", "")), str(granted.get("name", ""))]
	return identity.to_lower().contains("evolution") or identity.contains("进化")


func _is_phantom_dive_action(action: Dictionary) -> bool:
	var name := str(action.get("attack_name", ""))
	if name == "":
		var source: PokemonSlot = action.get("source_slot", null)
		var attack_index := int(action.get("attack_index", -1))
		if source != null and source.get_card_data() != null and attack_index >= 0 and attack_index < source.get_card_data().attacks.size():
			name = str(source.get_card_data().attacks[attack_index].get("name", ""))
	return name in ["Phantom Dive", "幻影潜袭"] or int(action.get("attack_index", -1)) == 1


func _is_dragapult_energy(card: Variant) -> bool:
	if not card is CardInstance:
		return false
	var instance := card as CardInstance
	if instance.card_data == null or not instance.card_data.is_energy():
		return false
	return _energy_type(instance) in ["R", "P", "ANY"] \
		or instance.card_data.effect_id in [LUMINOUS_ENERGY_EFFECT_ID, NEO_UPPER_ENERGY_EFFECT_ID]


func _is_basic_energy(card: Variant) -> bool:
	return card is CardInstance \
		and (card as CardInstance).card_data != null \
		and (card as CardInstance).card_data.card_type == "Basic Energy"


func _energy_type(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return str(card.card_data.energy_provides)


func _matches_any(item: Variant, names: Array[String]) -> bool:
	for name: String in names:
		if _matches_key(item, name):
			return true
	return false


func _display_name(item: Variant) -> String:
	var data := _card_data_from_item(item)
	if data == null:
		return ""
	return str(data.name_en) if str(data.name_en) != "" else str(data.name)
