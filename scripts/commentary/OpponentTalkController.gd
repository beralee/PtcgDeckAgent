extends Node
const Projector := preload("res://scripts/commentary/CommentaryPublicProjector.gd")
const Knowledge := preload("res://scripts/commentary/CommentaryKnowledge.gd")
const Director := preload("res://scripts/commentary/OpponentTalkDirector.gd")
const Session := preload("res://scripts/commentary/OpponentTalkSession.gd")
const Bubble := preload("res://scripts/commentary/OpponentTalkBubble.gd")
const Platform := preload("res://scenes/arena3d/ArenaPlatform.gd")
const Placement := preload("res://scripts/commentary/OpponentTalkPlacement.gd")
var battle: Control
var presenter: Control
var gsm: GameStateMachine
var panel: PanelContainer
var director := Director.new()
var knowledge := Knowledge.new()
var session: RefCounted
var closed := false
var dirty := true
var quiet := 0.0
var sequence := 0
var public_knowledge: Dictionary = {}
var deferred_reaction: Dictionary = {}
var history_dialog: Control

func setup(scene: Control, arena: Control, config: Dictionary, transport: RefCounted = null) -> void:
	battle = scene
	presenter = arena
	panel = Bubble.new()
	battle.add_child(panel)
	panel.close_requested.connect(close)
	panel.history_requested.connect(_show_history)
	# Floating buttons share the arena's one-touch/one-action ownership, before
	# its empty-board target can consume raw touch or compatibility mouse edges.
	presenter.ui_buttons.append(panel.history_button)
	presenter.ui_buttons.append(panel.close_button)
	session = Session.new()
	session.start(self, config, transport)
	session.line_ready.connect(panel.present)
	panel.identity.tooltip_text = "性格：" + session.personality
	_bind_machine()
	_layout()

func _bind_machine() -> void:
	var current: GameStateMachine = battle.get("_gsm")
	if current == gsm: return
	if gsm != null:
		# A replaced match must not inherit this match's speech or callbacks.
		close()
		return
	if current == null or current.game_state == null: return
	gsm = current
	_prime(Projector.snapshot(gsm.game_state))
	# Author archive verification may yield before the GSM exists. Observe its
	# early public events without speaking them again when the bind catches up.
	for action: GameAction in gsm.action_log:
		sequence += 1
		director.action(Projector.event(action, sequence))
	gsm.action_logged.connect(_on_action)
	dirty = true
	quiet = 0.0

func _prime(state: Dictionary) -> void:
	if not director.previous_prizes.is_empty() or state.get("players", []).size() != 2: return
	if int(state.get("turn", 0)) <= 0 or str(state.get("phase", "")) in ["SETUP", "MULLIGAN", "SETUP_PLACE"]: return
	director.previous_prizes = [int(state.players[0].prizes_remaining), int(state.players[1].prizes_remaining)]
	director.own_remaining = int(state.players[director.seat].prizes_remaining)
	director.other_remaining = int(state.players[1 - director.seat].prizes_remaining)

func _on_action(action: GameAction) -> void:
	if closed: return
	sequence += 1
	session.new_action()
	var event := Projector.event(action, sequence)
	if director.previous_prizes.is_empty(): _prime(Projector.snapshot(gsm.game_state))
	var cue := director.action(event)
	# Turn-end frustration waits for board resolution. Attack/arrival are
	# already committed, and can be shown before their visual animation.
	if not cue.is_empty():
		if cue.trigger == "stalled": deferred_reaction = cue
		else:
			deferred_reaction.clear()
			session.offer(cue, _now())
	dirty = true
	quiet = 0.0

func _process(delta: float) -> void:
	if closed or not is_instance_valid(battle) or session == null: return
	_bind_machine()
	if closed: return
	_layout()
	quiet += delta
	if dirty and quiet >= 0.25 and _settled():
		var state := Projector.snapshot(gsm.game_state)
		var cue := director.settled(state)
		if cue.is_empty() and not deferred_reaction.is_empty():
			# TURN_END may already have advanced the public turn once.
			if int(state.turn) <= int(deferred_reaction.turn) + 1: cue = deferred_reaction
		deferred_reaction.clear()
		public_knowledge = knowledge.observe(state)
		session.offer(cue, _now())
		dirty = false
	if not public_knowledge.is_empty(): session.prepare(public_knowledge, _now())
	session.tick(_now())

