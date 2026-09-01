class_name PtcgDAPPublicReplayViewer
extends "res://scenes/battle/BattleSceneRuntime.gd"

signal close_requested()

const PresentationScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayPresentation.gd"
)
const BATTLE_SCENE_VISUAL_SOURCE := "res://scenes/battle/BattleScene.tscn"
const NAVIGATION_POLICY := "timeline_autoplay_manual_step"
const BASE_FRAME_INTERVAL_SECONDS := 0.65
const PLAYBACK_SPEEDS := [0.5, 1.0, 2.0, 4.0]
const DEFAULT_PLAYBACK_SPEED := 2.0
const MAX_VISIBLE_LOG_LINES := 120

const LIVE_ONLY_BUTTONS := [
	"BtnOpponentHand", "BtnAttackVfxPreview", "BtnAiAdvice", "BtnBattleDiscussAI",
	"BtnZeusHelp", "BtnBattleLayout", "BtnBattleMore", "BtnReplayContinue",
	"BtnReplayBackToList", "BtnEndTurn", "HudEndTurnBtn", "BtnStadiumAction",
	"DialogConfirm", "DialogCancel", "HandoverBtn", "CoinOkBtn", "DetailCloseBtn",
	"DiscardCloseBtn", "ReviewCloseBtn", "ReviewRegenerateBtn",
]
const LIVE_ONLY_SURFACES := [
	"DialogOverlay", "HandoverPanel", "CoinFlipOverlay", "CoinOverlay", "DetailOverlay",
	"DiscardOverlay", "ReviewOverlay", "FieldInteractionOverlay", "MatchEndOverlay",
	"InvalidActionOverlay", "DrawRevealOverlay", "AttackVfxOverlay",
]

var _presentation: Variant = null
var _view_seat := 0
var _slot_public_entries: Dictionary = {}
var _prize_views: Dictionary = {0: [], 1: []}
var _deck_previews: Dictionary = {}
var _discard_previews: Dictionary = {}
var _stadium_entry: Dictionary = {}
var _visual_state: Dictionary = {}
var _player_labels := {0: "玩家 1", 1: "玩家 2"}
var _public_bench_sizes := {"my": BENCH_SIZE, "opp": BENCH_SIZE}
var _event_log_entries: Array[String] = []

var _is_playing := false
var _playback_speed := DEFAULT_PLAYBACK_SPEED
var _playback_accumulator := 0.0
var _autoplay_advance_count := 0


func _ready() -> void:
	set_process(false)
	_battle_mode = "review_readonly"
	set_meta("battle_scene_visual_source", BATTLE_SCENE_VISUAL_SOURCE)
	set_meta("battle_ui_mode", "battle_scene_read_only_timeline")
	set_meta("battle_ui_renderer", "BattleSceneRuntime")
	_prepare_read_only_battle_scene()
	_prepare_shared_battle_surfaces()
	_setup_side_previews()
	_install_field_card_views()
	_bind_side_surfaces_to_seats()
	_prepare_shared_stadium_surface()
	_bind_player_controls()
	_setup_speed_control()
	_install_battle_backdrop()
	_apply_battle_surface_styles()
	_style_hud_button(_button("BtnReplayPlayPause"))
	_style_hud_button(find_child("OptReplaySpeed", true, false) as OptionButton)
	_apply_responsive_layout()
	_render()
	set_process(true)


func _exit_tree() -> void:
	_is_playing = false
	_playback_accumulator = 0.0
	_presentation = null
	_event_log_entries.clear()
	_slot_public_entries.clear()
	_visual_state.clear()
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready() and is_inside_tree():
		_apply_responsive_layout()


func _process(delta: float) -> void:
	if _responsive_layout_stabilization_frames_remaining > 0 and is_inside_tree():
		_apply_responsive_layout()
		_responsive_layout_stabilization_frames_remaining -= 1
	advance_playback(delta)


func _input(_event: InputEvent) -> void:
	# Keep normal GUI delivery, but never enter the live battle pointer router,
	# prompt system, or action execution path.
	pass


func load_public_replay(
	contract_owner: Variant,
	manifest: Variant,
	frames: Variant,
	match_envelope: Variant = {}
) -> Dictionary:
	pause()
	_autoplay_advance_count = 0
	_event_log_entries.clear()
	var context_result := _apply_optional_match_context(contract_owner, manifest, match_envelope)
	if not bool(context_result.get("accepted", false)):
		_presentation = null
		_render()
		return context_result
	_view_player = _view_seat
	_bind_side_surfaces_to_seats()
	var opened: Dictionary = PresentationScript.create(contract_owner, manifest, frames)
	if not bool(opened.get("accepted", false)):
		_presentation = null
		_render()
		return opened
	_presentation = opened.get("presentation")
	_build_public_event_log(frames)
	_render()
	return {
		"accepted": true,
		"error_code": "",
		"authoritative": false,
		"battle_scene_visual_source": BATTLE_SCENE_VISUAL_SOURCE,
		"battle_ui_mode": "battle_scene_read_only_timeline",
		"navigation_policy": NAVIGATION_POLICY,
		"playback_speeds": PLAYBACK_SPEEDS.duplicate(),
		"grants": [],
	}


