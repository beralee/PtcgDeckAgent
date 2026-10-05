extends RefCounted
## Compact controls share a top status bar and the table's side zones.

static func place(control: Control, at: Vector2, dimensions: Vector2, font: int) -> void:
	control.custom_minimum_size = Vector2.ZERO
	control.position = at
	control.size = dimensions
	control.add_theme_font_size_override("font_size",font)
	if control is Button:
		control.clip_text = true
		control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

static func apply(p: Control) -> void:
	var m: Dictionary = p.platform_metrics
	var s: float = m.scale
	var h: float = m.target
	var gap := 6.0*s
	var header: float = p.status_bar.arrange(m,p.size.x)
	p.board_rect = Rect2(Vector2(0,header),Vector2(p.size.x,maxf(1,p.size.y-header)))
	p.world.screen_origin = p.board_rect.position
	p.world.screen_size = p.board_rect.size
	p.menu_button.hide()
	p.settings_button.hide()
	p.log_button.hide()
	p.stadium_button.hide()
	p.stats.hide()
	p.hint.hide()
	for button: Button in p.secondary_buttons: button.hide()
	# Replay retains its navigation owner; the five-entry live bar stays simple.
	if p.battle.call("_is_review_mode"):
		p.status_bar.hide()
		p.menu_button.show()
		place(p.menu_button,Vector2(gap,gap),Vector2(100*s,h),m.font)
		p.menu_button.text = "回放"
	for side: String in ["my","opp"]:
		var rect: Rect2 = p.world.side_zones.screen_rect(side,"discard")
		var button: Button = p.zone_buttons[side+"_discard"]
		var target_size: Vector2 = rect.size.max(Vector2(h,h))
		place(button,rect.get_center()-target_size*.5,target_size,m.font)
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
	var turn_size := Vector2(maxf(h,p.size.x*.21 if m.portrait else 110*s),h)
	var center: Vector2 = p.world.project(Vector3(6.05,.30,0)) if m.portrait else Vector2(p.size.x-turn_size.x*.5-gap,p.size.y-h*.5-gap)
	if m.portrait:
		var above: Rect2 = p.board_hud.pile_counter_rect("opp","deck")
		var below: Rect2 = p.world.side_zones.screen_rect("my","deck")
		center.y = (above.end.y+below.position.y)*.5
	place(p.end_button,center-turn_size*.5,turn_size,roundi(12*s))
	update_state(p)

static func _place_prize_picker(p: Control) -> void:
	var m: Dictionary = p.platform_metrics
	var s: float = m.scale
	var gap := 6.0*s
	var prize_w := minf(minf(114*s,(p.size.x-gap*6)/3),(p.board_rect.size.y-100*s)*.5/1.43)
	var prize_h := prize_w*1.43
	var grid_size := Vector2(prize_w*3+gap*2,prize_h*2+gap)
	var grid_at: Vector2 = p.board_rect.get_center()-grid_size*.5
	for i in range(6):
		place(p.prize_buttons[i],grid_at+Vector2(i%3*(prize_w+gap),floori(i/3.0)*(prize_h+gap)),Vector2(prize_w,prize_h),m.font)
		p.prize_buttons[i].text = ""
		p.prize_buttons[i].add_theme_constant_override("icon_max_width",roundi(prize_w-8))
		p.prize_buttons[i].z_index = 12
		p.prize_buttons[i].add_theme_stylebox_override("normal",p.ThemeScript.panel(p.theme_id,true))
	place(p.prize_notice,Vector2(gap,grid_at.y-48*s),Vector2(p.size.x-gap*2,40*s),m.font)
	p.prize_notice.z_index = 12
	p.prize_notice_title.text = "请选择 %d 张奖赏卡" % int(p.battle.get("_pending_prize_remaining"))
	p.prize_notice_title.add_theme_font_size_override("font_size",m.font)

static func update_state(p: Control) -> void:
	# Counts and enabled/visible state can change without reallocating styles or
	# moving all controls at each attack's hit, settle and completion boundaries.
	for side: String in ["opp","my"]:
		var count := 0
		if not p.last_frame.is_empty():
			var player: Dictionary = p.last_frame.players[p.last_frame.view if side == "my" else 1-p.last_frame.view]
			count = int(player.get("discard_count",0))
		p.zone_buttons[side+"_discard"].text = ("对手弃牌 " if side == "opp" else "我的弃牌 ") + str(count)
	if not p.last_frame.is_empty():
		var me: Dictionary = p.last_frame.players[p.last_frame.view]
		var opponent: Dictionary = p.last_frame.players[1-p.last_frame.view]
		p.stats.text = "回合 %d · 牌库 %d/%d · 奖赏 %d/%d" % [p.last_frame.turn,me.deck_count,opponent.deck_count,me.prizes,opponent.prizes]
	p.stadium_button.visible = false
	p.stadium_button.text = "场地详情" if p.last_frame.get("stadium","") != "" else "暂无场地"
	p.prize_notice_title.text = "请领取 %d 张奖赏" % int(p.battle.get("_pending_prize_remaining"))
	for button: Button in p.zone_buttons.values(): button.text = ""
	p.end_button.text = "结束回合"
	p.status_bar.sync(p.last_frame)
