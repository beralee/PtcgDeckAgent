class_name DeckStrategyV18MarnieCynthia
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const MARNIE_DECK_ID := 800018501
const CYNTHIA_DECK_ID := 800018543

const IMPIDIMP := "玛俐的捣蛋小妖"
const MORGREM := "玛俐的诈唬魔"
const GRIMMSNARL := "玛俐的长毛巨魔ex"
const SNORUNT := "雪童子"
const FROSLASS := "雪妖女"
const SHAYMIN := "谢米"

const GIBLE := "竹兰的圆陆鲨"
const GABITE := "竹兰的尖牙陆鲨"
const GARCHOMP := "竹兰的烈咬陆鲨ex"
const ROSELIA := "竹兰的毒蔷薇"
const ROSERADE := "竹兰的罗丝雷朵"
const SPIRITOMB := "竹兰的花岩怪"
const POWER_WEIGHT := "竹兰的力量负重"

const MUNKIDORI := "愿增猿"
const BUDEW := "含羞苞"
const RARE_CANDY := "神奇糖果"
const TM_EVOLUTION := "招式学习器 进化"
const SPIKEMUTH_GYM := "尖钉镇道馆"
const NIGHT_STRETCHER := "夜间担架"
const SUPER_ROD := "厉害钓竿"
const EARTHEN_VESSEL := "大地容器"
const CRISPIN := "赤松"
const SECRET_BOX := "秘密箱"
const BUDDY_BUDDY_POFFIN := "友好宝芬"
const BOSS_ORDERS := "老大的指令"
const COUNTER_CATCHER := "反击捕捉器"

const NO_BALLOON_GARDEVOIR_STRATEGY_ID := "v18_800017097_no_balloon_gardevoir"
const OPPONENT_RALTS_NAMES: Array[String] = ["拉鲁拉丝", "Ralts"]
const OPPONENT_KIRLIA_NAMES: Array[String] = ["奇鲁莉安", "Kirlia"]
const OPPONENT_GARDEVOIR_NAMES: Array[String] = ["沙奈朵ex", "Gardevoir ex"]
const OPPONENT_MUNKIDORI_NAMES: Array[String] = ["愿增猿", "Munkidori"]

const DARKNESS_ENERGY := "基本恶能量"
const FIGHTING_ENERGY := "基本斗能量"
const LUMINOUS_ENERGY := "夜光能量"

const PUNK_UP_STEP := "marnies_punk_up_assignments"
const SPIKEMUTH_STEP := "spikemuth_gym_marnies_pokemon"
const CYNTHIA_SEARCH_STEP := "csv10c_named_pokemon_search"
const CRISPIN_HAND_STEP := "csv9c196_energy_to_hand"
const CRISPIN_ATTACH_STEP := "csv9c196_energy_attachment"

const IDENTITY_ALIASES := {
	IMPIDIMP: [IMPIDIMP, "Marnie's Impidimp", "CSV10C_146", "cd9d3ec383aa409ff7930840c21d43b0"],
	MORGREM: [MORGREM, "Marnie's Morgrem", "CSV10C_147", "945c3caf74096499c2140de9f71d815e"],
	GRIMMSNARL: [GRIMMSNARL, "Marnie's Grimmsnarl ex", "CSV10C_148", "863479acd128e1e5e2643a3a1e77ce26"],
	SNORUNT: [SNORUNT, "Snorunt", "CSV9.5C_043", "f6baf0c4c60ff47c7f836c1271f40cb3"],
	FROSLASS: [FROSLASS, "Froslass", "CSV7C_059", "f27a2982c03f5b49a68ec0a77a2d6e48"],
	SHAYMIN: [SHAYMIN, "Shaymin", "CSV10C_007", "fd1e9b0379f79156fbb304162cbe21ba"],
	GIBLE: [GIBLE, "Cynthia's Gible", "CSV10C_111", "1bbd1874c0cc4c60d3f1128e8583d583"],
	GABITE: [GABITE, "Cynthia's Gabite", "CSV10C_112", "23e6f24fc40bdb19384bc3c7822beea1"],
	GARCHOMP: [GARCHOMP, "Cynthia's Garchomp ex", "CSV10C_113", "b494c15a64405edbc24ed017733ad8a5"],
	ROSELIA: [ROSELIA, "Cynthia's Roselia", "CSV10C_004", "727c75c20bc176aedf17c8190ab91044"],
	ROSERADE: [ROSERADE, "Cynthia's Roserade", "CSV10C_005", "3040f040cd7a982b18f5e8359ab1ed21"],
	SPIRITOMB: [SPIRITOMB, "Cynthia's Spiritomb", "CSV10C_138", "3c4ab79ab7320fa3a57639e232f507e9"],
	POWER_WEIGHT: [POWER_WEIGHT, "Cynthia's Power Weight", "CSV10C_200", "a13a8391817936aaa9c79cd3cfe5483f"],
	MUNKIDORI: [MUNKIDORI, "Munkidori", "CSV8C_094", "66fee12502043db7d92b97b0d62b0f59"],
	BUDEW: [BUDEW, "Budew", "CSV9.5C_004", "28505a8ad6e07e74382c1b5e09737932"],
	RARE_CANDY: [RARE_CANDY, "Rare Candy", "CSVH1C_045", "d3891abcfe3277c8811cde06741d3236"],
	TM_EVOLUTION: [TM_EVOLUTION, "Technical Machine: Evolution", "CSV5C_119", "43386015be5c073ba2e5b9d3692ece3f"],
	SPIKEMUTH_GYM: [SPIKEMUTH_GYM, "Spikemuth Gym", "CSV10C_216", "dc1d73740f5d6e98ad1491ca9067aac3"],
	NIGHT_STRETCHER: [NIGHT_STRETCHER, "Night Stretcher", "CSV8C_183", "3e6f1daf545dfed48d0588dd50792a2e"],
	SUPER_ROD: [SUPER_ROD, "Super Rod", "CSV1C_109", "c9c948169525fbb3dce70c477ec7a90a"],
	EARTHEN_VESSEL: [EARTHEN_VESSEL, "Earthen Vessel", "CSV6C_115", "e366f56ecd3f805a28294109a1a37453"],
	CRISPIN: [CRISPIN, "Crispin", "CSV9C_196", "136fdb6578daa3b81aef369495de4c3d"],
	SECRET_BOX: [SECRET_BOX, "Secret Box", "CSV8C_176", "e92a86246f44351d023bd4fa271089aa"],
	BUDDY_BUDDY_POFFIN: [BUDDY_BUDDY_POFFIN, "Buddy-Buddy Poffin", "CSV7C_177", "f866dfee26cd6b0dbbb52b74438d0a59"],
	DARKNESS_ENERGY: [DARKNESS_ENERGY, "Darkness Energy", "CSVE1C_DAR", "46c769fc57a6c250c560df648bb779f8"],
	FIGHTING_ENERGY: [FIGHTING_ENERGY, "Fighting Energy", "CSVE1C_FIG", "9fedb80a97ddd5cc8b8022a21364c326"],
	LUMINOUS_ENERGY: [LUMINOUS_ENERGY, "Luminous Energy", "CSV1C_127", "540ee48bb93584e4bfe3d7f5d0ee0efc"],
}

const MARNIE_PROFILE := {
	"strategy_id": "v18_marnie_cynthia_800018501",
	"signatures": [GRIMMSNARL, "Marnie's Grimmsnarl ex", "CSV10C_148"],
	"active_priority": [BUDEW, IMPIDIMP, SNORUNT, SHAYMIN, MUNKIDORI],
	"bench_priority": [IMPIDIMP, SNORUNT, MUNKIDORI, SHAYMIN],
	"search_priority": [GRIMMSNARL, MORGREM, IMPIDIMP, FROSLASS, SNORUNT, RARE_CANDY, DARKNESS_ENERGY],
	"evolution_priority": [GRIMMSNARL, MORGREM, FROSLASS],
	"energy_priority": [GRIMMSNARL, MORGREM, IMPIDIMP, MUNKIDORI],
	"ability_priority": [GRIMMSNARL, FROSLASS, MUNKIDORI],
}

