extends TestBase

const Catalog = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")

func test_unrelated_strategy_lookup_does_not_build_all_model_profiles() -> String:
	var started := Time.get_ticks_usec()
	for index: int in 30:
		if not Catalog.get_profile_for_strategy("charizard_ex").is_empty():
			return "Legacy strategy must not match a CPG profile"
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	return assert_true(elapsed < 100.0, "30 unrelated lookups took %.1f ms" % elapsed)

func test_lookup_keeps_exact_identity_and_returns_independent_profiles() -> String:
	var profile := Catalog.get_profile_for_deck(Catalog.ALL_DECK_IDS[0])
	var identity := str(profile.get("strategy_id", ""))
	var first := Catalog.get_profile_for_strategy(identity)
	var intact := first == profile
	first["display_name"] = "modified"
	return run_checks([
		assert_true(intact, "Exact profile must resolve"),
		assert_true(Catalog.get_profile_for_strategy(identity) == profile, "Returned data must be isolated"),
		assert_true(Catalog.get_profile_for_strategy(identity + "_wrong").is_empty()),
		assert_true(Catalog.get_profile_for_strategy("v18cpg_0_invalid").is_empty()),
	])
