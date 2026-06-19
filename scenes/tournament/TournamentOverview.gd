extends Control

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _last_non_battle_layout_context: Dictionary = {}


func _ready() -> void:
	HudThemeScript.apply(self)
	_connect_non_battle_layout_signal()
	%TitleLabel.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(26))
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnStartRound.pressed.connect(_on_start_round_pressed)
	_render()
	call_deferred("_render")
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
		panel.custom_minimum_size.x = _portrait_tournament_width(size, context) if portrait else 980.0
		panel.custom_minimum_size.y = maxf(780.0, size.y - _portrait_tournament_margin(size, context) * 2.0) if portrait else 700.0
	if portrait:
		_apply_overview_portrait_stack()
	else:
		_apply_overview_landscape_stack()
	_apply_overview_mobile_metrics(self, context, portrait)
	_apply_overview_button_stack(portrait)


func _apply_overview_portrait_stack() -> void:
	var middle_row := find_child("MiddleRow", true, false) as HBoxContainer
	var distribution := find_child("DistributionBox", true, false) as Control
	var roster := find_child("RosterBox", true, false) as Control
	if middle_row == null or distribution == null or roster == null:
		return
	var parent := middle_row.get_parent()
	var stack := parent.get_node_or_null("PortraitTournamentStack") as VBoxContainer if parent != null else null
	if stack == null and parent != null:
		stack = VBoxContainer.new()
		stack.name = "PortraitTournamentStack"
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", 12)
		parent.add_child(stack)
		parent.move_child(stack, middle_row.get_index() + 1)
	middle_row.visible = false
	if stack == null:
		return
	stack.visible = true
	for box: Control in [distribution, roster]:
		if box.get_parent() != stack:
			if box.get_parent() != null:
				box.get_parent().remove_child(box)
			box.owner = null
			stack.add_child(box)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _apply_overview_landscape_stack() -> void:
	var middle_row := find_child("MiddleRow", true, false) as HBoxContainer
	var distribution := find_child("DistributionBox", true, false) as Control
	var roster := find_child("RosterBox", true, false) as Control
	var stack := find_child("PortraitTournamentStack", true, false) as VBoxContainer
	if stack != null:
		stack.visible = false
	if middle_row == null or distribution == null or roster == null:
		return
	for box: Control in [distribution, roster]:
		if box.get_parent() != middle_row:
			if box.get_parent() != null:
				box.get_parent().remove_child(box)
			box.owner = null
			middle_row.add_child(box)
	middle_row.move_child(distribution, 0)
	middle_row.move_child(roster, 1)
	middle_row.visible = true


func _apply_overview_mobile_metrics(node: Node, context: Dictionary, portrait: bool) -> void:
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, float(context.get("secondary_button_height", 46.0)) if portrait else button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", int(context.get("button_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
		NonBattleTouchBridgeScript.bind_button_touch(button)
	elif node is TextEdit or node is RichTextLabel:
		var control := node as Control
		if portrait:
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, float(context.get("list_item_min_height", 148.0)) * 1.5)
			_apply_portrait_hidden_drag_scrollable_control(control)
			if control is TextEdit:
				(control as TextEdit).add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)))
				(control as TextEdit).wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			elif control is RichTextLabel:
				var rich := control as RichTextLabel
				var font_size := int(context.get("body_font_size", 15))
				rich.add_theme_font_size_override("normal_font_size", font_size)
				rich.add_theme_font_size_override("bold_font_size", font_size)
				rich.add_theme_font_size_override("italics_font_size", font_size)
				rich.add_theme_font_size_override("mono_font_size", font_size)
		else:
			HudThemeScript.style_scrollable_control(control, "auto")
			NonBattleTouchBridgeScript.configure_visible_vertical_scrollable_control(control)
	elif node is Label:
		var label := node as Label
		if label.name == "TitleLabel":
			label.add_theme_font_size_override("font_size", int(context.get("title_font_size", 26)) if portrait else HudThemeScript.scaled_font_size(26))
		elif portrait:
			label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child: Node in node.get_children():
		_apply_overview_mobile_metrics(child, context, portrait)


