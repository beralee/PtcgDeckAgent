class_name TestCSV10C136To140
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, mechanic: String = "", owner: int = 0) -> PokemonSlot:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "D"
	card.mechanic = mechanic
	card.hp = 300
	card.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 12
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, "", owner)
		state.players.append(player)
	return state


func _hand_card(name: String, owner: int = 1) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func test_csv10c_136_to_140_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(136, 141):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["136"].effect_id), "CSV10C_136 should register selected Bench scaling damage"),
		assert_true(processor.has_effect(cards["137"].effect_id), "CSV10C_137 should register Active Item lock"),
		assert_true(processor.has_attack_effect(cards["137"].effect_id), "CSV10C_137 should register mill 2"),
		assert_true(processor.has_attack_effect(cards["138"].effect_id), "CSV10C_138 should register Cynthia bench-counter scaling and weakness ignore"),
		assert_true(processor.has_attack_effect(cards["139"].effect_id), "CSV10C_139 should register visible opponent-hand bottom deck"),
		assert_true(processor.has_attack_effect(cards["140"].effect_id), "CSV10C_140 should register Pokemon ex bonus"),
	])


func test_csv10c_136_targets_one_benched_pokemon_for_twice_its_damage_counters() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var sneasel := _slot(_load_card("136"))
	state.players[0].active_pokemon = sneasel
	var first := _pokemon("First Bench", "", 1)
	var second := _pokemon("Second Bench", "", 1)
	first.damage_counters = 30
	second.damage_counters = 50
	state.players[1].bench = [first, second]
	processor.register_pokemon_card(sneasel.get_card_data())
	var effect: BaseEffect = processor.get_attack_effects_for_slot(sneasel, 1)[0]
	var steps := effect.get_attack_interaction_steps(sneasel.get_top_card(), sneasel.get_card_data().attacks[1], state)
	processor.execute_attack_effect(sneasel, 1, state.players[1].active_pokemon, state, [{"csv10c_damaged_bench_target": [second]}])
	var protected := _slot(_load_card("048"), 1)
	protected.damage_counters = 40
	state.players[1].bench = [protected]
	processor.register_pokemon_card(protected.get_card_data())
	processor.execute_attack_effect(sneasel, 1, state.players[1].active_pokemon, state, [{"csv10c_damaged_bench_target": [protected]}])
	return run_checks([
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [first, second], "CSV10C_136 should offer every opposing Benched Pokemon"),
		assert_eq(first.damage_counters, 30, "CSV10C_136 should honor the selected Bench target"),
		assert_eq(second.damage_counters, 150, "CSV10C_136 should deal target damage counters x20 as damage"),
		assert_eq(protected.damage_counters, 40, "CSV10C_136 should respect opposing Bench damage immunity"),
	])


func test_csv10c_137_blocks_opponent_items_only_while_active_and_mills_two() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var tyranitar := _slot(_load_card("137"))
	state.players[0].active_pokemon = tyranitar
	var first := _hand_card("Deck One", 1)
	var second := _hand_card("Deck Two", 1)
	var third := _hand_card("Deck Three", 1)
	state.players[1].deck = [first, second, third]
	processor.register_pokemon_card(tyranitar.get_card_data())
	var item := _hand_card("Opponent Item", 1)
	var blocked_active := processor.prevents_card_from_hand(1, item, state)
	state.players[0].active_pokemon = _pokemon("Replacement")
	state.players[0].bench = [tyranitar]
	var blocked_bench := processor.prevents_card_from_hand(1, item, state)
	state.players[0].active_pokemon = tyranitar
	state.players[0].bench.clear()
	processor.execute_attack_effect(tyranitar, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_true(blocked_active, "CSV10C_137 should block an opponent Item while Active"),
		assert_false(blocked_bench, "CSV10C_137 should stop blocking Items on the Bench"),
		assert_eq(state.players[1].discard_pile, [first, second], "CSV10C_137 should mill the top 2 opponent deck cards"),
		assert_eq(state.players[1].deck, [third], "CSV10C_137 should preserve the remaining deck"),
	])


