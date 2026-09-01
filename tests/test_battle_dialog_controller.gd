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
	var _dialog_library_search_board_mode := false
	var _dialog_library_search_board: Control = null
	var _dialog_buttons_original_parent: Node = null
	var _dialog_buttons_original_index := -1
	var _dialog_assignment_selected_source_index := -1
	var _dialog_assignment_assignments: Array[Dictionary] = []
	var _dialog_card_size := Vector2(92, 129)
	var _active_battle_layout_mode := ""
	var _modal_input_generation: int = 0
	var _modal_input_origin_position: Vector2 = Vector2(-1.0, -1.0)
	var _dialog_modal_transition_depth: int = 0
	var _dialog_modal_transition_generation: int = -1
	var _dialog_modal_transition_origin_position: Vector2 = Vector2(-1.0, -1.0)
	var _dialog_modal_transition_origin_source: String = ""
	var _dialog_generation: int = 0
	var _dialog_requires_fresh_action_input: bool = false
	var _dialog_user_input_generation: int = -1
	var _dialog_user_input_position: Vector2 = Vector2(-1.0, -1.0)
	var _dialog_user_input_source: String = ""
	var _dialog_confirm_input_generation: int = -1
	var _dialog_confirm_input_position: Vector2 = Vector2(-1.0, -1.0)
	var _dialog_cancel_input_generation: int = -1
	var _dialog_cancel_input_position: Vector2 = Vector2(-1.0, -1.0)
	var _dialog_modal_echo_blocked: bool = false
	var _dialog_echo_action_pending: String = ""
	var _dialog_same_position_action_locked: bool = false
	var _pending_choice := ""
	var _gsm = null
	var _last_dialog_choice: PackedInt32Array = PackedInt32Array()
	var _dialog_choice_call_count := 0
	var _last_effect_choice: PackedInt32Array = PackedInt32Array()
	var _effect_choice_call_count := 0
	var _cancelled_card_gallery_drag_sources: Array[String] = []
	var _screen_position_to_battle_local_offset := Vector2.ZERO

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
		_dialog_choice_call_count += 1
		_last_dialog_choice = selected_indices

	func _handle_effect_interaction_choice(selected_indices: PackedInt32Array) -> void:
		_effect_choice_call_count += 1
		_last_effect_choice = selected_indices

	func _cancel_card_gallery_drag_scroll(source: String = "cancel") -> void:
		_cancelled_card_gallery_drag_sources.append(source)

	func _set_card_gallery_drag_scroll_active(scroll: ScrollContainer, active: bool) -> void:
		if scroll != null:
			scroll.set_meta("card_gallery_drag_scroll_active", active)

	func _configure_card_gallery_drag_scroll(scroll: ScrollContainer, row: Control = null, source: String = "card_gallery") -> void:
		if scroll == null:
			return
		scroll.set_meta("card_gallery_drag_scroll_enabled", true)
		scroll.set_meta("card_gallery_drag_source", source)
		if row != null:
			row.set_meta("card_gallery_drag_row", true)

	func _screen_position_to_battle_local(screen_position: Vector2) -> Vector2:
		return screen_position + _screen_position_to_battle_local_offset


class FakeStadiumActionEffect extends BaseEffect:
	func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
		return true

	func can_execute(_card: CardInstance, _state: GameState) -> bool:
		return true

	func get_description() -> String:
		return "每回合可以使用1次竞技场能力。"