const CYNTHIA_PROFILE := {
	"strategy_id": "v18_marnie_cynthia_800018543",
	"signatures": [GARCHOMP, "Cynthia's Garchomp ex", "CSV10C_113"],
	"active_priority": [BUDEW, SPIRITOMB, GIBLE, ROSELIA, MUNKIDORI],
	"bench_priority": [GIBLE, ROSELIA, MUNKIDORI, SPIRITOMB],
	"search_priority": [GABITE, GARCHOMP, ROSERADE, GIBLE, ROSELIA, FIGHTING_ENERGY, POWER_WEIGHT],
	"evolution_priority": [GARCHOMP, ROSERADE, GABITE],
	"energy_priority": [GARCHOMP, GABITE, GIBLE, MUNKIDORI, SPIRITOMB],
	"ability_priority": [GABITE, ROSERADE, MUNKIDORI],
}

var _deck_id := 0
var _prediction_game_state: GameState = null
var _prediction_player_index := -1


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else 0
	_prediction_game_state = null
	_prediction_player_index = -1


func _profile() -> Dictionary:
	return MARNIE_PROFILE if _deck_id == MARNIE_DECK_ID else CYNTHIA_PROFILE


func get_strategy_id() -> String:
	return str(_profile().get("strategy_id", "v18_marnie_cynthia_%d" % _deck_id))


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
			"active": _opening_active_score(card),
			"bench": _opening_bench_score(card),
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
	var identity_counts: Dictionary = {}
	for entry: Dictionary in bench_candidates:
		var index := int(entry.get("index", -1))
		if index == active_index or float(entry.get("bench", 0.0)) <= 0.0:
			continue
		var card: CardInstance = player.hand[index]
		var identity := _opening_identity(card)
		var cap := _opening_identity_cap(identity)
		if int(identity_counts.get(identity, 0)) >= cap:
			continue
		bench_indices.append(index)
		identity_counts[identity] = int(identity_counts.get(identity, 0)) + 1
		if bench_indices.size() >= 4:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	_remember_prediction_context(game_state, player_index)
	var player := _valid_player(game_state, player_index)
	if player == null:
		return {}
	return _build_marnie_plan(game_state, player, context) if _deck_id == MARNIE_DECK_ID else _build_cynthia_plan(game_state, player, context)


func build_matchup_overlay(
	_game_state: GameState,
	_player_index: int,
	matchup_context: Dictionary
) -> Dictionary:
	if _deck_id != MARNIE_DECK_ID \
			or str(matchup_context.get("opponent_strategy_id", "")) != NO_BALLOON_GARDEVOIR_STRATEGY_ID:
		return {}
	return {
		"id": "marnie_vs_no_balloon_gardevoir_froslass_pressure_v1",
		"opponent_strategy_id": NO_BALLOON_GARDEVOIR_STRATEGY_ID,
		"flags": {
			"matchup_froslass_pressure": true,
			"matchup_froslass_target_count": 2,
			"matchup_gust_ability_engine": true,
		},
		"priorities": {
			"search": [FROSLASS, SNORUNT, GRIMMSNARL, MORGREM],
			"evolve": [FROSLASS, GRIMMSNARL, MORGREM],
			"ability": [MUNKIDORI, GRIMMSNARL],
			"trainer": [COUNTER_CATCHER, BOSS_ORDERS, SPIKEMUTH_GYM],
		},
	}


func score_matchup_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	matchup_context: Dictionary,
	_turn_contract: Dictionary = {}
) -> float:
	if _deck_id != MARNIE_DECK_ID \
			or str(matchup_context.get("opponent_strategy_id", "")) != NO_BALLOON_GARDEVOIR_STRATEGY_ID:
		return 0.0
	var player := _valid_player(game_state, player_index)
	if player == null:
		return 0.0
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_key(card, SNORUNT) and _count_slots(player, SNORUNT) < 2:
				return 900.0
		"evolve":
			if _matches_key(card, FROSLASS) and _count_slots(player, FROSLASS) < 2:
				return 1400.0
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_key(source, MUNKIDORI):
				return 650.0
		"play_trainer":
			if _card_matches_names(card, [BOSS_ORDERS, "Boss's Orders", COUNTER_CATCHER, "Counter Catcher"]):
				return 500.0 if _opponent_has_gardevoir_engine_target(game_state, player_index) else 0.0
		"end_turn":
			if _count_slots(player, FROSLASS) == 0 and _count_slots(player, SNORUNT) > 0:
				return -700.0
	return 0.0


func score_matchup_interaction_target(
	item: Variant,
	step: Dictionary,
	context: Dictionary,
	matchup_context: Dictionary
) -> float:
	if _deck_id != MARNIE_DECK_ID \
			or str(matchup_context.get("opponent_strategy_id", "")) != NO_BALLOON_GARDEVOIR_STRATEGY_ID \
			or not (item is PokemonSlot):
		return 0.0
	var step_id := str(step.get("id", "")).to_lower()
	if step_id not in ["opponent_bench_target", "opponent_bench_damage_targets"]:
		return 0.0
	var slot := item as PokemonSlot
	var top_card := slot.get_top_card()
	if top_card == null or int(top_card.owner_index) == int(context.get("player_index", -1)):
		return 0.0
	if _slot_matches_names(slot, OPPONENT_GARDEVOIR_NAMES):
		return 1800.0
	if _slot_matches_names(slot, OPPONENT_KIRLIA_NAMES):
		return 1500.0
	if _slot_matches_names(slot, OPPONENT_MUNKIDORI_NAMES):
		return 1000.0
	if _slot_matches_names(slot, OPPONENT_RALTS_NAMES):
		return 700.0
	return 0.0


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _valid_player(game_state, player_index)
	if player == null:
		return {}
	var debt := _setup_debt(player)
	var ready := _ready_attacker(player) != null
	var needs_poffin_before_chip := _needs_cynthia_poffin_before_chip(player, game_state)
	debt["needs_poffin_before_chip"] = int(needs_poffin_before_chip)
	debt["total"] = int(debt.get("total", 0)) + int(needs_poffin_before_chip)
	var evolution_names: Array[String] = []
	var attach_names: Array[String] = []
	var ability_names: Array[String] = []
	var action_bonuses: Array[Dictionary] = []
	if _deck_id == MARNIE_DECK_ID:
		_append_identity_aliases(evolution_names, GRIMMSNARL)
		_append_identity_aliases(evolution_names, MORGREM)
		_append_identity_aliases(evolution_names, FROSLASS)
		_append_identity_aliases(attach_names, GRIMMSNARL)
		_append_identity_aliases(attach_names, MORGREM)
		_append_identity_aliases(attach_names, IMPIDIMP)
		_append_identity_aliases(attach_names, MUNKIDORI)
		_append_identity_aliases(ability_names, GRIMMSNARL)
	else:
		_append_identity_aliases(evolution_names, GARCHOMP)
		_append_identity_aliases(evolution_names, GABITE)
		_append_identity_aliases(evolution_names, ROSERADE)
		_append_identity_aliases(attach_names, GARCHOMP)
		_append_identity_aliases(attach_names, GABITE)
		_append_identity_aliases(attach_names, GIBLE)
		_append_identity_aliases(attach_names, MUNKIDORI)
		_append_identity_aliases(ability_names, GABITE)
	_append_identity_aliases(ability_names, MUNKIDORI)
	action_bonuses.assign([
		{"kind": "evolve", "card_names": evolution_names, "bonus": 680.0},
		{"kind": "attach_energy", "target_names": attach_names, "bonus": 420.0},
		{"kind": "use_ability", "target_names": ability_names, "bonus": 320.0},
	])
	if needs_poffin_before_chip:
		action_bonuses.append({
			"kind": "play_trainer",
			"card_names": IDENTITY_ALIASES.get(BUDDY_BUDDY_POFFIN, []),
			"bonus": 280.0,
		})
	return {
		"enabled": true,
		"safe_setup_before_attack": needs_poffin_before_chip or (ready and int(debt.get("total", 0)) > 0),
		"setup_debt": debt,
		"action_bonuses": action_bonuses,
		"attack_penalty": 920.0 if int(debt.get("total", 0)) > 0 else 0.0,
	}


