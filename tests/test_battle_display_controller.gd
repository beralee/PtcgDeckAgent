class_name TestBattleDisplayController
extends TestBase

const BattleDisplayControllerScript = preload("res://scripts/ui/battle/BattleDisplayController.gd")


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func test_get_selected_deck_name_falls_back_to_unknown_label() -> String:
	var controller := BattleDisplayControllerScript.new()
	var original_ids: Array = GameManager.selected_deck_ids.duplicate()
	GameManager.selected_deck_ids.clear()
	var result := str(controller.call("get_selected_deck_name", 0))
	GameManager.selected_deck_ids = original_ids.duplicate()

	return run_checks([
		assert_eq(result, _u([0x672A, 0x77E5, 0x724C, 0x7EC4]), "Missing deck selections should fall back to the unknown deck label"),
	])


func test_hand_card_subtext_formats_basic_energy() -> String:
	var controller := BattleDisplayControllerScript.new()
	var card_data := CardData.new()
	card_data.card_type = "Basic Energy"
	card_data.energy_provides = "W"
	var result := str(controller.call("hand_card_subtext", card_data))

	return run_checks([
		assert_eq(result, _u([0x57FA, 0x672C, 0x80FD, 0x91CF, 0x20, 0x2F, 0x20, 0x6C34]), "Basic Energy subtext should show the localized energy type"),
	])


func test_clear_container_children_removes_existing_nodes() -> String:
	var controller := BattleDisplayControllerScript.new()
	var container := HBoxContainer.new()
	container.add_child(Label.new())
	container.add_child(Button.new())

	controller.call("clear_container_children", container)

	return run_checks([
		assert_eq(container.get_child_count(), 0, "clear_container_children should empty the target container"),
	])
