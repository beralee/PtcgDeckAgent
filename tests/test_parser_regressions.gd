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


func test_cli_entrypoints_are_compilable_and_instantiable() -> String:
	# Parsing the real scripts catches every syntax error; searching a few known
	# broken tokens cannot establish that the runner actually works.
	for path: String in [
		"res://tests/CliTestRunner.gd",
		"res://tests/FocusedSuiteRunner.gd",
		"res://tests/FunctionalTestRunner.gd",
		"res://tests/UITestRunner.gd",
	]:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			return "Test entrypoint is not instantiable: " + path
	return ""