func _make_test_card(name: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 60
	return CardInstance.create(card_data, 0)


func _make_test_stadium(name: String, effect_id: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Stadium"
	card_data.effect_id = effect_id
	card_data.description = "竞技场测试效果"
	return CardInstance.create(card_data, 0)


func _card_row_names(row: HBoxContainer) -> Array[String]:
	var names: Array[String] = []
	for child: Node in row.get_children():
		var card_view := child as BattleCardView
		if card_view == null or card_view.card_instance == null or card_view.card_instance.card_data == null:
			continue
		names.append(card_view.card_instance.card_data.name)
	return names


func _collect_battle_card_views(node: Node, views: Array[BattleCardView]) -> void:
	if node is BattleCardView:
		views.append(node as BattleCardView)
	for child: Node in node.get_children():
		_collect_battle_card_views(child, views)


func _battle_card_views_under(node: Node) -> Array[BattleCardView]:
	var views: Array[BattleCardView] = []
	if node != null:
		_collect_battle_card_views(node, views)
	return views


func _candidate_slot_for_view(card_view: BattleCardView) -> Control:
	if card_view == null:
		return null
	var parent := card_view.get_parent()
	while parent != null:
		if parent is Control and (bool((parent as Control).get_meta("library_search_candidate_slot", false)) or str(parent.name) == "LibrarySearchCandidateSlot"):
			return parent as Control
		parent = parent.get_parent()
	return null


func _emit_candidate_slot_tap(slot: Control) -> void:
	if slot == null:
		return
	var center := slot.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	press.global_position = center
	slot.gui_input.emit(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = center
	release.global_position = center
	slot.gui_input.emit(release)


func _screen_touch(position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	return event


func _screen_drag(position: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	return event


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event


func _prepare_library_search_touch_rects(library_scroll: ScrollContainer, library_row: HBoxContainer, candidate_slot: Control) -> Vector2:
	library_scroll.position = Vector2(200, 300)
	library_scroll.size = Vector2(640, 280)
	library_scroll.custom_minimum_size = library_scroll.size
	library_row.position = Vector2.ZERO
	library_row.size = Vector2(640, 260)
	library_row.custom_minimum_size = library_row.size
	candidate_slot.position = Vector2.ZERO
	candidate_slot.size = Vector2(180, 252)
	candidate_slot.custom_minimum_size = candidate_slot.size
	return candidate_slot.get_global_rect().get_center()


func _collect_library_empty_slots(node: Node, slots: Array[PanelContainer]) -> void:
	if node is PanelContainer:
		var panel := node as PanelContainer
		if bool(panel.get_meta("library_search_empty_slot", false)) or panel.name == "LibrarySearchEmptySlot":
			slots.append(panel)
	for child: Node in node.get_children():
		_collect_library_empty_slots(child, slots)


func _library_empty_slots_under(node: Node) -> Array[PanelContainer]:
	var slots: Array[PanelContainer] = []
	if node != null:
		_collect_library_empty_slots(node, slots)
	return slots


func _library_empty_slot_labels_under(node: Node) -> Array[String]:
	var labels: Array[String] = []
	for panel: PanelContainer in _library_empty_slots_under(node):
		var label := panel.get_child(0) as Label if panel.get_child_count() > 0 else null
		labels.append(label.text if label != null else "")
	return labels


func _text_hud_panels(row: HBoxContainer) -> Array[PanelContainer]:
	var panels: Array[PanelContainer] = []
	_collect_text_hud_panels(row, panels)
	return panels


func _first_action_hud_panel(row: HBoxContainer) -> PanelContainer:
	if row == null or row.get_child_count() == 0:
		return null
	var stack := row.get_child(0) as VBoxContainer
	if stack == null and row.get_child_count() > 1:
		stack = row.get_child(1) as VBoxContainer
	if stack == null or stack.get_child_count() == 0:
		return null
	return stack.get_child(0) as PanelContainer


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


func test_stadium_action_dialog_uses_pokemon_action_hud() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	var gsm := GameStateMachine.new()
	var stadium := _make_test_stadium("测试竞技场", "test_stadium_action")
	var effect := FakeStadiumActionEffect.new()
	gsm.effect_processor.register_effect(stadium.card_data.effect_id, effect)
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 3
	gsm.game_state.stadium_card = stadium
	scene.set("_gsm", gsm)

	controller.call("show_stadium_action_dialog", scene, 0)

	var dialog_data: Dictionary = scene.get("_dialog_data")
	var actions: Array = dialog_data.get("actions", [])
	var action_items: Array = dialog_data.get("action_items", [])
	var first_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var first_item: Dictionary = action_items[0] if action_items.size() > 0 and action_items[0] is Dictionary else {}
	var preview_panel := scene._dialog_card_row.find_child("PokemonActionCardPreview", true, false) as PanelContainer

	var result := run_checks([
		assert_eq(scene.get("_pending_choice"), "pokemon_action", "Stadium action should reuse the Pokemon action dialog choice path"),
		assert_eq(str(first_action.get("type", "")), "stadium_ability", "Stadium action should expose a dedicated ability-like action type"),
		assert_true(bool(first_action.get("enabled", false)), "Usable Stadium action should be enabled"),
		assert_eq(str(first_item.get("kind", "")), "特性", "Stadium action HUD should present the effect as an ability"),
		assert_eq(str(first_item.get("meta", "")), "竞技场", "Stadium action HUD should mark the source as Stadium"),
		assert_eq(dialog_data.get("pokemon_card", null), stadium, "Stadium action HUD should use the live Stadium card preview"),
		assert_not_null(preview_panel, "Stadium action HUD should render the same left-side card preview as Pokemon actions"),
	])
	scene.free()
	return result


func test_disabled_action_hud_option_does_not_confirm_or_hide_dialog() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_pending_choice", "pokemon_action")

	controller.call("show_dialog", scene, "选择行动：测试宝可梦", [], {
		"presentation": "action_hud",
		"action_items": [{
			"type": "ability",
			"kind": "特性",
			"title": "被封锁的特性",
			"body": "这行文字应该继续留在行动 HUD 内。",
			"enabled": false,
			"reason": "特性被封锁",
		}],
		"allow_cancel": true,
	})

	var panel := _first_action_hud_panel(scene.get("_dialog_card_row") as HBoxContainer)
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	if panel != null:
		panel.gui_input.emit(press)

	var result := run_checks([
		assert_not_null(panel, "Action HUD should render the disabled option panel"),
		assert_true(scene._dialog_overlay.visible, "Clicking a disabled Pokemon action row should keep the action HUD open"),
		assert_eq(Array(scene._last_dialog_choice), [], "Disabled Pokemon action rows should not confirm a dialog choice"),
		assert_eq(scene.get("_pending_choice"), "pokemon_action", "Disabled Pokemon action rows should keep the pending action context"),
	])
	scene.free()
	return result


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


func test_dialog_cancel_is_ignored_when_cancel_is_disallowed() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()

	controller.call("show_dialog", scene, "Choose", ["Only option"], {
		"presentation": "list",
		"allow_cancel": false,
	})
	scene.set("_pending_choice", "mandatory_choice")
	controller.call("on_dialog_cancel", scene)

	var result := run_checks([
		assert_true(scene._dialog_overlay.visible, "Mandatory dialogs should stay visible when cancel is requested"),
		assert_eq(scene.get("_pending_choice"), "mandatory_choice", "Mandatory dialogs should keep their pending choice after cancel"),
		assert_false(scene._dialog_cancel.visible, "Mandatory dialogs should keep the cancel button hidden"),
		assert_eq(scene._cancelled_card_gallery_drag_sources, [], "Blocked cancel should not clear active card-gallery drag capture"),
	])
	scene.free()
	return result


func test_dialog_confirm_clears_card_gallery_drag_capture() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene._dialog_overlay.visible = true
	scene.set("_pending_choice", "test_choice")

	controller.call("confirm_dialog_selection", scene, PackedInt32Array([0]))

	var result := run_checks([
		assert_false(scene._dialog_overlay.visible, "Confirming a dialog should hide the overlay"),
		assert_eq(scene._cancelled_card_gallery_drag_sources, ["dialog_confirm_selection"], "Confirming a dialog should clear stale card-gallery drag capture"),
		assert_eq(Array(scene._last_dialog_choice), [0], "Confirming a dialog should still forward the selected indices"),
	])
	scene.free()
	return result


func test_dialog_cancel_clears_card_gallery_drag_capture() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene._dialog_overlay.visible = true
	scene.set("_pending_choice", "test_choice")
	scene.set("_dialog_data", {"allow_cancel": true})

	controller.call("on_dialog_cancel", scene)

	var result := run_checks([
		assert_false(scene._dialog_overlay.visible, "Canceling a dialog should hide the overlay"),
		assert_eq(scene._cancelled_card_gallery_drag_sources, ["dialog_cancel"], "Canceling a dialog should clear stale card-gallery drag capture"),
		assert_eq(scene.get("_pending_choice"), "", "Canceling a dialog should clear pending choice"),
	])
	scene.free()
	return result


func test_dialog_cancel_can_resolve_effect_interaction_as_empty_selection() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene._dialog_overlay.visible = true
	scene.set("_pending_choice", "effect_interaction")
	scene.set("_dialog_card_selected_indices", [0])
	scene.set("_dialog_data", {
		"allow_cancel": true,
		"cancel_resolves_empty": true,
	})

	controller.call("on_dialog_cancel", scene)

	var result := run_checks([
		assert_false(scene._dialog_overlay.visible, "Canceling an optional effect step should hide the overlay"),
		assert_eq(Array(scene._last_effect_choice), [], "Canceling an optional effect step should submit an empty selection"),
		assert_eq(scene._cancelled_card_gallery_drag_sources, ["dialog_cancel_empty_selection"], "Cancel-as-empty should clear stale card-gallery drag capture"),
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


func test_card_dialog_large_choice_sets_rendered_drag_gallery() -> String:
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
		assert_eq(rendered_names, ["Choice 1", "Choice 2", "Choice 3", "Choice 4", "Choice 5", "Choice 6", "Choice 7", "Choice 8"], "The drag gallery should replace paged windows without hiding choices"),
		assert_eq(card_row.alignment, BoxContainer.ALIGNMENT_CENTER, "Card dialog rows should keep cards centered when the choice set is narrower than the dialog"),
		assert_eq(card_row.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Card dialog rows should fill horizontally so centered card groups remain centered"),
		assert_eq(card_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Card dialogs should preserve ScrollContainer horizontal scrolling semantics"),
		assert_true(card_scroll.has_meta("hud_scrollbar_styled"), "Card dialogs should keep the shared scroll container contract even when the visible bar is hidden"),
		assert_false(utility_row.find_child("CardDialogWheel", true, false) != null, "Large card dialogs should not create the old wheel slider"),
		assert_false(utility_row.visible, "Large card dialogs should not reserve a wheel utility row when there are no utility actions"),
	])
	scene.free()
	return result


func test_readonly_card_dialog_utility_action_submits_explicit_empty_selection() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_pending_choice", "effect_interaction")
	var card := _make_test_card("Viewed Card")

	controller.call("show_dialog", scene, "Inspect cards", [], {
		"presentation": "cards",
		"card_items": [card],
		"card_indices": [-1],
		"min_select": 0,
		"max_select": 0,
		"allow_cancel": false,
		"utility_actions": [{
			"label": "关闭并继续",
			"selected_indices": [],
		}],
	})
	var utility_row := scene.get("_dialog_utility_row") as HBoxContainer
	var close_button := utility_row.get_child(0) as Button if utility_row != null and utility_row.get_child_count() == 1 else null
	if close_button != null:
		close_button.pressed.emit()

	var result := run_checks([
		assert_true(close_button != null and close_button.text == "关闭并继续", "Readonly card previews should expose their close-and-continue action"),
		assert_eq(scene._dialog_choice_call_count, 1, "Pressing close-and-continue should resolve the dialog exactly once"),
		assert_eq(Array(scene._last_dialog_choice), [], "Readonly close actions must submit an empty selection instead of the invalid [-1] sentinel"),
	])
	scene.free()
	return result


func test_public_discard_optional_card_dialog_requires_explicit_empty_action() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "portrait")
	scene.set("_pending_choice", "effect_interaction")
	var cards := [_make_test_card("Discard Pokemon"), _make_test_card("Discard Energy")]
	var labels := ["Discard Pokemon", "Discard Energy"]

	controller.call("show_dialog", scene, "Choose up to 5 cards from discard", labels, {
		"presentation": "cards",
		"card_items": cards,
		"choice_labels": labels,
		"min_select": 0,
		"max_select": 5,
		"allow_cancel": true,
		"force_confirm": true,
		"requires_explicit_empty_selection": true,
	})
	var confirm := scene.get("_dialog_confirm") as Button
	var empty_button := scene.find_child("LibrarySearchEmptySelectionButton", true, false) as Button
	var disabled_on_open := confirm != null and confirm.disabled
	if confirm != null:
		controller.call("on_dialog_confirm", scene)
	var calls_after_ambiguous_confirm := scene._dialog_choice_call_count
	if empty_button != null:
		empty_button.pressed.emit()

	var result := run_checks([
		assert_true(disabled_on_open, "Portrait discard recovery must not enable an empty normal confirm"),
		assert_eq(calls_after_ambiguous_confirm, 0, "An empty normal confirm must not resolve a public discard choice"),
		assert_true(empty_button != null and empty_button.visible, "Public optional discard choices must expose a distinct no-selection action"),
		assert_eq(scene._dialog_choice_call_count, 1, "Only the explicit no-selection action may submit an empty public choice"),
		assert_eq(Array(scene._last_dialog_choice), [], "The explicit no-selection action should preserve the empty rules payload"),
	])
	scene.free()
	return result


func test_windows_landscape_public_discard_optional_card_dialog_requires_explicit_empty_action() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	scene.set("_pending_choice", "effect_interaction")
	var cards := [_make_test_card("Discard Pokemon"), _make_test_card("Discard Energy")]
	var labels := ["Discard Pokemon", "Discard Energy"]

	controller.call("show_dialog", scene, "Choose up to 5 cards from discard", labels, {
		"presentation": "cards",
		"card_items": cards,
		"choice_labels": labels,
		"min_select": 0,
		"max_select": 5,
		"allow_cancel": true,
		"force_confirm": true,
		"requires_explicit_empty_selection": true,
	})
	var confirm := scene.get("_dialog_confirm") as Button
	var empty_button := scene.find_child("LibrarySearchEmptySelectionButton", true, false) as Button

	var result := run_checks([
		assert_true(confirm != null and confirm.disabled, "Windows landscape discard recovery must disable an ambiguous empty confirm"),
		assert_true(empty_button != null and empty_button.visible, "Windows landscape discard recovery must expose the explicit no-selection action"),
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
		assert_true(absf(scene._dialog_card_scroll.custom_minimum_size.y - scene._dialog_card_size.y) <= 0.1, "Card dialogs should not reserve a visible scrollbar lane after drag scrolling is enabled"),
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


func test_full_library_search_uses_layout_specific_board() -> String:
	var controller := BattleDialogControllerScript.new()
	var landscape_scene := DialogSceneStub.new()
	landscape_scene.set("_active_battle_layout_mode", "landscape")
	var portrait_scene := DialogSceneStub.new()
	portrait_scene.set("_active_battle_layout_mode", "portrait")
	var cards := [_make_test_card("Basic A"), _make_test_card("Basic B")]
	var labels := ["Basic A", "Basic B"]
	var data := {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 1,
		"max_select": 1,
	}

	controller.call("show_dialog", landscape_scene, "Search deck", labels, data)
	controller.call("show_dialog", portrait_scene, "Search deck", labels, data)

	var landscape_board := landscape_scene.find_child("LibrarySearchBoard", true, false) as Control
	var portrait_board := portrait_scene.find_child("LibrarySearchBoard", true, false) as Control
	var landscape_button_slot := landscape_scene.find_child("LibrarySearchButtonSlot", true, false) as HBoxContainer
	var portrait_button_slot := portrait_scene.find_child("LibrarySearchButtonSlot", true, false) as HBoxContainer
	var landscape_buttons := landscape_scene._dialog_confirm.get_parent() as HBoxContainer
	var portrait_buttons := portrait_scene._dialog_confirm.get_parent() as HBoxContainer
	var landscape_source_panel := landscape_scene.find_child("LibrarySearchSourcePanel", true, false) as Control
	var portrait_source_panel := portrait_scene.find_child("LibrarySearchSourcePanel", true, false) as Control
	var result := run_checks([
		assert_true(bool(landscape_scene.get("_dialog_library_search_board_mode")), "Landscape full-library search should enter the board mode"),
		assert_true(bool(landscape_scene.get("_dialog_card_mode")), "Board mode should still use card-dialog selection state"),
		assert_not_null(landscape_board, "Board mode should create the LibrarySearchBoard node"),
		assert_true(landscape_board != null and landscape_board.visible, "Landscape board should be visible"),
		assert_false(landscape_scene._dialog_card_scroll.visible, "Board mode should hide the legacy card scroll"),
		assert_true(landscape_buttons != null and landscape_button_slot != null and landscape_buttons.get_parent() == landscape_button_slot, "Landscape board should keep confirm/cancel in the right-side instruction bar"),
		assert_true(landscape_source_panel != null and landscape_source_panel.visible, "Landscape board should keep the right-side source-card rail"),
		assert_true(bool(portrait_scene.get("_dialog_library_search_board_mode")), "Portrait full-library search should also enter board mode"),
		assert_true(bool(portrait_scene.get("_dialog_card_mode")), "Portrait board mode should still use card-dialog selection state"),
		assert_not_null(portrait_board, "Portrait board mode should create the LibrarySearchBoard node"),
		assert_true(portrait_board != null and portrait_board.visible, "Portrait board should be visible"),
		assert_false(portrait_scene._dialog_card_scroll.visible, "Portrait board mode should hide the legacy card scroll"),
		assert_true(portrait_buttons != null and portrait_buttons.get_parent() == portrait_scene._dialog_vbox, "Portrait board should leave confirm/cancel in the bottom dialog footer"),
		assert_eq(portrait_buttons.size_flags_horizontal if portrait_buttons != null else -1, Control.SIZE_EXPAND_FILL, "Portrait footer buttons should fill the bottom action row"),
		assert_true(portrait_button_slot != null and not portrait_button_slot.visible, "Portrait board should not reserve the landscape instruction-bar button slot"),
		assert_true(portrait_source_panel != null and not portrait_source_panel.visible, "Portrait board should hide the landscape source-card rail"),
	])
	landscape_scene.free()
	portrait_scene.free()
	return result


func test_landscape_library_search_restores_footer_button_layout_for_next_dialog() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var cards := [_make_test_card("Basic A"), _make_test_card("Basic B")]
	var labels := ["Basic A", "Basic B"]

	controller.call("show_dialog", scene, "Search deck", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 1,
		"max_select": 2,
		"allow_cancel": true,
	})
	var button_slot := scene.find_child("LibrarySearchButtonSlot", true, false) as HBoxContainer
	var board_buttons := scene._dialog_confirm.get_parent() as HBoxContainer
	var board_buttons_in_instruction_bar := board_buttons != null and button_slot != null and board_buttons.get_parent() == button_slot
	var board_buttons_shrink_end := board_buttons != null and board_buttons.size_flags_horizontal == Control.SIZE_SHRINK_END

	controller.call("show_dialog", scene, "Choose many", ["One", "Two"], {
		"presentation": "list",
		"min_select": 1,
		"max_select": 2,
		"allow_cancel": true,
	})
	var restored_buttons := scene._dialog_confirm.get_parent() as HBoxContainer
	var board := scene.find_child("LibrarySearchBoard", true, false) as Control

	var result := run_checks([
		assert_true(board_buttons_in_instruction_bar, "Landscape library search should place footer buttons in the instruction bar"),
		assert_true(board_buttons_shrink_end, "Instruction-bar buttons should keep the compact right-side layout"),
		assert_true(restored_buttons != null and restored_buttons.get_parent() == scene._dialog_vbox, "The next dialog should move footer buttons back into DialogVBox"),
		assert_eq(restored_buttons.size_flags_horizontal if restored_buttons != null else -1, Control.SIZE_EXPAND_FILL, "Restored footer buttons should fill the normal dialog footer instead of staying at the lower-right"),
		assert_eq(restored_buttons.alignment if restored_buttons != null else -1, BoxContainer.ALIGNMENT_CENTER, "Restored footer buttons should be centered in the normal dialog footer"),
		assert_true(scene._dialog_confirm.visible and scene._dialog_cancel.visible, "The next multi-select skill HUD should expose both confirm and cancel buttons"),
		assert_true(board == null or not board.visible, "The old landscape search board should be hidden after switching dialogs"),
	])
	scene.free()
	return result


func test_landscape_library_search_board_hides_horizontal_scrollbars_and_uses_drag() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var cards := [_make_test_card("Basic A"), _make_test_card("Basic B"), _make_test_card("Basic C")]
	var labels := ["Basic A", "Basic B", "Basic C"]

	controller.call("show_dialog", scene, "Search deck", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1, 2],
		"min_select": 1,
		"max_select": 2,
	})
	var library_scroll := scene.find_child("LibrarySearchLibraryScroll", true, false) as ScrollContainer
	var selected_scroll := scene.find_child("LibrarySearchSelectedScroll", true, false) as ScrollContainer
	var library_row := scene.find_child("LibraryCardRow", true, false) as HBoxContainer
	var selected_row := scene.find_child("LibrarySelectedSlotRow", true, false) as HBoxContainer

	var result := run_checks([
		assert_eq(library_scroll.horizontal_scroll_mode if library_scroll != null else -1, ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Library candidate rail should hide the native horizontal scrollbar"),
		assert_eq(selected_scroll.horizontal_scroll_mode if selected_scroll != null else -1, ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Selected-card rail should hide the native horizontal scrollbar"),
		assert_eq(library_scroll.vertical_scroll_mode if library_scroll != null else -1, ScrollContainer.SCROLL_MODE_DISABLED, "Library candidate rail should stay horizontal-only"),
		assert_eq(selected_scroll.vertical_scroll_mode if selected_scroll != null else -1, ScrollContainer.SCROLL_MODE_DISABLED, "Selected-card rail should stay horizontal-only"),
		assert_true(library_scroll != null and bool(library_scroll.get_meta("card_gallery_drag_scroll_active", false)), "Library candidate rail should keep drag scrolling active"),
		assert_true(selected_scroll != null and bool(selected_scroll.get_meta("card_gallery_drag_scroll_active", false)), "Selected-card rail should keep drag scrolling active"),
		assert_true(library_scroll != null and str(library_scroll.get_meta("card_gallery_drag_source", "")) == "library_search_candidates", "Library candidate rail should use the library drag source"),
		assert_true(selected_scroll != null and str(selected_scroll.get_meta("card_gallery_drag_source", "")) == "library_search_selected", "Selected-card rail should use the selected drag source"),
		assert_true(library_row != null and bool(library_row.get_meta("card_gallery_drag_row", false)), "Library candidate row should be registered for drag scrolling"),
		assert_true(selected_row != null and bool(selected_row.get_meta("card_gallery_drag_row", false)), "Selected-card row should be registered for drag scrolling"),
	])
	scene.free()
	return result


func test_library_search_board_single_select_waits_for_confirm() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var cards := [_make_test_card("Basic A"), _make_test_card("Basic B")]
	var labels := ["Basic A", "Basic B"]

	controller.call("show_dialog", scene, "Search deck", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 1,
		"max_select": 1,
	})
	controller.call("on_library_search_candidate_pressed", scene, 1)
	var selected_after_click: Array = (scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var selected_row := scene.find_child("LibrarySelectedSlotRow", true, false) as HBoxContainer
	var selected_views := _battle_card_views_under(selected_row)
	controller.call("on_dialog_confirm", scene)

	var result := run_checks([
		assert_eq(selected_after_click, [1], "Clicking a landscape board candidate should update selected real indices"),
		assert_eq(Array(scene._last_dialog_choice), [1], "Confirm should submit the selected real index"),
		assert_eq(selected_views.size(), 1, "Selected card should be copied into the lower selected slot row"),
		assert_eq(Array(scene._last_effect_choice), [], "Candidate click should not auto-resolve the effect interaction"),
	])
	scene.free()
	return result


func test_library_search_board_confirm_returns_real_index_from_card_indices() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var cards := [_make_test_card("Visible disabled"), _make_test_card("Visible legal")]
	var labels := ["Visible disabled", "Visible legal"]

	controller.call("show_dialog", scene, "Search deck", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [-1, 4],
		"min_select": 1,
		"max_select": 1,
	})
	controller.call("on_library_search_candidate_pressed", scene, -1)
	var selected_after_disabled: Array = (scene.get("_dialog_card_selected_indices") as Array).duplicate()
	controller.call("on_library_search_candidate_pressed", scene, 4)
	controller.call("on_dialog_confirm", scene)

	var result := run_checks([
		assert_eq(selected_after_disabled, [], "Disabled visible cards should not enter the board selection"),
		assert_eq(Array(scene._last_dialog_choice), [4], "Board confirm should return the real legal index, not the visible index"),
	])
	scene.free()
	return result


func test_library_search_board_selected_slots_match_max_select() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var cards := [_make_test_card("Energy A"), _make_test_card("Energy B"), _make_test_card("Energy C")]
	var labels := ["Energy A", "Energy B", "Energy C"]

	controller.call("show_dialog", scene, "Choose up to 2 Energy", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1, 2],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})
	var selected_row := scene.find_child("LibrarySelectedSlotRow", true, false) as HBoxContainer
	var initial_empty_slots := _library_empty_slots_under(selected_row).size()
	var initial_empty_labels := _library_empty_slot_labels_under(selected_row)

	controller.call("on_library_search_candidate_pressed", scene, 0)
	var selected_views_after_one := _battle_card_views_under(selected_row).size()
	var empty_slots_after_one := _library_empty_slots_under(selected_row).size()
	var empty_labels_after_one := _library_empty_slot_labels_under(selected_row)

	controller.call("on_library_search_candidate_pressed", scene, 1)
	var selected_views_after_two := _battle_card_views_under(selected_row).size()
	var empty_slots_after_two := _library_empty_slots_under(selected_row).size()

	var result := run_checks([
		assert_eq(initial_empty_slots, 2, "Optional search board should render one lower slot per max-select card before selection"),
		assert_eq(initial_empty_labels, ["可不选择", "可不选择"], "Optional empty slots should clearly say that each pick may be skipped"),
		assert_eq(selected_views_after_one, 1, "Selecting one card should fill one lower slot"),
		assert_eq(empty_slots_after_one, 1, "Selecting one card from a max-two search should leave one optional lower slot"),
		assert_eq(empty_labels_after_one, ["可不选择"], "The remaining lower slot should still communicate that it may be skipped"),
		assert_eq(selected_views_after_two, 2, "Selecting two cards should fill both lower slots"),
		assert_eq(empty_slots_after_two, 0, "A full max-two selection should not leave extra empty slots"),
	])
	scene.free()
	return result


func test_portrait_library_search_board_uses_bottom_buttons_and_max_slots() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "portrait")
	var source_card := _make_test_card("Search Source")
	var cards := [_make_test_card("Energy A"), _make_test_card("Energy B"), _make_test_card("Energy C")]
	var labels := ["Energy A", "Energy B", "Energy C"]

	controller.call("show_dialog", scene, "Choose up to 2 Energy", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1, 2],
		"source_card": source_card,
		"source_kind": "Item",
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})
	var board := scene.find_child("LibrarySearchBoard", true, false) as Control
	var button_slot := scene.find_child("LibrarySearchButtonSlot", true, false) as HBoxContainer
	var source_panel := scene.find_child("LibrarySearchSourcePanel", true, false) as Control
	var portrait_source_panel := scene.find_child("LibrarySearchPortraitSourcePanel", true, false) as Control
	var portrait_source_holder := scene.find_child("LibrarySearchPortraitSourceCardHolder", true, false) as Control
	var buttons := scene._dialog_confirm.get_parent() as HBoxContainer
	var selected_row := scene.find_child("LibrarySelectedSlotRow", true, false) as HBoxContainer
	var initial_empty_slots := _library_empty_slots_under(selected_row).size()
	var initial_empty_label := (_library_empty_slots_under(selected_row)[0].get_child(0) as Label) if initial_empty_slots > 0 else null
	var initial_empty_label_font_size := int(initial_empty_label.get_meta("library_search_empty_slot_font_size", 0)) if initial_empty_label != null else 0
	var portrait_source_views := _battle_card_views_under(portrait_source_holder)
	controller.call("on_library_search_candidate_pressed", scene, 1)
	var selected_views_after_one := _battle_card_views_under(selected_row).size()
	var empty_slots_after_one := _library_empty_slots_under(selected_row).size()
	var remaining_empty_label := (_library_empty_slots_under(selected_row)[0].get_child(0) as Label) if empty_slots_after_one > 0 else null
	var remaining_empty_label_font_size := int(remaining_empty_label.get_meta("library_search_empty_slot_font_size", 0)) if remaining_empty_label != null else 0

	var result := run_checks([
		assert_true(bool(scene.get("_dialog_library_search_board_mode")), "Portrait full-library search should use the board mode"),
		assert_true(board != null and board.visible, "Portrait library search board should be visible"),
		assert_true(bool(board.get_meta("library_search_portrait_layout", false)) if board != null else false, "Portrait board should record portrait layout metrics"),
		assert_true(buttons != null and buttons.get_parent() == scene._dialog_vbox, "Portrait board should keep the action buttons at the bottom"),
		assert_eq(buttons.size_flags_horizontal if buttons != null else -1, Control.SIZE_EXPAND_FILL, "Portrait bottom action row should fill the dialog width"),
		assert_true(button_slot != null and not button_slot.visible, "Portrait board should hide the landscape button slot"),
		assert_true(source_panel != null and not source_panel.visible, "Portrait board should hide the landscape source rail"),
		assert_true(portrait_source_panel != null and portrait_source_panel.visible, "Portrait board should show the current source card above the candidates"),
		assert_eq(portrait_source_views.size(), 1, "Portrait source strip should render the played source card"),
		assert_true(initial_empty_label_font_size >= 32, "Portrait optional empty slot label should be large enough to read"),
		assert_eq(initial_empty_slots, 2, "Portrait optional search should render one lower slot per max-select card"),
		assert_eq(selected_views_after_one, 1, "Portrait selected card should fill one lower slot"),
		assert_eq(empty_slots_after_one, 1, "Portrait max-two search should leave one optional lower slot after one pick"),
		assert_true(remaining_empty_label_font_size >= 32, "Portrait remaining optional empty slot label should stay readable after a pick"),
	])
	scene.free()
	return result


func test_library_search_business_callbacks_trust_delivered_card_clicks() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "portrait")
	var cards := [_make_test_card("Energy A"), _make_test_card("Energy B")]
	var labels := ["Energy A", "Energy B"]

	controller.call("show_dialog", scene, "Choose up to 2 Energy", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})
	var library_row := scene.find_child("LibraryCardRow", true, false) as HBoxContainer
	var candidate_views := _battle_card_views_under(library_row)
	var candidate := candidate_views[0] if candidate_views.size() > 0 else null
	var candidate_slot := _candidate_slot_for_view(candidate)
	_emit_candidate_slot_tap(candidate_slot)
	var selected_after_candidate_click: Array = (scene.get("_dialog_card_selected_indices") as Array).duplicate()

	var selected_row := scene.find_child("LibrarySelectedSlotRow", true, false) as HBoxContainer
	var selected_views := _battle_card_views_under(selected_row)
	var selected_view := selected_views[0] if selected_views.size() > 0 else null
	if selected_view != null:
		controller.call("on_library_selected_slot_pressed", scene, 0)
	var selected_after_remove: Array = (scene.get("_dialog_card_selected_indices") as Array).duplicate()

	var result := run_checks([
		assert_eq(selected_after_candidate_click, [0], "A delivered candidate click should select the card"),
		assert_eq(selected_after_remove, [], "A delivered selected-slot click should remove the selected card"),
	])
	scene.free()
	return result


