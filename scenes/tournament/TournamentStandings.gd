extends Control

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const CHAMPION_GOLD := Color(1.0, 0.72, 0.24, 1.0)
const CHAMPION_TEXT := Color(1.0, 0.96, 0.82, 1.0)
const CHAMPION_DEEP := Color(0.12, 0.055, 0.018, 0.92)

var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _last_non_battle_layout_context: Dictionary = {}


func _ready() -> void:
	HudThemeScript.apply(self)
	_connect_non_battle_layout_signal()
	%TitleLabel.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(26))
	%ChampionTitle.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(34))
	_apply_champion_banner_style()
	%BtnPrimary.pressed.connect(_on_primary_pressed)
	%BtnSecondary.pressed.connect(_on_secondary_pressed)
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
		panel.custom_minimum_size.x = float(context.get("content_width", 900.0)) if portrait else 900.0
		panel.custom_minimum_size.y = maxf(760.0, size.y - float(context.get("page_margin", 24.0)) * 2.0) if portrait else 640.0
	_apply_standings_mobile_metrics(self, context, portrait)
	_apply_standings_button_stack(portrait)


func _apply_standings_mobile_metrics(node: Node, context: Dictionary, portrait: bool) -> void:
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, float(context.get("secondary_button_height", 46.0)) if portrait else button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", int(context.get("button_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
		NonBattleTouchBridgeScript.bind_button_touch(button)
	elif node is TextEdit or node is RichTextLabel:
		var control := node as Control
		if portrait:
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, float(context.get("list_item_min_height", 148.0)) * 1.5)
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
	elif node is Label:
		var label := node as Label
		if label.name == "TitleLabel":
			label.add_theme_font_size_override("font_size", int(context.get("title_font_size", 26)) if portrait else HudThemeScript.scaled_font_size(26))
		elif label.name == "ChampionTitle":
			label.add_theme_font_size_override("font_size", int(context.get("section_font_size", 29)) if portrait else HudThemeScript.scaled_font_size(34))
			if portrait:
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif portrait:
			label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child: Node in node.get_children():
		_apply_standings_mobile_metrics(child, context, portrait)


func _apply_standings_button_stack(portrait: bool) -> void:
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
	if not GameManager.has_active_tournament():
		%TitleLabel.text = "比赛模式"
		%SummaryText.text = "当前没有进行中的比赛。"
		%StandingsLabel.text = "积分榜"
		%StandingsText.text = ""
		%BtnPrimary.text = "返回首页"
		%BtnSecondary.visible = false
		_set_champion_banner_visible(false)
		return

	var tournament: RefCounted = GameManager.current_tournament
	var summary: Dictionary = tournament.last_round_summary
	var round_number: int = int(summary.get("round", tournament.current_round))
	var player: Dictionary = summary.get("player", {})
	var opponent: Dictionary = summary.get("opponent", {})
	var result_label := "胜利" if str(summary.get("result", "")) == "win" else "失利"
	var standings: Array = _normalize_standings(summary.get("standings", tournament.get_standings()))
	var final_round := bool(summary.get("is_final_round", false))
	var player_rank := _rank_for_player(standings, int(tournament.player_participant_id))
	var player_is_champion := final_round and player_rank == 1

	if player_is_champion:
		%TitleLabel.text = "冠军诞生"
	elif final_round:
		%TitleLabel.text = "比赛结束"
	else:
		%TitleLabel.text = "第 %d 轮结束" % round_number
	_set_champion_banner_visible(player_is_champion)
	if player_is_champion:
		_render_champion_banner(tournament, player)

	var summary_lines: Array[String] = []
	if not player.is_empty():
		if player_is_champion:
			summary_lines.append(_champion_title_text(tournament, player))
			summary_lines.append("这不是单局胜利，而是整场瑞士轮稳定表现的结果。")
			summary_lines.append("最终积分：%d" % int(player.get("points", 0)))
		else:
			summary_lines.append("本轮结果：%s" % result_label)
			summary_lines.append("你的积分：%d" % int(player.get("points", 0)))
			if final_round and player_rank > 0:
				summary_lines.append("最终排名：第 %d 名" % player_rank)
		summary_lines.append("你的战绩：%d-%d-%d" % [
			int(player.get("wins", 0)),
			int(player.get("losses", 0)),
			int(player.get("draws", 0)),
		])
	if not opponent.is_empty():
		summary_lines.append("本轮对手：%s" % str(opponent.get("name", "")))
		summary_lines.append("对手卡组：%s" % tournament.participant_deck_name(int(opponent.get("id", -1))))
	if str(summary.get("reason", "")).strip_edges() != "":
		summary_lines.append("结束原因：%s" % str(summary.get("reason", "")))
	%SummaryText.text = "\n".join(summary_lines)
	%StandingsLabel.text = "最终积分榜" if final_round else "积分榜"
	%StandingsText.text = _build_standings_text(standings)
	%BtnPrimary.text = "返回首页" if final_round else "下一轮"
	%BtnSecondary.visible = true
	%BtnSecondary.text = "结束比赛"


