extends TestBase

const Fixtures = preload("res://tests/test_30thdc_cards.gd")


func test_real_snorunt_ice_shard_checks_active_type_and_water_payment() -> String:
	var fixture := Fixtures.new()
	var checks: Array[String] = []
	for seat: int in 2:
		for defender_type: String in ["F", "W"]:
			var gsm = fixture._battle("008")
			var state = gsm.game_state
			state.current_player_index = seat
			var card := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV6C_032.json")))
			var attacker := PokemonSlot.new()
			attacker.pokemon_stack.append(CardInstance.create(card, seat))
			state.players[seat].active_pokemon = attacker
			var water := CardData.new()
			water.card_type = "Basic Energy"
			water.energy_type = "W"
			water.energy_provides = "W"
			var defender = state.players[1 - seat].active_pokemon
			defender.get_card_data().hp = 1000
			defender.get_card_data().energy_type = defender_type
			defender.get_card_data().weakness_energy = ""
			defender.get_card_data().resistance_energy = ""
			var bench = fixture._slot("005", 1 - seat)
			bench.get_card_data().energy_type = "F"
			state.players[1 - seat].bench.assign([bench])
			gsm.effect_processor.register_pokemon_card(card)
			checks.append(assert_false(gsm.use_attack(seat, 0), "Printed Water cost is required"))
			attacker.attached_energy.append(CardInstance.create(water, seat))
			checks.append(assert_true(gsm.use_attack(seat, 0), "Real registered attack is playable"))
			checks.append(assert_eq(defender.damage_counters, 40 if defender_type == "F" else 10, "Only the opponent Active type enables the 30 bonus"))
			checks.append(assert_eq(bench.damage_counters, 0, "The bench is not attacked"))
			gsm.prepare_for_disposal()
	return run_checks(checks)
