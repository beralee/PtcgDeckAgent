class_name TestOpponentDeckFingerprintResolver
extends TestBase

const ResolverScript = preload("res://scripts/ai/OpponentDeckFingerprintResolver.gd")
const ProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")


func test_catalog_uses_exact_25_complete_v18_decks() -> String:
	ResolverScript.reset_catalog_cache_for_tests()
	var report: Dictionary = ResolverScript.catalog_report()
	var checks: Array[String] = [
		assert_true(bool(report.get("valid", false)), "Fingerprint catalog should load without errors: %s" % str(report.get("errors", []))),
		assert_eq(int(report.get("deck_count", 0)), 25, "Fingerprint scope must cover the exact 25 built-in V18 decks"),
	]
	var totals: Dictionary = report.get("deck_total_cards", {})
	for deck_id: int in ProfileCatalogScript.deck_ids():
		checks.append(assert_eq(int(totals.get(deck_id, 0)), 60, "Deck %d must contribute exactly 60 cards" % deck_id))
	return run_checks(checks)


func test_every_v18_deck_has_a_one_or_two_card_unique_fingerprint() -> String:
	var checks: Array[String] = []
	for deck_id: int in ProfileCatalogScript.deck_ids():
		var fingerprint: Dictionary = ResolverScript.minimal_unique_fingerprint(deck_id, 2)
		checks.append(assert_eq(str(fingerprint.get("status", "")), ResolverScript.STATUS_UNIQUE, "Deck %d should have a <=2-card fingerprint" % deck_id))
		checks.append(assert_true(int(fingerprint.get("evidence_card_count", 0)) in [1, 2], "Deck %d fingerprint should use one or two visible cards" % deck_id))
	return run_checks(checks)


func test_single_card_fingerprint_resolves_deck_and_strategy() -> String:
	var fingerprint: Dictionary = ResolverScript.minimal_unique_fingerprint(18000230, 1)
	var result: Dictionary = ResolverScript.classify_visible_cards(fingerprint.get("evidence", []))
	return run_checks([
		assert_eq(str(fingerprint.get("status", "")), ResolverScript.STATUS_UNIQUE, "The current Dragapult/Charizard list should have a one-card semantic fingerprint"),
		assert_eq(str(result.get("status", "")), ResolverScript.STATUS_UNIQUE, "A unique fingerprint card should resolve immediately"),
		assert_eq(int(result.get("deck_id", 0)), 18000230, "Resolved deck ID should be exact"),
		assert_eq(str(result.get("strategy_id", "")), "v18_18000230_dragapult_charizard", "Resolved strategy ID should come from the V18 profile"),
		assert_eq(int(result.get("evidence_card_count", 0)), 1, "The result should report its minimal one-card witness"),
	])


func test_two_ambiguous_cards_can_form_the_unique_minimal_witness() -> String:
	var fingerprint: Dictionary = ResolverScript.minimal_unique_fingerprint(800017097, 2)
	var evidence: Array = fingerprint.get("evidence", [])
	if evidence.size() != 2:
		return "Deck 800017097 should currently require the Ralts/Cleffa two-card witness, got %s" % str(evidence)
	var first: Dictionary = ResolverScript.classify_visible_cards([evidence[0]])
	var second: Dictionary = ResolverScript.classify_visible_cards([evidence[1]])
	var combined: Dictionary = ResolverScript.classify_visible_cards(evidence)
	return run_checks([
		assert_eq(str(first.get("status", "")), ResolverScript.STATUS_AMBIGUOUS, "The first card alone should remain ambiguous"),
		assert_eq(str(second.get("status", "")), ResolverScript.STATUS_AMBIGUOUS, "The second card alone should remain ambiguous"),
		assert_eq(str(combined.get("status", "")), ResolverScript.STATUS_UNIQUE, "The two-card intersection should be unique"),
		assert_eq(int(combined.get("deck_id", 0)), 800017097, "The pair should resolve the no-balloon Gardevoir list"),
		assert_eq(int(combined.get("evidence_card_count", 0)), 2, "The returned witness should remain minimal"),
	])


