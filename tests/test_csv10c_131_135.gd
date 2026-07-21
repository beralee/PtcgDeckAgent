class_name TestCSV10C131To135
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, attacks: Array[Dictionary] = []) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "D"
	card.hp = 300
	if attacks.is_empty():
		card.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	else:
		card.attacks.assign(attacks)
	return card


func _trainer(name: String, card_type: String = "Supporter") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 10
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		state.players.append(player)
	return state


func test_csv10c_131_to_135_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(131, 136):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["131"].effect_id), "CSV10C_131 should register delayed discard"),
		assert_true(processor.has_attack_effect(cards["132"].effect_id), "CSV10C_132 should register both attacks"),
		assert_true(processor.has_effect(cards["133"].effect_id), "CSV10C_133 should register its reactive Ability"),
		assert_true(processor.has_attack_effect(cards["134"].effect_id), "CSV10C_134 should register field-name scaling"),
		assert_true(processor.has_attack_effect(cards["135"].effect_id), "CSV10C_135 should register search and chosen-attack lock"),
	])


func test_csv10c_131_discards_defender_and_all_attached_cards_at_end_of_next_opponent_turn() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var grimer := _slot(_load_card("131"))
	state.players[0].active_pokemon = grimer
	var defender := state.players[1].active_pokemon
	var evolution := CardInstance.create(_pokemon("Defender Evolution"), 1)
	var energy := CardInstance.create(_trainer("Fixture Energy", "Basic Energy"), 1)
	var tool := CardInstance.create(_trainer("Fixture Tool", "Tool"), 1)
	defender.pokemon_stack.append(evolution)
	defender.attached_energy = [energy]
	defender.attached_tool = tool
	processor.register_pokemon_card(grimer.get_card_data())
	processor.execute_attack_effect(grimer, 0, defender, state)
	processor.process_pokemon_check(state)
	var survives_attacking_turn := state.players[1].active_pokemon == defender
	state.turn_number += 1
	state.current_player_index = 1
	processor.process_pokemon_check(state)
	return run_checks([
		assert_true(survives_attacking_turn, "CSV10C_131 delayed effect should not discard the defender during the attacker's turn"),
		assert_eq(state.players[1].active_pokemon, null, "CSV10C_131 should remove the affected Active Pokemon at the end of its controller's next turn"),
		assert_true(evolution in state.players[1].discard_pile and energy in state.players[1].discard_pile and tool in state.players[1].discard_pile, "CSV10C_131 should discard the Pokemon stack and every attached card"),
	])


func test_csv10c_132_confuses_locks_retreat_and_scales_with_each_special_condition() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var muk := _slot(_load_card("132"))
	state.players[0].active_pokemon = muk
	var defender := state.players[1].active_pokemon
	processor.register_pokemon_card(muk.get_card_data())
	processor.execute_attack_effect(muk, 0, defender, state)
	defender.set_status("poisoned", true)
	defender.set_status("burned", true)
	var bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(muk, 1):
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", muk, state))
	return run_checks([
		assert_true(defender.status_conditions.get("confused", false), "CSV10C_132 first attack should Confuse the defender"),
		assert_true(defender.effects.any(func(entry: Dictionary) -> bool: return entry.get("type", "") == "retreat_lock"), "CSV10C_132 first attack should lock retreat next turn"),
		assert_eq(bonus, 200, "CSV10C_132 second attack should add 200 to its printed 100 for 3 Special Conditions"),
	])


func test_csv10c_133_reactive_ability_benches_up_to_two_named_koffing_after_active_attack_damage() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var koffing := _slot(_load_card("133"))
	state.players[0].active_pokemon = koffing
	var first := CardInstance.create(_pokemon("火箭队的瓦斯弹"), 0)
	var second := CardInstance.create(_pokemon("瓦斯弹 特别插画"), 0)
	var unrelated := CardInstance.create(_pokemon("Unrelated"), 0)
	state.players[0].deck = [first, unrelated, second]
	processor.register_pokemon_card(koffing.get_card_data())
	var ability := processor.get_effect(koffing.get_card_data().effect_id)
	var steps: Array[Dictionary] = ability.call("get_reactive_interaction_steps", koffing, state.players[1].active_pokemon, state) if ability != null else []
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm.effect_processor.register_pokemon_card(koffing.get_card_data())
	var gsm_steps := gsm.get_post_damage_defender_interaction_steps(state.players[1].active_pokemon, koffing)
	processor.process_after_attack_damage(koffing, state.players[1].active_pokemon, 30, state, [{"csv10c_reactive_named_bench_search": [first, second]}])
	gsm.prepare_for_disposal()
	return run_checks([
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1, 1], "CSV10C_133 should show the full deck while enabling only matching Koffing cards"),
		assert_eq(int(steps[0].get("chooser_player_index", -1)) if not steps.is_empty() else -1, 0, "CSV10C_133 reactive UI must be controlled by the damaged Pokemon's owner"),
		assert_eq(gsm_steps[0].get("card_indices", []) if not gsm_steps.is_empty() else [], [0, -1, 1], "CSV10C_133 GameStateMachine bridge should expose the same full-deck reactive search UI"),
		assert_eq(state.players[0].bench.size(), 2, "CSV10C_133 should Bench up to 2 matching Koffing from the deck"),
		assert_eq(state.players[0].bench[0].get_top_card(), first, "CSV10C_133 should preserve deck selection order"),
		assert_eq(state.players[0].bench[1].get_top_card(), second, "CSV10C_133 should match names containing Koffing"),
		assert_true(unrelated in state.players[0].deck, "CSV10C_133 should leave unrelated deck cards untouched"),
	])


