class_name TestV18PureDragapultDiscardGuardRound1
extends TestBase


const STRATEGY_REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FIXED_ORDER_REGISTRY_SCRIPT = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const DECK_ID := 800018499
const DECK_PATH := "res://data/bundled_user/decks/800018499.json"
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategy175PureDragapult.gd"
const LUMINOUS_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"
const NEO_UPPER_EFFECT_ID := "83aba7d0c92c81e8c03b3785af695c2f"

const EXPECTED_OPENING: Array[String] = [
	"CSV9.5C_004",
	"CSV8C_157",
	"CSV7C_177",
	"CSV1C_112",
	"CSVE1C_FIR",
	"CSVE1C_PSY",
	"CSV8C_094",
]


func test_round1_fixed_prefix_discards_fodder_and_searches_drakloak() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production Registry")
	var fixed_order: Array[Dictionary] = FIXED_ORDER_REGISTRY_SCRIPT.new().load_fixed_order(DECK_ID)
	var opening_uids := _order_uids(fixed_order.slice(0, 7))
	var state := _base_state(1)
	var player: PlayerState = state.players[0]
	for uid: String in opening_uids:
		player.hand.append(_real_card(uid, 0))
	var setup: Dictionary = strategy.call("plan_opening_setup", player)
	_apply_opening_setup(player, setup)
	var first_bridge := _real_card(_entry_uid(fixed_order[13]), 0)
	player.hand.append(first_bridge)

	var ultra_ball := _find_hand_card(player, "CSV1C_112")
	var fire := _find_hand_card(player, "CSVE1C_FIR")
	var psychic := _find_hand_card(player, "CSVE1C_PSY")
	var munkidori := _find_hand_card(player, "CSV8C_094")
	var discard_candidates: Array = player.hand.duplicate()
	discard_candidates.erase(ultra_ball)
	var context := {"game_state": state, "player_index": 0}
	var discards: Array = strategy.call("pick_interaction_items", discard_candidates, {
		"id": "discard_cards",
		"min_select": 2,
		"max_select": 2,
	}, context)

	var drakloak := _real_card("CSV8C_158", 0)
	var dragapult := _real_card("CSV8C_159", 0)
	player.deck.assign([drakloak, dragapult])
	var searched: Array = strategy.call("pick_interaction_items", [drakloak, dragapult], {
		"id": "search_pokemon",
		"min_select": 0,
		"max_select": 1,
	}, context)
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "The production Registry must return the V18 rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "Deck 800018499 must keep its mature Pure Dragapult delegate"),
		assert_eq(opening_uids, EXPECTED_OPENING, "The test must use the real R1 fixed opening prefix"),
		assert_eq(_slot_uid(player.active_pokemon), "CSV9.5C_004", "The real fixed opening should keep Budew Active"),
		assert_true(_field_has_uid(player, "CSV8C_157"), "The real fixed opening should preserve a Dreepy route"),
		assert_eq(discards.size(), 2, "Ultra Ball should still receive two discard choices"),
		assert_true(munkidori in discards, "R1 Ultra Ball should spend Munkidori fodder before its only RP payment"),
		assert_false(fire in discards, "R1 Ultra Ball must preserve the only Fire payment"),
		assert_false(psychic in discards, "R1 Ultra Ball must preserve the only Psychic payment"),
		assert_eq(_card_uid(searched[0]) if not searched.is_empty() else "", "CSV8C_158", "With Dreepy alive and no Rare Candy, Ultra Ball should search Drakloak"),
	])


