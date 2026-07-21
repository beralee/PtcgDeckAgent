class_name DeckStrategyV18DarkCharacterFamily
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const MARNIE_DECK_ID := 800018501
const NS_ZOROARK_DECK_ID := 800018502

const MARNIE_IMPIDIMP: Array[String] = ["玛俐的捣蛋小妖", "Marnie's Impidimp", "CSV10C_146", "LEN_DRI_134"]
const MARNIE_MORGREM: Array[String] = ["玛俐的诈唬魔", "Marnie's Morgrem", "CSV10C_147", "LEN_DRI_135"]
const MARNIE_GRIMMSNARL: Array[String] = ["玛俐的长毛巨魔ex", "Marnie's Grimmsnarl ex", "CSV10C_148", "LEN_DRI_136"]
const NS_ZORUA: Array[String] = ["N的索罗亚", "N's Zorua", "CSV10C_144", "LEN_JTG_97", "074f56036068708a4e2ad19a282fa726"]
const NS_ZOROARK: Array[String] = ["N的索罗亚克ex", "N's Zoroark ex", "CSV10C_145", "LEN_JTG_98", "a1742becbf9fdc6a66ddfb1b306c4bc0"]
const NS_RESHIRAM: Array[String] = ["N的莱希拉姆", "N's Reshiram", "CSV10C_166", "LEN_JTG_116", "7ee514e3fb601f1f743a3d329b98daab"]
const NS_DARUMAKA: Array[String] = ["N的火红不倒翁", "N's Darumaka", "CSV10C_040", "LEN_JTG_26", "2838414253437693be0e9946c8827b6d"]
const NS_DARMANITAN: Array[String] = ["N的达摩狒狒", "N's Darmanitan", "CSV10C_041", "LEN_JTG_27", "26c746f169b803e490f3d0a92ca94412"]
const MUNKIDORI: Array[String] = ["愿增猿", "Munkidori", "CSV8C_094"]

const RARE_CANDY: Array[String] = ["神奇糖果", "Rare Candy"]
const TM_EVOLUTION: Array[String] = ["招式学习器 进化", "Technical Machine: Evolution"]
const SPIKEMUTH_GYM: Array[String] = ["尖钉镇道馆", "Spikemuth Gym", "CSV10C_216", "LEN_DRI_169"]
const NS_PP_UP: Array[String] = ["N的PP提升剂", "N's PP Up", "N的PP提升", "CSV10C_190", "LEN_JTG_152"]
const NS_CASTLE: Array[String] = ["N的城堡", "N's Castle", "CSV10C_215", "LEN_JTG_153"]
const REVERSAL_ENERGY: Array[String] = ["逆转能量", "Reversal Energy", "CSV2C_128", "cbadb3473273c14cf667d495d44d111b"]

const PUNK_UP_STEP := "marnies_punk_up_assignments"
const SPIKEMUTH_STEP := "spikemuth_gym_marnies_pokemon"
const TRADE_DISCARD_STEP := "discard_card"
const NS_PP_UP_STEP := "ns_pp_up_assignment"
const COPIED_ATTACK_STEP := "copied_attack"

const MARNIE_PROFILE := {
	"strategy_id": "v18_marnies_grimmsnarl_character_delegate",
	"signatures": ["玛俐的长毛巨魔ex", "Marnie's Grimmsnarl ex"],
	"active_priority": ["含羞苞", "Budew", "玛俐的捣蛋小妖", "Marnie's Impidimp", "雪童子", "Snorunt"],
	"bench_priority": ["玛俐的捣蛋小妖", "Marnie's Impidimp", "雪童子", "Snorunt", "愿增猿", "Munkidori"],
	"energy_priority": ["玛俐的长毛巨魔ex", "Marnie's Grimmsnarl ex", "玛俐的诈唬魔", "Marnie's Morgrem", "玛俐的捣蛋小妖", "Marnie's Impidimp", "愿增猿", "Munkidori"],
	"evolution_priority": ["玛俐的长毛巨魔ex", "Marnie's Grimmsnarl ex", "玛俐的诈唬魔", "Marnie's Morgrem", "雪妖女", "Froslass"],
	"search_priority": ["玛俐的长毛巨魔ex", "Marnie's Grimmsnarl ex", "玛俐的诈唬魔", "Marnie's Morgrem", "玛俐的捣蛋小妖", "Marnie's Impidimp", "神奇糖果", "Rare Candy"],
	"ability_priority": ["玛俐的长毛巨魔ex", "Marnie's Grimmsnarl ex", "雪妖女", "Froslass", "愿增猿", "Munkidori"],
	"trainer_priority": ["尖钉镇道馆", "Spikemuth Gym", "神奇糖果", "Rare Candy", "招式学习器 进化", "Technical Machine: Evolution"],
}

