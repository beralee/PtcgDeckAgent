class_name TestPlayerFeedbackCards20260829
extends TestBase

const OKIDOGI_EFFECT_ID := "cc0285c411d9f2c4d7c3f0c486cd2667"
const LUMINOUS_ENERGY_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"
const ARBOLIVA_EX_EFFECT_ID := "158981f07985a13c7ea6990821377019"
const GRENINJA_EX_EFFECT_ID := "5d5d2589f2d9c19ef7364714766600d4"
const SPARKLING_CRYSTAL_EFFECT_ID := "12164ed03296d2df4ef6d0fa8b5f8aae"


func test_csv95c_101_okidogi_adrenaline_power_accepts_luminous_energy() -> String:
	var okidogi := _load_card("res://data/bundled_user/cards/CSV9.5C_101.json")
	var luminous_data := _load_card("res://data/bundled_user/cards/CSV1C_127.json")
	if okidogi == null or luminous_data == null:
		return "Okidogi and Luminous Energy bundled cards should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(okidogi)
	var state := _make_state()
	var okidogi_slot := _slot(okidogi, 0)
	state.players[0].active_pokemon = okidogi_slot
	var luminous := CardInstance.create(luminous_data, 0)
	okidogi_slot.attached_energy = [luminous]

	var luminous_type := processor.get_energy_type(luminous, state)
	var boosted_hp := processor.get_effective_max_hp(okidogi_slot, state)
	var boosted_damage := processor.get_attacker_modifier(
		okidogi_slot,
		state,
		state.players[1].active_pokemon
	)
	var other_special := _energy("Other Special Energy", "C", 0, "Special Energy")
	okidogi_slot.attached_energy.append(other_special)
	var downgraded_type := processor.get_energy_type(luminous, state)
	var downgraded_hp := processor.get_effective_max_hp(okidogi_slot, state)
	var downgraded_damage := processor.get_attacker_modifier(
		okidogi_slot,
		state,
		state.players[1].active_pokemon
	)

	return run_checks([
		assert_eq(okidogi.effect_id, OKIDOGI_EFFECT_ID, "Okidogi should retain its stable effect id"),
		assert_eq(luminous_data.effect_id, LUMINOUS_ENERGY_EFFECT_ID, "Luminous Energy should retain its stable effect id"),
		assert_eq(luminous_type, "ANY", "Luminous Energy alone should provide every Energy type"),
		assert_eq(boosted_hp, 230, "Luminous Energy alone should activate Okidogi's +100 HP"),
		assert_eq(boosted_damage, 100, "Luminous Energy alone should activate Okidogi's +100 Active damage"),
		assert_eq(downgraded_type, "C", "Another Special Energy should downgrade Luminous Energy to Colorless"),
		assert_eq(downgraded_hp, 130, "Downgraded Luminous Energy should no longer activate Adrenaline Power"),
		assert_eq(downgraded_damage, 0, "Downgraded Luminous Energy should no longer add damage"),
	])


func test_csv10c_022_arboliva_oil_machine_gun_accepts_player_ui_distribution() -> String:
	var arboliva := _load_card("res://data/bundled_user/cards/CSV10C_022.json")
	if arboliva == null:
		return "CSV10C_022 Arboliva ex bundled card should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var attacker := _slot(arboliva, 0)
	attacker.attached_energy = [_energy("Grass Energy", "G", 0)]
	state.players[0].active_pokemon = attacker
	var defender := state.players[1].active_pokemon
	var bench_target := state.players[1].bench[0]
	gsm.effect_processor.register_pokemon_card(arboliva)
	var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(
		attacker.get_top_card(),
		arboliva.attacks[0],
		state
	) if not effects.is_empty() else []
	var invalid_context := [{"repeated_target_damage": [
		{"target": defender, "amount": 50},
	]}]
	var invalid_allowed := gsm.effect_processor.validate_attack_effect_context(
		attacker,
		0,
		defender,
		state,
		invalid_context
	)
	var ui_context := [{"repeated_target_damage": [
		{"target": defender, "amount": 30},
		{"target": bench_target, "amount": 30},
	]}]
	var attack_used := gsm.use_attack(0, 0, ui_context)

	return run_checks([
		assert_eq(arboliva.effect_id, ARBOLIVA_EX_EFFECT_ID, "Arboliva ex should retain its shared effect id"),
		assert_eq(effects.size(), 1, "Oil Machine Gun should register exactly one attack effect"),
		assert_eq(int(steps[0].get("total_counters", 0)) if not steps.is_empty() else 0, 6, "The player UI should request all six selections"),
		assert_false(invalid_allowed, "An incomplete five-of-six UI distribution must be rejected before the attack"),
		assert_true(attack_used, "A complete player UI distribution should execute Oil Machine Gun"),
		assert_eq(defender.damage_counters, 60, "Three selections should deal 60 damage to the Active Pokemon"),
		assert_eq(bench_target.damage_counters, 60, "Three selections should deal 60 damage to the Benched Pokemon"),
	])


