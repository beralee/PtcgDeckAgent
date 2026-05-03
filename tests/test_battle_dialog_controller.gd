class_name TestBattleDialogController
extends TestBase

const BattleDialogControllerScript = preload("res://scripts/ui/battle/BattleDialogController.gd")


class DialogSceneStub:
	extends Control

	var _dialog_title := Label.new()
	var _dialog_list := ItemList.new()
	var _dialog_overlay := Panel.new()
	var _dialog_cancel := Button.new()
	var _dialog_card_scroll := ScrollContainer.new()
	var _dialog_assignment_panel := VBoxContainer.new()
	var _dialog_card_row := HBoxContainer.new()
	var _dialog_utility_row := HBoxContainer.new()
	var _dialog_confirm := Button.new()
	var _dialog_status_lbl := Label.new()
	var _dialog_assignment_summary_lbl := Label.new()
	var _dialog_items_data: Array = []
	var _dialog_data: Dictionary = {}
	var _dialog_multi_selected_indices: Array[int] = []
	var _dialog_card_selected_indices: Array[int] = []
	var _dialog_card_page := 0
	var _dialog_card_page_size := 0
	var _dialog_card_mode := false
	var _dialog_assignment_mode := false
	var _dialog_assignment_selected_source_index := -1
	var _dialog_assignment_assignments: Array[Dictionary] = []
	var _dialog_card_size := Vector2(92, 129)
	var _pending_choice := ""
	var _gsm = null

	func _init() -> void:
		for node: Node in [
			_dialog_title,
			_dialog_list,
			_dialog_overlay,
			_dialog_cancel,
			_dialog_card_scroll,
			_dialog_assignment_panel,
			_dialog_card_row,
			_dialog_utility_row,
			_dialog_confirm,
			_dialog_status_lbl,
			_dialog_assignment_summary_lbl,
		]:
			add_child(node)

	func _bt(key: String, _params: Dictionary = {}) -> String:
		return key

	func _clear_container_children(container: Node) -> void:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.free()

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass

	func _record_battle_state_snapshot(_snapshot_reason: String, _extra_data: Dictionary = {}) -> void:
		pass

	func _record_battle_event(_event_data: Dictionary) -> void:
		pass

	func _dialog_state_snapshot() -> String:
		return ""

	func _recording_phase_name() -> String:
		return "test"

	func _hand_card_subtext(_card_data: CardData) -> String:
		return ""

	func _battle_card_mode_for_slot(_slot: PokemonSlot) -> String:
		return BattleCardView.MODE_CHOICE

	func _build_battle_status(_slot: PokemonSlot) -> Dictionary:
		return {}

	func _on_dialog_card_left_signal(_card_instance: CardInstance, _card_data: CardData, _choice_index: int) -> void:
		pass

	func _on_dialog_card_right_signal(_card_instance: CardInstance, _card_data: CardData) -> void:
		pass


func _make_test_card(name: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 60
	return CardInstance.create(card_data, 0)


func _card_row_names(row: HBoxContainer) -> Array[String]:
	var names: Array[String] = []
	for child: Node in row.get_children():
		var card_view := child as BattleCardView
		if card_view == null or card_view.card_instance == null or card_view.card_instance.card_data == null:
			continue
		names.append(card_view.card_instance.card_data.name)
	return names


func test_card_dialog_does_not_show_selectable_hint() -> String:
	var controller := BattleDialogControllerScript.new()

	return run_checks([
		assert_false(
			bool(controller.call("card_dialog_should_show_selectable_hint", false)),
			"Unselected cards in a card-selection dialog should not show the selectable hint"
		),
		assert_false(
			bool(controller.call("card_dialog_should_show_selectable_hint", true)),
			"Selected cards in a card-selection dialog should not show the selectable hint"
		),
	])


func test_card_dialog_uses_wheel_window_by_default_for_large_choice_sets() -> String:
	var controller := BattleDialogControllerScript.new()

	return run_checks([
		assert_eq(
			int(controller.call("resolve_card_dialog_page_size", {}, 8)),
			7,
			"Card-selection dialogs with more than seven cards should use the wheel window by default"
		),
		assert_eq(
			int(controller.call("resolve_card_dialog_page_size", {}, 7)),
			0,
			"Card-selection dialogs with seven or fewer cards should not add redundant wheel controls"
		),
		assert_eq(
			int(controller.call("resolve_card_dialog_page_size", {"card_page_size": 3}, 8)),
			3,
			"Explicit card_page_size should override the default wheel window size"
		),
		assert_eq(
			int(controller.call("resolve_card_dialog_page_size", {"card_page_size": 0}, 8)),
			0,
			"Explicit card_page_size=0 should allow special dialogs to opt out of wheel controls"
		),
	])


func test_card_dialog_wheel_window_moves_by_single_card() -> String:
	var controller := BattleDialogControllerScript.new()

	return run_checks([
		assert_eq(
			controller.call("card_dialog_window_range", 10, 7, 0),
			Vector2i(0, 7),
			"The first wheel position should show the first seven cards"
		),
		assert_eq(
			controller.call("card_dialog_window_range", 10, 7, 1),
			Vector2i(1, 8),
			"Moving the wheel once should rotate the visible cards by one card, not by a full page"
		),
		assert_eq(
			controller.call("card_dialog_window_range", 10, 7, 99),
			Vector2i(3, 10),
			"The wheel window should clamp to the last valid seven-card range"
		),
	])


func test_card_dialog_large_choice_sets_render_wheel_control() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	var cards: Array = []
	var labels: Array[String] = []
	for i: int in 8:
		var card_name := "Choice %d" % (i + 1)
		cards.append(_make_test_card(card_name))
		labels.append(card_name)

	controller.call("show_dialog", scene, "Choose", labels, {
		"presentation": "cards",
		"card_items": cards,
		"choice_labels": labels,
	})

	var card_row: HBoxContainer = scene.get("_dialog_card_row")
	var utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var wheel_box := utility_row.get_child(0) as HBoxContainer if utility_row.get_child_count() > 0 else null
	var wheel := wheel_box.get_node_or_null("CardDialogWheel") as HSlider if wheel_box != null else null
	var wheel_label := wheel_box.get_node_or_null("CardDialogWheelLabel") as Label if wheel_box != null else null
	var first_window := _card_row_names(card_row)
	var initial_label := wheel_label.text if wheel_label != null else ""
	if wheel != null:
		wheel.value = 1.0
		wheel.value_changed.emit(1.0)
	var second_window := _card_row_names(card_row)
	var shifted_label := wheel_label.text if wheel_label != null else ""

	var result := run_checks([
		assert_eq(card_row.get_child_count(), 7, "Large card dialogs should render up to seven cards at once"),
		assert_not_null(wheel, "Large card dialogs should replace page buttons with a wheel-sized slider"),
		assert_eq(initial_label, "1-7 / 8", "The wheel label should show the visible card range instead of a page number"),
		assert_eq(first_window, ["Choice 1", "Choice 2", "Choice 3", "Choice 4", "Choice 5", "Choice 6", "Choice 7"], "The first wheel position should render cards 1 through 7"),
		assert_eq(second_window, ["Choice 2", "Choice 3", "Choice 4", "Choice 5", "Choice 6", "Choice 7", "Choice 8"], "Moving the wheel one step should rotate the dialog by one card"),
		assert_eq(shifted_label, "2-8 / 8", "The wheel label should update after rotating the visible cards"),
	])
	scene.free()
	return result