const NS_PROFILE := {
	"strategy_id": "v18_ns_zoroark_character_delegate",
	"signatures": ["N的索罗亚克ex", "N's Zoroark ex", "N的莱希拉姆", "N's Reshiram"],
	"active_priority": ["皮宝宝", "Cleffa", "N的索罗亚", "N's Zorua", "N的火红不倒翁", "N's Darumaka"],
	"bench_priority": ["N的索罗亚", "N's Zorua", "N的莱希拉姆", "N's Reshiram", "N的火红不倒翁", "N's Darumaka", "愿增猿", "Munkidori"],
	"energy_priority": ["N的索罗亚克ex", "N's Zoroark ex", "N的索罗亚", "N's Zorua", "愿增猿", "Munkidori"],
	"evolution_priority": ["N的索罗亚克ex", "N's Zoroark ex", "N的达摩狒狒", "N's Darmanitan"],
	"search_priority": ["N的索罗亚克ex", "N's Zoroark ex", "N的索罗亚", "N's Zorua", "N的莱希拉姆", "N's Reshiram", "N的PP提升剂", "N's PP Up"],
	"ability_priority": ["N的索罗亚克ex", "N's Zoroark ex", "愿增猿", "Munkidori", "吉雉鸡ex", "Fezandipiti ex"],
	"trainer_priority": ["N的PP提升剂", "N's PP Up", "N的城堡", "N's Castle", "能量转移", "Energy Switch", "秘密箱", "Secret Box"],
}

const FAMILY_PROFILE := {
	"strategy_id": "v18_dark_character_family_delegate",
	"signatures": ["玛俐的长毛巨魔ex", "N的索罗亚克ex"],
	"active_priority": ["玛俐的捣蛋小妖", "N的索罗亚"],
	"bench_priority": ["玛俐的捣蛋小妖", "N的索罗亚"],
	"energy_priority": ["玛俐的长毛巨魔ex", "N的索罗亚克ex"],
	"evolution_priority": ["玛俐的长毛巨魔ex", "N的索罗亚克ex"],
	"search_priority": ["玛俐的长毛巨魔ex", "N的索罗亚克ex"],
	"ability_priority": ["玛俐的长毛巨魔ex", "N的索罗亚克ex"],
	"trainer_priority": ["神奇糖果", "N的PP提升剂"],
}

var _deck_id := 0
var _prediction_game_state: GameState = null
var _prediction_player_index := -1


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else 0
	_prediction_game_state = null
	_prediction_player_index = -1