func show_previous() -> Dictionary:
	pause()
	if _presentation != null:
		_presentation.previous()
	_render()
	return current_view()


func show_next() -> Dictionary:
	pause()
	if _presentation != null:
		_presentation.next()
	_render()
	return current_view()


func play() -> Dictionary:
	if _presentation == null:
		return _failure("replay_not_loaded")
	var view := current_view()
	if int(view.get("frame_count", 0)) <= 1:
		return _failure("replay_has_no_playable_timeline")
	if not bool(view.get("can_next", false)):
		_presentation.first()
		_render()
	_is_playing = true
	_playback_accumulator = 0.0
	_update_player_controls()
	return {"accepted": true, "error_code": "", "player": player_snapshot()}


func pause() -> Dictionary:
	_is_playing = false
	_playback_accumulator = 0.0
	_update_player_controls()
	return {"accepted": true, "error_code": "", "player": player_snapshot()}


func toggle_playback() -> Dictionary:
	return pause() if _is_playing else play()


func set_playback_speed(speed: float) -> Dictionary:
	var accepted_speed := -1.0
	for candidate: float in PLAYBACK_SPEEDS:
		if is_equal_approx(candidate, speed):
			accepted_speed = candidate
			break
	if accepted_speed < 0.0:
		return _failure("playback_speed_unsupported")
	_playback_speed = accepted_speed
	_playback_accumulator = 0.0
	_sync_speed_control_selection()
	_update_player_controls()
	return {
		"accepted": true,
		"error_code": "",
		"playback_speed": _playback_speed,
		"authoritative": false,
		"grants": [],
	}


func advance_playback(delta: float) -> Dictionary:
	if not _is_playing or _presentation == null or delta <= 0.0:
		return current_view()
	_playback_accumulator += delta
	var interval := BASE_FRAME_INTERVAL_SECONDS / maxf(_playback_speed, 0.01)
	var changed := false
	var remaining_guard := int(current_view().get("frame_count", 0)) + 1
	while _playback_accumulator + 0.000001 >= interval and remaining_guard > 0:
		var view := current_view()
		if not bool(view.get("can_next", false)):
			break
		_playback_accumulator -= interval
		_presentation.next()
		_autoplay_advance_count += 1
		changed = true
		remaining_guard -= 1
	if changed:
		_render()
	if not bool(current_view().get("can_next", false)):
		_is_playing = false
		_playback_accumulator = 0.0
		_update_player_controls()
	return current_view()


func current_view() -> Dictionary:
	return (
		_presentation.current_view()
		if _presentation != null
		else {
			"accepted": false,
			"error_code": "replay_not_loaded",
			"execution_authority": false,
		}
	)


func presentation_audit() -> Dictionary:
	var audit: Dictionary = (
		_presentation.audit_snapshot()
		if _presentation != null
		else {
			"document_type": "public_replay_presentation_audit_v1",
			"authoritative": false,
			"engine_invocations": 0,
			"ticket_invocations": 0,
			"callback_invocations": 0,
			"grants": [],
		}
	)
	audit["battle_scene_visual_source"] = BATTLE_SCENE_VISUAL_SOURCE
	audit["battle_ui_mode"] = "battle_scene_read_only_timeline"
	audit["navigation_policy"] = NAVIGATION_POLICY
	audit["view_seat"] = _view_seat
	audit["is_playing"] = _is_playing
	audit["playback_speed"] = _playback_speed
	audit["autoplay_advance_count"] = _autoplay_advance_count
	return audit


func player_snapshot() -> Dictionary:
	var view := current_view()
	var previous := _button("BtnReplayPrevTurn")
	var next := _button("BtnReplayNextTurn")
	return {
		"ordinal": int(view.get("ordinal", -1)),
		"frame_count": int(view.get("frame_count", 0)),
		"previous_disabled": previous == null or previous.disabled,
		"next_disabled": next == null or next.disabled,
		"navigation_policy": NAVIGATION_POLICY,
		"is_playing": _is_playing,
		"playback_speed": _playback_speed,
		"speed_options": PLAYBACK_SPEEDS.duplicate(),
		"frame_interval_seconds": BASE_FRAME_INTERVAL_SECONDS,
		"autoplay_advance_count": _autoplay_advance_count,
		"layout_mode": str(get_meta("public_replay_layout_mode", "")),
		"execution_authority": false,
	}


