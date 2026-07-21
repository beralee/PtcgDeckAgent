class_name TestV18HopZacianStrongFixedOrderIteration
extends TestBase


const PROFILE_CATALOG = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const STRATEGY_REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FIXED_ORDER_REGISTRY_SCRIPT = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")
const AI_OPPONENT_SCRIPT = preload("res://scripts/ai/AIOpponent.gd")

const DECK_ID := 800017407
const DECK_PATH := "res://data/bundled_user/decks/800017407.json"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18HopFroslass.gd"

const EXPECTED_OPENING: Array[String] = [
	"CSV10C_218", "CSV10C_161", "CSV10C_201", "CSV10C_201",
	"CSVE1C_DAR", "CSV4C_129", "CSV10C_175",
]
const EXPECTED_PRIZES: Array[String] = [
	"CSV3C_129", "CSV2C_113", "CSV8C_183",
	"CSVH1aC_023", "CSV10C_218", "CSV1C_123",
]
const EXPECTED_BRIDGE: Array[String] = [
	"CSV10C_161", "CSV8C_094", "CSVE1C_DAR",
	"CSV10C_195", "CSV10C_175", "CSVE1C_DAR",
]


func test_fixed_order_is_the_exact_complete_production_deck() -> String:
	var deck := _load_deck()
	var strategy := _resolve_strategy(deck)
	var profile: Dictionary = PROFILE_CATALOG.get_profile_for_deck(DECK_ID)
	var strong_order: Dictionary = profile.get("strong_order", {})
	var fixed_order: Array[Dictionary] = FIXED_ORDER_REGISTRY_SCRIPT.new().load_fixed_order(DECK_ID)
	var checks: Array[String] = [
		assert_not_null(deck, "Hop Zacian's production deck JSON should parse"),
		assert_not_null(strategy, "Hop Zacian should resolve through the production strategy registry"),
		assert_eq(
			str(strategy.call("get_strategy_id")) if strategy != null else "",
			"v18_800017407_hops_zacian",
			"The production registry should retain the Hop Zacian profile identity"
		),
		assert_eq(strong_order.get("opening_cards", []), EXPECTED_OPENING, "The catalog should pin the diagnosed opening seven"),
		assert_eq(strong_order.get("bridge_cards", []), EXPECTED_BRIDGE, "The catalog should preserve the diagnosed bridge six"),
	]
	if deck == null:
		return run_checks(checks)

	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	var order_uids := _order_uids(fixed_order)
	var expected_prefix: Array[String] = []
	expected_prefix.append_array(EXPECTED_OPENING)
	expected_prefix.append_array(EXPECTED_PRIZES)
	expected_prefix.append_array(EXPECTED_BRIDGE)
	checks.append(assert_eq(delegate.get_script().resource_path if delegate != null else "", DELEGATE_PATH, "The production wrapper should use the Hop/Froslass family delegate"))
	checks.append(assert_eq(order_uids.size(), 60, "The strong fixed order should contain all 60 cards"))
	checks.append(assert_eq(_uid_counts(order_uids), _deck_counts(deck), "The fixed order should preserve every production multiplicity"))
	checks.append(assert_eq(order_uids.slice(0, 7), EXPECTED_OPENING, "Cards 1-7 should be the exact opening hand"))
	checks.append(assert_eq(order_uids.slice(7, 13), EXPECTED_PRIZES, "Cards 8-13 should be the exact controlled prizes"))
	checks.append(assert_eq(order_uids.slice(13, 19), EXPECTED_BRIDGE, "Cards 14-19 should preserve the diagnosed bridge"))
	checks.append(assert_eq(order_uids.slice(0, 19), expected_prefix, "The complete controlled prefix should remain exact"))
	return run_checks(checks)