func test_payment_combinations_keep_only_route_critical_energy() -> String:
	var strategy := _production_strategy()
	var delegate := _delegate(strategy)
	if strategy == null or delegate == null:
		return assert_true(false, "Pure Dragapult production strategy and delegate should instantiate")
	var state := _base_state(1)
	var player: PlayerState = state.players[0]
	var dreepy := _slot(_real_card("CSV8C_157", 0))
	player.bench.append(dreepy)
	var fire := _real_card("CSVE1C_FIR", 0)
	var psychic := _real_card("CSVE1C_PSY", 0)
	var luminous := _real_card("CSV1C_127", 0)
	var neo_upper := _real_card("CSV7C_203", 0)
	var any_energy := _energy("Test Any Energy", "ANY")

	player.hand.assign([fire, psychic, luminous])
	var three_way: Array = delegate.call("_v175_first_attack_payment_combinations", player, dreepy)
	var after_fire: Array = delegate.call("_v175_first_attack_payment_combinations", player, dreepy, fire)
	player.hand.assign([luminous, _real_card("CSV1C_127", 0)])
	var suppressed_luminous: Array = delegate.call("_v175_first_attack_payment_combinations", player, dreepy)
	player.hand.assign([neo_upper])
	var neo_only: Array = delegate.call("_v175_first_attack_payment_combinations", player, dreepy)
	player.hand.assign([fire, any_energy])
	var generic_any: Array = delegate.call("_v175_first_attack_payment_combinations", player, dreepy)

	player.hand.assign([psychic, luminous, _real_card("CSV8C_094", 0)])
	var psychic_priority := int(strategy.call("get_discard_priority_contextual", psychic, state, 0))
	var luminous_priority := int(strategy.call("get_discard_priority_contextual", luminous, state, 0))
	var fodder_priority := int(strategy.call("get_discard_priority_contextual", player.hand[2], state, 0))
	player.hand.assign([neo_upper, _real_card("CSV8C_094", 0)])
	var neo_priority := int(strategy.call("get_discard_priority_contextual", neo_upper, state, 0))
	return run_checks([
		assert_eq(three_way.size(), 3, "R+P, R+ANY, and P+ANY should be three distinct first-attack payments"),
		assert_true(not after_fire.is_empty(), "P+Luminous should survive removing a redundant Fire"),
		assert_true(suppressed_luminous.is_empty(), "Two Luminous Energy must suppress each other and cannot pay RP"),
		assert_eq(neo_only.size(), 1, "Neo Upper alone should pay both RP requirements after the route reaches Stage 2"),
		assert_eq(generic_any.size(), 1, "A generic ANY plus Fire should pay the missing Psychic requirement"),
		assert_true(psychic_priority < fodder_priority, "The only Psychic half of P+Luminous must survive discard costs"),
		assert_true(luminous_priority < fodder_priority, "Effect-ID Luminous must survive when it is the only Fire half"),
		assert_true(neo_priority < fodder_priority, "Effect-ID Neo Upper must survive when it is the only RP payment"),
	])


func test_duplicate_stage2_and_munkidori_are_r1_discard_fodder() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Pure Dragapult production strategy should instantiate")
	var fixed_order: Array[Dictionary] = FIXED_ORDER_REGISTRY_SCRIPT.new().load_fixed_order(DECK_ID)
	var state := _base_state(1)
	var player: PlayerState = state.players[0]
	player.bench.append(_slot(_real_card("CSV8C_157", 0)))
	var fire := _real_card("CSVE1C_FIR", 0)
	var psychic := _real_card("CSVE1C_PSY", 0)
	var munkidori := _real_card("CSV8C_094", 0)
	var dragapult_a := _real_card(_entry_uid(fixed_order[13]), 0)
	var dragapult_b := _real_card(_entry_uid(fixed_order[14]), 0)
	player.hand.assign([fire, psychic, munkidori, dragapult_a, dragapult_b])
	var picked: Array = strategy.call("pick_interaction_items", player.hand, {
		"id": "discard_cards",
		"min_select": 2,
		"max_select": 2,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(munkidori in picked, "Munkidori should be first-route Ultra Ball fodder"),
		assert_true(dragapult_a in picked or dragapult_b in picked, "One duplicate Stage 2 should be spent before the only RP payment"),
		assert_false(fire in picked, "Duplicate Stage 2 fodder should preserve Fire"),
		assert_false(psychic in picked, "Duplicate Stage 2 fodder should preserve Psychic"),
	])


