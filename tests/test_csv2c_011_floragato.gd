class_name TestCSV2C011Floragato
extends TestBase

const SWITCH_EFFECT_FILE := "AttackSwitchOpponentActive.gd"


func test_magic_whip_registers_only_second_attack() -> String:
	var floragato: CardData = CardDatabase.get_card("CSV2C", "011")
	if floragato == null:
		return assert_not_null(floragato, "CSV2C_011 should exist in the bundled card database")

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(floragato)
	var attacker := _slot(floragato, 0)
	var first_attack_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var second_attack_effects := processor.get_attack_effects_for_slot(attacker, 1)

	return run_checks([
		assert_false(_has_effect_script(first_attack_effects, SWITCH_EFFECT_FILE), "Seed Bomb should not inherit Magic Whip's switch effect"),
		assert_true(_has_effect_script(second_attack_effects, SWITCH_EFFECT_FILE), "Magic Whip should register the opponent-switch attack effect"),
	])


func test_magic_whip_prompts_opponent_and_switches_selected_bench_to_active() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var floragato: CardData = CardDatabase.get_card("CSV2C", "011")
	if floragato == null:
		return assert_not_null(floragato, "CSV2C_011 should exist in the bundled card database")

	var attacker := _slot(floragato, 0)
	player.active_pokemon = attacker
	var old_active := opponent.active_pokemon
	var chosen_bench := opponent.bench[1]
	var unchosen_bench := opponent.bench[0]

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(floragato)
	var effects := processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), floragato.attacks[1], state))
	processor.execute_attack_effect(attacker, 1, old_active, state, [{
		"opponent_switch_target": [chosen_bench],
	}])

	return run_checks([
		assert_true(processor.has_attack_effect(floragato.effect_id), "CSV2C_011 should register an attack effect by effect_id"),
		assert_eq(steps.size(), 1, "Magic Whip should ask the opponent to choose one Benched Pokemon"),
		assert_eq(str(steps[0].get("id", "")), "opponent_switch_target", "Magic Whip should use the shared opponent-switch prompt id"),
		assert_true(bool(steps[0].get("opponent_chooses", false)), "Magic Whip's choice should belong to the opponent"),
		assert_eq(opponent.active_pokemon, chosen_bench, "Magic Whip should move the chosen opponent Bench Pokemon Active"),
		assert_contains(opponent.bench, old_active, "Magic Whip should move the old opponent Active Pokemon to the Bench"),
		assert_contains(opponent.bench, unchosen_bench, "Magic Whip should leave the unchosen Bench Pokemon on the Bench"),
	])


func test_magic_whip_does_nothing_without_opponent_bench() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	opponent.bench.clear()
	var floragato: CardData = CardDatabase.get_card("CSV2C", "011")
	if floragato == null:
		return assert_not_null(floragato, "CSV2C_011 should exist in the bundled card database")

	var attacker := _slot(floragato, 0)
	player.active_pokemon = attacker
	var old_active := opponent.active_pokemon
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(floragato)
	var effects := processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), floragato.attacks[1], state))
	processor.execute_attack_effect(attacker, 1, old_active, state)

	return run_checks([
		assert_eq(steps.size(), 0, "Magic Whip should not prompt when the opponent has no Bench Pokemon"),
		assert_eq(opponent.active_pokemon, old_active, "Magic Whip should leave the opponent Active Pokemon unchanged with no Bench"),
	])


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot(_pokemon("Active %d" % pi, "C"), pi)
		player.bench.append(_slot(_pokemon("Bench %d A" % pi, "C"), pi))
		player.bench.append(_slot(_pokemon("Bench %d B" % pi, "C"), pi))
		state.players.append(player)
	return state


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = 100
	cd.energy_type = energy_type
	return cd


func _has_effect_script(effects: Array[BaseEffect], file_name: String) -> bool:
	for effect: BaseEffect in effects:
		if effect == null or effect.get_script() == null:
			continue
		if str(effect.get_script().resource_path).get_file() == file_name:
			return true
	return false
