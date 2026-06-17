extends Control

const TOURNAMENT_SIZES := [16, 32, 64, 128]
const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

var _round_probe: RefCounted = SwissTournamentScript.new()
var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _last_non_battle_layout_context: Dictionary = {}


func _ready() -> void:
	HudThemeScript.apply(self)
	_connect_non_battle_layout_signal()
	%TitleLabel.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(24))
	%BtnBack.text = "返回"
	%BtnStart.text = "查看比赛情况"
	%TitleLabel.text = "比赛设置"
	%NameLabel.text = "玩家名字"
	%SizeLabel.text = "比赛人数"
	%HintLabel.text = "下一步会进入赛前总览页面，先查看参赛名单、卡组分布和本次瑞士轮轮数，再正式开始第一轮。"
	%NameEdit.placeholder_text = "输入你的名字"
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnStart.pressed.connect(_on_start_pressed)
	%NameEdit.text_changed.connect(_on_name_changed)
	_setup_size_options()
	_refresh_selected_deck()
	_refresh_round_info()
	_clear_error()
	call_deferred("_apply_non_battle_layout")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_non_battle_layout()


func _input(event: InputEvent) -> void:
	NonBattleTouchBridgeScript.handle_root_touch(self, event)


func _connect_non_battle_layout_signal() -> void:
	if GameManager == null or not GameManager.has_signal("non_battle_layout_mode_changed"):
		return
	var callback := Callable(self, "_on_non_battle_layout_mode_changed")
	if not GameManager.non_battle_layout_mode_changed.is_connected(callback):
		GameManager.non_battle_layout_mode_changed.connect(callback)


func _on_non_battle_layout_mode_changed(_mode: String) -> void:
	_apply_non_battle_layout()
	call_deferred("_apply_non_battle_layout")


func _apply_non_battle_layout_for_tests(viewport_size: Vector2, mode: String) -> void:
	_apply_non_battle_layout(viewport_size, mode)


func _apply_non_battle_layout(viewport_size: Vector2 = Vector2.ZERO, forced_mode: String = "") -> void:
	var size := viewport_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	var mode := forced_mode
	if mode == "":
		mode = str(GameManager.get("non_battle_layout_mode")) if GameManager != null else "landscape"
	var context: Dictionary = _non_battle_layout_controller.call("build_context", size, mode, false)
	_last_non_battle_layout_context = context.duplicate(true)
	var portrait := bool(context.get("is_portrait", false))
	set_meta("non_battle_layout_mode", str(context.get("resolved_mode", mode)))
	var panel := find_child("Panel", true, false) as Control
	if panel != null:
		panel.custom_minimum_size.x = float(context.get("content_width", 660.0)) if portrait else 660.0
		panel.custom_minimum_size.y = maxf(640.0, size.y - float(context.get("page_margin", 24.0)) * 2.0) if portrait else 460.0
	_apply_tournament_setup_mobile_metrics(self, context, portrait)
	_apply_tournament_setup_button_stack(portrait)


func _apply_tournament_setup_mobile_metrics(node: Node, context: Dictionary, portrait: bool) -> void:
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, float(context.get("secondary_button_height", 44.0)) if portrait else button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", int(context.get("button_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
		NonBattleTouchBridgeScript.bind_button_touch(button)
	elif node is OptionButton or node is LineEdit:
		var control := node as Control
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, float(context.get("input_height", 42.0)) if portrait else control.custom_minimum_size.y)
		if portrait:
			control.add_theme_font_size_override("font_size", maxi(int(context.get("input_font_size", 15)), int(context.get("button_font_size", 15))))
		if control is LineEdit:
			NonBattleTouchBridgeScript.bind_focus_control_touch(control)
	elif node is Label:
		var label := node as Label
		if label.name == "TitleLabel":
			label.add_theme_font_size_override("font_size", int(context.get("title_font_size", 24)) if portrait else HudThemeScript.scaled_font_size(24))
		elif portrait:
			label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child: Node in node.get_children():
		_apply_tournament_setup_mobile_metrics(child, context, portrait)


func _apply_tournament_setup_button_stack(portrait: bool) -> void:
	var current := find_child("ButtonRow", true, false) as BoxContainer
	if current == null:
		return
	if portrait and current is HBoxContainer:
		_replace_button_row(current, VBoxContainer.new(), 10)
	elif not portrait and current is VBoxContainer:
		_replace_button_row(current, HBoxContainer.new(), 16)


func _replace_button_row(current: BoxContainer, replacement: BoxContainer, separation: int) -> void:
	var parent := current.get_parent()
	if parent == null:
		return
	replacement.name = "ButtonRow"
	replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacement.add_theme_constant_override("separation", separation)
	var children := current.get_children()
	var index := current.get_index()
	var inherited_owner := current.owner
	parent.remove_child(current)
	parent.add_child(replacement)
	replacement.owner = inherited_owner
	parent.move_child(replacement, index)
	for child: Node in children:
		var child_owner := child.owner
		current.remove_child(child)
		child.owner = null
		replacement.add_child(child)
		child.owner = child_owner if child_owner != null else inherited_owner
	current.queue_free()


func _setup_size_options() -> void:
	%SizeOption.clear()
	for size: int in TOURNAMENT_SIZES:
		%SizeOption.add_item("%d 人" % size)
	%SizeOption.select(0)
	if not %SizeOption.item_selected.is_connected(_on_size_changed):
		%SizeOption.item_selected.connect(_on_size_changed)


func _refresh_selected_deck() -> void:
	var deck: DeckData = CardDatabase.get_deck(GameManager.tournament_selected_player_deck_id)
	%DeckLabel.text = "参赛卡组：%s" % (deck.deck_name if deck != null else "未选择")


func _selected_tournament_size() -> int:
	var size_index: int = maxi(0, %SizeOption.selected)
	return TOURNAMENT_SIZES[min(size_index, TOURNAMENT_SIZES.size() - 1)]


func _refresh_round_info() -> void:
	var tournament_size: int = _selected_tournament_size()
	var total_rounds: int = int(_round_probe.call("rounds_for_size", tournament_size))
	%RoundInfoLabel.text = "预计轮数：%d 轮（%d 人瑞士轮）" % [total_rounds, tournament_size]


func _clear_error() -> void:
	%ErrorLabel.visible = false
	%ErrorLabel.text = ""


func _show_error(message: String) -> void:
	%ErrorLabel.visible = true
	%ErrorLabel.text = message


func _on_size_changed(_index: int) -> void:
	_refresh_round_info()


func _on_name_changed(_text: String) -> void:
	_clear_error()


func _on_back_pressed() -> void:
	GameManager.goto_tournament_deck_select()


func _on_start_pressed() -> void:
	var player_name: String = %NameEdit.text.strip_edges()
	if player_name == "":
		_show_error("请输入玩家名字后再继续。")
		if %NameEdit.is_inside_tree():
			%NameEdit.grab_focus()
		return
	if GameManager.tournament_selected_player_deck_id <= 0:
		_show_error("请先返回上一页选择参赛卡组。")
		return
	var tournament_size: int = _selected_tournament_size()
	GameManager.start_swiss_tournament(player_name, tournament_size)
	if not GameManager.has_active_tournament():
		_show_error("比赛初始化失败，请重新选择卡组后再试。")
		return
	if not is_inside_tree():
		return
	GameManager.goto_tournament_overview()