func test_library_search_board_global_touch_bridge_separates_drag_from_tap() -> String:
	var controller := BattleDialogControllerScript.new()
	var drag_scene := DialogSceneStub.new()
	drag_scene.set("_active_battle_layout_mode", "portrait")
	drag_scene._screen_position_to_battle_local_offset = Vector2(100, 0)
	var cards := [_make_test_card("Energy A"), _make_test_card("Energy B")]
	var labels := ["Energy A", "Energy B"]

	controller.call("show_dialog", drag_scene, "Choose a Basic", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	})
	var drag_scroll := drag_scene.find_child("LibrarySearchLibraryScroll", true, false) as ScrollContainer
	var drag_row := drag_scene.find_child("LibraryCardRow", true, false) as HBoxContainer
	var drag_candidate := _candidate_slot_for_view(_battle_card_views_under(drag_row)[0])
	var drag_local_center := _prepare_library_search_touch_rects(drag_scroll, drag_row, drag_candidate)
	var drag_screen_center := drag_local_center - drag_scene._screen_position_to_battle_local_offset
	var drag_handled_press := bool(controller.call("try_handle_library_search_board_touch_input", drag_scene, _screen_touch(drag_screen_center, true)))
	var drag_handled_move := bool(controller.call("try_handle_library_search_board_touch_input", drag_scene, _screen_drag(drag_screen_center + Vector2(96, 0), Vector2(96, 0))))
	var drag_handled_release := bool(controller.call("try_handle_library_search_board_touch_input", drag_scene, _screen_touch(drag_screen_center + Vector2(96, 0), false)))
	var selected_after_drag: Array = (drag_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	drag_scene.free()

	var tap_scene := DialogSceneStub.new()
	tap_scene.set("_active_battle_layout_mode", "portrait")
	tap_scene._screen_position_to_battle_local_offset = Vector2(100, 0)
	controller.call("show_dialog", tap_scene, "Choose a Basic", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	})
	var tap_scroll := tap_scene.find_child("LibrarySearchLibraryScroll", true, false) as ScrollContainer
	var tap_row := tap_scene.find_child("LibraryCardRow", true, false) as HBoxContainer
	var tap_candidate := _candidate_slot_for_view(_battle_card_views_under(tap_row)[0])
	var tap_local_center := _prepare_library_search_touch_rects(tap_scroll, tap_row, tap_candidate)
	var tap_screen_center := tap_local_center - tap_scene._screen_position_to_battle_local_offset
	var tap_handled_press := bool(controller.call("try_handle_library_search_board_touch_input", tap_scene, _screen_touch(tap_screen_center, true)))
	var tap_handled_release := bool(controller.call("try_handle_library_search_board_touch_input", tap_scene, _screen_touch(tap_screen_center, false)))
	var selected_after_tap: Array = (tap_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	tap_scene.free()

	var mouse_scene := DialogSceneStub.new()
	mouse_scene.set("_active_battle_layout_mode", "portrait")
	mouse_scene._screen_position_to_battle_local_offset = Vector2(100, 0)
	controller.call("show_dialog", mouse_scene, "Choose a Basic", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	})
	var mouse_scroll := mouse_scene.find_child("LibrarySearchLibraryScroll", true, false) as ScrollContainer
	var mouse_row := mouse_scene.find_child("LibraryCardRow", true, false) as HBoxContainer
	var mouse_candidate := _candidate_slot_for_view(_battle_card_views_under(mouse_row)[0])
	var mouse_local_center := _prepare_library_search_touch_rects(mouse_scroll, mouse_row, mouse_candidate)
	var mouse_screen_center := mouse_local_center - mouse_scene._screen_position_to_battle_local_offset
	var mouse_handled_press := bool(controller.call("try_handle_library_search_board_touch_input", mouse_scene, _mouse_button(mouse_screen_center, true)))
	var mouse_handled_release := bool(controller.call("try_handle_library_search_board_touch_input", mouse_scene, _mouse_button(mouse_screen_center, false)))
	var selected_after_mouse_tap: Array = (mouse_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	mouse_scene.free()

	return run_checks([
		assert_true(drag_handled_press and drag_handled_move and drag_handled_release, "Global touch bridge should handle candidate drag events"),
		assert_eq(selected_after_drag, [], "Rightward global touch drag should not select a library candidate"),
		assert_true(tap_handled_press and tap_handled_release, "Global touch bridge should handle candidate tap events"),
		assert_eq(selected_after_tap, [0], "Global touch tap should select the candidate under the converted battle-local coordinate"),
		assert_true(mouse_handled_press and mouse_handled_release, "Global touch bridge should handle Android mouse-style tap events"),
		assert_eq(selected_after_mouse_tap, [0], "Android mouse-style tap should select the candidate under the converted battle-local coordinate"),
	])


func test_landscape_library_search_board_uses_slot_meta_for_mouse_tap() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var cards := [_make_test_card("Energy A"), _make_test_card("Energy B")]
	var labels := ["Energy A", "Energy B"]

	controller.call("show_dialog", scene, "Choose a Basic", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	})
	var library_scroll := scene.find_child("LibrarySearchLibraryScroll", true, false) as ScrollContainer
	var library_row := scene.find_child("LibraryCardRow", true, false) as HBoxContainer
	var candidate_views := _battle_card_views_under(library_row)
	var candidate := candidate_views[0] if candidate_views.size() > 0 else null
	var candidate_slot := _candidate_slot_for_view(candidate)
	if candidate_slot != null:
		candidate_slot.name = "Control"
	var local_center := _prepare_library_search_touch_rects(library_scroll, library_row, candidate_slot)
	var handled_press := bool(controller.call("try_handle_library_search_board_touch_input", scene, _mouse_button(local_center, true)))
	var handled_release := bool(controller.call("try_handle_library_search_board_touch_input", scene, _mouse_button(local_center, false)))
	var selected_after_mouse_tap: Array = (scene.get("_dialog_card_selected_indices") as Array).duplicate()

	var result := run_checks([
		assert_not_null(candidate_slot, "Candidate card should have a marked library-search slot wrapper"),
		assert_true(candidate_slot != null and bool(candidate_slot.get_meta("library_search_candidate_slot", false)), "Candidate slot should expose a stable meta marker"),
		assert_true(handled_press and handled_release, "Landscape mouse bridge should handle candidate tap events"),
		assert_eq(selected_after_mouse_tap, [0], "Landscape mouse tap should select via slot meta even when the runtime node name is auto-generated"),
	])
	scene.free()
	return result