func _profile() -> Dictionary:
	if _deck_id == MARNIE_DECK_ID:
		return MARNIE_PROFILE
	if _deck_id == NS_ZOROARK_DECK_ID:
		return NS_PROFILE
	return FAMILY_PROFILE


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	_remember_prediction_context(game_state, player_index)
	var player := _player(game_state, player_index)
	if _uses_marnie_route(player):
		return _build_marnie_plan(player)
	return _build_ns_plan(game_state, player_index, player)


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	_remember_prediction_context(game_state, player_index)
	var player := _player(game_state, player_index)
	if player == null:
		return {}
	if _uses_marnie_route(player):
		var debt := _marnie_setup_debt(player)
		return {
			"enabled": true,
			"safe_setup_before_attack": debt > 0 and _ready_marnie_attacker(player) != null,
			"setup_debt": {
				"missing_grimmsnarl_route": _count_field(player, MARNIE_GRIMMSNARL) == 0,
				"unfunded_marnie_energy": _marnie_energy_need(player),
			},
			"action_bonuses": [
				{"kind": "evolve", "target_names": ["玛俐的长毛巨魔ex", "玛俐的诈唬魔"], "bonus": 620.0},
				{"kind": "use_ability", "target_names": ["玛俐的长毛巨魔ex"], "bonus": 540.0},
				{"kind": "attach_energy", "target_names": ["玛俐的长毛巨魔ex", "玛俐的诈唬魔", "玛俐的捣蛋小妖"], "bonus": 320.0},
			],
			"attack_penalty": 720.0 if debt > 0 else 0.0,
		}
	var ns_debt := _ns_setup_debt(game_state, player_index, player)
	return {
		"enabled": true,
		"safe_setup_before_attack": ns_debt > 0 and _ready_ns_attacker(player) != null,
		"setup_debt": {
			"missing_zoroark_lane": _count_field(player, NS_ZOROARK) == 0,
			"missing_viable_copy_source": _best_n_copy_damage(game_state, player_index, player) < 90,
		},
		"action_bonuses": [
			{"kind": "play_basic_to_bench", "target_names": ["N的莱希拉姆", "N的索罗亚"], "bonus": 420.0},
			{"kind": "evolve", "target_names": ["N的索罗亚克ex"], "bonus": 520.0},
			{"kind": "use_ability", "target_names": ["N的索罗亚克ex"], "bonus": 260.0},
			{"kind": "play_trainer", "target_names": ["N的PP提升剂"], "bonus": 360.0},
		],
		"attack_penalty": 980.0 if ns_debt > 0 else 0.0,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	_remember_prediction_context(game_state, player_index)
	var score := super.score_action_absolute(action, game_state, player_index)
	var player := _player(game_state, player_index)
	if player == null:
		return score
	if _uses_marnie_route(player):
		return _score_marnie_action(action, game_state, player, score)
	return _score_ns_action(action, game_state, player_index, player, score)


func get_discard_priority(card: CardInstance) -> int:
	if _is_reversal_energy(card):
		return 2
	if _matches_any(card, MARNIE_GRIMMSNARL):
		return 3
	if _matches_any(card, MARNIE_MORGREM):
		return 6
	if _matches_any(card, MARNIE_IMPIDIMP):
		return 8
	if _matches_any(card, NS_ZOROARK):
		return 3
	if _matches_any(card, NS_ZORUA):
		return 7
	if _matches_any(card, NS_RESHIRAM) or _matches_any(card, NS_DARMANITAN):
		return 5
	if _matches_any(card, NS_DARUMAKA) or _matches_any(card, NS_PP_UP):
		return 10
	if _is_basic_darkness_energy(card):
		return 68
	return maxi(52, super.get_discard_priority(card))


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player := _player(game_state, player_index)
	if player == null:
		return get_discard_priority(card)
	if _uses_marnie_route(player):
		if _matches_any(card, MARNIE_GRIMMSNARL) and _count_field(player, MARNIE_GRIMMSNARL) == 0:
			return 1
		if _matches_any(card, MARNIE_MORGREM) and _count_field(player, MARNIE_MORGREM) == 0:
			return 3
		if _matches_any(card, MARNIE_IMPIDIMP) and _marnie_line_count(player) == 0:
			return 3
		if _matches_any(card, RARE_CANDY) and _has_marnie_seed(player) and _count_field(player, MARNIE_GRIMMSNARL) == 0:
			return 2
		return get_discard_priority(card)
	if _is_reversal_energy(card):
		return 1 if _count_hand_matches(player, REVERSAL_ENERGY) <= 1 else 42
	if _is_basic_darkness_energy(card):
		var active := player.active_pokemon
		var active_needs_manual := _matches_any(active, NS_ZOROARK) and _darkness_units(active) < 2
		if active_needs_manual and not game_state.energy_attached_this_turn and _basic_darkness_in_hand(player) <= 1:
			return 4
		return 112 if _has_ns_pp_target(player) else 64
	if _matches_any(card, NS_PP_UP):
		return 2 if _basic_energy_in_discard(player) > 0 and _has_ns_pp_target(player) else 58
	if _matches_any(card, NS_RESHIRAM):
		return 2 if _count_field(player, NS_RESHIRAM) == 0 else 54
	if _matches_any(card, NS_DARMANITAN):
		return 4 if _count_field(player, NS_DARMANITAN) == 0 else 50
	if _matches_any(card, NS_ZOROARK):
		return 3 if _count_field(player, NS_ZOROARK) == 0 else 38
	if _matches_any(card, NS_ZORUA):
		return 5 if _count_field(player, NS_ZORUA) + _count_field(player, NS_ZOROARK) < 2 else 44
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if _matches_any(card, MARNIE_GRIMMSNARL) or _matches_any(card, NS_ZOROARK):
		return 1000
	if _matches_any(card, MARNIE_MORGREM):
		return 930
	if _matches_any(card, MARNIE_IMPIDIMP) or _matches_any(card, NS_ZORUA):
		return 880
	if _matches_any(card, NS_RESHIRAM):
		return 850
	if _matches_any(card, NS_DARMANITAN):
		return 760
	if _matches_any(card, NS_DARUMAKA):
		return 690
	if _matches_any(card, NS_PP_UP):
		return 650
	if _is_basic_darkness_energy(card):
		return 620
	return super.get_search_priority(card)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	var max_select := maxi(1, int(step.get("max_select", 1)))
	if step_id == PUNK_UP_STEP:
		var darkness: Array = []
		for item: Variant in items:
			if item is CardInstance and _is_basic_darkness_energy(item as CardInstance):
				darkness.append(item)
		if darkness.is_empty():
			return super.pick_interaction_items(items, step, context)
		var player := _player_from_context(context)
		var wanted := mini(max_select, darkness.size())
		if player != null:
			wanted = mini(wanted, maxi(1, _marnie_energy_need(player)))
		var selected: Array = []
		for index: int in wanted:
			selected.append(darkness[index])
		return selected
	if step_id == NS_PP_UP_STEP:
		for item: Variant in items:
			if item is CardInstance and _is_basic_darkness_energy(item as CardInstance):
				return [item]
		for item: Variant in items:
			if item is CardInstance and _is_basic_energy(item as CardInstance):
				return [item]
	if step_id in [SPIKEMUTH_STEP, TRADE_DISCARD_STEP, COPIED_ATTACK_STEP]:
		return super.pick_interaction_items(items, {"id": step_id, "max_select": 1}, context)
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if item is Dictionary and step_id == COPIED_ATTACK_STEP:
		return _score_copied_attack_option(item as Dictionary, context)
	if item is CardInstance:
		var card := item as CardInstance
		if step_id == TRADE_DISCARD_STEP:
			return float(get_discard_priority_contextual(
				card,
				context.get("game_state", null),
				int(context.get("player_index", -1))
			))
		if step_id == SPIKEMUTH_STEP:
			return _marnie_search_score(card, player)
		if step_id == NS_PP_UP_STEP:
			if _is_basic_darkness_energy(card):
				return 4000.0
			return 800.0 if _is_basic_energy(card) else -1200.0
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == PUNK_UP_STEP:
			return _score_punk_up_target(slot, context)
		if step_id == NS_PP_UP_STEP:
			return _score_ns_pp_target(slot, context)
		if step_id.contains("send_out") or step_id.contains("handoff"):
			return score_handoff_target(slot, step, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	if not item is PokemonSlot:
		return super.score_handoff_target(item, step, context)
	var slot := item as PokemonSlot
	var player := _player_from_context(context)
	if _matches_any(slot, MARNIE_GRIMMSNARL):
		return 5200.0 if _darkness_units(slot) >= 2 else 2300.0
	if _matches_any(slot, NS_ZOROARK):
		var state: GameState = context.get("game_state", null)
		var index := int(context.get("player_index", -1))
		if _darkness_units(slot) >= 2 and _best_n_copy_damage(state, index, player) >= 90:
			return 5100.0
		return 1800.0
	if _matches_any(slot, MARNIE_IMPIDIMP) or _matches_any(slot, NS_ZORUA):
		return 720.0
	return super.score_handoff_target(item, step, context)


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or not _matches_any(slot, NS_ZOROARK):
		return super.predict_attacker_damage(slot, extra_context)
	var player_index := _prediction_player_index
	var top_card := slot.get_top_card()
	if top_card != null and _player(_prediction_game_state, top_card.owner_index) != null:
		player_index = top_card.owner_index
	var player := _player(_prediction_game_state, player_index)
	var copied := _best_n_copy_prediction(_prediction_game_state, player_index, player)
	var has_source := bool(copied.get("has_source", false))
	return {
		"damage": int(copied.get("damage", 0)),
		"can_attack": _darkness_units(slot) + extra_context >= 2 and has_source,
		"description": "night_joker:%s" % str(copied.get("attack_name", "")) if has_source else "night_joker:no_source",
	}


func _build_marnie_plan(player: PlayerState) -> Dictionary:
	var best_line := _best_marnie_line(player)
	var owner := _primary_name(best_line) if best_line != null else MARNIE_IMPIDIMP[0]
	var has_grimmsnarl := _count_field(player, MARNIE_GRIMMSNARL) > 0
	var ready := _ready_marnie_attacker(player)
	var bridge := MARNIE_IMPIDIMP[0]
	if not has_grimmsnarl:
		bridge = MARNIE_MORGREM[0]
		if _has_live_candy_bridge(player) or _count_field(player, MARNIE_MORGREM) > 0:
			bridge = MARNIE_GRIMMSNARL[0]
	elif _marnie_line_count(player) >= 2:
		bridge = MARNIE_GRIMMSNARL[0]
	var phase := "setup"
	if has_grimmsnarl:
		phase = "convert" if ready != null else "launch"
	var intent := "complete_marnie_evolution"
	if has_grimmsnarl:
		intent = "convert_shadow_bullet" if ready != null else "fund_punk_up_route"
	return {
		"id": "v18_dark_character_marnie",
		"intent": intent,
		"phase": phase,
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": bridge,
			"pivot_target_name": MARNIE_GRIMMSNARL[0],
		},
		"targets": {
			"primary_attacker_name": MARNIE_GRIMMSNARL[0],
			"bridge_target_name": bridge,
		},
		"priorities": {
			"attach": [MARNIE_GRIMMSNARL[0], MARNIE_MORGREM[0], MARNIE_IMPIDIMP[0], MUNKIDORI[0]],
			"handoff": [MARNIE_GRIMMSNARL[0]],
			"search": [bridge, MARNIE_GRIMMSNARL[0], MARNIE_MORGREM[0], MARNIE_IMPIDIMP[0]],
			"evolve": [MARNIE_GRIMMSNARL[0], MARNIE_MORGREM[0]],
			"ability": [MARNIE_GRIMMSNARL[0], MUNKIDORI[0]],
			"trainer": [SPIKEMUTH_GYM[0], RARE_CANDY[0], TM_EVOLUTION[0]],
		},
		"flags": {
			"dark_character_family": true,
			"marnie_route": true,
			"grimmsnarl_online": has_grimmsnarl,
			"punk_up_energy_need": _marnie_energy_need(player),
		},
	}


func _build_ns_plan(game_state: GameState, player_index: int, player: PlayerState) -> Dictionary:
	var zoroark := _best_slot(player, NS_ZOROARK)
	var zorua := _best_slot(player, NS_ZORUA)
	var owner := NS_ZORUA[0]
	if zoroark != null:
		owner = _primary_name(zoroark)
	elif zorua != null:
		owner = _primary_name(zorua)
	var copy_damage := _best_n_copy_damage(game_state, player_index, player)
	var ready := zoroark != null and _darkness_units(zoroark) >= 2 and copy_damage >= 90
	var phase := "setup"
	if zoroark != null:
		phase = "convert" if ready else "launch"
	var bridge := NS_RESHIRAM[0] if copy_damage < 90 else NS_ZOROARK[0]
	var intent := "establish_n_attack_source"
	if copy_damage >= 90:
		intent = "copy_best_n_attack" if ready else "complete_zoroark_lane"
	return {
		"id": "v18_dark_character_ns_zoroark",
		"intent": intent,
		"phase": phase,
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": bridge,
			"pivot_target_name": NS_ZOROARK[0],
		},
		"targets": {
			"primary_attacker_name": NS_ZOROARK[0],
			"bridge_target_name": bridge,
		},
		"priorities": {
			"attach": [NS_ZOROARK[0], NS_ZORUA[0], MUNKIDORI[0]],
			"handoff": [NS_ZOROARK[0]],
			"search": [bridge, NS_ZOROARK[0], NS_ZORUA[0], NS_PP_UP[0]],
			"evolve": [NS_ZOROARK[0], NS_DARMANITAN[0]],
			"ability": [NS_ZOROARK[0], MUNKIDORI[0]],
			"trainer": [NS_PP_UP[0], NS_CASTLE[0]],
		},
		"flags": {
			"dark_character_family": true,
			"ns_zoroark_route": true,
			"viable_copy_damage": copy_damage,
			"zoroark_ready": ready,
		},
	}


