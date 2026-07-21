class_name DeckStrategyV18PidgeotAcademy
extends "res://scripts/ai/DeckStrategyV18GardevoirFamily.gd"


const CONTROL_SCRIPT = preload("res://scripts/ai/DeckStrategyV18ControlGrass.gd")

const PIDGEOT_DECK_ID := 800018359
const ACADEMY_DECK_ID := 800018498
const CONTROL_LOW_DECK_FLOOR := 4
const ACADEMY_LOW_DECK_FLOOR := 5

const PIDGEY_UID := "151C_016"
const PIDGEOT_UID := "CSV4C_101"
const NACLI_UID := "SVP_080"
const GARGANACL_UID := "CSV4C_074"
const PAL_PAD_UID := "CSV1C_111"
const ACCOMPANYING_FLUTE_UID := "CSV8C_175"
const RUFFIAN_UID := "CSV10C_205"
const COUNTER_CATCHER_UID := "CSV6C_114"
const PRECIOUS_TROLLEY_UID := "CSV9C_186"
const NIGHT_STRETCHER_UID := "CSV8C_183"
const SUPER_ROD_UID := "CSV1C_109"
const RESEARCH_UID := "CSV1C_121"
const IONO_UID := "CSV3C_123"
const RALTS_UID := "CSV2C_053"
const KIRLIA_UID := "CS6.5C_030"
const GARDEVOIR_UID := "CSV2C_055"
const MUNKIDORI_UID := "CSV8C_094"
const SCREAM_TAIL_UID := "CSV6C_065"
const DRIFLOON_UID := "CSV2C_060"
const CLEFAIRY_EX_UID := "CSV10C_082"
const AREA_ZERO_UID := "CSV9C_207"
const BRAVERY_CHARM_UID := "CSV1C_118"
const ARTAZON_UID := "CSV2C_127"
const RALTS_NAMES: Array[String] = ["Ralts"]
const ACADEMY_KEY_ATTACKER_NAMES: Array[String] = ["Scream Tail", "Drifloon", "Lillie's Clefairy ex"]
const ACCOMPANYING_FLUTE_DANGEROUS_UIDS: Array[String] = [
	"CSV1C_050",
	"CS4DaC_137",
	"CS5aC_019",
	"CSV6C_051",
	"CSV8C_172",
	"151C_151",
	"CS6.5C_020",
	"CSV8C_135",
]
const ACCOMPANYING_FLUTE_DANGEROUS_NAMES: Array[String] = [
	"Miraidon ex",
	"Raikou V",
	"Raichu V",
	"Iron Hands ex",
	"Bloodmoon Ursaluna ex",
	"Mew ex",
	"Radiant Greninja",
	"Fezandipiti ex",
]
const ACCOMPANYING_FLUTE_BURDEN_UIDS: Array[String] = ["CS5bC_049"]
const ACCOMPANYING_FLUTE_BURDEN_NAMES: Array[String] = ["Lumineon V"]

const PIDGEOT_EFFECT := "8105afde9792c2596166f318a480d041"
const GARGANACL_EFFECT := "73c1d28d980ebe98f205db87eb647fe8"
const PAL_PAD_EFFECT := "a47d5a8ed00e14a2146fc511745d23b5"
const ACCOMPANYING_FLUTE_EFFECT := "e9bd0b4b3d97716a9757e6bccb1446ac"
const RUFFIAN_EFFECT := "dacd942c84db0948ced6544bacfa08d7"
const COUNTER_CATCHER_EFFECT := "06bc00d5dcec33898dc6db2e4c4d10ec"
const PRECIOUS_TROLLEY_EFFECT := "28f142be07616ba497b1afd206477963"
const NIGHT_STRETCHER_EFFECT := "3e6f1daf545dfed48d0588dd50792a2e"
const SUPER_ROD_EFFECT := "c9c948169525fbb3dce70c477ec7a90a"
const RESEARCH_EFFECT := "aecd80ca2722885c3d062a2255346f3e"
const IONO_EFFECT := "af514f82d182aeae5327b2c360df703d"
const KIRLIA_EFFECT := "4abd956bdf3e956fcf679120601760ff"
const GARDEVOIR_EFFECT := "bd134d7d84e9f1a837a74b061fcb5f40"
const MUNKIDORI_EFFECT := "66fee12502043db7d92b97b0d62b0f59"
const ARTAZON_EFFECT := "c117bea3cc758d46430d6bef11062a56"

