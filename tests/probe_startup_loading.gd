extends SceneTree
## Run in a fresh process: the shared suite runner itself loads battle scripts.

const DEFERRED_SCRIPTS := [
	"res://scripts/engine/EffectProcessor.gd",
	"res://scripts/engine/EffectRegistry.gd",
	"res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd",
	"res://scripts/ai/ptcgdap/host/godot/PtcgDAPModelActor.gd",
]
var _report := {"checkpoints": [], "unexpected_resources": [], "menu_ready": false}


func _initialize() -> void:
	_check_resources("autoloads")
	call_deferred("_open_menu")


func _check_resources(stage: String) -> void:
	_report.checkpoints.append({"stage": stage, "elapsed_ms": Time.get_ticks_msec()})
	for path: String in DEFERRED_SCRIPTS:
		if ResourceLoader.has_cached(path):
			_report.unexpected_resources.append({"stage": stage, "path": path})


func _open_menu() -> void:
	var scene: PackedScene = load("res://scenes/main_menu/MainMenu.tscn")
	var menu := scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	_report.menu_ready = menu.is_node_ready() and menu.get_node("%BtnStartBattle").is_visible_in_tree()
	_check_resources("menu_ready")
	await process_frame
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--startup-screenshot="):
			await RenderingServer.frame_post_draw
			_report.screenshot_error = root.get_texture().get_image().save_png(arg.trim_prefix("--startup-screenshot="))
			_report.first_draw_ms = Time.get_ticks_msec()
	_report.catalog_scanned = int(root.get_node("AuthorStrategyPackageCatalog").get("_scan_generation")) > 0
	_report.late_loads_ok = _exercise_late_loads() if "--exercise-late-loads" in OS.get_cmdline_user_args() else true
	print("STARTUP_LOADING_REPORT=" + JSON.stringify(_report))
	quit(0 if _report.menu_ready and _report.catalog_scanned and _report.late_loads_ok and _report.unexpected_resources.is_empty() else 1)


func _exercise_late_loads() -> bool:
	# Unlike ordinary suites, nothing else has preloaded the implementations.
	var database := root.get_node("CardDatabase")
	var source: Variant = database.get_card("CSV7C", "051")
	if source == null:
		_report.late_load_error = "missing_card"
		return false
	var status: Script = load("res://scripts/engine/CardImplementationStatus.gd")
	if status.is_unimplemented(source):
		_report.late_load_error = "source_unimplemented"
		return false
	var duplicate: Variant = source.duplicate(true)
	duplicate.set_code = "UTEST"
	duplicate.card_index = "999"
	duplicate.effect_id = "startup-lazy-alias-probe"
	var aliases: Script = load("res://scripts/engine/CardEffectAliasResolver.gd")
	if not aliases.find_duplicate_effect_alias(duplicate, [source]).get("matched", false):
		_report.late_load_error = "alias_not_found"
		return false
	var loader: Variant = root.get_node("AuthorStrategyPackageCatalog").get("_loader")
	var vectors: Dictionary = loader._coerce_integral_numbers(JSON.parse_string(FileAccess.get_file_as_string(
		"res://contracts/ptcgdap/competitive_policy_v2_conformance_vectors.json"
	)))
	for spec: Dictionary in vectors.get("cases", []):
		if spec.get("case_id") != "whole-turn-route-candidate-overrides-local-greedy-score":
			continue
		var policy: Dictionary = spec.policy.duplicate(true)
		if not loader._valid_adapter_shape(policy):
			_report.late_load_error = "valid_policy_rejected"
			return false
		policy["unexpected_startup_test_field"] = true
		return not loader._valid_adapter_shape(policy)
	_report.late_load_error = "missing_policy_fixture"
	return false
