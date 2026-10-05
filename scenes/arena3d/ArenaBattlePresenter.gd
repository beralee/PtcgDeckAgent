extends Control

const GameModal := preload("res://scripts/ui/GameModalDialog.gd")
## Visual adapter only. All gameplay clicks return to the existing scene owner.
const WorldScript := preload("res://scenes/arena3d/ArenaWorld.gd")
const FrameScript := preload("res://scenes/arena3d/ArenaFrame.gd")
const ThemeScript := preload("res://scenes/arena3d/ArenaTheme.gd")
const Backs := preload("res://scenes/arena3d/ArenaCardBacks.gd")
const Platform := preload("res://scenes/arena3d/ArenaPlatform.gd")
var platform_metrics: Dictionary = {}
var board_rect := Rect2()
var view_texture: TextureRect
var menu_button: MenuButton
var status_bar: Control
var compact_log: GameModal
var compact_log_text: RichTextLabel
var ui_buttons: Array[Button] = []
var quality_high := true
var back_view := -1
var theme_id := "grove"
var slot_labels: Dictionary = {}
var bench_badges: Dictionary = {}
var styled_dialog_generation := -1
var battle: Control
var world: Node3D
var viewport: SubViewport
var field: Control
var stats: Label
var hint: Label
var end_button: Button
var stadium_button: Button
var clock := 0.0
var last_frame: Dictionary = {}
var enabled := true
var down_slot := ""
var prize_buttons: Array[Button] = []
var hover_detail: Label
var down_signature := ""
var ability_observed: Dictionary = {}
var board_hud: Control
var secondary_buttons: Array[Button] = []
var zone_buttons: Dictionary = {}
var settings_button: Button
var log_button: Button
var motion: Control
var hover_preview: PanelContainer
var hover_art: TextureRect
var hover_caption: Label
var hover_elapsed := 0.0
var last_hover := ""
var card_hud: Control
var hand_dock: Control
var hand_fan: Node
var search_presentation: Node
var prize_notice: PanelContainer
var prize_notice_title: Label
var prize_ui_signature := ""
var last_layout_key: Array = []
var public_frame_dirty := true
var last_ui_key: Array = []
var layout_revision := 0

