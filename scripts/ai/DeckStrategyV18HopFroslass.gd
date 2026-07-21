class_name DeckStrategyV18HopFroslass
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const HOP_DECK_ID := 800017407
const FROSLASS_DECK_ID := 800017631
const LOW_DECK_FLOOR := 7

const HOPS_ZACIAN: Array[String] = ["赫普的苍响ex", "Hop's Zacian ex", "CSV10C_161", "832e8b704b5457781ee7c52adc1a0571"]
const HOPS_CRAMORANT: Array[String] = ["赫普的古月鸟", "Hop's Cramorant", "CSV10C_188", "a250d62a3355b00d48f2eaa8be6a5dfb"]
const HOPS_SNORLAX: Array[String] = ["赫普的卡比兽", "Hop's Snorlax", "CSV10C_175", "49c917fdc3770a031e96267e6add09ab"]
const HOPS_BAG: Array[String] = ["赫普的包包", "Hop's Bag", "CSV10C_195", "517d6bf6e21dbaf53ab99bbb392f2460"]
const HOPS_BAND: Array[String] = ["赫普的讲究头带", "Hop's Choice Band", "CSV10C_201", "87bf196475e64140c14197af70648893"]
const POSTWICK: Array[String] = ["化朗镇", "Postwick", "CSV10C_218", "0c3c21449043e462bb73afac6c389a34"]

const MUNKIDORI: Array[String] = ["愿增猿", "Munkidori", "CSV8C_094", "66fee12502043db7d92b97b0d62b0f59"]
const URSALUNA: Array[String] = ["月月熊 赫月ex", "Bloodmoon Ursaluna ex", "CSV8C_172", "f2afef80b13b8f6a071facbcade0251c"]
const TATSUGIRI: Array[String] = ["米立龙", "Tatsugiri", "CSV8C_160"]
const FEZANDIPITI: Array[String] = ["吉雉鸡ex", "Fezandipiti ex", "CSV8C_135"]
const MEW_EX: Array[String] = ["梦幻ex", "Mew ex", "151C_151"]
const LATIAS_EX: Array[String] = ["拉帝亚斯ex", "Latias ex", "CSV9C_078"]

const SNORUNT: Array[String] = ["雪童子", "Snorunt", "CSV9.5C_043", "f6baf0c4c60ff47c7f836c1271f40cb3"]
const FROSLASS: Array[String] = ["雪妖女", "Froslass", "CSV7C_059", "f27a2982c03f5b49a68ec0a77a2d6e48"]
const BUDEW: Array[String] = ["含羞苞", "Budew", "CSV9.5C_004", "28505a8ad6e07e74382c1b5e09737932"]
const MARACTUS: Array[String] = ["沙铃仙人掌", "Maractus", "CSV10C_008", "a5b32602f9c443a038fef288059aeb43"]

const DARKNESS_ENERGY: Array[String] = ["基本恶能量", "Darkness Energy", "CSVE1C_DAR"]
const JET_ENERGY: Array[String] = ["喷射能量", "Jet Energy", "CSV4C_129"]
const LUMINOUS_ENERGY: Array[String] = ["夜光能量", "Luminous Energy", "CSV1C_127", "540ee48bb93584e4bfe3d7f5d0ee0efc"]
const NIGHT_STRETCHER: Array[String] = ["夜间担架", "Night Stretcher", "CSV8C_183"]
const EARTHEN_VESSEL: Array[String] = ["大地容器", "Earthen Vessel", "CSV6C_115"]
const BUDDY_POFFIN: Array[String] = ["友好宝芬", "Buddy-Buddy Poffin", "CSV7C_177"]
const TM_EVOLUTION: Array[String] = ["招式学习器 进化", "Technical Machine: Evolution", "CSV5C_119", "43386015be5c073ba2e5b9d3692ece3f"]
const TM_DEVOLUTION: Array[String] = ["招式学习器 退化", "Technical Machine: Devolution", "CSV5C_120", "e228e825c541ce80e2507c557cb506c3"]
const BRAVERY_CHARM: Array[String] = ["勇气护符", "Bravery Charm", "CSV1C_118"]

const HOP_BAG_STEP := "csv10c_hop_bag_targets"
const MUNKIDORI_SOURCE_STEP := "source_pokemon"
const MUNKIDORI_TARGET_STEP := "target_damage_counters"
const TM_BENCH_STEP := "evolution_bench"
const TM_CARD_STEP := "evolution_cards"
const NIGHT_STRETCHER_STEP := "night_stretcher_choice"

const LOW_DECK_CHURN_CARDS: Array[String] = [
	"奇树", "Iono", "博士的研究", "Professor's Research", "裁判", "Judge",
	"派帕", "Arven", "宝可装置3.0", "Pokegear 3.0", "Pokégear 3.0",
	"巢穴球", "Nest Ball", "高级球", "Ultra Ball", "友好宝芬", "Buddy-Buddy Poffin",
	"赫普的包包", "Hop's Bag", "大地容器", "Earthen Vessel",
	"深钵镇", "Artazon", "城镇百货", "Town Store",
	"米立龙", "Tatsugiri", "梦幻ex", "Mew ex", "吉雉鸡ex", "Fezandipiti ex",
]

const HOP_PROFILE := {
	"strategy_id": "v18_hop_froslass_800017407_delegate",
	"signatures": ["赫普的苍响ex", "Hop's Zacian ex", "赫普的卡比兽", "Hop's Snorlax"],
	"active_priority": ["赫普的苍响ex", "Hop's Zacian ex", "米立龙", "Tatsugiri", "赫普的古月鸟", "Hop's Cramorant", "赫普的卡比兽", "Hop's Snorlax"],
	"bench_priority": ["赫普的卡比兽", "Hop's Snorlax", "赫普的苍响ex", "Hop's Zacian ex", "愿增猿", "Munkidori", "赫普的古月鸟", "Hop's Cramorant", "拉帝亚斯ex", "Latias ex"],
	"energy_priority": ["赫普的苍响ex", "Hop's Zacian ex", "赫普的卡比兽", "Hop's Snorlax", "赫普的古月鸟", "Hop's Cramorant", "愿增猿", "Munkidori", "月月熊 赫月ex", "Bloodmoon Ursaluna ex"],
	"evolution_priority": [],
	"search_priority": ["赫普的卡比兽", "Hop's Snorlax", "赫普的苍响ex", "Hop's Zacian ex", "赫普的古月鸟", "Hop's Cramorant", "赫普的讲究头带", "Hop's Choice Band", "愿增猿", "Munkidori"],
	"ability_priority": ["愿增猿", "Munkidori", "米立龙", "Tatsugiri", "梦幻ex", "Mew ex", "吉雉鸡ex", "Fezandipiti ex"],
	"trainer_priority": ["赫普的包包", "Hop's Bag", "赫普的讲究头带", "Hop's Choice Band", "化朗镇", "Postwick", "大地容器", "Earthen Vessel", "夜间担架", "Night Stretcher"],
}

