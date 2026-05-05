class_name TestFullLibrarySearchUI
extends TestBase

const BaseEffectScript = preload("res://scripts/effects/BaseEffect.gd")
const BattleDialogControllerScript = preload("res://scripts/ui/battle/BattleDialogController.gd")
const BattleEffectInteractionControllerScript = preload("res://scripts/ui/battle/BattleEffectInteractionController.gd")
const BattleInteractionControllerScript = preload("res://scripts/ui/battle/BattleInteractionController.gd")


class DialogSceneStub:
	extends Control

	var _dialog_title := Label.new()
	var _dialog_list := ItemList.new()
	var _dialog_overlay := Panel.new()
	var _dialog_cancel := Button.new()
	var _dialog_card_scroll := ScrollContainer.new()
	var _dialog_assignment_panel := VBoxContainer.new()
	var _dialog_assignment_source_scroll := ScrollContainer.new()
	var _dialog_assignment_target_scroll := ScrollContainer.new()
	var _dialog_card_row := HBoxContainer.new()
	var _dialog_utility_row := HBoxContainer.new()
	var _dialog_assignment_source_row := HBoxContainer.new()
	var _dialog_assignment_target_row := HBoxContainer.new()
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
	var clicked_indices: Array[int] = []
	var clicked_assignment_source_indices: Array[int] = []
	var clicked_assignment_target_indices: Array[int] = []

	func _init() -> void:
		for node: Node in [
			_dialog_title,
			_dialog_list,
			_dialog_overlay,
			_dialog_cancel,
			_dialog_card_scroll,
			_dialog_assignment_panel,
			_dialog_assignment_source_scroll,
			_dialog_assignment_target_scroll,
			_dialog_card_row,
			_dialog_utility_row,
			_dialog_assignment_source_row,
			_dialog_assignment_target_row,
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

	func _on_dialog_card_left_signal(_card_instance: CardInstance, _card_data: CardData, choice_index: int) -> void:
		clicked_indices.append(choice_index)

	func _on_dialog_card_right_signal(_card_instance: CardInstance, _card_data: CardData) -> void:
		pass

	func _on_assignment_source_chosen(source_index: int) -> void:
		clicked_assignment_source_indices.append(source_index)

	func _on_assignment_target_chosen(target_index: int) -> void:
		clicked_assignment_target_indices.append(target_index)

	func _show_card_detail(_card_data: CardData) -> void:
		pass


class FieldAssignmentSceneStub:
	extends Control

	var _field_interaction_row := HBoxContainer.new()
	var _field_interaction_data: Dictionary = {}
	var _field_interaction_assignment_entries: Array[Dictionary] = []
	var _field_interaction_assignment_selected_source_index := -1
	var _play_card_size := Vector2(92, 129)
	var clicked_field_source_indices: Array[int] = []

	func _init() -> void:
		add_child(_field_interaction_row)

	func _clear_container_children(container: Node) -> void:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.free()

	func _setup_dialog_card_view(card_view: BattleCardView, item: Variant, label: String) -> void:
		if item is CardInstance:
			var card: CardInstance = item
			card_view.setup_from_instance(card, BattleCardView.MODE_CHOICE)
			card_view.set_info(card.card_data.name, label)
		elif item is CardData:
			var data: CardData = item
			card_view.setup_from_card_data(data, BattleCardView.MODE_CHOICE)
			card_view.set_info(data.name, label)
		else:
			card_view.setup_from_instance(null, BattleCardView.MODE_CHOICE)
			card_view.set_info(str(label), "")

	func _on_field_assignment_source_chosen(source_index: int) -> void:
		clicked_field_source_indices.append(source_index)

	func _show_card_detail(_card_data: CardData) -> void:
		pass


class EffectSceneStub:
	extends Control

	var _pending_effect_card: CardInstance = null
	var _pending_effect_kind := ""
	var _pending_effect_slot: PokemonSlot = null
	var _pending_effect_ability_index := -1
	var _pending_effect_attack_data: Dictionary = {}
	var _pending_effect_attack_effects: Array[BaseEffect] = []
	var _pending_effect_step_index := 0
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_context: Dictionary = {}
	var _pending_effect_player_index := 0
	var _pending_choice := ""
	var _view_player := 0
	var _gsm = null
	var shown_title := ""
	var shown_items: Array = []
	var shown_extra_data: Dictionary = {}

	func _bt(key: String, _params: Dictionary = {}) -> String:
		return key

	func _has_pending_coin_animation() -> bool:
		return false

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass

	func _log(_message: String) -> void:
		pass

	func _dialog_item_has_card_visual(item: Variant) -> bool:
		return item is CardInstance or item is CardData or item is PokemonSlot

	func _show_dialog(title: String, items: Array, extra_data: Dictionary = {}) -> void:
		shown_title = title
		shown_items = items.duplicate(true)
		shown_extra_data = extra_data.duplicate(true)

	func _reset_effect_interaction() -> void:
		pass

	func _effect_state_snapshot() -> String:
		return ""

	func _is_field_interaction_active() -> bool:
		return false

	func _hide_field_interaction() -> void:
		pass

	func _reset_dialog_assignment_state() -> void:
		pass

	func _maybe_run_ai() -> void:
		pass

	func _state_snapshot() -> String:
		return ""

	func _refresh_ui() -> void:
		pass

	func _check_two_player_handover() -> void:
		pass

	func _get_trainer_followup_evolve_slot() -> PokemonSlot:
		return null

	func _try_start_evolve_trigger_ability_interaction(_player_index: int, _slot: PokemonSlot) -> void:
		pass


func _make_test_card(name: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 60
	return CardInstance.create(card_data, 0)


func _make_visible_cards(count: int) -> Array:
	var cards: Array = []
	for i: int in count:
		cards.append(_make_test_card("Visible %02d" % (i + 1)))
	return cards


func _contains_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _contains_label_text(child, text):
			return true
	return false


func _full_library_indices() -> Array[int]:
	return [-1, 0, -1, -1, 1, -1, -1, -1, 2, -1]


func test_base_effect_builds_full_library_search_contract() -> String:
	var effect := BaseEffectScript.new()
	var visible_cards := _make_visible_cards(10)
	var legal_items := [visible_cards[1], visible_cards[4], visible_cards[8]]

	var step: Dictionary = effect.call(
		"build_full_library_search_step",
		"choose_cards",
		"Choose cards",
		visible_cards,
		legal_items,
		"own_full_deck",
		1,
		3
	)

	var choice_labels: Array = step.get("choice_labels", [])
	return run_checks([
		assert_eq(step.get("items", []), legal_items, "items must contain only legal selectable cards"),
		assert_eq(step.get("card_items", []), visible_cards, "card_items must contain all 10 visible cards"),
		assert_eq(step.get("card_indices", []), _full_library_indices(), "card_indices must map visible cards to legal item indices and use -1 for disabled cards"),
		assert_eq(str(step.get("visible_scope", "")), "own_full_deck", "Full-deck visibility must be explicit"),
		assert_eq(str(step.get("card_disabled_badge", "")), "不可选", "Own full-deck disabled cards should default to the standard badge"),
		assert_eq(choice_labels.size(), 10, "choice_labels should describe every visible card"),
		assert_str_contains(str(choice_labels[0]), "不可选", "Disabled visible cards should be labeled as not selectable"),
		assert_str_contains(str(choice_labels[1]), "可选", "Legal visible cards should be labeled as selectable"),
	])


func test_effect_interaction_passes_full_library_dialog_metadata() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var effect := BaseEffectScript.new()
	var controller := BattleEffectInteractionControllerScript.new()
	var visible_cards := _make_visible_cards(10)
	var legal_items := [visible_cards[1], visible_cards[4], visible_cards[8]]
	var step: Dictionary = effect.call(
		"build_full_library_search_step",
		"choose_cards",
		"Choose cards",
		visible_cards,
		legal_items,
		"own_full_deck",
		1,
		3,
		{
			"show_selectable_hints": true,
			"card_selectable_hint": "Pick",
		}
	)
	var scene := EffectSceneStub.new()
	scene._pending_effect_card = _make_test_card("Source")
	scene._pending_effect_steps = [step]

	controller.call("show_next_effect_interaction_step", scene)
	var first_shown_items := scene.shown_items.duplicate(true)
	var first_extra := scene.shown_extra_data.duplicate(true)
	scene._pending_effect_steps.append({
		"id": "hold_context",
		"title": "Hold",
		"items": [],
		"labels": [],
		"presentation": "list",
		"min_select": 0,
		"max_select": 0,
	})
	controller.call("handle_effect_interaction_choice", scene, PackedInt32Array([0, 2, 9, -1]))
	var selected_items: Array = scene._pending_effect_context.get("choose_cards", [])

	GameManager.current_mode = previous_mode
	var extra := first_extra
	return run_checks([
		assert_eq(first_shown_items.size(), 3, "Dialog entry items must remain the legal label list, not the visible card list"),
		assert_eq(extra.get("card_items", []), visible_cards, "card_items should be passed through to the dialog"),
		assert_eq(extra.get("card_indices", []), _full_library_indices(), "card_indices should be passed through to the dialog"),
		assert_eq(str(extra.get("visible_scope", "")), "own_full_deck", "visible_scope should be passed through to the dialog"),
		assert_eq(str(extra.get("card_disabled_badge", "")), "不可选", "card_disabled_badge should be passed through to the dialog"),
		assert_true(bool(extra.get("show_selectable_hints", false)), "show_selectable_hints should be passed through to the dialog"),
		assert_eq(str(extra.get("card_selectable_hint", "")), "Pick", "card_selectable_hint should be passed through to the dialog"),
		assert_eq((extra.get("choice_labels", []) as Array).size(), 10, "visible choice_labels should be passed through to the dialog"),
		assert_eq(selected_items, [legal_items[0], legal_items[2]], "Confirmed effect choices should resolve only legal item indices and ignore visible-only indices"),
	])


func test_effect_interaction_defaults_own_full_deck_disabled_badge() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var controller := BattleEffectInteractionControllerScript.new()
	var visible_cards := _make_visible_cards(10)
	var legal_items := [visible_cards[1], visible_cards[4], visible_cards[8]]
	var step := {
		"id": "choose_cards",
		"title": "Choose cards",
		"items": legal_items,
		"labels": ["Visible 02", "Visible 05", "Visible 09"],
		"presentation": "cards",
		"card_items": visible_cards,
		"card_indices": _full_library_indices(),
		"visible_scope": "own_full_deck",
		"min_select": 1,
		"max_select": 1,
	}
	var scene := EffectSceneStub.new()
	scene._pending_effect_card = _make_test_card("Source")
	scene._pending_effect_steps = [step]

	controller.call("show_next_effect_interaction_step", scene)

	GameManager.current_mode = previous_mode
	return assert_eq(
		str(scene.shown_extra_data.get("card_disabled_badge", "")),
		"不可选",
		"Own full-deck dialog metadata should default disabled visible cards to 不可选"
	)


func test_dialog_renders_visible_disabled_cards_without_selecting_them() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	var visible_cards := _make_visible_cards(10)
	var legal_labels := ["Visible 02", "Visible 05", "Visible 09"]
	var visible_labels: Array[String] = []
	for i: int in visible_cards.size():
		visible_labels.append("%s %s" % [
			visible_cards[i].card_data.name,
			"可选" if int(_full_library_indices()[i]) >= 0 else "不可选",
		])

	controller.call("show_dialog", scene, "Choose cards", legal_labels, {
		"presentation": "cards",
		"card_items": visible_cards,
		"card_indices": _full_library_indices(),
		"choice_labels": visible_labels,
		"card_disabled_badge": "不可选",
		"min_select": 1,
		"max_select": 3,
	})

	var card_row: HBoxContainer = scene.get("_dialog_card_row")
	var enabled_card := card_row.get_child(0) as BattleCardView
	var disabled_card := card_row.get_child(3) as BattleCardView
	disabled_card.left_clicked.emit(disabled_card.card_instance, disabled_card.card_data)
	var clicked_after_disabled := scene.clicked_indices.duplicate()
	enabled_card.left_clicked.emit(enabled_card.card_instance, enabled_card.card_data)
	var clicked_after_enabled := scene.clicked_indices.duplicate()

	var result := run_checks([
		assert_eq(card_row.get_child_count(), 10, "The dialog should render all 10 visible cards"),
		assert_eq(int(disabled_card.get_meta("dialog_choice_index", 99)), -1, "Disabled visible cards should use -1 choice indices"),
		assert_eq(int(enabled_card.get_meta("dialog_choice_index", 99)), 0, "Enabled visible cards should map to their legal item index"),
		assert_true(_contains_label_text(disabled_card, "不可选"), "Disabled visible cards should show the disabled badge"),
		assert_eq(clicked_after_disabled, [], "Disabled visible cards should not emit selectable choices"),
		assert_eq(clicked_after_enabled, [0], "Enabled visible cards should emit their legal item index"),
	])
	scene.free()
	return result


func test_dialog_assignment_renders_full_library_source_metadata() -> String:
	var controller := BattleDialogControllerScript.new()
	var scene := DialogSceneStub.new()
	var visible_cards := _make_visible_cards(5)
	var source_items := [visible_cards[1], visible_cards[3]]
	var source_indices := [-1, 0, -1, 1, -1]
	var source_labels := ["Visible 02", "Visible 04"]
	var source_choice_labels := [
		"Visible 01 - LOCKED",
		"Visible 02 - PICK",
		"Visible 03 - LOCKED",
		"Visible 04 - PICK",
		"Visible 05 - LOCKED",
	]

	controller.call("show_dialog", scene, "Assign sources", [], {
		"ui_mode": "card_assignment",
		"source_items": source_items,
		"source_labels": source_labels,
		"source_card_items": visible_cards,
		"source_card_indices": source_indices,
		"source_choice_labels": source_choice_labels,
		"source_card_disabled_badge": "LOCKED",
		"target_items": [_make_test_card("Target")],
		"target_labels": ["Target"],
		"min_select": 1,
		"max_select": 1,
	})

	var source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var target_row: HBoxContainer = scene.get("_dialog_assignment_target_row")
	var enabled_card := source_row.get_child(0) as BattleCardView
	var disabled_card := source_row.get_child(2) as BattleCardView
	disabled_card.left_clicked.emit(disabled_card.card_instance, disabled_card.card_data)
	var clicked_after_disabled := scene.clicked_assignment_source_indices.duplicate()
	enabled_card.left_clicked.emit(enabled_card.card_instance, enabled_card.card_data)
	var clicked_after_enabled := scene.clicked_assignment_source_indices.duplicate()

	var result := run_checks([
		assert_eq(source_row.get_child_count(), 5, "Assignment source row should render every visible deck card"),
		assert_eq(int(disabled_card.get_meta("assignment_source_index", 99)), -1, "Disabled visible source cards should map to -1"),
		assert_eq(int(enabled_card.get_meta("assignment_source_index", 99)), 0, "Enabled visible source cards should map to legal source_items indices"),
		assert_true(bool(disabled_card.get_meta("assignment_source_disabled", false)), "Disabled source cards should be tagged as disabled"),
		assert_true(_contains_label_text(disabled_card, "LOCKED"), "Disabled assignment source cards should show the disabled badge"),
		assert_eq(clicked_after_disabled, [], "Disabled visible source cards should not emit assignment source choices"),
		assert_eq(clicked_after_enabled, [0], "Enabled visible source cards should emit their legal source index"),
		assert_eq(source_row.custom_minimum_size.y, scene._dialog_card_size.y, "Assignment source row should stay card-height so the scrollbar sits below cards"),
		assert_eq(target_row.custom_minimum_size.y, scene._dialog_card_size.y, "Assignment target row should stay card-height so the scrollbar sits below cards"),
		assert_eq(source_row.size_flags_vertical, Control.SIZE_SHRINK_BEGIN, "Assignment source row should not stretch into the scrollbar lane"),
		assert_eq(target_row.size_flags_vertical, Control.SIZE_SHRINK_BEGIN, "Assignment target row should not stretch into the scrollbar lane"),
	])
	scene.free()
	return result


func test_field_assignment_renders_full_library_source_metadata() -> String:
	var controller := BattleInteractionControllerScript.new()
	var scene := FieldAssignmentSceneStub.new()
	var visible_cards := _make_visible_cards(5)
	var source_items := [visible_cards[1], visible_cards[3]]
	scene._field_interaction_data = {
		"source_items": source_items,
		"source_labels": ["Visible 02", "Visible 04"],
		"source_card_items": visible_cards,
		"source_card_indices": [-1, 0, -1, 1, -1],
		"source_choice_labels": [
			"Visible 01 - LOCKED",
			"Visible 02 - PICK",
			"Visible 03 - LOCKED",
			"Visible 04 - PICK",
			"Visible 05 - LOCKED",
		],
		"source_card_disabled_badge": "LOCKED",
	}

	controller.call("build_field_assignment_source_cards", scene)
	controller.call("refresh_field_assignment_source_views", scene)

	var source_row: HBoxContainer = scene.get("_field_interaction_row")
	var enabled_card := source_row.get_child(0) as BattleCardView
	var disabled_card := source_row.get_child(2) as BattleCardView
	disabled_card.left_clicked.emit(disabled_card.card_instance, disabled_card.card_data)
	var clicked_after_disabled := scene.clicked_field_source_indices.duplicate()
	enabled_card.left_clicked.emit(enabled_card.card_instance, enabled_card.card_data)
	var clicked_after_enabled := scene.clicked_field_source_indices.duplicate()

	var result := run_checks([
		assert_eq(source_row.get_child_count(), 5, "Field assignment source row should render every visible deck card"),
		assert_eq(int(disabled_card.get_meta("field_assignment_source_index", 99)), -1, "Disabled visible field source cards should map to -1"),
		assert_eq(int(enabled_card.get_meta("field_assignment_source_index", 99)), 0, "Enabled visible field source cards should map to legal source_items indices"),
		assert_true(bool(disabled_card.get_meta("field_assignment_source_disabled", false)), "Disabled field source cards should be tagged as disabled"),
		assert_true(_contains_label_text(disabled_card, "LOCKED"), "Disabled field source cards should show the disabled badge"),
		assert_eq(clicked_after_disabled, [], "Disabled visible field source cards should not emit assignment source choices"),
		assert_eq(clicked_after_enabled, [0], "Enabled visible field source cards should emit their legal source index"),
	])
	scene.free()
	return result
