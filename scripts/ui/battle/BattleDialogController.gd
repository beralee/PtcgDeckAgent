class_name BattleDialogController
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const ENERGY_ICON_TEXTURES := {
	"R": preload("res://assets/ui/e-huo.png"),
	"W": preload("res://assets/ui/e-shui.png"),
	"G": preload("res://assets/ui/e-cao.png"),
	"L": preload("res://assets/ui/e-lei.png"),
	"P": preload("res://assets/ui/e-chao.png"),
	"F": preload("res://assets/ui/e-dou.png"),
	"D": preload("res://assets/ui/e-e.png"),
	"M": preload("res://assets/ui/e-gang.png"),
	"N": preload("res://assets/ui/e-long.png"),
	"C": preload("res://assets/ui/e-wu.png"),
}

func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func _replace_int_array(scene: Object, property_name: String, values: Array) -> void:
	var snapshot := values.duplicate()
	var target: Array[int] = scene.get(property_name)
	target.clear()
	for value_variant: Variant in snapshot:
		target.append(int(value_variant))
	scene.set(property_name, target)


func _replace_dictionary_array(scene: Object, property_name: String, values: Array) -> void:
	var snapshot := values.duplicate(true)
	var target: Array[Dictionary] = scene.get(property_name)
	target.clear()
	for value_variant: Variant in snapshot:
		if value_variant is Dictionary:
			target.append((value_variant as Dictionary).duplicate(true))
	scene.set(property_name, target)


func dialog_item_has_card_visual(item: Variant) -> bool:
	return item is CardInstance or item is CardData or item is PokemonSlot


func dialog_choice_subtitle(scene: Object, item: Variant, label: String) -> String:
	if item is PokemonSlot:
		var slot: PokemonSlot = item
		return "HP %d/%d" % [scene.call("_get_display_remaining_hp", slot), scene.call("_get_display_max_hp", slot)]
	if item is CardInstance:
		var card: CardInstance = item
		if label != "" and label != card.card_data.name:
			return label
		return str(scene.call("_hand_card_subtext", card.card_data))
	if item is CardData:
		var data: CardData = item
		if label != "" and label != data.name:
			return label
		return str(scene.call("_hand_card_subtext", data))
	return label


func selection_label_from_item(item: Variant, fallback: String = "") -> String:
	if fallback.strip_edges() != "":
		return fallback.strip_edges()
	if item is PokemonSlot:
		return (item as PokemonSlot).get_pokemon_name()
	if item is CardInstance:
		var card: CardInstance = item
		return card.card_data.name if card.card_data != null else ""
	if item is CardData:
		return (item as CardData).name
	if item is Dictionary:
		var entry: Dictionary = item
		for key: String in ["pokemon_name", "card_name", "name", "title"]:
			var text := str(entry.get(key, "")).strip_edges()
			if text != "":
				return text
	return str(item).strip_edges()


func selected_dialog_labels(scene: Object, sel_items: PackedInt32Array) -> Array[String]:
	var labels: Array[String] = []
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_items_data: Array = scene.get("_dialog_items_data")
	var choice_labels: Array = dialog_data.get("choice_labels", dialog_items_data)
	for idx: int in sel_items:
		if idx < 0:
			continue
		var item: Variant = dialog_items_data[idx] if idx < dialog_items_data.size() else null
		var fallback := str(choice_labels[idx]) if idx < choice_labels.size() else ""
		labels.append(selection_label_from_item(item, fallback))
	return labels


func selected_assignment_labels(assignments: Array[Dictionary]) -> Array[String]:
	var labels: Array[String] = []
	for assignment: Dictionary in assignments:
		var source_label := selection_label_from_item(assignment.get("source"))
		var target_label := selection_label_from_item(assignment.get("target"))
		if source_label != "" and target_label != "":
			labels.append("%s -> %s" % [source_label, target_label])
		elif source_label != "":
			labels.append(source_label)
		elif target_label != "":
			labels.append(target_label)
	return labels


func setup_dialog_card_view(scene: Object, card_view: BattleCardView, item: Variant, label: String) -> void:
	if item is CardInstance:
		card_view.setup_from_instance(item, BattleCardView.MODE_CHOICE)
		card_view.set_info(item.card_data.name, dialog_choice_subtitle(scene, item, label))
	elif item is CardData:
		card_view.setup_from_card_data(item, BattleCardView.MODE_CHOICE)
		card_view.set_info(item.name, dialog_choice_subtitle(scene, item, label))
	elif item is PokemonSlot:
		var slot: PokemonSlot = item
		card_view.setup_from_card_data(slot.get_card_data(), scene.call("_battle_card_mode_for_slot", slot))
		card_view.set_badges()
		card_view.set_battle_status(scene.call("_build_battle_status", slot))
	else:
		card_view.setup_from_instance(null, BattleCardView.MODE_CHOICE)
		card_view.set_info(str(label), "")


func dialog_should_use_card_mode(items: Array, extra_data: Dictionary) -> bool:
	var presentation := str(extra_data.get("presentation", "auto"))
	if presentation == "cards":
		return true
	if presentation in ["list", "action_hud"]:
		return false
	var card_items: Array = extra_data.get("card_items", items)
	for item: Variant in card_items:
		if not dialog_item_has_card_visual(item):
			return false
	return not card_items.is_empty()


func reset_dialog_assignment_state(scene: Object) -> void:
	scene.set("_dialog_assignment_mode", false)
	scene.set("_dialog_assignment_selected_source_index", -1)
	_replace_dictionary_array(scene, "_dialog_assignment_assignments", [])
	var assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	if assignment_panel != null:
		assignment_panel.visible = false
	var summary_label: Label = scene.get("_dialog_assignment_summary_lbl")
	if summary_label != null:
		summary_label.text = ""


func show_dialog(scene: Object, title: String, items: Array, extra_data: Dictionary = {}) -> void:
	var dialog_title: Label = scene.get("_dialog_title")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	dialog_title.text = title
	dialog_list.clear()
	scene.set("_dialog_items_data", items)
	scene.set("_dialog_data", extra_data)
	_replace_int_array(scene, "_dialog_multi_selected_indices", [])
	_replace_int_array(scene, "_dialog_card_selected_indices", [])
	reset_dialog_assignment_state(scene)

	var presentation := str(extra_data.get("presentation", "auto"))
	var assignment_mode := str(extra_data.get("ui_mode", "")) == "card_assignment"
	var action_hud_mode := presentation == "action_hud"
	scene.set("_dialog_assignment_mode", assignment_mode)
	var card_mode := false if assignment_mode or action_hud_mode else dialog_should_use_card_mode(items, extra_data)
	scene.set("_dialog_card_mode", card_mode)

	if assignment_mode:
		show_assignment_dialog(scene, extra_data)
	elif action_hud_mode:
		show_action_hud_dialog(scene, items, extra_data)
	elif card_mode:
		show_card_dialog(scene, items, extra_data)
	else:
		show_text_dialog(scene, items, extra_data)

	apply_dialog_surface_style(scene, bool(extra_data.get("transparent_battlefield_dialog", false)) or not (extra_data.get("card_groups", []) as Array).is_empty())
	style_dialog_footer_buttons(scene)
	dialog_overlay.modulate = Color(1, 1, 1, 0)
	dialog_overlay.visible = true
	dialog_cancel.visible = bool(extra_data.get("allow_cancel", true))
	update_dialog_confirm_state(scene)
	compact_dialog_box_to_content(scene)
	reveal_dialog_after_layout(scene, dialog_overlay)
	scene.call(
		"_runtime_log",
		"show_dialog",
		"title=%s mode=%s items=%d %s" % [
			title,
			"assignment" if assignment_mode else ("action_hud" if action_hud_mode else ("cards" if card_mode else "list")),
			items.size(),
			scene.call("_dialog_state_snapshot"),
		]
	)
	scene.call("_record_battle_state_snapshot", "before_choice_context", {
		"prompt_source": "dialog",
		"prompt_type": str(extra_data.get("prompt_type", scene.get("_pending_choice"))),
		"title": title,
	})
	scene.call("_record_battle_event", {
		"event_type": "choice_context",
		"prompt_source": "dialog",
		"prompt_type": str(extra_data.get("prompt_type", scene.get("_pending_choice"))),
		"title": title,
		"items": items.duplicate(true),
		"extra_data": extra_data.duplicate(true),
		"player_index": int(extra_data.get("player", _current_player_index(scene))),
		"turn_number": _turn_number(scene),
		"phase": scene.call("_recording_phase_name"),
	})
	if not assignment_mode and int(extra_data.get("max_select", 1)) > 1:
		scene.call("_log", "已启用多选：先选择卡牌，再点击确认。")


func apply_dialog_surface_style(scene: Object, transparent: bool) -> void:
	var dialog_overlay := scene.get("_dialog_overlay") as Panel
	var dialog_box := scene.get("_dialog_box") as PanelContainer
	if dialog_overlay != null:
		var overlay_style := StyleBoxFlat.new()
		overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.0 if transparent else 0.70)
		dialog_overlay.add_theme_stylebox_override("panel", overlay_style)
	if dialog_box != null:
		dialog_box.add_theme_stylebox_override("panel", transparent_dialog_box_style() if transparent else default_dialog_box_style())


func default_dialog_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.11, 0.98)
	style.border_color = Color(0.38, 0.55, 0.72, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	return style


func transparent_dialog_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.050, 0.94)
	style.border_color = Color(0.30, 0.64, 0.76, 0.82)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	return style


func compact_dialog_box_to_content(scene: Object) -> void:
	var dialog_box := scene.get("_dialog_box") as Control
	if dialog_box == null:
		return
	dialog_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	compact_visible_dialog_scroll(scene, "_dialog_card_scroll")
	compact_visible_dialog_scroll(scene, "_dialog_assignment_source_scroll")
	compact_visible_dialog_scroll(scene, "_dialog_assignment_target_scroll")
	var target_height := stable_dialog_box_content_height(scene, dialog_box)
	var minimum_size := dialog_box.custom_minimum_size
	minimum_size.y = target_height
	dialog_box.custom_minimum_size = minimum_size
	dialog_box.update_minimum_size()
	dialog_box.size = Vector2(dialog_box.size.x, target_height)
	var dialog_vbox := dialog_vbox_from_scene(scene, dialog_box)
	if dialog_vbox != null:
		var panel_minimum_y := 0.0
		var panel_style := dialog_box.get_theme_stylebox("panel")
		if panel_style != null:
			panel_minimum_y = panel_style.get_minimum_size().y
		dialog_vbox.size = Vector2(dialog_vbox.size.x, maxf(0.0, target_height - panel_minimum_y))
	var parent := dialog_box.get_parent()
	if parent is Container:
		(parent as Container).queue_sort()


func reveal_dialog_after_layout(scene: Object, dialog_overlay: Control) -> void:
	var reveal_id := int(dialog_overlay.get_meta("dialog_reveal_id", 0)) + 1
	dialog_overlay.set_meta("dialog_reveal_id", reveal_id)
	if scene is Node:
		var scene_node := scene as Node
		if scene_node.is_inside_tree():
			var tree := scene_node.get_tree()
			tree.process_frame.connect(func() -> void:
				if not is_instance_valid(scene):
					return
				if not is_instance_valid(dialog_overlay):
					return
				if int(dialog_overlay.get_meta("dialog_reveal_id", -1)) != reveal_id:
					return
				if not dialog_overlay.visible:
					return
				compact_dialog_box_to_content(scene)
				dialog_overlay.modulate = Color.WHITE
			, CONNECT_ONE_SHOT)
			return
	dialog_overlay.call_deferred("set", "modulate", Color.WHITE)