func test_library_search_board_allows_empty_confirm_when_min_select_zero() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var cards := [_make_test_card("Energy A"), _make_test_card("Energy B")]
	var labels := ["Energy A", "Energy B"]

	controller.call("show_dialog", scene, "Choose up to 2 Energy", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})
	var confirm := scene.get("_dialog_confirm") as Button
	var disabled_before_confirm := confirm.disabled
	controller.call("on_dialog_confirm", scene)

	var result := run_checks([
		assert_false(disabled_before_confirm, "Optional full-library board searches should allow empty confirm"),
		assert_eq(Array(scene._last_dialog_choice), [], "Empty confirm should submit an empty selection"),
	])
	scene.free()
	return result


func test_android_portrait_library_search_board_does_not_submit_empty_effect_choice_on_open() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "portrait")
	scene.set("_pending_choice", "effect_interaction")
	var cards := [_make_test_card("Basic A"), _make_test_card("Basic B")]
	var labels := ["Basic A", "Basic B"]

	controller.call("show_dialog", scene, "Choose 1 Basic Pokemon", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
		"force_confirm": true,
		"hidden_search_can_whiff": true,
	})
	var confirm := scene.get("_dialog_confirm") as Button
	var disabled_on_open := confirm.disabled if confirm != null else false
	if confirm != null and not confirm.disabled:
		controller.call("on_dialog_confirm", scene)
	var dialog_choice_calls_after_open_confirm := scene._dialog_choice_call_count
	controller.call("on_library_search_candidate_pressed", scene, 0)
	var enabled_after_selection := confirm != null and not confirm.disabled
	if confirm != null and not confirm.disabled:
		controller.call("on_dialog_confirm", scene)
	var submitted_after_selection := Array(scene._last_dialog_choice)

	var result := run_checks([
		assert_true(disabled_on_open, "Android portrait full-library effect search should not enable empty confirm before selection or an explicit skip action"),
		assert_eq(dialog_choice_calls_after_open_confirm, 0, "Opening-frame confirm should not submit an explicit empty effect selection"),
		assert_true(enabled_after_selection, "Selecting a legal card should enable the normal confirm button"),
		assert_eq(submitted_after_selection, [0], "Normal confirm should still submit the selected card after a portrait library pick"),
	])
	scene.free()
	return result


