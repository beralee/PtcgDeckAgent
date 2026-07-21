class_name TestSuiteRunnerErrorGate
extends TestBase

const SharedSuiteRunnerScript = preload("res://tests/SharedSuiteRunner.gd")
const VALID_FIXTURE_PATH := "res://tests/fixtures/suite_runner_valid_fixture.gd"
const ABSTRACT_FIXTURE_PATH := "res://tests/fixtures/suite_runner_abstract_fixture.gd"


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
