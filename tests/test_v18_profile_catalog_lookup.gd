extends TestBase

const ProfileCatalogScript := preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const DeckStrategyRegistryScript := preload("res://scripts/ai/DeckStrategyRegistry.gd")
const V18CPGProfileCatalogScript := preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")


func test_repeated_ai_picker_capability_lookup_stays_fast() -> String:
	var decks := CardDatabase.get_all_ai_decks()
	var registry := DeckStrategyRegistryScript.new()
	for deck: DeckData in decks:
		var base_strategy_id := registry.resolve_strategy_id_for_deck(deck)
		DeckStrategyRegistryScript.deck_supports_llm(deck.id, base_strategy_id)
	var started := Time.get_ticks_usec()
	for deck: DeckData in decks:
		var base_strategy_id := registry.resolve_strategy_id_for_deck(deck)
		DeckStrategyRegistryScript.deck_supports_llm(deck.id, base_strategy_id)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	return run_checks([
		assert_true(elapsed_ms < 100.0, "Repeated AI picker updates should resolve all deck capabilities without blocking the UI (%.1f ms)" % elapsed_ms),
		assert_eq(ProfileCatalogScript.strategy_id_for_deck(800018500), "v18_800018500_toedscruel_ogerpon", "V18 deck strategy ID should remain correct"),
		assert_eq(ProfileCatalogScript.strategy_id_for_deck(-1), "", "Unknown deck should have no V18 strategy"),
	])


func test_ai_picker_metadata_matches_full_v18_cpg_profiles() -> String:
	var checks: Array[String] = []
	for deck_id: int in V18CPGProfileCatalogScript.ALL_DECK_IDS:
		var full_profile: Dictionary = V18CPGProfileCatalogScript.get_profile_for_deck(deck_id)
		var metadata: Dictionary = V18CPGProfileCatalogScript.setup_variant_metadata_for_deck(deck_id)
		for field: String in [
			"base_strategy_id", "strategy_id", "runtime_kind",
			"battle_setup_available", "promotion_status", "experimental",
		]:
			checks.append(assert_eq(metadata.get(field), full_profile.get(field), "AI picker metadata %s should match full profile for deck %d" % [field, deck_id]))
	checks.append(assert_true(V18CPGProfileCatalogScript.setup_variant_metadata_for_deck(-1).is_empty(), "Unknown deck should have no AI picker metadata"))
	var cached_profile: Dictionary = ProfileCatalogScript.get_profile_for_deck(800018500)
	cached_profile["deck_name"] = "changed"
	checks.append(assert_false(ProfileCatalogScript.get_profile_for_deck(800018500).get("deck_name") == "changed", "Profile callers should receive independent copies"))
	return run_checks(checks)