const FROSLASS_PROFILE := {
	"strategy_id": "v18_hop_froslass_800017631_delegate",
	"signatures": ["雪妖女", "Froslass", "愿增猿", "Munkidori"],
	"active_priority": ["含羞苞", "Budew", "沙铃仙人掌", "Maractus", "雪童子", "Snorunt", "愿增猿", "Munkidori"],
	"bench_priority": ["雪童子", "Snorunt", "愿增猿", "Munkidori", "含羞苞", "Budew", "沙铃仙人掌", "Maractus", "月月熊 赫月ex", "Bloodmoon Ursaluna ex"],
	"energy_priority": ["愿增猿", "Munkidori", "沙铃仙人掌", "Maractus", "月月熊 赫月ex", "Bloodmoon Ursaluna ex", "含羞苞", "Budew"],
	"evolution_priority": ["雪妖女", "Froslass"],
	"search_priority": ["雪妖女", "Froslass", "雪童子", "Snorunt", "愿增猿", "Munkidori", "招式学习器 进化", "Technical Machine: Evolution", "基本恶能量", "Darkness Energy"],
	"ability_priority": ["愿增猿", "Munkidori", "雪妖女", "Froslass"],
	"trainer_priority": ["友好宝芬", "Buddy-Buddy Poffin", "招式学习器 进化", "Technical Machine: Evolution", "夜间担架", "Night Stretcher", "大地容器", "Earthen Vessel", "深钵镇", "Artazon"],
}

const FALLBACK_PROFILE := {
	"strategy_id": "v18_hop_froslass_family_delegate",
	"signatures": ["赫普的苍响ex", "雪妖女"],
	"active_priority": ["赫普的苍响ex", "含羞苞"],
	"bench_priority": ["赫普的卡比兽", "雪童子", "愿增猿"],
	"energy_priority": ["赫普的苍响ex", "愿增猿"],
	"evolution_priority": ["雪妖女"],
	"search_priority": ["赫普的卡比兽", "雪妖女"],
	"ability_priority": ["愿增猿", "雪妖女"],
	"trainer_priority": ["赫普的包包", "友好宝芬"],
}

var _deck_id := 0


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else 0


func _profile() -> Dictionary:
	if _deck_id == HOP_DECK_ID:
		return HOP_PROFILE
	if _deck_id == FROSLASS_DECK_ID:
		return FROSLASS_PROFILE
	return FALLBACK_PROFILE


