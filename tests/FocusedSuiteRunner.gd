extends SceneTree

const SharedSuiteRunnerScript = preload("res://tests/SharedSuiteRunner.gd")


func _initialize() -> void:
	var error_gate := SharedSuiteRunnerScript.ScriptErrorGate.new()
	OS.add_logger(error_gate)
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var suite_script_path: String = str(args.get("suite-script", ""))
	var test_filter: String = str(args.get("test-filter", args.get("test", ""))).strip_edges()
	if suite_script_path == "":
		print("Missing --suite-script")
		_finish(error_gate, 2)
		return

	var load_errors := error_gate.take_script_errors()
	var suite_resource: Resource = ResourceLoader.load(
		suite_script_path,
		"GDScript",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	load_errors.append_array(error_gate.take_script_errors())
	if suite_resource == null or not suite_resource is GDScript:
		var load_message := "Unable to load suite script: %s" % suite_script_path
		print(SharedSuiteRunnerScript.format_script_error_failure(load_message, load_errors))
		_finish(error_gate, 2)
		return

	var suite_script := suite_resource as GDScript
	var can_instantiate := suite_script.can_instantiate()
	load_errors.append_array(error_gate.take_script_errors())
	if not can_instantiate or not load_errors.is_empty():
		var validation_message := "Unable to instantiate suite script after load: %s" % suite_script_path
		if can_instantiate:
			validation_message = "Suite script emitted errors while loading: %s" % suite_script_path
		print(SharedSuiteRunnerScript.format_script_error_failure(validation_message, load_errors))
		_finish(error_gate, 2)
		return
	if SharedSuiteRunnerScript.script_requires_init_arguments(suite_script):
		print("Unable to instantiate suite without required _init arguments: %s" % suite_script_path)
		_finish(error_gate, 2)
		return

	var init_errors := error_gate.take_script_errors()
	var suite: Variant = suite_script.new()
	init_errors.append_array(error_gate.take_script_errors())
	var methods: Array[Dictionary] = []
	if suite != null and init_errors.is_empty():
		methods = suite.get_method_list()
		init_errors.append_array(error_gate.take_script_errors())
	if suite == null or not init_errors.is_empty():
		var init_message := SharedSuiteRunnerScript.format_script_error_failure(
			"Unable to instantiate suite: %s" % suite_script_path,
			init_errors
		)
		print(init_message)
		_finish(error_gate, 2)
		return

	var total: int = 0
	var failed: int = 0

	for method: Dictionary in methods:
		var method_name: String = str(method.get("name", ""))
		if not method_name.begins_with("test_"):
			continue
		if test_filter != "" and method_name.find(test_filter) == -1:
			continue
		total += 1
		print("RUN %s" % method_name)
		var runtime_errors := error_gate.take_script_errors()
		var result: Variant = await suite.call(method_name)
		runtime_errors.append_array(error_gate.take_script_errors())
		var message: String = SharedSuiteRunnerScript.format_script_error_failure(str(result), runtime_errors)
		if message == "":
			print("PASS %s" % method_name)
		else:
			failed += 1
			print("FAIL %s :: %s" % [method_name, message])

	if total == 0:
		print("No tests matched filter '%s' in %s" % [test_filter, suite_script_path])
		_finish(error_gate, 2)
		return

	suite = null
	var teardown_errors := error_gate.take_script_errors()
	if not teardown_errors.is_empty():
		total += 1
		failed += 1
		print("FAIL _suite_teardown :: %s" % SharedSuiteRunnerScript.format_script_error_failure("", teardown_errors))

	print("Total: %d | Failed: %d" % [total, failed])
	_finish(error_gate, 1 if failed > 0 else 0)


func _finish(error_gate: Logger, exit_code: int) -> void:
	OS.remove_logger(error_gate)
	quit(exit_code)


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in raw_args:
		if not raw_arg.begins_with("--"):
			continue
		var eq_index: int = raw_arg.find("=")
		if eq_index <= 2:
			continue
		var key: String = raw_arg.substr(2, eq_index - 2)
		var value: String = raw_arg.substr(eq_index + 1)
		parsed[key] = value
	return parsed
