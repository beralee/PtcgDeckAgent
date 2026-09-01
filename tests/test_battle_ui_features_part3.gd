## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本

extends "res://tests/helpers/BattleUIFeaturesShared.gd"

const UcisCompilerScript = preload("res://scripts/engine/ucis/UcisInteractionCompiler.gd")

func test_battle_scene_earthen_vessel_empty_search_touch_continue_consumes_card() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.deck.append_array([
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
		CardInstance.create(_make_pokemon_cd("Deck Pokemon", 90, "C"), 0),
	])

	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var earthen_vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	earthen_vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	player.hand.append_array([earthen_vessel, discard_cost])

	battle_scene.call("_try_play_trainer_with_interaction", 0, earthen_vessel)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var pending_index := int(battle_scene.get("_pending_effect_step_index"))
	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var current_step_id := ""
	if pending_index >= 0 and pending_index < pending_steps.size() and pending_steps[pending_index] is Dictionary:
		current_step_id = str((pending_steps[pending_index] as Dictionary).get("id", ""))
	var continue_option := _action_hud_option_at_index(battle_scene, 0)

	_emit_action_hud_touch_tap(continue_option, 0, Vector2(24, 24))

	var result := run_checks([
		assert_eq(current_step_id, "empty_search_resolution", "Earthen Vessel should be waiting on the empty-search resolution option before the mobile tap"),
		assert_true(continue_option != null, "Earthen Vessel empty-search dialog should render a continue option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A mobile ScreenTouch tap on continue should resolve the empty-search dialog"),
		assert_true(earthen_vessel in player.discard_pile, "Touching continue should consume Earthen Vessel"),
		assert_true(discard_cost in player.discard_pile, "Touching continue should pay Earthen Vessel's discard cost"),
	])

	battle_scene.free()
	return result


func test_battle_scene_earthen_vessel_energy_search_accepts_confirm_pressed_without_modal_origin() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var earthen_vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	earthen_vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	var energy_a := CardInstance.create(_make_energy_cd("Basic Energy A", "C"), 0)
	var energy_b := CardInstance.create(_make_energy_cd("Basic Energy B", "C"), 0)
	player.hand.append_array([earthen_vessel, discard_cost])
	player.deck.append_array([energy_a, energy_b])

	battle_scene.call("_try_play_trainer_with_interaction", 0, earthen_vessel)
	battle_scene.call("_on_dialog_card_chosen", 0)
	var pending_index := int(battle_scene.get("_pending_effect_step_index"))
	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var current_step_id := ""
	if pending_index >= 0 and pending_index < pending_steps.size() and pending_steps[pending_index] is Dictionary:
		current_step_id = str((pending_steps[pending_index] as Dictionary).get("id", ""))
	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	var empty_row := battle_scene.get("_dialog_utility_row") as HBoxContainer
	var empty_button := empty_row.find_child("LibrarySearchEmptySelectionButton", true, false) as Button if empty_row != null else null
	var no_selection_button := battle_scene.get("_dialog_cancel") as Button
	if no_selection_button != null:
		battle_scene.call("_on_dialog_cancel")

	var result := run_checks([
		assert_eq(current_step_id, "search_energy", "Precondition: Earthen Vessel should be waiting on the Basic Energy search step"),
		assert_null(empty_button, "Portrait Earthen Vessel search should not stack a separate empty-selection action above the footer"),
		assert_true(no_selection_button != null and no_selection_button.visible and no_selection_button.text == "不选择", "Portrait Earthen Vessel search should reuse the footer cancel slot for no-selection"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Explicit empty-selection action should resolve the Energy search"),
		assert_true(earthen_vessel in player.discard_pile, "Earthen Vessel should resolve after choosing no Energy"),
		assert_true(discard_cost in player.discard_pile, "Earthen Vessel should still pay its discard cost"),
		assert_true(energy_a in player.deck, "Choosing no Energy should leave the first Basic Energy in deck"),
		assert_true(energy_b in player.deck, "Choosing no Energy should leave the second Basic Energy in deck"),
		assert_false(energy_a in player.hand, "Choosing no Energy should not move the first Basic Energy to hand"),
		assert_false(energy_b in player.hand, "Choosing no Energy should not move the second Basic Energy to hand"),
	])

	battle_scene.free()
	return result


func test_battle_scene_try_play_trainer_with_interaction_respects_item_play_rules() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.SETUP
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand.append(nest_ball)
	player.deck.append(CardInstance.create(_make_pokemon_cd("Target", 70, "C"), 0))

	battle_scene.call("_try_play_trainer_with_interaction", 0, nest_ball)
	var log_rtl: RichTextLabel = battle_scene.get("_log_list") as RichTextLabel
	var log_text := log_rtl.get_parsed_text().strip_edges() if log_rtl != null else ""
	var latest_log := ""
	if not log_text.is_empty():
		var lines := log_text.split("\n")
		latest_log = lines[lines.size() - 1]

	return run_checks([
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Items should not enter the interaction flow when the play rules currently forbid them"),
		assert_true(nest_ball in player.hand, "Blocked trainer interactions should leave the card in hand"),
		assert_true(latest_log.length() > 0, "Blocked trainer interactions should explain why the card cannot currently be used"),
	])


func test_battle_scene_send_out_positions_panel_upward() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_send_out_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_field_interaction_position")), "top", "Own bench selection should move the field panel upward"),
	])


func test_battle_scene_boss_orders_positions_panel_downward() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active

	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := EffectBossOrdersScript.new()
	var card := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Opponent-only targets should move the field panel downward"),
	])


func test_battle_scene_electric_generator_positions_panel_upward() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]

	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Own bench energy targets should move the field panel upward"),
	])


func test_battle_scene_field_interaction_panel_metrics_follow_play_card_size() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.call("_ensure_field_interaction_panel")
	battle_scene.set("_play_card_size", Vector2(112, 156))
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(1366, 768))

	var panel: PanelContainer = battle_scene.get("_field_interaction_panel")
	var scroll: ScrollContainer = battle_scene.get("_field_interaction_scroll")
	var row: HBoxContainer = battle_scene.get("_field_interaction_row")

	return run_checks([
		assert_eq(scroll.custom_minimum_size.y, 202.0, "Field interaction card strip should reserve touch scrollbar clearance below cards"),
		assert_eq(panel.custom_minimum_size.y, 288.0, "Field interaction panel height should be derived from the card strip instead of drifting"),
		assert_gte(panel.custom_minimum_size.x, 680.0, "Field interaction panel width should remain wide enough for multi-card assignment UI"),
		assert_true(bool(scroll.size_flags_vertical & Control.SIZE_SHRINK_CENTER), "Field interaction scroll should shrink vertically"),
		assert_eq(row.custom_minimum_size.y, 156.0, "Field interaction card row should stay card-height"),
		assert_eq(row.size_flags_vertical, Control.SIZE_SHRINK_BEGIN, "Field interaction card row should start above the scrollbar lane"),
		assert_true(bool(panel.size_flags_vertical & Control.SIZE_SHRINK_CENTER), "Field interaction panel should shrink vertically"),
	])


func test_battle_scene_field_interaction_metrics_preserve_top_position() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	battle_scene.set("_play_card_size", Vector2(112, 156))

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(1366, 768))

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Field interaction metric refresh should preserve upward docking for own targets"),
	])


func test_battle_scene_landscape_grouped_energy_switch_sources_keep_room_after_layout_refresh() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_play_card_size", Vector2(112, 156))
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "L"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Active", "L"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "L"), 0))
	bench.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Bench", "L"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := EffectEnergySwitchScript.new()
	var card := CardInstance.create(_make_trainer_cd("Energy Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(1366, 768))

	var row := battle_scene.get("_field_interaction_row") as HBoxContainer
	var scroll := battle_scene.get("_field_interaction_scroll") as ScrollContainer
	var board := row.find_child("FieldEnergySourceBattlefield", true, false) as PanelContainer if row != null else null
	var cancel_button := battle_scene.get("_field_interaction_cancel_btn") as Button
	var confirm_button := battle_scene.get("_field_interaction_confirm_btn") as Button
	var cancel_style := cancel_button.get_theme_stylebox("normal") as StyleBoxFlat if cancel_button != null else null
	var confirm_style := confirm_button.get_theme_stylebox("normal") as StyleBoxFlat if confirm_button != null else null
	var source_card_count := 0
	var narrow_source_count := 0
	var short_source_count := 0
	var nodes: Array[Node] = []
	if row != null:
		nodes.append(row)
	while not nodes.is_empty():
		var node: Node = nodes.pop_front()
		if node is BattleCardView and node.has_meta("field_assignment_source_index"):
			var source_view := node as BattleCardView
			source_card_count += 1
			if source_view.custom_minimum_size.x < 92.0:
				narrow_source_count += 1
			if source_view.custom_minimum_size.y < 128.0:
				short_source_count += 1
		for child: Node in node.get_children():
			nodes.append(child)

	return run_checks([
		assert_not_null(board, "Energy Switch should render grouped source cards inside a battlefield-style board"),
		assert_true(row != null and board != null and row.custom_minimum_size.y >= board.custom_minimum_size.y, "Landscape metric refresh should not collapse the grouped Energy Switch source board back to one card lane"),
		assert_true(scroll != null and row != null and scroll.custom_minimum_size.y > row.custom_minimum_size.y, "Grouped source scroll should keep room for horizontal scrollbar clearance"),
		assert_eq(source_card_count, 2, "Energy Switch should render both attached Basic Energy cards as source choices"),
		assert_eq(narrow_source_count, 0, "Grouped field source cards should not use the old narrow mini-card width"),
		assert_eq(short_source_count, 0, "Grouped field source cards should keep the same readable minimum height as grouped dialog cards"),
		assert_true(cancel_button != null and bool(cancel_button.get_meta("field_interaction_hud_button", false)), "Landscape field-assignment cancel button should use the unified HUD button style"),
		assert_true(confirm_button != null and bool(confirm_button.get_meta("field_interaction_hud_button", false)), "Landscape field-assignment confirm button should use the unified HUD button style"),
		assert_true(cancel_style != null and cancel_style.border_color.a > 0.8, "Landscape field-assignment cancel button should have a visible HUD border"),
		assert_true(confirm_style != null and confirm_style.border_color.a > 0.8, "Landscape field-assignment confirm button should have a visible HUD border"),
	])


func test_grand_tree_followup_assignment_resets_expanded_field_panel_height() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_play_card_size", Vector2(112, 156))
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Seed", 70, "G"), 0))
	active.turn_played = 0
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "G"), 0))
	bench.attached_energy.append(CardInstance.create(_make_energy_cd("Bench Energy", "G"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench]

	var grouped_energy := CardInstance.create(_make_energy_cd("Old Energy", "G"), 0)
	var old_grouped_step: Dictionary = {
		"id": "old_grouped_assignment",
		"title": "Old grouped assignment",
		"ui_mode": "card_assignment",
		"source_items": [grouped_energy],
		"source_labels": ["Old Energy"],
		"source_groups": [{"slot": bench, "energy_indices": [0]}],
		"target_items": [active],
		"target_labels": ["Seed"],
		"min_select": 1,
		"max_select": 1,
	}
	battle_scene.call("_show_field_assignment_interaction", old_grouped_step)
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(1366, 768))
	var panel := battle_scene.get("_field_interaction_panel") as PanelContainer
	var expanded_height := panel.custom_minimum_size.y if panel != null else 0.0

	var stage1_cd := CardData.new()
	stage1_cd.name = "Tree Stage1"
	stage1_cd.card_type = "Pokemon"
	stage1_cd.stage = "Stage 1"
	stage1_cd.evolves_from = "Seed"
	stage1_cd.hp = 100
	stage1_cd.energy_type = "G"
	var stage2_cd := CardData.new()
	stage2_cd.name = "Tree Stage2"
	stage2_cd.card_type = "Pokemon"
	stage2_cd.stage = "Stage 2"
	stage2_cd.evolves_from = "Tree Stage1"
	stage2_cd.hp = 160
	stage2_cd.energy_type = "G"
	var stage1 := CardInstance.create(stage1_cd, 0)
	var stage2 := CardInstance.create(stage2_cd, 0)
	gsm.game_state.players[0].deck = [stage1, stage2]

	var effect := EffectGrandTreeScript.new()
	var stadium_cd := _make_trainer_cd("Great Tree", "Stadium", "")
	stadium_cd.effect_id = "grand_tree_ui_regression"
	var stadium := CardInstance.create(stadium_cd, 0)
	gsm.effect_processor.register_effect("grand_tree_ui_regression", effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "stadium", 0, steps, stadium)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(1366, 768))

	var followup_height := panel.custom_minimum_size.y if panel != null else 0.0
	var followup_scroll := battle_scene.get("_field_interaction_scroll") as ScrollContainer
	var followup_row := battle_scene.get("_field_interaction_row") as HBoxContainer

	return run_checks([
		assert_true(expanded_height > 288.0, "Test setup should first create a taller grouped assignment panel"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Grand Tree should keep the optional Stage 2 follow-up in field assignment mode"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "Grand Tree should advance from Stage 1 selection to its Stage 2 follow-up"),
		assert_eq(followup_height, 288.0, "Grand Tree follow-up should reset to the single-card-strip field panel height"),
		assert_true(followup_scroll != null and followup_scroll.custom_minimum_size.y <= 202.0, "Grand Tree follow-up scroll strip should not inherit a grouped-source height"),
		assert_true(followup_row != null and followup_row.custom_minimum_size.y <= 156.0, "Grand Tree follow-up row should stay at field card height and not cover the Bench"),
	])


func test_grand_tree_followup_compacts_after_stage2_source_selection() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_play_card_size", Vector2(112, 156))
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Seed", 70, "G"), 0))
	active.turn_played = 0
	gsm.game_state.players[0].active_pokemon = active

	var stage1_cd := CardData.new()
	stage1_cd.name = "Tree Stage1"
	stage1_cd.card_type = "Pokemon"
	stage1_cd.stage = "Stage 1"
	stage1_cd.evolves_from = "Seed"
	stage1_cd.hp = 100
	stage1_cd.energy_type = "G"
	var stage2_cd := CardData.new()
	stage2_cd.name = "Tree Stage2"
	stage2_cd.card_type = "Pokemon"
	stage2_cd.stage = "Stage 2"
	stage2_cd.evolves_from = "Tree Stage1"
	stage2_cd.hp = 160
	stage2_cd.energy_type = "G"
	var stage1 := CardInstance.create(stage1_cd, 0)
	var stage2 := CardInstance.create(stage2_cd, 0)
	gsm.game_state.players[0].deck = [stage1, stage2]

	var effect := EffectGrandTreeScript.new()
	var stadium_cd := _make_trainer_cd("Great Tree", "Stadium", "")
	stadium_cd.effect_id = "grand_tree_ui_compact"
	var stadium := CardInstance.create(stadium_cd, 0)
	gsm.effect_processor.register_effect("grand_tree_ui_compact", effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "stadium", 0, steps, stadium)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)

	var panel := battle_scene.get("_field_interaction_panel") as PanelContainer
	var expanded_height := panel.custom_minimum_size.y if panel != null else 0.0
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	var compact_height := panel.custom_minimum_size.y if panel != null else 0.0
	var scroll := battle_scene.get("_field_interaction_scroll") as ScrollContainer
	var row := battle_scene.get("_field_interaction_row") as HBoxContainer

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Grand Tree Stage 2 follow-up should stay in field target assignment mode"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "Grand Tree should still be resolving the Stage 2 follow-up"),
		assert_eq(int(battle_scene.get("_field_interaction_assignment_selected_source_index")), 0, "The Stage 2 source card should be selected"),
		assert_true(expanded_height >= 288.0, "Grand Tree Stage 2 source strip should start expanded before a source is selected"),
		assert_true(scroll != null and not scroll.visible, "Grand Tree Stage 2 source strip should collapse after choosing the evolution card"),
		assert_true(row != null and row.custom_minimum_size.y <= 1.0, "Grand Tree Stage 2 source row should not keep covering the Bench after source selection"),
		assert_true(compact_height <= 156.0, "Grand Tree Stage 2 field target prompt should use the compact battlefield HUD height"),
		assert_true(compact_height < expanded_height, "Grand Tree Stage 2 prompt should shrink after source selection"),
	])


func test_grand_tree_full_field_assignment_resolves_stage2_followup() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Seed", 70, "G"), 0))
	active.turn_played = 0
	gsm.game_state.players[0].active_pokemon = active

	var stage1_cd := CardData.new()
	stage1_cd.name = "Tree Stage1"
	stage1_cd.card_type = "Pokemon"
	stage1_cd.stage = "Stage 1"
	stage1_cd.evolves_from = "Seed"
	stage1_cd.hp = 100
	stage1_cd.energy_type = "G"
	var stage2_cd := CardData.new()
	stage2_cd.name = "Tree Stage2"
	stage2_cd.card_type = "Pokemon"
	stage2_cd.stage = "Stage 2"
	stage2_cd.evolves_from = "Tree Stage1"
	stage2_cd.hp = 160
	stage2_cd.energy_type = "G"
	var stage1 := CardInstance.create(stage1_cd, 0)
	var stage2 := CardInstance.create(stage2_cd, 0)
	gsm.game_state.players[0].deck = [stage1, stage2]

	var effect := EffectGrandTreeScript.new()
	var stadium_cd := _make_trainer_cd("Great Tree", "Stadium", "")
	stadium_cd.effect_id = "grand_tree_full_resolution"
	var stadium := CardInstance.create(stadium_cd, 0)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 0
	gsm.effect_processor.register_effect("grand_tree_full_resolution", effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "stadium", 0, steps, stadium)

	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_finalize_field_assignment_selection")

	var stack_size := active.pokemon_stack.size()
	var top_name := active.get_pokemon_name()
	var stage1_in_deck := stage1 in gsm.game_state.players[0].deck
	var stage2_in_deck := stage2 in gsm.game_state.players[0].deck

	return run_checks([
		assert_eq(stack_size, 3, "Grand Tree should resolve the selected optional Stage 2 follow-up"),
		assert_eq(top_name, "Tree Stage2", "Grand Tree full UI flow should leave the selected Stage 2 on top"),
		assert_false(stage1_in_deck, "Selected Stage 1 should leave the deck"),
		assert_false(stage2_in_deck, "Selected Stage 2 should leave the deck"),
		assert_eq(int(gsm.game_state.stadium_effect_used_turn), 3, "Using Grand Tree through the field UI should mark the Stadium action used"),
	])


