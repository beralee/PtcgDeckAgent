## 主菜单场景
extends Control


func _ready() -> void:
	%BtnStartBattle.pressed.connect(_on_start_battle)
	%BtnDeckManager.pressed.connect(_on_deck_manager)
	%BtnBattleReplay.pressed.connect(_on_battle_replay)
	%BtnSettings.pressed.connect(_on_settings)
	%BtnQuit.pressed.connect(_on_quit)


func _on_start_battle() -> void:
	GameManager.goto_battle_setup()


func _on_deck_manager() -> void:
	GameManager.goto_deck_manager()


func _on_battle_replay() -> void:
	GameManager.goto_replay_browser()


func _on_settings() -> void:
	GameManager.goto_settings()


func _on_quit() -> void:
	get_tree().quit()