func _append_identity_aliases(target: Array[String], key: String) -> void:
	var aliases: Variant = IDENTITY_ALIASES.get(key, [])
	if aliases is not Array:
		return
	for alias: Variant in aliases:
		target.append(str(alias))


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	_remember_prediction_context(game_state, player_index)
	var base_score := super.score_action_absolute(action, game_state, player_index)
	var player := _valid_player(game_state, player_index)
	if player == null:
		return base_score
	if _is_low_deck_churn(action, player):
		return -2200.0
	return _score_marnie_action(action, player, base_score) if _deck_id == MARNIE_DECK_ID else _score_cynthia_action(action, player, game_state, base_score)


func get_discard_priority(card: CardInstance) -> int:
	if card == null:
		return 0
	if _deck_id == MARNIE_DECK_ID:
		if _matches_key(card, GRIMMSNARL): return 3
		if _matches_key(card, MORGREM): return 5
		if _matches_key(card, IMPIDIMP): return 7
		if _matches_key(card, FROSLASS): return 6
		if _matches_key(card, SNORUNT): return 9
		if _matches_key(card, MUNKIDORI) or _matches_key(card, RARE_CANDY): return 11
		if _is_basic_energy(card, "D"): return 68
	else:
		if _matches_key(card, GARCHOMP): return 3
		if _matches_key(card, GABITE): return 5
		if _matches_key(card, GIBLE): return 7
		if _matches_key(card, ROSERADE): return 6
		if _matches_key(card, ROSELIA): return 9
		if _matches_key(card, POWER_WEIGHT) or _matches_key(card, TM_EVOLUTION): return 12
		if _is_basic_energy(card, "F"): return 18
		if _is_basic_energy(card, "D") or _matches_key(card, LUMINOUS_ENERGY): return 24
	return maxi(52, super.get_discard_priority(card))


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player := _valid_player(game_state, player_index)
	if player == null:
		return get_discard_priority(card)
	if _deck_id == MARNIE_DECK_ID:
		if _matches_key(card, RARE_CANDY) and _has_slot(player, IMPIDIMP) and not _has_slot(player, GRIMMSNARL):
			return 1
		if _matches_key(card, GRIMMSNARL) and (_has_slot(player, MORGREM) or _has_live_marnie_candy_route(player)):
			return 1
		if _matches_key(card, MORGREM) and _has_slot(player, IMPIDIMP) and not _has_slot(player, MORGREM):
			return 2
		if _is_basic_energy(card, "D") and _marnie_manual_energy_need(player) > 0 and _count_basic_energy(player.hand, "D") <= 1:
			return 3
	else:
		if _matches_key(card, GARCHOMP) and _has_slot(player, GABITE) and not _has_slot(player, GARCHOMP):
			return 1
		if _matches_key(card, GABITE) and _has_slot(player, GIBLE) and not _has_slot(player, GABITE):
			return 2
		if _matches_key(card, ROSERADE) and _has_slot(player, ROSELIA) and not _has_slot(player, ROSERADE):
			return 2
		if _is_basic_energy(card, "F") and _ready_garchomp(player) == null and _count_basic_energy(player.hand, "F") <= 1:
			return 2
		if (_is_basic_energy(card, "D") or _matches_key(card, LUMINOUS_ENERGY)) and _has_slot(player, MUNKIDORI) and not _has_funded_munkidori(player):
			return 4
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if _deck_id == MARNIE_DECK_ID:
		if _matches_key(card, GRIMMSNARL): return 1000
		if _matches_key(card, MORGREM): return 960
		if _matches_key(card, IMPIDIMP): return 920
		if _matches_key(card, FROSLASS): return 880
		if _matches_key(card, SNORUNT): return 840
		if _matches_key(card, RARE_CANDY): return 820
		if _is_basic_energy(card, "D"): return 690
	else:
		if _matches_key(card, GABITE): return 1000
		if _matches_key(card, GARCHOMP): return 980
		if _matches_key(card, ROSERADE): return 920
		if _matches_key(card, GIBLE): return 880
		if _matches_key(card, ROSELIA): return 820
		if _matches_key(card, POWER_WEIGHT): return 760
		if _is_basic_energy(card, "F"): return 700
		if _matches_key(card, LUMINOUS_ENERGY): return 620
	return super.get_search_priority(card)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	if step_id == PUNK_UP_STEP:
		var energies: Array = []
		for item: Variant in items:
			if item is CardInstance and _is_basic_energy(item, "D"):
				energies.append(item)
		var player := _player_from_context(context)
		var wanted := mini(maxi(1, int(step.get("max_select", 5))), energies.size())
		if player != null:
			wanted = mini(wanted, _marnie_punk_up_need(player))
		return energies.slice(0, wanted)
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if item is Dictionary:
		var assignment: Dictionary = item
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if step_id == PUNK_UP_STEP:
			return (500.0 if source is CardInstance and _is_basic_energy(source, "D") else -4000.0) + _score_punk_up_target(target, context)
		if step_id == CRISPIN_ATTACH_STEP:
			return _score_crispin_assignment(source, target, player)
		return score_interaction_target(source, step, context) + score_interaction_target(target, step, context)
	if item is String and step_id == "draw_to_hand_size_choice":
		if player != null and player.deck.size() <= 6:
			return -1600.0 if str(item) == "draw" else 1200.0
		if str(item) == "draw":
			return 4200.0 if player != null and player.hand.size() < 6 else 500.0
		return 700.0
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard"):
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id == "search_tool" \
				and _matches_key(card, TM_EVOLUTION) \
				and _cynthia_secret_box_poffin_tm_route_live(player, context):
			return 6200.0
		if step_id == SPIKEMUTH_STEP:
			return _marnie_search_score(card, player)
		if step_id == CYNTHIA_SEARCH_STEP:
			return _cynthia_search_score(card, player)
		if step_id.contains("evolution_cards"):
			if _matches_key(card, GABITE): return 5200.0
			if _matches_key(card, ROSERADE): return 4500.0
			if _matches_key(card, MORGREM): return 5100.0
			if _matches_key(card, FROSLASS): return 4400.0
			return 200.0
		if _is_recovery_step(step_id):
			return _score_recovery_card(card, player)
		if step_id == CRISPIN_HAND_STEP:
			return _score_crispin_hand_energy(card, player)
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == PUNK_UP_STEP:
			return _score_punk_up_target(slot, context)
		if step_id.contains("evolution_bench") or step_id.contains("target_pokemon"):
			if _matches_key(slot, GIBLE): return 5000.0
			if _matches_key(slot, ROSELIA): return 4300.0
			if _matches_key(slot, IMPIDIMP): return 4900.0
			if _matches_key(slot, SNORUNT): return 4100.0
			return 400.0
		if _is_handoff_step(step_id):
			return score_handoff_target(slot, step, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not item is PokemonSlot:
		return super.score_handoff_target(item, step, context)
	var slot := item as PokemonSlot
	if _matches_key(slot, GRIMMSNARL):
		return 5600.0 if _darkness_units(slot) >= 2 else 2600.0
	if _matches_key(slot, GARCHOMP):
		return 5700.0 if _fighting_units(slot) >= 1 else 2700.0
	if _matches_key(slot, SPIRITOMB) and _slot_energy_count(slot) >= 1:
		return 1800.0 + float(_cynthia_benched_damage(_player_from_context(context)))
	if _matches_key(slot, IMPIDIMP) or _matches_key(slot, GIBLE):
		return 700.0
	return super.score_handoff_target(item, step, context)


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null:
		return super.predict_attacker_damage(slot, extra_context)
	if _matches_key(slot, GRIMMSNARL):
		var grim_units := _darkness_units(slot) + extra_context
		return {"damage": 180 if grim_units >= 2 else 0, "can_attack": grim_units >= 2, "description": "shadow_bullet"}
	if _matches_key(slot, GARCHOMP):
		var fighting_units := _fighting_units(slot) + extra_context
		return {"damage": 260 if fighting_units >= 2 else (100 if fighting_units >= 1 else 0), "can_attack": fighting_units >= 1, "description": "cynthia_garchomp"}
	if _matches_key(slot, SPIRITOMB):
		var player := _prediction_player()
		var damage := _cynthia_benched_damage(player)
		var ready := _slot_energy_count(slot) + extra_context >= 1
		return {"damage": damage if ready else 0, "can_attack": ready, "description": "angry_spell"}
	return super.predict_attacker_damage(slot, extra_context)


func _build_marnie_plan(game_state: GameState, player: PlayerState, context: Dictionary) -> Dictionary:
	var ready := _ready_grimmsnarl(player)
	var owner_slot := _best_slot(player, [GRIMMSNARL, MORGREM, IMPIDIMP])
	var owner := _primary_name(owner_slot) if owner_slot != null else IMPIDIMP
	var bridge := _marnie_bridge(player)
	var debt := _marnie_setup_debt(player)
	var phase := "setup"
	if _has_slot(player, GRIMMSNARL):
		phase = "convert" if ready != null else "launch"
	if game_state.turn_number > 2 and not _has_slot(player, IMPIDIMP) and not _has_slot(player, MORGREM) and not _has_slot(player, GRIMMSNARL):
		phase = "rebuild"
	if ready != null and player.prizes.size() <= 2:
		phase = "close"
	return {
		"id": "v18_marnie_cynthia_800018501:%s" % phase,
		"intent": _marnie_intent(phase, ready != null),
		"phase": phase,
		"owner": {"turn_owner_name": owner, "bridge_target_name": bridge, "pivot_target_name": GRIMMSNARL},
		"targets": {"primary_attacker_name": GRIMMSNARL, "bridge_target_name": bridge, "damage_engine_name": FROSLASS},
		"priorities": {
			"attach": [GRIMMSNARL, MORGREM, IMPIDIMP, MUNKIDORI],
			"handoff": [GRIMMSNARL],
			"search": [bridge, GRIMMSNARL, MORGREM, FROSLASS, IMPIDIMP, SNORUNT],
			"evolve": [GRIMMSNARL, MORGREM, FROSLASS],
			"ability": [GRIMMSNARL, MUNKIDORI],
			"trainer": [SPIKEMUTH_GYM, RARE_CANDY, TM_EVOLUTION, NIGHT_STRETCHER],
		},
		"flags": {"marnie_cynthia_family": true, "marnie_route": true, "punk_up_need": _marnie_punk_up_need(player), "setup_debt": debt},
		"constraints": {
			"forbid_engine_churn": player.deck.size() <= 8 and ready != null,
			"forbid_extra_bench_padding": player.bench.size() >= 4 and int(debt.get("total", 0)) <= 0,
		},
		"context": context.duplicate(true),
	}


func _build_cynthia_plan(game_state: GameState, player: PlayerState, context: Dictionary) -> Dictionary:
	var ready := _ready_garchomp(player)
	var owner_slot := _best_slot(player, [GARCHOMP, GABITE, GIBLE])
	var owner := _primary_name(owner_slot) if owner_slot != null else GIBLE
	var bridge := _cynthia_bridge(player)
	var debt := _cynthia_setup_debt(player)
	var phase := "setup"
	if _has_slot(player, GABITE) or _has_slot(player, GARCHOMP):
		phase = "convert" if ready != null else "launch"
	if game_state.turn_number > 2 and not _has_slot(player, GIBLE) and not _has_slot(player, GABITE) and not _has_slot(player, GARCHOMP):
		phase = "rebuild"
	if ready != null and player.prizes.size() <= 2:
		phase = "close"
	return {
		"id": "v18_marnie_cynthia_800018543:%s" % phase,
		"intent": _cynthia_intent(phase, ready != null),
		"phase": phase,
		"owner": {"turn_owner_name": owner, "bridge_target_name": bridge, "pivot_target_name": GARCHOMP},
		"targets": {"primary_attacker_name": GARCHOMP, "bridge_target_name": bridge, "damage_engine_name": ROSERADE},
		"priorities": {
			"attach": [GARCHOMP, GABITE, GIBLE, MUNKIDORI, SPIRITOMB],
			"handoff": [GARCHOMP, SPIRITOMB],
			"search": [bridge, GARCHOMP, GABITE, ROSERADE, GIBLE, ROSELIA, FIGHTING_ENERGY],
			"evolve": [GARCHOMP, ROSERADE, GABITE],
			"ability": [GABITE, MUNKIDORI],
			"trainer": [TM_EVOLUTION, POWER_WEIGHT, CRISPIN, EARTHEN_VESSEL, NIGHT_STRETCHER],
		},
		"flags": {"marnie_cynthia_family": true, "cynthia_route": true, "garchomp_ready": ready != null, "setup_debt": debt},
		"constraints": {
			"forbid_engine_churn": player.deck.size() <= 8 and ready != null,
			"forbid_extra_bench_padding": player.bench.size() >= 4 and int(debt.get("total", 0)) <= 0,
		},
		"context": context.duplicate(true),
	}


func _score_marnie_action(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_key(card, IMPIDIMP): return maxf(base_score, 3800.0 if _count_slots(player, IMPIDIMP) == 0 else 2400.0)
			if _matches_key(card, SNORUNT): return maxf(base_score, 3200.0 if _count_slots(player, SNORUNT) == 0 else 2000.0)
			if _matches_key(card, MUNKIDORI): return maxf(base_score, 2200.0 if _count_slots(player, MUNKIDORI) == 0 else 600.0)
			if _matches_key(card, SHAYMIN): return maxf(base_score, 1500.0 if _count_slots(player, SHAYMIN) == 0 else 200.0)
		"evolve":
			var target: PokemonSlot = action.get("target_slot", null)
			if _matches_key(card, GRIMMSNARL) and (_matches_key(target, MORGREM) or _matches_key(target, IMPIDIMP)):
				return maxf(base_score, 5700.0 if _count_basic_energy(player.deck, "D") > 0 else 4100.0)
			if _matches_key(card, MORGREM) and _matches_key(target, IMPIDIMP): return maxf(base_score, 4400.0)
			if _matches_key(card, FROSLASS) and _matches_key(target, SNORUNT): return maxf(base_score, 4200.0)
		"attach_energy":
			return _score_marnie_attach(action, player, base_score)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_key(source, GRIMMSNARL):
				return maxf(base_score, 5900.0) if _count_basic_energy(player.deck, "D") > 0 and _marnie_punk_up_need(player) > 0 else -1400.0
			if _matches_key(source, MUNKIDORI):
				return maxf(base_score, 3600.0) if _has_damaged_own_pokemon(player) and _darkness_units(source) > 0 else -900.0
		"play_stadium":
			if _matches_key(card, SPIKEMUTH_GYM): return maxf(base_score, 3500.0) if _marnie_search_is_productive(player) else 500.0
		"use_stadium_effect":
			return maxf(base_score, 3900.0) if _marnie_search_is_productive(player) else -500.0
		"play_trainer":
			if _matches_key(card, RARE_CANDY): return maxf(base_score, 5300.0) if _has_live_marnie_candy_route(player) else -1500.0
			if _is_recovery_card(card): return maxf(base_score, 3300.0) if _has_recoverable_marnie_card(player) else -1600.0
		"attach_tool":
			if _matches_key(card, TM_EVOLUTION): return maxf(base_score, 3500.0) if _marnie_tm_target_count(player) > 0 else -1300.0
		"granted_attack":
			if _is_tm_evolution_attack(action): return maxf(base_score, 4900.0) if _marnie_tm_target_count(player) > 0 else -1800.0
		"attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			var attack_name := _attack_name(action, source)
			if _matches_key(source, GRIMMSNARL): return maxf(base_score, 3500.0 + float(int(action.get("projected_damage", 180))) * 3.0)
			if _matches_key(source, IMPIDIMP):
				if attack_name in ["骗取", "Cheeky Draw"]: return 1300.0 if player.deck.size() > 6 else -2400.0
				return 2300.0 if bool(action.get("projected_knockout", false)) else -400.0
		"end_turn":
			if int(_marnie_setup_debt(player).get("total", 0)) > 0: return minf(base_score, -1900.0)
	return base_score


func _score_cynthia_action(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	base_score: float
) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_key(card, GIBLE): return maxf(base_score, 3900.0 if _count_slots(player, GIBLE) == 0 else 2600.0)
			if _matches_key(card, ROSELIA): return maxf(base_score, 3200.0 if _count_slots(player, ROSELIA) == 0 else 1700.0)
			if _matches_key(card, MUNKIDORI): return maxf(base_score, 2100.0 if _count_slots(player, MUNKIDORI) == 0 else 500.0)
			if _matches_key(card, SPIRITOMB): return maxf(base_score, 1500.0)
		"evolve":
			if _matches_key(card, GARCHOMP): return maxf(base_score, 5600.0)
			if _matches_key(card, GABITE): return maxf(base_score, 4900.0)
			if _matches_key(card, ROSERADE): return maxf(base_score, 4600.0)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_key(source, GABITE): return maxf(base_score, 5000.0) if _cynthia_search_is_productive(player) else -900.0
			if _matches_key(source, MUNKIDORI): return maxf(base_score, 3700.0) if _has_damaged_own_pokemon(player) and _darkness_units(source) > 0 else -900.0
		"attach_energy":
			return _score_cynthia_attach(action, player, base_score)
		"attach_tool":
			var target: PokemonSlot = action.get("target_slot", null)
			if _matches_key(card, POWER_WEIGHT):
				if _matches_key(target, GARCHOMP): return maxf(base_score, 4200.0)
				if _is_cynthia_pokemon(target): return maxf(base_score, 2500.0)
				return -1600.0
			if _matches_key(card, TM_EVOLUTION):
				return _score_cynthia_tm_evolution_attach(target, player, game_state, base_score)
		"granted_attack":
			if _is_tm_evolution_attack(action):
				var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
				return _score_cynthia_tm_evolution_attack(source, player, game_state, base_score)
		"play_trainer":
			if _matches_key(card, CRISPIN): return maxf(base_score, 4400.0) if _crispin_is_productive(player) else -1200.0
			if _matches_key(card, EARTHEN_VESSEL): return maxf(base_score, 3500.0) if _ready_garchomp(player) == null else 900.0
			if _is_recovery_card(card): return maxf(base_score, 3500.0) if _has_recoverable_cynthia_card(player) else -1600.0
		"attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			if _matches_key(source, GARCHOMP):
				var attack_name := _attack_name(action, source)
				var attack_index := int(action.get("attack_index", -1))
				if attack_index == 0 or attack_name in ["螺旋俯冲", "Spiral Dive"]:
					if player.deck.size() <= 6: return 1300.0
					return maxf(base_score, 4100.0 if player.hand.size() < 6 else 2700.0)
				if attack_index == 1 or attack_name in ["龙之爆破", "Dragon Blast"]:
					if bool(action.get("projected_knockout", false)): return maxf(base_score, 5900.0)
					return maxf(base_score, 3600.0) if _has_post_blast_rebuild(player, source) else minf(base_score, 2400.0)
			if _matches_key(source, SPIRITOMB):
				return maxf(base_score, 1500.0 + float(_cynthia_benched_damage(player)) * 8.0)
		"end_turn":
			if int(_cynthia_setup_debt(player).get("total", 0)) > 0: return minf(base_score, -1900.0)
	return base_score


func _score_marnie_attach(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var energy: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if not _energy_pays(energy, "D", target):
		return base_score
	if _matches_key(target, GRIMMSNARL): return maxf(base_score, 4700.0 - float(_darkness_units(target)) * 720.0) if _darkness_units(target) < 2 else 900.0
	if _matches_key(target, MORGREM): return maxf(base_score, 4100.0 - float(_darkness_units(target)) * 600.0)
	if _matches_key(target, IMPIDIMP): return maxf(base_score, 3600.0 - float(_darkness_units(target)) * 520.0)
	if _matches_key(target, MUNKIDORI) and _darkness_units(target) == 0:
		return maxf(base_score, 3100.0) if _ready_grimmsnarl(player) != null else 1200.0
	return minf(base_score, -1300.0)


func _score_cynthia_attach(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var energy: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null:
		return base_score
	var tm_energy_score := _score_cynthia_tm_evolution_energy(energy, target, player, base_score)
	if not is_nan(tm_energy_score):
		return tm_energy_score
	if _matches_key(target, MUNKIDORI) and _energy_pays(energy, "D", target):
		return maxf(base_score, 3300.0) if _ready_garchomp(player) != null and _darkness_units(target) == 0 else 1300.0
	if _energy_pays(energy, "F", target):
		if _matches_key(target, GARCHOMP): return maxf(base_score, 4800.0 - float(_fighting_units(target)) * 650.0)
		if _matches_key(target, GABITE): return maxf(base_score, 3900.0 - float(_fighting_units(target)) * 520.0)
		if _matches_key(target, GIBLE): return maxf(base_score, 3400.0 - float(_fighting_units(target)) * 450.0)
		if _has_slot(player, GARCHOMP) or _has_slot(player, GABITE): return minf(base_score, -1400.0)
	return base_score


func _marnie_search_score(card: CardInstance, player: PlayerState) -> float:
	if _matches_key(card, GRIMMSNARL): return 5600.0 if player != null and (_has_slot(player, MORGREM) or _has_marnie_candy_seed(player)) else 1300.0
	if _matches_key(card, MORGREM): return 5100.0 if player != null and _has_slot(player, IMPIDIMP) else 1000.0
	if _matches_key(card, IMPIDIMP): return 4700.0 if player != null and not _has_marnie_line(player) else 1700.0
	return 0.0


func _cynthia_search_score(card: CardInstance, player: PlayerState) -> float:
	if _matches_key(card, GARCHOMP): return 5800.0 if player != null and _has_slot(player, GABITE) and not _has_slot(player, GARCHOMP) else 1300.0
	if _matches_key(card, GABITE): return 5500.0 if player != null and _has_slot(player, GIBLE) and not _has_slot(player, GABITE) else 1500.0
	if _matches_key(card, ROSERADE): return 5000.0 if player != null and _has_slot(player, ROSELIA) and not _has_slot(player, ROSERADE) else 1400.0
	if _matches_key(card, GIBLE): return 4500.0 if player != null and not _has_slot(player, GIBLE) else 1700.0
	if _matches_key(card, ROSELIA): return 4000.0 if player != null and not _has_slot(player, ROSELIA) else 1500.0
	if _matches_key(card, SPIRITOMB): return 1400.0 + float(_cynthia_benched_damage(player))
	return 0.0


func _score_punk_up_target(item: Variant, context: Dictionary) -> float:
	if not item is PokemonSlot:
		return -5000.0
	var slot := item as PokemonSlot
	var pending := _pending_assignment_count(slot, context)
	var total := _darkness_units(slot) + pending
	if _matches_key(slot, GRIMMSNARL): return 5400.0 - float(total) * 480.0 if total < 2 else 1200.0 - float(total) * 80.0
	if _matches_key(slot, MORGREM): return 4700.0 - float(total) * 420.0 if total < 2 else 1100.0
	if _matches_key(slot, IMPIDIMP): return 4200.0 - float(total) * 380.0 if total < 2 else 1000.0
	return -1800.0


func _score_crispin_hand_energy(card: CardInstance, player: PlayerState) -> float:
	if not _is_basic_energy_any(card):
		return -1800.0
	if player == null:
		return 0.0
	if _ready_garchomp(player) == null:
		return 4700.0 if _is_basic_energy(card, "D") else 3000.0
	if _has_slot(player, MUNKIDORI) and not _has_funded_munkidori(player):
		return 4700.0 if _is_basic_energy(card, "F") else 3000.0
	return 3400.0 if _is_basic_energy(card, "F") else 2800.0


func _score_crispin_assignment(source: Variant, target: Variant, player: PlayerState) -> float:
	if not source is CardInstance or not target is PokemonSlot or not _is_basic_energy_any(source):
		return -4000.0
	if _is_basic_energy(source, "F") and (_matches_key(target, GARCHOMP) or _matches_key(target, GABITE) or _matches_key(target, GIBLE)):
		return 5600.0 - float(_fighting_units(target)) * 500.0
	if _is_basic_energy(source, "D") and _matches_key(target, MUNKIDORI):
		return 4800.0 if player != null and _ready_garchomp(player) != null else 1700.0
	return -1200.0


func _score_recovery_card(card: CardInstance, player: PlayerState) -> float:
	if player == null:
		return 0.0
	if _deck_id == MARNIE_DECK_ID:
		if _matches_key(card, GRIMMSNARL): return 5400.0
		if _matches_key(card, MORGREM): return 5000.0
		if _matches_key(card, IMPIDIMP) or _matches_key(card, SNORUNT): return 4400.0
		if _is_basic_energy(card, "D"): return 3900.0 if _marnie_manual_energy_need(player) > 0 else 2300.0
	else:
		if _is_basic_energy(card, "F"): return 5500.0 if _ready_garchomp(player) == null else 3300.0
		if _matches_key(card, GARCHOMP): return 5300.0 if _has_slot(player, GABITE) else 2900.0
		if _matches_key(card, GABITE): return 5100.0 if _has_slot(player, GIBLE) else 2700.0
		if _matches_key(card, GIBLE) or _matches_key(card, ROSELIA): return 4200.0
		if _is_basic_energy(card, "D"): return 3200.0 if _has_slot(player, MUNKIDORI) else 1700.0
	return float(get_search_priority(card)) * 0.7


func _setup_debt(player: PlayerState) -> Dictionary:
	return _marnie_setup_debt(player) if _deck_id == MARNIE_DECK_ID else _cynthia_setup_debt(player)


func _marnie_setup_debt(player: PlayerState) -> Dictionary:
	var missing_seed := int(not _has_marnie_line(player))
	var missing_stage2 := int(not _has_slot(player, GRIMMSNARL))
	var missing_damage_engine := int(not (_has_slot(player, SNORUNT) or _has_slot(player, FROSLASS)))
	var missing_energy := mini(2, _marnie_manual_energy_need(player))
	return {
		"missing_marnie_seed": missing_seed,
		"missing_grimmsnarl": missing_stage2,
		"missing_froslass_route": missing_damage_engine,
		"missing_attack_energy": missing_energy,
		"total": missing_seed + missing_stage2 + missing_damage_engine + missing_energy,
	}


func _cynthia_setup_debt(player: PlayerState) -> Dictionary:
	var missing_seed := int(not (_has_slot(player, GIBLE) or _has_slot(player, GABITE) or _has_slot(player, GARCHOMP)))
	var missing_stage2 := int(not _has_slot(player, GARCHOMP))
	var missing_damage_engine := int(not (_has_slot(player, ROSELIA) or _has_slot(player, ROSERADE)))
	var missing_energy := int(_ready_garchomp(player) == null)
	return {
		"missing_garchomp_seed": missing_seed,
		"missing_garchomp": missing_stage2,
		"missing_roserade_route": missing_damage_engine,
		"missing_attack_energy": missing_energy,
		"total": missing_seed + missing_stage2 + missing_damage_engine + missing_energy,
	}


func _ready_attacker(player: PlayerState) -> PokemonSlot:
	return _ready_grimmsnarl(player) if _deck_id == MARNIE_DECK_ID else _ready_garchomp(player)


func _ready_grimmsnarl(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, GRIMMSNARL) and _darkness_units(slot) >= 2:
			return slot
	return null


func _ready_garchomp(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, GARCHOMP) and _fighting_units(slot) >= 1:
			return slot
	return null


func _marnie_bridge(player: PlayerState) -> String:
	if _has_slot(player, MORGREM): return GRIMMSNARL
	if _has_slot(player, IMPIDIMP):
		return GRIMMSNARL if _has_live_marnie_candy_route(player) else MORGREM
	if _has_slot(player, GRIMMSNARL):
		return FROSLASS if _has_slot(player, SNORUNT) and not _has_slot(player, FROSLASS) else IMPIDIMP
	return IMPIDIMP


func _cynthia_bridge(player: PlayerState) -> String:
	if _has_slot(player, GABITE) and not _has_slot(player, GARCHOMP): return GARCHOMP
	if _has_slot(player, GIBLE) and not _has_slot(player, GABITE): return GABITE
	if _has_slot(player, ROSELIA) and not _has_slot(player, ROSERADE): return ROSERADE
	return GIBLE


func _marnie_intent(phase: String, ready: bool) -> String:
	match phase:
		"convert", "close": return "convert_shadow_bullet" if ready else "fund_shadow_bullet"
		"rebuild": return "recover_marnie_evolution_lane"
		"launch": return "activate_punk_up_and_damage_engine"
		_: return "establish_marnie_stage2_route"


func _cynthia_intent(phase: String, ready: bool) -> String:
	match phase:
		"convert", "close": return "choose_spiral_draw_or_dragon_blast" if ready else "fund_garchomp"
		"rebuild": return "recover_cynthia_evolution_lane"
		"launch": return "complete_garchomp_and_roserade"
		_: return "establish_cynthia_evolution_routes"


func _opening_active_score(card: CardInstance) -> float:
	if _matches_key(card, BUDEW): return 10000.0
	if _deck_id == MARNIE_DECK_ID:
		if _matches_key(card, IMPIDIMP): return 8200.0
		if _matches_key(card, SNORUNT): return 6100.0
		if _matches_key(card, SHAYMIN): return 3400.0
		if _matches_key(card, MUNKIDORI): return 2600.0
	else:
		if _matches_key(card, SPIRITOMB): return 7600.0
		if _matches_key(card, GIBLE): return 7000.0
		if _matches_key(card, ROSELIA): return 5700.0
		if _matches_key(card, MUNKIDORI): return 2600.0
	return 100.0


func _opening_bench_score(card: CardInstance) -> float:
	if _deck_id == MARNIE_DECK_ID:
		if _matches_key(card, IMPIDIMP): return 10000.0
		if _matches_key(card, SNORUNT): return 9000.0
		if _matches_key(card, MUNKIDORI): return 8200.0
		if _matches_key(card, SHAYMIN): return 5200.0
	else:
		if _matches_key(card, GIBLE): return 10000.0
		if _matches_key(card, ROSELIA): return 9000.0
		if _matches_key(card, MUNKIDORI): return 8000.0
		if _matches_key(card, SPIRITOMB): return 5500.0
	return -100.0


func _opening_identity(card: CardInstance) -> String:
	for key: String in [IMPIDIMP, SNORUNT, MUNKIDORI, SHAYMIN, GIBLE, ROSELIA, SPIRITOMB, BUDEW]:
		if _matches_key(card, key):
			return key
	return _primary_name(card)


func _opening_identity_cap(identity: String) -> int:
	if identity in [IMPIDIMP, SNORUNT, GIBLE]:
		return 2
	return 1


func _marnie_punk_up_need(player: PlayerState) -> int:
	var need := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, GRIMMSNARL) or _matches_key(slot, MORGREM) or _matches_key(slot, IMPIDIMP):
			need += maxi(0, 2 - _darkness_units(slot))
	return mini(5, need)


func _marnie_manual_energy_need(player: PlayerState) -> int:
	var line := _best_slot(player, [GRIMMSNARL, MORGREM, IMPIDIMP])
	return maxi(0, 2 - _darkness_units(line)) if line != null else 2


func _has_live_marnie_candy_route(player: PlayerState) -> bool:
	return _has_marnie_candy_seed(player) and _hand_has(player, GRIMMSNARL)


func _has_marnie_candy_seed(player: PlayerState) -> bool:
	return player != null and _has_slot(player, IMPIDIMP) and _hand_has(player, RARE_CANDY)


func _marnie_search_is_productive(player: PlayerState) -> bool:
	return player != null and (not _has_marnie_line(player) or (_has_slot(player, IMPIDIMP) and not _has_slot(player, MORGREM)) or (_has_slot(player, MORGREM) and not _has_slot(player, GRIMMSNARL)))


func _cynthia_search_is_productive(player: PlayerState) -> bool:
	return player != null and ((_has_slot(player, GIBLE) and not _has_slot(player, GABITE)) or (_has_slot(player, GABITE) and not _has_slot(player, GARCHOMP)) or (_has_slot(player, ROSELIA) and not _has_slot(player, ROSERADE)))


func _crispin_is_productive(player: PlayerState) -> bool:
	return player != null and _count_basic_energy(player.deck, "F") > 0 and _count_basic_energy(player.deck, "D") > 0 and (_ready_garchomp(player) == null or (_has_slot(player, MUNKIDORI) and not _has_funded_munkidori(player)))


func _has_post_blast_rebuild(player: PlayerState, attacker: PokemonSlot) -> bool:
	if player == null:
		return false
	if _count_basic_energy(player.hand, "F") + _count_basic_energy(player.discard_pile, "F") > 0:
		return true
	if _hand_has(player, CRISPIN) or _hand_has(player, EARTHEN_VESSEL):
		return true
	for slot: PokemonSlot in _all_slots(player):
		if slot != attacker and (_matches_key(slot, GARCHOMP) or _matches_key(slot, GABITE) or _matches_key(slot, GIBLE)) and _fighting_units(slot) > 0:
			return true
	return false


func _has_funded_munkidori(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, MUNKIDORI) and _darkness_units(slot) > 0:
			return true
	return false


func _has_recoverable_marnie_card(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if _matches_key(card, IMPIDIMP) or _matches_key(card, MORGREM) or _matches_key(card, GRIMMSNARL) or _matches_key(card, SNORUNT) or _matches_key(card, FROSLASS) or _is_basic_energy(card, "D"):
			return true
	return false


func _has_recoverable_cynthia_card(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if _is_cynthia_pokemon(card) or _is_basic_energy(card, "F") or _is_basic_energy(card, "D"):
			return true
	return false


func _marnie_tm_target_count(player: PlayerState) -> int:
	return _count_slots(player, IMPIDIMP) + _count_slots(player, SNORUNT)


func _cynthia_tm_target_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var available_evolutions: Array[CardInstance] = []
	for card: CardInstance in player.deck:
		if _matches_key(card, GABITE) or _matches_key(card, ROSERADE):
			available_evolutions.append(card)
	var count := 0
	for slot: PokemonSlot in player.bench:
		if not (_matches_key(slot, GIBLE) or _matches_key(slot, ROSELIA)):
			continue
		for index: int in available_evolutions.size():
			var evolution: CardInstance = available_evolutions[index]
			if evolution.card_data != null and evolution.card_data.evolves_from_matches(slot.get_card_data()):
				count += 1
				available_evolutions.remove_at(index)
				break
	return mini(2, count)


func _needs_cynthia_poffin_before_chip(player: PlayerState, game_state: GameState) -> bool:
	if _deck_id != CYNTHIA_DECK_ID or player == null:
		return false
	if not (_matches_key(player.active_pokemon, GIBLE) or _matches_key(player.active_pokemon, ROSERADE)):
		return false
	if not _hand_has(player, BUDDY_BUDDY_POFFIN) or player.is_bench_full():
		return false
	if _ready_garchomp(player) != null or _has_live_cynthia_tm_carrier(player, game_state):
		return false
	return _cynthia_deck_has_poffin_target(player)


func _cynthia_deck_has_poffin_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if card == null or not card.is_basic_pokemon() or card.card_data == null:
			continue
		if int(card.card_data.hp) > 0 and int(card.card_data.hp) <= 70:
			return true
	return false


func _has_live_cynthia_tm_carrier(player: PlayerState, game_state: GameState) -> bool:
	var carrier := _cynthia_tm_route_carrier(player)
	if carrier == null or _cynthia_tm_target_count(player) <= 0:
		return false
	if _first_player_attack_locked(game_state, player):
		return false
	return _can_fund_tm_evolution_attack(carrier, player, game_state)


func _cynthia_secret_box_poffin_tm_route_live(player: PlayerState, context: Dictionary) -> bool:
	if _deck_id != CYNTHIA_DECK_ID or player == null or player.is_bench_full():
		return false
	var pending_effect: Variant = context.get("pending_effect_card", null)
	if not _matches_key(pending_effect, SECRET_BOX):
		return false
	var selected_item_raw: Variant = context.get("search_item", [])
	if not selected_item_raw is Array:
		return false
	var poffin_selected := false
	for selected_item: Variant in selected_item_raw:
		if super._matches_key(selected_item, "Buddy-Buddy Poffin"):
			poffin_selected = true
			break
	if not poffin_selected:
		return false
	var has_seed := false
	var has_evolution := false
	for deck_card: CardInstance in player.deck:
		if _matches_key(deck_card, GIBLE) or _matches_key(deck_card, ROSELIA):
			has_seed = true
		elif _matches_key(deck_card, GABITE) or _matches_key(deck_card, ROSERADE):
			has_evolution = true
		if has_seed and has_evolution:
			return true
	return false


func _score_cynthia_tm_evolution_attach(
	target: PokemonSlot,
	player: PlayerState,
	game_state: GameState,
	base_score: float
) -> float:
	if target == null or player == null or _first_player_attack_locked(game_state, player):
		return minf(base_score, -4000.0)
	if target != player.active_pokemon:
		return minf(base_score, -4000.0)
	var target_count := _cynthia_tm_target_count(player)
	if target_count <= 0:
		return minf(base_score, -1100.0)
	if not _can_fund_tm_evolution_attack(target, player, game_state):
		return maxf(base_score, 900.0)
	return maxf(base_score, 4200.0 + float(target_count) * 600.0)


func _score_cynthia_tm_evolution_energy(
	energy: Variant,
	target: PokemonSlot,
	player: PlayerState,
	base_score: float
) -> float:
	if player == null or not _energy_pays(energy, "F", target):
		return NAN
	var carrier := _cynthia_tm_route_carrier(player)
	if carrier == null or _cynthia_tm_target_count(player) <= 0 or not carrier.attached_energy.is_empty():
		return NAN
	return maxf(base_score, 5000.0) if target == carrier else minf(base_score, -3000.0)


func _score_cynthia_tm_evolution_attack(
	source: PokemonSlot,
	player: PlayerState,
	game_state: GameState,
	base_score: float
) -> float:
	if source == null or player == null or _first_player_attack_locked(game_state, player):
		return minf(base_score, -4000.0)
	var target_count := _cynthia_tm_target_count(player)
	if source != player.active_pokemon or target_count <= 0:
		return minf(base_score, -3000.0)
	if not _can_fund_tm_evolution_attack(source, player, game_state):
		return minf(base_score, -3000.0)
	return maxf(base_score, 7200.0 + float(target_count) * 900.0)


func _can_fund_tm_evolution_attack(
	target: PokemonSlot,
	player: PlayerState,
	game_state: GameState
) -> bool:
	if target != null and not target.attached_energy.is_empty():
		return true
	if player == null or (game_state != null and game_state.energy_attached_this_turn):
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _cynthia_tm_route_carrier(player: PlayerState) -> PokemonSlot:
	if player != null and _slot_has_tm_evolution(player.active_pokemon):
		return player.active_pokemon
	return null


func _first_player_attack_locked(game_state: GameState, player: PlayerState) -> bool:
	return game_state != null \
		and player != null \
		and int(game_state.turn_number) == 1 \
		and int(game_state.first_player_index) == int(player.player_index)


func _slot_has_tm_evolution(slot: PokemonSlot) -> bool:
	return slot != null and _matches_key(slot.attached_tool, TM_EVOLUTION)


func _has_marnie_line(player: PlayerState) -> bool:
	return _has_slot(player, IMPIDIMP) or _has_slot(player, MORGREM) or _has_slot(player, GRIMMSNARL)


func _has_damaged_own_pokemon(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if slot.damage_counters > 0:
			return true
	return false


func _cynthia_benched_damage(player: PlayerState) -> int:
	var total := 0
	if player != null:
		for slot: PokemonSlot in player.bench:
			if _is_cynthia_pokemon(slot):
				total += int(slot.damage_counters / 10) * 10
	return total


func _is_low_deck_churn(action: Dictionary, player: PlayerState) -> bool:
	if player == null or player.deck.size() > 6 or str(action.get("kind", "")) != "play_trainer":
		return false
	var name := _primary_name(action.get("card", null)).to_lower()
	return name in ["博士的研究", "professor's research", "奇树", "iono", "宝可装置3.0", "pokegear 3.0", "pokégear 3.0"]


func _is_tm_evolution_attack(action: Dictionary) -> bool:
	var raw: Variant = action.get("granted_attack_data", action.get("attack_data", {}))
	if not raw is Dictionary:
		return false
	var identity := "%s %s" % [str(raw.get("id", "")), str(raw.get("name", ""))]
	return identity.to_lower().contains("evolution") or identity.contains("进化")


func _attack_name(action: Dictionary, source: PokemonSlot) -> String:
	var direct := str(action.get("attack_name", ""))
	if direct != "":
		return direct
	var index := int(action.get("attack_index", -1))
	if source != null and index >= 0 and index < source.get_attacks().size():
		return str(source.get_attacks()[index].get("name", ""))
	return ""


func _is_recovery_card(item: Variant) -> bool:
	return _matches_key(item, NIGHT_STRETCHER) or _matches_key(item, SUPER_ROD)


func _is_recovery_step(step_id: String) -> bool:
	return step_id.contains("stretcher") or step_id.contains("rod") or step_id.contains("recover") or step_id == "cards_to_return"


func _is_handoff_step(step_id: String) -> bool:
	return step_id.contains("switch") or step_id.contains("active") or step_id.contains("handoff") or step_id.contains("send")


func _is_marnies_pokemon(item: Variant) -> bool:
	for key: String in [IMPIDIMP, MORGREM, GRIMMSNARL]:
		if _matches_key(item, key):
			return true
	return false


func _is_cynthia_pokemon(item: Variant) -> bool:
	for key: String in [GIBLE, GABITE, GARCHOMP, ROSELIA, ROSERADE, SPIRITOMB]:
		if _matches_key(item, key):
			return true
	return false


func _energy_pays(item: Variant, symbol: String, target: PokemonSlot = null) -> bool:
	var data := _card_data_from_item(item)
	if data == null or not data.is_energy():
		return false
	if _matches_key(item, LUMINOUS_ENERGY):
		return symbol == "C" or not _luminous_is_suppressed(item, target)
	var provides := str(data.energy_provides if data.energy_provides != "" else data.energy_type).to_upper()
	return provides == "ANY" or symbol in provides or symbol == "C"


func _luminous_is_suppressed(item: Variant, target: PokemonSlot) -> bool:
	if target == null:
		return false
	for energy: CardInstance in target.attached_energy:
		if energy == item:
			continue
		if energy != null and energy.card_data != null and str(energy.card_data.card_type) == "Special Energy":
			return true
	return false


func _is_basic_energy(item: Variant, symbol: String) -> bool:
	var data := _card_data_from_item(item)
	return data != null and str(data.card_type) == "Basic Energy" and _energy_pays(item, symbol)


func _is_basic_energy_any(item: Variant) -> bool:
	var data := _card_data_from_item(item)
	return data != null and str(data.card_type) == "Basic Energy"


func _darkness_units(slot: PokemonSlot) -> int:
	var count := 0
	if slot != null:
		for energy: CardInstance in slot.attached_energy:
			if _energy_pays(energy, "D", slot): count += 1
	return count


func _fighting_units(slot: PokemonSlot) -> int:
	var count := 0
	if slot != null:
		for energy: CardInstance in slot.attached_energy:
			if _energy_pays(energy, "F", slot): count += 1
	return count


func _slot_energy_count(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func _count_basic_energy(cards: Array, symbol: String) -> int:
	var count := 0
	for card: Variant in cards:
		if _is_basic_energy(card, symbol): count += 1
	return count


func _count_slots(player: PlayerState, key: String) -> int:
	var count := 0
	if player != null:
		for slot: PokemonSlot in _all_slots(player):
			if _matches_key(slot, key): count += 1
	return count


func _has_slot(player: PlayerState, key: String) -> bool:
	return _count_slots(player, key) > 0


func _best_slot(player: PlayerState, identities: Array[String]) -> PokemonSlot:
	if player == null:
		return null
	for identity: String in identities:
		for slot: PokemonSlot in _all_slots(player):
			if _matches_key(slot, identity): return slot
	return null


func _hand_has(player: PlayerState, key: String) -> bool:
	if player != null:
		for card: CardInstance in player.hand:
			if _matches_key(card, key): return true
	return false


func _pending_assignment_count(slot: PokemonSlot, context: Dictionary) -> int:
	var pending: Variant = context.get("pending_assignment_counts", {})
	return int(pending.get(slot.get_instance_id(), 0)) if pending is Dictionary and slot != null else 0


func _matches_key(item: Variant, key: String) -> bool:
	var aliases: Variant = IDENTITY_ALIASES.get(key, [])
	if aliases is Array:
		for alias: Variant in aliases:
			if super._matches_key(item, str(alias)):
				return true
	return super._matches_key(item, key)


func _card_matches_names(item: Variant, names: Array) -> bool:
	for name_variant: Variant in names:
		if super._matches_key(item, str(name_variant)):
			return true
	return false


func _slot_matches_names(slot: PokemonSlot, names: Array[String]) -> bool:
	if slot == null:
		return false
	for name: String in names:
		if super._matches_key(slot, name):
			return true
	return false


func _opponent_has_gardevoir_engine_target(game_state: GameState, player_index: int) -> bool:
	var opponent_index := 1 - player_index
	if game_state == null or opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if _slot_matches_names(slot, OPPONENT_GARDEVOIR_NAMES) \
				or _slot_matches_names(slot, OPPONENT_KIRLIA_NAMES):
			return true
	return false


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	return _valid_player(context.get("game_state", null), int(context.get("player_index", -1)))


func _valid_player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		return game_state.players[player_index]
	return null


func _remember_prediction_context(game_state: GameState, player_index: int) -> void:
	if _valid_player(game_state, player_index) == null:
		return
	_prediction_game_state = game_state
	_prediction_player_index = player_index


func _prediction_player() -> PlayerState:
	return _valid_player(_prediction_game_state, _prediction_player_index)
