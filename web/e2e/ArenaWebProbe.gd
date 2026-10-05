extends Node
## Test-export-only public fixture and read-only geometry for browser gestures.
var ready_for_input := false
var battle: Control
var production_3d_available := false
var production_3d_selected := false
var excluded_3d_media_absent := false

func _ready() -> void:
	call_deferred("_prepare")

func _prepare() -> void:
	GameManager.battle_3d_enabled = true
	# Exercise the production portable renderer and its real field selection.
	GameManager.selected_battle_background = "res://assets/arena3d/previews/grove.png"
	GameManager.battle_effects_enabled = false
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	if get_tree().current_scene.name != "BattleScene":
		GameManager.goto_battle()
		await get_tree().scene_changed
	battle = get_tree().current_scene
	production_3d_available = preload("res://scripts/ui/battle/BattlePresentation.gd").fields_3d_available()
	production_3d_selected = bool(battle.get("_arena_enabled"))
	excluded_3d_media_absent = (
		ResourceLoader.exists("res://assets/arena3d/previews/grove.png")
		and not ResourceLoader.exists("res://assets/arena3d/product-v6/grove_table.glb")
		and not ResourceLoader.exists("res://assets/arena3d/product-v3/studio_small_09.hdr")
	)
	# The real scene owns asynchronous startup and its loading overlay. Never
	# replace its state while deferred startup can still overwrite this fixture.
	await get_tree().process_frame
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 15000
	while bool(battle.get("_battle_start_pending")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert(not bool(battle.get("_battle_start_pending")), "Battle startup did not finish")
	var gs := GameState.new()
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 3
	gs.current_player_index = 0
	for pi in range(2):
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = PokemonSlot.new()
		player.active_pokemon.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV7C", "038"), pi))
		for i in range(20): player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C", "DAR"), pi))
		for i in range(5): player.hand.append(CardInstance.create(CardDatabase.get_card("CSVE1C", "DAR"), pi))
		var prizes: Array[CardInstance] = []
		for i in range(6): prizes.append(CardInstance.create(CardDatabase.get_card("CSVE1C", "DAR"), pi))
		player.set_prizes(prizes)
		gs.players.append(player)
	battle.get("_gsm").game_state = gs
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	var startup_notice := battle.get_node_or_null("MulliganNotice") as Control
	if startup_notice != null: startup_notice.hide()
	if battle.get("_handover_panel") != null: battle.get("_handover_panel").hide()
	var p := battle.get_node_or_null("Arena3DPresenter")
	if p != null:
		battle.get("_arena_hand_observer").prime(gs,0)
		p.motion.clear()
		p.world.motion_enabled = false
	battle.call("_refresh_ui")
	await get_tree().create_timer(.5).timeout
	ready_for_input = true

func snapshot() -> Dictionary:
	if not ready_for_input: return {"ready":false}
	var p := battle.get_node_or_null("Arena3DPresenter")
	var points := {}
	if p == null:
		for key: String in ["_my_active", "_dialog_cancel"]:
			var at: Vector2 = battle.get(key).get_global_rect().get_center()
			points["my_active" if key == "_my_active" else key] = {"x":at.x,"y":at.y}
		return {"ready":true,"points":points,"width":battle.get_viewport_rect().size.x,"height":battle.get_viewport_rect().size.y,
			"portrait":battle.get_viewport_rect().size.y > battle.get_viewport_rect().size.x,
			"choice":battle.get("_pending_choice"),"production_3d_available":production_3d_available,
			"production_3d_selected":production_3d_selected,"fixture_3d":false,
			"excluded_3d_media_absent":excluded_3d_media_absent}
	for id: String in p.last_frame.slots:
		var at: Vector2 = p.get_global_transform()*p.world.project(p.world.cards[id].node.position)
		points[id] = {"x":at.x,"y":at.y}
	for key: String in ["menu_button","settings_button","log_button"]:
		var at: Vector2 = p.get(key).get_global_rect().get_center()
		points[key] = {"x":at.x,"y":at.y}
	var popup: PopupMenu = p.menu_button.get_popup()
	if popup.visible and p.platform_metrics.portrait:
		var panel: StyleBox = popup.get_theme_stylebox("panel")
		var row_height: float = popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))+popup.get_theme_constant("v_separation")
		var at := Vector2(popup.position)+Vector2(popup.size.x*.5,panel.get_content_margin(SIDE_TOP)+row_height*.5)
		points["menu_log"] = {"x":at.x,"y":at.y}
	var close_at: Vector2 = p.compact_log.find_child("ModalCloseButton",true,false).get_global_rect().get_center()
	points["log_close"] = {"x":close_at.x,"y":close_at.y}
	for key: String in ["_dialog_cancel","_detail_close_btn"]:
		var at: Vector2 = battle.get(key).get_global_rect().get_center()
		points[key] = {"x":at.x,"y":at.y}
	var status_controls: Array[Control] = [p.status_bar.turn]
	status_controls.append_array(p.status_bar.buttons)
	var status_inside: bool = p.status_bar.is_visible_in_tree()
	for control: Control in status_controls:
		status_inside = status_inside and control.is_visible_in_tree() and p.status_bar.get_global_rect().encloses(control.get_global_rect())
	var exit_at: Vector2 = p.status_bar.buttons[3].get_global_rect().get_center()
	points["status_exit"] = {"x":exit_at.x,"y":exit_at.y}
	var cancel_choice := _text_choice(battle.get("_dialog_overlay"), 1)
	if cancel_choice != null:
		var at := cancel_choice.get_global_rect().get_center()
		points["confirm_exit_cancel"] = {"x":at.x,"y":at.y}
	return {"ready":true,"points":points,"width":battle.get_viewport_rect().size.x,"height":battle.get_viewport_rect().size.y,
		"excluded_3d_media_absent":excluded_3d_media_absent,
		"production_3d_available":production_3d_available,"production_3d_selected":production_3d_selected,"fixture_3d":true,
		"compact":p.platform_metrics.compact,"portrait":p.platform_metrics.portrait,"low":p.world.low_quality,
		"compact_toolbars_removed":not p.settings_button.visible and not p.log_button.visible and not p.stadium_button.visible and not p.menu_button.visible,
		"status_entries":status_controls.size(),"status_inside":status_inside,
		"board_below_status":is_equal_approx(p.board_rect.position.y,p.status_bar.size.y) and is_equal_approx(p.board_rect.end.y,p.size.y) and is_equal_approx(p.board_rect.size.x,p.size.x),
		"choice":battle.get("_pending_choice"),"detail":battle.get("_detail_overlay").visible,
		"menu":p.menu_button.get_popup().visible,"log":p.compact_log.visible,
		"theme":p.theme_id,"render_width":p.viewport.size.x,"render_height":p.viewport.size.y,
		"active_touches":battle.get("_arena_touch").fingers.size()}

func _text_choice(node: Node, index: int) -> Control:
	if node is Control and node.is_visible_in_tree() and int(node.get_meta("dialog_text_choice_index", -1)) == index:
		return node as Control
	for child: Node in node.get_children():
		var found := _text_choice(child, index)
		if found != null: return found
	return null