func plan_opening_setup(player: PlayerState) -> Dictionary:
	# Strong mode only changes deck order. Both modes intentionally use this same policy.
	var plan := super.plan_opening_setup(player)
	if player == null:
		return plan
	var preferred: Array[String] = HOPS_ZACIAN if _deck_id == HOP_DECK_ID else BUDEW
	var preferred_index := _first_basic_hand_index(player, preferred)
	if preferred_index < 0:
		return plan
	var result := plan.duplicate(true)
	var old_active := int(result.get("active_hand_index", -1))
	var bench_indices: Array = result.get("bench_hand_indices", []).duplicate()
	bench_indices.erase(preferred_index)
	if old_active >= 0 and old_active != preferred_index and old_active not in bench_indices:
		bench_indices.push_front(old_active)
	while bench_indices.size() > 5:
		bench_indices.pop_back()
	result["active_hand_index"] = preferred_index
	result["bench_hand_indices"] = bench_indices
	return result


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var player := _player(game_state, player_index)
	if player == null:
		return {}
	var debt := _setup_debt(player)
	var ready := _best_ready_attacker(game_state, player_index)
	var phase := _detect_family_phase(game_state, player_index, debt, ready)
	var owner := _route_owner_name(game_state, player_index, ready)
	var bridge := _bridge_target_name(player)
	var pivot := owner
	var intent := "establish_hop_damage_lane" if _deck_id == HOP_DECK_ID else "establish_froslass_damage_engine"
	if phase == "launch":
		intent = "launch_hop_attacker" if _deck_id == HOP_DECK_ID else "activate_munkidori_damage_loop"
	elif phase == "convert":
		intent = "convert_hop_damage_modifiers" if _deck_id == HOP_DECK_ID else "convert_frost_counters_with_munkidori"
	elif phase == "rebuild":
		intent = "rebuild_hop_attacker" if _deck_id == HOP_DECK_ID else "rebuild_froslass_munkidori_engine"
	elif phase == "close":
		intent = "take_final_prizes"
	return {
		"id": "v18_hop_froslass_%d:%s" % [_deck_id, phase],
		"intent": intent,
		"phase": phase,
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": bridge,
			"pivot_target_name": pivot,
		},
		"targets": {
			"primary_attacker_name": owner,
			"bridge_target_name": bridge,
		},
		"priorities": {
			"attach": _profile_list("energy_priority"),
			"handoff": _profile_list("energy_priority"),
			"search": _profile_list("search_priority"),
			"evolve": _profile_list("evolution_priority"),
			"ability": _profile_list("ability_priority"),
			"trainer": _profile_list("trainer_priority"),
		},
		"flags": {
			"family_deck_id": _deck_id,
			"setup_debt": debt,
			"ready_attacker": ready != null,
			"low_deck": _is_low_deck(player),
			"cramorant_prize_window": _cramorant_prize_window(game_state, player_index),
		},
		"constraints": {
			"forbid_engine_churn": _is_low_deck(player),
			"forbid_extra_bench_padding": player.bench.size() >= 4 and debt <= 0,
		},
		"context": context.duplicate(true),
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _player(game_state, player_index)
	if player == null:
		return {}
	var debt := _setup_debt(player)
	var ready := _best_ready_attacker(game_state, player_index)
	var bonuses: Array[Dictionary] = []
	var debt_data: Dictionary = {}
	if _deck_id == HOP_DECK_ID:
		debt_data = {
			"missing_hop_attacker": not _has_hop_attacker(player),
			"missing_snorlax_boost": _count_field(player, HOPS_SNORLAX) == 0,
			"missing_damage_transfer": _has_damage_source(player) and _count_powered_munkidori(player) == 0,
		}
		bonuses = [
			{"kind": "play_basic_to_bench", "target_names": ["赫普的卡比兽", "赫普的苍响ex", "愿增猿"], "bonus": 420.0},
			{"kind": "attach_tool", "target_names": ["赫普的苍响ex", "赫普的卡比兽", "赫普的古月鸟"], "bonus": 360.0},
			{"kind": "attach_energy", "target_names": ["赫普的苍响ex", "赫普的卡比兽", "愿增猿"], "bonus": 300.0},
			{"kind": "use_ability", "target_names": ["愿增猿"], "bonus": 520.0},
		]
	else:
		debt_data = {
			"missing_froslass": _count_field(player, FROSLASS) == 0,
			"missing_second_snow_line": _snow_line_count(player) < 2,
			"missing_powered_munkidori": _count_powered_munkidori(player) == 0,
		}
		bonuses = [
			{"kind": "play_basic_to_bench", "target_names": ["雪童子", "愿增猿"], "bonus": 480.0},
			{"kind": "evolve", "target_names": ["雪妖女"], "bonus": 680.0},
			{"kind": "attach_energy", "target_names": ["愿增猿"], "bonus": 460.0},
			{"kind": "use_ability", "target_names": ["愿增猿"], "bonus": 620.0},
		]
	return {
		"enabled": true,
		"safe_setup_before_attack": debt > 0 and ready != null and not _is_low_deck(player),
		"setup_debt": debt_data,
		"action_bonuses": bonuses,
		"attack_penalty": 760.0 if debt > 0 else 0.0,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	var player := _player(game_state, player_index)
	if player == null:
		return score
	if _must_stop_engine_churn(action, player):
		return minf(score, -7200.0)
	if str(action.get("kind", "")) == "end_turn" and _is_low_deck(player):
		return maxf(score, 1250.0 if _best_ready_attacker(game_state, player_index) == null else -250.0)
	if _deck_id == HOP_DECK_ID:
		return _score_hop_action(action, game_state, player_index, player, score)
	if _deck_id == FROSLASS_DECK_ID:
		return _score_froslass_action(action, game_state, player_index, player, score)
	return score


func _score_hop_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	base_score: float
) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	var target := _action_target_slot(action)
	match kind:
		"play_basic_to_bench":
			if _matches_any(card, HOPS_SNORLAX):
				return maxf(base_score, 4400.0 if _count_field(player, HOPS_SNORLAX) == 0 else 900.0)
			if _matches_any(card, HOPS_ZACIAN):
				return maxf(base_score, 4100.0 if _count_field(player, HOPS_ZACIAN) == 0 else 1800.0)
			if _matches_any(card, MUNKIDORI):
				return maxf(base_score, 3500.0 if _count_field(player, MUNKIDORI) == 0 else 2100.0)
			if _matches_any(card, HOPS_CRAMORANT):
				return maxf(base_score, 3300.0 if _cramorant_prize_window(game_state, player_index) else 1400.0)
		"attach_energy":
			return _score_hop_attachment(action, game_state, player_index, player, base_score)
		"attach_tool":
			if _matches_any(card, HOPS_BAND):
				return _hop_band_target_score(target, game_state, player_index, base_score)
		"play_trainer", "play_stadium":
			if _matches_any(card, HOPS_BAG):
				return maxf(base_score, 4200.0 if _missing_hop_core_count(player) > 0 else 300.0)
			if _matches_any(card, NIGHT_STRETCHER) and _has_recoverable_hop_core(player):
				return maxf(base_score, 3100.0)
			if _matches_any(card, POSTWICK) and _has_hop_attacker(player):
				return maxf(base_score, 2500.0)
		"use_ability":
			if _matches_any(action.get("source_slot", null), MUNKIDORI):
				return _munkidori_ability_score(action.get("source_slot", null), player, base_score)
		"attack", "granted_attack":
			return _score_hop_attack(action, game_state, player_index, base_score)
		"retreat":
			if target != null:
				return maxf(base_score, score_handoff_target(target, {"id": "retreat"}, {"game_state": game_state, "player_index": player_index}))
	return base_score


func _score_froslass_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	base_score: float
) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	var target := _action_target_slot(action)
	match kind:
		"play_basic_to_bench":
			if _matches_any(card, SNORUNT):
				return maxf(base_score, 4700.0 if _snow_line_count(player) < 2 else 1700.0)
			if _matches_any(card, MUNKIDORI):
				return maxf(base_score, 4500.0 if _count_field(player, MUNKIDORI) < 2 else 1600.0)
			if _matches_any(card, BUDEW) and _count_field(player, BUDEW) == 0:
				return maxf(base_score, 2800.0)
		"evolve":
			if _matches_any(card, FROSLASS) and _matches_any(target, SNORUNT):
				return maxf(base_score, 6100.0 if _count_field(player, FROSLASS) < 2 else 3900.0)
		"attach_energy":
			return _score_froslass_attachment(action, game_state, player_index, player, base_score)
		"attach_tool":
			if _matches_any(card, TM_EVOLUTION):
				if target == player.active_pokemon and _tm_evolution_target_count(player) > 0:
					return maxf(base_score, 5200.0)
				return minf(base_score, -1700.0)
			if _matches_any(card, BRAVERY_CHARM) and (_matches_any(target, MUNKIDORI) or _matches_any(target, MARACTUS)):
				return maxf(base_score, 2600.0)
		"play_trainer", "play_stadium":
			if _matches_any(card, BUDDY_POFFIN) and _snow_line_count(player) < 2:
				return maxf(base_score, 4300.0)
			if _matches_any(card, NIGHT_STRETCHER) and _has_recoverable_froslass_core(player):
				return maxf(base_score, 3500.0)
		"use_ability":
			if _matches_any(action.get("source_slot", null), MUNKIDORI):
				return _munkidori_ability_score(action.get("source_slot", null), player, base_score)
		"attack", "granted_attack":
			if _is_tm_evolution_attack(action):
				return maxf(base_score, 6500.0 if _tm_evolution_target_count(player) > 0 else -2400.0)
			return _score_froslass_attack(action, game_state, player_index, base_score)
		"retreat":
			if target != null:
				return maxf(base_score, score_handoff_target(target, {"id": "retreat"}, {"game_state": game_state, "player_index": player_index}))
	return base_score


