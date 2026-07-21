class_name DeckStrategyV18ControlGrass
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const CONTROL_DECK_ID := 800018359
const GRASS_DECK_ID := 800018500
const LOW_DECK_FLOOR := 6

const CONTROL_KEY_COPY_COUNTS := {
	"pidgeot": 2,
	"garganacl": 2,
	"pal_pad": 2,
	"turtonator": 1,
}
const CONTROL_KEY_EXCHANGE_WEIGHTS := {
	"pidgeot": 1.4,
	"garganacl": 1.2,
	"pal_pad": 0.7,
	"turtonator": 0.8,
}

const PIDGEY: Array[String] = ["Pidgey", "波波"]
const PIDGEOT_EX: Array[String] = ["Pidgeot ex", "大比鸟ex"]
const NACLI: Array[String] = ["Nacli", "盐石宝"]
const GARGANACL: Array[String] = ["Garganacl", "盐石巨灵"]
const FEEBAS: Array[String] = ["Feebas", "丑丑鱼"]
const MILOTIC: Array[String] = ["Milotic", "美纳斯"]
const TURTONATOR: Array[String] = ["Turtonator", "爆焰龟兽"]
const BUDEW: Array[String] = ["Budew", "含羞苞"]
const PAL_PAD: Array[String] = ["Pal Pad", "朋友手册"]
const SWITCHING_TICKET: Array[String] = ["Switching Ticket", "调换票"]
const COUNTER_CATCHER: Array[String] = ["Counter Catcher", "反击捕捉器"]
const ACCOMPANYING_FLUTE: Array[String] = ["Accompanying Flute", "配乐之笛"]
const RARE_CANDY: Array[String] = ["Rare Candy", "神奇糖果"]

const TOEDSCOOL: Array[String] = ["Toedscool", "原野水母"]
const TOEDSCRUEL_EX: Array[String] = ["Toedscruel ex", "陆地水母ex"]
const TOEDSCRUEL: Array[String] = ["Toedscruel", "陆地水母"]
const OGERPON: Array[String] = ["Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex"]
const IRON_LEAVES: Array[String] = ["Iron Leaves ex", "铁斑叶ex"]
const GRASS_ENERGY: Array[String] = ["Grass Energy", "基本草能量"]
const ENERGY_SWITCH: Array[String] = ["Energy Switch", "能量转移"]
const BUG_CATCHING_SET: Array[String] = ["Bug Catching Set", "捕虫套装"]
const SUPER_ROD: Array[String] = ["Super Rod", "厉害钓竿"]
const AREA_ZERO: Array[String] = ["Area Zero Underdepths", "零之大空洞"]

const CONTROL_PROFILE := {
	"strategy_id": "v18_control_delegate",
	"signatures": ["Pidgeot ex", "大比鸟ex", "Garganacl", "盐石巨灵"],
	"active_priority": ["Budew", "含羞苞", "Cleffa", "皮宝宝", "Pidgey", "波波", "Nacli", "盐石宝"],
	"bench_priority": ["Pidgey", "波波", "Nacli", "盐石宝", "Feebas", "丑丑鱼", "Genesect", "盖诺赛克特"],
	"energy_priority": ["Garganacl", "盐石巨灵", "Pidgeot ex", "大比鸟ex", "Turtonator", "爆焰龟兽", "Bloodmoon Ursaluna ex", "月月熊 赫月ex"],
	"evolution_priority": ["Pidgeot ex", "大比鸟ex", "Garganacl", "盐石巨灵", "Milotic", "美纳斯", "Pidgeotto", "比比鸟"],
	"search_priority": ["Pidgeot ex", "大比鸟ex", "Rare Candy", "神奇糖果", "Garganacl", "盐石巨灵", "Pal Pad", "朋友手册", "Counter Catcher", "反击捕捉器"],
	"ability_priority": ["Pidgeot ex", "大比鸟ex", "Garganacl", "盐石巨灵", "Milotic", "美纳斯"],
	"trainer_priority": ["Rare Candy", "神奇糖果", "Pal Pad", "朋友手册", "Counter Catcher", "反击捕捉器", "Team Star Grunt", "天星队手下", "Boss's Orders", "老大的指令"],
}

const GRASS_PROFILE := {
	"strategy_id": "v18_control_grass_delegate",
	"signatures": ["Toedscruel ex", "陆地水母ex", "Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex"],
	"active_priority": ["Toedscool", "原野水母", "Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex", "Mew ex", "梦幻ex"],
	"bench_priority": ["Toedscool", "原野水母", "Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex", "Iron Leaves ex", "铁斑叶ex"],
	"energy_priority": ["Toedscruel ex", "陆地水母ex", "Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex", "Iron Leaves ex", "铁斑叶ex"],
	"evolution_priority": ["Toedscruel ex", "陆地水母ex", "Toedscruel", "陆地水母"],
	"search_priority": ["Toedscruel ex", "陆地水母ex", "Toedscool", "原野水母", "Grass Energy", "基本草能量", "Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex"],
	"ability_priority": ["Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex", "Toedscruel ex", "陆地水母ex", "Toedscruel", "陆地水母"],
	"trainer_priority": ["Bug Catching Set", "捕虫套装", "Nest Ball", "巢穴球", "Energy Switch", "能量转移", "Super Rod", "厉害钓竿", "Area Zero Underdepths", "零之大空洞"],
}

var _deck_id := 0
var _profile_data: Dictionary = GRASS_PROFILE


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else 0
	_profile_data = CONTROL_PROFILE if _deck_id == CONTROL_DECK_ID else GRASS_PROFILE


func _profile() -> Dictionary:
	return _profile_data


func get_strategy_id() -> String:
	return "v18_control_grass_delegate_%d" % _deck_id


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var player := _player_from_state(game_state, player_index)
	if _is_control_deck():
		return _build_control_plan(game_state, player)
	return _build_grass_plan(game_state, player)


func _build_control_plan(game_state: GameState, player: PlayerState) -> Dictionary:
	var owner := "Garganacl"
	var bridge := "Pidgeot ex"
	var pivot := "Garganacl"
	var phase := "setup"
	var intent := "establish_control_engine"
	var ready := _best_control_attacker(player, game_state)
	if ready != null:
		owner = _primary_name(ready)
		pivot = owner
		phase = "convert"
		intent = "lock_and_sustain"
	elif _has_any_slot(player, PIDGEOT_EX):
		phase = "rebuild"
		intent = "rebuild_control_attacker"
	if player != null and player.deck.size() <= LOW_DECK_FLOOR:
		phase = "close"
		intent = "recycle_control_resources"
	var attach_priorities: Array[String] = []
	var fighting_owner := _control_fighting_owner(player)
	if fighting_owner != null:
		attach_priorities.append("Garganacl" if _matches_any(fighting_owner, GARGANACL) else "Nacli")
	for priority: String in [owner, "Garganacl", "Nacli", "Turtonator", "Pidgeot ex"]:
		if priority not in attach_priorities:
			attach_priorities.append(priority)
	return {
		"id": "v18_pidgeot_control_route",
		"intent": intent,
		"phase": phase,
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": bridge,
			"pivot_target_name": pivot,
		},
		"priorities": {
			"attach": attach_priorities,
			"handoff": [pivot, "Garganacl", "Turtonator", "Pidgeot ex"],
			"search": ["Pidgeot ex", "Rare Candy", "Pal Pad", "Counter Catcher", "Team Star Grunt"],
			"evolve": ["Pidgeot ex", "Garganacl", "Milotic"],
			"ability": ["Pidgeot ex", "Garganacl", "Milotic"],
			"trainer": ["Pal Pad", "Counter Catcher", "Team Star Grunt", "Boss's Orders"],
		},
		"flags": {
			"control_resource_reserve": true,
			"low_deck": player != null and player.deck.size() <= LOW_DECK_FLOOR,
			"quick_search_online": _has_any_slot(player, PIDGEOT_EX),
		},
		"constraints": {
			"forbid_engine_churn": player != null and player.deck.size() <= LOW_DECK_FLOOR,
			"forbid_extra_bench_padding": player != null and player.bench.size() >= 4,
		},
	}