func test_battle_scene_portrait_grouped_energy_switch_sources_keep_touch_room_after_layout_refresh() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_view_player", 0)
	battle_scene.call("_apply_portrait_layout", Vector2(390, 844))
	battle_scene.call("_setup_field_interaction_panel")

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Portrait Active", 120, "L"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Portrait Lightning Active", "L"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Portrait Bench", 90, "L"), 0))
	bench.attached_energy.append(CardInstance.create(_make_energy_cd("Portrait Lightning Bench", "L"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := EffectEnergySwitchScript.new()
	var card := CardInstance.create(_make_trainer_cd("Energy Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	if steps.is_empty():
		battle_scene.queue_free()
		GameManager.battle_layout_mode = previous_layout
		return assert_true(false, "Energy Switch should create an assignment step when attached Energy exists")
	battle_scene.call("_show_field_assignment_interaction", steps[0])
	battle_scene.call("_update_field_interaction_panel_metrics", Vector2(390, 844))

	var row := battle_scene.get("_field_interaction_row") as HBoxContainer
	var scroll := battle_scene.get("_field_interaction_scroll") as ScrollContainer
	var panel := battle_scene.get("_field_interaction_panel") as PanelContainer
	var board := row.find_child("FieldEnergySourceBattlefield", true, false) as PanelContainer if row != null else null
	var source_card_count := 0
	var narrow_source_count := 0
	var short_source_count := 0
	var flexible_source_count := 0
	var nodes: Array[Node] = []
	if row != null:
		nodes.append(row)
	while not nodes.is_empty():
		var node: Node = nodes.pop_front()
		if node is BattleCardView and node.has_meta("field_assignment_source_index"):
			var source_view := node as BattleCardView
			source_card_count += 1
			if source_view.custom_minimum_size.x < 104.0:
				narrow_source_count += 1
			if source_view.custom_minimum_size.y < 146.0:
				short_source_count += 1
			if source_view.size_flags_horizontal != Control.SIZE_SHRINK_CENTER:
				flexible_source_count += 1
		for child: Node in node.get_children():
			nodes.append(child)

	var result := run_checks([
		assert_not_null(board, "Portrait Energy Switch should render grouped source cards inside the battlefield-style board"),
		assert_true(row != null and board != null and row.custom_minimum_size.y >= board.custom_minimum_size.y, "Portrait metric refresh should not collapse the grouped Energy Switch source board back to one card lane"),
		assert_true(scroll != null and row != null and scroll.custom_minimum_size.y > row.custom_minimum_size.y, "Portrait grouped source scroll should keep room for horizontal scrollbar clearance"),
		assert_true(panel != null and scroll != null and panel.custom_minimum_size.y >= scroll.custom_minimum_size.y + 180.0, "Portrait grouped source panel should reserve room for the large popup controls below the board"),
		assert_eq(source_card_count, 2, "Portrait Energy Switch should render both attached Basic Energy cards as source choices"),
		assert_eq(narrow_source_count, 0, "Portrait grouped field source cards should keep the wider touch-card minimum"),
		assert_eq(short_source_count, 0, "Portrait grouped field source cards should keep the taller touch-card minimum"),
		assert_eq(flexible_source_count, 0, "Portrait grouped field source cards should use fixed horizontal sizing inside the scroll board"),
	])
	battle_scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_battle_scene_electric_generator_allows_two_field_assignments() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]

	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 1)
	battle_scene.call("_handle_field_assignment_target_index", 1)

	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")
	var cancel_button := battle_scene.get("_field_interaction_cancel_btn") as Button
	var confirm_button := battle_scene.get("_field_interaction_confirm_btn") as Button
	var cancel_style := cancel_button.get_theme_stylebox("normal") as StyleBoxFlat if cancel_button != null else null
	var confirm_style := confirm_button.get_theme_stylebox("normal") as StyleBoxFlat if confirm_button != null else null

	return run_checks([
		assert_eq(assignments.size(), 2, "Electric Generator should keep accepting a second assignment when two Lightning Energy cards are revealed"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Electric Generator should stay in assignment mode until the player confirms"),
		assert_true(cancel_button != null and bool(cancel_button.get_meta("field_interaction_hud_button", false)), "Electric Generator assignment cancel should use the unified HUD button style"),
		assert_true(confirm_button != null and bool(confirm_button.get_meta("field_interaction_hud_button", false)), "Electric Generator assignment confirm should use the unified HUD button style"),
		assert_true(cancel_style != null and cancel_style.border_color.a > 0.8, "Electric Generator assignment cancel should have a visible HUD border"),
		assert_true(confirm_style != null and confirm_style.border_color.a > 0.8, "Electric Generator assignment confirm should have a visible HUD border"),
	])


func test_battle_scene_prime_catcher_repositions_between_opponent_and_own_steps() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var my_active := PokemonSlot.new()
	my_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("My Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = my_active
	var my_bench := PokemonSlot.new()
	my_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("My Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [my_bench]

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := EffectPrimeCatcherScript.new()
	var card := CardInstance.create(_make_trainer_cd("Prime Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var first_position: String = str(battle_scene.get("_field_interaction_position"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_position, "bottom", "Prime Catcher opponent-target step should place the panel downward"),
		assert_eq(second_position, "top", "Prime Catcher own-switch step should move the panel upward"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Prime Catcher second step should still use field slot selection"),
	])


func test_battle_scene_psychic_embrace_switches_from_dialog_to_field_target() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var gardevoir := PokemonSlot.new()
	var gardevoir_card := CardInstance.create(_make_pokemon_cd("Gardevoir ex", 310, "P"), 0)
	gardevoir_card.card_data.effect_id = "abca39bc2f5c5e8da3e8fd3db4b19886"
	gardevoir.pokemon_stack.append(gardevoir_card)
	gsm.game_state.players[0].active_pokemon = gardevoir

	var drifloon := PokemonSlot.new()
	drifloon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Drifloon", 70, "P"), 0))
	gsm.game_state.players[0].bench = [drifloon]
	gsm.game_state.players[0].discard_pile = [CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)]

	var effect := AbilityPsychicEmbraceScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(gardevoir_card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "ability", 0, steps, gardevoir_card, gardevoir, 0)
	var first_pending: String = str(battle_scene.get("_pending_choice"))
	var first_field_mode: String = str(battle_scene.get("_field_interaction_mode"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_pending: String = str(battle_scene.get("_pending_choice"))
	var second_field_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_pending, "effect_interaction", "Psychic Embrace should start inside the effect interaction flow"),
		assert_eq(first_field_mode, "", "Discard energy selection should still use the dialog UI"),
		assert_eq(second_pending, "effect_interaction", "After selecting an energy, Psychic Embrace should continue to the target step"),
		assert_eq(second_field_mode, "slot_select", "Pokemon target selection should switch to field slot UI"),
		assert_eq(second_position, "top", "Own Psychic target selection should move the field panel upward"),
	])


func test_battle_scene_energy_switch_rejects_same_slot_target_in_field_assignment() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning A", "L"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := EffectEnergySwitchScript.new()
	var card := CardInstance.create(_make_trainer_cd("Energy Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	var step: Dictionary = steps[0].duplicate(true) if not steps.is_empty() else {}
	step["max_select"] = 2
	steps = [step]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var initial_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var initial_position: String = str(battle_scene.get("_field_interaction_position"))
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	var rejected_count: int = (battle_scene.get("_field_interaction_assignment_entries") as Array).size()

	battle_scene.call("_handle_field_assignment_target_index", 1)
	var accepted_entries: Array = battle_scene.get("_field_interaction_assignment_entries")
	var accepted_target: Variant = (accepted_entries[0] as Dictionary).get("target") if not accepted_entries.is_empty() else null

	return run_checks([
		assert_eq(initial_mode, "assignment", "Energy Switch should use field assignment UI"),
		assert_eq(initial_position, "top", "Own Energy Switch targets should move the field panel upward"),
		assert_eq(rejected_count, 0, "Energy Switch should reject assigning an energy back onto the same source Pokemon"),
		assert_eq(accepted_entries.size(), 1, "Energy Switch should accept a different target Pokemon"),
		assert_eq(accepted_target, bench, "Accepted assignment should point to the other Pokemon"),
	])


func test_battle_scene_energy_switch_source_click_allows_immediate_slot_target() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning A", "L"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := EffectEnergySwitchScript.new()
	var card := CardInstance.create(_make_trainer_cd("Energy Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	var step: Dictionary = steps[0].duplicate(true) if not steps.is_empty() else {}
	step["max_select"] = 2
	steps = [step]
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	battle_scene.set("_modal_input_slot_suppress_until_msec", 0)
	battle_scene.set("_hand_drag_suppress_click_until_msec", Time.get_ticks_msec() + 10000)

	battle_scene.call("_on_field_assignment_source_chosen", 0)
	var suppression_after_source_click := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))
	var hand_drag_suppressed_after_source_click := bool(battle_scene.call("_is_hand_drag_click_suppressed"))

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var target_click_consumed := bool(battle_scene.call("_consume_modal_slot_input_if_needed", click, "my_bench_0"))
	if not target_click_consumed:
		battle_scene.call("_handle_field_assignment_target_index", 1)

	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")
	var first_assignment: Dictionary = assignments[0] if not assignments.is_empty() else {}

	var result := run_checks([
		assert_eq(suppression_after_source_click, 0, "Choosing an Energy Switch source should not arm modal slot suppression for the intended target click"),
		assert_false(hand_drag_suppressed_after_source_click, "Choosing an Energy Switch source should clear stale hand drag suppression for subsequent hand taps"),
		assert_false(target_click_consumed, "The immediate target Pokemon click after choosing source Energy should not be swallowed by modal slot suppression"),
		assert_eq(assignments.size(), 1, "The immediate target Pokemon click after choosing source Energy should create the assignment"),
		assert_eq(first_assignment.get("target"), bench, "Immediate target click should resolve to the clicked Benched Pokemon"),
	])
	battle_scene.free()
	return result


func test_battle_scene_raging_bolt_bellowing_thunder_uses_energy_multiselect_dialog() -> String:
	var battle_scene = _make_battle_scene_stub()
	var dialog_box := PanelContainer.new()
	battle_scene.set("_dialog_box", dialog_box)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_cd := _make_pokemon_cd("Raging Bolt ex", 240, "N")
	attacker_cd.attacks = [
		{"name": "Burst Roar", "cost": "C", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x", "text": "", "is_vstar_power": false},
	]
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	gsm.game_state.players[0].active_pokemon = attacker

	var bench_bolt := PokemonSlot.new()
	bench_bolt.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	bench_bolt.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	var bench_ogerpon_a := PokemonSlot.new()
	bench_ogerpon_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Teal Mask Ogerpon ex", 210, "G"), 0))
	bench_ogerpon_a.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy A", "G"), 0))
	var bench_ogerpon_b := PokemonSlot.new()
	bench_ogerpon_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Teal Mask Ogerpon ex", 210, "G"), 0))
	bench_ogerpon_b.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy B", "G"), 0))
	gsm.game_state.players[0].bench = [bench_bolt, bench_ogerpon_a, bench_ogerpon_b]

	var effect := AttackDiscardBasicEnergyFromFieldDamageScript.new(70, 1)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), attacker_cd.attacks[1], gsm.game_state)
	var attack_effects: Array[BaseEffect] = [effect]
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker.get_top_card(), attacker, 1, attacker_cd.attacks[1], attack_effects)
	var card_row: HBoxContainer = battle_scene.get("_dialog_card_row")
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	var dialog_card_size: Vector2 = battle_scene.get("_dialog_card_size")
	var expected_compact_size := Vector2(maxf(92.0, dialog_card_size.x * 0.68), maxf(128.0, dialog_card_size.y * 0.68))
	var dialog_overlay := battle_scene.get("_dialog_overlay") as Panel
	var dialog_box_after_show := battle_scene.get("_dialog_box") as PanelContainer
	var overlay_style := dialog_overlay.get_theme_stylebox("panel") as StyleBoxFlat if dialog_overlay != null else null
	var dialog_box_style := dialog_box_after_show.get_theme_stylebox("panel") as StyleBoxFlat if dialog_box_after_show != null else null
	var battlefield := card_row.find_child("EnergyDiscardBattlefield", true, false) as PanelContainer
	var battlefield_style := battlefield.get_theme_stylebox("panel") as StyleBoxFlat if battlefield != null else null
	var active_label := card_row.find_child("EnergyDiscardActiveLabel", true, false) as Label
	var bench_label := card_row.find_child("EnergyDiscardBenchLabel", true, false) as Label
	var active_lane := card_row.find_child("EnergyDiscardActiveLane", true, false) as HBoxContainer
	var bench_lane := card_row.find_child("EnergyDiscardBenchLane", true, false) as HBoxContainer
	var group_positions: Array[String] = []
	var group_names: Array[String] = []
	var energy_choice_indices: Array[int] = []
	var pokemon_header_count := 0
	var card_line_count := 0
	var compact_card_count := 0
	var wrong_compact_card_size_count := 0
	var nodes: Array[Node] = card_row.get_children()
	while not nodes.is_empty():
		var node: Node = nodes.pop_front()
		if node is PanelContainer and String(node.name).begins_with("EnergyDiscardGroup"):
			group_positions.append(str(node.get_meta("energy_group_slot_position", "")))
			group_names.append(str(node.get_meta("energy_group_pokemon_name", "")))
		if node is HBoxContainer and String(node.name) == "EnergyGroupCardLine":
			card_line_count += 1
		if node is BattleCardView:
			var card_view := node as BattleCardView
			compact_card_count += 1
			if card_view.custom_minimum_size != expected_compact_size:
				wrong_compact_card_size_count += 1
			var choice_index := int(card_view.get_meta("dialog_choice_index", -1))
			if choice_index >= 0:
				energy_choice_indices.append(choice_index)
			elif card_view.card_data != null and card_view.card_data.card_type != "Basic Energy":
				pokemon_header_count += 1
		for nested: Node in node.get_children():
			nodes.append(nested)
	battle_scene.call("_on_dialog_card_chosen", 0)
	var first_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	battle_scene.call("_on_dialog_card_chosen", 1)
	var second_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()

	return run_checks([
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Bellowing Thunder should open a card dialog for attached Energy"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "Bellowing Thunder should not mark field Pokemon as selectable or selected"),
		assert_not_null(battlefield, "Bellowing Thunder should render the selection as one battlefield-style board"),
		assert_not_null(active_label, "Bellowing Thunder should label the active Pokemon row"),
		assert_not_null(bench_label, "Bellowing Thunder should label the bench row"),
		assert_eq(active_label.text if active_label != null else "", "战斗宝可梦", "Bellowing Thunder active row label should be concise"),
		assert_eq(bench_label.text if bench_label != null else "", "备战区", "Bellowing Thunder bench row label should be concise"),
		assert_eq(active_label.get_theme_font_size("font_size") if active_label != null else -1, 14, "Bellowing Thunder row labels should use small text"),
		assert_eq(bench_label.get_theme_font_size("font_size") if bench_label != null else -1, 14, "Bellowing Thunder row labels should use small text"),
		assert_not_null(active_lane, "Bellowing Thunder should render the active Pokemon lane above the bench"),
		assert_not_null(bench_lane, "Bellowing Thunder should render the bench lane below the active Pokemon"),
		assert_true(active_lane != null and bench_lane != null and active_lane.get_index() < bench_lane.get_index(), "Bellowing Thunder should place the active lane above the bench lane"),
		assert_eq(active_lane.get_child_count() if active_lane != null else -1, 1, "Bellowing Thunder battlefield should have one active slot on top"),
		assert_eq(bench_lane.get_child_count() if bench_lane != null else -1, 3, "Bellowing Thunder battlefield should put bench slots on the lower lane"),
		assert_eq(group_positions, ["战斗场", "备战区 1", "备战区 2", "备战区 3"], "Bellowing Thunder should distinguish duplicate Pokemon groups by field position"),
		assert_eq(group_names, ["Raging Bolt ex", "Raging Bolt ex", "Teal Mask Ogerpon ex", "Teal Mask Ogerpon ex"], "Bellowing Thunder group metadata should keep duplicate Pokemon names distinct"),
		assert_eq(overlay_style.bg_color.a if overlay_style != null else -1.0, 0.0, "Bellowing Thunder should not dim the battlefield behind the dialog"),
		assert_true(dialog_box_style != null and is_equal_approx(dialog_box_style.bg_color.a, 0.94), "Bellowing Thunder dialog box should be nearly opaque for readability"),
		assert_true(battlefield_style != null and is_equal_approx(battlefield_style.bg_color.a, 0.90), "Bellowing Thunder board wrapper should be nearly opaque for readability"),
		assert_eq(battlefield_style.border_width_left if battlefield_style != null else -1, 0, "Bellowing Thunder board wrapper should not draw an extra outer border"),
		assert_null(card_row.find_child("EnergyGroupSlotBadge", true, false), "Bellowing Thunder should not need explicit active/bench labels inside the WYSIWYG board"),
		assert_eq(pokemon_header_count, 4, "Bellowing Thunder should render one non-clickable Pokemon card per Energy owner"),
		assert_eq(card_line_count, 4, "Each Pokemon slot should put Pokemon and attached Energy on the same visual line"),
		assert_eq(compact_card_count, 8, "Bellowing Thunder should render four Pokemon cards plus four Energy cards"),
		assert_eq(wrong_compact_card_size_count, 0, "Pokemon cards and Energy cards should use the same compact card size"),
		assert_null(card_row.find_child("EnergyGroupTitle", true, false), "Bellowing Thunder should not repeat Pokemon names in extra title text"),
		assert_null(card_row.find_child("EnergyGroupSubtitle", true, false), "Bellowing Thunder should not show duplicate summary text inside each slot"),
		assert_null(card_row.find_child("EnergyGroupAttachedLabel", true, false), "Bellowing Thunder should not need repeated attached-Energy instruction text"),
		assert_eq(energy_choice_indices, [0, 1, 2, 3], "Bellowing Thunder should only make Energy cards selectable inside each Pokemon group"),
		assert_eq(dialog_items.size(), 4, "Bellowing Thunder dialog items should be the selected Basic Energy cards"),
		assert_eq(int(dialog_data.get("min_select", -1)), 0, "Bellowing Thunder should allow selecting no Energy"),
		assert_eq(int(dialog_data.get("max_select", -1)), 4, "Bellowing Thunder should allow selecting any visible Basic Energy"),
		assert_eq(first_selection, [0], "Clicking the first Energy should select it"),
		assert_eq(second_selection, [0, 1], "Clicking the second Energy should multi-select it without needing Pokemon targets"),
	])


func test_battle_scene_counter_catcher_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	gsm.game_state.players[0].prizes = [CardInstance.create(_make_pokemon_cd("My Prize 1", 60, "C"), 0), CardInstance.create(_make_pokemon_cd("My Prize 2", 60, "C"), 0), CardInstance.create(_make_pokemon_cd("My Prize 3", 60, "C"), 0)]
	gsm.game_state.players[1].prizes = [CardInstance.create(_make_pokemon_cd("Opp Prize", 60, "C"), 1)]
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := EffectCounterCatcherScript.new()
	var card := CardInstance.create(_make_trainer_cd("Counter Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Counter Catcher should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Counter Catcher should move the field panel downward for opponent targets"),
	])


func test_battle_scene_pokemon_catcher_heads_route_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := EffectPokemonCatcherScript.new(RiggedCoinFlipper.new([true]))
	var card := CardInstance.create(_make_trainer_cd("Pokemon Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Pokemon Catcher on heads should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Pokemon Catcher should move the field panel downward for opponent targets"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "Pokemon Catcher should expose opponent bench targets on the field"),
	])


func test_battle_scene_pokemon_catcher_waits_for_coin_animation_before_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	(battle_scene.get("_dialog_overlay") as Panel).visible = false
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	var coin_animator := FakeCoinAnimator.new()
	battle_scene.set("_coin_animator", coin_animator)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var flipper := RiggedCoinFlipper.new([true])
	flipper.coin_flipped.connect(func(result: bool) -> void:
		battle_scene.call("_on_coin_flipped", result)
	)
	var effect := EffectPokemonCatcherScript.new(flipper)
	var card := CardInstance.create(_make_trainer_cd("Pokemon Catcher", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	var delayed_pending_choice := str(battle_scene.get("_pending_choice"))
	var delayed_field_mode := str(battle_scene.get("_field_interaction_mode"))
	var delayed_coin_results: Array = coin_animator.played_results.duplicate()

	battle_scene.call("_on_coin_animation_finished")
	await Engine.get_main_loop().process_frame

	return run_checks([
		assert_eq(delayed_pending_choice, "effect_interaction", "Coin-flip follow-up prompts should stay in effect_interaction while the animation is running"),
		assert_eq(delayed_field_mode, "", "Pokemon Catcher should not show field slot selection before the coin animation finishes"),
		assert_eq(delayed_coin_results, [true], "Pokemon Catcher should start the coin animation immediately after the shared flipper emits"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Pokemon Catcher should show field slot selection after the coin animation finishes"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "Pokemon Catcher should still expose opponent bench targets after the coin animation"),
	])


func test_battle_scene_hoothoot_triple_stab_plays_all_three_coin_animations() -> String:
	var battle_scene = _make_battle_scene_stub()
	var coin_animator := FakeCoinAnimator.new()
	battle_scene.set("_coin_animator", coin_animator)

	# Triple Stab resolves all three flips synchronously. The battle UI must retain
	# the two later results while the first Tween is still playing.
	battle_scene.call("_on_coin_flipped", true)
	battle_scene.call("_on_coin_flipped", false)
	battle_scene.call("_on_coin_flipped", true)
	var first_animation_results: Array = coin_animator.played_results.duplicate()
	var queued_after_first: Array = (battle_scene.get("_coin_flip_queue") as Array).duplicate()

	battle_scene.call("_on_coin_animation_finished")
	await Engine.get_main_loop().process_frame
	var second_animation_results: Array = coin_animator.played_results.duplicate()

	battle_scene.call("_on_coin_animation_finished")
	await Engine.get_main_loop().process_frame
	var third_animation_results: Array = coin_animator.played_results.duplicate()

	battle_scene.call("_on_coin_animation_finished")
	await Engine.get_main_loop().process_frame

	return run_checks([
		assert_eq(first_animation_results, [true], "Hoothoot should start by displaying the first of its three coin results"),
		assert_eq(queued_after_first, [false, true], "Hoothoot should retain the other two synchronous coin results in order"),
		assert_eq(second_animation_results, [true, false], "Finishing the first animation should display the second result"),
		assert_eq(third_animation_results, [true, false, true], "Triple Stab should visibly display all three coin results"),
		assert_false(bool(battle_scene.get("_coin_animating")), "The coin overlay should finish only after the third result"),
		assert_true((battle_scene.get("_coin_flip_queue") as Array).is_empty(), "The three-result queue should be empty after all animations finish"),
	])


func test_battle_scene_ai_owned_coin_followup_resumes_after_animation() -> String:
	var previous_mode: int = GameManager.current_mode
	var battle_scene = _make_battle_scene_stub()
	battle_scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	var coin_animator := FakeCoinAnimator.new()
	battle_scene.set("_coin_animator", coin_animator)
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	battle_scene.set("_ai_opponent", ai)
	GameManager.current_mode = GameManager.GameMode.VS_AI

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var ai_player: PlayerState = gsm.game_state.players[1]
	var aroma_card := CardInstance.create(_make_trainer_cd("Capturing Aroma", "Item", ""), 1)
	aroma_card.card_data.effect_id = "7c0b20e121c9d0e0d2d8a43524f7494e"
	ai_player.hand.append(aroma_card)
	var evolution := CardData.new()
	evolution.name = "AI Evolution"
	evolution.card_type = "Pokemon"
	evolution.stage = "Stage1"
	evolution.hp = 90
	ai_player.deck.append(CardInstance.create(evolution, 1))

	var flipper := RiggedCoinFlipper.new([true])
	flipper.coin_flipped.connect(func(result: bool) -> void:
		battle_scene.call("_on_coin_flipped", result)
	)
	var effect := EffectCapturingAromaScript.new(flipper)
	gsm.effect_processor.register_effect("7c0b20e121c9d0e0d2d8a43524f7494e", effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(aroma_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 1, steps, aroma_card)
	battle_scene.call("_maybe_run_ai")

	var scheduled_before_finish: bool = bool(battle_scene.get("_ai_step_scheduled"))
	var pending_before_finish: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_on_coin_animation_finished")
	await Engine.get_main_loop().process_frame
	var scheduled_after_finish: bool = bool(battle_scene.get("_ai_step_scheduled"))
	if scheduled_after_finish:
		battle_scene.call("_run_ai_step")

	var pending_after_resume: String = str(battle_scene.get("_pending_choice"))
	var ai_resumed_after_finish: bool = scheduled_after_finish or pending_after_resume == ""
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(pending_before_finish, "effect_interaction", "AI-owned coin follow-up should remain pending while the coin animation is still running"),
		assert_false(scheduled_before_finish, "AI should not be scheduled before the coin animation finishes"),
		assert_eq(coin_animator.played_results, [true], "Capturing Aroma should enqueue exactly one shared coin animation"),
		assert_true(ai_resumed_after_finish, "When the coin animation finishes, BattleScene should schedule or complete the AI-owned follow-up step"),
		assert_eq(pending_after_resume, "", "After the AI resolves the resumed Capturing Aroma step, the interaction should complete"),
	])


func test_battle_scene_switch_cart_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Basic Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := EffectSwitchCartScript.new()
	var card := CardInstance.create(_make_trainer_cd("Switch Cart", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Switch Cart should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Switch Cart should move the field panel upward for own bench targets"),
	])


func test_battle_scene_mirage_gate_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench]
	for i: int in 7:
		gsm.game_state.players[0].lost_zone.append(CardInstance.create(_make_trainer_cd("Lost %d" % i, "Item", ""), 0))
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Fire", "R"), 0),
		CardInstance.create(_make_energy_cd("Water", "W"), 0),
		CardInstance.create(_make_energy_cd("Fire Extra", "R"), 0),
	]

	var effect := EffectMirageGateScript.new()
	var card := CardInstance.create(_make_trainer_cd("Mirage Gate", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Mirage Gate should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Mirage Gate should move the field panel upward for own Pokemon targets"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Mirage Gate should expose up to two different basic energy source cards"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Mirage Gate should expose own field Pokemon targets"),
	])


func test_battle_scene_mirage_gate_logs_when_the_deck_has_no_basic_energy() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	for i: int in 7:
		gsm.game_state.players[0].lost_zone.append(CardInstance.create(_make_trainer_cd("Lost %d" % i, "Item", ""), 0))
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
	]

	var mirage_gate_cd := _make_trainer_cd("Mirage Gate", "Item", "")
	mirage_gate_cd.effect_id = "15b5bf0cc2edae9b9cd0bc24389ad355"
	var card := CardInstance.create(mirage_gate_cd, 0)
	gsm.game_state.players[0].hand.append(card)
	battle_scene.call("_try_play_trainer_with_interaction", 0, card)
	var log_rtl: RichTextLabel = battle_scene.get("_log_list") as RichTextLabel
	var log_text := log_rtl.get_parsed_text().strip_edges() if log_rtl != null else ""
	var last_log := ""
	if not log_text.is_empty():
		var lines := log_text.split("\n")
		last_log = lines[lines.size() - 1]

	return run_checks([
		assert_true(not log_text.is_empty(), "Mirage Gate should leave a UI log entry when it whiffs"),
		assert_eq(last_log, "牌库里没有可附着的基本能量，幻象之门没有附着任何能量。", "Mirage Gate should explain the whiff to the player"),
		assert_contains(gsm.game_state.players[0].discard_pile, card, "Mirage Gate should still be discarded after the whiff"),
	])


func test_battle_scene_carmine_click_allows_first_turn_supporter_exception() -> String:
	var scene = _make_battle_scene_stub()

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 1
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.supporter_used_this_turn = false
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var own_active := PokemonSlot.new()
	own_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Own Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = own_active

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active

	scene._gsm = gsm
	scene._view_player = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	for i: int in 4:
		player.hand.append(CardInstance.create(_make_pokemon_cd("Discard %d" % i, 60, "C"), 0))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_pokemon_cd("Draw %d" % i, 60, "C"), 0))

	var card_data := _make_trainer_cd("CSV8C_199 Carmine", "Supporter", "")
	card_data.effect_id = "8150af4062192998497e376ad931bea4"
	var card := CardInstance.create(card_data, 0)
	player.hand.append(card)
	gsm.effect_processor.register_effect(card_data.effect_id, EffectCarmineScript.new())

	scene.call("_on_hand_card_clicked", card, PanelContainer.new())

	return run_checks([
		assert_eq(player.hand.size(), 5, "BattleScene should let Carmine discard the hand and draw 5 on the first turn going first"),
		assert_eq(player.discard_pile.size(), 5, "BattleScene should discard Carmine plus the previous hand cards"),
		assert_true(gsm.game_state.supporter_used_this_turn, "BattleScene should still mark the supporter as used after Carmine resolves"),
	])


