class_name SharedSuiteRunner
extends RefCounted

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")


static func run_suites(
	suites: Array[Dictionary],
	selected_suites: Dictionary = {},
	title: String = "PTCG Train Unit Tests"
) -> Dictionary:
	var total := 0
	var passed := 0
	var failed := 0
	var lines: Array[String] = ["===== %s =====" % title, ""]

	if not selected_suites.is_empty():
		lines.append("Selected suites: %s" % ", ".join(selected_suites.keys()))
		lines.append("")

	for suite: Dictionary in suites:
		var suite_name := str(suite.get("name", ""))
		if not TestSuiteFilterScript.should_run_suite(selected_suites, suite_name):
			continue

		lines.append("--- %s ---" % suite_name)
		var suite_script: GDScript = load(str(suite.get("path", "")))
		if suite_script == null:
			total += 1
			failed += 1
			lines.append("FAIL _suite_load :: Unable to load suite script")
			lines.append("")
			continue

		var test_obj = suite_script.new()
		if test_obj == null:
			total += 1
			failed += 1
			lines.append("FAIL _suite_init :: Unable to instantiate suite")
			lines.append("")
			continue

		var methods: Array[Dictionary] = test_obj.get_method_list()
		for method: Dictionary in methods:
			var method_name := str(method.get("name", ""))
			if not method_name.begins_with("test_"):
				continue

			total += 1
			var result: Variant = test_obj.call(method_name)
			var message := str(result)
			if message == "":
				passed += 1
				lines.append("PASS %s" % method_name)
			else:
				failed += 1
				lines.append("FAIL %s :: %s" % [method_name, message])
				print("FAIL: %s.%s: %s" % [suite_name, method_name, message])

		lines.append("")

	lines.append("===== Summary =====")
	lines.append("Total: %d | Passed: %d | Failed: %d" % [total, passed, failed])
	if failed == 0:
		lines.append("All tests passed!")
	else:
		lines.append("%d tests failed!" % failed)

	return {
		"total": total,
		"passed": passed,
		"failed": failed,
		"output": "\n".join(lines),
	}
