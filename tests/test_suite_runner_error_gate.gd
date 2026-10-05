class_name TestSuiteRunnerErrorGate
extends TestBase

const SharedSuiteRunnerScript = preload("res://tests/SharedSuiteRunner.gd")
const VALID_FIXTURE_PATH := "res://tests/fixtures/suite_runner_valid_fixture.gd"
const ABSTRACT_FIXTURE_PATH := "res://tests/fixtures/suite_runner_abstract_fixture.gd"


func test_skip_is_visible_and_cannot_mask_assertions_or_invalid_tests() -> String:
	var suites: Array[Dictionary] = [{"name": "ResultFixture", "path": "res://tests/fixtures/suite_runner_result_fixture.gd"}]
	var report := await SharedSuiteRunnerScript.run_suites(suites)
	return run_checks([
		assert_eq(report.passed, 0),
		assert_eq(report.failed, 3),
		assert_eq(report.skipped, 1),
		assert_eq(report.exit_code, 1),
	])


func test_all_skipped_and_unmatched_method_filters_are_not_success() -> String:
	var suites: Array[Dictionary] = [{"name": "ResultFixture", "path": "res://tests/fixtures/suite_runner_result_fixture.gd"}]
	var skipped := await SharedSuiteRunnerScript.run_suites(suites, {}, "Skip fixture", {"test_filter": "test_explicit_skip"})
	var unmatched := await SharedSuiteRunnerScript.run_suites(suites, {}, "Bad filter", {"test_filter": "no_such_test"})
	return run_checks([
		assert_eq(skipped.skipped, 1),
		assert_eq(skipped.passed, 0),
		assert_eq(skipped.exit_code, 2),
		assert_eq(unmatched.failed, 1),
	])


func test_empty_selection_cannot_report_success() -> String:
	var report := await SharedSuiteRunnerScript.run_suites([], {}, "Empty discovery")
	return assert_gt(int(report.get("failed", 0)), 0, "Running no suites must fail closed")


func test_unknown_selected_suite_is_not_silently_ignored() -> String:
	var suites: Array[Dictionary] = [{"name": "RunnerValidFixture", "path": VALID_FIXTURE_PATH}]
	var report := await SharedSuiteRunnerScript.run_suites(suites, {"runnervalidfixture": true, "misspelled": true})
	return run_checks([
		assert_gt(int(report.get("failed", 0)), 0, "Even a partially matched selection must reject unknown names"),
		assert_str_contains(str(report.get("output", "")), "misspelled"),
	])


func test_duplicate_suite_identity_fails_before_execution() -> String:
	var suites: Array[Dictionary] = [
		{"name": "RunnerValidFixture", "path": VALID_FIXTURE_PATH},
		{"name": "RunnerValidFixture", "path": VALID_FIXTURE_PATH},
	]
	var report := await SharedSuiteRunnerScript.run_suites(suites)
	return assert_gt(int(report.get("failed", 0)), 0, "Duplicate registration must not inflate coverage")


func test_discarded_assertion_failure_cannot_become_a_pass() -> String:
	var suites: Array[Dictionary] = [{"name": "IgnoredAssertion", "path": "res://tests/fixtures/suite_runner_ignored_assertion_fixture.gd"}]
	var report := await SharedSuiteRunnerScript.run_suites(suites)
	return assert_eq(int(report.get("failed", 0)), 1, "Ignoring an assertion's return value must still fail the test")


func test_script_error_gate_captures_only_script_errors_and_drains() -> String:
	var gate := SharedSuiteRunnerScript.ScriptErrorGate.new()
	var backtraces: Array[ScriptBacktrace] = []
	gate._log_error(
		"explode",
		"res://tests/fixtures/failing_dependency.gd",
		17,
		"",
		"Invalid access to property",
		false,
		Logger.ERROR_TYPE_SCRIPT,
		backtraces
	)
	gate._log_error(
		"push_error",
		"res://tests/test_suite_runner_error_gate.gd",
		1,
		"",
		"Ordinary application error",
		false,
		Logger.ERROR_TYPE_ERROR,
		backtraces
	)

	var captured := gate.take_script_errors()
	return run_checks([
		assert_eq(captured.size(), 1, "Only SCRIPT errors should trip the runner gate"),
		assert_str_contains(captured[0] if not captured.is_empty() else "", "failing_dependency.gd:17", "Captured errors should retain their source location"),
		assert_str_contains(captured[0] if not captured.is_empty() else "", "Invalid access to property", "Captured errors should retain their rationale"),
		assert_true(gate.take_script_errors().is_empty(), "Taking errors should atomically drain the gate"),
	])


func test_script_error_turns_an_empty_test_result_into_failure() -> String:
	var script_errors: Array[String] = [
		"res://tests/fixture.gd:9 in test_failure(): Invalid call",
	]
	var message := SharedSuiteRunnerScript.format_script_error_failure("", script_errors)
	return run_checks([
		assert_true(message != "", "A SCRIPT error must never preserve an empty PASS result"),
		assert_str_contains(message, "SCRIPT ERROR", "The failure should identify the engine error category"),
		assert_str_contains(message, "Invalid call", "The failure should include the actionable engine diagnostic"),
	])


func test_shared_runner_preserves_sync_and_async_passes() -> String:
	var suites: Array[Dictionary] = [
		{"name": "RunnerValidFixture", "path": VALID_FIXTURE_PATH},
	]
	var report := await SharedSuiteRunnerScript.run_suites(suites, {}, "Runner valid fixture")
	return run_checks([
		assert_eq(int(report.get("total", -1)), 2, "The fixture should expose both tests"),
		assert_eq(int(report.get("passed", -1)), 2, "Sync and async tests should retain normal PASS behavior"),
		assert_eq(int(report.get("failed", -1)), 0, "The logger gate should not create false failures"),
	])


func test_shared_runner_rejects_non_instantiable_suite() -> String:
	var suites: Array[Dictionary] = [
		{"name": "RunnerAbstractFixture", "path": ABSTRACT_FIXTURE_PATH},
	]
	var report := await SharedSuiteRunnerScript.run_suites(suites, {}, "Runner abstract fixture")
	var output := str(report.get("output", ""))
	return run_checks([
		assert_eq(int(report.get("total", -1)), 1, "A rejected suite should count as one infrastructure failure"),
		assert_eq(int(report.get("failed", -1)), 1, "A non-instantiable suite must fail the report"),
		assert_str_contains(output, "FAIL _suite_init", "The report should identify the rejected instantiation phase"),
		assert_str_contains(output, "Unable to instantiate", "The report should explain why no tests ran"),
	])
