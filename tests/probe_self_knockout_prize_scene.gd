extends Node

# Manual device diagnostic: add as an autoload only in an isolated export snapshot.
# Never add this fixture to the normal game's autoloads or distribute its APK.
# Android captures the real UI lifecycle; the companion test covers actual Nest Ball.

class ScenarioScene extends "res://scenes/battle/BattleScene.gd":
	func _start_battle() -> void:
		pass

var scene: Control
var output_dir := ""
var elapsed := 0.0
var capture_second := 12
var watching := false

func _process(delta: float) -> void:
	if not watching:
		return
	elapsed += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		_capture(capture_second)
		capture_second += 1

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	output_dir = "/sdcard/Android/data/com.example.ptcgdeckagent/files/self-ko-probe" if OS.get_name() == "Android" else "user://self-ko-probe"
	DirAccess.make_dir_recursive_absolute(output_dir)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var helper = load("res://tests/test_ai_self_knockout_prize_dialog.gd").new()
	var prepared: Control = helper._make_self_knockout_scene("CSV8C_082")
	var gsm: GameStateMachine = prepared.get("_gsm")
	var ai: Variant = prepared.get("_ai_opponent")
	gsm.state_changed.disconnect(prepared._on_state_changed)
	gsm.player_choice_required.disconnect(prepared._on_player_choice_required)
	gsm.action_logged.disconnect(prepared._on_action_logged)
	prepared.free()
	scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.set_script(ScenarioScene)
	get_tree().root.add_child(scene)
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
	get_tree().current_scene = scene
	scene.set("_gsm", gsm)
	scene.set("_ai_opponent", ai)
	scene.set("_view_player", 0)
	gsm.state_changed.connect(scene._on_state_changed)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	gsm.action_logged.connect(scene._on_action_logged)
	scene.call("_refresh_ui")
	scene.call("_show_dialog", "AI search", ["Choice"], {"player": 1})
	scene.call("_hide_ai_owned_effect_step_ui", 1)
	await get_tree().create_timer(1.0).timeout
	var source: PokemonSlot = gsm.game_state.players[1].bench[0]
	scene.call("_try_use_ability_with_interaction", 1, source, 0)
	scene.call("_maybe_run_ai")
	for i: int in 12:
		await get_tree().create_timer(1.0).timeout
		_capture(i)
	print("SELF_KO_PROBE_READY ", output_dir)
	watching = true

func _capture(second: int) -> void:
	var gsm: GameStateMachine = scene.get("_gsm")
	var slots: Array = scene.get("_my_prize_slots")
	var rect := (slots[0] as Control).get_global_rect() if not slots.is_empty() else Rect2()
	var report := {
		"second": second,
		"platform": OS.get_name(),
		"pending": scene.get("_pending_choice"),
		"engine_prize_remaining": gsm.get("_pending_prize_remaining"),
		"dialog_visible": (scene.get("_dialog_overlay") as Control).is_visible_in_tree(),
		"dialog_opacity": (scene.get("_dialog_overlay") as Control).modulate.a,
		"portrait_dialog_active": scene.get("_portrait_prize_dialog_active"),
		"prize_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"human_prizes": gsm.game_state.players[0].prizes.size(),
		"human_hand": gsm.game_state.players[0].hand.size(),
		"damage": gsm.game_state.players[0].active_pokemon.damage_counters,
		"turn": gsm.game_state.turn_number,
		"current_player": gsm.game_state.current_player_index,
		"state": scene.call("_state_snapshot"),
	}
	FileAccess.open(output_dir.path_join("state-%02d.json" % second), FileAccess.WRITE).store_string(JSON.stringify(report))
	FileAccess.open(output_dir.path_join("latest.json"), FileAccess.WRITE).store_string(JSON.stringify(report))
	print("SELF_KO_STATE ", JSON.stringify(report))