func _portrait_tournament_margin(viewport_size: Vector2, context: Dictionary) -> float:
	var fallback := clampf(viewport_size.x * 0.026, 14.0, 28.0)
	return minf(float(context.get("page_margin", fallback)), fallback)


func _portrait_tournament_width(viewport_size: Vector2, context: Dictionary) -> float:
	var margin := _portrait_tournament_margin(viewport_size, context)
	return maxf(320.0, viewport_size.x - margin * 2.0)


func _apply_portrait_hidden_drag_scrollable_control(control: Control) -> void:
	HudThemeScript.style_scrollable_control(control, "auto")
	NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scrollable_control(control)


func _apply_overview_button_stack(portrait: bool) -> void:
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


func _render() -> void:
	%TitleLabel.text = "比赛总览"
	%SubtitleLabel.text = "开赛前先确认参赛名单、卡组分布和本次瑞士轮轮数。"
	%MetaTitle.text = "本次比赛"
	%RosterTitle.text = "全部参赛选手"
	%RosterHint.text = "带 * 的是玩家本人。"
	if not GameManager.has_active_tournament():
		%MetaLabel.text = "当前没有待开始的比赛。"
		%DistributionText.text = "卡组分布"
		%RosterText.text = "参赛名单"
		%BtnStartRound.disabled = true
		return

	var tournament: RefCounted = GameManager.current_tournament
	var snapshot: Dictionary = tournament.get_overview_snapshot()
	var tournament_size: int = int(snapshot.get("tournament_size", 0))
	var total_rounds: int = int(snapshot.get("total_rounds", 0))
	var player_name: String = str(snapshot.get("player_name", "玩家"))
	var player_deck_name: String = str(snapshot.get("player_deck_name", "未选择"))

	%MetaLabel.text = "\n".join([
		"玩家：%s" % player_name,
		"参赛卡组：%s" % player_deck_name,
		"比赛人数：%d 人" % tournament_size,
		"瑞士轮数：%d 轮" % total_rounds,
		"对局规则：每轮自动配对，随机先后攻。",
	])
	%DistributionText.text = _build_distribution_text(snapshot.get("deck_distribution", []))
	%RosterText.text = _build_roster_text(snapshot.get("participants", []))
	%BtnStartRound.disabled = false


func _build_distribution_text(distribution_variant: Variant) -> String:
	var lines: Array[String] = ["卡组分布", "", "数量  占比    卡组"]
	if not (distribution_variant is Array):
		return "\n".join(lines)
	for entry_variant: Variant in distribution_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var count: int = int(entry.get("count", 0))
		var share: float = float(entry.get("share", 0.0)) * 100.0
		var deck_name: String = str(entry.get("deck_name", ""))
		lines.append("%3d   %5.1f%%  %s" % [count, share, deck_name])
	return "\n".join(lines)


func _build_roster_text(participants_variant: Variant) -> String:
	var lines: Array[String] = ["参赛名单", "", "编号  强度   选手            卡组"]
	if not (participants_variant is Array):
		return "\n".join(lines)
	for entry_variant: Variant in participants_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var marker := "*" if bool(entry.get("is_player", false)) else " "
		var index_label := "%s%02d" % [marker, int(entry.get("id", 0)) + 1]
		var ai_mode := str(entry.get("ai_mode", ""))
		var mode_label := "玩家" if bool(entry.get("is_player", false)) else _ai_mode_label(ai_mode)
		var name: String = str(entry.get("name", ""))
		var deck_name: String = str(entry.get("deck_name", ""))
		lines.append("%-4s  %-4s  %-14s  %s" % [index_label, mode_label, name, deck_name])
	return "\n".join(lines)


func _ai_mode_label(ai_mode: String) -> String:
	match ai_mode:
		"strong":
			return "强AI"
		"llm":
			return "LLM"
		_:
			return "弱AI"


func _on_back_pressed() -> void:
	GameManager.discard_tournament_keep_selected_deck()
	GameManager.goto_tournament_setup()


func _on_start_round_pressed() -> void:
	if not GameManager.prepare_current_tournament_battle():
		_render()
		return
	GameManager.goto_battle()