func _settled() -> bool:
	if gsm == null or gsm.game_state == null: return false
	if gsm.game_state.phase not in [GameState.GamePhase.MAIN, GameState.GamePhase.GAME_OVER]: return false
	if not gsm.get_pending_decision_snapshot().is_empty(): return false
	if str(battle.get("_pending_choice")) != "": return false
	if is_instance_valid(presenter) and presenter.motion != null and presenter.motion.is_busy(): return false
	return true

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _layout() -> void:
	battle.set_meta("opponent_talk_reserved_width", 0.0)
	battle.set_meta("commentary_reserved_height", 0.0)
	if not is_instance_valid(presenter) or presenter.world == null:
		panel.set_placement_available(false)
		return
	var world: Node3D = presenter.world
	if not world.cards.has("opp_active") or battle.call("_is_board_modal_overlay_visible") or world.cinematic:
		panel.set_placement_available(false)
		return
	var origin: Vector2 = presenter.global_position
	var bounds: Rect2 = presenter.board_rect
	bounds.position += origin
	bounds = bounds.intersection(Platform.safe_rect(battle)).grow(-8.0)
	var active: Rect2 = world.card_screen_rect("opp_active")
	active.position += origin
	var metrics := Platform.metrics(battle.get_viewport_rect().size,GameManager.get_ui_runtime_profile())
	panel.configure_mobile(float(metrics.scale) if metrics.touch else 0.0,not metrics.portrait)
	if metrics.touch:
		_layout_mobile(bounds,active,origin)
		return
	# Stay on the opponent's half. On compact layouts the public piles are
	# toolbar buttons; the empty upper board remains a safe fallback pocket.
	bounds.end.y = minf(bounds.end.y, active.end.y)
	var right_edge := bounds.end.x
	bounds.position.x = maxf(bounds.position.x, active.end.x + 6.0)
	bounds.end.x = right_edge
	var obstacles: Array[Rect2] = []
	for id: String in world.cards:
		if not world.cards[id].node.visible: continue
		var card: Rect2 = world.card_screen_rect(id)
		card.position += origin
		obstacles.append(card.grow(8.0))
	var piles := Rect2()
	if not world.compact_board:
		for side: String in ["my", "opp"]:
			for kind: String in ["deck", "discard"]:
				var pile: Rect2 = world.side_zones.screen_rect(side, kind)
				pile.position += origin
				if side == "opp": piles = pile if not piles.has_area() else piles.merge(pile)
				obstacles.append(pile.grow_individual(6, 28, 6, 36))
		for mine: bool in [true, false]:
			for i: int in 6:
				var prize: Rect2 = presenter.board_hud.prize_rect(i, mine)
				prize.position += origin
				obstacles.append(prize.grow(8))
	var controls: Array = [presenter.settings_button, presenter.log_button, presenter.end_button, presenter.stats, presenter.menu_button, presenter.stadium_button]
	controls.append_array(presenter.secondary_buttons)
	controls.append_array(presenter.zone_buttons.values())
	for control: Control in controls:
		if control.is_visible_in_tree(): obstacles.append(control.get_global_rect().grow(6.0))
	var slot := Rect2()
	var above := bounds
	above.end.y = minf(active.position.y, piles.position.y if piles.has_area() else active.position.y) - 8.0
	# Prefer a smaller bubble above the active/piles. Only use their gap at
	# active height when the bench or toolbar leaves no clear upper pocket.
	for region: Rect2 in [above, bounds]:
		for width: float in [320.0, 280.0, 360.0]:
			var wanted: Vector2 = panel.fit_width(width)
			var right := piles.position.x if piles.has_area() else bounds.end.x
			var preferred := Vector2((active.end.x + right - wanted.x) * 0.5, active.position.y - wanted.y - 10.0)
			slot = Placement.find_slot(region, wanted, preferred, obstacles)
			if slot.has_area(): break
		if slot.has_area(): break
	panel.set_placement_available(slot.has_area())
	if slot.has_area():
		panel.global_position = slot.position
		panel.size = slot.size

func _layout_mobile(bounds: Rect2, active: Rect2, origin: Vector2) -> void:
	# Mobile speech intentionally occupies the opponent's bench, as a brief
	# expressive overlay. The board remains fixed and body input passes through.
	var bench := Rect2()
	for id: String in presenter.world.cards:
		if not id.begins_with("opp_bench_"): continue
		var card: Rect2 = presenter.world.card_screen_rect(id)
		card.position += origin
		bench = card if not bench.has_area() else bench.merge(card)
	var width := bounds.size.x * (0.94 if bounds.size.y > bounds.size.x else 0.64)
	var wanted: Vector2 = panel.fit_width(width)
	var top := bounds.position.y
	var bottom := active.position.y-8
	if wanted.y > bottom-top:
		wanted = panel.fit_width(bounds.size.x*0.98)
	if not bounds.has_area() or wanted.x > bounds.size.x or wanted.y > bottom-top:
		panel.set_placement_available(false)
		return
	var desired_y := bench.get_center().y-wanted.y*.5 if bench.has_area() else top
	panel.global_position = Vector2(bounds.get_center().x-wanted.x*.5,clampf(desired_y,top,maxf(top,bottom-wanted.y)))
	panel.size = wanted
	panel.set_placement_available(true)

func _show_history() -> void:
	if closed or session == null: return
	if is_instance_valid(history_dialog): history_dialog.queue_free()
	history_dialog = preload("res://scripts/ui/GameModalDialog.gd").new()
	history_dialog.title = "对手说过的话"
	history_dialog.dialog_size = Vector2(640, 520)
	var rows := PackedStringArray()
	for entry: Dictionary in session.history: rows.append("第 %d 回合 · %s\n%s" % [int(entry.turn), entry.mood, entry.text])
	history_dialog.dialog_text = "\n\n".join(rows) if not rows.is_empty() else "对手还没开口。"
	battle.add_child(history_dialog)
	history_dialog.popup_centered()

func close() -> void:
	if closed: return
	closed = true
	if session != null: session.stop()
	if is_instance_valid(presenter) and is_instance_valid(panel):
		presenter.ui_buttons.erase(panel.history_button)
		presenter.ui_buttons.erase(panel.close_button)
	if gsm != null and gsm.action_logged.is_connected(_on_action): gsm.action_logged.disconnect(_on_action)
	if is_instance_valid(battle):
		battle.set_meta("commentary_reserved_height", 0.0)
		battle.set_meta("opponent_talk_reserved_width", 0.0)
	if is_instance_valid(panel): panel.queue_free()
	if is_instance_valid(history_dialog): history_dialog.queue_free()
	set_process(false)

func _exit_tree() -> void:
	close()
