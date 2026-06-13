class_name TestCS6aC099ZamazentaVSTAR
extends TestBase

const EFFECT_ID := "00d90ff674296941a9da9d9a0255aa2d"
const AbilityZamazentaVSTARShieldScript = preload("res://scripts/effects/pokemon_effects/AbilityZamazentaVSTARShield.gd")
const AttackSelfLockNextTurnScript = preload("res://scripts/effects/pokemon_effects/AttackSelfLockNextTurn.gd")


func test_star_shield_consumes_vstar_and_reduces_team_damage_next_opponent_turn() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var zamazenta_card := _zamazenta_vstar()
	processor.register_pokemon_card(zamazenta_card)
	var zamazenta := _make_slot(zamazenta_card, 0)
	state.players[0].active_pokemon = zamazenta
	var pre_existing_bench := _make_slot(_pokemon("Bench Before", "Basic", "M", 120), 0)
	state.players[0].bench.append(pre_existing_bench)
	var opponent_attacker: PokemonSlot = state.players[1].active_pokemon

	var usable_before := processor.can_use_ability(zamazenta, state, 0)
	var used := processor.execute_ability_effect(zamazenta, 0, [], state)
	var usable_after := processor.can_use_ability(zamazenta, state, 0)
	var new_bench := _make_slot(_pokemon("Bench After", "Basic", "M", 120), 0)
	state.players[0].bench.append(new_bench)
	var same_turn_modifier := processor.get_defender_modifier(new_bench, state, opponent_attacker)

	state.players[0].active_pokemon = _make_slot(_pokemon("Replacement Active", "Basic", "M", 120), 0)
	state.current_player_index = 1
	state.turn_number = 3
	var active_modifier := processor.get_defender_modifier(state.players[0].active_pokemon, state, opponent_attacker)
	var pre_existing_modifier := processor.get_defender_modifier(pre_existing_bench, state, opponent_attacker)
	var new_bench_modifier := processor.get_defender_modifier(new_bench, state, opponent_attacker)
	var own_attacker_modifier := processor.get_defender_modifier(new_bench, state, state.players[0].active_pokemon)
	var reduced_damage := DamageCalculator.new().calculate_damage(
		opponent_attacker,
		new_bench,
		{"damage": "220"},
		state,
		0,
		0,
		new_bench_modifier,
		true,
		true
	)

	state.current_player_index = 0
	state.turn_number = 4
	var expired_modifier := processor.get_defender_modifier(new_bench, state, opponent_attacker)

	return run_checks([
		assert_true(usable_before, "Star Shield should be usable on its owner's turn before VSTAR is spent"),
		assert_true(used, "Star Shield should execute through EffectProcessor"),
		assert_false(usable_after, "Star Shield should consume the player's VSTAR power"),
		assert_eq(same_turn_modifier, 0, "Star Shield should not reduce damage during the turn it is used"),
		assert_eq(active_modifier, -100, "Star Shield should protect the active replacement Pokemon next opponent turn"),
		assert_eq(pre_existing_modifier, -100, "Star Shield should protect Pokemon already in play"),
		assert_eq(new_bench_modifier, -100, "Star Shield should protect Pokemon that enter play after the ability resolves"),
		assert_eq(own_attacker_modifier, 0, "Star Shield should only reduce damage from the opponent's Pokemon"),
		assert_eq(reduced_damage, 120, "Star Shield should reduce 220 attack damage to 120"),
		assert_eq(expired_modifier, 0, "Star Shield should expire after the opponent's next turn"),
	])


func test_star_shield_cannot_be_used_on_opponent_turn() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var zamazenta_card := _zamazenta_vstar()
	processor.register_pokemon_card(zamazenta_card)
	var zamazenta := _make_slot(zamazenta_card, 0)
	state.players[0].active_pokemon = zamazenta
	state.current_player_index = 1

	return run_checks([
		assert_false(processor.can_use_ability(zamazenta, state, 0), "Star Shield should only be usable on its owner's turn"),
		assert_false(processor.execute_ability_effect(zamazenta, 0, [], state), "Star Shield should not execute on the opponent turn"),
		assert_false(bool(state.vstar_power_used[0]), "Failed Star Shield execution should not consume VSTAR"),
	])


func test_ultimate_impact_registers_and_locks_same_attack_next_own_turn() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var zamazenta_card := _zamazenta_vstar()
	processor.register_pokemon_card(zamazenta_card)
	var zamazenta := _make_slot(zamazenta_card, 0)
	state.players[0].active_pokemon = zamazenta
	_attach_energy(zamazenta, 0, "M", 2)
	_attach_energy(zamazenta, 0, "C", 1)

	var ability_effect := processor.get_effect(EFFECT_ID)
	var attack_effects := processor.get_attack_effects_for_slot(zamazenta, 0)
	processor.execute_attack_effect(zamazenta, 0, state.players[1].active_pokemon, state)
	var has_attack_lock := zamazenta.effects.any(func(effect: Dictionary) -> bool:
		return str(effect.get("type", "")) == "attack_lock" and int(effect.get("attack_index", -1)) == 0
	)
	state.turn_number = 4
	state.current_player_index = 0
	var can_reuse_attack := RuleValidator.new().can_use_attack(state, 0, 0, processor)

	return run_checks([
		assert_true(ability_effect is AbilityZamazentaVSTARShieldScript, "CS6aC_099 should register Star Shield as its ability effect"),
		assert_eq(attack_effects.size(), 1, "CS6aC_099 Ultimate Impact should register one attack effect"),
		assert_true(attack_effects[0] is AttackSelfLockNextTurnScript, "Ultimate Impact should reuse AttackSelfLockNextTurn"),
		assert_true(has_attack_lock, "Ultimate Impact should mark its attack as locked after use"),
		assert_false(can_reuse_attack, "Ultimate Impact should be unusable on the next own turn"),
	])


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_pokemon("Active %d" % pi, "Basic", "C", 120), pi)
		state.players.append(player)
	return state


func _zamazenta_vstar() -> CardData:
	var cd := _pokemon("藏玛然特VSTAR", "VSTAR", "M", 270)
	cd.name_en = "Zamazenta VSTAR"
	cd.mechanic = "V"
	cd.evolves_from = "藏玛然特V"
	cd.effect_id = EFFECT_ID
	cd.abilities = [{
		"name": "星耀之盾",
		"text": "During the opponent's next turn, your Pokemon take 100 less damage from attacks.",
	}]
	cd.attacks = [{
		"name": "终极冲击",
		"cost": "MMC",
		"damage": "220",
		"text": "During your next turn, this Pokemon can't attack.",
		"is_vstar_power": false,
	}]
	return cd


func _pokemon(name: String, stage: String, energy_type: String, hp: int) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		var energy := CardData.new()
		energy.name = "%s Energy %d" % [energy_type, i]
		energy.card_type = "Basic Energy"
		energy.energy_type = energy_type
		energy.energy_provides = energy_type
		slot.attached_energy.append(CardInstance.create(energy, owner_index))