func test_android_portrait_library_search_board_reuses_cancel_slot_for_explicit_empty_choice() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "portrait")
	scene.set("_pending_choice", "effect_interaction")
	var cards := [_make_test_card("Basic A"), _make_test_card("Basic B")]
	var labels := ["Basic A", "Basic B"]

	controller.call("show_dialog", scene, "Choose 1 Basic Pokemon", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
		"force_confirm": true,
		"hidden_search_can_whiff": true,
	})
	var empty_button := scene.find_child("LibrarySearchEmptySelectionButton", true, false) as Button
	var cancel_button := scene.get("_dialog_cancel") as Button
	var utility_row := scene.get("_dialog_utility_row") as HBoxContainer
	var no_selection_visible := cancel_button != null and cancel_button.visible
	var no_selection_label := cancel_button.text if cancel_button != null else ""
	controller.call("on_dialog_cancel", scene)
	var no_selection_closed_dialog := not scene._dialog_overlay.visible
	controller.call("show_dialog", scene, "Ordinary choice", ["Continue"], {
		"presentation": "list",
		"allow_cancel": true,
	})
	var restored_cancel_label := cancel_button.text if cancel_button != null else ""

	var result := run_checks([
		assert_null(empty_button, "Android portrait hidden-search board should not stack a separate no-selection action above the footer"),
		assert_true(utility_row != null and not utility_row.visible and utility_row.get_child_count() == 0, "Android portrait hidden-search board should reclaim the redundant utility row"),
		assert_true(no_selection_visible, "Android portrait hidden-search board should keep the footer secondary action visible"),
		assert_eq(no_selection_label, "不选择", "Android portrait should replace the footer cancel label with no-selection"),
		assert_eq(scene._dialog_choice_call_count, 1, "The portrait no-selection footer action should submit exactly one dialog choice"),
		assert_eq(Array(scene._last_dialog_choice), [], "The portrait no-selection footer action should submit an empty selection"),
		assert_true(no_selection_closed_dialog, "The portrait no-selection footer action should close the library-search dialog"),
		assert_eq(restored_cancel_label, "取消", "The footer label should reset for the next ordinary portrait dialog"),
	])
	scene.free()
	return result