func test_real_special_energy_effects_pay_dragapult_rp_cost() -> String:
	var state := _base_state(3)
	var dragapult := _slot(_real_card("CSV8C_159", 0))
	state.players[0].active_pokemon = dragapult
	var fire := _real_card("CSVE1C_FIR", 0)
	var luminous := _real_card("CSV1C_127", 0)
	var neo_upper := _real_card("CSV7C_203", 0)
	var validator := RuleValidator.new()
	var processor := EffectProcessor.new()
	dragapult.attached_energy.assign([fire, luminous])
	var luminous_pays := validator.has_enough_energy(dragapult, "RP", processor, state)
	dragapult.attached_energy.assign([neo_upper])
	var neo_pays := validator.has_enough_energy(dragapult, "RP", processor, state)
	return run_checks([
		assert_eq(str(luminous.card_data.effect_id), LUMINOUS_EFFECT_ID, "The guard must anchor real Luminous by effect ID"),
		assert_eq(str(neo_upper.card_data.effect_id), NEO_UPPER_EFFECT_ID, "The guard must anchor real Neo Upper by effect ID"),
		assert_true(luminous_pays, "Real Luminous should flex to Psychic beside basic Fire"),
		assert_true(neo_pays, "Real Neo Upper should provide two ANY units on Stage 2 Dragapult"),
	])


func _production_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	return STRATEGY_REGISTRY_SCRIPT.new().resolve_strategy_for_deck(DeckData.from_dict(parsed))


func _delegate(strategy: RefCounted) -> RefCounted:
	if strategy == null:
		return null
	var value: Variant = strategy.get("_delegate")
	return value as RefCounted if value is RefCounted else null


func _delegate_path(strategy: RefCounted) -> String:
	var value := _delegate(strategy)
	return value.get_script().resource_path if value != null else ""


func _base_state(turn_number: int) -> GameState:
	var state := GameState.new()
	state.turn_number = turn_number
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_basic("Opponent", 1))
	return state


func _apply_opening_setup(player: PlayerState, setup: Dictionary) -> void:
	var active_index := int(setup.get("active_hand_index", -1))
	var bench_indices: Array = setup.get("bench_hand_indices", [])
	var original_hand: Array[CardInstance] = player.hand.duplicate()
	player.active_pokemon = _slot(original_hand[active_index])
	for raw_index: Variant in bench_indices:
		player.bench.append(_slot(original_hand[int(raw_index)]))
	player.hand.clear()
	for index: int in original_hand.size():
		if index != active_index and index not in bench_indices:
			player.hand.append(original_hand[index])


func _real_card(uid: String, owner_index: int) -> CardInstance:
	var parts := uid.rsplit("_", true, 1)
	var card_data: CardData = CardDatabase.get_card(parts[0], parts[1]) if parts.size() == 2 else null
	return CardInstance.create(card_data, owner_index) if card_data != null else null


func _energy(card_name: String, provides: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.name_en = card_name
	card_data.card_type = "Special Energy"
	card_data.energy_provides = provides
	return CardInstance.create(card_data, 0)


func _basic(card_name: String, owner_index: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.name_en = card_name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 100
	return CardInstance.create(card_data, owner_index)


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(card)
	return slot


func _find_hand_card(player: PlayerState, uid: String) -> CardInstance:
	for card: CardInstance in player.hand:
		if _card_uid(card) == uid:
			return card
	return null


func _field_has_uid(player: PlayerState, uid: String) -> bool:
	if _slot_uid(player.active_pokemon) == uid:
		return true
	for slot: PokemonSlot in player.bench:
		if _slot_uid(slot) == uid:
			return true
	return false


func _slot_uid(slot: PokemonSlot) -> String:
	return _card_uid(slot.get_top_card()) if slot != null else ""


func _card_uid(card: CardInstance) -> String:
	return card.card_data.get_uid() if card != null and card.card_data != null else ""


func _order_uids(order: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in order:
		result.append(_entry_uid(entry))
	return result


func _entry_uid(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
