class_name Test151C005CharmeleonEffect
extends TestBase


func test_175_bomb_charizard_v2_charmeleon_cards_are_implemented() -> String:
	CardImplementationStatus.clear_cache()
	var charmeleon_151 := _charmeleon_151()
	var charmeleon_csv5c := _charmeleon_csv5c()

	return run_checks([
		assert_false(
			CardImplementationStatus.is_unimplemented(charmeleon_151),
			"151C_005 Charmeleon should not show the unimplemented badge: %s" % CardImplementationStatus.get_reason(charmeleon_151)
		),
		assert_false(
			CardImplementationStatus.is_unimplemented(charmeleon_csv5c),
			"CSV5C_015 Charmeleon should remain implemented: %s" % CardImplementationStatus.get_reason(charmeleon_csv5c)
		),
	])


func test_151c_005_charmeleon_fire_blast_discards_one_selected_attached_energy() -> String:
	var gsm := _make_gsm()
	var attacker := _slot(_charmeleon_151(), 0)
	var defender := _slot(_basic_pokemon("Defender", "C", 200), 1)
	var energies := [
		_attach_energy(attacker, "Fire Energy A", "R"),
		_attach_energy(attacker, "Fire Energy B", "R"),
		_attach_energy(attacker, "Fire Energy C", "R"),
	]
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var first_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var second_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	var used := gsm.use_attack(0, 1, [{
		AttackDiscardAttachedEnergyFromSelf.STEP_ID: [energies[1]],
	}])

	return run_checks([
		assert_eq(first_attack_effects.size(), 0, "151C_005 first attack is numeric-only and should not discard Energy"),
		assert_eq(second_attack_effects.size(), 1, "151C_005 second attack should register one discard-self-Energy effect"),
		assert_true(used, "151C_005 Fire Blast should be usable with three Fire Energy"),
		assert_eq(defender.damage_counters, 90, "151C_005 Fire Blast should deal its printed 90 damage"),
		assert_eq(attacker.attached_energy.size(), 2, "151C_005 Fire Blast should discard exactly one attached Energy"),
		assert_contains(gsm.game_state.players[0].discard_pile, energies[1], "Selected attached Energy should move to discard"),
		assert_false(energies[1] in attacker.attached_energy, "Selected attached Energy should leave Charmeleon"),
	])


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	gsm.game_state = state
	return gsm


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, name: String, energy_type: String) -> CardInstance:
	var energy := CardInstance.create(_energy(name, energy_type), 0)
	slot.attached_energy.append(energy)
	return energy


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _charmeleon_151() -> CardData:
	var cd := _basic_pokemon("火恐龙", "R", 100)
	cd.name_en = "Charmeleon"
	cd.set_code = "151C"
	cd.card_index = "005"
	cd.effect_id = "5c0e1214b56b8b00c3853bd00635a5de"
	cd.stage = "Stage 1"
	cd.evolves_from = "小火龙"
	cd.attacks = [
		{"name": "烈焰", "cost": "R", "damage": "20", "text": "", "is_vstar_power": false},
		{"name": "大字爆炎", "cost": "RRR", "damage": "90", "text": "选择这只宝可梦身上附着的1个能量，放于弃牌区。", "is_vstar_power": false},
	]
	return cd


func _charmeleon_csv5c() -> CardData:
	var cd := _basic_pokemon("火恐龙", "R", 90)
	cd.name_en = "Charmeleon"
	cd.set_code = "CSV5C"
	cd.card_index = "015"
	cd.effect_id = "80abbdd5ce75ddd713dab42752383acd"
	cd.stage = "Stage 1"
	cd.evolves_from = "小火龙"
	cd.abilities = [{"name": "闪焰之幕", "text": "这只宝可梦，不受到对手宝可梦所使用招式的效果影响。"}]
	cd.attacks = [
		{"name": "烈焰", "cost": "RR", "damage": "50", "text": "", "is_vstar_power": false},
	]
	return cd


func _basic_pokemon(name: String, energy_type: String, hp: int) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.retreat_cost = 1
	cd.attacks = [
		{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false},
	]
	return cd