func test_registry_scoring_preserves_the_band_dark_band_chain_for_both_seats() -> String:
	var checks: Array[String] = []
	for seat: int in [0, 1]:
		var fixture := _runtime_fixture(seat)
		var gsm: GameStateMachine = fixture.get("gsm", null)
		var ai: RefCounted = fixture.get("ai", null)
		var strategy: RefCounted = fixture.get("strategy", null)
		var player: PlayerState = fixture.get("player", null)
		var zacian: PokemonSlot = fixture.get("zacian", null)
		var snorlax: PokemonSlot = fixture.get("snorlax", null)
		checks.append(assert_not_null(strategy, "Seat %d should resolve Hop Zacian through the production registry" % seat))
		if gsm == null or ai == null or strategy == null or player == null or zacian == null or snorlax == null:
			continue

		var opening_actions: Array[Dictionary] = ai.call("get_legal_actions", gsm)
		var band_zacian := _find_action(opening_actions, "attach_tool", "CSV10C_201", zacian)
		var band_snorlax := _find_action(opening_actions, "attach_tool", "CSV10C_201", snorlax)
		checks.append(assert_false(band_zacian.is_empty(), "Seat %d should have a legal first Band attachment to Zacian" % seat))
		checks.append(assert_true(
			_score(strategy, band_zacian, gsm.game_state, seat) > _score(strategy, band_snorlax, gsm.game_state, seat),
			"Seat %d should assign the first Band to Zacian before Snorlax" % seat
		))
		_apply_tool(player, band_zacian)

		var energy_actions: Array[Dictionary] = ai.call("get_legal_actions", gsm)
		var dark_snorlax := _find_action(energy_actions, "attach_energy", "CSVE1C_DAR", snorlax)
		var dark_zacian := _find_action(energy_actions, "attach_energy", "CSVE1C_DAR", zacian)
		var jet_snorlax := _find_action(energy_actions, "attach_energy", "CSV4C_129", snorlax)
		var dark_score := _score(strategy, dark_snorlax, gsm.game_state, seat)
		var jet_score := _score(strategy, jet_snorlax, gsm.game_state, seat)
		checks.append(assert_false(dark_snorlax.is_empty(), "Seat %d should expose Darkness Energy for Snorlax" % seat))
		checks.append(assert_false(jet_snorlax.is_empty(), "Seat %d should expose Jet Energy for Snorlax" % seat))
		checks.append(assert_true(dark_score > _score(strategy, dark_zacian, gsm.game_state, seat), "Seat %d should send Energy to Snorlax after Zacian receives the first Band" % seat))
		checks.append(assert_eq(dark_score, jet_score, "Seat %d should retain the diagnosed Dark/Jet score tie on Snorlax" % seat))
		checks.append(assert_true(
			_action_index(energy_actions, dark_snorlax) < _action_index(energy_actions, jet_snorlax),
			"Seat %d should expose Dark before Jet so the production strict-greater tie break keeps Dark" % seat
		))
		_apply_energy(gsm.game_state, player, dark_snorlax)

		var second_band_actions: Array[Dictionary] = ai.call("get_legal_actions", gsm)
		var second_band_snorlax := _find_action(second_band_actions, "attach_tool", "CSV10C_201", snorlax)
		var second_band_zacian := _find_action(second_band_actions, "attach_tool", "CSV10C_201", zacian)
		checks.append(assert_false(second_band_snorlax.is_empty(), "Seat %d should retain the second Band for the powered Snorlax" % seat))
		checks.append(assert_true(second_band_zacian.is_empty(), "Seat %d should not expose a second Tool attachment to the already banded Zacian" % seat))
		_apply_tool(player, second_band_snorlax)

		gsm.game_state.turn_number += 2
		gsm.game_state.energy_attached_this_turn = false
		var next_turn_actions: Array[Dictionary] = ai.call("get_legal_actions", gsm)
		var next_turn_jet := _find_action(next_turn_actions, "attach_energy", "CSV4C_129", snorlax)
		var slash := _find_attack(next_turn_actions, "刹那斩")
		checks.append(assert_false(next_turn_jet.is_empty(), "Seat %d should retain the next-turn Jet attachment to Snorlax" % seat))
		if not slash.is_empty():
			checks.append(assert_false(bool(slash.get("projected_knockout", true)), "Seat %d Slash fixture should remain non-KO" % seat))
			checks.append(assert_true(
				_score(strategy, next_turn_jet, gsm.game_state, seat) > _score(strategy, slash, gsm.game_state, seat),
				"Seat %d should complete Snorlax with Jet before taking a non-KO Slash" % seat
			))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_turn_plan_reads_the_requested_player_seat() -> String:
	var deck := _load_deck()
	var strategy := _resolve_strategy(deck)
	if strategy == null:
		return assert_true(false, "Hop Zacian should resolve through the production strategy registry")
	var state := _base_state()
	var player_zero: PlayerState = state.players[0]
	var player_one: PlayerState = state.players[1]
	player_zero.active_pokemon = _slot(_real_card("CSV10C_161", 0))
	player_one.active_pokemon = _slot(_real_card("CSV10C_161", 1))
	player_one.bench.append(_slot(_real_card("CSV10C_175", 1)))
	var zero_plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"requested_seat": 0})
	var one_plan: Dictionary = strategy.call("build_turn_contract", state, 1, {"requested_seat": 1})
	return run_checks([
		assert_eq(int((zero_plan.get("flags", {}) as Dictionary).get("setup_debt", -1)), 1, "Seat 0 should report its own missing Snorlax debt"),
		assert_eq(str((zero_plan.get("owner", {}) as Dictionary).get("bridge_target_name", "")), "赫普的卡比兽", "Seat 0 should bridge to its missing Snorlax"),
		assert_eq(int((one_plan.get("flags", {}) as Dictionary).get("setup_debt", -1)), 0, "Seat 1 should see its own complete Zacian/Snorlax shell"),
		assert_eq(str((one_plan.get("owner", {}) as Dictionary).get("turn_owner_name", "")), "赫普的卡比兽", "Seat 1 should plan around its own Snorlax field"),
		assert_eq(int((zero_plan.get("context", {}) as Dictionary).get("requested_seat", -1)), 0, "Seat 0 plan context should remain seat-specific"),
		assert_eq(int((one_plan.get("context", {}) as Dictionary).get("requested_seat", -1)), 1, "Seat 1 plan context should remain seat-specific"),
	])