const PIDGEOT_NAMES: Array[String] = ["大比鸟ex", "Pidgeot ex"]
const NACLI_NAMES: Array[String] = ["盐石宝", "Nacli"]
const GARGANACL_NAMES: Array[String] = ["盐石巨灵", "Garganacl"]
const PAL_PAD_NAMES: Array[String] = ["朋友手册", "Pal Pad"]
const ACCOMPANYING_FLUTE_NAMES: Array[String] = ["配乐之笛", "Accompanying Flute"]
const RUFFIAN_NAMES: Array[String] = ["可怕的哥哥", "Ruffian"]
const COUNTER_CATCHER_NAMES: Array[String] = ["反击捕捉器", "Counter Catcher"]
const NIGHT_STRETCHER_NAMES: Array[String] = ["夜间担架", "Night Stretcher"]
const SUPER_ROD_NAMES: Array[String] = ["厉害钓竿", "Super Rod"]
const RESEARCH_NAMES: Array[String] = ["博士的研究", "Professor's Research"]
const IONO_NAMES: Array[String] = ["奇树", "Iono"]
const KIRLIA_NAMES: Array[String] = ["奇鲁莉安", "Kirlia"]
const GARDEVOIR_NAMES: Array[String] = ["沙奈朵ex", "Gardevoir ex"]
const MUNKIDORI_NAMES: Array[String] = ["愿增猿", "Munkidori"]
const BRAVERY_CHARM_NAMES: Array[String] = ["勇气护符", "Bravery Charm"]
const ACADEMY_ATTACKER_NAMES: Array[String] = [
	"吼叫尾", "Scream Tail",
	"飘飘球", "Drifloon",
	"莉莉艾的皮皮ex", "Lillie's Clefairy ex",
	"沙奈朵ex", "Gardevoir ex",
]

var _deck_id := ACADEMY_DECK_ID
var _strategy_text := ""
var _control_delegate: RefCounted = CONTROL_SCRIPT.new()


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else ACADEMY_DECK_ID
	if _is_control():
		_control_delegate.call("configure_from_deck", deck)
	else:
		super.configure_from_deck(deck)


func set_deck_strategy_text(strategy_text: String) -> void:
	_strategy_text = strategy_text.strip_edges()
	if _is_control() and _control_delegate.has_method("set_deck_strategy_text"):
		_control_delegate.call("set_deck_strategy_text", _strategy_text)


func get_deck_strategy_text() -> String:
	return _strategy_text


func get_strategy_id() -> String:
	return "v18_pidgeot_academy_%d_delegate" % _deck_id


func get_signature_names() -> Array[String]:
	return [PIDGEOT_UID, GARGANACL_UID] if _is_control() else [GARDEVOIR_UID, MUNKIDORI_UID]


func _deck_allows_munkidori_damage_transfer_debt() -> bool:
	return _deck_id == ACADEMY_DECK_ID or super._deck_allows_munkidori_damage_transfer_debt()


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if _is_control():
		var delegated: Variant = _control_delegate.call("plan_opening_setup", player)
		return delegated if delegated is Dictionary else {}
	return super.plan_opening_setup(player)


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var plan: Dictionary
	if _is_control():
		var delegated: Variant = _control_delegate.call("build_turn_plan", game_state, player_index, context)
		plan = (delegated as Dictionary).duplicate(true) if delegated is Dictionary else {}
	else:
		plan = super.build_turn_plan(game_state, player_index, context)
	var player := _player(game_state, player_index)
	var opponent := _opponent(game_state, player_index)
	if player == null:
		return _ensure_contract_shape(plan)

	var flags: Dictionary = plan.get("flags", {}) if plan.get("flags", {}) is Dictionary else {}
	var constraints: Dictionary = plan.get("constraints", {}) if plan.get("constraints", {}) is Dictionary else {}
	flags["dedicated_family"] = "pidgeot_control" if _is_control() else "academy_gardevoir"
	flags["own_deckout_guard"] = player.deck.size() <= _low_deck_floor()
	constraints["forbid_engine_churn"] = bool(constraints.get("forbid_engine_churn", false)) \
		or player.deck.size() <= _low_deck_floor()
	constraints["forbid_extra_bench_padding"] = bool(constraints.get("forbid_extra_bench_padding", false)) \
		or (_active_route_ready(player) and player.bench.size() >= 4)

	if _is_control():
		var deckout_pressure := opponent != null and opponent.deck.size() <= 2
		var deckout_finish := opponent != null and opponent.deck.size() <= 1 and _ready_garganacl_attack(player)
		flags["opponent_deckout_pressure"] = deckout_pressure
		flags["control_loop_live"] = _live_pal_pad_recovery(player)
		if deckout_finish:
			plan["phase"] = "close"
			plan["intent"] = "finish_garganacl_deckout"
			plan["owner"] = {
				"turn_owner_name": "Garganacl",
				"bridge_target_name": "Pidgeot ex",
				"pivot_target_name": "Garganacl",
			}
	else:
		var close_route := _ready_academy_attack(player) and player.prizes.size() <= 2
		var recovery_reason := _academy_recovery_reason(player)
		var recovery_route_live := recovery_reason != ""
		flags["final_prize_route"] = close_route
		flags["recovery_route_live"] = recovery_route_live
		flags["recovery_route_reason"] = recovery_reason
		_set_academy_recovery_plan_priorities(plan, recovery_route_live)
		if close_route:
			plan["phase"] = "close"
			plan["intent"] = "take_final_prizes_without_churn"

	plan["flags"] = flags
	plan["constraints"] = constraints
	plan["id"] = "v18_pidgeot_academy:%d:%s" % [_deck_id, str(plan.get("intent", ""))]
	return _ensure_contract_shape(plan)


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	var continuity: Dictionary
	if _is_control():
		var delegated: Variant = _control_delegate.call("build_continuity_contract", game_state, player_index, turn_contract)
		continuity = (delegated as Dictionary).duplicate(true) if delegated is Dictionary else {}
	else:
		continuity = super.build_continuity_contract(game_state, player_index, turn_contract)
	var player := _player(game_state, player_index)
	var opponent := _opponent(game_state, player_index)
	if player == null:
		return continuity
	var winning_attack := _ready_garganacl_attack(player) and opponent != null and opponent.deck.size() <= 1 \
		if _is_control() else _ready_academy_attack(player) and player.prizes.size() <= 2
	if winning_attack:
		continuity["safe_setup_before_attack"] = false
		continuity["attack_penalty"] = 0.0
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	setup_debt["own_deckout_guard"] = player.deck.size() <= _low_deck_floor()
	setup_debt["winning_attack_available"] = winning_attack
	continuity["setup_debt"] = setup_debt
	return continuity


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := float(_control_delegate.call("score_action_absolute", action, game_state, player_index)) \
		if _is_control() else super.score_action_absolute(action, game_state, player_index)
	return _score_dedicated_edge(action, game_state, player_index, score)