func test_conflicting_unique_cards_report_no_match() -> String:
	var left: Dictionary = ResolverScript.minimal_unique_fingerprint(18000230, 1)
	var right: Dictionary = ResolverScript.minimal_unique_fingerprint(18000625, 1)
	var visible: Array = []
	visible.append_array(left.get("evidence", []))
	visible.append_array(right.get("evidence", []))
	var result: Dictionary = ResolverScript.classify_visible_cards(visible)
	return run_checks([
		assert_eq(str(result.get("status", "")), ResolverScript.STATUS_NO_MATCH, "Cards that cannot coexist in any exact built-in list must not guess a deck"),
		assert_eq((result.get("candidate_deck_ids", []) as Array).size(), 0, "A contradictory observation should have no candidates"),
	])


func test_hidden_opponent_zones_are_never_used() -> String:
	var fingerprint: Dictionary = ResolverScript.minimal_unique_fingerprint(18000230, 1)
	var card := _card_from_evidence((fingerprint.get("evidence", []) as Array)[0])
	var state := _make_state()
	var opponent: PlayerState = state.players[1]
	opponent.hand.append(CardInstance.create(card, 1))
	opponent.deck.append(CardInstance.create(card, 1))
	opponent.prizes.append(CardInstance.create(card, 1))
	var result: Dictionary = ResolverScript.classify_game_state(state, 0)
	return run_checks([
		assert_eq(str(result.get("status", "")), ResolverScript.STATUS_UNKNOWN, "Hand, deck, and prizes are hidden and must not leak into inference"),
		assert_eq(int(result.get("observed_card_count", -1)), 0, "No hidden card should enter the public observation"),
	])


func test_public_board_cards_resolve_and_base_strategy_exposes_the_result() -> String:
	var fingerprint: Dictionary = ResolverScript.minimal_unique_fingerprint(800017097, 2)
	var evidence: Array = fingerprint.get("evidence", [])
	var state := _make_state()
	var opponent: PlayerState = state.players[1]
	opponent.active_pokemon = _slot(_card_from_evidence(evidence[0]), 1)
	opponent.bench.append(_slot(_card_from_evidence(evidence[1]), 1))
	var base := DeckStrategyBase.new()
	var result: Dictionary = base.resolve_opponent_deck(state, 0)
	return run_checks([
		assert_eq(str(result.get("status", "")), ResolverScript.STATUS_UNIQUE, "Active and Bench cards are public evidence"),
		assert_eq(int(result.get("deck_id", 0)), 800017097, "Base strategy API should return the exact opponent deck"),
		assert_true(base.opponent_is_deck(state, 0, 800017097), "Concrete strategies should have a one-line exact-deck predicate"),
		assert_true(base.opponent_uses_strategy(state, 0, "v18_800017097_no_balloon_gardevoir"), "Concrete strategies should have a one-line strategy predicate"),
		assert_false(base.opponent_is_deck(state, 0, 800018497), "The predicate must not match a sibling Gardevoir list"),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	var observer := PlayerState.new()
	observer.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [observer, opponent]
	return state


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot


func _card_from_evidence(evidence: Dictionary) -> CardData:
	var card := CardData.new()
	card.name = str(evidence.get("name", evidence.get("display_name", "Fingerprint Card")))
	card.name_en = str(evidence.get("name_en", evidence.get("display_name", "")))
	card.effect_id = str(evidence.get("effect_id", ""))
	card.card_type = str(evidence.get("card_type", "Pokemon"))
	card.stage = "Basic" if card.card_type == "Pokemon" else ""
	var uid := str(evidence.get("uid", ""))
	var separator := uid.find("_")
	if separator > 0:
		card.set_code = uid.substr(0, separator)
		card.card_index = uid.substr(separator + 1)
	return card
