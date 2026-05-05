class_name TestSpecialStatusRules
extends TestBase

const TM_DEVOLUTION_EFFECT_ID := "e228e825c541ce80e2507c557cb506c3"


class SequenceCoinFlipper extends CoinFlipper:
	var results: Array[bool] = []
	var index: int = 0

	func _init(sequence: Array[bool] = []) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		var result := true
		if index < results.size():
			result = results[index]
		index += 1
		coin_flipped.emit(result)
		return result


func _make_gsm(sequence: Array[bool] = []) -> GameStateMachine:
	var flipper := SequenceCoinFlipper.new(sequence)
	var gsm := GameStateMachine.new()
	gsm.coin_flipper = flipper
	gsm.effect_processor = EffectProcessor.new(flipper)
	gsm.effect_processor.bind_game_state_machine(gsm)
	gsm.game_state = GameState.new()
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	for pi: int in 2:
		gsm.game_state.players[pi].player_index = pi
		gsm.game_state.players[pi].active_pokemon = _make_slot(_make_pokemon("Active %d" % pi), pi)
		for i: int in 5:
			gsm.game_state.players[pi].deck.append(CardInstance.create(_make_pokemon("Deck %d-%d" % [pi, i]), pi))
	return gsm


func _make_pokemon(name: String, hp: int = 120, attacks: Array = []) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.energy_type = "C"
	card.retreat_cost = 1
	card.attacks.clear()
	for attack: Variant in attacks:
		if attack is Dictionary:
			card.attacks.append(attack as Dictionary)
	return card


func _make_attack(name: String = "Strike", cost: String = "C", damage: String = "50") -> Dictionary:
	return {
		"name": name,
		"cost": cost,
		"damage": damage,
		"text": "",
		"is_vstar_power": false,
	}


func _make_stage1(name: String, evolves_from: String, hp: int = 150) -> CardData:
	var card := _make_pokemon(name, hp)
	card.stage = "Stage 1"
	card.evolves_from = evolves_from
	return card


func _make_energy(name: String = "Colorless Energy", energy_type: String = "C") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _make_tool(name: String, effect_id: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Tool"
	card.effect_id = effect_id
	return card


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String = "C") -> CardInstance:
	var energy := CardInstance.create(_make_energy("%s Energy" % energy_type, energy_type), owner_index)
	slot.attached_energy.append(energy)
	return energy


func _attach_tm_devolution(slot: PokemonSlot, owner_index: int) -> void:
	slot.attached_tool = CardInstance.create(_make_tool("Technical Machine: Devolution", TM_DEVOLUTION_EFFECT_ID), owner_index)


func _make_evolved_defender(owner_index: int) -> PokemonSlot:
	var base := _make_pokemon("Base Defender", 120)
	var stage1 := _make_stage1("Stage1 Defender", "Base Defender", 160)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(base, owner_index))
	slot.pokemon_stack.append(CardInstance.create(stage1, owner_index))
	return slot


func _granted_attack(gsm: GameStateMachine, attacker: PokemonSlot) -> Dictionary:
	var attacks: Array[Dictionary] = gsm.effect_processor.get_granted_attacks(attacker, gsm.game_state)
	if attacks.is_empty():
		return {}
	return attacks[0]


func _has_action_kind(actions: Array[Dictionary], kind: String) -> bool:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == kind:
			return true
	return false