func stable_dialog_box_content_height(scene: Object, dialog_box: Control) -> float:
	var dialog_vbox := dialog_vbox_from_scene(scene, dialog_box)
	if dialog_vbox == null:
		return 0.0
	var visible_count := 0
	var height := 0.0
	for child: Node in dialog_vbox.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if not control.visible:
			continue
		height += stable_dialog_child_height(control)
		visible_count += 1
	if visible_count > 1:
		height += float(dialog_vbox.get_theme_constant("separation")) * float(visible_count - 1)
	var panel_style := dialog_box.get_theme_stylebox("panel")
	if panel_style != null:
		height += panel_style.get_minimum_size().y
	return ceilf(height)


func stable_dialog_child_height(control: Control) -> float:
	if control is ScrollContainer and control.custom_minimum_size.y > 0.0:
		return control.custom_minimum_size.y
	return maxf(control.get_minimum_size().y, control.custom_minimum_size.y)


func dialog_vbox_from_scene(scene: Object, dialog_box: Control) -> VBoxContainer:
	var dialog_vbox := scene.get("_dialog_vbox") as VBoxContainer
	if dialog_vbox == null and dialog_box.get_child_count() > 0 and dialog_box.get_child(0) is VBoxContainer:
		dialog_vbox = dialog_box.get_child(0) as VBoxContainer
	return dialog_vbox


func compact_visible_dialog_scroll(scene: Object, property_name: String) -> void:
	var scroll := scene.get(property_name) as Control
	if scroll == null or not scroll.visible:
		return
	var scroll_minimum := scroll.custom_minimum_size
	if scroll_minimum.y <= 0.0:
		return
	scroll.size = Vector2(scroll.size.x, scroll_minimum.y)
	scroll.update_minimum_size()


func show_text_dialog(scene: Object, items: Array, extra_data: Dictionary) -> void:
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_list: ItemList = scene.get("_dialog_list")
	dialog_card_scroll.visible = true
	dialog_assignment_panel.visible = false
	dialog_status_lbl.visible = false
	dialog_utility_row.visible = false
	dialog_confirm.visible = int(extra_data.get("max_select", 1)) > 1 or int(extra_data.get("min_select", 1)) > 1
	dialog_list.visible = false
	dialog_list.custom_minimum_size = Vector2.ZERO
	dialog_card_scroll.scroll_horizontal = 0
	dialog_card_scroll.scroll_vertical = 0
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if items.size() > 5 else ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.custom_minimum_size = Vector2(0, _action_hud_scroll_height(items.size()))
	HudThemeScript.style_scroll_container(dialog_card_scroll, "touch")
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)
	for item: Variant in items:
		dialog_list.add_item(str(item))
	dialog_list.select_mode = ItemList.SELECT_TOGGLE if int(extra_data.get("max_select", 1)) > 1 else ItemList.SELECT_SINGLE
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	if dialog_list.select_mode != ItemList.SELECT_SINGLE:
		dialog_list.multi_selected.connect(Callable(scene, "_on_dialog_item_multi_selected"))
	else:
		dialog_list.item_selected.connect(Callable(scene, "_on_dialog_item_selected"))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	dialog_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_card_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_card_row.custom_minimum_size = Vector2.ZERO
	dialog_card_row.add_child(stack)
	for i: int in items.size():
		stack.add_child(_build_text_hud_option(scene, str(items[i]), i))
	sync_text_hud_selection(scene)


func style_dialog_footer_buttons(scene: Object) -> void:
	var dialog_cancel := scene.get("_dialog_cancel") as Button
	var dialog_confirm := scene.get("_dialog_confirm") as Button
	var buttons_row := dialog_confirm.get_parent() as HBoxContainer if dialog_confirm != null else null
	if buttons_row != null:
		buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons_row.add_theme_constant_override("separation", 12)
	if dialog_cancel != null:
		style_dialog_button(dialog_cancel, "secondary")
	if dialog_confirm != null:
		style_dialog_button(dialog_confirm, "primary")


func style_dialog_button(button: Button, role: String = "primary") -> void:
	if button == null:
		return
	var accent := Color(1.0, 0.62, 0.28, 1.0) if role == "primary" else Color(0.36, 0.86, 1.0, 1.0)
	if role == "danger":
		accent = Color(1.0, 0.38, 0.30, 1.0)
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 172.0), maxf(button.custom_minimum_size.y, 56.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.55, 0.60, 1.0))
	button.add_theme_stylebox_override("normal", _dialog_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _dialog_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _dialog_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _dialog_button_style(Color(0.28, 0.34, 0.40, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _dialog_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.28) if pressed else Color(0.025, 0.075, 0.105, 0.95)
	if hover and not pressed:
		style.bg_color = Color(0.045, 0.13, 0.17, 0.98)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hover else 0.16)
	style.shadow_size = 10 if hover else 5
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _build_text_hud_option(scene: Object, label_text: String, option_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 74)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("dialog_text_choice_index", option_index)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				on_text_hud_option_pressed(scene, option_index)
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var index_label := Label.new()
	index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_label.custom_minimum_size = Vector2(44, 42)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	index_label.text = str(option_index + 1)
	index_label.add_theme_font_size_override("font_size", 18)
	index_label.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08, 1.0))
	index_label.add_theme_stylebox_override("normal", _action_hud_pill_style(Color(0.36, 0.86, 1.0, 1.0), true))
	row.add_child(index_label)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = label_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	row.add_child(title)

	style_text_hud_option(panel, false)
	return panel


func on_text_hud_option_pressed(scene: Object, option_index: int) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	var is_multi := max_select > 1 or min_select > 1
	if not is_multi:
		confirm_dialog_selection(scene, PackedInt32Array([option_index]))
		return
	var selected_indices: Array = scene.get("_dialog_multi_selected_indices")
	if option_index in selected_indices:
		selected_indices.erase(option_index)
	elif max_select <= 0 or selected_indices.size() < max_select:
		selected_indices.append(option_index)
	_replace_int_array(scene, "_dialog_multi_selected_indices", selected_indices)
	sync_text_hud_selection(scene)
	update_dialog_confirm_state(scene)


func sync_text_hud_selection(scene: Object) -> void:
	var dialog_card_row := scene.get("_dialog_card_row") as HBoxContainer
	if dialog_card_row == null:
		return
	var selected_indices: Array = scene.get("_dialog_multi_selected_indices")
	for child: Node in dialog_card_row.get_children():
		_sync_text_hud_selection_recursive(child, selected_indices)


func _sync_text_hud_selection_recursive(node: Node, selected_indices: Array) -> void:
	if node is PanelContainer and node.has_meta("dialog_text_choice_index"):
		var panel := node as PanelContainer
		var idx := int(panel.get_meta("dialog_text_choice_index", -1))
		style_text_hud_option(panel, idx in selected_indices)
	for child: Node in node.get_children():
		_sync_text_hud_selection_recursive(child, selected_indices)


func style_text_hud_option(panel: PanelContainer, selected: bool) -> void:
	var accent := Color(1.0, 0.62, 0.28, 1.0) if selected else Color(0.36, 0.86, 1.0, 1.0)
	panel.add_theme_stylebox_override("panel", _action_hud_panel_style(accent, true))


func show_card_dialog(scene: Object, items: Array, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")

	dialog_list.visible = false
	dialog_card_scroll.visible = false
	dialog_assignment_panel.visible = false
	dialog_card_scroll.scroll_horizontal = 0
	scene.set("_dialog_card_page_size", 0)
	scene.set("_dialog_card_page", 0)
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.custom_minimum_size = Vector2(0, _card_dialog_scroll_height(dialog_card_size))
	HudThemeScript.style_scroll_container(dialog_card_scroll)
	recreate_dialog_card_row(scene, dialog_card_scroll, dialog_card_size)
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	scene.call("_clear_container_children", dialog_utility_row)

	_populate_card_dialog_cards(scene)
	_rebuild_card_dialog_utility_row(scene)
	dialog_card_scroll.visible = true

	var min_select := int(extra_data.get("min_select", 1))
	var max_select := int(extra_data.get("max_select", 1))
	var show_confirm := max_select > 1 or min_select > 1
	dialog_confirm.visible = show_confirm
	dialog_status_lbl.visible = show_confirm
	if show_confirm:
		update_dialog_status_text(scene)


func _populate_card_dialog_cards(scene: Object) -> void:
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_items_data: Array = scene.get("_dialog_items_data")
	var card_items: Array = dialog_data.get("card_items", dialog_items_data)
	var card_indices: Array = dialog_data.get("card_indices", [])
	var labels: Array = dialog_data.get("choice_labels", dialog_items_data)
	var card_groups: Array = dialog_data.get("card_groups", [])
	var card_click_selectable: bool = bool(dialog_data.get("card_click_selectable", true))
	var show_selectable_hints: bool = bool(dialog_data.get("show_selectable_hints", false))
	var selectable_hint: String = str(dialog_data.get("card_selectable_hint", "可选"))
	var disabled_badge: String = str(dialog_data.get("card_disabled_badge", ""))
	dialog_card_scroll.scroll_horizontal = 0
	scene.call("_clear_container_children", dialog_card_row)
	reset_dialog_card_row_metrics(dialog_card_scroll, dialog_card_row, dialog_card_size)
	if not card_groups.is_empty():
		var grouped_height := grouped_card_dialog_scroll_height(dialog_card_size, card_items, card_groups, scene)
		dialog_card_scroll.custom_minimum_size = Vector2(0, grouped_height)
		dialog_card_scroll.size = Vector2(dialog_card_scroll.size.x, grouped_height)
		dialog_card_row.custom_minimum_size = Vector2(0, grouped_height - float(HudThemeScript.SCROLLBAR_TOUCH_THICKNESS + HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING))
		dialog_card_row.size = Vector2(dialog_card_row.size.x, dialog_card_row.custom_minimum_size.y)
		populate_grouped_card_dialog_items(scene, card_items, labels, card_groups, card_click_selectable)
		sync_dialog_card_selection(scene)
		return
	for i: int in _visible_card_display_order(card_items, card_indices):
		var real_index := i
		if i < card_indices.size():
			real_index = int(card_indices[i])
		var disabled := real_index < 0
		var card_view := BattleCardViewScript.new()
		prepare_dialog_card_view(card_view, dialog_card_size)
		card_view.set_clickable(card_click_selectable)
		setup_dialog_card_view(scene, card_view, card_items[i], labels[i] if i < labels.size() else "")
		if disabled:
			card_view.set_disabled(true)
			if disabled_badge != "":
				card_view.set_badges(disabled_badge, "")
		elif show_selectable_hints:
			card_view.set_selectable_hint_text(selectable_hint)
			card_view.set_selectable_hint(true)
		if card_click_selectable and not disabled:
			card_view.left_clicked.connect(Callable(scene, "_on_dialog_card_left_signal").bind(real_index))
		card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
		card_view.set_meta("dialog_choice_index", real_index)
		dialog_card_row.add_child(card_view)
	reset_dialog_card_row_metrics(dialog_card_scroll, dialog_card_row, dialog_card_size)
	sync_dialog_card_selection(scene)


func populate_grouped_card_dialog_items(
	scene: Object,
	card_items: Array,
	labels: Array,
	card_groups: Array,
	card_click_selectable: bool
) -> void:
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var energy_card_size := grouped_energy_card_size(dialog_card_size)
	var has_ungrouped := grouped_card_dialog_has_ungrouped(card_items, card_groups)
	var has_active := grouped_card_dialog_has_lane(scene, card_groups, "active")
	var has_bench := grouped_card_dialog_has_lane(scene, card_groups, "bench")
	var group_height := grouped_card_dialog_content_height(dialog_card_size, grouped_card_dialog_visible_lane_count(scene, card_groups, has_ungrouped))
	var board_panel := PanelContainer.new()
	board_panel.name = "EnergyDiscardBattlefield"
	board_panel.custom_minimum_size = Vector2(grouped_card_dialog_board_width(scene, card_groups, energy_card_size), group_height)
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	board_panel.add_theme_stylebox_override("panel", grouped_card_dialog_battlefield_style())
	dialog_card_row.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 12)
	board_margin.add_theme_constant_override("margin_right", 12)
	board_margin.add_theme_constant_override("margin_top", 12)
	board_margin.add_theme_constant_override("margin_bottom", 12)
	board_panel.add_child(board_margin)

	var board_box := VBoxContainer.new()
	board_box.name = "EnergyDiscardBattlefieldRows"
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_box.add_theme_constant_override("separation", 6)
	board_margin.add_child(board_box)

	var active_lane: HBoxContainer = null
	if has_active:
		board_box.add_child(create_grouped_card_dialog_lane_label("战斗宝可梦", "EnergyDiscardActiveLabel"))
		active_lane = HBoxContainer.new()
		active_lane.name = "EnergyDiscardActiveLane"
		active_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		active_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		active_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(active_lane)

	var bench_lane: HBoxContainer = null
	if has_bench:
		board_box.add_child(create_grouped_card_dialog_lane_label("备战区", "EnergyDiscardBenchLabel"))
		bench_lane = HBoxContainer.new()
		bench_lane.name = "EnergyDiscardBenchLane"
		bench_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		bench_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bench_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(bench_lane)

	var sorted_groups := grouped_card_dialog_sorted_groups(scene, card_groups)
	for group_index: int in sorted_groups.size():
		var group: Dictionary = sorted_groups[group_index]
		var slot_variant: Variant = group.get("slot")
		var indices: Array = grouped_card_dialog_group_indices(group)
		if not (slot_variant is PokemonSlot) or indices.is_empty():
			continue
		var pokemon_slot: PokemonSlot = slot_variant as PokemonSlot
		var slot_panel := create_grouped_card_dialog_slot_panel(
			scene,
			card_items,
			pokemon_slot,
			indices,
			group_index,
			energy_card_size,
			card_click_selectable
		)
		if grouped_card_dialog_slot_lane(scene, pokemon_slot) == "bench" and bench_lane != null:
			bench_lane.add_child(slot_panel)
		elif active_lane != null:
			active_lane.add_child(slot_panel)

	if has_ungrouped:
		board_box.add_child(create_grouped_card_dialog_lane_label("其他", "EnergyDiscardOtherLabel"))
		var other_lane := HBoxContainer.new()
		other_lane.name = "EnergyDiscardOtherLane"
		other_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		other_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		other_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		other_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(other_lane)
		for item_index: int in grouped_card_dialog_ungrouped_indices(card_items, card_groups):
			var card_view := BattleCardViewScript.new()
			prepare_grouped_energy_card_view(card_view, energy_card_size)
			card_view.set_clickable(card_click_selectable)
			setup_dialog_card_view(scene, card_view, card_items[item_index], labels[item_index] if item_index < labels.size() else "")
			if card_click_selectable:
				card_view.left_clicked.connect(Callable(scene, "_on_dialog_card_left_signal").bind(item_index))
			card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
			card_view.set_meta("dialog_choice_index", item_index)
			other_lane.add_child(card_view)


