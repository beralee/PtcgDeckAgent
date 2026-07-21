class_name TestCSV10C166To170
extends TestBase


class HeadsCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(true)
		return true


class TailsCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(false)
		return false


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon_card(name: String, attacks: Array[Dictionary] = [], owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "C"
	data.hp = 300
	if attacks.is_empty():
		data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	else:
		data.attacks.assign(attacks)
	return CardInstance.create(data, owner)


func _item(name: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _fixture_slot(name: String, owner: int = 0) -> PokemonSlot:
	var card := _pokemon_card(name, [], owner)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 24
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _fixture_slot("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_166_to_170_registry_contract() -> String:
	var processor := EffectProcessor.new(TailsCoinFlipper.new())
	var cards: Dictionary = {}
	for number: int in range(166, 171):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["166"].effect_id), "CSV10C_166 should register self-damage-counter scaling"),
		assert_true(processor.has_attack_effect(cards["167"].effect_id), "CSV10C_167 should register Poison"),
		assert_true(processor.has_attack_effect(cards["168"].effect_id), "CSV10C_168 should register double-tails recoil"),
		assert_true(processor.has_attack_effect(cards["169"].effect_id), "CSV10C_169 should register hidden hand shuffle and 3 coin flips"),
		assert_true(processor.has_attack_effect(cards["170"].effect_id), "CSV10C_170 should register top-10 copied attack and Confusion"),
	])


func test_csv10c_166_total_damage_is_self_damage_counter_count_times_20() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var reshiram := _slot(_load_card("166"))
	reshiram.damage_counters = 30
	state.players[0].active_pokemon = reshiram
	processor.register_pokemon_card(reshiram.get_card_data())
	var bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(reshiram, 0):
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", reshiram, state))
	return assert_eq(bonus, 40, "CSV10C_166 should add 40 to printed 20 for 3 damage counters")


func test_csv10c_167_poisons_and_168_double_tails_deals_90_recoil() -> String:
	var state := _state()
	var processor := EffectProcessor.new(TailsCoinFlipper.new())
	var rattata := _slot(_load_card("167"))
	state.players[0].active_pokemon = rattata
	processor.register_pokemon_card(rattata.get_card_data())
	processor.execute_attack_effect(rattata, 0, state.players[1].active_pokemon, state)
	var poisoned: bool = bool(state.players[1].active_pokemon.status_conditions.get("poisoned", false))
	var raticate := _slot(_load_card("168"))
	state.players[0].active_pokemon = raticate
	processor.register_pokemon_card(raticate.get_card_data())
	processor.execute_attack_effect(raticate, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_true(poisoned, "CSV10C_167 should Poison the defender"),
		assert_eq(raticate.damage_counters, 90, "CSV10C_168 should deal 90 recoil only when both flips are tails"),
	])


func test_csv10c_169_hidden_hand_choice_shuffles_selected_card_and_three_heads_total_60() -> String:
	var state := _state()
	var processor := EffectProcessor.new(HeadsCoinFlipper.new())
	var meowth := _slot(_load_card("169"))
	state.players[0].active_pokemon = meowth
	var first := _item("First Hand", 1)
	var selected := _item("Selected Hand", 1)
	state.players[1].hand = [first, selected]
	state.players[1].deck = [_item("Deck Card", 1)]
	processor.register_pokemon_card(meowth.get_card_data())
	var hand_effect: BaseEffect = null
	for effect: BaseEffect in processor.get_attack_effects_for_slot(meowth, 0):
		var steps := effect.get_attack_interaction_steps(meowth.get_top_card(), meowth.get_card_data().attacks[0], state)
		if not steps.is_empty():
			hand_effect = effect
			break
	var hand_steps: Array[Dictionary] = []
	if hand_effect != null:
		hand_steps.assign(hand_effect.get_attack_interaction_steps(meowth.get_top_card(), meowth.get_card_data().attacks[0], state))
	processor.execute_attack_effect(meowth, 0, state.players[1].active_pokemon, state, [{"opponent_hand_card_to_deck": [selected]}])
	state.players[1].active_pokemon.damage_counters = 20
	processor.execute_attack_effect(meowth, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(hand_steps[0].get("visible_scope", "") if not hand_steps.is_empty() else "", "opponent_hand_hidden", "CSV10C_169 should keep hand faces hidden during selection"),
		assert_eq(state.players[1].hand, [first], "CSV10C_169 should remove the selected hidden hand card"),
		assert_true(selected in state.players[1].deck, "CSV10C_169 should shuffle the revealed selected card into the deck"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 60, "CSV10C_169 should total 60 with 3 heads"),
	])


func test_csv10c_170_reveals_only_top_ten_and_copies_selected_pokemon_attack_then_shuffles() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var persian := _slot(_load_card("170"))
	state.players[0].active_pokemon = persian
	var copied_attacks: Array[Dictionary] = [{"name": "Copied Strike", "cost": "", "damage": "70", "text": "", "is_vstar_power": false}]
	var copied_pokemon := _pokemon_card("Revealed Pokemon", copied_attacks, 1)
	var deck: Array[CardInstance] = []
	for index: int in 9:
		deck.append(_item("Top Item %d" % index, 1))
	deck.append(copied_pokemon)
	deck.append(_pokemon_card("Eleventh Pokemon", copied_attacks, 1))
	state.players[1].deck = deck
	processor.register_pokemon_card(persian.get_card_data())
	var copy_effect: BaseEffect = null
	for effect: BaseEffect in processor.get_attack_effects_for_slot(persian, 0):
		if effect.has_method("get_followup_attack_interaction_steps"):
			copy_effect = effect
			break
	var steps: Array[Dictionary] = []
	if copy_effect != null:
		steps.assign(copy_effect.get_attack_interaction_steps(persian.get_top_card(), persian.get_card_data().attacks[0], state))
	var option: Dictionary = steps[0].get("items", [])[0] if not steps.is_empty() and not steps[0].get("items", []).is_empty() else {}
	copy_effect.set_attack_interaction_context([{"csv10c_persian_top_attack": [option]}]) if copy_effect != null else null
	var copied_damage := int(copy_effect.call("get_damage_bonus", persian, state)) if copy_effect != null else 0
	copy_effect.clear_attack_interaction_context() if copy_effect != null else null
	processor.execute_attack_effect(persian, 0, state.players[1].active_pokemon, state, [{"csv10c_persian_top_attack": [option]}])
	processor.execute_attack_effect(persian, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(steps[0].get("revealed_cards", []).size() if not steps.is_empty() else 0, 10, "CSV10C_170 should reveal exactly the top 10 cards"),
		assert_eq(steps[0].get("items", []).size() if not steps.is_empty() else 0, 1, "CSV10C_170 should offer attacks only from Pokemon among the top 10"),
		assert_eq(copied_damage, 70, "CSV10C_170 should use the selected revealed Pokemon attack damage"),
		assert_eq(state.players[1].deck.size(), 11, "CSV10C_170 should return every revealed card before shuffling"),
		assert_true(state.players[1].active_pokemon.status_conditions.get("confused", false), "CSV10C_170 second attack should Confuse the defender"),
	])