func test_battle_scene_rare_candy_uses_one_canonical_evolution_frontier() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var basic := PokemonSlot.new()
	var basic_cd := _make_pokemon_cd("Charmander", 70, "R")
	basic.pokemon_stack.append(CardInstance.create(basic_cd, 0))
	basic.turn_played = 1
	gsm.game_state.players[0].active_pokemon = basic

	var stage2_cd := CardData.new()
	stage2_cd.name = "Charizard ex"
	stage2_cd.card_type = "Pokemon"
	stage2_cd.stage = "Stage 2"
	stage2_cd.evolves_from = "Charmeleon"
	stage2_cd.hp = 330
	stage2_cd.energy_type = "R"
	var stage2_card := CardInstance.create(stage2_cd, 0)
	gsm.game_state.players[0].hand = [stage2_card]

	var stage1_cd := CardData.new()
	stage1_cd.name = "Charmeleon"
	stage1_cd.card_type = "Pokemon"
	stage1_cd.stage = "Stage 1"
	stage1_cd.evolves_from = "Charmander"
	stage1_cd.hp = 100
	stage1_cd.energy_type = "R"
	gsm.game_state.players[0].deck = [CardInstance.create(stage1_cd, 0)]

	var effect := EffectRareCandyScript.new()
	var card := CardInstance.create(_make_trainer_cd("Rare Candy", "Item", ""), 0)
	card.card_data.effect_id = "ui_test_rare_candy_ucis"
	gsm.effect_processor.register_effect(card.card_data.effect_id, effect)
	gsm.game_state.players[0].hand.append(card)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var first_field_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var metadata := UcisCompilerScript.metadata_for_step(steps[0])

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))

	return run_checks([
		assert_eq(first_field_mode, "", "Rare Candy's compound evolution options should use the dialog UI"),
		assert_eq(int(metadata.get("context_raw", -1)), 37, "Rare Candy must expose the official EVOLVE context"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "One accepted EVOLVE option should complete the interaction"),
		assert_eq(basic.pokemon_stack.size(), 2, "The selected EVOLVE option should bind both the Stage 2 card and legal target"),
		assert_true(basic.get_top_card() == stage2_card, "Rare Candy should evolve the selected Basic with the selected Stage 2 card"),
		assert_false(stage2_card in gsm.game_state.players[0].hand, "The evolved Stage 2 card should leave the hand"),
	])


func test_battle_scene_bench_damage_on_play_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_user := PokemonSlot.new()
	var user_card := CardInstance.create(_make_pokemon_cd("Bench User", 80, "P"), 0)
	bench_user.pokemon_stack.append(user_card)
	bench_user.turn_played = 3
	gsm.game_state.players[0].bench = [bench_user]

	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := AbilityBenchDamageOnPlayScript.new(10, 2)
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, bench_user, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Bench damage on play should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Opponent bench multi-select should move the field panel downward"),
		assert_eq(int(data.get("min_select", 0)), 2, "Bench damage on play should require selecting the full number of targets"),
		assert_eq(int(data.get("max_select", 0)), 2, "Bench damage on play should cap selections at the printed number of targets"),
	])


func test_battle_scene_star_portal_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.vstar_power_used = [false, false]
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var palkia_slot := PokemonSlot.new()
	var palkia_card := CardInstance.create(_make_pokemon_cd("Palkia VSTAR", 280, "W"), 0)
	palkia_slot.pokemon_stack.append(palkia_card)
	gsm.game_state.players[0].active_pokemon = palkia_slot
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Water", 90, "W"), 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Water A", "W"), 0),
		CardInstance.create(_make_energy_cd("Water B", "W"), 0),
		CardInstance.create(_make_energy_cd("Water C", "W"), 0),
	]

	var effect := AbilityStarPortalScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(palkia_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, palkia_card, palkia_slot, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Star Portal should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Star Portal should move the field panel upward for own Pokemon targets"),
		assert_eq(int(data.get("source_items", []).size()), 3, "Star Portal should expose up to three Water Energy cards"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Star Portal should expose Water Pokemon targets on the field"),
	])


func test_battle_scene_sadas_vitality_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var ancient_active := PokemonSlot.new()
	var ancient_cd := _make_pokemon_cd("Ancient Active", 120, "F")
	ancient_cd.is_tags = PackedStringArray(["Ancient"])
	ancient_active.pokemon_stack.append(CardInstance.create(ancient_cd, 0))
	gsm.game_state.players[0].active_pokemon = ancient_active

	var ancient_bench := PokemonSlot.new()
	var ancient_bench_cd := _make_pokemon_cd("Ancient Bench", 90, "F")
	ancient_bench_cd.is_tags = PackedStringArray(["Ancient"])
	ancient_bench.pokemon_stack.append(CardInstance.create(ancient_bench_cd, 0))
	gsm.game_state.players[0].bench = [ancient_bench]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Basic A", "F"), 0),
		CardInstance.create(_make_energy_cd("Basic B", "F"), 0),
	]

	var effect := EffectSadasVitalityScript.new()
	var card := CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var data: Dictionary = battle_scene.get("_field_interaction_data")
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 1)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Sada's Vitality should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Sada's Vitality should move the field panel upward for own Ancient targets"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Sada's Vitality should expose discard energy cards as sources"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Sada's Vitality should expose Ancient Pokemon targets on the field"),
		assert_eq(int(data.get("max_assignments_per_target", 0)), 1, "Sada's Vitality should declare one energy per Ancient target"),
		assert_eq(assignments.size(), 1, "Sada's Vitality UI should reject assigning two energy to the same Ancient target"),
	])


func test_battle_scene_sadas_vitality_field_assignment_confirm_resolves_effect() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var raging_bolt := PokemonSlot.new()
	var raging_bolt_cd := _make_pokemon_cd("Raging Bolt ex", 240, "N")
	raging_bolt_cd.is_tags = PackedStringArray(["Ancient"])
	raging_bolt.pokemon_stack.append(CardInstance.create(raging_bolt_cd, 0))
	gsm.game_state.players[0].active_pokemon = raging_bolt

	var energy := CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0)
	var second_energy := CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0)
	gsm.game_state.players[0].discard_pile = [energy, second_energy]
	for i: int in 3:
		gsm.game_state.players[0].deck.append(CardInstance.create(_make_pokemon_cd("Sada Draw %d" % i, 60, "C"), 0))

	var sada_cd := _make_trainer_cd("Professor Sada's Vitality", "Supporter", "")
	sada_cd.effect_id = "651276c51911345aa091c1c7b87f3f4f"
	var sada := CardInstance.create(sada_cd, 0)
	gsm.game_state.players[0].hand.append(sada)

	var effect := EffectSadasVitalityScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(sada, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, sada)
	var source_row := battle_scene.get("_field_interaction_row") as HBoxContainer
	var source_card := source_row.get_child(0) as BattleCardView
	var source_press := InputEventScreenTouch.new()
	source_press.index = 0
	source_press.pressed = true
	source_press.position = Vector2(200, 80)
	source_card.handle_bridged_pointer_input(source_press)
	var source_jitter := InputEventScreenDrag.new()
	source_jitter.index = 0
	source_jitter.position = Vector2(216, 82)
	source_jitter.relative = Vector2(16, 2)
	source_card.handle_bridged_pointer_input(source_jitter)
	var source_release := InputEventScreenTouch.new()
	source_release.index = 0
	source_release.pressed = false
	source_release.position = Vector2(216, 82)
	source_card.handle_bridged_pointer_input(source_release)
	var selected_source_after_touch := int(battle_scene.get("_field_interaction_assignment_selected_source_index"))
	battle_scene.call("_handle_field_assignment_target_index", 0)
	var confirm_button := battle_scene.get("_field_interaction_confirm_btn") as Button
	var overlay := battle_scene.get("_field_interaction_overlay") as Control
	var enabled_after_assignment := confirm_button != null and not confirm_button.disabled
	if confirm_button != null:
		confirm_button.emit_signal("pressed")

	var result := run_checks([
		assert_eq(selected_source_after_touch, 0, "Sada's Vitality must accept a real Energy touch with normal 16px finger jitter"),
		assert_true(enabled_after_assignment, "Sada field assignment confirm should enable after one legal energy assignment"),
		assert_true(overlay != null and int(overlay.z_index) >= 300 and not overlay.z_as_relative, "Field assignment overlay should sit above portrait HUD/input layers"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Confirm should finish the pending effect interaction"),
		assert_true(energy in raging_bolt.attached_energy, "Confirm should attach the selected discard Energy to Raging Bolt"),
		assert_false(energy in gsm.game_state.players[0].discard_pile, "Attached Energy should leave the discard pile"),
		assert_true(second_energy in gsm.game_state.players[0].discard_pile, "Unselected discard Energy should remain when confirming fewer than the max assignments"),
		assert_true(sada in gsm.game_state.players[0].discard_pile, "Sada should be discarded after resolving"),
		assert_eq(gsm.game_state.players[0].hand.size(), 3, "Sada should draw three cards after attaching Energy"),
	])
	battle_scene.free()
	return result


func test_battle_scene_attach_from_deck_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	var source_card := CardInstance.create(_make_pokemon_cd("Attach Source", 130, "L"), 0)
	active.pokemon_stack.append(source_card)
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Target", 90, "L"), 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
	]

	var effect := AbilityAttachFromDeckScript.new("L", 2, "own", false, false)
	var steps: Array[Dictionary] = effect.get_interaction_steps(source_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, source_card, active, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Attach-from-deck abilities should route to field assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Attach-from-deck abilities should move the field panel upward for own targets"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Attach-from-deck abilities should expose matching deck energy cards"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Attach-from-deck abilities should expose own field Pokemon targets"),
	])


func test_battle_scene_attack_switch_self_to_bench_routes_real_attack_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	var attacker_card := CardInstance.create(_make_pokemon_cd("Attacker", 120, "P"), 0)
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "P"), 0))
	gsm.game_state.players[0].bench = [bench]

	var effect := AttackSwitchSelfToBenchScript.new()
	var attack_data := {"name": "Switch Strike"}
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, attack_data, gsm.game_state)
	var attack_effects: Array[BaseEffect] = [effect]
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0, {}, attack_effects)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Self-switch attacks should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "Self-switch attacks should move the field panel upward for own bench targets"),
	])


func test_battle_scene_attack_any_target_damage_routes_real_attack_to_opponent_field() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	var attacker_card := CardInstance.create(_make_pokemon_cd("Attacker", 120, "P"), 0)
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AttackAnyTargetDamageScript.new(100)
	var attack_data := {"name": "Any Target Hit"}
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, attack_data, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Chosen-target attacks should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Chosen-target attacks should move the field panel downward for opponent targets"),
		assert_eq(int(data.get("items", []).size()), 2, "Chosen-target attacks should expose both opponent active and bench Pokemon"),
	])


func test_battle_scene_raging_bolt_clicks_opponent_bench_and_resolves_lightning_storm() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for owner_index: int in 2:
		var player := PlayerState.new()
		player.player_index = owner_index
		gsm.game_state.players.append(player)

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV8C_161.json"))
	var raging_card := CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else null
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(raging_card, 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	gsm.game_state.players[0].active_pokemon = attacker

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 160, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 120, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 0)
	var first_mode := str(battle_scene.get("_field_interaction_mode"))
	var field_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	battle_scene.call("_try_handle_field_interaction_slot_click", "opp_bench_0", opp_bench)
	GameManager.current_mode = previous_mode

	var result := run_checks([
		assert_not_null(raging_card, "CSV8C_161 Raging Bolt should load for the production UI path"),
		assert_eq(first_mode, "slot_select", "Lightning Storm should open the battlefield target selector"),
		assert_true(field_map.has("opp_bench_0"), "Lightning Storm should map the opponent Bench slot as clickable"),
		assert_eq(opp_bench.damage_counters, 60, "Clicking the opponent Bench slot should deal attached Energy count x30 to that Bench Pokemon"),
		assert_eq(opp_active.damage_counters, 0, "A selected Bench target must not silently fall back to the opponent Active Pokemon"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "The target click should finish the attack interaction without leaving the UI stuck"),
	])
	battle_scene.free()
	return result


func test_battle_scene_self_damage_counter_attack_routes_real_attack_to_opponent_field() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	var attacker_card := CardInstance.create(_make_pokemon_cd("Scream Tail", 90, "P"), 0)
	attacker.pokemon_stack.append(attacker_card)
	attacker.damage_counters = 30
	gsm.game_state.players[0].active_pokemon = attacker

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AttackSelfDamageCounterTargetDamageScript.new(20)
	var attack_data := {"name": "Roaring Scream"}
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, attack_data, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Self-damage-counter attacks should route to field slot selection"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "Self-damage-counter attacks should move the field panel downward for opponent targets"),
	])


func test_csv6c_065_scream_tail_player_click_deals_damage_to_selected_bench_target() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	for owner_index: int in 2:
		var player := PlayerState.new()
		player.player_index = owner_index
		gsm.game_state.players.append(player)

	var scream_tail: CardData = CardDatabase.get_card("CSV6C", "065")
	if scream_tail == null:
		GameManager.current_mode = previous_mode
		battle_scene.free()
		return "Missing bundled CSV6C_065 Scream Tail"
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(scream_tail, 0))
	attacker.damage_counters = 60
	attacker.attached_energy = [
		CardInstance.create(_make_energy_cd("Psychic Energy 1", "P"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy 2", "P"), 0),
	]
	gsm.game_state.players[0].active_pokemon = attacker
	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 260, "M"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 260, "M"), 1))
	gsm.game_state.players[1].bench = [opp_bench]
	gsm.effect_processor.register_pokemon_card(scream_tail)

	var registered_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 1)
	var field_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	battle_scene.call("_try_handle_field_interaction_slot_click", "opp_bench_0", opp_bench)
	GameManager.current_mode = previous_mode

	var result := run_checks([
		assert_eq(registered_effects.size(), 1, "The real CSV6C_065 second attack should register exactly one native effect"),
		assert_true(registered_effects[0] is AttackSelfDamageCounterTargetDamage, "CSV6C_065 should register the self-damage-counter target effect"),
		assert_true(field_map.has("opp_bench_0"), "The player UI should expose the selected opponent Bench target"),
		assert_eq(opp_bench.damage_counters, 120, "Six damage counters should deal 120 damage to the selected Bench Pokemon"),
		assert_eq(opp_active.damage_counters, 0, "The chosen-target attack must not redirect to the opponent Active Pokemon"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "The attack target interaction should finish after the field click"),
	])
	gsm.prepare_for_disposal()
	battle_scene.free()
	return result


func test_scream_tail_bench_knockout_visual_completion_clears_gholdengo_card_view() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	for owner_index: int in 2:
		var player := PlayerState.new()
		player.player_index = owner_index
		gsm.game_state.players.append(player)
	if battle_scene.has_method("_sync_battle_scene_context_runtime"):
		battle_scene.call("_sync_battle_scene_context_runtime")

	var scream_tail: CardData = CardDatabase.get_card("CSV6C", "065")
	if scream_tail == null:
		GameManager.current_mode = previous_mode
		gsm.prepare_for_disposal()
		battle_scene.free()
		return "Missing bundled CSV6C_065 Scream Tail"
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(scream_tail, 0))
	attacker.damage_counters = 60
	attacker.attached_energy = [
		CardInstance.create(_make_energy_cd("Psychic Energy 1", "P"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy 2", "P"), 0),
	]
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].prizes = [CardInstance.create(_make_trainer_cd("Prize", "Item", ""), 0)]

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 260, "M"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var gholdengo_slot := PokemonSlot.new()
	var gholdengo_card := CardInstance.create(_make_pokemon_cd("Gholdengo ex", 260, "M"), 1)
	gholdengo_slot.pokemon_stack.append(gholdengo_card)
	gholdengo_slot.damage_counters = 140
	gsm.game_state.players[1].bench = [gholdengo_slot]
	gsm.effect_processor.register_pokemon_card(scream_tail)

	var bench_panel := PanelContainer.new()
	var bench_card_view := BattleCardViewScript.new()
	bench_panel.add_child(bench_card_view)
	bench_card_view.setup_from_instance(gholdengo_card, BattleCardView.MODE_SLOT_BENCH)
	battle_scene.set("_slot_card_views", {"opp_bench_0": bench_card_view})

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 1)
	battle_scene.call("_try_handle_field_interaction_slot_click", "opp_bench_0", gholdengo_slot)
	var removed_from_bench := gsm.game_state.players[1].bench.is_empty()
	var cleared_by_committed_state_refresh := bench_card_view.card_instance == null
	battle_scene.call("_refresh_field_after_visual_event", "knockout")
	GameManager.current_mode = previous_mode

	var result := run_checks([
		assert_true(removed_from_bench, "Scream Tail should already remove the defeated Gholdengo ex from the rule-state Bench"),
		assert_true(cleared_by_committed_state_refresh, "The regular committed-state refresh should clear the defeated Bench slot"),
		assert_null(bench_card_view.card_instance, "KO visual completion must clear the defeated Gholdengo ex card view immediately"),
	])
	gsm.prepare_for_disposal()
	bench_panel.free()
	battle_scene.free()
	return result


func test_battle_scene_attack_dialog_routes_ns_darmanitan_flamebody_cannon_to_bench_choice() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	if battle_scene.has_method("_sync_battle_scene_context_runtime"):
		battle_scene.call("_sync_battle_scene_context_runtime")

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var darmanitan_cd: CardData = CardDatabase.get_card("LEN_JTG", "27")
	if darmanitan_cd == null:
		return "Missing LEN_JTG_27 N's Darmanitan card data"
	gsm.effect_processor.register_pokemon_card(darmanitan_cd)
	var darmanitan := PokemonSlot.new()
	darmanitan.pokemon_stack.append(CardInstance.create(darmanitan_cd, 0))
	darmanitan.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy 1", "R"), 0))
	darmanitan.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy 2", "R"), 0))
	darmanitan.attached_energy.append(CardInstance.create(_make_energy_cd("Colorless Energy", "C"), 0))
	gsm.game_state.players[0].active_pokemon = darmanitan
	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opponent Active", 120, "G"), 1))
	gsm.game_state.players[1].active_pokemon = defender
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 120, "G"), 1))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 120, "G"), 1))
	gsm.game_state.players[1].bench = [bench_a, bench_b]

	battle_scene.set("_pending_choice", "attack")
	battle_scene.set("_dialog_data", {
		"player": 0,
		"attack_count": darmanitan_cd.attacks.size(),
	})
	battle_scene.call("_handle_dialog_choice_legacy", PackedInt32Array([1]))

	var pending_choice := str(battle_scene.get("_pending_choice"))
	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var step: Dictionary = pending_steps[0] if not pending_steps.is_empty() and pending_steps[0] is Dictionary else {}

	return run_checks([
		assert_eq(pending_choice, "effect_interaction", "Legacy attack dialog should route N's Darmanitan second attack to target selection"),
		assert_eq(str(step.get("id", "")), "opponent_bench_damage_targets", "Flamebody Cannon should ask for an opponent Bench Pokemon"),
		assert_eq(int(step.get("min_select", 0)), 1, "Flamebody Cannon should require exactly one Bench target"),
		assert_eq(int(step.get("max_select", 0)), 1, "Flamebody Cannon should cap selection at one Bench target"),
		assert_eq((step.get("items", []) as Array).size(), 2, "Flamebody Cannon should expose the opponent Bench choices"),
		assert_eq(bench_a.damage_counters, 0, "The attack should not auto-hit the first Bench Pokemon before the choice is made"),
		assert_eq(darmanitan.attached_energy.size(), 3, "The attack should not discard its Energy before the target choice is confirmed"),
	])


func test_battle_scene_tm_evolution_routes_granted_attack_targets_to_field_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Attacker", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = attacker

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Basic", 70, "R"), 0))
	gsm.game_state.players[0].bench = [bench]

	var evo_cd := CardData.new()
	evo_cd.name = "Bench Evolution"
	evo_cd.card_type = "Pokemon"
	evo_cd.stage = "Stage 1"
	evo_cd.evolves_from = "Bench Basic"
	evo_cd.hp = 110
	evo_cd.energy_type = "R"
	var decoy_cd := _make_pokemon_cd("Wrong Evolution", 90, "G")
	decoy_cd.stage = "Stage 1"
	decoy_cd.evolves_from = "Other Basic"
	gsm.game_state.players[0].deck = [
		CardInstance.create(evo_cd, 0),
		CardInstance.create(decoy_cd, 0),
	]

	var tool_card := CardInstance.create(_make_trainer_cd("TM Evolution", "Tool", ""), 0)
	tool_card.card_data.effect_id = "43386015be5c073ba2e5b9d3692ece3f"
	attacker.attached_tool = tool_card
	var effect := AttackTMEvolutionScript.new(2)
	var granted_attack: Dictionary = gsm.effect_processor.get_granted_attacks(attacker, gsm.game_state)[0]
	var steps: Array[Dictionary] = effect.get_granted_attack_interaction_steps(attacker, granted_attack, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "granted_attack", 0, steps, tool_card, attacker, 0, granted_attack)
	var first_field_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var first_field_position: String = str(battle_scene.get("_field_interaction_position"))
	var first_field_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	if first_field_mode == "slot_select":
		battle_scene.call("_handle_field_slot_select_index", 0)
	var pending_context: Dictionary = battle_scene.get("_pending_effect_context")
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var card_items: Array = dialog_data.get("card_items", [])
	var card_indices: Array = dialog_data.get("card_indices", [])

	return run_checks([
		assert_eq(first_field_mode, "slot_select", "TM Evolution should first route bench target selection to field slot UI"),
		assert_eq(first_field_position, "top", "TM Evolution should move the field panel upward for own bench targets"),
		assert_true(first_field_map.has("my_bench_0"), "TM Evolution should map the selectable bench target before deck search"),
		assert_eq(pending_context.get("evolution_bench", []), [bench], "TM Evolution should store the chosen bench target before opening the deck"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "TM Evolution should show the searched deck after the bench target is chosen"),
		assert_eq(card_items.size(), 2, "TM Evolution should still show the complete searched deck after target selection"),
		assert_eq(card_indices, [0, -1], "TM Evolution should disable non-matching evolution cards in the full-deck view"),
	])


func test_battle_scene_move_damage_counters_to_opponent_repositions_between_steps() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var user_slot := PokemonSlot.new()
	var munkidori_cd := _make_pokemon_cd("Munkidori", 90, "D")
	munkidori_cd.effect_id = "munkidori_counter_ui_test"
	munkidori_cd.abilities = [{"name": "亢奋脑力"}]
	user_slot.pokemon_stack.append(CardInstance.create(munkidori_cd, 0))
	user_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Dark Energy", "D"), 0))
	gsm.game_state.players[0].active_pokemon = user_slot

	var own_damaged := PokemonSlot.new()
	own_damaged.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Own Damaged", 120, "P"), 0))
	own_damaged.damage_counters = 30
	gsm.game_state.players[0].bench = [own_damaged]

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AbilityMoveDamageCountersToOpponentScript.new(3)
	gsm.effect_processor.register_effect("munkidori_counter_ui_test", effect)
	var user_card := user_slot.get_top_card()
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, user_slot, 0)
	var first_position: String = str(battle_scene.get("_field_interaction_position"))

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var second_position: String = str(battle_scene.get("_field_interaction_position"))

	return run_checks([
		assert_eq(first_position, "top", "Selecting the damaged own Pokemon should move the panel upward"),
		assert_eq(second_position, "bottom", "Selecting the opponent target should move the panel downward"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "counter_distribution", "The second step should use Dragapult-style counter distribution UI"),
	])


func test_battle_scene_move_opponent_damage_counters_keeps_panel_downward() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var effect := AbilityMoveOpponentDamageCountersScript.new()
	var alakazam_cd := _make_pokemon_cd("Radiant Alakazam", 130, "P")
	alakazam_cd.effect_id = "ui_test_radiant_alakazam"
	alakazam_cd.abilities = [{"name": "Painful Spoons", "text": ""}]
	gsm.effect_processor.register_effect(alakazam_cd.effect_id, effect)
	var user_slot := PokemonSlot.new()
	user_slot.pokemon_stack.append(CardInstance.create(alakazam_cd, 0))
	gsm.game_state.players[0].active_pokemon = user_slot

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	opp_active.damage_counters = 20
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var user_card := user_slot.get_top_card()
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, user_slot, 0)
	var first_position: String = str(battle_scene.get("_field_interaction_position"))
	var active_slot_id := str(battle_scene.call("_slot_id_from_slot", opp_active))
	var bench_slot_id := str(battle_scene.call("_slot_id_from_slot", opp_bench))

	battle_scene.call("_try_handle_field_interaction_slot_click", active_slot_id, opp_active)
	var second_position: String = str(battle_scene.get("_field_interaction_position"))
	var target_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	var target_field_mode := str(battle_scene.get("_field_interaction_mode"))

	battle_scene.call("_try_handle_field_interaction_slot_click", bench_slot_id, opp_bench)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))

	return run_checks([
		assert_eq(first_position, "bottom", "Opponent source selection should move the panel downward"),
		assert_eq(second_position, "bottom", "Opponent target selection should keep the panel downward"),
		assert_eq(target_field_mode, "slot_select", "The second step should still use field slot UI"),
		assert_false(target_map.has(active_slot_id), "Radiant Alakazam target UI should exclude the selected source Pokemon"),
		assert_true(target_map.has(bench_slot_id), "Radiant Alakazam target UI should keep the opponent Bench target selectable"),
		assert_eq(opp_active.damage_counters, 0, "Radiant Alakazam should remove two counters from the selected Active source"),
		assert_eq(opp_bench.damage_counters, 20, "Radiant Alakazam should place the moved counters on the selected Bench target"),
	])


func test_battle_scene_move_opponent_damage_counters_allows_bench_to_active() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var effect := AbilityMoveOpponentDamageCountersScript.new()
	var alakazam_cd := _make_pokemon_cd("Radiant Alakazam", 130, "P")
	alakazam_cd.effect_id = "ui_test_radiant_alakazam_bench_to_active"
	alakazam_cd.abilities = [{"name": "Painful Spoons", "text": ""}]
	gsm.effect_processor.register_effect(alakazam_cd.effect_id, effect)
	var user_slot := PokemonSlot.new()
	user_slot.pokemon_stack.append(CardInstance.create(alakazam_cd, 0))
	gsm.game_state.players[0].active_pokemon = user_slot

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	opp_bench.damage_counters = 20
	gsm.game_state.players[1].bench = [opp_bench]

	var user_card := user_slot.get_top_card()
	var steps: Array[Dictionary] = effect.get_interaction_steps(user_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, user_card, user_slot, 0)
	var active_slot_id := str(battle_scene.call("_slot_id_from_slot", opp_active))
	var bench_slot_id := str(battle_scene.call("_slot_id_from_slot", opp_bench))
	battle_scene.call("_try_handle_field_interaction_slot_click", bench_slot_id, opp_bench)
	var target_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")

	battle_scene.call("_try_handle_field_interaction_slot_click", active_slot_id, opp_active)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))

	return run_checks([
		assert_true(target_map.has(active_slot_id), "Radiant Alakazam target UI should allow moving counters to the opponent Active"),
		assert_false(target_map.has(bench_slot_id), "Radiant Alakazam target UI should exclude the selected Bench source"),
		assert_eq(opp_bench.damage_counters, 0, "Radiant Alakazam should remove two counters from the selected Bench source"),
		assert_eq(opp_active.damage_counters, 20, "Radiant Alakazam should place the moved counters on the selected Active target"),
	])


func test_battle_scene_loads_selected_background_texture() -> String:
	var previous_background := GameManager.selected_battle_background
	GameManager.selected_battle_background = "res://assets/ui/background1.png"
	var scene := BattleSceneScript.new()
	var resolved_path := scene._resolve_battle_backdrop_path()
	var loaded_texture := scene._load_battle_backdrop_texture()
	GameManager.selected_battle_background = previous_background

	return run_checks([
		assert_eq(resolved_path, "res://assets/ui/background1.png", "BattleScene 应解析到选中的背景路径"),
		assert_not_null(loaded_texture, "应能加载已选择的对战背景"),
	])


# ===================== 弃牌区数据测试 =====================

## 测试：弃牌区初始为空
func test_stadium_backdrop_resolves_area_zero_background() -> String:
	var coordinator := BattleStadiumBackdropCoordinatorScript.new()
	var stadium_cd := _make_trainer_cd("零之大空洞", "Stadium", "")
	stadium_cd.set_code = "CSV9C"
	stadium_cd.card_index = "207"
	stadium_cd.effect_id = "701eb0ccb34fe3d319ea1307bc36c1ef"
	var stadium := CardInstance.create(stadium_cd, 0)
	var resolved_path: String = coordinator.resolve_stadium_backdrop_path(stadium, "res://assets/ui/background.png")

	return run_checks([
		assert_eq(
			resolved_path,
			"res://assets/ui/stadium_backgrounds/area_zero_underdepths.webp",
			"Area Zero Underdepths should resolve to its dynamic stadium background"
		),
	])


func test_stadium_backdrop_resolves_calamitous_snowy_mountain_background() -> String:
	var coordinator := BattleStadiumBackdropCoordinatorScript.new()
	var stadium_cd := _make_trainer_cd("灾祸雪山", "Stadium", "")
	stadium_cd.name_en = "Calamitous Snowy Mountain"
	stadium_cd.set_code = "CSV3C"
	stadium_cd.card_index = "129"
	stadium_cd.effect_id = "ceac9ee87d5850880f7438665925dbd2"
	var stadium := CardInstance.create(stadium_cd, 0)
	var expected_path := "res://assets/ui/stadium_backgrounds/calamitous_snowy_mountain.webp"
	var resolved_path: String = coordinator.resolve_stadium_backdrop_path(stadium, "res://assets/ui/background.png")

	return run_checks([
		assert_eq(resolved_path, expected_path, "Calamitous Snowy Mountain should resolve to its dynamic stadium background"),
		assert_true(FileAccess.file_exists(expected_path), "Calamitous Snowy Mountain background asset should exist"),
	])


func test_stadium_backdrop_resolves_perilous_jungle_background() -> String:
	var coordinator := BattleStadiumBackdropCoordinatorScript.new()
	var stadium_cd := _make_trainer_cd("Perilous Jungle", "Stadium", "")
	stadium_cd.name_en = "Perilous Jungle"
	stadium_cd.set_code = "CSV7C"
	stadium_cd.card_index = "200"
	stadium_cd.effect_id = "16a6fb86a8ebd1cffc6f171250057d5c"
	var stadium := CardInstance.create(stadium_cd, 0)
	var resolved_path: String = coordinator.resolve_stadium_backdrop_path(stadium, "res://assets/ui/background.png")

	return run_checks([
		assert_eq(
			resolved_path,
			"res://assets/ui/stadium_backgrounds/perilous_jungle.webp",
			"Perilous Jungle should resolve to its dynamic stadium background"
		),
	])


func test_stadium_background_map_resources_exist_and_load() -> String:
	var file := FileAccess.open("res://data/stadium_backgrounds.json", FileAccess.READ)
	if file == null:
		return "Stadium background map should be readable"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return "Stadium background map should be a JSON object"

	var checks: Array[String] = []
	var mapped_count := 0
	for section: String in ["by_effect_id", "by_card_id", "by_name_en", "by_name"]:
		var section_value: Variant = (parsed as Dictionary).get(section, {})
		checks.append(assert_true(section_value is Dictionary, "Stadium background section should be a dictionary: %s" % section))
		if not section_value is Dictionary:
			continue
		for key_variant: Variant in (section_value as Dictionary).keys():
			var key := str(key_variant)
			var path := str((section_value as Dictionary).get(key_variant, ""))
			if key == "" or path == "":
				checks.append("Stadium background map should not contain empty keys or paths in %s" % section)
				continue
			mapped_count += 1
			checks.append(assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "Mapped stadium background should exist: %s => %s" % [key, path]))
			var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
			if texture == null and FileAccess.file_exists(path):
				var image := Image.load_from_file(ProjectSettings.globalize_path(path))
				if image != null and not image.is_empty():
					texture = ImageTexture.create_from_image(image)
			checks.append(assert_not_null(texture, "Mapped stadium background should load as texture: %s" % path))
	checks.append(assert_gte(mapped_count, 19, "Stadium background map should include the local Stadium card set"))
	return run_checks(checks)


func test_csv10c_stadium_cards_resolve_their_dynamic_backgrounds() -> String:
	var coordinator := BattleStadiumBackdropCoordinatorScript.new()
	var default_path := "res://assets/ui/background.png"
	var expected_by_card_id := {
		"214": "res://assets/ui/stadium_backgrounds/stones_cave.webp",
		"215": "res://assets/ui/stadium_backgrounds/ns_castle.webp",
		"216": "res://assets/ui/stadium_backgrounds/spikemuth_gym.webp",
		"217": "res://assets/ui/stadium_backgrounds/levincia.webp",
		"218": "res://assets/ui/stadium_backgrounds/postwick.webp",
		"219": "res://assets/ui/stadium_backgrounds/team_rocket_watchtower.webp",
		"220": "res://assets/ui/stadium_backgrounds/team_rocket_factory.webp",
		"286": "res://assets/ui/stadium_backgrounds/levincia.webp",
	}
	var checks: Array[String] = []
	for card_index_variant: Variant in expected_by_card_id.keys():
		var card_index := str(card_index_variant)
		var stadium_cd := _make_trainer_cd("CSV10C Stadium %s" % card_index, "Stadium", "")
		stadium_cd.set_code = "CSV10C"
		stadium_cd.card_index = card_index
		var resolved_path: String = coordinator.resolve_stadium_backdrop_path(
			CardInstance.create(stadium_cd, 0),
			default_path
		)
		checks.append(assert_eq(
			resolved_path,
			str(expected_by_card_id[card_index_variant]),
			"CSV10C_%s should resolve to its dynamic stadium background" % card_index
		))
	return run_checks(checks)


func test_all_bundled_stadium_cards_resolve_dynamic_backgrounds() -> String:
	var coordinator := BattleStadiumBackdropCoordinatorScript.new()
	var default_path := "res://assets/ui/background.png"
	var missing: Array[String] = []
	var stadium_count := 0
	for file_name: String in DirAccess.get_files_at("res://data/bundled_user/cards"):
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://data/bundled_user/cards/%s" % file_name, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Dictionary:
			continue
		var data := parsed as Dictionary
		if str(data.get("card_type", "")) != "Stadium":
			continue
		stadium_count += 1
		var card_data := _make_trainer_cd(str(data.get("name", "")), "Stadium", str(data.get("description", "")))
		card_data.name_en = str(data.get("name_en", ""))
		card_data.set_code = str(data.get("set_code", ""))
		card_data.card_index = str(data.get("card_index", ""))
		card_data.effect_id = str(data.get("effect_id", ""))
		var resolved_path: String = coordinator.resolve_stadium_backdrop_path(CardInstance.create(card_data, 0), default_path)
		if resolved_path == default_path:
			missing.append("%s_%s" % [card_data.set_code, card_data.card_index])
	return run_checks([
		assert_gte(stadium_count, 19, "The bundled card pool should include all currently supported Stadium cards"),
		assert_eq(missing, [], "Every bundled Stadium card should resolve a dynamic background"),
	])


