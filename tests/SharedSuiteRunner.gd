class_name SharedSuiteRunner
extends RefCounted

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")


class ScriptErrorGate extends Logger:
	var _mutex := Mutex.new()
	var _script_errors: Array[String] = []


	func _log_message(_message: String, _error: bool) -> void:
		pass


	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		var detail := rationale.strip_edges()
		if detail == "":
			detail = code.strip_edges()
		if detail == "":
			detail = "Unspecified script error"
		var location := file.strip_edges()
		if location == "":
			location = "<unknown script>"
		if line > 0:
			location += ":%d" % line
		if function.strip_edges() != "":
			location += " in %s()" % function

		_mutex.lock()
		_script_errors.append("%s: %s" % [location, detail])
		_mutex.unlock()


	func take_script_errors() -> Array[String]:
		_mutex.lock()
		var captured: Array[String] = _script_errors.duplicate()
		_script_errors.clear()
		_mutex.unlock()
		return captured


static func format_script_error_failure(base_message: String, script_errors: Array[String]) -> String:
	if script_errors.is_empty():
		return base_message
	var script_error_message := "SCRIPT ERROR :: %s" % " | ".join(script_errors)
	if base_message.strip_edges() == "":
		return script_error_message
	return "%s | %s" % [base_message, script_error_message]