func _score_marnie_action(action: Dictionary, game_state: GameState, player: PlayerState, base_score: float) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_any(card, MARNIE_IMPIDIMP):
				return maxf(base_score, 3500.0 if _marnie_line_count(player) == 0 else 2200.0)
		"evolve":
			var target: PokemonSlot = action.get("target_slot", null)
			if _matches_any(card, MARNIE_GRIMMSNARL) and (_matches_any(target, MARNIE_MORGREM) or _matches_any(target, MARNIE_IMPIDIMP)):
				return maxf(base_score, 5400.0 if _basic_darkness_in_deck(player) > 0 else 3800.0)
			if _matches_any(card, MARNIE_MORGREM) and _matches_any(target, MARNIE_IMPIDIMP):
				return maxf(base_score, 3900.0)
		"attach_energy":
			return _score_marnie_attach(action, player, base_score)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_any(source, MARNIE_GRIMMSNARL):
				return maxf(base_score, 5600.0) if _basic_darkness_in_deck(player) > 0 and _marnie_energy_need(player) > 0 else -900.0
		"play_trainer":
			if _matches_any(card, RARE_CANDY):
				return maxf(base_score, 5000.0) if _has_live_candy_bridge(player) else -1500.0
		"play_stadium":
			if _matches_any(card, SPIKEMUTH_GYM):
				return maxf(base_score, 3300.0) if _count_field(player, MARNIE_GRIMMSNARL) == 0 else maxf(base_score, 900.0)
		"use_stadium_effect":
			if _count_field(player, MARNIE_GRIMMSNARL) == 0:
				return maxf(base_score, 3600.0)
		"attach_tool":
			if _matches_any(card, TM_EVOLUTION) and player.active_pokemon == action.get("target_slot", null) and _count_field(player, MARNIE_IMPIDIMP) > 0:
				return maxf(base_score, 3100.0)
		"attack", "granted_attack":
			return _score_marnie_attack(action, game_state, player, base_score)
	return base_score


