class_name TestV18CharizardDragapultStrongFixedOrderRound2
extends TestBase


const PROFILE_CATALOG = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const STRATEGY_REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FIXED_ORDER_REGISTRY_SCRIPT = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const DECK_ID := 18000230
const DECK_PATH := "res://data/bundled_user/decks/18000230.json"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyDragapultCharizard.gd"

const EXPECTED_OPENING: Array[String] = [
	"CSV8C_157", "CSV8C_157", "151C_004", "CSV5C_015",
	"CSVH1C_045", "CSVE1C_FIR", "CSV1C_127",
]
const EXPECTED_PRIZES: Array[String] = [
	"CSVH1aC_023", "CSV3C_123", "CSVE1C_FIR",
	"CSV1C_123", "CSV8C_158", "CSV1C_112",
]
const EXPECTED_BRIDGE: Array[String] = [
	"CSV8C_159", "CSV5C_075", "CSV8C_158",
	"CSVH1C_045", "CSV1C_127", "CSV1C_127",
]


func test_round2_fixed_order_is_a_legal_dual_stage2_route() -> String:
	var deck := _load_deck()
	var strategy := _resolve_strategy(deck)
	var profile: Dictionary = PROFILE_CATALOG.get_profile_for_deck(DECK_ID)
	var strong_order: Dictionary = profile.get("strong_order", {})
	var fixed_order: Array[Dictionary] = FIXED_ORDER_REGISTRY_SCRIPT.new().load_fixed_order(DECK_ID)
	var order_uids := _order_uids(fixed_order)
	var opening := order_uids.slice(0, 7)
	var prizes := order_uids.slice(7, 13)
	var bridge := order_uids.slice(13, 19)
	var expected_prefix: Array[String] = []
	expected_prefix.append_array(EXPECTED_OPENING)
	expected_prefix.append_array(EXPECTED_PRIZES)
	expected_prefix.append_array(EXPECTED_BRIDGE)
	return run_checks([
		assert_not_null(deck, "Charizard/Dragapult production deck JSON should parse"),
		assert_not_null(strategy, "Charizard/Dragapult should resolve through the production registry"),
		assert_eq(
			str(strategy.call("get_strategy_id")) if strategy != null else "",
			"v18_18000230_dragapult_charizard",
			"The production wrapper should retain the exact V18 profile identity"
		),
		assert_eq(strong_order.get("opening_cards", []), EXPECTED_OPENING, "The catalog should pin the diagnosed opening seven"),
		assert_eq(strong_order.get("bridge_cards", []), EXPECTED_BRIDGE, "The catalog should pin the diagnosed bridge six"),
		assert_eq(order_uids.size(), 60, "The fixed order should contain the complete production deck"),
		assert_eq(_uid_counts(order_uids), _deck_counts(deck), "The fixed order should preserve every deck multiplicity"),
		assert_eq(opening, EXPECTED_OPENING, "Cards 1-7 should be the exact dual-Stage-2 opening"),
		assert_eq(prizes, EXPECTED_PRIZES, "Cards 8-13 should be the controlled safe prize block"),
		assert_eq(bridge, EXPECTED_BRIDGE, "Cards 14-19 should be the exact dual-Stage-2 bridge"),
		assert_eq(order_uids.slice(0, 19), expected_prefix, "The complete controlled prefix should remain exact"),
		assert_false("CSV9.5C_004" in opening, "Round 2 should remove Budew from the opening hand"),
		assert_false("CSV1C_127" in prizes, "The controlled prizes must not pin Luminous Energy"),
	])


func test_production_wrapper_opens_dreepy_with_both_backup_routes() -> String:
	var deck := _load_deck()
	var strategy := _resolve_strategy(deck)
	if strategy == null:
		return assert_true(false, "Charizard/Dragapult should resolve through the production registry")
	var delegate: RefCounted = strategy.get("_delegate")
	var player := PlayerState.new()
	for uid: String in EXPECTED_OPENING:
		player.hand.append(_real_card(uid, 0))
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var active_index := int(plan.get("active_hand_index", -1))
	var bench_indices: Array = plan.get("bench_hand_indices", [])
	return run_checks([
		assert_eq(delegate.get_script().resource_path if delegate != null else "", DELEGATE_PATH, "The wrapper should preserve the mature production delegate"),
		assert_eq(_hand_uid(player, active_index), "CSV8C_157", "The first Dreepy should be Active"),
		assert_true(_bench_contains_uid(player, bench_indices, "CSV8C_157"), "The second Dreepy should seed the backup Dragapult route"),
		assert_true(_bench_contains_uid(player, bench_indices, "151C_004"), "Charmander should seed the backup Charizard route"),
		assert_eq(bench_indices.size(), 2, "Only the two backup Basics should be Benched"),
	])


func test_fire_plus_luminous_unlocks_phantom_dive_before_jet_head() -> String:
	var deck := _load_deck()
	var strategy := _resolve_strategy(deck)
	if strategy == null:
		return assert_true(false, "Charizard/Dragapult should resolve through the production registry")
	var state := _base_state()
	var player: PlayerState = state.players[0]
	var dragapult := _slot(_real_card("CSV8C_159", 0))
	var fire := _real_card("CSVE1C_FIR", 0)
	var luminous := _real_card("CSV1C_127", 0)
	player.active_pokemon = dragapult
	dragapult.attached_energy.append(fire)
	var validator := RuleValidator.new()
	var processor := EffectProcessor.new()
	var jet_before := validator.can_use_attack(state, 0, 0, processor)
	var phantom_before := validator.can_use_attack(state, 0, 1, processor)
	dragapult.attached_energy.append(luminous)
	var phantom_after := validator.can_use_attack(state, 0, 1, processor)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"strong_fixed_opening": true})
	var jet_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": dragapult,
		"attack_index": 0,
		"attack_name": "Jet Head",
		"projected_damage": 70,
	}, state, 0, plan))
	var phantom_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": dragapult,
		"attack_index": 1,
		"attack_name": "Phantom Dive",
		"projected_damage": 200,
	}, state, 0, plan))
	return run_checks([
		assert_true(jet_before, "One Fire Energy should already make Jet Head legal"),
		assert_false(phantom_before, "One Fire Energy alone must not pay Phantom Dive's Fire/Psychic cost"),
		assert_true(phantom_after, "Real Luminous Energy should flex to Psychic and unlock Phantom Dive"),
		assert_true(phantom_score > jet_score, "The mature production delegate should choose unlocked Phantom Dive before Jet Head"),
	])


func _base_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		for prize_index: int in 6:
			player.prizes.append(_filler_card("Prize %d" % prize_index, player_index))
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_opponent_card(1))
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


func _opponent_card(owner_index: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = "Round 2 Defender"
	card_data.name_en = "Round 2 Defender"
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 330
	card_data.attacks = [{"name": "Wait", "cost": "C", "damage": "10"}]
	return CardInstance.create(card_data, owner_index)


func _filler_card(card_name: String, owner_index: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.name_en = card_name
	card_data.card_type = "Item"
	return CardInstance.create(card_data, owner_index)


func _hand_uid(player: PlayerState, hand_index: int) -> String:
	if player == null or hand_index < 0 or hand_index >= player.hand.size():
		return ""
	return _card_uid(player.hand[hand_index])


func _bench_contains_uid(player: PlayerState, indices: Array, uid: String) -> bool:
	for raw_index: Variant in indices:
		if _hand_uid(player, int(raw_index)) == uid:
			return true
	return false


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
	if deck == null:
		return counts
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