func test_battle_scene_prize_slots_keep_fixed_grid_positions() -> String:
	var scene := BattleSceneScript.new()
	var slots: Array[BattleCardView] = []
	for _i: int in 6:
		var slot := BattleCardView.new()
		slot.set_clickable(false)
		slot.set_compact_preview(true)
		slot.setup_from_instance(null, BattleCardView.MODE_PREVIEW)
		slots.append(slot)

	var player := PlayerState.new()
	var prize_cards: Array[CardInstance] = []
	CardInstance.reset_id_counter()
	for i: int in 6:
		var card := CardInstance.create(_make_pokemon_cd("Prize%d" % i, 60, "C"), 0)
		card.face_up = false
		prize_cards.append(card)
	player.set_prizes(prize_cards)
	player.take_prize_from_slot(1)

	scene.call("_update_prize_slots", slots, player.get_prize_layout(), true)

	return run_checks([
		assert_true(slots[0].visible, "Filled prize slots should stay visible"),
		assert_eq(slots[0].mouse_filter, Control.MOUSE_FILTER_STOP, "Selectable Prize slots must keep receiving pointer input after refresh"),
		assert_true(slots[1].visible, "Empty fixed slot should still keep its grid position"),
		assert_true(slots[1].self_modulate.a < 0.1, "Taken prize slots should fade out instead of collapsing"),
		assert_true(slots[2].self_modulate.a > 0.9, "Neighbour prize slots should stay in place and visible"),
	])


func test_battle_scene_prize_selection_titles_highlight_and_reset() -> String:
	var scene = _make_battle_scene_stub()
	var my_title := Label.new()
	var opp_title := Label.new()
	var my_hud_title := Label.new()
	var opp_hud_title := Label.new()
	scene.set("_my_prizes_title", my_title)
	scene.set("_opp_prizes_title", opp_title)
	scene.set("_my_prize_hud_title", my_hud_title)
	scene.set("_opp_prize_hud_title", opp_hud_title)
	scene.set("_view_player", 0)
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", 0)
	scene.set("_pending_prize_remaining", 2)
	scene.call("_refresh_prize_titles")

	var pending_my_text: String = my_title.text
	var pending_opp_text: String = opp_title.text
	var pending_my_hud_text: String = my_hud_title.text
	var pending_my_color: Color = my_title.get_theme_color("font_color")
	var pending_my_hud_color: Color = my_hud_title.get_theme_color("font_color")
	var my_title_size: int = my_title.get_theme_font_size("font_size")
	var opp_title_size: int = opp_title.get_theme_font_size("font_size")

	scene.set("_pending_choice", "")
	scene.set("_pending_prize_player_index", -1)
	scene.set("_pending_prize_remaining", 0)
	scene.call("_refresh_prize_titles")

	return run_checks([
		assert_eq(pending_my_text, "选择奖赏卡：选2张", "Prize selection should replace the player title with the highlighted count prompt"),
		assert_eq(pending_my_hud_text, "选择奖赏卡：选2张", "Prize selection should also update the field HUD title"),
		assert_eq(pending_opp_text, "对方奖赏", "The non-selecting side should keep its default title"),
		assert_eq(pending_my_color, Color(1.0, 0.87, 0.34, 1.0), "Prize selection title should switch to the highlight color"),
		assert_eq(pending_my_hud_color, Color(1.0, 0.87, 0.34, 1.0), "Prize selection HUD title should switch to the highlight color"),
		assert_eq(my_title_size, 11, "Prize titles should be one size larger in the side panel"),
		assert_eq(opp_title_size, 11, "Opponent prize title should also be one size larger in the side panel"),
		assert_eq(my_title.text, "己方奖赏", "After prize selection, the player title should reset to its default text"),
		assert_eq(opp_title.text, "对方奖赏", "After prize selection, the opponent title should remain at its default text"),
		assert_eq(my_hud_title.text, "己方奖赏", "After prize selection, the HUD title should reset to its default text"),
		assert_eq(my_title.get_theme_color("font_color"), Color(0.93, 0.97, 1.0, 0.9), "After prize selection, the side-panel title should return to its normal color"),
		assert_eq(my_hud_title.get_theme_color("font_color"), Color(0.54, 0.9, 0.94, 0.9), "After prize selection, the HUD title should return to its normal color"),
	])


func test_discard_pile_initially_empty() -> String:
	var player := PlayerState.new()
	player.player_index = 0
	return run_checks([
		assert_eq(player.discard_pile.size(), 0, "初始弃牌区为空"),
	])


## 测试：弃牌区正确累积卡牌
func test_discard_pile_accumulates() -> String:
	var player := PlayerState.new()
	player.player_index = 0

	CardInstance.reset_id_counter()
	for i: int in 3:
		var cd := _make_trainer_cd("物品%d" % i, "Item", "效果%d" % i)
		var inst := CardInstance.create(cd, 0)
		player.discard_pile.append(inst)

	return run_checks([
		assert_eq(player.discard_pile.size(), 3, "弃牌区有3张"),
		assert_eq(player.discard_pile[0].card_data.name, "物品0", "第1张正确"),
		assert_eq(player.discard_pile[2].card_data.name, "物品2", "第3张正确"),
	])


## 测试：昏厥宝可梦及附着卡牌全部进入弃牌区
func test_knockout_all_cards_to_discard() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.player_index = 0

	# 构建一个带能量和道具的宝可梦
	var cd := _make_pokemon_cd("小火龙", 70, "R")
	var pokemon_inst := CardInstance.create(cd, 0)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(pokemon_inst)

	var energy_cd := _make_energy_cd("火能量", "R")
	var energy_inst := CardInstance.create(energy_cd, 0)
	slot.attached_energy.append(energy_inst)

	var tool_cd := _make_trainer_cd("力量头巾", "Tool", "+20伤害")
	var tool_inst := CardInstance.create(tool_cd, 0)
	slot.attached_tool = tool_inst

	# collect_all_cards 应返回所有卡牌
	var all_cards: Array[CardInstance] = slot.collect_all_cards()
	for card: CardInstance in all_cards:
		player.discard_pile.append(card)

	return run_checks([
		assert_gte(player.discard_pile.size(), 3, "弃牌区至少3张（宝可梦+能量+道具）"),
	])


# ===================== 卡牌详情文本测试 =====================

## 测试：宝可梦卡 CardData 包含完整信息
func test_pokemon_card_data_completeness() -> String:
	var cd := _make_pokemon_cd("小火龙", 70, "R")
	return run_checks([
		assert_eq(cd.name, "小火龙", "名称正确"),
		assert_eq(cd.hp, 70, "HP正确"),
		assert_eq(cd.energy_type, "R", "属性正确"),
		assert_eq(cd.weakness_energy, "W", "弱点属性正确"),
		assert_eq(cd.weakness_value, "×2", "弱点倍率正确"),
		assert_eq(cd.retreat_cost, 1, "撤退费用正确"),
		assert_eq(cd.attacks.size(), 2, "有2个招式"),
		assert_eq(cd.abilities.size(), 1, "有1个特性"),
		assert_eq(cd.attacks[0].get("name", ""), "撞击", "招式1名称正确"),
		assert_eq(cd.attacks[0].get("cost", ""), "RC", "招式1费用正确"),
	])


## 测试：训练家卡 CardData 包含描述
func test_trainer_card_data_description() -> String:
	var cd := _make_trainer_cd("博士的研究", "Supporter", "弃掉手牌抽7张")
	return run_checks([
		assert_eq(cd.name, "博士的研究", "名称正确"),
		assert_eq(cd.card_type, "Supporter", "类型正确"),
		assert_str_contains(cd.description, "抽7张", "描述包含关键信息"),
	])


## 测试：能量卡 energy_provides 正确
func test_energy_card_provides() -> String:
	var cd := _make_energy_cd("火能量", "R")
	return run_checks([
		assert_eq(cd.card_type, "Basic Energy", "类型正确"),
		assert_eq(cd.energy_provides, "R", "提供火能量"),
	])


func test_battle_scene_uses_effective_hp_for_bravery_charm() -> String:
	var battle_scene = BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var scream_tail := _make_pokemon_cd("吼叫尾", 90, "P")
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(scream_tail, 0))
	slot.damage_counters = 20
	var bravery_charm := CardData.new()
	bravery_charm.name = "勇气护符"
	bravery_charm.card_type = "Tool"
	bravery_charm.effect_id = "d1c2f018a644e662f2b6895fdfc29281"
	slot.attached_tool = CardInstance.create(bravery_charm, 0)
	gsm.game_state.players[0].active_pokemon = slot
	battle_scene._gsm = gsm

	var status: Dictionary = battle_scene._build_battle_status(slot)
	var overlay_text: String = battle_scene._slot_overlay_text(slot)
	var subtitle: String = battle_scene._dialog_choice_subtitle(slot, "")

	return run_checks([
		assert_eq(int(status.get("hp_current", 0)), 120, "战斗状态当前HP应显示勇气护符加成后的有效剩余HP"),
		assert_eq(int(status.get("hp_max", 0)), 140, "战斗状态最大HP应显示勇气护符加成后的有效最大HP"),
		assert_str_contains(overlay_text, "120/140", "战斗页覆盖文本应显示有效HP"),
		assert_str_contains(subtitle, "120/140", "选择弹窗副标题也应显示有效HP"),
	])


## 测试：宝可梦判定方法正确
func test_battle_scene_regidrago_copy_dragapult_injects_followup_assignment_step() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var regidrago_cd := _make_regidrago_vstar_cd()
	var dragapult_cd := _make_dragapult_ex_cd()
	gsm.effect_processor.register_pokemon_card(regidrago_cd)
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 1", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 2", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(dragapult_cd, 0))

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 220, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "P"), 1))
	bench_b.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)
	gsm.game_state.players[1].bench.append(bench_b)

	battle_scene.set("_gsm", gsm)
	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 0)

	var initial_steps: Array = battle_scene.get("_pending_effect_steps")
	var copied_step: Dictionary = initial_steps[0] if not initial_steps.is_empty() else {}
	var copied_items: Array = copied_step.get("items", [])
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var action_items: Array = dialog_data.get("action_items", [])
	var phantom_option: Dictionary = {}
	var phantom_action: Dictionary = {}
	var all_action_costs_are_apex := true
	for item: Variant in copied_items:
		if not (item is Dictionary):
			continue
		var attack: Dictionary = item.get("attack", {})
		if str(attack.get("name", "")) == "Phantom Dive":
			phantom_option = item
			break
	for action: Variant in action_items:
		if not (action is Dictionary):
			all_action_costs_are_apex = false
			continue
		var action_dict: Dictionary = action
		if str(action_dict.get("cost", "")) != "GGR":
			all_action_costs_are_apex = false
		if str(action_dict.get("title", "")) == "Phantom Dive":
			phantom_action = action_dict

	battle_scene.set("_pending_effect_context", {"copied_attack": [phantom_option]})
	battle_scene.set("_pending_effect_step_index", 1)
	battle_scene.call("_inject_followup_steps")

	var pending_attack_effects: Array = battle_scene.get("_pending_effect_attack_effects")
	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var has_followup := pending_steps.size() > 1 and str(pending_steps[1].get("id", "")) == "bench_damage_counters"
	var injected_step_count: int = pending_steps.size()

	battle_scene.set("_pending_effect_context", {
		"copied_attack": [phantom_option],
		"bench_damage_counters": [
			{"target": bench_a, "amount": 30},
			{"target": bench_b, "amount": 30},
		],
	})
	battle_scene.set("_pending_effect_step_index", 2)
	battle_scene.call("_inject_followup_steps")
	var final_steps: Array = battle_scene.get("_pending_effect_steps")

	return run_checks([
		assert_false(initial_steps.is_empty(), "巨龙无双应先进入复制招式交互"),
		assert_eq(str(dialog_data.get("presentation", "")), "action_hud", "巨龙无双复制招式弹窗应复用宝可梦行动 HUD"),
		assert_eq(action_items.size(), copied_items.size(), "巨龙无双 HUD 应为每个可复制招式显示一个选项"),
		assert_true(all_action_costs_are_apex, "巨龙无双 HUD 的招式费用应统一显示为巨龙无双费用"),
		assert_eq(pending_attack_effects.size(), 1, "攻击交互状态应保留原始攻击效果，供后续步骤注入使用"),
		assert_false(phantom_option.is_empty(), "复制招式列表中应包含 Phantom Dive"),
		assert_false(phantom_action.is_empty(), "HUD 选项中应包含 Phantom Dive"),
		assert_eq(str(phantom_action.get("cost", "")), "GGR", "Phantom Dive HUD 费用应显示巨龙无双的 GGR"),
		assert_true(str(phantom_action.get("meta", "")).contains("Dragapult ex"), "Phantom Dive HUD 元信息应显示来源宝可梦"),
		assert_true(has_followup, "选中 Phantom Dive 后应注入 bench_damage_counters 分配步骤"),
	])


func test_battle_scene_does_not_reinject_resolved_followup_steps() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var regidrago_cd := _make_regidrago_vstar_cd()
	var dragapult_cd := _make_dragapult_ex_cd()
	gsm.effect_processor.register_pokemon_card(regidrago_cd)
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 1", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 2", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(dragapult_cd, 0))

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 220, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "P"), 1))
	bench_b.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)
	gsm.game_state.players[1].bench.append(bench_b)

	battle_scene.set("_gsm", gsm)
	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 0)

	var initial_steps: Array = battle_scene.get("_pending_effect_steps")
	var copied_items: Array = (initial_steps[0] as Dictionary).get("items", []) if not initial_steps.is_empty() else []
	var phantom_option: Dictionary = {}
	for item: Variant in copied_items:
		if not (item is Dictionary):
			continue
		var attack: Dictionary = item.get("attack", {})
		if str(attack.get("name", "")) == "Phantom Dive":
			phantom_option = item
			break

	battle_scene.set("_pending_effect_context", {"copied_attack": [phantom_option]})
	battle_scene.set("_pending_effect_step_index", 1)
	battle_scene.call("_inject_followup_steps")
	var injected_count: int = (battle_scene.get("_pending_effect_steps") as Array).size()

	battle_scene.set("_pending_effect_context", {
		"copied_attack": [phantom_option],
		"bench_damage_counters": [
			{"target": bench_a, "amount": 30},
			{"target": bench_b, "amount": 30},
		],
	})
	battle_scene.set("_pending_effect_step_index", 2)
	battle_scene.call("_inject_followup_steps")
	var final_count: int = (battle_scene.get("_pending_effect_steps") as Array).size()

	return run_checks([
		assert_false(phantom_option.is_empty(), "Phantom Dive should still be available as a copied attack"),
		assert_eq(final_count, injected_count, "Resolved follow-up steps should not be injected a second time"),
	])


func test_battle_scene_regidrago_copy_dragapult_real_choice_enters_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var regidrago_cd := _make_regidrago_vstar_cd()
	var dragapult_cd := _make_dragapult_ex_cd()
	gsm.effect_processor.register_pokemon_card(regidrago_cd)
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 1", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass 2", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(dragapult_cd, 0))

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 220, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "P"), 1))
	bench_b.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)
	gsm.game_state.players[1].bench.append(bench_b)

	battle_scene.set("_gsm", gsm)
	battle_scene.call("_try_use_attack_with_interaction", 0, attacker, 0)

	var initial_steps: Array = battle_scene.get("_pending_effect_steps")
	var copied_items: Array = (initial_steps[0] as Dictionary).get("items", []) if not initial_steps.is_empty() else []
	var phantom_index: int = -1
	for i: int in copied_items.size():
		var item: Variant = copied_items[i]
		if not (item is Dictionary):
			continue
		var attack: Dictionary = item.get("attack", {})
		if str(attack.get("name", "")) == "Phantom Dive":
			phantom_index = i
			break

	if phantom_index >= 0:
		battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([phantom_index]))

	var pending_choice: String = battle_scene.get("_pending_choice")
	var field_interaction_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var steps_after_choice: Array = battle_scene.get("_pending_effect_steps")
	var has_assignment_step := steps_after_choice.size() > 1 and str(steps_after_choice[1].get("id", "")) == "bench_damage_counters"

	return run_checks([
		assert_gte(phantom_index, 0, "Phantom Dive should appear in the copied attack options"),
		assert_eq(pending_choice, "effect_interaction", "Selecting Phantom Dive should continue into the follow-up interaction flow"),
		assert_eq(field_interaction_mode, "counter_distribution", "Selecting Phantom Dive should switch into the counter distribution interaction mode"),
		assert_true(has_assignment_step, "The queued follow-up step should be bench_damage_counters"),
	])


func test_battle_scene_dragapult_phantom_dive_action_hud_counter_distribution_accepts_immediate_bench_click() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var dragapult_cd := _make_dragapult_ex_cd()
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic", "P"), 0))
	gsm.game_state.players[0].active_pokemon = attacker

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 320, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "P"), 1))
	bench_b.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)
	gsm.game_state.players[1].bench.append(bench_b)

	battle_scene.call("_show_pokemon_action_dialog", 0, attacker, true)

	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var phantom_action_index: int = -1
	for i: int in actions.size():
		var action: Variant = actions[i]
		if not (action is Dictionary):
			continue
		var action_dict: Dictionary = action
		if str(action_dict.get("type", "")) == "attack" and int(action_dict.get("attack_index", -1)) == 1:
			phantom_action_index = i
			break

	var phantom_option := _action_hud_option_at_index(battle_scene, phantom_action_index)
	_emit_action_hud_mouse_click(phantom_option, Vector2(18, 18), Vector2(360, 180))

	var mode_after_attack := str(battle_scene.get("_field_interaction_mode"))
	var pending_after_attack := str(battle_scene.get("_pending_choice"))
	var index_map_after_attack: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	var broad_guard_cleared := int(battle_scene.get("_modal_input_slot_suppress_until_msec")) <= Time.get_ticks_msec()

	battle_scene.call("_on_counter_distribution_amount_chosen", 6)
	_emit_slot_mouse_click(battle_scene, "opp_bench_0", Vector2(620, 360))

	return run_checks([
		assert_gte(phantom_action_index, 0, "Dragapult action HUD should expose Phantom Dive as the second attack"),
		assert_not_null(phantom_option, "Phantom Dive HUD option should be rendered"),
		assert_eq(pending_after_attack, "effect_interaction", "Phantom Dive should enter the follow-up interaction flow"),
		assert_eq(mode_after_attack, "counter_distribution", "Phantom Dive should show the bench counter distribution UI"),
		assert_true(index_map_after_attack.has("opp_bench_0"), "Counter distribution should target the opponent Bench"),
		assert_true(broad_guard_cleared, "Field counter distribution must clear the broad modal slot guard"),
		assert_eq(bench_a.damage_counters, 60, "The immediate Bench click after choosing 6 counters should be accepted"),
		assert_eq(defender.damage_counters, 200, "Resolving Phantom Dive after counter assignment should deal active damage"),
	])


func test_battle_scene_portrait_ns_zoroark_night_joker_blocks_same_position_copied_attack_echo() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var zoroark_cd: CardData = CardDatabase.get_card("LEN_JTG", "98")
	var reshiram_cd: CardData = CardDatabase.get_card("LEN_JTG", "116")
	if zoroark_cd == null or reshiram_cd == null:
		return "LEN_JTG_98 or LEN_JTG_116 fixture missing"
	gsm.effect_processor.register_pokemon_card(zoroark_cd)
	gsm.effect_processor.register_pokemon_card(reshiram_cd)

	var zoroark := PokemonSlot.new()
	zoroark.pokemon_stack.append(CardInstance.create(zoroark_cd, 0))
	zoroark.turn_played = 0
	zoroark.damage_counters = 30
	zoroark.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy A", "D"), 0))
	zoroark.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy B", "D"), 0))
	gsm.game_state.players[0].active_pokemon = zoroark

	var bench_reshiram := PokemonSlot.new()
	bench_reshiram.pokemon_stack.append(CardInstance.create(reshiram_cd, 0))
	bench_reshiram.turn_played = 0
	gsm.game_state.players[0].bench.append(bench_reshiram)

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Night Joker Defender", 300, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	battle_scene.call("_show_pokemon_action_dialog", 0, zoroark, true)
	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var night_joker_action_index := -1
	for i: int in actions.size():
		var action: Variant = actions[i]
		if action is Dictionary and str((action as Dictionary).get("type", "")) == "attack" and int((action as Dictionary).get("attack_index", -1)) == 0:
			night_joker_action_index = i
			break

	var night_joker_option := _action_hud_option_at_index(battle_scene, night_joker_action_index)
	var shared_position := Vector2(520, 520)
	_emit_action_hud_touch_tap(night_joker_option, 0, shared_position)
	var pending_after_night_joker := str(battle_scene.get("_pending_choice"))
	var dialog_data_after_night_joker: Dictionary = battle_scene.get("_dialog_data")
	var copied_action_items: Array = dialog_data_after_night_joker.get("action_items", [])
	var copied_option := _action_hud_option_at_index(battle_scene, 0)

	_emit_action_hud_touch_tap(copied_option, 0, shared_position)
	var pending_after_echo := str(battle_scene.get("_pending_choice"))
	var damage_after_echo := defender.damage_counters
	var copied_option_after_echo := _action_hud_option_at_index(battle_scene, 0)

	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	battle_scene.set("_modal_input_slot_suppress_until_msec", 0)
	_emit_action_hud_touch_tap(copied_option_after_echo, 0, shared_position)

	return run_checks([
		assert_gte(night_joker_action_index, 0, "Portrait N's Zoroark action HUD should expose Night Joker"),
		assert_not_null(night_joker_option, "Night Joker HUD option should be rendered"),
		assert_eq(pending_after_night_joker, "effect_interaction", "Choosing Night Joker should open the copied Bench attack HUD"),
		assert_eq(str(dialog_data_after_night_joker.get("presentation", "")), "action_hud", "Night Joker copied attack choices should render as an action HUD"),
		assert_gte(copied_action_items.size(), 2, "Night Joker should expose both Benched N's Reshiram attacks"),
		assert_not_null(copied_option, "Night Joker copied attack HUD should render the first copied attack option"),
		assert_eq(pending_after_echo, "effect_interaction", "The same-position portrait touch echo must not auto-select the first copied attack"),
		assert_eq(damage_after_echo, 0, "The same-position copied attack echo must not deal damage"),
		assert_gt(defender.damage_counters, damage_after_echo, "A later real copied attack tap should still execute Powerful Rage"),
	])


func test_battle_scene_portrait_ns_zoroark_night_joker_touch_press_waits_for_release() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var zoroark_cd: CardData = CardDatabase.get_card("LEN_JTG", "98")
	var reshiram_cd: CardData = CardDatabase.get_card("LEN_JTG", "116")
	if zoroark_cd == null or reshiram_cd == null:
		return "LEN_JTG_98 or LEN_JTG_116 fixture missing"
	gsm.effect_processor.register_pokemon_card(zoroark_cd)
	gsm.effect_processor.register_pokemon_card(reshiram_cd)

	var zoroark := PokemonSlot.new()
	zoroark.pokemon_stack.append(CardInstance.create(zoroark_cd, 0))
	zoroark.turn_played = 0
	zoroark.damage_counters = 30
	zoroark.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy A", "D"), 0))
	zoroark.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy B", "D"), 0))
	gsm.game_state.players[0].active_pokemon = zoroark

	var bench_reshiram := PokemonSlot.new()
	bench_reshiram.pokemon_stack.append(CardInstance.create(reshiram_cd, 0))
	bench_reshiram.turn_played = 0
	gsm.game_state.players[0].bench.append(bench_reshiram)

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Night Joker Defender", 300, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	battle_scene.call("_show_pokemon_action_dialog", 0, zoroark, true)
	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var night_joker_action_index := -1
	for i: int in actions.size():
		var action: Variant = actions[i]
		if action is Dictionary and str((action as Dictionary).get("type", "")) == "attack" and int((action as Dictionary).get("attack_index", -1)) == 0:
			night_joker_action_index = i
			break

	var night_joker_option := _action_hud_option_at_index(battle_scene, night_joker_action_index)
	var touch_position := Vector2(420, 440)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = touch_position
	if night_joker_option != null:
		night_joker_option.emit_signal("gui_input", press)
	var pending_after_press := str(battle_scene.get("_pending_choice"))
	var dialog_data_after_press: Dictionary = battle_scene.get("_dialog_data")
	var damage_after_press := defender.damage_counters

	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = touch_position
	if night_joker_option != null:
		night_joker_option.emit_signal("gui_input", release)
	var pending_after_release := str(battle_scene.get("_pending_choice"))
	var dialog_data_after_release: Dictionary = battle_scene.get("_dialog_data")
	var overlay_visible_after_release := bool((battle_scene.get("_dialog_overlay") as Control).visible)
	var copied_action_items: Array = dialog_data_after_release.get("action_items", [])

	return run_checks([
		assert_gte(night_joker_action_index, 0, "Portrait N's Zoroark action HUD should expose Night Joker"),
		assert_not_null(night_joker_option, "Night Joker HUD option should be rendered"),
		assert_eq(pending_after_press, "pokemon_action", "Night Joker touch press should keep the first action HUD open"),
		assert_eq(str(dialog_data_after_press.get("presentation", "")), "action_hud", "The first HUD should remain an action HUD while the touch is down"),
		assert_eq(damage_after_press, 0, "Touch press alone must not execute Night Joker"),
		assert_eq(pending_after_release, "effect_interaction", "Night Joker touch release should open the copied attack HUD"),
		assert_true(overlay_visible_after_release, "The copied attack HUD overlay should be visible after release"),
		assert_eq(str(dialog_data_after_release.get("presentation", "")), "action_hud", "Copied attacks should render as an action HUD after release"),
		assert_gte(copied_action_items.size(), 2, "Night Joker should expose Benched N's Reshiram attacks after release"),
	])


func test_battle_scene_portrait_slot_opened_ns_zoroark_night_joker_opens_copied_attack_hud() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var zoroark_cd: CardData = CardDatabase.get_card("LEN_JTG", "98")
	var reshiram_cd: CardData = CardDatabase.get_card("LEN_JTG", "116")
	if zoroark_cd == null or reshiram_cd == null:
		return "LEN_JTG_98 or LEN_JTG_116 fixture missing"

	var zoroark := PokemonSlot.new()
	zoroark.pokemon_stack.append(CardInstance.create(zoroark_cd, 0))
	zoroark.turn_played = 0
	zoroark.damage_counters = 30
	zoroark.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy A", "D"), 0))
	zoroark.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy B", "D"), 0))
	gsm.game_state.players[0].active_pokemon = zoroark

	var bench_reshiram := PokemonSlot.new()
	bench_reshiram.pokemon_stack.append(CardInstance.create(reshiram_cd, 0))
	bench_reshiram.turn_played = 0
	gsm.game_state.players[0].bench.append(bench_reshiram)

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Night Joker Defender", 300, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender

	var opening_touch := Vector2(360, 720)
	_emit_slot_touch_tap(battle_scene, "my_active", 0, opening_touch)
	var pending_after_slot_tap := str(battle_scene.get("_pending_choice"))
	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var night_joker_action_index := -1
	for i: int in actions.size():
		var action: Variant = actions[i]
		if action is Dictionary and str((action as Dictionary).get("type", "")) == "attack" and int((action as Dictionary).get("attack_index", -1)) == 0:
			night_joker_action_index = i
			break

	var night_joker_option := _action_hud_option_at_index(battle_scene, night_joker_action_index)
	_emit_action_hud_touch_tap(night_joker_option, 1, Vector2(360, 160))
	var pending_after_night_joker := str(battle_scene.get("_pending_choice"))
	var dialog_data_after_night_joker: Dictionary = battle_scene.get("_dialog_data")
	var overlay_visible_after_night_joker := bool((battle_scene.get("_dialog_overlay") as Control).visible)
	var copied_action_items: Array = dialog_data_after_night_joker.get("action_items", [])
	var copied_option := _action_hud_option_at_index(battle_scene, 0)

	return run_checks([
		assert_eq(pending_after_slot_tap, "pokemon_action", "Portrait slot touch should open the Pokemon action HUD"),
		assert_gte(night_joker_action_index, 0, "Portrait slot-opened N's Zoroark HUD should expose Night Joker"),
		assert_not_null(night_joker_option, "Night Joker HUD option should be rendered after opening from the field slot"),
		assert_eq(pending_after_night_joker, "effect_interaction", "Choosing Night Joker from the portrait slot-opened HUD should open copied Bench attack choices"),
		assert_true(overlay_visible_after_night_joker, "The copied attack HUD overlay should remain visible after choosing Night Joker"),
		assert_eq(str(dialog_data_after_night_joker.get("presentation", "")), "action_hud", "Night Joker copied attack choices should use the action HUD in portrait"),
		assert_gte(copied_action_items.size(), 2, "Night Joker should expose Benched N's Reshiram attacks after a real portrait slot-opened tap"),
		assert_not_null(copied_option, "The copied attack HUD should render a selectable copied attack option"),
		assert_eq(defender.damage_counters, 0, "Opening the copied attack HUD should not default-execute Night Joker"),
	])


func test_battle_scene_real_dragapult_slot_action_hud_shows_counter_distribution() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	if dragapult_cd == null:
		return "CSV8C_159 Dragapult ex fixture missing"
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic", "P"), 0))
	gsm.game_state.players[0].active_pokemon = attacker

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 320, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))

	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var phantom_action_index := -1
	for i: int in actions.size():
		var action: Variant = actions[i]
		if action is Dictionary and str((action as Dictionary).get("type", "")) == "attack" and int((action as Dictionary).get("attack_index", -1)) == 1:
			phantom_action_index = i
			break
	var phantom_option := _action_hud_option_at_index(battle_scene, phantom_action_index)
	_emit_action_hud_mouse_click(phantom_option, Vector2(18, 18), Vector2(620, 180))

	var overlay := battle_scene.get("_field_interaction_overlay") as Control
	var mode_after_attack := str(battle_scene.get("_field_interaction_mode"))
	var pending_after_attack := str(battle_scene.get("_pending_choice"))
	var index_map_after_attack: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	var visible_after_attack := overlay != null and overlay.visible

	return run_checks([
		assert_true(gsm.effect_processor.has_attack_effect(dragapult_cd.effect_id), "Real CSV8C_159 should register Phantom Dive by effect_id even when localized names are mojibake"),
		assert_eq(str(battle_scene.get("_dialog_data").get("presentation", "")) if phantom_action_index < 0 else "action_hud", "action_hud", "Slot click should open the Pokemon action HUD before choosing Phantom Dive"),
		assert_gte(phantom_action_index, 0, "Real Dragapult action HUD should expose attack index 1"),
		assert_not_null(phantom_option, "Real Dragapult Phantom Dive option should be rendered"),
		assert_eq(pending_after_attack, "effect_interaction", "Real Dragapult Phantom Dive should leave the flow waiting for counter assignment"),
		assert_eq(mode_after_attack, "counter_distribution", "Real Dragapult Phantom Dive must show the 6-counter distribution UI"),
		assert_true(visible_after_attack, "Counter distribution overlay must be visible after selecting real Dragapult Phantom Dive"),
		assert_true(index_map_after_attack.has("opp_bench_0"), "Counter distribution must map opponent Bench slots for real Dragapult"),
	])


func test_battle_scene_real_regidrago_copy_dragapult_action_hud_shows_counter_distribution() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var regidrago_cd := _make_regidrago_vstar_cd()
	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	if dragapult_cd == null:
		return "CSV8C_159 Dragapult ex fixture missing"
	gsm.effect_processor.register_pokemon_card(regidrago_cd)
	gsm.effect_processor.register_pokemon_card(dragapult_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(regidrago_cd, 0))
	attacker.turn_played = 0
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass A", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Grass B", "G"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(dragapult_cd, 0))

	var defender := PokemonSlot.new()
	defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender", 320, "C"), 1))
	defender.turn_played = 0
	gsm.game_state.players[1].active_pokemon = defender
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "P"), 1))
	bench_a.turn_played = 0
	gsm.game_state.players[1].bench.append(bench_a)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))
	var apex_option := _action_hud_option_at_index(battle_scene, 0)
	_emit_action_hud_mouse_click(apex_option, Vector2(18, 18), Vector2(620, 180))

	var copied_steps: Array = battle_scene.get("_pending_effect_steps")
	var copied_items: Array = (copied_steps[0] as Dictionary).get("items", []) if not copied_steps.is_empty() else []
	var phantom_index := -1
	for i: int in copied_items.size():
		var item: Variant = copied_items[i]
		if not (item is Dictionary):
			continue
		var source_card: Variant = (item as Dictionary).get("source_card", null)
		if source_card is CardInstance and (source_card as CardInstance).card_data != null:
			if (source_card as CardInstance).card_data.effect_id == dragapult_cd.effect_id and int((item as Dictionary).get("attack_index", -1)) == 1:
				phantom_index = i
				break
	var phantom_copy_option := _action_hud_option_at_index(battle_scene, phantom_index)
	_emit_action_hud_mouse_click(phantom_copy_option, Vector2(18, 18), Vector2(620, 260))

	var overlay := battle_scene.get("_field_interaction_overlay") as Control
	var mode_after_copy := str(battle_scene.get("_field_interaction_mode"))
	var pending_after_copy := str(battle_scene.get("_pending_choice"))
	var index_map_after_copy: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	var visible_after_copy := overlay != null and overlay.visible

	return run_checks([
		assert_true(gsm.effect_processor.has_attack_effect(regidrago_cd.effect_id), "Regidrago VSTAR should register Apex Dragon"),
		assert_true(gsm.effect_processor.has_attack_effect(dragapult_cd.effect_id), "Real CSV8C_159 should register Phantom Dive by effect_id"),
		assert_not_null(apex_option, "Regidrago active slot click should render Apex Dragon in the action HUD"),
		assert_gte(phantom_index, 0, "Copied attack HUD should include real Dragapult attack index 1"),
		assert_not_null(phantom_copy_option, "Real Dragapult copied attack option should be rendered"),
		assert_eq(pending_after_copy, "effect_interaction", "Copying real Dragapult Phantom Dive should wait for counter assignment"),
		assert_eq(mode_after_copy, "counter_distribution", "Copying real Dragapult Phantom Dive must show the 6-counter distribution UI"),
		assert_true(visible_after_copy, "Counter distribution overlay must be visible after selecting copied real Dragapult Phantom Dive"),
		assert_true(index_map_after_copy.has("opp_bench_0"), "Counter distribution must map opponent Bench slots after Regidrago copy"),
	])


func test_battle_scene_mela_routes_real_effect_from_field_slot_to_dialog() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Fire Active", 110, "R"), 0))
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Fire Bench", 90, "R"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0),
	]

	var mela_card := CardInstance.create(_make_trainer_cd("Mela", "Supporter", ""), 0)
	var steps: Array[Dictionary] = EffectMelaScript.new().get_interaction_steps(mela_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, mela_card)
	battle_scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "Mela 选完我方宝可梦后应退出场上点选"),
		assert_true(bool(battle_scene.get("_dialog_overlay").visible), "Mela 第二步应回到弃牌区能量选择弹框"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "Mela 选完目标后应推进到第二个交互步骤"),
	])


func test_battle_scene_attach_basic_energy_from_discard_routes_second_step_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_card := CardInstance.create(_make_pokemon_cd("Discard Attacker", 140, "L"), 0)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 100, "L"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 100, "L"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]
	gsm.game_state.players[0].discard_pile = [
		CardInstance.create(_make_energy_cd("Lightning 1", "L"), 0),
		CardInstance.create(_make_energy_cd("Lightning 2", "L"), 0),
	]

	var effect := AttackAttachBasicEnergyFromDiscardScript.new("L", 2, "own_bench")
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1]))

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "弃牌贴能攻击第二步应切到场上选目标"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "给我方宝可梦贴能的场上交互应上移"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "完成能量选择后应推进到目标选择步骤"),
	])


func test_battle_scene_search_and_attach_routes_real_attack_to_field_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_card := CardInstance.create(_make_pokemon_cd("Search Attacker", 140, "L"), 0)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 100, "L"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 100, "L"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning 1", "L"), 0),
		CardInstance.create(_make_trainer_cd("Decoy", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Lightning 2", "L"), 0),
	]

	var effect := AttackSearchAndAttachScript.new("L", 2, "top_n", 5, "bench")
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "搜牌库贴能攻击应直接进入场上分配 UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "给我方宝可梦贴能的 assignment UI 应上移"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("source_items", []).size()), 2, "应展示两张可分配的基础能量"),
	])


func test_battle_scene_portrait_joltik_charge_combines_grass_and_lightning_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var joltik_cd := _make_pokemon_cd("Joltik", 30, "L")
	joltik_cd.attacks = [{"name": "Joltik Charge", "cost": "C", "damage": "", "text": "", "is_vstar_power": false}]
	var attacker_card := CardInstance.create(joltik_cd, 0)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Target", 100, "L"), 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Grass 1", "G"), 0),
		CardInstance.create(_make_energy_cd("Grass 2", "G"), 0),
		CardInstance.create(_make_energy_cd("Grass 3", "G"), 0),
		CardInstance.create(_make_energy_cd("Lightning 1", "L"), 0),
		CardInstance.create(_make_energy_cd("Lightning 2", "L"), 0),
		CardInstance.create(_make_energy_cd("Lightning 3", "L"), 0),
	]

	var effect := CSV9CEffects.AttackJoltikCharge.new(0)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, joltik_cd.attacks[0], gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	var data: Dictionary = battle_scene.get("_field_interaction_data")
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 1)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 2)
	var selected_after_third_grass := int(battle_scene.get("_field_interaction_assignment_selected_source_index"))
	var assignments_after_third_grass: Array = (battle_scene.get("_field_interaction_assignment_entries") as Array).duplicate(true)
	battle_scene.call("_on_field_assignment_source_chosen", 3)
	battle_scene.call("_handle_field_assignment_target_index", 1)
	battle_scene.call("_on_field_assignment_source_chosen", 4)
	battle_scene.call("_handle_field_assignment_target_index", 1)
	var assignments_after_two_lightning: Array = (battle_scene.get("_field_interaction_assignment_entries") as Array).duplicate(true)

	var result := run_checks([
		assert_eq(steps.size(), 1, "Joltik Charge should enter one combined assignment step on portrait UI"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Portrait Joltik Charge should use the field assignment HUD"),
		assert_eq(int(data.get("source_items", []).size()), 6, "Portrait Joltik Charge should show Grass and Lightning Energy together"),
		assert_eq(int(data.get("max_select", 0)), 4, "Portrait Joltik Charge should allow four total assignments"),
		assert_eq(data.get("source_bucket_keys", []), ["G", "G", "G", "L", "L", "L"], "Portrait Joltik Charge should preserve source Energy type buckets"),
		assert_eq(selected_after_third_grass, -1, "Portrait Joltik Charge should reject selecting a third Grass source"),
		assert_eq(assignments_after_third_grass.size(), 2, "Portrait Joltik Charge should keep only two Grass assignments"),
		assert_eq(assignments_after_two_lightning.size(), 4, "Portrait Joltik Charge should accept two Grass plus two Lightning assignments"),
	])
	battle_scene.free()
	return result


func test_battle_scene_gholdengo_single_selected_energy_deals_fifty_to_neutral_target() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_cd: CardData = CardDatabase.get_card("CSV4C", "089")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := _make_pokemon_cd("Neutral Defender", 200, "C")
	defender_cd.weakness_energy = "W"
	defender_cd.weakness_value = "×2"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var chosen_water := CardInstance.create(_make_energy_cd("Chosen Water", "W"), 0)
	var unchosen_psychic := CardInstance.create(_make_energy_cd("Unchosen Psychic", "P"), 0)
	gsm.game_state.players[0].hand = [chosen_water, unchosen_psychic]

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 0)
	var first_step: Dictionary = (battle_scene.get("_pending_effect_steps") as Array)[0] if not (battle_scene.get("_pending_effect_steps") as Array).is_empty() else {}
	var first_items: Array = first_step.get("items", [])
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))

	return run_checks([
		assert_eq(str(first_step.get("id", "")), "discard_basic_energy", "赛富豪ex应先弹出手牌基础能量弃置选择"),
		assert_eq(first_items.size(), 2, "赛富豪ex应将每张可弃置的手牌基础能量各展示一次"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "选择弃置能量后应完成攻击交互"),
		assert_true(chosen_water in gsm.game_state.players[0].discard_pile, "选中的水能应进入弃牌区"),
		assert_true(unchosen_psychic in gsm.game_state.players[0].hand, "未选中的基础能量应保留在手牌"),
		assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 50, "通过 BattleScene 真实入口只弃置 1 张能量时，对无钢弱点目标应只造成 50 伤害"),
	])


func test_battle_scene_return_energy_then_bench_damage_routes_second_step_to_opponent_field() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_card := CardInstance.create(_make_pokemon_cd("Bench Sniper", 180, "W"), 0)
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	attacker.attached_energy = [
		CardInstance.create(_make_energy_cd("Water 1", "W"), 0),
		CardInstance.create(_make_energy_cd("Water 2", "W"), 0),
		CardInstance.create(_make_energy_cd("Water 3", "W"), 0),
	]
	gsm.game_state.players[0].active_pokemon = attacker
	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := AttackReturnEnergyThenBenchDamageScript.new(120, -1, 3)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	var attack_effects: Array[BaseEffect] = [effect]
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0, {}, attack_effects)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1, 2]))

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "退能打备战攻击第二步应切到场上选对手目标"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "bottom", "攻击对方场上的目标时 UI 应下移"),
		assert_eq(int(battle_scene.get("_pending_effect_step_index")), 1, "完成退能选择后应推进到备战目标步骤"),
	])


func test_battle_scene_opponent_chooses_step_requests_handover_in_two_player() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opponent_active := PokemonSlot.new()
	opponent_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opponent_active
	var opponent_bench := PokemonSlot.new()
	opponent_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opponent_bench]

	var gust_card := CardInstance.create(_make_pokemon_cd("Iron Bundle", 100, "W"), 0)
	var steps: Array[Dictionary] = AbilityGustFromBenchScript.new().get_interaction_steps(gust_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, gust_card)

	var handover_visible: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_set_handover_panel_visible", false, "test_resume")
	battle_scene.set("_view_player", 1)
	battle_scene.call("_show_next_effect_interaction_step")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(handover_visible, "opponent_chooses 的步骤在双人模式下应先交机给对手"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "交机后应继续进入场上选槽模式"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "交机给对手后应按对手视角上移面板"),
	])


func test_battle_scene_opponent_chooses_step_handover_waits_for_active_attack_vfx() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opponent_active := PokemonSlot.new()
	opponent_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("VFX Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opponent_active
	var opponent_bench := PokemonSlot.new()
	opponent_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("VFX Opp Bench", 90, "C"), 1))
	gsm.game_state.players[1].bench = [opponent_bench]

	var overlay := Control.new()
	var sequence := Control.new()
	sequence.name = "AttackVfxSequence"
	sequence.set_meta("attack_vfx_sequence", true)
	sequence.set_meta("attack_vfx_kind", "attack")
	sequence.set_meta("attack_vfx_animation_active", true)
	overlay.add_child(sequence)
	battle_scene.set("_attack_vfx_overlay", overlay)

	var gust_card := CardInstance.create(_make_pokemon_cd("VFX Iron Bundle", 100, "W"), 0)
	var steps: Array[Dictionary] = AbilityGustFromBenchScript.new().get_interaction_steps(gust_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, gust_card)

	var handover_visible_during_vfx: bool = bool(battle_scene.get("_handover_panel").visible)
	var field_mode_during_vfx: String = str(battle_scene.get("_field_interaction_mode"))
	var delay_active: bool = bool(battle_scene.get("_handover_attack_vfx_delay_active"))
	var delay_token: int = int(battle_scene.get("_handover_attack_vfx_delay_token"))
	sequence.set_meta("attack_vfx_animation_active", false)
	battle_scene.call("_poll_attack_vfx_handover_delay", delay_token, "effect_step")
	var handover_visible_after_vfx: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_on_handover_confirmed")
	var field_mode_after_handover: String = str(battle_scene.get("_field_interaction_mode"))
	var field_position_after_handover: String = str(battle_scene.get("_field_interaction_position"))

	GameManager.current_mode = previous_mode
	overlay.free()
	battle_scene.free()
	return run_checks([
		assert_false(handover_visible_during_vfx, "Opponent effect-step handover should stay hidden while attack VFX is active"),
		assert_eq(field_mode_during_vfx, "", "Opponent effect-step field UI should not open over an active attack VFX"),
		assert_true(delay_active, "Opponent effect-step should register an attack-VFX completion wait"),
		assert_true(handover_visible_after_vfx, "Opponent effect-step handover should appear after the attack VFX finishes"),
		assert_eq(field_mode_after_handover, "slot_select", "Confirming the delayed effect-step handover should continue to field slot selection"),
		assert_eq(field_position_after_handover, "top", "Delayed opponent effect-step UI should still use the opponent-side position"),
	])


func test_battle_scene_collapsed_stadium_handover_uses_step_chooser_player() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active %d" % pi, 120, "C"), pi))
		player.active_pokemon = active
		for bench_index: int in 5:
			var bench := PokemonSlot.new()
			bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench %d-%d" % [pi, bench_index], 80, "C"), pi))
			player.bench.append(bench)

	var stadium_card := CardInstance.create(_make_trainer_cd("Collapsed Stadium", "Stadium", ""), 0)
	var steps: Array[Dictionary] = EffectCollapsedStadiumScript.new().get_on_play_interaction_steps(stadium_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "play_stadium", 0, steps, stadium_card)
	battle_scene.call("_handle_field_slot_select_index", 0)
	var handover_visible: bool = bool(battle_scene.get("_handover_panel").visible)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "第一位玩家选完后应先等待下一步交机"),
		assert_true(handover_visible, "Collapsed Stadium 轮到对手弃备战时应触发交机提示"),
	])


func test_battle_scene_collapsed_stadium_over_area_zero_cleanup_releases_drag_state() -> String:
	var battle_scene = _make_battle_scene_stub()
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	var hand_row := HBoxContainer.new()
	hand_scroll.add_child(hand_row)
	battle_scene.add_child(hand_scroll)
	battle_scene.set("_hand_scroll", hand_scroll)
	battle_scene.call("_setup_hand_drag_scroll")
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active %d" % pi, 120, "C"), pi))
		player_state.active_pokemon = active

	var player: PlayerState = gsm.game_state.players[0]
	for bench_index: int in 8:
		var bench := PokemonSlot.new()
		bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Area Zero Bench %d" % bench_index, 80, "C"), 0))
		player.bench.append(bench)

	var zero_cd := _make_trainer_cd("Area Zero Underdepths", "Stadium", "")
	zero_cd.effect_id = EffectAreaZeroUnderdepthsScript.EFFECT_ID
	gsm.game_state.stadium_card = CardInstance.create(zero_cd, 0)
	gsm.game_state.stadium_owner_index = 0

	var collapsed_cd := _make_trainer_cd("Collapsed Stadium", "Stadium", "")
	collapsed_cd.effect_id = EffectCollapsedStadiumScript.EFFECT_ID
	var collapsed := CardInstance.create(collapsed_cd, 0)
	player.hand.append(collapsed)

	var stale_scroll := ScrollContainer.new()
	var stale_row := HBoxContainer.new()
	stale_scroll.add_child(stale_row)
	battle_scene.add_child(stale_scroll)
	battle_scene.call("_configure_card_gallery_drag_scroll", stale_scroll, stale_row, "collapsed_cleanup")
	battle_scene.call("_set_card_gallery_drag_scroll_active", stale_scroll, true)
	var stale_press := InputEventMouseButton.new()
	stale_press.button_index = MOUSE_BUTTON_LEFT
	stale_press.pressed = true
	stale_press.global_position = Vector2(220, 24)
	battle_scene.call("_handle_card_gallery_drag_scroll_input", stale_press, stale_scroll, "collapsed_cleanup")
	battle_scene.set("_hand_drag_suppress_click_until_msec", Time.get_ticks_msec() + 10000)
	var stale_gallery_active_before: bool = bool(battle_scene.get("_card_gallery_drag_active"))
	var stale_hand_suppressed_before: bool = bool(battle_scene.call("_is_hand_drag_click_suppressed"))

	battle_scene.call("_try_play_stadium_with_interaction", 0, collapsed)
	var first_mode := str(battle_scene.get("_field_interaction_mode"))
	for target_index: int in [4, 5, 6, 7]:
		battle_scene.call("_handle_field_slot_select_index", target_index)

	var stale_gallery_active_after: bool = bool(battle_scene.get("_card_gallery_drag_active"))
	var stale_hand_suppressed_after: bool = bool(battle_scene.call("_is_hand_drag_click_suppressed"))
	# The successful action now reconciles the semantic hand and deliberately
	# discards stale synthetic content width. Restore real overflow so this
	# assertion isolates capture recovery from the layout-reset contract.
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)
	hand_scroll.scroll_horizontal = 300
	var start_scroll := hand_scroll.scroll_horizontal
	var hand_press := InputEventMouseButton.new()
	hand_press.button_index = MOUSE_BUTTON_LEFT
	hand_press.pressed = true
	hand_press.global_position = Vector2(200, 24)
	battle_scene.call("_handle_hand_drag_scroll_input", hand_press, "hand_card_gui")
	var drag_left := InputEventMouseMotion.new()
	drag_left.global_position = Vector2(120, 24)
	battle_scene.call("_input", drag_left)
	var scroll_after_drag := hand_scroll.scroll_horizontal

	var result := run_checks([
		assert_true(stale_gallery_active_before, "The test should start with a stale card-search/gallery drag capture"),
		assert_true(stale_hand_suppressed_before, "The test should start with a stale hand drag click suppression window"),
		assert_eq(first_mode, "slot_select", "Collapsed Stadium replacing Area Zero should use the field-slot cleanup selector"),
		assert_eq(player.bench.size(), 4, "Collapsed Stadium should trim the Area Zero-expanded Bench to four"),
		assert_eq(gsm.game_state.stadium_card, collapsed, "Collapsed Stadium should be the active Stadium after cleanup"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "The cleanup interaction should finish cleanly"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "The field cleanup overlay should be closed after the required choices"),
		assert_false(stale_gallery_active_after, "Finishing the Stadium cleanup should clear stale card-gallery drag capture"),
		assert_false(stale_hand_suppressed_after, "Finishing the Stadium cleanup should clear stale hand drag click suppression"),
		assert_true(scroll_after_drag > start_scroll, "The hand row should be draggable immediately after the Stadium cleanup"),
	])
	battle_scene.free()
	return result


func test_battle_scene_vs_ai_area_zero_ko_cleanup_uses_human_chooser_when_ai_owns_stadium() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	battle_scene._setup_ai_for_tests()
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	battle_scene.set("_ai_opponent", ai)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 6
	gsm.game_state.phase = GameState.GamePhase.POKEMON_CHECK
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.deck.append(CardInstance.create(_make_pokemon_cd("Area Zero Deck %d" % pi, 60, "C"), pi))
		gsm.game_state.players.append(player)

	var tera_cd := _make_pokemon_cd("Human Only Tera ex", 230, "C")
	tera_cd.mechanic = "ex"
	tera_cd.is_tags = PackedStringArray(["Tera"])
	var tera_active := PokemonSlot.new()
	tera_active.pokemon_stack.append(CardInstance.create(tera_cd, 0))
	tera_active.damage_counters = 230
	gsm.game_state.players[0].active_pokemon = tera_active

	var cleanup_target := PokemonSlot.new()
	cleanup_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Area Zero Cleanup Target", 90, "C"), 0))
	gsm.game_state.players[0].bench.append(cleanup_target)
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Area Zero Replacement", 90, "C"), 0))
	gsm.game_state.players[0].bench.append(replacement)
	for bench_index: int in 4:
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Area Zero Extra %d" % bench_index, 90, "C"), 0))
		gsm.game_state.players[0].bench.append(bench_slot)

	var ai_active := PokemonSlot.new()
	ai_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("AI Active Area Zero Owner", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = ai_active

	for prize_index: int in 3:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_trainer_cd("Human Prize %d" % prize_index, "Item", ""), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_trainer_cd("AI Prize %d" % prize_index, "Item", ""), 1))

	var zero_cd := _make_trainer_cd("Area Zero Underdepths", "Stadium", "")
	zero_cd.effect_id = EffectAreaZeroUnderdepthsScript.EFFECT_ID
	gsm.game_state.stadium_card = CardInstance.create(zero_cd, 1)
	gsm.game_state.stadium_owner_index = 1

	gsm.call("_check_all_knockouts")
	var cleanup_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var cleanup_prompt_player: int = int(battle_scene.get("_pending_effect_player_index"))
	var cleanup_chooser: int = int(battle_scene.call("_get_effect_interaction_prompt_player_index"))
	var cleanup_blocks_ai: bool = bool(battle_scene.call("_is_ui_blocking_ai"))
	var cleanup_ai_scheduled: bool = bool(battle_scene.get("_ai_step_scheduled"))
	var cleanup_dialog_items: Array = (battle_scene.get("_dialog_data") as Dictionary).get("card_items", [])
	var first_cleanup_item: Variant = cleanup_dialog_items[0] if not cleanup_dialog_items.is_empty() else null

	battle_scene.call("_on_dialog_card_chosen", 0)
	var pending_after_cleanup: String = str(battle_scene.get("_pending_choice"))
	var prize_player_after_cleanup: int = int(battle_scene.get("_pending_prize_player_index"))
	var prize_remaining_after_cleanup: int = int(battle_scene.get("_pending_prize_remaining"))
	var ai_scheduled_after_cleanup: bool = bool(battle_scene.get("_ai_step_scheduled"))
	var cleanup_dialog_overlay: Control = battle_scene.get("_dialog_overlay") as Control
	var cleanup_field_overlay: Control = battle_scene.get("_field_interaction_overlay") as Control
	var ai_cleanup_diagnostics := "ready=%s blocking=%s draw=%s coin=%s dialog=%s field=%s state=%s effect=%s" % [
		str(battle_scene.call("_is_ai_turn_ready")),
		str(battle_scene.call("_is_ui_blocking_ai")),
		str(battle_scene.get("_draw_reveal_active")),
		str(battle_scene.call("_has_pending_coin_animation")),
		str(cleanup_dialog_overlay != null and cleanup_dialog_overlay.visible),
		str(cleanup_field_overlay != null and cleanup_field_overlay.visible),
		str(battle_scene.call("_state_snapshot")),
		str(battle_scene.call("_effect_state_snapshot")),
	]
	var cleanup_target_removed: bool = cleanup_target not in gsm.game_state.players[0].bench
	var bench_size_after_cleanup: int = gsm.game_state.players[0].bench.size()

	battle_scene.set("_ai_step_scheduled", false)
	battle_scene.call("_try_take_prize_from_slot", 1, 0)
	battle_scene.call("_try_take_prize_from_slot", 1, 1)
	var pending_after_prizes: String = str(battle_scene.get("_pending_choice"))
	var send_out_player: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))

	battle_scene.call("_on_dialog_card_chosen", 0)
	var active_after_send_out: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var pending_after_send_out: String = str(battle_scene.get("_pending_choice"))
	var phase_after_send_out: int = gsm.game_state.phase

	var result := run_checks([
		assert_eq(cleanup_pending_choice, "effect_interaction", "Area Zero KO cleanup should open a real effect interaction in BattleScene"),
		assert_eq(cleanup_prompt_player, 1, "This edge case should keep the engine cleanup start player as the AI Stadium owner"),
		assert_eq(cleanup_chooser, 0, "The UI prompt owner must come from the cleanup step chooser, so the human chooses the discard"),
		assert_true(cleanup_blocks_ai, "The visible human cleanup dialog should block AI execution"),
		assert_false(cleanup_ai_scheduled, "AI should not be scheduled while the human-owned cleanup dialog is open"),
		assert_true(first_cleanup_item is PokemonSlot, "The cleanup dialog should expose Bench PokemonSlot items"),
		assert_eq(pending_after_cleanup, "take_prize", "After human cleanup, the pending engine prize prompt should be restored"),
		assert_eq(prize_player_after_cleanup, 1, "After cleanup, the AI should be the prize-taking player"),
		assert_eq(prize_remaining_after_cleanup, 2, "KOing the Tera ex should still require two AI prizes"),
		assert_true(ai_scheduled_after_cleanup, "Restoring an AI-owned prize prompt after cleanup should schedule the AI to continue | %s" % ai_cleanup_diagnostics),
		assert_true(cleanup_target_removed, "The human-selected Bench Pokemon should be discarded"),
		assert_eq(bench_size_after_cleanup, 5, "Human Bench should be trimmed to the normal limit before prizes"),
		assert_eq(pending_after_prizes, "send_out", "After AI prizes, the flow should ask the human to send out a replacement"),
		assert_eq(send_out_player, 0, "The send-out prompt should belong to the human player"),
		assert_eq(active_after_send_out, replacement, "The selected replacement should become Active"),
		assert_eq(pending_after_send_out, "", "The cleanup, prize, and send-out chain should fully resolve"),
		assert_eq(phase_after_send_out, GameState.GamePhase.MAIN, "After the full chain, battle should return to MAIN"),
	])
	GameManager.current_mode = previous_mode
	battle_scene.free()
	return result


func test_battle_scene_two_player_area_zero_ko_cleanup_hands_to_defender_before_attacker_prizes() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	battle_scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 6
	gsm.game_state.phase = GameState.GamePhase.POKEMON_CHECK
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.deck.append(CardInstance.create(_make_pokemon_cd("Two Player Deck %d" % pi, 60, "C"), pi))
		gsm.game_state.players.append(player)

	var pikachu_cd := _make_pokemon_cd("皮卡丘ex", 200, "L")
	pikachu_cd.mechanic = "ex"
	pikachu_cd.ancient_trait = "Tera"
	pikachu_cd.attacks = [{"name": "黄晶伏特", "cost": "GLM", "damage": "300", "text": "", "is_vstar_power": false}]
	var pikachu := PokemonSlot.new()
	pikachu.pokemon_stack.append(CardInstance.create(pikachu_cd, 0))
	gsm.game_state.players[0].active_pokemon = pikachu

	var terapagos_cd := _make_pokemon_cd("太乐巴戈斯ex", 230, "C")
	terapagos_cd.mechanic = "ex"
	terapagos_cd.ancient_trait = "Tera"
	var terapagos := PokemonSlot.new()
	terapagos.pokemon_stack.append(CardInstance.create(terapagos_cd, 1))
	terapagos.damage_counters = 230
	gsm.game_state.players[1].active_pokemon = terapagos

	var cleanup_target := PokemonSlot.new()
	cleanup_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender Area Zero Cleanup Target", 90, "C"), 1))
	gsm.game_state.players[1].bench.append(cleanup_target)
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender Replacement", 90, "C"), 1))
	gsm.game_state.players[1].bench.append(replacement)
	for bench_index: int in 4:
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender Extra %d" % bench_index, 90, "C"), 1))
		gsm.game_state.players[1].bench.append(bench_slot)

	for prize_index: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_trainer_cd("Attacker Prize %d" % prize_index, "Item", ""), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_trainer_cd("Defender Prize %d" % prize_index, "Item", ""), 1))

	var zero_cd := _make_trainer_cd("零之大空洞", "Stadium", "")
	zero_cd.effect_id = EffectAreaZeroUnderdepthsScript.EFFECT_ID
	gsm.game_state.stadium_card = CardInstance.create(zero_cd, 0)
	gsm.game_state.stadium_owner_index = 0

	gsm.call("_check_all_knockouts")
	var cleanup_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var cleanup_engine_player: int = int(battle_scene.get("_pending_effect_player_index"))
	var cleanup_chooser: int = int(battle_scene.call("_get_effect_interaction_prompt_player_index"))
	var handover_visible_for_cleanup: bool = bool((battle_scene.get("_handover_panel") as Panel).visible)
	var view_before_cleanup_handover: int = int(battle_scene.get("_view_player"))
	var dialog_visible_before_handover: bool = bool((battle_scene.get("_dialog_overlay") as Panel).visible)

	battle_scene.call("_on_handover_confirmed")
	var view_after_cleanup_handover: int = int(battle_scene.get("_view_player"))
	var cleanup_dialog_visible: bool = bool((battle_scene.get("_dialog_overlay") as Panel).visible)
	var cleanup_items: Array = (battle_scene.get("_dialog_data") as Dictionary).get("card_items", [])
	var first_cleanup_item: Variant = cleanup_items[0] if not cleanup_items.is_empty() else null

	battle_scene.call("_on_dialog_card_chosen", 0)
	var cleanup_target_removed: bool = cleanup_target not in gsm.game_state.players[1].bench
	var bench_size_after_cleanup: int = gsm.game_state.players[1].bench.size()
	var pending_after_cleanup: String = str(battle_scene.get("_pending_choice"))
	var prize_player_after_cleanup: int = int(battle_scene.get("_pending_prize_player_index"))
	var prize_remaining_after_cleanup: int = int(battle_scene.get("_pending_prize_remaining"))
	var handover_visible_for_prizes: bool = bool((battle_scene.get("_handover_panel") as Panel).visible)

	battle_scene.call("_on_handover_confirmed")
	var view_after_prize_handover: int = int(battle_scene.get("_view_player"))
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	var pending_after_prizes: String = str(battle_scene.get("_pending_choice"))
	var handover_visible_for_send_out: bool = bool((battle_scene.get("_handover_panel") as Panel).visible)

	battle_scene.call("_on_handover_confirmed")
	var view_after_send_out_handover: int = int(battle_scene.get("_view_player"))
	var send_out_player_after_handover: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))
	battle_scene.call("_on_dialog_card_chosen", 0)
	var active_after_send_out: PokemonSlot = gsm.game_state.players[1].active_pokemon
	var pending_after_send_out: String = str(battle_scene.get("_pending_choice"))
	var phase_after_send_out: int = gsm.game_state.phase
	var current_player_after_send_out: int = gsm.game_state.current_player_index

	var result := run_checks([
		assert_eq(cleanup_pending_choice, "effect_interaction", "Two-player Area Zero KO cleanup should open an effect interaction before prizes"),
		assert_eq(cleanup_engine_player, 0, "The engine cleanup start player can be the Stadium owner"),
		assert_eq(cleanup_chooser, 1, "The actual cleanup chooser must be the knocked-out defender"),
		assert_true(handover_visible_for_cleanup, "The UI should ask to hand over to the defender before showing cleanup cards"),
		assert_eq(view_before_cleanup_handover, 0, "The attacker should still be the view player before accepting the cleanup handover"),
		assert_false(dialog_visible_before_handover, "Cleanup cards must stay hidden until the defender accepts handover"),
		assert_eq(view_after_cleanup_handover, 1, "Accepting the cleanup handover should switch to the defender"),
		assert_true(cleanup_dialog_visible, "After handover, the defender should see the Area Zero cleanup dialog"),
		assert_true(first_cleanup_item is PokemonSlot, "The cleanup dialog should expose defender Bench PokemonSlot items"),
		assert_true(cleanup_target_removed, "The defender-selected excess Bench Pokemon should be discarded"),
		assert_eq(bench_size_after_cleanup, 5, "The defender Bench should be trimmed to five before prizes"),
		assert_eq(pending_after_cleanup, "take_prize", "After cleanup, the attacker should be prompted to take prizes"),
		assert_eq(prize_player_after_cleanup, 0, "Pikachu ex's owner should take Terapagos prizes after cleanup"),
		assert_eq(prize_remaining_after_cleanup, 2, "KOing Terapagos ex should still award two prizes"),
		assert_true(handover_visible_for_prizes, "The UI should hand back to the attacker before prize selection"),
		assert_eq(view_after_prize_handover, 0, "Accepting the prize handover should switch back to the attacker"),
		assert_eq(pending_after_prizes, "send_out", "After prizes, the defender should be asked to send out a replacement"),
		assert_true(handover_visible_for_send_out, "The UI should hand over to the defender for send-out"),
		assert_eq(view_after_send_out_handover, 1, "Accepting send-out handover should switch to the defender"),
		assert_eq(send_out_player_after_handover, 1, "The send-out prompt should belong to the defender"),
		assert_eq(active_after_send_out, replacement, "The defender-selected replacement should become Active"),
		assert_eq(pending_after_send_out, "", "The cleanup, prize, and send-out chain should fully resolve"),
		assert_eq(phase_after_send_out, GameState.GamePhase.MAIN, "After replacement, the battle should return to MAIN"),
		assert_eq(current_player_after_send_out, 1, "After the attack knockout flow, turn should pass to the defender"),
	])
	GameManager.current_mode = previous_mode
	battle_scene.free()
	return result