func grouped_card_dialog_scroll_height(card_size: Vector2, card_items: Array = [], card_groups: Array = [], scene: Object = null) -> float:
	return grouped_card_dialog_content_height(card_size, grouped_card_dialog_visible_lane_count(scene, card_groups, grouped_card_dialog_has_ungrouped(card_items, card_groups))) + float(HudThemeScript.SCROLLBAR_TOUCH_THICKNESS + HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING)


func grouped_card_dialog_content_height(card_size: Vector2, visible_lane_count: int = 2) -> float:
	var energy_card_size := grouped_energy_card_size(card_size)
	var lane_count := float(maxi(1, visible_lane_count))
	return grouped_card_dialog_slot_height(energy_card_size) * lane_count + 30.0 * lane_count + 36.0


func grouped_card_dialog_slot_height(energy_card_size: Vector2) -> float:
	return energy_card_size.y + 20.0


func grouped_card_dialog_board_width(scene: Object, card_groups: Array, energy_card_size: Vector2) -> float:
	var active_width := 0.0
	var bench_width := 0.0
	var bench_count := 0
	for group_variant: Variant in card_groups:
		if not (group_variant is Dictionary):
			continue
		var group: Dictionary = group_variant
		var slot_variant: Variant = group.get("slot")
		if not (slot_variant is PokemonSlot):
			continue
		var indices: Array = grouped_card_dialog_group_indices(group)
		var width := grouped_card_dialog_group_width(energy_card_size, indices.size())
		if grouped_card_dialog_slot_lane(scene, slot_variant as PokemonSlot) == "bench":
			if bench_count > 0:
				bench_width += 14.0
			bench_width += width
			bench_count += 1
		else:
			active_width = maxf(active_width, width)
	return maxf(540.0, maxf(active_width, bench_width)) + 24.0


func grouped_card_dialog_group_width(energy_card_size: Vector2, energy_count: int) -> float:
	var card_count := energy_count + 1
	return maxf(212.0, energy_card_size.x * float(card_count) + 12.0 * float(maxi(0, card_count - 1)) + 22.0)


func grouped_energy_card_size(card_size: Vector2) -> Vector2:
	return Vector2(maxf(92.0, card_size.x * 0.68), maxf(128.0, card_size.y * 0.68))


func grouped_card_dialog_group_indices(group: Dictionary) -> Array:
	var indices: Array = group.get("card_indices", [])
	if indices.is_empty():
		indices = group.get("energy_indices", [])
	return indices


func grouped_card_dialog_grouped_index_set(card_groups: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for group_variant: Variant in card_groups:
		if not (group_variant is Dictionary):
			continue
		for idx_variant: Variant in grouped_card_dialog_group_indices(group_variant as Dictionary):
			grouped[int(idx_variant)] = true
	return grouped


func grouped_card_dialog_ungrouped_indices(card_items: Array, card_groups: Array) -> Array[int]:
	var grouped := grouped_card_dialog_grouped_index_set(card_groups)
	var indices: Array[int] = []
	for i: int in card_items.size():
		if not grouped.has(i):
			indices.append(i)
	return indices


func grouped_card_dialog_has_ungrouped(card_items: Array, card_groups: Array) -> bool:
	return not grouped_card_dialog_ungrouped_indices(card_items, card_groups).is_empty()


func grouped_card_dialog_has_lane(scene: Object, card_groups: Array, lane: String) -> bool:
	for group_variant: Variant in card_groups:
		if not (group_variant is Dictionary):
			continue
		var group: Dictionary = group_variant
		if grouped_card_dialog_group_indices(group).is_empty():
			continue
		var slot_variant: Variant = group.get("slot")
		if not (slot_variant is PokemonSlot):
			continue
		var group_lane := grouped_card_dialog_slot_lane(scene, slot_variant as PokemonSlot)
		if lane == "bench" and group_lane == "bench":
			return true
		if lane == "active" and group_lane != "bench":
			return true
	return false


func grouped_card_dialog_visible_lane_count(scene: Object, card_groups: Array, has_ungrouped: bool = false) -> int:
	var count := 0
	if grouped_card_dialog_has_lane(scene, card_groups, "active"):
		count += 1
	if grouped_card_dialog_has_lane(scene, card_groups, "bench"):
		count += 1
	if has_ungrouped:
		count += 1
	return maxi(1, count)


func create_grouped_card_dialog_lane_label(text: String, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.70, 0.86, 0.92, 0.92))
	return label


func prepare_grouped_energy_card_view(card_view: BattleCardView, energy_card_size: Vector2) -> void:
	card_view.custom_minimum_size = energy_card_size
	card_view.size = energy_card_size
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func create_grouped_card_dialog_slot_panel(
	scene: Object,
	card_items: Array,
	pokemon_slot: PokemonSlot,
	indices: Array,
	group_index: int,
	energy_card_size: Vector2,
	card_click_selectable: bool
) -> PanelContainer:
	var slot_position := grouped_card_dialog_slot_position(scene, pokemon_slot)
	var group_panel := PanelContainer.new()
	group_panel.name = "EnergyDiscardGroup%d" % group_index
	group_panel.custom_minimum_size = Vector2(
		grouped_card_dialog_group_width(energy_card_size, indices.size()),
		grouped_card_dialog_slot_height(energy_card_size)
	)
	group_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	group_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	group_panel.add_theme_stylebox_override("panel", grouped_card_dialog_panel_style(group_index))
	group_panel.set_meta("energy_group_slot_position", slot_position)
	group_panel.set_meta("energy_group_pokemon_name", pokemon_slot.get_pokemon_name())
	group_panel.set_meta("energy_group_basic_energy_count", indices.size())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	group_panel.add_child(margin)

	var group_box := VBoxContainer.new()
	group_box.add_theme_constant_override("separation", 6)
	group_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(group_box)

	var card_line := HBoxContainer.new()
	card_line.name = "EnergyGroupCardLine"
	card_line.alignment = BoxContainer.ALIGNMENT_CENTER
	card_line.add_theme_constant_override("separation", 12)
	card_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_line.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	group_box.add_child(card_line)

	var header_view := BattleCardViewScript.new()
	prepare_grouped_energy_card_view(header_view, energy_card_size)
	header_view.set_clickable(false)
	header_view.setup_from_card_data(pokemon_slot.get_card_data(), scene.call("_battle_card_mode_for_slot", pokemon_slot))
	header_view.set_badges()
	header_view.set_battle_status(scene.call("_build_battle_status", pokemon_slot))
	header_view.set_meta("dialog_choice_index", -1)
	card_line.add_child(header_view)

	for energy_idx_variant: Variant in indices:
		var real_index := int(energy_idx_variant)
		if real_index < 0 or real_index >= card_items.size():
			continue
		var card_view := BattleCardViewScript.new()
		prepare_grouped_energy_card_view(card_view, energy_card_size)
		card_view.set_clickable(card_click_selectable)
		setup_dialog_card_view(scene, card_view, card_items[real_index], "")
		if card_click_selectable:
			card_view.left_clicked.connect(Callable(scene, "_on_dialog_card_left_signal").bind(real_index))
		card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
		card_view.set_meta("dialog_choice_index", real_index)
		card_line.add_child(card_view)
	return group_panel


func grouped_card_dialog_sorted_groups(scene: Object, card_groups: Array) -> Array:
	var sorted := card_groups.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return grouped_card_dialog_group_order(scene, a) < grouped_card_dialog_group_order(scene, b)
	)
	return sorted


