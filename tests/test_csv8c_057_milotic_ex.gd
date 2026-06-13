class_name TestCSV8C057MiloticEx
extends TestBase

const MILOTIC_EFFECT_ID := "57e95f8cb1129f6b45b7bbbc1a45b643"


func test_csv8c_057_shimmering_scales_prevents_tera_attack_damage() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var tera_attacker := _make_slot(_make_attacker_data("Tera Attacker", "tera_damage", true), 0)
	var milotic := _make_slot(_make_milotic_data(), 1)
	state.players[0].active_pokemon = tera_attacker
	state.players[1].active_pokemon = milotic
	gsm.effect_processor.register_pokemon_card(milotic.get_card_data())

	var attack_ok := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(attack_ok, "Tera attacker should still be able to use the attack"),
		assert_true(gsm.effect_processor.has_effect(MILOTIC_EFFECT_ID), "CSV8C_057 should register Shimmering Scales as a passive Ability"),
		assert_eq(milotic.damage_counters, 0, "CSV8C_057 should prevent damage from attacks used by opponent Tera Pokemon"),
	])


func test_csv8c_057_shimmering_scales_does_not_block_non_tera_attack_damage() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var attacker := _make_slot(_make_attacker_data("Normal Attacker", "normal_damage", false), 0)
	var milotic := _make_slot(_make_milotic_data(), 1)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = milotic
	gsm.effect_processor.register_pokemon_card(milotic.get_card_data())

	var attack_ok := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(attack_ok, "Non-Tera attacker should be able to use the attack"),
		assert_eq(milotic.damage_counters, 120, "CSV8C_057 should not prevent damage from non-Tera attackers"),
	])


func test_csv8c_057_shimmering_scales_prevents_tera_attack_status_effects() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var tera_attacker := _make_slot(_make_attacker_data("Tera Sleeper", "tera_sleep", true), 0)
	var normal_attacker := _make_slot(_make_attacker_data("Normal Sleeper", "normal_sleep", false), 0)
	var milotic := _make_slot(_make_milotic_data(), 1)
	state.players[0].active_pokemon = tera_attacker
	state.players[1].active_pokemon = milotic
	processor.register_pokemon_card(milotic.get_card_data())
	processor.register_attack_effect("tera_sleep", EffectApplyStatus.new("asleep", false, 0))
	processor.register_attack_effect("normal_sleep", EffectApplyStatus.new("asleep", false, 0))

	processor.execute_attack_effect(tera_attacker, 0, milotic, state)
	var tera_blocked := not bool(milotic.status_conditions.get("asleep", false))
	processor.execute_attack_effect(normal_attacker, 0, milotic, state)
	var normal_applied := bool(milotic.status_conditions.get("asleep", false))

	return run_checks([
		assert_true(tera_blocked, "CSV8C_057 should prevent effects from attacks used by opponent Tera Pokemon"),
		assert_true(normal_applied, "CSV8C_057 should not prevent attack effects from non-Tera Pokemon"),
	])


func test_csv8c_057_hypno_splash_applies_sleep() -> String:
	var processor := EffectProcessor.new()
	var state := _make_state()
	var milotic := _make_slot(_make_milotic_data(), 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = milotic
	processor.register_pokemon_card(milotic.get_card_data())

	processor.execute_attack_effect(milotic, 0, defender, state)

	return run_checks([
		assert_true(processor.has_attack_effect(MILOTIC_EFFECT_ID), "CSV8C_057 should register Hypno Splash's sleep effect"),
		assert_true(defender.status_conditions.get("asleep", false), "CSV8C_057 Hypno Splash should make the opponent Active Pokemon Asleep"),
	])


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
		player.active_pokemon = _make_slot(_make_basic_data("Active%d" % pi, "C"), pi)
		state.players.append(player)
	return state


func _make_milotic_data() -> CardData:
	var cd := _make_basic_data("Milotic ex", "W")
	cd.stage = "Stage 1"
	cd.hp = 270
	cd.mechanic = "ex"
	cd.effect_id = MILOTIC_EFFECT_ID
	cd.evolves_from = "Feebas"
	cd.abilities = [{"name": "Shimmering Scales", "text": "Prevent all damage and effects from attacks used by your opponent's Tera Pokemon."}]
	cd.attacks = [{"name": "Hypno Splash", "cost": "WCC", "damage": "160", "text": "Your opponent's Active Pokemon is now Asleep.", "is_vstar_power": false}]
	return cd


func _make_attacker_data(name: String, effect_id: String, is_tera: bool) -> CardData:
	var cd := _make_basic_data(name, "R")
	cd.hp = 220
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Strike", "cost": "", "damage": "120", "text": "", "is_vstar_power": false}]
	if is_tera:
		cd.ancient_trait = "Tera"
		cd.is_tags = PackedStringArray(["Tera"])
	return cd


func _make_basic_data(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.stage = "Basic"
	cd.hp = 100
	cd.retreat_cost = 1
	cd.attacks = [{"name": "Strike", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot
