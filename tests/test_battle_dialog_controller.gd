class_name TestBattleDialogController
extends TestBase

const BattleDialogControllerScript = preload("res://scripts/ui/battle/BattleDialogController.gd")


class DialogSceneStub:
	extends Control

	var _dialog_title := Label.new()
	var _dialog_list := ItemList.new()
	var _dialog_overlay := Panel.new()
	var _dialog_cancel := Button.new()
	var _dialog_box := PanelContainer.new()
	var _dialog_vbox := VBoxContainer.new()
	var _dialog_buttons := HBoxContainer.new()
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
	var _last_dialog_choice: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		add_child(_dialog_overlay)
		_dialog_overlay.add_child(_dialog_box)
		_dialog_box.add_child(_dialog_vbox)
		_dialog_vbox.add_child(_dialog_title)
		_dialog_vbox.add_child(_dialog_list)
		_dialog_vbox.add_child(_dialog_card_scroll)
		_dialog_card_scroll.add_child(_dialog_card_row)
		_dialog_vbox.add_child(_dialog_status_lbl)
		_dialog_vbox.add_child(_dialog_utility_row)
		_dialog_vbox.add_child(_dialog_assignment_panel)
		_dialog_vbox.add_child(_dialog_buttons)
		_dialog_buttons.add_child(_dialog_cancel)
		_dialog_buttons.add_child(_dialog_confirm)
		_dialog_assignment_panel.add_child(_dialog_assignment_summary_lbl)

	func _bt(key: String, _params: Dictionary = {}) -> String:
		return key

	func _clear_container_children(container: Node) -> void:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.free()

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass

	func _log(_message: String) -> void:
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

	func _handle_dialog_choice(selected_indices: PackedInt32Array) -> void:
		_last_dialog_choice = selected_indices


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


func _text_hud_panels(row: HBoxContainer) -> Array[PanelContainer]:
	var panels: Array[PanelContainer] = []
	_collect_text_hud_panels(row, panels)
	return panels


func _collect_text_hud_panels(node: Node, panels: Array[PanelContainer]) -> void:
	if node is PanelContainer and node.has_meta("dialog_text_choice_index"):
		panels.append(node as PanelContainer)
	for child: Node in node.get_children():
		_collect_text_hud_panels(child, panels)


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


func test_text_dialog_uses_large_hud_options_and_footer_buttons() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()

	controller.call("show_dialog", scene, "Choose", ["Discard Stadium", "Keep Stadium"], {
		"presentation": "list",
		"allow_cancel": true,
	})

	var card_row: HBoxContainer = scene.get("_dialog_card_row")
	var panels := _text_hud_panels(card_row)
	var card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var confirm: Button = scene.get("_dialog_confirm")
	var cancel: Button = scene.get("_dialog_cancel")
	controller.call("on_text_hud_option_pressed", scene, 1)

	var result := run_checks([
		assert_false(dialog_list.visible, "Text option dialogs should hide the old small ItemList"),
		assert_true(card_scroll.visible, "Text option dialogs should use the HUD option scroll area"),
		assert_eq(panels.size(), 2, "Text option dialogs should render one large HUD panel per option"),
		assert_true(panels[0].custom_minimum_size.y >= 74.0, "HUD text options should be tall enough for touch input"),
		assert_false(confirm.visible, "Single-choice text HUD dialogs should submit by tapping the option"),
		assert_true(cancel.custom_minimum_size.y >= 56.0, "Dialog cancel buttons should use the larger HUD touch target"),
		assert_eq(Array(scene._last_dialog_choice), [1], "Tapping a text HUD option should preserve the original choice index"),
	])
	scene.free()
	return result


