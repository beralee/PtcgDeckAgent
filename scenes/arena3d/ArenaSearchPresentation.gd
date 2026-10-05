extends Node
## Decorates the existing search owner. Does not select, reorder or copy options.
const Preview := preload("res://scenes/arena3d/ArenaPreviewCard.gd")
var presenter: Control
var battle: Control
var board: Control
var left_panel: PanelContainer
var right_panel: PanelContainer
var left: Control
var right: Control
var left_title: Label
var left_caption: Label
var right_caption: Label
var current_card: BattleCardView
var source_card: BattleCardView
var generation := -1
var selected_signature := ""
var layout_size := Vector2.ZERO
var old_minimum := Vector2.ZERO
var compact := false

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c27")
	style.border_color = Color("3d6674")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0,0,0,.45)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel",style)
	return panel

func _column(panel: Control, title: String) -> Dictionary:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",18)
	column.add_child(heading)
	var preview := Preview.new()
	preview.world = presenter.world
	column.add_child(preview)
	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",15)
	column.add_child(caption)
	return {"title":heading,"preview":preview,"caption":caption}

func apply() -> void:
	var box: Control = battle.get("_dialog_box")
	if not battle.get("_dialog_library_search_board_mode"):
		if old_minimum != Vector2.ZERO:
			box.custom_minimum_size.x = old_minimum.x
			old_minimum = Vector2.ZERO
		return
	board = battle.get("_dialog_library_search_board")
	if not is_instance_valid(board): return
	compact = presenter.platform_metrics.compact
	if compact:
		if is_instance_valid(left_panel): left_panel.hide()
		if is_instance_valid(right_panel): right_panel.hide()
		if old_minimum != Vector2.ZERO:
			box.custom_minimum_size = old_minimum
			old_minimum = Vector2.ZERO
		var owner = battle.get("_battle_dialog_controller")
		owner._apply_library_search_board_layout(battle,owner._library_search_board_nodes(board))
		layout_size = battle.get_viewport_rect().size
		return
	var main: HBoxContainer = board.find_child("LibrarySearchMainRow",true,false)
	if left_panel == null:
		left_panel = _panel()
		left_panel.name = "ArenaSelectedCardPanel"
		main.add_child(left_panel)
		main.move_child(left_panel,0)
		var l := _column(left_panel,"候选预览")
		left = l.preview
		left_title = l.title
		left_caption = l.caption
		left.inspect.connect(func(): _inspect(current_card))
		right_panel = _panel()
		right_panel.name = "ArenaSourceCardPanel"
		main.add_child(right_panel)
		var r := _column(right_panel,"正在使用")
		right = r.preview
		right_caption = r.caption
		right.inspect.connect(func(): _inspect(source_card))
	# The original source view remains the authority for texture and details.
	left_panel.show()
	# Keep it populated but replace its small visible panel with our 3D view.
	board.find_child("LibrarySearchSourcePanel",true,false).hide()
	board.find_child("LibrarySearchPortraitSourcePanel",true,false).hide()
	var holder := board.find_child("LibrarySearchSourceCardHolder",true,false)
	source_card = holder.get_child(0) as BattleCardView if holder.get_child_count() else null
	right.set_art(_texture(source_card))
	right_caption.text = _name(source_card)+"\n点击大图查看详情"
	right_panel.visible = source_card != null
	var row: HBoxContainer = board.find_child("LibraryCardRow",true,false)
	for slot in row.get_children():
		if slot.get_child_count() == 0: continue
		var card := slot.get_child(0) as BattleCardView
		if card == null: continue
		card.info_overlay_enabled = false
		if not slot.has_meta("arena_preview_bound"):
			slot.set_meta("arena_preview_bound",true)
			var bound_generation := int(battle.get("_dialog_generation"))
			slot.mouse_entered.connect(func():
				if bound_generation == int(battle.get("_dialog_generation")): _show_card(card,"候选预览")
			)
			slot.mouse_exited.connect(_show_selected)
	if generation != int(battle.get("_dialog_generation")):
		generation = int(battle.get("_dialog_generation"))
		selected_signature = ""
		current_card = null
		for slot in row.get_children():
			if int(slot.get_meta("dialog_choice_index",-1)) >= 0 and slot.get_child_count():
				_show_card(slot.get_child(0) as BattleCardView,"候选预览")
				break
		if current_card == null and row.get_child_count() and row.get_child(0).get_child_count(): _show_card(row.get_child(0).get_child(0) as BattleCardView,"牌库预览")
	if old_minimum == Vector2.ZERO: old_minimum = box.custom_minimum_size
	_layout()
	_show_selected()

