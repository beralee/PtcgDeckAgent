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
