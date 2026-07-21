class_name TestV18Stage2CoreRound2
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_buddy_poffin_covers_two_distinct_stage2_families_before_backups() -> String:
	var strategy := _load_strategy()
	var basics := _load_chain_basics()
	var checks: Array[String] = _load_checks(strategy, basics)
	if strategy == null or basics.size() != 3:
		return run_checks(checks)

	var candidates := _two_copies_each(basics)
	var picked: Array = strategy.call(
		"pick_interaction_items",
		candidates,
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": _make_state(), "player_index": 0}
	)
	var picked_uids := _picked_uids(picked)
	checks.append(assert_eq(picked.size(), 2, "Buddy-Buddy Poffin should take both available search slots"))
	checks.append(assert_eq(_unique_count(picked_uids), 2, "Buddy-Buddy Poffin should cover two distinct evolution families before taking a same-name backup"))
	return run_checks(checks)


func test_precious_trolley_covers_all_three_stage2_families_before_backups() -> String:
	var strategy := _load_strategy()
	var basics := _load_chain_basics()
	var checks: Array[String] = _load_checks(strategy, basics)
	if strategy == null or basics.size() != 3:
		return run_checks(checks)

	var candidates := _two_copies_each(basics)
	var picked: Array = strategy.call(
		"pick_interaction_items",
		candidates,
		{"id": "csv9c186_basic_pokemon", "max_select": 4},
		{"game_state": _make_state(), "player_index": 0}
	)
	var first_three: Array = picked.slice(0, mini(3, picked.size()))
	var first_three_uids := _picked_uids(first_three)
	var all_picked_uids := _picked_uids(picked)
	checks.append(assert_eq(picked.size(), 4, "Precious Trolley should fill all four available search slots"))
	checks.append(assert_eq(_unique_count(first_three_uids), 3, "Precious Trolley should cover Swinub, Torchic, and Pidgey before taking a backup"))
	checks.append(assert_eq(_unique_count(all_picked_uids), 3, "Precious Trolley should include all three Stage 2 seed identities"))
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck) if deck != null else null


func _load_chain_basics() -> Array[CardData]:
	var basics: Array[CardData] = []
	for card: CardData in [
		CardDatabase.get_card("CSV10C", "102"),
		CardDatabase.get_card("CSV7C", "036"),
		CardDatabase.get_card("151C", "016"),
	]:
		if card != null:
			basics.append(card)
	return basics


func _load_checks(strategy: RefCounted, basics: Array[CardData]) -> Array[String]:
	return [
		assert_not_null(strategy, "Deck 800017047 should resolve its V18 strategy"),
		assert_eq(basics.size(), 3, "Swinub, Torchic, and Pidgey should load"),
	]


func _two_copies_each(basics: Array[CardData]) -> Array:
	var candidates: Array = []
	for basic: CardData in basics:
		candidates.append(CardInstance.create(basic, 0))
		candidates.append(CardInstance.create(basic, 0))
	return candidates


func _picked_uids(picked: Array) -> Array[String]:
	var result: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance and (item as CardInstance).card_data != null:
			result.append((item as CardInstance).card_data.get_uid())
	return result


func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value: String in values:
		unique[value] = true
	return unique.size()


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	return state