func _score_ns_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	base_score: float
) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_any(card, NS_ZORUA):
				return maxf(base_score, 3400.0 if _count_field(player, NS_ZOROARK) + _count_field(player, NS_ZORUA) < 2 else 1600.0)
			if _matches_any(card, NS_RESHIRAM):
				return maxf(base_score, 3800.0 if _best_n_copy_damage(game_state, player_index, player) < 90 else 1300.0)
			if _matches_any(card, NS_DARUMAKA):
				return maxf(base_score, 1700.0)
		"evolve":
			var target: PokemonSlot = action.get("target_slot", null)
			if _matches_any(card, NS_ZOROARK) and _matches_any(target, NS_ZORUA):
				return maxf(base_score, 4700.0)
			if _matches_any(card, NS_DARMANITAN) and _matches_any(target, NS_DARUMAKA):
				return maxf(base_score, 2600.0)
		"attach_energy":
			return _score_ns_attach(action, player, base_score)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_any(source, NS_ZOROARK):
				if player.deck.size() <= 6:
					return -1900.0
				return maxf(base_score, 3700.0) if _best_trade_discard_priority(player, game_state, player_index) >= 50 else maxf(base_score, 900.0)
		"play_trainer":
			if _matches_any(card, NS_PP_UP):
				return maxf(base_score, 4300.0) if _basic_energy_in_discard(player) > 0 and _has_ns_pp_target(player) else -1800.0
		"play_stadium":
			if _matches_any(card, NS_CASTLE):
				return maxf(base_score, 1400.0)
		"attack", "granted_attack":
			return _score_ns_attack(action, game_state, player_index, player, base_score)
	return base_score


