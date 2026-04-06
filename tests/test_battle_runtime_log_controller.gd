class_name TestBattleRuntimeLogController
extends TestBase

const BattleRuntimeLogControllerScript = preload("res://scripts/ui/battle/BattleRuntimeLogController.gd")


func test_card_instance_label_handles_missing_card() -> String:
	var controller := BattleRuntimeLogControllerScript.new()
	var result := str(controller.call("card_instance_label", null))

	return run_checks([
		assert_eq(result, "-", "card_instance_label should render a dash for null cards"),
	])


func test_card_instance_label_includes_name_and_instance_id() -> String:
	var controller := BattleRuntimeLogControllerScript.new()
	var card_data := CardData.new()
	card_data.name = "Switch"
	var card_instance := CardInstance.new()
	card_instance.card_data = card_data
	card_instance.instance_id = 12
	var result := str(controller.call("card_instance_label", card_instance))

	return run_checks([
		assert_eq(result, "Switch#12", "card_instance_label should include the card name and instance id"),
	])
