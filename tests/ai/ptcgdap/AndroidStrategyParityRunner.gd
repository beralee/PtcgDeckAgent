extends Node

# Test export only; never registered by the player project or shipped preset.
const Suite = preload("res://tests/ai/ptcgdap/test_platform_player_matches.gd")
var output_dir := ""
var package_path := ""
var captured := false
var connected_clients: Array[int] = []
var execution_profile := "worker_v1"
var smoke_only := false
var error_gate = preload("res://tests/SharedSuiteRunner.gd").ScriptErrorGate.new()

func _ready() -> void:
	OS.add_logger(error_gate)
	_boot.call_deferred()

func _boot() -> void:
	output_dir = "/sdcard/Android/data/com.example.ptcgdeckagent/files/strategy-parity" if OS.get_name() == "Android" else "user://strategy-parity"
	if OS.get_name() == "Android" and FileAccess.file_exists(output_dir.path_join("request.json")):
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_dir.path_join("request.json")))
		if request is Dictionary:
			package_path = str(request.get("package_path", ""))
			execution_profile = str(request.get("execution_profile", execution_profile))
			smoke_only = bool(request.get("smoke_only", false))
			output_dir = str(request.get("output_dir", output_dir))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--parity-output="): output_dir = arg.trim_prefix("--parity-output=")
		if arg.begins_with("--parity-package="): package_path = arg.trim_prefix("--parity-package=")
		if arg.begins_with("--parity-profile="): execution_profile = arg.trim_prefix("--parity-profile=")
		if arg == "--parity-smoke-only": smoke_only = true
	DirAccess.make_dir_recursive_absolute(output_dir)
	if not package_path.is_empty():
		if get_tree().current_scene != null:
			get_tree().current_scene.queue_free()
			await get_tree().process_frame
		await _run_matches()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
	print("PARITY_WAITING_FOR_HUB_DOWNLOAD " + output_dir)
	while not captured:
		await get_tree().process_frame
		_watch_clients(get_tree().root)
	print("PARITY_DOWNLOAD_CAPTURED waiting for start marker")
	while not FileAccess.file_exists(output_dir.path_join("start")):
		await get_tree().create_timer(0.5).timeout
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		await get_tree().process_frame
	await _run_matches()

func _watch_clients(node: Node) -> void:
	if node.get_script() != null and node.get_script().resource_path == "res://scripts/ai/ptcgdap/platform/service/StrategyPlatformClient.gd" and not connected_clients.has(node.get_instance_id()):
		connected_clients.append(node.get_instance_id())
		node.connect("request_completed", _on_request_completed)
	for child: Node in node.get_children(): _watch_clients(child)

func _on_request_completed(result: Dictionary) -> void:
	if captured or not result.get("accepted", false) or not result.get("package_bytes") is PackedByteArray:
		return
	var bytes: PackedByteArray = result.package_bytes
	if bytes.is_empty(): return
	package_path = output_dir.path_join("downloaded.ptcgai")
	var file := FileAccess.open(package_path, FileAccess.WRITE)
	if file == null:
		push_error("PARITY cannot write captured package")
		return
	file.store_buffer(bytes)
	file.close()
	_write_json("download.json", {"operation":result.get("operation"), "expected_release":result.get("expected_release"), "sha256":FileAccess.get_sha256(package_path).to_upper(), "platform":OS.get_name()})
	captured = true

func _run_matches() -> void:
	var smoke_results: Array = []
	for spec: Array in [
		["res://tests/ptcgdap/godot/test_strategy_hub_scene.gd", "test_strategy_marketplace_download_hands_exact_bytes_to_strict_catalog_installer"],
		["res://tests/ptcgdap/godot/test_strategy_hub_scene.gd", "test_strategy_hub_mobile_readability_and_modal_import"],
		["res://tests/ai/ptcgdap/test_platform_model_inference.gd", "test_native_scores_are_exact_and_model_changes_the_eligible_selection"],
		["res://tests/ai/ptcgdap/test_platform_model_inference.gd", "test_invalid_model_preflight_is_recoverable_and_cannot_start"],
		["res://tests/ai/ptcgdap/test_platform_model_inference.gd", "test_real_v2_package_keeps_original_bytes_and_reaches_native_preflight"],
		["res://tests/ai/ptcgdap/test_worker_interaction_lifecycle.gd", "test_all_author_adapters_preserve_pending_search_and_target"],
		["res://tests/ai/ptcgdap/test_worker_interaction_lifecycle.gd", "test_worker_assignment_retains_source_identity_and_rebinds_current_indices"],
		["res://tests/ai/ptcgdap/test_worker_interaction_lifecycle.gd", "test_close_releases_all_author_adapter_cycles_and_revokes_old_adapter"],
		["res://tests/ptcgdap/godot/test_developer_model_trace.gd", "test_trace_records_exact_runtime_projection_and_rebinds_reordered_frontier"],
		["res://tests/ptcgdap/godot/test_developer_model_trace.gd", "test_trace_capture_rejects_hidden_unknown_uid_and_bad_indexes"],
		["res://tests/ptcgdap/godot/test_developer_model_trace.gd", "test_projector_fingerprint_resolves_compiled_export_remap"],
		["res://tests/ptcgdap/godot/test_developer_model_trace.gd", "test_trace_preserves_model_adjudication_without_timing_or_extra_fields"],
	]:
		var smoke_suite: Variant = load(spec[0]).new()
		var smoke_error: String = await smoke_suite.call(spec[1])
		smoke_results.append({"test":spec[1], "error":smoke_error})
	_write_json("smoke.json", smoke_results)
	var smoke_failed := false
	for smoke_result: Dictionary in smoke_results:
		if not str(smoke_result.error).is_empty(): smoke_failed = true
	if smoke_failed or smoke_only:
		_write_json("complete.json", {"ok":not smoke_failed, "smoke_only":true,"matches":[],"platform":OS.get_name(),"architecture":Engine.get_architecture_name(),"script_errors":error_gate.take_script_errors()})
		OS.remove_logger(error_gate)
		get_tree().quit(1 if smoke_failed else 0)
		return
	var suite := Suite.new()
	suite.package_override = package_path
	suite.capture_trace = true
	suite.execution_profile = execution_profile
	var results: Array = []
	var failures: Array = []
	for smoke_result: Dictionary in smoke_results:
		if not str(smoke_result.error).is_empty(): failures.append(smoke_result.error)
	for match_seed: int in [84590, 84591, 84592]:
		for seat: int in [0, 1]:
			suite.seed_override = match_seed
			var error: String = await suite._match(false, seat)
			var report := suite.last_report.duplicate(true)
			report["test_error"] = error
			_write_json("match-%d-%d.json" % [match_seed, seat], report)
			results.append({"seed":match_seed,"seat":seat,"error":error})
			if not error.is_empty(): failures.append(error)
	var script_errors: Array = error_gate.take_script_errors()
	_write_json("complete.json", {"platform":OS.get_name(), "package_sha256":FileAccess.get_sha256(package_path).to_upper(), "matches":results,"ok":failures.is_empty() and script_errors.is_empty(),"script_errors":script_errors,"standalone_export":OS.has_feature("template"),"architecture":Engine.get_architecture_name()})
	print("PARITY_COMPLETE " + JSON.stringify(results))
	OS.remove_logger(error_gate)
	get_tree().quit(0 if failures.is_empty() else 1)

func _write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(output_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		push_error("PARITY report write failed: " + name)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(value))
