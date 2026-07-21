class_name TestCSV10C116To120
extends TestBase


class RiggedCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(true)
		return true


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, stage: String = "Basic", card_type: String = "Pokemon") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.stage = stage
	card.hp = 140
	card.attacks = [{"name": "Fixture Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 5
	state.current_player_index = 0
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		state.players.append(player)
	return state


func test_csv10c_116_to_120_registry_contract() -> String:
	var processor := EffectProcessor.new(RiggedCoinFlipper.new())
	var checks: Array[String] = []
	for number: int in range(116, 121):
		var card := _load_card("%03d" % number)
		processor.register_pokemon_card(card)
		checks.append(assert_true(processor.has_attack_effect(card.effect_id), "CSV10C_%03d should register its scripted attack behavior" % number))
	return run_checks(checks)


func test_csv10c_116_searches_stadium_from_full_deck() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("116")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	var stadium := CardInstance.create(_pokemon("Fixture Stadium", "", "Stadium"), 0)
	var pokemon := CardInstance.create(_pokemon("Illegal Pokemon"), 0)
	state.players[0].deck = [stadium, pokemon]
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array[Dictionary] = []
	if not effects.is_empty():
		steps = effects[0].get_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{"search_cards": [stadium]}])
	return run_checks([
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1], "CSV10C_116 should reveal the full deck and enable only Stadium cards"),
		assert_true(stadium in state.players[0].hand, "CSV10C_116 should put the selected Stadium into hand"),
		assert_true(pokemon in state.players[0].deck, "CSV10C_116 should leave non-Stadium cards in deck"),
	])


func test_csv10c_117_locks_retreat_and_damages_each_own_bench() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("117")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	var bench_a := _slot(_pokemon("Own Bench A"))
	var bench_b := _slot(_pokemon("Own Bench B"))
	state.players[0].bench = [bench_a, bench_b]
	processor.register_pokemon_card(card)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state)
	processor.execute_attack_effect(attacker, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_true(state.players[1].active_pokemon.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("type", "")).contains("retreat")), "CSV10C_117 Earth Rumble should lock the defender's retreat"),
		assert_eq(bench_a.damage_counters, 20, "CSV10C_117 Earthquake should damage the first own Benched Pokemon by 20"),
		assert_eq(bench_b.damage_counters, 20, "CSV10C_117 Earthquake should damage every own Benched Pokemon by 20"),
		assert_eq(attacker.damage_counters, 0, "CSV10C_117 Earthquake should not damage the attacker"),
	])


func test_csv10c_118_recoil_and_119_attacker_chosen_gust() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card118 := _load_card("118")
	var toedscool := _slot(card118)
	processor.register_pokemon_card(card118)
	processor.execute_attack_effect(toedscool, 0, state.players[1].active_pokemon, state)
	var card119 := _load_card("119")
	var toedscruel := _slot(card119)
	state.players[0].active_pokemon = toedscruel
	var old_active := state.players[1].active_pokemon
	var bench_a := _slot(_pokemon("Opponent Bench A"), 1)
	var bench_b := _slot(_pokemon("Opponent Bench B"), 1)
	state.players[1].bench = [bench_a, bench_b]
	processor.register_pokemon_card(card119)
	var gust_effects := processor.get_attack_effects_for_slot(toedscruel, 0)
	var steps: Array[Dictionary] = []
	if not gust_effects.is_empty():
		steps = gust_effects[0].get_attack_interaction_steps(toedscruel.get_top_card(), card119.attacks[0], state)
	processor.execute_attack_effect(toedscruel, 0, old_active, state, [{"opponent_switch_target": [bench_b]}])
	var selected_bench_promoted := state.players[1].active_pokemon == bench_b
	processor.execute_attack_effect(toedscruel, 1, state.players[1].active_pokemon, state)
	var old_active_switched_to_bench := old_active in state.players[1].bench
	var protected_active := _slot(_pokemon("Mist-Protected Active"), 1)
	var protected_bench := _slot(_pokemon("Protected Bench"), 1)
	var mist_data := CardData.new()
	mist_data.name = "Mist Energy"
	mist_data.card_type = "Special Energy"
	mist_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	protected_active.attached_energy = [CardInstance.create(mist_data, 1)]
	state.players[1].active_pokemon = protected_active
	state.players[1].bench = [protected_bench]
	processor.execute_attack_effect(toedscruel, 0, protected_active, state, [{"opponent_switch_target": [protected_bench]}])
	return run_checks([
		assert_eq(toedscool.damage_counters, 10, "CSV10C_118 should deal 10 recoil"),
		assert_false(bool(steps[0].get("opponent_chooses", true)) if not steps.is_empty() else true, "CSV10C_119 Drag Off must let the attacking player choose the opponent Bench target"),
		assert_true(selected_bench_promoted, "CSV10C_119 should promote the selected opponent Benched Pokemon"),
		assert_true(old_active_switched_to_bench, "CSV10C_119 should move the old opponent Active to the Bench"),
		assert_eq(toedscruel.damage_counters, 30, "CSV10C_119 Assault should deal 30 recoil"),
		assert_eq(state.players[1].active_pokemon, protected_active, "CSV10C_119 should respect Mist Energy attack-effect protection"),
	])


func test_csv10c_120_paralyzes_only_on_heads() -> String:
	var state := _state()
	var processor := EffectProcessor.new(RiggedCoinFlipper.new())
	var card := _load_card("120")
	var attacker := _slot(card)
	processor.register_pokemon_card(card)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state)
	return assert_true(state.players[1].active_pokemon.status_conditions.get("paralyzed", false), "CSV10C_120 Hindering Bite should Paralyze on heads")
