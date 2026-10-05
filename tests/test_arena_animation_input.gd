extends TestBase

const Scenario := preload("res://scripts/tools/ArenaSignatureScenario.gd")
var saved: Array

func _open() -> Node:
	saved = [GameManager.battle_3d_enabled, GameManager.current_mode, GameManager.battle_effects_enabled, GameManager.battle_layout_mode, GameManager.ui_runtime_profile]
	var rig := Scenario.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	await rig.mount("dragapult", 0)
	rig.battle.get_node("Arena3DPresenter").world.sound_enabled = false
	return rig

func _close(rig: Node) -> void:
	await rig.close()
	rig.free()
	GameManager.battle_3d_enabled = saved[0]
	GameManager.current_mode = saved[1]
	GameManager.battle_effects_enabled = saved[2]
	GameManager.battle_layout_mode = saved[3]
	GameManager.ui_runtime_profile = saved[4]

func _add_card(rig: Node, set_code: String, index: String) -> CardInstance:
	var player: PlayerState = rig.gsm.game_state.players[0]
	var card := CardInstance.create(CardDatabase.get_card(set_code, index), 0)
	player.deck.pop_back()
	player.hand.append(card)
	rig.battle.call("_refresh_ui")
	return card

func _mouse(presenter: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	presenter._on_input(event)

func _touch(scene: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	scene.get("_arena_touch").handle(event)

func test_pokemon_transfer_allows_touch_attachment_and_shows_current_damage() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	var presenter: Control = scene.get_node("Arena3DPresenter")
	rig.transfer()
	presenter._refresh()
	var player: PlayerState = rig.gsm.game_state.players[0]
	var energy: CardInstance = player.hand[2]
	var before := player.bench[0].attached_energy.size()
	var checks: Array[String] = [
		assert_true(presenter.motion.is_busy(), "The real Munkidori performance is active"),
		assert_true(scene.call("_can_view_player_start_turn_action"), "The next card is available during Pokemon animation"),
		assert_eq(presenter.motion.shown.slots.my_active.damage, player.active_pokemon.damage_counters, "Selectable board exposes the committed damage"),
	]
	scene.call("_on_hand_card_clicked", energy, null)
	presenter._refresh()
	var point: Vector2 = presenter.get_global_transform() * presenter.world.project(presenter.world.cards.my_bench_0.node.position)
	checks.append(assert_eq(presenter.touch_target(point).get("id"), "my_bench_0", "Touch picking remains active during performance"))
	_touch(scene, point, true)
	_touch(scene, point, false)
	checks.append(assert_eq(player.bench[0].attached_energy.size(), before + 1, "A physical touch commits exactly one energy attachment"))
	checks.append(assert_true(presenter.motion.is_busy(), "The Pokemon animation keeps playing"))
	await _close(rig)
	return run_checks(checks)

func test_required_choice_and_opponent_turn_still_block_new_cards() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	rig.transfer()
	var supporter := _add_card(rig, "CSVH1aC", "023")
	var energy: CardInstance = rig.gsm.game_state.players[0].hand[2]
	scene.call("_on_hand_card_clicked", supporter, null)
	var checks: Array[String] = [assert_false(scene.call("_can_view_player_start_turn_action"), "An unresolved target choice remains exclusive")]
	scene.call("_on_hand_card_clicked", energy, null)
	checks.append(assert_true(scene.get("_selected_hand_card") != energy, "Cannot start another card inside a required choice"))
	scene.call("_on_dialog_cancel")
	rig.gsm.game_state.current_player_index = 1
	checks.append(assert_false(scene.call("_can_view_player_start_turn_action"), "Opponent turn never becomes a human action window"))
	await _close(rig)
	return run_checks(checks)

func test_dragging_a_card_during_ability_animation_commits_once() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	var presenter: Control = scene.get_node("Arena3DPresenter")
	rig.transfer()
	await (Engine.get_main_loop() as SceneTree).process_frame
	presenter._refresh()
	var player: PlayerState = rig.gsm.game_state.players[0]
	var energy: CardInstance = player.hand[2]
	var before := player.active_pokemon.attached_energy.size()
	var card_view: BattleCardView
	for view: BattleCardView in scene.get("_hand_container").get_children():
		if view.card_instance == energy: card_view = view
	var drag := preload("res://scenes/arena3d/ArenaHandDrag.gd").new()
	drag.scene = scene
	var start: Vector2 = card_view.get_global_transform() * (card_view.size * .5)
	var target_point: Vector2 = presenter.get_global_transform() * presenter.world.project(presenter.world.cards.my_active.node.position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	drag.handle(press)
	var move := InputEventMouseMotion.new()
	move.position = target_point
	drag.handle(move)
	var checks: Array[String] = [
		assert_true(presenter.motion.is_busy(), "The real character is still playing during drag"),
		assert_true(drag.active, "Dragging starts during the cinematic"),
	]
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = target_point
	drag.handle(release)
	drag.handle(release)
	checks.append(assert_eq(player.active_pokemon.attached_energy.size(), before + 1, "Drag release commits once; duplicate release cannot replay it"))
	checks.append(assert_true(presenter.motion.is_busy(), "Drag does not stop the character"))
	drag.cancel()
	await _close(rig)
	return run_checks(checks)

func test_ability_mouse_gesture_rejects_changed_window_then_accepts_fresh_target() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	var presenter: Control = scene.get_node("Arena3DPresenter")
	rig.transfer()
	var player: PlayerState = rig.gsm.game_state.players[0]
	var energy: CardInstance = player.hand[2]
	var before := player.active_pokemon.attached_energy.size()
	scene.call("_on_hand_card_clicked", energy, null)
	presenter._refresh()
	var point: Vector2 = presenter.world.project(presenter.world.cards.my_active.node.position)
	_mouse(presenter, point, true)
	# A real board change invalidates the gesture without adding a draw barrier.
	rig.gsm.game_state.players[1].active_pokemon.damage_counters += 10
	_mouse(presenter, point, false)
	var checks: Array[String] = [assert_eq(player.active_pokemon.attached_energy.size(), before, "Stale mouse release cannot commit to a changed window")]
	scene.call("_refresh_ui")
	presenter._refresh()
	_mouse(presenter, point, true)
	_mouse(presenter, point, false)
	checks.append(assert_eq(player.active_pokemon.attached_energy.size(), before + 1, "A fresh mouse gesture works while the ability is still playing"))
	checks.append(assert_true(presenter.motion.is_busy(), "Mouse input never cancels the ability"))
	await _close(rig)
	return run_checks(checks)

func test_supporter_after_ability_restores_the_original_input_and_board_hold() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	var presenter: Control = scene.get_node("Arena3DPresenter")
	rig.transfer()
	presenter._refresh()
	var checks: Array[String] = [assert_true(scene.call("_can_view_player_start_turn_action"), "Ability allows the next action")]
	var supporter := _add_card(rig, "CSVH1aC", "023")
	var target: PokemonSlot = rig.gsm.game_state.players[1].bench[1]
	var old_name: String = presenter.motion.shown.slots.opp_active.name
	checks.append(assert_true(rig.gsm.play_trainer(0, supporter, [{"opponent_bench_target": [target]}]), "The real Supporter commits"))
	presenter._refresh()
	checks.append(assert_false(scene.call("_can_view_player_start_turn_action"), "Supporter retains its original animation input lock"))
	checks.append(assert_eq(presenter.motion.shown.slots.opp_active.name, old_name, "Supporter retains its original pre-effect board hold"))
	var point: Vector2 = presenter.get_global_transform() * presenter.world.project(presenter.world.cards.my_active.node.position)
	checks.append(assert_true(presenter.touch_target(point).is_empty(), "Supporter retains its touch input lock"))
	await _close(rig)
	return run_checks(checks)

func test_attack_after_ability_restores_the_original_input_lock() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	var presenter: Control = scene.get_node("Arena3DPresenter")
	rig.transfer()
	presenter._refresh()
	var checks: Array[String] = [assert_true(scene.call("_can_view_player_start_turn_action"), "Ability allows the next action")]
	rig.attack()
	checks.append(assert_false(presenter.motion.allows_live_actions_during_ability(), "Committed attack immediately retires the ability exception"))
	await (Engine.get_main_loop() as SceneTree).process_frame
	checks.append(assert_true(presenter.motion.attack_count > 0, "The real attack presentation starts"))
	checks.append(assert_true(presenter.motion.is_busy(), "Attack keeps its original animation barrier"))
	checks.append(assert_false(scene.call("_can_view_player_start_turn_action"), "Attack keeps its original action lock"))
	var point: Vector2 = presenter.get_global_transform() * presenter.world.project(presenter.world.cards.my_active.node.position)
	checks.append(assert_true(presenter.touch_target(point).is_empty(), "Attack keeps its original touch lock"))
	await _close(rig)
	return run_checks(checks)

func test_draw_and_reward_sequences_keep_their_original_locks_during_ability() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	var presenter: Control = scene.get_node("Arena3DPresenter")
	rig.transfer()
	presenter._refresh()
	var checks: Array[String] = [assert_true(scene.call("_can_view_player_start_turn_action"), "Ability begins with live input")]
	rig.gsm.draw_cards_for_effect(0, 1)
	checks.append(assert_true(presenter.motion.hand_transfer.is_busy(), "Real draw enters the existing flight queue"))
	checks.append(assert_false(scene.call("_can_view_player_start_turn_action"), "Draw remains blocking even when an ability was already playing"))
	presenter.motion.hand_transfer.clear()
	checks.append(assert_true(scene.call("_can_view_player_start_turn_action"), "Only the remaining ability yields input"))
	presenter.motion.queue_prize_reward(0, 1, true)
	checks.append(assert_false(scene.call("_can_view_player_start_turn_action"), "Reward presentation keeps its original lock"))
	presenter.motion.clear()
	checks.append(assert_false(presenter.motion.allows_live_actions_during_ability(), "Cleanup retires the ability exception"))
	await _close(rig)
	return run_checks(checks)

func test_psychic_embrace_keeps_playing_while_a_hand_card_is_used() -> String:
	var rig := await _open()
	var scene: Control = rig.battle
	var presenter: Control = scene.get_node("Arena3DPresenter")
	var player: PlayerState = rig.gsm.game_state.players[0]
	var data := CardDatabase.get_card("CSV2C", "055")
	player.active_pokemon = rig._slot(data, 0)
	rig.gsm.effect_processor.register_pokemon_card(data)
	player.discard_pile.append(CardInstance.create(rig._energy("P"), 0))
	while rig.gsm.count_player_total_cards(0) < 60: player.deck.append(CardInstance.create(rig._energy("R"), 0))
	while rig.gsm.count_player_total_cards(0) > 60: player.deck.pop_back()
	rig.combat_species = "gardevoir"
	scene.call("_refresh_ui")
	presenter._refresh()
	var resolved: bool = rig.perform_combat()
	presenter._refresh()
	var energy: CardInstance = player.hand[2]
	var before := player.active_pokemon.attached_energy.size()
	var checks: Array[String] = [
		assert_true(resolved, "Psychic Embrace resolves through its real fresh target choices"),
		assert_eq(presenter.world.signature_vfx.last_outcome.get("kind"), "embrace", "The real Gardevoir animation starts"),
		assert_true(scene.call("_can_view_player_start_turn_action"), "The first full Psychic Embrace animation already permits input"),
	]
	scene.call("_on_hand_card_clicked", energy, null)
	presenter._refresh()
	var point: Vector2 = presenter.world.project(presenter.world.cards.my_active.node.position)
	_mouse(presenter, point, true)
	_mouse(presenter, point, false)
	checks.append(assert_eq(player.active_pokemon.attached_energy.size(), before + 1, "A card can be used during the first Psychic Embrace"))
	checks.append(assert_true(presenter.motion.is_busy(), "The full Gardevoir performance continues"))
	await _close(rig)
	return run_checks(checks)