static func run_suites(
	suites: Array[Dictionary],
	selected_suites: Dictionary = {},
	title: String = "PTCG Train Unit Tests"
) -> Dictionary:
	var total := 0
	var passed := 0
	var failed := 0
	var lines: Array[String] = ["===== %s =====" % title, ""]
	var error_gate := ScriptErrorGate.new()
	OS.add_logger(error_gate)

	if not selected_suites.is_empty():
		lines.append("Selected suites: %s" % ", ".join(selected_suites.keys()))
		lines.append("")

	for suite: Dictionary in suites:
		var suite_name := str(suite.get("name", ""))
		if not TestSuiteFilterScript.should_run_suite(selected_suites, suite_name):
			continue

		lines.append("--- %s ---" % suite_name)
		var suite_path := str(suite.get("path", ""))
		var load_errors := error_gate.take_script_errors()
		var suite_resource: Resource = ResourceLoader.load(
			suite_path,
			"GDScript",
			ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		load_errors.append_array(error_gate.take_script_errors())
		if suite_resource == null or not suite_resource is GDScript:
			total += 1
			failed += 1
			var load_message := "Unable to load suite script: %s" % suite_path
			lines.append("FAIL _suite_load :: %s" % format_script_error_failure(load_message, load_errors))
			lines.append("")
			continue

		var suite_script := suite_resource as GDScript
		var can_instantiate := suite_script.can_instantiate()
		load_errors.append_array(error_gate.take_script_errors())
		if not load_errors.is_empty():
			total += 1
			failed += 1
			var validation_message := "Suite script emitted errors while loading: %s" % suite_path
			lines.append("FAIL _suite_load :: %s" % format_script_error_failure(validation_message, load_errors))
			lines.append("")
			continue
		if not can_instantiate:
			total += 1
			failed += 1
			lines.append("FAIL _suite_init :: Suite script cannot be instantiated: %s" % suite_path)
			lines.append("")
			continue
		if script_requires_init_arguments(suite_script):
			total += 1
			failed += 1
			lines.append("FAIL _suite_init :: Unable to instantiate suite without required _init arguments: %s" % suite_path)
			lines.append("")
			continue

		var init_errors := error_gate.take_script_errors()
		var test_obj: Variant = suite_script.new()
		init_errors.append_array(error_gate.take_script_errors())
		var methods: Array[Dictionary] = []
		if test_obj != null and init_errors.is_empty():
			methods = test_obj.get_method_list()
			init_errors.append_array(error_gate.take_script_errors())
		if test_obj == null or not init_errors.is_empty():
			test_obj = null
			suite_script = null
			await _wait_for_cleanup_frames()
			init_errors.append_array(error_gate.take_script_errors())
			total += 1
			failed += 1
			lines.append("FAIL _suite_init :: %s" % format_script_error_failure(
				"Unable to instantiate suite: %s" % suite_path,
				init_errors
			))
			lines.append("")
			continue

		var suite_test_count := 0
		for method: Dictionary in methods:
			var method_name := str(method.get("name", ""))
			if not method_name.begins_with("test_"):
				continue

			suite_test_count += 1
			total += 1
			# Emit the active test immediately. The summary is intentionally buffered,
			# but operators must still be able to distinguish a slow test from a
			# stalled runner and stop at the exact owning test.
			print("RUN: %s.%s" % [suite_name, method_name])
			var started_at_msec := Time.get_ticks_msec()
			var runtime_errors := error_gate.take_script_errors()
			var root_snapshot := _capture_root_children()
			var orphan_snapshot := _capture_orphan_nodes()
			var result: Variant = await test_obj.call(method_name)

			await _cleanup_root_children(root_snapshot)
			_cleanup_orphan_nodes(orphan_snapshot)
			await _wait_for_cleanup_frames()
			runtime_errors.append_array(error_gate.take_script_errors())

			var message := format_script_error_failure(str(result), runtime_errors)
			if message == "":
				passed += 1
				lines.append("PASS %s" % method_name)
				print("PASS: %s.%s (%d ms)" % [
					suite_name,
					method_name,
					Time.get_ticks_msec() - started_at_msec,
				])
			else:
				failed += 1
				lines.append("FAIL %s :: %s" % [method_name, message])
				print("FAIL: %s.%s (%d ms): %s" % [
					suite_name,
					method_name,
					Time.get_ticks_msec() - started_at_msec,
					message,
				])

		if suite_test_count == 0:
			total += 1
			failed += 1
			lines.append("FAIL _suite_discovery :: No test methods found")

		lines.append("")
		test_obj = null
		suite_script = null
		await _wait_for_cleanup_frames()
		var teardown_errors := error_gate.take_script_errors()
		if not teardown_errors.is_empty():
			total += 1
			failed += 1
			lines.append("FAIL _suite_teardown :: %s" % format_script_error_failure("", teardown_errors))
			lines.append("")

	lines.append("===== Summary =====")
	lines.append("Total: %d | Passed: %d | Failed: %d" % [total, passed, failed])
	if failed == 0:
		lines.append("All tests passed!")
	else:
		lines.append("%d tests failed!" % failed)

	OS.remove_logger(error_gate)
	return {
		"total": total,
		"passed": passed,
		"failed": failed,
		"output": "\n".join(lines),
	}


static func script_requires_init_arguments(suite_script: GDScript) -> bool:
	for method: Dictionary in suite_script.get_script_method_list():
		if str(method.get("name", "")) != "_init":
			continue
		var args: Array = method.get("args", [])
		var default_args: Array = method.get("default_args", [])
		return args.size() > default_args.size()
	return false


static func _wait_for_cleanup_frames() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
		await tree.process_frame


static func _capture_root_children() -> Dictionary:
	var snapshot := {}
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return snapshot
	for child: Node in tree.root.get_children():
		snapshot[child.get_instance_id()] = true
	return snapshot


static func _cleanup_root_children(before_snapshot: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	for child: Node in tree.root.get_children():
		if before_snapshot.has(child.get_instance_id()):
			continue
		child.queue_free()


static func _capture_orphan_nodes() -> Dictionary:
	var snapshot := {}
	for orphan_id: int in Node.get_orphan_node_ids():
		snapshot[orphan_id] = true
	return snapshot


static func _cleanup_orphan_nodes(before_snapshot: Dictionary) -> void:
	for orphan_id: int in Node.get_orphan_node_ids():
		if before_snapshot.has(orphan_id):
			continue
		var obj := instance_from_id(orphan_id)
		if obj is Node:
			(obj as Node).free()