func visual_snapshot() -> Dictionary:
	return _visual_state.duplicate(true)


func _bind_player_controls() -> void:
	var previous := _button("BtnReplayPrevTurn")
	var play_pause := _button("BtnReplayPlayPause")
	var next := _button("BtnReplayNextTurn")
	var back := _button("BtnBack")
	if previous != null and not previous.pressed.is_connected(show_previous):
		previous.pressed.connect(show_previous)
	if play_pause != null and not play_pause.pressed.is_connected(toggle_playback):
		play_pause.pressed.connect(toggle_playback)
	if next != null and not next.pressed.is_connected(show_next):
		next.pressed.connect(show_next)
	if back != null and not back.pressed.is_connected(_on_public_replay_back_pressed):
		back.pressed.connect(_on_public_replay_back_pressed)


func _setup_speed_control() -> void:
	var speed_control := find_child("OptReplaySpeed", true, false) as OptionButton
	if speed_control == null:
		return
	speed_control.clear()
	for speed: float in PLAYBACK_SPEEDS:
		var speed_label := str(speed).trim_suffix(".0")
		speed_control.add_item("%s×" % speed_label)
	if not speed_control.item_selected.is_connected(_on_speed_selected):
		speed_control.item_selected.connect(_on_speed_selected)
	_sync_speed_control_selection()


func _sync_speed_control_selection() -> void:
	var speed_control := find_child("OptReplaySpeed", true, false) as OptionButton
	if speed_control == null:
		return
	for index: int in PLAYBACK_SPEEDS.size():
		if is_equal_approx(float(PLAYBACK_SPEEDS[index]), _playback_speed):
			speed_control.select(index)
			return


func _on_speed_selected(index: int) -> void:
	if index < 0 or index >= PLAYBACK_SPEEDS.size():
		return
	set_playback_speed(float(PLAYBACK_SPEEDS[index]))


func _on_public_replay_back_pressed() -> void:
	pause()
	close_requested.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			show_previous()
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			show_next()
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			toggle_playback()
			get_viewport().set_input_as_handled()


func _prepare_read_only_battle_scene() -> void:
	for node_name: String in LIVE_ONLY_BUTTONS:
		var button := find_child(node_name, true, false) as Button
		if button != null:
			button.visible = false
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
	for node_name: String in LIVE_ONLY_SURFACES:
		var surface := find_child(node_name, true, false) as CanvasItem
		if surface != null:
			surface.visible = false
	var previous := _button("BtnReplayPrevTurn")
	var play_pause := _button("BtnReplayPlayPause")
	var next := _button("BtnReplayNextTurn")
	var speed_control := find_child("OptReplaySpeed", true, false) as OptionButton
	var back := _button("BtnBack")
	if previous != null:
		previous.visible = true
		previous.text = "◀ 上一帧"
		previous.tooltip_text = "查看上一条已验证公开帧"
		previous.set_meta("portrait_compact_text_override", "◀")
	if play_pause != null:
		play_pause.visible = true
		play_pause.text = "▶ 播放"
		play_pause.tooltip_text = "自动播放公开录像；空格键可播放或暂停"
		play_pause.set_meta("portrait_compact_text_override", "播放")
	if next != null:
		next.visible = true
		next.text = "下一帧 ▶"
		next.tooltip_text = "查看下一条已验证公开帧"
		next.set_meta("portrait_compact_text_override", "▶")
	if speed_control != null:
		speed_control.visible = true
		speed_control.tooltip_text = "调整自动播放速度"
		speed_control.set_meta("portrait_compact_text_override", "倍速")
	if back != null:
		back.visible = true
		back.text = "退出录像"
		back.tooltip_text = "返回策略中心；录像不能接管或继续对局"
		back.set_meta("portrait_compact_text_override", "退出")


func _prepare_shared_battle_surfaces() -> void:
	_left_panel.visible = false
	_right_panel.visible = false
	_hand_title.visible = false
	_hand_scroll.visible = true
	_hand_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_opp_hand_bar.visible = true
	_opp_prize_hud_count.visible = true
	_my_prize_hud_count.visible = true
	var hand_vbox := get_node_or_null("MainArea/CenterField/HandArea/HandVBox") as VBoxContainer
	if hand_vbox != null:
		hand_vbox.add_theme_constant_override("separation", 0)
	var stadium_sections := get_node_or_null(
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections"
	) as HBoxContainer
	if stadium_sections != null:
		stadium_sections.move_child(_stadium_center_section, 0)
		stadium_sections.move_child(_lost_zone_section, 1)
	var log_title := find_child("LogTitle", true, false) as Label
	if log_title != null:
		log_title.text = "操作日志 · 公开录像"