func _score_hop_attachment(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	base_score: float
) -> float:
	var energy: Variant = action.get("card", null)
	var target := _action_target_slot(action)
	if target == null:
		return base_score
	if _matches_any(target, MUNKIDORI):
		if not _energy_pays_darkness(energy):
			return minf(base_score, -2200.0)
		if _has_darkness_energy(target):
			return minf(base_score, -1200.0)
		return maxf(base_score, 4300.0 if _has_damage_source(player) else 2550.0)
	if _matches_any(target, HOPS_ZACIAN):
		var need := 0 if _has_tool(target, HOPS_BAND) else 1
		if _attached_energy_count(target) < need:
			return maxf(base_score, 4700.0)
		return maxf(base_score, 1500.0)
	if _matches_any(target, HOPS_SNORLAX):
		var need := 2 if _has_tool(target, HOPS_BAND) else 3
		return maxf(base_score, 4400.0 - float(_attached_energy_count(target)) * 320.0) if _attached_energy_count(target) < need else minf(base_score, 250.0)
	if _matches_any(target, HOPS_CRAMORANT):
		if _attached_energy_count(target) == 0 and _cramorant_prize_window(game_state, player_index):
			return maxf(base_score, 4550.0)
		return minf(base_score, 700.0)
	if _matches_any(target, URSALUNA):
		var required := _bloodmoon_energy_required(game_state, player_index)
		if required > 0 and _attached_energy_count(target) < required:
			return maxf(base_score, 3600.0 + float(5 - required) * 220.0)
		return minf(base_score, 400.0)
	return base_score


func _score_froslass_attachment(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	base_score: float
) -> float:
	var energy: Variant = action.get("card", null)
	var target := _action_target_slot(action)
	if target == null:
		return base_score
	if _matches_any(target, MUNKIDORI):
		if not _energy_pays_darkness(energy):
			return minf(base_score, -2600.0)
		if _has_darkness_energy(target):
			return minf(base_score, -1900.0)
		var powered_count := _count_powered_munkidori(player)
		return maxf(base_score, 5600.0 - float(powered_count) * 420.0)
	if target == player.active_pokemon and _has_tool(target, TM_EVOLUTION) and _tm_evolution_target_count(player) > 0:
		return maxf(base_score, 5100.0 if _attached_energy_count(target) == 0 else 500.0)
	if _matches_any(target, URSALUNA):
		var required := _bloodmoon_energy_required(game_state, player_index)
		if required > 0 and _attached_energy_count(target) < required:
			return maxf(base_score, 4100.0 + float(5 - required) * 180.0)
	if _matches_any(target, MARACTUS) and target == player.active_pokemon and _attached_energy_count(target) == 0:
		return maxf(base_score, 2900.0)
	if _matches_any(target, FROSLASS) or _matches_any(target, SNORUNT):
		return minf(base_score, -2100.0)
	return base_score


func _score_hop_attack(action: Dictionary, game_state: GameState, player_index: int, base_score: float) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null:
		return base_score
	if _matches_any(source, HOPS_CRAMORANT):
		if not _cramorant_prize_window(game_state, player_index):
			return minf(base_score, -5200.0)
		return maxf(base_score, 3900.0 + float(int(action.get("projected_damage", 120))) * 2.0)
	if _matches_any(source, HOPS_ZACIAN):
		return maxf(base_score, 3200.0 + float(int(action.get("projected_damage", 30))) * 2.0)
	if _matches_any(source, HOPS_SNORLAX):
		return maxf(base_score, 4100.0 + (650.0 if _count_powered_munkidori(_player(game_state, player_index)) > 0 else 0.0))
	if _matches_any(source, URSALUNA):
		return maxf(base_score, 4700.0)
	return base_score


func _score_froslass_attack(action: Dictionary, game_state: GameState, player_index: int, base_score: float) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null:
		return base_score
	if _matches_any(source, BUDEW):
		return maxf(base_score, 3400.0 if int(game_state.turn_number) <= 4 else 2100.0)
	if _matches_any(source, MARACTUS):
		return maxf(base_score, 3000.0)
	if _matches_any(source, URSALUNA):
		return maxf(base_score, 4800.0)
	if _matches_any(source, FROSLASS):
		return minf(base_score, 400.0)
	return base_score


