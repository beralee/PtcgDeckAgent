class_name TestBattleRecordingController
extends TestBase

const BattleRecordingControllerScript = preload("res://scripts/ui/battle/BattleRecordingController.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


func _make_card(name: String, card_type: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = card_type
	var instance := CardInstance.new()
	instance.card_data = card_data
	instance.instance_id = 7
	instance.owner_index = 1
	instance.face_up = true
	return instance


func test_serialize_card_instance_keeps_core_card_fields() -> String:
	var controller := BattleRecordingControllerScript.new()
	var serialized: Dictionary = controller.call("serialize_card_instance", _make_card("Switch", "Item"))

	return run_checks([
		assert_eq(str(serialized.get("card_name", "")), "Switch", "serialize_card_instance should keep the card name"),
		assert_eq(str(serialized.get("card_type", "")), "Item", "serialize_card_instance should keep the card type"),
		assert_eq(int(serialized.get("owner_index", -1)), 1, "serialize_card_instance should keep the owner index"),
	])


func test_recording_phase_name_returns_empty_without_game_state() -> String:
	var controller := BattleRecordingControllerScript.new()
	var scene = BattleSceneScript.new()
	scene.set("_gsm", null)
	var phase := str(controller.call("recording_phase_name", scene))

	return run_checks([
		assert_eq(phase, "", "recording_phase_name should stay empty when no game state exists"),
	])


func test_local_recording_includes_ai_and_author_strategy_battles() -> String:
	var controller := BattleRecordingControllerScript.new()
	var previous_mode: int = GameManager.current_mode
	var results: Array[bool] = []
	for mode: int in [
		GameManager.GameMode.TWO_PLAYER,
		GameManager.GameMode.VS_AI,
		GameManager.GameMode.VS_AUTHOR_STRATEGY_AI,
	]:
		GameManager.current_mode = mode
		results.append(bool(controller.call("should_record_local_battle", null)))
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(results, [true, true, true], "Every local battle mode must produce a native replay record"),
	])
