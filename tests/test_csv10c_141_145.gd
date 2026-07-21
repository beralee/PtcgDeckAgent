class_name TestCSV10C141To145
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, attacks: Array[Dictionary] = [], mechanic: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "D"
	card.mechanic = mechanic
	card.hp = 300
	if attacks.is_empty():
		card.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	else:
		card.attacks.assign(attacks)
	return card


func _card(name: String, card_type: String = "Item", owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	data.energy_provides = "D" if card_type.contains("Energy") else ""
	return CardInstance.create(data, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 14
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		state.players.append(player)
	return state


func test_csv10c_141_to_145_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(141, 146):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["141"].effect_id), "CSV10C_141 should register Pokemon ex bonus"),
		assert_true(processor.has_attack_effect(cards["142"].effect_id), "CSV10C_142 should register selected Energy discard"),
		assert_true(processor.has_attack_effect(cards["143"].effect_id), "CSV10C_143 should register recoil"),
		assert_false(processor.has_attack_effect(cards["144"].effect_id), "CSV10C_144 is numeric-only"),
		assert_true(processor.has_effect(cards["145"].effect_id), "CSV10C_145 should register Trade"),
		assert_true(processor.has_attack_effect(cards["145"].effect_id), "CSV10C_145 should register Night Joker"),
	])


func test_csv10c_141_adds_70_only_against_pokemon_ex() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var liepard := _slot(_load_card("141"))
	state.players[0].active_pokemon = liepard
	processor.register_pokemon_card(liepard.get_card_data())
	state.players[1].active_pokemon = _slot(_pokemon("Defender ex", [], "ex"), 1)
	var against_ex := _damage_bonus(processor, liepard, 0, state)
	state.players[1].active_pokemon = _slot(_pokemon("Plain Defender"), 1)
	var against_plain := _damage_bonus(processor, liepard, 0, state)
	return run_checks([
		assert_eq(against_ex, 70, "CSV10C_141 should add 70 against Pokemon ex"),
		assert_eq(against_plain, 0, "CSV10C_141 should not add damage against a plain Pokemon"),
	])


func test_csv10c_142_discards_explicitly_selected_defender_energy() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var scraggy := _slot(_load_card("142"))
	state.players[0].active_pokemon = scraggy
	var first := _card("First Energy", "Basic Energy", 1)
	var selected := _card("Selected Energy", "Special Energy", 1)
	state.players[1].active_pokemon.attached_energy = [first, selected]
	processor.register_pokemon_card(scraggy.get_card_data())
	processor.execute_attack_effect(scraggy, 0, state.players[1].active_pokemon, state, [{"discard_opponent_active_energy": [selected]}])
	var mist := _card("Mist Energy", "Special Energy", 1)
	mist.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	state.players[1].active_pokemon.attached_energy.append(mist)
	processor.execute_attack_effect(scraggy, 0, state.players[1].active_pokemon, state, [{"discard_opponent_active_energy": [first]}])
	return run_checks([
		assert_eq(state.players[1].active_pokemon.attached_energy, [first, mist], "CSV10C_142 should leave the unselected Energy attached and respect Mist Energy protection"),
		assert_true(selected in state.players[1].discard_pile, "CSV10C_142 should discard the selected Energy"),
	])


func test_csv10c_143_recoil_applies_only_to_second_attack() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var scrafty := _slot(_load_card("143"))
	state.players[0].active_pokemon = scrafty
	processor.register_pokemon_card(scrafty.get_card_data())
	processor.execute_attack_effect(scrafty, 0, state.players[1].active_pokemon, state)
	var after_first := scrafty.damage_counters
	processor.execute_attack_effect(scrafty, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(after_first, 0, "CSV10C_143 first attack should have no recoil"),
		assert_eq(scrafty.damage_counters, 30, "CSV10C_143 second attack should deal 30 to itself"),
	])


func test_csv10c_145_trade_discards_one_draws_two_and_night_joker_filters_sources() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var zoroark := _slot(_load_card("145"))
	state.players[0].active_pokemon = zoroark
	var discard_me := _card("Discard Me")
	var draw_one := _card("Draw One")
	var draw_two := _card("Draw Two")
	state.players[0].hand = [discard_me]
	state.players[0].deck = [draw_one, draw_two]
	var valid_attacks: Array[Dictionary] = [{"name": "Valid N Attack", "cost": "", "damage": "50", "text": "", "is_vstar_power": false}]
	var recursive_attacks: Array[Dictionary] = [{"name": "暗夜王牌", "cost": "DD", "damage": "", "text": "", "is_vstar_power": false}]
	state.players[0].bench = [
		_slot(_pokemon("N的达摩狒狒", valid_attacks)),
		_slot(_pokemon("N的另一只索罗亚克", recursive_attacks)),
		_slot(_pokemon("Unrelated Pokemon", valid_attacks)),
	]
	processor.register_pokemon_card(zoroark.get_card_data())
	var used := processor.execute_ability_effect(zoroark, 0, [{"discard_card": [discard_me]}], state)
	var copy_effect: BaseEffect = null
	for effect: BaseEffect in processor.get_attack_effects_for_slot(zoroark, 0):
		if effect.has_method("get_followup_attack_interaction_steps"):
			copy_effect = effect
			break
	var steps: Array[Dictionary] = []
	if copy_effect != null:
		steps = copy_effect.get_attack_interaction_steps(zoroark.get_top_card(), zoroark.get_card_data().attacks[0], state)
	return run_checks([
		assert_true(used, "CSV10C_145 Trade should be usable with a hand card"),
		assert_true(discard_me in state.players[0].discard_pile, "CSV10C_145 Trade should discard the selected hand card"),
		assert_eq(state.players[0].hand, [draw_one, draw_two], "CSV10C_145 Trade should draw 2 cards"),
		assert_eq(steps[0].get("items", []).size() if not steps.is_empty() else 0, 1, "CSV10C_145 Night Joker should offer only non-recursive attacks from Benched N's Pokemon"),
		assert_eq((steps[0].get("items", [])[0] as Dictionary).get("attack_index", -1) if not steps.is_empty() else -1, 0, "CSV10C_145 should expose the valid N Pokemon attack"),
	])


func _damage_bonus(processor: EffectProcessor, attacker: PokemonSlot, attack_index: int, state: GameState) -> int:
	var total := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, attack_index):
		if effect.has_method("get_damage_bonus"):
			total += int(effect.call("get_damage_bonus", attacker, state))
	return total