func get_discard_priority(card: CardInstance) -> int:
	if _deck_id == HOP_DECK_ID:
		if _matches_any(card, HOPS_ZACIAN) or _matches_any(card, HOPS_SNORLAX):
			return 5
		if _matches_any(card, HOPS_BAND) or _matches_any(card, HOPS_BAG) or _matches_any(card, NIGHT_STRETCHER):
			return 9
		if _matches_any(card, MUNKIDORI) or _is_basic_darkness_energy(card):
			return 12
		if _matches_any(card, HOPS_CRAMORANT):
			return 34
	if _deck_id == FROSLASS_DECK_ID:
		if _matches_any(card, FROSLASS):
			return 3
		if _matches_any(card, SNORUNT) or _matches_any(card, MUNKIDORI):
			return 5
		if _matches_any(card, TM_EVOLUTION) or _matches_any(card, NIGHT_STRETCHER):
			return 7
		if _is_basic_darkness_energy(card) or _matches_any(card, LUMINOUS_ENERGY):
			return 9
		if _matches_any(card, TM_DEVOLUTION):
			return 52
	if _matches_any(card, LOW_DECK_CHURN_CARDS):
		return 94
	return maxi(48, super.get_discard_priority(card))


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player := _player(game_state, player_index)
	if player == null:
		return get_discard_priority(card)
	if _deck_id == HOP_DECK_ID:
		if _matches_any(card, HOPS_SNORLAX) and _count_field(player, HOPS_SNORLAX) == 0:
			return 1
		if _matches_any(card, HOPS_ZACIAN) and _count_field(player, HOPS_ZACIAN) == 0:
			return 2
		if _matches_any(card, HOPS_BAND) and not _field_has_tool(player, HOPS_BAND):
			return 2
		if _is_basic_darkness_energy(card) and _has_unpowered_munkidori(player) and _basic_darkness_in_hand(player) <= 1:
			return 2
	if _deck_id == FROSLASS_DECK_ID:
		if _matches_any(card, FROSLASS) and _count_field(player, FROSLASS) < 2 and _count_field(player, SNORUNT) > 0:
			return 1
		if _matches_any(card, SNORUNT) and _snow_line_count(player) < 2:
			return 2
		if _matches_any(card, MUNKIDORI) and _count_field(player, MUNKIDORI) < 2:
			return 2
		if (_is_basic_darkness_energy(card) or _matches_any(card, LUMINOUS_ENERGY)) and _has_unpowered_munkidori(player):
			return 1
		if _matches_any(card, TM_EVOLUTION) and _tm_evolution_target_count(player) > 0:
			return 2
	if _is_low_deck(player) and _matches_any(card, LOW_DECK_CHURN_CARDS):
		return 125
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if _deck_id == HOP_DECK_ID:
		if _matches_any(card, HOPS_SNORLAX): return 1000
		if _matches_any(card, HOPS_ZACIAN): return 960
		if _matches_any(card, HOPS_BAND): return 920
		if _matches_any(card, HOPS_CRAMORANT): return 820
		if _matches_any(card, MUNKIDORI): return 780
		if _is_basic_darkness_energy(card): return 700
	if _deck_id == FROSLASS_DECK_ID:
		if _matches_any(card, FROSLASS): return 1000
		if _matches_any(card, SNORUNT): return 960
		if _matches_any(card, MUNKIDORI): return 930
		if _matches_any(card, TM_EVOLUTION): return 850
		if _is_basic_darkness_energy(card) or _matches_any(card, LUMINOUS_ENERGY): return 820
		if _matches_any(card, NIGHT_STRETCHER): return 760
	return super.get_search_priority(card)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		return []
	if _deck_id == HOP_DECK_ID and step_id == HOP_BAG_STEP:
		var ranked: Array[Dictionary] = []
		for item: Variant in items:
			ranked.append({"item": item, "score": score_interaction_target(item, step, context)})
		ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
		)
		var selected: Array = []
		var identities: Array[String] = []
		for entry: Dictionary in ranked:
			var candidate: Variant = entry.get("item")
			var identity := _hop_core_identity(candidate)
			if identity != "" and identity in identities:
				continue
			selected.append(candidate)
			if identity != "":
				identities.append(identity)
			if selected.size() >= max_select:
				break
		return selected
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if item is Dictionary:
		var assignment: Dictionary = item
		var target_score := score_interaction_target(assignment.get("target", null), step, context)
		return target_score + float(int(assignment.get("amount", 0))) * 4.0
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard"):
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id == NIGHT_STRETCHER_STEP:
			return _recovery_card_score(card, player)
		if _deck_id == HOP_DECK_ID:
			return _hop_search_card_score(card, player, step_id, context)
		if _deck_id == FROSLASS_DECK_ID:
			return _froslass_search_card_score(card, player, step_id)
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == MUNKIDORI_SOURCE_STEP:
			return _damage_source_score(slot)
		if step_id == MUNKIDORI_TARGET_STEP:
			return _damage_target_score(slot, context)
		if _deck_id == FROSLASS_DECK_ID and step_id == TM_BENCH_STEP:
			return 5600.0 if _matches_any(slot, SNORUNT) else 150.0
		if _is_handoff_step(step_id):
			return score_handoff_target(slot, step, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not item is PokemonSlot:
		return super.score_handoff_target(item, step, context)
	var slot := item as PokemonSlot
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _deck_id == HOP_DECK_ID:
		if _matches_any(slot, HOPS_CRAMORANT):
			return 4900.0 if _cramorant_prize_window(game_state, player_index) and _hop_slot_ready(slot, game_state, player_index) else 450.0
		if _matches_any(slot, HOPS_SNORLAX):
			return 5200.0 if _hop_slot_ready(slot, game_state, player_index) else 2300.0 + float(_attached_energy_count(slot)) * 280.0
		if _matches_any(slot, HOPS_ZACIAN):
			return 4700.0 if _hop_slot_ready(slot, game_state, player_index) else 2500.0
		if _matches_any(slot, URSALUNA):
			return 5600.0 if _hop_slot_ready(slot, game_state, player_index) else 1800.0
		if _matches_any(slot, MUNKIDORI):
			return 300.0
	if _deck_id == FROSLASS_DECK_ID:
		if _matches_any(slot, URSALUNA):
			return 5600.0 if _froslass_slot_ready(slot, game_state, player_index) else 1500.0
		if _matches_any(slot, BUDEW):
			return 3900.0
		if _matches_any(slot, MARACTUS):
			return 3600.0 if _froslass_slot_ready(slot, game_state, player_index) else 2200.0
		if _matches_any(slot, MUNKIDORI):
			return 2500.0 if _froslass_slot_ready(slot, game_state, player_index) else 650.0
		if _matches_any(slot, FROSLASS) or _matches_any(slot, SNORUNT):
			return 180.0
	return super.score_handoff_target(item, step, context)


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null:
		return super.predict_attacker_damage(slot, extra_context)
	var energy_count := _attached_energy_count(slot) + extra_context
	if _matches_any(slot, HOPS_ZACIAN):
		var required := 0 if _has_tool(slot, HOPS_BAND) else 1
		return {"damage": 60 if _has_tool(slot, HOPS_BAND) else 30, "can_attack": energy_count >= required, "description": "instant_slash"}
	if _matches_any(slot, HOPS_CRAMORANT):
		var required := 0 if _has_tool(slot, HOPS_BAND) else 1
		return {"damage": 150 if _has_tool(slot, HOPS_BAND) else 120, "can_attack": energy_count >= required, "description": "prize_window_spit"}
	if _matches_any(slot, HOPS_SNORLAX):
		var required := 2 if _has_tool(slot, HOPS_BAND) else 3
		return {"damage": 170 if _has_tool(slot, HOPS_BAND) else 140, "can_attack": energy_count >= required, "description": "snorlax_pressure"}
	if _matches_any(slot, BUDEW):
		return {"damage": 10, "can_attack": true, "description": "item_lock"}
	if _matches_any(slot, MARACTUS):
		return {"damage": 20 if energy_count >= 1 else 0, "can_attack": energy_count >= 1, "description": "retreat_lock"}
	if _matches_any(slot, MUNKIDORI):
		var can_attack := energy_count >= 2 and _slot_has_psychic_energy(slot)
		return {"damage": 60 if can_attack else 0, "can_attack": can_attack, "description": "psychic_confusion"}
	return super.predict_attacker_damage(slot, extra_context)


func _hop_search_card_score(card: CardInstance, player: PlayerState, step_id: String, context: Dictionary) -> float:
	if player == null:
		return float(get_search_priority(card))
	if step_id == HOP_BAG_STEP:
		if _matches_any(card, HOPS_SNORLAX):
			return 5900.0 if _count_field(player, HOPS_SNORLAX) == 0 else 1200.0
		if _matches_any(card, HOPS_ZACIAN):
			return 5600.0 if _count_field(player, HOPS_ZACIAN) == 0 else 1900.0
		if _matches_any(card, HOPS_CRAMORANT):
			return 5000.0 if _cramorant_prize_window(context.get("game_state", null), int(context.get("player_index", -1))) else 1100.0
	if _matches_any(card, HOPS_BAND) and not _field_has_tool(player, HOPS_BAND):
		return 5200.0
	if _matches_any(card, MUNKIDORI) and _has_damage_source(player) and _count_powered_munkidori(player) == 0:
		return 4700.0
	if _is_basic_darkness_energy(card) and _has_unpowered_munkidori(player):
		return 4400.0
	return float(get_search_priority(card))


func _froslass_search_card_score(card: CardInstance, player: PlayerState, step_id: String) -> float:
	if step_id == TM_CARD_STEP:
		return 6500.0 if _matches_any(card, FROSLASS) else 100.0
	if player == null:
		return float(get_search_priority(card))
	if _matches_any(card, FROSLASS):
		return 6200.0 if _count_field(player, SNORUNT) > 0 and _count_field(player, FROSLASS) < 2 else 2800.0
	if _matches_any(card, SNORUNT):
		return 5800.0 if _snow_line_count(player) < 2 else 1700.0
	if _matches_any(card, MUNKIDORI):
		return 5500.0 if _count_field(player, MUNKIDORI) < 2 else 1800.0
	if _is_basic_darkness_energy(card) or _matches_any(card, LUMINOUS_ENERGY):
		return 5300.0 if _has_unpowered_munkidori(player) else 1900.0
	if _matches_any(card, TM_EVOLUTION) and _tm_evolution_target_count(player) > 0:
		return 5000.0
	return float(get_search_priority(card))


func _recovery_card_score(card: CardInstance, player: PlayerState) -> float:
	if player == null:
		return float(get_search_priority(card))
	if _deck_id == HOP_DECK_ID:
		if _matches_any(card, HOPS_SNORLAX) and _count_field(player, HOPS_SNORLAX) == 0: return 5900.0
		if _matches_any(card, HOPS_ZACIAN) and _count_field(player, HOPS_ZACIAN) == 0: return 5600.0
		if _matches_any(card, MUNKIDORI) and _has_damage_source(player): return 5000.0
		if _is_basic_darkness_energy(card) and _has_unpowered_munkidori(player): return 4700.0
	if _deck_id == FROSLASS_DECK_ID:
		if _matches_any(card, FROSLASS) and _count_field(player, SNORUNT) > 0: return 6400.0
		if _matches_any(card, SNORUNT) and _snow_line_count(player) < 2: return 6000.0
		if _matches_any(card, MUNKIDORI) and _count_field(player, MUNKIDORI) < 2: return 5700.0
		if _is_basic_darkness_energy(card) and _has_unpowered_munkidori(player): return 5400.0
	return float(get_search_priority(card))


func _munkidori_ability_score(source: Variant, player: PlayerState, base_score: float) -> float:
	if not source is PokemonSlot or not _has_darkness_energy(source as PokemonSlot):
		return minf(base_score, -2500.0)
	var movable := _maximum_movable_damage(player)
	if movable < 10:
		return minf(base_score, -3000.0)
	return maxf(base_score, 5900.0 + float(mini(30, movable)) * 24.0)


func _damage_source_score(slot: PokemonSlot) -> float:
	if slot == null or slot.damage_counters < 10:
		return -1200.0
	var score := 2200.0 + float(mini(30, slot.damage_counters)) * 45.0
	if _matches_any(slot, HOPS_SNORLAX):
		score += 500.0
	if slot.get_remaining_hp() <= 40:
		score += 1200.0
	return score


func _damage_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var score := 1600.0 + float(slot.damage_counters) * 12.0
	if slot.get_remaining_hp() <= 30:
		score += 5200.0
	var cd := slot.get_card_data()
	if cd != null and cd.mechanic in ["ex", "V", "VSTAR"]:
		score += 900.0
	var state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var opponent := _opponent(state, player_index)
	if opponent != null and opponent.active_pokemon == slot:
		score += 280.0
	return score


func _detect_family_phase(game_state: GameState, player_index: int, debt: int, ready: PokemonSlot) -> String:
	var player := _player(game_state, player_index)
	if player == null:
		return "setup"
	if not player.prizes.is_empty() and player.prizes.size() <= 2 and ready != null:
		return "close"
	if debt > 0:
		if int(game_state.turn_number) <= 2:
			return "setup"
		return "rebuild" if _had_family_route(player) else "setup"
	if ready != null:
		return "convert"
	return "launch"


func _route_owner_name(game_state: GameState, player_index: int, ready: PokemonSlot) -> String:
	if ready != null:
		return _primary_name(ready)
	var player := _player(game_state, player_index)
	if _deck_id == HOP_DECK_ID:
		if _cramorant_prize_window(game_state, player_index) and _count_field(player, HOPS_CRAMORANT) > 0:
			return HOPS_CRAMORANT[0]
		if _count_field(player, HOPS_SNORLAX) > 0:
			return HOPS_SNORLAX[0]
		return HOPS_ZACIAN[0]
	if _count_field(player, MUNKIDORI) > 0:
		return MUNKIDORI[0]
	return BUDEW[0]


func _bridge_target_name(player: PlayerState) -> String:
	if _deck_id == HOP_DECK_ID:
		if _count_field(player, HOPS_SNORLAX) == 0:
			return HOPS_SNORLAX[0]
		if _count_field(player, HOPS_ZACIAN) == 0:
			return HOPS_ZACIAN[0]
		if _has_damage_source(player) and _count_powered_munkidori(player) == 0:
			return MUNKIDORI[0]
		return HOPS_CRAMORANT[0]
	if _count_field(player, FROSLASS) < 2 and _count_field(player, SNORUNT) > 0:
		return FROSLASS[0]
	if _snow_line_count(player) < 2:
		return SNORUNT[0]
	return MUNKIDORI[0]


func _setup_debt(player: PlayerState) -> int:
	if player == null:
		return 3
	if _deck_id == HOP_DECK_ID:
		var debt := 0
		if not _has_hop_attacker(player):
			debt += 1
		if _count_field(player, HOPS_SNORLAX) == 0:
			debt += 1
		if _has_damage_source(player) and _count_powered_munkidori(player) == 0:
			debt += 1
		return debt
	var debt := maxi(0, 2 - _snow_line_count(player))
	if _count_field(player, FROSLASS) == 0 and _has_froslass_evolution_route(player):
		debt += 1
	if _count_powered_munkidori(player) == 0:
		debt += 1
	return debt


func _best_ready_attacker(game_state: GameState, player_index: int) -> PokemonSlot:
	var player := _player(game_state, player_index)
	if player == null:
		return null
	var best: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var ready := _hop_slot_ready(slot, game_state, player_index) if _deck_id == HOP_DECK_ID else _froslass_slot_ready(slot, game_state, player_index)
		if not ready:
			continue
		var score := score_handoff_target(slot, {"id": "ready_check"}, {"game_state": game_state, "player_index": player_index})
		if score > best_score:
			best_score = score
			best = slot
	return best


func _hop_slot_ready(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if slot == null:
		return false
	if _matches_any(slot, HOPS_CRAMORANT):
		var need := 0 if _has_tool(slot, HOPS_BAND) else 1
		return _cramorant_prize_window(game_state, player_index) and _attached_energy_count(slot) >= need
	if _matches_any(slot, HOPS_ZACIAN):
		return _attached_energy_count(slot) >= (0 if _has_tool(slot, HOPS_BAND) else 1)
	if _matches_any(slot, HOPS_SNORLAX):
		return _attached_energy_count(slot) >= (2 if _has_tool(slot, HOPS_BAND) else 3)
	if _matches_any(slot, URSALUNA):
		return _attached_energy_count(slot) >= _bloodmoon_energy_required(game_state, player_index)
	return false


func _froslass_slot_ready(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if slot == null:
		return false
	if _matches_any(slot, BUDEW):
		return true
	if _matches_any(slot, MARACTUS):
		return _attached_energy_count(slot) >= 1
	if _matches_any(slot, URSALUNA):
		return _attached_energy_count(slot) >= _bloodmoon_energy_required(game_state, player_index)
	if _matches_any(slot, MUNKIDORI):
		return _attached_energy_count(slot) >= 2 and _slot_has_psychic_energy(slot)
	return false


func _bloodmoon_energy_required(game_state: GameState, player_index: int) -> int:
	var remaining := _opponent_remaining_prizes(game_state, player_index)
	return maxi(0, remaining - 1)


func _cramorant_prize_window(game_state: GameState, player_index: int) -> bool:
	return _opponent_remaining_prizes(game_state, player_index) in [3, 4]


func _opponent_remaining_prizes(game_state: GameState, player_index: int) -> int:
	var opponent := _opponent(game_state, player_index)
	if opponent == null or opponent.prizes.is_empty():
		return 6
	return opponent.prizes.size()


func _must_stop_engine_churn(action: Dictionary, player: PlayerState) -> bool:
	if not _is_low_deck(player):
		return false
	if player.deck.size() > 4 and _best_ready_attacker_from_player(player) == null:
		return false
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	if kind in ["play_trainer", "play_stadium", "use_stadium_effect"] and _matches_any(card, LOW_DECK_CHURN_CARDS):
		return true
	if kind == "use_ability" and _matches_any(action.get("source_slot", null), LOW_DECK_CHURN_CARDS):
		return true
	return false


func _best_ready_attacker_from_player(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		var prediction := predict_attacker_damage(slot)
		if bool(prediction.get("can_attack", false)):
			return slot
	return null


func _is_low_deck(player: PlayerState) -> bool:
	return player != null and player.deck.size() <= LOW_DECK_FLOOR


func _has_hop_attacker(player: PlayerState) -> bool:
	return _count_field(player, HOPS_ZACIAN) + _count_field(player, HOPS_CRAMORANT) + _count_field(player, HOPS_SNORLAX) + _count_field(player, URSALUNA) > 0


func _missing_hop_core_count(player: PlayerState) -> int:
	var missing := 0
	if _count_field(player, HOPS_SNORLAX) == 0: missing += 1
	if _count_field(player, HOPS_ZACIAN) == 0: missing += 1
	return missing


func _has_recoverable_hop_core(player: PlayerState) -> bool:
	return _zone_has(player.discard_pile, HOPS_SNORLAX) or _zone_has(player.discard_pile, HOPS_ZACIAN) or _zone_has(player.discard_pile, MUNKIDORI)


func _has_recoverable_froslass_core(player: PlayerState) -> bool:
	return _zone_has(player.discard_pile, FROSLASS) or _zone_has(player.discard_pile, SNORUNT) or _zone_has(player.discard_pile, MUNKIDORI) or _zone_has(player.discard_pile, DARKNESS_ENERGY)


func _has_froslass_evolution_route(player: PlayerState) -> bool:
	return _count_field(player, SNORUNT) > 0 and (_zone_has(player.hand, FROSLASS) or _zone_has(player.deck, FROSLASS))


func _snow_line_count(player: PlayerState) -> int:
	return _count_field(player, SNORUNT) + _count_field(player, FROSLASS)


func _tm_evolution_target_count(player: PlayerState) -> int:
	if player == null or not _zone_has(player.deck, FROSLASS):
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if _matches_any(slot, SNORUNT):
			count += 1
	return mini(2, count)


func _count_powered_munkidori(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, MUNKIDORI) and _has_darkness_energy(slot):
			count += 1
	return count


func _has_unpowered_munkidori(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, MUNKIDORI) and not _has_darkness_energy(slot):
			return true
	return false


func _has_damage_source(player: PlayerState) -> bool:
	return _maximum_movable_damage(player) >= 10


func _maximum_movable_damage(player: PlayerState) -> int:
	var maximum := 0
	if player == null:
		return maximum
	for slot: PokemonSlot in _all_slots(player):
		maximum = maxi(maximum, slot.damage_counters)
	return maximum


func _basic_darkness_in_hand(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.hand:
		if _is_basic_darkness_energy(card):
			count += 1
	return count


func _has_darkness_energy(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _energy_pays_darkness(energy):
			return true
	return false


func _slot_has_psychic_energy(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if str(energy.card_data.energy_provides) in ["P", "ANY"] or _matches_any(energy, LUMINOUS_ENERGY):
			return true
	return false


func _energy_pays_darkness(item: Variant) -> bool:
	var cd := _card_data_from_item(item)
	if cd == null or not cd.is_energy():
		return false
	return str(cd.energy_provides) in ["D", "ANY"] or _matches_any(item, DARKNESS_ENERGY) or _matches_any(item, LUMINOUS_ENERGY)


func _is_basic_darkness_energy(item: Variant) -> bool:
	var cd := _card_data_from_item(item)
	return cd != null and cd.card_type == "Basic Energy" and (str(cd.energy_provides) == "D" or _matches_any(item, DARKNESS_ENERGY))


func _attached_energy_count(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func _has_tool(slot: PokemonSlot, names: Array[String]) -> bool:
	return slot != null and slot.attached_tool != null and _matches_any(slot.attached_tool, names)


func _field_has_tool(player: PlayerState, names: Array[String]) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _has_tool(slot, names):
			return true
	return false


func _action_target_slot(action: Dictionary) -> PokemonSlot:
	var target: Variant = action.get("target_slot", action.get("target", null))
	return target as PokemonSlot if target is PokemonSlot else null


func _is_tm_evolution_attack(action: Dictionary) -> bool:
	if str(action.get("kind", "")) not in ["attack", "granted_attack"]:
		return false
	var attack_name := _attack_name(action).to_lower()
	var attack_id := str(action.get("attack_id", "")).to_lower()
	return attack_id == "tm_evolution" or attack_name in ["进化", "evolution"]


func _attack_name(action: Dictionary) -> String:
	var direct := str(action.get("attack_name", ""))
	if direct != "":
		return direct
	var attack: Variant = action.get("attack", {})
	return str((attack as Dictionary).get("name", "")) if attack is Dictionary else ""


func _is_handoff_step(step_id: String) -> bool:
	return step_id.contains("switch") or step_id.contains("active") or step_id.contains("send") or step_id.contains("handoff") or step_id.contains("retreat")


func _hop_band_target_score(target: PokemonSlot, game_state: GameState, player_index: int, base_score: float) -> float:
	if target == null or _has_tool(target, HOPS_BAND):
		return minf(base_score, -1800.0)
	if _matches_any(target, HOPS_ZACIAN):
		return maxf(base_score, 5200.0)
	if _matches_any(target, HOPS_SNORLAX):
		return maxf(base_score, 5000.0 if _attached_energy_count(target) >= 1 else 4000.0)
	if _matches_any(target, HOPS_CRAMORANT):
		return maxf(base_score, 4800.0 if _cramorant_prize_window(game_state, player_index) else 1900.0)
	return minf(base_score, 350.0)


func _hop_core_identity(item: Variant) -> String:
	if _matches_any(item, HOPS_SNORLAX): return "snorlax"
	if _matches_any(item, HOPS_ZACIAN): return "zacian"
	if _matches_any(item, HOPS_CRAMORANT): return "cramorant"
	return ""


func _first_basic_hand_index(player: PlayerState, names: Array[String]) -> int:
	for index: int in player.hand.size():
		var card: CardInstance = player.hand[index]
		if card != null and card.is_basic_pokemon() and _matches_any(card, names):
			return index
	return -1


func _count_field(player: PlayerState, names: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, names):
			count += 1
	return count


func _zone_has(zone: Array, names: Array[String]) -> bool:
	for item: Variant in zone:
		if _matches_any(item, names):
			return true
	return false


func _had_family_route(player: PlayerState) -> bool:
	if _deck_id == HOP_DECK_ID:
		return _has_hop_attacker(player) or _zone_has(player.discard_pile, HOPS_ZACIAN) or _zone_has(player.discard_pile, HOPS_SNORLAX)
	return _snow_line_count(player) > 0 or _zone_has(player.discard_pile, FROSLASS) or _zone_has(player.discard_pile, SNORUNT)


func _matches_any(item: Variant, names: Array[String]) -> bool:
	for name: String in names:
		if _matches_key(item, name):
			return true
	return false


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	return _player(context.get("game_state", null), int(context.get("player_index", -1)))


func _player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _opponent(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	return game_state.players[opponent_index]