func score_action_absolute_with_plan(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary = {}
) -> float:
	if not _is_control():
		return super.score_action_absolute_with_plan(action, game_state, player_index, turn_plan)
	var score := float(_control_delegate.call(
		"score_action_absolute_with_plan",
		action,
		game_state,
		player_index,
		turn_plan
	))
	return _score_dedicated_edge(action, game_state, player_index, score)


func evaluate_board(game_state: GameState, player_index: int) -> float:
	var score := float(_control_delegate.call("evaluate_board", game_state, player_index)) \
		if _is_control() else super.evaluate_board(game_state, player_index)
	var player := _player(game_state, player_index)
	var opponent := _opponent(game_state, player_index)
	if player == null or opponent == null:
		return score
	if _is_control():
		score += float(maxi(0, player.deck.size() - opponent.deck.size())) * 55.0
		if opponent.deck.size() <= 1 and _ready_garganacl_attack(player):
			score += 1600.0
	elif _ready_academy_attack(player):
		score += float(maxi(0, 3 - player.prizes.size())) * 380.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if _is_control():
		var delegated: Variant = _control_delegate.call("predict_attacker_damage", slot, extra_context)
		return delegated if delegated is Dictionary else {"damage": 0, "can_attack": false, "description": ""}
	return super.predict_attacker_damage(slot, extra_context)


func get_search_priority(card: CardInstance) -> int:
	var priority := int(_control_delegate.call("get_search_priority", card)) \
		if _is_control() else super.get_search_priority(card)
	if _is_control() and _matches(card, [PIDGEOT_UID], PIDGEOT_NAMES, [PIDGEOT_EFFECT]):
		return maxi(priority, 1600)
	if _is_control() and _matches(card, [GARGANACL_UID], GARGANACL_NAMES, [GARGANACL_EFFECT]):
		return maxi(priority, 1450)
	if not _is_control() and _matches(card, [GARDEVOIR_UID], GARDEVOIR_NAMES, [GARDEVOIR_EFFECT]):
		return maxi(priority, 1600)
	return priority


func get_discard_priority(card: CardInstance) -> int:
	return int(_control_delegate.call("get_discard_priority", card)) \
		if _is_control() else super.get_discard_priority(card)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var priority := int(_control_delegate.call("get_discard_priority_contextual", card, game_state, player_index)) \
		if _is_control() else super.get_discard_priority_contextual(card, game_state, player_index)
	var player := _player(game_state, player_index)
	if _is_control() and player != null and _matches(card, [PAL_PAD_UID], PAL_PAD_NAMES, [PAL_PAD_EFFECT]) \
		and _discard_supporter_count(player) > 0:
		return mini(priority, 1)
	return priority


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}):
	if _is_control():
		if str(step.get("id", "")).to_lower() == "bench_basic_pokemon":
			return _pick_accompanying_flute_burdens(items, step)
		var delegated: Variant = _control_delegate.call("pick_interaction_items", items, step, context)
		return delegated if delegated is Array or delegated is Dictionary else []
	return super.pick_interaction_items(items, step, context)


func pick_embrace_target(target_slots: Array, game_state: GameState = null, player_index: int = -1) -> Variant:
	if _is_control():
		return target_slots[0] if not target_slots.is_empty() else null
	if not _is_control():
		var player := _player(game_state, player_index)
		var retreat_owner := _academy_engine_retreat_embrace_target(
			target_slots,
			game_state,
			player,
			player_index
		)
		if retreat_owner != null:
			return retreat_owner
		if _academy_active_scaler_needs_embrace(game_state, player, player_index):
			var active := player.active_pokemon
			if active in target_slots:
				return active
	return super.pick_embrace_target(target_slots, game_state, player_index)


