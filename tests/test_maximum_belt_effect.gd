class_name TestMaximumBeltEffect
extends TestBase


func _make_basic_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	return cd


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		var active_cd := _make_basic_pokemon_data("Active_%d" % pi, "C", 120)
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(active_cd, pi))
		active.turn_played = 0
		player.active_pokemon = active
		state.players.append(player)

	return state


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func test_maximum_belt_boosts_real_arceus_damage_into_ex_targets() -> String:
	var arceus_cd := CardDatabase.get_card("CS5aC", "107")
	var miraidon_cd := CardDatabase.get_card("CSV1C", "050")
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	if arceus_cd == null or miraidon_cd == null or max_belt_cd == null:
		return "Missing Maximum Belt / Arceus VSTAR / Miraidon ex real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(arceus_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)

	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(miraidon_cd, 1))

	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var actual_damage := gsm._calculate_attack_damage(attacker, defender, arceus_cd.attacks[0], 0)

	return run_checks([
		assert_eq(preview_damage, 250, "Maximum Belt should raise Trinity Nova preview damage from 200 to 250 against Pokemon ex"),
		assert_eq(actual_damage, 250, "Maximum Belt should raise Trinity Nova actual damage from 200 to 250 against Pokemon ex"),
	])


func _make_reported_typhlosion_battle(player_index: int = 0) -> GameStateMachine:
	var typhlosion := CardDatabase.get_card("CSV10C", "030")
	var adventure := CardDatabase.get_card("CSV10C", "208")
	var victini := CardDatabase.get_card("CSV9C", "023")
	var dragapult := CardDatabase.get_card("CSV8C", "159")
	var belt := CardDatabase.get_card("CSV7C", "189")
	var fire := CardDatabase.get_card("CSVE1C", "FIR")
	for data: CardData in [typhlosion, adventure, victini, dragapult, belt, fire]:
		if data == null:
			return null
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	# Normal deck construction and replay restoration register every Pokemon.
	# This fixture skips setup, so preserve that production precondition here.
	for data: CardData in [typhlosion, victini, dragapult]:
		gsm.effect_processor.register_pokemon_card(data)
	gsm.game_state.turn_number = 3 + player_index
	gsm.game_state.current_player_index = player_index
	var player := gsm.game_state.players[player_index]
	var opponent := gsm.game_state.players[1 - player_index]
	var attacker := _make_slot(typhlosion, player_index)
	var defender := _make_slot(dragapult, 1 - player_index)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	player.bench.append(_make_slot(victini, player_index))
	for i in 4:
		player.discard_pile.append(CardInstance.create(adventure, player_index))
	attacker.attached_energy.append(CardInstance.create(fire, player_index))
	player.hand.append(CardInstance.create(belt, player_index))
	for side: PlayerState in gsm.game_state.players:
		for i in 6:
			side.prizes.append(CardInstance.create(fire, side.player_index))
			side.deck.append(CardInstance.create(fire, side.player_index))
	return gsm


func test_ethans_typhlosion_belt_from_hand_boosts_the_same_turn_attack() -> String:
	var gsm := _make_reported_typhlosion_battle()
	if gsm == null:
		return "Missing real card data for the reported Typhlosion / Maximum Belt interaction"
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var attacker := player.active_pokemon
	var defender := opponent.active_pokemon
	var dragapult := defender.get_card_data()
	var tool := player.hand[0]
	var before := gsm.get_attack_preview_damage(0, 0)
	var attached := gsm.attach_tool(0, tool, attacker)
	var after := gsm.get_attack_preview_damage(0, 0)
	var attacked := gsm.use_attack(0, 0)
	return run_checks([
		assert_eq(before, 290, "Four Adventures and Victini should deal 290 before attaching the belt"),
		assert_true(attached, "Maximum Belt should attach from hand in MAIN"),
		assert_eq(after, 340, "The first preview after attachment must include Maximum Belt's 50 damage"),
		assert_true(attacked, "The reported first attack must execute"),
		assert_eq(defender.damage_counters, 340, "The same-turn attack must deal 340, not 290"),
		assert_true(opponent.discard_pile.any(func(card: CardInstance) -> bool: return card.card_data == dragapult), "340 damage should knock out the 320 HP Dragapult ex"),
	])