func _build_grass_plan(game_state: GameState, player: PlayerState) -> Dictionary:
	var owner := "Toedscruel ex"
	var bridge := "Toedscruel ex"
	var pivot := "Toedscruel ex"
	var phase := "setup"
	var intent := "spread_grass_energy"
	var ready := _best_grass_attacker(player)
	if ready != null:
		owner = _primary_name(ready)
		pivot = owner
		phase = "convert"
		intent = "convert_colony_rush"
	elif _has_any_slot(player, TOEDSCRUEL_EX):
		phase = "launch"
		intent = "fund_colony_rush"
	elif player != null and int(game_state.turn_number) > 2:
		phase = "rebuild"
		intent = "rebuild_toedscruel_lane"
	if player != null and player.deck.size() <= LOW_DECK_FLOOR:
		phase = "close"
		intent = "attack_without_deck_churn"
	return {
		"id": "v18_toedscruel_ogerpon_route",
		"intent": intent,
		"phase": phase,
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": bridge,
			"pivot_target_name": pivot,
		},
		"priorities": {
			"attach": [owner, "Toedscruel ex", "Toedscool", "Teal Mask Ogerpon ex", "Iron Leaves ex"],
			"handoff": [pivot, "Toedscruel ex", "Iron Leaves ex", "Teal Mask Ogerpon ex"],
			"search": ["Toedscruel ex", "Toedscool", "Grass Energy", "Teal Mask Ogerpon ex", "Super Rod"],
			"evolve": ["Toedscruel ex", "Toedscruel"],
			"ability": ["Teal Mask Ogerpon ex"],
			"trainer": ["Bug Catching Set", "Energy Switch", "Super Rod", "Area Zero Underdepths"],
		},
		"flags": {
			"grass_spread_debt": _grass_spread_debt(player),
			"low_deck": player != null and player.deck.size() <= LOW_DECK_FLOOR,
			"forbid_deck_churn": player != null and player.deck.size() <= LOW_DECK_FLOOR and _active_can_attack(player),
		},
		"constraints": {
			"forbid_engine_churn": player != null and player.deck.size() <= LOW_DECK_FLOOR and _active_can_attack(player),
			"forbid_extra_bench_padding": player != null and player.bench.size() >= 6 and _grass_spread_debt(player) <= 0,
		},
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _player_from_state(game_state, player_index)
	if player == null:
		return {}
	if _is_control_deck():
		var engine_debt := 0 if _has_any_slot(player, PIDGEOT_EX) else 1
		var sustain_debt := 0 if _has_any_slot(player, GARGANACL) else 1
		var fighting_debt := _control_fighting_debt(player)
		var control_bonuses := _control_continuity_action_bonuses(
			game_state,
			player,
			engine_debt,
			sustain_debt,
			fighting_debt
		)
		var control_setup_live := engine_debt + sustain_debt + fighting_debt > 0 \
			and not control_bonuses.is_empty()
		return {
			"enabled": control_setup_live,
			"safe_setup_before_attack": control_setup_live,
			"setup_debt": {
				"missing_pidgeot_engine": engine_debt,
				"missing_sustain_lane": sustain_debt,
				"missing_salt_lane_fighting": fighting_debt,
			},
			"action_bonuses": control_bonuses,
			"attack_penalty": 520.0 if control_setup_live else 0.0,
		}
	var spread_debt := _grass_spread_debt(player)
	var lane_debt := 0 if _has_any_slot(player, TOEDSCRUEL_EX) else 1
	var grass_bonuses := _grass_continuity_action_bonuses(
		game_state,
		player,
		spread_debt,
		lane_debt
	)
	var grass_setup_live := spread_debt + lane_debt > 0 and not grass_bonuses.is_empty()
	return {
		"enabled": grass_setup_live,
		"safe_setup_before_attack": grass_setup_live,
		"setup_debt": {
			"missing_toedscruel_lane": lane_debt,
			"missing_energized_bench_bodies": spread_debt,
		},
		"action_bonuses": grass_bonuses,
		"attack_penalty": 620.0 if grass_setup_live else 0.0,
	}


func _score_continuity_action_bonus(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary
) -> float:
	if str(action.get("kind", "")) in ["attack", "granted_attack"] \
			and bool(action.get("projected_knockout", false)):
		return 0.0
	return super._score_continuity_action_bonus(action, game_state, player_index, turn_contract)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	var player := _player_from_state(game_state, player_index)
	if player == null:
		return score
	if _is_control_deck():
		return _score_control_action(action, game_state, player_index, score)
	return _score_grass_action(action, game_state, player_index, score)


func _score_control_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player: PlayerState = game_state.players[player_index]
	var score := base_score
	var kind := str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			var card: Variant = action.get("card", null)
			if _matches_any(card, PIDGEY):
				score = maxf(score, 3400.0 if not _has_any_slot(player, PIDGEY) and not _has_any_slot(player, PIDGEOT_EX) else 900.0)
			elif _matches_any(card, NACLI):
				score = maxf(score, 3000.0 if not _has_any_slot(player, NACLI) and not _has_any_slot(player, GARGANACL) else 760.0)
			elif _matches_any(card, FEEBAS):
				score = maxf(score, 1900.0 if not _has_any_slot(player, MILOTIC) else 420.0)
		"evolve":
			var evolution: Variant = action.get("card", null)
			if _matches_any(evolution, PIDGEOT_EX):
				score = maxf(score, 4700.0)
			elif _matches_any(evolution, GARGANACL):
				score = maxf(score, 4100.0)
			elif _matches_any(evolution, MILOTIC):
				score = maxf(score, 2700.0)
		"attach_energy":
			score = _score_control_attachment(action, game_state, player_index, score)
		"use_ability":
			var source: Variant = action.get("source_slot", null)
			if _matches_any(source, PIDGEOT_EX):
				if player.deck.size() <= 1 and _active_can_attack(player):
					return minf(score, -2400.0)
				score = maxf(score, 4300.0 if _control_setup_debt(player) > 0 else 3100.0)
		"play_trainer", "play_stadium":
			score = _score_control_trainer(action, game_state, player_index, score)
		"attack", "granted_attack":
			score = _score_control_attack(action, game_state, player_index, score)
		"retreat":
			var target: Variant = action.get("bench_target", null)
			score += score_handoff_target(target, {"id": "retreat"}, {
				"game_state": game_state,
				"player_index": player_index,
			}) * 0.35
		"end_turn":
			if _quick_search_available(player, game_state.turn_number) and player.deck.size() > 1:
				score -= 1700.0
	return score


