extends "res://tests/helpers/BattleUIFeaturesShared.gd"


func test_ai_dusclops_self_knockout_keeps_human_portrait_prize_visible() -> String:
	return _check_self_knockout_prize("CSV8C_082", 50)


func test_ai_dusknoir_self_knockout_keeps_human_portrait_prize_visible() -> String:
	return _check_self_knockout_prize("CSV8C_083", 130)


func test_ai_self_knockout_prize_restores_opacity_after_hidden_ai_dialog() -> String:
	return _check_self_knockout_prize("CSV8C_082", 50, true)


func _make_self_knockout_scene(uid: String) -> Control:
	var scene := _prepare_real_portrait_battle_scene()
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 1
	state.first_player_index = 0
	state.turn_number = 10
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		var active := PokemonSlot.new()
		var data := _make_pokemon_cd("Active %d" % pi, 320, "C")
		data.abilities = []
		data.attacks = []
		active.pokemon_stack.append(CardInstance.create(data, pi))
		player.active_pokemon = active
		player.set_prizes(_make_named_deck_cards(pi, ["Prize 0", "Prize 1", "Prize 2", "Prize 3", "Prize 4", "Prize 5"]))
		player.deck.append_array(_make_named_deck_cards(pi, ["Deck 0", "Deck 1"]))
		state.players.append(player)
	var card := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % uid)))
	gsm.effect_processor.register_pokemon_card(card)
	var source := PokemonSlot.new()
	source.pokemon_stack.append(CardInstance.create(card, 1))
	state.players[1].bench.append(source)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	scene.set("_ai_opponent", ai)
	gsm.state_changed.connect(scene._on_state_changed)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	gsm.action_logged.connect(scene._on_action_logged)
	return scene


func _check_self_knockout_prize(uid: String, damage: int, previous_ai_dialog: bool = false) -> String:
	var old_mode: int = GameManager.current_mode
	var old_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene := _make_self_knockout_scene(uid)
	var gsm: GameStateMachine = scene.get("_gsm")
	var source: PokemonSlot = gsm.game_state.players[1].bench[0]
	var effect := gsm.effect_processor.get_effect(source.get_top_card().card_data.effect_id)
	var search_resolved := true
	if previous_ai_dialog:
		search_resolved = _play_ai_nest_ball(scene)
	scene.call("_try_use_ability_with_interaction", 1, source, 0)
	scene.call("_run_ai_step")
	var dialog := scene.get("_dialog_overlay") as Panel
	var host := scene.get("_my_prize_hud_host") as VBoxContainer
	var vbox := scene.get("_dialog_vbox") as VBoxContainer
	var before := run_checks([
		assert_true(search_resolved, "Prior real AI Nest Ball search must complete before self-KO"),
		assert_true(effect is AbilitySelfKnockoutDamageCounters, "Actual printing must register its self-KO effect"),
		assert_eq(gsm.game_state.players[0].active_pokemon.damage_counters, damage, "AI target selection must execute the actual card ability"),
		assert_false(source in gsm.game_state.players[1].bench, "Self-KO must remove the source"),
		assert_eq(str(scene.get("_pending_choice")), "take_prize", "Human must own the next required choice"),
		assert_eq(int(scene.get("_pending_prize_player_index")), 0),
		assert_true(dialog.visible, "AI effect cleanup must not hide the newly opened human Prize dialog"),
		assert_eq(dialog.modulate.a, 1.0, "Prize dialog must not inherit the transparent AI dialog"),
		assert_true(host.get_parent() == vbox, "Selectable Prize cards must remain in the visible dialog"),
	])
	var slots: Array[BattleCardView] = scene.get("_my_prize_slots")
	_send_prize_card_view_input(slots[0], "touch")
	var after := run_checks([
		assert_eq(gsm.game_state.players[0].prizes.size(), 5, "Touch must take exactly one prize"),
		assert_eq(gsm.game_state.players[0].hand.size(), 1),
		assert_eq(int(gsm.get("_pending_prize_remaining")), 0),
		assert_eq(str(scene.get("_pending_choice")), "", "Prize choice must finish without stale effect state"),
		assert_eq(gsm.game_state.current_player_index, 1, "Self-KO must resume the same AI turn"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN),
	])
	scene.free()
	GameManager.current_mode = old_mode
	GameManager.battle_layout_mode = old_layout
	return before if not before.is_empty() else after


func _play_ai_nest_ball(scene: Control) -> bool:
	var gsm: GameStateMachine = scene.get("_gsm")
	var data := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/CSVH1C_043.json")))
	var card := CardInstance.create(data, 1)
	gsm.game_state.players[1].hand.append(card)
	scene.call("_try_play_trainer_with_interaction", 1, card)
	var ai: Variant = scene.get("_ai_opponent")
	ai.run_single_step(scene, gsm)
	return card in gsm.game_state.players[1].discard_pile and gsm.game_state.players[1].bench.size() == 2
