class_name DeckStrategyV18PartnerFamilies
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const ETHAN_HO_OH_DECK_ID := 800018539
const CYNTHIA_GARCHOMP_DECK_ID := 800018543
const ETHAN_TYPHLOSION_DECK_ID := 800018880

const HO_OH := "阿响的凤王ex"
const CHARCADET := "炭小侍"
const ARMAROUGE := "红莲铠骑"
const HEARTHFLAME := "厄诡椪 火灶面具ex"
const IRON_HANDS := "铁臂膀ex"

const CYNDAQUIL := "阿响的火球鼠"
const QUILAVA := "阿响的火岩鼠"
const TYPHLOSION := "阿响的火暴兽"
const ETHANS_ADVENTURE := "阿响的冒险"
const PIDGEY := "波波"
const PIDGEOTTO := "比比鸟"
const PIDGEOT := "大比鸟ex"
const VICTINI := "比克提尼"

const GIBLE := "竹兰的圆陆鲨"
const GABITE := "竹兰的尖牙陆鲨"
const GARCHOMP := "竹兰的烈咬陆鲨ex"
const ROSELIA := "竹兰的毒蔷薇"
const ROSERADE := "竹兰的罗丝雷朵"
const SPIRITOMB := "竹兰的花岩怪"
const MUNKIDORI := "愿增猿"
const POWER_WEIGHT := "竹兰的力量负重"

const FIRE_ENERGY := "基本火能量"
const FIGHTING_ENERGY := "基本斗能量"
const DARKNESS_ENERGY := "基本恶能量"
const LUMINOUS_ENERGY := "夜光能量"
const LEGACY_ENERGY := "遗赠能量"
const RARE_CANDY := "神奇糖果"
const TM_EVOLUTION := "招式学习器 进化"
const SUPER_ROD := "厉害钓竿"
const NIGHT_STRETCHER := "夜间担架"
const TYPHLOSION_UID := "CSV10C_030"
const ETHANS_ADVENTURE_UID := "CSV10C_208"
const PIDGEOT_UID := "CSV4C_101"
const QUICK_SEARCH_USED_EFFECT := "ability_search_any_used"
const QUICK_SEARCH_SHARED_FLAG := "ability_search_any_quick_search"
const QUICK_SEARCH_ADVENTURE_EXACT_KO := "quick_search_adventure_exact_ko"
const PLAY_ADVENTURE_EXACT_KO := "play_adventure_exact_ko"

const IDENTITY_ALIASES := {
	HO_OH: [HO_OH, "Ethan's Ho-Oh ex", "CSV10C_035", "23d228f7053a7314a2ee5f651f38a3cb"],
	CHARCADET: [CHARCADET, "Charcadet", "CSV9C_033"],
	ARMAROUGE: [ARMAROUGE, "Armarouge", "CSV1C_028"],
	HEARTHFLAME: [HEARTHFLAME, "Hearthflame Mask Ogerpon ex", "CSV9.5C_029"],
	IRON_HANDS: [IRON_HANDS, "Iron Hands ex", "CSV6C_051"],
	CYNDAQUIL: [CYNDAQUIL, "Ethan's Cyndaquil", "CSV10C_028", "37286bb1c41e2a5ea5d647b9c0e974f9"],
	QUILAVA: [QUILAVA, "Ethan's Quilava", "CSV10C_029", "3e4c565939e331574817cf3918c28725"],
	TYPHLOSION: [TYPHLOSION, "Ethan's Typhlosion", "CSV10C_030", "58b6393e8518ece9660234700f511a22"],
	ETHANS_ADVENTURE: [ETHANS_ADVENTURE, "Ethan's Adventure", "CSV10C_208", "3b03f59349002f02a731b531dbdb4358"],
	PIDGEY: [PIDGEY, "Pidgey", "151C_016"],
	PIDGEOTTO: [PIDGEOTTO, "Pidgeotto", "151C_017"],
	PIDGEOT: [PIDGEOT, "Pidgeot ex", "CSV4C_101"],
	VICTINI: [VICTINI, "Victini", "CSV9C_023"],
	GIBLE: [GIBLE, "Cynthia's Gible", "CSV10C_111", "1bbd1874c0cc4c60d3f1128e8583d583"],
	GABITE: [GABITE, "Cynthia's Gabite", "CSV10C_112", "23e6f24fc40bdb19384bc3c7822beea1"],
	GARCHOMP: [GARCHOMP, "Cynthia's Garchomp ex", "CSV10C_113", "b494c15a64405edbc24ed017733ad8a5"],
	ROSELIA: [ROSELIA, "Cynthia's Roselia", "CSV10C_004"],
	ROSERADE: [ROSERADE, "Cynthia's Roserade", "CSV10C_005"],
	SPIRITOMB: [SPIRITOMB, "Cynthia's Spiritomb", "CSV10C_138"],
	MUNKIDORI: [MUNKIDORI, "Munkidori", "CSV8C_094"],
	POWER_WEIGHT: [POWER_WEIGHT, "Cynthia's Power Weight", "CSV10C_200", "a13a8391817936aaa9c79cd3cfe5483f"],
	FIRE_ENERGY: [FIRE_ENERGY, "Fire Energy", "CSVE1C_FIR"],
	FIGHTING_ENERGY: [FIGHTING_ENERGY, "Fighting Energy", "CSVE1C_FIG"],
	DARKNESS_ENERGY: [DARKNESS_ENERGY, "Darkness Energy", "CSVE1C_DAR"],
	LUMINOUS_ENERGY: [LUMINOUS_ENERGY, "Luminous Energy", "CSV1C_127", "540ee48bb93584e4bfe3d7f5d0ee0efc"],
	LEGACY_ENERGY: [LEGACY_ENERGY, "Legacy Energy", "CSV8C_207", "6f31b7241a181631016466e561f148f3"],
	RARE_CANDY: [RARE_CANDY, "Rare Candy"],
	TM_EVOLUTION: [TM_EVOLUTION, "Technical Machine: Evolution"],
	SUPER_ROD: [SUPER_ROD, "Super Rod"],
	NIGHT_STRETCHER: [NIGHT_STRETCHER, "Night Stretcher"],
}