func _layout() -> void:
	layout_size = battle.get_viewport_rect().size
	var height := clampf(layout_size.y*.45,330,470)
	for preview in [left,right]:
		preview.custom_minimum_size = Vector2(roundf(height*.716),height)
		preview.motion_enabled = presenter.world.motion_enabled
	var box: Control = battle.get("_dialog_box")
	box.custom_minimum_size.x = minf(1640,layout_size.x-48)
	board.custom_minimum_size.y = maxf(height+96,470)
	_polish()
	call_deferred("_polish")

func _polish() -> void:
	if not is_instance_valid(board): return
	var bar: PanelContainer = board.find_child("LibrarySearchInstructionBar",true,false)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142d3a")
	style.border_color = Color("668e9e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("panel",style)
	var instruction: Label = board.find_child("LibrarySearchInstructionLabel",true,false)
	instruction.add_theme_font_size_override("font_size",18)
	for button: Button in [battle.get("_dialog_confirm"),battle.get("_dialog_cancel")]:
		button.custom_minimum_size = Vector2(108,46)
	# The selected strip is rebuilt by its existing owner after every click.
	# Apply the same clean printed-card presentation to these new views.
	for node in board.find_children("*","",true,false):
		if node is BattleCardView: node.info_overlay_enabled = false

func _texture(card: BattleCardView) -> Texture2D:
	if not is_instance_valid(card) or card.get("_face_down"): return null
	return card.get("_texture_rect").texture

func _name(card: BattleCardView) -> String:
	return card.card_data.display_name() if is_instance_valid(card) and card.card_data != null else "本次效果"

func _show_card(card: BattleCardView, title: String) -> void:
	if not is_instance_valid(card): return
	current_card = card
	left.set_art(_texture(card))
	left_title.text = title
	left_caption.text = _name(card)+"\n点击大图查看详情"

func _show_selected() -> void:
	if not is_instance_valid(board): return
	var indices: Array = battle.get("_dialog_card_selected_indices")
	var row: Node = board.find_child("LibraryCardRow",true,false)
	if indices.is_empty():
		if is_instance_valid(current_card): left_title.text = "候选预览"
		return
	for slot in row.get_children():
		if int(slot.get_meta("dialog_choice_index",-1)) == int(indices.back()) and slot.get_child_count():
			_show_card(slot.get_child(0) as BattleCardView,"已选卡牌 · %d 张"%indices.size())
			return

func _inspect(card: BattleCardView) -> void:
	if is_instance_valid(card) and _texture(card) != null:
		battle.call("_on_dialog_card_right_signal",card.card_instance,card.card_data)

func _process(_delta: float) -> void:
	if not is_instance_valid(board) or not board.is_visible_in_tree(): return
	if battle.get_viewport_rect().size != layout_size or compact != bool(presenter.platform_metrics.compact):
		apply()
		battle.get("_battle_dialog_controller").compact_dialog_box_to_content(battle)
	if compact: return
	left.motion_enabled = presenter.world.motion_enabled
	right.motion_enabled = presenter.world.motion_enabled
	if battle.get_viewport_rect().size != layout_size:
		_layout()
		battle.get("_battle_dialog_controller").compact_dialog_box_to_content(battle)
	var signature := str(battle.get("_dialog_card_selected_indices"))
	if signature != selected_signature:
		selected_signature = signature
		_show_selected()
		_polish()
