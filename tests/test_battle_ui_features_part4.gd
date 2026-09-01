## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本

extends "res://tests/helpers/BattleUIFeaturesShared.gd"


func test_meowscarada_bouquet_magic_accepts_real_basic_grass_energy_through_battle_ui() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	var meowscarada_data: CardData = CardDatabase.get_card("CSV2C", "012")
	var grass_energy_data: CardData = CardDatabase.get_card("CSVE1C", "GRA")
	if meowscarada_data == null or grass_energy_data == null:
		GameManager.current_mode = previous_mode
		battle_scene.free()
		return "CSV2C_012 Meowscarada ex and the bundled Basic Grass Energy should load"
	gsm.effect_processor.register_pokemon_card(meowscarada_data)
	var meowscarada := PokemonSlot.new()
	meowscarada.pokemon_stack.append(CardInstance.create(meowscarada_data, 0))
	var own_active := PokemonSlot.new()
	own_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Own Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = own_active
	gsm.game_state.players[0].bench = [meowscarada]
	var grass_energy := CardInstance.create(grass_energy_data, 0)
	gsm.game_state.players[0].hand = [grass_energy]

	var opponent_active := PokemonSlot.new()
	opponent_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opponent Active", 300, "C"), 1))
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opponent Bench", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opponent_active
	gsm.game_state.players[1].bench = [bench_target]

	battle_scene.call("_show_pokemon_action_dialog", 0, meowscarada, false)
	var action_data: Dictionary = battle_scene.get("_dialog_data")
	var actions: Array = action_data.get("actions", [])
	var bouquet_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	var ability_option := _first_action_hud_option(battle_scene)
	_emit_action_hud_mouse_click(ability_option)
	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var energy_step: Dictionary = pending_steps[0] if not pending_steps.is_empty() else {}
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var target_field_mode := str(battle_scene.get("_field_interaction_mode"))
	var target_field_data: Dictionary = battle_scene.get("_field_interaction_data")
	if target_field_mode == "slot_select":
		battle_scene.call("_handle_field_slot_select_index", 0)

	var result := run_checks([
		assert_eq(str(bouquet_action.get("type", "")), "ability", "Meowscarada's first action should be Bouquet Magic"),
		assert_true(bool(bouquet_action.get("enabled", false)), "Benched Meowscarada should enable Bouquet Magic with a production Basic Grass Energy in hand"),
		assert_not_null(ability_option, "The enabled Bouquet Magic action should be clickable in the battle HUD"),
		assert_eq(str(energy_step.get("id", "")), "bouquet_magic_grass_energy", "The UI should open Bouquet Magic's Grass Energy cost step"),
		assert_eq(energy_step.get("items", []), [grass_energy], "The production Basic Grass Energy should be selectable as Bouquet Magic's cost"),
		assert_eq(target_field_mode, "slot_select", "After choosing the Energy, Bouquet Magic should open opponent-Bench field selection"),
		assert_eq(target_field_data.get("items", []), [bench_target], "Only the opponent's Benched Pokemon should be selectable"),
		assert_true(grass_energy in gsm.game_state.players[0].discard_pile, "The selected Basic Grass Energy should be discarded"),
		assert_eq(bench_target.damage_counters, 30, "Bouquet Magic should place exactly 3 damage counters through the battle UI"),
	])
	GameManager.current_mode = previous_mode
	battle_scene.free()
	return result


func test_slowking_inspiration_challenge_copies_kyurem_into_real_field_target_selection() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	var slowking_data: CardData = CardDatabase.get_card("CSV9C", "072")
	var kyurem_data: CardData = CardDatabase.get_card("CSV9C", "147")
	if slowking_data == null or kyurem_data == null:
		GameManager.current_mode = previous_mode
		battle_scene.free()
		return "CSV9C_072 Slowking and CSV9C_147 Kyurem should load"
	gsm.effect_processor.register_pokemon_card(slowking_data)
	gsm.effect_processor.register_pokemon_card(kyurem_data)

	var slowking := PokemonSlot.new()
	slowking.pokemon_stack.append(CardInstance.create(slowking_data, 0))
	slowking.attached_energy = [
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		CardInstance.create(_make_energy_cd("Colorless Energy", "C"), 0),
	]
	gsm.game_state.players[0].active_pokemon = slowking
	gsm.game_state.players[0].deck = [
		CardInstance.create(kyurem_data, 0),
		CardInstance.create(_make_pokemon_cd("Own deck filler", 60, "C"), 0),
	]

	var target_active := PokemonSlot.new()
	target_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target Active", 300, "C"), 1))
	var target_bench_a := PokemonSlot.new()
	target_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target Bench A", 300, "C"), 1))
	var target_bench_b := PokemonSlot.new()
	target_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target Bench B", 300, "C"), 1))
	gsm.game_state.players[1].active_pokemon = target_active
	gsm.game_state.players[1].bench = [target_bench_a, target_bench_b]
	gsm.game_state.players[1].deck = [CardInstance.create(_make_pokemon_cd("Opponent deck filler", 60, "C"), 1)]

	battle_scene.call("_try_use_attack_with_interaction", 0, slowking, 0)
	var copied_attack_option := _first_action_hud_option(battle_scene)
	_emit_action_hud_mouse_click(copied_attack_option)
	var field_mode := str(battle_scene.get("_field_interaction_mode"))
	var field_data: Dictionary = battle_scene.get("_field_interaction_data")
	var target_items: Array = field_data.get("items", [])
	if field_mode == "slot_select" and target_items.size() == 3:
		battle_scene.call("_handle_field_slot_select_index", 0)
	var selected_indices: Array = battle_scene.get("_field_interaction_selected_indices")

	var result := run_checks([
		assert_not_null(copied_attack_option, "Slowking should show Kyurem's copied attack in the action HUD"),
		assert_eq(field_mode, "slot_select", "Choosing Trifrost should switch the real battle UI to field target selection"),
		assert_eq(str(field_data.get("id", "")), "csv9c_tri_frost_targets", "The field selector should be Kyurem Trifrost's native target step"),
		assert_eq(target_items, [target_active, target_bench_a, target_bench_b], "Slowking should expose all three opposing Pokemon as Trifrost targets"),
		assert_eq(int(field_data.get("min_select", -1)), 3, "Copied Trifrost should require exactly three targets"),
		assert_eq(int(field_data.get("max_select", -1)), 3, "Copied Trifrost should keep the selector open until three targets are chosen"),
		assert_eq(selected_indices, [0], "The real field selector should accept an opponent Pokemon click"),
	])
	GameManager.current_mode = previous_mode
	battle_scene.free()
	return result

func test_battle_scene_iron_hands_ui_prize_and_turn_flow() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
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
		for di_amp_ui: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Amp UI Deck %d-%d" % [pi, di_amp_ui], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var iron_hands_cd: CardData = CardDatabase.get_card("CSV6C", "051")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(iron_hands_cd, 0))
	for energy_type: String in ["L", "L", "C", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(iron_hands_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := _make_pokemon_cd("Prize Target", 120, "W")
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var replacement_slot := PokemonSlot.new()
	replacement_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 120, "W"), 1))
	gsm.game_state.players[1].bench = [replacement_slot]
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 1)
	var first_pending_choice: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	var second_pending_choice: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	var handover_after_second_prize: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_on_handover_confirmed")
	var send_out_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var opp_deck_before_send_out: int = gsm.game_state.players[1].deck.size()
	battle_scene.call("_handle_field_slot_select_index", 0)
	var current_after_send_out: int = gsm.game_state.current_player_index
	var phase_after_send_out: int = gsm.game_state.phase
	var opp_deck_after_send_out: int = gsm.game_state.players[1].deck.size()
	var win_reason_after_send_out: String = gsm.game_state.win_reason
	var view_after_send_out: int = int(battle_scene.get("_view_player"))

	gsm.end_turn(1)
	var handover_back_to_player: bool = bool(battle_scene.get("_handover_panel").visible)
	var current_after_opponent_end: int = gsm.game_state.current_player_index
	var phase_after_opponent_end: int = gsm.game_state.phase
	var view_after_opponent_end: int = int(battle_scene.get("_view_player"))
	var pending_handover_valid: bool = (battle_scene.get("_pending_handover_action") as Callable).is_valid()
	battle_scene.call("_on_handover_confirmed")
	battle_scene.call("_show_attack_dialog", 0, attacker_slot)
	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var amp_action: Dictionary = actions[1] if actions.size() > 1 and actions[1] is Dictionary else {}

	var checks := run_checks([
		assert_eq(first_pending_choice, "take_prize", "Iron Hands ex Amp You Very Much should first enter prize selection"),
		assert_eq(second_pending_choice, "take_prize", "After the first prize, Iron Hands ex should still wait for the second prize"),
		assert_true(handover_after_second_prize, "Two-player mode should hand over to the opponent after the second prize"),
		assert_eq(send_out_mode, "slot_select", "After handover confirmation, Iron Hands ex should open the send-out field selector"),
		assert_eq(opp_deck_before_send_out, 3, "The opponent fixture should still have cards in deck before sending out"),
		assert_eq(current_after_send_out, 1, "After the defending player sends out a replacement, the turn should pass to the opponent"),
		assert_eq(opp_deck_after_send_out, 2, "After the defending player sends out a replacement, they should draw 1 card for turn"),
		assert_eq(phase_after_send_out, GameState.GamePhase.MAIN, "After replacement, the opponent should begin their turn in MAIN"),
		assert_eq(win_reason_after_send_out, "", "After replacement, the game should not immediately end"),
		assert_eq(view_after_send_out, 1, "After replacement, the view should follow the opponent turn"),
		assert_eq(current_after_opponent_end, 0, "After the opponent ends the turn, the current player should switch back to the player"),
		assert_eq(phase_after_opponent_end, GameState.GamePhase.MAIN, "After the opponent ends the turn, the next player should also be in MAIN"),
		assert_eq(view_after_opponent_end, 1, "Before the handover is confirmed, the view should still stay on the opponent side"),
		assert_false(pending_handover_valid, "The handover system should not be stuck with a stale deferred action after the opponent turn ends"),
		assert_true(handover_back_to_player, "After the opponent ends the turn, the UI should prompt to hand over back to the player"),
		assert_true(bool(amp_action.get("enabled", false)), "On the next turn, Amp You Very Much should still be enabled"),
		assert_eq(str(amp_action.get("reason", "")), "", "Amp You Very Much should not keep a stale disable reason"),
	])
	if checks != "":
		GameManager.current_mode = previous_mode
		return checks

	var arm_press_scene = _make_battle_scene_stub()
	var arm_press_gsm := GameStateMachine.new()
	arm_press_gsm.game_state = GameState.new()
	arm_press_gsm.game_state.current_player_index = 0
	arm_press_gsm.game_state.first_player_index = 0
	arm_press_gsm.game_state.turn_number = 2
	arm_press_gsm.game_state.phase = GameState.GamePhase.MAIN
	arm_press_scene.set("_gsm", arm_press_gsm)
	arm_press_scene.set("_view_player", 0)
	arm_press_gsm.state_changed.connect(arm_press_scene._on_state_changed)
	arm_press_gsm.player_choice_required.connect(arm_press_scene._on_player_choice_required)
	arm_press_gsm.action_logged.connect(arm_press_scene._on_action_logged)
	var arm_my_prize_slots: Array[BattleCardView] = []
	var arm_opp_prize_slots: Array[BattleCardView] = []
	for _j: int in 6:
		arm_my_prize_slots.append(BattleCardView.new())
		arm_opp_prize_slots.append(BattleCardView.new())
	arm_press_scene.set("_my_prize_slots", arm_my_prize_slots)
	arm_press_scene.set("_opp_prize_slots", arm_opp_prize_slots)

	for pi2: int in 2:
		var player2 := PlayerState.new()
		player2.player_index = pi2
		for dj: int in 3:
			player2.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi2, dj], 60, "C"), pi2))
		arm_press_gsm.game_state.players.append(player2)

	var arm_attacker := PokemonSlot.new()
	arm_attacker.pokemon_stack.append(CardInstance.create(iron_hands_cd, 0))
	for energy_type2: String in ["L", "L", "C"]:
		arm_attacker.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type2, energy_type2), 0))
	arm_press_gsm.effect_processor.register_pokemon_card(iron_hands_cd)
	arm_press_gsm.game_state.players[0].active_pokemon = arm_attacker
	var arm_defender := PokemonSlot.new()
	arm_defender.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Arm Press Target", 160, "W"), 1))
	arm_press_gsm.game_state.players[1].active_pokemon = arm_defender
	var arm_replacement := PokemonSlot.new()
	arm_replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 100, "W"), 1))
	arm_press_gsm.game_state.players[1].bench = [arm_replacement]
	for i2: int in 6:
		arm_press_gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i2, 60, "C"), 0))
		arm_press_gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i2, 60, "C"), 1))

	arm_press_scene.call("_try_use_attack_with_interaction", 0, arm_attacker, 0)
	arm_press_scene.call("_try_take_prize_from_slot", 0, 0)
	var handover_visible: bool = bool(arm_press_scene.get("_handover_panel").visible)
	arm_press_scene.call("_on_handover_confirmed")
	arm_press_scene.call("_handle_field_slot_select_index", 0)
	var arm_current_after_send_out: int = arm_press_gsm.game_state.current_player_index
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(handover_visible, "Arm Press knockout should prompt a handover to the opponent"),
		assert_eq(arm_current_after_send_out, 1, "After Arm Press knockout and replacement, the turn should pass to the opponent"),
	])


func test_two_player_handover_waits_for_active_attack_vfx() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	var overlay := Control.new()
	var sequence := Control.new()
	sequence.name = "AttackVfxSequence"
	sequence.set_meta("attack_vfx_sequence", true)
	sequence.set_meta("attack_vfx_kind", "attack")
	sequence.set_meta("attack_vfx_animation_active", true)
	overlay.add_child(sequence)
	battle_scene.set("_attack_vfx_overlay", overlay)

	battle_scene.call("_check_two_player_handover")

	var handover_visible: bool = bool(battle_scene.get("_handover_panel").visible)
	var delay_active: bool = bool(battle_scene.get("_handover_attack_vfx_delay_active"))
	var view_player_after_check: int = int(battle_scene.get("_view_player"))
	var live_actions_allowed_during_delay: bool = bool(battle_scene.call("_can_accept_live_action"))
	var delay_token: int = int(battle_scene.get("_handover_attack_vfx_delay_token"))
	sequence.set_meta("attack_vfx_animation_active", false)
	battle_scene.call("_poll_attack_vfx_handover_delay", delay_token, "turn")
	var handover_visible_after_vfx_finished: bool = bool(battle_scene.get("_handover_panel").visible)
	var delay_active_after_vfx_finished: bool = bool(battle_scene.get("_handover_attack_vfx_delay_active"))

	GameManager.current_mode = previous_mode
	overlay.free()
	battle_scene.free()
	return run_checks([
		assert_false(handover_visible, "Two-player handover should wait while an attack VFX is still active"),
		assert_true(delay_active, "The scene should enter the attack-VFX handover delay state"),
		assert_false(live_actions_allowed_during_delay, "Live actions should be blocked while the delayed handover is waiting"),
		assert_eq(view_player_after_check, 0, "The visible player should not switch before the delayed handover is confirmed"),
		assert_true(handover_visible_after_vfx_finished, "Two-player handover should appear immediately once attack VFX is finished"),
		assert_false(delay_active_after_vfx_finished, "The attack-VFX handover delay state should clear as soon as animations finish"),
	])


func test_two_player_send_out_handover_waits_for_active_attack_vfx() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var opponent_replacement := PokemonSlot.new()
	opponent_replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opponent Replacement", 100, "C"), 1))
	gsm.game_state.players[1].bench = [opponent_replacement]
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	var overlay := Control.new()
	var sequence := Control.new()
	sequence.name = "AttackVfxSequence"
	sequence.set_meta("attack_vfx_sequence", true)
	sequence.set_meta("attack_vfx_kind", "attack")
	sequence.set_meta("attack_vfx_animation_active", true)
	overlay.add_child(sequence)
	battle_scene.set("_attack_vfx_overlay", overlay)

	battle_scene.call("_prompt_send_out_dialog", 1)

	var handover_visible_during_vfx: bool = bool(battle_scene.get("_handover_panel").visible)
	var delay_active: bool = bool(battle_scene.get("_handover_attack_vfx_delay_active"))
	var view_player_during_vfx: int = int(battle_scene.get("_view_player"))
	var field_mode_during_vfx: String = str(battle_scene.get("_field_interaction_mode"))
	var delay_token: int = int(battle_scene.get("_handover_attack_vfx_delay_token"))
	sequence.set_meta("attack_vfx_animation_active", false)
	battle_scene.call("_poll_attack_vfx_handover_delay", delay_token, "send_out")
	var handover_visible_after_vfx: bool = bool(battle_scene.get("_handover_panel").visible)
	var delay_active_after_vfx: bool = bool(battle_scene.get("_handover_attack_vfx_delay_active"))
	battle_scene.call("_on_handover_confirmed")
	var send_out_field_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var send_out_player: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))

	GameManager.current_mode = previous_mode
	overlay.free()
	battle_scene.free()
	return run_checks([
		assert_false(handover_visible_during_vfx, "Send-out handover should stay hidden while the attack VFX is still active"),
		assert_true(delay_active, "Send-out should register an attack-VFX completion wait"),
		assert_eq(view_player_during_vfx, 0, "Send-out should not switch view player before the attack VFX finishes"),
		assert_eq(field_mode_during_vfx, "", "Send-out field selection should not open over an active attack VFX"),
		assert_true(handover_visible_after_vfx, "Send-out handover should appear after the attack VFX finishes"),
		assert_false(delay_active_after_vfx, "The send-out attack-VFX delay should clear after the VFX finishes"),
		assert_eq(send_out_field_mode, "slot_select", "Confirming the delayed handover should open the send-out field selector"),
		assert_eq(send_out_player, 1, "The delayed send-out prompt should still belong to the opponent"),
	])


func test_battle_scene_roaring_moon_self_ko_prompts_both_active_replacements() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		var my_prize_view := BattleCardView.new()
		my_prize_view.set_clickable(false)
		my_prize_slots.append(my_prize_view)
		var opp_prize_view := BattleCardView.new()
		opp_prize_view.set_clickable(false)
		opp_prize_slots.append(opp_prize_view)
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)
	battle_scene.call("_setup_prize_viewer")

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Moon UI Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var roaring_cd: CardData = CardDatabase.get_card("CSV6C", "096")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(roaring_cd, 0))
	attacker_slot.damage_counters = 40
	for energy_type: String in ["D", "D", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(roaring_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var my_replacement := PokemonSlot.new()
	my_replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("My Moon Bench", 120, "D"), 0))
	gsm.game_state.players[0].bench = [my_replacement]

	var defender_cd := _make_pokemon_cd("Frenzied Gouging Target", 220, "W")
	defender_cd.mechanic = "ex"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var opp_replacement := PokemonSlot.new()
	opp_replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Moon Bench", 120, "W"), 1))
	gsm.game_state.players[1].bench = [opp_replacement]

	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 0)
	var first_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var first_prize_player: int = int(battle_scene.get("_pending_prize_player_index"))
	var handover_to_player_prizes: bool = bool(battle_scene.get("_handover_panel").visible)
	var view_for_player_prizes: int = int(battle_scene.get("_view_player"))

	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	var second_prize_player: int = int(battle_scene.get("_pending_prize_player_index"))
	var handover_to_opponent_prizes: bool = bool(battle_scene.get("_handover_panel").visible)

	battle_scene.call("_on_handover_confirmed")
	var view_for_opponent_prizes: int = int(battle_scene.get("_view_player"))
	battle_scene.call("_try_take_prize_from_slot", 1, 0)
	battle_scene.call("_try_take_prize_from_slot", 1, 1)
	var pending_after_all_prizes: String = str(battle_scene.get("_pending_choice"))
	var handover_to_opponent_send_out: bool = bool(battle_scene.get("_handover_panel").visible)

	battle_scene.call("_on_handover_confirmed")
	var opponent_send_out_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var opponent_send_out_player: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))
	battle_scene.call("_handle_field_slot_select_index", 0)
	var opponent_active_after_send_out: PokemonSlot = gsm.game_state.players[1].active_pokemon
	var pending_after_opp_send_out: String = str(battle_scene.get("_pending_choice"))
	var handover_to_player_send_out: bool = bool(battle_scene.get("_handover_panel").visible)

	battle_scene.call("_on_handover_confirmed")
	var player_send_out_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var player_send_out_player: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))
	battle_scene.call("_handle_field_slot_select_index", 0)
	var current_after_both_send_out: int = gsm.game_state.current_player_index
	var phase_after_both_send_out: int = gsm.game_state.phase
	var view_after_both_send_out: int = int(battle_scene.get("_view_player"))
	var pending_after_both_send_out: String = str(battle_scene.get("_pending_choice"))
	var handover_after_both_send_out: bool = bool(battle_scene.get("_handover_panel").visible)
	var opponent_deck_after_turn_start: int = gsm.game_state.players[1].deck.size()

	var result := run_checks([
		assert_not_null(roaring_cd, "CSV6C_096 should exist in the card database"),
		assert_eq(first_pending_choice, "take_prize", "Roaring Moon ex self-KO should first enter prize selection"),
		assert_eq(first_prize_player, 0, "The attacker should first take prizes for the Defending Pokemon"),
		assert_false(handover_to_player_prizes, "Two-player mode should keep view on the attacker for the first prize queue"),
		assert_eq(view_for_player_prizes, 0, "The first prize queue should stay on the attacker"),
		assert_eq(second_prize_player, 1, "After defender prizes, the opponent should take prizes for Roaring Moon ex"),
		assert_true(handover_to_opponent_prizes, "The UI should hand over to the opponent for Roaring Moon ex prizes"),
		assert_eq(view_for_opponent_prizes, 1, "After handover confirmation, the view should move to the opponent"),
		assert_eq(pending_after_all_prizes, "send_out", "After both prize queues, the UI should wait for send-out"),
		assert_true(handover_to_opponent_send_out, "The UI should hand over to the opponent for their Active replacement"),
		assert_eq(opponent_send_out_mode, "slot_select", "Opponent handover should open the send-out field selector"),
		assert_eq(opponent_send_out_player, 1, "The first send-out prompt should belong to the opponent"),
		assert_eq(opponent_active_after_send_out, opp_replacement, "The opponent replacement should become Active"),
		assert_eq(pending_after_opp_send_out, "send_out", "After opponent replacement, the attacker should still be prompted to send out"),
		assert_false(handover_to_player_send_out, "After opponent replacement, the attacker send-out prompt should be available without an extra handover"),
		assert_eq(player_send_out_mode, "slot_select", "Attacker handover should open the send-out field selector"),
		assert_eq(player_send_out_player, 0, "The second send-out prompt should belong to the attacker"),
		assert_eq(gsm.game_state.players[0].active_pokemon, my_replacement, "The attacking player's replacement should become Active"),
		assert_eq(current_after_both_send_out, 1, "After both replacements, the turn should pass to the opponent"),
		assert_eq(phase_after_both_send_out, GameState.GamePhase.MAIN, "After both replacements, the opponent should begin their turn"),
		assert_eq(view_after_both_send_out, 1, "After both replacements, the view should follow the opponent turn"),
		assert_eq(pending_after_both_send_out, "", "The send-out UI flow should finish cleanly"),
		assert_false(handover_after_both_send_out, "No stale handover should remain after both replacements"),
		assert_eq(opponent_deck_after_turn_start, 2, "The opponent should draw for turn after both replacements finish"),
	])
	GameManager.current_mode = previous_mode
	battle_scene.free()
	return result