func test_windows_landscape_hidden_search_requires_explicit_empty_action() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	scene.set("_pending_choice", "effect_interaction")
	var cards := [_make_test_card("Basic A"), _make_test_card("Basic B")]
	var labels := ["Basic A", "Basic B"]

	controller.call("show_dialog", scene, "Choose 1 Basic Pokemon", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1],
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
		"force_confirm": true,
		"hidden_search_can_whiff": true,
	})
	var confirm := scene.get("_dialog_confirm") as Button
	var cancel_button := scene.get("_dialog_cancel") as Button
	var empty_button := scene.find_child("LibrarySearchEmptySelectionButton", true, false) as Button
	var disabled_on_open := confirm != null and confirm.disabled
	if confirm != null:
		controller.call("on_dialog_confirm", scene)
	var calls_after_normal_empty_confirm := scene._dialog_choice_call_count
	if empty_button != null:
		empty_button.pressed.emit()

	var result := run_checks([
		assert_true(disabled_on_open, "Windows landscape hidden search must disable the ambiguous empty confirm"),
		assert_eq(calls_after_normal_empty_confirm, 0, "Ambiguous empty confirm must not resolve a landscape effect prompt"),
		assert_true(empty_button != null and empty_button.visible, "Windows landscape hidden search should keep its separate explicit no-selection action"),
		assert_eq(cancel_button.text if cancel_button != null else "", "取消", "Windows landscape should keep the normal cancel action unchanged"),
		assert_eq(scene._dialog_choice_call_count, 1, "The explicit no-selection action should resolve exactly once"),
		assert_eq(Array(scene._last_dialog_choice), [], "Explicit no-selection should keep the rules payload empty"),
	])
	scene.free()
	return result