func _prepare_shared_stadium_surface() -> void:
	_ensure_battle_stadium_hud_coordinator()
	_battle_stadium_hud_coordinator.call("ensure_stadium_card_view")
	if _stadium_card_view != null:
		_stadium_card_view.set_clickable(false)
		_stadium_card_view.set_secondary_inspect_enabled(false)
		_stadium_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bind_side_surfaces_to_seats() -> void:
	_prize_views.clear()
	_deck_previews.clear()
	_discard_previews.clear()
	_prize_views[_view_seat] = _my_prize_slots
	_prize_views[1 - _view_seat] = _opp_prize_slots
	_deck_previews[_view_seat] = _my_deck_preview
	_deck_previews[1 - _view_seat] = _opp_deck_preview
	_discard_previews[_view_seat] = _my_discard_preview
	_discard_previews[1 - _view_seat] = _opp_discard_preview
	for preview: BattleCardView in [
		_my_deck_preview, _opp_deck_preview, _my_discard_preview, _opp_discard_preview,
	]:
		if preview != null:
			preview.set_clickable(false)
			preview.set_secondary_inspect_enabled(false)
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _render() -> void:
	_update_player_controls()
	if _presentation == null:
		_set_label("LblPhase", "公开 AI 录像 · 尚未加载")
		_set_label("LblTurn", "只读对战场景")
		_clear_visual_state()
		return
	_render_public_frame(_presentation.current_view())


func _update_player_controls() -> void:
	var view := current_view()
	var loaded := _presentation != null
	var previous := _button("BtnReplayPrevTurn")
	var play_pause := _button("BtnReplayPlayPause")
	var next := _button("BtnReplayNextTurn")
	var speed_control := find_child("OptReplaySpeed", true, false) as OptionButton
	if previous != null:
		previous.disabled = not loaded or not bool(view.get("can_previous", false))
	if next != null:
		next.disabled = not loaded or not bool(view.get("can_next", false))
	if play_pause != null:
		play_pause.disabled = not loaded or int(view.get("frame_count", 0)) <= 1
		if _is_playing:
			play_pause.text = "⏸ 暂停"
			play_pause.set_meta("portrait_compact_text_override", "暂停")
		elif loaded and not bool(view.get("can_next", false)):
			play_pause.text = "↻ 重头播放"
			play_pause.set_meta("portrait_compact_text_override", "重头播放")
		else:
			play_pause.text = "▶ 播放"
			play_pause.set_meta("portrait_compact_text_override", "播放")
	if speed_control != null:
		speed_control.disabled = not loaded


func _render_public_frame(view: Dictionary) -> void:
	var acting_seat := int(view.get("acting_seat", -1))
	var acting_text := str(_player_labels.get(acting_seat, "无人"))
	_set_label("LblPhase", "公开录像 · %s · %s" % [
		str(view.get("phase", "unknown")), str(view.get("event_kind", "unknown")),
	])
	_set_label("LblTurn", "第 %d 回合 · 帧 %d / %d · %s行动" % [
		int(view.get("turn_number", 0)), int(view.get("ordinal", 0)) + 1,
		int(view.get("frame_count", 0)), acting_text,
	])
	var counts_by_seat: Dictionary = {}
	for row: Variant in view.get("zone_counts", []):
		if row is Dictionary:
			counts_by_seat[int(row.get("seat", -1))] = row
	var my_counts: Dictionary = counts_by_seat.get(_view_seat, {})
	var opp_counts: Dictionary = counts_by_seat.get(1 - _view_seat, {})
	var my_hand_count := int(my_counts.get("hand_count", 0))
	var opp_hand_count := int(opp_counts.get("hand_count", 0))
	_set_label("OppHandLbl", "%s手牌：%d 张" % [
		_player_labels.get(1 - _view_seat, "对方"), opp_hand_count,
	])
	_render_public_hand(my_hand_count)
	_set_label("OppHudLeftTitle", "%s奖赏" % _player_labels.get(1 - _view_seat, "对方"))
	_set_label("MyHudLeftTitle", "%s奖赏" % _player_labels.get(_view_seat, "我方"))
	_set_label("OppHudLeftValue", "%d" % int(opp_counts.get("prize_count", 0)))
	_set_label("MyHudLeftValue", "%d" % int(my_counts.get("prize_count", 0)))
	_set_label("OppDeckHudValue", "%d" % int(opp_counts.get("deck_count", 0)))
	_set_label("MyDeckHudValue", "%d" % int(my_counts.get("deck_count", 0)))
	_render_face_down_pile(_deck_previews.get(_view_seat), int(my_counts.get("deck_count", 0)))
	_render_face_down_pile(_deck_previews.get(1 - _view_seat), int(opp_counts.get("deck_count", 0)))
	_render_prizes(_view_seat, int(my_counts.get("prize_count", 0)))
	_render_prizes(1 - _view_seat, int(opp_counts.get("prize_count", 0)))
	_render_board(view.get("board", []))
	var public_zone_state := _render_public_cards(view.get("public_cards", []))
	_set_label("MyDiscardHudValue", "%d" % int(public_zone_state.discard_counts.get(_view_seat, 0)))
	_set_label("OppDiscardHudValue", "%d" % int(public_zone_state.discard_counts.get(1 - _view_seat, 0)))
	_set_label("MyLostValue", "%d" % int(public_zone_state.lost_zone_counts.get(_view_seat, 0)))
	_set_label("EnemyLostValue", "%d" % int(public_zone_state.lost_zone_counts.get(1 - _view_seat, 0)))
	_render_public_event_log(int(view.get("ordinal", 0)))
	_visual_state = {
		"ordinal": int(view.get("ordinal", -1)),
		"view_seat": _view_seat,
		"slots": _slot_public_entries.duplicate(true),
		"stadium_card_uid": _stadium_entry.get("card_uid"),
		"discard_counts": public_zone_state.discard_counts.duplicate(true),
		"lost_zone_counts": public_zone_state.lost_zone_counts.duplicate(true),
		"hand_count": my_hand_count,
		"execution_authority": false,
	}


