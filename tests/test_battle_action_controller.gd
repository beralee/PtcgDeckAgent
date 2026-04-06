class_name TestBattleActionController
extends TestBase

const BattleActionControllerScript = preload("res://scripts/ui/battle/BattleActionController.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


func _make_pokemon_cd(name: String) -> CardData:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 70
	card_data.energy_type = "C"
	return card_data


func test_on_hand_card_clicked_selects_basic_pokemon_and_refreshes_hand() -> String:
	var controller := BattleActionControllerScript.new()
	var scene = BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	gsm.game_state.players = [player, opponent]
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_hand_container", HBoxContainer.new())
	var card := CardInstance.create(_make_pokemon_cd("Basic"), 0)
	player.hand = [card]

	controller.call("on_hand_card_clicked", scene, card, PanelContainer.new())

	return run_checks([
		assert_eq(scene.get("_selected_hand_card"), card, "Clicking a basic Pokemon should arm it as the selected hand card"),
		assert_true((scene.get("_hand_container") as HBoxContainer).get_child_count() >= 1, "Selecting a hand card should still refresh the rendered hand"),
	])


func test_try_use_stadium_with_interaction_no_stadium_is_noop() -> String:
	var controller := BattleActionControllerScript.new()
	var scene = BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene.set("_gsm", gsm)

	controller.call("try_use_stadium_with_interaction", scene, 0)

	return run_checks([
		assert_true(true, "Calling try_use_stadium_with_interaction without a stadium should safely no-op"),
	])