func setup(scene: Control) -> void:
	battle = scene
	platform_metrics = Platform.metrics(battle.get_viewport_rect().size,GameManager.ui_runtime_profile)
	quality_high = not platform_metrics.low and ThemeScript.option("quality_high",true)
	_sync_card_backs()
	theme_id = preload("res://scripts/ui/battle/BattlePresentation.gd").selected_theme()
	name = "Arena3DPresenter"
	z_index = 2
	field = battle.get_node("MainArea/CenterField/FieldArea")
	field.modulate.a = 0
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.name = "ArenaBackdrop"
	backdrop.color = Color("0c1720")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	view_texture = TextureRect.new()
	view_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(view_texture)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Platform.msaa(quality_high)
	add_child(viewport)
	world = WorldScript.new()
	# Quality must be decided before _ready loads geometry, skies and particles.
	world.configure_quality(not quality_high)
	viewport.add_child(world)
	if world.theme_id != theme_id:
		world.set_theme(theme_id)
	world.configure_quality(not quality_high)
	view_texture.texture = viewport.get_texture()
	board_hud = preload("res://scenes/arena3d/ArenaBoardHud.gd").new()
	board_hud.world = world
	board_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board_hud)
	card_hud = preload("res://scenes/arena3d/ArenaCardHud.gd").new()
	card_hud.world = world
	card_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(card_hud)
	var hand_area: Control = battle.get_node("MainArea/CenterField/HandArea")
	hand_dock = preload("res://scenes/arena3d/ArenaHandDock.gd").new()
	hand_area.add_child(hand_dock)
	hand_area.move_child(hand_dock,0)
	hand_fan = preload("res://scenes/arena3d/ArenaHandFan.gd").new()
	hand_fan.presenter = self
	hand_fan.battle = battle
	add_child(hand_fan)
	motion = preload("res://scenes/arena3d/ArenaMotionDirector.gd").new()
	motion.world = world
	add_child(motion)
	world.supporter_canvas = motion
	motion.hand_transfer = preload("res://scenes/arena3d/ArenaHandChoreography.gd").new()
	motion.hand_transfer.presenter = self
	motion.hand_transfer.battle = battle
	battle.add_child(motion.hand_transfer)
	motion.hand_transfer.busy_changed.connect(func(busy: bool):
		if busy or not motion.is_busy(): motion.busy_changed.emit(busy)
	)
	search_presentation = preload("res://scenes/arena3d/ArenaSearchPresentation.gd").new()
	search_presentation.presenter = self
	search_presentation.battle = battle
	add_child(search_presentation)
	motion.busy_changed.connect(func(busy: bool):
		battle.call("_set_battle_visual_input_blocked",busy)
		if not busy: battle.call_deferred("_on_battle_visual_sequence_idle")
	)
	battle.get_node("MainArea/LogPanel").hide()
	preload("res://scenes/arena3d/ArenaLayout.gd").apply(battle,true)
	stats = Label.new()
	stats.position = Vector2(22,18)
	stats.add_theme_font_size_override("font_size",19)
	stats.add_theme_color_override("font_color",Color("b4d6e7"))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("91b7cc"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_backing := StyleBoxFlat.new()
	hint_backing.bg_color = Color(.025,.04,.035,.85)
	hint_backing.content_margin_left = 8
	hint_backing.content_margin_right = 8
	hint_backing.content_margin_top = 2
	hint_backing.content_margin_bottom = 2
	hint_backing.set_corner_radius_all(4)
	hint.add_theme_stylebox_override("normal",hint_backing)
	add_child(hint)
	prize_notice = PanelContainer.new()
	prize_notice.name = "PrizeNotice"
	prize_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var notice_style := ThemeScript.panel(theme_id,true)
	notice_style.bg_color = Color("18231f",.96)
	notice_style.border_color = Color("f3d68c")
	prize_notice.add_theme_stylebox_override("panel",notice_style)
	var notice_content := VBoxContainer.new()
	notice_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prize_notice.add_child(notice_content)
	prize_notice_title = Label.new()
	prize_notice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize_notice_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prize_notice_title.add_theme_font_size_override("font_size",24)
	prize_notice_title.add_theme_color_override("font_color",Color("ffe4a0"))
	notice_content.add_child(prize_notice_title)
	var notice_help := Label.new()
	notice_help.text = "点击发光的奖赏卡，继续对战"
	notice_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_help.add_theme_font_size_override("font_size",16)
	notice_content.add_child(notice_help)
	add_child(prize_notice)
	prize_notice.hide()
	hover_detail = Label.new()
	hover_detail.position = Vector2(22,385)
	hover_detail.add_theme_font_size_override("font_size",16)
	hover_detail.modulate = Color("bddbe8")
	hover_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_detail.visible = false
	add_child(hover_detail)
	_make_hover_preview()
	_make_compact_menu()
	status_bar = preload("res://scenes/arena3d/ArenaStatusBar.gd").new()
	add_child(status_bar)
	status_bar.setup(self)
	end_button = _button("结束回合",func(): battle.call("_on_end_turn"))
	stadium_button = _button("场地",func(): battle.call("_on_stadium_action_pressed"))
	var effects := _button("动态特效：开" if world.motion_enabled else "动态特效：关",func():
		world.motion_enabled = not world.motion_enabled
		ThemeScript.save_option("motion",world.motion_enabled)
	)
	effects.position = Vector2(22,100)
	effects.pressed.connect(func(): effects.text = "动态特效：开" if world.motion_enabled else "动态特效：关")
	secondary_buttons.append(effects)
	effects.hide()
	var fast := _button("动画速度：快速" if motion.fast_enabled else "动画速度：标准",func():
		motion.fast_enabled = not motion.fast_enabled
		ThemeScript.save_option("fast",motion.fast_enabled)
	)
	fast.pressed.connect(func(): fast.text = "动画速度：快速" if motion.fast_enabled else "动画速度：标准")
	secondary_buttons.append(fast)
	fast.hide()
	var audio_button := _button("音效：开" if world.sound_enabled else "音效：关",func():
		world.sound_enabled = not world.sound_enabled
		ThemeScript.save_option("sound",world.sound_enabled)
	)
	audio_button.position = Vector2(22,260)
	audio_button.pressed.connect(func(): audio_button.text = "音效：开" if world.sound_enabled else "音效：关")
	secondary_buttons.append(audio_button)
	audio_button.hide()
	settings_button = _button("表现设置",func():
		for button in secondary_buttons: button.visible = not button.visible
	)
	log_button = _button("对战记录",func():
		if platform_metrics.compact:
			_open_compact_log()
			return
		var panel := battle.get_node("MainArea/LogPanel") as Control
		battle.set_meta("arena_log_open",not bool(battle.get_meta("arena_log_open",false)))
		panel.visible = bool(battle.get_meta("arena_log_open"))
	)
	for side in [false,true]:
		var enemy: bool = side
		var discard := _button("对手弃牌" if enemy else "我的弃牌",func():
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			battle.call("_on_discard_open_control_input",click,"opponent" if enemy else "self","对手弃牌区" if enemy else "我的弃牌区")
		)
		discard.position = Vector2(22,220 if enemy else 180)
		zone_buttons["opp_discard" if enemy else "my_discard"] = discard
	for button: Button in zone_buttons.values():
		button.text = ""
		button.custom_minimum_size = Vector2.ZERO
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1,1,1,.04)
		hover.border_color = Color("c7ddeb")
		hover.set_border_width_all(2)
		hover.set_corner_radius_all(5)
		button.add_theme_stylebox_override("hover",hover)
	for i in range(6):
		var index: int = i
		var prize := _button("领取奖赏 %d" % (i+1),func():
			var owner_index: int = int(battle.get("_pending_prize_player_index"))
			if owner_index == int(battle.get("_view_player")) and not battle.call("_is_ai_prize_prompt"):
				battle.call("_try_take_prize_from_slot",owner_index,index)
		)
		# The existing desktop prize owner commits on press, then drains its
		# release. Committing on release would leave that shield armed too late.
		prize.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		prize.icon = Backs.for_side(true)
		prize.expand_icon = true
		prize.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prize.text = ""
		prize.visible = false
		prize.position = Vector2(size.x-175,100+i*37)
		prize_buttons.append(prize)
	gui_input.connect(_on_input)
	_apply_theme()
	_refresh()

