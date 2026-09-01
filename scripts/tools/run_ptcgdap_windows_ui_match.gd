extends Node

const ACCEPTANCE_SCRIPT_PATH := "res://scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsUiMatchAcceptance.gd"
const ACCEPTANCE_DOCUMENT_TYPE := "author_strategy_windows_ui_match_report_v1"
const DEVELOPMENT_ACTIVATION_ARG := "--ptcgdap-development-ui-match"
const DEVICE_CANARY_ACTIVATION_ARG := "--ptcgdap-production-device-canary"
const READY_PREFIX := "PTCGDAP_WINDOWS_UI_READY="
const SCENE_PREFIX := "PTCGDAP_WINDOWS_UI_SCENE="
const TARGET_PREFIX := "PTCGDAP_WINDOWS_UI_TARGET="
const REPORT_PREFIX := "PTCGDAP_WINDOWS_UI_MATCH="

var _active := false
var _completed := false
var _started_usec := 0
var _last_scene_path := ""
var _observed_scene_paths: Array[String] = []
var _target_fingerprints: Dictionary = {}
var _acceptance_mode := ""
var _acceptance_script: Script = null


func _ready() -> void:
	set_process(false)
	var args := OS.get_cmdline_user_args()
	var development_count := args.count(DEVELOPMENT_ACTIVATION_ARG)
	var canary_count := args.count(DEVICE_CANARY_ACTIVATION_ARG)
	if development_count == 0 and canary_count == 0:
		return
	_acceptance_script = load(ACCEPTANCE_SCRIPT_PATH) as Script
	if _acceptance_script == null or not _acceptance_script.can_instantiate():
		_fail_start("acceptance_script_unavailable")
		return
	if development_count + canary_count != 1:
		_fail_start("activation_mode_conflict")
		return
	_acceptance_mode = "device_canary" if canary_count == 1 else "development"
	_started_usec = Time.get_ticks_usec()
	if OS.get_name() != "Windows":
		_fail_start("development_platform_not_authorized")
		return
	if not OS.has_feature("template") or OS.has_feature("editor"):
		_fail_start("not_standalone_export")
		return
	_active = true
	set_process(true)
	var catalog_audit: Dictionary = AuthorStrategyPackageCatalog.audit_snapshot() \
		if AuthorStrategyPackageCatalog != null else {}
	print(READY_PREFIX + JSON.stringify({
		"active": true,
		"runtime_platform": OS.get_name(),
		"standalone_export": true,
		"acceptance_mode": _acceptance_mode,
		"development_only": _acceptance_mode == "development",
		"device_canary": _acceptance_mode == "device_canary",
		"production_ready": false,
		"catalog_scan_elapsed_usec": int(catalog_audit.get("last_scan_elapsed_usec", -1)),
	}))


func _process(_delta: float) -> void:
	if not _active or _completed:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var scene_path := str(current_scene.scene_file_path)
	if scene_path.is_empty():
		return
	if scene_path != _last_scene_path:
		_last_scene_path = scene_path
		if scene_path not in _observed_scene_paths:
			_observed_scene_paths.append(scene_path)
		print(SCENE_PREFIX + scene_path)
	_emit_ui_targets(current_scene)


func _emit_ui_targets(current_scene: Node) -> void:
	var names: Array[String] = []
	match str(current_scene.scene_file_path):
		"res://scenes/main_menu/MainMenu.tscn":
			names = ["BtnStartBattle"]
		"res://scenes/battle_setup/BattleSetup.tscn":
			names = ["ModeAuthorStrategyButton", "BtnStart"]
	for target_name: String in names:
		var target := current_scene.find_child(target_name, true, false) as Control
		if target == null or not target.is_visible_in_tree():
			continue
		var viewport_size: Vector2 = current_scene.get_viewport_rect().size
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			continue
		var rect := target.get_global_rect()
		var payload := {
			"name": target_name,
			"x": (rect.position.x + rect.size.x * 0.5) / viewport_size.x,
			"y": (rect.position.y + rect.size.y * 0.5) / viewport_size.y,
			"disabled": bool(target.get("disabled")) if target is BaseButton else false,
			"scene": str(current_scene.scene_file_path),
		}
		if str(current_scene.scene_file_path) == "res://scenes/battle_setup/BattleSetup.tscn":
			var mode_option := current_scene.find_child("ModeOption", true, false) as OptionButton
			var author_selected := mode_option != null and mode_option.selected == 2
			if target_name == "ModeAuthorStrategyButton":
				payload["state"] = "author_selected" if author_selected else "other_mode"
			elif target_name == "BtnStart":
				payload["state"] = (
					"author_ready" if author_selected and not bool(payload.get("disabled", true))
					else ("author_waiting" if author_selected else "other_mode")
				)
		var fingerprint := JSON.stringify(payload)
		if str(_target_fingerprints.get(target_name, "")) == fingerprint:
			continue
		_target_fingerprints[target_name] = fingerprint
		print(TARGET_PREFIX + fingerprint)


func is_active() -> bool:
	return _active and not _completed


func complete_match(battle_scene: Control, winner_index: int, reason: String) -> void:
	if not is_active():
		return
	_completed = true
	set_process(false)
	_finish_match_after_present(battle_scene, winner_index, reason)


func _finish_match_after_present(battle_scene: Control, winner_index: int, reason: String) -> void:
	# Let the match-end overlay reach the swap chain before the external harness
	# captures its terminal screenshot.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	var report: Dictionary = _acceptance_script.build_report(
		battle_scene, winner_index, reason, _observed_scene_paths, _started_usec,
		_acceptance_mode
	)
	print(REPORT_PREFIX + JSON.stringify(report))
	_quit_after_report(bool(report.get("is_clean", false)))


func _quit_after_report(clean: bool) -> void:
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if clean else 1)


func _fail_start(code: String) -> void:
	_completed = true
	print(REPORT_PREFIX + JSON.stringify({
		"schema_version": 1,
		"document_type": ACCEPTANCE_DOCUMENT_TYPE,
		"runtime_platform": OS.get_name(),
		"standalone_export": OS.has_feature("template") and not OS.has_feature("editor"),
		"complete_match_finished": false,
		"acceptance_mode": _acceptance_mode,
		"development_only": _acceptance_mode != "device_canary",
		"device_canary": _acceptance_mode == "device_canary",
		"production_ready": false,
		"a5_claimed": false,
		"real_mouse_input_proven": false,
		"network_isolation_proven": false,
		"is_clean": false,
		"dirty_reasons": [code],
	}))
	get_tree().quit.call_deferred(1)
