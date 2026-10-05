class_name TestSuiteCatalogSuite
extends TestBase

const TestSuiteCatalogScript = preload("res://tests/TestSuiteCatalog.gd")


func test_categories_form_a_complete_disjoint_partition() -> String:
	var names := {}
	var paths := {}
	for suite: Dictionary in TestSuiteCatalogScript.all_suites():
		if suite.groups.size() != 1 or suite.category not in ["ui", "functional", "ai"]:
			return "Every suite needs exactly one primary category: %s" % suite
		if names.has(suite.name.to_lower()) or paths.has(suite.path):
			return "Duplicate suite identity: %s" % suite
		names[suite.name.to_lower()] = true
		paths[suite.path] = true
	return assert_gt(paths.size(), 0, "Catalog discovery must not be empty")


func test_ui_and_new_ai_owners_are_not_hidden_in_functional() -> String:
	return run_checks([
		assert_eq(TestSuiteCatalogScript._groups_for_file("test_battle_ui_features.gd"), ["ui"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("test_battle_setup_ai_versions.gd"), ["ui"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("test_deck_manager.gd"), ["ui"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("test_battle_action_controller.gd"), ["ui"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("test_web_release_layout.gd"), ["functional"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("ui/test_strategy_hub_input_compatibility.gd"), ["ui"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("ptcgdap/godot/test_public_observation_firewall.gd"), ["ai"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("ai/ptcgdap/test_platform_model_inference.gd"), ["ai"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("ai/ptcgdap/test_model_input_contract.gd"), ["ai"], "AI model input is not UI input"),
		assert_eq(TestSuiteCatalogScript._groups_for_file("ptcgdap/godot/test_policy_input.gd"), ["ai"], "The owning directory takes precedence over ambiguous filename tokens"),
		assert_eq(TestSuiteCatalogScript._groups_for_file("test_v18_gardevoir_variants_strategy.gd"), ["ai"]),
		assert_eq(TestSuiteCatalogScript._groups_for_file("test_rule_validator.gd"), ["functional"]),
	])


func test_partially_valid_groups_cannot_hide_a_typo() -> String:
	return assert_true(TestSuiteCatalogScript.get_suites({"ui": true, "functonal": true}).is_empty())


func test_smoke_profile_references_real_suites_in_the_declared_category() -> String:
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/test_profiles.json"))
	if not profile is Dictionary or not profile.get("smoke") is Dictionary:
		return "Smoke profile is missing or malformed"
	var by_name := {}
	for suite: Dictionary in TestSuiteCatalogScript.all_suites():
		by_name[suite.name] = suite.category
	for name: String in profile.get("suite_timeout_seconds", {}):
		if not by_name.has(name) or float(profile.suite_timeout_seconds[name]) <= 0:
			return "Stale or invalid suite time budget: " + name
	for category: String in TestSuiteCatalogScript.GROUPS:
		var names: Array = profile.smoke.get(category, [])
		if names.is_empty():
			return "Smoke coverage is empty for " + category
		for name: String in names:
			if by_name.get(name, "") != category:
				return "Stale or miscategorized smoke gate: " + name
	return ""


func test_catalog_discovers_every_shared_suite_test_file() -> String:
	var discovered := TestSuiteCatalogScript.all_suites()
	var discovered_paths := {}
	for suite: Dictionary in discovered:
		discovered_paths[str(suite.get("path", ""))] = true

	var missing: Array[String] = []
	_collect_missing("res://tests", "res://tests", discovered_paths, missing)

	return run_checks([
		assert_eq(missing.size(), 0, "Every test_*.gd file that declares test_ methods should be discoverable through the shared suite catalog"),
	])


func _collect_missing(root_dir: String, current_dir: String, discovered_paths: Dictionary, missing: Array[String]) -> void:
	var dir := DirAccess.open(current_dir)
	if dir == null:
		missing.append("%s::<open_failed>" % current_dir)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry in [".", ".."]:
			entry = dir.get_next()
			continue
		var script_path := current_dir.path_join(entry)
		if dir.current_is_dir():
			_collect_missing(root_dir, script_path, discovered_paths, missing)
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			if TestSuiteCatalogScript._script_declares_suite_test_method(script_path) and not bool(discovered_paths.get(script_path, false)):
				missing.append(script_path)
		entry = dir.get_next()
	dir.list_dir_end()


func test_functional_group_includes_previously_omitted_core_suites() -> String:
	var names := TestSuiteCatalogScript.get_suite_names_for_group(TestSuiteCatalogScript.GROUP_FUNCTIONAL)
	var name_set := {}
	for suite_name: String in names:
		name_set[suite_name] = true

	return run_checks([
		assert_true(bool(name_set.get("PersistentEffects", false)), "Functional group should include PersistentEffects"),
		assert_true(bool(name_set.get("BundledDeckCatalog", false)), "Functional group must always include the bundled deck/AI picker completeness gate"),
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
