extends RefCounted
## Responsive host geometry; the inherited controls remain the action owners.
static func apply(scene: Control, force: bool = false) -> void:
	var area := scene.get_node_or_null("MainArea") as Control
	if area == null: return
	var view_size := scene.get_viewport_rect().size
	var metrics := preload("res://scenes/arena3d/ArenaPlatform.gd").metrics(view_size,GameManager.ui_runtime_profile)
	var safe := preload("res://scenes/arena3d/ArenaPlatform.gd").safe_rect(scene)
	scene.get_node("MainArea/LogPanel").visible = bool(scene.get_meta("arena_log_open", false)) and not metrics.compact
	var top := scene.get_node("TopBar") as Control
	top.visible = not metrics.compact
	top.offset_left = safe.position.x
	top.offset_right = safe.end.x-view_size.x
	top.offset_top = safe.position.y
	top.offset_bottom = safe.position.y+56
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.offset_left = safe.position.x
	area.offset_right = safe.end.x-view_size.x
	area.offset_top = safe.position.y+(0 if metrics.compact else 58)+float(scene.get_meta("commentary_reserved_height",0.0))
	area.offset_bottom = safe.end.y-view_size.y
	area.custom_minimum_size = Vector2.ZERO
	var edge_hud := scene.get_node_or_null("PortraitEdgeHudOverlay") as Control
	if edge_hud != null: edge_hud.hide()
	# These controls are also toggled by the inherited display refresh.
	for name in ["BtnAttackVfxPreview", "BtnBattleLayout"]:
		var button := scene.find_child(name, true, false) as Control
		if button != null: button.hide()
	var panel := scene.get("_field_interaction_panel") as Control
	var row := scene.get("_field_interaction_row") as Control
	var strip := scene.get("_field_interaction_scroll") as Control
	if panel != null and row != null and row.get_child_count() == 0:
		panel.custom_minimum_size.y = 0
		if strip != null: strip.custom_minimum_size.y = 0
	if not force and scene.get_meta("arena_layout_size",Vector2.ZERO) == view_size: return
	scene.set_meta("arena_layout_size",view_size)
	# The 2D portrait view writes explicit modal rectangles. Rebind them to
	# this viewport when rotating, including dialogs opened after the resize.
	for name: String in ["DialogOverlay","HandoverPanel","CoinFlipOverlay","DetailOverlay","DiscardOverlay","ReviewOverlay","FieldInteractionOverlay","DrawRevealOverlay","MatchEndOverlay","InvalidActionOverlay"]:
		var overlay := scene.find_child(name,true,false) as Control
		if overlay == null: continue
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.offset_left = safe.position.x
		overlay.offset_top = safe.position.y
		overlay.offset_right = safe.end.x-view_size.x
		overlay.offset_bottom = safe.end.y-view_size.y
		for child in overlay.get_children():
			if child is Control and (str(child.name).ends_with("Center") or child.has_meta("portrait_modal_full_rect_child")):
				child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if scene.get("_dialog_overlay") != null and scene.get("_dialog_overlay").visible:
		scene.get("_battle_dialog_controller").compact_dialog_box_to_content(scene)
	(scene.get_node("MainArea/CenterField") as Control).custom_minimum_size = Vector2.ZERO
	for path in ["MainArea/LeftPanel", "MainArea/RightPanel", "MainArea/CenterField/OppHandBar"]:
		scene.get_node(path).hide()
	var field := scene.get_node("MainArea/CenterField/FieldArea") as Control
	for child in field.get_children():
		if child is Control: child.hide()
	field.custom_minimum_size = Vector2.ZERO
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var height := clampf(view_size.y * .148, 106, 190)
	if metrics.compact: height = clampf(view_size.y*.16,84*metrics.scale,150*metrics.scale)
	var card_size := Vector2(roundf(height * .716), height)
	scene.set("_play_card_size", card_size)
	var hand := scene.get("_hand_container") as HBoxContainer
	var scroll := scene.get("_hand_scroll") as ScrollContainer
	if hand != null:
		hand.custom_minimum_size = Vector2(0, height+28)
		hand.alignment = BoxContainer.ALIGNMENT_CENTER
		hand.add_theme_constant_override("separation", -roundi(card_size.x*.16))
		for card in hand.get_children():
			if card is BattleCardView: card.custom_minimum_size = card_size
	if scroll != null: scroll.custom_minimum_size = Vector2(0,height+28)
	var hand_area := scene.get_node("MainArea/CenterField/HandArea") as Control
	hand_area.size_flags_vertical = Control.SIZE_FILL
	hand_area.custom_minimum_size = Vector2(0,height+30)
	var title := scene.get_node("MainArea/CenterField/HandArea/HandVBox/HandTitle") as Label
	title.hide()
	for name in ["LblPhase", "LblTurn"]:
		var label := scene.find_child(name, true, false) as Label
		if label != null: label.add_theme_font_size_override("font_size", 15)
