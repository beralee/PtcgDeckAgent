class_name TestMunkidoriLuminousEnergy
extends TestBase

const AbilityMoveDamageCountersToOpponent = preload("res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd")


func _make_basic_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Test Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.effect_id = effect_id
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_basic_pokemon_data("Active%d" % pi, "P", 120), pi)
		for bi: int in 2:
			player.bench.append(_make_slot(_make_basic_pokemon_data("Bench%d_%d" % [pi, bi], "P", 90), pi))
		state.players.append(player)
	return state


func test_munkidori_luminous_energy_counts_as_dark() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var munki_cd := _make_basic_pokemon_data("Munkidori", "P", 110, "Basic", "", "66fee12502043db7d92b97b0d62b0f59")
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Luminous Energy", "", "Special Energy", "540ee48bb93584e4bfe3d7f5d0ee0efc"), 0))
	player.active_pokemon = munki_slot
	player.active_pokemon.damage_counters = 30

	var effect := AbilityMoveDamageCountersToOpponent.new(3)
	return run_checks([
		assert_true(effect.can_use_ability(munki_slot, state), "Munkidori should treat Luminous Energy as attached Dark Energy"),
	])


func test_munkidori_luminous_energy_downgrades_with_other_special_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var munki_cd := _make_basic_pokemon_data("Munkidori", "P", 110, "Basic", "", "66fee12502043db7d92b97b0d62b0f59")
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Luminous Energy", "", "Special Energy", "540ee48bb93584e4bfe3d7f5d0ee0efc"), 0))
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("Gift Energy", "", "Special Energy", "e743e30dbebcadb0d15f5538198c2861"), 0))
	player.active_pokemon = munki_slot
	player.active_pokemon.damage_counters = 30

	var effect := AbilityMoveDamageCountersToOpponent.new(3)
	return run_checks([
		assert_false(effect.can_use_ability(munki_slot, state), "Luminous Energy should downgrade to Colorless when another Special Energy is attached"),
	])
