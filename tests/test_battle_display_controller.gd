class_name TestBattleDisplayController
extends TestBase

const BattleDisplayControllerScript = preload("res://scripts/ui/battle/BattleDisplayController.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


class RefreshHandSceneStub extends Control:
	var _gsm: GameStateMachine = null
	var _draw_reveal_active: bool = false
	var _draw_reveal_allow_hand_refresh_during_fly: bool = false
	var _draw_reveal_pending_hand_refresh: bool = false
	var _draw_reveal_current_action: GameAction = null
	var _draw_reveal_visible_instance_ids: Array[int] = []
	var _draw_reveal_queue: Array = []
	var _hand_scroll: ScrollContainer = ScrollContainer.new()
	var _hand_container: HBoxContainer = HBoxContainer.new()
	var _view_player: int = 0
	var _latest_opponent_action_text: String = ""
	var _latest_opponent_action_turn_number: int = -1
	var _selected_hand_card: CardInstance = null
	var _play_card_size: Vector2 = Vector2(130, 182)
	var _portrait_active: bool = false
	var _review_mode: bool = false

	func _init() -> void:
		_hand_scroll.name = "HandScroll"
		_hand_container.name = "HandContainer"
		_hand_scroll.add_child(_hand_container)
		add_child(_hand_scroll)

	func _bt(key: String, params: Dictionary = {}) -> String:
		return BattleI18n.t(key, params)

	func _is_portrait_battle_layout_active() -> bool:
		return _portrait_active

	func _is_review_mode() -> bool:
		return _review_mode


class FieldSceneStub extends Control:
	var _slot_card_views: Dictionary = {}
	var _field_interaction_slot_index_by_id: Dictionary = {}
	var _gsm: GameStateMachine = null
	var _play_card_size: Vector2 = Vector2(130, 182)

	func _is_portrait_battle_layout_active() -> bool:
		return false

	func _field_interaction_selected_slot_ids() -> Array[String]:
		return []

	func _is_field_interaction_active() -> bool:
		return false


class RecordingFieldCardView extends BattleCardView:
	var setup_call_count: int = 0

	func setup_from_instance(inst: CardInstance = null, mode: String = MODE_HAND) -> void:
		setup_call_count += 1
		super.setup_from_instance(inst, mode)


func _make_refresh_hand_scene_stub(current_player: int, turn_number: int) -> RefreshHandSceneStub:
	var scene := RefreshHandSceneStub.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = current_player
	gsm.game_state.turn_number = turn_number
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	scene._gsm = gsm
	return scene


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func _hand_test_card(name: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _field_test_slot(name: String, owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.hp = 120
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func test_field_refresh_rebinds_unchanged_cards_to_restore_authoritative_ui_state() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := FieldSceneStub.new()
	var panel := PanelContainer.new()
	var card_view := RecordingFieldCardView.new()
	panel.add_child(card_view)
	scene.add_child(panel)
	var slot := _field_test_slot("Stable Active")
	card_view.setup_from_instance(slot.get_top_card(), BattleCardView.MODE_SLOT_ACTIVE)
	scene._slot_card_views = {"my_active": card_view}
	var before := card_view.setup_call_count

	controller.call("refresh_slot_card_view", scene, "my_active", slot, true)
	controller.call("refresh_slot_card_view", scene, "my_active", slot, true)
	var result := run_checks([
		assert_eq(card_view.setup_call_count, before + 2, "Every committed field repaint must rebind the card view so stale animation geometry cannot survive on Windows"),
		assert_eq(card_view.card_instance, slot.get_top_card(), "The authoritative repaint must retain the current card identity"),
	])
	scene.free()
	return result


func test_get_selected_deck_name_falls_back_to_unknown_label() -> String:
	var controller := BattleDisplayControllerScript.new()
	var original_ids: Array = GameManager.selected_deck_ids.duplicate()
	GameManager.selected_deck_ids.clear()
	var result := str(controller.call("get_selected_deck_name", 0))
	GameManager.selected_deck_ids = original_ids.duplicate()

	return run_checks([
		assert_eq(result, _u([0x672A, 0x77E5, 0x724C, 0x7EC4]), "Missing deck selections should fall back to the unknown deck label"),
	])


func test_get_selected_deck_name_uses_dedicated_ai_deck_in_vs_ai_mode() -> String:
	var controller := BattleDisplayControllerScript.new()
	var original_ids: Array = GameManager.selected_deck_ids.duplicate()
	var original_mode: int = GameManager.current_mode
	var test_deck_id := 990002

	var normal_deck := DeckData.new()
	normal_deck.id = test_deck_id
	normal_deck.deck_name = "Normal Slot 2"
	normal_deck.total_cards = 60
	var ai_deck := DeckData.new()
	ai_deck.id = test_deck_id
	ai_deck.deck_name = "AI Slot 2"
	ai_deck.total_cards = 60

	CardDatabase.save_deck(normal_deck)
	CardDatabase.save_ai_deck(ai_deck)
	GameManager.selected_deck_ids = [123, test_deck_id]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var result := str(controller.call("get_selected_deck_name", 1))
	GameManager.selected_deck_ids = original_ids.duplicate()
	GameManager.current_mode = original_mode
	CardDatabase.delete_deck(test_deck_id)
	CardDatabase.delete_ai_deck(test_deck_id)

	return run_checks([
		assert_eq(result, "AI Slot 2", "Battle display should show the dedicated AI deck name for player 2 in VS_AI mode"),
	])


func test_get_display_player_name_prefers_tournament_names() -> String:
	var controller := BattleDisplayControllerScript.new()
	var previous_names := GameManager.battle_player_display_names.duplicate()
	var previous_mode := GameManager.current_mode
	var previous_selection := GameManager.ai_selection.duplicate(true)

	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.ai_selection["display_name"] = "系统AI"
	GameManager.set_battle_player_display_names(["小林", "青木"])
	var player_name := str(controller.call("get_display_player_name", 0))
	var opponent_name := str(controller.call("get_display_player_name", 1))

	GameManager.battle_player_display_names = previous_names
	GameManager.current_mode = previous_mode
	GameManager.ai_selection = previous_selection

	return run_checks([
		assert_eq(player_name, "小林", "Battle display should use the explicit player tournament name for player 1"),
		assert_eq(opponent_name, "青木", "Battle display should use the explicit player tournament name for player 2"),
	])
	

func test_battle_scene_formats_action_log_with_display_names() -> String:
	var scene := BattleSceneScript.new()
	var previous_names := GameManager.battle_player_display_names.duplicate()
	GameManager.set_battle_player_display_names(["小林", "青木"])
	var rendered := str(scene.call("_format_action_description_for_display", "第3回合开始，玩家1行动；玩家2抽1张牌"))
	GameManager.battle_player_display_names = previous_names

	return run_checks([
		assert_true(rendered.find("小林") >= 0, "BattleScene should replace 玩家1 with the player display name in battle logs"),
		assert_true(rendered.find("青木") >= 0, "BattleScene should replace 玩家2 with the opponent display name in battle logs"),
		assert_true(rendered.find("玩家1") < 0 and rendered.find("玩家2") < 0, "BattleScene display log text should not keep numeric default player labels when tournament names are available"),
	])


func test_hand_card_subtext_formats_basic_energy() -> String:
	var controller := BattleDisplayControllerScript.new()
	var card_data := CardData.new()
	card_data.card_type = "Basic Energy"
	card_data.energy_provides = "W"
	var result := str(controller.call("hand_card_subtext", card_data))

	return run_checks([
		assert_eq(result, _u([0x57FA, 0x672C, 0x80FD, 0x91CF, 0x20, 0x2F, 0x20, 0x6C34]), "Basic Energy subtext should show the localized energy type"),
	])


func test_clear_container_children_removes_existing_nodes() -> String:
	var controller := BattleDisplayControllerScript.new()
	var container := HBoxContainer.new()
	container.add_child(Label.new())
	container.add_child(Button.new())

	controller.call("clear_container_children", container)

	return run_checks([
		assert_eq(container.get_child_count(), 0, "clear_container_children should empty the target container"),
	])


func test_refresh_hand_shows_latest_opponent_action_text_during_opponent_turn() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 7)
	scene._latest_opponent_action_text = "玩家2使用了老大的指令"
	scene._latest_opponent_action_turn_number = 7

	controller.call("refresh_hand", scene)

	var hand_container: HBoxContainer = scene._hand_container
	var label := hand_container.get_child(0) as Label
	return run_checks([
		assert_eq(hand_container.get_child_count(), 1, "Opponent turns should still render a single status label in the hand area"),
		assert_eq(label.text, "玩家2使用了老大的指令", "The hand-area waiting label should mirror the latest opponent action text for the current turn"),
	])


func test_refresh_hand_falls_back_to_waiting_text_when_opponent_has_no_current_turn_action() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 8)
	scene._latest_opponent_action_text = "玩家2使用了老大的指令"
	scene._latest_opponent_action_turn_number = 7

	controller.call("refresh_hand", scene)

	var hand_container: HBoxContainer = scene._hand_container
	var label := hand_container.get_child(0) as Label
	return run_checks([
		assert_eq(label.text, BattleI18n.t("battle.hand.waiting"), "The hand area should fall back to the waiting copy before the opponent logs a new action this turn"),
	])


func test_native_replay_keeps_local_hand_visible_during_ai_turn() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 8)
	scene._review_mode = true
	var local_card := _hand_test_card("Nest Ball")
	scene._gsm.game_state.players[0].hand.append(local_card)

	controller.call("refresh_hand", scene)

	var hand_container: HBoxContainer = scene._hand_container
	var rendered_card := hand_container.get_child(0) as BattleCardView
	return run_checks([
		assert_eq(str(hand_container.get_meta("battle_hand_surface_mode", "")), "cards", "Replay must keep the local player's real hand surface visible across both turns"),
		assert_eq(rendered_card.card_instance.instance_id if rendered_card != null else -1, local_card.instance_id, "Replay must render the recorded hand identity through the normal BattleCardView"),
	])


func test_refresh_hand_enlarges_and_centers_portrait_waiting_text() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 8)
	scene._portrait_active = true
	scene._hand_scroll.custom_minimum_size = Vector2(360, 120)

	controller.call("refresh_hand", scene)

	var hand_container: HBoxContainer = scene._hand_container
	var label := hand_container.get_child(0) as Label
	var font_size := label.get_theme_font_size("font_size")
	return run_checks([
		assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "Portrait hand info text should be horizontally centered"),
		assert_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, "Portrait hand info text should be vertically centered"),
		assert_gte(font_size, 48, "Portrait hand info text should be at least three times the default label size"),
		assert_gte(label.custom_minimum_size.x, 360.0, "Portrait hand info label should fill the hand scroll width"),
		assert_gte(label.custom_minimum_size.y, 120.0, "Portrait hand info label should fill the hand scroll height"),
		assert_eq(hand_container.alignment, BoxContainer.ALIGNMENT_CENTER, "Portrait hand info should be centered within the hand row"),
	])


func test_refresh_hand_keeps_portrait_waiting_font_stable_across_ai_action_updates() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 8)
	scene._portrait_active = true
	scene._hand_scroll.custom_minimum_size = Vector2(360, 120)

	controller.call("refresh_hand", scene)
	var label := scene._hand_container.get_node("HandWaitingLabel") as Label
	var first_font_size := label.get_theme_font_size("font_size")
	for action_index: int in 5:
		scene._latest_opponent_action_text = "AI action %d" % action_index
		scene._latest_opponent_action_turn_number = 8
		controller.call("refresh_hand", scene)
	var final_font_size := label.get_theme_font_size("font_size")

	return run_checks([
		assert_eq(
			final_font_size,
			first_font_size,
			"Repeated opponent action refreshes must not multiply an already-overridden portrait font size"
		),
		assert_eq(
			label.custom_minimum_size,
			Vector2(360, 182),
			"Repeated AI HUD refreshes must keep one deterministic hand-area position and size"
		),
	])


func test_training_waiting_hud_resets_stale_horizontal_scroll_before_centering_text() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 8)
	scene._portrait_active = true
	scene.size = Vector2(390, 844)
	scene._hand_scroll.custom_minimum_size = Vector2(360, 120)
	scene._hand_scroll.size = Vector2(360, 120)
	scene._hand_container.custom_minimum_size = Vector2(900, 182)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	scene._hand_scroll.scroll_horizontal = 180
	var reproduced_stale_scroll := scene._hand_scroll.scroll_horizontal > 0

	controller.call("refresh_hand", scene)
	var label := scene._hand_container.get_node("HandWaitingLabel") as Label
	var result := run_checks([
		assert_true(reproduced_stale_scroll, "The regression setup must reproduce a previously scrolled hand rail"),
		assert_eq(scene._hand_scroll.scroll_horizontal, 0, "AI waiting text must reset stale hand-card scrolling before it is centered"),
		assert_eq(scene._hand_container.alignment, BoxContainer.ALIGNMENT_CENTER, "Training-mode AI text must own a centered hand row"),
		assert_eq(label.custom_minimum_size.x, 360.0, "Training-mode AI text must use the visible rail width, not stale card content width"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_refresh_hand_centers_windows_cards_in_explicit_hand_rail_after_draw() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(0, 8)
	scene._portrait_active = false
	scene.size = Vector2(1280, 720)
	scene._hand_scroll.size = Vector2(900, 182)
	scene._hand_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	scene._hand_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scene._hand_container.custom_minimum_size = Vector2(0, 182)
	scene._gsm.game_state.players[0].hand = [
		_hand_test_card("Drawn A"),
		_hand_test_card("Drawn B"),
		_hand_test_card("Drawn C"),
	]

	controller.call("refresh_hand", scene)

	return run_checks([
		assert_eq(scene._hand_container.alignment, BoxContainer.ALIGNMENT_CENTER, "Windows hand cards must remain centered after a draw refresh"),
		assert_eq(scene._hand_container.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "The Windows hand row must continue filling the visible rail"),
		assert_eq(scene._hand_container.custom_minimum_size.x, 900.0, "Centering must use an explicit rail width instead of relying on transient ScrollContainer expansion"),
		assert_eq(scene._hand_container.get_child_count(), 3, "The draw refresh must preserve all visible hand cards"),
	])


func test_windows_overflowing_hand_preserves_user_scroll_during_refresh() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(0, 8)
	scene._portrait_active = false
	scene.size = Vector2(1280, 720)
	scene._hand_scroll.size = Vector2(520, 182)
	for index: int in 8:
		scene._gsm.game_state.players[0].hand.append(_hand_test_card("Card %d" % index))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	controller.call("refresh_hand", scene)
	await tree.process_frame
	scene._hand_scroll.scroll_horizontal = 240
	var scroll_before_refresh := scene._hand_scroll.scroll_horizontal

	controller.call("refresh_hand", scene)
	var result := run_checks([
		assert_true(scroll_before_refresh > 0, "The regression setup must create an overflowing Windows hand"),
		assert_eq(scene._hand_scroll.scroll_horizontal, scroll_before_refresh, "Refreshing an overflowing hand must not steal the user's scroll position"),
		assert_eq(scene._hand_container.alignment, BoxContainer.ALIGNMENT_CENTER, "Overflowing hands may scroll while keeping the same deterministic row contract"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_hand_surface_stabilization_repairs_a_late_landscape_layout_pass() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(0, 8)
	scene._portrait_active = false
	scene.size = Vector2(1280, 720)
	scene._hand_scroll.size = Vector2(900, 182)
	scene._gsm.game_state.players[0].hand = [
		_hand_test_card("Stable A"),
		_hand_test_card("Stable B"),
	]
	controller.call("refresh_hand", scene)

	# Reproduce the responsive/fullscreen layout pass that used to overwrite
	# the content-aware hand metrics after the draw refresh had completed.
	scene._hand_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	scene._hand_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scene._hand_container.custom_minimum_size.x = 0.0
	controller.call("stabilize_hand_surface_layout", scene)

	return run_checks([
		assert_eq(scene._hand_container.alignment, BoxContainer.ALIGNMENT_CENTER, "A late Windows layout pass must not leave the hand row left-aligned"),
		assert_eq(scene._hand_container.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Hand stabilization must restore the landscape fill contract"),
		assert_eq(scene._hand_container.custom_minimum_size.x, 900.0, "Hand stabilization must restore the current visible rail width"),
	])


func test_refresh_hand_restores_portrait_card_row_after_waiting_text() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 8)
	scene._portrait_active = true
	scene._hand_scroll.custom_minimum_size = Vector2(360, 120)

	controller.call("refresh_hand", scene)
	scene._gsm.game_state.current_player_index = 0
	controller.call("refresh_hand", scene)

	return run_checks([
		assert_eq(scene._hand_container.alignment, BoxContainer.ALIGNMENT_BEGIN, "Portrait hand card row should return to left-start alignment after the waiting label is removed"),
		assert_eq(scene._hand_container.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "Portrait hand card row should return to shrink-begin sizing for horizontal scrolling"),
		assert_eq(scene._hand_container.custom_minimum_size.x, 0.0, "Portrait hand card row should not keep the waiting label's full-width minimum"),
	])