func grouped_card_dialog_group_order(scene: Object, group_variant: Variant) -> int:
	if not (group_variant is Dictionary):
		return 9999
	var group: Dictionary = group_variant
	var slot_variant: Variant = group.get("slot")
	if not (slot_variant is PokemonSlot):
		return 9999
	var slot := slot_variant as PokemonSlot
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return 9999
	for player: PlayerState in gsm.game_state.players:
		if player.active_pokemon == slot:
			return 0
		var bench_index := player.bench.find(slot)
		if bench_index >= 0:
			return 100 + bench_index
	return 9999


func grouped_card_dialog_slot_lane(scene: Object, slot: PokemonSlot) -> String:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return "unknown"
	for player: PlayerState in gsm.game_state.players:
		if player.active_pokemon == slot:
			return "active"
		if player.bench.find(slot) >= 0:
			return "bench"
	return "unknown"


func grouped_card_dialog_slot_position(scene: Object, slot: PokemonSlot) -> String:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return "场上宝可梦"
	for player: PlayerState in gsm.game_state.players:
		if player.active_pokemon == slot:
			return "战斗场"
		var bench_index := player.bench.find(slot)
		if bench_index >= 0:
			return "备战区 %d" % (bench_index + 1)
	return "场上宝可梦"


func grouped_card_dialog_panel_style(group_index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var tint := 0.02 * float(group_index % 2)
	style.bg_color = Color(0.020 + tint, 0.038 + tint, 0.052 + tint, 0.92)
	style.border_color = Color(0.32, 0.72, 0.84, 0.78)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 8
	return style


func grouped_card_dialog_battlefield_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.015, 0.025, 0.90)
	style.border_color = Color(0.28, 0.62, 0.72, 0.0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style


func _card_dialog_scroll_height(card_size: Vector2) -> float:
	return card_size.y + float(HudThemeScript.SCROLLBAR_TOUCH_THICKNESS + HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING)


func recreate_dialog_card_row(scene: Object, dialog_card_scroll: ScrollContainer, dialog_card_size: Vector2) -> HBoxContainer:
	var old_row := scene.get("_dialog_card_row") as HBoxContainer
	if old_row != null and old_row.get_parent() == dialog_card_scroll:
		dialog_card_scroll.remove_child(old_row)
		old_row.queue_free()
	if dialog_card_scroll.custom_minimum_size.y > 0.0:
		dialog_card_scroll.size = Vector2(dialog_card_scroll.size.x, dialog_card_scroll.custom_minimum_size.y)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, dialog_card_size.y)
	row.size = Vector2(0, dialog_card_size.y)
	dialog_card_scroll.add_child(row)
	scene.set("_dialog_card_row", row)
	return row


func prepare_dialog_card_view(card_view: BattleCardView, dialog_card_size: Vector2) -> void:
	card_view.custom_minimum_size = dialog_card_size
	card_view.size = dialog_card_size
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func reset_dialog_card_row_metrics(scroll: ScrollContainer, row: HBoxContainer, dialog_card_size: Vector2) -> void:
	row.custom_minimum_size = Vector2(0, dialog_card_size.y)
	row.size = Vector2(row.size.x, dialog_card_size.y)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for child: Node in row.get_children():
		if child is BattleCardView:
			prepare_dialog_card_view(child as BattleCardView, dialog_card_size)
	if scroll != null and scroll.custom_minimum_size.y > 0.0:
		scroll.size = Vector2(scroll.size.x, scroll.custom_minimum_size.y)


func _rebuild_card_dialog_utility_row(scene: Object) -> void:
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	scene.call("_clear_container_children", dialog_utility_row)
	var has_controls := false

	var utility_actions: Array = dialog_data.get("utility_actions", [])
	for action_variant: Variant in utility_actions:
		if not (action_variant is Dictionary):
			continue
		has_controls = true
		var action: Dictionary = action_variant
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(action.get("label", _bt(scene, "battle.dialog.action_label")))
		style_dialog_button(button, "primary")
		var action_index := int(action.get("index", -1))
		button.pressed.connect(func() -> void:
			confirm_dialog_selection(scene, PackedInt32Array([action_index]))
		)
		dialog_utility_row.add_child(button)
	dialog_utility_row.visible = has_controls


func show_action_hud_dialog(scene: Object, _items: Array, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")

	dialog_list.visible = false
	dialog_card_scroll.visible = true
	dialog_assignment_panel.visible = false
	dialog_utility_row.visible = false
	dialog_confirm.visible = false
	dialog_status_lbl.visible = false
	var action_items: Array = extra_data.get("action_items", [])
	var preview_item: Variant = extra_data.get("pokemon_card", extra_data.get("pokemon_card_data", null))
	var has_preview := preview_item is CardInstance or preview_item is CardData
	var preview_size := _action_hud_preview_card_size(scene)
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if action_items.size() > 5 else ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_height := _action_hud_scroll_height(action_items.size())
	if has_preview:
		scroll_height = maxf(scroll_height, preview_size.y + 18.0)
	dialog_card_scroll.custom_minimum_size = Vector2(0, scroll_height)
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)

	dialog_card_row.add_theme_constant_override("separation", 16 if has_preview else 10)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if has_preview:
		dialog_card_row.add_child(_build_action_hud_card_preview(preview_item, preview_size))
	dialog_card_row.add_child(stack)

	var option_width := _action_hud_option_width(scene, preview_size, has_preview)
	for i: int in action_items.size():
		var action: Dictionary = action_items[i] if action_items[i] is Dictionary else {}
		stack.add_child(_build_action_hud_option(scene, action, i, option_width))


func _action_hud_scroll_height(action_count: int) -> float:
	var visible_count: int = clampi(action_count, 1, 5)
	return float(visible_count * 88 + maxi(visible_count - 1, 0) * 8 + 2)


func _action_hud_preview_card_size(scene: Object) -> Vector2:
	var detail_card_size_variant: Variant = scene.get("_detail_card_size")
	if detail_card_size_variant is Vector2:
		var detail_card_size: Vector2 = detail_card_size_variant
		if detail_card_size.x > 0.0 and detail_card_size.y > 0.0:
			return detail_card_size
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	return Vector2(maxf(188.0, dialog_card_size.x * 1.26), maxf(264.0, dialog_card_size.y * 1.26))


func _action_hud_option_width(scene: Object, preview_size: Vector2, has_preview: bool) -> float:
	if not has_preview:
		return 760.0
	var dialog_box := scene.get("_dialog_box") as Control
	var box_width := 860.0
	if dialog_box != null and dialog_box.custom_minimum_size.x > 0.0:
		box_width = dialog_box.custom_minimum_size.x
	return maxf(420.0, box_width - (preview_size.x + 14.0) - 16.0)


func _build_action_hud_card_preview(preview_item: Variant, preview_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PokemonActionCardPreview"
	panel.custom_minimum_size = Vector2(preview_size.x + 14.0, preview_size.y + 14.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _action_hud_card_preview_style())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var card_view := BattleCardViewScript.new()
	card_view.name = "PokemonActionCardView"
	card_view.custom_minimum_size = preview_size
	card_view.size = preview_size
	card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_view.set_clickable(false)
	card_view.set_compact_preview(true)
	if preview_item is CardInstance:
		card_view.setup_from_instance(preview_item as CardInstance, BattleCardViewScript.MODE_PREVIEW)
	elif preview_item is CardData:
		card_view.setup_from_card_data(preview_item as CardData, BattleCardViewScript.MODE_PREVIEW)
	margin.add_child(card_view)
	return panel


func _action_hud_card_preview_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.026, 0.036, 0.92)
	style.border_color = Color(0.36, 0.86, 1.0, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.74, 1.0, 0.18)
	style.shadow_size = 10
	return style


func _build_action_hud_option(scene: Object, action: Dictionary, action_index: int, option_width: float = 760.0) -> Control:
	var enabled := bool(action.get("enabled", true))
	var accent := _action_hud_accent(str(action.get("type", "")), enabled)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(option_width, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _action_hud_panel_style(accent, enabled))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_dialog_selection(scene, PackedInt32Array([action_index]))
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var kind := Label.new()
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kind.text = str(action.get("kind", "行动"))
	kind.custom_minimum_size = Vector2(58, 22)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kind.add_theme_font_size_override("font_size", 13)
	kind.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08, 1.0))
	kind.add_theme_stylebox_override("normal", _action_hud_pill_style(accent, enabled))
	header.add_child(kind)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(action.get("title", ""))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0) if enabled else Color(0.62, 0.66, 0.70, 1.0))
	header.add_child(title)

	var cost_text := str(action.get("cost", "")).strip_edges()
	if cost_text != "":
		header.add_child(_build_energy_cost_icons(cost_text, enabled))

	var meta := Label.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.text = str(action.get("meta", ""))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_theme_font_size_override("font_size", 14)
	meta.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96, 1.0) if enabled else Color(0.50, 0.54, 0.58, 1.0))
	header.add_child(meta)

	var body := RichTextLabel.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = str(action.get("body", ""))
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", Color(0.84, 0.89, 0.94, 1.0) if enabled else Color(0.55, 0.59, 0.63, 1.0))
	box.add_child(body)

	var reason := str(action.get("reason", "")).strip_edges()
	if not enabled and reason != "":
		var reason_label := Label.new()
		reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reason_label.text = "不可用：%s" % reason
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.add_theme_font_size_override("font_size", 13)
		reason_label.add_theme_color_override("font_color", Color(1.0, 0.67, 0.50, 1.0))
		box.add_child(reason_label)

	return panel