const PROFILES := {
	ETHAN_HO_OH_DECK_ID: {
		"strategy_id": "v18_partner_family_800018539",
		"signatures": [HO_OH, "Ethan's Ho-Oh ex", "CSV10C_035"],
		"active_priority": ["梦幻ex", "Mew ex", "怒鹦哥ex", "Squawkabilly ex", CHARCADET, HO_OH],
		"bench_priority": [HO_OH, CHARCADET, ARMAROUGE, "拉帝亚斯ex", "Latias ex", "吉雉鸡ex", "Fezandipiti ex"],
		"search_priority": [HO_OH, CHARCADET, ARMAROUGE, FIRE_ENERGY, "Fire Energy", "大地容器", "Earthen Vessel"],
		"evolution_priority": [ARMAROUGE],
		"energy_priority": [HO_OH, HEARTHFLAME, "Hearthflame Mask Ogerpon ex", IRON_HANDS, "Iron Hands ex", ARMAROUGE],
		"ability_priority": [HO_OH, ARMAROUGE, "怒鹦哥ex", "Squawkabilly ex", "吉雉鸡ex", "Fezandipiti ex"],
	},
	CYNTHIA_GARCHOMP_DECK_ID: {
		"strategy_id": "v18_partner_family_800018543",
		"signatures": [GARCHOMP, "Cynthia's Garchomp ex", "CSV10C_113"],
		"active_priority": ["含羞苞", "Budew", GIBLE, SPIRITOMB],
		"bench_priority": [GIBLE, ROSELIA, MUNKIDORI, SPIRITOMB],
		"search_priority": [GABITE, GARCHOMP, ROSERADE, GIBLE, ROSELIA, FIGHTING_ENERGY, POWER_WEIGHT],
		"evolution_priority": [GARCHOMP, ROSERADE, GABITE],
		"energy_priority": [GARCHOMP, GABITE, GIBLE, MUNKIDORI, SPIRITOMB],
		"ability_priority": [GABITE, ROSERADE, MUNKIDORI],
	},
	ETHAN_TYPHLOSION_DECK_ID: {
		"strategy_id": "v18_partner_family_800018880",
		"signatures": [TYPHLOSION, "Ethan's Typhlosion", "CSV10C_030"],
		"active_priority": [CYNDAQUIL, PIDGEY, VICTINI],
		"bench_priority": [CYNDAQUIL, PIDGEY, VICTINI, "吉雉鸡ex", "Fezandipiti ex"],
		"search_priority": [QUILAVA, TYPHLOSION, PIDGEOT, CYNDAQUIL, PIDGEY, ETHANS_ADVENTURE, FIRE_ENERGY],
		"evolution_priority": [TYPHLOSION, PIDGEOT, QUILAVA, PIDGEOTTO],
		"energy_priority": [TYPHLOSION, QUILAVA, CYNDAQUIL, VICTINI],
		"ability_priority": [QUILAVA, PIDGEOT, "吉雉鸡ex", "Fezandipiti ex"],
	},
}

var _deck_id := 0
var _prediction_game_state: GameState = null
var _prediction_player_index := -1


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else 0
	_prediction_game_state = null
	_prediction_player_index = -1


func _profile() -> Dictionary:
	var profile: Variant = PROFILES.get(_deck_id, {})
	return profile if profile is Dictionary else {}


