class_name TestTestRunnerFilter
extends TestBase

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")


func test_parse_suite_filter_empty_args_runs_all() -> String:
	var selected := TestSuiteFilterScript.parse_suite_filter(PackedStringArray())
	return run_checks([
		assert_true(selected.is_empty(), "No suite filter args should keep the filter empty"),
		assert_true(TestSuiteFilterScript.should_run_suite(selected, "GameStateMachine"), "Empty filters should allow any suite"),
	])


func test_parse_suite_filter_collects_multiple_suites_case_insensitively() -> String:
	var selected := TestSuiteFilterScript.parse_suite_filter(PackedStringArray([
		"--suite=GameStateMachine, DeckIdentityTracker",
		"--suite=benchmarkevaluator",
	]))
	return run_checks([
		assert_eq(selected.size(), 3, "Multiple suite args should merge into one filter set"),
		assert_true(TestSuiteFilterScript.should_run_suite(selected, "gamestatemachine"), "Filters should match normalized suite names"),
		assert_true(TestSuiteFilterScript.should_run_suite(selected, "DeckIdentityTracker"), "Filters should ignore surrounding whitespace"),
		assert_true(TestSuiteFilterScript.should_run_suite(selected, "BenchmarkEvaluator"), "Filters should support repeated --suite args"),
		assert_false(TestSuiteFilterScript.should_run_suite(selected, "AIBenchmark"), "Unlisted suites should be skipped"),
	])


func test_parse_suite_filter_ignores_empty_entries() -> String:
	var selected := TestSuiteFilterScript.parse_suite_filter(PackedStringArray([
		"--suite= , GameStateMachine ,, ",
	]))
	return run_checks([
		assert_eq(selected.size(), 1, "Empty suite entries should be ignored"),
		assert_true(TestSuiteFilterScript.should_run_suite(selected, "GameStateMachine"), "The valid suite should still be kept"),
	])


func test_parse_group_filter_collects_multiple_groups_case_insensitively() -> String:
	var selected := TestSuiteFilterScript.parse_group_filter(PackedStringArray([
		"--group=functional, AI_Training",
	]))
	return run_checks([
		assert_eq(selected.size(), 2, "Multiple groups should merge into one normalized set"),
		assert_true(TestSuiteFilterScript.should_run_group(selected, "functional"), "Group filters should be case-insensitive"),
		assert_true(TestSuiteFilterScript.should_run_group(selected, "ai_training"), "Group filters should normalize whitespace and casing"),
		assert_false(TestSuiteFilterScript.should_run_group(selected, "extended"), "Unlisted groups should be skipped"),
	])


func test_should_run_any_group_accepts_matching_suite_group() -> String:
	var selected := TestSuiteFilterScript.parse_group_filter(PackedStringArray([
		"--group=functional",
	]))
	return run_checks([
		assert_true(TestSuiteFilterScript.should_run_any_group(selected, ["functional"]), "Matching suite groups should run"),
		assert_false(TestSuiteFilterScript.should_run_any_group(selected, ["ai_training"]), "Non-matching suite groups should be skipped"),
		assert_true(TestSuiteFilterScript.should_run_any_group({}, ["ai_training"]), "Empty group filters should allow all groups"),
	])