func test_csv10c_022_arboliva_aromatic_shot_executes_and_clears_status() -> String:
	var arboliva := _load_card("res://data/bundled_user/cards/CSV10C_022.json")
	if arboliva == null:
		return "CSV10C_022 Arboliva ex bundled card should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var attacker := _slot(arboliva, 0)
	attacker.attached_energy = [
		_energy("Grass A", "G", 0),
		_energy("Grass B", "G", 0),
		_energy("Grass C", "G", 0),
	]
	attacker.status_conditions["poisoned"] = true
	attacker.status_conditions["burned"] = true
	state.players[0].active_pokemon = attacker
	var defender := state.players[1].active_pokemon
	gsm.effect_processor.register_pokemon_card(arboliva)
	var unusable_reason := gsm.get_attack_unusable_reason(0, 1)
	var attack_used := gsm.use_attack(0, 1)

	return run_checks([
		assert_eq(unusable_reason, "", "Three attached Energy should pay Aromatic Shot"),
		assert_true(attack_used, "Aromatic Shot should execute through the production attack entry"),
		assert_eq(defender.damage_counters, 160, "Aromatic Shot should deal its printed 160 damage"),
		assert_false(attacker.status_conditions.get("poisoned", false), "Aromatic Shot should clear Poison"),
		assert_false(attacker.status_conditions.get("burned", false), "Aromatic Shot should clear Burn"),
	])


func test_csv7c_123_greninja_mirage_barrage_uses_two_energy_with_sparkling_crystal_cache_shape() -> String:
	var greninja := _load_card("res://data/bundled_user/cards/CSV7C_123.json")
	var sparkling_data := _load_card("res://data/bundled_user/cards/CSV8C_186.json")
	if greninja == null or sparkling_data == null:
		return "Greninja ex and Sparkling Crystal bundled cards should load"
	# Existing player caches can predate the Tera metadata migration. The stable
	# card identity still makes this a Tera Pokemon and must be enough for tools.
	greninja.ancient_trait = ""
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var attacker := _slot(greninja, 0)
	var water_a := _energy("Water A", "W", 0)
	var water_b := _energy("Water B", "W", 0)
	attacker.attached_energy = [water_a, water_b]
	attacker.attached_tool = CardInstance.create(sparkling_data, 0)
	state.players[0].active_pokemon = attacker
	var defender := state.players[1].active_pokemon
	var bench_target := state.players[1].bench[0]
	gsm.effect_processor.register_pokemon_card(greninja)
	var modifier := gsm.effect_processor.get_attack_any_cost_modifier(
		attacker,
		greninja.attacks[1],
		state
	)
	var unusable_reason := gsm.get_attack_unusable_reason(0, 1)
	var attack_context := [{
		"greninja_ex_discard_energy": [water_a, water_b],
		"greninja_ex_targets": [defender, bench_target],
	}]
	var attack_used := gsm.use_attack(0, 1, attack_context)

	return run_checks([
		assert_eq(greninja.effect_id, GRENINJA_EX_EFFECT_ID, "Greninja ex should retain its stable effect id"),
		assert_eq(sparkling_data.effect_id, SPARKLING_CRYSTAL_EFFECT_ID, "Sparkling Crystal should retain its stable effect id"),
		assert_true(greninja.is_tera_pokemon(), "The cached Greninja identity should still be recognized as Tera"),
		assert_eq(modifier, -1, "Sparkling Crystal should reduce cached Greninja ex's attack cost by one"),
		assert_eq(unusable_reason, "", "Two Water Energy plus Sparkling Crystal should pay Mirage Barrage"),
		assert_true(attack_used, "Mirage Barrage should execute through the production attack entry"),
		assert_true(water_a in state.players[0].discard_pile and water_b in state.players[0].discard_pile, "Mirage Barrage should discard both selected Energy"),
		assert_eq(defender.damage_counters, 120, "Mirage Barrage should deal 120 damage to the first target"),
		assert_eq(bench_target.damage_counters, 120, "Mirage Barrage should deal 120 damage to the second target"),
	])


func _load_card(path: String) -> CardData:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner, 400), owner)
		player.bench = [_slot(_pokemon("Bench %d" % owner, 400), owner)]
		player.deck = [_dummy_card("Deck %d" % owner, owner)]
		for prize_index: int in 6:
			player.prizes.append(_dummy_card("Prize %d-%d" % [owner, prize_index], owner))
		state.players.append(player)
	return state


func _pokemon(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.attacks = [{"name": "Strike", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _energy(name: String, energy_type: String, owner: int, card_type: String = "Basic Energy") -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner)


func _dummy_card(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, owner)