func _render_public_hand(count: int) -> void:
	var resolved_count := maxi(count, 0)
	var existing_count := 0
	for child: Node in _hand_container.get_children():
		if child is BattleCardView:
			existing_count += 1
	if existing_count != resolved_count:
		for child: Node in _hand_container.get_children():
			_hand_container.remove_child(child)
			child.queue_free()
		for index: int in resolved_count:
			var card_view := BATTLE_CARD_VIEW.new() as BattleCardView
			card_view.name = "PublicHandCard_%d" % index
			card_view.custom_minimum_size = _play_card_size
			card_view.setup_from_card_data(null, BattleCardView.MODE_HAND)
			card_view.set_back_texture(_player_card_back_texture)
			card_view.set_face_down(true)
			card_view.set_clickable(false)
			card_view.set_secondary_inspect_enabled(false)
			card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hand_container.add_child(card_view)
	else:
		for child: Node in _hand_container.get_children():
			var card_view := child as BattleCardView
			if card_view != null:
				card_view.custom_minimum_size = _play_card_size
	_hand_container.set_meta("battle_hand_surface_mode", "public_count_back")


func _render_board(entries: Variant) -> void:
	_slot_public_entries.clear()
	_stadium_entry.clear()
	for slot_id: Variant in _slot_card_views.keys():
		_reset_card_view(_slot_card_views.get(slot_id), str(slot_id).contains("active"))
	var my_capacity := BENCH_SIZE
	var opp_capacity := BENCH_SIZE
	if entries is Array:
		for entry_variant: Variant in entries:
			if not entry_variant is Dictionary:
				continue
			var entry: Dictionary = entry_variant
			var seat := int(entry.get("seat", -1))
			var zone := str(entry.get("zone", ""))
			if zone == "stadium":
				_stadium_entry = entry.duplicate(true)
				continue
			if zone not in ["active", "bench"] or seat not in [0, 1]:
				continue
			var side := "my" if seat == _view_seat else "opp"
			var slot_id := (
				"%s_active" % side
				if zone == "active"
				else "%s_bench_%d" % [side, int(entry.get("slot", 0))]
			)
			_render_slot(slot_id, entry, zone == "active")
			if zone == "bench":
				if side == "my":
					my_capacity = maxi(my_capacity, int(entry.get("slot", 0)) + 1)
				else:
					opp_capacity = maxi(opp_capacity, int(entry.get("slot", 0)) + 1)
	_public_bench_sizes = {"my": my_capacity, "opp": opp_capacity}
	_sync_bench_slot_visibility(_public_bench_sizes)
	_render_stadium(_stadium_entry)