func _score_marnie_attach(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if energy == null or target == null or not _energy_pays_darkness(energy):
		return base_score
	if _matches_any(target, MARNIE_GRIMMSNARL):
		return maxf(base_score, 4200.0 - float(_darkness_units(target)) * 700.0) if _darkness_units(target) < 2 else maxf(base_score, 1200.0)
	if _matches_any(target, MARNIE_MORGREM):
		return maxf(base_score, 3600.0 - float(_darkness_units(target)) * 520.0)
	if _matches_any(target, MARNIE_IMPIDIMP):
		return maxf(base_score, 3100.0 - float(_darkness_units(target)) * 440.0)
	if _matches_any(target, MUNKIDORI) and _darkness_units(target) == 0:
		return maxf(base_score, 2500.0 if _ready_marnie_attacker(player) != null else 1500.0)
	return minf(base_score, -1200.0)


func _score_ns_attach(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if energy == null or target == null or not _energy_pays_darkness(energy):
		return base_score
	if _matches_any(target, NS_ZOROARK):
		return maxf(base_score, 4300.0 - float(_darkness_units(target)) * 760.0) if _darkness_units(target) < 2 else maxf(base_score, 900.0)
	if _matches_any(target, NS_ZORUA):
		return maxf(base_score, 3600.0 - float(_darkness_units(target)) * 620.0)
	if _matches_any(target, MUNKIDORI) and _darkness_units(target) == 0 and _ready_ns_attacker(player) != null:
		return maxf(base_score, 2200.0)
	if _is_n_character(target):
		return minf(base_score, 300.0)
	return minf(base_score, -1300.0)


func _score_marnie_attack(action: Dictionary, _game_state: GameState, player: PlayerState, base_score: float) -> float:
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	var attack_name := _attack_name(action, source)
	if _matches_any(source, MARNIE_GRIMMSNARL):
		return maxf(base_score, 3400.0 + float(int(action.get("projected_damage", 0))) * 2.0)
	if _matches_any(source, MARNIE_IMPIDIMP):
		if attack_name in ["骗取", "Cheeky Draw"] and player.deck.size() > 6:
			return 1150.0
		if bool(action.get("projected_knockout", false)):
			return 2300.0
		return -300.0
	return base_score


func _score_ns_attack(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	base_score: float
) -> float:
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	var attack_name := _attack_name(action, source)
	if _matches_any(source, NS_ZOROARK) and _is_night_joker_name(attack_name):
		var copy_damage := _best_n_copy_damage(game_state, player_index, player)
		if copy_damage < 90:
			return -2600.0
		return maxf(base_score, 3200.0 + float(copy_damage) * 3.0)
	if _matches_any(source, NS_ZORUA) and not bool(action.get("projected_knockout", false)):
		return -500.0
	return base_score


func _marnie_search_score(card: CardInstance, player: PlayerState) -> float:
	if _matches_any(card, MARNIE_GRIMMSNARL):
		if _count_field(player, MARNIE_MORGREM) > 0 or _has_candy_seed_route(player):
			return 5200.0
		return 1200.0
	if _matches_any(card, MARNIE_MORGREM):
		return 4700.0 if _has_marnie_seed(player) else 900.0
	if _matches_any(card, MARNIE_IMPIDIMP):
		return 4300.0 if _marnie_line_count(player) == 0 else 1700.0
	return 0.0


func _score_punk_up_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return -INF
	var pending := _pending_assignment_count(slot, context)
	var total := _darkness_units(slot) + pending
	var active_bonus := 320.0 if _is_active_context_slot(slot, context) else 0.0
	if _matches_any(slot, MARNIE_GRIMMSNARL):
		return (5200.0 - float(total) * 400.0 if total < 2 else 1600.0 - float(total) * 60.0) + active_bonus
	if _matches_any(slot, MARNIE_MORGREM):
		return (4400.0 - float(total) * 360.0 if total < 2 else 1300.0) + active_bonus
	if _matches_any(slot, MARNIE_IMPIDIMP):
		return (3600.0 - float(total) * 320.0 if total < 2 else 1000.0) + active_bonus
	return -1400.0


func _score_ns_pp_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return -INF
	var source: Variant = context.get("assignment_source", context.get("source_card", null))
	if source is CardInstance and not _energy_pays_darkness(source as CardInstance):
		return 200.0 if _is_n_character(slot) else -1500.0
	var total := _darkness_units(slot) + _pending_assignment_count(slot, context)
	if _matches_any(slot, NS_ZOROARK):
		return 5200.0 - float(total) * 620.0 if total < 2 else 1400.0
	if _matches_any(slot, NS_ZORUA):
		return 4500.0 - float(total) * 520.0 if total < 2 else 1200.0
	if _matches_any(slot, NS_RESHIRAM) or _matches_any(slot, NS_DARMANITAN) or _matches_any(slot, NS_DARUMAKA):
		return 500.0
	return -1300.0


func _score_copied_attack_option(option: Dictionary, context: Dictionary) -> float:
	var attack: Dictionary = {}
	var raw_attack: Variant = option.get("attack", {})
	if raw_attack is Dictionary:
		attack = raw_attack as Dictionary
	var name := str(attack.get("name", ""))
	if _is_night_joker_name(name):
		return -3000.0
	var damage := _estimate_copy_attack_damage(attack, context.get("game_state", null), int(context.get("player_index", -1)))
	var score := 900.0 + float(damage) * 8.0
	if name in ["焚身加农炮", "Immolating Cannon"]:
		score -= 400.0
		score += 320.0
	if name in ["纯真火焰", "Virtuous Flame"]:
		score += 80.0
	return score


func _estimate_copy_attack_damage(attack: Dictionary, game_state: GameState, player_index: int) -> int:
	var name := str(attack.get("name", ""))
	var player := _player(game_state, player_index)
	if name in ["力量愤怒", "Powerful Rage"]:
		return player.active_pokemon.damage_counters * 2 if player != null and player.active_pokemon != null else 0
	if name in ["复燃", "Reignite"]:
		return _opponent_basic_energy_discard_count(game_state, player_index) * 30
	return _parse_damage(str(attack.get("damage", "")))


func _best_n_copy_damage(game_state: GameState, player_index: int, player: PlayerState) -> int:
	return int(_best_n_copy_prediction(game_state, player_index, player).get("damage", 0))


func _best_n_copy_prediction(game_state: GameState, player_index: int, player: PlayerState) -> Dictionary:
	if player == null:
		return {"damage": 0, "attack_name": "", "has_source": false}
	var best := {"damage": 0, "attack_name": "", "has_source": false}
	for slot: PokemonSlot in player.bench:
		if slot == null or not _is_n_character(slot):
			continue
		for attack: Dictionary in slot.get_attacks():
			if bool(attack.get("is_vstar_power", false)) or _is_night_joker_name(str(attack.get("name", ""))):
				continue
			var damage := _estimate_copy_attack_damage(attack, game_state, player_index)
			if not bool(best.get("has_source", false)) or damage > int(best.get("damage", 0)):
				best = {
					"damage": damage,
					"attack_name": str(attack.get("name", "")),
					"has_source": true,
				}
	return best


func _marnie_setup_debt(player: PlayerState) -> int:
	if player == null:
		return 0
	var debt := 0
	if _marnie_line_count(player) == 0:
		debt += 1
	if _count_field(player, MARNIE_GRIMMSNARL) == 0:
		debt += 2
	debt += mini(2, _marnie_energy_need(player))
	return debt


func _ns_setup_debt(game_state: GameState, player_index: int, player: PlayerState) -> int:
	if player == null:
		return 0
	var debt := 0
	if _count_field(player, NS_ZOROARK) == 0:
		debt += 2
	if _best_n_copy_damage(game_state, player_index, player) < 90:
		debt += 1
	if _count_field(player, NS_ZOROARK) + _count_field(player, NS_ZORUA) < 2:
		debt += 1
	return debt


func _marnie_energy_need(player: PlayerState) -> int:
	if player == null:
		return 0
	var need := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, MARNIE_GRIMMSNARL) or _matches_any(slot, MARNIE_MORGREM) or _matches_any(slot, MARNIE_IMPIDIMP):
			need += maxi(0, 2 - _darkness_units(slot))
	return mini(5, need)


func _ready_marnie_attacker(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, MARNIE_GRIMMSNARL) and _darkness_units(slot) >= 2:
			return slot
	return null


func _ready_ns_attacker(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, NS_ZOROARK) and _darkness_units(slot) >= 2:
			return slot
	return null


func _best_marnie_line(player: PlayerState) -> PokemonSlot:
	var slot := _best_slot(player, MARNIE_GRIMMSNARL)
	if slot != null:
		return slot
	slot = _best_slot(player, MARNIE_MORGREM)
	if slot != null:
		return slot
	return _best_slot(player, MARNIE_IMPIDIMP)


func _best_slot(player: PlayerState, names: Array[String]) -> PokemonSlot:
	var best: PokemonSlot = null
	var best_energy := -1
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_any(slot, names):
			continue
		var energy := _darkness_units(slot)
		if best == null or energy > best_energy:
			best = slot
			best_energy = energy
	return best


func _marnie_line_count(player: PlayerState) -> int:
	return _count_field(player, MARNIE_IMPIDIMP) + _count_field(player, MARNIE_MORGREM) + _count_field(player, MARNIE_GRIMMSNARL)


func _has_marnie_seed(player: PlayerState) -> bool:
	return _count_field(player, MARNIE_IMPIDIMP) > 0


func _has_live_candy_bridge(player: PlayerState) -> bool:
	return _has_candy_seed_route(player) and _hand_has(player, MARNIE_GRIMMSNARL)


func _has_candy_seed_route(player: PlayerState) -> bool:
	return player != null and _has_marnie_seed(player) and _hand_has(player, RARE_CANDY)


func _has_ns_pp_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if (_matches_any(slot, NS_ZOROARK) or _matches_any(slot, NS_ZORUA)) and _darkness_units(slot) < 2:
			return true
	return false


func _best_trade_discard_priority(player: PlayerState, game_state: GameState, player_index: int) -> int:
	var best := -1
	for card: CardInstance in player.hand:
		best = maxi(best, get_discard_priority_contextual(card, game_state, player_index))
	return best


func _basic_darkness_in_hand(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.hand:
			if _is_basic_darkness_energy(card):
				count += 1
	return count


func _basic_darkness_in_deck(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.deck:
			if _is_basic_darkness_energy(card):
				count += 1
	return count


func _basic_energy_in_discard(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.discard_pile:
			if _is_basic_energy(card):
				count += 1
	return count


func _opponent_basic_energy_discard_count(game_state: GameState, player_index: int) -> int:
	if game_state == null:
		return 0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0
	return _basic_energy_in_discard(game_state.players[opponent_index])


func _darkness_units(slot: PokemonSlot) -> int:
	var count := 0
	if slot != null:
		for energy: CardInstance in slot.attached_energy:
			if _energy_pays_darkness(energy):
				count += 1
	return count


func _is_basic_darkness_energy(card: CardInstance) -> bool:
	return _is_basic_energy(card) and _energy_symbol(card) == "D"


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and str(card.card_data.card_type) == "Basic Energy"


func _energy_pays_darkness(card: CardInstance) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return false
	var symbol := _energy_symbol(card)
	return symbol == "D" or symbol == "ANY" or "D" in symbol


func _energy_symbol(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	var symbol := str(card.card_data.energy_provides)
	if symbol == "":
		symbol = str(card.card_data.energy_type)
	return symbol.to_upper()


func _count_field(player: PlayerState, names: Array[String]) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, names):
			count += 1
	return count


func _hand_has(player: PlayerState, names: Array[String]) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _matches_any(card, names):
			return true
	return false


func _count_hand_matches(player: PlayerState, names: Array[String]) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.hand:
			if _matches_any(card, names):
				count += 1
	return count


func _is_n_character(item: Variant) -> bool:
	var data := _card_data_from_item(item)
	if data == null or not data.is_pokemon():
		return false
	if _matches_any(item, NS_ZORUA) or _matches_any(item, NS_ZOROARK) or _matches_any(item, NS_RESHIRAM) \
			or _matches_any(item, NS_DARUMAKA) or _matches_any(item, NS_DARMANITAN):
		return true
	for raw_name: Variant in [data.name, data.name_en, data.name_zh]:
		var name := _normalize_name(str(raw_name))
		if name.begins_with("n's ") or name.begins_with("n的"):
			return true
	return false


func _is_reversal_energy(item: Variant) -> bool:
	var data := _card_data_from_item(item)
	return data != null and data.is_energy() and _matches_any(item, REVERSAL_ENERGY)


func _uses_marnie_route(player: PlayerState) -> bool:
	if _deck_id == MARNIE_DECK_ID:
		return true
	if _deck_id == NS_ZOROARK_DECK_ID:
		return false
	if player == null:
		return false
	for item: Variant in _all_slots(player):
		if _matches_any(item, MARNIE_GRIMMSNARL) or _matches_any(item, MARNIE_MORGREM) or _matches_any(item, MARNIE_IMPIDIMP):
			return true
	for item: Variant in player.hand:
		if _matches_any(item, MARNIE_GRIMMSNARL) or _matches_any(item, MARNIE_MORGREM) or _matches_any(item, MARNIE_IMPIDIMP):
			return true
	for item: Variant in player.deck:
		if _matches_any(item, MARNIE_GRIMMSNARL) or _matches_any(item, MARNIE_MORGREM) or _matches_any(item, MARNIE_IMPIDIMP):
			return true
	for item: Variant in player.discard_pile:
		if _matches_any(item, MARNIE_GRIMMSNARL) or _matches_any(item, MARNIE_MORGREM) or _matches_any(item, MARNIE_IMPIDIMP):
			return true
	return false


func _matches_any(item: Variant, names: Array[String]) -> bool:
	var labels: Array[String] = []
	var data := _card_data_from_item(item)
	if data != null:
		for label: Variant in [data.name, data.name_en, data.name_zh, data.get_uid(), data.effect_id]:
			var normalized := _normalize_name(str(label))
			if normalized != "" and not labels.has(normalized):
				labels.append(normalized)
		if str(data.set_code) != "" and str(data.card_index) != "":
			labels.append(_normalize_name("%s_%s" % [data.set_code, data.card_index]))
	else:
		labels.append(_normalize_name(str(item)))
	for name: String in names:
		if _normalize_name(name) in labels:
			return true
	return false


func _normalize_name(value: String) -> String:
	return value.strip_edges().to_lower().replace(char(0x2019), "'").replace(char(0x2018), "'").replace(char(0x02BC), "'")


func _attack_name(action: Dictionary, source: PokemonSlot) -> String:
	var name := str(action.get("attack_name", "")).strip_edges()
	if name != "":
		return name
	var granted_attack_data: Variant = action.get("granted_attack_data", {})
	if granted_attack_data is Dictionary:
		name = str((granted_attack_data as Dictionary).get("name", "")).strip_edges()
		if name != "":
			return name
	var attack_index := int(action.get("attack_index", -1))
	if source != null and attack_index >= 0 and attack_index < source.get_attacks().size():
		return str(source.get_attacks()[attack_index].get("name", ""))
	return ""


func _is_night_joker_name(name: String) -> bool:
	return name in ["暗夜王牌", "暗夜小丑", "Night Joker"]


func _parse_damage(text: String) -> int:
	var digits := ""
	for index: int in text.length():
		var character := text.substr(index, 1)
		if character >= "0" and character <= "9":
			digits += character
		elif digits != "":
			break
	return int(digits) if digits != "" else 0


func _pending_assignment_count(slot: PokemonSlot, context: Dictionary) -> int:
	var pending: Variant = context.get("pending_assignment_counts", {})
	if not pending is Dictionary or slot == null:
		return 0
	return int((pending as Dictionary).get(slot.get_instance_id(), 0))


func _is_active_context_slot(slot: PokemonSlot, context: Dictionary) -> bool:
	var player := _player_from_context(context)
	return player != null and player.active_pokemon == slot


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	return _player(context.get("game_state", null), int(context.get("player_index", -1)))


func _remember_prediction_context(game_state: GameState, player_index: int) -> void:
	if _player(game_state, player_index) == null:
		return
	_prediction_game_state = game_state
	_prediction_player_index = player_index


func _player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]