func _runtime_fixture(seat: int) -> Dictionary:
	var deck := _load_deck()
	var strategy := _resolve_strategy(deck)
	var gsm := GameStateMachine.new()
	var state := _base_state()
	gsm.game_state = state
	state.current_player_index = seat
	state.first_player_index = seat
	var player: PlayerState = state.players[seat]
	var opponent: PlayerState = state.players[1 - seat]
	var zacian := _slot(_real_card("CSV10C_161", seat))
	var snorlax := _slot(_real_card("CSV10C_175", seat))
	player.active_pokemon = zacian
	player.bench.append(snorlax)
	player.hand.assign([
		_real_card("CSV10C_218", seat),
		_real_card("CSV10C_201", seat),
		_real_card("CSV10C_201", seat),
		_real_card("CSVE1C_DAR", seat),
		_real_card("CSV4C_129", seat),
	])
	for _index: int in 12:
		player.deck.append(_real_card("CSV1C_123", seat))
	opponent.active_pokemon = _opponent_slot(1 - seat)

	var ai: RefCounted = AI_OPPONENT_SCRIPT.new()
	ai.call("configure", seat, 1)
	ai.set("decision_runtime_mode", "rules_only")
	ai.call("set_deck_strategy", strategy)
	return {
		"gsm": gsm,
		"ai": ai,
		"strategy": strategy,
		"player": player,
		"zacian": zacian,
		"snorlax": snorlax,
	}


func _base_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	state.energy_attached_this_turn = false
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		for prize_index: int in 6:
			player.prizes.append(_filler_card("Prize %d" % prize_index, player_index))
		state.players.append(player)
	return state


func _resolve_strategy(deck: DeckData) -> RefCounted:
	if deck == null:
		return null
	return STRATEGY_REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", deck)


func _load_deck() -> DeckData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _real_card(uid: String, owner_index: int) -> CardInstance:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % uid))
	var card_data := CardData.from_dict(parsed) if parsed is Dictionary else CardData.new()
	return CardInstance.create(card_data, owner_index)


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _opponent_slot(owner_index: int) -> PokemonSlot:
	var card_data := CardData.new()
	card_data.name = "Regression Defender"
	card_data.name_en = "Regression Defender"
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 330
	card_data.attacks = [{"name": "Wait", "cost": "C", "damage": "10"}]
	return _slot(CardInstance.create(card_data, owner_index))


func _filler_card(card_name: String, owner_index: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.name_en = card_name
	card_data.card_type = "Item"
	return CardInstance.create(card_data, owner_index)


func _find_action(
	actions: Array[Dictionary],
	kind: String,
	uid: String,
	target: PokemonSlot
) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == kind \
				and _card_uid(action.get("card", null)) == uid \
				and action.get("target_slot", null) == target:
			return action
	return {}


func _find_attack(actions: Array[Dictionary], attack_name: String) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "attack" and str(action.get("attack_name", "")) == attack_name:
			return action
	return {}


func _action_index(actions: Array[Dictionary], wanted: Dictionary) -> int:
	for index: int in actions.size():
		if actions[index] == wanted:
			return index
	return -1


func _score(
	strategy: RefCounted,
	action: Dictionary,
	state: GameState,
	player_index: int
) -> float:
	if strategy == null or action.is_empty():
		return -INF
	var contract: Dictionary = strategy.call("build_turn_contract", state, player_index, {"strong_fixed_opening": true})
	return float(strategy.call("score_action_absolute_with_plan", action, state, player_index, contract))


func _apply_tool(player: PlayerState, action: Dictionary) -> void:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if card == null or target == null:
		return
	player.hand.erase(card)
	target.attached_tool = card


func _apply_energy(state: GameState, player: PlayerState, action: Dictionary) -> void:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if card == null or target == null:
		return
	player.hand.erase(card)
	target.attached_energy.append(card)
	state.energy_attached_this_turn = true


func _card_uid(item: Variant) -> String:
	if item is CardInstance and (item as CardInstance).card_data != null:
		return (item as CardInstance).card_data.get_uid()
	return ""


func _order_uids(order: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in order:
		result.append(_entry_uid(entry))
	return result


func _deck_counts(deck: DeckData) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in deck.cards:
		counts[_entry_uid(entry)] = int(entry.get("count", 0))
	return counts


func _uid_counts(uids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for raw_uid: Variant in uids:
		var uid := str(raw_uid)
		counts[uid] = int(counts.get(uid, 0)) + 1
	return counts


func _entry_uid(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