func test_text_dialog_multi_select_uses_large_confirm_button() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()

	controller.call("show_dialog", scene, "Choose many", ["One", "Two", "Three"], {
		"presentation": "list",
		"min_select": 1,
		"max_select": 2,
		"allow_cancel": true,
	})

	var confirm: Button = scene.get("_dialog_confirm")
	var card_row: HBoxContainer = scene.get("_dialog_card_row")
	var panels := _text_hud_panels(card_row)
	var initially_disabled := confirm.disabled
	controller.call("on_text_hud_option_pressed", scene, 0)
	var enabled_after_pick := not confirm.disabled

	var result := run_checks([
		assert_eq(panels.size(), 3, "Multi-select text dialogs should also render large HUD panels"),
		assert_true(confirm.visible, "Multi-select text HUD dialogs should keep an explicit confirm button"),
		assert_true(confirm.custom_minimum_size.y >= 56.0, "Dialog confirm buttons should use the larger HUD touch target"),
		assert_true(initially_disabled, "Multi-select confirm should start disabled until enough options are selected"),
		assert_true(enabled_after_pick, "Selecting a HUD text option should update confirm enabled state"),
	])
	scene.free()
	return result


func test_card_dialog_large_choice_sets_render_hud_scrollbar() -> String:
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
	var card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var rendered_names := _card_row_names(card_row)

	var result := run_checks([
		assert_eq(card_row.get_child_count(), 8, "Large card dialogs should render the full selectable card set"),
		assert_eq(rendered_names, ["Choice 1", "Choice 2", "Choice 3", "Choice 4", "Choice 5", "Choice 6", "Choice 7", "Choice 8"], "The HUD scrollbar should replace paged windows without hiding choices"),
		assert_eq(card_row.alignment, BoxContainer.ALIGNMENT_CENTER, "Card dialog rows should keep cards centered when the choice set is narrower than the dialog"),
		assert_eq(card_row.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Card dialog rows should fill horizontally so centered card groups remain centered"),
		assert_eq(card_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Card dialogs should use native horizontal scrolling"),
		assert_true(card_scroll.has_meta("hud_scrollbar_styled"), "Card dialogs should apply the shared HUD scrollbar style"),
		assert_false(utility_row.find_child("CardDialogWheel", true, false) != null, "Large card dialogs should not create the old wheel slider"),
		assert_false(utility_row.visible, "Large card dialogs should not reserve a wheel utility row when there are no utility actions"),
	])
	scene.free()
	return result


func test_card_dialog_resets_stale_dialog_box_height() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene._dialog_box.custom_minimum_size = Vector2(640, 420)
	scene._dialog_box.size = Vector2(640, 420)
	var card := _make_test_card("Tool")

	controller.call("show_dialog", scene, "Choose tool", ["Tool"], {
		"presentation": "cards",
		"card_items": [card],
		"choice_labels": ["Tool"],
		"allow_cancel": true,
	})

	var compact_height := scene._dialog_box.custom_minimum_size.y
	var result := run_checks([
		assert_true(compact_height > 0.0 and compact_height < 420.0, "Card dialogs should replace stale fixed height with compact content height"),
		assert_true(scene._dialog_card_scroll.custom_minimum_size.y > scene._dialog_card_size.y, "Card dialogs should only reserve explicit height for the HUD scrollbar inside the card scroller"),
	])
	scene.free()
	return result


func test_card_dialog_height_does_not_accumulate_across_repeated_dialogs() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	var card := _make_test_card("Tool")

	controller.call("show_dialog", scene, "Choose tool", ["Tool"], {
		"presentation": "cards",
		"card_items": [card],
		"choice_labels": ["Tool"],
		"allow_cancel": true,
	})
	var first_min_height := scene._dialog_box.custom_minimum_size.y

	controller.call("show_dialog", scene, "Choose tool again", ["Tool"], {
		"presentation": "cards",
		"card_items": [card],
		"choice_labels": ["Tool"],
		"allow_cancel": true,
	})
	var second_min_height := scene._dialog_box.custom_minimum_size.y

	var result := run_checks([
		assert_true(second_min_height > 0.0, "Repeated card dialogs should keep a concrete compact content height"),
		assert_eq(second_min_height, first_min_height, "Repeated card dialogs should not accumulate custom dialog-box height"),
	])
	scene.free()
	return result