func test_csv10c_134_counts_named_pokemon_on_both_fields() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var weezing := _slot(_load_card("134"))
	state.players[0].active_pokemon = weezing
	state.players[0].bench = [_slot(_pokemon("火箭队的瓦斯弹"))]
	state.players[1].active_pokemon = _slot(_pokemon("瓦斯弹"), 1)
	state.players[1].bench = [_slot(_pokemon("双弹瓦斯 ex"), 1), _slot(_pokemon("Unrelated"), 1)]
	processor.register_pokemon_card(weezing.get_card_data())
	var bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(weezing, 0):
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", weezing, state))
	return assert_eq(bonus, 120, "CSV10C_134 should add 120 to printed 40 when 4 matching Pokemon are in play")


func test_csv10c_135_searches_full_deck_for_supporter_and_locks_selected_defender_attack() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var murkrow := _slot(_load_card("135"))
	state.players[0].active_pokemon = murkrow
	var item := CardInstance.create(_trainer("Fixture Item", "Item"), 0)
	var supporter := CardInstance.create(_trainer("Fixture Supporter"), 0)
	state.players[0].deck = [item, supporter]
	var defender_attacks: Array[Dictionary] = [
		{"name": "First Attack", "cost": "", "damage": "10", "text": "", "is_vstar_power": false},
		{"name": "Second Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false},
	]
	state.players[1].active_pokemon = _slot(_pokemon("Two Attack Defender", defender_attacks), 1)
	processor.register_pokemon_card(murkrow.get_card_data())
	var first_steps: Array[Dictionary] = []
	for effect: BaseEffect in processor.get_attack_effects_for_slot(murkrow, 0):
		first_steps.append_array(effect.get_attack_interaction_steps(murkrow.get_top_card(), murkrow.get_card_data().attacks[0], state))
	processor.execute_attack_effect(murkrow, 0, state.players[1].active_pokemon, state, [{"search_cards": [supporter]}])
	var lock_steps: Array[Dictionary] = []
	for effect: BaseEffect in processor.get_attack_effects_for_slot(murkrow, 1):
		lock_steps.append_array(effect.get_attack_interaction_steps(murkrow.get_top_card(), murkrow.get_card_data().attacks[1], state))
	processor.execute_attack_effect(murkrow, 1, state.players[1].active_pokemon, state, [{"defender_attack_name_lock": ["Second Attack"]}])
	var lock: Dictionary = {}
	for entry: Dictionary in state.players[1].active_pokemon.effects:
		if entry.get("type", "") == "defender_attack_lock":
			lock = entry
	state.players[1].active_pokemon.effects.clear()
	var mist_data := _trainer("Mist Energy", "Special Energy")
	mist_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	state.players[1].active_pokemon.attached_energy = [CardInstance.create(mist_data, 1)]
	processor.execute_attack_effect(murkrow, 1, state.players[1].active_pokemon, state, [{"defender_attack_name_lock": ["First Attack"]}])
	return run_checks([
		assert_eq(first_steps[0].get("card_indices", []) if not first_steps.is_empty() else [], [-1, 0], "CSV10C_135 should expose the full deck and enable only Supporters"),
		assert_true(supporter in state.players[0].hand and item in state.players[0].deck, "CSV10C_135 should put only the selected Supporter into hand"),
		assert_eq(lock.get("attack_name", ""), "Second Attack", "CSV10C_135 should lock the explicitly selected defender attack"),
		assert_false(bool(lock_steps[0].get("allow_cancel", true)) if not lock_steps.is_empty() else true, "CSV10C_135 UI should require selecting one defender attack"),
		assert_false(state.players[1].active_pokemon.effects.any(func(entry: Dictionary) -> bool: return entry.get("type", "") == "defender_attack_lock"), "CSV10C_135 should respect Mist Energy attack-effect protection"),
	])