func test_battle_scene_two_player_area_zero_ko_cleanup_waits_for_attack_vfx_then_hands_to_defender() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree is required for attack VFX handover timing"
	var previous_mode: int = GameManager.current_mode
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE

	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_battle_mode", "review_readonly")
	tree.root.add_child(battle_scene)
	await tree.process_frame
	await tree.process_frame
	battle_scene.set("_battle_mode", "live")
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 6
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	if battle_scene.has_method("_sync_battle_scene_context_runtime"):
		battle_scene.call("_sync_battle_scene_context_runtime")
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.deck.append(CardInstance.create(_make_pokemon_cd("Deck filler %d" % pi, 60, "C"), pi))
		gsm.game_state.players.append(player)

	var pikachu_cd: CardData = CardDatabase.get_card("CSV9C", "054")
	if pikachu_cd == null:
		GameManager.current_mode = previous_mode
		GameManager.battle_layout_mode = previous_layout
		battle_scene.queue_free()
		await tree.process_frame
		return "Missing bundled Pikachu ex CSV9C/054 card data"
	gsm.effect_processor.register_pokemon_card(pikachu_cd)
	var pikachu := PokemonSlot.new()
	pikachu.pokemon_stack.append(CardInstance.create(pikachu_cd, 0))
	pikachu.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	pikachu.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	pikachu.attached_energy.append(CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0))
	gsm.game_state.players[0].active_pokemon = pikachu
	var pikachu_effect_id: String = str(gsm.effect_processor.resolve_effect_id(pikachu_cd.effect_id))
	gsm.effect_processor.replace_attack_effects(pikachu_effect_id, [AttackDiscardAttachedEnergyFromSelf.new(3, 0)])
	var pikachu_attack_effect_count: int = gsm.effect_processor.get_attack_effects_for_slot(pikachu, 0).size()
	var pikachu_attack_step_count: int = 0
	var pikachu_attack_data: Dictionary = pikachu_cd.attacks[0] if not pikachu_cd.attacks.is_empty() else {}
	for attack_effect: BaseEffect in gsm.effect_processor.get_attack_effects_for_slot(pikachu, 0):
		pikachu_attack_step_count += attack_effect.get_attack_interaction_steps(pikachu.get_top_card(), pikachu_attack_data, gsm.game_state).size()

	var terapagos_cd: CardData = CardDatabase.get_card("CSV9C", "175")
	if terapagos_cd == null:
		GameManager.current_mode = previous_mode
		GameManager.battle_layout_mode = previous_layout
		battle_scene.queue_free()
		await tree.process_frame
		return "Missing bundled Terapagos ex CSV9C/175 card data"
	gsm.effect_processor.register_pokemon_card(terapagos_cd)
	var terapagos := PokemonSlot.new()
	terapagos.pokemon_stack.append(CardInstance.create(terapagos_cd, 1))
	gsm.game_state.players[1].active_pokemon = terapagos

	for bench_index: int in 6:
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Defender Bench %d" % bench_index, 90, "C"), 1))
		gsm.game_state.players[1].bench.append(bench_slot)
	for prize_index: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_trainer_cd("Attacker Prize %d" % prize_index, "Item", ""), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_trainer_cd("Defender Prize %d" % prize_index, "Item", ""), 1))

	var zero_cd := _make_trainer_cd("Area Zero Underdepths", "Stadium", "")
	zero_cd.effect_id = EffectAreaZeroUnderdepthsScript.EFFECT_ID
	gsm.game_state.stadium_card = CardInstance.create(zero_cd, 0)
	gsm.game_state.stadium_owner_index = 0

	battle_scene.call("_try_use_attack_with_interaction", 0, pikachu, 0)
	var attack_discard_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var attack_discard_dialog_data: Dictionary = (battle_scene.get("_dialog_data") as Dictionary).duplicate(true)
	var attack_discard_items: Array = attack_discard_dialog_data.get("card_items", [])
	for energy_choice_index: int in 3:
		battle_scene.call("_on_dialog_card_chosen", energy_choice_index)
	var attack_discard_confirm_enabled: bool = not bool((battle_scene.get("_dialog_confirm") as Button).disabled)
	battle_scene.call("_on_dialog_confirm")
	var attack_resolved: bool = gsm.game_state.players[1].active_pokemon == null
	var pending_after_attack: String = str(battle_scene.get("_pending_choice"))
	var cleanup_chooser_after_attack: int = int(battle_scene.call("_get_effect_interaction_prompt_player_index"))
	var active_vfx_count_after_attack: int = int((battle_scene.get("_battle_attack_vfx_controller") as RefCounted).call("get_active_attack_vfx_count", battle_scene))
	var delay_active_after_attack: bool = bool(battle_scene.get("_handover_attack_vfx_delay_active"))
	var handover_visible_during_vfx: bool = bool((battle_scene.get("_handover_panel") as Control).visible)
	var dialog_visible_during_vfx: bool = bool((battle_scene.get("_dialog_overlay") as Control).visible)

	await tree.create_timer(1.65).timeout
	await tree.process_frame

	var delay_active_after_vfx: bool = bool(battle_scene.get("_handover_attack_vfx_delay_active"))
	var handover_visible_after_vfx: bool = bool((battle_scene.get("_handover_panel") as Control).visible)
	var dialog_visible_after_vfx: bool = bool((battle_scene.get("_dialog_overlay") as Control).visible)
	var view_before_cleanup_handover: int = int(battle_scene.get("_view_player"))
	var pending_action_after_vfx: Callable = battle_scene.get("_pending_handover_action") as Callable

	battle_scene.call("_on_handover_confirmed")
	var view_after_cleanup_handover: int = int(battle_scene.get("_view_player"))
	var dialog_visible_after_handover: bool = bool((battle_scene.get("_dialog_overlay") as Control).visible)
	var cleanup_items: Array = (battle_scene.get("_dialog_data") as Dictionary).get("card_items", [])
	var first_cleanup_item: Variant = cleanup_items[0] if not cleanup_items.is_empty() else null

	battle_scene.call("_on_dialog_card_chosen", 0)
	var pending_after_cleanup: String = str(battle_scene.get("_pending_choice"))
	var prize_player_after_cleanup: int = int(battle_scene.get("_pending_prize_player_index"))
	var prize_remaining_after_cleanup: int = int(battle_scene.get("_pending_prize_remaining"))
	var handover_visible_for_prizes: bool = bool((battle_scene.get("_handover_panel") as Control).visible)

	battle_scene.call("_on_handover_confirmed")
	var view_after_prize_handover: int = int(battle_scene.get("_view_player"))
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	await tree.create_timer(0.36).timeout
	await tree.process_frame
	var pending_after_first_prize: String = str(battle_scene.get("_pending_choice"))
	var remaining_after_first_prize: int = int(battle_scene.get("_pending_prize_remaining"))
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	await tree.create_timer(0.36).timeout
	await tree.process_frame
	var pending_after_prizes: String = str(battle_scene.get("_pending_choice"))
	var handover_visible_for_send_out: bool = bool((battle_scene.get("_handover_panel") as Control).visible)

	battle_scene.call("_on_handover_confirmed")
	var view_after_send_out_handover: int = int(battle_scene.get("_view_player"))
	var send_out_player_after_handover: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))
	battle_scene.call("_on_dialog_card_chosen", 0)
	await tree.process_frame
	var active_after_send_out: PokemonSlot = gsm.game_state.players[1].active_pokemon
	var pending_after_send_out: String = str(battle_scene.get("_pending_choice"))
	var phase_after_send_out: int = gsm.game_state.phase
	var current_player_after_send_out: int = gsm.game_state.current_player_index
	var view_after_send_out: int = int(battle_scene.get("_view_player"))

	var result := run_checks([
		assert_eq(attack_discard_pending_choice, "effect_interaction", "Pikachu ex attack should first ask which attached Energy to discard"),
		assert_true(pikachu_attack_effect_count > 0, "Pikachu ex fixture should have its discard-Energy attack effect registered"),
		assert_true(pikachu_attack_step_count > 0, "Pikachu ex fixture attack effect should expose discard-Energy interaction steps"),
		assert_eq(
			int(attack_discard_dialog_data.get("min_select", 0)),
			3,
			"Pikachu ex attack should require three discarded Energy cards; dialog=%s" % JSON.stringify(attack_discard_dialog_data)
		),
		assert_eq(int(attack_discard_dialog_data.get("max_select", 0)), 3, "Pikachu ex attack should cap discarded Energy selection at three"),
		assert_eq(attack_discard_items.size(), 3, "Pikachu ex attack fixture should expose exactly three Energy choices"),
		assert_true(attack_discard_confirm_enabled, "Selecting three Energy cards should enable the attack interaction confirm"),
		assert_true(attack_resolved, "Pikachu ex attack should knock out the opposing Terapagos ex"),
		assert_eq(pending_after_attack, "effect_interaction", "KO should enter Area Zero cleanup before prizes"),
		assert_eq(cleanup_chooser_after_attack, 1, "The knocked-out defender should choose excess Bench Pokemon"),
		assert_true(active_vfx_count_after_attack > 0, "The real attack VFX should be active when cleanup is requested"),
		assert_true(delay_active_after_attack, "Cleanup handover should be delayed while attack VFX is active"),
		assert_false(handover_visible_during_vfx, "The handover panel should not cover the attack animation"),
		assert_false(dialog_visible_during_vfx, "Cleanup cards should not be shown before the delayed handover"),
		assert_false(delay_active_after_vfx, "The delayed handover should finish after attack VFX completes"),
		assert_true(handover_visible_after_vfx, "After attack VFX, the UI should ask to hand over to the defender"),
		assert_false(dialog_visible_after_vfx, "Cleanup cards should still wait for defender handover confirmation"),
		assert_eq(view_before_cleanup_handover, 0, "The attacker should remain visible until handover is confirmed"),
		assert_true(pending_action_after_vfx.is_valid(), "The VFX-delayed handover should install the cleanup follow-up"),
		assert_eq(view_after_cleanup_handover, 1, "Confirming handover should switch to the defender"),
		assert_true(dialog_visible_after_handover, "The defender should see the Area Zero cleanup dialog after handover"),
		assert_true(first_cleanup_item is PokemonSlot, "Cleanup dialog should expose Bench PokemonSlot items"),
		assert_eq(pending_after_cleanup, "take_prize", "After cleanup, the attacker should be prompted to take prizes"),
		assert_eq(prize_player_after_cleanup, 0, "The attacker should take Terapagos ex prizes after cleanup"),
		assert_eq(prize_remaining_after_cleanup, 2, "KOing Terapagos ex should require two prizes"),
		assert_true(handover_visible_for_prizes, "After defender cleanup, the UI should hand back to the attacker for prizes"),
		assert_eq(view_after_prize_handover, 0, "Prize handover should switch back to the attacker"),
		assert_eq(pending_after_first_prize, "take_prize", "After one prize, the second prize should still be pending"),
		assert_eq(remaining_after_first_prize, 1, "Only one prize should remain after the first prize"),
		assert_eq(pending_after_prizes, "send_out", "After prizes, the defender should be asked to send out a replacement"),
		assert_true(handover_visible_for_send_out, "After prizes, the UI should hand over to the defender for replacement"),
		assert_eq(view_after_send_out_handover, 1, "Send-out handover should switch to the defender"),
		assert_eq(send_out_player_after_handover, 1, "Send-out prompt should belong to the knocked-out defender"),
		assert_true(active_after_send_out != null, "The defender should have an Active Pokemon after replacement"),
		assert_eq(pending_after_send_out, "", "The cleanup, prize, and send-out chain should fully resolve"),
		assert_eq(phase_after_send_out, GameState.GamePhase.MAIN, "After replacement, the battle should return to MAIN"),
		assert_eq(current_player_after_send_out, 1, "After the attack knockout flow, turn should pass to the defender"),
		assert_eq(view_after_send_out, 1, "After replacement, the visible player should remain the new current player"),
	])
	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout
	if is_instance_valid(battle_scene):
		battle_scene.queue_free()
		await tree.process_frame
	return result


func test_battle_scene_vs_ai_area_zero_bench_tera_ko_cleanup_confirm_discards_multiple() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	battle_scene._setup_ai_for_tests()
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	battle_scene.set("_ai_opponent", ai)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 6
	gsm.game_state.phase = GameState.GamePhase.POKEMON_CHECK
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.deck.append(CardInstance.create(_make_pokemon_cd("Bench KO Deck %d" % pi, 60, "C"), pi))
		gsm.game_state.players.append(player)

	var human_active := PokemonSlot.new()
	human_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Human Non Tera Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = human_active

	var bench_tera_cd := _make_pokemon_cd("Human Bench Tera ex", 230, "C")
	bench_tera_cd.mechanic = "ex"
	bench_tera_cd.is_tags = PackedStringArray(["Tera"])
	var bench_tera := PokemonSlot.new()
	bench_tera.pokemon_stack.append(CardInstance.create(bench_tera_cd, 0))
	bench_tera.damage_counters = 230
	gsm.game_state.players[0].bench.append(bench_tera)

	var discard_a := PokemonSlot.new()
	discard_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Area Zero Bench Discard A", 90, "C"), 0))
	var discard_b := PokemonSlot.new()
	discard_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Area Zero Bench Discard B", 90, "C"), 0))
	gsm.game_state.players[0].bench.append(discard_a)
	gsm.game_state.players[0].bench.append(discard_b)
	for bench_index: int in 5:
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Area Zero Bench Survivor %d" % bench_index, 90, "C"), 0))
		gsm.game_state.players[0].bench.append(bench_slot)

	var ai_active := PokemonSlot.new()
	ai_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("AI Active Bench KO", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = ai_active

	for prize_index: int in 3:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_trainer_cd("Human Bench KO Prize %d" % prize_index, "Item", ""), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_trainer_cd("AI Bench KO Prize %d" % prize_index, "Item", ""), 1))

	var zero_cd := _make_trainer_cd("Area Zero Underdepths", "Stadium", "")
	zero_cd.effect_id = EffectAreaZeroUnderdepthsScript.EFFECT_ID
	gsm.game_state.stadium_card = CardInstance.create(zero_cd, 1)
	gsm.game_state.stadium_owner_index = 1

	gsm.call("_check_all_knockouts")
	var cleanup_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var cleanup_chooser: int = int(battle_scene.call("_get_effect_interaction_prompt_player_index"))
	var cleanup_dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var confirm_visible_before: bool = bool((battle_scene.get("_dialog_confirm") as Button).visible)
	var confirm_disabled_initial: bool = bool((battle_scene.get("_dialog_confirm") as Button).disabled)
	var cleanup_items: Array = cleanup_dialog_data.get("card_items", [])
	var first_item: Variant = cleanup_items[0] if not cleanup_items.is_empty() else null
	var second_item: Variant = cleanup_items[1] if cleanup_items.size() > 1 else null

	battle_scene.call("_on_dialog_card_chosen", 0)
	var confirm_disabled_after_one: bool = bool((battle_scene.get("_dialog_confirm") as Button).disabled)
	var pending_after_one: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_on_dialog_card_chosen", 1)
	var confirm_disabled_after_two: bool = bool((battle_scene.get("_dialog_confirm") as Button).disabled)
	battle_scene.call("_on_dialog_confirm")
	var pending_after_cleanup: String = str(battle_scene.get("_pending_choice"))
	var prize_player_after_cleanup: int = int(battle_scene.get("_pending_prize_player_index"))
	var prize_remaining_after_cleanup: int = int(battle_scene.get("_pending_prize_remaining"))
	var ai_scheduled_after_cleanup: bool = bool(battle_scene.get("_ai_step_scheduled"))
	var cleanup_dialog_overlay: Control = battle_scene.get("_dialog_overlay") as Control
	var cleanup_field_overlay: Control = battle_scene.get("_field_interaction_overlay") as Control
	var ai_cleanup_diagnostics := "ready=%s blocking=%s draw=%s coin=%s dialog=%s field=%s state=%s effect=%s" % [
		str(battle_scene.call("_is_ai_turn_ready")),
		str(battle_scene.call("_is_ui_blocking_ai")),
		str(battle_scene.get("_draw_reveal_active")),
		str(battle_scene.call("_has_pending_coin_animation")),
		str(cleanup_dialog_overlay != null and cleanup_dialog_overlay.visible),
		str(cleanup_field_overlay != null and cleanup_field_overlay.visible),
		str(battle_scene.call("_state_snapshot")),
		str(battle_scene.call("_effect_state_snapshot")),
	]
	var discarded_a: bool = discard_a not in gsm.game_state.players[0].bench
	var discarded_b: bool = discard_b not in gsm.game_state.players[0].bench
	var bench_tera_removed: bool = bench_tera not in gsm.game_state.players[0].bench
	var active_still_alive: bool = gsm.game_state.players[0].active_pokemon == human_active
	var bench_size_after_cleanup: int = gsm.game_state.players[0].bench.size()

	var result := run_checks([
		assert_eq(cleanup_pending_choice, "effect_interaction", "Bench Tera KO should open an Area Zero cleanup interaction before prizes"),
		assert_eq(cleanup_chooser, 0, "Bench Tera cleanup should remain a human-owned prompt even when the AI owns the Stadium"),
		assert_eq(int(cleanup_dialog_data.get("min_select", 0)), 2, "Losing a Bench Tera from an eight-Pokemon Bench should require two discards"),
		assert_eq(int(cleanup_dialog_data.get("max_select", 0)), 2, "The cleanup dialog should cap selection at the exact excess count"),
		assert_true(confirm_visible_before, "Multi-discard cleanup should expose a confirm button"),
		assert_true(confirm_disabled_initial, "Confirm should start disabled before the required two cards are selected"),
		assert_true(first_item is PokemonSlot, "The first cleanup card item should be a Bench PokemonSlot"),
		assert_true(second_item is PokemonSlot, "The second cleanup card item should be a Bench PokemonSlot"),
		assert_eq(pending_after_one, "effect_interaction", "Selecting only one card should not prematurely resolve a two-discard cleanup"),
		assert_true(confirm_disabled_after_one, "Confirm should remain disabled until the second required discard is selected"),
		assert_false(confirm_disabled_after_two, "Confirm should become enabled once exactly two discards are selected"),
		assert_eq(pending_after_cleanup, "take_prize", "Confirming the two discards should restore the AI prize prompt"),
		assert_eq(prize_player_after_cleanup, 1, "The AI should take prizes after Bench Tera cleanup"),
		assert_eq(prize_remaining_after_cleanup, 2, "Bench Tera ex knockout should award two prizes"),
		assert_true(ai_scheduled_after_cleanup, "Confirming the cleanup should schedule the AI prize continuation | %s" % ai_cleanup_diagnostics),
		assert_true(bench_tera_removed, "The knocked-out Bench Tera should already be removed from the Bench"),
		assert_true(discarded_a, "The first selected excess Bench Pokemon should be discarded"),
		assert_true(discarded_b, "The second selected excess Bench Pokemon should be discarded"),
		assert_true(active_still_alive, "A Bench knockout cleanup must not clear the living Active Pokemon"),
		assert_eq(bench_size_after_cleanup, 5, "The Bench should be trimmed to five after the multi-discard cleanup"),
	])
	GameManager.current_mode = previous_mode
	battle_scene.free()
	return result


