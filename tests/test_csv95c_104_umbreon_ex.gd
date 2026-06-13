class_name TestCsv95c104UmbreonEx
extends TestBase

const EFFECT_ID := "233350ffecdbfac2a8fab27e7f7da282"


func test_csv95c_104_registry_maps_both_attacks() -> String:
	var processor := EffectProcessor.new()
	var umbreon := _umbreon_ex_data()
	processor.register_pokemon_card(umbreon)
	var effects := processor.get_attack_effects_for_slot(_make_slot(umbreon, 0), 0)
	var second_attack_effects := processor.get_attack_effects_for_slot(_make_slot(umbreon, 0), 1)

	return run_checks([
		assert_true(processor.has_attack_effect(EFFECT_ID), "CSV9.5C_104 should register attack effects by API effect_id"),
		assert_eq(effects.size(), 1, "Moon Mirage should have exactly one registered status effect"),
		assert_eq(second_attack_effects.size(), 1, "Onyx should have exactly one registered prize-taking effect"),
	])


func test_csv95c_104_moon_mirage_confuses_only_on_first_attack() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var umbreon := _umbreon_ex_data()
	processor.register_pokemon_card(umbreon)
	var attacker := _make_slot(umbreon, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = attacker
	state.shared_turn_flags["_draw_effect_processor"] = processor

	processor.execute_attack_effect(attacker, 0, defender, state)
	var confused_after_first := bool(defender.status_conditions.get("confused", false))
	defender.status_conditions.clear()
	processor.execute_attack_effect(attacker, 1, defender, state)
	var confused_after_second := bool(defender.status_conditions.get("confused", false))

	return run_checks([
		assert_true(confused_after_first, "Moon Mirage should confuse the opponent's Active Pokemon"),
		assert_false(confused_after_second, "Onyx should not also apply Moon Mirage's Confused status"),
	])


func test_csv95c_104_onyx_discards_all_self_energy_and_takes_one_prize() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var processor := EffectProcessor.new()
	var umbreon := _umbreon_ex_data()
	processor.register_pokemon_card(umbreon)
	var attacker := _make_slot(umbreon, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = attacker
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var dark_energy := CardInstance.create(_make_energy_data("Darkness Energy", "D"), 0)
	var lightning_energy := CardInstance.create(_make_energy_data("Lightning Energy", "L"), 0)
	var psychic_energy := CardInstance.create(_make_energy_data("Psychic Energy", "P"), 0)
	attacker.attached_energy.append_array([dark_energy, lightning_energy, psychic_energy])
	var first_prize := CardInstance.create(_make_trainer_data("Prize One"), 0)
	var second_prize := CardInstance.create(_make_trainer_data("Prize Two"), 0)
	player.set_prizes([first_prize, second_prize])

	processor.execute_attack_effect(attacker, 1, defender, state)

	return run_checks([
		assert_eq(attacker.attached_energy.size(), 0, "Onyx should discard every Energy attached to Umbreon ex"),
		assert_true(dark_energy in player.discard_pile, "Onyx should discard Darkness Energy from itself"),
		assert_true(lightning_energy in player.discard_pile, "Onyx should discard Lightning Energy from itself"),
		assert_true(psychic_energy in player.discard_pile, "Onyx should discard Psychic Energy from itself"),
		assert_eq(player.prizes.size(), 1, "Onyx should take exactly one Prize card"),
		assert_true(first_prize in player.hand, "Onyx should put the taken Prize card into the player's hand"),
		assert_false(second_prize in player.hand, "Onyx should leave the second Prize card in prizes"),
		assert_eq(player.get_prize_layout()[0], null, "Onyx should clear the taken prize slot from the layout"),
	])


func test_csv95c_104_onyx_does_not_fire_on_moon_mirage() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var processor := EffectProcessor.new()
	var umbreon := _umbreon_ex_data()
	processor.register_pokemon_card(umbreon)
	var attacker := _make_slot(umbreon, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = attacker
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var dark_energy := CardInstance.create(_make_energy_data("Darkness Energy", "D"), 0)
	attacker.attached_energy.append(dark_energy)
	var prize := CardInstance.create(_make_trainer_data("Prize"), 0)
	player.set_prizes([prize])

	processor.execute_attack_effect(attacker, 0, defender, state)

	return run_checks([
		assert_eq(attacker.attached_energy.size(), 1, "Moon Mirage should not discard Umbreon ex's Energy"),
		assert_false(dark_energy in player.discard_pile, "Moon Mirage should not move attached Energy to discard"),
		assert_eq(player.prizes.size(), 1, "Moon Mirage should not take a Prize card"),
		assert_false(prize in player.hand, "Moon Mirage should leave Prize cards in prizes"),
	])


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.ATTACK
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_data("Active %d" % pi, "Basic", "", "C", 100, ""), pi)
		state.players.append(player)
	return state


func _umbreon_ex_data() -> CardData:
	var cd := _make_pokemon_data("Umbreon ex", "Stage 1", "Eevee", "D", 280, "ex")
	cd.effect_id = EFFECT_ID
	cd.ancient_trait = "Tera"
	cd.attacks = [
		{"name": "Moon Mirage", "text": "Confuse the opponent's Active Pokemon.", "cost": "DCC", "damage": "160", "is_vstar_power": false},
		{"name": "Onyx", "text": "Discard all Energy from this Pokemon, and take 1 Prize card.", "cost": "LPD", "damage": "", "is_vstar_power": false},
	]
	return cd


func _make_pokemon_data(
	name: String,
	stage: String,
	evolves_from: String,
	energy_type: String,
	hp: int,
	mechanic: String
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.evolves_from = evolves_from
	cd.energy_type = energy_type
	cd.hp = hp
	cd.mechanic = mechanic
	return cd


func _make_energy_data(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd


func _make_trainer_data(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Item"
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot
