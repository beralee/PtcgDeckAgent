class_name TestSuiteCatalogSuite
extends TestBase

const TestSuiteCatalogScript = preload("res://tests/TestSuiteCatalog.gd")


func test_catalog_discovers_every_test_file() -> String:
	var discovered := TestSuiteCatalogScript.all_suites()
	var discovered_paths := {}
	for suite: Dictionary in discovered:
		discovered_paths[str(suite.get("path", ""))] = true

	var missing: Array[String] = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return "Unable to open tests directory"

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("test_") and file_name.ends_with(".gd"):
			var script_path := "res://tests/%s" % file_name
			if not bool(discovered_paths.get(script_path, false)):
				missing.append(script_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	return run_checks([
		assert_eq(missing.size(), 0, "Every test_*.gd file should be discoverable through the suite catalog"),
	])


func test_functional_group_includes_previously_omitted_core_suites() -> String:
	var names := TestSuiteCatalogScript.get_suite_names_for_group(TestSuiteCatalogScript.GROUP_FUNCTIONAL)
	var name_set := {}
	for suite_name: String in names:
		name_set[suite_name] = true

	return run_checks([
		assert_true(bool(name_set.get("PersistentEffects", false)), "Functional group should include PersistentEffects"),
		assert_true(bool(name_set.get("RuleValidator", false)), "Functional group should include RuleValidator"),
		assert_true(bool(name_set.get("DamageCalculator", false)), "Functional group should include DamageCalculator"),
		assert_true(bool(name_set.get("SetupFlow", false)), "Functional group should include SetupFlow"),
		assert_true(bool(name_set.get("EffectRegistry", false)), "Functional group should include EffectRegistry"),
	])


func test_ai_training_group_is_isolated_from_functional_rule_suites() -> String:
	var names := TestSuiteCatalogScript.get_suite_names_for_group(TestSuiteCatalogScript.GROUP_AI_TRAINING)
	var name_set := {}
	for suite_name: String in names:
		name_set[suite_name] = true

	return run_checks([
		assert_true(bool(name_set.get("AIBaseline", false)), "AI/training group should include AI baseline coverage"),
		assert_true(bool(name_set.get("MCTSPlanner", false)), "AI/training group should include MCTS coverage"),
		assert_false(bool(name_set.get("RuleValidator", false)), "AI/training group should not include core rule validation tests"),
		assert_false(bool(name_set.get("BattleUIFeatures", false)), "AI/training group should not include Battle UI regression tests"),
	])