func _build_energy_cost_icons(cost_text: String, enabled: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	for symbol: String in cost_text:
		row.add_child(_build_energy_cost_icon(symbol, enabled))
	return row


func _build_energy_cost_icon(symbol: String, enabled: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ENERGY_ICON_TEXTURES.get(symbol, ENERGY_ICON_TEXTURES.get("C"))
	icon.modulate = Color(1, 1, 1, 1) if enabled else Color(0.45, 0.45, 0.45, 0.82)
	return icon


func _action_hud_accent(action_type: String, enabled: bool) -> Color:
	if not enabled:
		return Color(0.34, 0.38, 0.42, 1.0)
	match action_type:
		"ability":
			return Color(0.35, 0.80, 0.95, 1.0)
		"attack", "granted_attack":
			return Color(1.0, 0.48, 0.24, 1.0)
		"retreat":
			return Color(0.62, 0.90, 0.42, 1.0)
		_:
			return Color(0.72, 0.78, 0.86, 1.0)


func _action_hud_panel_style(accent: Color, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.96) if enabled else Color(0.028, 0.035, 0.043, 0.90)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22 if enabled else 0.08)
	style.shadow_size = 8 if enabled else 2
	return style


func _action_hud_pill_style(accent: Color, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent if enabled else Color(0.30, 0.33, 0.36, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func show_assignment_dialog(scene: Object, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_assignment_source_scroll: ScrollContainer = scene.get("_dialog_assignment_source_scroll")
	var dialog_assignment_target_scroll: ScrollContainer = scene.get("_dialog_assignment_target_scroll")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_assignment_target_row: HBoxContainer = scene.get("_dialog_assignment_target_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var source_items: Array = extra_data.get("source_items", [])
	var source_labels: Array = extra_data.get("source_labels", [])
	var source_groups: Array = extra_data.get("source_groups", [])
	var source_card_items: Array = extra_data.get("source_card_items", [])
	var source_card_indices: Array = extra_data.get("source_card_indices", [])
	var source_choice_labels: Array = extra_data.get("source_choice_labels", [])

	dialog_list.visible = false
	dialog_card_scroll.visible = false
	dialog_assignment_panel.visible = true
	dialog_assignment_source_scroll.scroll_horizontal = 0
	dialog_assignment_target_scroll.scroll_horizontal = 0
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)
	scene.call("_clear_container_children", dialog_assignment_source_row)
	scene.call("_clear_container_children", dialog_assignment_target_row)
	if not source_groups.is_empty():
		reset_grouped_assignment_source_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size, source_items, source_groups, scene)
	else:
		reset_dialog_card_row_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size)
	reset_dialog_card_row_metrics(dialog_assignment_target_scroll, dialog_assignment_target_row, dialog_card_size)
	reset_dialog_assignment_state(scene)
	scene.set("_dialog_assignment_mode", true)
	dialog_assignment_panel.visible = true

	var disabled_badge := str(extra_data.get("source_card_disabled_badge", extra_data.get("card_disabled_badge", "")))
	if not source_groups.is_empty():
		populate_grouped_source_items(scene, source_items, source_labels, source_groups)
	elif not source_card_items.is_empty():
		for i: int in _visible_card_display_order(source_card_items, source_card_indices):
			var real_index := i
			if i < source_card_indices.size():
				real_index = int(source_card_indices[i])
			var display_label := str(source_choice_labels[i]) if i < source_choice_labels.size() else ""
			add_assignment_source_card(
				scene,
				source_items,
				source_labels,
				real_index,
				source_card_items[i],
				display_label,
				real_index < 0,
				disabled_badge
			)
	else:
		for i: int in source_items.size():
			add_assignment_source_card(scene, source_items, source_labels, i)

	var target_items: Array = extra_data.get("target_items", [])
	var target_labels: Array = extra_data.get("target_labels", [])
	for i: int in target_items.size():
		var target_view := BattleCardViewScript.new()
		prepare_dialog_card_view(target_view, dialog_card_size)
		target_view.set_clickable(true)
		setup_dialog_card_view(scene, target_view, target_items[i], target_labels[i] if i < target_labels.size() else "")
		target_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			scene.call("_on_assignment_target_chosen", i)
		)
		target_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				scene.call("_show_card_detail", cd)
		)
		target_view.set_meta("assignment_target_index", i)
		dialog_assignment_target_row.add_child(target_view)
	if not source_groups.is_empty():
		reset_grouped_assignment_source_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size, source_items, source_groups, scene)
	else:
		reset_dialog_card_row_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size)
	reset_dialog_card_row_metrics(dialog_assignment_target_scroll, dialog_assignment_target_row, dialog_card_size)

	dialog_utility_row.visible = true
	var clear_button := Button.new()
	clear_button.custom_minimum_size = Vector2(140, 40)
	clear_button.text = _bt(scene, "battle.dialog.clear")
	style_dialog_button(clear_button, "secondary")
	clear_button.pressed.connect(func() -> void:
		_replace_dictionary_array(scene, "_dialog_assignment_assignments", [])
		scene.set("_dialog_assignment_selected_source_index", -1)
		refresh_assignment_dialog_views(scene)
	)
	dialog_utility_row.add_child(clear_button)

	dialog_confirm.visible = true
	dialog_status_lbl.visible = false
	refresh_assignment_dialog_views(scene)


func _visible_card_display_order(card_items: Array, card_indices: Array) -> Array[int]:
	var selectable: Array[int] = []
	var disabled: Array[int] = []
	for i: int in card_items.size():
		var real_index := i
		if i < card_indices.size():
			real_index = int(card_indices[i])
		if real_index >= 0:
			selectable.append(i)
		else:
			disabled.append(i)
	selectable.append_array(disabled)
	return selectable


func populate_grouped_source_items(scene: Object, source_items: Array, source_labels: Array, source_groups: Array) -> void:
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var energy_card_size := grouped_energy_card_size(dialog_card_size)
	var has_active := grouped_card_dialog_has_lane(scene, source_groups, "active")
	var has_bench := grouped_card_dialog_has_lane(scene, source_groups, "bench")
	var board_panel := PanelContainer.new()
	board_panel.name = "EnergyAssignmentSourceBattlefield"
	board_panel.custom_minimum_size = Vector2(grouped_card_dialog_board_width(scene, source_groups, energy_card_size), grouped_card_dialog_content_height(dialog_card_size, grouped_card_dialog_visible_lane_count(scene, source_groups)))
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	board_panel.add_theme_stylebox_override("panel", grouped_card_dialog_battlefield_style())
	dialog_assignment_source_row.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 12)
	board_margin.add_theme_constant_override("margin_right", 12)
	board_margin.add_theme_constant_override("margin_top", 12)
	board_margin.add_theme_constant_override("margin_bottom", 12)
	board_panel.add_child(board_margin)

	var board_box := VBoxContainer.new()
	board_box.name = "EnergyAssignmentSourceRows"
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_box.add_theme_constant_override("separation", 6)
	board_margin.add_child(board_box)

	var active_lane: HBoxContainer = null
	if has_active:
		board_box.add_child(create_grouped_card_dialog_lane_label("战斗宝可梦", "EnergyAssignmentSourceActiveLabel"))
		active_lane = HBoxContainer.new()
		active_lane.name = "EnergyAssignmentSourceActiveLane"
		active_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		active_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		active_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(active_lane)

	var bench_lane: HBoxContainer = null
	if has_bench:
		board_box.add_child(create_grouped_card_dialog_lane_label("备战区", "EnergyAssignmentSourceBenchLabel"))
		bench_lane = HBoxContainer.new()
		bench_lane.name = "EnergyAssignmentSourceBenchLane"
		bench_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		bench_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bench_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(bench_lane)

	var sorted_groups := grouped_card_dialog_sorted_groups(scene, source_groups)
	for group_index: int in sorted_groups.size():
		var group: Dictionary = sorted_groups[group_index]
		var slot_variant: Variant = group.get("slot")
		var indices: Array = grouped_card_dialog_group_indices(group)
		if not (slot_variant is PokemonSlot) or indices.is_empty():
			continue
		var pokemon_slot: PokemonSlot = slot_variant as PokemonSlot
		var slot_panel := create_grouped_assignment_source_slot_panel(
			scene,
			source_items,
			source_labels,
			pokemon_slot,
			indices,
			group_index,
			energy_card_size
		)
		if grouped_card_dialog_slot_lane(scene, pokemon_slot) == "bench" and bench_lane != null:
			bench_lane.add_child(slot_panel)
		elif active_lane != null:
			active_lane.add_child(slot_panel)


func reset_grouped_assignment_source_metrics(scroll: ScrollContainer, row: HBoxContainer, dialog_card_size: Vector2, source_items: Array, source_groups: Array, scene: Object = null) -> void:
	var grouped_height := grouped_card_dialog_scroll_height(dialog_card_size, source_items, source_groups, scene)
	scroll.custom_minimum_size = Vector2(0, grouped_height)
	scroll.size = Vector2(scroll.size.x, grouped_height)
	row.custom_minimum_size = Vector2(0, grouped_height - float(HudThemeScript.SCROLLBAR_TOUCH_THICKNESS + HudThemeScript.CARD_SCROLLBAR_CLEARANCE_PADDING))
	row.size = Vector2(row.size.x, row.custom_minimum_size.y)


func create_grouped_assignment_source_slot_panel(
	scene: Object,
	source_items: Array,
	source_labels: Array,
	pokemon_slot: PokemonSlot,
	indices: Array,
	group_index: int,
	energy_card_size: Vector2
) -> PanelContainer:
	var group_panel := PanelContainer.new()
	group_panel.name = "EnergyAssignmentSourceGroup%d" % group_index
	group_panel.custom_minimum_size = Vector2(
		grouped_card_dialog_group_width(energy_card_size, indices.size()),
		grouped_card_dialog_slot_height(energy_card_size)
	)
	group_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	group_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	group_panel.add_theme_stylebox_override("panel", grouped_card_dialog_panel_style(group_index))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	group_panel.add_child(margin)

	var card_line := HBoxContainer.new()
	card_line.name = "EnergyAssignmentSourceCardLine"
	card_line.alignment = BoxContainer.ALIGNMENT_CENTER
	card_line.add_theme_constant_override("separation", 12)
	card_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_line.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(card_line)

	var header_view := BattleCardViewScript.new()
	prepare_grouped_energy_card_view(header_view, energy_card_size)
	header_view.set_clickable(false)
	header_view.setup_from_card_data(pokemon_slot.get_card_data(), scene.call("_battle_card_mode_for_slot", pokemon_slot))
	header_view.set_badges()
	header_view.set_battle_status(scene.call("_build_battle_status", pokemon_slot))
	card_line.add_child(header_view)

	for source_idx_variant: Variant in indices:
		var source_index := int(source_idx_variant)
		if source_index < 0 or source_index >= source_items.size():
			continue
		var source_view := BattleCardViewScript.new()
		prepare_grouped_energy_card_view(source_view, energy_card_size)
		source_view.set_clickable(true)
		setup_dialog_card_view(scene, source_view, source_items[source_index], source_labels[source_index] if source_index < source_labels.size() else "")
		source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			scene.call("_on_assignment_source_chosen", source_index)
		)
		source_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				scene.call("_show_card_detail", cd)
		)
		source_view.set_meta("assignment_source_index", source_index)
		source_view.set_meta("assignment_source_disabled", false)
		card_line.add_child(source_view)
	return group_panel


func add_assignment_source_card(
	scene: Object,
	source_items: Array,
	source_labels: Array,
	source_index: int,
	display_item: Variant = null,
	display_label: String = "",
	disabled: bool = false,
	disabled_badge: String = ""
) -> void:
	if (source_index < 0 or source_index >= source_items.size()) and display_item == null:
		return
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var source_view := BattleCardViewScript.new()
	prepare_dialog_card_view(source_view, dialog_card_size)
	source_view.set_clickable(not disabled)
	var source_label: String = display_label
	if source_label == "" and source_index >= 0 and source_index < source_labels.size():
		source_label = str(source_labels[source_index])
	var source_item: Variant = display_item if display_item != null else source_items[source_index]
	setup_dialog_card_view(scene, source_view, source_item, source_label)
	if disabled:
		source_view.set_disabled(true)
		if disabled_badge != "":
			source_view.set_badges(disabled_badge, "")
	else:
		source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			scene.call("_on_assignment_source_chosen", source_index)
		)
	source_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
		if cd != null:
			scene.call("_show_card_detail", cd)
	)
	source_view.set_meta("assignment_source_index", source_index)
	source_view.set_meta("assignment_source_disabled", disabled)
	dialog_assignment_source_row.add_child(source_view)


func find_assignment_index_for_source(scene: Object, source_index: int) -> int:
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	for i: int in assignments.size():
		if int((assignments[i] as Dictionary).get("source_index", -1)) == source_index:
			return i
	return -1


func dialog_assignment_last_target_index(scene: Object) -> int:
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if assignments.is_empty():
		return -1
	return int((assignments.back() as Dictionary).get("target_index", -1))


