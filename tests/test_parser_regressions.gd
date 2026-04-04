class_name TestParserRegressions
extends TestBase


func test_critical_test_scripts_load_without_parser_errors() -> String:
	var runner_script = load("res://tests/TestRunner.gd")
	var functional_runner_script = load("res://tests/FunctionalTestRunner.gd")
	var ai_training_runner_script = load("res://tests/AITrainingTestRunner.gd")
	var suite_catalog_script = load("res://tests/TestSuiteCatalog.gd")
	var mcts_script = load("res://tests/test_mcts_failure_diagnostics.gd")
	var battle_ui_script = load("res://tests/test_battle_ui_features.gd")

	return run_checks([
		assert_true(runner_script != null, "TestRunner.gd should load without parser errors"),
		assert_true(functional_runner_script != null, "FunctionalTestRunner.gd should load without parser errors"),
		assert_true(ai_training_runner_script != null, "AITrainingTestRunner.gd should load without parser errors"),
		assert_true(suite_catalog_script != null, "TestSuiteCatalog.gd should load without parser errors"),
		assert_true(mcts_script != null, "test_mcts_failure_diagnostics.gd should load without parser errors"),
		assert_true(battle_ui_script != null, "test_battle_ui_features.gd should load without parser errors"),
	])


func test_regression_sources_do_not_contain_known_parser_breakages() -> String:
	var mcts_source := FileAccess.get_file_as_string("res://tests/test_mcts_failure_diagnostics.gd")
	var battle_ui_source := FileAccess.get_file_as_string("res://tests/test_battle_ui_features.gd")
	var runner_source := FileAccess.get_file_as_string("res://tests/TestRunner.gd")

	return run_checks([
		assert_false("var match :=" in mcts_source, "MCTS diagnostics test should not use the reserved keyword 'match' as a variable"),
		assert_false(char(0x2033) in battle_ui_source, "Battle UI features test should not contain stray double-prime characters"),
		assert_false(char(0x20AC) in battle_ui_source, "Battle UI features test should not contain stray euro-sign characters"),
		assert_true("TestSuiteCatalogScript" in runner_source, "TestRunner should load suites through the shared catalog"),
		assert_true("SharedSuiteRunnerScript" in runner_source, "TestRunner should delegate execution through the shared runner"),
	])
