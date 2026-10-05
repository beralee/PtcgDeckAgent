extends Node
const Projector := preload("res://scripts/commentary/CommentaryPublicProjector.gd")
const Knowledge := preload("res://scripts/commentary/CommentaryKnowledge.gd")
const Session := preload("res://scripts/commentary/BattleCommentarySession.gd")
const PanelScript := preload("res://scripts/commentary/CommentaryPanel.gd")
const Platform := preload("res://scenes/arena3d/ArenaPlatform.gd")
var battle: Control
var presenter: Control
var gsm: GameStateMachine
var panel: PanelContainer
var session: RefCounted
var knowledge := Knowledge.new()
var events: Array = []
var sequence := 0
var revision := 0
var dirty := true
var quiet := 0.0
var previous: Dictionary = {}
var closed := false
var history_dialog: Control

func setup(scene: Control, arena: Control, api_config: Dictionary, transport: RefCounted = null) -> void:
	battle = scene
	presenter = arena
	gsm = scene.get("_gsm")
	panel = PanelScript.new()
	battle.add_child(panel)
	panel.close_requested.connect(close)
	panel.history_requested.connect(_show_history)
	session = Session.new()
	session.line_ready.connect(panel.present)
	session.status_changed.connect(func(value: String): panel.status.text = value)
	session.start(self, api_config, transport)
	if gsm != null:
		gsm.action_logged.connect(_on_action)
		# Early setup events contain hidden identities; copy only allow-listed fields.
		for action: GameAction in gsm.action_log: _on_action(action)
	_layout()

func _on_action(action: GameAction) -> void:
	if closed: return
	if session != null: session.mark_unsettled()
	sequence += 1
	events.append(Projector.event(action, sequence))
	if events.size() > 64: events.pop_front()
	dirty = true
	quiet = 0.0

func _process(delta: float) -> void:
	if closed or not is_instance_valid(battle) or session == null: return
	_layout()
	quiet += delta
	if dirty and quiet >= 0.45 and _settled():
		var state := Projector.snapshot(gsm.game_state)
		if not state.is_empty():
			revision += 1
			var packet := {"snapshot_id": revision, "state": state, "before": previous, "events": events.duplicate(true), "knowledge": knowledge.observe(state)}
			session.offer(packet)
			previous = state
			events.clear()
			dirty = false
	# Never await this from a game action or a presentation input gate.
	session.tick(float(Time.get_ticks_msec()) / 1000.0)

func _settled() -> bool:
	if gsm == null or gsm.game_state == null: return false
	if gsm.game_state.phase not in [GameState.GamePhase.MAIN, GameState.GamePhase.GAME_OVER]: return false
	if not gsm.get_pending_decision_snapshot().is_empty(): return false
	if str(battle.get("_pending_choice")) != "": return false
	if is_instance_valid(presenter) and presenter.motion != null and presenter.motion.is_busy(): return false
	return true

func _layout() -> void:
	var safe := Platform.safe_rect(battle)
	var metrics := Platform.metrics(battle.get_viewport_rect().size, GameManager.ui_runtime_profile)
	var height := PanelScript.reserved_height(safe.size)
	battle.set_meta("commentary_reserved_height", height + 8)
	panel.position = safe.position + Vector2(8, 0 if metrics.compact else 58)
	panel.size = Vector2(maxf(0, safe.size.x - 16), height)
	panel.body.max_lines_visible = 4 if safe.size.x < 1000 else 3

func _show_history() -> void:
	if session == null: return
	if is_instance_valid(history_dialog): history_dialog.queue_free()
	history_dialog = preload("res://scripts/ui/GameModalDialog.gd").new()
	history_dialog.title = "本局解说记录"
	history_dialog.dialog_size = Vector2(720, 540)
	var rows := PackedStringArray()
	for entry: Dictionary in session.history: rows.append("【%s】\n%s" % [entry.source, entry.text])
	history_dialog.dialog_text = "\n\n".join(rows) if not rows.is_empty() else "还没有解说记录。"
	battle.add_child(history_dialog)
	history_dialog.popup_centered()

func close() -> void:
	if closed: return
	closed = true
	if session != null: session.stop()
	if gsm != null and gsm.action_logged.is_connected(_on_action): gsm.action_logged.disconnect(_on_action)
	if is_instance_valid(battle): battle.set_meta("commentary_reserved_height", 0.0)
	if is_instance_valid(panel): panel.queue_free()
	if is_instance_valid(history_dialog): history_dialog.queue_free()
	set_process(false)

func _exit_tree() -> void:
	close()