func get_strategy_id() -> String:
	if _deck_id == ETHAN_HO_OH_DECK_ID:
		return "v18_ethans_ho_oh_core"
	return "v18_stage2_core_%d" % _deck_id


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	_remember_prediction_context(game_state, player_index)
	var player: PlayerState = _valid_player(game_state, player_index)
	var phase := "setup"
	var intent := "establish_partner_engine"
	var owner := _first_profile_name("energy_priority")
	var bridge := owner
	var pivot := owner
	var debt := _setup_debt(player)
	var exact_ko_route := _typhlosion_adventure_exact_ko_route(game_state, player_index)
	var exact_ko_debt := str(exact_ko_route.get("debt", ""))

	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			bridge = ARMAROUGE
			var ready_ho_oh := _best_ready_slot(player, HO_OH, 4)
			if ready_ho_oh != null:
				phase = "convert"
				intent = "attack_with_accelerated_ho_oh"
				pivot = HO_OH
			elif _has_slot(player, HO_OH):
				phase = "launch"
				intent = "concentrate_golden_flame"
		ETHAN_TYPHLOSION_DECK_ID:
			owner = TYPHLOSION
			bridge = QUILAVA if not _has_slot(player, QUILAVA) else PIDGEOT
			pivot = TYPHLOSION
			if exact_ko_debt != "":
				phase = "convert"
				intent = exact_ko_debt
			elif _best_ready_slot(player, TYPHLOSION, 1) != null:
				phase = "convert"
				intent = "convert_adventures_into_partner_blast"
			elif _has_slot(player, QUILAVA) or _has_slot(player, TYPHLOSION):
				phase = "launch"
				intent = "finish_typhlosion_and_seed_discard"
		CYNTHIA_GARCHOMP_DECK_ID:
			owner = GARCHOMP
			bridge = GABITE if not _has_slot(player, GABITE) else ROSERADE
			pivot = GARCHOMP
			if _best_ready_slot(player, GARCHOMP, 1) != null:
				phase = "convert"
				intent = "choose_spiral_draw_or_dragon_blast"
			elif _has_slot(player, GABITE) or _has_slot(player, GARCHOMP):
				phase = "launch"
				intent = "complete_cynthia_evolutions"

	if exact_ko_debt == "" and player != null and not player.prizes.is_empty() and player.prizes.size() <= 2 and _best_family_attacker(player) != null:
		phase = "close"
		intent = "take_final_prizes"
	elif player != null and int(game_state.turn_number) > 2 and debt > 0 and _had_family_route(player):
		phase = "rebuild"

	return {
		"id": "v18_partner_family_%d:%s" % [_deck_id, phase],
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
			"trainer": _trainer_priorities(),
		},
		"flags": {
			"partner_family_deck_id": _deck_id,
			"setup_debt": debt,
			"exact_ko_debt": exact_ko_debt,
			"ready_attacker": _best_family_attacker(player) != null,
		},
		"constraints": {
			"forbid_engine_churn": player != null and player.deck.size() <= 10 and _best_family_attacker(player) != null,
			"forbid_extra_bench_padding": player != null and player.bench.size() >= 4 and debt <= 0,
		},
		"context": context.duplicate(true),
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _valid_player(game_state, player_index)
	var debt := _setup_debt(player)
	var exact_ko_route := _typhlosion_adventure_exact_ko_route(game_state, player_index)
	var exact_ko_debt := str(exact_ko_route.get("debt", ""))
	var action_bonuses: Array[Dictionary] = [
		{"kind": "evolve", "target_names": _profile_list("evolution_priority"), "bonus": 360.0 if debt > 0 else 100.0},
		{"kind": "use_ability", "target_names": _profile_list("ability_priority"), "bonus": 240.0},
		{"kind": "attach_energy", "target_names": _profile_list("energy_priority"), "bonus": 210.0},
	]
	if exact_ko_debt == QUICK_SEARCH_ADVENTURE_EXACT_KO:
		action_bonuses.append({
			"kind": "use_ability",
			"target_names": [PIDGEOT, "Pidgeot ex"],
			"bonus": 2200.0,
		})
	elif exact_ko_debt == PLAY_ADVENTURE_EXACT_KO:
		action_bonuses.append({
			"kind": "play_trainer",
			"card_names": [ETHANS_ADVENTURE, "Ethan's Adventure"],
			"bonus": 3200.0,
		})
	return {
		"enabled": true,
		"safe_setup_before_attack": exact_ko_debt != "" or (debt > 0 and _best_family_attacker(player) != null),
		"setup_debt": {
			"partner_route": debt,
			"exact_ko": exact_ko_debt,
			"deck_id": _deck_id,
		},
		"action_bonuses": action_bonuses,
		"attack_penalty": 3600.0 if exact_ko_debt != "" else 520.0,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	_remember_prediction_context(game_state, player_index)
	var score := super.score_action_absolute(action, game_state, player_index)
	var player := _valid_player(game_state, player_index)
	if player == null:
		return score
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			return _score_ho_oh_action(action, player, score)
		ETHAN_TYPHLOSION_DECK_ID:
			return _score_typhlosion_action(action, player, score, game_state, player_index)
		CYNTHIA_GARCHOMP_DECK_ID:
			return _score_garchomp_action(action, player, score)
	return score


func _score_ho_oh_action(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_key(card, HO_OH):
				return maxf(base_score, 3900.0 if _count_slots(player, HO_OH) == 0 else 2800.0)
			if _matches_key(card, CHARCADET):
				return maxf(base_score, 2400.0)
		"evolve":
			if _matches_key(card, ARMAROUGE):
				return maxf(base_score, 3600.0)
		"attach_energy":
			var target: PokemonSlot = action.get("target_slot", null)
			if _energy_pays(card, "R", target):
				if _matches_key(target, HO_OH):
					var gap := maxi(0, 4 - _attached_energy(target))
					if gap <= 0:
						return minf(base_score, 700.0)
					return maxf(base_score, 4600.0 - float(gap - 1) * 260.0)
				if _has_slot(player, HO_OH):
					return minf(base_score, -1700.0)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_key(source, HO_OH):
				return maxf(base_score, 4800.0) if _count_basic_energy(player.hand, "R") > 0 else -1900.0
			if _matches_key(source, ARMAROUGE):
				return _score_armarouge_ability(player, base_score)
		"play_trainer":
			if _is_recovery_card(card):
				return maxf(base_score, 2800.0) if _has_recoverable_family_card(player) else -1800.0
			if _matches_key(card, "能量回收") or _matches_key(card, "Energy Retrieval"):
				return maxf(base_score, 3000.0) if _count_basic_energy(player.discard_pile, "R") > 0 else -1700.0
		"retreat":
			var target: PokemonSlot = action.get("bench_target", null)
			if _matches_key(target, HO_OH) and _is_ready_family_attacker(target):
				return maxf(base_score, 3900.0)
		"end_turn":
			if _setup_debt(player) > 0:
				return minf(base_score, -1900.0)
	return base_score


func _score_typhlosion_action(
	action: Dictionary,
	player: PlayerState,
	base_score: float,
	game_state: GameState,
	player_index: int
) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_key(card, CYNDAQUIL):
				return maxf(base_score, 3400.0 if _count_slots(player, CYNDAQUIL) == 0 else 2300.0)
			if _matches_key(card, PIDGEY):
				return maxf(base_score, 2500.0)
			if _matches_key(card, VICTINI):
				return maxf(base_score, 1700.0)
		"evolve":
			if _matches_key(card, TYPHLOSION):
				return maxf(base_score, 4900.0)
			if _matches_key(card, QUILAVA):
				return maxf(base_score, 4200.0)
			if _matches_key(card, PIDGEOT):
				return maxf(base_score, 3900.0)
			if _matches_key(card, PIDGEOTTO):
				return maxf(base_score, 3000.0)
		"attach_energy":
			var target: PokemonSlot = action.get("target_slot", null)
			var tm_energy_score := _score_typhlosion_tm_evolution_energy(card, target, player, base_score)
			if not is_nan(tm_energy_score):
				return tm_energy_score
			if _energy_pays(card, "R", target):
				if _matches_key(target, TYPHLOSION):
					return maxf(base_score, 4200.0 - float(_attached_energy(target)) * 500.0)
				if _matches_key(target, QUILAVA) or _matches_key(target, CYNDAQUIL):
					return maxf(base_score, 3200.0 - float(_attached_energy(target)) * 450.0)
				if _has_slot(player, TYPHLOSION) or _has_slot(player, QUILAVA):
					return minf(base_score, -1400.0)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_key(source, QUILAVA):
				return maxf(base_score, 4700.0) if _zone_has(player.deck, ETHANS_ADVENTURE) else -1300.0
			if _matches_key(source, PIDGEOT):
				return maxf(base_score, 4400.0)
		"play_trainer":
			if _matches_key(card, ETHANS_ADVENTURE) or _matches_key(card, "Ethan's Adventure"):
				return maxf(base_score, 4600.0)
			if _is_recovery_card(card):
				return maxf(base_score, 3000.0) if _has_recoverable_family_card(player) else -1700.0
			if _matches_key(card, RARE_CANDY) or _matches_key(card, "Rare Candy"):
				return maxf(base_score, 4300.0) if _has_slot(player, CYNDAQUIL) else -1200.0
		"attach_tool":
			if _matches_key(card, TM_EVOLUTION) or _matches_key(card, "Technical Machine: Evolution"):
				var target: PokemonSlot = action.get("target_slot", action.get("target", null))
				return _score_typhlosion_tm_evolution_attach(target, player, game_state, base_score)
		"granted_attack":
			if _is_tm_evolution_attack(action):
				var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
				return _score_typhlosion_tm_evolution_attack(source, player, game_state, base_score)
		"attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			if _matches_key(source, TYPHLOSION):
				var adventure_count := _count_zone(player.discard_pile, ETHANS_ADVENTURE)
				if int(action.get("attack_index", -1)) == 0 or _attack_name(action).contains("搭档爆破"):
					var prediction := predict_attacker_damage(source)
					var predicted_damage := int(prediction.get("damage", 0))
					var defender := _opponent_active(game_state, player_index)
					var knockout_bonus := 1800.0 if _would_knock_out(defender, predicted_damage) else 0.0
					return maxf(base_score, 2100.0 + float(adventure_count) * 650.0 + knockout_bonus)
				if int(action.get("attack_index", -1)) == 1 and adventure_count >= 2 and not bool(action.get("projected_knockout", false)):
					return minf(base_score, 2600.0)
		"retreat":
			var target: PokemonSlot = action.get("bench_target", null)
			if _matches_key(target, TYPHLOSION) and _is_ready_family_attacker(target):
				return maxf(base_score, 4000.0)
		"end_turn":
			if _setup_debt(player) > 0:
				return minf(base_score, -1800.0)
	return base_score


func _score_typhlosion_tm_evolution_attach(
	target: PokemonSlot,
	player: PlayerState,
	game_state: GameState,
	base_score: float
) -> float:
	if target == null or player == null or _first_player_attack_locked(game_state, player):
		return minf(base_score, -4000.0)
	if target != player.active_pokemon:
		return minf(base_score, -4000.0)
	var target_count := _tm_evolution_target_count(player)
	if target_count <= 0:
		return minf(base_score, -1100.0)
	if not _can_fund_tm_evolution_attack(target, player, game_state):
		return maxf(base_score, 900.0)
	return maxf(base_score, 4200.0 + float(target_count) * 600.0)


func _score_typhlosion_tm_evolution_energy(
	energy: Variant,
	target: PokemonSlot,
	player: PlayerState,
	base_score: float
) -> float:
	var energy_data := _card_data_from_item(energy)
	if energy_data == null or not energy_data.is_energy() or player == null:
		return NAN
	var carrier := _tm_route_carrier(player)
	if carrier == null or _tm_evolution_target_count(player) <= 0 or not carrier.attached_energy.is_empty():
		return NAN
	return maxf(base_score, 5000.0) if target == carrier else minf(base_score, -3000.0)


func _score_typhlosion_tm_evolution_attack(
	source: PokemonSlot,
	player: PlayerState,
	game_state: GameState,
	base_score: float
) -> float:
	if source == null or player == null or _first_player_attack_locked(game_state, player):
		return minf(base_score, -4000.0)
	var target_count := _tm_evolution_target_count(player)
	if source != player.active_pokemon or target_count <= 0:
		return minf(base_score, -3000.0)
	if not _can_fund_tm_evolution_attack(source, player, game_state):
		return minf(base_score, -3000.0)
	return maxf(base_score, 7200.0 + float(target_count) * 900.0)


func _score_garchomp_action(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"play_basic_to_bench":
			if _matches_key(card, GIBLE):
				return maxf(base_score, 3500.0 if _count_slots(player, GIBLE) == 0 else 2400.0)
			if _matches_key(card, ROSELIA):
				return maxf(base_score, 2800.0)
		"evolve":
			if _matches_key(card, GARCHOMP):
				return maxf(base_score, 5000.0)
			if _matches_key(card, GABITE):
				return maxf(base_score, 4400.0)
			if _matches_key(card, ROSERADE):
				return maxf(base_score, 4200.0)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_key(source, GABITE):
				return maxf(base_score, 4700.0)
		"attach_energy":
			return _score_cynthia_attach(action, player, base_score)
		"attach_tool":
			var target: PokemonSlot = action.get("target_slot", null)
			if _matches_key(card, POWER_WEIGHT) or _matches_key(card, "Cynthia's Power Weight"):
				if _matches_key(target, GARCHOMP):
					return maxf(base_score, 3900.0)
				if _is_cynthia_pokemon(target):
					return maxf(base_score, 2300.0)
			if _matches_key(card, TM_EVOLUTION) or _matches_key(card, "Technical Machine: Evolution"):
				return maxf(base_score, 3800.0) if _tm_evolution_target_count(player) > 0 else -1200.0
		"granted_attack":
			if _is_tm_evolution_attack(action):
				return maxf(base_score, 4900.0) if _tm_evolution_target_count(player) > 0 else -1700.0
		"play_trainer":
			if _is_recovery_card(card):
				return maxf(base_score, 3200.0) if _has_recoverable_family_card(player) else -1700.0
			if _matches_key(card, "大地容器") or _matches_key(card, "Earthen Vessel"):
				return maxf(base_score, 3300.0) if _count_basic_energy(player.hand, "F") == 0 else base_score
		"attack":
			if _matches_key(action.get("source_slot", null), GARCHOMP):
				var attack_index := int(action.get("attack_index", -1))
				if attack_index == 0 or _attack_name(action).contains("螺旋俯冲"):
					var draw_live := player.hand.size() < 6 and player.deck.size() > 6
					return maxf(base_score, 3600.0 if draw_live else 2500.0)
				if attack_index == 1 or _attack_name(action).contains("龙之爆破"):
					if bool(action.get("projected_knockout", false)):
						return maxf(base_score, 5600.0)
					return maxf(base_score, 3900.0) if _has_garchomp_rebuild_energy(player) else minf(base_score, 2500.0)
		"retreat":
			var target: PokemonSlot = action.get("bench_target", null)
			if _matches_key(target, GARCHOMP) and _is_ready_family_attacker(target):
				return maxf(base_score, 4100.0)
		"end_turn":
			if _setup_debt(player) > 0:
				return minf(base_score, -1800.0)
	return base_score


func get_discard_priority(card: CardInstance) -> int:
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			if _is_basic_energy(card, "R"):
				return 4
			if _matches_key(card, HO_OH):
				return 7
			if _matches_key(card, CHARCADET) or _matches_key(card, ARMAROUGE):
				return 12
			if _is_recovery_card(card):
				return 9
			if _matches_key(card, "厄诡椪 水井面具ex") or _matches_key(card, "Wellspring Mask Ogerpon ex") \
					or _matches_key(card, "太乐巴戈斯ex") or _matches_key(card, "Terapagos ex") \
					or _matches_key(card, "铁蚁ex") or _matches_key(card, "Durant ex"):
				return 96
		ETHAN_TYPHLOSION_DECK_ID:
			if _matches_key(card, ETHANS_ADVENTURE) or _matches_key(card, "Ethan's Adventure"):
				return 98
			if _is_basic_energy(card, "R"):
				return 8
			if _matches_key(card, QUILAVA) or _matches_key(card, TYPHLOSION):
				return 6
			if _matches_key(card, CYNDAQUIL) or _matches_key(card, PIDGEY):
				return 12
			if _matches_key(card, RARE_CANDY) or _matches_key(card, "Rare Candy") or _is_recovery_card(card):
				return 10
		CYNTHIA_GARCHOMP_DECK_ID:
			if _matches_key(card, GARCHOMP) or _matches_key(card, GABITE) or _matches_key(card, ROSERADE):
				return 6
			if _matches_key(card, GIBLE) or _matches_key(card, ROSELIA):
				return 11
			if _is_basic_energy(card, "F"):
				return 8
			if _matches_key(card, TM_EVOLUTION) or _matches_key(card, POWER_WEIGHT) or _is_recovery_card(card):
				return 12
	return super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player := _valid_player(game_state, player_index)
	var priority := get_discard_priority(card)
	if player == null:
		return priority
	if _deck_id == ETHAN_TYPHLOSION_DECK_ID and _matches_key(card, ETHANS_ADVENTURE):
		return 98 if _count_zone(player.discard_pile, ETHANS_ADVENTURE) < 4 else 65
	if _is_family_evolution(card) and not _has_direct_parent(player, card.card_data):
		return mini(priority, 8)
	return priority


func get_search_priority(card: CardInstance) -> int:
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			if _matches_key(card, HO_OH): return 1000
			if _matches_key(card, CHARCADET): return 820
			if _matches_key(card, ARMAROUGE): return 760
			if _is_basic_energy(card, "R"): return 700
		ETHAN_TYPHLOSION_DECK_ID:
			if _matches_key(card, QUILAVA): return 980
			if _matches_key(card, TYPHLOSION): return 940
			if _matches_key(card, CYNDAQUIL): return 850
			if _matches_key(card, ETHANS_ADVENTURE): return 820
			if _is_basic_energy(card, "R"): return 680
		CYNTHIA_GARCHOMP_DECK_ID:
			if _matches_key(card, GABITE): return 1000
			if _matches_key(card, GARCHOMP): return 980
			if _matches_key(card, ROSERADE): return 900
			if _matches_key(card, GIBLE): return 860
			if _matches_key(card, ROSELIA): return 780
			if _is_basic_energy(card, "F"): return 700
	return super.get_search_priority(card)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	if item is Dictionary:
		var assignment: Dictionary = item
		return score_interaction_target(assignment.get("source", null), step, context) \
			+ score_interaction_target(assignment.get("target", null), step, context)
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if _deck_id == CYNTHIA_GARCHOMP_DECK_ID and step_id == "draw_to_hand_size_choice":
		if str(item) == "draw":
			return 4600.0 if player != null and player.hand.size() < 6 and player.deck.size() > 6 else -900.0
		return 1200.0 if player == null or player.hand.size() >= 6 or player.deck.size() <= 6 else -700.0
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard"):
			var game_state: GameState = context.get("game_state", null)
			return float(get_discard_priority_contextual(card, game_state, int(context.get("player_index", -1))))
		if _is_recovery_step(step_id):
			return _score_recovery_card(card, player)
		if _deck_id == ETHAN_HO_OH_DECK_ID and step_id == "move_fire_energy_from_bench_to_active":
			var source := _source_slot_for_energy(player, card)
			if source == null:
				return 0.0
			if _matches_key(source, HO_OH):
				return 3200.0 - float(_attached_energy(source)) * 300.0
			return 3900.0
		match _deck_id:
			ETHAN_HO_OH_DECK_ID:
				return _score_ho_oh_search_card(card, player)
			ETHAN_TYPHLOSION_DECK_ID:
				return _score_typhlosion_search_card(card, player, step_id, context)
			CYNTHIA_GARCHOMP_DECK_ID:
				return _score_cynthia_search_card(card, player, step_id)
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if _deck_id == ETHAN_TYPHLOSION_DECK_ID and _is_opponent_target_step(step_id):
			return _score_typhlosion_gust_target(slot)
		match _deck_id:
			ETHAN_HO_OH_DECK_ID:
				if step_id == "attach_fire_to_benched_ethan":
					if _matches_key(slot, HO_OH):
						return 5200.0 - absf(float(_attached_energy(slot) - 2)) * 400.0
					return 500.0
				if _is_handoff_step(step_id):
					return score_handoff_target(slot, step, context)
			ETHAN_TYPHLOSION_DECK_ID:
				if step_id.contains("evolution_bench"):
					if _matches_key(slot, CYNDAQUIL):
						return 4700.0
					if _matches_key(slot, PIDGEY):
						return 3600.0
					return 500.0
				if _is_handoff_step(step_id):
					return score_handoff_target(slot, step, context)
			CYNTHIA_GARCHOMP_DECK_ID:
				if step_id.contains("evolution_bench") or step_id.contains("target_pokemon"):
					if _matches_key(slot, GIBLE):
						return 4800.0
					if _matches_key(slot, ROSELIA):
						return 3900.0
					return 450.0
				if _is_handoff_step(step_id):
					return score_handoff_target(slot, step, context)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	if not item is PokemonSlot:
		return super.score_handoff_target(item, step, context)
	var slot := item as PokemonSlot
	var step_id := str(step.get("id", "")).to_lower()
	if _deck_id == ETHAN_TYPHLOSION_DECK_ID and _is_opponent_target_step(step_id):
		return _score_typhlosion_gust_target(slot)
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			if _matches_key(slot, HO_OH):
				return 5200.0 + float(_attached_energy(slot)) * 180.0 if _is_ready_family_attacker(slot) else 2300.0
		ETHAN_TYPHLOSION_DECK_ID:
			if _matches_key(slot, TYPHLOSION):
				if not _is_ready_family_attacker(slot):
					return 2500.0
				var prediction := predict_attacker_damage(slot)
				var defender := _opponent_active(_prediction_game_state, _prediction_player_index)
				var knockout_bonus := 1800.0 if _would_knock_out(defender, int(prediction.get("damage", 0))) else 0.0
				return 5200.0 + knockout_bonus
			if _matches_key(slot, VICTINI) and _is_ready_family_attacker(slot):
				return 1800.0
		CYNTHIA_GARCHOMP_DECK_ID:
			if _matches_key(slot, GARCHOMP):
				return 5400.0 + float(_attached_energy(slot)) * 220.0 if _is_ready_family_attacker(slot) else 2700.0
			if _matches_key(slot, SPIRITOMB) and _is_ready_family_attacker(slot):
				return 1700.0
	return super.score_handoff_target(item, step, context)


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null:
		return super.predict_attacker_damage(slot, extra_context)
	var energy_count := _attached_energy(slot) + extra_context
	if _matches_key(slot, HO_OH):
		return {"damage": 160 if energy_count >= 4 else 0, "can_attack": energy_count >= 4, "description": "golden_flame_route"}
	if _matches_key(slot, TYPHLOSION):
		var can_attack := energy_count >= 1
		var player := _valid_player(_prediction_game_state, _prediction_player_index)
		return {
			"damage": _typhlosion_partner_blast_damage(player) if can_attack else 0,
			"can_attack": can_attack,
			"description": "partner_blast_route",
		}
	if _matches_key(slot, GARCHOMP):
		var damage := 0
		if energy_count >= 2:
			damage = 260
		elif energy_count >= 1:
			damage = 100
		return {"damage": damage, "can_attack": energy_count >= 1, "description": "cynthia_attack_route"}
	return super.predict_attacker_damage(slot, extra_context)


func _typhlosion_partner_blast_damage(player: PlayerState) -> int:
	var damage := 40
	if player == null:
		return damage
	damage += _count_zone(player.discard_pile, ETHANS_ADVENTURE) * 60
	if _has_slot(player, VICTINI):
		damage += 10
	return damage


func _typhlosion_adventure_exact_ko_route(
	game_state: GameState,
	player_index: int,
	route_context: Dictionary = {}
) -> Dictionary:
	var route := {
		"debt": "",
		"current_damage": 0,
		"boosted_damage": 0,
		"defender_hp": 0,
	}
	if _deck_id != ETHAN_TYPHLOSION_DECK_ID or game_state == null or game_state.supporter_used_this_turn:
		return route
	var player := _valid_player(game_state, player_index)
	if player == null or not _has_exact_uid(player.active_pokemon, TYPHLOSION_UID):
		return route
	var has_required_fire := false
	for energy: CardInstance in player.active_pokemon.attached_energy:
		if _energy_pays(energy, "R", player.active_pokemon):
			has_required_fire = true
			break
	if not has_required_fire:
		return route
	var defender := _opponent_active(game_state, player_index)
	if defender == null:
		return route
	var current_damage := _typhlosion_partner_blast_damage(player)
	var defender_hp := defender.get_remaining_hp()
	route["current_damage"] = current_damage
	route["boosted_damage"] = current_damage + 60
	route["defender_hp"] = defender_hp
	if current_damage >= defender_hp or current_damage + 60 < defender_hp:
		return route
	if not _has_exact_uid_on_field(player, PIDGEOT_UID):
		return route
	if _zone_has_exact_uid(player.hand, ETHANS_ADVENTURE_UID):
		route["debt"] = PLAY_ADVENTURE_EXACT_KO
		return route
	if not _zone_has_exact_uid(player.deck, ETHANS_ADVENTURE_UID):
		return route
	var explicit_source: Variant = route_context.get("quick_search_source", null)
	if bool(route_context.get("require_quick_search_source", false)) and not _has_exact_uid(explicit_source, PIDGEOT_UID):
		return route
	var quick_search_source := _available_typhlosion_quick_search_source(player, game_state)
	if quick_search_source == null:
		return route
	if explicit_source != null and not _has_exact_uid(explicit_source, PIDGEOT_UID):
		return route
	route["debt"] = QUICK_SEARCH_ADVENTURE_EXACT_KO
	route["quick_search_source"] = quick_search_source
	return route


func _available_typhlosion_quick_search_source(player: PlayerState, game_state: GameState) -> PokemonSlot:
	if player == null or game_state == null:
		return null
	var shared_key := "%s_%d" % [QUICK_SEARCH_SHARED_FLAG, int(player.player_index)]
	if int(game_state.shared_turn_flags.get(shared_key, -1)) == int(game_state.turn_number):
		return null
	for slot: PokemonSlot in _all_slots(player):
		if not _has_exact_uid(slot, PIDGEOT_UID):
			continue
		var used_this_turn := false
		for effect: Dictionary in slot.effects:
			if str(effect.get("type", "")) == QUICK_SEARCH_USED_EFFECT \
					and int(effect.get("turn", -1)) == int(game_state.turn_number):
				used_this_turn = true
				break
		if not used_this_turn:
			return slot
	return null


func _interaction_quick_search_source(context: Dictionary) -> Variant:
	for key: String in ["pending_effect_card", "effect_card", "source_card", "pending_card", "source_slot"]:
		var source: Variant = context.get(key, null)
		if source != null:
			return source
	return null


func _has_exact_uid_on_field(player: PlayerState, uid: String) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _has_exact_uid(slot, uid):
			return true
	return false


func _zone_has_exact_uid(cards: Array, uid: String) -> bool:
	for card: Variant in cards:
		if _has_exact_uid(card, uid):
			return true
	return false


func _has_exact_uid(item: Variant, uid: String) -> bool:
	var card_data := _card_data_from_item(item)
	return card_data != null and str(card_data.get_uid()).to_lower() == uid.to_lower()


func _score_typhlosion_gust_target(slot: PokemonSlot) -> float:
	var player := _valid_player(_prediction_game_state, _prediction_player_index)
	if slot == null or player == null or not _matches_key(player.active_pokemon, TYPHLOSION):
		return 0.0
	var prediction := predict_attacker_damage(player.active_pokemon)
	if not bool(prediction.get("can_attack", false)):
		return 0.0
	var damage := int(prediction.get("damage", 0))
	var score := float(slot.get_prize_count()) * 180.0 - float(slot.get_remaining_hp()) * 0.20
	if _would_knock_out(slot, damage):
		score += 4200.0
	return score


func _remember_prediction_context(game_state: GameState, player_index: int) -> void:
	if _valid_player(game_state, player_index) == null:
		return
	_prediction_game_state = game_state
	_prediction_player_index = player_index


func _opponent_active(game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null:
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	return game_state.players[opponent_index].active_pokemon


func _would_knock_out(defender: PokemonSlot, damage: int) -> bool:
	return defender != null and damage > 0 and damage >= defender.get_remaining_hp()


func _is_opponent_target_step(step_id: String) -> bool:
	return step_id in ["opponent_bench_target", "opponent_switch_target", "gust_target"]


func _score_ho_oh_search_card(card: CardInstance, player: PlayerState) -> float:
	if _matches_key(card, HO_OH):
		var field_count := _count_slots(player, HO_OH)
		if field_count == 0:
			return 5200.0
		if field_count == 1:
			return 3600.0
		return 1200.0
	if _matches_key(card, CHARCADET):
		return 4100.0 if _count_slots(player, CHARCADET) == 0 and not _has_slot(player, ARMAROUGE) else 1300.0
	if _matches_key(card, ARMAROUGE):
		return 4400.0 if _has_slot(player, CHARCADET) and not _has_slot(player, ARMAROUGE) else 1000.0
	if _is_basic_energy(card, "R"):
		return 3900.0 if player == null or _count_basic_energy(player.hand, "R") < 2 else 2400.0
	return float(get_search_priority(card))


func _score_typhlosion_search_card(
	card: CardInstance,
	player: PlayerState,
	step_id: String,
	context: Dictionary
) -> float:
	if step_id == "search_cards" and _has_exact_uid(card, ETHANS_ADVENTURE_UID):
		var game_state: GameState = context.get("game_state", null)
		var route := _typhlosion_adventure_exact_ko_route(game_state, int(context.get("player_index", -1)), {
			"quick_search_source": _interaction_quick_search_source(context),
			"require_quick_search_source": true,
		})
		if str(route.get("debt", "")) == QUICK_SEARCH_ADVENTURE_EXACT_KO:
			return 7000.0
	if step_id == "search_named_card" and (_matches_key(card, ETHANS_ADVENTURE) or _matches_key(card, "Ethan's Adventure")):
		return 5600.0
	if _matches_key(card, QUILAVA):
		return 5300.0 if _has_slot(player, CYNDAQUIL) and not _has_slot(player, QUILAVA) else 1300.0
	if _matches_key(card, TYPHLOSION):
		return 5400.0 if _has_slot(player, QUILAVA) and not _has_slot(player, TYPHLOSION) else 1100.0
	if _matches_key(card, CYNDAQUIL):
		return 4800.0 if _count_slots(player, CYNDAQUIL) == 0 else 1800.0
	if _matches_key(card, PIDGEOTTO):
		return 3900.0 if _has_slot(player, PIDGEY) and not _has_slot(player, PIDGEOTTO) else 1000.0
	if _matches_key(card, PIDGEOT):
		return 4300.0 if _has_slot(player, PIDGEOTTO) and not _has_slot(player, PIDGEOT) else 1200.0
	if _is_basic_energy(card, "R"):
		return 3600.0 if not _has_ready_energy_owner(player) else 2100.0
	return float(get_search_priority(card))


func _score_cynthia_search_card(card: CardInstance, player: PlayerState, step_id: String) -> float:
	if step_id.contains("evolution_cards"):
		if _matches_key(card, GABITE):
			return 5200.0
		if _matches_key(card, ROSERADE):
			return 4300.0
		return 500.0
	if _matches_key(card, GARCHOMP):
		return 5600.0 if _has_slot(player, GABITE) and not _has_slot(player, GARCHOMP) else 1200.0
	if _matches_key(card, GABITE):
		return 5400.0 if _has_slot(player, GIBLE) and not _has_slot(player, GABITE) else 1500.0
	if _matches_key(card, ROSERADE):
		return 5000.0 if _has_slot(player, ROSELIA) and not _has_slot(player, ROSERADE) else 1400.0
	if _matches_key(card, GIBLE):
		return 4700.0 if _count_slots(player, GIBLE) == 0 else 1900.0
	if _matches_key(card, ROSELIA):
		return 4000.0 if _count_slots(player, ROSELIA) == 0 else 1500.0
	if _matches_key(card, SPIRITOMB):
		return 1700.0
	if _is_basic_energy(card, "F"):
		return 3600.0 if not _has_ready_energy_owner(player) else 2100.0
	return float(get_search_priority(card))


func _score_recovery_card(card: CardInstance, player: PlayerState) -> float:
	if card == null:
		return 0.0
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			if _matches_key(card, HO_OH): return 5400.0 if _count_slots(player, HO_OH) < 2 else 2500.0
			if _matches_key(card, ARMAROUGE) or _matches_key(card, CHARCADET): return 4200.0
			if _is_basic_energy(card, "R"): return 3900.0
		ETHAN_TYPHLOSION_DECK_ID:
			if _matches_key(card, TYPHLOSION): return 5400.0 if _has_slot(player, QUILAVA) else 3000.0
			if _matches_key(card, QUILAVA): return 5200.0 if _has_slot(player, CYNDAQUIL) else 2900.0
			if _matches_key(card, CYNDAQUIL): return 4500.0 if _count_slots(player, CYNDAQUIL) == 0 else 2300.0
			if _is_basic_energy(card, "R"): return 4000.0 if not _has_ready_energy_owner(player) else 2600.0
		CYNTHIA_GARCHOMP_DECK_ID:
			if _is_basic_energy(card, "F"):
				return 5400.0 if _has_slot(player, GARCHOMP) and not _has_ready_energy_owner(player) else 3600.0
			if _matches_key(card, GARCHOMP): return 5200.0 if _has_slot(player, GABITE) else 3000.0
			if _matches_key(card, GABITE): return 5000.0 if _has_slot(player, GIBLE) else 2800.0
			if _matches_key(card, GIBLE) or _matches_key(card, ROSELIA): return 4100.0
			if _is_basic_energy(card, "D"): return 3000.0 if _has_slot(player, MUNKIDORI) else 1800.0
	return float(get_search_priority(card)) * 0.75


func _score_cynthia_attach(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var card: Variant = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if _matches_key(target, MUNKIDORI) and _energy_pays(card, "D", target):
		return maxf(base_score, 3000.0 if _dark_route_is_funded(player) else 2100.0)
	if _energy_pays(card, "F", target):
		if _matches_key(target, GARCHOMP):
			return maxf(base_score, 4400.0 - float(_attached_energy(target)) * 550.0)
		if _matches_key(target, GABITE) or _matches_key(target, GIBLE):
			return maxf(base_score, 3300.0 - float(_attached_energy(target)) * 420.0)
		if _has_slot(player, GARCHOMP) or _has_slot(player, GABITE):
			return minf(base_score, -1300.0)
	return base_score


func _dark_route_is_funded(player: PlayerState) -> bool:
	return _best_ready_slot(player, GARCHOMP, 1) != null or _best_ready_slot(player, GABITE, 1) != null


func _score_armarouge_ability(player: PlayerState, base_score: float) -> float:
	if player == null or player.active_pokemon == null:
		return -1800.0
	if _matches_key(player.active_pokemon, HO_OH) and _attached_energy(player.active_pokemon) < 4:
		return maxf(base_score, 3900.0)
	if _matches_key(player.active_pokemon, HEARTHFLAME) or _matches_key(player.active_pokemon, "Hearthflame Mask Ogerpon ex"):
		return maxf(base_score, 2100.0)
	return -1800.0


func _setup_debt(player: PlayerState) -> int:
	if player == null:
		return 2
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			return int(not _has_slot(player, HO_OH)) + int(not (_has_slot(player, CHARCADET) or _has_slot(player, ARMAROUGE)))
		ETHAN_TYPHLOSION_DECK_ID:
			return int(not (_has_slot(player, CYNDAQUIL) or _has_slot(player, QUILAVA) or _has_slot(player, TYPHLOSION))) \
				+ int(not (_has_slot(player, PIDGEY) or _has_slot(player, PIDGEOTTO) or _has_slot(player, PIDGEOT)))
		CYNTHIA_GARCHOMP_DECK_ID:
			return int(not (_has_slot(player, GIBLE) or _has_slot(player, GABITE) or _has_slot(player, GARCHOMP))) \
				+ int(not (_has_slot(player, ROSELIA) or _has_slot(player, ROSERADE)))
	return 0


func _trainer_priorities() -> Array[String]:
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			return ["大地容器", "Earthen Vessel", "能量回收", "Energy Retrieval", NIGHT_STRETCHER, "Night Stretcher", SUPER_ROD, "Super Rod"]
		ETHAN_TYPHLOSION_DECK_ID:
			return [ETHANS_ADVENTURE, "Ethan's Adventure", "派帕", "Arven", TM_EVOLUTION, "Technical Machine: Evolution", RARE_CANDY, "Rare Candy", SUPER_ROD, "Super Rod"]
		CYNTHIA_GARCHOMP_DECK_ID:
			return [TM_EVOLUTION, "Technical Machine: Evolution", POWER_WEIGHT, "Cynthia's Power Weight", "大地容器", "Earthen Vessel", NIGHT_STRETCHER, "Night Stretcher"]
	return []


func _best_family_attacker(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	match _deck_id:
		ETHAN_HO_OH_DECK_ID:
			return _best_ready_slot(player, HO_OH, 4)
		ETHAN_TYPHLOSION_DECK_ID:
			return _best_ready_slot(player, TYPHLOSION, 1)
		CYNTHIA_GARCHOMP_DECK_ID:
			return _best_ready_slot(player, GARCHOMP, 1)
	return null


func _best_ready_slot(player: PlayerState, identity: String, minimum_energy: int) -> PokemonSlot:
	var best: PokemonSlot = null
	var best_energy := -1
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_key(slot, identity):
			continue
		var count := _attached_energy(slot)
		if count >= minimum_energy and count > best_energy:
			best = slot
			best_energy = count
	return best


func _is_ready_family_attacker(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	if _matches_key(slot, HO_OH): return _attached_energy(slot) >= 4
	if _matches_key(slot, TYPHLOSION): return _attached_energy(slot) >= 1
	if _matches_key(slot, GARCHOMP): return _attached_energy(slot) >= 1
	if _matches_key(slot, VICTINI): return _attached_energy(slot) >= 2
	if _matches_key(slot, SPIRITOMB): return _attached_energy(slot) >= 1
	return bool(super.predict_attacker_damage(slot).get("can_attack", false))


func _has_ready_energy_owner(player: PlayerState) -> bool:
	return _best_family_attacker(player) != null


func _had_family_route(player: PlayerState) -> bool:
	if player == null:
		return false
	match _deck_id:
		ETHAN_HO_OH_DECK_ID: return _has_slot(player, HO_OH) or _zone_has(player.discard_pile, HO_OH)
		ETHAN_TYPHLOSION_DECK_ID: return _has_slot(player, TYPHLOSION) or _zone_has(player.discard_pile, TYPHLOSION)
		CYNTHIA_GARCHOMP_DECK_ID: return _has_slot(player, GARCHOMP) or _zone_has(player.discard_pile, GARCHOMP)
	return false


func _has_recoverable_family_card(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		match _deck_id:
			ETHAN_HO_OH_DECK_ID:
				if _matches_key(card, HO_OH) or _matches_key(card, CHARCADET) or _matches_key(card, ARMAROUGE) or _is_basic_energy(card, "R"): return true
			ETHAN_TYPHLOSION_DECK_ID:
				if _matches_key(card, CYNDAQUIL) or _matches_key(card, QUILAVA) or _matches_key(card, TYPHLOSION) or _is_basic_energy(card, "R"): return true
			CYNTHIA_GARCHOMP_DECK_ID:
				if _is_cynthia_pokemon(card) or _is_basic_energy(card, "F"): return true
	return false


func _has_garchomp_rebuild_energy(player: PlayerState) -> bool:
	return _count_basic_energy(player.hand, "F") + _count_basic_energy(player.discard_pile, "F") > 0 \
		or _count_slots_with_energy(player, GARCHOMP, 1) >= 2


func _has_direct_parent(player: PlayerState, evolution: CardData) -> bool:
	if player == null or evolution == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if evolution.evolves_from_matches(slot.get_card_data()):
			return true
	return false


func _is_family_evolution(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_evolution_pokemon() and (
		_matches_key(card, ARMAROUGE) or _matches_key(card, QUILAVA) or _matches_key(card, TYPHLOSION) \
		or _matches_key(card, PIDGEOTTO) or _matches_key(card, PIDGEOT) or _matches_key(card, GABITE) \
		or _matches_key(card, GARCHOMP) or _matches_key(card, ROSERADE)
	)


func _tm_evolution_target_count(player: PlayerState) -> int:
	if player == null:
		return 0
	if _deck_id == ETHAN_TYPHLOSION_DECK_ID:
		var typhlosion_target_count := 0
		for slot: PokemonSlot in player.bench:
			if _matches_key(slot, CYNDAQUIL) or _matches_key(slot, PIDGEY):
				typhlosion_target_count += 1
		return mini(2, typhlosion_target_count)
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _deck_id == CYNTHIA_GARCHOMP_DECK_ID and (_matches_key(slot, GIBLE) or _matches_key(slot, ROSELIA)):
			count += 1
	return count


func _can_fund_tm_evolution_attack(target: PokemonSlot, player: PlayerState, game_state: GameState) -> bool:
	if target != null and not target.attached_energy.is_empty():
		return true
	if player == null or (game_state != null and game_state.energy_attached_this_turn):
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _tm_route_carrier(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	if _slot_has_tm_evolution(player.active_pokemon):
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if _slot_has_tm_evolution(slot):
			return slot
	return null


func _first_player_attack_locked(game_state: GameState, player: PlayerState) -> bool:
	return game_state != null \
		and player != null \
		and int(game_state.turn_number) == 1 \
		and int(game_state.first_player_index) == int(player.player_index)


func _slot_has_tm_evolution(slot: PokemonSlot) -> bool:
	return slot != null and _matches_key(slot.attached_tool, TM_EVOLUTION)


func _is_tm_evolution_attack(action: Dictionary) -> bool:
	var attack: Dictionary = action.get("granted_attack_data", {}) if action.get("granted_attack_data", {}) is Dictionary else {}
	var identity := "%s %s" % [str(attack.get("id", "")), str(attack.get("name", ""))]
	return identity.to_lower().contains("evolution") or identity.contains("进化")


func _attack_name(action: Dictionary) -> String:
	var direct := str(action.get("attack_name", ""))
	if direct != "":
		return direct
	var attack: Variant = action.get("attack_data", action.get("granted_attack_data", {}))
	return str((attack as Dictionary).get("name", "")) if attack is Dictionary else ""


func _is_recovery_card(item: Variant) -> bool:
	return _matches_key(item, SUPER_ROD) or _matches_key(item, "Super Rod") \
		or _matches_key(item, NIGHT_STRETCHER) or _matches_key(item, "Night Stretcher")


func _is_recovery_step(step_id: String) -> bool:
	return step_id in ["night_stretcher_choice", "cards_to_return"] \
		or step_id.contains("recover") or step_id.contains("stretcher") or step_id.contains("rod")


func _is_handoff_step(step_id: String) -> bool:
	return step_id.contains("switch") or step_id.contains("active") or step_id.contains("handoff") or step_id.contains("send")


func _is_cynthia_pokemon(item: Variant) -> bool:
	for identity: String in [GIBLE, GABITE, GARCHOMP, ROSELIA, ROSERADE, SPIRITOMB]:
		if _matches_key(item, identity):
			return true
	return false


func _energy_pays(item: Variant, symbol: String, target: PokemonSlot = null) -> bool:
	var data := _card_data_from_item(item)
	if data == null or not data.is_energy():
		return false
	if _matches_key(item, LEGACY_ENERGY):
		return true
	if _matches_key(item, LUMINOUS_ENERGY):
		return not _luminous_is_suppressed(item, target) or symbol == "C"
	var provides := str(data.energy_provides if data.energy_provides != "" else data.energy_type)
	return provides == "ANY" or symbol in provides


func _luminous_is_suppressed(item: Variant, target: PokemonSlot) -> bool:
	if target == null:
		return false
	for attached: CardInstance in target.attached_energy:
		if attached == item:
			continue
		if attached != null and attached.card_data != null and str(attached.card_data.card_type) == "Special Energy":
			return true
	return false


func _is_basic_energy(item: Variant, symbol: String) -> bool:
	var data := _card_data_from_item(item)
	return data != null and str(data.card_type) == "Basic Energy" and _energy_pays(item, symbol)


func _attached_energy(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func _count_basic_energy(cards: Array, symbol: String) -> int:
	var count := 0
	for card: Variant in cards:
		if _is_basic_energy(card, symbol):
			count += 1
	return count


func _count_zone(cards: Array, identity: String) -> int:
	var count := 0
	for card: Variant in cards:
		if _matches_key(card, identity):
			count += 1
	return count


func _zone_has(cards: Array, identity: String) -> bool:
	return _count_zone(cards, identity) > 0


func _has_slot(player: PlayerState, identity: String) -> bool:
	return _count_slots(player, identity) > 0


func _count_slots(player: PlayerState, identity: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, identity):
			count += 1
	return count


func _count_slots_with_energy(player: PlayerState, identity: String, minimum: int) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, identity) and _attached_energy(slot) >= minimum:
			count += 1
	return count


func _source_slot_for_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	if player == null or energy == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if energy in slot.attached_energy:
			return slot
	return null


func _valid_player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		return game_state.players[player_index]
	return null


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	var game_state: GameState = context.get("game_state", null)
	return _valid_player(game_state, int(context.get("player_index", -1)))


func _matches_key(item: Variant, key: String) -> bool:
	var aliases: Variant = IDENTITY_ALIASES.get(key, [])
	if aliases is Array:
		for alias: Variant in aliases:
			if super._matches_key(item, str(alias)):
				return true
	return super._matches_key(item, key)


func _first_profile_name(key: String) -> String:
	var values := _profile_list(key)
	return values[0] if not values.is_empty() else ""