func _academy_engine_retreat_embrace_target(
	target_slots: Array,
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> PokemonSlot:
	if game_state == null or player == null or player.active_pokemon == null:
		return null
	var active := player.active_pokemon
	if active not in target_slots \
			or not _matches(active, [GARDEVOIR_UID], GARDEVOIR_NAMES, [GARDEVOIR_EFFECT]) \
			or _get_retreat_energy_gap(active) != 1 \
			or not _can_take_more_psychic_embrace_damage(active, game_state):
		return null
	var discard_fuel := _count_psychic_energy_in_discard(game_state, player_index)
	if discard_fuel <= 0:
		return null
	for slot: PokemonSlot in player.bench:
		if not _matches(
			slot,
			[SCREAM_TAIL_UID, DRIFLOON_UID, CLEFAIRY_EX_UID],
			ACADEMY_ATTACKER_NAMES,
			[]
		):
			continue
		var attack_gap := _minimum_attack_gap(slot)
		if attack_gap >= 0 and attack_gap <= discard_fuel - 1:
			return active
	return null


func _academy_darkness_owner_waiting(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches(slot, [MUNKIDORI_UID], MUNKIDORI_NAMES, [MUNKIDORI_EFFECT]) \
				and not _slot_has_energy_symbol_local(slot, "D"):
			return true
	if player.bench.size() >= 5:
		return false
	for hand_card: CardInstance in player.hand:
		if _matches(hand_card, [MUNKIDORI_UID], MUNKIDORI_NAMES, [MUNKIDORI_EFFECT]):
			return true
	return false


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var score := float(_control_delegate.call("score_interaction_target", item, step, context)) \
		if _is_control() else super.score_interaction_target(item, step, context)
	var player := _context_player(context)
	if player == null:
		return score
	if _is_control() and _matches(item, [PAL_PAD_UID], PAL_PAD_NAMES, [PAL_PAD_EFFECT]) and _live_pal_pad_recovery(player):
		return maxf(score, 5200.0)
	if not _is_control() and _is_academy_recovery_item(item):
		return _academy_recovery_score(item) if _academy_recovery_live(player) else minf(score, -4200.0)
	return score


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _is_control():
		return float(_control_delegate.call("score_handoff_target", item, step, context))
	return super.score_handoff_target(item, step, context)


func _score_dedicated_edge(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var player := _player(game_state, player_index)
	var opponent := _opponent(game_state, player_index)
	if player == null:
		return base_score
	var score := base_score
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	match kind:
		"attack", "granted_attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			if _is_control() and _matches(source, [GARGANACL_UID], GARGANACL_NAMES, [GARGANACL_EFFECT]):
				if opponent != null and opponent.deck.size() <= 1:
					return maxf(score, 8200.0)
				if player.deck.size() <= CONTROL_LOW_DECK_FLOOR:
					score = maxf(score, 4300.0)
			elif not _is_control() and _matches(source, [SCREAM_TAIL_UID, DRIFLOON_UID, CLEFAIRY_EX_UID, GARDEVOIR_UID], ACADEMY_ATTACKER_NAMES, [GARDEVOIR_EFFECT]):
				if bool(action.get("projected_knockout", false)) or player.prizes.size() <= 2:
					return maxf(score, 7600.0)
				if player.deck.size() <= ACADEMY_LOW_DECK_FLOOR:
					score = maxf(score, 4800.0)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _is_control() and _matches(source, [PIDGEOT_UID], PIDGEOT_NAMES, [PIDGEOT_EFFECT]) \
				and player.deck.size() <= 2 and _active_route_ready(player):
				return minf(score, -6500.0)
			if not _is_control() and _matches(source, [GARDEVOIR_UID], GARDEVOIR_NAMES, [GARDEVOIR_EFFECT]):
				if _academy_active_scaler_has_visible_prize(game_state, player, player_index):
					return minf(score, -4200.0)
				if _academy_active_scaler_needs_embrace(game_state, player, player_index):
					return maxf(score, 5600.0)
			if not _is_control() and _matches(source, [KIRLIA_UID], KIRLIA_NAMES, [KIRLIA_EFFECT]):
				if _academy_active_scaler_has_visible_prize(game_state, player, player_index):
					return minf(score, -4200.0)
				if player.deck.size() <= ACADEMY_LOW_DECK_FLOOR and _active_route_ready(player):
					return minf(score, -6500.0)
			if not _is_control() and _matches(source, [MUNKIDORI_UID], MUNKIDORI_NAMES, [MUNKIDORI_EFFECT]):
				if not _has_movable_damage(player) or not _has_opponent_damage_target(opponent):
					return minf(score, -4500.0)
				return maxf(score, 4400.0)
		"use_stadium_effect":
			if not _is_control() \
					and _matches(card, [ARTAZON_UID], ["Artazon"], [ARTAZON_EFFECT]) \
					and player.bench.size() >= 4 \
					and _count_primary_shell_bodies(player) >= 2 \
					and _count_attackers_on_field(player) >= 1:
				return minf(score, -4200.0)
		"attach_energy":
			var target: PokemonSlot = action.get("target_slot", null)
			if _is_control():
				var salt_lane := _control_incomplete_salt_lane(player)
				if salt_lane != null and target == salt_lane:
					return maxf(score, 5000.0)
				if salt_lane != null and target in player.bench \
						and _matches(target, [PIDGEOT_UID], PIDGEOT_NAMES, [PIDGEOT_EFFECT]):
					return minf(score, -4300.0)
			elif _is_basic_energy_symbol_local(card, "D"):
				if _matches(target, [MUNKIDORI_UID], MUNKIDORI_NAMES, [MUNKIDORI_EFFECT]):
					return minf(score, -3800.0) if _slot_has_energy_symbol_local(target, "D") else maxf(score, 4600.0)
				if _academy_darkness_owner_waiting(player):
					return minf(score, -4200.0)
		"attach_tool":
			if not _is_control() and _matches(
				card,
				[BRAVERY_CHARM_UID],
				BRAVERY_CHARM_NAMES,
				["d1c2f018a644e662f2b6895fdfc29281"]
			):
				var target: PokemonSlot = action.get("target_slot", null)
				if _academy_charm_crosses_visible_prize(game_state, player, player_index, target):
					return maxf(score, 5800.0)
				return minf(score, -4600.0)
		"play_trainer", "play_stadium":
			if not _is_control() \
					and (_matches(card, [RESEARCH_UID], RESEARCH_NAMES, [RESEARCH_EFFECT]) \
					or _matches(card, [IONO_UID], IONO_NAMES, [IONO_EFFECT])) \
					and _academy_active_scaler_has_visible_prize(game_state, player, player_index):
				return minf(score, -4200.0)
			score = _score_shared_trainer_gate(card, player, opponent, score)
			if _is_control():
				score = _score_control_trainer_gate(card, game_state, player, opponent, score)
			else:
				score = _score_academy_trainer_gate(card, player, score)
		"end_turn":
			if _is_control() and opponent != null and opponent.deck.size() <= 1 and _ready_garganacl_attack(player):
				return minf(score, -5200.0)
			if not _is_control() and _ready_academy_attack(player) and player.prizes.size() <= 2:
				return minf(score, -5200.0)
	return score


func _score_shared_trainer_gate(
	card: Variant,
	player: PlayerState,
	opponent: PlayerState,
	base_score: float
) -> float:
	if not _matches(card, [COUNTER_CATCHER_UID], COUNTER_CATCHER_NAMES, [COUNTER_CATCHER_EFFECT]):
		return base_score
	if opponent == null or opponent.bench.is_empty():
		return minf(base_score, -5200.0)
	if player.prizes.size() <= opponent.prizes.size():
		return minf(base_score, -4800.0)
	return maxf(base_score, 5100.0)


func _score_control_trainer_gate(
	card: Variant,
	game_state: GameState,
	player: PlayerState,
	opponent: PlayerState,
	base_score: float
) -> float:
	if _matches(card, [PRECIOUS_TROLLEY_UID], ["Precious Trolley"], [PRECIOUS_TROLLEY_EFFECT]) \
			and _control_opening_dual_seed_trolley_live(game_state, player):
		return maxf(base_score, 5600.0)
	if _matches(card, [PAL_PAD_UID], PAL_PAD_NAMES, [PAL_PAD_EFFECT]):
		return maxf(base_score, 5600.0) if _live_pal_pad_recovery(player) else minf(base_score, -5000.0)
	if _matches(card, [ACCOMPANYING_FLUTE_UID], ACCOMPANYING_FLUTE_NAMES, [ACCOMPANYING_FLUTE_EFFECT]):
		if opponent == null or opponent.deck.is_empty() or opponent.bench.size() >= _bench_limit(game_state, opponent):
			return minf(base_score, -4800.0)
		return maxf(base_score, 2800.0)
	if _matches(card, [RUFFIAN_UID], RUFFIAN_NAMES, [RUFFIAN_EFFECT]):
		return maxf(base_score, 3600.0) if _opponent_has_ruffian_target(opponent) else minf(base_score, -4800.0)
	return base_score


func _score_academy_trainer_gate(card: Variant, player: PlayerState, base_score: float) -> float:
	if (_matches(card, [RESEARCH_UID], RESEARCH_NAMES, [RESEARCH_EFFECT]) \
		or _matches(card, [IONO_UID], IONO_NAMES, [IONO_EFFECT])) \
		and player.deck.size() <= ACADEMY_LOW_DECK_FLOOR and _active_route_ready(player):
		return minf(base_score, -7000.0)
	if _is_academy_recovery_item(card):
		if not _academy_recovery_live(player):
			return minf(base_score, -4500.0)
		return _academy_recovery_score(card)
	return base_score


func _is_control() -> bool:
	return _deck_id == PIDGEOT_DECK_ID


func _low_deck_floor() -> int:
	return CONTROL_LOW_DECK_FLOOR if _is_control() else ACADEMY_LOW_DECK_FLOOR


func _player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _opponent(game_state: GameState, player_index: int) -> PlayerState:
	return _player(game_state, 1 - player_index)


func _context_player(context: Dictionary) -> PlayerState:
	return _player(context.get("game_state", null), int(context.get("player_index", -1)))


func _ensure_contract_shape(plan: Dictionary) -> Dictionary:
	if not plan.has("phase"):
		plan["phase"] = "setup"
	if not plan.has("intent"):
		plan["intent"] = "establish_engine"
	if not plan.get("owner", null) is Dictionary:
		plan["owner"] = {"turn_owner_name": "", "bridge_target_name": "", "pivot_target_name": ""}
	if not plan.get("priorities", null) is Dictionary:
		plan["priorities"] = {"attach": [], "handoff": [], "search": [], "evolve": [], "ability": [], "trainer": []}
	if not plan.get("flags", null) is Dictionary:
		plan["flags"] = {}
	if not plan.get("constraints", null) is Dictionary:
		plan["constraints"] = {"forbid_engine_churn": false, "forbid_extra_bench_padding": false}
	return plan


func _active_route_ready(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	return _slot_can_attack(player.active_pokemon)


func _academy_active_scaler_needs_embrace(
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> bool:
	if not _is_control():
		if game_state == null or player == null:
			return false
		var active := player.active_pokemon
		if not _slot_is_live(active) or not _matches(
			active,
			[DRIFLOON_UID, SCREAM_TAIL_UID],
			["Drifloon", "Scream Tail"],
			[]
		):
			return false
		var current: Dictionary = predict_attacker_damage(active, 0)
		if not bool(current.get("can_attack", false)):
			return false
		var has_psychic_fuel := false
		for card: CardInstance in player.discard_pile:
			if _is_basic_energy_symbol_local(card, "P"):
				has_psychic_fuel = true
				break
		if not has_psychic_fuel or not _can_take_more_psychic_embrace_damage(active, game_state):
			return false
		var after: Dictionary = predict_attacker_damage(active, 1)
		var current_scaler_damage := int(current.get("damage", 0))
		if not bool(after.get("can_attack", false)) or int(after.get("damage", 0)) <= current_scaler_damage:
			return false
		var opponent := _opponent(game_state, player_index)
		if opponent == null or opponent.active_pokemon == null:
			return false
		var active_target_damage := current_scaler_damage
		for attack: Dictionary in active.get_card_data().attacks:
			var raw_damage := str(attack.get("damage", "")).strip_edges()
			if raw_damage.is_valid_int() and _attack_gap(active, str(attack.get("cost", ""))) <= 0:
				active_target_damage = maxi(active_target_damage, raw_damage.to_int())
		if _slot_is_live(opponent.active_pokemon) \
			and opponent.active_pokemon.get_remaining_hp() <= active_target_damage:
			return false
		if _matches(active, [SCREAM_TAIL_UID], ["Scream Tail"], []):
			for target: PokemonSlot in opponent.bench:
				if _slot_is_live(target) and target.get_remaining_hp() <= current_scaler_damage:
					return false
		return true
	return false


func _academy_active_scaler_has_visible_prize(
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> bool:
	if _is_control() or game_state == null or player == null:
		return false
	var active := player.active_pokemon
	if not _slot_is_live(active) or not _matches(
		active,
		[DRIFLOON_UID, SCREAM_TAIL_UID],
		["Drifloon", "Scream Tail"],
		[]
	):
		return false
	var prediction: Dictionary = predict_attacker_damage(active, 0)
	if not bool(prediction.get("can_attack", false)):
		return false
	var damage := int(prediction.get("damage", 0))
	if damage <= 0:
		return false
	var opponent := _opponent(game_state, player_index)
	if opponent == null:
		return false
	if _slot_is_live(opponent.active_pokemon) and opponent.active_pokemon.get_remaining_hp() <= damage:
		return true
	if _matches(active, [SCREAM_TAIL_UID], ["Scream Tail"], []):
		for target: PokemonSlot in opponent.bench:
			if _slot_is_live(target) and target.get_remaining_hp() <= damage:
				return true
	return false


func _ready_garganacl_attack(player: PlayerState) -> bool:
	return player != null and _matches(player.active_pokemon, [GARGANACL_UID], GARGANACL_NAMES, [GARGANACL_EFFECT]) \
		and _slot_can_attack(player.active_pokemon)


func _control_incomplete_salt_lane(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var nacli: PokemonSlot = null
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches(slot, [GARGANACL_UID], GARGANACL_NAMES, [GARGANACL_EFFECT]):
			return null if _slot_can_attack(slot) else slot
		if nacli == null and _matches(slot, [NACLI_UID], NACLI_NAMES, []):
			nacli = slot
	return nacli


func _control_opening_dual_seed_trolley_live(game_state: GameState, player: PlayerState) -> bool:
	if game_state == null or int(game_state.turn_number) > 2:
		return false
	if player == null or player.bench.size() + 2 > _bench_limit(game_state, player):
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches(slot, [PIDGEY_UID], ["Pidgey"], []):
			return false
		if _matches(slot, [NACLI_UID], NACLI_NAMES, []):
			return false
	var pidgey_in_deck := false
	var nacli_in_deck := false
	for deck_card: CardInstance in player.deck:
		pidgey_in_deck = pidgey_in_deck or _matches(deck_card, [PIDGEY_UID], ["Pidgey"], [])
		nacli_in_deck = nacli_in_deck or _matches(deck_card, [NACLI_UID], NACLI_NAMES, [])
	return pidgey_in_deck and nacli_in_deck


func _academy_charm_crosses_visible_prize(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target: PokemonSlot
) -> bool:
	if game_state == null or player == null or target == null or target != player.active_pokemon:
		return false
	if not _matches(target, [DRIFLOON_UID, SCREAM_TAIL_UID], ["Drifloon", "Scream Tail"], []):
		return false
	if not _academy_active_scaler_needs_embrace(game_state, player, player_index):
		return false
	var after: Dictionary = predict_attacker_damage(target, 1)
	var damage := int(after.get("damage", 0))
	if damage <= 0:
		return false
	var opponent := _opponent(game_state, player_index)
	if opponent == null:
		return false
	if _slot_is_live(opponent.active_pokemon) and opponent.active_pokemon.get_remaining_hp() <= damage:
		return true
	if _matches(target, [SCREAM_TAIL_UID], ["Scream Tail"], []):
		for bench_target: PokemonSlot in opponent.bench:
			if _slot_is_live(bench_target) and bench_target.get_remaining_hp() <= damage:
				return true
	return false


func _ready_academy_attack(player: PlayerState) -> bool:
	return player != null and _matches(
		player.active_pokemon,
		[SCREAM_TAIL_UID, DRIFLOON_UID, CLEFAIRY_EX_UID, GARDEVOIR_UID],
		ACADEMY_ATTACKER_NAMES,
		[GARDEVOIR_EFFECT]
	) and _slot_can_attack(player.active_pokemon)


func _slot_can_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if _attack_gap(slot, str(attack.get("cost", ""))) <= 0:
			return true
	return false


func _attack_gap(slot: PokemonSlot, raw_cost: String) -> int:
	var cost := CardData.normalize_attack_cost(raw_cost)
	var required: Dictionary = {}
	for symbol: String in cost:
		if symbol != "C":
			required[symbol] = int(required.get(symbol, 0)) + 1
	var provided: Dictionary = {}
	var any_units := 0
	var total_units := 0
	for energy: CardInstance in slot.attached_energy:
		var data := _card_data(energy)
		if data == null:
			continue
		var provision := str(data.energy_provides)
		if provision == "":
			provision = str(data.energy_type)
		if provision == "ANY":
			any_units += 1
			total_units += 1
			continue
		for symbol: String in provision:
			total_units += 1
			provided[symbol] = int(provided.get(symbol, 0)) + 1
	var typed_gap := 0
	for symbol: Variant in required:
		typed_gap += maxi(0, int(required[symbol]) - int(provided.get(symbol, 0)))
	typed_gap = maxi(0, typed_gap - any_units)
	return maxi(typed_gap, maxi(0, cost.length() - total_units))


func _live_pal_pad_recovery(player: PlayerState) -> bool:
	return player != null and _discard_supporter_count(player) > 0


func _discard_supporter_count(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.discard_pile:
		var data := _card_data(card)
		if data != null and str(data.card_type) == "Supporter":
			count += 1
	return count


func _academy_recovery_live(player: PlayerState) -> bool:
	return _academy_recovery_reason(player) != ""


func _academy_recovery_reason(player: PlayerState) -> String:
	if player == null:
		return ""
	var discarded_key_attacker := false
	var discarded_gardevoir := false
	var discarded_ralts := false
	var discarded_kirlia := false
	for card: CardInstance in player.discard_pile:
		discarded_key_attacker = discarded_key_attacker or _matches(
			card,
			[SCREAM_TAIL_UID, DRIFLOON_UID, CLEFAIRY_EX_UID],
			ACADEMY_KEY_ATTACKER_NAMES,
			[]
		)
		discarded_gardevoir = discarded_gardevoir or _matches(
			card, [GARDEVOIR_UID], GARDEVOIR_NAMES, [GARDEVOIR_EFFECT]
		)
		discarded_ralts = discarded_ralts or _matches(card, [RALTS_UID], RALTS_NAMES, [])
		discarded_kirlia = discarded_kirlia or _matches(
			card, [KIRLIA_UID], KIRLIA_NAMES, [KIRLIA_EFFECT]
		)
	if discarded_key_attacker and not _academy_zone_has(
		player,
		[SCREAM_TAIL_UID, DRIFLOON_UID, CLEFAIRY_EX_UID],
		ACADEMY_KEY_ATTACKER_NAMES,
		[]
	):
		return "missing_key_attacker"
	if discarded_gardevoir and not _academy_zone_has(
		player, [GARDEVOIR_UID], GARDEVOIR_NAMES, [GARDEVOIR_EFFECT]
	):
		return "missing_first_gardevoir"
	if discarded_kirlia and not _academy_zone_has(
		player, [KIRLIA_UID], KIRLIA_NAMES, [KIRLIA_EFFECT]
	):
		return "broken_evolution_line"
	if discarded_ralts and not _academy_zone_has(player, [RALTS_UID], RALTS_NAMES, []):
		return "broken_evolution_line"
	return ""


func _academy_zone_has(
	player: PlayerState,
	uids: Array[String],
	names: Array[String],
	effect_ids: Array[String]
) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches(slot, uids, names, effect_ids):
			return true
	for card: CardInstance in player.hand:
		if _matches(card, uids, names, effect_ids):
			return true
	return false


func _set_academy_recovery_plan_priorities(plan: Dictionary, recovery_route_live: bool) -> void:
	var priorities: Dictionary = plan.get("priorities", {}) if plan.get("priorities", {}) is Dictionary else {}
	var current: Array = priorities.get("trainer", []) if priorities.get("trainer", []) is Array else []
	var trainer_priorities: Array = []
	for priority: Variant in current:
		if not _is_academy_recovery_priority(priority):
			trainer_priorities.append(priority)
	if recovery_route_live:
		trainer_priorities.push_front("Super Rod")
		trainer_priorities.push_front("Night Stretcher")
	priorities["trainer"] = trainer_priorities
	plan["priorities"] = priorities


func _is_academy_recovery_priority(item: Variant) -> bool:
	var priority := str(item)
	return priority in NIGHT_STRETCHER_NAMES or priority in SUPER_ROD_NAMES


func _academy_recovery_score(item: Variant) -> float:
	return 5400.0 if _matches(
		item, [NIGHT_STRETCHER_UID], NIGHT_STRETCHER_NAMES, [NIGHT_STRETCHER_EFFECT]
	) else 4600.0


func _is_academy_recovery_item(item: Variant) -> bool:
	return _matches(item, [NIGHT_STRETCHER_UID], NIGHT_STRETCHER_NAMES, [NIGHT_STRETCHER_EFFECT]) \
		or _matches(item, [SUPER_ROD_UID], SUPER_ROD_NAMES, [SUPER_ROD_EFFECT])


func _has_movable_damage(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.damage_counters > 0:
			return true
	return false


func _has_opponent_damage_target(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot != null and slot.get_remaining_hp() > 0:
			return true
	return false


func _opponent_has_ruffian_target(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot == null:
			continue
		if slot.attached_tool != null:
			return true
		for energy: CardInstance in slot.attached_energy:
			var data := _card_data(energy)
			if data != null and str(data.card_type) == "Special Energy":
				return true
	return false


func _pick_accompanying_flute_burdens(items: Array, step: Dictionary) -> Dictionary:
	var max_select := clampi(int(step.get("max_select", items.size())), 0, items.size())
	var picked: Array = []
	for item: Variant in items:
		if picked.size() >= max_select:
			break
		if _is_accompanying_flute_control_burden(item):
			picked.append(item)
	return {"handled": true, "items": picked}


func _is_accompanying_flute_control_burden(item: Variant) -> bool:
	var data := _card_data(item)
	if data == null or not data.is_basic_pokemon():
		return false
	if _matches(item, ACCOMPANYING_FLUTE_DANGEROUS_UIDS, ACCOMPANYING_FLUTE_DANGEROUS_NAMES, []):
		return false
	# Flute benches from the deck, so Lumineon's from-hand Luminous Sign does not trigger.
	return _matches(item, ACCOMPANYING_FLUTE_BURDEN_UIDS, ACCOMPANYING_FLUTE_BURDEN_NAMES, [])


func _bench_limit(game_state: GameState, player: PlayerState) -> int:
	if game_state == null or player == null or not _matches(game_state.stadium_card, [AREA_ZERO_UID], ["零之大空洞", "Area Zero Underdepths"], []):
		return 5
	for slot: PokemonSlot in player.get_all_pokemon():
		var data := _card_data(slot)
		if data != null and data.is_tera_pokemon():
			return 8
	return 5


func _is_basic_energy_symbol_local(item: Variant, symbol: String) -> bool:
	var data := _card_data(item)
	if data == null or str(data.card_type) != "Basic Energy":
		return false
	var provision := str(data.energy_provides)
	if provision == "":
		provision = str(data.energy_type)
	return provision == symbol


func _slot_has_energy_symbol_local(slot: PokemonSlot, symbol: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _is_basic_energy_symbol_local(energy, symbol):
			return true
	return false


func _matches(item: Variant, uids: Array[String], names: Array[String], effect_ids: Array[String]) -> bool:
	var data := _card_data(item)
	if data == null:
		return false
	var uid := "%s_%s" % [str(data.set_code), str(data.card_index)]
	if uid in uids or str(data.effect_id) in effect_ids:
		return true
	return str(data.name) in names or str(data.name_en) in names or str(data.name_zh) in names


func _card_data(item: Variant) -> CardData:
	if item is CardData:
		return item as CardData
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	return null
