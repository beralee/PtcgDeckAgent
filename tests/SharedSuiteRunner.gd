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
	title: String = "PTCG Train Unit Tests",
	options: Dictionary = {}
) -> Dictionary:
	var records: Array[Dictionary] = []
	var identities := {}
	var paths := {}
	var selected_count := 0
	for suite: Dictionary in suites:
		var name := str(suite.get("name", ""))
		var key := TestSuiteFilterScript.normalize_suite_name(name)
		var path := str(suite.get("path", ""))
		if key.is_empty() or path.is_empty() or identities.has(key) or paths.has(path):
			_record(records, suite, "_suite_selection", "failed", "Empty or duplicate suite identity: %s (%s)" % [name, path])
		identities[key] = true
		paths[path] = true
		if TestSuiteFilterScript.should_run_suite(selected_suites, name):
			selected_count += 1
	for key: String in selected_suites:
		if not identities.has(key):
			_record(records, {}, "_suite_selection", "failed", "Unknown suite: %s" % key)
	if selected_count == 0:
		_record(records, {}, "_suite_selection", "failed", "No suites selected; refusing an empty success")
	if not records.is_empty():
		return _build_report(records, title)

	var error_gate := ScriptErrorGate.new()
	OS.add_logger(error_gate)
	for suite: Dictionary in suites:
		if not TestSuiteFilterScript.should_run_suite(selected_suites, str(suite.name)):
			continue
		var suite_path := str(suite.path)
		var load_errors := error_gate.take_script_errors()
		var resource := ResourceLoader.load(suite_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		load_errors.append_array(error_gate.take_script_errors())
		if resource == null or not resource is GDScript:
			_record(records, suite, "_suite_load", "failed", format_script_error_failure("Unable to load suite script: %s" % suite_path, load_errors))
			continue
		var script := resource as GDScript
		var instantiable := script.can_instantiate()
		load_errors.append_array(error_gate.take_script_errors())
		if not load_errors.is_empty():
			_record(records, suite, "_suite_load", "failed", format_script_error_failure("Suite emitted errors while loading", load_errors))
			continue
		if not instantiable or script_requires_init_arguments(script):
			_record(records, suite, "_suite_init", "failed", "Unable to instantiate suite without required _init arguments or abstract implementation: %s" % suite_path)
			continue
		var suite_root := _capture_root_children()
		var suite_orphans := _capture_orphan_nodes()
		var test_obj: Variant = script.new()
		var init_errors := error_gate.take_script_errors()
		if test_obj == null or not init_errors.is_empty():
			_record(records, suite, "_suite_init", "failed", format_script_error_failure("Unable to instantiate suite", init_errors))
		else:
			var methods: Array[Dictionary] = test_obj.get_method_list()
			methods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
			var test_count := 0
			for method: Dictionary in methods:
				var method_name := str(method.name)
				if not method_name.begins_with("test_"):
					continue
				var test_filter := str(options.get("test_filter", ""))
				if not test_filter.is_empty() and method_name.find(test_filter) == -1:
					continue
				test_count += 1
				var arguments: Array = method.get("args", [])
				var defaults: Array = method.get("default_args", [])
				if arguments.size() > defaults.size():
					_record(records, suite, method_name, "failed", "Test methods must not require arguments")
					continue
				print("RUN: %s.%s" % [suite.name, method_name])
				var started := Time.get_ticks_msec()
				var errors := error_gate.take_script_errors()
				var root_before := _capture_root_children()
				var orphans_before := _capture_orphan_nodes()
				if test_obj.has_method("take_assertion_failures"):
					test_obj.take_assertion_failures()
				var result: Variant = await test_obj.call(method_name)
				await _cleanup_root_children(root_before)
				_cleanup_orphan_nodes(orphans_before)
				await _wait_for_cleanup_frames()
				errors.append_array(error_gate.take_script_errors())
				var message := str(result) if result is String else "Test must return String; received %s" % type_string(typeof(result))
				var assertion_failed := false
				if test_obj.has_method("take_assertion_failures"):
					var assertions: Array = test_obj.take_assertion_failures()
					if not assertions.is_empty():
						assertion_failed = true
						message = " | ".join(assertions)
				message = format_script_error_failure(message, errors)
				var status := "passed" if message.is_empty() else "failed"
				if not assertion_failed and errors.is_empty() and message.begins_with("SKIP: ") and message.trim_prefix("SKIP: ").strip_edges() != "":
					status = "skipped"
				_record(records, suite, method_name, status, message, Time.get_ticks_msec() - started)
			if test_count == 0:
				_record(records, suite, "_suite_discovery", "failed", "No test methods matched filter '%s'" % str(options.get("test_filter", "")))
		if test_obj is Node and is_instance_valid(test_obj):
			(test_obj as Node).free()
		test_obj = null
		resource = null
		script = null
		await _cleanup_root_children(suite_root)
		_cleanup_orphan_nodes(suite_orphans)
		await _wait_for_cleanup_frames()
		var teardown_errors := error_gate.take_script_errors()
		if not teardown_errors.is_empty():
			_record(records, suite, "_suite_teardown", "failed", format_script_error_failure("", teardown_errors))
	OS.remove_logger(error_gate)
	return _build_report(records, title)


static func _record(records: Array[Dictionary], suite: Dictionary, test: String, status: String, message: String, elapsed_ms: int = 0) -> void:
	var record := {"suite": str(suite.get("name", "")), "path": str(suite.get("path", "")), "test": test, "status": status, "message": message, "elapsed_ms": elapsed_ms}
	records.append(record)
	var label: String = {"passed": "PASS", "failed": "FAIL", "skipped": "SKIP"}.get(status, "FAIL")
	print("%s: %s.%s (%d ms)%s" % [label, record.suite, test, elapsed_ms, " :: " + message if message != "" else ""])


static func _build_report(records: Array[Dictionary], title: String) -> Dictionary:
	var passed := 0
	var failed := 0
	var skipped := 0
	var lines: Array[String] = ["===== %s =====" % title]
	for record: Dictionary in records:
		match record.status:
			"passed": passed += 1
			"skipped": skipped += 1
			_: failed += 1
		var label: String = {"passed": "PASS", "failed": "FAIL", "skipped": "SKIP"}.get(record.status, "FAIL")
		lines.append("%s %s :: %s %s" % [label, record.test, record.suite, record.message])
	lines.append("===== Summary =====")
	lines.append("Total: %d | Passed: %d | Failed: %d | Skipped: %d" % [records.size(), passed, failed, skipped])
	var exit_code := 1 if failed > 0 else (2 if passed == 0 else 0)
	if failed == 0 and skipped == 0 and passed > 0:
		lines.append("All tests passed!")
	return {"schema_version": 1, "total": records.size(), "passed": passed, "failed": failed, "skipped": skipped, "exit_code": exit_code, "cases": records, "output": "\n".join(lines)}




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