func _apply_champion_banner_style() -> void:
	var banner := get_node_or_null("%ChampionBanner") as PanelContainer
	if banner == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = CHAMPION_DEEP
	style.border_color = CHAMPION_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(1.0, 0.58, 0.12, 0.34)
	style.shadow_size = 18
	banner.add_theme_stylebox_override("panel", style)
	%ChampionKicker.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(13))
	%ChampionKicker.add_theme_color_override("font_color", Color(1.0, 0.80, 0.36, 1.0))
	%ChampionTitle.add_theme_color_override("font_color", CHAMPION_TEXT)
	%ChampionTitle.add_theme_color_override("font_shadow_color", Color(1.0, 0.58, 0.12, 0.72))
	%ChampionTitle.add_theme_constant_override("shadow_offset_y", 2)
	%ChampionSubtitle.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(16))
	%ChampionSubtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56, 1.0))


func _set_champion_banner_visible(visible: bool) -> void:
	var banner := get_node_or_null("%ChampionBanner") as Control
	if banner != null:
		banner.visible = visible


func _render_champion_banner(tournament: RefCounted, player: Dictionary) -> void:
	var record := "%d-%d-%d" % [
		int(player.get("wins", 0)),
		int(player.get("losses", 0)),
		int(player.get("draws", 0)),
	]
	%ChampionKicker.text = "TOURNAMENT CHAMPION"
	%ChampionTitle.text = _champion_title_text(tournament, player)
	%ChampionSubtitle.text = "最终战绩 %s，积分 %d。你的卡组赢下了整场比赛。" % [record, int(player.get("points", 0))]


func _champion_title_text(tournament: RefCounted, player: Dictionary) -> String:
	var player_name := str(player.get("name", tournament.player_name if tournament != null else "玩家")).strip_edges()
	if player_name == "":
		player_name = "玩家"
	return "恭喜，%s使用%s获得冠军！" % [player_name, _champion_deck_display(tournament, player)]


func _champion_deck_display(tournament: RefCounted, player: Dictionary) -> String:
	if tournament == null:
		return "参赛卡组"
	var participant_id := int(player.get("id", tournament.player_participant_id))
	var deck_name := str(tournament.participant_deck_name(participant_id)).strip_edges()
	if deck_name == "":
		return "参赛卡组"
	if deck_name.ends_with("卡组"):
		return deck_name
	return "%s卡组" % deck_name


func _normalize_standings(standings_variant: Variant) -> Array:
	var standings: Array = []
	if not (standings_variant is Array):
		return standings
	for entry_variant: Variant in standings_variant:
		if entry_variant is Dictionary:
			standings.append((entry_variant as Dictionary).duplicate(true))
	return standings


func _rank_for_player(standings: Array, player_id: int) -> int:
	for entry_variant: Variant in standings:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if int(entry.get("id", -1)) == player_id:
			return int(entry.get("rank", 0))
	return 0


func _build_standings_text(standings_variant: Variant) -> String:
	var lines: Array[String] = ["排名  积分  战绩      选手          卡组"]
	if not (standings_variant is Array):
		return "\n".join(lines)
	for entry_variant: Variant in standings_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var rank: int = int(entry.get("rank", 0))
		var points: int = int(entry.get("points", 0))
		var record := "%d-%d-%d" % [
			int(entry.get("wins", 0)),
			int(entry.get("losses", 0)),
			int(entry.get("draws", 0)),
		]
		var name: String = str(entry.get("name", ""))
		var deck_name := ""
		if GameManager.has_active_tournament():
			deck_name = GameManager.current_tournament.participant_deck_name(int(entry.get("id", -1)))
		lines.append("%2d    %2d    %-7s  %-12s  %s" % [rank, points, record, name, deck_name])
	return "\n".join(lines)


func _on_primary_pressed() -> void:
	if not GameManager.has_active_tournament():
		GameManager.goto_main_menu()
		return
	if GameManager.current_tournament.finished:
		GameManager.clear_tournament()
		GameManager.goto_main_menu()
		return
	if not GameManager.prepare_current_tournament_battle():
		GameManager.clear_tournament()
		GameManager.goto_main_menu()
		return
	GameManager.goto_battle()


func _on_secondary_pressed() -> void:
	GameManager.clear_tournament()
	GameManager.goto_main_menu()