func _apply_theme() -> void:
	var colors := ThemeScript.palette(theme_id)
	board_hud.theme_id = theme_id
	card_hud.theme_id = theme_id
	hand_dock.theme_id = theme_id
	board_hud.queue_redraw()
	stats.add_theme_color_override("font_color", Color(colors.ink))
	hint.add_theme_color_override("font_color", Color(colors.muted))
	for child in get_children():
		if child is Button and child not in zone_buttons.values():
			child.add_theme_stylebox_override("normal", ThemeScript.panel(theme_id))
			child.add_theme_stylebox_override("hover", ThemeScript.panel(theme_id, true))
			child.add_theme_color_override("font_color", Color(colors.ink))
	for path in ["TopBar", "MainArea/LogPanel"]:
		var control := battle.get_node_or_null(path)
		if control is PanelContainer: control.add_theme_stylebox_override("panel", ThemeScript.panel(theme_id))
	var hand_style := StyleBoxFlat.new()
	hand_style.bg_color = Color.TRANSPARENT
	hand_style.content_margin_top = 2
	hand_style.content_margin_bottom = 2
	hand_style.content_margin_left = 18
	hand_style.content_margin_right = 18
	battle.get_node("MainArea/CenterField/HandArea").add_theme_stylebox_override("panel",hand_style)
	for key in ["_dialog_box", "_detail_box", "_field_interaction_panel"]:
		var control = battle.get(key)
		if control is PanelContainer:
			control.add_theme_stylebox_override("panel", ThemeScript.panel(theme_id))
			_style_buttons(control)
	for path in ["DialogOverlay/DialogCenter/DialogBox", "DetailOverlay/DetailCenter/DetailBox"]:
		var control := battle.get_node_or_null(path)
		if control is PanelContainer:
			control.add_theme_stylebox_override("panel",ThemeScript.panel(theme_id))
			_style_buttons(control)
	_style_buttons(battle.get_node("TopBar"))
	var primary := ThemeScript.panel(theme_id,true)
	primary.bg_color = Color(colors.accent)
	end_button.add_theme_stylebox_override("normal",primary)
	end_button.add_theme_color_override("font_color",Color("182321"))
	end_button.add_theme_font_size_override("font_size",18)
	var log_list := battle.get_node("MainArea/LogPanel/LogPanelVBox/LogList")
	log_list.add_theme_stylebox_override("normal", ThemeScript.panel(theme_id))
	log_list.add_theme_color_override("default_color", Color(colors.ink))

func _style_buttons(node: Node) -> void:
	if node is Button:
		node.add_theme_stylebox_override("normal", ThemeScript.panel(theme_id))
		node.add_theme_stylebox_override("hover", ThemeScript.panel(theme_id,true))
		node.add_theme_color_override("font_color", Color(ThemeScript.palette(theme_id).ink))
	for child in node.get_children(): _style_buttons(child)

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(118,34)
	button.add_theme_font_size_override("font_size",14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035,.08,.13,.92)
	style.border_color = Color("345f79")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate()
	hover.bg_color = Color("185571")
	button.add_theme_stylebox_override("hover",hover)
	button.pressed.connect(action)
	add_child(button)
	ui_buttons.append(button)
	return button

func _make_compact_menu() -> void:
	menu_button = MenuButton.new()
	menu_button.text = "菜单"
	add_child(menu_button)
	ui_buttons.append(menu_button)
	menu_button.about_to_popup.connect(func():
		var popup := menu_button.get_popup()
		popup.clear()
		if platform_metrics.portrait:
			for button: Button in [log_button,stadium_button]+secondary_buttons:
				popup.add_item(button.text)
				popup.set_item_metadata(popup.item_count-1,button)
				popup.set_item_disabled(popup.item_count-1,button.disabled)
			popup.add_separator()
		for name: String in ["BtnOpponentHand","BtnAiAdvice","BtnBattleDiscussAI","BtnZeusHelp","BtnReplayPrevTurn","BtnReplayPlayPause","BtnReplayNextTurn","BtnReplayContinue","BtnReplayBackToList","BtnBack"]:
			var button := battle.find_child(name,true,false) as Button
			if button == null or not button.visible: continue
			popup.add_item(button.text)
			var index := popup.item_count-1
			popup.set_item_metadata(index,button)
			popup.set_item_disabled(index,button.disabled)
		var speed: OptionButton = battle.get("_opt_replay_speed")
		if speed != null and speed.visible:
			for i in range(speed.item_count):
				popup.add_item("回放速度 · "+speed.get_item_text(i))
				popup.set_item_metadata(popup.item_count-1,{"speed":i})
		popup.add_theme_font_size_override("font_size",platform_metrics.font)
		popup.add_theme_constant_override("v_separation",roundi(24*platform_metrics.scale))
	)
	menu_button.get_popup().id_pressed.connect(func(id: int):
		var popup := menu_button.get_popup()
		var metadata: Variant = popup.get_item_metadata(popup.get_item_index(id))
		if metadata is Dictionary:
			var speed: OptionButton = battle.get("_opt_replay_speed")
			speed.select(metadata.speed)
			speed.item_selected.emit(metadata.speed)
			return
		var button := metadata as Button
		if is_instance_valid(button) and not button.disabled: button.pressed.emit()
	)
	compact_log = GameModal.new()
	compact_log.title = "对战记录"
	add_child(compact_log)
	compact_log_text = RichTextLabel.new()
	compact_log_text.bbcode_enabled = true
	compact_log_text.scroll_following = true
	compact_log.add_content(compact_log_text)
	var quality := _button("画质：精细" if quality_high else "画质：省电",func():
		if platform_metrics.low: return
		quality_high = not quality_high
		world.configure_quality(not quality_high)
		ThemeScript.save_option("quality_high",quality_high)
	)
	quality.pressed.connect(func(): quality.text = "画质：精细" if quality_high else "画质：省电")
	quality.hide()
	quality.disabled = platform_metrics.low
	if platform_metrics.low: quality.text = "画质：流畅"
	secondary_buttons.append(quality)