func _score_control_trainer(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player: PlayerState = game_state.players[player_index]
	var card: Variant = action.get("card", null)
	if _matches_any(card, PAL_PAD):
		var supporter_count := _discard_supporter_count(player)
		if supporter_count <= 0:
			return minf(base_score, -2200.0)
		return maxf(base_score, 3000.0 + float(mini(2, supporter_count)) * 620.0 + (700.0 if player.deck.size() <= LOW_DECK_FLOOR else 0.0))
	if _matches_any(card, SWITCHING_TICKET):
		return _score_switching_ticket_exchange(player, base_score)
	if _matches_any(card, COUNTER_CATCHER):
		return maxf(base_score, 3500.0) if _is_behind_on_prizes(game_state, player_index) else minf(base_score, 250.0)
	if _matches_any(card, ACCOMPANYING_FLUTE):
		var opponent: PlayerState = game_state.players[1 - player_index]
		if opponent.bench.size() >= 5 or opponent.deck.size() <= 3:
			return minf(base_score, -900.0)
		return maxf(base_score, 2200.0 + float(3 - mini(3, opponent.bench.size())) * 260.0)
	if _matches_any(card, RARE_CANDY):
		return maxf(base_score, 4300.0) if _control_candy_route_live(player) else minf(base_score, -1200.0)
	if _matches_key(card, "Team Star Grunt") or _matches_key(card, "天星队手下"):
		return maxf(base_score, 3300.0) if _opponent_active_energy_count(game_state, player_index) > 0 else minf(base_score, 200.0)
	if player.deck.size() <= 2 and _is_draw_reset_card(card) and _active_can_attack(player):
		return minf(base_score, -2600.0)
	return base_score


func _score_control_attachment(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if energy == null or target == null:
		return base_score
	if _is_basic_fighting_energy(energy):
		var fighting_owner := _control_fighting_owner(game_state.players[player_index])
		if fighting_owner != null:
			if target == fighting_owner:
				return maxf(base_score, 3900.0 + float(_attached_energy_paying(target, "F")) * 420.0)
			if _matches_any(target, PIDGEOT_EX):
				return minf(base_score, 180.0)
	if _matches_any(target, TURTONATOR):
		if _energy_pays(energy, "R") and _opponent_active_is_energized_ex(game_state, player_index):
			return maxf(base_score, 3900.0)
		return minf(base_score, -700.0)
	if _matches_any(target, GARGANACL):
		var fighting := _attached_energy_paying(target, "F")
		if fighting < 2 and _energy_pays(energy, "F"):
			return maxf(base_score, 3500.0 + float(fighting) * 420.0)
		return minf(base_score, 300.0)
	if _matches_any(target, PIDGEOT_EX):
		return maxf(base_score, 2100.0) if target.attached_energy.size() < 2 else minf(base_score, 260.0)
	if _matches_key(target, "Bloodmoon Ursaluna ex") or _matches_key(target, "月月熊 赫月ex"):
		return maxf(base_score, 1900.0) if game_state.players[player_index].prizes.size() <= 3 else minf(base_score, 350.0)
	return minf(base_score, 120.0)


func _score_control_attack(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player: PlayerState = game_state.players[player_index]
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	var attack_index := int(action.get("attack_index", 0))
	if _matches_any(source, TURTONATOR) and attack_index == 0:
		return maxf(base_score, 4200.0) if _opponent_active_is_energized_ex(game_state, player_index) else minf(base_score, -850.0)
	if _matches_any(source, GARGANACL):
		var opponent: PlayerState = game_state.players[1 - player_index]
		return maxf(base_score, 2900.0 + float(maxi(0, 8 - opponent.deck.size())) * 180.0)
	if _matches_any(source, BUDEW):
		return maxf(base_score, 2300.0 if int(game_state.turn_number) <= 4 else 1350.0)
	if _matches_any(source, NACLI):
		return maxf(base_score, 1750.0)
	return base_score


func _score_grass_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player: PlayerState = game_state.players[player_index]
	var score := base_score
	var kind := str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			var card: Variant = action.get("card", null)
			if _matches_any(card, TOEDSCOOL):
				var lane_count := _count_any_slots(player, TOEDSCOOL) + _count_any_slots(player, TOEDSCRUEL_EX) + _count_any_slots(player, TOEDSCRUEL)
				score = maxf(score, 3900.0 if lane_count == 0 else (2700.0 if lane_count == 1 else 420.0))
			elif _matches_any(card, OGERPON):
				var ogerpon_count := _count_any_slots(player, OGERPON)
				score = maxf(score, 3600.0 if ogerpon_count == 0 else (2400.0 if ogerpon_count < 2 else 650.0))
			elif _matches_any(card, IRON_LEAVES):
				score = maxf(score, 1900.0 if _field_grass_energy(player) >= 3 else 500.0)
		"evolve":
			var evolution: Variant = action.get("card", null)
			if _matches_any(evolution, TOEDSCRUEL_EX):
				score = maxf(score, 4500.0)
			elif _matches_any(evolution, TOEDSCRUEL):
				score = maxf(score, 2350.0 if not _has_any_slot(player, TOEDSCRUEL) else 450.0)
		"attach_energy":
			score = _score_grass_attachment(action, game_state, player_index, score)
		"use_ability":
			var source: Variant = action.get("source_slot", null)
			if _matches_any(source, OGERPON):
				if not _hand_has_grass_energy(player):
					return minf(score, -2200.0)
				if player.deck.size() <= 2:
					return minf(score, -2800.0)
				if player.deck.size() <= LOW_DECK_FLOOR and _active_can_attack(player):
					return minf(score, -1900.0)
				score = maxf(score, 4700.0 if _grass_spread_debt(player) > 0 else 3300.0)
		"play_trainer", "play_stadium":
			score = _score_grass_trainer(action, game_state, player_index, score)
		"attack", "granted_attack":
			score = _score_grass_attack(action, game_state, player_index, score)
		"retreat":
			var target: Variant = action.get("bench_target", null)
			score += score_handoff_target(target, {"id": "retreat"}, {
				"game_state": game_state,
				"player_index": player_index,
			}) * 0.30
		"end_turn":
			if _teal_dance_available(player, game_state.turn_number) and player.deck.size() > LOW_DECK_FLOOR:
				score -= 2200.0
			if _grass_setup_action_available(player, game_state.turn_number):
				score -= 1500.0
	return score


func _score_grass_trainer(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player: PlayerState = game_state.players[player_index]
	var card: Variant = action.get("card", null)
	if _matches_any(card, BUG_CATCHING_SET):
		if player.deck.size() <= LOW_DECK_FLOOR and _active_can_attack(player):
			return minf(base_score, -1900.0)
		return maxf(base_score, 3100.0 + float(_grass_setup_debt(player)) * 420.0)
	if _matches_any(card, SUPER_ROD):
		var recoverable := _recoverable_grass_count(player)
		if recoverable <= 0:
			return minf(base_score, -2200.0)
		if player.deck.size() <= LOW_DECK_FLOOR:
			return maxf(base_score, 4700.0 + float(mini(3, recoverable)) * 280.0)
		return maxf(base_score, 2600.0) if _missing_grass_rebuild_piece(player) else minf(base_score, 300.0)
	if _matches_any(card, ENERGY_SWITCH):
		var gain := _selected_or_best_grass_transfer_gain(action, player)
		return maxf(base_score, 2800.0 + gain) if gain > 0.0 else minf(base_score, -2100.0)
	if _matches_any(card, AREA_ZERO):
		return maxf(base_score, 3200.0) if _has_any_slot(player, OGERPON) and player.bench.size() >= 4 else minf(base_score, 500.0)
	if player.deck.size() <= LOW_DECK_FLOOR and _active_can_attack(player) and _is_draw_reset_card(card):
		return minf(base_score, -2800.0)
	return base_score


func _score_grass_attachment(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player: PlayerState = game_state.players[player_index]
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if energy == null or target == null or not _energy_pays(energy, "G"):
		return minf(base_score, -900.0)
	var attached_grass := _attached_energy_paying(target, "G")
	if _matches_any(target, TOEDSCRUEL_EX):
		if attached_grass < 2:
			return maxf(base_score, 3900.0 + float(attached_grass) * 650.0)
		return minf(base_score, -650.0) if _grass_spread_debt(player) > 0 else maxf(base_score, 700.0)
	if _matches_any(target, IRON_LEAVES):
		if target == player.active_pokemon and attached_grass < 3:
			return maxf(base_score, 3600.0 + float(attached_grass) * 300.0)
		return minf(base_score, 500.0)
	if target in player.bench and attached_grass == 0 and _has_ready_toedscruel(player):
		return maxf(base_score, 3000.0)
	if _matches_any(target, OGERPON):
		if attached_grass == 0 and _teal_dance_available(player, game_state.turn_number, target):
			return minf(base_score, -650.0)
		if _grass_spread_debt(player) > 0 and attached_grass > 0:
			return minf(base_score, -700.0)
		return maxf(base_score, 2050.0 if attached_grass < 3 else 300.0)
	if target in player.bench and attached_grass == 0:
		return maxf(base_score, 2200.0)
	return minf(base_score, 250.0)


func _score_grass_attack(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player: PlayerState = game_state.players[player_index]
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	if _matches_any(source, TOEDSCRUEL_EX):
		var energized_bench := _energized_grass_bench_count(player)
		var score := maxf(base_score, 2300.0 + float(energized_bench) * 620.0)
		if energized_bench < 2 and _grass_setup_action_available(player, game_state.turn_number) and not bool(action.get("projected_knockout", false)):
			score -= 2100.0
		return score
	if _matches_any(source, IRON_LEAVES):
		return maxf(base_score, 3200.0)
	if _matches_any(source, OGERPON):
		return maxf(base_score, 2500.0 + float(int(action.get("projected_damage", 0))) * 1.3)
	return base_score


func get_discard_priority(card: CardInstance) -> int:
	if _is_control_deck():
		if _matches_any(card, PAL_PAD):
			return 2
		if _matches_any(card, SWITCHING_TICKET):
			return 3
		if _matches_any(card, PIDGEOT_EX) or _matches_any(card, GARGANACL) or _matches_any(card, RARE_CANDY):
			return 5
		if _matches_any(card, COUNTER_CATCHER) or _is_control_supporter(card):
			return 9
		if _matches_any(card, TURTONATOR) or _matches_any(card, MILOTIC):
			return 18
		return super.get_discard_priority(card)
	if _matches_any(card, TOEDSCRUEL_EX) or _matches_any(card, SUPER_ROD):
		return 4
	if _matches_any(card, TOEDSCOOL) or _matches_any(card, ENERGY_SWITCH):
		return 8
	if _matches_any(card, OGERPON):
		return 12
	if _matches_any(card, GRASS_ENERGY):
		return 18
	return super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player := _player_from_state(game_state, player_index)
	if player == null:
		return get_discard_priority(card)
	if _is_control_deck():
		if _matches_any(card, PAL_PAD) and _discard_supporter_count(player) > 0:
			return 1
		if _matches_any(card, SWITCHING_TICKET) and _control_ticket_exchange_value(player) >= 1.0:
			return 1
	else:
		if _matches_any(card, SUPER_ROD) and (player.deck.size() <= LOW_DECK_FLOOR or _missing_grass_rebuild_piece(player)):
			return 1
		if _matches_any(card, GRASS_ENERGY) and _hand_grass_energy_count(player) <= 2:
			return 5
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if _is_control_deck():
		if _matches_any(card, PIDGEOT_EX):
			return 1200
		if _matches_any(card, RARE_CANDY):
			return 1150
		if _matches_any(card, GARGANACL):
			return 1050
		if _matches_any(card, PAL_PAD):
			return 1000
		if _matches_any(card, COUNTER_CATCHER) or _matches_any(card, SWITCHING_TICKET):
			return 900
		return super.get_search_priority(card)
	if _matches_any(card, TOEDSCRUEL_EX):
		return 1200
	if _matches_any(card, TOEDSCOOL):
		return 1120
	if _matches_any(card, GRASS_ENERGY):
		return 1040
	if _matches_any(card, OGERPON):
		return 980
	if _matches_any(card, SUPER_ROD) or _matches_any(card, ENERGY_SWITCH):
		return 860
	return super.get_search_priority(card)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	if step_id in ["bug_catching_set_cards", "cards_to_return", "supporters_to_return"]:
		return _pick_ranked_items(items, step, context, int(step.get("max_select", 1)))
	if step_id == "iron_leaves_energy_to_move":
		return _pick_iron_leaves_energy(items, step, context)
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if _is_control_deck():
		if item is CardInstance and step_id == "search_cards":
			return _control_search_score(item as CardInstance, player, context)
		if item is CardInstance and step_id == "supporters_to_return":
			return _control_supporter_recovery_score(item as CardInstance, context)
		if item is CardInstance and step_id.contains("discard"):
			return float(get_discard_priority_contextual(item as CardInstance, context.get("game_state", null), int(context.get("player_index", -1))))
	else:
		if item is CardInstance and step_id in ["bug_catching_set_cards", "search_cards", "search_pokemon"]:
			return _grass_search_score(item as CardInstance, player)
		if item is CardInstance and step_id == "cards_to_return":
			return _grass_recovery_score(item as CardInstance, player)
		if step_id == "energy_assignment":
			var transfer_score: Variant = _grass_energy_assignment_score(item, context)
			if transfer_score != null:
				return float(transfer_score)
		if item is CardInstance and step_id == "iron_leaves_energy_to_move":
			return _iron_leaves_energy_source_score(item as CardInstance, player)
		if item is CardInstance and step_id == "basic_energy_from_hand" and _matches_any(item, GRASS_ENERGY):
			return 4200.0
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not item is PokemonSlot:
		return super.score_handoff_target(item, step, context)
	var slot := item as PokemonSlot
	var player := _player_from_context(context)
	if _is_control_deck():
		if _matches_any(slot, GARGANACL) and _slot_can_attack(slot):
			return 4400.0
		if _matches_any(slot, TURTONATOR) and _slot_can_attack(slot):
			return 4100.0
		if _matches_any(slot, PIDGEOT_EX):
			return 2600.0 if _slot_can_attack(slot) else 500.0
		if _matches_any(slot, BUDEW):
			return 1300.0
	else:
		if _matches_any(slot, TOEDSCRUEL_EX) and _slot_can_attack(slot):
			return 4800.0 + float(_energized_grass_bench_count(player)) * 180.0
		if _matches_any(slot, IRON_LEAVES) and _slot_can_attack(slot):
			return 4200.0
		if _matches_any(slot, OGERPON) and _slot_can_attack(slot):
			return 3000.0
	return super.score_handoff_target(item, step, context)


func evaluate_board(game_state: GameState, player_index: int) -> float:
	var score := super.evaluate_board(game_state, player_index)
	var player := _player_from_state(game_state, player_index)
	if player == null:
		return score
	if _is_control_deck():
		score += 1050.0 if _has_any_slot(player, PIDGEOT_EX) else 0.0
		score += 720.0 if _has_any_slot(player, GARGANACL) else 0.0
		score += 420.0 if _has_any_slot(player, MILOTIC) else 0.0
	else:
		score += 980.0 if _has_any_slot(player, TOEDSCRUEL_EX) else 0.0
		score += float(_energized_grass_bench_count(player)) * 430.0
		score += float(_count_any_slots(player, OGERPON)) * 260.0
	return score


func _control_search_score(card: CardInstance, player: PlayerState, context: Dictionary) -> float:
	if player == null:
		return float(get_search_priority(card))
	var rare_candy_in_hand := _first_hand_match(player, RARE_CANDY) != null
	var garganacl_in_hand := _first_hand_match(player, GARGANACL) != null
	if _is_basic_fighting_energy(card) and _control_garganacl_one_fighting_short(player):
		return 5400.0
	if _control_redundant_stage_two_without_basic_route(card, player):
		return 180.0
	if _matches_any(card, PIDGEOT_EX) and not _has_any_slot(player, PIDGEOT_EX) and _has_any_slot(player, PIDGEY):
		return 5200.0
	if _matches_any(card, RARE_CANDY) and _control_candy_route_live(player) and not rare_candy_in_hand:
		if _has_any_slot(player, NACLI) and not _has_any_slot(player, GARGANACL) and garganacl_in_hand:
			return 5300.0
		return 4900.0
	if _matches_any(card, GARGANACL) and _has_any_slot(player, NACLI) and not _has_any_slot(player, GARGANACL):
		return 5300.0 if rare_candy_in_hand else 4500.0
	if _matches_any(card, PAL_PAD) and _discard_supporter_count(player) > 0:
		return 4300.0 + float(mini(2, _discard_supporter_count(player))) * 240.0
	if _matches_any(card, SWITCHING_TICKET):
		var exchange_value := _control_ticket_exchange_value(player)
		if exchange_value >= 0.8:
			return 3200.0 + exchange_value * 300.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and _matches_any(card, COUNTER_CATCHER) and _is_behind_on_prizes(game_state, player_index):
		return 3800.0
	if game_state != null and (_matches_key(card, "Team Star Grunt") or _matches_key(card, "天星队手下")) and _opponent_active_energy_count(game_state, player_index) > 0:
		return 3600.0
	if player.deck.size() <= 2 and _is_draw_reset_card(card):
		return -1800.0
	return float(get_search_priority(card))


func _control_supporter_recovery_score(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _matches_key(card, "Team Star Grunt") or _matches_key(card, "天星队手下"):
		return 4400.0 if game_state != null and _opponent_active_energy_count(game_state, player_index) > 0 else 2500.0
	if _matches_key(card, "Boss's Orders") or _matches_key(card, "老大的指令"):
		return 3900.0
	if _matches_key(card, "Xerosic's Machinations") or _matches_key(card, "库瑟洛斯奇的企图"):
		return 3600.0
	if _matches_key(card, "Brock's Scouting") or _matches_key(card, "小刚的发掘"):
		return 3300.0
	if _matches_key(card, "Lana's Aid") or _matches_key(card, "水莲的照顾"):
		return 3100.0
	return 1600.0 + float(get_search_priority(card))


func _grass_search_score(card: CardInstance, player: PlayerState) -> float:
	if player == null:
		return float(get_search_priority(card))
	if _matches_any(card, TOEDSCRUEL_EX):
		return 4900.0 if _has_any_slot(player, TOEDSCOOL) and not _has_any_slot(player, TOEDSCRUEL_EX) else 1800.0
	if _matches_any(card, TOEDSCOOL):
		var lanes := _count_any_slots(player, TOEDSCOOL) + _count_any_slots(player, TOEDSCRUEL_EX) + _count_any_slots(player, TOEDSCRUEL)
		return 4600.0 if lanes == 0 else (3200.0 if lanes == 1 else 700.0)
	if _is_basic_grass_energy(card):
		return 4100.0 if _hand_grass_energy_count(player) <= 1 else 2500.0
	if _matches_any(card, OGERPON):
		var count := _count_any_slots(player, OGERPON)
		return 3900.0 if count == 0 else (2800.0 if count == 1 else 650.0)
	if _matches_any(card, TOEDSCRUEL):
		return 2600.0 if not _has_any_slot(player, TOEDSCRUEL) and _has_any_slot(player, TOEDSCOOL) else 400.0
	if _matches_any(card, IRON_LEAVES):
		return 2300.0 if _field_grass_energy(player) >= 3 else 800.0
	return float(get_search_priority(card))


func _grass_recovery_score(card: CardInstance, player: PlayerState) -> float:
	var low_deck := player != null and player.deck.size() <= LOW_DECK_FLOOR
	if _matches_any(card, TOEDSCRUEL_EX):
		return 5000.0 if player != null and not _has_any_slot(player, TOEDSCRUEL_EX) else (3600.0 if low_deck else 1900.0)
	if _matches_any(card, TOEDSCOOL):
		return 4500.0 if player != null and _missing_grass_rebuild_piece(player) else (3300.0 if low_deck else 1700.0)
	if _is_basic_grass_energy(card):
		return 4300.0 if low_deck else 3000.0
	if _matches_any(card, OGERPON):
		return 3500.0 if player != null and _count_any_slots(player, OGERPON) == 0 else 1500.0
	return 500.0


func _grass_energy_assignment_score(item: Variant, context: Dictionary) -> Variant:
	var player := _player_from_context(context)
	if player == null:
		return null
	if item is CardInstance:
		var energy := item as CardInstance
		var source := _slot_holding_energy(player, energy)
		if source == null:
			return null
		var best := -INF
		for target: PokemonSlot in _all_slots(player):
			if target != source:
				best = maxf(best, _grass_transfer_gain(source, target, energy, player))
		return best
	if item is PokemonSlot:
		var selected: Variant = context.get("assignment_source", context.get("source_card", null))
		if selected is CardInstance:
			var source := _slot_holding_energy(player, selected as CardInstance)
			return _grass_transfer_gain(source, item as PokemonSlot, selected as CardInstance, player) if source != null else null
		var best := -INF
		for source_slot: PokemonSlot in _all_slots(player):
			if source_slot == item:
				continue
			for energy: CardInstance in source_slot.attached_energy:
				best = maxf(best, _grass_transfer_gain(source_slot, item as PokemonSlot, energy, player))
		return best
	return null


func _selected_or_best_grass_transfer_gain(action: Dictionary, player: PlayerState) -> float:
	var raw_targets: Variant = action.get("targets", [])
	if raw_targets is Array:
		for raw_group: Variant in raw_targets:
			if not raw_group is Dictionary:
				continue
			var assignments: Variant = (raw_group as Dictionary).get("energy_assignment", [])
			if not assignments is Array:
				continue
			for raw_assignment: Variant in assignments:
				if not raw_assignment is Dictionary:
					continue
				var energy: Variant = (raw_assignment as Dictionary).get("source", null)
				var target: Variant = (raw_assignment as Dictionary).get("target", null)
				if energy is CardInstance and target is PokemonSlot:
					var source := _slot_holding_energy(player, energy as CardInstance)
					if source != null:
						return _grass_transfer_gain(source, target as PokemonSlot, energy as CardInstance, player)
	var best := -INF
	for source: PokemonSlot in _all_slots(player):
		for energy: CardInstance in source.attached_energy:
			for target: PokemonSlot in _all_slots(player):
				if target != source:
					best = maxf(best, _grass_transfer_gain(source, target, energy, player))
	return best


func _grass_transfer_gain(
	source: PokemonSlot,
	target: PokemonSlot,
	energy: CardInstance,
	player: PlayerState
) -> float:
	if source == null or target == null or source == target or energy == null or not _energy_pays(energy, "G"):
		return -3000.0
	var gain := 0.0
	var source_grass := _attached_energy_paying(source, "G")
	var target_grass := _attached_energy_paying(target, "G")
	if _matches_any(target, TOEDSCRUEL_EX) and target_grass < 2:
		gain += 3100.0 if target_grass == 1 else 1900.0
	elif _matches_any(target, IRON_LEAVES) and target == player.active_pokemon and target_grass < 3:
		gain += 2300.0
	elif _matches_any(target, OGERPON) and target_grass < 3:
		gain += 950.0
	elif target in player.bench and target_grass == 0:
		gain += 1350.0
	else:
		gain -= 650.0
	if _matches_any(source, TOEDSCRUEL_EX) and source_grass <= 2:
		gain -= 3500.0
	if _slot_can_attack(source) and not _slot_can_attack_with_removed_energy(source, energy):
		gain -= 3300.0
	if source in player.bench and source_grass == 1:
		gain -= 2600.0
	elif source_grass > 1:
		gain += 450.0
	return gain


func _pick_ranked_items(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	requested_max: int
) -> Array:
	var max_select := maxi(1, requested_max)
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		ranked.append({
			"item": item,
			"score": score_interaction_target(item, step, context),
			"index": index,
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", -INF))
		var right_score := float(right.get("score", -INF))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var selected: Array = []
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		if float(entry.get("score", -INF)) <= 0.0:
			continue
		selected.append(entry.get("item"))
	return selected


func _pick_iron_leaves_energy(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var player := _player_from_context(context)
	var source_slot: PokemonSlot = context.get("source_slot", context.get("ability_source", null))
	var needed := maxi(0, 3 - _attached_energy_paying(source_slot, "G"))
	if needed <= 0:
		return []
	var ranked := _pick_ranked_items(items, step, context, mini(needed, items.size()))
	return ranked


func _iron_leaves_energy_source_score(energy: CardInstance, player: PlayerState) -> float:
	if player == null or energy == null:
		return -2000.0
	var source := _slot_holding_energy(player, energy)
	if source == null:
		return -2000.0
	var grass_count := _attached_energy_paying(source, "G")
	if _matches_any(source, TOEDSCRUEL_EX) and grass_count <= 2:
		return -2800.0
	if source in player.bench and grass_count <= 1:
		return -1700.0
	return 2600.0 + float(grass_count) * 180.0


func _control_continuity_action_bonuses(
	game_state: GameState,
	player: PlayerState,
	engine_debt: int,
	sustain_debt: int,
	fighting_debt: int
) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if player == null or engine_debt + sustain_debt + fighting_debt <= 0:
		return bonuses
	var structural_debt := engine_debt + sustain_debt
	var bench_open := player.bench.size() < _continuity_bench_limit(game_state, player)
	if bench_open and engine_debt > 0:
		_append_basic_continuity_bonus(bonuses, _first_hand_match(player, PIDGEY), 440.0)
	if bench_open and sustain_debt > 0:
		_append_basic_continuity_bonus(bonuses, _first_hand_match(player, NACLI), 400.0)
	var engine_evolution := _first_executable_evolution(player, PIDGEOT_EX, int(game_state.turn_number))
	if engine_debt > 0 and engine_evolution != null:
		bonuses.append({
			"kind": "evolve",
			"card_names": [_primary_name(engine_evolution)],
			"bonus": 520.0,
		})
	var sustain_evolution := _first_executable_evolution(player, GARGANACL, int(game_state.turn_number))
	if sustain_debt > 0 and sustain_evolution != null:
		bonuses.append({
			"kind": "evolve",
			"card_names": [_primary_name(sustain_evolution)],
			"bonus": 500.0,
		})
	if _control_rare_candy_action_live(player, game_state.turn_number, engine_debt, sustain_debt):
		var rare_candy := _first_hand_match(player, RARE_CANDY)
		bonuses.append({
			"kind": "play_trainer",
			"card_names": [_primary_name(rare_candy)],
			"bonus": 480.0,
		})
	if structural_debt > 0 and player.deck.size() > 0 \
			and _quick_search_available(player, game_state.turn_number):
		var pidgeot := _first_matching_slot(player, PIDGEOT_EX)
		bonuses.append({
			"kind": "use_ability",
			"target_names": [_primary_name(pidgeot)],
			"bonus": 380.0,
		})
	var pal_pad := _first_hand_match(player, PAL_PAD)
	if structural_debt > 0 and pal_pad != null and _discard_supporter_count(player) > 0:
		bonuses.append({
			"kind": "play_trainer",
			"card_names": [_primary_name(pal_pad)],
			"bonus": 260.0,
		})
	if fighting_debt > 0 and not game_state.energy_attached_this_turn:
		var fighting_energy := _first_hand_basic_fighting_energy(player)
		var fighting_owner := _control_fighting_owner(player)
		if fighting_energy != null and fighting_owner != null:
			bonuses.append({
				"kind": "attach_energy",
				"card_names": [_primary_name(fighting_energy)],
				"target_names": [_primary_name(fighting_owner)],
				"bonus": 620.0,
			})
	return bonuses


func _grass_continuity_action_bonuses(
	game_state: GameState,
	player: PlayerState,
	spread_debt: int,
	lane_debt: int
) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if player == null or spread_debt + lane_debt <= 0:
		return bonuses
	if player.bench.size() < _continuity_bench_limit(game_state, player):
		if lane_debt > 0:
			_append_basic_continuity_bonus(bonuses, _first_hand_match(player, TOEDSCOOL), 360.0)
		if spread_debt > 0:
			_append_basic_continuity_bonus(bonuses, _first_hand_match(player, OGERPON), 340.0)
	var evolution := _first_executable_evolution(player, TOEDSCRUEL_EX, int(game_state.turn_number))
	if lane_debt > 0 and evolution != null:
		bonuses.append({
			"kind": "evolve",
			"card_names": [_primary_name(evolution)],
			"bonus": 440.0,
		})
	if spread_debt > 0 and player.deck.size() > 0 \
			and _teal_dance_available(player, game_state.turn_number):
		var ogerpon := _first_unused_ogerpon(player, game_state.turn_number)
		bonuses.append({
			"kind": "use_ability",
			"target_names": [_primary_name(ogerpon)],
			"bonus": 320.0,
		})
	if spread_debt > 0 and not game_state.energy_attached_this_turn and _hand_has_grass_energy(player):
		var target := _first_unenergized_grass_bench(player)
		var grass_energy := _first_hand_grass_energy(player)
		if target != null and grass_energy != null:
			bonuses.append({
				"kind": "attach_energy",
				"card_names": [_primary_name(grass_energy)],
				"target_names": [_primary_name(target)],
				"bonus": 260.0,
			})
	return bonuses


func _append_basic_continuity_bonus(
	bonuses: Array[Dictionary],
	card: CardInstance,
	bonus: float
) -> void:
	if card == null or not card.is_basic_pokemon():
		return
	bonuses.append({
		"kind": "play_basic_to_bench",
		"card_names": [_primary_name(card)],
		"bonus": bonus,
	})


func _first_hand_match(player: PlayerState, names: Array[String]) -> CardInstance:
	if player == null:
		return null
	for card: CardInstance in player.hand:
		if _matches_any(card, names):
			return card
	return null


func _first_hand_grass_energy(player: PlayerState) -> CardInstance:
	if player == null:
		return null
	for card: CardInstance in player.hand:
		if _matches_any(card, GRASS_ENERGY) or _energy_pays(card, "G"):
			return card
	return null


func _first_hand_basic_fighting_energy(player: PlayerState) -> CardInstance:
	if player == null:
		return null
	for card: CardInstance in player.hand:
		if _is_basic_fighting_energy(card):
			return card
	return null


func _first_matching_slot(player: PlayerState, names: Array[String]) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, names):
			return slot
	return null


func _first_executable_evolution(
	player: PlayerState,
	evolution_names: Array[String],
	turn_number: int
) -> CardInstance:
	var evolution := _first_hand_match(player, evolution_names)
	if evolution == null or evolution.card_data == null:
		return null
	var evolves_from := str(evolution.card_data.evolves_from)
	if evolves_from == "":
		return null
	for slot: PokemonSlot in _all_slots(player):
		if slot.turn_played >= turn_number or slot.turn_evolved == turn_number:
			continue
		if _matches_key(slot, evolves_from):
			return evolution
	return null


func _control_rare_candy_action_live(
	player: PlayerState,
	turn_number: int,
	engine_debt: int,
	sustain_debt: int
) -> bool:
	if _first_hand_match(player, RARE_CANDY) == null:
		return false
	var has_engine_stage_two := engine_debt > 0 and _first_hand_match(player, PIDGEOT_EX) != null
	var has_sustain_stage_two := sustain_debt > 0 and _first_hand_match(player, GARGANACL) != null
	for slot: PokemonSlot in _all_slots(player):
		if slot.turn_played >= turn_number or slot.turn_evolved == turn_number:
			continue
		if has_engine_stage_two and _matches_any(slot, PIDGEY):
			return true
		if has_sustain_stage_two and _matches_any(slot, NACLI):
			return true
	return false


func _first_unused_ogerpon(player: PlayerState, turn_number: int) -> PokemonSlot:
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_any(slot, OGERPON):
			continue
		var used := false
		for effect: Dictionary in slot.effects:
			if str(effect.get("type", "")) == "ability_attach_basic_energy_from_hand_draw_used" \
					and int(effect.get("turn", -1)) == turn_number:
				used = true
				break
		if not used:
			return slot
	return null


func _first_unenergized_grass_bench(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in player.bench:
		if _attached_energy_paying(slot, "G") == 0:
			return slot
	return null


func _continuity_bench_limit(game_state: GameState, player: PlayerState) -> int:
	if game_state == null or not _matches_any(game_state.stadium_card, AREA_ZERO):
		return 5
	for slot: PokemonSlot in _all_slots(player):
		var data := slot.get_card_data()
		if data != null and data.is_tera_pokemon():
			return 8
	return 5


func _best_control_attacker(player: PlayerState, game_state: GameState) -> PokemonSlot:
	if player == null:
		return null
	for names: Array[String] in [GARGANACL, TURTONATOR, PIDGEOT_EX]:
		for slot: PokemonSlot in _all_slots(player):
			if _matches_any(slot, names) and _slot_can_attack(slot):
				if names != TURTONATOR or _opponent_active_is_energized_ex(game_state, player.player_index):
					return slot
	if player.active_pokemon != null and _slot_can_attack(player.active_pokemon):
		return player.active_pokemon
	return null


func _best_grass_attacker(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for names: Array[String] in [TOEDSCRUEL_EX, IRON_LEAVES, OGERPON]:
		for slot: PokemonSlot in _all_slots(player):
			if _matches_any(slot, names) and _slot_can_attack(slot):
				return slot
	if player.active_pokemon != null and _slot_can_attack(player.active_pokemon):
		return player.active_pokemon
	return null


func _control_setup_debt(player: PlayerState) -> int:
	if player == null:
		return 2
	var debt := 0
	if not _has_any_slot(player, PIDGEOT_EX):
		debt += 1
	if not _has_any_slot(player, GARGANACL):
		debt += 1
	return debt


func _control_fighting_owner(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_garganacl: PokemonSlot = null
	var best_garganacl_energy := -1
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_any(slot, GARGANACL):
			continue
		var garganacl_fighting := _attached_energy_paying(slot, "F")
		if garganacl_fighting >= 2:
			return null
		if garganacl_fighting > best_garganacl_energy:
			best_garganacl = slot
			best_garganacl_energy = garganacl_fighting
	if best_garganacl != null:
		return best_garganacl
	var best_nacli: PokemonSlot = null
	var best_nacli_energy := -1
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_any(slot, NACLI):
			continue
		var nacli_fighting := _attached_energy_paying(slot, "F")
		if nacli_fighting >= 2:
			return null
		if nacli_fighting > best_nacli_energy:
			best_nacli = slot
			best_nacli_energy = nacli_fighting
	return best_nacli


func _control_fighting_debt(player: PlayerState) -> int:
	var owner := _control_fighting_owner(player)
	if owner == null:
		return 0
	return maxi(0, 2 - _attached_energy_paying(owner, "F"))


func _grass_setup_debt(player: PlayerState) -> int:
	if player == null:
		return 4
	var debt := 0
	if not _has_any_slot(player, TOEDSCRUEL_EX):
		debt += 1
	debt += maxi(0, 2 - (_count_any_slots(player, TOEDSCOOL) + _count_any_slots(player, TOEDSCRUEL_EX) + _count_any_slots(player, TOEDSCRUEL)))
	debt += maxi(0, 2 - _count_any_slots(player, OGERPON))
	return debt


func _grass_spread_debt(player: PlayerState) -> int:
	if player == null:
		return 3
	return maxi(0, 3 - _energized_grass_bench_count(player))


func _grass_setup_action_available(player: PlayerState, turn_number: int) -> bool:
	if player == null or _grass_spread_debt(player) <= 0:
		return false
	if _hand_has_grass_energy(player):
		return true
	return _teal_dance_available(player, turn_number)


func _has_ready_toedscruel(player: PlayerState) -> bool:
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, TOEDSCRUEL_EX) and _slot_can_attack(slot):
			return true
	return false


func _active_can_attack(player: PlayerState) -> bool:
	return player != null and player.active_pokemon != null and _slot_can_attack(player.active_pokemon)


func _slot_can_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if _attack_gap(slot, str(attack.get("cost", ""))) <= 0:
			return true
	return false


func _slot_can_attack_with_removed_energy(slot: PokemonSlot, removed: CardInstance) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if _attack_gap(slot, str(attack.get("cost", "")), removed) <= 0:
			return true
	return false


func _attack_gap(slot: PokemonSlot, raw_cost: String, excluded: CardInstance = null) -> int:
	var cost := CardData.normalize_attack_cost(raw_cost)
	var required: Dictionary = {}
	for symbol: String in cost:
		if symbol != "C":
			required[symbol] = int(required.get(symbol, 0)) + 1
	var provided: Dictionary = {}
	var any_units := 0
	var total_units := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == excluded or energy == null or energy.card_data == null:
			continue
		var provision := str(energy.card_data.energy_provides)
		if provision == "":
			provision = str(energy.card_data.energy_type)
		if provision == "ANY":
			any_units += 1
			total_units += 1
			continue
		for symbol: String in provision:
			total_units += 1
			if symbol != "C":
				provided[symbol] = int(provided.get(symbol, 0)) + 1
	var missing_typed := 0
	for symbol: Variant in required:
		missing_typed += maxi(0, int(required[symbol]) - int(provided.get(symbol, 0)))
	missing_typed = maxi(0, missing_typed - any_units)
	return maxi(missing_typed, maxi(0, cost.length() - total_units))


func _energy_pays(energy: CardInstance, symbol: String) -> bool:
	if energy == null or energy.card_data == null or not energy.card_data.is_energy():
		return false
	var provision := str(energy.card_data.energy_provides)
	if provision == "":
		provision = str(energy.card_data.energy_type)
	return provision == "ANY" or symbol in provision


func _attached_energy_paying(slot: PokemonSlot, symbol: String) -> int:
	var count := 0
	if slot == null:
		return count
	for energy: CardInstance in slot.attached_energy:
		if _energy_pays(energy, symbol):
			count += 1
	return count


func _field_grass_energy(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		count += _attached_energy_paying(slot, "G")
	return count


func _energized_grass_bench_count(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for slot: PokemonSlot in player.bench:
		if _attached_energy_paying(slot, "G") > 0:
			count += 1
	return count


func _hand_has_grass_energy(player: PlayerState) -> bool:
	return _hand_grass_energy_count(player) > 0


func _hand_grass_energy_count(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.hand:
		if _matches_any(card, GRASS_ENERGY) or _energy_pays(card, "G"):
			count += 1
	return count


func _teal_dance_available(player: PlayerState, turn_number: int, only_source: PokemonSlot = null) -> bool:
	if player == null or not _hand_has_grass_energy(player):
		return false
	var candidates: Array[PokemonSlot] = []
	if only_source != null:
		candidates.append(only_source)
	else:
		for slot: PokemonSlot in _all_slots(player):
			candidates.append(slot)
	for slot: PokemonSlot in candidates:
		if slot == null or not _matches_any(slot, OGERPON):
			continue
		var used := false
		for effect: Dictionary in slot.effects:
			if str(effect.get("type", "")) == "ability_attach_basic_energy_from_hand_draw_used" and int(effect.get("turn", -1)) == turn_number:
				used = true
				break
		if not used:
			return true
	return false


func _quick_search_available(player: PlayerState, turn_number: int) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_any(slot, PIDGEOT_EX):
			continue
		var used := false
		for effect: Dictionary in slot.effects:
			if str(effect.get("type", "")) == "ability_search_any_used" and int(effect.get("turn", -1)) == turn_number:
				used = true
				break
		if not used:
			return true
	return false


func _control_candy_route_live(player: PlayerState) -> bool:
	return player != null and (
		(_has_any_slot(player, PIDGEY) and not _has_any_slot(player, PIDGEOT_EX))
		or (_has_any_slot(player, NACLI) and not _has_any_slot(player, GARGANACL))
	)


func _control_garganacl_one_fighting_short(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or not _matches_any(slot, GARGANACL) or slot.get_card_data() == null:
			continue
		for attack: Dictionary in slot.get_card_data().attacks:
			var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
			if cost.contains("F") and _attack_gap(slot, cost) == 1:
				return true
	return false


func _control_redundant_stage_two_without_basic_route(card: CardInstance, player: PlayerState) -> bool:
	if player == null:
		return false
	if _matches_any(card, PIDGEOT_EX):
		return _has_any_slot(player, PIDGEOT_EX) and not _has_any_slot(player, PIDGEY)
	if _matches_any(card, GARGANACL):
		return _has_any_slot(player, GARGANACL) and not _has_any_slot(player, NACLI)
	return false


func _score_switching_ticket_exchange(player: PlayerState, base_score: float) -> float:
	if player == null or player.prizes.is_empty() or player.deck.is_empty():
		return minf(base_score, -1800.0)
	var exchange_value := _control_ticket_exchange_value(player)
	if exchange_value < 0.35:
		return minf(base_score, -900.0)
	var exchanged_cards := mini(player.prizes.size(), player.deck.size())
	return maxf(base_score, 650.0 + exchange_value * 900.0 + float(exchanged_cards) * 45.0)


func _control_ticket_exchange_value(player: PlayerState) -> float:
	if player == null:
		return 0.0
	var exchanged_cards := mini(player.prizes.size(), player.deck.size())
	var hidden_cards := player.prizes.size() + player.deck.size()
	if exchanged_cards <= 0 or hidden_cards <= 0:
		return 0.0
	var exchange_fraction := float(exchanged_cards) / float(hidden_cards)
	var value := 0.0
	for key: String in CONTROL_KEY_COPY_COUNTS:
		var total_copies := int(CONTROL_KEY_COPY_COUNTS[key])
		var missing_copies := maxi(0, total_copies - _visible_control_key_count(player, key))
		value += float(missing_copies) * float(CONTROL_KEY_EXCHANGE_WEIGHTS[key]) * exchange_fraction
	return value


func _visible_control_key_count(player: PlayerState, key: String) -> int:
	if player == null:
		return 0
	var names := _control_key_names(key)
	var count := 0
	for cards: Array in [player.hand, player.discard_pile, player.lost_zone]:
		for card: CardInstance in cards:
			if _matches_any(card, names):
				count += 1
	count += _count_any_slots(player, names)
	return count


func _control_key_names(key: String) -> Array[String]:
	match key:
		"pidgeot":
			return PIDGEOT_EX
		"garganacl":
			return GARGANACL
		"pal_pad":
			return PAL_PAD
		"turtonator":
			return TURTONATOR
	return []


func _discard_supporter_count(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Supporter":
			count += 1
	return count


func _is_control_supporter(item: Variant) -> bool:
	return _matches_key(item, "Team Star Grunt") or _matches_key(item, "天星队手下") \
		or _matches_key(item, "Boss's Orders") or _matches_key(item, "老大的指令") \
		or _matches_key(item, "Xerosic's Machinations") or _matches_key(item, "库瑟洛斯奇的企图") \
		or _matches_key(item, "Brock's Scouting") or _matches_key(item, "小刚的发掘") \
		or _matches_key(item, "Lana's Aid") or _matches_key(item, "水莲的照顾")


func _is_draw_reset_card(item: Variant) -> bool:
	return _matches_key(item, "Professor's Research") or _matches_key(item, "博士的研究") \
		or _matches_key(item, "Iono") or _matches_key(item, "奇树") \
		or _matches_key(item, "Squawkabilly ex") or _matches_key(item, "怒鹦哥ex") \
		or _matches_key(item, "Fezandipiti ex") or _matches_key(item, "吉雉鸡ex") \
		or _matches_key(item, "Mew ex") or _matches_key(item, "梦幻ex")


func _is_behind_on_prizes(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	return game_state.players[player_index].prizes.size() > game_state.players[1 - player_index].prizes.size()


func _opponent_active_energy_count(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var opponent: PlayerState = game_state.players[1 - player_index]
	return opponent.active_pokemon.attached_energy.size() if opponent.active_pokemon != null else 0


func _opponent_active_is_energized_ex(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent.active_pokemon == null or opponent.active_pokemon.get_card_data() == null:
		return false
	return str(opponent.active_pokemon.get_card_data().mechanic).to_lower() == "ex" and not opponent.active_pokemon.attached_energy.is_empty()


func _recoverable_grass_count(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and (card.card_data.is_pokemon() or card.card_data.card_type == "Basic Energy"):
			count += 1
	return count


func _missing_grass_rebuild_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	return not _has_any_slot(player, TOEDSCRUEL_EX) \
		or (_count_any_slots(player, TOEDSCOOL) + _count_any_slots(player, TOEDSCRUEL_EX) + _count_any_slots(player, TOEDSCRUEL)) < 2 \
		or _field_grass_energy(player) < 4


func _slot_holding_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	if player == null or energy == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if energy in slot.attached_energy:
			return slot
	return null


func _has_any_slot(player: PlayerState, names: Array[String]) -> bool:
	return _count_any_slots(player, names) > 0


func _count_any_slots(player: PlayerState, names: Array[String]) -> int:
	var count := 0
	if player == null:
		return count
	for slot: PokemonSlot in _all_slots(player):
		if _matches_any(slot, names):
			count += 1
	return count


func _matches_any(item: Variant, names: Array[String]) -> bool:
	for name: String in names:
		if _matches_key(item, name):
			return true
	return false


func _is_basic_grass_energy(card: CardInstance) -> bool:
	return card != null \
		and card.card_data != null \
		and card.card_data.card_type == "Basic Energy" \
		and _energy_pays(card, "G")


func _is_basic_fighting_energy(card: CardInstance) -> bool:
	return card != null \
		and card.card_data != null \
		and card.card_data.card_type == "Basic Energy" \
		and _energy_pays(card, "F")


func _player_from_state(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	return _player_from_state(context.get("game_state", null), int(context.get("player_index", -1)))


func _is_control_deck() -> bool:
	return _deck_id == CONTROL_DECK_ID
