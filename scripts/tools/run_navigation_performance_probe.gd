extends SceneTree

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu/MainMenu.tscn"
const REPORT_PREFIX := "PTCGDAP_NAVIGATION_PERFORMANCE="
const TIMEOUT_MSEC := 15_000
const TARGETS := {
	"battle_setup": {
		"handler": "_on_start_battle",
		"scene": "res://scenes/battle_setup/BattleSetup.tscn",
	},
	"deck_manager": {
		"handler": "_on_deck_manager",
		"scene": "res://scenes/deck_manager/DeckManager.tscn",
	},
	"deck_training": {
		"handler": "_on_deck_training",
		"scene": "res://scenes/deck_training/DeckTrainingBrowser.tscn",
	},
	"strategy_hub": {
		"handler": "_on_strategy_hub",
		"scene": "res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn",
	},
	"settings": {
		"handler": "_on_settings",
		"scene": "res://scenes/settings/Settings.tscn",
	},
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu_started_msec := Time.get_ticks_msec()
	var target_name := _target_name()
	if not TARGETS.has(target_name):
		print(REPORT_PREFIX + JSON.stringify({
			"accepted": false,
			"error_code": "target_invalid",
			"supported_targets": TARGETS.keys(),
		}))
		quit(2)
		return
	var packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	if packed == null:
		print(REPORT_PREFIX + JSON.stringify({"accepted": false, "error_code": "main_menu_unavailable"}))
		quit(2)
		return
	var menu := packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var menu_ready_msec := Time.get_ticks_msec() - menu_started_msec
	var target: Dictionary = TARGETS[target_name]
	var started_msec := Time.get_ticks_msec()
	menu.call(str(target.get("handler", "")))
	var expected_scene := str(target.get("scene", ""))
	while Time.get_ticks_msec() - started_msec < TIMEOUT_MSEC:
		await process_frame
		if current_scene != null and str(current_scene.scene_file_path) == expected_scene:
			await process_frame
			print(REPORT_PREFIX + JSON.stringify({
				"accepted": true,
				"target": target_name,
				"scene": expected_scene,
				"menu_ready_msec": menu_ready_msec,
				"navigation_msec": Time.get_ticks_msec() - started_msec,
				"feedback_text": "正在载入…",
			}))
			quit(0)
			return
	print(REPORT_PREFIX + JSON.stringify({
		"accepted": false,
		"error_code": "navigation_timeout",
		"target": target_name,
		"expected_scene": expected_scene,
		"actual_scene": str(current_scene.scene_file_path) if current_scene != null else "",
	}))
	quit(1)


func _target_name() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--target="):
			return arg.get_slice("=", 1)
	return "battle_setup"