func _open_compact_log() -> void:
	var log_list: RichTextLabel = battle.get("_log_list")
	compact_log_text.text = log_list.text
	compact_log_text.custom_minimum_size = battle.get_viewport_rect().size*Vector2(.8,.65)
	compact_log_text.add_theme_font_size_override("normal_font_size",platform_metrics.font)
	compact_log.popup_centered_clamped(Vector2i(battle.get_viewport_rect().size*.85),.9)

func _has_live_board_choices() -> bool:
	return motion.allows_live_actions_during_ability() and (
		battle.call("_can_view_player_start_turn_action")
		or battle.call("_should_present_field_interaction")
	)

func _board_input_blocked_by_motion() -> bool:
	# Only committed Pokemon abilities yield to fresh human choices. Supporter,
	# attack, draw and reward sequences keep their existing presentation gates.
	return motion.is_busy() and not _has_live_board_choices()

func touch_target(global_point: Vector2) -> Dictionary:
	if battle.call("_is_board_modal_overlay_visible") or menu_button.get_popup().visible or compact_log.visible: return {}
	var panel: Control = battle.get("_field_interaction_panel")
	if is_instance_valid(panel) and panel.is_visible_in_tree() and panel.get_global_rect().has_point(global_point): return {}
	if not get_global_rect().has_point(global_point): return {}
	var buttons := ui_buttons.duplicate()
	buttons.reverse()
	buttons.sort_custom(func(a: Button,b: Button): return a.z_index > b.z_index)
	for button: Button in buttons:
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled: continue
		if not button.get_global_rect().has_point(global_point): continue
		var prize := prize_buttons.find(button)
		return {"kind":"prize","index":prize} if prize >= 0 else {"kind":"button","button":button}
	if _board_input_blocked_by_motion(): return {}
	var local := get_global_transform().affine_inverse()*global_point
	if not board_rect.has_point(local): return {}
	var slot: String = world.hit_slot(local)
	return {"kind":"slot","id":slot} if slot != "" else {"kind":"board"}

func activate_touch_target(target: Dictionary, inspect: bool) -> void:
	if battle.call("_is_board_modal_overlay_visible"): return
	if target.get("kind","") == "button":
		var button: Button = target.get("button")
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled: return
		if button is MenuButton: button.show_popup()
		else: button.pressed.emit()
		return
	if target.get("kind","") != "slot": return
	var id: String = target.id
	if id == "stadium":
		var gsm = battle.get("_gsm")
		var card: CardInstance = gsm.game_state.stadium_card
		if card != null: battle.call("_on_stadium_card_right_clicked" if inspect else "_on_stadium_card_left_clicked",card,card.card_data)
	elif inspect or (id.begins_with("opp_") and not battle.call("_is_field_interaction_active") and battle.get("_selected_hand_card") == null and str(battle.get("_pending_choice")) == ""):
		var data: Dictionary = last_frame.get("slots",{}).get(id,{})
		if not data.get("concealed",true) and not data.get("empty",true): battle.call("_show_slot_card_detail",id)
	else: battle.call("_handle_slot_left_click",id)

