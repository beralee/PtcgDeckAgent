class_name TestPalkiaGholdengoAuthorCandidate
extends TestBase


const STRATEGY_REGISTRY_SCRIPT := preload("res://scripts/ai/DeckStrategyRegistry.gd")
const EXPECTED_STRATEGY_ID := "palkia_gholdengo_author_v1"


func test_575479_resolves_to_independently_named_author_candidate() -> String:
	var registry := STRATEGY_REGISTRY_SCRIPT.new()
	var deck := DeckData.new()
	deck.id = 575479
	deck.deck_name = "Gholdengo Palkia author candidate"
	deck.total_cards = 60
	var resolved_id := str(registry.resolve_strategy_id_for_deck(deck))
	var strategy = registry.resolve_strategy_for_deck(deck)
	return run_checks([
		assert_eq(resolved_id, EXPECTED_STRATEGY_ID, "Deck 575479 should resolve to its author-strategy candidate"),
		assert_not_null(strategy, "Deck 575479 should instantiate its author-strategy candidate"),
		assert_eq(
			str(strategy.get_strategy_id()) if strategy != null else "",
			EXPECTED_STRATEGY_ID,
			"The 575479 strategy instance should report the candidate strategy id"
		),
	])
