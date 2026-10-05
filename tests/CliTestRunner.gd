extends SceneTree

const Catalog = preload("res://tests/TestSuiteCatalog.gd")
const Runner = preload("res://tests/SharedSuiteRunner.gd")
const Filter = preload("res://scripts/tools/TestSuiteFilter.gd")


func _initialize() -> void:
	call_deferred("_run")


func _default_group() -> String:
	return ""


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var options := parse_args(args)
	var catalog_gate := Runner.ScriptErrorGate.new()
	OS.add_logger(catalog_gate)
	var selected_groups := Filter.parse_group_filter(args)
	if selected_groups.is_empty() and not _default_group().is_empty():
		selected_groups[_default_group()] = true
	var suites: Array[Dictionary] = []
	var selection_error := ""
	for group: String in selected_groups:
		if group not in Catalog.GROUPS:
			selection_error = "Unknown test group: %s" % group
	if options.has("suite-script"):
		var path := str(options["suite-script"])
		suites.append({"name": Catalog._suite_name_for_file(path), "path": path})
	else:
		suites = Catalog.get_suites(selected_groups)
	for field: String in ["profile", "ai-version"]:
		if options.has(field):
			var key := "profiles" if field == "profile" else "ai_versions"
			suites = suites.filter(func(suite: Dictionary) -> bool: return str(options[field]) in suite.get(key, []))
	var discovery_errors := catalog_gate.take_script_errors()
	OS.remove_logger(catalog_gate)
	selection_error = Runner.format_script_error_failure(selection_error, discovery_errors)
	if options.has("list") and selection_error.is_empty():
		var listing := {"schema_version": 1, "suites": suites, "count": suites.size()}
		quit(write_report(listing, options))
		return
	var report: Dictionary
	if not selection_error.is_empty():
		var records: Array[Dictionary] = []
		Runner._record(records, {}, "_suite_selection", "failed", selection_error)
		report = Runner._build_report(records, "PTCG Test Selection")
	else:
		report = await Runner.run_suites(suites, Filter.parse_suite_filter(args), "PTCG Tests", {"test_filter": options.get("test-filter", options.get("test", ""))})
	report["engine_version"] = Engine.get_version_info().string
	report["platform"] = OS.get_name()
	# Only record public selectors; integration credentials are not report data.
	var public_filters := {}
	for key: String in ["group", "suite", "suite-script", "profile", "ai-version", "test-filter", "test"]:
		if options.has(key):
			public_filters[key] = options[key]
	report["filters"] = public_filters
	print(report.output)
	# Legacy focused summary consumed by existing local scripts.
	print("Total: %d | Failed: %d" % [report.total, report.failed])
	var write_code := write_report(report, options)
	quit(write_code if write_code != 0 else int(report.exit_code))


static func parse_args(args: PackedStringArray) -> Dictionary:
	var result := {}
	for arg: String in args:
		if not arg.begins_with("--"):
			continue
		var separator := arg.find("=")
		if separator == -1:
			result[arg.trim_prefix("--")] = true
		else:
			result[arg.substr(2, separator - 2)] = arg.substr(separator + 1)
	return result


static func write_report(report: Dictionary, options: Dictionary) -> int:
	var path := str(options.get("report", ""))
	if path.is_empty():
		if options.has("list"):
			print(JSON.stringify(report))
		return 0
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write test report: %s" % path)
		return 2
	file.store_string(JSON.stringify(report, "\t"))
	return 0