func test_battle_scene_vs_ai_roaring_moon_keeps_human_send_out_after_ai_replacement() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	battle_scene._setup_ai_for_tests()
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	battle_scene.set("_ai_opponent", ai)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
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
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Moon AI Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var roaring_cd: CardData = CardDatabase.get_card("CSV6C", "096")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(roaring_cd, 0))
	attacker_slot.damage_counters = 40
	for energy_type: String in ["D", "D", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(roaring_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var my_replacement := PokemonSlot.new()
	my_replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Human Moon Bench", 120, "D"), 0))
	gsm.game_state.players[0].bench = [my_replacement]

	var defender_cd := _make_pokemon_cd("AI Frenzied Target", 220, "W")
	defender_cd.mechanic = "ex"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var ai_replacement := PokemonSlot.new()
	ai_replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("AI Moon Bench", 120, "W"), 1))
	gsm.game_state.players[1].bench = [ai_replacement]

	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("AI Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 0)
	var initial_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var initial_prize_player: int = int(battle_scene.get("_pending_prize_player_index"))
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	var pending_before_ai_prizes: String = str(battle_scene.get("_pending_choice"))
	var prize_player_before_ai_prizes: int = int(battle_scene.get("_pending_prize_player_index"))
	battle_scene.call("_run_ai_step")
	battle_scene.call("_run_ai_step")
	var pending_after_ai_prizes: String = str(battle_scene.get("_pending_choice"))
	var pending_before_ai_send_out: String = str(battle_scene.get("_pending_choice"))
	var prompt_player_before_ai_send_out: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))
	battle_scene.call("_run_ai_step")
	var ai_active_after_send_out: PokemonSlot = gsm.game_state.players[1].active_pokemon
	var pending_after_ai_send_out: String = str(battle_scene.get("_pending_choice"))
	var prompt_player_after_ai_send_out: int = int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))
	var field_mode_after_ai_send_out: String = str(battle_scene.get("_field_interaction_mode"))
	var roaring_moon_diagnostics := "ready=%s blocking=%s draw=%s scheduled=%s state=%s effect=%s" % [
		str(battle_scene.call("_is_ai_turn_ready")),
		str(battle_scene.call("_is_ui_blocking_ai")),
		str(battle_scene.get("_draw_reveal_active")),
		str(battle_scene.get("_ai_step_scheduled")),
		str(battle_scene.call("_state_snapshot")),
		str(battle_scene.call("_effect_state_snapshot")),
	]

	var result := run_checks([
		assert_not_null(roaring_cd, "CSV6C_096 should exist in the card database"),
		assert_eq(initial_pending_choice, "take_prize", "Roaring Moon ex should first prompt the human to take AI Active prizes"),
		assert_eq(initial_prize_player, 0, "The human should first take prizes for the Defending Pokemon"),
		assert_eq(pending_before_ai_prizes, "take_prize", "After human prizes, the AI prize prompt should remain"),
		assert_eq(prize_player_before_ai_prizes, 1, "The AI should then take prizes for Roaring Moon ex"),
		assert_eq(pending_after_ai_prizes, "send_out", "After AI takes Roaring Moon prizes, AI send-out should remain | %s" % roaring_moon_diagnostics),
		assert_eq(pending_before_ai_send_out, "send_out", "After human prizes, AI should be prompted to replace its Active first"),
		assert_eq(prompt_player_before_ai_send_out, 1, "The first send-out prompt should belong to the AI"),
		assert_eq(ai_active_after_send_out, ai_replacement, "AI should send out its replacement"),
		assert_eq(pending_after_ai_send_out, "send_out", "AI send-out must preserve the follow-up human send-out prompt"),
		assert_eq(prompt_player_after_ai_send_out, 0, "The follow-up send-out prompt should belong to the human"),
		assert_eq(field_mode_after_ai_send_out, "slot_select", "Human send-out should be selectable after AI replacement"),
	])
	GameManager.current_mode = previous_mode
	battle_scene.free()
	return result


func test_battle_scene_radiant_charizard_attack_uses_prize_cost_reduction_without_discarding_energy() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var radiant_charizard_cd: CardData = CardDatabase.get_card("CS5.5C", "007")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(radiant_charizard_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	gsm.effect_processor.register_pokemon_card(radiant_charizard_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var target_slot := PokemonSlot.new()
	target_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bulky Target", 330, "G"), 1))
	gsm.game_state.players[1].active_pokemon = target_slot
	gsm.game_state.players[1].prizes.clear()
	for i: int in 2:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 0)

	return run_checks([
		assert_not_null(radiant_charizard_cd, "CS5.5C_007 should exist in the card database"),
		assert_eq(target_slot.damage_counters, 250, "Radiant Charizard should still deal 250 damage through the BattleScene attack flow"),
		assert_eq(attacker_slot.attached_energy.size(), 1, "Radiant Charizard should keep its only Fire Energy after Combustion Blast"),
	])


func test_battle_scene_dragapult_double_knockout_without_live_replacement_stays_on_prizes() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
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
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active Prize Target", 200, "W"), 1))
	gsm.game_state.players[1].active_pokemon = active_target
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Only Bench Target", 60, "W"), 1))
	gsm.game_state.players[1].bench = [bench_target]
	for i: int in 2:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
	for i: int in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 1)
	battle_scene.call("_on_counter_distribution_amount_chosen", 6)
	battle_scene.call("_handle_counter_distribution_target", 0)
	var first_pending_choice: String = str(battle_scene.get("_pending_choice"))
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	var second_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var second_pending_count: int = int(battle_scene.get("_pending_prize_remaining"))
	var handover_visible_after_first: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_try_take_prize_from_slot", 0, 1)
	var final_phase: int = gsm.game_state.phase
	var winner_index: int = gsm.game_state.winner_index

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_eq(first_pending_choice, "take_prize", "The first Dragapult ex knockout should enter prize selection"),
		assert_eq(second_pending_choice, "take_prize", "When no live replacement remains, the second prize should queue immediately"),
		assert_eq(second_pending_count, 1, "Exactly one follow-up prize should still be pending after the first take"),
		assert_false(handover_visible_after_first, "There should be no send-out handover when the only Bench Pokemon is already knocked out"),
		assert_eq(gsm.game_state.players[0].hand.size(), 2, "The player should still be able to take both prizes through the BattleScene flow"),
		assert_eq(final_phase, GameState.GamePhase.GAME_OVER, "Taking the second queued prize should end the game"),
		assert_eq(winner_index, 0, "The attacking player should win after taking both remaining prizes"),
	])


func test_battle_scene_dragapult_active_only_knockout_keeps_prize_selection_clickable() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
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
		gsm.game_state.players.append(player)

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active Only Target", 200, "W"), 1))
	gsm.game_state.players[1].active_pokemon = active_target
	var replacement_slot := PokemonSlot.new()
	replacement_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Surviving Bench", 120, "W"), 1))
	gsm.game_state.players[1].bench = [replacement_slot]
	for i: int in 2:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize %d" % i, 60, "C"), 0))
	for i: int in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize %d" % i, 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, attacker_slot, 1)
	battle_scene.call("_on_counter_distribution_amount_chosen", 6)
	battle_scene.call("_handle_counter_distribution_target", 0)
	var attack_vfx_overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var attack_vfx_mouse_filter: int = attack_vfx_overlay.mouse_filter if attack_vfx_overlay != null else Control.MOUSE_FILTER_IGNORE
	var first_pending_choice: String = str(battle_scene.get("_pending_choice"))
	var bench_remaining_hp: int = replacement_slot.get_remaining_hp()
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	var pending_choice_after_take: String = str(battle_scene.get("_pending_choice"))
	var pending_prize_remaining_after_take: int = int(battle_scene.get("_pending_prize_remaining"))
	var handover_visible_after_take: bool = bool(battle_scene.get("_handover_panel").visible)
	battle_scene.call("_on_handover_confirmed")
	var send_out_mode: String = str(battle_scene.get("_field_interaction_mode"))

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_eq(attack_vfx_mouse_filter, Control.MOUSE_FILTER_IGNORE, "Attack VFX overlay must not intercept prize clicks"),
		assert_eq(first_pending_choice, "take_prize", "Dragging through Phantom Dive should still enter prize selection after the Active knockout"),
		assert_eq(bench_remaining_hp, 60, "The benched replacement should survive the counter placement in this fixture"),
		assert_eq(pending_choice_after_take, "send_out", "After taking the prize, the flow should advance to the replacement prompt"),
		assert_eq(pending_prize_remaining_after_take, 0, "The prize selection state should be fully cleared after the prize is taken"),
		assert_true(handover_visible_after_take, "Two-player mode should hand over to the defending player after the prize is taken"),
		assert_eq(send_out_mode, "slot_select", "After handover confirmation, the defending player should be prompted to send out a replacement"),
	])


func test_battle_scene_human_prize_prompt_blocks_field_actions_until_prize_taken() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
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
		gsm.game_state.players.append(player)

	var attacker_cd := _make_pokemon_cd("Prize Taker", 220, "L")
	var my_active := PokemonSlot.new()
	my_active.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	my_active.attached_energy.append(CardInstance.create(_make_energy_cd("Energy R", "R"), 0))
	my_active.attached_energy.append(CardInstance.create(_make_energy_cd("Energy C", "C"), 0))
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	gsm.game_state.players[0].active_pokemon = my_active
	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Knocked Out Target", 30, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Replacement", 120, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("My Prize", 60, "C"), 0))
	gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Opp Prize", 60, "C"), 1))

	battle_scene.call("_try_use_attack_with_interaction", 0, my_active, 0)
	var pending_before_field_click: String = str(battle_scene.get("_pending_choice"))
	var dialog_visible_before_field_click: bool = bool((battle_scene.get("_dialog_overlay") as Panel).visible)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	battle_scene.call("_on_slot_input", click, "my_active")
	var pending_after_field_click: String = str(battle_scene.get("_pending_choice"))
	var dialog_visible_after_field_click: bool = bool((battle_scene.get("_dialog_overlay") as Panel).visible)
	var hand_before_take: int = gsm.game_state.players[0].hand.size()
	battle_scene.call("_on_prize_slot_input", click, 0, "己方奖赏", 0)
	var hand_after_take: int = gsm.game_state.players[0].hand.size()
	var pending_after_take: String = str(battle_scene.get("_pending_choice"))
	var prize_count_after_take: int = gsm.game_state.players[0].prizes.size()

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(pending_before_field_click, "take_prize", "Knocking out the AI active Pokemon should enter a human-owned prize prompt"),
		assert_eq(pending_after_field_click, "take_prize", "Human prize prompts should ignore field clicks instead of opening other actions"),
		assert_eq(dialog_visible_after_field_click, dialog_visible_before_field_click, "Field clicks during prize selection must not change the dialog overlay state"),
		assert_eq(hand_after_take, hand_before_take + 1, "Clicking the prize slot should still take exactly one prize card"),
		assert_eq(prize_count_after_take, 0, "Taking the prize through the prize-slot input path should remove it from the prize area"),
		assert_false(pending_after_take == "take_prize", "After the prize is taken, the prize prompt should be cleared so the battle can continue"),
	])


func test_battle_scene_landscape_match_end_keeps_full_summary_with_centered_return_action() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE

	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "landscape")
	var fake_review_service := FakeBattleReviewService.new()
	battle_scene.set("_battle_review_service", fake_review_service)
	battle_scene.set("_battle_review_match_dir", "user://test_match_end_review")
	battle_scene.set("_battle_review_winner_index", 0)
	battle_scene.set("_battle_review_reason", "knockout")

	battle_scene.call("_show_match_end_dialog", 0, "knockout")
	var match_end_overlay := battle_scene.get("_match_end_overlay") as Panel
	var ai_button := battle_scene.get("_match_end_ai_button") as Button
	var review_button := battle_scene.get("_match_end_review_button") as Button
	var learning_button := battle_scene.get("_match_end_learning_button") as Button
	var return_button := battle_scene.get("_match_end_return_button") as Button
	var stats_grid := battle_scene.get("_match_end_stats_grid") as GridContainer
	var action_summary := battle_scene.get("_match_end_action_summary") as RichTextLabel
	var ai_title := battle_scene.get("_match_end_ai_title") as Label
	var ai_content := battle_scene.get("_match_end_ai_content") as RichTextLabel
	var button_row := return_button.get_parent() as HBoxContainer if return_button != null else null
	var non_battle_orientation_restored := bool(battle_scene.get("_match_end_non_battle_orientation_restored"))
	var quick_review_requested := bool(battle_scene.get("_match_end_quick_review_requested"))

	var generate_calls: Array = fake_review_service.generate_calls
	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout

	return run_checks([
		assert_true(match_end_overlay != null and match_end_overlay.visible, "Match end should use the result screen overlay"),
		assert_not_null(stats_grid, "Match end result screen should render stat cards"),
		assert_eq(stats_grid.get_child_count() if stats_grid != null else -1, 4, "Landscape match end should keep the full stat summary"),
		assert_not_null(action_summary, "Landscape match end should keep the action summary panel"),
		assert_not_null(ai_title, "Landscape match end should keep the quick-review title panel"),
		assert_not_null(ai_content, "Landscape match end should keep the quick-review content panel"),
		assert_not_null(button_row, "Match end result screen should use a centered bottom button row"),
		assert_eq(button_row.alignment if button_row != null else -1, BoxContainer.ALIGNMENT_CENTER, "Match end bottom button row should center its visible action"),
		assert_true(ai_button != null and not ai_button.visible, "Match end should keep the removed AI quick-review button hidden"),
		assert_true(review_button != null and not review_button.visible, "Match end should keep the removed AI review button hidden"),
		assert_true(learning_button != null and not learning_button.visible, "Match end should keep the removed learning-pool button hidden"),
		assert_not_null(return_button, "Match end result screen should include a return action"),
		assert_true(return_button.visible if return_button != null else false, "Match end should keep only the return action visible"),
		assert_eq(return_button.text if return_button != null else "", "返回对战准备", "Single-match result screen should keep the return label"),
		assert_true(non_battle_orientation_restored, "Match end should restore non-battle orientation before keeping the player on the result screen"),
		assert_false(quick_review_requested, "Local landscape quick review should not count as a remote AI request"),
		assert_eq(generate_calls.size(), 0, "Hidden AI review button should not start battle review generation"),
	])


func test_battle_scene_portrait_match_end_keeps_compact_summary_with_scrollable_quick_review() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT

	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_rotated_portrait_canvas_active", true)
	battle_scene.rotation_degrees = 90.0
	battle_scene.position = Vector2(1600.0, 0.0)
	battle_scene.set("_battle_review_winner_index", 0)
	battle_scene.set("_battle_review_reason", "knockout")

	battle_scene.call("_show_match_end_dialog", 0, "knockout")
	var match_end_overlay := battle_scene.get("_match_end_overlay") as Panel
	var ai_button := battle_scene.get("_match_end_ai_button") as Button
	var review_button := battle_scene.get("_match_end_review_button") as Button
	var learning_button := battle_scene.get("_match_end_learning_button") as Button
	var return_button := battle_scene.get("_match_end_return_button") as Button
	var stats_grid := battle_scene.get("_match_end_stats_grid") as GridContainer
	var action_summary := battle_scene.get("_match_end_action_summary") as RichTextLabel
	var ai_title := battle_scene.get("_match_end_ai_title") as Label
	var ai_content := battle_scene.get("_match_end_ai_content") as RichTextLabel
	var action_panel: Control = null
	if action_summary != null and action_summary.get_parent() != null:
		action_panel = action_summary.get_parent().get_parent() as Control
	var ai_panel: Control = null
	var ai_node: Node = ai_title
	while ai_node != null:
		if str(ai_node.name) == "MatchEndAiPanel" and ai_node is Control:
			ai_panel = ai_node as Control
			break
		ai_node = ai_node.get_parent()
	var quick_review_requested := bool(battle_scene.get("_match_end_quick_review_requested"))
	var quick_review_result: Dictionary = battle_scene.get("_match_end_quick_review_result")
	var quick_review_configured := bool(battle_scene.call("_match_end_quick_review_configured"))
	var quick_review_state_valid := (quick_review_configured and quick_review_result.is_empty()) or ((not quick_review_configured) and not quick_review_result.is_empty())
	var non_battle_orientation_restored := bool(battle_scene.get("_match_end_non_battle_orientation_restored"))
	var rotation_after_match_end: float = float(battle_scene.rotation_degrees)
	var position_after_match_end: Vector2 = battle_scene.position

	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout
	return run_checks([
		assert_true(match_end_overlay != null and match_end_overlay.visible, "Portrait match end should use the result screen overlay"),
		assert_eq(stats_grid.get_child_count() if stats_grid != null else -1, 2, "Portrait compact match end should show only the essential stat cards"),
		assert_true(action_panel != null and not action_panel.visible, "Portrait compact match end should hide the action summary panel"),
		assert_true(ai_panel != null and ai_panel.visible, "Portrait compact match end should show the AI quick-review panel"),
		assert_true(ai_title != null and ai_title.visible, "Portrait compact match end should show the AI quick-review title"),
		assert_true(ai_content != null and ai_content.visible, "Portrait compact match end should show the AI quick-review content"),
		assert_true(ai_content != null and ai_content.text != "", "Portrait compact match end should render quick-review text immediately"),
		assert_true(ai_content != null and ai_content.scroll_active, "Portrait quick-review content should scroll inside a fixed panel"),
		assert_true(ai_content != null and not ai_content.fit_content, "Portrait quick-review content should not grow the result modal"),
		assert_true(ai_content != null and ai_content.custom_minimum_size.y >= 126.0, "Portrait quick-review content should keep a readable touch-height area"),
		assert_true(ai_button != null and not ai_button.visible, "Portrait compact match end should hide the AI quick-review button"),
		assert_true(review_button != null and not review_button.visible, "Portrait compact match end should hide the AI review button"),
		assert_true(learning_button != null and not learning_button.visible, "Portrait compact match end should hide the learning-pool button"),
		assert_true(return_button != null and return_button.visible, "Portrait compact match end should keep the return action visible"),
		assert_false(non_battle_orientation_restored, "Portrait match end should keep battle orientation while the result overlay is still in BattleScene"),
		assert_true(absf(rotation_after_match_end - 90.0) <= 0.001, "Portrait match end should not clear the rotated battle canvas transform"),
		assert_eq(position_after_match_end, Vector2(1600.0, 0.0), "Portrait match end should keep the rotated battle canvas anchored in place"),
		assert_false(quick_review_requested, "Portrait immediate match end should not count as a completed remote AI request before the service responds"),
		assert_true(quick_review_state_valid, "Portrait compact match end should either prepare local review text or keep a pending remote AI review state"),
	])


func test_battle_scene_portrait_match_end_matches_handover_modal_metrics() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT

	var scene: Control = BattleScenePacked.instantiate()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	scene.call("_style_handover_overlay")
	scene.call("_show_match_end_dialog", 0, "knockout")

	var handover_box := scene.get_node("HandoverPanel/HandoverCenter/HandoverBox") as PanelContainer
	var handover_button := scene.find_child("HandoverBtn", true, false) as Button
	var match_end_overlay := scene.get("_match_end_overlay") as Panel
	var match_end_box := match_end_overlay.get_node_or_null("MatchEndCenter/MatchEndBox") as PanelContainer if match_end_overlay != null else null
	var return_button := scene.get("_match_end_return_button") as Button
	var handover_box_style := handover_box.get_theme_stylebox("panel") as StyleBoxFlat if handover_box != null else null
	var match_end_box_style := match_end_box.get_theme_stylebox("panel") as StyleBoxFlat if match_end_box != null else null
	var handover_button_style := handover_button.get_theme_stylebox("normal") as StyleBoxFlat if handover_button != null else null
	var return_button_style := return_button.get_theme_stylebox("normal") as StyleBoxFlat if return_button != null else null
	var near_width := float(scene.call("_portrait_popup_near_width"))
	var review_height := float(scene.call("_portrait_match_end_review_modal_height", Vector2(390, 844)))

	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout
	var result := run_checks([
		assert_not_null(match_end_box, "Portrait match end should create a result modal box"),
		assert_true(match_end_box != null and match_end_box.custom_minimum_size.x >= near_width - 0.1, "Portrait match end box should use the near-width modal for readable quick review text"),
		assert_true(match_end_box != null and handover_box != null and match_end_box.custom_minimum_size.y > handover_box.custom_minimum_size.y, "Portrait match end box should be taller than the handover prompt to fit quick review"),
		assert_true(match_end_box != null and absf(match_end_box.custom_minimum_size.y - review_height) <= 0.1, "Portrait match end box should use the dedicated quick-review modal height"),
		assert_true(return_button != null and handover_button != null and return_button.custom_minimum_size.x >= handover_button.custom_minimum_size.x, "Portrait match end return button should remain at least as wide as the handover button"),
		assert_true(return_button != null and handover_button != null and absf(return_button.custom_minimum_size.y - handover_button.custom_minimum_size.y) <= 0.1, "Portrait match end return button should match the handover button height"),
		assert_true(return_button != null and handover_button != null and return_button.get_theme_font_size("font_size") >= handover_button.get_theme_font_size("font_size"), "Portrait match end return button text should be at least as readable as the handover button"),
		assert_true(match_end_box_style != null and handover_box_style != null and match_end_box_style.bg_color.is_equal_approx(handover_box_style.bg_color), "Portrait match end box should use the handover modal surface color"),
		assert_true(match_end_box_style != null and handover_box_style != null and match_end_box_style.border_color.is_equal_approx(handover_box_style.border_color), "Portrait match end box should use the handover modal border color"),
		assert_true(return_button_style != null and handover_button_style != null and return_button_style.bg_color.is_equal_approx(handover_button_style.bg_color), "Portrait match end return button should use the handover HUD button surface"),
		assert_true(return_button_style != null and handover_button_style != null and return_button_style.border_color.is_equal_approx(handover_button_style.border_color), "Portrait match end return button should use the handover HUD button border"),
	])

	scene.queue_free()
	return result


func test_battle_scene_match_end_restores_landscape_ai_metrics_after_portrait_refresh() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT

	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.call("_show_match_end_dialog", 0, "knockout")
	var ai_content := battle_scene.get("_match_end_ai_content") as RichTextLabel
	var portrait_scroll_active := ai_content != null and ai_content.scroll_active
	var portrait_fit_content := ai_content != null and ai_content.fit_content

	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	battle_scene.set("_active_battle_layout_mode", "landscape")
	var coordinator: RefCounted = battle_scene.get("_battle_overlay_coordinator")
	if coordinator != null:
		coordinator.call("refresh_match_end_screen")
	var landscape_scroll_active := ai_content != null and ai_content.scroll_active
	var landscape_fit_content := ai_content != null and ai_content.fit_content
	var landscape_font_size := ai_content.get_theme_font_size("normal_font_size") if ai_content != null else -1

	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout
	return run_checks([
		assert_true(portrait_scroll_active, "Portrait match end should start with a scrollable AI quick-review panel"),
		assert_false(portrait_fit_content, "Portrait match end should use fixed AI content height"),
		assert_false(landscape_scroll_active, "Landscape refresh should restore fit-content AI quick-review behavior"),
		assert_true(landscape_fit_content, "Landscape refresh should let the AI quick-review panel size like the original landscape UI"),
		assert_eq(landscape_font_size, 14, "Landscape refresh should restore the original quick-review font size after portrait scaling"),
	])


func test_match_end_return_preserves_tournament_standings_route_when_active() -> String:
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id
	var previous_in_progress := GameManager.tournament_battle_in_progress
	var previous_mode: int = GameManager.current_mode
	var previous_suppressed := bool(GameManager.get("suppress_scene_navigation_for_tests"))
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575716)
	GameManager.start_swiss_tournament("测试玩家", 16)
	var prepared := GameManager.prepare_current_tournament_battle()

	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_battle_review_winner_index", 0)
	battle_scene.set("_battle_review_reason", "knockout")
	battle_scene.call("_on_match_end_return_pressed")

	var requested_path := GameManager.consume_last_requested_scene_path()
	var tournament_still_exists := GameManager.current_tournament != null
	var active_after_return := GameManager.is_tournament_battle_active()
	var summary: Dictionary = GameManager.current_tournament.last_round_summary if GameManager.current_tournament != null else {}

	GameManager.clear_tournament()
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	GameManager.tournament_battle_in_progress = previous_in_progress
	GameManager.current_mode = previous_mode
	GameManager.set_scene_navigation_suppressed_for_tests(previous_suppressed)

	return run_checks([
		assert_true(prepared, "Tournament test setup should prepare an active battle"),
		assert_eq(requested_path, GameManager.SCENE_TOURNAMENT_STANDINGS, "Tournament match-end return should go to tournament standings"),
		assert_true(tournament_still_exists, "Tournament match-end return should not clear the tournament object"),
		assert_false(active_after_return, "Tournament match-end return should finalize the active battle"),
		assert_false(summary.is_empty(), "Tournament match-end return should record the round summary before standings"),
	])


func test_match_end_return_activates_on_button_down_and_latches_navigation() -> String:
	var previous_suppressed := bool(GameManager.get("suppress_scene_navigation_for_tests"))
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.consume_last_requested_scene_path()
	GameManager.consume_battle_setup_startup_input_shield_request()
	var battle_scene = _make_battle_scene_stub()
	battle_scene.call("_show_match_end_dialog", 0, "knockout")
	var return_button := battle_scene.get("_match_end_return_button") as Button
	if return_button != null:
		return_button.button_down.emit()
	var requested_from_button_down := GameManager.consume_last_requested_scene_path()
	var startup_shield_request: Dictionary = GameManager.consume_battle_setup_startup_input_shield_request()
	if return_button != null:
		return_button.pressed.emit()
	var requested_from_release_echo := GameManager.consume_last_requested_scene_path()
	var duplicate_shield_request: Dictionary = GameManager.consume_battle_setup_startup_input_shield_request()
	var navigation_latched: bool = battle_scene.get("_match_end_return_navigation_started")
	var button_disabled := return_button != null and return_button.disabled
	battle_scene.queue_free()
	GameManager.set_scene_navigation_suppressed_for_tests(previous_suppressed)

	return run_checks([
		assert_eq(requested_from_button_down, GameManager.SCENE_BATTLE_SETUP, "Match-end return must not depend on Android or desktop pointer release delivery"),
		assert_eq(str(startup_shield_request.get("reason", "")), "battle_match_end_return", "Match-end return must arm the BattleSetup startup shield before changing scenes"),
		assert_eq(requested_from_release_echo, "", "The release echo after button-down navigation must not enqueue a second scene change"),
		assert_true(duplicate_shield_request.is_empty(), "The release echo must not arm a second BattleSetup startup shield"),
		assert_true(navigation_latched, "Match-end navigation should latch after its first activation"),
		assert_true(button_disabled, "The terminal return action should disable immediately after activation"),
	])


