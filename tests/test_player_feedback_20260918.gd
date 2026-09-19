extends "res://tests/helpers/BattleUIFeaturesShared.gd"


func _real_card(uid: String) -> CardData:
	return CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % uid)))


func _slot_for(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _feedback_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot_for(_make_pokemon_cd("Active %d" % owner, 500, "C"), owner)
		for i: int in 6:
			player.prizes.append(CardInstance.create(_make_trainer_cd("Prize", "Item", ""), owner))
			player.deck.append(CardInstance.create(_make_trainer_cd("Deck", "Item", ""), owner))
		gsm.game_state.players.append(player)
	return gsm


func _feedback_scene(gsm: GameStateMachine) -> Control:
	var scene := _make_battle_scene_stub()
	# The shared stub stores detached controls. Give these test controls an
	# owner so freeing the scene also frees their generated card views.
	for property: Dictionary in scene.get_property_list():
		if not str(property.name).begins_with("_"):
			continue
		var value: Variant = scene.get(property.name)
		if value is Node and value.get_parent() == null:
			scene.add_child(value)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	gsm.state_changed.connect(scene._on_state_changed)
	return scene


func test_real_iron_leaves_player_selects_energy_from_two_pokemon() -> String:
	var gsm := _feedback_gsm()
	var scene := _feedback_scene(gsm)
	var player := gsm.game_state.players[0]
	var old_active := player.active_pokemon
	var donor := _slot_for(_make_pokemon_cd("Other donor", 130, "G"), 0)
	player.bench.append(donor)
	var grass := CardInstance.create(_real_card("CSVE1C_GRA"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic", "P"), 0)
	var keep := CardInstance.create(_make_energy_cd("Fire", "R"), 0)
	old_active.attached_energy.assign([grass, keep])
	donor.attached_energy.append(psychic)
	var leaves := CardInstance.create(_real_card("CSV7C_033"), 0)
	player.hand.append(leaves)
	scene.call("_try_play_to_bench", 0, leaves, "my_bench_1")
	var steps: Array = scene.get("_pending_effect_steps")
	var checks: Array[String] = [assert_eq(steps.size(), 1, "Real Iron Leaves should open its Energy chooser")]
	if not steps.is_empty():
		var items: Array = steps[0].get("items", [])
		scene.call("_handle_effect_interaction_choice", PackedInt32Array([items.find(psychic), items.find(grass)]))
	checks.append(assert_true(player.active_pokemon.get_top_card() == leaves, "Iron Leaves must switch in"))
	checks.append(assert_eq(player.active_pokemon.attached_energy, [psychic, grass], "Both selected Energy must reach Iron Leaves in selection order"))
	checks.append(assert_eq(old_active.attached_energy, [keep], "Unselected Energy must remain on its source"))
	checks.append(assert_true(donor.attached_energy.is_empty(), "The second source must lose its selected Energy"))
	scene.free()
	return run_checks(checks)


func test_real_scramble_switch_keeps_picker_available_for_multiple_energy() -> String:
	var gsm := _feedback_gsm()
	var scene := _feedback_scene(gsm)
	var player := gsm.game_state.players[0]
	var old_active := player.active_pokemon
	var incoming := _slot_for(_make_pokemon_cd("Incoming", 200, "G"), 0)
	player.bench.append(incoming)
	for i: int in 3:
		old_active.attached_energy.append(CardInstance.create(_real_card("CSVE1C_GRA"), 0))
	var energy := old_active.attached_energy.duplicate()
	var card := CardInstance.create(_real_card("CSV9C_180"), 0)
	player.hand.append(card)
	scene.call("_try_play_trainer_with_interaction", 0, card)
	scene.call("_handle_field_slot_select_index", 0)
	var checks: Array[String] = [assert_eq(str(scene.get("_field_interaction_mode")), "assignment", "Scramble Switch must open the real assignment chooser")]
	for i: int in 2:
		var scroll := scene.get("_field_interaction_scroll") as ScrollContainer
		checks.append(assert_true(scroll != null and scroll.visible, "Energy picker must remain available before selection %d" % (i + 1)))
		scene.call("_on_field_assignment_source_chosen", i)
		scene.call("_handle_field_assignment_target_index", 0)
	scene.call("_finalize_field_assignment_selection")
	checks.append(assert_true(player.active_pokemon == incoming, "Scramble Switch must switch to the selected target"))
	checks.append(assert_eq(incoming.attached_energy, [energy[0], energy[1]], "Two selected physical Energy must transfer"))
	checks.append(assert_eq(old_active.attached_energy, [energy[2]], "The unselected third Energy must stay"))
	checks.append(assert_true(card in player.discard_pile, "Successful Scramble Switch must be consumed"))
	scene.free()
	return run_checks(checks)


func test_real_slowking_copied_trifrost_hits_only_three_clicked_bench_targets() -> String:
	var gsm := _feedback_gsm()
	var scene := _feedback_scene(gsm)
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var slowking := _slot_for(_real_card("CSV9C_072"), 0)
	player.active_pokemon = slowking
	for i: int in 2:
		slowking.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic", "P"), 0))
	var kyurem := CardInstance.create(_real_card("CSV9C_147"), 0)
	player.deck.push_front(kyurem)
	for i: int in 5:
		opponent.bench.append(_slot_for(_make_pokemon_cd("Bench %d" % i, 500, "C"), 1))
	gsm.effect_processor.register_pokemon_card(slowking.get_card_data())
	gsm.effect_processor.register_pokemon_card(kyurem.card_data)
	var effects := gsm.effect_processor.get_attack_effects_for_slot(slowking, 0)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in effects:
		steps.append_array(effect.get_attack_interaction_steps(slowking.get_top_card(), slowking.get_card_data().attacks[0], gsm.game_state))
	scene.call("_start_effect_interaction", "attack", 0, steps, slowking.get_top_card(), slowking, 0, {}, effects)
	scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var checks: Array[String] = [assert_eq(str(scene.get("_field_interaction_mode")), "slot_select", "Copied Trifrost must expose field targets")]
	var chosen: Array = [opponent.bench[4], opponent.bench[1], opponent.bench[3]]
	for target: PokemonSlot in chosen:
		var data: Dictionary = scene.get("_field_interaction_data")
		var items: Array = data.get("items", [])
		scene.call("_handle_field_slot_select_index", items.find(target))
	for target: PokemonSlot in opponent.get_all_pokemon():
		checks.append(assert_eq(target.damage_counters, 110 if target in chosen else 0, "Damage must match clicked identity: %s" % target.get_pokemon_name()))
	checks.append(assert_true(kyurem in player.discard_pile, "The revealed Kyurem must be discarded"))
	checks.append(assert_true(slowking.attached_energy.is_empty(), "Copied Trifrost must discard Slowking's Energy"))
	scene.free()
	return run_checks(checks)


func test_festival_lead_defiance_band_rechecks_prizes_between_attacks() -> String:
	var gsm := _feedback_gsm()
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var dipplin := _slot_for(_real_card("CSV8C_024"), 0)
	player.active_pokemon = dipplin
	dipplin.attached_energy.append(CardInstance.create(_real_card("CSVE1C_GRA"), 0))
	dipplin.attached_tool = CardInstance.create(_real_card("CSV1C_117"), 0)
	gsm.effect_processor.register_pokemon_card(dipplin.get_card_data())
	gsm.game_state.stadium_card = CardInstance.create(_real_card("CSV8C_201"), 0)
	for i: int in 5:
		player.bench.append(_slot_for(_make_pokemon_cd("Bench %d" % i, 100, "G"), 0))
	opponent.prizes.pop_back()
	var checks: Array[String] = [assert_eq(gsm.get_attack_preview_damage(0, 0), 130, "Five Benched Pokemon plus active Defiance Band must preview 130")]
	checks.append(assert_true(gsm.use_attack(0, 0), "First Festival Lead attack must execute"))
	checks.append(assert_eq(opponent.active_pokemon.damage_counters, 130, "First attack must deal 100 + 30, without multiplying the Tool bonus"))
	player.prizes.pop_back()
	checks.append(assert_eq(gsm.get_attack_preview_damage(0, 0), 100, "Tied prizes must disable Defiance Band before the second attack"))
	checks.append(assert_true(gsm.use_attack(0, 0), "Second Festival Lead attack must execute"))
	checks.append(assert_eq(opponent.active_pokemon.damage_counters, 230, "The second attack must recalculate the Tool condition"))
	return run_checks(checks)


func test_tablet_landscape_end_turn_and_hand_fit_real_viewports() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_layout := GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	var checks: Array[String] = []
	for dimensions: Vector2i in [Vector2i(1024, 768), Vector2i(1280, 800), Vector2i(1340, 800), Vector2i(1600, 960), Vector2i(1600, 1200), Vector2i(1920, 1200), Vector2i(2560, 1600)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		tree.root.add_child(viewport)
		var scene: Control = BattleScenePacked.instantiate()
		viewport.add_child(scene)
		await tree.process_frame
		var gsm := _feedback_gsm()
		for player: PlayerState in gsm.game_state.players:
			for i: int in 5:
				player.bench.append(_slot_for(_real_card("CSV7C_033"), player.player_index))
			for i: int in 7:
				player.hand.append(CardInstance.create(_real_card("CSVE1C_GRA"), player.player_index))
		scene.set("_gsm", gsm)
		scene.set("_view_player", 0)
		scene.call("_refresh_ui")
		scene.call("_apply_landscape_layout", Vector2(dimensions))
		for i: int in 4:
			await tree.process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for node_name: String in ["MainArea", "HudEndTurnBtn", "HandArea", "MyBench", "OppBench", "MyHudLeft", "OppHudLeft", "LogPanel"]:
			var control := scene.find_child(node_name, true, false) as Control
			var rect := control.get_global_rect() if control != null else Rect2()
			checks.append(assert_true(control != null and control.is_visible_in_tree(), "%s must be visible at %s" % [node_name, dimensions]))
			checks.append(assert_true(rect.size.x > 0 and rect.size.y > 0 and bounds.grow(1).encloses(rect), "%s must fit %s: %s" % [node_name, dimensions, rect]))
		var hand_container: HBoxContainer = scene.get("_hand_container")
		for hand_card: Control in hand_container.get_children():
			if hand_card is BattleCardView:
				var info: Control = hand_card.get("_info_panel")
				checks.append(assert_true(hand_card.get_global_rect().grow(1).encloses(info.get_global_rect()), "Hand card caption must stay inside its card at %s" % dimensions))
		if OS.get_cmdline_user_args().has("--capture-player-feedback") and DisplayServer.get_name() != "headless" and dimensions.x in [1024, 1600]:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			await RenderingServer.frame_post_draw
			var capture_path := "res://tmp/player_feedback_20260918/tablet_%dx%d.png" % [dimensions.x, dimensions.y]
			checks.append(assert_eq(viewport.get_texture().get_image().save_png(capture_path), OK, "Tablet preview capture must save"))
		# Re-layout the same live scene when Area Zero exposes all eight slots.
		for player: PlayerState in gsm.game_state.players:
			player.active_pokemon.get_card_data().ancient_trait = "Tera"
		gsm.game_state.stadium_card = CardInstance.create(_real_card("CSV9C_207"), 0)
		scene.call("_refresh_ui")
		scene.call("_apply_landscape_layout", Vector2(dimensions))
		for i: int in 4:
			await tree.process_frame
		for node_name: String in ["HudEndTurnBtn", "HandArea", "MyBench7", "OppBench7", "LogPanel"]:
			var control := scene.find_child(node_name, true, false) as Control
			checks.append(assert_true(control != null and control.is_visible_in_tree(), "%s must be visible with Area Zero at %s" % [node_name, dimensions]))
			if control != null:
				checks.append(assert_true(bounds.grow(1).encloses(control.get_global_rect()), "%s must fit with Area Zero at %s" % [node_name, dimensions]))
		viewport.queue_free()
		await tree.process_frame
	GameManager.battle_layout_mode = previous_layout
	return run_checks(checks)


func test_landscape_deck_delete_closes_dialog_and_preserves_other_rows() -> String:
	# Match the existing portrait deletion regression with the native dialog path.
	var fixtures := preload("res://tests/test_deck_delete_feedback_regressions.gd").new()
	var removed_id := 99180918
	var survivor_id := 99180919
	if CardDatabase.has_deck(removed_id) or CardDatabase.has_deck(survivor_id):
		return "Delete regression fixture IDs already exist; refusing to overwrite them"
	CardDatabase.save_deck(fixtures._make_deck(removed_id, "Landscape Delete Probe"))
	CardDatabase.save_deck(fixtures._make_deck(survivor_id, "Landscape Survivor Probe"))
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = fixtures.DeckManagerScene.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	scene.call("_apply_non_battle_layout_for_tests", Vector2(1280, 800), "landscape")
	var deck_list := scene.get_node("%DeckList")
	var survivor_before: Control = fixtures._deck_row_with_id(deck_list, survivor_id)
	scene.call("_on_delete_deck", CardDatabase.get_deck(removed_id))
	var dialogs := scene.find_children("*", "ConfirmationDialog", true, false)
	var checks: Array[String] = [assert_eq(dialogs.size(), 1, "Landscape deletion must show its confirmation dialog")]
	if not dialogs.is_empty():
		var dialog := dialogs[0] as ConfirmationDialog
		dialog.confirmed.emit()
		checks.append(assert_false(dialog.visible, "Confirmation must close inside the callback"))
		checks.append(assert_true(CardDatabase.has_deck(removed_id), "Deletion must wait until the input callback finishes"))
		await tree.process_frame
		checks.append(assert_false(CardDatabase.has_deck(removed_id), "The selected deck must be deleted on the next frame"))
		checks.append(assert_null(fixtures._deck_row_with_id(deck_list, removed_id), "The deleted row must be removed"))
		checks.append(assert_true(is_instance_valid(survivor_before) and fixtures._deck_row_with_id(deck_list, survivor_id) == survivor_before, "Unrelated rows must survive without a full rebuild"))
	scene.queue_free()
	await tree.process_frame
	for deck_id: int in [removed_id, survivor_id]:
		if CardDatabase.has_deck(deck_id):
			CardDatabase.delete_deck(deck_id)
	return run_checks(checks)