func test_library_search_board_source_card_is_read_only() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	scene.set("_active_battle_layout_mode", "landscape")
	var source_card := _make_test_card("Nest Ball")
	var cards := [_make_test_card("Basic A")]
	var labels := ["Basic A"]

	controller.call("show_dialog", scene, "Search deck", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0],
		"source_card": source_card,
		"source_kind": "trainer",
		"min_select": 1,
		"max_select": 1,
	})
	var source_holder := scene.find_child("LibrarySearchSourceCardHolder", true, false) as Control
	var source_views := _battle_card_views_under(source_holder)

	var result := run_checks([
		assert_eq(source_views.size(), 1, "Board should render the current source card in the right-side read-only panel"),
		assert_false(source_views[0].has_meta("dialog_choice_index") if source_views.size() > 0 else true, "Source card view should not be a selectable dialog candidate"),
		assert_eq(scene.get("_dialog_card_selected_indices"), [], "Rendering the source card should not change selected indices"),
	])
	scene.free()
	return result


func test_assignment_at_max_auto_confirms_unless_effect_requires_review() -> String:
	var controller := BattleDialogControllerScript.new()
	return run_checks([
		assert_true(
			bool(controller.call("should_auto_confirm_assignment", {
				"min_select": 0,
				"max_select": 2,
				"auto_confirm_at_max": true,
			}, 2)),
			"Optional assignment effects should complete as soon as every allowed assignment is made",
		),
		assert_false(
			bool(controller.call("should_auto_confirm_assignment", {
				"min_select": 1,
				"max_select": 1,
				"field_assignment_require_confirm": true,
			}, 1)),
			"Effects such as Energy Switch that require route review must keep the explicit confirm step",
		),
		assert_false(
			bool(controller.call("should_auto_confirm_assignment", {
				"min_select": 0,
				"max_select": 2,
			}, 1)),
			"An incomplete optional assignment must remain editable",
		),
		assert_false(
			bool(controller.call("should_auto_confirm_assignment", {
				"min_select": 0,
				"max_select": 2,
			}, 2)),
			"Assignment effects must opt in before reaching max skips their review step",
		),
	])


func test_any_energy_cost_icon_uses_luminous_texture() -> String:
	var controller := BattleDialogControllerScript.new()
	var luminous_icon := controller.call("_build_energy_cost_icon", "ANY", true) as TextureRect
	var colorless_icon := controller.call("_build_energy_cost_icon", "C", true) as TextureRect
	var luminous_texture := luminous_icon.texture if luminous_icon != null else null
	var colorless_texture := colorless_icon.texture if colorless_icon != null else null
	var result := run_checks([
		assert_true(luminous_texture != null, "ANY Energy costs should render the luminous Energy texture"),
		assert_eq(luminous_texture.get_size() if luminous_texture != null else Vector2.ZERO, Vector2(256, 256), "Dialog ANY markers should use the standard Energy icon source size"),
		assert_true(
			luminous_texture.resource_path != colorless_texture.resource_path if luminous_texture != null and colorless_texture != null else false,
			"ANY Energy costs should no longer fall back to the Colorless Energy texture",
		),
	])
	if luminous_icon != null:
		luminous_icon.free()
	if colorless_icon != null:
		colorless_icon.free()
	return result