func test_csv10c_138_counts_damage_counters_only_on_own_benched_cynthia_pokemon_and_ignores_weakness() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var spiritomb := _slot(_load_card("138"))
	state.players[0].active_pokemon = spiritomb
	var cynthia_one := _pokemon("竹兰的烈咬陆鲨")
	var cynthia_two := _pokemon("Cynthia's Gible")
	var unrelated := _pokemon("Unrelated")
	cynthia_one.damage_counters = 30
	cynthia_two.damage_counters = 20
	unrelated.damage_counters = 90
	state.players[0].bench = [cynthia_one, cynthia_two, unrelated]
	processor.register_pokemon_card(spiritomb.get_card_data())
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm.effect_processor.register_pokemon_card(spiritomb.get_card_data())
	state.players[1].active_pokemon.get_card_data().weakness_energy = "D"
	state.players[1].active_pokemon.get_card_data().weakness_value = "×2"
	var final_damage := gsm.get_attack_preview_damage(0, 0)
	var bonus := 0
	var ignores_weakness := false
	for effect: BaseEffect in processor.get_attack_effects_for_slot(spiritomb, 0):
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", spiritomb, state))
		if effect.has_method("ignores_weakness"):
			ignores_weakness = bool(effect.call("ignores_weakness", spiritomb, state, 0))
	return run_checks([
		assert_eq(bonus, 40, "CSV10C_138 should add 40 to printed 10 for 5 counters on Cynthia's Benched Pokemon"),
		assert_true(ignores_weakness, "CSV10C_138 should ignore Weakness"),
		assert_eq(final_damage, 50, "CSV10C_138 should deal exactly 10 damage per real counter and must not double for Weakness"),
	])


func test_csv10c_139_reveals_opponent_hand_and_puts_selected_card_on_deck_bottom() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var purrloin := _slot(_load_card("139"))
	state.players[0].active_pokemon = purrloin
	var first := _hand_card("First Hand", 1)
	var selected := _hand_card("Selected Hand", 1)
	var top := _hand_card("Deck Top", 1)
	state.players[1].hand = [first, selected]
	state.players[1].deck = [top]
	processor.register_pokemon_card(purrloin.get_card_data())
	var effect: BaseEffect = processor.get_attack_effects_for_slot(purrloin, 0)[0]
	var steps := effect.get_attack_interaction_steps(purrloin.get_top_card(), purrloin.get_card_data().attacks[0], state)
	processor.execute_attack_effect(purrloin, 0, state.players[1].active_pokemon, state, [{"csv10c_opponent_hand_to_bottom": [selected]}])
	return run_checks([
		assert_eq(steps[0].get("visible_scope", "") if not steps.is_empty() else "", "opponent_hand_revealed", "CSV10C_139 should reveal the opponent hand to the attacker"),
		assert_eq(state.players[1].hand, [first], "CSV10C_139 should remove the selected hand card"),
		assert_eq(state.players[1].deck, [top, selected], "CSV10C_139 should place the selected card on the bottom without shuffling"),
	])


func test_csv10c_140_adds_40_only_against_pokemon_ex() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var purrloin := _slot(_load_card("140"))
	state.players[0].active_pokemon = purrloin
	processor.register_pokemon_card(purrloin.get_card_data())
	state.players[1].active_pokemon = _pokemon("Defender ex", "ex", 1)
	var versus_ex := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(purrloin, 0):
		if effect.has_method("get_damage_bonus"):
			versus_ex += int(effect.call("get_damage_bonus", purrloin, state))
	state.players[1].active_pokemon = _pokemon("Plain Defender", "", 1)
	var versus_plain := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(purrloin, 0):
		if effect.has_method("get_damage_bonus"):
			versus_plain += int(effect.call("get_damage_bonus", purrloin, state))
	return run_checks([
		assert_eq(versus_ex, 40, "CSV10C_140 should add 40 against Pokemon ex"),
		assert_eq(versus_plain, 0, "CSV10C_140 should not add damage against a non-ex Pokemon"),
	])
