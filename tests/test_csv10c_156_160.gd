class_name TestCSV10C156To160
extends TestBase


class HeadsCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(true)
		return true


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "M"
	data.hp = 300
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _energy(owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = "Metal Energy"
	data.card_type = "Basic Energy"
	data.energy_type = "M"
	data.energy_provides = "M"
	return CardInstance.create(data, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 20
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_156_to_160_registry_contract() -> String:
	var processor := EffectProcessor.new(HeadsCoinFlipper.new())
	var cards: Dictionary = {}
	for number: int in range(156, 161):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["156"].effect_id), "CSV10C_156 should register 2 coin flips"),
		assert_true(processor.has_attack_effect(cards["157"].effect_id), "CSV10C_157 should register Confusion"),
		assert_true(processor.has_attack_effect(cards["158"].effect_id), "CSV10C_158 should register 3 coin flips"),
		assert_true(processor.has_effect(cards["159"].effect_id), "CSV10C_159 should register Active attachment healing"),
		assert_true(processor.has_attack_effect(cards["159"].effect_id), "CSV10C_159 should register draw 2"),
		assert_true(processor.has_attack_effect(cards["160"].effect_id), "CSV10C_160 should register Bench damage and damage reduction"),
	])


func test_csv10c_156_two_heads_total_20_and_158_three_heads_total_360() -> String:
	var state := _state()
	var processor := EffectProcessor.new(HeadsCoinFlipper.new())
	var klink := _slot(_load_card("156"))
	state.players[0].active_pokemon = klink
	processor.register_pokemon_card(klink.get_card_data())
	state.players[1].active_pokemon.damage_counters = 10
	processor.execute_attack_effect(klink, 0, state.players[1].active_pokemon, state)
	var two_heads_total := state.players[1].active_pokemon.damage_counters

	var klinklang := _slot(_load_card("158"))
	state.players[0].active_pokemon = klinklang
	processor.register_pokemon_card(klinklang.get_card_data())
	state.players[1].active_pokemon.damage_counters = 120
	processor.execute_attack_effect(klinklang, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(two_heads_total, 20, "CSV10C_156 should total 20 with 2 heads, replacing printed 10x base"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 360, "CSV10C_158 should total 360 with 3 heads, replacing printed 120x base"),
	])


func test_csv10c_157_first_attack_confuses_defender() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var klang := _slot(_load_card("157"))
	state.players[0].active_pokemon = klang
	processor.register_pokemon_card(klang.get_card_data())
	processor.execute_attack_effect(klang, 0, state.players[1].active_pokemon, state)
	return assert_true(state.players[1].active_pokemon.status_conditions.get("confused", false), "CSV10C_157 should Confuse with attack 0")


func test_csv10c_159_real_hand_attachment_hook_heals_target_90_while_magearna_active_and_attack_draws_two() -> String:
	var gsm := GameStateMachine.new()
	var state := _state()
	gsm.game_state = state
	var magearna := _slot(_load_card("159"))
	state.players[0].active_pokemon = magearna
	var target := _pokemon("Damaged Target")
	target.damage_counters = 120
	state.players[0].bench = [target]
	var energy := _energy()
	state.players[0].hand = [energy]
	var draw_one := _energy()
	var draw_two := _energy()
	state.players[0].deck = [draw_one, draw_two]
	gsm.effect_processor.register_pokemon_card(magearna.get_card_data())
	var attached := gsm.attach_energy(0, energy, target)
	gsm.effect_processor.execute_attack_effect(magearna, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_true(attached, "CSV10C_159 test should attach Energy through the real GameStateMachine path"),
		assert_eq(target.damage_counters, 30, "CSV10C_159 should heal the Energy attachment target by 90"),
		assert_eq(state.players[0].hand, [draw_one, draw_two], "CSV10C_159 attack should draw 2 cards"),
	])


func test_csv10c_160_targets_one_bench_for_50_and_second_attack_reduces_incoming_60() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var corviknight := _slot(_load_card("160"))
	state.players[0].active_pokemon = corviknight
	var first := _pokemon("First Bench", 1)
	var selected := _pokemon("Selected Bench", 1)
	state.players[1].bench = [first, selected]
	processor.register_pokemon_card(corviknight.get_card_data())
	processor.execute_attack_effect(corviknight, 0, state.players[1].active_pokemon, state, [{"bench_target": [selected]}])
	processor.execute_attack_effect(corviknight, 1, state.players[1].active_pokemon, state)
	var reduction: Dictionary = {}
	for entry: Dictionary in corviknight.effects:
		if entry.get("type", "") == "reduce_damage_next_turn":
			reduction = entry
	return run_checks([
		assert_eq(first.damage_counters, 0, "CSV10C_160 should honor the selected Bench target"),
		assert_eq(selected.damage_counters, 50, "CSV10C_160 should deal 50 to the selected Bench Pokemon"),
		assert_eq(reduction.get("amount", 0), 60, "CSV10C_160 should reduce incoming attack damage by 60 next opponent turn"),
	])