func _prepare_basic_attacker_gsm(sequence: Array[bool] = []) -> GameStateMachine:
	var gsm := _make_gsm(sequence)
	var attacker := _make_slot(_make_pokemon("Status Attacker", 120, [_make_attack()]), 0)
	var defender := _make_slot(_make_pokemon("Status Defender", 120), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(attacker, 0)
	return gsm


func _prepare_granted_attacker_gsm(sequence: Array[bool] = []) -> GameStateMachine:
	var gsm := _make_gsm(sequence)
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	gsm.game_state.players[1].active_pokemon = _make_evolved_defender(1)
	_attach_energy(attacker, 0)
	_attach_tm_devolution(attacker, 0)
	return gsm


func test_active_pokemon_check_applies_active_status_damage_and_recovery_flips() -> String:
	var gsm := _make_gsm([true, true])
	var active: PokemonSlot = gsm.game_state.players[0].active_pokemon
	active.status_conditions["poisoned"] = true
	active.status_conditions["burned"] = true
	active.status_conditions["asleep"] = true
	active.status_conditions["paralyzed"] = true

	gsm.game_state.current_player_index = 0
	var damaged_slots: Array[PokemonSlot] = gsm.effect_processor.process_pokemon_check(gsm.game_state)

	return run_checks([
		assert_eq(active.damage_counters, 30, "Pokemon Check should place 10 Poison plus 20 Burn damage on the Active Pokemon"),
		assert_true(active in damaged_slots, "Pokemon Check should report the Active Pokemon that took status damage"),
		assert_true(active.status_conditions.get("poisoned", false), "Poison should persist after Pokemon Check"),
		assert_false(active.status_conditions.get("burned", false), "Burn should clear on a heads flip after applying damage"),
		assert_false(active.status_conditions.get("asleep", false), "Sleep should clear on a heads flip"),
		assert_false(active.status_conditions.get("paralyzed", false), "Paralysis should clear during its owner's Pokemon Check"),
	])


func test_paralysis_survives_opponent_pokemon_check_and_clears_on_owner_check() -> String:
	var gsm := _make_gsm()
	var paralyzed_active: PokemonSlot = gsm.game_state.players[1].active_pokemon
	paralyzed_active.set_status("paralyzed", true)

	gsm.game_state.current_player_index = 0
	gsm.effect_processor.process_pokemon_check(gsm.game_state)
	var remains_after_opponent_check := bool(paralyzed_active.status_conditions.get("paralyzed", false))

	gsm.game_state.current_player_index = 1
	gsm.effect_processor.process_pokemon_check(gsm.game_state)

	return run_checks([
		assert_true(remains_after_opponent_check, "Paralysis should not clear during the opponent's Pokemon Check"),
		assert_false(paralyzed_active.status_conditions.get("paralyzed", false), "Paralysis should clear during its owner's Pokemon Check"),
	])


func test_bench_special_conditions_are_ignored_by_pokemon_check() -> String:
	var gsm := _make_gsm([true, true])
	var bench_slot := _make_slot(_make_pokemon("Stale Bench Status"), 0)
	bench_slot.status_conditions["poisoned"] = true
	bench_slot.status_conditions["burned"] = true
	bench_slot.status_conditions["asleep"] = true
	bench_slot.status_conditions["paralyzed"] = true
	gsm.game_state.players[0].bench.append(bench_slot)

	gsm.effect_processor.process_pokemon_check(gsm.game_state)

	return run_checks([
		assert_eq(bench_slot.damage_counters, 0, "Pokemon Check should not damage Benched Pokemon with stale status flags"),
		assert_true(bench_slot.status_conditions.get("poisoned", false), "Pokemon Check should not mutate stale Bench Poison"),
		assert_true(bench_slot.status_conditions.get("burned", false), "Pokemon Check should not mutate stale Bench Burn"),
		assert_true(bench_slot.status_conditions.get("asleep", false), "Pokemon Check should not mutate stale Bench Sleep"),
		assert_true(bench_slot.status_conditions.get("paralyzed", false), "Pokemon Check should not mutate stale Bench Paralysis"),
	])


func test_retreat_status_rules_match_official_status_matrix() -> String:
	var gsm := _make_gsm()
	var active: PokemonSlot = gsm.game_state.players[0].active_pokemon
	gsm.game_state.players[0].bench.append(_make_slot(_make_pokemon("Retreat Target"), 0))

	active.status_conditions["poisoned"] = true
	active.status_conditions["burned"] = true
	active.set_status("confused", true)
	var can_retreat_confused_poison_burn := gsm.rule_validator.can_retreat(gsm.game_state, 0, gsm.effect_processor)

	active.clear_all_status()
	active.set_status("asleep", true)
	var can_retreat_asleep := gsm.rule_validator.can_retreat(gsm.game_state, 0, gsm.effect_processor)

	active.clear_all_status()
	active.set_status("paralyzed", true)
	var can_retreat_paralyzed := gsm.rule_validator.can_retreat(gsm.game_state, 0, gsm.effect_processor)

	return run_checks([
		assert_true(can_retreat_confused_poison_burn, "Confusion, Poison, and Burn should not prevent retreat"),
		assert_false(can_retreat_asleep, "Sleep should prevent retreat"),
		assert_false(can_retreat_paralyzed, "Paralysis should prevent retreat"),
	])


func test_evolution_clears_all_special_conditions_including_poison() -> String:
	var gsm := _make_gsm()
	var active: PokemonSlot = gsm.game_state.players[0].active_pokemon
	active.status_conditions["poisoned"] = true
	active.status_conditions["burned"] = true
	active.status_conditions["asleep"] = true
	active.status_conditions["paralyzed"] = true
	active.status_conditions["confused"] = true
	var evolution := CardInstance.create(_make_stage1("Status Stage 1", active.get_pokemon_name()), 0)
	gsm.game_state.players[0].hand.append(evolution)

	var evolved := gsm.evolve_pokemon(0, evolution, active)

	return run_checks([
		assert_true(evolved, "Evolution should be legal in this mid-game test state"),
		assert_false(active.has_any_status(), "Evolution should clear all special conditions, including Poison"),
	])


func test_normal_attack_status_rules_and_confusion_tails() -> String:
	var gsm := _prepare_basic_attacker_gsm([false])
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon

	attacker.set_status("asleep", true)
	var can_attack_asleep := gsm.can_use_attack(0, 0)

	attacker.clear_all_status()
	attacker.set_status("paralyzed", true)
	var can_attack_paralyzed := gsm.can_use_attack(0, 0)

	attacker.clear_all_status()
	attacker.status_conditions["poisoned"] = true
	attacker.status_conditions["burned"] = true
	attacker.set_status("confused", true)
	var can_attack_confused := gsm.can_use_attack(0, 0)
	var used_confused_attack := gsm.use_attack(0, 0)

	return run_checks([
		assert_false(can_attack_asleep, "Sleep should block normal attacks"),
		assert_false(can_attack_paralyzed, "Paralysis should block normal attacks"),
		assert_true(can_attack_confused, "Confusion should allow declaring an attack before the coin flip"),
		assert_true(used_confused_attack, "Confusion tails still consumes the declared attack"),
		assert_eq(attacker.damage_counters, 60, "Confusion tails should deal 30 self damage, then active Poison/Burn apply during Pokemon Check"),
		assert_eq(defender.damage_counters, 0, "Confusion tails should make the attack fail before damage or effects resolve"),
	])


func test_granted_attack_is_blocked_by_asleep() -> String:
	var gsm := _prepare_granted_attacker_gsm()
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	attacker.set_status("asleep", true)

	var used := gsm.use_granted_attack(0, attacker, _granted_attack(gsm, attacker))

	return run_checks([
		assert_false(used, "Asleep should block tool-granted attacks"),
		assert_eq(defender.pokemon_stack.size(), 2, "Blocked granted attack should not execute its effect"),
	])


func test_granted_attack_is_blocked_by_paralyzed() -> String:
	var gsm := _prepare_granted_attacker_gsm()
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	attacker.set_status("paralyzed", true)

	var used := gsm.use_granted_attack(0, attacker, _granted_attack(gsm, attacker))

	return run_checks([
		assert_false(used, "Paralyzed should block tool-granted attacks"),
		assert_eq(defender.pokemon_stack.size(), 2, "Blocked granted attack should not execute its effect"),
	])


func test_granted_attack_respects_first_player_first_turn_attack_rule() -> String:
	var gsm := _prepare_granted_attacker_gsm()
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	gsm.game_state.turn_number = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 0

	var can_use := gsm.rule_validator.can_use_granted_attack(gsm.game_state, 0, attacker, _granted_attack(gsm, attacker), gsm.effect_processor)
	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)

	return run_checks([
		assert_false(can_use, "Tool-granted attacks should obey the first-player first-turn attack restriction"),
		assert_false(_has_action_kind(actions, "granted_attack"), "AI legal actions should not expose a first-player first-turn granted attack"),
	])


func test_granted_attack_confusion_tails_fails_before_effect() -> String:
	var gsm := _prepare_granted_attacker_gsm([false])
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	attacker.set_status("confused", true)

	var used := gsm.use_granted_attack(0, attacker, _granted_attack(gsm, attacker))

	return run_checks([
		assert_true(used, "Declaring a granted attack under Confusion should consume the attack even on tails"),
		assert_eq(attacker.damage_counters, 30, "Confusion tails should place 30 damage on the attacker"),
		assert_eq(defender.pokemon_stack.size(), 2, "Confusion tails should make the granted attack fail before its effect executes"),
	])


func test_granted_attack_confusion_heads_executes_effect() -> String:
	var gsm := _prepare_granted_attacker_gsm([true])
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	attacker.set_status("confused", true)

	var used := gsm.use_granted_attack(0, attacker, _granted_attack(gsm, attacker))

	return run_checks([
		assert_true(used, "Confusion heads should allow the granted attack to resolve"),
		assert_eq(attacker.damage_counters, 0, "Confusion heads should not damage the attacker"),
		assert_eq(defender.pokemon_stack.size(), 1, "Confusion heads should execute the granted attack effect"),
	])


func test_ai_action_builder_filters_status_blocked_attacks() -> String:
	var gsm := _prepare_basic_attacker_gsm()
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	_attach_tm_devolution(attacker, 0)
	var builder := AILegalActionBuilder.new()

	attacker.set_status("asleep", true)
	var asleep_actions := builder.build_actions(gsm, 0)

	attacker.clear_all_status()
	attacker.set_status("paralyzed", true)
	var paralyzed_actions := builder.build_actions(gsm, 0)

	attacker.clear_all_status()
	attacker.set_status("confused", true)
	var confused_actions := builder.build_actions(gsm, 0)

	return run_checks([
		assert_false(_has_action_kind(asleep_actions, "attack"), "AI should not expose normal attacks while Asleep"),
		assert_false(_has_action_kind(asleep_actions, "granted_attack"), "AI should not expose granted attacks while Asleep"),
		assert_false(_has_action_kind(paralyzed_actions, "attack"), "AI should not expose normal attacks while Paralyzed"),
		assert_false(_has_action_kind(paralyzed_actions, "granted_attack"), "AI should not expose granted attacks while Paralyzed"),
		assert_true(_has_action_kind(confused_actions, "attack"), "AI should still expose normal attacks while Confused"),
		assert_true(_has_action_kind(confused_actions, "granted_attack"), "AI should still expose granted attacks while Confused"),
	])