func test_ethans_typhlosion_belt_works_without_preview_for_either_player() -> String:
	var checks: Array[String] = []
	for player_index in 2:
		var gsm := _make_reported_typhlosion_battle(player_index)
		if gsm == null:
			return "Missing reported battle cards"
		var player := gsm.game_state.players[player_index]
		var defender := gsm.game_state.players[1 - player_index].active_pokemon
		checks.append(assert_true(gsm.attach_tool(player_index, player.hand[0], player.active_pokemon), "Belt must attach before the first attack"))
		checks.append(assert_true(gsm.use_attack(player_index, 0), "Attack must execute without prewarming a preview"))
		checks.append(assert_eq(defender.damage_counters, 340, "Player %d must immediately deal 340 without opening attack preview" % player_index))
	return run_checks(checks)


func test_ethans_typhlosion_belt_through_player_hand_and_board_actions() -> String:
	var gsm := _make_reported_typhlosion_battle()
	if gsm == null:
		return "Missing reported battle cards"
	var helpers = load("res://tests/helpers/BattleUIFeaturesShared.gd").new()
	var scene: Control = helpers._make_battle_scene_stub()
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	var old_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var player := gsm.game_state.players[0]
	var attacker := player.active_pokemon
	var defender := gsm.game_state.players[1].active_pokemon
	var belt := player.hand[0]
	scene.call("_on_hand_card_clicked", belt, null)
	var selected: bool = scene.get("_selected_hand_card") == belt
	scene.call("_handle_slot_left_click", "my_active")
	var attached: bool = attacker.attached_tool == belt and not player.hand.has(belt)
	scene.call("_try_use_attack_with_interaction", 0, attacker, 0)
	GameManager.current_mode = old_mode
	return run_checks([
		assert_true(selected, "Player hand action must select the real belt"),
		assert_true(attached, "Player board action must attach the selected belt immediately"),
		assert_eq(defender.damage_counters, 340, "The next player attack must apply all 340 damage through the UI interaction path"),
	])


func test_ethans_typhlosion_belt_is_suppressed_only_while_jamming_tower_is_in_play() -> String:
	var tower := CardDatabase.get_card("CSV8C", "203")
	if tower == null:
		return "Missing real Jamming Tower card"
	var checks: Array[String] = []
	for remove_tower in [false, true]:
		var gsm := _make_reported_typhlosion_battle()
		if gsm == null:
			return "Missing reported battle cards"
		var player := gsm.game_state.players[0]
		var defender := gsm.game_state.players[1].active_pokemon
		gsm.game_state.stadium_card = CardInstance.create(tower, 1)
		gsm.game_state.stadium_owner_index = 1
		checks.append(assert_true(gsm.attach_tool(0, player.hand[0], player.active_pokemon), "Suppression must not prevent attachment"))
		checks.append(assert_eq(gsm.get_attack_preview_damage(0, 0), 290, "Jamming Tower suppresses only the belt's 50, leaving Victini's 10"))
		if remove_tower:
			gsm.game_state.players[1].discard_pile.append(gsm.game_state.stadium_card)
			gsm.game_state.stadium_card = null
			gsm.game_state.stadium_owner_index = -1
		var expected := 340 if remove_tower else 290
		checks.append(assert_eq(gsm.get_attack_preview_damage(0, 0), expected, "Belt suppression must follow the current stadium immediately"))
		checks.append(assert_true(gsm.use_attack(0, 0), "Attack must execute with the current stadium"))
		checks.append(assert_eq(defender.damage_counters, expected, "Actual damage must match the current tool suppression state"))
	return run_checks(checks)


func test_maximum_belt_does_not_boost_real_arceus_damage_into_non_ex_targets() -> String:
	var arceus_cd := CardDatabase.get_card("CS5aC", "107")
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	if arceus_cd == null or max_belt_cd == null:
		return "Missing Maximum Belt / Arceus VSTAR real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(arceus_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)

	var non_ex_cd := _make_basic_pokemon_data("Non-ex Target", "W", 220)
	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(non_ex_cd, 1))

	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var actual_damage := gsm._calculate_attack_damage(attacker, defender, arceus_cd.attacks[0], 0)

	return run_checks([
		assert_eq(preview_damage, 200, "Maximum Belt should not boost Trinity Nova against non-ex targets"),
		assert_eq(actual_damage, 200, "Maximum Belt should not boost actual damage against non-ex targets"),
	])