func test_battle_dialog_footer_actions_commit_once_on_release() -> String:
	var confirm_scene = _make_battle_scene_stub()
	confirm_scene.set("_pending_choice", "release_commit_confirm")
	confirm_scene.call("_show_dialog", "Confirm action", ["Choice"], {
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	})
	var confirm_button := confirm_scene.get("_dialog_confirm") as Button
	if confirm_button != null:
		confirm_scene.call("_on_dialog_confirm_button_down")
	var confirm_open_after_press := (confirm_scene.get("_dialog_overlay") as Panel).visible
	confirm_scene.call("_on_dialog_confirm")
	var confirm_closed := not (confirm_scene.get("_dialog_overlay") as Panel).visible
	var confirm_choice_cleared := str(confirm_scene.get("_pending_choice")) == ""

	var cancel_scene = _make_battle_scene_stub()
	cancel_scene.set("_pending_choice", "release_commit_cancel")
	cancel_scene.call("_show_dialog", "Cancel action", ["Choice"], {
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	})
	var cancel_button := cancel_scene.get("_dialog_cancel") as Button
	if cancel_button != null:
		cancel_scene.call("_on_dialog_cancel_button_down")
	var cancel_open_after_press := (cancel_scene.get("_dialog_overlay") as Panel).visible
	cancel_scene.call("_on_dialog_cancel")
	var cancel_closed := not (cancel_scene.get("_dialog_overlay") as Panel).visible
	var cancel_choice_cleared := str(cancel_scene.get("_pending_choice")) == ""
	confirm_scene.queue_free()
	cancel_scene.queue_free()

	return run_checks([
		assert_true(confirm_open_after_press, "Dialog confirm must keep the overlay present throughout the press"),
		assert_true(cancel_open_after_press, "Dialog cancel must keep the overlay present throughout the press"),
		assert_true(confirm_closed and confirm_choice_cleared, "Dialog confirm must commit exactly when the standard Button emits pressed on release"),
		assert_true(cancel_closed and cancel_choice_cleared, "Dialog cancel must close exactly when the standard Button emits pressed on release"),
	])


func test_tournament_game_over_shows_match_end_before_standings() -> String:
	var previous_tournament := GameManager.current_tournament
	var previous_tournament_deck_id := GameManager.tournament_selected_player_deck_id
	var previous_in_progress := GameManager.tournament_battle_in_progress
	var previous_mode: int = GameManager.current_mode
	var previous_suppressed := bool(GameManager.get("suppress_scene_navigation_for_tests"))
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575716)
	GameManager.start_swiss_tournament("测试玩家", 16)
	var prepared := GameManager.prepare_current_tournament_battle()
	GameManager.consume_last_requested_scene_path()

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	battle_scene.call("_on_game_over", 0, "knockout")
	var match_end_overlay := battle_scene.get("_match_end_overlay") as Panel
	var return_button := battle_scene.get("_match_end_return_button") as Button
	var requested_before_return := GameManager.consume_last_requested_scene_path()
	var active_after_game_over := GameManager.is_tournament_battle_active()
	var return_route_latched := bool(battle_scene.get("_match_end_tournament_return_pending"))
	var summary_after_game_over: Dictionary = GameManager.current_tournament.last_round_summary if GameManager.current_tournament != null else {}
	battle_scene.call("_on_match_end_return_pressed")
	var requested_after_return := GameManager.consume_last_requested_scene_path()

	GameManager.clear_tournament()
	GameManager.current_tournament = previous_tournament
	GameManager.tournament_selected_player_deck_id = previous_tournament_deck_id
	GameManager.tournament_battle_in_progress = previous_in_progress
	GameManager.current_mode = previous_mode
	GameManager.set_scene_navigation_suppressed_for_tests(previous_suppressed)

	return run_checks([
		assert_true(prepared, "Tournament test setup should prepare an active battle"),
		assert_true(match_end_overlay != null and match_end_overlay.visible, "Tournament game over should show the match-end screen"),
		assert_eq(return_button.text if return_button != null else "", "返回比赛积分", "Tournament match-end screen should return to standings"),
		assert_eq(requested_before_return, "", "Tournament game over should not navigate away before the player sees the result screen"),
		assert_false(active_after_game_over, "Tournament result should be finalized immediately so resume cannot misclassify a completed match as a forfeit"),
		assert_true(return_route_latched, "The result screen should retain an immutable tournament-standings return route after finalization"),
		assert_false(summary_after_game_over.is_empty(), "Game over should persist the completed round before the result screen is shown"),
		assert_eq(requested_after_return, GameManager.SCENE_TOURNAMENT_STANDINGS, "The latched result-screen route should still return to standings after the active flag is cleared"),
	])


func test_battle_scene_landscape_match_end_quick_review_failure_updates_ai_panel() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_battle_review_winner_index", 0)
	battle_scene.set("_battle_review_reason", "knockout")
	battle_scene.set("_view_player", 0)

	battle_scene.call("_show_match_end_dialog", 0, "knockout")
	battle_scene.call("_on_match_end_quick_review_completed", {
		"status": "failed",
		"errors": [{
			"error_type": "python_fallback_timeout",
			"message": "ZenMux Python fallback timed out",
		}],
	})
	var result: Dictionary = battle_scene.get("_match_end_quick_review_result")
	var ai_title := battle_scene.get("_match_end_ai_title") as Label
	var ai_content := battle_scene.get("_match_end_ai_content") as RichTextLabel
	var return_button := battle_scene.get("_match_end_return_button") as Button

	return run_checks([
		assert_eq(str(result.get("status", "")), "ai_failed_fallback", "Match end should replace failed AI review with local fallback"),
		assert_true(bool(battle_scene.get("_match_end_quick_review_requested")), "Failed AI review should still count as handled"),
		assert_false(bool(battle_scene.get("_match_end_quick_review_busy")), "Failed AI review should clear busy state"),
		assert_true(ai_title != null and ai_title.visible, "Landscape match end should keep the AI title panel after quick-review failure"),
		assert_true(ai_content != null and ai_content.visible, "Landscape match end should keep AI content after quick-review failure"),
		assert_str_contains(ai_content.text if ai_content != null else "", "评分", "Landscape match end should show the fallback review content"),
		assert_true(return_button != null and return_button.visible, "Match end should keep the return action visible after quick-review failure"),
	])


func test_battle_scene_match_end_quick_review_payload_uses_llm_digest() -> String:
	var battle_scene = _make_battle_scene_stub()
	var match_dir := "user://test_quick_review_digest_%d" % Time.get_ticks_usec()
	var global_dir := ProjectSettings.globalize_path(match_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)
	var digest := {
		"meta": {"winner_index": 0, "total_turns": 6},
		"opening": {"opening_tags": {"0": ["Raging Bolt ex"], "1": ["Entei V"]}},
		"inflection_points": [{
			"turn_number": 5,
			"player_index": 0,
			"kind": "multi_prize_knockout",
			"summary": "玩家1用极雷轰拿下两奖",
		}],
		"critical_sequences": [{
			"turn_number": 5,
			"player_index": 0,
			"kind": "knockout",
			"summary": "极雷轰完成关键击倒",
			"actions": ["玩家1使用极雷轰"],
		}],
		"turn_summaries": [{
			"turn_number": 6,
			"key_actions": [{"player_index": 0, "description": "玩家1完成终结攻击", "damage": 210}],
			"key_choices": [{"player_index": 0, "title": "选择丢弃能量", "selected_labels": ["猛雷鼓ex 雷能量"]}],
		}],
	}
	var file := FileAccess.open(match_dir.path_join("llm_digest.json"), FileAccess.WRITE)
	if file == null:
		return "failed to create quick review digest fixture"
	file.store_string(JSON.stringify(digest))
	file.close()
	battle_scene.set("_battle_review_match_dir", match_dir)
	battle_scene.set("_match_end_stats", {
		"winner_index": 0,
		"turn_number": 6,
		"view_player": {"prizes_taken": 6, "max_damage": 210},
		"opponent": {"prizes_taken": 4},
	})

	var payload: Dictionary = battle_scene.call("_build_match_end_quick_review_payload")
	var subject: Dictionary = payload.get("review_subject", {})
	var context: Dictionary = payload.get("quick_review_context", {})
	var key_moments: Array = context.get("key_moments", [])
	var last_turn: Dictionary = context.get("last_turn", {})
	var last_actions: Array = last_turn.get("key_actions", [])
	var first_moment: Dictionary = key_moments[0] if not key_moments.is_empty() and key_moments[0] is Dictionary else {}
	var first_action: Dictionary = last_actions[0] if not last_actions.is_empty() and last_actions[0] is Dictionary else {}

	DirAccess.remove_absolute(global_dir.path_join("llm_digest.json"))
	DirAccess.remove_absolute(global_dir)
	return run_checks([
		assert_eq(str(subject.get("result", "")), "win", "Quick review should mark the current view player result"),
		assert_str_contains(str(subject.get("review_instruction", "")), "只评价当前玩家", "Quick review should tell the LLM to focus on the current player"),
		assert_false(context.is_empty(), "Quick review payload should include compact digest context when recording exists"),
		assert_eq(str(first_moment.get("summary", "")), "玩家1用极雷轰拿下两奖", "Quick review should expose key moments to the LLM"),
		assert_eq(int(last_turn.get("turn_number", 0)), 6, "Quick review should expose the last turn summary"),
		assert_eq(str(first_action.get("description", "")), "玩家1完成终结攻击", "Quick review should keep concrete action descriptions"),
	])


func test_battle_scene_match_end_quick_review_payload_focuses_human_in_vs_ai_even_if_view_shifted() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_ids: Array = GameManager.selected_deck_ids.duplicate()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids = [575716, 575720]
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_view_player", 1)
	battle_scene.set("_match_end_stats", {
		"winner_index": 0,
		"view_player_index": 1,
		"opponent_index": 0,
		"is_view_player_winner": false,
		"view_player": {"prizes_taken": 2, "max_damage": 120},
		"opponent": {"prizes_taken": 6, "max_damage": 240},
		"players": [
			{"prizes_taken": 6, "max_damage": 240, "knockouts": 3},
			{"prizes_taken": 2, "max_damage": 120, "knockouts": 1},
		],
	})

	var payload: Dictionary = battle_scene.call("_build_match_end_quick_review_payload")
	var subject: Dictionary = payload.get("review_subject", {})
	var review_player: Dictionary = payload.get("view_player", {})
	var review_opponent: Dictionary = payload.get("opponent", {})

	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_ids
	return run_checks([
		assert_eq(int(payload.get("view_player_index", -1)), 0, "VS_AI quick review should review the human/player side, not a shifted visible side"),
		assert_eq(str(subject.get("result", "")), "win", "VS_AI quick review should preserve the human player's win"),
		assert_eq(int(subject.get("player_index", -1)), 0, "VS_AI quick review subject should be player 0"),
		assert_eq(int(review_player.get("prizes_taken", 0)), 6, "Quick review player stats should be normalized to the human side"),
		assert_eq(int(review_opponent.get("prizes_taken", 0)), 2, "Quick review opponent stats should be normalized to the AI side"),
	])


func test_battle_scene_landscape_match_end_quick_review_busy_keeps_progress_panel() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_match_end_quick_review_busy", true)
	battle_scene.set("_match_end_quick_review_progress_text", "正在让 Kimi K3 快速点评...")
	battle_scene.call("_show_match_end_dialog", 0, "knockout")

	var result: Dictionary = battle_scene.get("_match_end_quick_review_result")
	var ai_title := battle_scene.get("_match_end_ai_title") as Label
	var ai_content := battle_scene.get("_match_end_ai_content") as RichTextLabel
	var return_button := battle_scene.get("_match_end_return_button") as Button

	return run_checks([
		assert_true(result.is_empty(), "Busy quick review should not create a local preview result"),
		assert_true(ai_title != null and ai_title.visible, "Landscape match end should show AI progress title"),
		assert_true(ai_content != null and ai_content.visible, "Landscape match end should show AI progress content"),
		assert_str_contains(ai_content.text if ai_content != null else "", "Kimi K3", "Landscape match end should keep the model progress text"),
		assert_true(return_button != null and return_button.visible, "Match end should keep the return action visible while quick-review state is busy"),
	])


func test_battle_scene_portrait_match_end_quick_review_busy_uses_scrollable_progress_panel() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT

	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_rotated_portrait_canvas_active", true)
	battle_scene.rotation_degrees = 90.0
	battle_scene.position = Vector2(1600.0, 0.0)
	battle_scene.set("_match_end_quick_review_busy", true)
	battle_scene.set("_match_end_quick_review_progress_text", "正在生成 Kimi K3 快评...")
	battle_scene.call("_show_match_end_dialog", 0, "knockout")

	var result: Dictionary = battle_scene.get("_match_end_quick_review_result")
	var ai_title := battle_scene.get("_match_end_ai_title") as Label
	var ai_content := battle_scene.get("_match_end_ai_content") as RichTextLabel
	var return_button := battle_scene.get("_match_end_return_button") as Button
	var quick_review_requested := bool(battle_scene.get("_match_end_quick_review_requested"))

	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout
	return run_checks([
		assert_true(result.is_empty(), "Portrait busy quick review should not create a local preview result"),
		assert_false(quick_review_requested, "Portrait busy quick review should not start a duplicate remote request"),
		assert_true(ai_title != null and ai_title.visible, "Portrait match end should show AI progress title"),
		assert_true(ai_content != null and ai_content.visible, "Portrait match end should show AI progress content"),
		assert_true(ai_content != null and ai_content.scroll_active, "Portrait progress content should use the same fixed scrollable panel"),
		assert_true(ai_content != null and not ai_content.fit_content, "Portrait progress content should not resize the result modal"),
		assert_str_contains(ai_content.text if ai_content != null else "", "Kimi K3", "Portrait match end should keep the model progress text"),
		assert_true(return_button != null and return_button.visible, "Portrait match end should keep the return action visible while quick-review state is busy"),
	])


func test_battle_scene_switch_pokemon_routes_real_effect_to_field_slots() -> String:
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
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	var switch_card := CardInstance.create(_make_trainer_cd("Pokemon Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = EffectSwitchPokemonScript.new("self").get_interaction_steps(switch_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, switch_card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "宝可梦交替应直接进入场上换位选择"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "我方换位交互面板应上移"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "应展示全部可选备战宝可梦"),
	])


func test_battle_scene_search_attach_to_v_routes_real_attack_to_field_assignment_ui() -> String:
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

	var attacker_card := CardInstance.create(_make_pokemon_cd("Arceus VSTAR", 280, "C"), 0)
	attacker_card.card_data.mechanic = "VSTAR"
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(attacker_card)
	gsm.game_state.players[0].active_pokemon = attacker
	var bench_v := PokemonSlot.new()
	var bench_v_card := CardInstance.create(_make_pokemon_cd("Bench V", 220, "L"), 0)
	bench_v_card.card_data.mechanic = "V"
	bench_v.pokemon_stack.append(bench_v_card)
	var bench_non_v := PokemonSlot.new()
	bench_non_v.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench NonV", 100, "L"), 0))
	gsm.game_state.players[0].bench = [bench_v, bench_non_v]
	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning 1", "L"), 0),
		CardInstance.create(_make_energy_cd("Water 1", "W"), 0),
		CardInstance.create(_make_energy_cd("Psychic 1", "P"), 0),
	]

	var effect := AttackSearchAttachToVScript.new(3)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker_card, {}, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "attack", 0, steps, attacker_card, attacker, 0)
	var targets: Array = (battle_scene.get("_field_interaction_data") as Dictionary).get("target_items", [])

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "三重星应直接进入场上 assignment UI"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "给我方 V 宝可梦贴能的面板应上移"),
		assert_eq(targets.size(), 2, "应只提供己方 V 宝可梦作为可贴能目标"),
		assert_true(bench_non_v not in targets, "非 V 宝可梦不应出现在三重星的可选目标中"),
	])


func test_battle_scene_run_away_draw_routes_real_ability_to_field_slots() -> String:
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

	var active_card := CardInstance.create(_make_pokemon_cd("Run Away", 70, "C"), 0)
	var active := PokemonSlot.new()
	active.pokemon_stack.append(active_card)
	gsm.game_state.players[0].active_pokemon = active
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	var steps: Array[Dictionary] = AbilityRunAwayDrawScript.new(3).get_interaction_steps(active_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, active_card, active, 0)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "跑路抽牌应在场上选择新的战斗宝可梦"),
		assert_eq(str(battle_scene.get("_field_interaction_position")), "top", "我方替换战斗宝可梦的面板应上移"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "应展示全部可选备战宝可梦"),
	])


func test_battle_scene_self_knockout_damage_counters_routes_real_ability_to_opponent_field() -> String:
	return _run_self_knockout_damage_counters_field_target_test(5, 50, "ui_test_dusclops_cursed_blast")


func test_battle_scene_high_self_knockout_damage_counters_routes_selected_bench_target() -> String:
	return _run_self_knockout_damage_counters_field_target_test(13, 130, "ui_test_dusknoir_cursed_blast")


func test_battle_scene_used_ability_slots_tilt_right_this_turn() -> String:
	var battle_scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 3
	battle_scene._gsm = gsm

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_panel := PanelContainer.new()
	var active_view := BattleCardViewScript.new()
	active_panel.add_child(active_view)
	battle_scene.set("_slot_card_views", {"my_active": active_view})

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Ability User", 120, "P"), 0))
	active_slot.effects.append({
		"type": "ability_demo_used",
		"turn": gsm.game_state.turn_number,
	})

	battle_scene.call("_refresh_slot_card_view", "my_active", active_slot, true)
	var used_panel := active_view.get("_status_used_panel") as Control
	var used_label := active_view.get("_status_used_label") as Label
	return run_checks([
		assert_true(used_panel != null, "BattleCardView should expose a USED status panel"),
		assert_true(used_panel.visible, "Used-ability active Pokemon should show the USED badge"),
		assert_true(used_label != null, "BattleCardView should expose a USED status label"),
		assert_eq(used_label.text, "USED", "USED badge should use the expected text"),
		assert_true(bool(battle_scene.call("_slot_used_ability_this_turn", active_slot)), "BattleScene should still detect used abilities this turn"),
	])

	return run_checks([
		assert_eq(int(active_view.rotation_degrees), 15, "本回合已用过特性的战斗宝可梦应向右倾斜 15 度"),
		assert_true(bool(battle_scene.call("_slot_used_ability_this_turn", active_slot)), "当回合 ability 标记应被 BattleScene 识别为已用特性"),
	])


func test_battle_scene_used_ability_tilt_resets_next_turn() -> String:
	var battle_scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 3
	battle_scene._gsm = gsm

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_panel := PanelContainer.new()
	var bench_view := BattleCardViewScript.new()
	bench_panel.add_child(bench_view)
	battle_scene.set("_slot_card_views", {"my_bench_0": bench_view})

	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench Ability User", 90, "P"), 0))
	bench_slot.effects.append({
		"type": "ability_demo_used",
		"turn": 3,
	})

	battle_scene.call("_refresh_slot_card_view", "my_bench_0", bench_slot, false)
	var used_panel_now := bench_view.get("_status_used_panel") as Control
	var used_visible_now: bool = used_panel_now != null and used_panel_now.visible
	var tilted_now: float = 15.0
	gsm.game_state.turn_number = 4
	battle_scene.call("_refresh_slot_card_view", "my_bench_0", bench_slot, false)
	var used_panel_next_turn := bench_view.get("_status_used_panel") as Control
	return run_checks([
		assert_true(used_panel_now != null, "BattleCardView should expose a USED status panel"),
		assert_true(used_visible_now, "USED badge should be visible during the turn it was used"),
		assert_true(used_panel_next_turn != null, "BattleCardView should keep the USED status panel after refresh"),
		assert_false(used_panel_next_turn.visible, "USED badge should clear on the next turn"),
		assert_false(bool(battle_scene.call("_slot_used_ability_this_turn", bench_slot)), "Old ability markers should not count next turn"),
	])

	return run_checks([
		assert_eq(int(tilted_now), 15, "备战区宝可梦本回合用过特性时也应倾斜"),
		assert_eq(int(bench_view.rotation_degrees), 0, "到下个回合刷新后应自动回正"),
		assert_false(bool(battle_scene.call("_slot_used_ability_this_turn", bench_slot)), "非当回合的 ability 标记不应继续判定为已用特性"),
	])


func test_battle_scene_used_ability_tilt_adjusts_card_z_index() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(120, 168)
	card_view.size = Vector2(120, 168)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 120,
		"hp_max": 120,
		"hp_ratio": 1.0,
		"energy_icons": [],
		"tool_name": "",
		"ability_used_this_turn": true,
	})
	var used_panel := card_view.get("_status_used_panel") as Control
	var used_label := card_view.get("_status_used_label") as Label
	return run_checks([
		assert_true(used_panel != null, "BattleCardView should expose a USED status panel"),
		assert_true(used_panel.visible, "USED badge should be visible when battle status marks ability usage"),
		assert_true(used_label != null, "BattleCardView should expose a USED status label"),
		assert_eq(used_label.text, "USED", "USED badge should render the expected text"),
		assert_eq(int(card_view.rotation_degrees), 0, "Card root should remain upright"),
		assert_eq(int(card_view.z_index), 0, "USED badge should not change card layering"),
	])


func test_battle_card_view_used_energy_hp_rows_keep_fixed_bottom_stack_metrics() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(137, 192)
	card_view.size = Vector2(137, 192)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["R", "C"],
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var hud := card_view.get("_status_hud") as VBoxContainer
	var used_panel := card_view.get("_status_used_panel") as Control
	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var status_panel := card_view.get("_status_condition_panel") as Control
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var children := hud.get_children() if hud != null else []
	var used_index := children.find(used_panel)
	var hp_index := children.find(hp_panel)
	var energy_index := children.find(energy_panel)
	var last_visible: Control = null
	for child_variant: Variant in children:
		var child := child_variant as Control
		if child != null and child.visible:
			last_visible = child

	var used_height := used_panel.custom_minimum_size.y if used_panel != null else -1.0
	var hp_height := hp_panel.custom_minimum_size.y if hp_panel != null else -2.0
	var energy_height := energy_panel.custom_minimum_size.y if energy_panel != null else -3.0
	var hud_alignment := int(hud.alignment) if hud != null else -1

	var result := run_checks([
		assert_true(hud != null, "Battle status HUD should exist"),
		assert_eq(hud_alignment, int(BoxContainer.ALIGNMENT_END), "Battle status HUD rows should stay anchored to the bottom"),
		assert_true(used_panel != null and used_panel.visible, "USED row should be visible after an ability is used"),
		assert_true(energy_panel != null and energy_panel.visible, "Energy row should be visible when Energy is attached"),
		assert_true(status_panel != null and not status_panel.visible, "Empty status row should not reserve a visible slot"),
		assert_true(absf(used_height - hp_height) < 0.1, "USED row should reserve the same height as HP"),
		assert_true(absf(energy_height - hp_height) < 0.1, "Energy row should reserve the same height as HP"),
		assert_true(used_index >= 0 and hp_index == used_index + 1, "USED row should stack directly above HP"),
		assert_true(energy_index > hp_index, "Energy row should remain below HP in the battle HUD order"),
		assert_true(last_visible == energy_panel, "Bottom visible battle HUD row should remain stable when USED and Energy are both present"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_status_icons_render_below_hp_and_clear() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(120, 168)
	card_view.size = Vector2(120, 168)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 90,
		"hp_max": 120,
		"hp_ratio": 0.75,
		"status_icons": ["poisoned", "confused", "paralyzed"],
		"energy_icons": ["D"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})

	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var status_panel := card_view.get("_status_condition_panel") as Control
	var status_row := card_view.get("_status_condition_row") as HBoxContainer
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var hud := card_view.get("_status_hud") as VBoxContainer
	var status_index := hud.get_children().find(status_panel) if hud != null else -1
	var hp_index := hud.get_children().find(hp_panel) if hud != null else -1
	var energy_index := hud.get_children().find(energy_panel) if hud != null else -1
	var status_visible_with_conditions := status_panel != null and status_panel.visible
	var child_count_with_conditions := status_row.get_child_count() if status_row != null else -1

	card_view.set_battle_status({
		"hp_current": 90,
		"hp_max": 120,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["D"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var status_visible_after_clear := status_panel != null and status_panel.visible
	var child_count_after_clear := status_row.get_child_count() if status_row != null else -1

	return run_checks([
		assert_true(status_panel != null, "BattleCardView should expose a status condition panel"),
		assert_true(status_row != null, "BattleCardView should expose a status condition row"),
		assert_true(status_visible_with_conditions, "Status condition panel should show when status exists"),
		assert_eq(child_count_with_conditions, 3, "BattleCardView should render one icon per active status"),
		assert_false(status_visible_after_clear, "Status condition panel should hide when status clears"),
		assert_eq(child_count_after_clear, 0, "Status condition row should not keep stale icons"),
		assert_true(hp_index >= 0 and status_index == hp_index + 1, "Status condition row should sit directly below HP"),
		assert_true(energy_index > status_index, "Energy row should stay below status condition row"),
	])


func test_battle_card_view_status_hud_scales_with_portrait_card_size() -> String:
	var small_card := BattleCardViewScript.new()
	small_card.custom_minimum_size = Vector2(120, 168)
	small_card.size = Vector2(120, 168)
	small_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	small_card.set_battle_status({
		"hp_current": 120,
		"hp_max": 120,
		"hp_ratio": 1.0,
		"status_icons": ["poisoned"],
		"energy_icons": ["L"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var small_hp_label := small_card.get("_status_hp_value_label") as Label
	var small_energy_row := small_card.get("_status_energy_row") as HBoxContainer
	var small_icon: Control = null
	if small_energy_row != null and small_energy_row.get_child_count() > 0:
		small_icon = small_energy_row.get_child(0) as Control

	var large_card := BattleCardViewScript.new()
	large_card.custom_minimum_size = Vector2(214, 300)
	large_card.size = Vector2(214, 300)
	large_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	large_card.set_battle_status({
		"hp_current": 200,
		"hp_max": 200,
		"hp_ratio": 1.0,
		"status_icons": ["poisoned"],
		"energy_icons": ["L"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var large_hp_label := large_card.get("_status_hp_value_label") as Label
	var large_energy_row := large_card.get("_status_energy_row") as HBoxContainer
	var large_icon: Control = null
	if large_energy_row != null and large_energy_row.get_child_count() > 0:
		large_icon = large_energy_row.get_child(0) as Control

	var result := run_checks([
		assert_true(small_hp_label != null and large_hp_label != null, "BattleCardView should expose HP labels for status scaling"),
		assert_gt(large_hp_label.get_theme_font_size("font_size"), small_hp_label.get_theme_font_size("font_size"), "Portrait-size cards should scale up the HP text"),
		assert_true(small_icon != null and large_icon != null, "BattleCardView should expose energy icons for status scaling"),
		assert_gt(large_icon.custom_minimum_size.x, small_icon.custom_minimum_size.x, "Portrait-size cards should scale up energy icons"),
	])

	small_card.queue_free()
	large_card.queue_free()
	return result


func test_battle_card_view_portrait_status_rows_follow_card_size() -> String:
	var base_card := BattleCardViewScript.new()
	base_card.custom_minimum_size = Vector2(214, 300)
	base_card.size = Vector2(214, 300)
	base_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	base_card.set_battle_status({
		"hp_current": 170,
		"hp_max": 220,
		"hp_ratio": 0.77,
		"status_icons": ["poisoned"],
		"energy_icons": ["R", "C"],
		"tool_name": "勇气护符",
		"ability_used_this_turn": false,
	})

	var portrait_card := BattleCardViewScript.new()
	portrait_card.custom_minimum_size = Vector2(214, 300)
	portrait_card.size = Vector2(214, 300)
	portrait_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	portrait_card.set_portrait_status_metrics_enabled(true)
	portrait_card.set_battle_status({
		"hp_current": 170,
		"hp_max": 220,
		"hp_ratio": 0.77,
		"status_icons": ["poisoned"],
		"energy_icons": ["R", "C"],
		"tool_name": "勇气护符",
		"ability_used_this_turn": false,
	})

	var base_hp_font := (base_card.get("_status_hp_value_label") as Label).get_theme_font_size("font_size")
	var base_tool_font := (base_card.get("_status_tool_label") as Label).get_theme_font_size("font_size")
	var base_status_row := base_card.get("_status_condition_row") as HBoxContainer
	var base_energy_row := base_card.get("_status_energy_row") as HBoxContainer
	var base_status_icon := base_status_row.get_child(0) as Control if base_status_row != null and base_status_row.get_child_count() > 0 else null
	var base_energy_icon := base_energy_row.get_child(0) as Control if base_energy_row != null and base_energy_row.get_child_count() > 0 else null
	var portrait_hp := (portrait_card.get("_status_hp_bar_panel") as Control).custom_minimum_size.y
	var portrait_status := (portrait_card.get("_status_condition_panel") as Control).custom_minimum_size.y
	var portrait_energy := (portrait_card.get("_status_energy_panel") as Control).custom_minimum_size.y
	var portrait_tool := (portrait_card.get("_status_tool_panel") as Control).custom_minimum_size.y
	var portrait_hp_font := (portrait_card.get("_status_hp_value_label") as Label).get_theme_font_size("font_size")
	var portrait_tool_font := (portrait_card.get("_status_tool_label") as Label).get_theme_font_size("font_size")
	var portrait_status_row := portrait_card.get("_status_condition_row") as HBoxContainer
	var portrait_energy_row := portrait_card.get("_status_energy_row") as HBoxContainer
	var portrait_status_icon := portrait_status_row.get_child(0) as Control if portrait_status_row != null and portrait_status_row.get_child_count() > 0 else null
	var portrait_energy_icon := portrait_energy_row.get_child(0) as Control if portrait_energy_row != null and portrait_energy_row.get_child_count() > 0 else null
	var expected_portrait_slot_height := portrait_card.custom_minimum_size.y / 5.0

	var result := run_checks([
		assert_true(absf(portrait_hp - expected_portrait_slot_height) <= 0.1, "Portrait HP slot should be one fifth of the card height"),
		assert_true(absf(portrait_status - expected_portrait_slot_height) <= 0.1, "Portrait status slot should be one fifth of the card height"),
		assert_true(absf(portrait_energy - expected_portrait_slot_height) <= 0.1, "Portrait Energy slot should be one fifth of the card height"),
		assert_true(absf(portrait_tool - expected_portrait_slot_height) <= 0.1, "Portrait Tool text slot should be one fifth of the card height"),
		assert_gt(portrait_hp_font, base_hp_font, "Portrait HP text should use the fixed one-fifth slot to become more readable"),
		assert_gt(portrait_tool_font, base_tool_font, "Portrait Tool text should use the fixed one-fifth slot to become more readable"),
		assert_true(portrait_status_icon != null and base_status_icon != null and portrait_status_icon.custom_minimum_size.y > base_status_icon.custom_minimum_size.y, "Portrait status icons should use the fixed one-fifth slot to become more readable"),
		assert_true(portrait_energy_icon != null and base_energy_icon != null and portrait_energy_icon.custom_minimum_size.y > base_energy_icon.custom_minimum_size.y, "Portrait Energy icons should use the fixed one-fifth slot to become more readable"),
		assert_true(portrait_status_icon != null and portrait_energy_icon != null and absf(portrait_status_icon.custom_minimum_size.y - portrait_energy_icon.custom_minimum_size.y) <= 0.1, "Portrait status and Energy icons should share the same enlarged metric"),
	])

	base_card.queue_free()
	portrait_card.queue_free()
	return result


func test_battle_card_view_portrait_status_slots_are_one_fifth_of_card_height() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(214, 300)
	card_view.size = Vector2(214, 300)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	card_view.set_portrait_status_metrics_enabled(true)
	card_view.set_battle_status({
		"hp_current": 170,
		"hp_max": 220,
		"hp_ratio": 0.77,
		"status_icons": ["poisoned"],
		"energy_icons": ["R", "C"],
		"tool_name": "Tool text",
		"ability_used_this_turn": true,
	})

	var used_panel := card_view.get("_status_used_panel") as Control
	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var status_panel := card_view.get("_status_condition_panel") as Control
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var tool_panel := card_view.get("_status_tool_panel") as Control
	var status_hud := card_view.get("_status_hud") as VBoxContainer
	var expected_height := minf(card_view.custom_minimum_size.y / 5.0, (card_view.custom_minimum_size.y - 20.0) / 5.0)
	var visible_stack_height := 0.0
	for panel: Control in [used_panel, hp_panel, status_panel, energy_panel, tool_panel]:
		if panel != null and panel.visible:
			visible_stack_height += panel.custom_minimum_size.y

	var result := run_checks([
		assert_true(used_panel != null and absf(used_panel.custom_minimum_size.y - expected_height) <= 0.1, "Portrait ability-used text slot should fit the available status overlay height"),
		assert_true(hp_panel != null and absf(hp_panel.custom_minimum_size.y - expected_height) <= 0.1, "Portrait HP slot should fit the available status overlay height"),
		assert_true(status_panel != null and absf(status_panel.custom_minimum_size.y - expected_height) <= 0.1, "Portrait special-condition slot should fit the available status overlay height"),
		assert_true(energy_panel != null and absf(energy_panel.custom_minimum_size.y - expected_height) <= 0.1, "Portrait Energy slot should fit the available status overlay height"),
		assert_true(tool_panel != null and absf(tool_panel.custom_minimum_size.y - expected_height) <= 0.1, "Portrait text/tool slot should fit the available status overlay height"),
		assert_true(visible_stack_height <= card_view.custom_minimum_size.y - 20.0 + 0.1, "All visible portrait status rows should fit inside the card overlay"),
		assert_eq(status_hud.get_theme_constant("separation") if status_hud != null else -1, 0, "Portrait field status slots should not add extra vertical gap beyond the fitted slots"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_portrait_status_text_uses_large_readable_metrics() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(214, 300)
	card_view.size = Vector2(214, 300)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	card_view.set_portrait_status_metrics_enabled(true)
	card_view.set_battle_status({
		"hp_current": 170,
		"hp_max": 220,
		"hp_ratio": 0.77,
		"status_icons": [],
		"energy_icons": [],
		"tool_name": "勇气护符",
		"ability_used_this_turn": true,
	})

	var slot_height := card_view.custom_minimum_size.y / 5.0
	var used_label := card_view.get("_status_used_label") as Label
	var hp_label := card_view.get("_status_hp_value_label") as Label
	var tool_label := card_view.get("_status_tool_label") as Label
	var hp_font := hp_label.get_theme_font("font") as FontVariation if hp_label != null else null
	var tool_font := tool_label.get_theme_font("font") as FontVariation if tool_label != null else null
	var tool_regular_weight := tool_font == null or tool_font.variation_embolden <= 0.05
	var used_matches_tool_size := used_label != null and tool_label != null and absf(float(used_label.get_theme_font_size("font_size") - tool_label.get_theme_font_size("font_size"))) <= 0.1

	var result := run_checks([
		assert_true(hp_label != null and hp_label.get_theme_font_size("font_size") >= roundi(slot_height * 0.52), "Portrait HP text should use most of the fixed status slot height"),
		assert_true(tool_label != null and tool_label.get_theme_font_size("font_size") >= roundi(slot_height * 0.45), "Portrait Tool text should be large enough in the fixed status slot"),
		assert_true(used_matches_tool_size, "Portrait USED text should match the Tool text size"),
		assert_true(hp_label != null and hp_label.get_theme_constant("outline_size") >= 2, "Portrait HP text should use a readable outline on the HP bar"),
		assert_true(tool_label != null and tool_label.get_theme_constant("outline_size") >= 1, "Portrait Tool text should use a subtle outline for thicker glyphs"),
		assert_true(hp_font != null and hp_font.variation_embolden >= 1.45, "Portrait HP text should use a heavier font variation"),
		assert_true(tool_regular_weight, "Portrait Tool text should use regular font weight"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_landscape_used_text_matches_tool_metrics() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(137, 192)
	card_view.size = Vector2(137, 192)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": [],
		"tool_name": "Tool",
		"ability_used_this_turn": true,
	})

	var used_label := card_view.get("_status_used_label") as Label
	var tool_label := card_view.get("_status_tool_label") as Label
	var tool_font := tool_label.get_theme_font("font") as FontVariation if tool_label != null else null
	var tool_regular_weight := tool_font == null or tool_font.variation_embolden <= 0.05
	var used_matches_tool_size := used_label != null and tool_label != null and absf(float(used_label.get_theme_font_size("font_size") - tool_label.get_theme_font_size("font_size"))) <= 0.1

	var result := run_checks([
		assert_true(used_matches_tool_size, "Landscape USED text should match the Tool text size"),
		assert_true(tool_regular_weight, "Landscape Tool text should use regular font weight"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_landscape_used_energy_tool_does_not_expand_card_minimum() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(64, 90)
	card_view.size = Vector2(64, 90)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_status_text_scale(0.8)
	card_view.set_portrait_status_metrics_enabled(true)
	card_view.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["R", "C", "L"],
		"tool_name": "Tool",
		"ability_used_this_turn": false,
	})
	var before_minimum := card_view.get_combined_minimum_size()
	card_view.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["R", "C", "L"],
		"tool_name": "Tool",
		"ability_used_this_turn": true,
	})
	var after_minimum := card_view.get_combined_minimum_size()
	var used_panel := card_view.get("_status_used_panel") as Control
	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var tool_panel := card_view.get("_status_tool_panel") as Control
	var visible_stack_height := 0.0
	for panel: Control in [used_panel, hp_panel, energy_panel, tool_panel]:
		if panel != null and panel.visible:
			visible_stack_height += panel.custom_minimum_size.y
	var available_status_height := card_view.custom_minimum_size.y - 20.0

	var result := run_checks([
		assert_true(before_minimum.y <= card_view.custom_minimum_size.y + 0.5, "Energy plus Tool should not expand the landscape card before USED appears"),
		assert_true(after_minimum.y <= card_view.custom_minimum_size.y + 0.5, "USED plus Energy plus Tool should not expand the landscape card minimum"),
		assert_true(visible_stack_height <= available_status_height + 0.1, "USED plus Energy plus Tool rows should fit inside the card overlay instead of overflowing"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_landscape_vstar_energy_icon_stays_with_text_metrics() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(137, 192)
	card_view.size = Vector2(137, 192)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	card_view.set_status_text_scale(0.8)
	card_view.set_portrait_status_metrics_enabled(true)
	card_view.set_battle_status({
		"hp_current": 280,
		"hp_max": 280,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": ["W"],
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var combined_minimum := card_view.get_combined_minimum_size()
	var used_panel := card_view.get("_status_used_panel") as Control
	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var used_label := card_view.get("_status_used_label") as Label
	var hp_label := card_view.get("_status_hp_value_label") as Label
	var energy_row := card_view.get("_status_energy_row") as HBoxContainer
	var energy_icon := energy_row.get_child(0) as Control if energy_row != null and energy_row.get_child_count() > 0 else null
	var used_font_size := used_label.get_theme_font_size("font_size") if used_label != null else 0
	var hp_font_size := hp_label.get_theme_font_size("font_size") if hp_label != null else 0
	var max_text_metric := maxi(used_font_size, hp_font_size)
	var energy_icon_height := energy_icon.custom_minimum_size.y if energy_icon != null else 0.0

	var icon_metric_check := ""
	if energy_icon_height > float(max_text_metric) + 0.1:
		icon_metric_check = "Landscape VSTAR Energy icon should stay within text metrics; energy_icon=%.2f max_text=%d used=%d hp=%d" % [
			energy_icon_height,
			max_text_metric,
			used_font_size,
			hp_font_size,
		]
	var result := run_checks([
		assert_true(combined_minimum.y <= card_view.custom_minimum_size.y + 0.5, "Landscape VSTAR Energy HUD should not grow the card minimum height"),
		assert_true(used_panel != null and hp_panel != null and energy_panel != null, "Landscape VSTAR status panels should be available"),
		assert_true(hp_panel != null and energy_panel != null and absf(hp_panel.custom_minimum_size.y - energy_panel.custom_minimum_size.y) <= 0.1, "Landscape VSTAR Energy slot height should match the HP slot height"),
		icon_metric_check,
	])

	card_view.queue_free()
	return result


func test_battle_card_view_portrait_vstar_energy_icon_stays_with_text_metrics() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(214, 300)
	card_view.size = Vector2(214, 300)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	card_view.set_status_text_scale(1.0)
	card_view.set_portrait_status_metrics_enabled(true)
	card_view.set_battle_status({
		"hp_current": 280,
		"hp_max": 280,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": ["W"],
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var combined_minimum := card_view.get_combined_minimum_size()
	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var used_label := card_view.get("_status_used_label") as Label
	var hp_label := card_view.get("_status_hp_value_label") as Label
	var energy_row := card_view.get("_status_energy_row") as HBoxContainer
	var energy_icon := energy_row.get_child(0) as Control if energy_row != null and energy_row.get_child_count() > 0 else null
	var max_text_metric := maxi(
		used_label.get_theme_font_size("font_size") if used_label != null else 0,
		hp_label.get_theme_font_size("font_size") if hp_label != null else 0
	)
	var energy_icon_height := energy_icon.custom_minimum_size.y if energy_icon != null else 0.0

	var result := run_checks([
		assert_true(combined_minimum.y <= card_view.custom_minimum_size.y + 0.5, "Portrait VSTAR Energy HUD should not grow the card minimum height"),
		assert_true(hp_panel != null and energy_panel != null and absf(hp_panel.custom_minimum_size.y - energy_panel.custom_minimum_size.y) <= 0.1, "Portrait VSTAR Energy slot height should match the HP slot height"),
		assert_true(energy_icon != null and energy_icon_height <= float(max_text_metric) + 0.1, "Portrait VSTAR Energy icon should stay within text metrics"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_landscape_energy_icons_shrink_without_slot_growth() -> String:
	var one_card := BattleCardViewScript.new()
	one_card.custom_minimum_size = Vector2(137, 192)
	one_card.size = Vector2(137, 192)
	one_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	one_card.set_status_text_scale(0.8)
	one_card.set_portrait_status_metrics_enabled(true)
	one_card.set_battle_status({
		"hp_current": 280,
		"hp_max": 280,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": ["W"],
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var eight_icons: Array[String] = []
	for _i: int in 8:
		eight_icons.append("W")
	var eight_card := BattleCardViewScript.new()
	eight_card.custom_minimum_size = Vector2(137, 192)
	eight_card.size = Vector2(137, 192)
	eight_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	eight_card.set_status_text_scale(0.8)
	eight_card.set_portrait_status_metrics_enabled(true)
	eight_card.set_battle_status({
		"hp_current": 280,
		"hp_max": 280,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": eight_icons,
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var sixteen_icons: Array[String] = []
	for _i: int in 16:
		sixteen_icons.append("W")
	var sixteen_card := BattleCardViewScript.new()
	sixteen_card.custom_minimum_size = Vector2(137, 192)
	sixteen_card.size = Vector2(137, 192)
	sixteen_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	sixteen_card.set_status_text_scale(0.8)
	sixteen_card.set_portrait_status_metrics_enabled(true)
	sixteen_card.set_battle_status({
		"hp_current": 280,
		"hp_max": 280,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": sixteen_icons,
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var one_energy_panel := one_card.get("_status_energy_panel") as Control
	var eight_energy_panel := eight_card.get("_status_energy_panel") as Control
	var sixteen_energy_panel := sixteen_card.get("_status_energy_panel") as Control
	var one_energy_row := one_card.get("_status_energy_row") as HBoxContainer
	var eight_energy_row := eight_card.get("_status_energy_row") as HBoxContainer
	var sixteen_energy_row := sixteen_card.get("_status_energy_row") as HBoxContainer
	var one_icon := one_energy_row.get_child(0) as Control if one_energy_row != null and one_energy_row.get_child_count() > 0 else null
	var eight_icon := eight_energy_row.get_child(0) as Control if eight_energy_row != null and eight_energy_row.get_child_count() > 0 else null
	var sixteen_icon := sixteen_energy_row.get_child(0) as Control if sixteen_energy_row != null and sixteen_energy_row.get_child_count() > 0 else null
	var one_slot_height := one_energy_panel.custom_minimum_size.y if one_energy_panel != null else -1.0
	var eight_slot_height := eight_energy_panel.custom_minimum_size.y if eight_energy_panel != null else -2.0
	var sixteen_slot_height := sixteen_energy_panel.custom_minimum_size.y if sixteen_energy_panel != null else -3.0
	var one_icon_size := one_icon.custom_minimum_size.y if one_icon != null else -1.0
	var eight_icon_size := eight_icon.custom_minimum_size.y if eight_icon != null else -2.0
	var sixteen_icon_size := sixteen_icon.custom_minimum_size.y if sixteen_icon != null else -3.0
	var eight_row_width := eight_energy_row.get_combined_minimum_size().x if eight_energy_row != null else INF
	var sixteen_row_width := sixteen_energy_row.get_combined_minimum_size().x if sixteen_energy_row != null else INF
	var eight_width_check := ""
	if eight_row_width > eight_card.custom_minimum_size.x + 0.1:
		eight_width_check = "Eight Energy icons should fit the landscape card width; row_width=%.2f card_width=%.2f icon_size=%.2f icon_width=%.2f child_min=%.2f row_min=%s count=%d separation=%d" % [
			eight_row_width,
			eight_card.custom_minimum_size.x,
			eight_icon_size,
			eight_icon.custom_minimum_size.x if eight_icon != null else -1.0,
			eight_icon.get_combined_minimum_size().x if eight_icon != null else -1.0,
			str(eight_energy_row.custom_minimum_size if eight_energy_row != null else Vector2.ZERO),
			eight_energy_row.get_child_count() if eight_energy_row != null else -1,
			eight_energy_row.get_theme_constant("separation") if eight_energy_row != null else -1,
		]
	var sixteen_width_check := ""
	if sixteen_row_width > sixteen_card.custom_minimum_size.x + 0.1:
		sixteen_width_check = "Sixteen Energy icons should fit the landscape card width; row_width=%.2f card_width=%.2f icon_size=%.2f separation=%d" % [
			sixteen_row_width,
			sixteen_card.custom_minimum_size.x,
			sixteen_icon_size,
			sixteen_energy_row.get_theme_constant("separation") if sixteen_energy_row != null else -1,
		]

	var result := run_checks([
		assert_true(one_card.get_combined_minimum_size().y <= one_card.custom_minimum_size.y + 0.5, "One Energy should not grow the landscape card height"),
		assert_true(eight_card.get_combined_minimum_size().y <= eight_card.custom_minimum_size.y + 0.5, "Eight Energy icons should not grow the landscape card height"),
		assert_true(sixteen_card.get_combined_minimum_size().y <= sixteen_card.custom_minimum_size.y + 0.5, "Sixteen Energy icons should not grow the landscape card height"),
		assert_true(absf(one_slot_height - eight_slot_height) <= 0.1, "Landscape Energy slot height should not change when more Energy is attached"),
		assert_true(absf(one_slot_height - sixteen_slot_height) <= 0.1, "Landscape Energy slot height should stay fixed even with many Energy icons"),
		assert_true(one_icon_size > eight_icon_size and eight_icon_size > sixteen_icon_size, "Landscape Energy icons should shrink as the attached Energy count grows"),
		eight_width_check,
		sixteen_width_check,
	])

	one_card.queue_free()
	eight_card.queue_free()
	sixteen_card.queue_free()
	return result


func test_battle_card_view_portrait_energy_icons_shrink_without_slot_growth() -> String:
	var one_card := BattleCardViewScript.new()
	one_card.custom_minimum_size = Vector2(214, 300)
	one_card.size = Vector2(214, 300)
	one_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	one_card.set_status_text_scale(1.0)
	one_card.set_portrait_status_metrics_enabled(true)
	one_card.set_battle_status({
		"hp_current": 280,
		"hp_max": 280,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": ["W"],
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var twelve_icons: Array[String] = []
	for _i: int in 12:
		twelve_icons.append("W")
	var twelve_card := BattleCardViewScript.new()
	twelve_card.custom_minimum_size = Vector2(214, 300)
	twelve_card.size = Vector2(214, 300)
	twelve_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	twelve_card.set_status_text_scale(1.0)
	twelve_card.set_portrait_status_metrics_enabled(true)
	twelve_card.set_battle_status({
		"hp_current": 280,
		"hp_max": 280,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": twelve_icons,
		"tool_name": "",
		"ability_used_this_turn": true,
	})

	var one_energy_panel := one_card.get("_status_energy_panel") as Control
	var twelve_energy_panel := twelve_card.get("_status_energy_panel") as Control
	var one_energy_row := one_card.get("_status_energy_row") as HBoxContainer
	var twelve_energy_row := twelve_card.get("_status_energy_row") as HBoxContainer
	var one_icon := one_energy_row.get_child(0) as Control if one_energy_row != null and one_energy_row.get_child_count() > 0 else null
	var twelve_icon := twelve_energy_row.get_child(0) as Control if twelve_energy_row != null and twelve_energy_row.get_child_count() > 0 else null
	var one_slot_height := one_energy_panel.custom_minimum_size.y if one_energy_panel != null else -1.0
	var twelve_slot_height := twelve_energy_panel.custom_minimum_size.y if twelve_energy_panel != null else -2.0
	var one_icon_size := one_icon.custom_minimum_size.y if one_icon != null else -1.0
	var twelve_icon_size := twelve_icon.custom_minimum_size.y if twelve_icon != null else -2.0
	var twelve_row_width := twelve_energy_row.get_combined_minimum_size().x if twelve_energy_row != null else INF
	var twelve_width_check := ""
	if twelve_row_width > twelve_card.custom_minimum_size.x + 0.1:
		twelve_width_check = "Many portrait Energy icons should fit the card width; row_width=%.2f card_width=%.2f icon_size=%.2f icon_width=%.2f child_min=%.2f row_min=%s count=%d separation=%d" % [
			twelve_row_width,
			twelve_card.custom_minimum_size.x,
			twelve_icon_size,
			twelve_icon.custom_minimum_size.x if twelve_icon != null else -1.0,
			twelve_icon.get_combined_minimum_size().x if twelve_icon != null else -1.0,
			str(twelve_energy_row.custom_minimum_size if twelve_energy_row != null else Vector2.ZERO),
			twelve_energy_row.get_child_count() if twelve_energy_row != null else -1,
			twelve_energy_row.get_theme_constant("separation") if twelve_energy_row != null else -1,
		]

	var result := run_checks([
		assert_true(one_card.get_combined_minimum_size().y <= one_card.custom_minimum_size.y + 0.5, "One Energy should not grow the portrait card height"),
		assert_true(twelve_card.get_combined_minimum_size().y <= twelve_card.custom_minimum_size.y + 0.5, "Many Energy icons should not grow the portrait card height"),
		assert_true(absf(one_slot_height - twelve_slot_height) <= 0.1, "Portrait Energy slot height should not change when more Energy is attached"),
		assert_true(one_icon_size > twelve_icon_size, "Portrait Energy icons should shrink as the attached Energy count grows"),
		twelve_width_check,
	])

	one_card.queue_free()
	twelve_card.queue_free()
	return result


func test_battle_scene_landscape_field_status_uses_portrait_hp_used_tool_metrics() -> String:
	var battle_scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.turn_number = 3
	battle_scene._gsm = gsm

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_view := BattleCardViewScript.new()
	active_view.custom_minimum_size = Vector2(137, 192)
	active_view.size = Vector2(137, 192)
	battle_scene.set("_slot_card_views", {"my_active": active_view})

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Landscape Metrics", 200, "P"), 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	active_slot.attached_tool = CardInstance.create(_make_trainer_cd("Tool", "Tool", ""), 0)
	active_slot.effects.append({
		"type": "ability_demo_used",
		"turn": gsm.game_state.turn_number,
	})
	battle_scene.call("_refresh_slot_card_view", "my_active", active_slot, true)

	var expected_height := active_view.custom_minimum_size.y / 5.0
	var used_panel := active_view.get("_status_used_panel") as Control
	var hp_panel := active_view.get("_status_hp_bar_panel") as Control
	var tool_panel := active_view.get("_status_tool_panel") as Control
	var used_label := active_view.get("_status_used_label") as Label
	var hp_label := active_view.get("_status_hp_value_label") as Label
	var tool_label := active_view.get("_status_tool_label") as Label
	var energy_row := active_view.get("_status_energy_row") as HBoxContainer
	var energy_icon := energy_row.get_child(0) as Control if energy_row != null and energy_row.get_child_count() > 0 else null
	var used_matches_tool_size := used_label != null and tool_label != null and absf(float(used_label.get_theme_font_size("font_size") - tool_label.get_theme_font_size("font_size"))) <= 0.1
	var portrait_probe := BattleCardViewScript.new()
	portrait_probe.custom_minimum_size = active_view.custom_minimum_size
	portrait_probe.size = active_view.size
	portrait_probe.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	portrait_probe.set_status_text_scale(1.0)
	portrait_probe.set_portrait_status_metrics_enabled(true)
	portrait_probe.set_battle_status({
		"hp_current": 200,
		"hp_max": 200,
		"hp_ratio": 1.0,
		"status_icons": [],
		"energy_icons": [],
		"tool_name": "Tool",
		"ability_used_this_turn": true,
	})
	var portrait_hp_label := portrait_probe.get("_status_hp_value_label") as Label
	var portrait_tool_label := portrait_probe.get("_status_tool_label") as Label
	var expected_hp_font := roundi(float(portrait_hp_label.get_theme_font_size("font_size")) * 0.8) if portrait_hp_label != null else -1
	var expected_tool_font := roundi(float(portrait_tool_label.get_theme_font_size("font_size")) * 0.8) if portrait_tool_label != null else -1
	var expected_energy_icon_size := expected_hp_font

	var result := run_checks([
		assert_true(bool(active_view.get("_portrait_status_metrics_enabled")), "Landscape field cards should enable the shared readable status metrics"),
		assert_eq(float(active_view.get("_status_text_scale")), 0.8, "Landscape field status text should be scaled down by 20 percent"),
		assert_true(used_panel != null and absf(used_panel.custom_minimum_size.y - expected_height) <= 0.1, "Landscape USED slot should match the portrait one-fifth height, expected=%s got=%s card_min=%s field=%s" % [str(expected_height), str(used_panel.custom_minimum_size.y if used_panel != null else -1.0), str(active_view.custom_minimum_size), str(active_view.get("_field_slot_layout_size"))]),
		assert_true(hp_panel != null and absf(hp_panel.custom_minimum_size.y - expected_height) <= 0.1, "Landscape HP slot should match the portrait one-fifth height, expected=%s got=%s card_min=%s field=%s" % [str(expected_height), str(hp_panel.custom_minimum_size.y if hp_panel != null else -1.0), str(active_view.custom_minimum_size), str(active_view.get("_field_slot_layout_size"))]),
		assert_true(tool_panel != null and absf(tool_panel.custom_minimum_size.y - expected_height) <= 0.1, "Landscape Tool slot should match the portrait one-fifth height, expected=%s got=%s card_min=%s field=%s" % [str(expected_height), str(tool_panel.custom_minimum_size.y if tool_panel != null else -1.0), str(active_view.custom_minimum_size), str(active_view.get("_field_slot_layout_size"))]),
		assert_true(used_matches_tool_size, "Landscape USED text should keep the same size as Tool text"),
		assert_eq(hp_label.get_theme_font_size("font_size") if hp_label != null else -1, expected_hp_font, "Landscape HP text should be 20 percent smaller than portrait"),
		assert_eq(roundi(energy_icon.custom_minimum_size.y) if energy_icon != null else -1, expected_energy_icon_size, "Landscape Energy icon height should match the readable text metric"),
		assert_eq(roundi(energy_icon.custom_minimum_size.x) if energy_icon != null else -1, expected_energy_icon_size, "Landscape Energy icon width should match the readable text metric"),
		assert_eq(energy_row.alignment if energy_row != null else -1, BoxContainer.ALIGNMENT_CENTER, "Landscape Energy icons should be centered in the Energy slot"),
		assert_eq(tool_label.get_theme_font_size("font_size") if tool_label != null else -1, expected_tool_font, "Landscape Tool text should be 20 percent smaller than portrait"),
		assert_true(hp_label != null and hp_label.get_theme_constant("outline_size") >= 2, "Landscape HP text should use the readable portrait outline"),
		assert_true(tool_label != null and tool_label.get_theme_constant("outline_size") >= 1, "Landscape Tool text should use the readable portrait outline"),
	])

	portrait_probe.queue_free()
	active_view.queue_free()
	return result


func test_battle_card_view_portrait_status_icons_match_large_text_metrics() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(214, 300)
	card_view.size = Vector2(214, 300)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	card_view.set_portrait_status_metrics_enabled(true)
	card_view.set_battle_status({
		"hp_current": 170,
		"hp_max": 220,
		"hp_ratio": 0.77,
		"status_icons": ["poisoned"],
		"energy_icons": ["R"],
		"tool_name": "Tool",
		"ability_used_this_turn": false,
	})

	var hp_label := card_view.get("_status_hp_value_label") as Label
	var tool_label := card_view.get("_status_tool_label") as Label
	var status_row := card_view.get("_status_condition_row") as HBoxContainer
	var energy_row := card_view.get("_status_energy_row") as HBoxContainer
	var status_icon := status_row.get_child(0) as Control if status_row != null and status_row.get_child_count() > 0 else null
	var energy_icon := energy_row.get_child(0) as Control if energy_row != null and energy_row.get_child_count() > 0 else null
	var expected_min_icon_height := mini(
		hp_label.get_theme_font_size("font_size") if hp_label != null else 0,
		tool_label.get_theme_font_size("font_size") if tool_label != null else 0
	)

	var result := run_checks([
		assert_true(expected_min_icon_height > 0, "Portrait text metrics should be available for icon sizing"),
		assert_true(status_icon != null and status_icon.custom_minimum_size.y >= expected_min_icon_height, "Portrait special-condition icons should match the enlarged text height"),
		assert_true(energy_icon != null and energy_icon.custom_minimum_size.y >= expected_min_icon_height, "Portrait Energy icons should match the enlarged text height"),
		assert_true(status_icon != null and absf(status_icon.custom_minimum_size.y - energy_icon.custom_minimum_size.y) <= 0.1, "Portrait condition and Energy icons should use the same large metric"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_portrait_status_hud_shrinks_on_expanded_bench_cards() -> String:
	var small_card := BattleCardViewScript.new()
	small_card.custom_minimum_size = Vector2(64, 90)
	small_card.size = Vector2(64, 90)
	small_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	small_card.set_portrait_status_metrics_enabled(true)
	small_card.set_battle_status({
		"hp_current": 120,
		"hp_max": 160,
		"hp_ratio": 0.75,
		"status_icons": ["poisoned"],
		"energy_icons": ["R", "C"],
		"tool_name": "Tool",
		"ability_used_this_turn": false,
	})

	var normal_card := BattleCardViewScript.new()
	normal_card.custom_minimum_size = Vector2(120, 168)
	normal_card.size = Vector2(120, 168)
	normal_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	normal_card.set_portrait_status_metrics_enabled(true)
	normal_card.set_battle_status({
		"hp_current": 120,
		"hp_max": 160,
		"hp_ratio": 0.75,
		"status_icons": ["poisoned"],
		"energy_icons": ["R", "C"],
		"tool_name": "Tool",
		"ability_used_this_turn": false,
	})

	var small_hp_panel := small_card.get("_status_hp_bar_panel") as Control
	var small_energy_row := small_card.get("_status_energy_row") as HBoxContainer
	var small_tool_label := small_card.get("_status_tool_label") as Label
	var small_energy_icon := small_energy_row.get_child(0) as Control if small_energy_row != null and small_energy_row.get_child_count() > 0 else null
	var normal_hp_panel := normal_card.get("_status_hp_bar_panel") as Control
	var normal_energy_row := normal_card.get("_status_energy_row") as HBoxContainer
	var normal_tool_label := normal_card.get("_status_tool_label") as Label
	var normal_energy_icon := normal_energy_row.get_child(0) as Control if normal_energy_row != null and normal_energy_row.get_child_count() > 0 else null
	var expected_small_hp_height := minf(small_card.custom_minimum_size.y / 5.0, (small_card.custom_minimum_size.y - 20.0) / 4.0)
	var expected_normal_hp_height := normal_card.custom_minimum_size.y / 5.0

	var result := run_checks([
		assert_true(small_hp_panel != null and normal_hp_panel != null, "Status HUD should expose HP panels for scaling checks"),
		assert_true(small_hp_panel.custom_minimum_size.y < normal_hp_panel.custom_minimum_size.y, "Expanded-bench small cards should shrink HP status rows"),
		assert_true(small_hp_panel != null and absf(small_hp_panel.custom_minimum_size.y - expected_small_hp_height) <= 0.1, "Small expanded-bench HP rows should fit inside the status overlay"),
		assert_true(normal_hp_panel != null and absf(normal_hp_panel.custom_minimum_size.y - expected_normal_hp_height) <= 0.1, "Normal portrait HP rows should be one fifth of the card height"),
		assert_true(small_energy_icon != null and normal_energy_icon != null and small_energy_icon.custom_minimum_size.y < normal_energy_icon.custom_minimum_size.y, "Expanded-bench small cards should shrink Energy icons"),
		assert_true(small_tool_label != null and normal_tool_label != null and small_tool_label.get_theme_font_size("font_size") < normal_tool_label.get_theme_font_size("font_size"), "Expanded-bench small cards should shrink Tool text"),
	])

	small_card.queue_free()
	normal_card.queue_free()
	return result


func test_battle_card_view_status_icons_use_layout_card_size_without_feedback_growth() -> String:
	var stable_card := BattleCardViewScript.new()
	stable_card.custom_minimum_size = Vector2(137, 192)
	stable_card.size = Vector2(137, 192)
	stable_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	stable_card.set_portrait_status_metrics_enabled(true)
	stable_card.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["R", "C"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var stable_energy_row := stable_card.get("_status_energy_row") as HBoxContainer
	var stable_icon := stable_energy_row.get_child(0) as Control if stable_energy_row != null and stable_energy_row.get_child_count() > 0 else null
	var stable_icon_size := stable_icon.custom_minimum_size if stable_icon != null else Vector2.ZERO

	var feedback_card := BattleCardViewScript.new()
	feedback_card.custom_minimum_size = Vector2(137, 192)
	feedback_card.size = Vector2(274, 384)
	feedback_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	feedback_card.set_portrait_status_metrics_enabled(true)
	feedback_card.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["R", "C"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var feedback_energy_row := feedback_card.get("_status_energy_row") as HBoxContainer
	var feedback_icon := feedback_energy_row.get_child(0) as Control if feedback_energy_row != null and feedback_energy_row.get_child_count() > 0 else null

	var result := run_checks([
		assert_true(stable_icon != null and feedback_icon != null, "Energy icons should render for feedback-size regression"),
		assert_eq(feedback_icon.custom_minimum_size if feedback_icon != null else Vector2.ZERO, stable_icon_size, "Energy icon size should follow the layout card size, not the already-expanded Control size"),
	])

	stable_card.queue_free()
	feedback_card.queue_free()
	return result


func test_battle_card_view_field_slot_status_does_not_feedback_into_parent_minimum() -> String:
	var slot_size := Vector2(137, 192)
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2.ZERO
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	card_view.set_field_slot_layout_size(slot_size)
	card_view.set_portrait_status_metrics_enabled(true)
	var empty_minimum := card_view.get_combined_minimum_size()
	card_view.set_battle_status({
		"hp_current": 220,
		"hp_max": 300,
		"hp_ratio": 220.0 / 300.0,
		"status_icons": [],
		"energy_icons": ["M", "M"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var energy_minimum := card_view.get_combined_minimum_size()
	card_view.set_battle_status({
		"hp_current": 220,
		"hp_max": 300,
		"hp_ratio": 220.0 / 300.0,
		"status_icons": ["poisoned"],
		"energy_icons": ["M", "M"],
		"tool_name": "Ancient Booster Energy Capsule",
		"ability_used_this_turn": true,
	})
	var full_status_minimum := card_view.get_combined_minimum_size()
	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var expected_row_height := minf(slot_size.y / 5.0, (slot_size.y - 20.0) / 5.0)
	var row := HBoxContainer.new()
	var left_panel := PanelContainer.new()
	var right_panel := PanelContainer.new()
	left_panel.custom_minimum_size = slot_size
	right_panel.custom_minimum_size = slot_size
	row.add_child(left_panel)
	row.add_child(right_panel)
	var left_card := BattleCardViewScript.new()
	var right_card := BattleCardViewScript.new()
	for slot_card: BattleCardView in [left_card, right_card]:
		slot_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
		slot_card.set_field_slot_layout_size(slot_size)
		slot_card.set_portrait_status_metrics_enabled(true)
		slot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_card)
	right_panel.add_child(right_card)
	var row_minimum_before := row.get_combined_minimum_size()
	right_card.set_battle_status({
		"hp_current": 220,
		"hp_max": 300,
		"hp_ratio": 220.0 / 300.0,
		"status_icons": [],
		"energy_icons": ["M", "M"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var row_minimum_after := row.get_combined_minimum_size()

	var result := run_checks([
		assert_true(empty_minimum.x <= 0.5 and empty_minimum.y <= 4.5, "Locked field slot card should only keep the base frame minimum before status, got %s" % str(empty_minimum)),
		assert_true(energy_minimum.x <= empty_minimum.x + 0.5 and energy_minimum.y <= empty_minimum.y + 0.5, "Attached Energy HUD should not grow the field slot card parent minimum, before=%s after=%s" % [str(empty_minimum), str(energy_minimum)]),
		assert_true(full_status_minimum.x <= empty_minimum.x + 0.5 and full_status_minimum.y <= empty_minimum.y + 0.5, "Energy, Tool, status, and USED rows should not grow the field slot card parent minimum, before=%s after=%s" % [str(empty_minimum), str(full_status_minimum)]),
		assert_true(row_minimum_after.x <= row_minimum_before.x + 0.5 and row_minimum_after.y <= row_minimum_before.y + 0.5, "A field row should not relayout or shift neighbors after one slot gains Energy, before=%s after=%s" % [str(row_minimum_before), str(row_minimum_after)]),
		assert_true(hp_panel != null and absf(hp_panel.custom_minimum_size.y - expected_row_height) <= 0.1, "Field slot HP row should still use the slot layout height for readable metrics"),
		assert_true(energy_panel != null and absf(energy_panel.custom_minimum_size.y - expected_row_height) <= 0.1, "Field slot Energy row should still use the slot layout height for readable metrics"),
	])

	card_view.queue_free()
	row.queue_free()
	return result


func test_battle_card_view_status_and_energy_icons_share_base_size() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(137, 192)
	card_view.size = Vector2(137, 192)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": ["poisoned", "burned"],
		"energy_icons": ["R", "C"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})

	var status_row := card_view.get("_status_condition_row") as HBoxContainer
	var energy_row := card_view.get("_status_energy_row") as HBoxContainer
	var status_icon := status_row.get_child(0) as Control if status_row != null and status_row.get_child_count() > 0 else null
	var energy_icon := energy_row.get_child(0) as Control if energy_row != null and energy_row.get_child_count() > 0 else null
	var status_size := status_icon.custom_minimum_size.y if status_icon != null else -1.0
	var energy_size := energy_icon.custom_minimum_size.y if energy_icon != null else -2.0

	var result := run_checks([
		assert_true(status_icon != null and energy_icon != null, "Battle status HUD should render comparable status and Energy icons"),
		assert_true(absf(status_size - energy_size) < 0.1, "Status and attached Energy icons should share the same base size"),
	])

	card_view.queue_free()
	return result


func test_battle_card_view_double_turbo_energy_uses_two_same_size_markers() -> String:
	var basic_card := BattleCardViewScript.new()
	basic_card.custom_minimum_size = Vector2(137, 192)
	basic_card.size = Vector2(137, 192)
	basic_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	basic_card.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["C"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})
	var dte_card := BattleCardViewScript.new()
	dte_card.custom_minimum_size = Vector2(137, 192)
	dte_card.size = Vector2(137, 192)
	dte_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	dte_card.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["C", "C"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})

	var basic_row := basic_card.get("_status_energy_row") as HBoxContainer
	var dte_row := dte_card.get("_status_energy_row") as HBoxContainer
	var basic_icon := basic_row.get_child(0) as Control if basic_row != null and basic_row.get_child_count() > 0 else null
	var dte_icon_a := dte_row.get_child(0) as Control if dte_row != null and dte_row.get_child_count() > 0 else null
	var dte_icon_b := dte_row.get_child(1) as Control if dte_row != null and dte_row.get_child_count() > 1 else null

	var result := run_checks([
		assert_eq(dte_row.get_child_count() if dte_row != null else -1, 2, "Double Turbo Energy should show two Colorless Energy markers"),
		assert_true(basic_icon != null and dte_icon_a != null and dte_icon_b != null, "Basic and Double Turbo Energy markers should all render"),
		assert_eq(dte_icon_a.custom_minimum_size, basic_icon.custom_minimum_size, "The first Double Turbo marker should keep the same size as a normal Energy marker"),
		assert_eq(dte_icon_b.custom_minimum_size, basic_icon.custom_minimum_size, "The second Double Turbo marker should keep the same size as a normal Energy marker"),
	])

	basic_card.queue_free()
	dte_card.queue_free()
	return result


func test_battle_scene_double_turbo_energy_icon_codes_show_two_energy_units() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	scene.set("_gsm", gsm)
	var slot := PokemonSlot.new()
	var dte_cd := CardData.new()
	dte_cd.name = "Double Turbo Energy"
	dte_cd.card_type = "Special Energy"
	dte_cd.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
	slot.attached_energy.append(CardInstance.create(dte_cd, 0))

	var icons: Array = scene.call("_slot_energy_icon_codes", slot)
	return run_checks([
		assert_eq(icons.size(), 2, "Double Turbo Energy should show two Colorless Energy units in the field HUD"),
		assert_eq(str(icons[0]) if icons.size() > 0 else "", "C", "The first Double Turbo marker should be Colorless"),
		assert_eq(str(icons[1]) if icons.size() > 1 else "", "C", "The second Double Turbo marker should be Colorless"),
	])


func test_battle_card_view_any_energy_uses_luminous_icon_at_normal_energy_size() -> String:
	var normal_card := BattleCardViewScript.new()
	normal_card.custom_minimum_size = Vector2(137, 192)
	normal_card.size = Vector2(137, 192)
	normal_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	normal_card.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["R"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})

	var luminous_card := BattleCardViewScript.new()
	luminous_card.custom_minimum_size = Vector2(137, 192)
	luminous_card.size = Vector2(137, 192)
	luminous_card.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	luminous_card.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": [],
		"energy_icons": ["ANY"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})

	var normal_row := normal_card.get("_status_energy_row") as HBoxContainer
	var luminous_row := luminous_card.get("_status_energy_row") as HBoxContainer
	var normal_icon := normal_row.get_child(0) as Control if normal_row != null and normal_row.get_child_count() > 0 else null
	var luminous_icon := luminous_row.get_child(0) as Control if luminous_row != null and luminous_row.get_child_count() > 0 else null
	var luminous_texture: Texture2D = luminous_icon.get("texture") as Texture2D if luminous_icon != null else null

	var result := run_checks([
		assert_true(luminous_icon != null, "ANY Energy should render a field HUD marker"),
		assert_false(luminous_icon.has_meta("energy_label_chip") if luminous_icon != null else true, "ANY Energy should use the luminous texture instead of an ANY text chip"),
		assert_true(luminous_texture != null, "The luminous Energy marker should have a texture"),
		assert_eq(luminous_texture.get_size() if luminous_texture != null else Vector2.ZERO, Vector2(256, 256), "The luminous icon should use the same 256x256 source format as other Energy icons"),
		assert_eq(luminous_icon.custom_minimum_size if luminous_icon != null else Vector2.ZERO, normal_icon.custom_minimum_size if normal_icon != null else Vector2(-1, -1), "The luminous marker should render at exactly the same HUD size as a normal Energy icon"),
	])

	normal_card.queue_free()
	luminous_card.queue_free()
	return result


func test_battle_card_view_landscape_status_slots_match_hp_height() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(137, 192)
	card_view.size = Vector2(137, 192)
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 150,
		"hp_max": 200,
		"hp_ratio": 0.75,
		"status_icons": ["poisoned", "burned"],
		"energy_icons": ["R", "C", "R", "C", "R", "C", "R", "C", "R", "C", "R", "C"],
		"tool_name": "",
		"ability_used_this_turn": false,
	})

	var hp_panel := card_view.get("_status_hp_bar_panel") as Control
	var hp_bar := card_view.get("_status_hp_bar") as ProgressBar
	var hp_overlay := hp_bar.get_parent() as Control if hp_bar != null else null
	var status_panel := card_view.get("_status_condition_panel") as Control
	var energy_panel := card_view.get("_status_energy_panel") as Control
	var status_row := card_view.get("_status_condition_row") as HBoxContainer
	var energy_row := card_view.get("_status_energy_row") as HBoxContainer
	var status_icon := status_row.get_child(0) as Control if status_row != null and status_row.get_child_count() > 0 else null
	var energy_icon := energy_row.get_child(0) as Control if energy_row != null and energy_row.get_child_count() > 0 else null
	var hp_height := hp_panel.custom_minimum_size.y if hp_panel != null else 0.0
	var status_height := status_panel.custom_minimum_size.y if status_panel != null else -1.0
	var energy_height := energy_panel.custom_minimum_size.y if energy_panel != null else -1.0
	var hp_overlay_height := hp_overlay.custom_minimum_size.y if hp_overlay != null else 0.0

	var result := run_checks([
		assert_true(hp_panel != null and status_panel != null and energy_panel != null, "Landscape card should expose HP, status, and Energy slot panels"),
		assert_true(absf(status_height - hp_height) < 0.1, "Status slot height should match the HP slot height in landscape"),
		assert_true(absf(energy_height - hp_height) < 0.1, "Energy slot height should match the HP slot height in landscape"),
		assert_true(status_icon != null and status_icon.custom_minimum_size.y <= hp_overlay_height, "Status icons should fit inside the HP bar height"),
		assert_true(energy_icon != null and energy_icon.custom_minimum_size.y <= hp_overlay_height, "Energy icons should fit inside the HP bar height"),
		assert_true(energy_icon != null and status_icon != null and energy_icon.custom_minimum_size.y <= status_icon.custom_minimum_size.y * 0.75, "Attached Energy icons should stay visually smaller than status icons"),
		assert_true(energy_row != null and energy_row.get_combined_minimum_size().x <= card_view.custom_minimum_size.x, "Many attached Energy icons should not force the field card wider"),
	])

	card_view.queue_free()
	return result


func test_battle_scene_battle_status_includes_active_status_icons() -> String:
	var battle_scene = _make_battle_scene_stub()
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Status Probe", 100, "D"), 0))
	slot.set_status("poisoned", true)
	slot.set_status("burned", true)
	slot.set_status("paralyzed", true)

	var status: Dictionary = battle_scene.call("_build_battle_status", slot)
	return run_checks([
		assert_eq(status.get("status_icons", []), ["poisoned", "burned", "paralyzed"], "Battle status should expose active status icon keys in stable order"),
	])


func test_battle_card_view_marks_unimplemented_effect_card() -> String:
	var card_view := BattleCardViewScript.new()
	var card_data := CardData.new()
	card_data.name = "Missing Effect Item"
	card_data.card_type = "Item"
	card_data.effect_id = "missing-ui-effect"
	card_data.description = "Search your deck for any card."
	card_view.setup_from_card_data(card_data, BattleCardViewScript.MODE_HAND)
	var badge_panel := card_view.get("_implementation_badge_panel") as Control
	var badge_label := card_view.get("_implementation_badge_label") as Label

	return run_checks([
		assert_true(badge_panel != null, "BattleCardView should expose an unimplemented badge panel"),
		assert_true(badge_panel != null and badge_panel.visible, "Cards with missing effect implementation should show the unimplemented badge"),
		assert_true(badge_label != null, "BattleCardView should expose an unimplemented badge label"),
		assert_eq(badge_label.text, "未实现", "Unimplemented badge should use the expected HUD text"),
	])


func test_battle_card_view_hides_unimplemented_badge_for_basic_energy_and_face_down() -> String:
	var card_view := BattleCardViewScript.new()
	var energy := CardData.new()
	energy.name = "Test Energy"
	energy.card_type = "Basic Energy"
	card_view.setup_from_card_data(energy, BattleCardViewScript.MODE_HAND)
	var badge_panel := card_view.get("_implementation_badge_panel") as Control
	var visible_for_energy := badge_panel != null and badge_panel.visible

	var missing_item := CardData.new()
	missing_item.name = "Hidden Missing Effect"
	missing_item.card_type = "Item"
	missing_item.effect_id = "missing-hidden-effect"
	missing_item.description = "Draw cards."
	card_view.setup_from_card_data(missing_item, BattleCardViewScript.MODE_HAND)
	card_view.set_face_down(true)
	var visible_face_down := badge_panel != null and badge_panel.visible

	return run_checks([
		assert_true(badge_panel != null, "BattleCardView should keep the unimplemented badge panel"),
		assert_false(visible_for_energy, "Basic Energy should not show the unimplemented badge"),
		assert_false(visible_face_down, "Face-down cards should not reveal implementation status"),
	])


func test_battle_card_view_touch_long_press_opens_detail_without_left_click() -> String:
	var card_view := BattleCardViewScript.new()
	var card_data := _make_pokemon_cd("Touch Inspect", 70, "R")
	card_view.setup_from_card_data(card_data, BattleCardViewScript.MODE_HAND)
	var counters := {"left": 0, "right": 0}
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		counters["left"] = int(counters["left"]) + 1
	)
	card_view.right_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		counters["right"] = int(counters["right"]) + 1
	)

	card_view.call("_start_touch_long_press", Vector2(8, 8), 0)
	card_view.call("_on_touch_long_press_timeout")
	var suppresses_emulated_left := bool(card_view.get("_suppress_next_left_click"))
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	card_view.call("_gui_input", left_click)

	return run_checks([
		assert_eq(int(counters["right"]), 1, "Long press should reuse the right-click detail signal"),
		assert_true(suppresses_emulated_left, "Long press should suppress the next emulated left click"),
		assert_eq(int(counters["left"]), 0, "Long press detail should not also select or play the card"),
	])


func test_modal_choice_tap_suppresses_followup_battle_slot_input() -> String:
	var battle_scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		game_state.players.append(player)
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Tap Target", 120, "C"), 0))
	game_state.players[0].active_pokemon = active_slot
	gsm.game_state = game_state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	(battle_scene.get("_dialog_overlay") as Panel).visible = false

	battle_scene.call("_mark_modal_input_consumed", "test_modal_choice")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	battle_scene.call("_on_slot_input", click, "my_active")

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Panel
	var result := run_checks([
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A follow-up touch event from a modal card choice should not open the Pokemon action HUD"),
		assert_false(dialog_overlay.visible, "A follow-up touch event from a modal card choice should not show a second dialog"),
	])

	battle_scene.free()
	return result


func test_portrait_slot_tap_mouse_action_hud_option_click_activates() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(24, 24)
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(24, 24)
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	var emulated_click := InputEventMouseButton.new()
	emulated_click.button_index = MOUSE_BUTTON_LEFT
	emulated_click.pressed = true
	if option != null:
		option.emit_signal("gui_input", emulated_click)

	var result := run_checks([
		assert_true(option != null, "Portrait Pokemon action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "A real MouseButton action HUD option click should choose retreat"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "A real MouseButton action HUD option click should enter retreat target selection"),
	])

	battle_scene.free()
	return result


func test_portrait_slot_tap_delayed_mouse_action_hud_option_click_activates() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()

	var touch_position := Vector2(24, 24)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	var emulated_click := InputEventMouseButton.new()
	emulated_click.button_index = MOUSE_BUTTON_LEFT
	emulated_click.pressed = true
	emulated_click.position = touch_position
	emulated_click.global_position = touch_position
	if option != null:
		option.emit_signal("gui_input", emulated_click)

	var result := run_checks([
		assert_true(option != null, "Portrait Pokemon action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "A delayed real MouseButton action HUD option click should choose retreat"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "A delayed real MouseButton action HUD option click should enter retreat target selection"),
	])

	battle_scene.free()
	return result


func test_portrait_slot_tap_action_hud_option_touch_activates() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_touch_position := Vector2(360, 720)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	_emit_action_hud_touch_tap(option, 0, Vector2(20, 20))

	var result := run_checks([
		assert_true(option != null, "Portrait retreat-only action HUD should render the retreat option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "A real ScreenTouch tap on an action HUD option should activate retreat"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "A real ScreenTouch action option should open retreat target selection"),
	])

	battle_scene.free()
	return result


func test_portrait_retreat_action_hud_different_position_touch_tail_does_not_select_bench() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[0]
	var active_before: PokemonSlot = player.active_pokemon
	var bench_target: PokemonSlot = player.bench[0]

	battle_scene.call("_show_pokemon_action_dialog", 0, active_before, true)
	var option := _first_action_hud_option(battle_scene)
	_emit_action_hud_touch_tap(option, 0, Vector2(180, 620))
	var pending_after_retreat := str(battle_scene.get("_pending_choice"))

	var tail_press := InputEventScreenTouch.new()
	tail_press.pressed = true
	tail_press.index = 0
	tail_press.position = Vector2(260, 740)
	battle_scene.call("_on_slot_input", tail_press, "my_bench_0")
	var tail_release := InputEventScreenTouch.new()
	tail_release.pressed = false
	tail_release.index = 0
	tail_release.position = Vector2(260, 740)
	battle_scene.call("_on_slot_input", tail_release, "my_bench_0")
	var active_after_tail: PokemonSlot = player.active_pokemon
	var pending_after_tail := str(battle_scene.get("_pending_choice"))

	battle_scene.set("_modal_input_slot_suppress_until_msec", Time.get_ticks_msec() - 1)
	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	_emit_slot_touch_tap(battle_scene, "my_bench_0", 0, Vector2(260, 740))

	var result := run_checks([
		assert_true(option != null, "Retreat-only action HUD should render the retreat option"),
		assert_eq(pending_after_retreat, "retreat_bench", "Touching the action HUD retreat option should enter Bench target selection"),
		assert_eq(active_after_tail, active_before, "A different-position tail event from the same HUD touch should not promote a Bench Pokemon"),
		assert_eq(pending_after_tail, "retreat_bench", "Blocking the different-position tail event should keep retreat target selection open"),
		assert_eq(player.active_pokemon, bench_target, "A later intentional Bench touch should still complete retreat"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "The intentional Bench touch should clear retreat selection"),
	])

	battle_scene.free()
	return result


func test_portrait_slot_tap_immediate_mouse_action_hud_option_click_activates() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_touch_position := Vector2(360, 720)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	var immediate_mouse_echo := InputEventMouseButton.new()
	immediate_mouse_echo.button_index = MOUSE_BUTTON_LEFT
	immediate_mouse_echo.pressed = true
	immediate_mouse_echo.position = Vector2(20, 20)
	immediate_mouse_echo.global_position = Vector2(360, 160)
	if option != null:
		option.emit_signal("gui_input", immediate_mouse_echo)

	var result := run_checks([
		assert_true(option != null, "Portrait retreat-only action HUD should render the retreat option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "A real immediate MouseButton action HUD option click should choose retreat"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "A real immediate MouseButton action HUD option click should enter retreat target selection"),
	])

	battle_scene.free()
	return result


func test_mouse_opened_retreat_hud_option_press_enters_retreat() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_click_position := Vector2(360, 720)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)

	var option := _first_action_hud_option(battle_scene)
	var delayed_option_press := InputEventMouseButton.new()
	delayed_option_press.button_index = MOUSE_BUTTON_LEFT
	delayed_option_press.pressed = true
	delayed_option_press.position = Vector2(18, 18)
	delayed_option_press.global_position = Vector2(360, 160)
	if option != null:
		option.emit_signal("gui_input", delayed_option_press)

	var result := run_checks([
		assert_true(option != null, "Retreat-only action HUD should render the retreat option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "A real MouseButton press on the retreat option should enter retreat target selection"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "A real MouseButton press on the retreat option should open field-target mode"),
	])

	battle_scene.free()
	return result


func test_mouse_slot_release_opens_action_hud() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_click_position := Vector2(360, 720)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = original_click_position
	press.global_position = original_click_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var pending_after_press := str(battle_scene.get("_pending_choice"))
	var option_after_press := _first_action_hud_option(battle_scene)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = original_click_position
	release.global_position = original_click_position
	battle_scene.call("_on_slot_input", release, "my_active")
	var option_after_release := _first_action_hud_option(battle_scene)

	var result := run_checks([
		assert_eq(pending_after_press, "", "Mouse slot press should only start the slot click, not open the Pokemon action HUD"),
		assert_true(option_after_press == null, "The action HUD option should not exist before the opening mouse release"),
		assert_eq(str(battle_scene.get("_pending_choice")), "pokemon_action", "Mouse slot release should open the Pokemon action HUD"),
		assert_true(option_after_release != null, "The action HUD option should render after the opening mouse release"),
	])

	battle_scene.free()
	return result


func test_mouse_opened_action_hud_followup_option_click_enters_retreat() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_click_position := Vector2(360, 720)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = original_click_position
	press.global_position = original_click_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = original_click_position
	release.global_position = original_click_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	_emit_action_hud_mouse_click(option, Vector2(18, 18), Vector2(580, 260))

	var result := run_checks([
		assert_true(option != null, "Retreat-only action HUD should render the retreat option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "A real MouseButton option click after opening the HUD should choose retreat"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "A real MouseButton option click should enter retreat target selection"),
	])

	battle_scene.free()
	return result


func test_touch_opened_action_hud_delayed_mouse_option_click_activates() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_touch_position := Vector2(360, 720)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	_emit_action_hud_mouse_click(option, Vector2(18, 18), Vector2(580, 260))

	var result := run_checks([
		assert_true(option != null, "Retreat-only action HUD should render the retreat option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "A delayed real MouseButton action HUD option click should choose retreat"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "A delayed real MouseButton action HUD option click should enter retreat target selection"),
	])

	battle_scene.free()
	return result


func test_tool_attached_active_repeated_touch_opening_never_auto_enters_retreat() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot: PokemonSlot = player.active_pokemon
	var emergency_board := CardInstance.create(_make_trainer_cd("Emergency Board", "Tool", "Tool attached before opening the action HUD"), 0)
	active_slot.attached_tool = emergency_board

	var pending_after_attempts: Array[String] = []
	var field_mode_after_attempts: Array[String] = []
	var first_action_types: Array[String] = []

	for attempt: int in 3:
		battle_scene.set("_modal_input_slot_suppress_until_msec", Time.get_ticks_msec() - 1)
		battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 2000)

		var touch_position := Vector2(360 + attempt * 7, 720 - attempt * 5)
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.index = 0
		press.position = touch_position
		battle_scene.call("_on_slot_input", press, "my_active")
		var release := InputEventScreenTouch.new()
		release.pressed = false
		release.index = 0
		release.position = touch_position
		battle_scene.call("_on_slot_input", release, "my_active")

		var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
		first_action_types.append(str((actions[0] as Dictionary).get("type", "")) if not actions.is_empty() and actions[0] is Dictionary else "")

		pending_after_attempts.append(str(battle_scene.get("_pending_choice")))
		field_mode_after_attempts.append(str(battle_scene.get("_field_interaction_mode")))
		battle_scene.call("_on_dialog_cancel")

	var result := run_checks([
		assert_eq(first_action_types, ["retreat", "retreat", "retreat"], "The regression setup should keep retreat as the first action HUD option"),
		assert_eq(pending_after_attempts, ["pokemon_action", "pokemon_action", "pokemon_action"], "Repeated Tool-attached touch openings should keep the action HUD open"),
		assert_eq(field_mode_after_attempts, ["", "", ""], "Repeated Tool-attached touch openings should not enter retreat target selection"),
		assert_true(active_slot.attached_tool == emergency_board, "The attached Tool should remain attached during the repeated touch-open regression"),
	])

	battle_scene.free()
	return result


func test_mouse_slot_release_opens_action_hud_without_sticky_field_state() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_click_position := Vector2(360, 720)

	var open_click := InputEventMouseButton.new()
	open_click.button_index = MOUSE_BUTTON_LEFT
	open_click.pressed = true
	open_click.position = original_click_position
	open_click.global_position = original_click_position
	battle_scene.call("_on_slot_input", open_click, "my_active")
	var pending_choice_after_press := str(battle_scene.get("_pending_choice"))
	var option_after_press := _first_action_hud_option(battle_scene)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = original_click_position
	release.global_position = original_click_position
	battle_scene.call("_on_slot_input", release, "my_active")
	var option_after_release := _first_action_hud_option(battle_scene)

	var result := run_checks([
		assert_eq(pending_choice_after_press, "", "Mouse slot press should not open the action HUD"),
		assert_true(option_after_press == null, "Mouse slot press should not render action HUD options"),
		assert_eq(str(battle_scene.get("_pending_choice")), "pokemon_action", "Mouse slot release should open the action HUD"),
		assert_true(option_after_release != null, "Mouse slot release should render action HUD options"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "Opening the action HUD should not leave sticky field selection state"),
	])

	battle_scene.free()
	return result


func test_pokemon_action_hud_blocks_underlying_slot_reopen_clicks() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var active_slot: PokemonSlot = gsm.game_state.players[0].active_pokemon
	battle_scene.call("_show_pokemon_action_dialog", 0, active_slot, true)

	var slot_click := InputEventMouseButton.new()
	slot_click.button_index = MOUSE_BUTTON_LEFT
	slot_click.pressed = true
	slot_click.position = Vector2(360, 720)
	slot_click.global_position = Vector2(360, 720)
	battle_scene.call("_on_slot_input", slot_click, "my_active")

	var result := run_checks([
		assert_eq(str(battle_scene.get("_pending_choice")), "pokemon_action", "The existing Pokemon action HUD should remain open"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "Underlying slot clicks while the action HUD is open should not start field selection"),
	])

	battle_scene.free()
	return result


func test_action_hud_option_mouse_press_activates_before_release() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_click_position := Vector2(360, 720)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)

	var option := _first_action_hud_option(battle_scene)
	var option_press := InputEventMouseButton.new()
	option_press.button_index = MOUSE_BUTTON_LEFT
	option_press.pressed = true
	option_press.position = Vector2(18, 18)
	option_press.global_position = Vector2(580, 260)
	if option != null:
		option.emit_signal("gui_input", option_press)
	var later_release := InputEventMouseButton.new()
	later_release.button_index = MOUSE_BUTTON_LEFT
	later_release.pressed = false
	later_release.position = Vector2(18, 18)
	later_release.global_position = Vector2(580, 260)
	if option != null:
		option.emit_signal("gui_input", later_release)

	var result := run_checks([
		assert_true(option != null, "Retreat-only action HUD should render the retreat option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "An option mouse press should activate retreat before release"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "An option mouse press should enter retreat target selection"),
	])

	battle_scene.free()
	return result


func test_action_hud_cancel_closes_release_opened_hud() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var original_click_position := Vector2(360, 720)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)
	var pending_before_cancel := str(battle_scene.get("_pending_choice"))
	var option_before_cancel := _first_action_hud_option(battle_scene)

	battle_scene.call("_on_dialog_cancel")

	var result := run_checks([
		assert_eq(pending_before_cancel, "pokemon_action", "The action HUD should be open before cancel"),
		assert_true(option_before_cancel != null, "The action HUD should render before cancel"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Cancel should close the Pokemon action HUD"),
	])

	battle_scene.free()
	return result


func test_action_hud_cancel_allows_immediate_slot_reopen() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))
	battle_scene.call("_on_dialog_cancel")
	var pending_after_first_cancel := str(battle_scene.get("_pending_choice"))
	var guard_after_first_cancel := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))
	var pending_after_same_slot_reopen := str(battle_scene.get("_pending_choice"))
	var same_slot_card_data: CardData = (battle_scene.get("_dialog_data") as Dictionary).get("pokemon_card_data", null)

	battle_scene.call("_on_dialog_cancel")
	_emit_slot_mouse_click(battle_scene, "my_bench_0", Vector2(520, 720))
	var pending_after_other_slot_reopen := str(battle_scene.get("_pending_choice"))
	var other_slot_card_data: CardData = (battle_scene.get("_dialog_data") as Dictionary).get("pokemon_card_data", null)

	var result := run_checks([
		assert_eq(pending_after_first_cancel, "", "Cancel should close the Pokemon action HUD"),
		assert_eq(guard_after_first_cancel, 0, "Canceling the Pokemon action HUD should not leave a timed slot-input guard"),
		assert_eq(pending_after_same_slot_reopen, "pokemon_action", "The same Pokemon should reopen immediately after cancel"),
		assert_true(same_slot_card_data != null and same_slot_card_data.name == "Portrait Tap Active", "The immediate same-slot tap should reopen the Active Pokemon HUD"),
		assert_eq(pending_after_other_slot_reopen, "pokemon_action", "A different Pokemon should reopen immediately after cancel"),
		assert_true(other_slot_card_data != null and other_slot_card_data.name == "Retreat Receiver", "The immediate other-slot tap should reopen the Bench Pokemon HUD"),
	])

	battle_scene.free()
	return result


func test_android_action_hud_cancel_owns_pointer_tail_and_next_bench_tap_opens_hud() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	battle_scene.call("_configure_battle_pointer_input_for_tests", true)
	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))
	var cancel_position := Vector2(520, 720)

	# Godot emits BaseButton.button_down from its internal _gui_input before the
	# external gui_input signal can record an origin. The scene-level observer must
	# already own the physical Android pointer when button_down closes the HUD.
	var cancel_touch_press := InputEventScreenTouch.new()
	cancel_touch_press.pressed = true
	cancel_touch_press.index = 0
	cancel_touch_press.position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", cancel_touch_press)
	battle_scene.call("_on_dialog_cancel_button_down")
	battle_scene.call("_on_slot_input", cancel_touch_press, "my_bench_0")

	var cancel_touch_release := InputEventScreenTouch.new()
	cancel_touch_release.pressed = false
	cancel_touch_release.index = 0
	cancel_touch_release.position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", cancel_touch_release)
	battle_scene.call("_on_dialog_cancel")
	battle_scene.call("_on_slot_input", cancel_touch_release, "my_bench_0")

	# Android may synthesize a MouseButton pair for the same touch after the modal
	# has disappeared. It belongs to the cancel sequence and must not hit the board.
	var echo_press := InputEventMouseButton.new()
	echo_press.button_index = MOUSE_BUTTON_LEFT
	echo_press.pressed = true
	echo_press.device = InputEvent.DEVICE_ID_EMULATION
	echo_press.position = cancel_position
	echo_press.global_position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", echo_press)
	battle_scene.call("_on_slot_input", echo_press, "my_bench_0")
	var echo_release := InputEventMouseButton.new()
	echo_release.button_index = MOUSE_BUTTON_LEFT
	echo_release.pressed = false
	echo_release.device = InputEvent.DEVICE_ID_EMULATION
	echo_release.position = cancel_position
	echo_release.global_position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", echo_release)
	battle_scene.call("_on_slot_input", echo_release, "my_bench_0")
	var pending_after_cancel_tail := str(battle_scene.get("_pending_choice"))

	# A new physical touch is a new sequence even at the exact same coordinate.
	# It must open the Bench Pokemon HUD immediately, with no time-window heuristic.
	var bench_press := InputEventScreenTouch.new()
	bench_press.pressed = true
	bench_press.index = 0
	bench_press.position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", bench_press)
	battle_scene.call("_on_slot_input", bench_press, "my_bench_0")
	var bench_release := InputEventScreenTouch.new()
	bench_release.pressed = false
	bench_release.index = 0
	bench_release.position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", bench_release)
	battle_scene.call("_on_slot_input", bench_release, "my_bench_0")
	var bench_card_data: CardData = (battle_scene.get("_dialog_data") as Dictionary).get("pokemon_card_data", null)

	var result := run_checks([
		assert_eq(pending_after_cancel_tail, "", "The cancel touch tail and its Android mouse echo must not open an underlying HUD"),
		assert_eq(str(battle_scene.get("_pending_choice")), "pokemon_action", "The next independent Bench touch must open the Pokemon action HUD"),
		assert_true(bench_card_data != null and bench_card_data.name == "Retreat Receiver", "The reopened HUD must belong to the tapped Bench Pokemon"),
	])

	battle_scene.free()
	return result


func test_android_action_hud_cancel_blocks_unlabelled_mouse_echo_over_active_slot() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	battle_scene.call("_configure_battle_pointer_input_for_tests", true)
	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))
	var cancel_position := Vector2(360, 720)

	var cancel_touch_press := InputEventScreenTouch.new()
	cancel_touch_press.pressed = true
	cancel_touch_press.index = 0
	cancel_touch_press.position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", cancel_touch_press)
	battle_scene.call("_on_dialog_cancel_button_down")

	var cancel_touch_release := InputEventScreenTouch.new()
	cancel_touch_release.pressed = false
	cancel_touch_release.index = 0
	cancel_touch_release.position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", cancel_touch_release)
	battle_scene.call("_on_dialog_cancel")
	battle_scene.call("_on_slot_input", cancel_touch_release, "my_active")

	# Some native Android paths deliver the compatibility mouse tail without
	# DEVICE_ID_EMULATION. It is still the same physical tap that cancelled the
	# HUD and must not be treated as a fresh board click.
	var echo_press := InputEventMouseButton.new()
	echo_press.button_index = MOUSE_BUTTON_LEFT
	echo_press.pressed = true
	echo_press.device = 0
	echo_press.position = cancel_position
	echo_press.global_position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", echo_press)
	battle_scene.call("_on_slot_input", echo_press, "my_active")
	var echo_release := InputEventMouseButton.new()
	echo_release.button_index = MOUSE_BUTTON_LEFT
	echo_release.pressed = false
	echo_release.device = 0
	echo_release.position = cancel_position
	echo_release.global_position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", echo_release)
	battle_scene.call("_on_slot_input", echo_release, "my_active")

	var result := run_checks([
		assert_eq(
			str(battle_scene.get("_pending_choice")),
			"",
			"Cancel's native Android compatibility-mouse tail must not reopen the underlying Active Pokemon HUD"
		),
	])

	battle_scene.free()
	return result


func test_modal_pointer_drain_shield_releases_for_next_independent_touch() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	battle_scene.call("_configure_battle_pointer_input_for_tests", true)
	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))
	var cancel_position := Vector2(360, 720)
	var cancel_press := InputEventScreenTouch.new()
	cancel_press.pressed = true
	cancel_press.index = 0
	cancel_press.position = cancel_position
	battle_scene.call("_observe_battle_pointer_event", cancel_press)
	battle_scene.call("_begin_modal_pointer_drain", "test_press_commit_control")
	var drain_shield := battle_scene.get("_modal_pointer_drain_shield") as Control
	var visible_after_commit := drain_shield != null and drain_shield.visible

	var cancel_release := InputEventScreenTouch.new()
	cancel_release.pressed = false
	cancel_release.index = 0
	cancel_release.position = cancel_position
	var release_observation: Dictionary = battle_scene.call(
		"_observe_battle_pointer_event",
		cancel_release
	)
	var release_consumed := bool(
		battle_scene.call(
			"_update_modal_pointer_drain",
			cancel_release,
			release_observation
		)
	)
	var visible_while_waiting_for_optional_echo := (
		drain_shield != null
		and drain_shield.visible
	)

	# A platform is allowed to omit the compatibility mouse echo. The very next
	# touch press is a new physical sequence and must remove the barrier
	# synchronously instead of waiting for a timeout.
	var next_press := InputEventScreenTouch.new()
	next_press.pressed = true
	next_press.index = 0
	next_press.position = Vector2(520, 720)
	var next_observation: Dictionary = battle_scene.call(
		"_observe_battle_pointer_event",
		next_press
	)
	var next_press_consumed := bool(
		battle_scene.call(
			"_update_modal_pointer_drain",
			next_press,
			next_observation
		)
	)

	var result := run_checks([
		assert_true(visible_after_commit, "Closing on touch-down should leave a full-screen drain shield"),
		assert_true(release_consumed, "The release from the closing gesture should remain owned by the modal"),
		assert_true(visible_while_waiting_for_optional_echo, "The drain shield should wait for a possible compatibility-mouse tail"),
		assert_false(next_press_consumed, "A new touch sequence must pass through immediately"),
		assert_true(drain_shield != null and not drain_shield.visible, "The new touch should synchronously remove the old drain shield"),
	])

	battle_scene.free()
	return result


func test_dialog_action_button_down_claims_sequence_and_release_commits() -> String:
	var source := FileAccess.get_file_as_string(
		"res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd"
	)
	var controller_source := FileAccess.get_file_as_string(
		"res://scripts/ui/battle/BattleDialogController.gd"
	)
	var runtime_source := FileAccess.get_file_as_string(
		"res://scenes/battle/BattleSceneRuntime.gd"
	)
	var confirm_start := source.find("func _on_dialog_confirm_input")
	var confirm_end := source.find("func _on_dialog_cancel_input", confirm_start)
	var cancel_start := confirm_end
	var cancel_end := source.find("func _on_dialog_confirm_button_down", cancel_start)
	var confirm_body := (
		source.substr(confirm_start, confirm_end - confirm_start)
		if confirm_start >= 0 and confirm_end > confirm_start
		else ""
	)
	var cancel_body := (
		source.substr(cancel_start, cancel_end - cancel_start)
		if cancel_start >= 0 and cancel_end > cancel_start
		else ""
	)
	var confirm_dispatch := confirm_body.find("_battle_dialog_controller.call")
	var cancel_dispatch := cancel_body.find("_battle_dialog_controller.call")
	var drain_end_start := runtime_source.find("func _end_modal_pointer_drain")
	var drain_end_end := runtime_source.find(
		"\n\nfunc _update_modal_pointer_drain",
		drain_end_start
	)
	var drain_end_body := (
		runtime_source.substr(drain_end_start, drain_end_end - drain_end_start)
		if drain_end_start >= 0 and drain_end_end > drain_end_start
		else ""
	)
	var pressed_confirm_start := source.find("func _on_dialog_confirm()")
	var pressed_confirm_end := source.find(
		"func _on_dialog_cancel()",
		pressed_confirm_start
	)
	var pressed_cancel_start := pressed_confirm_end
	var pressed_cancel_end := source.find(
		"func _on_dialog_confirm_input",
		pressed_cancel_start
	)
	var pressed_confirm_body := (
		source.substr(
			pressed_confirm_start,
			pressed_confirm_end - pressed_confirm_start
		)
		if pressed_confirm_start >= 0 and pressed_confirm_end > pressed_confirm_start
		else ""
	)
	var pressed_cancel_body := (
		source.substr(
			pressed_cancel_start,
			pressed_cancel_end - pressed_cancel_start
		)
		if pressed_cancel_start >= 0 and pressed_cancel_end > pressed_cancel_start
		else ""
	)
	var button_down_start := controller_source.find("func on_dialog_action_button_down")
	var button_down_end := controller_source.find(
		"func _has_fresh_dialog_action_input",
		button_down_start
	)
	var button_down_body := (
		controller_source.substr(button_down_start, button_down_end - button_down_start)
		if button_down_start >= 0 and button_down_end > button_down_start
		else ""
	)
	var confirm_down_start := source.find("func _on_dialog_confirm_button_down")
	var confirm_down_end := source.find(
		"func _on_dialog_cancel_button_down",
		confirm_down_start
	)
	var cancel_down_start := confirm_down_end
	var cancel_down_end := source.find(
		"func _confirm_assignment_dialog",
		cancel_down_start
	)
	var confirm_down_body := (
		source.substr(confirm_down_start, confirm_down_end - confirm_down_start)
		if confirm_down_start >= 0 and confirm_down_end > confirm_down_start
		else ""
	)
	var cancel_down_body := (
		source.substr(cancel_down_start, cancel_down_end - cancel_down_start)
		if cancel_down_start >= 0 and cancel_down_end > cancel_down_start
		else ""
	)

	return run_checks([
		assert_true(
			confirm_dispatch >= 0,
			"Confirm GUI input must register exact pointer ownership with the dialog controller"
		),
		assert_true(
			cancel_dispatch >= 0,
			"Cancel GUI input must register exact pointer ownership with the dialog controller"
		),
		assert_false(
			confirm_body.contains("accept_event()") or confirm_body.contains("set_input_as_handled()"),
			"Confirm gui_input must not preempt BaseButton's native button_down/pressed lifecycle"
		),
		assert_false(
			cancel_body.contains("accept_event()") or cancel_body.contains("set_input_as_handled()"),
			"Cancel gui_input must not preempt BaseButton's native button_down/pressed lifecycle"
		),
		assert_true(
			button_down_body.contains("_claim_current_modal_pointer_sequence"),
			"Button-down must assign exact sequence ownership before the modal can close"
		),
		assert_false(
			button_down_body.contains("_begin_modal_pointer_drain"),
			"Standard Buttons must not arm a full-screen drain shield that can outlive touch-only Android input"
		),
		assert_false(
			confirm_down_body.contains("_battle_dialog_controller.call(\"on_dialog_confirm\", self)"),
			"Confirm button-down must only claim the pointer sequence, not commit the action"
		),
		assert_false(
			cancel_down_body.contains("_battle_dialog_controller.call(\"on_dialog_cancel\", self)"),
			"Cancel button-down must only claim the pointer sequence, not close the overlay"
		),
		assert_false(
			drain_end_body.contains("_dialog_cancel_activated_on_button_down"),
			"Ending the pointer barrier must not cancel an already scheduled dialog action"
		),
		assert_false(
			drain_end_body.contains("_dialog_confirm_activated_on_button_down"),
			"Pointer lifecycle and dialog-action lifecycle must remain independent"
		),
		assert_true(
			pressed_confirm_body.contains("_dialog_confirm_activated_on_button_down = false"),
			"The release callback must consume the armed confirm action"
		),
		assert_true(
			pressed_cancel_body.contains("_dialog_cancel_activated_on_button_down = false"),
			"The release callback must consume the armed cancel action"
		),
		assert_true(
			pressed_confirm_body.contains("on_dialog_confirm"),
			"Confirm must commit through the standard Button pressed signal"
		),
		assert_true(
			pressed_cancel_body.contains("on_dialog_cancel"),
			"Cancel must commit through the standard Button pressed signal"
		),
	])


func test_tool_attached_active_repeated_mouse_opening_never_auto_enters_retreat() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot: PokemonSlot = player.active_pokemon
	var emergency_board := CardInstance.create(_make_trainer_cd("Emergency Board", "Tool", "Tool attached before opening the action HUD"), 0)
	active_slot.attached_tool = emergency_board

	var pending_after_attempts: Array[String] = []
	var field_mode_after_attempts: Array[String] = []
	var active_same_after_attempts: Array[bool] = []
	var tool_same_after_attempts: Array[bool] = []
	var first_action_types: Array[String] = []
	var option_available_after_attempts: Array[bool] = []

	for attempt: int in 3:
		battle_scene.set("_modal_input_slot_suppress_until_msec", Time.get_ticks_msec() - 1)
		battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 2000)

		_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360 + attempt * 8, 720 - attempt * 6))

		var option := _first_action_hud_option(battle_scene)
		option_available_after_attempts.append(option != null)
		var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
		first_action_types.append(str((actions[0] as Dictionary).get("type", "")) if not actions.is_empty() and actions[0] is Dictionary else "")

		pending_after_attempts.append(str(battle_scene.get("_pending_choice")))
		field_mode_after_attempts.append(str(battle_scene.get("_field_interaction_mode")))
		active_same_after_attempts.append(player.active_pokemon == active_slot)
		tool_same_after_attempts.append(active_slot.attached_tool == emergency_board)

		battle_scene.call("_on_dialog_cancel")

	var result := run_checks([
		assert_eq(option_available_after_attempts, [true, true, true], "Every repeated opening should render the action HUD option"),
		assert_eq(first_action_types, ["retreat", "retreat", "retreat"], "The regression setup should keep retreat as the first action HUD option"),
		assert_eq(pending_after_attempts, ["pokemon_action", "pokemon_action", "pokemon_action"], "Repeated openings on a Tool-attached Active should keep the action HUD open until the player chooses an option"),
		assert_eq(field_mode_after_attempts, ["", "", ""], "Repeated openings should not enter retreat field-target mode before an option is chosen"),
		assert_eq(active_same_after_attempts, [true, true, true], "The Active Pokemon should not retreat during repeated HUD openings"),
		assert_eq(tool_same_after_attempts, [true, true, true], "The attached Tool should remain attached while testing repeated HUD openings"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Canceling after each repeated opening should leave no sticky pending action"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "", "Canceling after each repeated opening should leave no sticky field interaction"),
	])

	battle_scene.free()
	return result


func test_portrait_koraidon_action_hud_local_mouse_option_click_activates() -> String:
	var battle_scene := _make_portrait_koraidon_action_hud_scene()
	var original_touch_position := Vector2(360, 720)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	var emulated_click := InputEventMouseButton.new()
	emulated_click.button_index = MOUSE_BUTTON_LEFT
	emulated_click.pressed = true
	emulated_click.position = Vector2(16, 16)
	emulated_click.global_position = Vector2(16, 16)
	if option != null:
		option.emit_signal("gui_input", emulated_click)

	var data: Dictionary = battle_scene.get("_dialog_data")
	var actions: Array = data.get("actions", [])
	var attack_count := 0
	var retreat_count := 0
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if str(action.get("type", "")) == "attack":
			attack_count += 1
		elif str(action.get("type", "")) == "retreat":
			retreat_count += 1
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var opponent_damage := gsm.game_state.players[1].active_pokemon.damage_counters

	var result := run_checks([
		assert_true(option != null, "Portrait Koraidon action HUD should render at least one option"),
		assert_eq(attack_count, 2, "Koraidon action HUD should list both printed attacks"),
		assert_eq(retreat_count, 1, "Koraidon action HUD should include retreat"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A real local-position MouseButton click should choose Koraidon's first attack"),
		assert_gt(opponent_damage, 0, "The real local-position click should execute Primitive Beatdown"),
	])

	battle_scene.free()
	return result


func test_portrait_touch_opened_action_hud_mouse_option_click_works_when_global_position_is_distinct() -> String:
	var battle_scene := _make_portrait_koraidon_action_hud_scene()
	var original_touch_position := Vector2(360, 720)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	_emit_action_hud_mouse_release(option, Vector2(16, 16), original_touch_position)
	var option_click := InputEventMouseButton.new()
	option_click.button_index = MOUSE_BUTTON_LEFT
	option_click.pressed = true
	option_click.position = Vector2(16, 16)
	option_click.global_position = Vector2(360, 160)
	_emit_action_hud_mouse_click(option, option_click.position, option_click.global_position)

	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var opponent_damage := gsm.game_state.players[1].active_pokemon.damage_counters

	var result := run_checks([
		assert_true(option != null, "Portrait Koraidon action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A real option click with reliable global coordinates should activate"),
		assert_gt(opponent_damage, 0, "The real option click should execute Koraidon's first attack instead of requiring retreat or a second action"),
	])

	battle_scene.free()
	return result


func test_android_landscape_rotated_portrait_action_hud_mouse_option_click_works_when_global_position_is_distinct() -> String:
	var battle_scene := _make_rotated_portrait_koraidon_action_hud_scene()
	var original_touch_position := Vector2(930, 520)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	_emit_action_hud_mouse_release(option, Vector2(18, 18), original_touch_position)
	var option_click := InputEventMouseButton.new()
	option_click.button_index = MOUSE_BUTTON_LEFT
	option_click.pressed = true
	option_click.position = Vector2(18, 18)
	option_click.global_position = Vector2(930, 220)
	_emit_action_hud_mouse_click(option, option_click.position, option_click.global_position)

	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var opponent_damage := gsm.game_state.players[1].active_pokemon.damage_counters

	var result := run_checks([
		assert_true(option != null, "Android landscape rotated-portrait Koraidon action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A reliable option click should activate the action HUD option"),
		assert_gt(opponent_damage, 0, "The reliable option click should execute Koraidon's first attack instead of requiring retreat or a second action"),
	])

	battle_scene.free()
	return result


func test_android_landscape_mouse_opened_action_hud_accepts_distinct_option_tap() -> String:
	var battle_scene := _make_koraidon_action_hud_scene("landscape")
	var original_click_position := Vector2(930, 520)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)

	var option := _first_action_hud_option(battle_scene)
	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var first_action_type := ""
	if not actions.is_empty() and actions[0] is Dictionary:
		first_action_type = str((actions[0] as Dictionary).get("type", ""))

	var option_click := InputEventMouseButton.new()
	option_click.button_index = MOUSE_BUTTON_LEFT
	option_click.pressed = true
	option_click.position = Vector2(18, 18)
	option_click.global_position = Vector2(580, 260)
	_emit_action_hud_mouse_click(option, option_click.position, option_click.global_position)

	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var opponent_damage := gsm.game_state.players[1].active_pokemon.damage_counters

	var result := run_checks([
		assert_true(option != null, "Android landscape Koraidon action HUD should render at least one option"),
		assert_eq(first_action_type, "attack", "The first Koraidon action HUD option should be an attack in this regression setup"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "The real option tap should activate the action HUD option instead of leaving the player stuck in pokemon_action"),
		assert_gt(opponent_damage, 0, "The real option tap should execute Koraidon's first attack instead of requiring another tap or retreat"),
	])

	battle_scene.free()
	return result


func test_android_landscape_rotated_portrait_lugia_vstar_action_hud_mouse_option_click_uses_summoning_star() -> String:
	var battle_scene := _make_lugia_vstar_action_hud_scene(true)
	var original_touch_position := Vector2(360, 720)
	var rotated_same_touch_global_position := Vector2(880, 360)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	var action_data_before_click: Dictionary = battle_scene.get("_dialog_data")
	var actions_before_click: Array = action_data_before_click.get("actions", [])
	var first_action_type := ""
	if not actions_before_click.is_empty() and actions_before_click[0] is Dictionary:
		first_action_type = str((actions_before_click[0] as Dictionary).get("type", ""))
	var same_open_click := InputEventMouseButton.new()
	same_open_click.button_index = MOUSE_BUTTON_LEFT
	same_open_click.pressed = true
	same_open_click.position = Vector2(20, 20)
	same_open_click.global_position = rotated_same_touch_global_position
	if option != null:
		option.emit_signal("gui_input", same_open_click)

	var result := run_checks([
		assert_true(option != null, "Lugia VSTAR action HUD should render at least one option"),
		assert_eq(first_action_type, "ability", "The first Lugia VSTAR action HUD option should be Summoning Star"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real MouseButton action HUD option click should choose Summoning Star"),
		assert_true(str(battle_scene.get("_pending_choice")) != "pokemon_action", "Choosing Summoning Star should leave the action HUD"),
	])

	battle_scene.free()
	return result


func test_lugia_vstar_action_hud_option_touch_activates_once() -> String:
	var battle_scene := _make_lugia_vstar_action_hud_scene(true)
	var original_touch_position := Vector2(360, 720)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	_emit_action_hud_touch_tap(option, 0, Vector2(20, 20))

	var result := run_checks([
		assert_true(option != null, "Lugia VSTAR action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real ScreenTouch option tap should choose Summoning Star"),
		assert_true(str(battle_scene.get("_pending_choice")) != "pokemon_action", "Choosing Summoning Star should leave the action HUD"),
	])

	battle_scene.free()
	return result


func test_android_mouse_opened_lugia_vstar_action_hud_local_click_uses_summoning_star() -> String:
	var battle_scene := _make_lugia_vstar_action_hud_scene(false)
	var original_click_position := Vector2(360, 720)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)

	var option := _first_action_hud_option(battle_scene)
	var action_data_before_echo: Dictionary = battle_scene.get("_dialog_data")
	var actions_before_echo: Array = action_data_before_echo.get("actions", [])
	var first_action_type := ""
	if not actions_before_echo.is_empty() and actions_before_echo[0] is Dictionary:
		first_action_type = str((actions_before_echo[0] as Dictionary).get("type", ""))

	var local_mouse_echo := InputEventMouseButton.new()
	local_mouse_echo.button_index = MOUSE_BUTTON_LEFT
	local_mouse_echo.pressed = true
	local_mouse_echo.position = Vector2(20, 20)
	local_mouse_echo.global_position = Vector2(20, 20)
	if option != null:
		option.emit_signal("gui_input", local_mouse_echo)

	var result := run_checks([
		assert_true(option != null, "Lugia VSTAR action HUD should render at least one option after a mouse-style Android tap"),
		assert_eq(first_action_type, "ability", "The first Lugia VSTAR action HUD option should be Summoning Star"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real local-coordinate MouseButton click should choose Summoning Star"),
		assert_true(str(battle_scene.get("_pending_choice")) != "pokemon_action", "Choosing Summoning Star should leave the action HUD"),
	])

	battle_scene.free()
	return result


func test_android_mouse_opened_lugia_vstar_delayed_local_click_uses_summoning_star() -> String:
	var battle_scene := _make_lugia_vstar_action_hud_scene(false)
	var original_click_position := Vector2(360, 720)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)

	var option := _first_action_hud_option(battle_scene)
	var action_data_before_echo: Dictionary = battle_scene.get("_dialog_data")
	var actions_before_echo: Array = action_data_before_echo.get("actions", [])
	var first_action_type := ""
	if not actions_before_echo.is_empty() and actions_before_echo[0] is Dictionary:
		first_action_type = str((actions_before_echo[0] as Dictionary).get("type", ""))

	var delayed_local_mouse_echo := InputEventMouseButton.new()
	delayed_local_mouse_echo.button_index = MOUSE_BUTTON_LEFT
	delayed_local_mouse_echo.pressed = true
	delayed_local_mouse_echo.position = Vector2(20, 20)
	delayed_local_mouse_echo.global_position = Vector2(20, 20)
	if option != null:
		option.emit_signal("gui_input", delayed_local_mouse_echo)

	var result := run_checks([
		assert_true(option != null, "Lugia VSTAR action HUD should render at least one option after a mouse-style Android tap"),
		assert_eq(first_action_type, "ability", "The first Lugia VSTAR action HUD option should be Summoning Star"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real local-coordinate MouseButton click should choose Summoning Star"),
		assert_true(str(battle_scene.get("_pending_choice")) != "pokemon_action", "Choosing Summoning Star should leave the action HUD"),
	])

	battle_scene.free()
	return result


func test_android_mouse_opened_lugia_vstar_delayed_lower_local_click_uses_summoning_star() -> String:
	var battle_scene := _make_lugia_vstar_action_hud_scene(false)
	var original_click_position := Vector2(360, 720)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)

	var option := _first_action_hud_option(battle_scene)
	var action_data_before_echo: Dictionary = battle_scene.get("_dialog_data")
	var actions_before_echo: Array = action_data_before_echo.get("actions", [])
	var first_action_type := ""
	if not actions_before_echo.is_empty() and actions_before_echo[0] is Dictionary:
		first_action_type = str((actions_before_echo[0] as Dictionary).get("type", ""))

	var delayed_lower_local_mouse_echo := InputEventMouseButton.new()
	delayed_lower_local_mouse_echo.button_index = MOUSE_BUTTON_LEFT
	delayed_lower_local_mouse_echo.pressed = true
	delayed_lower_local_mouse_echo.position = Vector2(32, 220)
	delayed_lower_local_mouse_echo.global_position = Vector2(32, 220)
	if option != null:
		option.emit_signal("gui_input", delayed_lower_local_mouse_echo)

	var result := run_checks([
		assert_true(option != null, "Lugia VSTAR action HUD should render at least one option after a mouse-style Android tap"),
		assert_eq(first_action_type, "ability", "The first Lugia VSTAR action HUD option should be Summoning Star"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real lower local-coordinate MouseButton click should choose Summoning Star"),
		assert_true(str(battle_scene.get("_pending_choice")) != "pokemon_action", "Choosing Summoning Star should leave the action HUD"),
	])

	battle_scene.free()
	return result


func test_landscape_charmander_tm_evolution_after_attach_release_open_shows_action_hud_without_auto_starting_evolution() -> String:
	var battle_scene := _make_landscape_charmander_tm_evolution_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot: PokemonSlot = player.active_pokemon
	var fire_energy: CardInstance = player.hand[0]
	var tm_evolution: CardInstance = player.hand[1]

	battle_scene.set("_selected_hand_card", fire_energy)
	battle_scene.call("_handle_slot_left_click", "my_active")
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)
	battle_scene.set("_selected_hand_card", tm_evolution)
	battle_scene.call("_handle_slot_left_click", "my_active")
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 520))

	var option := _first_action_hud_option(battle_scene)
	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var first_action_type := ""
	if not actions.is_empty() and actions[0] is Dictionary:
		first_action_type = str((actions[0] as Dictionary).get("type", ""))

	var result := run_checks([
		assert_eq(active_slot.attached_energy.size(), 1, "Charmander should have one Fire Energy before opening the action HUD"),
		assert_true(active_slot.attached_tool == tm_evolution, "Charmander should have TM Evolution attached before opening the action HUD"),
		assert_true(option != null, "Charmander action HUD should render the TM Evolution action option"),
		assert_eq(first_action_type, "granted_attack", "TM Evolution should be the first available action in this regression setup"),
		assert_eq(str(battle_scene.get("_pending_choice")), "pokemon_action", "Opening the Charmander slot should stop at the action HUD"),
		assert_false(bool(battle_scene.get("_dialog_card_mode")), "Opening the Charmander slot should not jump into TM Evolution's deck search"),
		assert_false(bool(battle_scene.get("_dialog_assignment_mode")), "Opening the Charmander slot should not jump into TM Evolution's target flow"),
	])

	battle_scene.free()
	return result


func test_landscape_charmander_tm_evolution_after_attach_local_click_starts_evolution() -> String:
	var battle_scene := _make_landscape_charmander_tm_evolution_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot: PokemonSlot = player.active_pokemon
	var fire_energy: CardInstance = player.hand[0]
	var tm_evolution: CardInstance = player.hand[1]

	battle_scene.set("_selected_hand_card", fire_energy)
	battle_scene.call("_handle_slot_left_click", "my_active")
	var attached_energy_count := active_slot.attached_energy.size()
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)

	battle_scene.set("_selected_hand_card", tm_evolution)
	battle_scene.call("_handle_slot_left_click", "my_active")
	var attached_tool: CardInstance = active_slot.attached_tool
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 520))

	var option := _first_action_hud_option(battle_scene)
	var action_data_before_echo: Dictionary = battle_scene.get("_dialog_data")
	var actions_before_echo: Array = action_data_before_echo.get("actions", [])
	var first_action_type := ""
	if not actions_before_echo.is_empty() and actions_before_echo[0] is Dictionary:
		first_action_type = str((actions_before_echo[0] as Dictionary).get("type", ""))

	var local_mouse_echo := InputEventMouseButton.new()
	local_mouse_echo.button_index = MOUSE_BUTTON_LEFT
	local_mouse_echo.pressed = true
	local_mouse_echo.position = Vector2(20, 20)
	local_mouse_echo.global_position = Vector2(20, 20)
	if option != null:
		option.emit_signal("gui_input", local_mouse_echo)
	var field_mode := str(battle_scene.get("_field_interaction_mode"))
	var field_position := str(battle_scene.get("_field_interaction_position"))
	var field_data: Dictionary = battle_scene.get("_field_interaction_data")

	var result := run_checks([
		assert_eq(attached_energy_count, 1, "Charmander should have the manually attached Fire Energy before opening the action HUD"),
		assert_true(attached_tool == tm_evolution, "Charmander should have TM Evolution attached before opening the action HUD"),
		assert_true(option != null, "Landscape Charmander action HUD should render at least one option after Fire Energy and TM Evolution are attached"),
		assert_eq(first_action_type, "granted_attack", "TM Evolution should be the first available action in this regression setup"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real local MouseButton click should choose TM Evolution"),
		assert_false(bool(battle_scene.get("_dialog_card_mode")), "TM Evolution should not enter deck search before choosing a bench target"),
		assert_eq(field_mode, "slot_select", "The UI should enter TM Evolution's bench target selection after choosing it"),
		assert_eq(field_position, "top", "TM Evolution should show own bench target selection above the field"),
		assert_eq(int((field_data.get("items", []) as Array).size()), 1, "TM Evolution should expose the single evolvable Bench target"),
	])

	battle_scene.free()
	return result


func test_landscape_charmander_tm_evolution_delayed_local_click_starts_evolution() -> String:
	var battle_scene := _make_landscape_charmander_tm_evolution_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot: PokemonSlot = player.active_pokemon
	var fire_energy: CardInstance = player.hand[0]
	var tm_evolution: CardInstance = player.hand[1]

	battle_scene.set("_selected_hand_card", fire_energy)
	battle_scene.call("_handle_slot_left_click", "my_active")
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)
	battle_scene.set("_selected_hand_card", tm_evolution)
	battle_scene.call("_handle_slot_left_click", "my_active")
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 520))

	var option := _first_action_hud_option(battle_scene)
	var actions_before_tail: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var first_action_type := ""
	if not actions_before_tail.is_empty() and actions_before_tail[0] is Dictionary:
		first_action_type = str((actions_before_tail[0] as Dictionary).get("type", ""))
	_emit_action_hud_mouse_click(option, Vector2(20, 20), Vector2(20, 20))
	var field_mode := str(battle_scene.get("_field_interaction_mode"))
	var field_position := str(battle_scene.get("_field_interaction_position"))

	var result := run_checks([
		assert_eq(active_slot.attached_energy.size(), 1, "Charmander should have one Fire Energy before opening the action HUD"),
		assert_true(active_slot.attached_tool == tm_evolution, "Charmander should have TM Evolution attached before opening the action HUD"),
		assert_true(option != null, "Charmander action HUD should render the TM Evolution action option"),
		assert_eq(first_action_type, "granted_attack", "TM Evolution should be the first available action in this regression setup"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real local MouseButton click should choose TM Evolution"),
		assert_false(bool(battle_scene.get("_dialog_card_mode")), "TM Evolution should not enter deck search before choosing a bench target"),
		assert_eq(field_mode, "slot_select", "The UI should enter TM Evolution's bench target selection after choosing it"),
		assert_eq(field_position, "top", "TM Evolution should show own bench target selection above the field"),
	])

	battle_scene.free()
	return result


func test_landscape_charmander_tm_evolution_two_bench_reliable_mouse_click_starts_evolution() -> String:
	var battle_scene := _make_landscape_charmander_tm_evolution_action_hud_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot: PokemonSlot = player.active_pokemon
	var fire_energy: CardInstance = player.hand[0]
	var tm_evolution: CardInstance = player.hand[1]

	var bench_charmander_cd := _make_pokemon_cd("Charmander", 70, "R")
	bench_charmander_cd.attacks = []
	bench_charmander_cd.abilities = []
	var bench_charmander := PokemonSlot.new()
	bench_charmander.pokemon_stack.append(CardInstance.create(bench_charmander_cd, 0))
	var bench_pidgey_cd := _make_pokemon_cd("Pidgey", 60, "C")
	bench_pidgey_cd.attacks = []
	bench_pidgey_cd.abilities = []
	var bench_pidgey := PokemonSlot.new()
	bench_pidgey.pokemon_stack.append(CardInstance.create(bench_pidgey_cd, 0))
	player.bench = [bench_charmander, bench_pidgey]

	var charmeleon_cd := _make_pokemon_cd("Charmeleon", 100, "R")
	charmeleon_cd.stage = "Stage 1"
	charmeleon_cd.evolves_from = "Charmander"
	var pidgeotto_cd := _make_pokemon_cd("Pidgeotto", 80, "C")
	pidgeotto_cd.stage = "Stage 1"
	pidgeotto_cd.evolves_from = "Pidgey"
	player.deck = [CardInstance.create(charmeleon_cd, 0), CardInstance.create(pidgeotto_cd, 0)]

	battle_scene.set("_selected_hand_card", fire_energy)
	battle_scene.call("_handle_slot_left_click", "my_active")
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)
	battle_scene.set("_selected_hand_card", tm_evolution)
	battle_scene.call("_handle_slot_left_click", "my_active")
	battle_scene.set("_suppress_slot_followup_click_until_msec", Time.get_ticks_msec() - 1)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 520))

	var option := _first_action_hud_option(battle_scene)
	var actions_before_echo: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var first_action_type := ""
	if not actions_before_echo.is_empty() and actions_before_echo[0] is Dictionary:
		first_action_type = str((actions_before_echo[0] as Dictionary).get("type", ""))

	var reliable_mouse_echo := InputEventMouseButton.new()
	reliable_mouse_echo.button_index = MOUSE_BUTTON_LEFT
	reliable_mouse_echo.pressed = true
	reliable_mouse_echo.position = Vector2(18, 18)
	reliable_mouse_echo.global_position = Vector2(580, 260)
	if option != null:
		option.emit_signal("gui_input", reliable_mouse_echo)
	var field_mode := str(battle_scene.get("_field_interaction_mode"))
	var field_position := str(battle_scene.get("_field_interaction_position"))
	var field_data: Dictionary = battle_scene.get("_field_interaction_data")

	var result := run_checks([
		assert_eq(active_slot.attached_energy.size(), 1, "Charmander should have one Fire Energy before opening the action HUD"),
		assert_true(active_slot.attached_tool == tm_evolution, "Charmander should have TM Evolution attached before opening the action HUD"),
		assert_eq(player.bench.size(), 2, "The regression setup should keep Charmander and Pidgey on the Bench"),
		assert_true(option != null, "Charmander action HUD should render the TM Evolution action option"),
		assert_eq(first_action_type, "granted_attack", "TM Evolution should be the first available action in this regression setup"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A real MouseButton click should choose TM Evolution"),
		assert_false(bool(battle_scene.get("_dialog_card_mode")), "TM Evolution should not enter deck search before choosing bench targets"),
		assert_eq(field_mode, "slot_select", "The UI should enter TM Evolution's bench target selection after choosing it"),
		assert_eq(field_position, "top", "TM Evolution should show own bench target selection above the field"),
		assert_eq(int((field_data.get("items", []) as Array).size()), 2, "TM Evolution should expose both evolvable Bench targets"),
	])

	battle_scene.free()
	return result


func test_android_lugia_vstar_knockout_prize_accepts_screen_touch() -> String:
	var battle_scene := _make_lugia_vstar_action_hud_scene(false)
	var gsm: GameStateMachine = battle_scene.get("_gsm")
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
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Lugia Prize %d" % i, 60, "C"), 0))
	var defender := gsm.game_state.players[1].active_pokemon
	if defender != null:
		defender.damage_counters = 80

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))

	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var attack_action_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "attack":
			attack_action_index = i
			break
	var attack_option := _action_hud_option_at_index(battle_scene, attack_action_index)
	var attack_click := InputEventMouseButton.new()
	attack_click.button_index = MOUSE_BUTTON_LEFT
	attack_click.pressed = true
	attack_click.position = Vector2(18, 18)
	attack_click.global_position = Vector2(360, 180)
	_emit_action_hud_mouse_click(attack_option, attack_click.position, attack_click.global_position)

	var pending_after_attack := str(battle_scene.get("_pending_choice"))
	var dialog_visible_after_attack := bool((battle_scene.get("_dialog_overlay") as Panel).visible)
	var prize_slot_filter_after_attack := my_prize_slots[0].mouse_filter
	var hand_before_prize := gsm.game_state.players[0].hand.size()
	var prize_press := InputEventScreenTouch.new()
	prize_press.pressed = true
	prize_press.index = 0
	prize_press.position = Vector2(24, 24)
	battle_scene.call("_on_prize_slot_input", prize_press, 0, "Prize", 0)
	var prize_release := InputEventScreenTouch.new()
	prize_release.pressed = false
	prize_release.index = 0
	prize_release.position = Vector2(24, 24)
	battle_scene.call("_on_prize_slot_input", prize_release, 0, "Prize", 0)
	var hand_after_prize := gsm.game_state.players[0].hand.size()

	var result := run_checks([
		assert_true(attack_action_index >= 0, "Lugia VSTAR action HUD should expose Tempest Dive as an attack option"),
		assert_true(attack_option != null, "The attack option should render in the action HUD"),
		assert_eq(pending_after_attack, "take_prize", "Lugia VSTAR knockout should enter prize selection after Tempest Dive"),
		assert_false(dialog_visible_after_attack, "The action HUD overlay should be closed while choosing Prize cards"),
		assert_eq(prize_slot_filter_after_attack, Control.MOUSE_FILTER_STOP, "A selectable Prize card view must keep receiving pointer input after UI refresh"),
		assert_eq(hand_after_prize, hand_before_prize + 1, "An Android ScreenTouch on a selectable Prize card should take that Prize"),
		assert_true(str(battle_scene.get("_pending_choice")) != "take_prize", "After taking the only pending Prize, the flow should leave Prize selection"),
	])

	battle_scene.free()
	return result


func test_android_portrait_lugia_vstar_knockout_opens_prize_dialog() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var battle_scene := _make_real_portrait_lugia_vstar_knockout_scene()
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(180, 640))

	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var attack_action_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "attack":
			attack_action_index = i
			break
	var attack_option := _action_hud_option_at_index(battle_scene, attack_action_index)
	_emit_action_hud_mouse_click(attack_option, Vector2(18, 18), Vector2(180, 220))
	battle_scene.call("_apply_portrait_layout", Vector2(390, 844))
	battle_scene.call("_refresh_ui")
	battle_scene.call("_deferred_finalize_portrait_layout_constraints")

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Panel
	var dialog_vbox := battle_scene.get("_dialog_vbox") as VBoxContainer
	var dialog_confirm := battle_scene.get("_dialog_confirm") as Button
	var buttons_row := dialog_confirm.get_parent() as Control if dialog_confirm != null else null
	var my_host := battle_scene.get("_my_prize_hud_host") as VBoxContainer
	var my_slots: Array[BattleCardView] = battle_scene.get("_my_prize_slots")
	var first_prize_slot := my_slots[0] if not my_slots.is_empty() else null
	var pending_after_attack := str(battle_scene.get("_pending_choice"))
	var resolved_mode := str(battle_scene.call("_current_resolved_battle_layout_mode"))
	var dialog_visible_after_attack := dialog_overlay != null and dialog_overlay.visible
	var host_in_dialog_after_attack := my_host != null and dialog_vbox != null and my_host.get_parent() == dialog_vbox
	var buttons_hidden_after_attack := buttons_row != null and not buttons_row.visible
	var first_prize_clickable := first_prize_slot != null and first_prize_slot.mouse_filter == Control.MOUSE_FILTER_STOP

	var result := run_checks([
		assert_true(attack_action_index >= 0, "The action HUD should expose Tempest Dive before the regression attack"),
		assert_true(attack_option != null, "The Tempest Dive option should render in the action HUD"),
		assert_eq(pending_after_attack, "take_prize", "Lugia VSTAR knockout should enter prize selection"),
		assert_eq(resolved_mode, "portrait", "The Android portrait regression must run with portrait layout resolved"),
		assert_true(dialog_visible_after_attack, "A human-owned portrait Prize prompt should open the centered Prize dialog"),
		assert_true(host_in_dialog_after_attack, "The selectable Prize host should be moved into the dialog after the knockout"),
		assert_true(buttons_hidden_after_attack, "The Prize dialog should hide generic cancel/confirm buttons"),
		assert_true(first_prize_clickable, "The visible Prize slot in the dialog should remain clickable"),
	])

	battle_scene.free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_android_active_portrait_lugia_vstar_knockout_opens_prize_dialog_when_layout_auto() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_AUTO
	var battle_scene := _make_real_portrait_lugia_vstar_knockout_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_rotated_portrait_canvas_active", true)
	battle_scene.set("_rotated_portrait_physical_viewport_size", Vector2(1600, 900))
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	gsm.state_changed.connect(battle_scene._on_state_changed)
	gsm.player_choice_required.connect(battle_scene._on_player_choice_required)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	_emit_slot_mouse_click(battle_scene, "my_active", Vector2(180, 640))

	var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
	var attack_action_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "attack":
			attack_action_index = i
			break
	var attack_option := _action_hud_option_at_index(battle_scene, attack_action_index)
	_emit_action_hud_mouse_click(attack_option, Vector2(18, 18), Vector2(180, 220))
	battle_scene.call("_apply_portrait_layout", Vector2(900, 1600))
	battle_scene.call("_refresh_ui")
	battle_scene.call("_deferred_finalize_portrait_layout_constraints")

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Panel
	var dialog_vbox := battle_scene.get("_dialog_vbox") as VBoxContainer
	var my_host := battle_scene.get("_my_prize_hud_host") as VBoxContainer
	var pending_after_attack := str(battle_scene.get("_pending_choice"))
	var active_portrait := bool(battle_scene.call("_is_portrait_battle_layout_active"))
	var resolved_mode := str(battle_scene.call("_current_resolved_battle_layout_mode"))
	var dialog_visible_after_attack := dialog_overlay != null and dialog_overlay.visible
	var host_in_dialog_after_attack := my_host != null and dialog_vbox != null and my_host.get_parent() == dialog_vbox

	var result := run_checks([
		assert_true(attack_action_index >= 0, "The action HUD should expose Tempest Dive before the auto-layout regression attack"),
		assert_true(attack_option != null, "The Tempest Dive option should render before the auto-layout regression attack"),
		assert_eq(pending_after_attack, "take_prize", "Lugia VSTAR knockout should still enter prize selection in active portrait layout"),
		assert_true(active_portrait, "The regression scene should be treated as active portrait layout"),
		assert_true(dialog_visible_after_attack, "A human-owned Prize prompt should open while the battle is already in active portrait layout, even if current resolver reports %s" % resolved_mode),
		assert_true(host_in_dialog_after_attack, "The selectable Prize host should move into the dialog while active portrait layout is in use"),
	])

	battle_scene.free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_portrait_prize_dialog_ignores_stale_cached_dialog_vbox() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_view_player", 0)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	var live_dialog_vbox := battle_scene.find_child("DialogVBox", true, false) as VBoxContainer
	var stale_dialog_vbox := VBoxContainer.new()
	stale_dialog_vbox.name = "StaleDialogVBox"
	battle_scene.set("_dialog_vbox", stale_dialog_vbox)
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_my_prizes_title", battle_scene.find_child("MyPrizesLbl", true, false))
	battle_scene.set("_opp_prizes_title", battle_scene.find_child("OppPrizesLbl", true, false))
	battle_scene.set("_my_prize_hud_title", battle_scene.find_child("MyHudLeftTitle", true, false))
	battle_scene.set("_opp_prize_hud_title", battle_scene.find_child("OppHudLeftTitle", true, false))
	battle_scene.set("_my_hud_left", battle_scene.find_child("MyHudLeft", true, false))
	battle_scene.set("_opp_hud_left", battle_scene.find_child("OppHudLeft", true, false))
	battle_scene.set("_my_prize_hud_host", battle_scene.find_child("MyPrizeHudHost", true, false))
	battle_scene.set("_opp_prize_hud_host", battle_scene.find_child("OppPrizeHudHost", true, false))
	battle_scene.set("_my_deck_hud_box", battle_scene.find_child("MyDeckHudBox", true, false))
	battle_scene.set("_opp_deck_hud_box", battle_scene.find_child("OppDeckHudBox", true, false))
	battle_scene.set("_my_discard_hud_box", battle_scene.find_child("MyDiscardHudBox", true, false))
	battle_scene.set("_opp_discard_hud_box", battle_scene.find_child("OppDiscardHudBox", true, false))

	battle_scene.call("_setup_side_previews")
	battle_scene.call("_setup_prize_viewer")

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Stale VBox Prize", 60, "C"), 0))
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	battle_scene.set("_gsm", gsm)

	var my_slots: Array[BattleCardView] = battle_scene.get("_my_prize_slots")
	battle_scene.set("_pending_choice", "take_prize")
	battle_scene.set("_pending_prize_player_index", 0)
	battle_scene.set("_pending_prize_remaining", 1)
	battle_scene.call("_update_prize_slots", my_slots, gsm.game_state.players[0].get_prize_layout(), true)
	battle_scene.call("_show_portrait_prize_dialog_if_needed")

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Panel
	var my_host := battle_scene.get("_my_prize_hud_host") as VBoxContainer
	var dialog_visible := dialog_overlay != null and dialog_overlay.visible
	var host_in_live_dialog := my_host != null and live_dialog_vbox != null and my_host.get_parent() == live_dialog_vbox
	var host_not_moved_to_stale_dialog := my_host != null and my_host.get_parent() != stale_dialog_vbox
	var prize_slot := my_slots[0] if not my_slots.is_empty() else null
	var prize_slot_clickable := prize_slot != null and prize_slot.mouse_filter == Control.MOUSE_FILTER_STOP

	var result := run_checks([
		assert_true(live_dialog_vbox != null, "The real battle scene should expose the live portrait dialog VBox"),
		assert_true(dialog_visible, "A human portrait Prize prompt should still open when the cached VBox reference is stale"),
		assert_true(host_in_live_dialog, "The Prize host must be moved into the live dialog VBox, not an old cached container"),
		assert_true(host_not_moved_to_stale_dialog, "The Prize host should never be reparented into a detached stale dialog VBox"),
		assert_true(prize_slot_clickable, "The visible Prize slot should remain clickable after recovering from a stale dialog VBox"),
	])

	battle_scene.free()
	stale_dialog_vbox.free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_android_lugia_vstar_knockout_prize_card_view_input_takes_prize_after_refresh() -> String:
	for input_mode: String in ["touch", "mouse"]:
		var battle_scene := _make_lugia_vstar_action_hud_scene(false)
		var gsm: GameStateMachine = battle_scene.get("_gsm")
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
		battle_scene.call("_setup_prize_viewer")
		for i: int in 6:
			gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Lugia CardView Prize %d" % i, 60, "C"), 0))
		var defender := gsm.game_state.players[1].active_pokemon
		if defender != null:
			defender.damage_counters = 80

		_emit_slot_mouse_click(battle_scene, "my_active", Vector2(360, 720))

		var actions: Array = (battle_scene.get("_dialog_data") as Dictionary).get("actions", [])
		var attack_action_index := -1
		for i: int in actions.size():
			if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "attack":
				attack_action_index = i
				break
		var attack_option := _action_hud_option_at_index(battle_scene, attack_action_index)
		var attack_click := InputEventMouseButton.new()
		attack_click.button_index = MOUSE_BUTTON_LEFT
		attack_click.pressed = true
		attack_click.position = Vector2(18, 18)
		attack_click.global_position = Vector2(360, 180)
		_emit_action_hud_mouse_click(attack_option, attack_click.position, attack_click.global_position)

		var pending_after_attack := str(battle_scene.get("_pending_choice"))
		var pending_prize_player := int(battle_scene.get("_pending_prize_player_index"))
		var prize_slot := my_prize_slots[0] if not my_prize_slots.is_empty() else null
		var left_connection_count := prize_slot.left_clicked.get_connections().size() if prize_slot != null else -1
		var gui_connection_count := prize_slot.gui_input.get_connections().size() if prize_slot != null else -1
		var hand_before_prize := gsm.game_state.players[0].hand.size()
		if prize_slot != null:
			_send_prize_card_view_input(prize_slot, input_mode)
		var hand_after_prize := gsm.game_state.players[0].hand.size()
		var pending_after_prize := str(battle_scene.get("_pending_choice"))
		var prize_count_after_prize := gsm.game_state.players[0].prizes.size()

		var result := run_checks([
			assert_true(attack_action_index >= 0, "Lugia VSTAR action HUD should expose Tempest Dive as an attack option (%s)" % input_mode),
			assert_true(attack_option != null, "The attack option should render in the action HUD (%s)" % input_mode),
			assert_eq(pending_after_attack, "take_prize", "A knockout should enter prize selection before the prize card is tapped (%s)" % input_mode),
			assert_eq(pending_prize_player, 0, "The human player should own the prize prompt after knocking out the AI Active (%s)" % input_mode),
			assert_true(prize_slot != null, "The refreshed prize area should expose the selectable BattleCardView (%s)" % input_mode),
			assert_gt(left_connection_count, 0, "The refreshed prize card view should keep its left-click connection after knockout UI refresh (%s)" % input_mode),
			assert_gt(gui_connection_count, 0, "The refreshed prize card view should keep its gui_input connection after knockout UI refresh (%s)" % input_mode),
			assert_eq(hand_after_prize, hand_before_prize + 1, "Tapping the refreshed prize BattleCardView should take the prize after knockout (%s)" % input_mode),
			assert_eq(prize_count_after_prize, 5, "Taking the refreshed prize BattleCardView should remove one prize card (%s)" % input_mode),
			assert_false(pending_after_prize == "take_prize", "After taking the only pending prize, prize selection should clear (%s)" % input_mode),
		])
		battle_scene.free()
		if result != "":
			return result
	return ""


func test_selectable_prize_slots_restore_card_view_clickability_after_initial_disabled_build() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_view_player", 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Initially Disabled Prize", 60, "C"), 0))
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		var my_slot := BattleCardView.new()
		my_slot.set_clickable(false)
		my_slot.setup_from_instance(null, BattleCardView.MODE_PREVIEW)
		var opp_slot := BattleCardView.new()
		opp_slot.set_clickable(false)
		opp_slot.setup_from_instance(null, BattleCardView.MODE_PREVIEW)
		my_prize_slots.append(my_slot)
		opp_prize_slots.append(opp_slot)
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)
	battle_scene.call("_setup_prize_viewer")
	battle_scene.set("_pending_choice", "take_prize")
	battle_scene.set("_pending_prize_player_index", 0)
	battle_scene.set("_pending_prize_remaining", 1)
	battle_scene.call("_update_prize_slots", my_prize_slots, gsm.game_state.players[0].get_prize_layout(), true)

	var prize_slot := my_prize_slots[0]
	var mouse_filter_after_update := prize_slot.mouse_filter
	var clickability_after_update := bool(prize_slot.get("_clickable"))
	var left_connection_count := prize_slot.left_clicked.get_connections().size()
	var hand_before := gsm.game_state.players[0].hand.size()
	_send_prize_card_view_input(prize_slot, "touch")
	var hand_after := gsm.game_state.players[0].hand.size()
	var pending_after := str(battle_scene.get("_pending_choice"))

	battle_scene.free()
	return run_checks([
		assert_eq(mouse_filter_after_update, Control.MOUSE_FILTER_STOP, "A selectable prize slot should accept GUI input at the Control level"),
		assert_true(clickability_after_update, "A selectable prize slot built disabled should restore BattleCardView clickability, not only mouse_filter"),
		assert_gt(left_connection_count, 0, "The selectable prize slot should keep its left-click prize-taking connection"),
		assert_eq(hand_after, hand_before + 1, "A selectable prize slot built disabled should take the prize through its card-view click path"),
		assert_false(pending_after == "take_prize", "After taking the only pending prize, prize selection should clear"),
	])


func test_portrait_prize_dialog_slot_gui_input_takes_prize_on_android_touch() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_view_player", 0)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_my_prizes_title", battle_scene.find_child("MyPrizesLbl", true, false))
	battle_scene.set("_opp_prizes_title", battle_scene.find_child("OppPrizesLbl", true, false))
	battle_scene.set("_my_prize_hud_title", battle_scene.find_child("MyHudLeftTitle", true, false))
	battle_scene.set("_opp_prize_hud_title", battle_scene.find_child("OppHudLeftTitle", true, false))
	battle_scene.set("_my_hud_left", battle_scene.find_child("MyHudLeft", true, false))
	battle_scene.set("_opp_hud_left", battle_scene.find_child("OppHudLeft", true, false))
	battle_scene.set("_my_prize_hud_host", battle_scene.find_child("MyPrizeHudHost", true, false))
	battle_scene.set("_opp_prize_hud_host", battle_scene.find_child("OppPrizeHudHost", true, false))
	battle_scene.set("_my_deck_hud_box", battle_scene.find_child("MyDeckHudBox", true, false))
	battle_scene.set("_opp_deck_hud_box", battle_scene.find_child("OppDeckHudBox", true, false))
	battle_scene.set("_my_discard_hud_box", battle_scene.find_child("MyDiscardHudBox", true, false))
	battle_scene.set("_opp_discard_hud_box", battle_scene.find_child("OppDiscardHudBox", true, false))

	battle_scene.call("_setup_side_previews")
	battle_scene.call("_setup_prize_viewer")

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Portrait Prize", 60, "C"), 0))
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	battle_scene.set("_gsm", gsm)

	var my_slots: Array[BattleCardView] = battle_scene.get("_my_prize_slots")
	battle_scene.set("_pending_choice", "take_prize")
	battle_scene.set("_pending_prize_player_index", 0)
	battle_scene.set("_pending_prize_remaining", 1)
	battle_scene.call("_update_prize_slots", my_slots, gsm.game_state.players[0].get_prize_layout(), true)
	battle_scene.call("_show_portrait_prize_dialog_if_needed")

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Panel
	var dialog_vbox := battle_scene.get("_dialog_vbox") as VBoxContainer
	var my_host := battle_scene.get("_my_prize_hud_host") as VBoxContainer
	var prize_slot := my_slots[0] if not my_slots.is_empty() else null
	var dialog_visible_before_tap := dialog_overlay != null and dialog_overlay.visible
	var host_in_dialog_before_tap := my_host != null and dialog_vbox != null and my_host.get_parent() == dialog_vbox
	var prize_slot_connection_count := prize_slot.gui_input.get_connections().size() if prize_slot != null else -1
	var hand_before := gsm.game_state.players[0].hand.size()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(24, 24)
	if prize_slot != null:
		prize_slot.emit_signal("gui_input", press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(24, 24)
	if prize_slot != null:
		prize_slot.emit_signal("gui_input", release)
	var hand_after := gsm.game_state.players[0].hand.size()

	var result := run_checks([
		assert_true(dialog_visible_before_tap, "Portrait prize selection should show the prize dialog before the tap"),
		assert_true(host_in_dialog_before_tap, "The selectable prize host should be inside the portrait dialog"),
		assert_true(prize_slot != null, "The portrait prize dialog should expose a real connected prize slot"),
		assert_gt(prize_slot_connection_count, 0, "The portrait prize slot should keep its gui_input connection after moving into the dialog"),
		assert_eq(hand_after, hand_before + 1, "A ScreenTouch press/release emitted through the visible prize slot should take the Prize"),
		assert_false(str(battle_scene.get("_pending_choice")) == "take_prize", "After taking the prize through the dialog slot signal, the flow should leave Prize selection"),
	])

	battle_scene.free()
	GameManager.battle_layout_mode = previous_layout
	return result