func on_assignment_source_chosen(scene: Object, source_index: int) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source_items: Array = dialog_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return
	var assigned_index := find_assignment_index_for_source(scene, source_index)
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if assigned_index >= 0:
		assignments.remove_at(assigned_index)
		_replace_dictionary_array(scene, "_dialog_assignment_assignments", assignments)
		if int(scene.get("_dialog_assignment_selected_source_index")) == source_index:
			scene.set("_dialog_assignment_selected_source_index", -1)
		refresh_assignment_dialog_views(scene)
		return
	var max_assignments := int(dialog_data.get("max_select", source_items.size()))
	if max_assignments > 0 and assignments.size() >= max_assignments:
		scene.call("_log", _bt(scene, "battle.dialog.assign_limit_reached"))
		return
	if int(scene.get("_dialog_assignment_selected_source_index")) == source_index:
		scene.set("_dialog_assignment_selected_source_index", -1)
	else:
		scene.set("_dialog_assignment_selected_source_index", source_index)
	refresh_assignment_dialog_views(scene)


func on_assignment_target_chosen(scene: Object, target_index: int) -> void:
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	if selected_source_index < 0:
		scene.call("_log", _bt(scene, "battle.dialog.choose_target"))
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source_items: Array = dialog_data.get("source_items", [])
	var target_items: Array = dialog_data.get("target_items", [])
	if selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = dialog_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(selected_source_index, [])
	if target_index in excluded:
		scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
		return
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if bool(dialog_data.get("single_target_only", false)):
		for assignment_variant: Variant in assignments:
			if assignment_variant is Dictionary and int((assignment_variant as Dictionary).get("target_index", -1)) != target_index:
				scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
				return
	var max_per_target: int = int(dialog_data.get("max_assignments_per_target", 0))
	if max_per_target > 0 and _count_assignments_for_target_index(assignments, target_index) >= max_per_target:
		scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
		return
	assignments.append({
		"source_index": selected_source_index,
		"source": source_items[selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	_replace_dictionary_array(scene, "_dialog_assignment_assignments", assignments)
	scene.set("_dialog_assignment_selected_source_index", -1)
	refresh_assignment_dialog_views(scene)


func refresh_assignment_dialog_views(scene: Object) -> void:
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_assignment_target_row: HBoxContainer = scene.get("_dialog_assignment_target_row")
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	for child: Node in dialog_assignment_source_row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		if bool(card_view.get_meta("assignment_source_disabled", false)):
			card_view.set_selected(false)
			card_view.set_selectable_hint(false)
			card_view.set_disabled(true)
			continue
		var idx := int(card_view.get_meta("assignment_source_index", -1))
		var source_selected := idx == selected_source_index
		var source_assigned := find_assignment_index_for_source(scene, idx) >= 0
		card_view.set_selected(source_selected)
		card_view.set_selectable_hint(not source_selected and not source_assigned)
		card_view.set_disabled(source_assigned)
	for child: Node in dialog_assignment_target_row.get_children():
		if not (child is BattleCardView):
			continue
		var target_view := child as BattleCardView
		var idx := int(target_view.get_meta("assignment_target_index", -1))
		var target_selected := idx == dialog_assignment_last_target_index(scene)
		target_view.set_selected(target_selected)
		target_view.set_selectable_hint(not target_selected)
		target_view.set_disabled(false)
	update_assignment_dialog_state(scene)


func update_assignment_dialog_state(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var summary_label: Label = scene.get("_dialog_assignment_summary_lbl")
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var min_assignments := int(dialog_data.get("min_select", 0))
	var max_assignments := int(dialog_data.get("max_select", 0))
	dialog_confirm.disabled = assignments.size() < min_assignments

	var target_counts: Dictionary = {}
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		var assignment := assignment_variant as Dictionary
		var target: Variant = assignment.get("target")
		if target == null:
			continue
		target_counts[target] = int(target_counts.get(target, 0)) + 1

	var summary_parts: Array[String] = []
	for target: Variant in target_counts.keys():
		if target is PokemonSlot:
			var slot: PokemonSlot = target as PokemonSlot
			summary_parts.append("%s×%d" % [slot.get_pokemon_name(), int(target_counts[target])])

	var summary := ""
	if max_assignments > 0:
		summary = _bt(scene, "battle.dialog.assignment_summary", {
			"assigned_count": assignments.size(),
			"max_assignments": max_assignments,
		})
	else:
		summary = _bt(scene, "battle.dialog.assignment_summary_unlimited", {
			"assigned_count": assignments.size(),
		})
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	if selected_source_index >= 0:
		var source_items: Array = dialog_data.get("source_items", [])
		if selected_source_index < source_items.size():
			var selected_source: Variant = source_items[selected_source_index]
			if selected_source is CardInstance:
				summary += " " + _bt(scene, "battle.dialog.assignment_current_source", {
					"name": (selected_source as CardInstance).card_data.name,
				})
	if not summary_parts.is_empty():
		summary += " 已分配到：" + ", ".join(summary_parts)
	summary_label.text = summary


func _count_assignments_for_target_index(assignments: Array, target_index: int) -> int:
	var count := 0
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		if int((assignment_variant as Dictionary).get("target_index", -1)) == target_index:
			count += 1
	return count


func on_dialog_card_chosen(scene: Object, real_index: int) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	var is_multi := max_select > 1 or min_select > 1
	if not is_multi:
		confirm_dialog_selection(scene, PackedInt32Array([real_index]))
		return
	if not bool(scene.call("_toggle_dialog_card_choice", real_index, max_select)):
		return
	sync_dialog_card_selection(scene)
	update_dialog_confirm_state(scene)


func card_dialog_should_show_selectable_hint(_selected: bool) -> bool:
	return false


func sync_dialog_card_selection(scene: Object) -> void:
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	for child: Node in dialog_card_row.get_children():
		sync_dialog_card_selection_recursive(child, selected_indices)


func sync_dialog_card_selection_recursive(node: Node, selected_indices: Array) -> void:
	if node is BattleCardView:
		var card_view := node as BattleCardView
		var idx := int(card_view.get_meta("dialog_choice_index", -1))
		var selected := idx >= 0 and idx in selected_indices
		card_view.set_selected(selected)
		card_view.set_selectable_hint(idx >= 0 and card_dialog_should_show_selectable_hint(selected))
	for child: Node in node.get_children():
		sync_dialog_card_selection_recursive(child, selected_indices)


func update_dialog_confirm_state(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var min_select := int(dialog_data.get("min_select", 1))
	if bool(scene.get("_dialog_assignment_mode")):
		update_assignment_dialog_state(scene)
		return
	if bool(scene.get("_dialog_card_mode")):
		var selected_indices: Array = scene.get("_dialog_card_selected_indices")
		dialog_confirm.disabled = selected_indices.size() < min_select
		update_dialog_status_text(scene)
		return
	if not dialog_list.visible:
		var hud_selected: Array = scene.get("_dialog_multi_selected_indices")
		dialog_confirm.disabled = hud_selected.size() < min_select
		return
	if dialog_list.select_mode == ItemList.SELECT_SINGLE:
		dialog_confirm.disabled = dialog_list.get_selected_items().size() < min_select
	else:
		var multi_selected: Array = scene.get("_dialog_multi_selected_indices")
		dialog_confirm.disabled = multi_selected.size() < min_select


func update_dialog_status_text(scene: Object) -> void:
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	if dialog_status_lbl == null or not dialog_status_lbl.visible:
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	if max_select > 1:
		dialog_status_lbl.text = _bt(scene, "battle.dialog.card_status_with_max", {
			"selected_count": selected_indices.size(),
			"min_select": min_select,
			"max_select": max_select,
		})
	else:
		dialog_status_lbl.text = _bt(scene, "battle.dialog.card_status", {
			"selected_count": selected_indices.size(),
			"min_select": min_select,
		})


func confirm_dialog_selection(scene: Object, sel_items: PackedInt32Array) -> void:
	scene.call(
		"_runtime_log",
		"confirm_dialog_selection",
		"choice=%s selected=%s %s" % [scene.get("_pending_choice"), JSON.stringify(sel_items), scene.call("_dialog_state_snapshot")]
	)
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	dialog_overlay.visible = false
	scene.call("_handle_dialog_choice", sel_items)


func on_dialog_item_selected(scene: Object, idx: int) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	if dialog_list.select_mode != ItemList.SELECT_SINGLE:
		return
	dialog_confirm.disabled = false
	if not bool(scene.get("_dialog_card_mode")):
		confirm_dialog_selection(scene, PackedInt32Array([idx]))


func on_dialog_item_multi_selected(scene: Object, idx: int, selected: bool) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	if dialog_list.select_mode == ItemList.SELECT_SINGLE:
		return
	var selected_indices: Array = scene.get("_dialog_multi_selected_indices")
	if selected:
		if idx not in selected_indices:
			selected_indices.append(idx)
	else:
		selected_indices.erase(idx)
	_replace_int_array(scene, "_dialog_multi_selected_indices", selected_indices)
	update_dialog_confirm_state(scene)


func on_dialog_confirm(scene: Object) -> void:
	if bool(scene.get("_dialog_assignment_mode")):
		confirm_assignment_dialog(scene)
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var sel_items := PackedInt32Array()
	if bool(scene.get("_dialog_card_mode")):
		var selected_indices: Array = scene.get("_dialog_card_selected_indices")
		for selected_idx: int in selected_indices:
			sel_items.append(selected_idx)
	else:
		var dialog_list: ItemList = scene.get("_dialog_list")
		if dialog_list.visible:
			sel_items = dialog_list.get_selected_items()
		else:
			var hud_selected: Array = scene.get("_dialog_multi_selected_indices")
			for selected_idx: int in hud_selected:
				sel_items.append(selected_idx)
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	if sel_items.size() < min_select:
		scene.call("_log", _bt(scene, "battle.dialog.select_at_least", {"count": min_select}))
		return
	if max_select > 0 and sel_items.size() > max_select:
		scene.call("_log", _bt(scene, "battle.dialog.select_at_most", {"count": max_select}))
		return
	confirm_dialog_selection(scene, sel_items)


func on_dialog_cancel(scene: Object) -> void:
	scene.call(
		"_runtime_log",
		"dialog_cancel",
		"choice=%s %s" % [scene.get("_pending_choice"), scene.call("_dialog_state_snapshot")]
	)
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	dialog_overlay.visible = false
	_replace_int_array(scene, "_dialog_card_selected_indices", [])
	reset_dialog_assignment_state(scene)
	if str(scene.get("_pending_choice")) == "effect_interaction":
		scene.call("_reset_effect_interaction")
	scene.set("_pending_choice", "")


func confirm_assignment_dialog(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 0))
	var max_select := int(dialog_data.get("max_select", 0))
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var assignment_count := assignments.size()
	if assignment_count < min_select:
		scene.call("_log", _bt(scene, "battle.dialog.assign_at_least", {"count": min_select}))
		return
	if max_select > 0 and assignment_count > max_select:
		scene.call("_log", _bt(scene, "battle.dialog.assign_at_most", {"count": max_select}))
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment_variant: Variant in assignments:
		if assignment_variant is Dictionary:
			stored_assignments.append((assignment_variant as Dictionary).duplicate())
	var pending_step_index := int(scene.get("_pending_effect_step_index"))
	var pending_steps: Array = scene.get("_pending_effect_steps")
	if pending_step_index < 0 or pending_step_index >= pending_steps.size():
		var pending_choice := str(scene.get("_pending_choice"))
		if pending_choice == "heavy_baton_target":
			var dialog_overlay_hb: Panel = scene.get("_dialog_overlay")
			dialog_overlay_hb.visible = false
			reset_dialog_assignment_state(scene)
			scene.call("_commit_heavy_baton_assignment", stored_assignments)
			return
		if pending_choice == "exp_share_target":
			var dialog_overlay_exp: Panel = scene.get("_dialog_overlay")
			dialog_overlay_exp.visible = false
			reset_dialog_assignment_state(scene)
			scene.call("_commit_exp_share_assignment", stored_assignments)
			return
		return
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	dialog_overlay.visible = false
	reset_dialog_assignment_state(scene)
	scene.call("_commit_effect_assignment_selection", stored_assignments)


func _current_player_index(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.current_player_index
	return -1


func _turn_number(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.turn_number
	return 0


func show_setup_active_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	var items: Array[String] = []
	for card: CardInstance in basics:
		items.append("%s (HP %d)" % [card.card_data.name, card.card_data.hp])
	scene.set("_pending_choice", "setup_active_%d" % pi)
	var dialog_data := {
		"basics": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"choice_labels": items,
	}
	scene.call("_ensure_ai_opponent")
	var ai_opponent: Variant = scene.get("_ai_opponent")
	var is_ai_prompt: bool = (
		GameManager.current_mode == GameManager.GameMode.VS_AI
		and ai_opponent != null
		and pi == ai_opponent.player_index
	)
	if is_ai_prompt:
		scene.set("_dialog_data", dialog_data)
		scene.set("_dialog_items_data", items)
		var dialog_overlay: Panel = scene.get("_dialog_overlay")
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_overlay != null:
			dialog_overlay.visible = false
		if dialog_cancel != null:
			dialog_cancel.visible = false
	else:
		show_dialog(scene, "玩家 %d：选择战斗宝可梦" % (pi + 1), items, dialog_data)
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_cancel != null:
			dialog_cancel.visible = false
	scene.call("_maybe_run_ai")


func show_setup_bench_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	if player.is_bench_full():
		scene.set("_pending_choice", "")
		scene.set("_dialog_data", {})
		scene.set("_dialog_items_data", [])
		scene.call("_after_setup_bench", pi)
		_schedule_followup_ai_step_if_ready(scene, gsm)
		return
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if basics.is_empty():
		scene.set("_pending_choice", "")
		scene.set("_dialog_data", {})
		scene.set("_dialog_items_data", [])
		scene.call("_after_setup_bench", pi)
		_schedule_followup_ai_step_if_ready(scene, gsm)
		return
	var items: Array[String] = ["完成"]
	for card: CardInstance in basics:
		items.append("%s (HP %d)" % [card.card_data.name, card.card_data.hp])
	var choice_indices: Array[int] = []
	for card_idx: int in basics.size():
		choice_indices.append(card_idx + 1)
	scene.set("_pending_choice", "setup_bench_%d" % pi)
	var dialog_data := {
		"cards": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"card_indices": choice_indices,
		"choice_labels": items.slice(1),
		"utility_actions": [{"label": "完成", "index": 0}],
	}
	scene.call("_ensure_ai_opponent")
	var ai_opponent: Variant = scene.get("_ai_opponent")
	var is_ai_prompt: bool = (
		GameManager.current_mode == GameManager.GameMode.VS_AI
		and ai_opponent != null
		and pi == ai_opponent.player_index
	)
	if is_ai_prompt:
		scene.set("_dialog_data", dialog_data)
		scene.set("_dialog_items_data", items)
		var dialog_overlay: Panel = scene.get("_dialog_overlay")
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_overlay != null:
			dialog_overlay.visible = false
		if dialog_cancel != null:
			dialog_cancel.visible = false
	else:
		show_dialog(scene, "玩家 %d：选择备战宝可梦（可选，最多 5 只）" % (pi + 1), items, dialog_data)
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_cancel != null:
			dialog_cancel.visible = false
	scene.call("_maybe_run_ai")


func _schedule_followup_ai_step_if_ready(scene: Object, gsm: Variant) -> void:
	if scene == null or gsm == null or gsm.game_state == null:
		return
	scene.call("_ensure_ai_opponent")
	var ai_opponent: Variant = scene.get("_ai_opponent")
	if GameManager.current_mode != GameManager.GameMode.VS_AI or ai_opponent == null:
		return
	if str(scene.get("_pending_choice")) != "":
		return
	if gsm.game_state.phase == GameState.GamePhase.SETUP:
		return
	if gsm.game_state.current_player_index != ai_opponent.player_index:
		return
	if bool(scene.get("_ai_running")):
		scene.set("_ai_followup_requested", true)
		return
	if bool(scene.get("_ai_step_scheduled")):
		return
	scene.set("_ai_step_scheduled", true)
	scene.call_deferred("_run_ai_step")


func show_send_out_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	var bench_choices: Array[PokemonSlot] = []
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and not gsm.effect_processor.is_effectively_knocked_out(bench_slot, gsm.game_state):
			bench_choices.append(bench_slot)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {
		"player": pi,
		"bench": bench_choices,
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	})
	scene.call("_show_field_slot_choice", "请选择玩家%d要派出的宝可梦" % (pi + 1), bench_choices, scene.get("_dialog_data"))

func show_heavy_baton_dialog(
	scene: Object,
	pi: int,
	bench_targets: Array[PokemonSlot],
	energy_count: int,
	source_name: String,
	source_slot: PokemonSlot = null,
	source_energy: Array[CardInstance] = []
) -> void:
	scene.set("_pending_choice", "heavy_baton_target")
	var dialog_data := {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"source_slot": source_slot,
		"source_energy": source_energy.duplicate(),
		"min_select": 1,
		"max_select": maxi(1, mini(energy_count, source_energy.size())),
		"allow_cancel": false,
	}
	scene.set("_dialog_data", dialog_data)
	if source_slot != null and not source_energy.is_empty():
		var source_labels: Array[String] = []
		var source_indices: Array[int] = []
		for i: int in source_energy.size():
			var energy: CardInstance = source_energy[i]
			source_labels.append(energy.card_data.name if energy != null and energy.card_data != null else "")
			source_indices.append(i)
		var target_labels: Array[String] = []
		for target: PokemonSlot in bench_targets:
			target_labels.append(target.get_pokemon_name())
		var assignment_data := dialog_data.duplicate(true)
		assignment_data.merge({
			"ui_mode": "card_assignment",
			"source_items": source_energy.duplicate(),
			"source_labels": source_labels,
			"source_groups": [{"slot": source_slot, "card_indices": source_indices, "energy_indices": source_indices}],
			"target_items": bench_targets.duplicate(),
			"target_labels": target_labels,
			"single_target_only": true,
			"min_select": 1,
			"max_select": maxi(1, mini(energy_count, source_energy.size())),
			"allow_cancel": false,
		}, true)
		scene.call("_show_dialog", "%s：选择要转移的能量和接收宝可梦" % source_name, [], assignment_data)
		return
	scene.call(
		"_show_field_slot_choice",
		"%s：选择接收 %d 个能量的备战宝可梦" % [source_name, energy_count],
		bench_targets,
		scene.get("_dialog_data")
	)


func show_exp_share_dialog(
	scene: Object,
	pi: int,
	bench_targets: Array[PokemonSlot],
	source_slot: PokemonSlot,
	source_energy: Array[CardInstance]
) -> void:
	scene.set("_pending_choice", "exp_share_target")
	var dialog_data := {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"source_slot": source_slot,
		"source_energy": source_energy.duplicate(),
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}
	scene.set("_dialog_data", dialog_data)
	var source_labels: Array[String] = []
	var source_indices: Array[int] = []
	for i: int in source_energy.size():
		var energy: CardInstance = source_energy[i]
		source_labels.append(energy.card_data.name if energy != null and energy.card_data != null else "")
		source_indices.append(i)
	var target_labels: Array[String] = []
	for target: PokemonSlot in bench_targets:
		target_labels.append(target.get_pokemon_name())
	var assignment_data := dialog_data.duplicate(true)
	assignment_data.merge({
		"ui_mode": "card_assignment",
		"source_items": source_energy.duplicate(),
		"source_labels": source_labels,
		"source_groups": [{"slot": source_slot, "card_indices": source_indices, "energy_indices": source_indices}],
		"target_items": bench_targets.duplicate(),
		"target_labels": target_labels,
		"single_target_only": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}, true)
	scene.call("_show_dialog", "学习装置：选择要转移的能量和接收宝可梦", [], assignment_data)


func show_pokemon_action_dialog(scene: Object, cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_data: CardData = slot.get_card_data()
	var items: Array[String] = []
	var actions: Array[Dictionary] = []
	var action_items: Array[Dictionary] = []
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	for i: int in card_data.abilities.size():
		var ability: Dictionary = card_data.abilities[i]
		var ability_name := str(ability.get("name", ""))
		var can_use := false
		var ability_reason := "%s 当前无法使用特性" % card_data.name
		if effect != null and effect.has_method("can_use_ability"):
			can_use = gsm.effect_processor.can_use_ability(slot, gsm.game_state, i)
			ability_reason = "" if can_use else "%s 当前无法使用特性" % card_data.name
		items.append("%s[特性] %s" % ["" if can_use else "[不可用] ", ability_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": i,
			"enabled": can_use,
			"reason": ability_reason,
		})
		action_items.append(_build_pokemon_action_item(
			"ability",
			"特性",
			ability_name,
			"",
			_action_body_from_text(str(ability.get("text", ""))),
			can_use,
			ability_reason
		))
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, gsm.game_state):
		var can_use_granted: bool = bool(granted.get("enabled", false))
		var granted_name := str(granted.get("name", ""))
		var granted_reason := "" if can_use_granted else "%s 当前无法使用特性" % card_data.name
		items.append("%s[特性] %s" % ["" if can_use_granted else "[不可用] ", granted_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": int(granted.get("ability_index", card_data.abilities.size())),
			"enabled": can_use_granted,
			"reason": granted_reason,
		})
		action_items.append(_build_pokemon_action_item(
			"ability",
			"特性",
			granted_name,
			"赋予",
			_action_body_from_text(str(granted.get("text", "由场上效果赋予的特性。"))),
			can_use_granted,
			granted_reason
		))
	if include_attacks:
		for i: int in card_data.attacks.size():
			var attack: Dictionary = card_data.attacks[i]
			var can_use_attack: bool = gsm.can_use_attack(cp, i)
			var attack_reason: String = "" if can_use_attack else gsm.get_attack_unusable_reason(cp, i)
			var preview_damage: int = gsm.get_attack_preview_damage(cp, i)
			items.append("%s[招式] %s [%s] %s" % [
				"" if can_use_attack else "[不可用] ",
				str(attack.get("name", "")),
				str(attack.get("cost", "")),
				str(attack.get("damage", "")),
			])
			actions.append({
				"type": "attack",
				"slot": slot,
				"attack_index": i,
				"enabled": can_use_attack,
				"reason": attack_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"attack",
				"招式",
				str(attack.get("name", "")),
				_attack_damage_meta_text(attack, preview_damage),
				_attack_body_text(attack, preview_damage),
				can_use_attack,
				attack_reason,
				str(attack.get("cost", ""))
			))
		for granted_attack: Dictionary in gsm.effect_processor.get_granted_attacks(slot, gsm.game_state):
			var granted_can_use: bool = bool(scene.call("_can_use_granted_attack", cp, slot, granted_attack))
			var granted_reason: String = "" if granted_can_use else str(scene.call("_get_granted_attack_unusable_reason", cp, slot, granted_attack))
			items.append("%s[招式] %s [%s]" % [
				"" if granted_can_use else "[不可用] ",
				str(granted_attack.get("name", "")),
				str(granted_attack.get("cost", "")),
			])
			actions.append({
				"type": "granted_attack",
				"slot": slot,
				"granted_attack": granted_attack,
				"enabled": granted_can_use,
				"reason": granted_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"granted_attack",
				"招式",
				str(granted_attack.get("name", "")),
				_attack_damage_meta_text(granted_attack, 0),
				_attack_body_text(granted_attack, 0),
				granted_can_use,
				granted_reason,
				str(granted_attack.get("cost", ""))
			))
		if slot == gsm.game_state.players[cp].active_pokemon:
			var can_retreat: bool = gsm.rule_validator.can_retreat(gsm.game_state, cp, gsm.effect_processor)
			var retreat_cost: int = gsm.effect_processor.get_effective_retreat_cost(slot, gsm.game_state)
			items.append("%s[行动] 撤退" % ("" if can_retreat else "[不可用] "))
			actions.append({
				"type": "retreat",
				"enabled": can_retreat,
				"reason": "当前无法撤退",
			})
			action_items.append(_build_pokemon_action_item(
				"retreat",
				"行动",
				"撤退",
				"费用 %d" % retreat_cost,
				"支付撤退费用，选择 1 只备战宝可梦与战斗宝可梦交换。",
				can_retreat,
				"当前无法撤退"
			))
	if actions.is_empty():
		var empty_reason := "%s 当前没有可执行的行动" % card_data.name
		items.append("[不可用] 当前没有可执行行动")
		actions.append({
			"type": "noop",
			"enabled": false,
			"reason": empty_reason,
		})
		action_items.append(_build_pokemon_action_item(
			"noop",
			"行动",
			"当前没有可执行行动",
			"",
			"这只宝可梦当前没有可用的特性、招式或撤退操作。",
			false,
			empty_reason
		))
	scene.set("_pending_choice", "pokemon_action")
	show_dialog(scene, "选择行动：%s" % card_data.name, items, {
		"player": cp,
		"actions": actions,
		"action_items": action_items,
		"pokemon_card": slot.get_top_card(),
		"pokemon_card_data": card_data,
		"presentation": "action_hud",
		"allow_cancel": true,
	})
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	if dialog_cancel != null:
		dialog_cancel.visible = true


func _build_pokemon_action_item(
	action_type: String,
	kind: String,
	title: String,
	meta: String,
	body: String,
	enabled: bool,
	reason: String,
	cost: String = ""
) -> Dictionary:
	return {
		"type": action_type,
		"kind": kind,
		"title": title if title.strip_edges() != "" else "未命名",
		"meta": meta,
		"body": body,
		"cost": cost,
		"enabled": enabled,
		"reason": reason,
	}


func _attack_damage_meta_text(attack: Dictionary, preview_damage: int) -> String:
	var damage := str(attack.get("damage", "")).strip_edges()
	if damage != "":
		return "伤害 %s" % damage
	if preview_damage > 0:
		return "预览 %d" % preview_damage
	return ""


func _attack_meta_text(attack: Dictionary, preview_damage: int) -> String:
	var parts: Array[String] = []
	var cost := str(attack.get("cost", "")).strip_edges()
	var damage := str(attack.get("damage", "")).strip_edges()
	if cost != "":
		parts.append("费用 %s" % cost)
	if damage != "":
		parts.append("伤害 %s" % damage)
	elif preview_damage > 0:
		parts.append("预览 %d" % preview_damage)
	return " · ".join(parts)


func _attack_body_text(attack: Dictionary, preview_damage: int) -> String:
	var lines: Array[String] = []
	var damage := str(attack.get("damage", "")).strip_edges()
	if damage != "":
		lines.append("基础伤害：%s。" % damage)
	elif preview_damage > 0:
		lines.append("预览伤害：%d。" % preview_damage)
	var text := str(attack.get("text", "")).strip_edges()
	if text != "":
		lines.append(text)
	if lines.is_empty():
		lines.append("无额外效果。")
	return "\n".join(lines)


func _action_body_from_text(text: String) -> String:
	var body := text.strip_edges()
	return body if body != "" else "无额外效果。"


func _legacy_show_pokemon_action_dialog(scene: Object, cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_data: CardData = slot.get_card_data()
	var items: Array[String] = []
	var actions: Array[Dictionary] = []
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	if effect != null:
		for i: int in card_data.abilities.size():
			var ability: Dictionary = card_data.abilities[i]
			if not effect.has_method("can_use_ability"):
				continue
			var can_use: bool = gsm.effect_processor.can_use_ability(slot, gsm.game_state, i)
			var ability_reason := "" if can_use else "%s 当前无法使用特性" % card_data.name
			var prefix := "" if can_use else "[不可用] "
			items.append("%s[特性] %s" % [prefix, ability.get("name", "")])
			actions.append({
				"type": "ability",
				"slot": slot,
				"ability_index": i,
				"enabled": can_use,
				"reason": ability_reason,
			})
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, gsm.game_state):
		var can_use_granted: bool = bool(granted.get("enabled", false))
		var granted_name := str(granted.get("name", ""))
		var granted_reason := "" if can_use_granted else "%s 当前无法使用特性" % card_data.name
		var granted_prefix := "" if can_use_granted else "[不可用] "
		items.append("%s[特性] %s" % [granted_prefix, granted_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": int(granted.get("ability_index", card_data.abilities.size())),
			"enabled": can_use_granted,
			"reason": granted_reason,
		})
	if include_attacks:
		for i: int in card_data.attacks.size():
			var attack: Dictionary = card_data.attacks[i]
			var can_use_attack: bool = gsm.can_use_attack(cp, i)
			var attack_reason: String = "" if can_use_attack else gsm.get_attack_unusable_reason(cp, i)
			var prefix: String = "" if can_use_attack else "[不可用] "
			var preview_damage: int = gsm.get_attack_preview_damage(cp, i)
			var preview_text := ""
			if String(attack.get("damage", "")) != "" or preview_damage > 0:
				preview_text = " 预览伤害:%d" % preview_damage
			items.append("%s[招式] %s [%s] %s%s" % [prefix, attack.get("name", ""), attack.get("cost", ""), attack.get("damage", ""), preview_text])
			actions.append({
				"type": "attack",
				"slot": slot,
				"attack_index": i,
				"enabled": can_use_attack,
				"reason": attack_reason,
			})
		for granted_attack: Dictionary in gsm.effect_processor.get_granted_attacks(slot, gsm.game_state):
			var granted_can_use: bool = bool(scene.call("_can_use_granted_attack", cp, slot, granted_attack))
			var granted_prefix: String = "" if granted_can_use else "[不可用] "
			var granted_reason: String = "" if granted_can_use else str(scene.call("_get_granted_attack_unusable_reason", cp, slot, granted_attack))
			items.append("%s[招式] %s [%s]" % [granted_prefix, str(granted_attack.get("name", "")), str(granted_attack.get("cost", ""))])
			actions.append({
				"type": "granted_attack",
				"slot": slot,
				"granted_attack": granted_attack,
				"enabled": granted_can_use,
				"reason": granted_reason,
			})
		if slot == gsm.game_state.players[cp].active_pokemon:
			var can_retreat: bool = gsm.rule_validator.can_retreat(gsm.game_state, cp, gsm.effect_processor)
			var retreat_prefix: String = "" if can_retreat else "[不可用] "
			items.append("%s[行动] 撤退" % retreat_prefix)
			actions.append({
				"type": "retreat",
				"enabled": can_retreat,
				"reason": "当前无法撤退",
			})
	if actions.is_empty():
		scene.call("_log", "%s 当前没有可执行的行动" % card_data.name)
		return
	scene.set("_pending_choice", "pokemon_action")
	show_dialog(scene, "选择行动：%s" % card_data.name, items, {"player": cp, "actions": actions})
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	if dialog_cancel != null:
		dialog_cancel.visible = true


func show_retreat_dialog(scene: Object, cp: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[cp]
	var active: PokemonSlot = player.active_pokemon
	var cost: int = gsm.effect_processor.get_effective_retreat_cost(active, gsm.game_state)
	var energy_discard: Array[CardInstance] = []
	var paid_units := 0
	for energy: CardInstance in active.attached_energy:
		if paid_units >= cost:
			break
		energy_discard.append(energy)
		paid_units += gsm.effect_processor.get_energy_colorless_count(energy)
	scene.set("_pending_choice", "retreat_bench")
	scene.set("_dialog_data", {
		"player": cp,
		"bench": player.bench,
		"energy_discard": energy_discard,
		"allow_cancel": true,
		"min_select": 1,
		"max_select": 1,
	})
	scene.call("_show_field_slot_choice", "选择接收 %d 个能量的备战宝可梦" % cost, player.bench, scene.get("_dialog_data"))


func show_match_end_dialog(scene: Object, winner_index: int, reason: String) -> void:
	var summary := match_end_summary_text(winner_index, reason)
	var items: Array[String] = [summary]
	var extra_data := {
		"winner": winner_index,
		"reason": reason,
		"action": "game_over",
	}
	var review_action := current_match_end_review_action(scene)
	if not review_action.is_empty():
		items.append(str(review_action.get("label", "生成AI复盘")))
		extra_data["review_action"] = str(review_action.get("kind", "generate"))
		extra_data["review_action_index"] = items.size() - 1
	var learning_action := current_match_end_learning_action(scene)
	if not learning_action.is_empty():
		items.append(str(learning_action.get("label", "让AI学习")))
		extra_data["learning_action"] = str(learning_action.get("kind", "mark"))
		extra_data["learning_action_index"] = items.size() - 1
	items.append("返回对战准备")
	extra_data["return_action_index"] = items.size() - 1
	scene.set("_pending_choice", "game_over")
	show_dialog(scene, "对战结束", items, extra_data)


func match_end_summary_text(winner_index: int, reason: String) -> String:
	return "玩家 %d 获胜\n原因：%s" % [winner_index + 1, reason]


func current_match_end_review_action(scene: Object) -> Dictionary:
	if not bool(scene.call("_should_offer_battle_review")):
		return {}
	if bool(scene.get("_battle_review_busy")):
		var progress_text := str(scene.get("_battle_review_progress_text"))
		return {
			"kind": "busy",
			"label": progress_text if progress_text != "" else "正在生成AI复盘...",
		}
	var cached_review: Dictionary = scene.call("_load_cached_battle_review")
	var cached_status := str(cached_review.get("status", ""))
	if cached_status in ["completed", "partial_success"]:
		scene.set("_battle_review_last_review", cached_review)
		return {"kind": "view", "label": "查看AI复盘"}
	if cached_status == "failed":
		scene.set("_battle_review_last_review", cached_review)
		return {"kind": "retry", "label": "生成失败，重试"}
	var last_review: Dictionary = scene.get("_battle_review_last_review")
	if str(last_review.get("status", "")) == "failed":
		return {"kind": "retry", "label": "生成失败，重试"}
	return {"kind": "generate", "label": "生成AI复盘"}


func current_match_end_learning_action(scene: Object) -> Dictionary:
	if not bool(scene.call("_should_offer_match_learning")):
		return {}
	if bool(scene.call("_is_current_match_marked_for_learning")):
		return {"kind": "marked", "label": "已加入学习池"}
	return {"kind": "mark", "label": "让AI学习"}