func _process(delta: float) -> void:
	if not is_instance_valid(battle) or not is_instance_valid(field): return
	status_bar.sync(last_frame)
	# Pointer timing remains display-rate. Layout/style allocation only runs when
	# geometry or the public UI refresh changes, instead of rebuilding at 60 Hz.
	if battle.get("_arena_touch") != null: battle.get("_arena_touch").tick(delta)
	clock += delta
	var drag: RefCounted = battle.get("_arena_hand_drag")
	var ui_key := [battle.get("_dialog_generation"),battle.get("_arena_input_generation"),
		battle.get("_pending_choice"),battle.get("_view_player"),battle.get("_pending_prize_remaining"),
		battle.get("_pending_prize_animating"),battle.get("_selected_hand_card"),
		motion.is_busy(),motion.hold > 0 and last_frame != motion.shown,drag.active if drag != null else false,
		battle.call("_is_board_modal_overlay_visible"),battle.call("_can_view_player_start_turn_action"),
		battle.call("_is_field_interaction_active"),battle.get("_hud_end_turn_btn").disabled]
	var refresh_due: bool = public_frame_dirty or ui_key != last_ui_key or (not world.low_quality and clock > .12)
	if refresh_due:
		clock = 0
		_refresh()
		last_ui_key = ui_key
	var layout_key := [battle.get_viewport_rect().size,field.global_position,field.size,
		battle.get_meta("commentary_reserved_height",0.0),GameManager.ui_runtime_profile,
		battle.get_meta("arena_log_open",false),quality_high,world.camera.transform,world.camera.size,viewport.size,
		world.bench_counts.my,world.bench_counts.opp]
	if world.low_quality and layout_key == last_layout_key:
		if not platform_metrics.touch: _update_hover_preview(delta)
		return
	last_layout_key = layout_key
	layout_revision += 1
	preload("res://scenes/arena3d/ArenaLayout.gd").apply(battle)
	position = field.global_position - battle.global_position
	size = field.size
	platform_metrics = Platform.metrics(battle.get_viewport_rect().size,GameManager.ui_runtime_profile)
	board_rect = Rect2(Vector2.ZERO,size)
	menu_button.visible = platform_metrics.compact
	status_bar.visible = platform_metrics.compact
	hint.visible = not platform_metrics.compact
	var board_layout_changed: bool = world.compact_board != platform_metrics.compact or world.portrait_board != platform_metrics.portrait
	world.compact_board = platform_metrics.compact
	world.portrait_board = platform_metrics.portrait
	world.hud_scale = platform_metrics.scale
	if board_layout_changed and not motion.shown.is_empty(): world.display(motion.shown)
	hand_dock.touch_mode = platform_metrics.touch
	hand_dock.ui_scale = platform_metrics.scale
	if platform_metrics.touch:
		hover_preview.hide()
	else:
		_update_hover_preview(delta)
	_update_slot_labels()
	field.modulate.a = 0
	var right: float = world.project(Vector3(world.side_x-.6,.3,0)).x
	stats.position = Vector2(30,16)
	end_button.position = Vector2(size.x-198,size.y-65)
	end_button.size = Vector2(168,44)
	settings_button.position = Vector2(size.x-180,16)
	log_button.position = Vector2(size.x-180,60)
	for i in range(secondary_buttons.size()): secondary_buttons[i].position = Vector2(size.x-342,60+i*43)
	var old_stadium: Control = battle.get("_stadium_card_overlay")
	if old_stadium != null: old_stadium.modulate.a = 0
	stadium_button.position = world.project(Vector3(-5.4,.3,0)) - Vector2(60,16)
	if last_frame.get("stadium", "") != "":
		stadium_button.position = world.project(Vector3(-4.2,.3,1.2)) - Vector2(60,0)
	stadium_button.custom_minimum_size.x = 110
	stadium_button.size.x = 110
	for side in ["my","opp"]:
		var rect: Rect2 = world.side_zones.screen_rect(side,"discard")
		var button: Button = zone_buttons[side+"_discard"]
		button.position = rect.position
		button.size = rect.size+Vector2(0,31)
	for i in range(prize_buttons.size()):
		var rect: Rect2 = board_hud.prize_rect(i,true)
		prize_buttons[i].position = rect.position
		prize_buttons[i].custom_minimum_size = Vector2.ZERO
		prize_buttons[i].size = rect.size
		prize_buttons[i].text = ""
		prize_buttons[i].tooltip_text = "领取奖赏 %d" % (i+1)
		prize_buttons[i].add_theme_font_size_override("font_size",13)
	hint.position = Vector2(32,size.y-28)
	if platform_metrics.compact:
		preload("res://scenes/arena3d/ArenaCompactHud.gd").apply(self)
	else:
		stats.show()
		settings_button.show()
		log_button.show()
		for button: Button in zone_buttons.values():
			button.text = ""
			button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		settings_button.text = "表现设置"
		log_button.text = "对战记录"
		for button: Button in [settings_button,log_button]+secondary_buttons:
			button.custom_minimum_size = Vector2(118,34)
			button.size = button.custom_minimum_size
			button.add_theme_font_size_override("font_size",14)
		stats.add_theme_font_size_override("font_size",19)
		stadium_button.add_theme_font_size_override("font_size",14)
		end_button.add_theme_font_size_override("font_size",18)
	# Open six stable card slots on every platform; idle prizes stay stacked.
	preload("res://scenes/arena3d/ArenaCompactHud.gd")._place_prize_picker(self)
	view_texture.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view_texture.position = board_rect.position
	view_texture.size = board_rect.size
	world.screen_size = board_rect.size
	world.screen_origin = board_rect.position
	viewport.msaa_3d = Platform.msaa(quality_high)
	motion.hand_transfer.configure_quality(quality_high)
	var target_size := Platform.render_size(board_rect.size,2560 if quality_high else Platform.LOW_RENDER_EDGE)
	if viewport.size != target_size:
		viewport.size = target_size
		world.invalidate_render()

func _sync_card_backs() -> void:
	var view := int(battle.get("_view_player"))
	if view == back_view: return
	back_view = view
	Backs.bind_view(battle,view)
	var gsm = battle.get("_gsm")
	if gsm != null and gsm.game_state != null:
		battle.get("_battle_display_controller").update_side_previews(battle,gsm.game_state.players[1-view],gsm.game_state.players[view])

func _record_prize_ui_if_changed(gsm: RefCounted, ready: bool) -> void:
	# Diagnose reward stalls without recording a single hidden card identity.
	var engine_count := int(gsm.get("_pending_prize_remaining"))
	if engine_count <= 0 and prize_ui_signature.is_empty(): return
	var state := {
		"engine_player":int(gsm.get("_pending_prize_player_index")),
		"engine_count":engine_count,
		"ui_choice":str(battle.get("_pending_choice")),
		"ui_player":int(battle.get("_pending_prize_player_index")),
		"ui_count":int(battle.get("_pending_prize_remaining")),
		"motion_busy":motion.is_busy(),
		"modal_visible":bool(battle.call("_is_board_modal_overlay_visible")),
		"prize_buttons_ready":ready,
		"notice_visible":prize_notice.visible,
	}
	var signature := JSON.stringify(state)
	if signature == prize_ui_signature: return
	prize_ui_signature = signature if engine_count > 0 else ""
	battle.call("_record_battle_event",{"event_type":"arena_prize_ui","reward_ui":state})