func test_maximum_belt_and_double_turbo_still_knock_out_teal_mask_ogerpon_ex() -> String:
	var arceus_cd := CardDatabase.get_card("CS5aC", "107")
	var ogerpon_cd := CardDatabase.get_card("CSV8C", "028")
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	var dte_cd := CardDatabase.get_card("CSNC", "024")
	if arceus_cd == null or ogerpon_cd == null or max_belt_cd == null or dte_cd == null:
		return "Missing Arceus VSTAR / Teal Mask Ogerpon ex / Maximum Belt / Double Turbo Energy real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(arceus_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)
	attacker.attached_energy.append(CardInstance.create(dte_cd, 0))

	var grass_cd := CardData.new()
	grass_cd.name = "Grass Energy"
	grass_cd.card_type = "Basic Energy"
	grass_cd.energy_provides = "G"
	attacker.attached_energy.append(CardInstance.create(grass_cd, 0))

	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(ogerpon_cd, 1))

	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var actual_damage := gsm._calculate_attack_damage(attacker, defender, arceus_cd.attacks[0], 0)
	var knock_out := actual_damage >= ogerpon_cd.hp

	return run_checks([
		assert_eq(preview_damage, 230, "Double Turbo should reduce Trinity Nova by 20, then Maximum Belt should add 50 for a total of 230 into Ogerpon ex"),
		assert_eq(actual_damage, 230, "Actual damage should also be 230 into Teal Mask Ogerpon ex"),
		assert_true(knock_out, "230 damage should knock out Teal Mask Ogerpon ex with 210 HP"),
	])


func test_maximum_belt_boosts_any_target_attack_only_when_target_is_active_ex() -> String:
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	if max_belt_cd == null:
		return "Missing Maximum Belt real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker_cd := _make_basic_pokemon_data("Any Target Attacker", "D", 210, "Basic", "", "maximum_belt_any_target_test")
	attacker_cd.attacks = [{
		"name": "Cruel Arrow",
		"cost": "CCC",
		"damage": "",
		"text": "",
		"is_vstar_power": false,
	}]
	gsm.effect_processor.register_attack_effect(attacker_cd.effect_id, AttackAnyTargetDamage.new(100))
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)

	var active_ex_cd := _make_basic_pokemon_data("Active ex", "P", 220, "Basic", "ex")
	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(active_ex_cd, 1))

	var bench_ex_cd := _make_basic_pokemon_data("Bench ex", "P", 220, "Basic", "ex")
	var bench_ex := _make_slot(bench_ex_cd, 1)
	gsm.game_state.players[1].bench.append(bench_ex)

	gsm.effect_processor.execute_attack_effect(attacker, 0, defender, gsm.game_state, [{"any_target": [defender]}])
	gsm.effect_processor.execute_attack_effect(attacker, 0, defender, gsm.game_state, [{"any_target": [bench_ex]}])

	return run_checks([
		assert_eq(defender.damage_counters, 150, "Maximum Belt should boost any-target attack damage when the selected target is the opponent Active ex"),
		assert_eq(bench_ex.damage_counters, 100, "Maximum Belt should not boost any-target attack damage to a Benched ex"),
	])


func test_maximum_belt_boosts_multitarget_attack_only_for_active_ex_target() -> String:
	var max_belt_cd := CardDatabase.get_card("CSV7C", "189")
	if max_belt_cd == null:
		return "Missing Maximum Belt real card data"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker_cd := _make_basic_pokemon_data("Radiant Greninja", "W", 130, "Basic", "", "maximum_belt_moonlight_test")
	attacker_cd.attacks = [{
		"name": "Moonlight Shuriken",
		"cost": "WWC",
		"damage": "",
		"text": "",
		"is_vstar_power": false,
	}]
	gsm.effect_processor.register_attack_effect(attacker_cd.effect_id, AttackMoonlightShuriken.new(90, 2))

	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.pokemon_stack.clear()
	attacker.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker.attached_tool = CardInstance.create(max_belt_cd, 0)

	var active_ex_cd := _make_basic_pokemon_data("Active ex", "P", 220, "Basic", "ex")
	var defender := gsm.game_state.players[1].active_pokemon
	defender.pokemon_stack.clear()
	defender.pokemon_stack.append(CardInstance.create(active_ex_cd, 1))

	var bench_ex_cd := _make_basic_pokemon_data("Bench ex", "P", 220, "Basic", "ex")
	var bench_ex := _make_slot(bench_ex_cd, 1)
	gsm.game_state.players[1].bench.append(bench_ex)

	gsm.effect_processor.execute_attack_effect(
		attacker,
		0,
		defender,
		gsm.game_state,
		[{"moonlight_shuriken_targets": [defender, bench_ex]}]
	)

	return run_checks([
		assert_eq(defender.damage_counters, 140, "Maximum Belt should boost multitarget attack damage to the opponent Active ex"),
		assert_eq(bench_ex.damage_counters, 90, "Maximum Belt should not boost multitarget attack damage to a Benched ex"),
	])