func _render_slot(slot_id: String, entry: Dictionary, active: bool) -> void:
	var view := _slot_card_views.get(slot_id) as BattleCardView
	if view == null:
		return
	var uid := str(entry.get("card_uid", ""))
	var data := _card_data_for_uid(uid)
	view.setup_from_card_data(
		data, BattleCardView.MODE_SLOT_ACTIVE if active else BattleCardView.MODE_SLOT_BENCH
	)
	view.set_clickable(false)
	view.set_secondary_inspect_enabled(false)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_disabled(false)
	view.set_selected(false)
	view.set_selectable_hint(false)
	view.set_badges("", "")
	view.self_modulate = Color.WHITE
	if data == null:
		view.set_info("未知公开卡牌", uid)
	var damage := maxi(0, int(entry.get("damage", 0)))
	var hp_max := maxi(int(data.hp) if data != null else damage, 1)
	view.set_battle_status({
		"hp_current": maxi(0, hp_max - damage),
		"hp_max": hp_max,
		"hp_ratio": float(maxi(0, hp_max - damage)) / float(hp_max),
		"status_icons": (entry.get("status", []) as Array).duplicate(),
		"energy_icons": [],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	_slot_public_entries[slot_id] = entry.duplicate(true)


func _render_stadium(entry: Dictionary) -> void:
	_prepare_shared_stadium_surface()
	if _stadium_card_view == null:
		return
	if entry.is_empty():
		_stadium_card_view.visible = false
		_stadium_card_view.setup_from_card_data(null, BattleCardView.MODE_PREVIEW)
		_set_legacy_stadium_hud_visible(_is_portrait_battle_layout_active())
		_set_label("StadiumLbl", "竞技场区")
		_sync_public_stadium_backdrop(null)
		return
	var uid := str(entry.get("card_uid", ""))
	var data := _card_data_for_uid(uid)
	_stadium_card_view.visible = true
	_stadium_card_view.setup_from_card_data(data, BattleCardView.MODE_PREVIEW)
	_stadium_card_view.set_compact_preview(true)
	_stadium_card_view.set_clickable(false)
	_stadium_card_view.set_secondary_inspect_enabled(false)
	_stadium_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stadium_card_view.set_disabled(false)
	_stadium_card_view.set_selectable_hint(false)
	_stadium_card_view.set_badges("", "")
	_stadium_card_view.set_info("", "")
	if data == null:
		_stadium_card_view.set_info("未知公开卡牌", uid)
	_set_legacy_stadium_hud_visible(false)
	_battle_stadium_hud_coordinator.call("position_stadium_card_view")
	_sync_public_stadium_backdrop(data)


func _sync_public_stadium_backdrop(card_data: CardData) -> void:
	_ensure_battle_stadium_backdrop_coordinator()
	if _battle_stadium_backdrop_coordinator.has_method("sync_stadium_card_data"):
		_battle_stadium_backdrop_coordinator.call("sync_stadium_card_data", card_data, true)


func _render_public_cards(entries: Variant) -> Dictionary:
	var discard_counts := {0: 0, 1: 0}
	var lost_zone_counts := {0: 0, 1: 0}
	var discard_top: Dictionary = {}
	if entries is Array:
		for entry_variant: Variant in entries:
			if not entry_variant is Dictionary:
				continue
			var entry: Dictionary = entry_variant
			var seat := int(entry.get("seat", -1))
			if seat not in [0, 1]:
				continue
			match str(entry.get("zone", "")):
				"discard":
					discard_counts[seat] = int(discard_counts.get(seat, 0)) + 1
					discard_top[seat] = entry
				"lost_zone":
					lost_zone_counts[seat] = int(lost_zone_counts.get(seat, 0)) + 1
	for seat: int in [0, 1]:
		_render_public_card_preview(_discard_previews.get(seat), discard_top.get(seat, {}))
	return {"discard_counts": discard_counts, "lost_zone_counts": lost_zone_counts}


func _render_public_card_preview(view: BattleCardView, entry: Dictionary) -> void:
	if view == null:
		return
	if entry.is_empty():
		view.setup_from_card_data(null, BattleCardView.MODE_PREVIEW)
		view.set_face_down(false)
		view.self_modulate = Color(1, 1, 1, 0.05)
		return
	var uid := str(entry.get("card_uid", ""))
	var data := _card_data_for_uid(uid)
	view.setup_from_card_data(data, BattleCardView.MODE_PREVIEW)
	view.set_face_down(false)
	view.set_clickable(false)
	view.set_secondary_inspect_enabled(false)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.self_modulate = Color.WHITE
	if data == null:
		view.set_info("未知公开卡牌", uid)


func _render_face_down_pile(view: BattleCardView, count: int) -> void:
	if view == null:
		return
	view.setup_from_card_data(null, BattleCardView.MODE_PREVIEW)
	view.set_face_down(count > 0)
	view.set_clickable(false)
	view.set_secondary_inspect_enabled(false)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.self_modulate = Color.WHITE if count > 0 else Color(1, 1, 1, 0.05)


func _render_prizes(seat: int, count: int) -> void:
	var views: Array = _prize_views.get(seat, [])
	for index: int in views.size():
		var view := views[index] as BattleCardView
		if view == null:
			continue
		view.visible = true
		view.setup_from_card_data(null, BattleCardView.MODE_PREVIEW)
		view.set_face_down(index < count)
		view.set_clickable(false)
		view.set_secondary_inspect_enabled(false)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.self_modulate = Color.WHITE if index < count else Color(1, 1, 1, 0.035)


func _reset_card_view(view: BattleCardView, active: bool) -> void:
	if view == null:
		return
	view.setup_from_card_data(
		null, BattleCardView.MODE_SLOT_ACTIVE if active else BattleCardView.MODE_SLOT_BENCH
	)
	view.set_clickable(false)
	view.set_secondary_inspect_enabled(false)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_disabled(false)
	view.set_selected(false)
	view.set_selectable_hint(false)
	view.set_badges("", "")
	view.clear_battle_status()
	view.set_info("", "")
	view.self_modulate = Color(1, 1, 1, 0.18)


func _clear_visual_state() -> void:
	_slot_public_entries.clear()
	_stadium_entry.clear()
	for slot_id: Variant in _slot_card_views.keys():
		_reset_card_view(_slot_card_views.get(slot_id), str(slot_id).contains("active"))
	_render_stadium({})
	_render_public_hand(0)
	for seat: int in [0, 1]:
		_render_face_down_pile(_deck_previews.get(seat), 0)
		_render_public_card_preview(_discard_previews.get(seat), {})
		_render_prizes(seat, 0)
	_visual_state = {"slots": {}, "execution_authority": false}


func _build_public_event_log(frames: Variant) -> void:
	_event_log_entries.clear()
	if not frames is Array:
		return
	for frame_variant: Variant in frames:
		if not frame_variant is Dictionary:
			continue
		var frame: Dictionary = frame_variant
		_event_log_entries.append("回合 %d · %s" % [
			int(frame.get("turn_number", 0)),
			_event_kind_label(str(frame.get("event_kind", "unknown"))),
		])


func _render_public_event_log(ordinal: int) -> void:
	var log_list := find_child("LogList", true, false) as RichTextLabel
	if log_list == null:
		return
	var last_index := mini(ordinal, _event_log_entries.size() - 1)
	var first_index := maxi(0, last_index - MAX_VISIBLE_LOG_LINES + 1)
	var lines := PackedStringArray()
	for index: int in range(first_index, last_index + 1):
		var prefix := "[color=#68e6ff]▶[/color]" if index == last_index else "  "
		lines.append("%s [b]%03d[/b]  %s" % [prefix, index + 1, _event_log_entries[index]])
	log_list.text = "\n".join(lines)
	log_list.scroll_to_line(maxi(log_list.get_line_count() - 1, 0))


func _event_kind_label(event_kind: String) -> String:
	match event_kind:
		"match_started":
			return "对局开始"
		"state_progressed":
			return "状态更新"
		"decision_recorded":
			return "AI 决策"
		"match_finished":
			return "对局结束"
		_:
			return event_kind


func _apply_optional_match_context(
	contract_owner: Variant,
	manifest: Variant,
	match_envelope: Variant
) -> Dictionary:
	_view_seat = 0
	_player_labels = {0: "玩家 1", 1: "玩家 2"}
	if not match_envelope is Dictionary or match_envelope.is_empty():
		return {"accepted": true, "error_code": ""}
	if contract_owner == null or not contract_owner.has_method("validate_document"):
		return _failure("contract_owner_invalid")
	var validated: Dictionary = contract_owner.validate_document(match_envelope)
	if not bool(validated.get("accepted", false)):
		return validated
	if not manifest is Dictionary or match_envelope.get("match_id") != manifest.get("match_id"):
		return _failure("replay_envelope_binding_invalid")
	var seats: Variant = match_envelope.get("seat_assignment", [])
	if seats is Array and seats.size() == 2 and int(seats[0]) in [0, 1]:
		_view_seat = int(seats[0])
	var participants: Variant = match_envelope.get("participants", [])
	if participants is Array and participants.size() == 2:
		for participant_index: int in 2:
			var participant: Variant = participants[participant_index]
			if not participant is Dictionary:
				continue
			var seat := (
				int(seats[participant_index])
				if seats is Array and seats.size() == 2
				else participant_index
			)
			if participant.get("participant_kind") == "strategy_release":
				_player_labels[seat] = "策略 AI"
			else:
				_player_labels[seat] = "规则 AI"
	return {"accepted": true, "error_code": ""}


func _card_data_for_uid(uid: String) -> CardData:
	var separator := uid.rfind("_")
	if separator <= 0 or separator + 1 >= uid.length():
		return null
	return CardDatabase.get_card(uid.left(separator), uid.substr(separator + 1))


func _apply_responsive_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	_apply_replay_layout_for_size(size)


func _apply_replay_layout_for_size(layout_size: Vector2) -> void:
	if layout_size.x <= 0.0 or layout_size.y <= 0.0:
		return
	_ensure_battle_layout_coordinator()
	var is_mobile := (
		OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
		or OS.has_feature("web_android") or OS.has_feature("web_ios")
	)
	var layout_context_variant: Variant = _battle_layout_coordinator.call(
		"apply", layout_size, "auto", is_mobile
	)
	var layout_context: Dictionary = (
		layout_context_variant if layout_context_variant is Dictionary else {}
	)
	_update_battle_layout_button()
	_style_vstar_lost_huds()
	_style_end_turn_hud_buttons()
	_finalize_portrait_layout_constraints()
	_ensure_battle_display_coordinator()
	_battle_display_coordinator.call("stabilize_hand_surface_layout")
	_layout_llm_wait_label()
	var mode := str(layout_context.get("resolved_mode", _active_battle_layout_mode))
	if mode == "":
		mode = "portrait" if layout_size.y > layout_size.x else "landscape"
	_fit_replay_controls_to_layout(layout_size, mode)
	set_meta("public_replay_layout_mode", mode)
	var log_panel := find_child("LogPanel", true, false) as CanvasItem
	if log_panel != null:
		log_panel.visible = mode == "landscape"
	_update_player_controls()
	var back := _button("BtnBack")
	if back != null:
		# The shared review layout hides the live BattleScene exit. This viewer's
		# BtnBack is its only read-only exit, so restore it after every relayout.
		back.visible = true


func _fit_replay_controls_to_layout(layout_size: Vector2, mode: String) -> void:
	if mode != "portrait":
		return
	var top_bar_left := find_child("TopBarLeft", true, false) as Control
	var top_bar_center := find_child("TopBarCenter", true, false) as Control
	var top_bar_right := find_child("TopBarRight", true, false) as Control
	var top_bar_actions := find_child("TopBarActions", true, false) as HBoxContainer
	if top_bar_left == null or top_bar_right == null or top_bar_actions == null:
		return
	var controls := _portrait_direct_top_action_buttons()
	var gap := clampi(roundi(layout_size.x * 0.007), 2, 5)
	var status_width := clampf(layout_size.x * 0.19, 88.0, 120.0)
	# TopBar has 6 px side insets plus a 10 px column gap. Reserve a small
	# rounding allowance so the final button stays inside narrow phone canvases.
	var outer_and_column_gap := 34.0
	var actions_width := maxf(layout_size.x - status_width - outer_and_column_gap, 220.0)
	var button_width := maxf(
		(actions_width - float(gap * maxi(controls.size() - 1, 0)))
		/ float(maxi(controls.size(), 1)),
		44.0
	)
	top_bar_left.custom_minimum_size.x = status_width
	top_bar_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if top_bar_center != null:
		top_bar_center.visible = false
		top_bar_center.custom_minimum_size.x = 0.0
	top_bar_right.custom_minimum_size.x = actions_width
	top_bar_right.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_bar_actions.custom_minimum_size.x = actions_width
	top_bar_actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_bar_actions.alignment = BoxContainer.ALIGNMENT_END
	top_bar_actions.add_theme_constant_override("separation", gap)
	for control: Button in controls:
		if control == null:
			continue
		control.custom_minimum_size.x = button_width
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _current_bench_display_sizes() -> Dictionary:
	return _public_bench_sizes.duplicate()


func _current_bench_display_size() -> int:
	return maxi(int(_public_bench_sizes.my), int(_public_bench_sizes.opp))


func _portrait_direct_top_action_buttons() -> Array[Button]:
	return [
		_button("BtnReplayPrevTurn"),
		_button("BtnReplayPlayPause"),
		_button("BtnReplayNextTurn"),
		find_child("OptReplaySpeed", true, false) as OptionButton,
		_button("BtnBack"),
	]


func _button(node_name: String) -> Button:
	return find_child(node_name, true, false) as Button


func _set_label(node_name: String, text: String) -> void:
	var label := find_child(node_name, true, false) as Label
	if label != null:
		label.text = text
		label.tooltip_text = text


static func _failure(code: String) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"authoritative": false,
		"navigation_policy": NAVIGATION_POLICY,
		"grants": [],
	}