func _refresh() -> void:
	var gsm = battle.get("_gsm")
	if gsm == null or gsm.game_state == null: return
	_sync_card_backs()
	if styled_dialog_generation != int(battle.get("_dialog_generation")):
		styled_dialog_generation = int(battle.get("_dialog_generation"))
		style_dialog()
	if public_frame_dirty or not world.low_quality or last_frame.is_empty() or int(last_frame.view) != int(battle.get("_view_player")):
		last_frame = FrameScript.capture(gsm.game_state,int(battle.get("_view_player")),battle)
	public_frame_dirty = false
	# Input and target art must describe the same committed state, even while
	# the independent Pokemon ability performance is still playing.
	board_hud.frame = motion.present(last_frame, not _has_live_board_choices())
	board_hud.queue_redraw()
	var ready := false
	for i in range(prize_buttons.size()):
		var pi: int = int(battle.get("_pending_prize_player_index"))
		prize_buttons[i].visible = battle.get("_pending_choice") == "take_prize" and pi == int(last_frame.view) and not battle.call("_is_ai_prize_prompt") and not battle.get("_pending_prize_animating") and not motion.is_busy()
		if prize_buttons[i].visible:
			prize_buttons[i].disabled = gsm.game_state.players[pi].get_prize_at_slot(i) == null
			ready = ready or not prize_buttons[i].disabled
			var style := StyleBoxFlat.new()
			style.bg_color = Color("17392c")
			style.border_color = Color("ffe3a0")
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			prize_buttons[i].add_theme_stylebox_override("normal",style)
			prize_buttons[i].add_theme_color_override("font_color",Color("fff2c2"))
			prize_buttons[i].add_theme_constant_override("outline_size",5)
			prize_buttons[i].add_theme_color_override("font_outline_color",Color("1d190e"))
	board_hud.prize_ready = ready
	board_hud.prize_remaining = int(battle.get("_pending_prize_remaining"))
	prize_notice.visible = ready and not battle.call("_is_board_modal_overlay_visible")
	prize_notice_title.text = "← 请领取 %d 张奖赏" % board_hud.prize_remaining
	_record_prize_ui_if_changed(gsm,ready)
	world.dynamics.reward_ready = ready
	hand_dock.count = int(last_frame.players[last_frame.view].hand_count)
	hand_dock.motion_enabled = world.motion_enabled and quality_high
	for card in battle.get("_hand_container").get_children():
		if card is BattleCardView:
			var foil: bool = world.motion_enabled and quality_high
			if not card.has_meta("arena_v5_foil") or bool(card.get_meta("arena_v5_foil")) != foil:
				card.set_card_foil_effect_enabled(foil,.28)
				card.set_meta("arena_v5_foil",foil)
	world.mark_targets(battle.call("_should_present_field_interaction"),battle.get("_field_interaction_slot_index_by_id"),battle.call("_field_interaction_selected_slot_ids"))
	# Reuse the existing read-only legality projection for hand targeting.
	var drag: RefCounted = battle.get("_arena_hand_drag")
	var selected: CardInstance = drag.card if drag != null and drag.active else battle.get("_selected_hand_card")
	if selected != null and not battle.call("_is_field_interaction_active"):
		var intent: Dictionary = preload("res://scripts/ui/battle/intent/BattleActionIntentModel.gd").build(gsm,int(last_frame.view),selected)
		var eligible := {}
		for id in intent.target_slot_ids: eligible[id] = true
		world.mark_targets(true,eligible,[])
	var mine: Dictionary = last_frame.players[last_frame.view]
	var opp: Dictionary = last_frame.players[1-last_frame.view]
	var displayed: Dictionary = board_hud.frame
	if not platform_metrics.compact:
		stats.text = ("你的回合" if displayed.current == displayed.view else "对手的回合") + "  /  第 %02d 回合" % displayed.turn
	for side in ["my","opp"]:
		var player: Dictionary = mine if side == "my" else opp
		var button: Button = zone_buttons[side+"_discard"]
		button.tooltip_text = "%s弃牌区 · %d 张\n点击查看全部" % ["我的" if side == "my" else "对手",player.get("discard_count",0)]
	var original: Button = battle.get("_hud_end_turn_btn")
	end_button.disabled = original.disabled or not battle.call("_can_view_player_start_turn_action") or battle.call("_is_field_interaction_active")
	end_button.text = original.text + "  →" if not original.disabled and not platform_metrics.get("compact",false) else original.text
	stadium_button.text = "场地 · " + (last_frame.stadium if last_frame.stadium != "" else "暂无场地")
	stadium_button.visible = last_frame.get("stadium_card",{}).is_empty() and world.supporter_vfx.active.is_empty()
	hint.text = "点击 / 拖动出牌  ·  悬停阅读  ·  右键查看详情"
	if battle.get("_selected_hand_card") != null:
		hint.text = "已选择手牌  /  点击目标宝可梦或空备战位"
	elif battle.call("_should_present_field_interaction"):
		hint.text = "请选择场上的目标宝可梦"
	if battle.get("_pending_choice") == "take_prize":
		hint.text = "对手正在领取奖赏卡…" if battle.call("_is_ai_prize_prompt") else ("击倒结算中…" if motion.is_busy() else "请选择左侧奖赏卡，加入手牌")
	elif battle.get("_pending_choice") == "send_out":
		hint.text = "请选择一只备战宝可梦出战"
	if platform_metrics.compact:
		preload("res://scenes/arena3d/ArenaCompactHud.gd").update_state(self)

func _update_slot_labels() -> void:
	# Statistics now share one card-anchored HUD; preserve the test entry point.
	if not world.low_quality or world.render_dirty: card_hud.queue_redraw()
func _input_signature(frame: Dictionary) -> String:
	return JSON.stringify([frame, battle.get("_arena_input_generation"), battle.get("_modal_input_generation"), battle.get("_dialog_generation"), battle.get("_prize_prompt_generation"), battle.get("_pending_choice")])

func _on_input(event: InputEvent) -> void:
	if battle.call("_is_board_modal_overlay_visible"): return
	if event is InputEventMouse and not board_rect.has_point(event.position): return
	if event is InputEventMouseMotion:
		world.hover_id = world.hit_slot(event.position)
		var data: Dictionary = last_frame.get("slots",{}).get(world.hover_id,{})
		hover_detail.text = ""
		if not data.get("empty",true) and not data.get("concealed",true):
			hover_detail.text = "%s\nHP %d / %d\n能量 %d  ·  进化 %d%s" % [data.name,data.hp,data.max_hp,data.energy.size(),data.evolution,"\n已附着道具" if data.tool else ""]
			if not data.status.is_empty():
				var status_names := {"poisoned":"中毒","burned":"灼伤","asleep":"睡眠","paralyzed":"麻痹","confused":"混乱"}
				var names: Array[String] = []
				for status: String in data.status: names.append(status_names.get(status,status))
				hover_detail.text += "\n状态：" + "、".join(names)
	if not event is InputEventMouseButton: return
	if _board_input_blocked_by_motion(): return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		world.camera_distance = clampf(world.camera_distance + (-.04 if event.button_index == MOUSE_BUTTON_WHEEL_UP else .04),.82,1.2)
		accept_event()
		return
	var id: String = world.hit_slot(event.position)
	if event.pressed:
		down_slot = id
		down_signature = _input_signature(last_frame)
		return
	if id == "" or id != down_slot: return
	down_slot = ""
	var gsm = battle.get("_gsm")
	var current_frame: Dictionary = FrameScript.capture(gsm.game_state,int(battle.get("_view_player")),battle)
	if _input_signature(current_frame) != down_signature: return
	if id == "stadium":
		# Preserve the existing read-only detail route during required choices.
		# A right click must not create a new gameplay action window.
		var stadium: CardInstance = gsm.game_state.stadium_card
		if stadium != null:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				battle.call("_on_stadium_card_right_clicked",stadium,stadium.card_data)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				battle.call("_on_stadium_card_left_clicked",stadium,stadium.card_data)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		activate_touch_target({"kind":"slot","id":id},false)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# A concealed face cannot be inspected by the new display path.
		var card: Dictionary = last_frame.get("slots",{}).get(id,{})
		if not card.get("concealed",true): battle.call("_show_slot_card_detail",id)
	accept_event()

func _input(event: InputEvent) -> void:
	if preload("res://scripts/ui/GameModalDialog.gd").active_for(self) != null:
		return
	# Hover is observation, not an action. Track it before inherited hand/scroll
	# handlers consume motion, and keep game choices on the GUI input route.
	if not event is InputEventMouseMotion or world == null: return
	var local: Vector2 = get_global_transform().affine_inverse()*event.position
	world.hover_id = world.hit_slot(local) if Rect2(Vector2.ZERO,size).has_point(local) and not battle.call("_is_board_modal_overlay_visible") else ""

func _on_action(action: GameAction) -> void:
	public_frame_dirty = true
	var mine: bool = action.player_index == int(battle.get("_view_player"))
	if action.action_type in [GameAction.ActionType.ATTACK,GameAction.ActionType.USE_ABILITY,GameAction.ActionType.PLAY_TRAINER]:
		motion.reward_chain = [0,0]
	var ability_before: Dictionary=ability_observed if not ability_observed.is_empty() else motion.shown
	ability_observed=FrameScript.capture(battle.get("_gsm").game_state,int(battle.get("_view_player")))
	if action.action_type==GameAction.ActionType.USE_ABILITY:
		var embrace: Dictionary=preload("res://scenes/arena3d/ArenaPokemonAbilityCue.gd").capture(action,battle.get("_gsm").game_state,int(battle.get("_view_player")),ability_before,ability_observed)
		if motion.start_psychic_embrace(embrace):return
	if action.action_type == GameAction.ActionType.PLAY_TRAINER:
		var cue := preload("res://scenes/arena3d/ArenaSupporterCue.gd").capture(action,battle.get("_gsm").game_state,int(battle.get("_view_player")),motion.shown)
		if motion.start_supporter(cue): return
	if mine and action.action_type in [GameAction.ActionType.PLAY_POKEMON,GameAction.ActionType.EVOLVE,GameAction.ActionType.PLAY_STADIUM] and hand_fan.last_card_id != "":
		var local: Vector2 = get_global_transform().affine_inverse()*hand_fan.last_point
		var origin: Vector3 = world.ray_origin(local)
		var direction: Vector3 = world.ray_normal(local)
		motion.arrival_origins[hand_fan.last_card_id] = Plane(Vector3.UP,1).intersects_ray(origin,direction)
	if action.action_type == GameAction.ActionType.PLAY_TRAINER and world.motion_enabled and not motion.hand_transfer.is_busy():
		world.fly_card(Backs.for_side(mine),Vector3(0,1,11 if mine else -11),world.side_zones.location("my" if mine else "opp","discard")+Vector3(0,.6,0),.85,true)
	if action.action_type == GameAction.ActionType.KNOCKOUT:
		motion.knockouts.append({"side":"my" if mine else "opp","name":str(action.data.get("pokemon_name",""))})
		var owner := 1-action.player_index
		var available: int = battle.get("_gsm").game_state.players[owner].prizes.size()
		motion.queue_prize_reward(owner,mini(available,int(action.data.get("prize_count",0))),not mine)
	if action.action_type == GameAction.ActionType.DRAW_CARD: return
	if action.action_type == GameAction.ActionType.TAKE_PRIZE:
		motion.zone_flight(mine,true)
		return
	if action.action_type == GameAction.ActionType.USE_ABILITY and action.data.get("ability_vfx","") == "counter_transfer":
		var signature := preload("res://scenes/arena3d/ArenaSignatureVfx.gd")
		var view: int = int(battle.get("_view_player"))
		var caster := signature.slot_id(action.data.get("caster",{}),view)
		var source := signature.slot_id(action.data.get("source",{}),view)
		var target := signature.slot_id(action.data.get("target",{}),view)
		if motion.start_counter_transfer(last_frame.get("slots",{}).get(caster,{}),caster,source,target,int(action.data.get("counter_count",0)),str(action.data.get("ability_name","转移伤害"))): return
	if action.action_type in [GameAction.ActionType.PLAY_TRAINER,GameAction.ActionType.USE_ABILITY,GameAction.ActionType.RETREAT]:
		if world.motion_enabled and not motion.hand_transfer.is_busy():
			var names := {GameAction.ActionType.PLAY_TRAINER:"使用训练家",GameAction.ActionType.USE_ABILITY:"发动特性",GameAction.ActionType.RETREAT:"撤退 / 换位"}
			motion.banner(names[action.action_type])
	if action.action_type != GameAction.ActionType.ATTACK: return
	# The engine enriches targets immediately after emitting action_logged.
	# Retain the visible pre-hit board, then read committed public targets.
	if world.motion_enabled:
		motion.hold = .35
		# The engine can finish the turn synchronously before the deferred attack
		# starts. Reserve its presentation now so handover/AI cannot cover it.
		motion.busy_time = maxf(motion.busy_time,.35)
		motion.ability_animation_active = false
		motion.busy_changed.emit(true)
	var committed: Dictionary = FrameScript.capture(battle.get("_gsm").game_state,int(battle.get("_view_player")))
	var counters: Array[Dictionary] = preload("res://scenes/arena3d/ArenaSignatureVfx.gd").counter_landings(last_frame,committed,mine)
	call_deferred("_play_committed_attack",action,counters)

