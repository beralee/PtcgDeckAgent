class_name TestUnitedWingsEffect
extends TestBase

const AttackUnitedWingsCountDamageScript := preload("res://scripts/effects/pokemon_effects/AttackUnitedWingsCountDamage.gd")


func test_united_wings_registers_english_and_chinese_attack_names() -> String:
	var processor := EffectProcessor.new()
	var english_card := _united_wings_pokemon("Murkrow", "test_united_wings_murkrow", "United Wings", "D", "D")
	var chinese_card := _united_wings_pokemon("Localized Bird", "test_united_wings_chinese", "团结之翼", "C", "CC")
	processor.register_pokemon_card(english_card)
	processor.register_pokemon_card(chinese_card)
	var english_effects := processor.get_attack_effects_for_slot(_slot(english_card, 0), 0)
	var chinese_effects := processor.get_attack_effects_for_slot(_slot(chinese_card, 0), 0)

	return run_checks([
		assert_true(_has_effect_type(english_effects, AttackUnitedWingsCountDamageScript), "English United Wings should register the discard-count damage effect"),
		assert_true(_has_effect_type(chinese_effects, AttackUnitedWingsCountDamageScript), "Chinese 团结之翼 should register the discard-count damage effect"),
	])


func test_united_wings_damage_counts_own_discard_pokemon_with_united_wings_attack() -> String:
	var attacker_card := _united_wings_pokemon("Murkrow", "test_united_wings_active", "United Wings", "D", "D")
	var empty_fixture := _united_wings_gsm(attacker_card)
	var empty_damage := int(empty_fixture.gsm.get_attack_preview_damage(0, 0))

	var powered_fixture := _united_wings_gsm(attacker_card)
	var player: PlayerState = powered_fixture.gsm.game_state.players[0]
	player.discard_pile.append_array([
		CardInstance.create(_united_wings_pokemon("Wattrel", "test_united_wings_wattrel", "United Wings", "L", "CC"), 0),
		CardInstance.create(_united_wings_pokemon("Flamigo", "test_united_wings_flamigo", "团结之翼", "C", "CC"), 0),
		CardInstance.create(_united_wings_pokemon_zh_field("Dartrix", "test_united_wings_dartrix"), 0),
		CardInstance.create(_pokemon("Flying Filler", "test_united_wings_non_matching", [_attack("Gust", "C", "20", "")], "C"), 0),
		CardInstance.create(_trainer("Discarded Item", "Item", "test_united_wings_item"), 0),
	])
	var preview_damage := int(powered_fixture.gsm.get_attack_preview_damage(0, 0))
	var attacked := bool(powered_fixture.gsm.use_attack(0, 0))

	return run_checks([
		assert_eq(empty_damage, 0, "United Wings should deal 0 damage with no matching Pokemon in discard despite printed 20x"),
		assert_eq(preview_damage, 60, "United Wings should preview 20 damage for each matching discard Pokemon"),
		assert_true(attacked, "United Wings should execute through GameStateMachine"),
		assert_eq(powered_fixture.defender.damage_counters, 60, "United Wings should deal 60 for three matching discard Pokemon"),
	])


func _united_wings_gsm(attacker_card: CardData) -> Dictionary:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var attacker := _slot(attacker_card, 0)
	attacker.attached_energy.append(CardInstance.create(_energy("Darkness Energy", "D"), 0))
	var defender := _slot(_pokemon("Defender", "test_united_wings_defender", [_attack("Tackle", "C", "10", "")], "C", 300), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(attacker_card)
	return {"gsm": gsm, "attacker": attacker, "defender": defender}


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _united_wings_pokemon(name: String, effect_id: String, attack_name: String, energy_type: String, cost: String) -> CardData:
	return _pokemon(
		name,
		effect_id,
		[_attack(attack_name, cost, "20x", "This attack does 20 damage for each Pokemon in your discard pile that has the United Wings attack.")],
		energy_type
	)


func _united_wings_pokemon_zh_field(name: String, effect_id: String) -> CardData:
	var card := _pokemon(
		name,
		effect_id,
		[_attack("Localized United Wings", "CC", "20x", "This attack does 20 damage for each Pokemon in your discard pile that has the United Wings attack.")],
		"C"
	)
	card.attacks[0]["name_zh"] = "团结之翼"
	return card


func _pokemon(name: String, effect_id: String, attacks: Array[Dictionary], energy_type: String = "C", hp: int = 90) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = "Basic"
	cd.attacks = attacks
	cd.weakness_energy = ""
	cd.weakness_value = ""
	cd.resistance_energy = ""
	cd.resistance_value = ""
	return cd


func _trainer(name: String, card_type: String, effect_id: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _energy(name: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = provides
	cd.effect_id = "energy_%s" % provides
	return cd


func _attack(name: String, cost: String, damage: String, text: String) -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _has_effect_type(effects: Array, effect_type: Variant) -> bool:
	for effect: BaseEffect in effects:
		if is_instance_of(effect, effect_type):
			return true
	return false