func _play_committed_attack(action: GameAction, counters: Array[Dictionary] = []) -> void:
	var mine: bool = action.player_index == int(battle.get("_view_player"))
	var card: Dictionary = last_frame.get("slots",{}).get("my_active" if mine else "opp_active",{})
	var targets: Array[String] = []
	for entry: Variant in action.data.get("targets",[]):
		if not entry is Dictionary: continue
		var side := "my" if int(entry.get("player_index",1-action.player_index)) == int(battle.get("_view_player")) else "opp"
		var kind: String = entry.get("slot_kind","active")
		if kind == "active": targets.append(side+"_active")
		elif kind == "bench": targets.append(side+"_bench_%d" % int(entry.get("slot_index",0)))
	motion.start_attack(mine,card.get("type","C"),str(action.data.get("attack_name","攻击")),targets,int(action.data.get("damage",0)),counters)

func _make_hover_preview() -> void:
	hover_preview = PanelContainer.new()
	hover_preview.name = "ArenaHoverPreview"
	hover_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_preview.z_index = 60
	hover_preview.add_theme_stylebox_override("panel",ThemeScript.panel(theme_id))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_preview.add_child(column)
	hover_art = TextureRect.new()
	hover_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hover_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hover_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hover_art)
	hover_caption = Label.new()
	hover_caption.add_theme_font_size_override("font_size",17)
	hover_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hover_caption)
	add_child(hover_preview)
	hover_preview.hide()

func _update_hover_preview(delta: float) -> void:
	var hand_card: BattleCardView = hand_fan.hovered if hand_fan != null and is_instance_valid(hand_fan.hovered) else null
	if hand_card != null and (not hand_card.is_visible_in_tree() or hand_card.get("_face_down") or hand_card.card_data == null): hand_card = null
	var key: String = "hand:%d" % hand_card.get_instance_id() if hand_card != null else world.hover_id
	if key != last_hover:
		last_hover = key
		hover_elapsed = 0
		hover_preview.hide()
	hover_elapsed += delta
	var data: Dictionary = last_frame.get("stadium_card",{}) if last_hover == "stadium" else last_frame.get("slots",{}).get(last_hover,{})
	var drag: RefCounted = battle.get("_arena_hand_drag")
	if (hand_card == null and (data.get("empty",true) or data.get("concealed",true))) or battle.call("_is_board_modal_overlay_visible") or _board_input_blocked_by_motion() or (drag != null and drag.active):
		hover_preview.hide()
		return
	if hover_elapsed < .24: return
	if hand_card != null:
		hover_art.texture = hand_card.get("_texture_rect").texture
		hover_caption.text = "%s\n手牌 · 右键查看详情" % hand_card.card_data.display_name()
	else:
		var path: String = data.get("image","")
		if not world.texture_cache.has(path): return
		hover_art.texture = world.texture_cache[path]
		hover_caption.text = str(data.name) if last_hover == "stadium" else "%s\n%d / %d HP  ·  附能 %d 张" % [data.name,data.hp,data.max_hp,data.energy.size()]
		if data.get("tool_name","") != "": hover_caption.text += "\n道具："+str(data.tool_name)
	if hover_art.texture == null:
		hover_preview.hide()
		return
	var height: float = minf(390,size.y-105)
	hover_art.custom_minimum_size = Vector2(height*.716,height)
	hover_preview.reset_size()
	var left_side := false
	if hand_card == null:
		var at: Vector2 = world.project(world.positions[last_hover])
		left_side = at.x > size.x*.5
	hover_preview.position = Vector2(20 if left_side else size.x-hover_preview.size.x-20,maxf(66,(size.y-hover_preview.size.y)*.5))
	hover_preview.show()


func style_dialog() -> void:
	# Styling happens before first paint, once per content generation.
	var control := battle.get_node_or_null("DialogOverlay/DialogCenter/DialogBox")
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel",ThemeScript.panel(theme_id))
		_style_buttons(control)
	if search_presentation != null: search_presentation.apply()
